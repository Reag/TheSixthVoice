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

# ================================================================ the knock-down (SP2 Task 4)
#
# "At the end of your movement, you may choose a hostile character adjacent to you; they must make a
# Hull save or be knocked prone."
#
# ADJACENT IS DISTANCE 1 FROM THE MECH'S OWN TILES, AND THE TALENTS MOD'S WIDENING IS IGNORED
# (ruling 18, the seams line). UnitRelation.get_characters_within measures a radius
# (unit_relation.gd:34-43), and a measured radius is a place House Guard's adjacency widening never
# arrives - the Fungal Network and Gravity Well precedent. spec/test_compat.gd pins that from the
# other side, with the talents mod resident; this file pins the measure itself.
#
# THE PROMPT IS DECLINABLE AND DECLINING COSTS NOTHING EXTRA - but the CHARGE IS ALREADY GONE, and
# that is not the Halo shape. Halo returns before spend_actions so a cancel is free; here the charge
# and the Quick paid for the FLIGHT, which already happened, so the pick is the only thing declined.
#
# HOW "NOBODY WAS OFFERED" IS TOLD FROM "NOBODY WAS ASKED". testkit/mod_choice_responder.gd records
# EVERY one_unit prompt, including the ones its queue does not answer, which is what lets
# unit_prompts.size() == 0 mean "the gear raised no prompt" rather than "the gear raised one and the
# base answered it". Without that the distance and faction mutations below would both pass green.

const LANDING := FIVE_EAST                    # the same full leap Task 3 flies, named for what
                                              # it means to THIS section; one tile, one value
const BESIDE_LANDING := Vector2i(9, 5)        # distance 1 from LANDING
const ALSO_BESIDE_LANDING := Vector2i(8, 6)   # distance 1 from LANDING, the other side
const TWO_FROM_LANDING := Vector2i(10, 5)     # distance 2: outside, and exactly where House Guard's
                                              # widening would reach if it reached at all
const BESIDE_START := Vector2i(2, 5)          # distance 1 from START, distance 6 from LANDING

## The units the ONE unit prompt offered, compared as OBJECTS rather than by id: every hostile this
## fixture builds is a copy of the same dummy frame, so ids would not distinguish them at all.
## Returns [] when no prompt was raised, which is why every test below asserts unit_prompts.size()
## rather than reading this in isolation - "offered nobody" and "never asked" must not be confused.
func offered_units() -> Array:
	if responder.unit_prompts.is_empty(): return []
	return responder.unit_prompts[0].units

## Every test below leaps from START (3,5) to LANDING (8,5) - five tiles east, exactly Speed.
func test_a_hostile_adjacent_to_the_landing_is_offered() -> void:
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	Fixture.force_save_to_fail(victim)
	responder.unit_queue.append(victim)
	await leap_to(LANDING)
	assert_eq(primrose.tile(), LANDING, 'VACUITY: the leap landed where the test aimed it.')
	assert_eq(responder.unit_prompts.size(), 1, 'exactly one pick was offered.')
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'and the failed save knocked it prone.')

func test_a_passed_save_leaves_it_standing() -> void:
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	Fixture.force_save_to_pass(victim)
	responder.unit_queue.append(victim)
	await leap_to(LANDING)
	assert_eq(responder.unit_prompts.size(), 1, 'VACUITY: it was picked.')
	assert_false(victim.has_status(Lancer.STATUS.PRONE), 'a passed Hull save keeps it upright.')

func test_declining_the_pick_prones_nobody() -> void:
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	Fixture.force_save_to_fail(victim)
	responder.unit_queue.append(null)  # decline
	await leap_to(LANDING)
	assert_eq(responder.unit_prompts.size(), 1, 'VACUITY: the prompt was raised and then declined.')
	assert_false(victim.has_status(Lancer.STATUS.PRONE), 'nobody is knocked down.')

func test_declining_still_costs_the_charge_the_flight_already_paid() -> void:
	# NOT the Halo shape. There, the cancel comes before spend_actions and is therefore free
	# (action_halo.gd:125-131). Here the flight has already happened and already paid; the pick is a
	# rider on a completed move, and a refund would give the player a free reposition.
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	responder.unit_queue.append(null)
	await leap_to(LANDING)
	assert_eq(primrose.tile(), LANDING, 'VACUITY: it flew.')
	assert_eq(responder.unit_prompts.size(), 1, 'VACUITY: and the declined prompt was the one raised.')
	assert_eq(wind.charges_current, CHARGES - 1, 'the charge is still spent.')
	assert_true(Unit.is_valid(victim), 'VACUITY: there was somebody to decline.')

func test_every_adjacent_hostile_is_offered() -> void:
	var first := Fixture.create_hostile(game, BESIDE_LANDING)
	var second := Fixture.create_hostile(game, ALSO_BESIDE_LANDING)
	responder.unit_queue.append(first)
	await leap_to(LANDING)
	assert_eq(offered_units().size(), 2, 'both adjacent hostiles are on the menu.')
	# CORRECTED AT IMPLEMENTATION (the draft asserted only the SIZE, plus Unit.is_valid(second) as its
	# vacuity guard). A size of 2 is also what a menu offering the same unit twice, or one hostile and
	# some third character, would report - and is_valid(second) is true whether or not it was offered.
	# Membership is the assertion the test name actually makes.
	assert_true(offered_units().has(first), 'the one beside the landing is on it.')
	assert_true(offered_units().has(second), 'and so is the one diagonally off it.')

