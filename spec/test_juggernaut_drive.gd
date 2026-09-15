# Juggernaut Drive (Subutai trait, SP1 Task 3 and Task 4).
#
#   "1/round, as a free action at the end of its turn, the Subutai may move up to 3 spaces ignoring
#    terrain and Immobilized. It must move in a straight line directly towards an allied character
#    within line of sight. It may only take this action if it is Immobilized."
#
# SECTION 1 (Task 3) is the LINE GEOMETRY PIN. The trait offers, as endpoints, the tiles of
# AoeCalculator.line(subutai, ALLY) capped at 3. The pathfinder then paths to each of those with
# AoeCalculator.line(subutai, ENDPOINT) - a different aim angle - and requires every step to be
# connected in its astar graph. Ruling 17 widens the graph so a disagreement can no longer silently
# drop an endpoint; these tests record whether the two derivations agree at all, so a future modkit
# that changes AoeCalculator.line shows up here rather than as "the Drive offers fewer tiles".
#
# MEASURED 2026-09-15, SP1 Task 3: they agree on all eight compass rays and DISAGREE for both
# off-axis allies, at the third endpoint only, by exactly one intermediate tile. AoeCalculator.line
# picks, per ring, the one tile whose bearing from the origin is angularly closest to the aim
# vector; aiming at a distance-3 endpoint is a different bearing from aiming at the distance-6/7
# ally that produced it, so an intermediate ring can resolve to a different tile. Both rays still
# START at the origin, step 8-adjacently, and END on the same endpoint - so no candidate is lost.
# Task 4 must therefore NOT assert the Drive's travelled path tile-by-tile for an off-axis ally:
# an off-axis Drive may travel a one-tile-different ray to the same destination.
#
# SECTION 2 (Task 4) is the trait itself.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_juggernaut_drive.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const TRAIT_ID := &'mt_juggernaut_drive'
const ACTION_ID := &'action_juggernaut_drive'
const RANGE := 3

const START := Vector2i(8, 8)

var game:Gamemaster
var subutai:Unit

## Reads what the picker offered. Added ALONGSIDE the responder, which still answers; this only
## listens. Section 1 raises no prompts, so it simply sees nothing there.
var watcher:PromptWatcher

## The stock ChoiceBusResponder that SpecFactory.setup_gamemaster just created. It is reachable only
## through SpecFactory.current_responder (spec_factory.gd:11, assigned at :31 and :51) - the suite's
## own idiom, cf. test_heaer.gd:272 - and it is a FRESH instance per before_each, so nothing set on
## it in one test leaks into the next.
var responder:SpecFactory.ChoiceBusResponder

func before_each() -> void:
	game = SubutaiFixture.create_game(self, Vector2i(24, 24))
	subutai = SubutaiFixture.create_subutai(game, START)
	responder = SpecFactory.current_responder
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- section 1: the line geometry pin

## The candidate endpoints the trait will offer for an ally at `ally_tile`.
func candidates_towards(ally_tile:Vector2i) -> Array[Vector2i]:
	return CommonActionUtil.get_all_occupied_tiles_in_line(subutai, subutai.tile(), ally_tile, RANGE)

func test_the_helper_never_offers_the_units_own_tile():
	# AoeCalculator.line builds from Tile.get_rings(origin, length), which starts at distance 1. If
	# the origin ever entered the candidate set, the picker would offer "stay put" as a Drive.
	for direction:Vector2i in Tile.DIRECTIONS:
		var tiles := candidates_towards(START + direction * 6)
		assert_false(tiles.has(START), 'towards %s: the origin is not a candidate.' % direction)

func test_the_helper_does_not_widen_the_line_for_a_size_two_unit():
	# RangePattern.get_aoe_tiles ignores origin_unit_size for a LINE (it only reaches
	# AoeCalculator.line(start, target, value)), so a size-2 unit gets single anchor tiles and not a
	# 2-wide swath. If that ever changed, the picker would offer off-line tiles and the trait would
	# stop being "in a straight line".
	assert_eq(subutai.state.occupying_size, 2, 'The Subutai is size 2.')
	for direction:Vector2i in Tile.DIRECTIONS:
		var tiles := candidates_towards(START + direction * 6)
		assert_eq(tiles.size(), RANGE, 'towards %s: exactly %d candidates.' % [direction, RANGE])

