## The knockdown itself. The statuses/save wiring is declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 12: the round is spent by FORCING the save, pass or fail - the trigger is the crit, not the
## knockdown. So the increment happens HERE, before super() rolls the save. Incrementing in on_crit()
## instead would spend the round only on a FAILED save, because a passed save makes should_abort
## return true and on_crit is never reached.
##
## THE CHARACTER GATE (also ruling 12, and the Fitzgerald's own review finding 1) and THE BOOKKEEPING
## FLAG (false) live once, in the shared helper's header (gear/shared/once_per_round). This file and
## onhit_knock_em_down.gd were two copies of one mechanism; close-out Pass D extracted it at the
## third instance, as the SP1 plan's decision note said it should.
extends OnHitEffect

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const TRAIT_ID:StringName = &'mt_magnetic_weight_redistribution'
const USAGE_KEY:StringName = &'magnetic_weight'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		OncePerRound.spend(activation.context.unit, attacked_unit, TRAIT_ID, USAGE_KEY)
	return await super(stage, activation, attacked_unit)
