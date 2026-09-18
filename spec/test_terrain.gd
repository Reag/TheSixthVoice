# The TERRAIN helper (Vauban SP1 Task 2), born with Sap and Gravity Well and FROZEN when SP1 ships.
#
# Roadmap §4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Two later frames consume it -
# Leoleth and the Shackleton - and SP2's Mastication of the Maar is its first in-frame consumer of
# lay(), so a rename here is three frames' worth of churn.
# test_the_frozen_interface_pins_these_four_signatures is the guard, and it pins the whole signature -
# argument order, names, types, default count and return type - not only that a name survives.
#
# WHAT THE HELPER IS FOR. Difficult terrain is a FACTIONLESS property of a map tile
# (terrain_data.gd:43, merged by OR at :64), and there are three different accessors on MapState that
# sound like they answer "is this difficult" and do not (get_ground_terrain_at,
# get_ground_surface_terrain_at, get_dynamic_terrain_at). get_surface_terrain_at (map_state.gd:140) is
# the one that includes unit-projected zones, and it is the only one any consumer should use. That
# choice, the whole-footprint reads around it, and the spawn recipe for laid terrain are written once
# here instead of per frame.
#
# THIS FILE ASSERTS AGAINST VANILLA UNITS AND IN-CODE RESOURCES ONLY. The Vauban's traits do not exist
# yet at this task, and the helper is frame-agnostic by construction; test_sap.gd and
# test_gravity_well.gd are what exercise it from inside real content.
#
# NOTHING HERE IS A .tres UNDER spec/. The marker frame and both terrain-zone Kits below are built in
# code. A hand-written .tres that references another .tres by path with no uid is silently dropped by
# the loader (the lancer-tactics-gdscript skill's UID trap), and nothing under spec/ is scanned into
# ContentLibrary in the first place - so a resource file here would be a fixture that looks like
# content and is neither.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_terrain.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')
const GatedZone := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/passive_gated_terrain_zone.gd')

## The blank sprite every vanilla marker deployable uses (dep_apocalypse_difficult.tres). A frame with
## no sprite at all is not a shape any vanilla spawn takes, so the in-code marker below borrows this
## one rather than finding out.
const BLANK_SPRITE := preload('res://assets/frames/shared/blank.png')

const CLEAN := Vector2i(2, 2)
const FIELD_A := Vector2i(5, 4)
const FIELD_B := Vector2i(6, 4)
const WEST_OF_FIELD := Vector2i(4, 4)
const EAST_OF_FIELD := Vector2i(7, 4)
const OFF_MAP := Vector2i(-1, -1)

const LAYER_TILE := Vector2i(2, 6)
const MAAR_TILE := Vector2i(10, 4)

const GATE_KEY := &'spec_terrain_lit'
const GATED_KIT := &'mt_spec_gated_zone'
const MARKER_FRAME := &'dep_spec_terrain_marker'
const MARKER_KIT := &'mt_spec_marker_terrain'

