## DAZZLING WIND, LEAP (Primrose rank I, SP2 Task 3 + Task 4).
##
## "Limited 3. Leap (Quick): fly your speed in a straight line. At the end of your movement, you may
## choose a hostile character adjacent to you; they must make a Hull save or be knocked prone."
##
## Task 3 is the flight: a straight-line flying move of UP TO Speed (ruling 15 - the player picks the
## endpoint, the Full Speed Ahead reading), costing a Quick and one of three charges. Task 4 appends
## the end-of-movement pick to the bottom of this file.
##
## HOW A MOVEMENT ACTION IS DRIVEN FROM A SPEC. ActionSystemMovement.activate asks
## TargetActionUtil.ask_for_movement_alt for a plan, and on the player branch X.TEST_MODE makes the
## activation's target_tiles the list the choice bus is asked to pick from
## (target_action_util.gd:78-81 - the engine's own comment says "this is also how TEST_MODE
## communicates what tiles we should aim at"). So passing target_tiles = [destination] is how a spec
## aims the Leap. This mod's test_full_speed_ahead.gd records the same thing.
##
## THE MOVE IS DATA. flying + straight_line on the inline MovementType, and NOTHING else (ruling 15):
## the card names no engagement or reaction waiver, so the Leap provokes exactly what any other move
## would. It does NOT need can_move_through_enemies either - movement_type.gd:99 is
## `return can_move_through_enemies or flying  # NEW RULE: FLYING CAN MOVE THROUGH ENEMIES`, so the
## flavour's "easily clearing any terrain or hostile forces" is already the engine's own rule and
## setting the flag would be a line that reads as load-bearing and is not.
##
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_leap.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const KIT_ID := &'ms_dazzling_wind'
const ACTION_ID := &'action_leap'

## The Primrose's Speed is 5 (07-primrose.md Stats). Every tile below is measured in those five.
const SPEED := 5
const CHARGES := 3
const SP_COST := 2

const START := Vector2i(3, 5)
const FIVE_EAST := Vector2i(8, 5)     # exactly Speed away, straight
const TWO_EAST := Vector2i(5, 5)      # a SHORT leap: ruling 15's "up to"
const OFF_THE_MAP := Vector2i(-5, -5) # not a tile: the cancel

var game:Gamemaster
var primrose:Unit
var wind:GearCore
var responder

## THE TESTKIT RESPONDER FROM THE FIRST TEST, NOT THE STOCK ONE, AND THIS IS NOT PREMATURE.
## Task 4 needs a responder that can DECLINE a unit pick without abort_all - abort_all would kill the
## movement picker that runs ahead of it in the same activation - and the testkit responder inherits
## every stock behaviour, including chosen_move_tile, so Task 3's tests read identically through it.
## Building the stock game here and a prompted one in Task 4 would leave a test with TWO live
## responders BOTH answering every request (primrose_fixture.gd:88 records why that is fatal), so the
## choice is made once, here.
func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	primrose = Fixture.create_primrose(game, START)
	wind = Fixture.equip(primrose, KIT_ID)
	await Fixture.open_turn(game, primrose)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func leap_to(tile:Vector2i) -> void:
	await game.execute_event(&'event_gear_activate', {
		unit = primrose,
		gear = wind,
		action = wind.kit.get_action(ACTION_ID),
		target_tiles = [tile] as Array[Vector2i],
	})

func action() -> ActionSystemMovement:
	return wind.kit.get_action(ACTION_ID) as ActionSystemMovement

# ---------------------------------------------------------------- the system as data

