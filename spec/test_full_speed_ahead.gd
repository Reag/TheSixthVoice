# Hull-break Thrusters, FULL SPEED AHEAD (Fitzgerald rank II, SP3 Task 1 + Task 2).
#
# Task 1 covers the DASH: a straight-line flying move of up to Speed in any direction, through
# hostile characters, ignoring engagement and reactions, costing a QUICK and one of three charges.
# Task 2 appends the PATH WALK (saves, Prone, 3 AP to those caught, 1 AP to self per occupied space
# crossed) to the bottom of this file.
#
# HOW A MOVEMENT ACTION IS DRIVEN FROM A SPEC. ActionSystemMovement.activate asks
# TargetActionUtil.ask_for_movement_alt for a plan, and on the player branch X.TEST_MODE makes the
# activation's target_tiles the list the choice bus is asked to pick from
# (target_action_util.gd:78-81 - the engine's own comment says "this is also how TEST_MODE
# communicates what tiles we should aim at"). So passing target_tiles = [destination] to
# event_gear_activate is how a spec aims the dash; the stock responder answers, and no mod-private
# prompt type is involved.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_full_speed_ahead.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const SYSTEM_ID := &'ms_hull_break_thrusters'
const ACTION_ID := &'action_full_speed_ahead'

# The Fitzgerald's Speed is 4 (01-fitzgerald.md). Everything below is measured in those four tiles.
const SPEED := 4
const START := Vector2i(2, 4)

var game:Gamemaster
var fitz:Unit
var thrusters:GearCore

func before_each() -> void:
	game = Fixture.create_game(self)
	fitz = Fixture.create_fitzgerald(game, START)
	thrusters = fitz.core.equip_system(SYSTEM_ID)
	SpecFactory.apply_passive_buffs(fitz)
	await Fixture.open_turn(game, fitz)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Fire FULL SPEED AHEAD at a destination tile. See the file header for why target_tiles is how a
## spec aims a movement action.
func dash_to(tile:Vector2i) -> void:
	await game.execute_event(&'event_gear_activate', {
		unit = fitz,
		gear = thrusters,
		action = thrusters.kit.get_action(ACTION_ID),
		target_tiles = [tile] as Array[Vector2i],
	})

func test_the_system_is_limited_three_and_unique() -> void:
	var kit:Kit = ContentLibrary.get_kit(SYSTEM_ID)
	assert_true(Kit.is_valid(kit), 'ms_hull_break_thrusters is in the kits index.')
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 3, 'Limited 3.')
	assert_true(kit.is_unique(), 'Unique.')

func test_the_dash_is_a_quick_action() -> void:
	var action:Action = thrusters.kit.get_action(ACTION_ID)
	assert_not_null(action, 'The kit carries action_full_speed_ahead.')
	assert_eq(
		action.get_action_type(SpecificAction.create(fitz, thrusters, action)),
		Lancer.ACTION.QUICK,
		'FULL SPEED AHEAD is a QUICK.'
	)

func test_the_fitzgerald_flies_its_full_speed_in_a_straight_line() -> void:
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START + Vector2i(SPEED, 0), 'It ended Speed tiles due east.')

func test_a_charge_is_spent() -> void:
	var before:int = thrusters.charges_current
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(thrusters.charges_current, before - 1, 'One of the three charges is gone.')

func test_it_is_refused_with_no_charges_left() -> void:
	thrusters.charges_current = 0
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START, 'An uncharged system moves nobody.')

func test_it_flies_through_a_hostile_character() -> void:
	Fixture.create_dummy(game, START + Vector2i(2, 0), 10)
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START + Vector2i(SPEED, 0), 'The hostile in the way was passed through.')

func test_an_engaged_fitzgerald_leaves_without_provoking_overwatch() -> void:
	# Adjacent hostile: engagement would normally hold it, and leaving would provoke a reaction.
	var blocker := Fixture.create_dummy(game, START + Vector2i(1, 0), 10)
	var blocker_health:int = blocker.core.current.health
	# TASK 2 AMENDED THIS TEST, AND ONLY THIS LINE. The blocker stands on a tile the dash enters, so
	# once the path walk below existed it started forcing a Hull save on it - and an uncheated d20
	# failed that save often enough to knock 3 AP off the blocker and turn "nothing shot at it" red
	# for the wrong reason. Cheating the save to PASS takes the path walk's damage off the table
	# without weakening anything: this assertion still reads zero only if no REACTION fired, and an
	# overwatch shot would pop its own die off the same queue (a 20 against evasion 10 is a hit) and
	# move the number. The placement is deliberately unchanged - adjacent AND in the way is the case
	# worth testing.
	cheat_passed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START + Vector2i(SPEED, 0), 'Engagement did not hold it.')
	assert_eq(blocker.core.current.health, blocker_health, 'Nothing shot at it on the way out.')