# The frozen contract itself (design §1.2, rulings row 2026-09-18). Read off
# Script.get_script_method_list()'s own dictionary shape (Godot 4.7): each entry is
# {name, args, default_args, flags, id, return}; each arg and the return are property-info dicts
# {name, class_name, type, hint, hint_string, usage}. `type` is a Variant.Type and for a TYPE_OBJECT
# argument or return, `class_name` carries the script's class as a StringName. The named constants
# are used rather than the integers, so this file does not have to hard-code Godot's enum ordering.
#
# `defaults` is zero for all four, and that is part of the contract: every consumer passes every
# argument, and a default quietly grown later would let a caller omit the map or the frame.
#
# lay() IS A COROUTINE and still reports its declared return type here - Teleport.move is the same
# shape (declared -> EventCore, contains await) and test_teleport.gd pins it green today.
const FROZEN_SIGNATURES := {
	is_difficult = {
		args = [['map', TYPE_OBJECT, &'MapState'], ['tile', TYPE_VECTOR2I, &'']],
		defaults = 0, return_type = TYPE_BOOL, return_class = &'',
	},
	is_unit_in_difficult = {
		args = [['unit', TYPE_OBJECT, &'Unit']],
		defaults = 0, return_type = TYPE_BOOL, return_class = &'',
	},
	is_entering_difficult = {
		args = [['unit', TYPE_OBJECT, &'Unit'], ['next_anchor', TYPE_VECTOR2I, &'']],
		defaults = 0, return_type = TYPE_BOOL, return_class = &'',
	},
	lay = {
		args = [
			['activation', TYPE_OBJECT, &'EventCore'],
			['specific', TYPE_OBJECT, &'SpecificAction'],
			['center', TYPE_VECTOR2I, &''],
			['deployable', TYPE_OBJECT, &'Frame'],
		],
		defaults = 0, return_type = TYPE_OBJECT, return_class = &'Unit',
	},
}

var game:Gamemaster

func before_each() -> void:
	game = VaubanFixture.create_game(self)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## A Kit carrying ONE PassiveGatedTerrainZone: Burst 1, height 1, difficult, gated on GATE_KEY.
func gated_kit() -> Kit:
	var terrain := TerrainData.new()
	terrain.difficult_terrain = true
	var zone:PassiveTerrainZone = GatedZone.new()
	zone.state_key = GATE_KEY
	zone.terrain_data = terrain
	zone.range_pattern = RangePattern.create(Lancer.AOE_TYPE.BURST, 1)
	zone.height = 1
	var kit := Kit.new()
	kit.compcon_id = GATED_KIT
	kit.is_trait = true
	kit.passives.append(zone)
	return kit

## The same shape with a PLAIN PassiveTerrainZone - no gate, always on. This is what the marker frame
## carries, and it is also the control that proves the gated one's darkness is the gate's doing.
func plain_terrain_kit() -> Kit:
	var terrain := TerrainData.new()
	terrain.difficult_terrain = true
	var zone := PassiveTerrainZone.new()
	zone.terrain_data = terrain
	zone.range_pattern = RangePattern.create(Lancer.AOE_TYPE.BURST, 1)
	zone.height = 1
	var kit := Kit.new()
	kit.compcon_id = MARKER_KIT
	kit.is_trait = true
	kit.passives.append(zone)
	return kit

## A MARKER deployable frame, built in code: non-obstructing, blank-sprited, carrying the plain zone.
##
## is_deactivated_on_owner_death = FALSE is the whole point of the survival test below, and it
## corrects design §1.2 - see this task's NOTE. With the export left at its `true` default,
## EventService.remove_unit_from_game queues event_unit_die on this marker the moment its owner dies
## (event_service.gd:56-63), and the terrain goes with it.
func marker_frame() -> Frame:
	var frame := Frame.create_dummy()
	frame.compcon_id = MARKER_FRAME
	frame.entity_type = Frame.ENTITY.MARKER
	frame.is_obstruction = false
	frame.is_deactivated_on_owner_death = false
	frame.sprites = [BLANK_SPRITE] as Array[Texture2D]
	frame.traits = [plain_terrain_kit()] as Array[Kit]
	return frame

## The install_recorder() idiom (test_draw_fire.gd, and the Vauban probe's own `install`):
## full_repair() is what rebuilds the loadout from the new Kit list, and the tracking pass is what
## turns a PassiveTerrainZone on that loadout into voxels on the map (map_state.gd:376-378).
func install(kit:Kit, on:Unit) -> GearCore:
	on.core.loadout.equipped_kits.append(kit)
	on.core.full_repair()
	VaubanFixture.track(game)
	return on.get_gear(kit.compcon_id)

