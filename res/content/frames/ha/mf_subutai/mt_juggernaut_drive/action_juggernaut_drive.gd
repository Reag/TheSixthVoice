extends ActionReactionMovement

# JUGGERNAUT DRIVE (Subutai trait)
#
#   "1/round, as a free action at the end of its turn, the Subutai may move up to 3 spaces ignoring
#    terrain and Immobilized. It must move in a straight line directly towards an allied character
#    within line of sight. It may only take this action if it is Immobilized."
#
# The Raleigh's Full Metal Jacket trigger shape (end_turn PRE, consumes_rxn false,
# counts_as_free_action true) on the movement-reaction archetype. The archetype does the whole
# activation - confirm, pathfinder, picker, spend, move - so this class only answers three
# questions: how often, when, and over which tiles.
#
# WHY A NON-VOLUNTARY MOVEMENT TYPE (ruling 7). A voluntary move is refused while Immobilized at
# three places, all outside a mod's reach: pathfinder.gd:333 and event_unit_move.gd:451 (both
# class_name scripts) and action_reaction_movement.gd:46-48. Setting voluntary = false on the
# resource bypasses all three by taking the engine's knockback/pull path. The accepted
# consequences, all recorded in rulings.md: no Overwatch and no engagement against the Drive, a
# Slowed or Prone Subutai may still Drive, a Drive off a ledge takes fall damage, and a grapple is
# broken as a knockback would break it.
#
# WHY NO CONFIRM PROMPT (ruling 9). ActionReactionMovement.confirm_use_of_reaction asks only when
# requires_reaction_available(), which is consumes_rxn - false here. So the movement picker IS the
# prompt, and cancelling it is the card's "may". The archetype calls spend_actions AFTER the picker,
# so declining spends nothing.
#
# WHAT A SPEC MUST NOT ASSERT (measured, SP1 Task 3). For an ally that is NOT on a compass ray, the
# pathfinder's own ray to a candidate endpoint and the ally-ray that produced that endpoint disagree
# by one intermediate tile at the third step. Both start adjacent to the origin, step 8-adjacently,
# and land on the SAME tile, so no endpoint is lost - but an off-axis Drive's travelled path must
# never be asserted tile by tile. Landing tiles are safe.

## A reaction that consumes no reaction point has a per-round hard limit of 99
## (action_reaction.gd:69), which would let the Subutai Drive on every extra activation it is
## granted. The card says 1/round. (Base Action returns 1 for a naturally free action, so this is
## restoring the ordinary rule rather than inventing one.)
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# super() checks this is OUR turn end (triggering_unit_is = UNIT) and that the movement type is
	# valid. event_turn_end.execute_preblock also fires a VIRTUAL end_turn core per owned deployable,
	# and that check is what rejects those.
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# "It may only take this action if it is Immobilized" - the engine's own test (ruling 10): the
	# status, the smaller party in a grapple, or Shutdown.
	if not UnitCondition.is_immobilized(unit): return false
	# "towards an allied character within line of sight" - with nobody to drive towards there is no
	# line, so do not open a picker with nothing in it.
	return not visible_allied_characters(unit).is_empty()

## Allied CHARACTERS the Subutai can see, excluding itself.
##
## get_all_characters(), not get_all_units(): the card says "allied character", so a friendly drone,
## turret or other deployable does not anchor a line. Excluding self matters because
## UnitRelation.are_allies is true of a unit and itself, and a line towards our own tile is no line
## at all.
func visible_allied_characters(unit:Unit) -> Array[Unit]:
	var allies:Array[Unit] = []
	for other:Unit in unit.map.get_all_characters():
		if not Unit.is_valid(other) or other == unit: continue
		if not UnitRelation.are_allies(unit, other): continue
		if not UnitRelation.can_see(unit, other): continue
		allies.append(other)
	return allies

## ONE picker over every line at once (ruling 9), rather than "pick an ally, then pick a tile".
##
## The candidate endpoints are the union, over every visible allied character, of the Line-pattern
## tiles from the Subutai towards that ally, capped at get_target_range - the card's "up to 3
## spaces", authored as movement_range_fixed on the .tres - and at the distance
## (CommonActionUtil.get_all_occupied_tiles_in_line, the Full Speed Ahead helper; the origin tile is
## excluded, because AoeCalculator.line builds from rings starting at distance 1).
##
## TWO THINGS THIS OVERRIDE DOES THAT THE BASE DOES NOT, both rulings from the SP1 review:
##
##  - RULING 18: it merges the unit's LIVE flying state into the authored movement type. The .tres
##    cannot carry runtime state, and merge_with_standard_move_type is false, so without this a
##    Flying Subutai would Drive as a ground unit - and MovementType.takes_fall_damage() is true for
##    a non-voluntary, non-flying move, so it would fall out of the sky at its own turn end. Vanilla's
##    own MovementType.create_for_involuntary sets flying from the unit for exactly this reason.
##
##  - RULING 17: allow_alternate_paths_to_those_tiles is TRUE. Pathfinder.calculate_step_path_for_line
##    re-derives the path to each candidate with AoeCalculator.line(origin, ENDPOINT) - a different
##    aim angle from line(origin, ALLY) - and then requires every step to be CONNECTED in an astar
##    graph built only from the tiles we hand it. One tile of rounding disagreement and the path
##    comes back empty and that endpoint silently vanishes from the picker. The flag puts the
##    intervening tiles in the graph. It gains no endpoint: straight_line still forces the line path,
##    and generate_for_given_tiles filters movable_tiles back down to given_tiles (pathfinder.gd:313).
func generate_reaction_pathfinder(moving_unit:Unit, specific:SpecificAction) -> Pathfinder:
	# create_merged is a COPY, so the authored resource is never mutated - a mutation would persist
	# for the whole scene and make every later Drive flying.
	var use_movement_type:MovementType = movement_type
	if moving_unit.state.is_flying():
		use_movement_type = MovementType.create_merged(movement_type, MovementType.new())
		use_movement_type.flying = true

	var tiles:Array[Vector2i] = []
	for ally:Unit in visible_allied_characters(moving_unit):
		for tile:Vector2i in CommonActionUtil.get_all_occupied_tiles_in_line(
			moving_unit, moving_unit.tile(), ally.tile(), get_target_range(specific)
		):
			if not tiles.has(tile): tiles.append(tile)

	return await Pathfinder.generate_for_given_tiles(
		moving_unit,
		tiles,
		use_movement_type,
		true, # ruling 17
		get_target_range(specific),
	)