func test_every_candidate_lies_on_the_ray_towards_the_ally():
	for direction:Vector2i in Tile.DIRECTIONS:
		var ally_tile:Vector2i = START + direction * 6
		var full_line := CommonActionUtil.get_all_occupied_tiles_in_line(subutai, START, ally_tile, 6)
		for tile:Vector2i in candidates_towards(ally_tile):
			assert_true(full_line.has(tile),
				'towards %s: %s is on the full line to the ally.' % [direction, tile])

## Every ally offset the measurement covers: the eight compass rays at range 6, plus two off-axis.
func all_ally_offsets() -> Array[Vector2i]:
	var ally_offsets:Array[Vector2i] = []
	for direction:Vector2i in Tile.DIRECTIONS: ally_offsets.append(direction * 6)
	ally_offsets.append(Vector2i(7, 3))   # shallow off-axis
	ally_offsets.append(Vector2i(-5, 4))  # steep off-axis, negative x
	return ally_offsets

func test_the_two_line_derivations_agree_on_every_compass_ray():
	# THE MEASUREMENT, in the half where the two derivations are identical. The pathfinder walks
	# AoeCalculator.line(origin, ENDPOINT); the trait offers a prefix of
	# AoeCalculator.line(origin, ALLY). On an axis or a true diagonal both aim vectors have the same
	# bearing, so the two agree tile for tile. If this ever reddens, the line algorithm itself moved.
	for direction:Vector2i in Tile.DIRECTIONS:
		var towards_ally := candidates_towards(START + direction * 6)
		for i:int in towards_ally.size():
			var endpoint:Vector2i = towards_ally[i]
			var direct := AoeCalculator.line(START, endpoint, i + 1, game.map.shape)
			assert_eq(direct, towards_ally.slice(0, i + 1),
				'towards %s, endpoint %s: the two line derivations agree.' % [direction, endpoint])

func test_the_pathfinders_own_line_reaches_every_candidate_it_is_offered():
	# What actually has to hold for ruling 17 to keep every endpoint on the picker: whatever ray the
	# pathfinder derives, it must be a contiguous 8-adjacent walk from the origin that ENDS on the
	# candidate, of exactly the candidate's distance. Off-axis it may pass through a different
	# intermediate tile than the ally-line did (see the header); it never fails to arrive.
	for offset:Vector2i in all_ally_offsets():
		var towards_ally := candidates_towards(START + offset)
		for i:int in towards_ally.size():
			var endpoint:Vector2i = towards_ally[i]
			var direct := AoeCalculator.line(START, endpoint, i + 1, game.map.shape)
			assert_eq(direct.size(), i + 1,
				'ally at %s, endpoint %s: the ray is %d tiles long.' % [offset, endpoint, i + 1])
			if direct.is_empty(): continue
			assert_eq(direct.back(), endpoint,
				'ally at %s: the ray ends on the candidate %s.' % [offset, endpoint])
			var previous:Vector2i = START
			for tile:Vector2i in direct:
				assert_eq(Tile.distance(previous, tile), 1,
					'ally at %s, endpoint %s: %s is one step from %s.' % [offset, endpoint, tile, previous])
				previous = tile

func test_an_off_axis_drive_may_travel_a_one_tile_different_ray_to_the_same_tile():
	# The disagreement itself, pinned with the exact tiles measured on 1.4.3 (SP1 Task 3). This is a
	# RECORD, not a requirement: if a future modkit reddens it, the line algorithm changed and Task
	# 4's Drive should be re-measured - it is not a bug in this mod.
	var shallow := candidates_towards(START + Vector2i(7, 3))
	assert_eq(shallow, [Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9)] as Array[Vector2i],
		'The shallow off-axis ally-line is unchanged.')
	assert_eq(AoeCalculator.line(START, Vector2i(11, 9), 3, game.map.shape),
		[Vector2i(9, 8), Vector2i(10, 9), Vector2i(11, 9)] as Array[Vector2i],
		'The pathfinder reaches (11, 9) via (9, 8), where the ally-line used (9, 9).')

	var steep := candidates_towards(START + Vector2i(-5, 4))
	assert_eq(steep, [Vector2i(7, 9), Vector2i(6, 10), Vector2i(5, 10)] as Array[Vector2i],
		'The steep off-axis ally-line is unchanged.')
	assert_eq(AoeCalculator.line(START, Vector2i(5, 10), 3, game.map.shape),
		[Vector2i(7, 9), Vector2i(6, 9), Vector2i(5, 10)] as Array[Vector2i],
		'The pathfinder reaches (5, 10) via (6, 9), where the ally-line used (6, 10).')

