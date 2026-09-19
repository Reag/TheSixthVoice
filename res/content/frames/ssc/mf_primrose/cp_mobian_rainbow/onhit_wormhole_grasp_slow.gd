## The Slowed itself. The statuses/save wiring is declarative on the .tres; this script exists for two
## clauses the .tres cannot express.
##
## THE OVERWATCH GATE, first, and it has to be first: "when you damage a character with an OVERWATCH".
## activation.context.flags carries Action.FLAG.IS_OVERWATCH for an overwatch attack, put there by
## CommonActionUtil.choose_and_use through action_overwatch.gd:31-39, and it survives into the attack
## events unchanged (action_attack.gd:267-272 passes context.flags into event_unit_attack_declared).
## This is the Tortuga's onhit_hyper_reflex_mode_immobilize.gd line for line.
##
## THE 1/ROUND INCREMENT, second, and it has to be second: ruling 10 spends the round by FORCING the
## save, pass or fail. super.should_abort is what rolls it (on_hit_effect.gd:69-73), so the increment
## goes before the super call and after the overwatch gate - a normal hit must spend nothing.
##
## THE CHARACTER GATE: the card says "damage a CHARACTER". apply_on_hits is reached for any valid
## target unit, so without it an overwatch against a destructible object would spend the round on a
## save that can do nothing.
##
## THE DURATION IS THE ENGINE'S OWN AND THERE IS DELIBERATELY NO OVERRIDE.
## OnHitEffect.get_applied_duration_for_statuses returns StatusType.get_standard_until(status)
## (on_hit_effect.gd:91-92), and content/statuses/status_slowed.tres declares standard_until = 1 =
## Lancer.UNTIL.END_OF_NEXT_TURN - which is exactly what ruling 10 asks for.
## test_the_slow_lasts_until_the_end_of_the_targets_next_turn is what would notice an override being
## added.
##
## increment_action_usage's second argument is FALSE for the same reason Magnetic Weight
## Redistribution's is: the flag gates only the uses_this_turn tally (gear_core.gd:180-181), nothing
## reads a per-turn count under this key, and a true here would write a third counter nobody reads.
extends OnHitEffect

const CORE_ID:StringName = &'cp_mobian_rainbow'
const USAGE_KEY:StringName = &'wormhole_slow'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		if not activation.context.flags.has(Action.FLAG.IS_OVERWATCH): return true
		if (
			Unit.is_valid(attacked_unit) and attacked_unit.is_character() and
			Unit.is_valid(activation.context.unit)
		):
			var core_gear:GearCore = activation.context.unit.get_gear(CORE_ID)
			if GearCore.is_valid(core_gear): core_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)
