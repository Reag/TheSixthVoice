# The Naga (HORUS) - SP1 Task 1, with the trait list pinned as each task lands.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix or resource group is
# wrong is silently filed somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT. Like the Fitzgerald, the Primrose, the Sluagh and the Leoleth, the
# Naga ships its own li_naga.tres rather than extending a vanilla licence - so there is no
# .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row.
#
# Numbers come from the notes repo's specs/sixth-voice/10-naga.md Stats table, which is generated
# from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in the
# lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_naga_frame.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')

const FRAME_ID := &'mf_naga'
const LICENSE_ID := &'li_naga'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table (specs/sixth-voice/10-naga.md), in the engine's field names. SIXTEEN FIELDS,
## not the card's fourteen columns: Statblock carries `reactions` and `activations` too, and every
## frame in this mod sets both to 1.
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 10, armor = 1, evasion = 8, edef = 10,
	speed = 3, heat = 5, save_target = 10, sensor_range = 8, tech_attack = 1, repairs = 5,
	systems_points = 7, reactions = 1, activations = 1,
}

const NAGA_TILE := Vector2i(4, 6)
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
	if frame == null: return
	assert_not_null(frame.stat, 'fixture: the frame carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size, and the Fitzgerald DOES set it, so a copy from that
	# file is the natural mistake. A size-2 frame that also set it would report height 0.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Naga is a full size 2, not size 1/2.')

func test_the_mounts_are_a_flex_and_a_heavy_in_that_order():
	# Sheet line 24: "Mounts: Flex, Heavy" - TWO mounts, in that order (ruling 21). Player-visible:
	# the mech sheet draws mounts in array order.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_heavy.tres'], 'A Flex and a Heavy - the sheet.')

func test_the_roles_are_striker_then_support():
	# Sheet line 6: "Roles: Striker, Support" - and ORDER matters: role_primary and role_secondary
	# are different fields read by catalog_blurb.gd and opfor_editor_modal.gd. Lancer.SQUAD_ROLE is
	# { NONE, STRIKER, DEFENDER, CONTROLLER, ARTILLERY, SUPPORT } (lancer.gd:181), so STRIKER is 1
	# and SUPPORT is 5.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.SUPPORT, 'Secondary role SUPPORT.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_naga.sprites.
	#
	# 160x160, the size-2 shape (the Myconid's reasoning): the mod ships two stand-ins, and
	# mf_placeholder_160.png is ALSO 160x160, so the size assertion alone cannot catch a revert to
	# the stand-in - the resource_path checks below are what actually pin the author's art, and the
	# frame's OWN filename rather than a sibling's.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(160, 160), 'A size-2 frame uses a 160x160 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'),
		'And it is the author\'s own art, not the shared stand-in.')
	assert_true(sprite.resource_path.ends_with('/mf_naga.png'),
		'The frame wears its OWN sprite - not a sibling frame\'s, and not the stand-in.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# LITERALS, NOT A RELATIONSHIP - the Sluagh's, the Vauban's and the Primrose's shape.
	# mf_naga.png (160x160, 11,559 opaque pixels) carries ZERO channel-encoded pixels against
	# palette_index_r.png's seven red values (measured 2026-09-22, the same test
	# palette_swap_func.gdshaderinc runs), so this scheme is INERT on the token today. Pinned anyway,
	# because the day channel-encoded art replaces this sprite these become the frame's default
	# paint, and an edit made between now and then would land unnoticed. The three are the sprite's
	# own most-common literal fill colours, most-used first, excluding the linework's pure black -
	# see the .tres comment for the counts.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Naga carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.21960784, 0.6862745, 0.5137255, 1), 'base_0 is the sprite\'s swarm green.')
	assert_eq(ours.base_1, Color(0.0627451, 0.06666667, 0.078431375, 1), 'base_1 is the sprite\'s near-black.')
	assert_eq(ours.base_2, Color(0.32156864, 0.7529412, 0.5921569, 1), 'base_2 is the sprite\'s pale green.')

func test_the_name_and_flavour_and_tagline_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green, and then
	# end to end through tr(). A tr() that falls through to the raw key is the signature of a missing
	# CSV row OR of a stale compiled .translation; either way the card is blank in game.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_naga.name', 'frame.mf_naga.flavor', 'frame.mf_naga.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_naga.name'), 'Naga', 'The frame is named Naga.')
	assert_eq(X.tr('frame.mf_naga.flavor.short'), 'Shimmering Havoc',
		'The tagline the author picked (ruling 1) - the one invented string in SP1.')
	var flavour:String = X.tr('frame.mf_naga.flavor')
	assert_true(flavour.begins_with('The Broadcasts started small'), 'The flavour opens as the sheet does.')
	assert_true(flavour.ends_with('who think they can get away.'), 'And ends as the sheet does, nothing after.')

func test_the_frame_carries_its_traits_in_sheet_order():
	# WRITTEN FINAL AT TASK 1 AND DELIBERATELY RED UNTIL THE CORE TASK LANDS: Task 1 lands only the
	# vanilla Exposed Reactor, Task 2 inserts Wire Slither ahead of it, Task 3 Advanced Targeting
	# Calculations between the two, and the core task appends SHIMMERING VEIL last - and this line
	# goes green at that moment and not before. One deliberate red is a cleaner signal than four
	# rewrites of the expected list (the ledger records it at every step).
	#
	# THIS ASSERTS ORDER, DELIBERATELY, and must not be relaxed to membership. The array order is
	# PLAYER-VISIBLE: catalog_license_focus_spread.gd:31 iterates core.frame.traits in array order
	# to fill the catalog's trait slots, and mech_section.gd:109 iterates
	# loadout.get_frame_traits(), which preserves it. The final order is the sheet's - the three
	# traits in the order it prints them, then the core system (design 1.1).
	#
	# IT SHOULD NOT GROW PAST FOUR. SP2-SP4 add GEAR to li_naga's ranks, not traits to the frame.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried,
		[&'mt_wire_slither', &'mt_advanced_targeting_calculations', &'mt_exposed_reactor', &'cp_shimmering_veil'],
		'The frame carries exactly its three traits and its core system, in the sheet\'s order.')