# ---------------------------------------------------------------- section 2: the trait
#
# The Drive is an end_turn PRE free-action movement reaction. Everything below drives it through the
# real engine path - event_turn_end.execute_preblock awaits END_TURN PRE reactions BEFORE
# handle_ending_unit zeroes speed and flips is_taking_turn - and reads what the player was offered
# off PromptWatcher rather than off the bus signals.
#
# WHAT THIS SECTION MUST NOT ASSERT: an off-axis Drive's travelled path, tile by tile. Section 1
# above measured that the pathfinder's own ray to an endpoint and the ally-ray that produced that
# endpoint disagree by one intermediate tile off-axis. Both end on the same tile, so LANDING tiles
# are safe to assert; intermediate tiles are not.

## Where the picker actually offers tiles: params.tiles is the TEST_MODE aiming list and is empty
## for a reaction, so pathfinder.movable_tiles is the only honest source (prompt_watcher.gd says so
## in its own comment).
func offered_by(prompt:Dictionary) -> Array:
	return prompt.pathfinder.movable_tiles

## Immobilized until the start of the unit's next turn, through the same UnitCondition.apply_status
## + SpecFactory.dummy_event() pair test_reinforced_chassis.gd uses. (There is no apply_status_alt.)
func immobilize(unit:Unit) -> void:
	UnitCondition.apply_status(
		SpecFactory.dummy_event(), unit, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.START_OF_TURN)

func slow(unit:Unit) -> void:
	UnitCondition.apply_status(
		SpecFactory.dummy_event(), unit, Lancer.STATUS.SLOWED, Lancer.UNTIL.START_OF_TURN)

## The OTHER limb of UnitCondition.is_immobilized (unit_condition.gd:413-418): GRAPPLED while not the
## larger party. is_larger_in_grapple is a plain state flag, false by default
## (unit_battle_state.gd:56) and set by Katamari.create - so the status alone is the whole condition,
## and it is set explicitly here rather than relied on, since the assertion below is about it.
func grapple_as_the_smaller(unit:Unit) -> void:
	UnitCondition.apply_status(
		SpecFactory.dummy_event(), unit, Lancer.STATUS.GRAPPLED, Lancer.UNTIL.START_OF_TURN)
	unit.state.is_larger_in_grapple = false

## A full-height forbidden-interior column spanning the map north to south at `x`: blocks sight at
## every layer and gives no cover of its own. Lifted from test_hole_puncher.gd, which is all about
## this - including the calculate_los_blockers() re-push vanilla's test_map_sightlines.gd does. The
## forbidden_interiors_enabled flag the column depends on is set by FitzgeraldFixture.create_game().
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', wall)
	game.map.calculate_los_blockers()

## End the Subutai's turn and return the move_tile prompts that turn end opened.
func end_turn() -> Array[Dictionary]:
	var before:int = watcher.kinds(PromptWatcher.KIND.move_tile).size()
	await game.execute_event(&'event_turn_end', {unit = subutai})
	return watcher.kinds(PromptWatcher.KIND.move_tile).slice(before)

func drive_gear() -> GearCore:
	return subutai.get_gear(TRAIT_ID)

func drive_action() -> Action:
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	return null if not Kit.is_valid(kit) else kit.get_action(ACTION_ID)

func uses_this_round() -> int:
	var gear:GearCore = drive_gear()
	if gear == null: return -1
	return gear.get_uses_this_round(gear.kit.get_action(ACTION_ID))

func test_the_trait_and_its_action_exist():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_juggernaut_drive is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_not_null(kit.get_action(ACTION_ID), 'It carries action_juggernaut_drive.')

func test_the_subutai_carries_the_trait():
	assert_not_null(drive_gear(), 'The frame grants mt_juggernaut_drive.')