## The 3x3 of tiles centred on `tile` - a size-1 unit's Burst 1 (aoe_calculator.gd:33-35 iterates
## range(-radius, center_size + radius), which for radius 1 and size 1 is -1, 0, 1 on both axes).
func burst_1(tile:Vector2i) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for x:int in [-1, 0, 1]:
		for y:int in [-1, 0, 1]: tiles.append(tile + Vector2i(x, y))
	return tiles

## BOTH READS, ON PURPOSE, and they are not redundant.
##
## The ENGINE's own read (vanilla's assertion shape, test_cp_magnetic_field_projector.gd:24) measures
## the zone and the spawn independently of anything we wrote - so a broken helper cannot make the
## gated-zone and lay cases pass by agreeing with itself.
##
## THE HELPER's read is what pins the accessor choice, and it is the ONLY place in this file that can.
## Every tile-property case here lays ground terrain through VaubanFixture.lay_difficult, which writes
## ground_surface_terrain - visible to get_surface_terrain_at AND get_ground_surface_terrain_at alike,
## so those cases cannot tell the two apart. A UNIT-PROJECTED zone lands in dynamic_terrain and is
## merged into surface_terrain only (map_state.gd:474-478), so it is invisible to every other
## accessor. Measured 2026-09-18: with only the engine read here, swapping is_difficult onto
## get_ground_surface_terrain_at left this whole file GREEN - the helper's entire reason for existing
## was unpinned. With both, that swap reddens exactly the three zone/spawn cases.
func assert_burst_is_difficult(tile:Vector2i, expected:bool, message:String) -> void:
	for burst_tile:Vector2i in burst_1(tile):
		assert_eq(game.map.get_surface_terrain_at(burst_tile).is_difficult(), expected,
			'%s (%s)' % [message, burst_tile])
		assert_eq(Terrain.is_difficult(game.map, burst_tile), expected,
			'%s, and the helper says so too (%s)' % [message, burst_tile])

# ---------------------------------------------------------------- the interface itself

func test_the_frozen_interface_pins_these_four_signatures():
	# Design §1.2 freezes these four when SP1 ships. This pins the FULL signature of each - argument
	# count, each argument's name and order, each argument's type, the default-argument count, and the
	# return type - not only that the name survives. A rename, a reordered parameter, a changed type
	# or a silently-grown default is three frames' worth of churn, and nothing else in the suite would
	# notice any of them until those frames are written.
	#
	# Deliberately does NOT fail if a FIFTH function is added: the freeze contract is "additions
	# allowed, reshapes not", and design §1.2 already names three candidates it deliberately did not
	# birth (a lifetime for laid terrain, a Burst 2 frame, "damage in").
	#
	# Through a Script-typed local, not Terrain.get_script_method_list() directly: GDScript reads a
	# preloaded script constant as a CLASS in a call position and refuses the call at parse time.
	var script:Script = Terrain
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'Terrain.%s survives.' % required)
		if not by_name.has(required): continue

		var entry:Dictionary = by_name[required]
		var expected:Dictionary = FROZEN_SIGNATURES[required]
		var expected_args:Array = expected.args

		assert_eq(entry.args.size(), expected_args.size(),
			'%s takes exactly %d argument(s).' % [required, expected_args.size()])
		for i:int in range(min(entry.args.size(), expected_args.size())):
			var actual_arg:Dictionary = entry.args[i]
			var expected_arg:Array = expected_args[i]
			assert_eq(actual_arg.name, expected_arg[0],
				'%s arg %d is named "%s".' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.type, expected_arg[1],
				'%s arg %d ("%s") has the frozen Variant.Type.' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.class_name, expected_arg[2],
				'%s arg %d ("%s") has the frozen class_name.' % [required, i, expected_arg[0]])

		# PINS `static`, NOT ONLY THE NAME (the Myconid frame close, finding 4). Every caller spells
		# Terrain.<fn>(...) on the preloaded script CONSTANT, never on an instance, and GDScript
		# refuses that at PARSE time if `static` is dropped - which is this whole file AND every trait
		# that preloads the helper going unparsable, with GUT logging 'Ignoring script ...' and
		# dropping them from the totals rather than failing them. A bitwise AND against the single bit,
		# as addons/gut/script_parser.gd tests it, so an unrelated future flag cannot fail this.
		assert_true((entry.flags & METHOD_FLAG_STATIC) != 0,
			'%s is still static - a caller spells it on the class, not an instance.' % required)
		assert_eq(entry.default_args.size(), expected.defaults,
			'%s takes exactly %d default argument(s).' % [required, expected.defaults])

		assert_eq(entry.return.type, expected.return_type,
			'%s has the frozen return Variant.Type.' % required)
		assert_eq(entry.return.class_name, expected.return_class,
			'%s has the frozen return class_name.' % required)

