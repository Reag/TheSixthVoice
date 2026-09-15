# The shared Subutai spec fixture (SP1 Task 1).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as mk2_fixture.gd does:
# everything except create_<frame>() is frame-agnostic, and duplicating ~60 lines per frame is what
# the delegation exists to stop.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'mt_juggernaut_drive') stops finding anything. No Subutai spec writes to the
# frame's stats, so there is nothing to isolate from.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_subutai'

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Subutai with its traits' passive buffs applied, and the map's tile index told it is size 2.
##
## THE RE-TRACKING LINE IS LOAD-BEARING (SP2, the recentre probe). SpecFactory.create_unit adds the
## unit to the map at SIZE 1 - the dummy Everest's size - and only full_repair() below grows it to
## the frame's size 2. MapState.unit_tiles is rebuilt only when map_bus.update_unit_tile_tracking
## fires (map_state.gd:352), which nothing in that sequence does, so without this line the map
## indexes the Subutai at its anchor tile ALONE: any AoE lookup through get_all_units_at_tiles
## (the whole attack pipeline, action_attack.gd:164) misses it on its other three tiles, and a
## Line that reaches its near edge finds nobody there. SP1's Drive specs never noticed because a
## Drive moves the unit, and UnitTile.move_to re-tracks (unit_tile.gd:12-19).
static func create_subutai(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

static func create_dummy(
	game:Gamemaster, tile:Vector2i, evasion:int, faction:Faction.SIDE = Faction.AI_ENEMY
) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, faction)

## A friendly CHARACTER, for Juggernaut Drive. Task 4 aims the Drive's lines at these; the Drive
## reads allies off map.get_all_characters(), so a deployable will not do.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## A friendly DEPLOYABLE (the vanilla Jericho cover), for the other half of that same distinction: a
## unit the Drive can see and is allied to, which map.get_all_characters() must nevertheless not
## return. Same statblock as test_heaer.gd's cover - 10 HP, no armor, evasion 10 - since nothing here
## ever shoots it.
static func create_allied_deployable(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 10, 0, 10, Faction.PLAYER)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
