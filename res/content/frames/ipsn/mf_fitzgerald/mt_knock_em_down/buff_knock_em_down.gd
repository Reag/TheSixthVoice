## Knock 'em down: supplies a crit-stage OnHitEffect to the Fitzgerald's Cannon attacks, once a round.
##
## The round limit is hand-rolled because the engine never enforces one for a buff-triggered effect
## (reaction_bus.gd:126-139) - only for ActionReactions. Crack Shot III's buff_watch_this.gd counts
## the same way; this mirrors it, gating on == 0 instead of watch_this's > 0 since the two read as
## opposite conditions for the same counter.
##
## CANNON is filtered declaratively via weapon_types = [1] on the .tres (BuffWeaponType.
## check_if_passive_applies, called through super below) - unlike Hole Puncher, this trait is
## Cannon-only, not Cannon-or-Line, so no extra predicate is needed here.
extends BuffWeaponTypeOnHit

const USAGE_KEY:StringName = &'knock_em_down'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0
