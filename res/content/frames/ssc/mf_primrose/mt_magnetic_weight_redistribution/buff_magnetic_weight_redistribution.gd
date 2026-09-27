## MAGNETIC WEIGHT REDISTRIBUTION: supplies a crit-stage OnHitEffect to the Primrose's Heavy and
## Superheavy MELEE attacks, once a round.
##
##   "1/round, when the Primrose critically hits with a Heavy or Superheavy melee weapon, the target
##    must succeed a Hull save or be knocked Prone."
##
## THE FITZGERALD'S buff_knock_em_down.gd, COPIED with two differences (see the SP1 plan's decision
## note): a different USAGE_KEY, and the threat gate below. The size and type filters are
## DECLARATIVE on the .tres (weapon_sizes = [2, 3], weapon_types = [2]) and are applied by
## BuffWeaponType.check_if_passive_applies through super() - there is nothing to do here for them.
##
## THE ROUND LIMIT is the shared once-per-round helper (gear/shared/once_per_round, close-out Pass D),
## whose header says why it is hand-rolled; so is Knock 'em down's.
##
## THE THREAT GATE IS RULING 8, and it is the only clause the Fitzgerald's copy does not have. The
## Thrown tag makes get_alternate_actions build a variant of the SAME action with threat = 0
## (action_attack_weapon.gd:349-372, via VariantActionGroup.get_variant_specifics at :96-98) - same
## weapon_size, same weapon_type - so both declarative filters pass a throw and nothing else in the
## engine distinguishes it. The card says "melee weapon". A thrown one is not being used as a melee
## weapon.
##
## WHY NOT UnitAction.is_melee_weapon HERE TOO: weapon_types = [MELEE] on the .tres already asks that,
## through the same is_weapon_type call (buff_weapon_type.gd:43 binds context.gear, exactly as
## UnitAction.is_melee_weapon does at unit_action.gd:549-553). Repeating it would be a second gate
## nobody could delete without deleting the first.
extends BuffWeaponTypeOnHit

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const USAGE_KEY:StringName = &'magnetic_weight'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	# A throw is threat 0 (ruling 8). super() has already established context.action is an
	# ActionAttackWeapon, so `threat` is safe to read.
	if context.action.threat <= 0: return false
	return OncePerRound.is_unspent(core.get_owner_gear(context.map), USAGE_KEY)
