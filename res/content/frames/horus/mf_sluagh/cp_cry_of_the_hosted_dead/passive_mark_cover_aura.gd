## THE MARK'S DOME: soft cover for the Sluagh and for whoever is standing beside it.
##
##   "A dome of bleak darkness envelops you, causing the following effects until the end of the
##    scene: You and adjacent allied characters gain soft cover."
##
## AN AURA, BECAUSE OF WHERE THE ENGINE MEASURES COVER. CoverCalculator.determine_cover reads the
## Buff.TO.COVER buffs of the DEFENDER and of the ATTACKER and of nobody else
## (cover_calculator.gd:56-62), so a cover buff on the Sluagh cannot shelter the unit next to it. The
## buff must be ON the sheltered unit, and a PassiveAura is the engine's way to put it there and take
## it away again. Ruling 14.
##
## EXTENDS PassiveAura DIRECTLY, AND MUST. Kit.is_passive_of_type matches the script or its DIRECT
## base and its own comment says "only goes one layer deep" (kit.gd:161-165); LoadoutCore indexes
## aura gear with kit.has_passive_type(PassiveAura) (loadout_core.gd:298-301). A subclass of a
## subclass would never be indexed, the aura would never run, and every resource assertion about it
## would still be green.
##
## is_within_range IS THE ONE FUNCTION A SUBCLASS OVERRIDES (design section 7). The stock body tests
## UnitRelation.distance_between(aura_unit, moving_unit) > aura_range (passive_aura.gd:85), which is
## a RADIUS - and ruling 6 has this card TAKING House Guard's widening, which reaches
## adjacent_characters and nothing that measures a radius (memory third-party-adjacency-widening).
## The talents mod's own Greater Guardian is the shape being copied: it subclasses PassiveAura and
## overrides exactly this function.
##
## MEASURED, SP1 Task 7: deleting this override reddens NOTHING in spec/test_mark_of_the_dead.gd,
## because a radius of 1 and is_adjacent agree in vanilla. spec/test_compat.gd (Task 9) is the only
## thing that can tell the two apart, with the talents mod resident. Do not read the green as
## evidence that the override is inert - read it as evidence of where the seam lives.
##
## THE ARGUMENT ORDER IS THE RULING. is_adjacent(a, b) is adjacent_characters(a).has(b)
## (unit_relation.gd:7-8), so this reads the AURA UNIT'S buffs - the Sluagh's. House Guard on the
## Sluagh therefore widens the dome, and House Guard on the ally does not. spec/test_compat.gd pins
## both directions in Task 9.
##
## aura_range IS INERT HERE and is left at its export default of 1. Nothing in this class reads it;
## it is written nowhere in the .tres for the same reason. If a later session removes this override,
## the default silently becomes the rule again - which is a radius, and a different card.
##
## THE SELF CASE IS EXPLICIT rather than left to is_adjacent. UnitRelation.adjacent_characters is
## get_characters_within(unit, 1, false) (unit_relation.gd:10-11), and whether that list contains the
## unit itself is not a property this card should depend on either way: "You and adjacent allied
## characters" names the holder separately, so this does too. (It does not, today:
## get_units_within's first clause is other_unit != unit, unit_relation.gd:58.)
extends PassiveAura

func is_within_range(moving_unit:Unit, aura_unit:Unit) -> bool:
	if not Unit.is_valid(moving_unit) or not Unit.is_valid(aura_unit): return false
	if moving_unit == aura_unit: return true
	return UnitRelation.is_adjacent(aura_unit, moving_unit)

## "allied CHARACTERS", and applies_only_to_characters does not deliver it on its own: that flag is
## `moving_unit.is_character()` (passive_aura.gd:73), and Unit.is_character() returns TRUE for a drone
## ("active mech/pilot/drone", unit.gd:116). is_actor() is is_character() and not is_drone (:117), so
## AN ADJACENT ALLIED DRONE IS NOT SHELTERED and this line is the only thing that refuses it - delete
## it and `test_an_adjacent_allied_drone_is_not_sheltered` reddens. A REAL NARROWING, not a
## restatement.
##
## THIS IS THE MOD'S SETTLED READING OF THE WORD, not this frame's local taste: ruling 194 (the
## Vauban's Gravity Well shelters allied MECHS, "drones and deployables are not sheltered" - the same
## mechanism, a range-1 aura, one frame over), rulings 64 and 70 (a drone's shot counts as its
## owner's) and ruling 269 (the Stealing) all spell it the same way. The canonical paragraph is in
## mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd's header.
func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super(moving_unit, aura_unit, aura_gear): return false
	return moving_unit.is_actor()
