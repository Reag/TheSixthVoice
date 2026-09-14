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

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const SYSTEM_ID := &'ms_hull_break_thrusters'
const ACTION_ID := &'action_full_speed_ahead'

# The Fitzgerald's Speed is 4 (01-fitzgerald.md). Everything below is measured in those four tiles.
const SPEED := 4
const START := Vector2i(2, 4)

var game:Gamemaster
var fitz:Unit
var thrusters:GearCore

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	fitz = FitzgeraldFixture.create_fitzgerald(game, START)
	thrusters = fitz.core.equip_system(SYSTEM_ID)
	SpecFactory.apply_passive_buffs(fitz)
	await FitzgeraldFixture.open_turn(game, fitz)

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

## The destination above is straight, exactly Speed away, and reachable by ordinary walking - so
## test_the_fitzgerald_flies_its_full_speed_in_a_straight_line's landing-tile assertion is satisfied
## by almost any movement action, including one with every card clause deleted. These two tests pin
## the card directly on the action instead of inferring it from where the unit happened to land.
func test_the_movement_budget_is_the_units_speed() -> void:
	# get_target_range only falls through to unit.get_speed_max() because movement_range_fixed is
	# left at 0 and the .tres never sets movement_type.spend_move (action_system_movement.gd:31-36,
	# 33-35). Nothing else on this branch tries to overshoot Speed, so a widened
	# movement_range_fixed would pass every other test in this file.
	var action:Action = thrusters.kit.get_action(ACTION_ID)
	var specific := SpecificAction.create(fitz, thrusters, action)
	assert_eq(action.get_target_range(specific), SPEED, 'The budget is exactly Speed, not more.')

func test_the_movement_type_carries_every_clause_of_the_card() -> void:
	# get_movement_type(unit) (action_system_movement.gd:38-45) merges the .tres's inline
	# MovementType with the unit's own - asserting the merged flags directly is the only way to pin
	# each clause of the card independently of the others or of where the dash lands.
	#
	# The Fitzgerald carries no FLYING status, so MovementType.create's "flying implies
	# straight_line" fallback (movement_type.gd:54-55) never fires for it: straight_line and flying
	# only reach the merged type because the .tres sets them explicitly, so deleting either one from
	# the .tres has to turn this test - and the realized path - red.
	var action:ActionSystemMovement = thrusters.kit.get_action(ACTION_ID) as ActionSystemMovement
	var movement_type := action.get_movement_type(fitz)
	assert_true(movement_type.flying, 'FLYING: "fly your speed" on the card.')
	assert_true(movement_type.straight_line, '"in a straight line" - no dog-legs.')
	assert_true(movement_type.can_move_through_enemies, '"moving through hostile characters".')
	assert_true(movement_type.ignore_engagement, 'Leaving engagement is silent: no hold, no reaction.')
	assert_true(movement_type.ignore_rxns, 'Nothing gets a reaction off this move at all.')

func test_a_charge_is_spent() -> void:
	var before:int = thrusters.charges_current
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(thrusters.charges_current, before - 1, 'One of the three charges is gone.')

func test_it_is_refused_with_no_charges_left() -> void:
	thrusters.charges_current = 0
	# The tile assertion below would also pass against an action that never fired at all - it does
	# not tell a REFUSAL apart from a no-op. get_gear_unavailable_reason is exactly what
	# event_gear_activate.check_specific_context calls before aborting the event
	# (content/events/event_gear_activate.gd:46-51, whose own log line is literally
	# "[ Gear not available ]"), and unit_action.gd:153 is the clause that reads charges_current and
	# hands back REASON.NO_CHARGES. Asserting that reason directly proves the refusal is FOR LACK OF
	# CHARGES specifically, not some unrelated gate that happened to also block the dash.
	var action:Action = thrusters.kit.get_action(ACTION_ID)
	var specific := SpecificAction.create(fitz, thrusters, action)
	assert_eq(
		UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.NO_CHARGES,
		'The system itself reports NO_CHARGES, not some other gate.'
	)
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START, 'An uncharged system moves nobody.')

func test_it_flies_through_a_hostile_character() -> void:
	FitzgeraldFixture.create_dummy(game, START + Vector2i(2, 0), 10)
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.tile(), START + Vector2i(SPEED, 0), 'The hostile in the way was passed through.')

func test_an_engaged_fitzgerald_leaves_without_provoking_overwatch() -> void:
	# Adjacent hostile: engagement would normally hold it, and leaving would provoke a reaction.
	var blocker := FitzgeraldFixture.create_dummy(game, START + Vector2i(1, 0), 10)
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
## and the frame's own HULL so the cheated save die decides the outcome. FitzgeraldFixture.create_dummy has
## already FrameIsolation'd it, so these writes are to its own copy of the frame, not a shared one.
func make_victim(tile:Vector2i) -> Unit:
	var victim := FitzgeraldFixture.create_dummy(game, tile, 10)
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
	# Neither assertion above tells "the save was forced and passed" apart from "cheat_passed_saves
	# silently did nothing and no save was ever forced" - a victim that is never made to save looks
	# exactly the same as one that saved and cleared it. roll_dice (dice.gd:33-35) only pops
	# CHEAT_ROLL_QUEUE when it is non-empty, otherwise it rolls live; cheat_passed_saves seeded four
	# 20s, and this dash forces exactly one Hull save (one hostile on the ray, accuracy_bonus 0 so
	# no extra d6 pop - roll_d6_accuracy, dice.gd:86-88, only rolls for a non-zero bonus). A working
	# cheat therefore leaves exactly three 20s behind; a no-op cheat would have left the queue empty
	# both before and after, since an empty queue is never touched. This is the cheapest proof that
	# the pass was cheated rather than lucked into on a natural roll.
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 3,
		'One cheated 20 was actually popped for the forced save, not left unused.')

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

func test_crossing_an_ally_still_costs_self_damage_but_spares_the_ally() -> void:
	# The self-damage half of the card ("each occupied space you pass through") counts ANY
	# character; the save half ("all hostile characters") only makes hostiles save - see
	# count_occupied_crossed's and caught_hostiles' headers. That asymmetry was, until now, only a
	# comment: nothing distinguished it from a future refactor that unified the two helpers onto one
	# hostiles-only definition of "occupied", which would still make every other test above pass.
	var ally := FitzgeraldFixture.create_dummy(game, START + Vector2i(2, 0), 10, Faction.AI_ALLY)
	assert_true(UnitRelation.are_allies(fitz, ally),
		'Sanity: PLAYER (the Fitzgerald) and AI_ALLY are actually allied, not two enemies.')
	var fitz_before:int = fitz.core.current.health
	var ally_before:int = ally.core.current.health
	# Failed, not passed: if a regression ever DID route the ally into caught_hostiles, a cheated
	# fail makes that show up deterministically as Prone + 3 damage, rather than a natural roll that
	# might pass by luck and hide the bug.
	cheat_failed_saves()
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz_before - fitz.core.current.health, 1,
		'The Fitzgerald still pays 1 AP for the occupied space - the ally counts same as a hostile.')
	assert_false(ally.has_status(Lancer.STATUS.PRONE), 'The ally is never forced to save...')
	assert_eq(ally.core.current.health, ally_before, '...and takes no damage either.')

func test_an_empty_run_costs_the_fitzgerald_nothing() -> void:
	var before:int = fitz.core.current.health
	await dash_to(START + Vector2i(SPEED, 0))
	assert_eq(fitz.core.current.health, before, 'Nothing was in the way, so nothing was paid.')
