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
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START + Vector2i(SPEED, 0), 'Engagement did not hold it.')
	assert_eq(blocker.core.current.health, blocker_health, 'Nothing shot at it on the way out.')
