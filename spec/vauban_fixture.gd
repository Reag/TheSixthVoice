# The shared Vauban spec fixture (SP1 Task 1).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as mk2_fixture.gd,
# subutai_fixture.gd, myconid_fixture.gd and maidens_blush_fixture.gd do: everything except
# create_<frame>() and this frame's own terrain helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'mt_sap') stops finding anything. No Vauban spec writes to the frame's stats.
#
# THE GAMEMASTER IS THE SHARED ONE, which matters beyond the 2.65x it bought: the re-use branch of
# SpecFactory.setup_gamemaster builds a CampaignCore and hangs it on the map (spec_factory.gd:47-48),
# and the fresh branch returns before reaching those two lines. EventService.remove_unit_from_game
# dereferences map.campaign_core with no guard (event_service.gd:80), so on a fresh gamemaster the
# first death in a test throws before unit.remove_from_game(), leaving a corpse that still answers
# is_valid(). test_gravity_well.gd and test_terrain.gd both kill a unit on purpose.
#
# NO SIZE RE-TRACKING. The Myconid's fixture ends create_myconid with UnitTile.move_to because that
# frame is size 2 and SpecFactory.create_unit adds every unit at size 1. The Vauban IS size 1, so the
# line would be a no-op that reads as load-bearing. Deliberately absent.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_vauban'
const BREACH_ID := &'mt_solfataric_breach'
const SAP_ID := &'mt_sap'
const GRAVITY_WELL_ID := &'mt_gravity_well'

## EARTH SHAKER GRAV-GEN, the core system (SP2). One Kit carrying two pressables - the protocol and
## MASTICATION OF THE MAAR - plus the crater frame the second one lays.
const CORE_ID := &'cp_earth_shaker_grav_gen'
const PROTOCOL_ID := &'action_grav_amped_interference'
const MAAR_ACTION_ID := &'action_mastication_of_the_maar'
const MAAR_FRAME_ID := &'dep_maar'

## The plain vanilla rifle every Fitzgerald spec uses. Not melee - its weapon_type is unset, so it is
## the archetype default, RIFLE (3, action_attack_weapon.gd:12). It carries NO accuracy modifier, so
## an attack with it pops a d20 and nothing else off Dice.CHEAT_ROLL_QUEUE.
const RANGED_ID := &'mw_assault_rifle'

