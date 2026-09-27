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
## THE CHARACTER GATE: the card says "damage a CHARACTER". The shared helper applies it
## (gear/shared/once_per_round): an overwatch against a destructible object spends nothing.
##
## THE DURATION IS THE ENGINE'S OWN AND THERE IS DELIBERATELY NO OVERRIDE.
## OnHitEffect.get_applied_duration_for_statuses returns StatusType.get_standard_until(status)
## (on_hit_effect.gd:91-92), and content/statuses/status_slowed.tres declares standard_until = 1 =
## Lancer.UNTIL.END_OF_NEXT_TURN - which is exactly what ruling 10 asks for.
## test_the_slow_lasts_until_the_end_of_the_targets_next_turn is what would notice an override being
## added.
##
## The helper's increment passes increment_per_turn_counter = false; its header says why.
extends OnHitEffect

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const CORE_ID:StringName = &'cp_mobian_rainbow'
const USAGE_KEY:StringName = &'wormhole_slow'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		if not activation.context.flags.has(Action.FLAG.IS_OVERWATCH): return true
		OncePerRound.spend(activation.context.unit, attacked_unit, CORE_ID, USAGE_KEY)
	return await super(stage, activation, attacked_unit)
