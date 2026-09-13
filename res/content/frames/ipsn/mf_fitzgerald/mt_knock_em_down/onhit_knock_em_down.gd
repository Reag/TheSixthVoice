## The knockdown itself. The statuses/save wiring is declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 15 (2026-09-13): the round is spent by FORCING the save, pass or fail - the trigger is the
## crit, not the knockdown. So the increment happens here, before super() rolls the save, exactly as
## Crack Shot III increments before it calls UnitHasecheck.make_save. Incrementing in on_crit()
## instead would spend the round only on a FAILED save, because a passed save makes should_abort
## return true and on_crit is never reached.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_knock_em_down'
const USAGE_KEY:StringName = &'knock_em_down'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on and Unit.is_valid(attacked_unit) and Unit.is_valid(activation.context.unit):
		var trait_gear:GearCore = activation.context.unit.get_gear(TRAIT_ID)
		if GearCore.is_valid(trait_gear): trait_gear.increment_action_usage(USAGE_KEY)
	return await super(stage, activation, attacked_unit)