func test_exposed_reactor_is_the_vanilla_shared_kit():
	# Sheet: "Vanilla shared trait: reuse content/frames/shared/mt_exposed_reactor.tres, do not
	# author." Pinned by PATH, so a copy of the vanilla file into this mod - which would silently
	# REPLACE vanilla's for every Gorgon and Goblin too (mirror-path overlay) - shows up here.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var reactor:Array = frame.traits.filter(func(kit:Kit) -> bool: return kit.compcon_id == &'mt_exposed_reactor')
	assert_eq(reactor.size(), 1, 'The frame carries Exposed Reactor once.')
	if reactor.is_empty(): return
	assert_eq(reactor[0].resource_path, 'res://content/frames/shared/mt_exposed_reactor.tres',
		'And it is the VANILLA resource, referenced, not a copy under this mod.')

# ---------------------------------------------------------------- the licence

func test_the_licence_is_registered():
	assert_not_null(_license(), '%s loads as an UnlockTree through ContentLibrary.' % LICENSE_ID)

func test_the_licence_grants_the_frame_at_rank_two_and_nowhere_else():
	var license := _license()
	var frame := _frame()
	assert_not_null(license, 'fixture: the licence loads.')
	assert_not_null(frame, 'fixture: the frame loads.')
	if license == null or frame == null: return
	assert_not_null(license.rank_1, 'the licence has a rank_1.')
	assert_not_null(license.rank_2, 'the licence has a rank_2.')
	assert_not_null(license.rank_3, 'the licence has a rank_3.')
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_2_frames:Array = license.rank_2.granted_frames.map(
		func(f:Frame) -> StringName: return f.compcon_id)
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Naga, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_its_gear_rank_by_rank():
	# EXACT lists, not "contains ours": each line goes red exactly once, in the sub-project that
	# fills that rank (SP2 rank 1, SP3 rank 2, SP4 rank 3), and that sub-project rewrites this test
	# the way test_sluagh_frame.gd's own rewrite did. Strings, not StringNames: Array[StringName]
	# .sort() orders by the interned pointer, not the text. Rank 1 rewritten at SP2 Task 2, rank 2 at
	# SP3, rank 3 at SP4.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1:Array[String] = []
	for kit:Kit in license.rank_1.granted_gear: rank_1.append(String(kit.compcon_id))
	rank_1.sort()
	assert_eq(rank_1, ['ms_wide_gaze_networks', 'mw_shimmering_blade'] as Array[String],
		'Rank 1 grants the Shimmering Blade and Wide Gaze Networks, and nothing else.')
	var rank_2:Array[String] = []
	for kit:Kit in license.rank_2.granted_gear: rank_2.append(String(kit.compcon_id))
	rank_2.sort()
	assert_eq(rank_2, ['ms_green_tide', 'mw_binding_fangs'] as Array[String],
		'Rank 2 grants Binding Fangs and Green Tide, and nothing else.')
	var rank_3:Array[String] = []
	for kit:Kit in license.rank_3.granted_gear: rank_3.append(String(kit.compcon_id))
	rank_3.sort()
	assert_eq(rank_3, ['mw_weeping_lance', 'wm_bounded_automatic_targeting_systems'] as Array[String],
		'Rank 3 grants the Weeping Lance and Bounded Automatic Targeting Systems, and nothing else.')

