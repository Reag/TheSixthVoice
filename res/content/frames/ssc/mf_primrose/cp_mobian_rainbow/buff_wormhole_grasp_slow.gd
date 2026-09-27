## WORMHOLE GRASP, the Slowed: "1/round, when you damage a character with an Overwatch, they must
## succeed a Hull save or be Slowed until the end of their next turn."
##
## UNFILTERED, because the card is: no weapon_sizes, no weapon_types, and allow_basic TRUE on the
## .tres. BuffWeaponType refuses basic gear unless that flag is set (buff_weapon_type.gd:52), and an
## overwatch with a basic weapon is still an Overwatch. The IS_OVERWATCH gate lives on the
## OnHitEffect rather than here, because `should_abort` is where the activation's flags are in scope -
## the Tortuga's onhit_hyper_reflex_mode_immobilize.gd is the vanilla shape.
##
## THE ROUND LIMIT is the shared once-per-round helper (gear/shared/once_per_round, close-out Pass D).
## This gates on the CORE Kit's usage, and onhit_wormhole_grasp_slow.gd spends it - one key, two
## files, both naming &'wormhole_slow'.
##
## get_owner_gear IS THE CORE KIT, not the weapon: UnitCondition.apply_buffs stamps BuffCore.from_gear
## with the gear that applied the buff (unit_condition.gd:705-709), and the protocol passes
## context.gear - cp_mobian_rainbow. So the usage lives on the core system and follows it, which is
## right: the 1/round belongs to Wormhole Grasp and not to whichever weapon happened to fire.
extends BuffWeaponTypeOnHit

const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const USAGE_KEY:StringName = &'wormhole_slow'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return OncePerRound.is_unspent(core.get_owner_gear(context.map), USAGE_KEY)
