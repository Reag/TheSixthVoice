## The rend itself. The statuses and the save are declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 14 (2026-09-17), inherited whole from Knock 'em down's ruling 15: the round is spent by
## FORCING the Hull save, pass or fail - the trigger is the crit, not the statuses. So the increment
## happens here, BEFORE super() rolls the save, exactly as Crack Shot III increments before calling
## UnitHasecheck.make_save. Incrementing in on_crit() instead would spend the round only on a FAILED
## save, because a passed save makes should_abort return true and on_crit is never reached.
##
## THE CHARACTER GATE (the card's subject is "the target", and Impaired and Slowed do nothing to a
## non-character) and THE BOOKKEEPING FLAG (false, as the mod's other 1/round traits) live once, in
## the shared helper's header (gear/shared/once_per_round, close-out Pass D).
extends OnHitEffect

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const TRAIT_ID:StringName = &'mt_rend'
const USAGE_KEY:StringName = &'rend'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		OncePerRound.spend(activation.context.unit, attacked_unit, TRAIT_ID, USAGE_KEY)
	return await super(stage, activation, attacked_unit)