func test_the_licence_names_itself_after_the_frame():
	# THERE IS NO LICENCE NAME ROW, AND THAT IS THE ENGINE'S DESIGN: UnlockTree.license_name
	# (unlock_tree.gd:28-32) reads rank_2.granted_frames.front() and translates frame.<id>.name -
	# and an empty rank_2 renames the licence "???" (:32).
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_naga.name'),
		'The licence names itself after its granted frame, translated.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_naga():
	# THE PLAYER-FACING HALF OF THE LICENCE: PilotCore.get_available_frames (pilot_core.gd:390-397)
	# walks the pilot's OWN RankProgress rows for a non-GMS licence.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_naga at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Naga 2 pilot is offered the Naga.')

	# The rank actually gates it: get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:34-39).
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Naga 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = NagaFixture.create_game(self)
	var naga:Unit = NagaFixture.create_naga(game, NAGA_TILE)
	assert_true(Unit.is_valid(naga), 'A unit was created.')
	if not Unit.is_valid(naga): return
	assert_eq(naga.core.frame.compcon_id, FRAME_ID, 'It is wearing the Naga frame.')
	assert_eq(naga.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or sensor range into
	# the current block. Sensors 8 is the number the core passive and active measure against.
	assert_eq(naga.get_sensor_range(), SHEET_STATS.sensor_range,
		'It has the sheet Sensors, read the way the engine reads it.')
	assert_eq(naga.get_evasion(), SHEET_STATS.evasion, 'And the sheet evasion.')
	assert_eq(naga.get_save_target(), SHEET_STATS.save_target, 'And the sheet save target.')
	assert_eq(naga.core.current.armor, SHEET_STATS.armor, 'And the sheet armor.')
	assert_true(naga.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the ability specs depends on '
		+ 'it, and CommonActionUtil auto-accepts prompts for a non-player unit.')

func test_the_map_indexes_the_naga_on_every_tile_of_its_footprint():
	# THE FIXTURE'S RE-TRACKING LINE, MEASURED (the Myconid's and the Subutai's lesson): without
	# UnitTile.move_to after full_repair, the map indexes a size-2 unit at its anchor alone.
	var game:Gamemaster = NagaFixture.create_game(self)
	var naga:Unit = NagaFixture.create_naga(game, NAGA_TILE)
	assert_eq(naga.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')
	for tile:Vector2i in naga.occupied_tiles():
		assert_eq(game.map.get_unit_at_tile(tile), naga, 'The map finds the Naga at %s.' % tile)

func test_the_fixture_arms_a_shooter_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK: the weapon reaches a mount, it is not basic gear (the core passive's
	# reaction must set allow_basic for Lock On consumed by a BASIC weapon; the rifle case tests
	# the non-basic path), and equip() is idempotent (a second call must not refund the core power
	# SALVATION spends).
	var game:Gamemaster = NagaFixture.create_game(self)
	var hostile:Unit = NagaFixture.create_hostile(game, TARGET_TILE)
	var rifle:GearCore = NagaFixture.arm_rifle(hostile)
	assert_true(GearCore.is_valid(rifle), 'The rifle equipped.')
	if not GearCore.is_valid(rifle): return
	var mounted_ids:Array[StringName] = []
	for gear:GearCore in hostile.core.loadout.get_all_weapons(): mounted_ids.append(gear.kit.compcon_id)
	assert_has(mounted_ids, NagaFixture.MAIN_RIFLE, 'And it reached a mount.')
	assert_false(hostile.core.loadout.is_gear_basic(rifle), 'And it is NOT basic gear.')
	var again:GearCore = NagaFixture.arm_rifle(hostile)
	assert_eq(again.persistent_id, rifle.persistent_id,
		'equip() is idempotent: a second call hands back the same gear and re-equips nothing.')

func test_the_fixture_can_lock_on_and_consume_and_read_the_source():
	# THE VACUITY GUARD FOR THE CORE SYSTEM'S SPECS: a lock lands with the locker's ms_lock_on gear
	# id as its source, source_of_status reads it, and a rifle shot consumes it (the responder
	# answers the attack_declared consume prompt yes). The dice: d20, the +1 accuracy die the
	# consumed lock adds, the damage die.
	var game:Gamemaster = NagaFixture.create_game(self)
	var naga:Unit = NagaFixture.create_naga(game, NAGA_TILE)
	var hostile:Unit = NagaFixture.create_hostile(game, TARGET_TILE)
	NagaFixture.arm_rifle(naga)
	await NagaFixture.lock_on(game, naga, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'The lock landed.')
	assert_eq(NagaFixture.source_of_status(hostile, Lancer.STATUS.LOCKON), naga.get_gear(NagaFixture.LOCK_ON).persistent_id,
		'Its source is the Naga\'s own ms_lock_on gear.')
	NagaFixture.queue([19, 3, 3])
	await NagaFixture.shoot(game, naga, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'The shot consumed it.')
	assert_gt(hostile.current_damage(), 0, 'And the shot landed.')
