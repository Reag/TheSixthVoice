## MOBILIZED HYDRAULICS (Shackleton), the offer: supplies onhit_mobilized_hydraulics to the
## Shackleton's MELEE attacks while the trait's 1/round is unspent. Design ruling 7.
##
## MELEE IS DECLARATIVE on the .tres: weapon_types = [MELEE] with allow_basic = true, so the Ram and
## the Improvised Attack (both weapon_type MELEE, size NONE) count - ruling 6, the author's call.
##
## The round limit is hand-rolled because the engine enforces none for a buff-triggered effect
## (reaction_bus.gd:126-139); buff_knock_em_down.gd is the shape. event_unit_attack.gd:48 collects the
## on-hit buffs again per target, and that list is what on_attack runs over, so a second target in the
## same attack is not re-offered once the round is spent. (The arming itself is a stamp on the
## attack's DeclaredAttackSummary since Pass F task 10, so nothing needs clearing at on_resolution.)
extends BuffWeaponTypeOnHit

const TRAIT_ID:StringName = &'mt_mobilized_hydraulics'
const USAGE_KEY:StringName = &'mobilized_hydraulics'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0
