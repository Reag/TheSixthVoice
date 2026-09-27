## REND: supplies a crit-stage OnHitEffect to the Maiden's Blush's MELEE attacks, once a round.
##
## Knock 'em down's shape with the weapon type changed (design §1.1, ruling 14). The two traits are
## the same mechanism and are deliberately written the same way, so a reader who knows one knows both.
##
## The round limit is the shared once-per-round helper (gear/shared/once_per_round, close-out Pass D),
## whose header says why it is hand-rolled; onhit_rend.gd spends it.
##
## MELEE IS FILTERED DECLARATIVELY, on the .tres (weapon_types = [2], read by
## BuffWeaponType.check_if_passive_applies through the super below), and BASIC gear is excluded by
## BuffWeaponType.allow_basic's own default of false - which is ruling 12 in a line nobody has to
## write: Ram, Grapple and the Improvised Attack are basic mw_ Kits with weapon_type = MELEE, and none
## of them triggers Rend.
extends BuffWeaponTypeOnHit

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const USAGE_KEY:StringName = &'rend'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return OncePerRound.is_unspent(core.get_owner_gear(context.map), USAGE_KEY)