func test_the_action_is_a_free_end_of_turn_reaction_that_spends_no_point():
	var action := drive_action()
	assert_not_null(action, 'The action exists.')
	if action == null: return
	assert_true(action is ActionReactionMovement, 'It is a movement reaction.')
	assert_has(action.triggers_on, &'end_turn', 'It triggers on end_turn.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE, 'PRE, before the turn actually ends.')
	assert_false(action.consumes_rxn, 'It spends no reaction point.')
	assert_true(action.counts_as_free_action, 'It is a free action.')
	assert_eq(action.movement_range_fixed, RANGE, 'Up to 3 spaces.')
	assert_false(action.is_mandatory, 'The card says "may".')

func test_the_movement_type_carries_every_clause_of_the_card():
	# Asserted on the resource rather than inferred from where the unit landed: a move that happens
	# to end 3 east satisfies almost any movement type.
	var action := drive_action()
	if action == null:
		assert_not_null(action, 'The action exists.')
		return
	var move_type:MovementType = action.movement_type
	assert_not_null(move_type, 'The action carries a movement type.')
	if move_type == null: return
	assert_false(move_type.voluntary, 'Non-voluntary: the only path past Immobilized (ruling 7).')
	assert_true(move_type.straight_line, 'A straight line.')
	assert_true(move_type.ignore_dangerous, 'Ignores dangerous terrain in transit (ruling 8).')
	assert_true(move_type.ignore_difficult, 'Ignores difficult terrain (ruling 8).')
	assert_true(move_type.free_climb, 'Free climbs (ruling 8).')
	assert_false(move_type.flying, 'NOT flying: the resource is a ground move (ruling 8).')
	assert_false(move_type.can_break_interiors, 'It does not break walls (ruling 8).')
	assert_false(move_type.can_move_through_enemies, 'Units still stop it (ruling 8).')
	assert_false(move_type.spend_move, 'It does not spend the turn movement.')

func test_the_per_round_hard_limit_is_one():
	# ActionReaction returns 99 for a reaction that consumes no point; the card says 1/round.
	var action := drive_action()
	if action == null:
		assert_not_null(action, 'The action exists.')
		return
	var specific := SpecificAction.create(subutai, drive_gear(), action)
	assert_eq(action.get_per_round_hard_limit(specific), 1, '1/round.')

func test_an_immobilized_subutai_with_a_visible_ally_is_offered_exactly_the_three_tiles_towards_it():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	# EXPECTED IS COMPUTED BEFORE THE TURN ENDS. candidates_towards() reads subutai.tile(), and the
	# stock responder answers the picker it is about to open - with no chosen_move_tile set it takes
	# pathfinder.reachable_tiles[0] - so by the time end_turn() returns the Subutai has MOVED and the
	# same call would describe the lines from wherever it landed. (Measured: it reported the line
	# from the new origin and the test failed on a tile three further east.)
	var expected := candidates_towards(START + Vector2i(6, 0))
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'One movement picker was opened.')
	if prompts.is_empty(): return
	var offered:Array = offered_by(prompts[0])
	assert_eq(offered.size(), expected.size(), 'Exactly the line tiles are offered.')
	for tile:Vector2i in expected:
		assert_true(offered.has(tile), '%s is offered.' % tile)

func test_an_off_axis_ally_is_still_offered_all_three_tiles():
	# RULING 17'S ONLY GUARD. Every other behavioural test here aims at a compass ray, and section 1
	# measured the two line derivations to agree on all eight of those - so flipping
	# allow_alternate_paths_to_those_tiles back to false leaves every one of them green and proves
	# only the map. This is the shallow off-axis ally section 1 measured as DISAGREEING: the
	# pathfinder reaches the third candidate (11, 9) via (9, 8), which is NOT one of the candidate
	# tiles. With a narrow graph are_points_connected fails on that step,
	# calculate_step_path_for_line returns an empty path, and the endpoint never enters
	# valid_destinations (pathfinder.gd:503-504). Ruling 17 puts the intervening tile in the graph
	# and all three survive.
	#
	# LANDING TILES ONLY. The section header says why the travelled path must not be asserted here.
	SubutaiFixture.create_ally(game, START + Vector2i(7, 3))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	# Computed before the turn ends, for the reason the compass-ray test above records: the responder
	# answers the picker, so afterwards the Subutai is no longer standing at START.
	var expected := candidates_towards(START + Vector2i(7, 3))
	assert_eq(expected.size(), RANGE, 'The off-axis ally-line still has three candidates.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'One movement picker was opened.')
	if prompts.is_empty(): return
	var offered:Array = offered_by(prompts[0])
	assert_eq(offered.size(), expected.size(),
		'Every off-axis candidate survives the pathfinder, including the one it reaches off-line.')
	for tile:Vector2i in expected:
		assert_true(offered.has(tile), '%s is offered.' % tile)

func test_the_picker_can_be_cancelled_because_the_card_says_may():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'One movement picker was opened.')
	if prompts.is_empty(): return
	assert_true(prompts[0].can_cancel, 'The picker can be voluntarily cancelled.')