func test_the_system_is_limited_three() -> void:
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_true(Kit.is_valid(kit), 'ms_dazzling_wind is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, SP_COST, 'SP 2.')
	assert_eq(kit.charges_max, CHARGES, 'Limited 3.')
	# NOT Unique - the card's tag line is "LIMITED 3" and nothing else. Asserted so that a
	# copy-paste of the Rend Axe's system_tags shows up here.
	assert_false(kit.is_unique(), 'not Unique.')

func test_leap_is_a_quick_action() -> void:
	var leap := action()
	assert_not_null(leap, 'the Kit carries action_leap.')
	if leap == null: return
	assert_eq(leap.get_action_type(Fixture.specific(primrose, KIT_ID)), Lancer.ACTION.QUICK, 'Quick.')

func test_the_movement_type_is_flying_and_straight_line_and_nothing_else() -> void:
	# Read the AUTHORED resource, not get_movement_type(unit): that one merges in the unit's own
	# movement type (action_system_movement.gd:36-41), which would mask a flag we failed to set and
	# add flags we did not author. The card's promise is what THIS resource declares.
	var leap := action()
	if leap == null: return assert_true(false, 'no action to inspect.')
	var move:MovementType = leap.movement_type
	assert_not_null(move, 'the action carries a MovementType.')
	if move == null: return
	assert_true(move.flying, 'flying.')
	assert_true(move.straight_line, 'in a straight line.')
	# Ruling 15: the card names no waiver, so none is granted. Each of these is a separate assertion
	# because each one is a different promise the player would otherwise be given for free.
	assert_false(move.ignore_engagement, 'no engagement waiver - the card names none.')
	assert_false(move.ignore_rxns, 'no reaction waiver - the card names none.')
	assert_false(move.must_move_max_possible, 'UP TO Speed, not exactly Speed (ruling 15).')
	assert_false(move.teleport, 'it is a flight, not a teleport.')
	assert_false(move.spend_move, 'it does not eat the standard move.')
	# Deliberately NOT set, because the engine already does it: movement_type.gd:99 answers
	# `can_move_through_enemies or flying`.
	assert_false(move.can_move_through_enemies,
		'not authored - flying already grants it (movement_type.gd:99).')

func test_the_reach_is_the_printed_speed_not_what_is_left_of_the_turn() -> void:
	# movement_range_fixed 0 + spend_move false => unit.get_speed_max() (action_system_movement.gd:30-35).
	# Spending the standard move first and still getting five tiles is what proves it.
	var leap := action()
	if leap == null: return assert_true(false, 'no action to inspect.')
	primrose.core.current.speed = 0
	assert_eq(leap.get_target_range(Fixture.specific(primrose, KIT_ID)), SPEED,
		'the Leap still reaches five tiles with the standard move spent.')

# ---------------------------------------------------------------- the flight

func test_the_primrose_flies_its_full_speed_in_a_straight_line() -> void:
	await leap_to(FIVE_EAST)
	assert_eq(primrose.tile(), FIVE_EAST, 'it arrives five tiles east.')

func test_a_shorter_leap_is_allowed() -> void:
	# Ruling 15's "up to Speed". must_move_max_possible false is the flag that permits it, and this
	# is the test that would redden if it were set.
	await leap_to(TWO_EAST)
	assert_eq(primrose.tile(), TWO_EAST, 'a two-tile leap lands two tiles away.')

## ADDED AT REVIEW (controller, 2026-09-19), AFTER TWO WRONG TESTS AND ONE CORRECTED ASSUMPTION.
##
## Task 3's M1 - straight_line = false - reddened ONLY the movement-type assertion above, which
## looked like a gap: the card's "in a straight line" pinned by one resource field and by nothing the
## mech does. Chasing it turned up the reason, and it is that THE ASSUMPTION WAS WRONG, not the
## content.
##
## "STRAIGHT LINE" IN THIS ENGINE MEANS NO DOG-LEGS, AT ANY ANGLE - NOT ONE OF EIGHT RAYS.
## pathfinder.gd:495-497 builds each candidate destination's path with calculate_step_path_for_line
## instead of calculate_step_path, and that is an AoeCalculator.line to an ARBITRARY tile
## (pathfinder.gd:721-726). So a flight from (3,5) to (6,7) - dx 3, dy 2, on no 8-directional ray -
## is a straight line, and is correctly offered. Measured: reachable_tiles under this action is every
## tile within Chebyshev distance 5, minus the origin. The Fitzgerald spec's
## test_the_movement_type_carries_every_clause_of_the_card says deleting straight_line must turn "the
## realized path" red; on an unobstructed map it does not, because a walked path and a drawn line
## between the same two tiles end in the same place. Both frames' straight-line clause is pinned by
## the movement-type assertion, and that is the honest state of it.
##
## WHAT IS BEHAVIOURALLY OBSERVABLE, AND IS PINNED HERE, is the OTHER half of ruling 15. With
## must_move_max_possible ALSO set, is_tile_within_max_distance_of_straight_movement turns on
## (pathfinder.gd:711-718) and the picker stops consulting the pathfinder at all - the player may
## click anywhere inside the radius and the engine walks a "pathfinder-be-damned" straight path there
## (target_action_util.gd:95-103, and the engine's own comment above that function says so). Leap
## leaves must_move_max_possible false precisely so the endpoint stays the pathfinder's business,
## which is what "the player picks the endpoint, up to Speed" means. The flag assertion above says
## the field is false; this says what that buys.
func test_the_picker_still_consults_the_pathfinder() -> void:
	var leap := action()
	if leap == null: return assert_true(false, 'no action to inspect.')
	var pathfinder:Pathfinder = await leap.generate_action_pathfinder(Fixture.specific(primrose, KIT_ID))
	assert_not_null(pathfinder, 'the action builds a pathfinder.')
	if pathfinder == null: return
	# VACUITY: the tile really is inside the budget, so a false below cannot be the distance test.
	assert_lte(Tile.distance(FIVE_EAST, START), SPEED, 'VACUITY: the tile is within Speed.')
	assert_false(pathfinder.is_tile_within_max_distance_of_straight_movement(FIVE_EAST, START),
		"must_move_max_possible is off, so the endpoint stays the pathfinder's business.")

func test_it_flies_over_a_hostile_in_the_ray() -> void:
	# The engine's rule, not ours (movement_type.gd:99). A hostile standing in the middle of the ray
	# neither blocks the leap nor changes where it lands.
	var blocker := Fixture.create_hostile(game, Vector2i(5, 5))
	await leap_to(FIVE_EAST)
	assert_eq(primrose.tile(), FIVE_EAST, 'it flew over the blocker.')
	assert_true(Unit.is_valid(blocker), 'VACUITY: the blocker was really there.')

func test_the_primrose_lands_rather_than_staying_airborne() -> void:
	# MovementType.flying is fake flying for the PATHFINDER only
	# (action_system_movement.gd:46-63); the unit is never given the FLYING status, so it is on the
	# ground when it stops. A Leap that left the mech flying would change every later cover, fall and
	# engagement calculation in the scene.
	await leap_to(FIVE_EAST)
	assert_false(primrose.has_status(Lancer.STATUS.FLYING), 'it is on the ground when it lands.')

# ---------------------------------------------------------------- the charge

func test_a_leap_spends_a_charge() -> void:
	await leap_to(FIVE_EAST)
	assert_eq(primrose.tile(), FIVE_EAST, 'VACUITY: the leap happened.')
	assert_eq(wind.charges_current, CHARGES - 1, 'one charge gone.')

func test_cancelling_at_the_picker_spends_nothing() -> void:
	# Ruling 15. ActionSystemMovement.activate returns on abort_without_movement_plan BEFORE
	# spend_actions, and spend_actions is the only path to gear.spend_charge()
	# (unit_action.gd:275) - so this costs us no code, and this test is what pins that it stays true.
	#
	# HOW THE CANCEL IS EXPRESSED: the stock responder answers a move_tile request with
	# chosen_move_tile when it is set (spec_factory.gd:423-424), and target_action_util.gd:90-91
	# turns a tile that is not on the map into CompconPlan.create_aborted(). Aiming off the map is
	# therefore exactly a player pressing escape. abort_all would do it too, but Task 4 needs a
	# cancel that does NOT also kill the unit picker, so this file uses one mechanism throughout.
	responder.chosen_move_tile = OFF_THE_MAP
	await leap_to(FIVE_EAST)
	assert_eq(primrose.tile(), START, 'it did not move.')
	assert_eq(wind.charges_current, CHARGES, 'and no charge was spent.')
	assert_eq(primrose.state.actions, UnitAction.current_total(primrose), 'nor an action point.')

func test_it_is_refused_with_no_charges_left() -> void:
	wind.charges_current = 0
	assert_eq(UnitAction.get_gear_unavailable_reason(Fixture.specific(primrose, KIT_ID)),
		UnitAction.REASON.NO_CHARGES, 'an empty Dazzling Wind is refused, and the engine names why.')

func test_the_card_text_resolves() -> void:
	for key:String in ['gear.ms_dazzling_wind.name', 'gear.ms_dazzling_wind.flavor',
			'gear.ms_dazzling_wind.action_leap.name', 'gear.ms_dazzling_wind.action_leap.effect']:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)
