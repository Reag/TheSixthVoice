# DONT GIVE UP THE MECH (Hazard, cp_int_type_command_systems - the core active) - SP1 Task 4,
# rulings 6-7:
#
#   "All allied characters within SENSORS may move up to their speed as a reaction. For the rest of
#    the scene, you and all adjacent allied characters can not be pushed, pulled, knocked back, or
#    knocked Prone."
#
# THE MOVES are observed through testkit/prompt_watcher.gd's move_tile kind (who was offered a
# reticle) and answered by the responder's chosen_move_tile. A DECLINED reticle is the responder's
# abort_all, raised from the watcher's own signal the instant the move request appears - the
# responder reads abort_all a frame later - and lowered again after the press, so the core power's
# own yes/no is answered normally.
#
# THE IMMUNITY is measured with REAL forced movement: CommonActionUtil.generate_knockback_events
# (what every knocking effect calls, and where immunity is asked first), and a raw involuntary
# event_unit_pick_move for "pulled" (the event's own gate). Voluntary pick moves are NOT refused -
# buff_dgutm_knockback.gd's refinement, measured here.
#
# House Guard does not widen the aura: test_compat.gd.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_dont_give_up_the_mech.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const STUB_CANNON := &'mw_stub_cannon' # HA, a vanilla knockback weapon: the forcer's specific

const HAZARD_TILE := Vector2i(6, 6)
const ADJACENT := Vector2i(7, 6)
const TWO_OUT := Vector2i(8, 6)
const WITHIN_SENSORS := Vector2i(12, 6)   # 6 from the Hazard: inside Sensors 10
const OUTSIDE_SENSORS := Vector2i(20, 6)  # 14 out
const HOSTILE_TILE := Vector2i(6, 2)

var game:Gamemaster
var responder
var watcher
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	responder.abort_all = false
	Dice.CHEAT_ROLL_QUEUE.clear()

func press() -> void:
	await Fixture.open_turn(game, hazard)
	await SpecFactory.use(game, hazard, Fixture.CORE_ID, Fixture.DGUTM_ID)

func press_declining_every_move() -> void:
	var decline := func(kind:StringName, _info:Dictionary) -> void:
		if kind == &'move_tile': responder.abort_all = true
	watcher.prompt.connect(decline)
	await press()
	watcher.prompt.disconnect(decline)
	responder.abort_all = false

func offered_movers() -> Array:
	return watcher.kinds(&'move_tile').map(func(info:Dictionary) -> Unit: return info.unit)

func immune(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, Fixture.DGUTM_KNOCKBACK) and UnitCondition.has_buff(unit, Fixture.DGUTM_PRONE)

func forcer() -> SpecificAction:
	var gear:GearCore = Fixture.equip(hostile, STUB_CANNON)
	return SpecificAction.create(hostile, gear, gear.get_solo_action())

## A real knockback of 2 away from the hostile; true when it produced any movement at all.
func knock_back(unit:Unit) -> bool:
	var events := CommonActionUtil.generate_knockback_events(unit, 2, forcer(), hostile.occupied_tiles(),
		[EventUnitPickMove.FLAG.AUTO_FURTHEST])
	if events.is_empty(): return false
	var before:Vector2i = unit.tile()
	await game.execute_event_block(EventBlock.create_multiple(events))
	return unit.tile() != before

## An involuntary pull of up to 2 (a grapple's or a lasso's shape) straight through the event.
func pull(unit:Unit) -> bool:
	var before:Vector2i = unit.tile()
	var specific := forcer()
	await game.execute_event_block(EventBlock.create_multiple([EventCore.create(&'event_unit_pick_move', {
		target_unit = unit,
		resource = MovementType.create_for_involuntary(unit),
		number = 2,
		flags = [EventUnitPickMove.FLAG.AUTO_FURTHEST],
		unit = specific.unit, gear = specific.gear, action = specific.action,
	})]))
	return unit.tile() != before

## A voluntary "may move 2" on the unit (Emergency Armature's shape).
func may_move(unit:Unit) -> bool:
	var before:Vector2i = unit.tile()
	await game.execute_event_block(EventBlock.create_multiple([EventCore.create(&'event_unit_pick_move', {
		target_unit = unit,
		resource = MovementType.create(unit, true),
		number = 2,
	})]))
	return unit.tile() != before

# ---------------------------------------------------------------- the press

func test_it_spends_the_core_power_and_the_hazard_does_not_move():
	await press()
	assert_false(hazard.core.has_core_power, 'The core power is spent.')
	assert_eq(hazard.tile(), HAZARD_TILE, 'The Hazard does not move.')
	assert_does_not_have(offered_movers(), hazard, 'And is not offered a move.')

