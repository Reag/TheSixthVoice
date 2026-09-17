## REND: supplies a crit-stage OnHitEffect to the Maiden's Blush's MELEE attacks, once a round.
##
## Knock 'em down's shape with the weapon type changed (design §1.1, ruling 14). The two traits are
## the same mechanism and are deliberately written the same way, so a reader who knows one knows both.
##
## The round limit is hand-rolled because the engine never enforces one for a buff-triggered effect -
## ReactionBus consults per-round limits only for ActionReactions (reaction_bus.gd:116-124). Crack
## Shot III's buff_watch_this.gd counts the same way; this gates on == 0 instead of watch_this's > 0
## because the two read as opposite conditions for the same counter.
##
## MELEE IS FILTERED DECLARATIVELY, on the .tres (weapon_types = [2], read by
## BuffWeaponType.check_if_passive_applies through the super below), and BASIC gear is excluded by
## BuffWeaponType.allow_basic's own default of false - which is ruling 12 in a line nobody has to
## write: Ram, Grapple and the Improvised Attack are basic mw_ Kits with weapon_type = MELEE, and none
## of them triggers Rend.
extends BuffWeaponTypeOnHit

const USAGE_KEY:StringName = &'rend'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0
