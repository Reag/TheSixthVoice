# The shared Myconid spec fixture (SP1 Task 2).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as mk2_fixture.gd and
# subutai_fixture.gd do: everything except create_<frame>() is frame-agnostic, and duplicating ~60
# lines per frame is what the delegation exists to stop. This is the FOURTH copy of the same
# four-line create_<frame>() body; mk2_fixture.gd's header already records that the extraction into
# a create_frame(frame_id) is open work for whoever next has reason to touch all of them, and adding
# a frame is not that occasion.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'mt_halo') stops finding anything. No Myconid spec writes to the frame's stats, so
# there is nothing to isolate from.
#
# THE GAMEMASTER IS THE SHARED ONE (87694e6), which matters here beyond the 2.65x it bought: the
# re-use branch of SpecFactory.setup_gamemaster builds a CampaignCore and hangs it on the map
# (spec_factory.gd:48-49), and the fresh branch returns at :32 before reaching those two lines.
# EventService.remove_unit_from_game dereferences map.campaign_core with no guard
# (event_service.gd:80), so on a fresh gamemaster the first death in a test throws
# "Nonexistent function 'get_lancer_by_id' in base 'Nil'" four lines before unit.remove_from_game(),
# leaving a corpse that still answers is_valid(). No Myconid spec hand-builds a CampaignCore; the
# ones in test_heaer.gd and test_blasting_powder.gd predate that change and are now redundant.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_myconid'
const SYMBIOSIS_ID := &'mt_symbiosis'
const HALO_ID := &'mt_halo'
const CORE_ID := &'cp_quietus_machines'
const PROTOCOL_ID := &'action_fungal_network'

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Myconid with its traits' passive buffs applied, and the map's tile index told it is size 2.
##
## THE RE-TRACKING LINE IS LOAD-BEARING, and it is move_to rather than
## update_tracking_and_statuses alone (the Subutai's SP2 recentre bug and its frame-close fix wave 2).
## SpecFactory.create_unit adds the unit to the map at SIZE 1 - the dummy Everest's size - and only
## full_repair() below grows it to the frame's size 2. MapState.unit_tiles is rebuilt only when
## map_bus.update_unit_tile_tracking fires (map_state.gd:352), which nothing in that sequence does,
## so without this line the map indexes the Myconid at its anchor tile ALONE and every range lookup
## through the tile index misses it on the other three. The rebuild also READS the cache it is
## supposed to be catching up with (map_state.gd:379 iterates unit.occupied_tiles(), and unit.gd:206
## hands back the cached state.occupied_tiles), so the cache has to be refreshed BEFORE the rebuild -
## which is exactly the order UnitTile.move_to uses (unit_tile.gd:10-13).
static func create_myconid(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached footprint, THEN rebuild the map's tile index
	return unit

static func create_dummy(
	game:Gamemaster, tile:Vector2i, evasion:int, faction:Faction.SIDE = Faction.AI_ENEMY
) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, faction)

## A friendly CHARACTER, for Halo. Halo reads its candidates off map.get_all_characters(), so a
## deployable will not do - and the 200 HP punching bag underneath means an ally can be shot at
## without ending the scene.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Open the Myconid's turn and press FUNGAL NETWORK, so both of QUIETUS MACHINES' PassiveAuras go
## live (SP2 Task 3). Lifted out of test_fungal_network.gd's own press_protocol(), which now
## delegates here (SP2 Task 5) rather than duplicating it.
##
## THE TURN MUST BE OPEN FIRST, and not merely for tidiness: unit_action.gd:119 refuses a PROTOCOL
## unless unit.state.is_using_protocols, which only event_turn_start opens. Without it every caller
## of this function would fail with "Gear not available / reason : protocol" and read as broken
## content rather than a missing turn. Grep a red run's output for `Gear not available` before
## suspecting the .tres; the reason string names the exact gate.
##
## SpecFactory.use(game, unit, kit_id, action_id) rather than use_solo(): cp_quietus_machines could
## grow a second action the way cp_siege_engine did, and this mirrors SubutaiFixture.gather_round's
## shape rather than depending on the action count staying at one.
static func fungal_network(game:Gamemaster, myconid:Unit) -> void:
	await open_turn(game, myconid)
	await SpecFactory.use(game, myconid, CORE_ID, PROTOCOL_ID)

## A hostile NON-character: the vanilla Jericho cover. Fungal Network's hostile aura sets
## applies_only_to_characters, and this is the only way to prove that clause does anything - a
## deployable standing in the cloud must be untouched (passive_aura.gd:73).
##
## The numbers are this frame's, not the Fitzgerald's: 200 HP so nothing here can kill it and end a
## scene, 0 armor so a damage assertion is the weapon's number, and evasion 10 to match create_dummy.
static func create_deployable(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 200, 0, 10, Faction.AI_ENEMY)

## Give a unit a pilot Grit, which is what Halo grants Overshield equal to.
##
## PilotCore.get_grit() is Util.half(license_level), and Util.half is CEILI (util.gd:14-15) - the
## engine's own glossary row for lancer.term.grit says "rounded up" too. So licence level 0 is the
## only Grit 0, licence level 1 and 2 are both Grit 1, 3 and 4 are Grit 2. SpecFactory.create_unit
## hands out a PilotCore with license_level 0 (pilot_core.gd:26), so a fixture unit has Grit 0 until
## this is called - which is what makes the "Grit 0, Halo is not offered" case the default rather
## than something a test has to arrange.
##
## Takes the GRIT the caller wants and derives the level, so a spec never has to do the rounding in
## its head; asserted against get_grit() by the helper's own caller where it matters.
static func set_grit(unit:Unit, grit:int) -> void:
	if not Unit.is_valid(unit) or not PilotCore.is_valid(unit.core.pilot): return
	unit.core.pilot.license_level = grit * 2