func test_answering_the_picker_moves_the_subutai_and_spends_the_round():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	responder.chosen_move_tile = START + Vector2i(3, 0)
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	await end_turn()
	assert_eq(subutai.tile(), START + Vector2i(3, 0), 'It drove the full 3 towards the ally.')
	assert_eq(uses_this_round(), 1, 'The Drive is spent for the round.')

func test_declining_the_picker_leaves_it_in_place_and_spends_nothing():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	responder.abort_all = true
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	var prompts := await end_turn()
	# Without this the test would pass just as well if the reaction stopped triggering at all: the
	# unit is in the same place and nothing was spent either way. abort_all still OPENS the prompt
	# and reports it to the watcher before cancelling it, so this is safe to assert here.
	assert_eq(prompts.size(), 1, 'The picker did open - there was something to decline.')
	assert_eq(subutai.tile(), START, 'It stayed put.')
	assert_eq(uses_this_round(), 0, 'Declining costs nothing.')

func test_the_reaction_point_is_untouched():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	responder.chosen_move_tile = START + Vector2i(3, 0)
	await SubutaiFixture.open_turn(game, subutai)
	var points_before:int = subutai.core.current.reactions
	immobilize(subutai)
	await end_turn()
	assert_eq(subutai.core.current.reactions, points_before, 'A free action spends no reaction.')
	assert_eq(subutai.tile(), START + Vector2i(3, 0), 'It did Drive, so there was something to spend.')

func test_a_subutai_that_is_not_immobilized_is_not_offered_the_drive():
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: the card gates on Immobilized.')
	assert_eq(subutai.tile(), START, 'It did not move.')

func test_an_immobilized_subutai_with_no_allied_character_is_not_offered_the_drive():
	SubutaiFixture.create_dummy(game, START + Vector2i(6, 0), 10) # an ENEMY, not an ally
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: there is nobody friendly to drive towards.')

# ------------------------------------------------- the three cases the design named and the plan lost
#
# SP1's whole-branch review measured that this file was 23/23 with `if not UnitRelation.can_see(...)`
# deleted from visible_allied_characters(), and 23/23 again with get_all_characters() swapped for
# get_all_units() - two implementation lines the design had asked for and nothing tested. The first
# two tests below pin them. The third pins a ruling rather than a line: "Immobilized" is the engine's
# own UnitCondition.is_immobilized, which has three limbs, and only the status limb was exercised.

func test_an_ally_behind_a_wall_does_not_anchor_a_line():
	# "towards an allied character WITHIN LINE OF SIGHT". The ally is a real allied character at the
	# same distance as every other test in this file uses; the only difference is the wall.
	var ally := SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	build_wall_at(START.x + 4)
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	# THE FIXTURE CHECKS ARE NOT DECORATION. Without them this test would pass just as well if the
	# wall had accidentally swallowed the candidate tiles, or if the ally had never been placed - it
	# has to be an ally the Drive would otherwise drive towards, unseen for exactly one reason.
	assert_true(UnitRelation.are_allies(subutai, ally), 'fixture: it is an ally.')
	assert_false(UnitRelation.can_see(subutai, ally), 'fixture: the wall blocks sight to it.')
	assert_eq(candidates_towards(START + Vector2i(6, 0)).size(), RANGE,
		'fixture: the line towards it still has three candidates, all west of the wall.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: an unseen ally anchors no line.')
	assert_eq(subutai.tile(), START, 'It did not move.')

