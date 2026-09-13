# Spike 10 (2026-09-13): can a mod STRIP the AP damage flag from an attack made with a weapon that
# carries the Ripper Mod? That is the mod's second clause (Fitzgerald rank II, IPS-N): "Attacks made
# with this weapon lose AP and cannot gain AP by any means."
#
# This is a PROBE, not a spec for content. It builds the candidate buff in memory, hangs it off a
# VANILLA weapon mod fitted to a VANILLA AP rifle, and asserts what the engine does with the armor
# of the unit that gets shot. The verdict is written up in
# D:\DEV\lancer-tactics-claude\specs\2026-09-13-ap-strip-feasibility.md; the Ripper Mod's real specs
# replace this file when SP3 builds it.
#
# WHY THIS SEAM. Weapon tags are add-only (action_attack_weapon.gd:130-138 never deletes a key) and
# both readers of the AP tag sit in a class_name script (event_unit_attack_declared.gd:80 and :249),
# so nothing on the TAG side can take AP away. But the tag is not what armor reads. The declared
# attack turns it into EventService.DAMAGE_FLAG.AP on each damage event's context, and
# event_unit_damage.gd's execute_preblock then does, in order:
#
#     prelim  = DamageModifications.create(unit, amount, context)    # reads context.flags
#     await core.execute_reaction_events(TRIGGER.DAMAGE, TIMING.PRE)  # brace, black witch, ...
#     final   = DamageModifications.create(unit, amount, context)    # reads context.flags AGAIN
#
# and damage_modifications.gd:103 only skips armor when the FINAL read still carries the flag. A
# DAMAGE PRE trigger runs between the two reads with the damage event itself in hand, and the
# reaction bus fires triggered BUFFS as well as reactions (reaction_bus.gd:60-68), on every unit's
# buffs, not just the victim's. The Bastion's buff_deathcounter_bastion.gd is the vanilla precedent
# for a PRE buff mutating the triggering damage event (it calls context.event.set_aborted()). So the
# candidate is a hidden triggered Buff, applied by the mod's PassiveWeaponMod through applied_buffs,
# that erases the flag from the triggering event's context.flags. No script extension anywhere.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_ripper_mod_ap.gd
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

## THE CANDIDATE. A hidden buff on the attacker that fires PRE on every damage event, and erases the
## AP flag when that damage is an attack roll's own, dealt by the buff's holder, with the weapon the
## buff's source mod is fitted to. It does NOT call super.activate(): the base implementation clears
## the buff off the unit, and this one has to outlive every shot.
class ProbeStripAp extends Buff:
	func _init() -> void:
		hide_from_player = true
		triggers_on.append(ReactionBus.TRIGGER.DAMAGE)
		trigger_timing = ReactionBus.TIMING.PRE

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.gear, Context.PROP.object]

	func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context := triggering_event.context
		if not context.flags.has(EventService.DAMAGE_FLAG.AP): return false
		if not AttackRoll.is_valid(context.object): return false # only an attack's own damage
		if context.target_unit != unit: return false # the damage event's target_unit is WHO dealt it
		var weapon:GearCore = context.gear
		var mod:GearCore = weapon.get_weapon_mod(unit.core.loadout)
		return GearCore.is_valid(mod) and mod.persistent_id == core.from_gear

	func activate(core:BuffCore, activation:EventCore) -> void:
		activation.context.event.context.flags.erase(EventService.DAMAGE_FLAG.AP)

## For the "cannot gain AP by any means" half: a WEAPON_TAG buff granting AP to every weapon, the
## Rainmaker's Huntsman shape. weapon_types left empty so BuffWeaponType's gate lets everything through.
class ProbeGrantAp extends BuffWeaponType:
	func _init() -> void:
		to = Buff.TO.WEAPON_TAG
		hide_from_player = true

	func get_values(core:BuffCore, context:Context) -> Context:
		return Context.create({category = Lancer.WEAPON_TAG.AP, number = 0})

## A vanilla Main Rifle with AP on its one profile: 1d3+2 energy (mw_thermal_rifle.tres:13-15).
const AP_RIFLE := &'mw_thermal_rifle'
## A vanilla Main Rifle with NO AP: 1d6 kinetic, Reliable (mw_assault_rifle.tres:13-15).
const PLAIN_RIFLE := &'mw_assault_rifle'
## A vanilla weapon mod that fits any Auxiliary/Main/Heavy weapon (allowed_sizes [0,1,2], no type
## filter). It stands in for the Ripper Mod: the probe buff needs a real mod GearCore to be
## attributed to, so that "the weapon this mod is fitted to" is answered the way the real mod will
## answer it - weapon.get_weapon_mod(loadout) against BuffCore.from_gear.
const CARRIER_MOD := &'wm_uncle_class_comp_con'

const ARMOR := 2
const AP_RIFLE_DAMAGE := 5    # 1d3+2 with the die pinned to 3
const PLAIN_RIFLE_DAMAGE := 6 # 1d6 pinned to 6

const FIRE_FROM := Vector2i(0, 2)
const TARGET_TILE := Vector2i(4, 2) # distance 4 on the default 5x5 map; aim_range defaults to 5

