# The shared M/K2 spec fixture (SP1 Task 1).
#
# DELEGATES TO fitzgerald_fixture.gd RATHER THAN COPYING IT. Everything that file does except
# create_fitzgerald() is frame-agnostic - the map with forbidden interiors enabled, the 200 HP
# punching bag, the guarded turn open - and duplicating ~60 lines per frame is exactly what SP2's
# Task 0 extraction existed to stop. The frame id is the only real difference, so it is the only
# thing this file adds.
#
# Generalising fitzgerald_fixture.create_fitzgerald() into a create_frame(frame_id) was the other
# option and was NOT taken: its three existing call sites are covered by 200 green tests, and a
# no-behaviour-change refactor of them is not SP1's job. If a third frame arrives, do it then.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_mk2'

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## An M/K2 with its traits' passive buffs applied.
##
## NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
## duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
## derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
## unit.get_gear(&'mt_rapid_stabilization_jets') stops finding anything. No M/K2 spec writes to the
## frame's stats, so there is nothing to isolate from.
static func create_mk2(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

static func create_dummy(
	game:Gamemaster, tile:Vector2i, evasion:int, faction:Faction.SIDE = Faction.AI_ENEMY
) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, faction)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
