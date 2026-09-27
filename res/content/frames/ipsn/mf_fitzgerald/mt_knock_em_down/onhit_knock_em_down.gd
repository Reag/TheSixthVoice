## The knockdown itself. The statuses/save wiring is declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 15 (2026-09-13): the round is spent by FORCING the save, pass or fail - the trigger is the
## crit, not the knockdown. So the increment happens here, before super() rolls the save, exactly as
## Crack Shot III increments before it calls UnitHasecheck.make_save. Incrementing in on_crit()
## instead would spend the round only on a FAILED save, because a passed save makes should_abort
## return true and on_crit is never reached.
##
## THE CHARACTER GATE (review finding 1, 2026-09-13) and THE BOOKKEEPING FLAG (whole-branch review,
## 2026-09-13) now live once, in the shared helper's header (gear/shared/once_per_round, close-out
## Pass D): a crit on a non-character spends nothing, and the increment passes
## increment_per_turn_counter = false.
extends OnHitEffect

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const TRAIT_ID:StringName = &'mt_knock_em_down'
const USAGE_KEY:StringName = &'knock_em_down'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		OncePerRound.spend(activation.context.unit, attacked_unit, TRAIT_ID, USAGE_KEY)
	return await super(stage, activation, attacked_unit)
