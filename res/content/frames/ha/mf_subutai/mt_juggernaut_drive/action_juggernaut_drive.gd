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
# ONE MORE CONSEQUENCE, MEASURED AT THE FRAME CLOSE: `ignore_difficult` on the .tres is DEAD.
# MovementType.ignores_difficult_terrain() is `ignore_difficult or teleport or flying or NOT
# VOLUNTARY` (movement_type.gd:107-108) and pathfinder.gd:99 is its only reader in the engine, so a
# non-voluntary move already ignores difficult terrain and the flag changes nothing. It is kept
# because ruling 8 says the card means it. Its two neighbours are NOT dead and must not be cleaned up
# with it: `free_climb` is read bare by the climb multiplier (pathfinder.gd:774) and
# `ignore_dangerous` bare by event_map_dangerous.check_specific_context (:19).
#
# WHY NO CONFIRM PROMPT (ruling 9). ActionReactionMovement.confirm_use_of_reaction asks only when
# requires_reaction_available(), which is consumes_rxn - false here. So the movement picker IS the
# prompt, and cancelling it is the card's "may". The archetype calls spend_actions AFTER the picker,
# so declining spends nothing.
#
# WHAT A SPEC MUST NOT ASSERT (measured, SP1 Task 3). For an ally that is NOT on a compass ray, the
# pathfinder's own ray to a candidate endpoint and the ally-ray that produced that endpoint disagree
# by one intermediate tile. The divergence is at the FIRST step, while resolving the THIRD endpoint:
# for the shallow off-axis ally the spec measures, the pathfinder leaves via (9, 8) where the
# ally-line used (9, 9), both en route to the same endpoint (11, 9). Both rays start
# adjacent to the origin, step 8-adjacently, and land on the SAME tile, so no endpoint is lost - but
# an off-axis Drive's travelled path must never be asserted tile by tile. Landing tiles are safe.

## A reaction that consumes no reaction point has a per-round hard limit of 99
## (action_reaction.gd:69), which would let the Subutai Drive on every extra activation it is
## granted. The card says 1/round. (Base Action returns 1 for a naturally free action, so this is
## restoring the ordinary rule rather than inventing one.)
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# super() checks this is OUR turn end (triggering_unit_is = UNIT) and that the movement type is
	# valid. event_turn_end.execute_preblock also fires a VIRTUAL end_turn core per owned deployable
	# (event_turn_end.gd:20-24), and that check is what rejects those - guarded by
	# test_a_deployable_the_subutai_owns_does_not_open_a_second_picker, which has to OWN the
	# deployable (SpecFactory builds them unowned) and has to DECLINE the first picker, or the engine's
	# own 1/round limit stops the second one and this line can be deleted with the suite green.
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# "It may only take this action if it is Immobilized" - the engine's own test (ruling 10): the
	# status, the smaller party in a grapple, or Shutdown.
	if not UnitCondition.is_immobilized(unit): return false
	# "towards an allied character within line of sight" - with nobody to drive towards there is no
	# line, so do not open a picker with nothing in it.
	#
	# AND NOT JUST "IS THERE AN ALLY". The candidates are the min(3, distance) line tiles towards that
	# ally, and the Subutai is size 2 - so an ally standing close enough leaves every candidate anchor
	# with a footprint that overlaps it, and the pathfinder rejects all of them. THIS IS THE COMMON
	# CASE, not the exotic one: the frame's own Guardian trait rewards allies for standing adjacent.
	# TargetActionUtil.ask_for_movement opens the picker for a player unit regardless of whether the
	# pathfinder found anything, so without this the Subutai gets a dead prompt at every turn end for
	# as long as it stays Immobilized. triggers_on_event is the only sync seam that can stop it:
	# generate_reaction_pathfinder is awaited by the archetype's activate immediately before
	# ask_for_movement, with nothing in between to bail from.
	return has_a_clear_candidate(unit, get_target_range(SpecificAction.create(unit, gear, self)))

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

