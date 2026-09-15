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

const TRAIT_ID := &'mt_juggernaut_drive'
const ACTION_ID := &'action_juggernaut_drive'
const RANGE := 3

const START := Vector2i(8, 8)

var game:Gamemaster
var subutai:Unit

func before_each() -> void:
	game = SubutaiFixture.create_game(self, Vector2i(24, 24))
	subutai = SubutaiFixture.create_subutai(game, START)

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
