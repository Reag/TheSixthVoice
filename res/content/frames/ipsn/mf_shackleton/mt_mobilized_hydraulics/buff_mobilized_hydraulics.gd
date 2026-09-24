## MOBILIZED HYDRAULICS (Shackleton), the offer: supplies onhit_mobilized_hydraulics to the
## Shackleton's MELEE attacks while the trait's 1/round is unspent. Design ruling 7.
##
## MELEE IS DECLARATIVE on the .tres: weapon_types = [MELEE] with allow_basic = true, so the Ram and
## the Improvised Attack (both weapon_type MELEE, size NONE) count - ruling 6, the author's call.
##
## The round limit is hand-rolled because the engine enforces none for a buff-triggered effect
## (reaction_bus.gd:126-139); buff_knock_em_down.gd is the shape. The gate is read twice per attack
## and the difference matters: event_unit_attack_declared.gd:42 collects on-hit buffs ONCE before
## any target is rolled (that list is what on_resolution later runs over, so the arming is always
## cleared), and event_unit_attack.gd:48 collects them again per target (that list is what on_attack
## runs over, so a second target in the same attack is not re-offered once the round is spent).
extends BuffWeaponTypeOnHit

const TRAIT_ID:StringName = &'mt_mobilized_hydraulics'
const USAGE_KEY:StringName = &'mobilized_hydraulics'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0
