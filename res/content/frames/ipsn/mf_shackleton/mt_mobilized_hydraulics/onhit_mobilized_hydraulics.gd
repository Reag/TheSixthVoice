## MOBILIZED HYDRAULICS (Shackleton): "1/round, when the Shackleton hits an enemy with a melee attack,
## it may have that attack gain Knockback 2." Design ruling 7.
##
## ON_ATTACK, NOT ON_HIT - the order is the whole design. event_unit_attack.gd:59 settles the roll,
## :66-69 runs every ON_ATTACK effect, and :84 is action.on_hit, where action_attack_weapon.gd:325-331
## sums EXTRA_KNOCKBACK into the weapon's own value and :337 queues the push. So arming here folds
## the +2 into the SAME push as the weapon's own knockback; the ON_HIT stage (:85-87) runs after the
## push and would be too late. The roll is known at this point, so only an actual hit is offered
## (the BATS on-attack prompt, onhit_bounded_automatic_targeting_systems.gd, is the shape).
##
## A STAMP ON THE ATTACK, NOT A ONETIME BUFF. consume_buffs at action_attack_weapon.gd:345 would eat a
## onetime knockback buff after the FIRST target of a multi-target melee attack; instead the answer is
## stamped as meta on the attack's own DeclaredAttackSummary (context.resource, one object shared by
## every per-target event of the attack - event_unit_attack_declared.gd:62), so every target the
## attack hits after the answer gains the Knockback, and the stamp dies with the attack.
## buff_mobilized_hydraulics_knockback reads it off the same summary, which action_attack_weapon.on_hit
## hands it as context.resource (:320, :325). Pass F task 10 (open-items G): this replaced a state flag
## on the trait's GearCore cleared at on_resolution, which the knockback buff read with no check that
## the attack in progress was the one that armed it - a flag left set handed +2 to the next attack of
## any kind.
##
## "ENEMY" is UnitRelation.are_enemies - a destructible object or an ally is not offered. The round is
## spent by ACCEPTING; a decline spends nothing, so the next melee hit is offered again.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_mobilized_hydraulics'
const USAGE_KEY:StringName = &'mobilized_hydraulics'
## The meta stamped on the DeclaredAttackSummary; read by buff_mobilized_hydraulics_knockback.gd.
const ARMED_META := &'reag_hydraulics_armed'

func on_attack(activation:EventCore, attacked_unit:Unit) -> void:
	var context:Context = activation.context
	var roll := context.object as AttackRoll
	if roll == null or not roll.hit: return
	if not DeclaredAttackSummary.is_valid(context.resource): return
	var owner:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(owner) or not Unit.is_valid(attacked_unit): return
	if not UnitRelation.are_enemies(owner, attacked_unit): return
	var trait_gear:GearCore = owner.get_gear(TRAIT_ID)
	if not GearCore.is_valid(trait_gear): return
	if trait_gear.get_uses_this_round_alt(USAGE_KEY) > 0: return

	var confirmed := true # the AI always takes it
	if owner.is_player_controlled():
		var brochure := BrochureCore.create({
			title = trait_gear.kit.name(),
			description = trait_gear.kit.bbcode_description(),
			show_continue = false,
		})
		confirmed = await choice_bus.quick_yesno_for({
			tile = attacked_unit.tile(),
			title = tr('battle.confirm.use').format({action = Util.formatted_color(
				trait_gear.kit.name(),
				Colors.get_action_color(Action.FLAVOR.WEAPON)
			)}),
			brochure = brochure,
			whois = attacked_unit,
		})
		if activation.abort_without_units([owner, attacked_unit]): return
	if not confirmed: return

	trait_gear.increment_action_usage(USAGE_KEY, false)
	context.resource.set_meta(ARMED_META, true)
