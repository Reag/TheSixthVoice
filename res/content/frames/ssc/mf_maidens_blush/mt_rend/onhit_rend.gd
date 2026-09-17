## The rend itself. The statuses and the save are declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 14 (2026-09-17), inherited whole from Knock 'em down's ruling 15: the round is spent by
## FORCING the Hull save, pass or fail - the trigger is the crit, not the statuses. So the increment
## happens here, BEFORE super() rolls the save, exactly as Crack Shot III increments before calling
## UnitHasecheck.make_save. Incrementing in on_crit() instead would spend the round only on a FAILED
## save, because a passed save makes should_abort return true and on_crit is never reached.
##
## THE CHARACTER GATE. The card's subject is "the target", and Impaired and Slowed do nothing to a
## non-character; event_unit_attack.gd reaches apply_on_crits for ANY valid target unit and only
## checks is_character() two lines later, for the crit bark. Without this gate a melee crit on a
## destructible object would spend the 1/round and force a save that can do nothing.
##
## THE BOOKKEEPING FLAG. increment_action_usage's second argument, increment_per_turn_counter, is
## passed false to match this mod's other two 1/round traits. It gates only the uses_this_turn tally
## (gear_core.gd:173-181 - uses_this_round and uses_this_scene are written either way), this trait's
## limit is the per-ROUND counter buff_rend reads, and nothing anywhere consults a per-turn count
## under &'rend'.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_rend'
const USAGE_KEY:StringName = &'rend'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if (
		stage == apply_on and Unit.is_valid(attacked_unit) and attacked_unit.is_character() and
		Unit.is_valid(activation.context.unit)
	):
		var trait_gear:GearCore = activation.context.unit.get_gear(TRAIT_ID)
		if GearCore.is_valid(trait_gear): trait_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)
