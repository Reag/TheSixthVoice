# Script extension on the character sheet's RANGE DISPLAY widget - the threat indicator.
#
# THE GAP IS VANILLA'S, AND VANILLA SAYS SO. range_display.gd:65-67 renders the PRINTED
# `attack.threat`; nothing on that path ever calls `attack.threat_distance(specific)`. Its
# rerender_specific (:6-43) does compute an override, but only for AIM RANGE, and only from a block
# commented `# TEMPORARY HOTFIX HACK` that names two compcon ids outright - wm_stabilizer_mod +5,
# cb_neurolink_targeting +3. The general walk that would have covered everything else sits commented
# out beneath it under `# TOO CRASHY TO RUN OUT OF COMBAT` (:21-41). `rerender(attack,
# aim_range_override)` takes exactly one override and it is not this one.
#
# Reported against the DDMR (author, 2026-09-19: "does not increase the threat ... did not move from
# 3 to 4"), but it was never a DDMR bug: mt_artful_caress on the same frame has the identical gap,
# and so does every weapon mod and trait anyone ships. Combat is unaffected - ActionAttackWeapon.
# threat_distance (:186-189) reads the buffs correctly and always did.
#
# ============================ WHY THIS DOES NOT CALL BuffBonus ============================
#
# BuffBonus.get_bonus_for_subtype is the engine's own answer and it is the wrong tool HERE, for the
# reason vanilla's comment gestures at. The walk ends in BuffWeaponType.check_if_passive_applies,
# whose last filter is `from_weapon_mod and not context.gear.is_weapon_mod_attached(core.from_gear)`
# (buff_weapon_type.gd:53). A BuffCore minted for a display pass has no `from_gear`, so the buffs
# that matter most - every weapon mod's, including the DDMR's, which sets from_weapon_mod = true -
# are precisely the ones that go through a null there. The character sheet is drawn out of combat,
# with no live BuffCores to borrow.
#
# So this reads STATIC DATA off the loadout, which is what vanilla's working hotfix does, only
# generically instead of by hard-coded id: the weapon mods actually fitted to this weapon, and the
# traits actually on this unit. It re-implements two filters from buff_weapon_type.gd and nothing
# else:
#
#   weapon_sizes  -> ActionAttackWeapon.weapon_size          (buff_weapon_type.gd:42)
#   weapon_types  -> ActionAttackWeapon.is_weapon_type(gear) (:43)
#
# `from_weapon_mod` needs no check: a buff reached through get_weapon_mod_passives IS on a mod
# fitted to this weapon - gear_core.gd:363-374 walks this gear's own `mod_ids` - so the condition
# that would have crashed is satisfied by construction. `weapon_types_forbidden`, `damage_types`,
# `from_compcon_id`, `allow_basic` and `requires_consume_lock` are deliberately NOT re-implemented:
# nothing in this mod sets them, they cannot make a bonus APPEAR that the engine withholds (each one
# can only narrow), and a half-copy of the engine's filter set is worse than an honestly partial one.
# A future buff that uses them would be over-reported here and correct in play; that is the known
# edge, and it is the safe direction for a display.
#
# ============================== WHAT IT DELIBERATELY DOES NOT DO ==============================
#
# IT NEVER INVENTS A THREAT. `if attack.threat <= 0: return` mirrors the engine: get_target_range
# (action_attack_weapon.gd:198-201) only reaches threat_distance for a melee weapon whose printed
# threat is above zero, so a threat_range bonus on a rifle or on a thrown profile never reaches play
# and must not reach the sheet either.
#
# IT NEVER SHOWS AN INDICATOR VANILLA HID. The re-render below runs only when %ThreatRange is
# already visible after super(). Vanilla's own visibility rule (`attack.threat > 1 or (aim_range == 0
# and not range_pattern)`, :65) is left exactly as it is - a weapon printing threat 1 alongside an
# aim range stays hidden even if a bonus would take it to 2. That is a narrower fix than "correct in
# all cases", chosen on purpose: widening the rule changes what a VANILLA install looks like for
# every weapon in the game, and this mod has no business doing that from a frame's weapon mod.
#
# THE INSTALL LOG IS NOT EVIDENCE THAT ANY OF THIS RUNS (memory lancer-tactics-extension-seams;
# unit_action.gd is the known-dead seam that logs identically). spec/test_range_display_extension.gd
# is the evidence: it renders the real widget and asserts the string a player would read off
# TagIcon's Number label. Unlike an autoload, this needs no entry in mod_main.gd's EXTENDED_AUTOLOADS
# and no deferred reload. The widget is not fresh per draw - it lives inside weapon_mount_item /
# kit_entry rows that TrekBox POOLS (Util.pull_next_available_item_from_placeholder re-shows a hidden
# row before it instances a new one) - but every instance comes from range_display.tscn after the
# mod installed, and each draw calls rerender_specific again, so it picks up the extended script
# with no help. (This mod is requires_restart, so no row can predate the install.)
extends "res://ui/page/character_sheet/widgets/range_display.gd"