func test_every_allied_character_within_sensors_with_a_reaction_is_offered_a_move():
	var near := Fixture.create_ally(game, ADJACENT)
	var mid := Fixture.create_ally(game, WITHIN_SENSORS)
	var far := Fixture.create_ally(game, OUTSIDE_SENSORS)
	var spent := Fixture.create_ally(game, Vector2i(6, 8))
	var drone := Fixture.create_drone(game, Vector2i(5, 6))
	# AFTER the Hazard's turn opens: every turn start refreshes EVERY unit's reaction point
	# (every_new_turn_refresh), so zeroing it before would be undone by the press itself.
	await Fixture.open_turn(game, hazard)
	spent.core.current.reactions = 0
	await press()
	var movers := offered_movers()
	assert_has(movers, near, 'An adjacent ally is offered.')
	assert_has(movers, mid, 'An ally 6 out, inside Sensors 10, is offered.')
	assert_does_not_have(movers, far, 'One outside Sensors is not.')
	assert_does_not_have(movers, spent, 'One with no reaction is not.')
	assert_has(movers, drone, 'A drone is a character (ruling 2026-09-27) and is offered too.')
	assert_does_not_have(movers, hostile, 'Nor a hostile.')
	assert_eq(movers.size(), 3, 'Exactly the three.')

func test_a_taken_move_is_up_to_speed_and_spends_the_allys_reaction():
	var ally := Fixture.create_ally(game, WITHIN_SENSORS)
	responder.chosen_move_tile = WITHIN_SENSORS + Vector2i(0, 3)
	await press()
	assert_eq(ally.tile(), WITHIN_SENSORS + Vector2i(0, 3), 'The ally moved where it chose (3 of its speed).')
	assert_eq(ally.core.current.reactions, 0, 'RAW: "as a reaction" - its reaction point is spent.')
	var farthest:int = 0
	for tile:Vector2i in watcher.kinds(&'move_tile')[0].pathfinder.reachable_tiles:
		farthest = maxi(farthest, Tile.distance(WITHIN_SENSORS, tile))
	assert_eq(farthest, ally.core.get_speed_max(), 'The reticle reaches exactly the ally\'s speed.')

func test_a_declined_move_spends_nothing_and_the_immunity_still_comes():
	var ally := Fixture.create_ally(game, WITHIN_SENSORS)
	await press_declining_every_move()
	assert_eq(watcher.kinds(&'move_tile').size(), 1, 'fixture: the reticle was raised.')
	assert_eq(ally.tile(), WITHIN_SENSORS, 'Declined: no move.')
	assert_eq(ally.core.current.reactions, 1, 'And the reaction point is kept.')
	assert_true(UnitCondition.has_buff(hazard, Fixture.DGUTM_ACTIVE), 'The second sentence still happens.')

# ---------------------------------------------------------------- the immunity aura

func test_the_hazard_and_an_adjacent_ally_become_immune_and_others_do_not():
	var near := Fixture.create_ally(game, ADJACENT)
	var far := Fixture.create_ally(game, TWO_OUT + Vector2i(0, 3))
	var drone := Fixture.create_drone(game, Vector2i(5, 6))
	await press_declining_every_move()
	assert_true(immune(hazard), 'The Hazard is immune.')
	assert_true(immune(near), 'An adjacent ally is immune.')
	assert_false(immune(far), 'One further out is not.')
	assert_true(immune(drone), '"allied characters": a drone is one (ruling 2026-09-27) and is adjacent.')
	assert_false(immune(hostile), 'Nor a hostile.')

func test_nothing_is_immune_before_the_press():
	var near := Fixture.create_ally(game, ADJACENT)
	assert_false(immune(hazard), 'The aura is off until the switch.')
	assert_false(immune(near), 'For everyone.')

func test_the_hazard_refuses_knockback_and_prone_for_the_rest_of_the_scene():
	await press_declining_every_move()
	assert_false(await knock_back(hazard), 'Knocked back: refused.')
	assert_false(await pull(hazard), 'Pulled: refused.')
	SpecFactory.apply(hazard, Lancer.STATUS.PRONE)
	assert_false(hazard.has_status(Lancer.STATUS.PRONE), 'Knocked Prone: refused.')
	await Fixture.cycle_turn(game, hazard)
	await Fixture.cycle_turn(game, hazard)
	assert_true(immune(hazard), 'Still immune two turns later - "for the rest of the scene".')

func test_an_adjacent_ally_refuses_both_and_loses_it_two_tiles_away():
	var ally := Fixture.create_ally(game, ADJACENT)
	await press_declining_every_move()
	assert_false(await knock_back(ally), 'The adjacent ally refuses knockback.')
	SpecFactory.apply(ally, Lancer.STATUS.PRONE)
	assert_false(ally.has_status(Lancer.STATUS.PRONE), 'And Prone.')
	Fixture.step(ally, TWO_OUT)
	assert_false(immune(ally), 'Two tiles away the aura lets go.')
	assert_true(await knock_back(ally), 'And it can be knocked back again.')
	SpecFactory.apply(ally, Lancer.STATUS.PRONE)
	assert_true(ally.has_status(Lancer.STATUS.PRONE), 'And knocked Prone.')

func test_an_ally_that_walks_in_becomes_immune():
	var ally := Fixture.create_ally(game, TWO_OUT)
	await press_declining_every_move()
	assert_false(immune(ally), 'fixture: out of the aura.')
	Fixture.step(ally, ADJACENT)
	assert_true(immune(ally), 'Walking in: immune.')

func test_a_voluntary_move_is_still_allowed():
	await press_declining_every_move()
	assert_true(await may_move(hazard), 'A "may move" on the Hazard is not a push - it still moves.')

func test_control_without_the_press_the_hazard_is_knocked_back():
	assert_true(await knock_back(hazard), 'CONTROL: the same knockback moves an unprotected Hazard.')