## The candidate endpoints of the Drive: the union, over every visible allied character, of the
## Line-pattern tiles from the unit's tile towards that ally, capped at `range_tiles`.
##
## ONE DEFINITION, TWO CALLERS. generate_reaction_pathfinder hands these to the pathfinder, and
## triggers_on_event asks whether any of them could be stood on. Computing the union twice would let
## the gate and the picker drift apart, which is precisely the bug the gate exists to prevent.
func candidate_tiles(unit:Unit, range_tiles:int) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for ally:Unit in visible_allied_characters(unit):
		# The origin tile is excluded, because AoeCalculator.line builds from rings starting at
		# distance 1 (CommonActionUtil.get_all_occupied_tiles_in_line is the Full Speed Ahead helper).
		for tile:Vector2i in CommonActionUtil.get_all_occupied_tiles_in_line(
			unit, unit.tile(), ally.tile(), range_tiles
		):
			if not tiles.has(tile): tiles.append(tile)
	return tiles

## Could the Drive land ANYWHERE? A cheap, SYNCHRONOUS approximation of the pathfinder's endpoint
## validity, used only to decide whether opening the picker is worth the player's time.
##
## IT IS AN APPROXIMATION ON PURPOSE, AND IT IS BIASED TOWARDS OFFERING. It models exactly one of the
## pathfinder's rejection reasons - another unit overlapping the size-2 footprint
## (pathfinder.gd:132-134 for the anchor tile, :158-160 for the footprint) - and models NOTHING about
## terrain, elevation, dz, off-map footprints, dynamic-zone boundaries or CANT_MOVE_THROUGH. So the
## picker CAN still open empty, for a wall or a cliff or a map edge. That is accepted: the failure
## this guards is the routine one (an ally standing next to the Subutai), and a gate that is merely
## incomplete costs a prompt, while a gate that is WRONG silently deletes a legal Drive.
##
## Hence every uncertainty below resolves towards "offer it": a unit is treated as a blocker only
## when the pathfinder would certainly treat it as one. Attached units (a grapple katamari), exiled
## units, markers (excluded by get_all_units_at_tiles' default) and non-obstruction frames are all
## things the pathfinder steps over, so they are not blockers here either; and a stackup skips the
## whole narrowing, because pathfinder.gd:123-125 folds the entire stack into can_share_space_units
## and reproducing that is not worth the risk of getting it backwards.
func has_a_clear_candidate(unit:Unit, range_tiles:int) -> bool:
	var candidates := candidate_tiles(unit, range_tiles)
	if candidates.is_empty(): return false
	if UnitCondition.is_in_stackup(unit): return true # err towards offering; see the header
	var attached:Array[Unit] = Katamari.create(unit).all_units
	for candidate:Vector2i in candidates:
		if footprint_is_clear(unit, candidate, attached): return true
	return false

## Does the unit's footprint anchored at `candidate` overlap anything the pathfinder would refuse to
## share a tile with? Mirrors the occupation filter at pathfinder.gd:109-116 and the CAN_SHARE_SPACE
## pass at :117-122, minus the cases the header lists as deliberately unmodelled.
func footprint_is_clear(unit:Unit, candidate:Vector2i, attached:Array[Unit]) -> bool:
	var buff_context := Context.create({unit = unit, target_tiles = [candidate], resource = movement_type})
	for other:Unit in unit.map.get_all_units_at_tiles(unit.occupied_tiles(candidate)):
		if other == unit or attached.has(other): continue
		if other.has_status(Lancer.STATUS.EXILED): continue
		if not other.core.frame.is_obstruction: continue
		if UnitCondition.has_buff_to(
			unit, Buff.TO.CAN_SHARE_SPACE, Context.clone(buff_context, {target_unit = other})
		): continue
		if UnitCondition.has_buff_to(
			other, Buff.TO.CAN_SHARE_SPACE, Context.clone(buff_context, {target_unit = unit})
		): continue
		return false
	return true

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
##    and generate_for_given_tiles filters movable_tiles back down to given_tiles (pathfinder.gd:314).
func generate_reaction_pathfinder(moving_unit:Unit, specific:SpecificAction) -> Pathfinder:
	# create_merged is a COPY, so the authored resource is never mutated - a mutation would persist
	# for the whole scene and make every later Drive flying.
	var use_movement_type:MovementType = movement_type
	if moving_unit.state.is_flying():
		use_movement_type = MovementType.create_merged(movement_type, MovementType.new())
		use_movement_type.flying = true

	return await Pathfinder.generate_for_given_tiles(
		moving_unit,
		candidate_tiles(moving_unit, get_target_range(specific)),
		use_movement_type,
		true, # ruling 17
		get_target_range(specific),
	)
