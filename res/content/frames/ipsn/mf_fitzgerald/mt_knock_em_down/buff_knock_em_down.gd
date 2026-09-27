## Knock 'em down: supplies a crit-stage OnHitEffect to the Fitzgerald's Cannon attacks, once a round.
##
## The round limit is the shared once-per-round helper (gear/shared/once_per_round, close-out Pass D),
## whose header says why it is hand-rolled; onhit_knock_em_down.gd spends it.
##
## CANNON is filtered declaratively via weapon_types = [1] on the .tres (BuffWeaponType.
## check_if_passive_applies, called through super below) - unlike Hole Puncher, this trait is
## Cannon-only, not Cannon-or-Line, so no extra predicate is needed here.
extends BuffWeaponTypeOnHit

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const USAGE_KEY:StringName = &'knock_em_down'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return OncePerRound.is_unspent(core.get_owner_gear(context.map), USAGE_KEY)
