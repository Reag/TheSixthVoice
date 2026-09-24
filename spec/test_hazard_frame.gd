# The Hazard (IPS-N) - SP1 Task 1, with the trait list pinned as each task lands.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written.
#
# A FULL LICENCE, NOT AN ALT (the IPS-N licence README): li_hazard.tres is its own file, so there is
# no .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row.
#
# Numbers come from the notes repo's specs/sixth-voice/12-hazard.md Stats table, generated from the
# LCP. A red here means the .tres drifted from the card, OR the sheet was regenerated.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hazard_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const FRAME_ID := &'mf_hazard'
const LICENSE_ID := &'li_hazard'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a sibling Reag-* mod cannot hold a
## display-text test green.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table, in the engine's field names (plus reactions/activations, 1 on every frame here).
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 10, armor = 1, evasion = 8, edef = 8,
	speed = 4, heat = 5, save_target = 10, sensor_range = 10, tech_attack = -2, repairs = 5,
	systems_points = 6, reactions = 1, activations = 1,
}

const HAZARD_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(8, 6)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _frame() -> Frame:
	var frame = ContentLibrary.get_mech_frame(FRAME_ID)
	return frame if Frame.is_valid(frame) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

# ---------------------------------------------------------------- the frame

func test_the_frame_is_registered():
	assert_not_null(_frame(), '%s loads as a valid Frame through ContentLibrary.' % FRAME_ID)

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	var frame:Frame = _frame()
	if frame == null or frame.stat == null:
		fail_test('fixture: the frame loads.')
		return
	assert_false(frame.stat.is_size_half, 'The Hazard is a full size 1, not size 1/2.')

func test_the_mounts_are_flex_main_heavy():
	# Sheet: "Mounts: Flex, Main, Heavy" - three, in that order; the mech sheet draws them in order.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_main.tres', 'mount_heavy.tres'], 'Flex, Main, Heavy - the sheet.')