func rerender_specific(dummy_specific:SpecificAction) -> void:
	# Vanilla first, in full: it draws the aim range, the AoE and the tooltips, and its visibility
	# decisions are the ones we honour below rather than second-guess.
	super(dummy_specific)

	if not SpecificAction.is_valid(dummy_specific): return
	if not dummy_specific.action is ActionAttackWeapon: return
	var attack:ActionAttackWeapon = dummy_specific.action
	# See "IT NEVER INVENTS A THREAT" above.
	if attack.threat <= 0: return

	var tag:Node = get_node_or_null('%ThreatRange')
	# See "IT NEVER SHOWS AN INDICATOR VANILLA HID" above.
	if tag == null or not tag.visible: return

	var threat:int = attack.threat + collect_static_threat_bonus(dummy_specific, attack)
	if threat == attack.threat: return

	tag.rerender(threat, Icon.term(Lancer.TERM.THREAT))
	tooltip_bus.show_glossary_on_mouseover(
		tag, GlossaryItem.create(Lancer.term_name(Lancer.TERM.THREAT), threat)
	)

## Every threat_range bonus this weapon carries that can be read WITHOUT a live combat context.
## See the header for which of buff_weapon_type.gd's filters are re-implemented and which are not.
func collect_static_threat_bonus(specific:SpecificAction, attack:ActionAttackWeapon) -> int:
	if not Unit.is_valid(specific.unit) or not GearCore.is_valid(specific.gear): return 0
	var loadout:LoadoutCore = specific.unit.core.loadout
	if loadout == null: return 0

	var buffs:Array[Buff] = []
	# The mods fitted to THIS weapon. get_weapon_mod_passives walks specific.gear's own mod_ids
	# (gear_core.gd:363-367), so `from_weapon_mod` is already satisfied - see the header.
	for passive:PassiveWeaponMod in specific.gear.get_weapon_mod_passives(loadout):
		buffs.append_array(passive.applied_buffs)
	# The frame's traits, which is where mt_artful_caress lives. Vanilla's own hotfix reaches for
	# loadout.get_traits() the same way for cb_neurolink_targeting (range_display.gd:16-19).
	for trait_gear:GearCore in loadout.get_traits():
		if not GearCore.is_valid(trait_gear): continue
		for passive:Passive in trait_gear.get_passives_of_type(PassiveBuffApplicator):
			buffs.append_array(passive.applied_buffs)

	var bonus:int = 0
	for buff:Buff in buffs:
		if not buff is BuffWeaponTypeBonus: continue
		var weapon_buff:BuffWeaponTypeBonus = buff
		if weapon_buff.bonus_subtype != Buff.BONUS_SUBTYPE.THREAT_RANGE: continue
		if not applies_to_weapon(weapon_buff, specific, attack): continue
		# NOT QUITE VANILLA'S RULE. BuffBonus.get_bonus_for_subtype (buff_bonus.gd:27-29) adds a
		# stacking bonus, but on the FIRST overriding one it RETURNS maxi(value, running total) and
		# never looks at a later buff, so its answer depends on buff order. This keeps walking and
		# takes the max against the bonus so far (the printed threat is added back by the caller).
		# The two agree for stacking bonuses; they can differ only once an override is in play, and
		# no threat_range bonus in this mod sets overrides.
		if weapon_buff.overrides: bonus = maxi(bonus, weapon_buff.bonus_value - attack.threat)
		else: bonus += weapon_buff.bonus_value
	return bonus

## The two filters from BuffWeaponType.check_if_passive_applies (buff_weapon_type.gd:42-43) that a
## display pass can evaluate honestly. The header says why the other five are left out.
func applies_to_weapon(
	weapon_buff:BuffWeaponTypeBonus, specific:SpecificAction, attack:ActionAttackWeapon
) -> bool:
	if not weapon_buff.weapon_sizes.is_empty() and not weapon_buff.weapon_sizes.has(attack.weapon_size):
		return false
	if not weapon_buff.weapon_types.is_empty() and not weapon_buff.weapon_types.any(
		attack.is_weapon_type.bind(specific.gear)
	): return false
	return true