var game:Gamemaster
var unit:Unit
var target:Unit
var modded:GearCore  # AP rifle carrying the stand-in mod
var plain:GearCore   # a second AP rifle, no mod
var carrier:GearCore # the stand-in mod's own GearCore

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)
	unit = SpecFactory.create_unit(game.map, FIRE_FROM)
	# Equip everything before touching any state: equip_system full_repair()s the whole loadout.
	modded = unit.core.equip_system(AP_RIFLE)
	plain = unit.core.equip_system(AP_RIFLE)
	carrier = unit.core.loadout.equip_weapon_mod(CARRIER_MOD, modded)
	SpecFactory.apply_passive_buffs(unit)

	target = SpecFactory.create_unit(game.map, TARGET_TILE, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(target) # we rewrite its stats
	target.core.frame.stat.health = 200 # never dies
	target.core.frame.stat.armor = ARMOR
	target.core.frame.stat.evasion = -10 # every shot hits; the dice only fix the numbers
	target.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func strip_ap_from(mod:GearCore) -> void:
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, ProbeStripAp.new(), mod)

func grant_ap_to_everything() -> void:
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, ProbeGrantAp.new())

## Fire a weapon's solo profile at the target and return the health it lost. One shot per test: a
## second activation of the same gear in one turn is silently refused by the per-turn soft limit.
func shoot(weapon:GearCore, die:int) -> int:
	var before:int = target.core.current.health
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [die, die, die, die, die, die, die, die])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(),
		gear = weapon,
		unit = unit,
		target_unit = target,
	})
	return before - target.core.current.health

func has_ap(weapon:GearCore) -> bool:
	var specific := SpecificAction.create(unit, weapon, weapon.get_solo_action())
	return specific.action.has_tag(Lancer.WEAPON_TAG.AP, specific)

# ---------------------------------------------------------------- the fixture itself

func test_fixture_the_stand_in_mod_is_fitted_to_one_rifle_only() -> void:
	assert_true(GearCore.is_valid(carrier), 'The stand-in mod equipped.')
	assert_eq(modded.get_weapon_mod(unit.core.loadout), carrier, 'The first rifle carries the stand-in mod.')
	assert_null(plain.get_weapon_mod(unit.core.loadout), 'The second rifle carries nothing.')
	assert_true(has_ap(modded), 'The rifle has the AP tag.')

func test_fixture_an_ap_rifle_ignores_armor() -> void:
	var lost := await shoot(plain, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE, 'Full damage: AP ignored the armor.')

func test_fixture_armor_reduces_a_rifle_without_ap() -> void:
	var assault:GearCore = unit.core.equip_system(PLAIN_RIFLE)
	SpecFactory.apply_passive_buffs(unit)
	assert_false(has_ap(assault), 'The assault rifle has no AP.')
	var lost := await shoot(assault, 6)
	assert_eq(lost, PLAIN_RIFLE_DAMAGE - ARMOR, 'Armor took its bite.')

# ---------------------------------------------------------------- the strip

func test_a_pre_damage_buff_strips_ap_from_the_modded_weapon() -> void:
	strip_ap_from(carrier)
	assert_true(has_ap(modded), 'The TAG is still there; only the damage flag is taken away.')
	var lost := await shoot(modded, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE - ARMOR, 'Armor reduced the modded rifle\'s damage: AP was stripped.')

func test_the_strip_leaves_the_unmodded_weapon_alone() -> void:
	strip_ap_from(carrier)
	var lost := await shoot(plain, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE, 'The other rifle keeps its AP.')

func test_the_buff_survives_the_shot() -> void:
	strip_ap_from(carrier)
	var before := unit.state.buffs.size()
	await shoot(modded, 3)
	assert_eq(unit.state.buffs.size(), before, 'The strip buff was not consumed by firing.')

# ---------------------------------------------------------------- "cannot gain AP by any means"

func test_fixture_a_weapon_tag_buff_gives_a_plain_rifle_ap() -> void:
	var assault:GearCore = unit.core.equip_system(PLAIN_RIFLE)
	SpecFactory.apply_passive_buffs(unit)
	grant_ap_to_everything()
	assert_true(has_ap(assault), 'The buff hands the assault rifle AP.')
	var lost := await shoot(assault, 6)
	assert_eq(lost, PLAIN_RIFLE_DAMAGE, 'Buff-granted AP ignored the armor.')

func test_ap_gained_from_a_buff_is_stripped_too() -> void:
	var assault:GearCore = unit.core.equip_system(PLAIN_RIFLE)
	var assault_mod:GearCore = unit.core.loadout.equip_weapon_mod(CARRIER_MOD, assault)
	SpecFactory.apply_passive_buffs(unit)
	grant_ap_to_everything()
	strip_ap_from(assault_mod)
	assert_true(has_ap(assault), 'The tag side still says AP.')
	var lost := await shoot(assault, 6)
	assert_eq(lost, PLAIN_RIFLE_DAMAGE - ARMOR, 'The strip runs after every source of AP, so buff-granted AP is gone too.')