func test_a_hostile_two_tiles_from_the_landing_is_not_offered() -> void:
	var far := Fixture.create_hostile(game, TWO_FROM_LANDING)
	await leap_to(LANDING)
	assert_eq(primrose.tile(), LANDING, 'VACUITY: it flew.')
	assert_eq(responder.unit_prompts.size(), 0, 'nobody is adjacent, so no prompt is raised.')
	assert_false(far.has_status(Lancer.STATUS.PRONE), 'and nobody is knocked down.')

func test_a_hostile_adjacent_only_at_the_START_is_not_offered() -> void:
	# "At the END of your movement". Measuring from the wrong tile would be invisible in every other
	# test in this file, because every other test puts the hostile beside the landing.
	var left_behind := Fixture.create_hostile(game, BESIDE_START)
	await leap_to(LANDING)
	# CORRECTED AT IMPLEMENTATION: the draft had no landing guard here, and this is the one test in
	# the section whose hostile starts ADJACENT to the Primrose - so a leap that engagement or
	# occupation stopped dead would leave the mech on START, raise no prompt, and pass this test for
	# precisely the wrong reason.
	assert_eq(primrose.tile(), LANDING, 'VACUITY: it really did fly away from it.')
	assert_eq(responder.unit_prompts.size(), 0, 'the mech flew away from it; it is not offered.')
	assert_false(left_behind.has_status(Lancer.STATUS.PRONE), 'and it is not knocked down.')

func test_an_adjacent_ALLY_is_not_offered() -> void:
	var friend := Fixture.create_ally(game, BESIDE_LANDING)
	await leap_to(LANDING)
	# CORRECTED AT IMPLEMENTATION: same missing guard as above - without it, a leap that never
	# happened offers nobody either.
	assert_eq(primrose.tile(), LANDING, 'VACUITY: it flew.')
	assert_eq(responder.unit_prompts.size(), 0, 'a hostile character, says the card.')
	assert_false(friend.has_status(Lancer.STATUS.PRONE), 'the ally stays up.')

func test_a_leap_that_never_moved_offers_nothing() -> void:
	# The cancelled flight from Task 3, now with a hostile standing beside the START tile: a cancelled
	# Leap must not knock somebody down for free.
	#
	# CORRECTED AT IMPLEMENTATION. The draft said the unit.tile() == start_tile guard is what stops
	# that, and that this test makes Task 3's inert line load-bearing. MEASURED, IT DOES NOT. Task 4's
	# M3 neutered that guard and this file stayed 24/24; neutering the abort_without_unit line above it
	# instead ALSO stayed 24/24; only neutering BOTH reddens this test. The reason is
	# event_core.gd:26-32 - abort_when returns the already-aborted flag, and the movement picker's
	# cancel aborted the activation inside super.activate - so the abort line returns first and the
	# tile guard never runs on this path. Both lines stay (see action_leap.gd); what this test pins is
	# the PAIR, and saying so is the difference between a guard that is redundant and one that is dead.
	var neighbour := Fixture.create_hostile(game, BESIDE_START)
	Fixture.force_save_to_fail(neighbour)
	responder.chosen_move_tile = OFF_THE_MAP
	await leap_to(LANDING)
	assert_eq(primrose.tile(), START, 'VACUITY: the flight was cancelled.')
	assert_eq(responder.unit_prompts.size(), 0, 'no pick is offered.')
	assert_false(neighbour.has_status(Lancer.STATUS.PRONE), 'and nobody is knocked down.')

func test_the_save_is_a_HULL_save() -> void:
	# force_save_to_fail pins HULL to -30 and leaves the other three at 0, so a save of any other
	# attribute would come up neutral and pass more often than not. Asserted as a pair with
	# force_save_to_pass above: together they can only both hold if the save really reads Hull.
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	victim.core.frame.hase = HaseBlock.create(-30, 30, 30, 30)  # hopeless Hull, excellent everything else
	victim.core.full_repair()
	responder.unit_queue.append(victim)
	await leap_to(LANDING)
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'a -30 HULL is what failed.')

func test_the_prone_is_not_a_timed_status() -> void:
	# Lancer.UNTIL.MANUAL: Prone is cleared by standing up, not by a clock. This mod's own
	# action_full_speed_ahead.gd:70-72 applies it the same way, and a timed Prone would quietly
	# expire at the end of the round in real play while every other test here stayed green.
	var victim := Fixture.create_hostile(game, BESIDE_LANDING)
	Fixture.force_save_to_fail(victim)
	responder.unit_queue.append(victim)
	await leap_to(LANDING)
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'VACUITY: it is prone.')
	await game.execute_event(&'event_turn_end', {unit = primrose})
	await game.execute_event(&'event_turn_start', {unit = victim})
	await game.execute_event(&'event_turn_end', {unit = victim})
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'and still prone a full turn later.')