func test_the_roles_are_striker_then_support():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.SUPPORT, 'Secondary role SUPPORT.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG fails to parse and the frame drops out of ContentLibrary
	# silently. 80x80 is the size-1 shape; the path pins the author's own file, not the stand-in.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.sprites.is_empty():
		fail_test('The frame carries at least one sprite.')
		return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'), 'The author\'s own file, not the stand-in.')
	assert_true(sprite.resource_path.ends_with('/mf_hazard.png'), 'The frame wears its OWN sprite.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# LITERALS. mf_hazard.png (80x80, 3,363 opaque px) carries ZERO channel-encoded pixels (measured
	# 2026-09-24), so the scheme is inert today; pinned so an edit between now and channel-encoded art
	# does not land unnoticed. The sprite's three most-common fills, excluding the black linework.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Hazard carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.54509807, 0.078431375, 0.45490196, 1), 'base_0 is the sprite\'s magenta.')
	assert_eq(ours.base_1, Color(0.2627451, 0.27450982, 0.3647059, 1), 'base_1 is the sprite\'s blue slate.')
	assert_eq(ours.base_2, Color(0.40392157, 0.36862746, 0.33333334, 1), 'base_2 is the sprite\'s khaki.')

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation (run the headless --import on a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_hazard.name', 'frame.mf_hazard.flavor', 'frame.mf_hazard.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_hazard.name'), 'Hazard', 'The frame is named Hazard.')
	assert_eq(X.tr('frame.mf_hazard.flavor.short'), 'Common Soldier', 'The tagline the author picked (ruling 1).')
	var flavour:String = X.tr('frame.mf_hazard.flavor')
	assert_true(flavour.begins_with('The Hazard is IPS-N\'s experimental attempt'), 'The flavour opens as the sheet does.')
	assert_true(flavour.ends_with('Dont give up the ship.'), 'And ends as the sheet does, verbatim.')

func test_the_frame_carries_its_traits_in_sheet_order():
	# WRITTEN FINAL AT TASK 1 AND DELIBERATELY RED UNTIL THE CORE TASK LANDS (the Thorn's rule). The
	# order is PLAYER-VISIBLE (the catalog and the mech sheet iterate it) and must not be relaxed to
	# membership. It should not grow past three: SP2-SP4 add gear to the licence, not traits.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried, [&'mt_weight_of_fire', &'mt_shield_wall', &'cp_int_type_command_systems'],
		'The frame carries exactly its two traits and its core system, in the sheet\'s order.')

# ---------------------------------------------------------------- the licence

func test_the_licence_is_registered():
	assert_not_null(_license(), '%s loads as an UnlockTree through ContentLibrary.' % LICENSE_ID)

func test_the_licence_grants_the_frame_at_rank_two_and_nowhere_else():
	var license := _license()
	var frame := _frame()
	assert_not_null(license, 'fixture: the licence loads.')
	assert_not_null(frame, 'fixture: the frame loads.')
	if license == null or frame == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null:
		fail_test('the licence has all three ranks.')
		return
	var rank_2_frames:Array = license.rank_2.granted_frames.map(func(f:Frame) -> StringName: return f.compcon_id)
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Hazard, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_exactly_the_gear_built_so_far():
	# EXACT lists: each line goes red exactly once, in the sub-project that fills that rank (SP2 rank
	# 1, SP3 rank 2, SP4 rank 3), and that sub-project rewrites this test.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null or license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1_ids:Array = license.rank_1.granted_gear.map(func(k:Kit) -> StringName: return k.compcon_id)
	assert_eq(rank_1_ids, [&'mw_wavemaker_grenade_launcher', &'ms_emergency_armature'] as Array,
		'Rank 1 grants the Wavemaker and the Emergency Armature, in the sheet\'s order (SP2).')
	assert_eq(license.rank_2.granted_gear.size(), 0, 'Rank 2 grants no gear yet (SP3).')
	assert_eq(license.rank_3.granted_gear.size(), 0, 'Rank 3 grants nothing yet (SP4).')

func test_the_licence_names_itself_after_the_frame():
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_hazard.name'), 'The licence names itself after its granted frame.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_hazard():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Hazard 2 pilot is offered the Hazard.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Hazard 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var hazard:Unit = Fixture.create_hazard(game, HAZARD_TILE)
	assert_true(Unit.is_valid(hazard), 'A unit was created.')
	if not Unit.is_valid(hazard): return
	assert_eq(hazard.core.frame.compcon_id, FRAME_ID, 'It is wearing the Hazard frame.')
	assert_eq(hazard.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(hazard.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors, through the accessor.')
	assert_eq(hazard.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(hazard.get_save_target(), SHEET_STATS.save_target, 'The sheet save target.')
	assert_eq(hazard.core.current.armor, SHEET_STATS.armor, 'The sheet armor.')
	assert_eq(hazard.core.loadout.mounts.size(), 3, 'Three mounts to fill.')
	assert_true(hazard.is_mech(), 'A mech.')
	assert_true(hazard.is_player_controlled(), 'PLAYER controlled - confirm_use asks rather than auto-accepting.')

func test_the_fixture_sets_grit_and_builds_mech_ally_and_drone():
	var game:Gamemaster = Fixture.create_game(self)
	var hazard:Unit = Fixture.create_hazard(game, HAZARD_TILE, 4)
	var ally:Unit = Fixture.create_ally(game, HAZARD_TILE + Vector2i(1, 0), 1)
	var drone:Unit = Fixture.create_drone(game, HAZARD_TILE + Vector2i(0, 1))
	assert_eq(Fixture.Overshield.grit(hazard), 4, 'create_hazard sets Grit.')
	assert_eq(Fixture.Overshield.grit(ally), 1, 'create_ally sets Grit.')
	assert_true(ally.is_mech() and ally.is_actor(), 'The ally is a mech and an actor.')
	assert_true(UnitRelation.are_allies(hazard, ally), 'And an ally.')
	assert_true(drone.is_character() and not drone.is_actor() and not drone.is_mech(),
		'The drone is a character but neither an actor nor a mech - the negative control.')

func test_the_fixture_can_shoot_a_hostile_with_the_rifle():
	# THE VACUITY GUARD FOR EVERY DAMAGE CASE: the rifle's d20 and hit die land on a hostile for the
	# hit die, so a Reliable case is measuring the tag and not a miss. With no trait wired yet the
	# rifle prints Reliable 2 - Task 2 moves this.
	var game:Gamemaster = Fixture.create_game(self)
	var hazard:Unit = Fixture.create_hazard(game, HAZARD_TILE)
	var hostile:Unit = Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([19, 4, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'The rifle hit for its die (armor 0).')