func test_a_friendly_deployable_does_not_anchor_a_line():
	# "towards an ALLIED CHARACTER". A drone, turret or cover the Subutai owns is allied and plainly
	# visible, and is still not a character - which is why the trait reads map.get_all_characters()
	# and not get_all_units().
	var dep := SubutaiFixture.create_allied_deployable(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	assert_true(UnitRelation.are_allies(subutai, dep), 'fixture: the deployable is allied.')
	assert_true(UnitRelation.can_see(subutai, dep), 'fixture: it is in plain sight.')
	assert_false(dep.is_character(), 'fixture: it is not a character.')
	assert_eq(candidates_towards(START + Vector2i(6, 0)).size(), RANGE,
		'fixture: the line towards it would have had three candidates.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: a deployable is not an allied character.')
	assert_eq(subutai.tile(), START, 'It did not move.')

func test_a_grappled_smaller_subutai_is_offered_the_drive():
	# Ruling 10: "Immobilized" is the ENGINE's test, not the status. UnitCondition.is_immobilized is
	# true for the smaller party in a grapple and for Shutdown as well, and the trait calls it rather
	# than has_status - so a Subutai held by something bigger can still Drive itself free. Every other
	# test in this file reaches Immobilized through the status, so this is the only guard on that.
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	grapple_as_the_smaller(subutai)
	assert_false(subutai.has_status(Lancer.STATUS.IMMOBILIZED),
		'fixture: the Immobilized STATUS is not what is being tested here.')
	assert_true(UnitCondition.is_immobilized(subutai), 'fixture: the engine still calls it immobilized.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'The grapple limb of is_immobilized opens the Drive too.')

# ------------------------------------------------------ the picker must never open with nothing in it
#
# SP1's whole-branch review: triggers_on_event gated only on "an ally exists", but the candidates are
# the min(3, distance) line tiles towards it and the Subutai is size 2 - so an ally standing close
# enough leaves every candidate anchor with a footprint that overlaps it, and the pathfinder rejects
# the lot. ask_for_movement opens the picker for a player unit regardless, so the Subutai got a dead
# prompt at every turn end for as long as it stayed Immobilized. Guardian rewards allies for standing
# adjacent, so this is the ordinary case.
#
# THE GEOMETRY IS DIRECTIONAL, and these two tests are aimed the way they are for that reason. The
# Subutai anchors its 2x2 footprint on its NORTH-WEST tile, so the footprint reaches away to the east
# and south: an ally two tiles EAST is covered by both candidate anchors, while an ally two tiles
# WEST is not covered by the near one and does still leave a legal landing tile. Measured
# 2026-09-15: the empty-picker window is an ally at anchor distance 1 in any direction, and at anchor
# distance 2 to the east/south.

func test_an_immobilized_subutai_whose_only_ally_is_pressed_against_it_is_offered_nothing():
	# The ally is on the single candidate tile the line offers, so the only anchor the Drive could
	# take IS the ally's tile.
	SubutaiFixture.create_ally(game, START + Vector2i(-1, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	assert_eq(candidates_towards(START + Vector2i(-1, 0)).size(), 1,
		'fixture: the line towards an adjacent ally has exactly one candidate - its own tile.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: there is nowhere legal to land.')
	assert_eq(subutai.tile(), START, 'It did not move.')

func test_an_immobilized_subutai_whose_only_ally_is_two_tiles_east_is_offered_nothing():
	# Two candidates this time, and the size-2 footprint kills both: anchoring on the first would put
	# the Subutai's east half on the ally, and the second IS the ally's tile.
	SubutaiFixture.create_ally(game, START + Vector2i(2, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	assert_eq(candidates_towards(START + Vector2i(2, 0)).size(), 2,
		'fixture: the line still offers two candidate tiles - both are illegal endpoints.')
	var prompts := await end_turn()
	assert_eq(prompts.size(), 0, 'No picker: every candidate footprint overlaps the ally.')
	assert_eq(subutai.tile(), START, 'It did not move.')

func test_a_unit_standing_along_the_line_shortens_the_offer():
	# A unit in the way narrows the offer, and this test records EXACTLY how - which is not what the
	# task brief predicted, so read the measurement rather than the intuition.
	#
	# The blocker sits on the SECOND candidate, two tiles east. The Subutai is size 2 and anchors on
	# its north-west tile, so an anchor at candidate 1 would occupy the blocker's tile and an anchor
	# at candidate 2 would BE it: both are invalid endpoints. Candidate 3 occupies nothing the
	# blocker holds, and it survives - so the one tile offered is the one PAST the blocker, not the
	# one before it.
	#
	# AND IT IS NOT RULING 17 THAT LETS IT REACH THAT TILE. Flipping
	# allow_alternate_paths_to_those_tiles back to false (mutation 4, run 2026-09-15) leaves THIS
	# test green: the ally is due east, section 1 measured the two line derivations to agree on every
	# compass ray, so the far candidate survives either way - a blocker on the line costs the Drive
	# the near endpoints and not the far one, narrow graph or wide. The one test that does discriminate
	# on that flag is test_an_off_axis_ally_is_still_offered_all_three_tiles above.
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	SubutaiFixture.create_dummy(game, START + Vector2i(2, 0), 10)
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	var line := candidates_towards(START + Vector2i(6, 0))
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'The picker still opens.')
	if prompts.is_empty(): return
	var offered:Array = offered_by(prompts[0])
	assert_eq(offered.size(), 1, 'The blocker costs the Drive two of its three endpoints.')
	assert_eq(offered, [line[2]] as Array[Vector2i],
		'The survivor is the far candidate, the only anchor whose size-2 footprint misses the blocker.')

func test_a_slowed_and_immobilized_subutai_is_still_offered_the_drive():
	# Ruling 7: the archetype gates Slowed and Immobilized only for a VOLUNTARY movement type.
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	slow(subutai)
	var prompts := await end_turn()
	assert_eq(prompts.size(), 1, 'Slowed does not stop a non-voluntary move.')

func test_a_second_turn_end_in_the_same_round_offers_nothing():
	# The 1/round is the engine's per-round hard limit, consulted inside does_reaction_trigger, so
	# the picker never opens a second time.
	#
	# THE TURN IS RE-OPENED BY HAND, NOT BY event_turn_start. The brief's version called open_turn()
	# again; that is wrong on 1.4.3, because event_turn_start:79 calls UnitAction.new_turn_refresh,
	# which calls reset_per_round_usage and CLEARS uses_this_round - so a second real turn start is a
	# new round as far as this limit is concerned and the Drive would legitimately be offered again.
	# event_turn_end.check_specific_context only demands is_taking_turn, so setting that flag alone
	# reproduces the case the card actually forbids: two turn ends inside one round.
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	responder.chosen_move_tile = START + Vector2i(3, 0)
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	await end_turn()
	assert_eq(uses_this_round(), 1, 'The first Drive was taken.')

	subutai.state.is_taking_turn = true # re-open the turn WITHOUT clearing uses_this_round
	var second := await end_turn()
	assert_eq(second.size(), 0, 'The second turn end in the same round offers no Drive.')

func test_a_drive_that_ends_in_dangerous_terrain_takes_the_terrain_damage():
	# Ruling 19. ignore_dangerous protects the Drive in TRANSIT only - event_map_dangerous refuses a
	# move whose movement type carries it (event_map_dangerous.gd:22) - but handle_ending_unit walks
	# the unit's occupied tiles afterwards with NO movement type at all, in the very same turn-end
	# event, and that one lands.
	#
	# There is no map.set_surface_terrain_at: surface terrain is derived from the landscape, so the
	# reachable API is SpecFactory.add_blocks_to_landscape, exactly as vanilla's
	# test/gamemaster/test_dangerous_terrain.gd uses it. The lava replaces the GROUND block at
	# height 0 rather than sitting on top of it, so the destination stays level with the start and
	# the picker's offer is unchanged.
	#
	# The engineering check event_map_dangerous makes is cheated to a 1 so the damage is not a coin
	# flip; without that this test would pass or fail on the die.
	SubutaiFixture.create_ally(game, START + Vector2i(6, 0))
	responder.chosen_move_tile = START + Vector2i(3, 0)
	var lava:Array[Vector3i] = []
	for tile:Vector2i in UnitTile.get_occupied(START + Vector2i(3, 0), 2, game.map.size):
		lava.append(Vector3i(tile.x, 0, tile.y))
	SpecFactory.add_blocks_to_landscape(game.get_landscape_node(), 'block_lava', lava)
	await SubutaiFixture.open_turn(game, subutai)
	immobilize(subutai)
	var health_before:int = subutai.core.current.health
	Dice.CHEAT_ROLL_QUEUE.append(1) # the eng check event_map_dangerous rolls: fail it
	await end_turn()
	assert_eq(subutai.tile(), START + Vector2i(3, 0), 'It drove into the fire.')
	assert_lt(subutai.core.current.health, health_before,
		'It takes the dangerous-terrain damage at the end of the same turn.')