## A vanilla TECH attack, and it needs no equipping: ms_fragment_signal is in every player mech's
## basic loadout (content/gear/basic/basic_loadout_mech_player.tres) and its single action is an
## ActionAttackTech (content/gear/basic/ms_fragment_signal.tres). Gravity Well's buff refuses
## anything that is not an ActionAttackWeapon, and this is the negative control for that clause.
const TECH_ID := &'ms_fragment_signal'

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Vauban with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own default
## gives us and which every hostile/ally relation in the trait specs depends on.
static func create_vauban(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. Defaults to evasion 10 ("only hit when we say"), the
## value test_hole_puncher.gd chose for the same reason.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER. Speed 4 as well, so a four-step standard move exactly spends it -
## which is what test_sap.gd's multi-entry cases are built on, and what the probe measured with.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	var hostile := create_dummy(game, tile, evasion)
	hostile.core.frame.stat.speed = 4
	hostile.core.full_repair()
	return hostile

## A friendly character, for the cases that need somebody who is not an enemy.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## A hostile OBJECT - a Jericho cover on the enemy side.
##
## THE POINT IS THAT IT IS NOT A CHARACTER. Frame.ENTITY.OBJECT makes Unit.is_character() false
## (unit.gd:116 -> frame.gd:101), so anything keyed on "hostile Characters" - which is the Maar's
## target filter, design ruling 8 - must let this through even though it IS hostile. A hostile MECH
## and a friendly object each fail to separate the two clauses on their own; this is the case that
## does. Numbers are test_heaer.gd's (10 HP, no armor, evasion 10); none of them matter to a filter
## that only asks what side it is on and whether it is a character.
static func create_hostile_object(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 10, 0, 10, Faction.AI_ENEMY)

## An allied DRONE: a character that is not a mech.
##
## Built by flipping is_drone on an ALREADY-ISOLATED frame rather than by loading a vanilla drone
## frame (dep_orochi_guardian_drone and friends), and that is deliberate. FitzgeraldFixture.create_dummy
## calls FrameIsolation.isolate_frame, which deep-duplicates the Frame AND its Statblock - so this
## write cannot reach the shared ContentLibrary copy the way a write to a loaded drone frame would.
## It also keeps the unit's stats identical to every other dummy in the spec, so the only thing that
## differs between the drone case and the ally case is the one flag under test.
##
## is_mech() is `is_character() and not is_drone and not is_pilot` (unit.gd:118 -> frame.gd:101), and
## the frame's compcon_id is still the knockoff Everest's `mf_...`, so LoadoutCore's basic-gear branch
## (loadout_core.gd:177-186) still hands it the PLAYER loadout - which is what full_repair() below
## rebuilds.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Put the rifle on a unit as a SYSTEM. Idempotent, so a spec may call it in before_each and again in
## a test.
static func equip_ranged(unit:Unit) -> void:
	if GearCore.is_valid(unit.get_gear(RANGED_ID)): return
	unit.core.equip_system(RANGED_ID)
	SpecFactory.apply_passive_buffs(unit)

## Run the tracking pass: rebuild every unit's dynamic terrain and re-evaluate every aura.
##
## THIS IS WHAT HANGS AN AURA BUFF. PassiveAura.update_unit is called from
## UnitTile.update_tracking_and_statuses (unit_tile.gd:24) and from nowhere a spec reaches otherwise;
## SpecFactory.apply_passive_buffs only marks the gear's aura ACTIVE (unit_condition.gd:878-880), it
## does not place anything. So a spec that creates a Vauban and an adjacent ally and then asserts the
## ally holds buff_gravity_well needs this call in between - without it the assertion fails for a
## reason that has nothing to do with the trait.
##
## It is also what rebuilds MapState.dynamic_terrain from every PassiveTerrainZone on the map
## (map_state.gd:376-378) and then recalculates the merged surface (:403-413), which is what
## test_terrain.gd's gated-zone and lay cases read back.
static func track(game:Gamemaster) -> void:
	UnitTile.update_tracking_and_statuses(game.map)

## The TerrainBlockData every difficult-ground case in this frame uses: difficult and nothing else.
##
## Built fresh per call rather than cached in a static, because SpecFactory.set_terrain stores the
## SAME instance at every listed tile and MapState.calculate_surface_merged_terrain_and_height_at
## merges into duplicates - a shared static that something merged into would leak between tests.
static func difficult_block() -> TerrainBlockData:
	var block := TerrainBlockData.new()
	block.difficult_terrain = true
	return block

## Make exactly `tiles` difficult ground, and everything else clean.
##
## READ THAT AGAIN: this loops the WHOLE MAP and writes either the block or TerrainBlockData.BLANK
## at every tile - so calling this twice does not add a second patch, it REPLACES the first. Every
## caller that wants two separate patches (test_sap.gd's in-out-in case) passes both in one call.
## The name says "lay" and not "add" for that reason.
##
## NOT SpecFactory.set_terrain (spec_factory.gd:166-172), DELIBERATELY, though it has the exact same
## whole-map-replace shape and this fixture's first draft called it verbatim. That helper writes
## map.ground_terrain, and get_surface_terrain_at - the accessor below, and the one the pathfinder
## itself charges difficult terrain through (pathfinder.gd:80,95) - never reads ground_terrain.
## surface_terrain is merged from ground_surface_terrain plus dynamic terrain only
## (map_state.gd:474-478: calculate_surface_merged_terrain_and_height_at calls
## merge_in(get_ground_surface_terrain_at(tile)), which reads ground_surface_terrain, and two
## base_merge_in(get_dynamic_terrain_at(...)) calls - ground_terrain appears nowhere in the
## function). MEASURED here 2026-09-18 exactly as Reag-ThyHubris/spec/test_earthstep.gd's own
## _make_rough already recorded: with set_terrain the same tile reports ground=true, surface=false,
## and test_the_fixture_lays_difficult_terrain_the_way_its_callers_assume could never pass - the
## first full run of this file went 16/17 on exactly that. Writing ground_surface_terrain directly
## and recalculating is that file's own established fix, adopted here rather than reinvented.
##
## Vanilla's OWN assertion shape is game.map.get_surface_terrain_at(tile).is_difficult()
## (test/gear/test_cp_magnetic_field_projector.gd:24, there produced by a live PassiveTerrainZone
## rather than this helper); so does every spec in this frame.
static func lay_difficult(game:Gamemaster, tiles:Array[Vector2i]) -> void:
	var block := difficult_block()
	for y:int in game.map.size.y:
		for x:int in game.map.size.x:
			var tile:Vector2i = Vector2i(x, y)
			game.map.ground_surface_terrain[tile] = block if tile in tiles else TerrainBlockData.BLANK
			game.map.calculate_surface_merged_terrain_and_height_at(tile)

## Press GRAV-AMPED INTERFERENCE, turn and all.
##
## THE TURN IS NOT DECORATION: unit_action.gd:144 refuses a protocol unless
## unit.state.is_using_protocols, which only event_turn_start opens (the same gate
## MyconidFixture.fungal_network opens for the same reason). Without it the press fails with
## "[ Gear not available ] reason : protocol" and every assertion downstream reads as broken content.
##
## SpecFactory.use(game, unit, kit_id, action_id) rather than use_solo(): this Kit carries TWO
## pressables by the end of SP2, and use_solo fires the Kit's FIRST action whatever it is.
##
## CALL THIS LAST. GearCore.short_repair clears gear state (gear_core.gd:143-150) and
## SpecFactory.apply_passive_buffs calls full_repair, so equipping anything after the press silently
## puts the field out again.
static func press_protocol(game:Gamemaster, vauban:Unit) -> void:
	await open_turn(game, vauban)
	await SpecFactory.use(game, vauban, CORE_ID, PROTOCOL_ID)

## The number a save forced by `unit` has to beat - the FORCER's save target, which is what
## event_unit_save reads (event_unit_save.gd:41-43), not the saver's.
static func save_target_of(unit:Unit) -> int:
	return unit.get_save_target() if Unit.is_valid(unit) else 10

## A real EventCore with a real, VALID EventBlock, which a save has to be run inside.
##
## UnitHasecheck.make_*_save routes through run_save_event, which calls event.execute_events - a no-op
## unless event.block is a real, is_block_valid() EventBlock (event_core.gd:77-81, :48). Lifted from
## this mod's own test_weak_computer.gd, which lifted it from test/gear/test_ms_stable_structure.gd.
## It needs the GutTest itself, for add_child_autoqfree.
static func save_event(test:GutTest) -> EventCore:
	var event := SpecFactory.dummy_event()
	event.block = EventBlock.create_multiple([event])
	test.add_child_autoqfree(event.block)
	return event

## A forcer named the way every vanilla save-forcing action in content/ names one: unit AND gear AND
## action.
##
## ALL THREE OR NOTHING, and this is not tidiness. UnitHasecheck.roll_check copies the forcer into the
## buff context only `if SpecificAction.is_valid(forcing_action)` (unit_hasecheck.gd:180), and
## SpecificAction.is_valid demands all three (specific_action.gd:16-23). Force a save with a bare Unit
## and the saver's TO.SAVE buffs are asked about a context with NO forcer in it - which reads in a log
## as "failed a Hull save from ?" and in a spec as "save buffs do not work". Measured by the SP2 probe.
##
## ms_fragment_signal is the default gear for the same reason every Vauban spec uses it as its tech
## control: it is in every player mech's basic loadout, so any unit can name it without equipping
## anything.
static func forcer(unit:Unit, gear_id:StringName = TECH_ID, action_id:StringName = &'') -> SpecificAction:
	return SpecificAction.from_id(unit, gear_id, action_id)

## Force a Hull save on `saver` in `forcing`'s name, through the same production call every vanilla
## save-forcing action makes. Returns whether it passed.
static func force_hull_save(test:GutTest, saver:Unit, forcing:SpecificAction) -> bool:
	return await UnitHasecheck.make_hull_save(save_event(test), saver, forcing)

## Queue a d20 and then a tail of sixes, so a save resolves to exactly what the caller intends and
## nothing downstream drains the FIFO into real RNG (test_draw_fire.gd's shape).
##
## WHY THE TAIL MATTERS HERE SPECIFICALLY: a -1 accuracy buff makes roll_check pop a SECOND die
## (Dice.roll_d6_accuracy rolls one d6 and negates it for -1, dice.gd:86-88), so the buffed and
## unbuffed paths through the same save consume different numbers of entries. A short queue would
## make the two cases differ for a reason that has nothing to do with the buff.
static func queue_save_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var queue:Array[int] = [d20]
	for i:int in 60: queue.append(6)
	Dice.CHEAT_ROLL_QUEUE.assign(queue)
