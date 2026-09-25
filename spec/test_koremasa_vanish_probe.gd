# PROBE: VANISH WHILE RIDING (Koremasa SP3, design 3.0, ruling 28). Kept until the frame close, as the
# spike-7 probe is: test_phase_cloud.gd's riding tests cover its behaviour through Vanish itself, but
# the unstacked shape's tile set equalling a real dismount's is asserted only here.
#
# The question: in ONE activation, can the ride be ended (koremasa_ride.gd's dismount, no relocation)
# and a PREVENTABLE teleport then be pathfound from the Koremasa's own tile - which is still the
# mount's anchor tile at that moment? Katamari.dettach_units -> validate_attachments erases the
# emptied attachment key and update_cached_values_and_token recomputes stackup_order synchronously
# (unit_battle_state.gd:195-216), so the reading is YES; this measures it.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_koremasa_vanish_probe.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const Ride := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_koremasa/cp_overdrive_exploitation_sequences/koremasa_ride.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const KOREMASA_TILE := Vector2i(3, 3)
const MOUNT_TILE := Vector2i(7, 3) ## size 2: (7,3) (8,3) (7,4) (8,4)
const LANDING := Vector2i(6, 3)
const DESTINATION := Vector2i(11, 6) ## within 5 of the mount's anchor, clear of everything

var game:Gamemaster
var responder
var koremasa:Unit
var mount:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	mount = Fixture.create_mount(game, MOUNT_TILE)
	responder.chosen_move_tile = LANDING
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)
	responder.chosen_move_tile = Tile.INVALID

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_move_tile = Tile.INVALID

## Dismount then pathfind, both on one event, the way Vanish's activate will.
func dismount_then_pathfind(event:EventCore) -> Pathfinder:
	Ride.dismount(event, koremasa, Fixture.core(koremasa), false)
	var tiles := Teleport.candidate_tiles(koremasa, 5, true)
	gut.p('candidates after dismount: %d; stackup_order %d; tile %s; footprint %s' % [
		tiles.size(), koremasa.state.stackup_order, koremasa.tile(), koremasa.occupied_tiles()])
	assert_false(tiles.is_empty(), 'MEASURE: the candidate set is non-empty straight after the dismount.')
	assert_true(tiles.has(DESTINATION), 'MEASURE: the destination is a candidate.')
	var pathfinder:Pathfinder = await Teleport.pathfinder(koremasa, tiles)
	return pathfinder

func test_the_fixture_rides():
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: riding.')
	assert_gt(koremasa.state.stackup_order, 0, 'fixture: the Koremasa is a rider.')

func test_the_dismount_is_visible_to_the_pathfinder_at_once():
	var event := SpecFactory.dummy_event()
	var pathfinder := await dismount_then_pathfind(event)
	assert_eq(koremasa.state.stackup_order, -1, 'MEASURE: out of the stack, synchronously.')
	assert_eq(koremasa.occupied_tiles().size(), 1, 'MEASURE: its own footprint again, synchronously.')
	assert_not_null(pathfinder, 'MEASURE: a pathfinder was built.')
	if pathfinder == null: return
	assert_true(pathfinder.is_reachable(DESTINATION), 'MEASURE: the destination is reachable in the same activation.')

func test_move_along_lands_the_koremasa_alone_and_leaves_the_mount():
	var event := SpecFactory.dummy_event()
	var pathfinder := await dismount_then_pathfind(event)
	if pathfinder == null or not pathfinder.is_reachable(DESTINATION):
		fail_test('no path to measure')
		return
	var plan := CompconPlan.create([DESTINATION], pathfinder.path_to(DESTINATION))
	var move:EventCore = await Teleport.move_along(null, koremasa, pathfinder, plan)
	assert_not_null(move, 'MEASURE: a move ran.')
	assert_eq(koremasa.tile(), DESTINATION, 'MEASURE: the Koremasa landed where it chose.')
	assert_eq(koremasa.state.stackup_order, -1, 'MEASURE: still out of any stack.')
	assert_eq(koremasa.occupied_tiles(), [DESTINATION] as Array[Vector2i], 'MEASURE: its own one-tile footprint.')
	assert_eq(mount.tile(), MOUNT_TILE, 'MEASURE: the mount did not move.')
	assert_false(UnitCondition.is_in_stackup(mount), 'MEASURE: the mount is out of the stack.')
	assert_false(mount.has_status(Lancer.STATUS.IMPAIRED), 'MEASURE: the ride chip (and its Impaired) is gone.')
	assert_eq(mount.occupied_tiles().size(), 4, 'MEASURE: the mount keeps its whole footprint.')

