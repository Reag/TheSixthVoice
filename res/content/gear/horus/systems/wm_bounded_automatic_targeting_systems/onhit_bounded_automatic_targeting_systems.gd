## BOUNDED AUTOMATIC TARGETING SYSTEMS, the Naga's rank-III weapon mod (SP4 Task 2, ruling 19 as
## re-cut by the author on 2026-09-23).
##
## "1/round, when you hit with an attack that consumed Lock On you may expend a charge, if you do, the
##  hit is treated as a Critical Hit. Resulting damage is not rolled twice. If the hit was already
##  Critical, you deal the maximum possible damage."
##
## ONE ON-HIT EFFECT ON THE MOD, AT THE ON_ATTACK STAGE - NOT THE DESIGN'S ARM-AT-DECLARATION SHAPE.
## The design armed BATS at attack_declared because it held that MAXIMIZE_DAMAGE had no prompt seam.
## It has one: event_unit_attack.gd runs every weapon mod's on_attack at :67, AFTER the roll sequence
## has settled hit and crit (:59) and BEFORE MAXIMIZE_DAMAGE is read (:72-74) and before any on_hit /
## on_crit effect (:83-93). So the player is asked only on an actual hit, knowing the result - the
## card's "when you hit ... you may" - and the answer can still turn the hit into a crit (roll.crit,
## which on_crit effects and the damage summary read later) or max a crit (roll.maximized, which :73
## only ever sets true). The author took this shape on 2026-09-23; ruling 19's mechanism is superseded.
##
## "RESULTING DAMAGE IS NOT ROLLED TWICE" IS NOT REACHABLE, recorded as a divergence (author,
## 2026-09-23). Damage for a crit is the higher of two sets that are ALWAYS both rolled
## (attack_util.gd:251-257), picked per weapon by get_damage_for_attack (action_attack.gd:77); no buff
## or on-hit seam reaches it for one attack roll. A BATS crit therefore takes the higher set like any
## crit.
##
## "Consumed Lock On" is OnHitEffect's own require_consume_lock (on_hit_effect.gd:57-64: roll.consumed_lock,
## copied from buff_lock_consumed at event_unit_attack.gd:54). 1/round is the mod gear's own per-round
## tally under USAGE_KEY, which event_turn_start resets with every other per-round count. A target
## that is crit-immune is not offered the conversion: vanilla demotes a crit on such a target
## (event_unit_attack.gd:222-223), so a spent charge would buy nothing - the same trap rule as Binding
## Fangs' already-locked target (ruling 14). A crit that got through is still maxed.
extends OnHitEffect

const USAGE_KEY := &'bounded_automatic_targeting_systems'

func on_attack(activation:EventCore, attacked_unit:Unit) -> void:
	var context:Context = activation.context
	var roll := context.object as AttackRoll
	if roll == null or not roll.hit: return
	var owner:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(owner): return
	var mod:GearCore = context.gear.get_weapon_mod(owner.core.loadout)
	if not GearCore.is_valid(mod): return
	if not mod.has_charges_left(): return
	if mod.get_uses_this_round_alt(USAGE_KEY) > 0: return
	var already_crit := roll.crit
	if not already_crit and UnitCondition.has_buff_to(attacked_unit, Buff.TO.CRIT_IMMUNITY, context): return

	var confirmed := true # the AI always takes it
	if owner.is_player_controlled():
		var brochure := BrochureCore.create({
			title = mod.kit.name(),
			description = mod.kit.bbcode_description(),
			subtitle = tr('lancer.geartag.limited').format({value = mod.get_charges_count_string(owner.core)}),
			show_continue = false,
		})
		confirmed = await choice_bus.quick_yesno_for({
			tile = attacked_unit.tile(),
			title = tr('battle.confirm.use').format({action = Util.formatted_color(
				mod.kit.name(),
				Colors.get_action_color(Action.FLAVOR.WEAPON)
			)}),
			brochure = brochure,
			whois = attacked_unit,
		})
		if activation.abort_without_units([owner, attacked_unit]): return
	if not confirmed: return

	mod.spend_charge()
	mod.increment_action_usage(USAGE_KEY, false)
	if already_crit: roll.maximized = true
	else: roll.crit = true
