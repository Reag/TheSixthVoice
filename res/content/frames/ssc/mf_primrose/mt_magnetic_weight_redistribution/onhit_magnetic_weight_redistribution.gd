## The knockdown itself. The statuses/save wiring is declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 12: the round is spent by FORCING the save, pass or fail - the trigger is the crit, not the
## knockdown. So the increment happens HERE, before super() rolls the save. Incrementing in on_crit()
## instead would spend the round only on a FAILED save, because a passed save makes should_abort
## return true and on_crit is never reached.
##
## THE CHARACTER GATE, also ruling 12 and the Fitzgerald's own review finding 1: the card says "the
## target", and event_unit_attack.gd's apply_on_crits is reached for ANY valid target unit - it only
## checks is_character() two lines later, for the crit bark (:95). Without the explicit gate below, a
## crit on a destructible object would spend the 1/round and force a Hull save that can do nothing
## (a non-character is immune to Prone outright, unit_condition.gd:502).
##
## THE BOOKKEEPING FLAG: increment_action_usage's second argument, increment_per_turn_counter, is
## passed FALSE, matching both of the Fitzgerald's 1/round traits. The flag gates only the
## uses_this_turn tally (gear_core.gd:180-181); uses_this_round and uses_this_scene are written either
## way, this trait's limit is the per-ROUND counter the buff reads, and the per-turn soft limit at
## unit_action.gd:168 asks per-ACTION against the usage group of the action being taken (the weapon's),
## never this trait's key. A true here would write a third counter nobody reads.
##
## THIS IS THE FITZGERALD'S onhit_knock_em_down.gd WITH TWO CONSTANTS CHANGED. See the SP1 plan's
## decision note for why it is copied rather than generalised, and what the third copy should trigger.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_magnetic_weight_redistribution'
const USAGE_KEY:StringName = &'magnetic_weight'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if (
		stage == apply_on and Unit.is_valid(attacked_unit) and attacked_unit.is_character() and
		Unit.is_valid(activation.context.unit)
	):
		var trait_gear:GearCore = activation.context.unit.get_gear(TRAIT_ID)
		if GearCore.is_valid(trait_gear): trait_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)