func test_the_gated_zone_is_a_terrain_zone_with_one_state_key_export():
	# The second half of the frozen interface, and it is an EXPORT rather than a function - so the
	# method-list pin above cannot see it. A .tres in SP2 will set this field by name
	# (state_key = &"grav_amped"), and a rename would leave that .tres setting nothing, silently: an
	# unknown property in a .tres is skipped, not an error.
	var zone = GatedZone.new()
	assert_true(zone is PassiveTerrainZone,
		'PassiveGatedTerrainZone extends PassiveTerrainZone, so map_state collects it like any other.')
	# get_script_property_list() is a method of SCRIPT, not of the instance (Object's own is
	# get_property_list) - so this reads it off a Script-typed local exactly as the method-list pin
	# above does, and for the same reason: a preloaded script constant in a call position is a CLASS.
	var script:Script = GatedZone
	var found := false
	for property:Dictionary in script.get_script_property_list():
		if property.name != 'state_key': continue
		found = true
		assert_eq(property.type, TYPE_STRING_NAME, 'state_key is a StringName.')
		assert_true((property.usage & PROPERTY_USAGE_STORAGE) != 0,
			'And it is stored, so a .tres can set it.')
	assert_true(found, 'PassiveGatedTerrainZone declares state_key.')
	assert_eq(zone.state_key, &'', 'It defaults to empty - an unconfigured zone is DARK, never lit.')

# ---------------------------------------------------------------- is_difficult

func test_is_difficult_reads_the_tile_property():
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B])
	assert_true(Terrain.is_difficult(game.map, FIELD_A), 'A laid tile is difficult.')
	assert_true(Terrain.is_difficult(game.map, FIELD_B), 'So is the other one.')
	assert_false(Terrain.is_difficult(game.map, CLEAN), 'A tile that was not laid is not.')
	# THE ENGINE'S OWN READ, alongside ours, so this test also says WHICH accessor the helper is
	# agreeing with. test/gear/test_cp_magnetic_field_projector.gd:24 asserts exactly this expression.
	assert_eq(Terrain.is_difficult(game.map, FIELD_A),
		game.map.get_surface_terrain_at(FIELD_A).is_difficult(),
		'The helper is get_surface_terrain_at().is_difficult() and nothing else.')

func test_is_difficult_is_false_off_the_map_and_for_a_null_map():
	# Both are reachable from a real gate: a step reaction is handed a next-anchor by the move event,
	# and a buff gate runs for every unit on every event, where a throw is an error storm rather than
	# a wrong answer. MapState.get_surface_terrain_at already bounds-checks and returns BLANK
	# (map_state.gd:140-142); the null guard is ours.
	assert_false(Terrain.is_difficult(game.map, OFF_MAP), 'Off the map is not difficult ground.')
	assert_false(Terrain.is_difficult(null, FIELD_A), 'Neither is anything on a null map.')

# ---------------------------------------------------------------- is_unit_in_difficult