## RULING 28's "a declined teleport leaves it mounted" means the reticle has to come BEFORE the
## dismount. The Mule Harness climb-off builds its pathfinder with the rider's stackup_order briefly
## set to -1 (action_mule_harness_climb_off.gd); a teleport also needs the rider's OWN footprint, so
## occupying_size is flipped with it. Measure that this "virtual" shape offers exactly what a real
## dismount would, leaves the ride intact, and that its pathfinder still lands the move afterwards.
func unstacked_shape_tiles_and_pathfinder() -> Array:
	var old_order := koremasa.state.stackup_order
	var old_size := koremasa.state.occupying_size
	koremasa.state.stackup_order = -1
	koremasa.state.occupying_size = koremasa.core.get_size()
	var tiles := Teleport.candidate_tiles(koremasa, 5, true)
	var pathfinder:Pathfinder = await Teleport.pathfinder(koremasa, tiles)
	koremasa.state.stackup_order = old_order
	koremasa.state.occupying_size = old_size
	return [tiles, pathfinder]

func test_the_unstacked_shape_offers_what_a_real_dismount_would():
	var pair := await unstacked_shape_tiles_and_pathfinder()
	var virtual_tiles:Array[Vector2i] = pair[0]
	assert_true(Fixture.is_riding(koremasa, mount), 'MEASURE: still riding after the virtual computation.')
	assert_eq(koremasa.occupied_tiles().size(), 4, 'MEASURE: the rider still spans the mount.')
	Ride.dismount(SpecFactory.dummy_event(), koremasa, Fixture.core(koremasa), false)
	var real_tiles := Teleport.candidate_tiles(koremasa, 5, true)
	virtual_tiles.sort()
	real_tiles.sort()
	gut.p('virtual %d, real %d' % [virtual_tiles.size(), real_tiles.size()])
	assert_eq(virtual_tiles, real_tiles, 'MEASURE: the virtual shape offers exactly the real dismount\'s set.')

func test_the_unstacked_pathfinder_moves_the_koremasa_after_a_real_dismount():
	var pair := await unstacked_shape_tiles_and_pathfinder()
	var pathfinder:Pathfinder = pair[1]
	assert_true(pathfinder != null and pathfinder.is_reachable(DESTINATION), 'MEASURE: reachable while still mounted.')
	if pathfinder == null or not pathfinder.is_reachable(DESTINATION): return
	Ride.dismount(SpecFactory.dummy_event(), koremasa, Fixture.core(koremasa), false)
	var plan := CompconPlan.create([DESTINATION], pathfinder.path_to(DESTINATION))
	await Teleport.move_along(null, koremasa, pathfinder, plan)
	assert_eq(koremasa.tile(), DESTINATION, 'MEASURE: the pre-built pathfinder lands the move.')
	assert_eq(mount.tile(), MOUNT_TILE, 'MEASURE: the mount stayed.')
	assert_eq(koremasa.state.stackup_order, -1, 'MEASURE: out of the stack.')

## The control: WITHOUT the dismount, a rider has no movement of its own (pathfinder.gd:343) - so the
## dismount really is what the teleport depends on, not something the teleport would do anyway.
func test_control_without_the_dismount_the_rider_cannot_teleport():
	var tiles := Teleport.candidate_tiles(koremasa, 5, true)
	var pathfinder:Pathfinder = await Teleport.pathfinder(koremasa, tiles)
	var reachable := pathfinder != null and pathfinder.is_reachable(DESTINATION)
	gut.p('rider without dismount: candidates %d, reachable %s' % [tiles.size(), reachable])
	assert_false(reachable, 'CONTROL: still riding, the destination is not reachable.')