# ---------------------------------------------------------------- the path walk (Task 2)
#
# Ruling 7: hostiles PASSED THROUGH, or adjacent to any tile entered AFTER the start tile, are
# affected once each. Adjacency to the start tile alone is not enough - you were already standing
# there. That exclusion is free rather than subtracted: AoeCalculator.line's rings begin one step
# from the origin (aoe_calculator.gd:143, Tile.get_rings starts its loop at 1 - tile.gd:349), so the
# entered-tile list never contains the start tile.
#
# ADJACENCY HERE IS CHEBYSHEV, AND THAT MOVED ONE OF THESE TESTS. Tile.distance is max(dx, dy)
# (tile.gd:380-387) over an eight-way neighbourhood (Tile.DIRECTIONS, tile.gd:22), so a tile
# DIAGONALLY off the ray is at distance 1 from it. The tile directly north of START is diagonally
# adjacent to START + (1, 0), which IS an entered tile, so it is caught - correctly, by the ruling.
# The only tiles adjacent to START and to nothing else on an eastward dash are the three BEHIND it,
# so the start-tile exclusion is pinned from due west instead. (The task brief specified
# START + (0, -1); that would have failed against a correct implementation.)

## Force every Hull save in this activation to FAIL. The save is a d20 plus the target's HULL
## against the Fitzgerald's save target (event_unit_save.gd, execute()); a 1 can never clear it.
## Buffer sized for four saves - no test below puts more than two hostiles on the ray, and one d20
## is popped per save (unit_hasecheck.gd:200, roll_d20_with_player_interventions; the accuracy die
## is only rolled for a non-zero bonus, dice.gd:86-88).
##
## Dice.cheat_roll() does NOT exist - the queue is the API, exactly as the sibling specs' cheat_a_hit
## helpers use it. Cleared first for the reason test_knock_em_down.gd records at length: cheat
## helpers only APPEND, so a leftover die from an earlier activation would answer the next save.
func cheat_failed_saves() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array([1, 1, 1, 1])

## ...and to PASS.
func cheat_passed_saves() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array([20, 20, 20, 20])

## A dummy that can actually be hurt and shoved: 20 HP, 1 armor so the AP on the damage is visible,
## and the frame's own HULL so the cheated save die decides the outcome. Fixture.create_dummy has
## already FrameIsolation'd it, so these writes are to its own copy of the frame, not a shared one.
func make_victim(tile:Vector2i) -> Unit:
	var victim := Fixture.create_dummy(game, tile, 10)
	victim.core.frame.stat.health = 20
	victim.core.frame.stat.armor = 1
	victim.core.full_repair()
	return victim

func test_a_hostile_passed_through_is_knocked_prone_and_takes_three_ap() -> void:
	var victim := make_victim(START + Vector2i(2, 0))
	var before:int = victim.core.current.health
	cheat_failed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'It failed its Hull save and went down.')
	assert_eq(before - victim.core.current.health, 3, 'Three damage, and its 1 armor did not bite: AP.')

func test_a_passed_save_costs_nothing() -> void:
	var victim := make_victim(START + Vector2i(2, 0))
	var before:int = victim.core.current.health
	cheat_passed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_false(victim.has_status(Lancer.STATUS.PRONE), 'It stayed up.')
	assert_eq(victim.core.current.health, before, 'And took nothing.')

func test_a_hostile_beside_the_path_is_caught_too() -> void:
	# One tile north of the second tile entered: never passed through, but became adjacent.
	var victim := make_victim(START + Vector2i(2, -1))
	cheat_failed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'Becoming adjacent is enough.')

func test_a_hostile_beside_only_the_start_tile_is_not_caught() -> void:
	# Directly WEST of where the Fitzgerald was standing - behind the dash, and the only direction
	# from which a tile touches the start tile and nothing on the eastward ray. See the Chebyshev
	# note in this section's header for why north does not qualify.
	var victim := make_victim(START + Vector2i(-1, 0))
	cheat_failed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_false(victim.has_status(Lancer.STATUS.PRONE),
		'Ruling 7: you were already standing next to it.')

func test_a_hostile_passed_through_and_adjacent_later_is_affected_once() -> void:
	var victim := make_victim(START + Vector2i(1, 0))
	var before:int = victim.core.current.health
	cheat_failed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(before - victim.core.current.health, 3, 'One save, one helping of damage.')

func test_crossing_two_occupied_spaces_costs_two_self_damage() -> void:
	make_victim(START + Vector2i(1, 0))
	make_victim(START + Vector2i(3, 0))
	var before:int = fitz.core.current.health
	cheat_passed_saves() # keep the victims upright so only the self-damage moves
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(before - fitz.core.current.health, 2, 'One AP kinetic per occupied space crossed.')

func test_an_empty_run_costs_the_fitzgerald_nothing() -> void:
	var before:int = fitz.core.current.health
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.core.current.health, before, 'Nothing was in the way, so nothing was paid.')