func test_is_unit_in_difficult_is_true_when_any_one_tile_of_its_footprint_is():
	# A SIZE-2 unit anchored at WEST_OF_FIELD occupies (4,4) (5,4) (4,5) (5,5) - of which only (5,4)
	# is difficult. "In at least one space of difficult terrain" is the card's wording for Gravity
	# Well, and this is what makes that literal for a big mech.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var big := VaubanFixture.create_dummy(game, WEST_OF_FIELD)
	SpecFactory.change_size(big, 2)
	assert_eq(big.occupied_tiles().size(), 4, 'fixture: it really is size 2.')
	assert_true(big.occupied_tiles().has(FIELD_A), 'fixture: and one of its tiles is the laid one.')

	assert_true(Terrain.is_unit_in_difficult(big), 'One difficult tile in the footprint is enough.')

func test_is_unit_in_difficult_is_false_on_clean_ground():
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B])
	var unit := VaubanFixture.create_dummy(game, CLEAN)
	assert_false(Terrain.is_unit_in_difficult(unit), 'A unit standing away from the field is not in it.')
	assert_false(Terrain.is_unit_in_difficult(null), 'And a null unit is not in anything.')

# ---------------------------------------------------------------- is_entering_difficult

func test_is_entering_difficult_is_true_stepping_from_clean_ground_into_the_field():
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B])
	var mover := VaubanFixture.create_hostile(game, WEST_OF_FIELD)
	assert_true(Terrain.is_entering_difficult(mover, FIELD_A),
		'Standing clean, stepping onto a difficult tile: an entry.')

func test_is_entering_difficult_is_false_when_the_unit_already_stands_in_the_field():
	# Ruling 3's actual test, and the half that stops Sap asking for a save on every step of a walk
	# THROUGH the field: "the destination footprint touches difficult ground AND the current footprint
	# does not".
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B])
	var mover := VaubanFixture.create_hostile(game, FIELD_A)
	assert_true(Terrain.is_unit_in_difficult(mover), 'fixture: it is standing in the field.')
	assert_false(Terrain.is_entering_difficult(mover, FIELD_B),
		'Moving from one difficult tile to the next is not a new entry.')

func test_is_entering_difficult_is_false_from_clean_ground_into_clean_ground():
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B])
	var mover := VaubanFixture.create_hostile(game, CLEAN)
	assert_false(Terrain.is_entering_difficult(mover, EAST_OF_FIELD), 'Clean to clean is not an entry.')
	assert_false(Terrain.is_entering_difficult(mover, Tile.INVALID),
		'And an absent next anchor is not an entry either - a new_turn context carries no target_tiles.')

func test_is_entering_difficult_measures_the_whole_footprint_of_a_size_two_unit():
	# The destination read is UnitTile.get_occupied(next_anchor, state.occupying_size, map.size)
	# (unit_tile.gd:45), NOT the anchor tile alone - so a size-2 unit whose anchor lands on clean
	# ground but whose body overlaps the field IS entering it. Hard-coding the anchor would pass every
	# test above and fail only here.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var big := VaubanFixture.create_dummy(game, CLEAN)
	SpecFactory.change_size(big, 2)
	assert_false(Terrain.is_unit_in_difficult(big), 'fixture: it starts clean.')
	assert_false(Terrain.is_difficult(game.map, WEST_OF_FIELD), 'fixture: the anchor tile itself is clean.')

	assert_true(Terrain.is_entering_difficult(big, WEST_OF_FIELD),
		'Anchoring clean while the body overlaps the field is still an entry.')

# ---------------------------------------------------------------- the gated zone

func test_a_gated_zone_projects_nothing_until_its_state_is_set():
	# The engine collects every PassiveTerrainZone on every gear of every unit UNCONDITIONALLY
	# (map_state.gd:427-432) - there is no "active" flag for a zone the way there is for an aura
	# (is_aura_active) or a dynamic zone (is_dynamic_zone_active). Overriding the voxel list is the
	# only way a zone on a Kit stays dark, and Thy Hubris' passive_poisoned_soil.gd is the precedent.
	var unit := VaubanFixture.create_dummy(game, MAAR_TILE)
	var gear := install(gated_kit(), unit)
	assert_true(GearCore.is_valid(gear), 'fixture: the gated Kit is on the unit.')

	assert_burst_is_difficult(MAAR_TILE, false, 'Nothing is difficult while the gate is shut')

func test_a_gated_zone_projects_its_burst_once_its_state_is_set():
	var unit := VaubanFixture.create_dummy(game, MAAR_TILE)
	var gear := install(gated_kit(), unit)

	gear.set_state(String(GATE_KEY), true)
	VaubanFixture.track(game)

	assert_burst_is_difficult(MAAR_TILE, true, 'The whole Burst 1 is difficult once the gate opens')
	# AND THE CONTROL: a tile outside the burst is untouched, so the assertion above is measuring the
	# zone's pattern rather than a map-wide write.
	assert_false(game.map.get_surface_terrain_at(MAAR_TILE + Vector2i(2, 0)).is_difficult(),
		'Two tiles out is outside Burst 1 and stays clean.')

# ---------------------------------------------------------------- lay

func test_lay_spawns_an_owned_marker_whose_burst_is_difficult_ground():
	# ACTIVATION IS NULL HERE, so lay() takes its X.current_level() fallback rather than its
	# activation branch. Both branches are two lines lifted verbatim from Teleport._run
	# (teleport.gd:383-390), whose activation branch test_uncertainty_field.gd drives end to end on
	# every run; SP2's test_mastication_of_the_maar.gd is what drives THIS helper's activation branch,
	# because the Maar calls lay() from a real activate(). Written down so the gap is a known one.
	var layer := VaubanFixture.create_dummy(game, LAYER_TILE)
	VaubanFixture.equip_ranged(layer)
	var specific := SpecificAction.from_id(layer, VaubanFixture.RANGED_ID)
	assert_true(SpecificAction.is_valid(specific), 'fixture: the layer has a gear to be billed for it.')

	var maar:Unit = await Terrain.lay(null, specific, MAAR_TILE, marker_frame())

	assert_true(Unit.is_valid(maar), 'lay() hands back the unit it spawned.')
	if not Unit.is_valid(maar): return
	assert_eq(maar.tile(), MAAR_TILE, 'It is standing on the chosen tile, already on the map.')
	assert_true(maar.is_marker(), 'It is a MARKER, so it blocks nothing and takes no auras.')
	assert_eq(maar.get_faction(), Faction.NONE, 'Spawned factionless, the Apocalypse Rail\'s own recipe.')
	assert_true(maar.state.is_owned_by(layer),
		'And OWNED by the caller - UnitAction.set_deployable_owner, so a later frame can find its owner.')
	assert_burst_is_difficult(MAAR_TILE, true, 'Its Burst 1 is difficult ground')

func test_the_laid_terrain_survives_the_layers_death():
	# RULING 8's requirement, and the reason the marker frame above sets
	# is_deactivated_on_owner_death = false. With that export left at its `true` default,
	# EventService.remove_unit_from_game queues event_unit_die on every MARKER the dying unit owns
	# (event_service.gd:56-63) and this test goes red - which is exactly the mutation named in Step 6.
	var layer := VaubanFixture.create_dummy(game, LAYER_TILE)
	VaubanFixture.equip_ranged(layer)
	var specific := SpecificAction.from_id(layer, VaubanFixture.RANGED_ID)
	var maar:Unit = await Terrain.lay(null, specific, MAAR_TILE, marker_frame())
	assert_true(Unit.is_valid(maar), 'fixture: the marker landed.')
	if not Unit.is_valid(maar): return

	await game.execute_event(&'event_unit_die', {unit = layer})

	assert_false(Unit.is_valid(layer), 'fixture: the layer really died.')
	assert_true(Unit.is_valid(maar), 'The marker outlives it.')
	assert_burst_is_difficult(MAAR_TILE, true, 'And so does its terrain')
