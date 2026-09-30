# The Purple Thorn (SSC) - SP1 Task 1, with the trait list pinned as each task lands.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix or resource group is
# wrong is silently filed somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT. Like the Fitzgerald, the Primrose, the Sluagh, the Leoleth and the
# Naga, the Purple Thorn ships its own li_purple_thorn.tres rather than extending a vanilla licence -
# so there is no .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row.
#
# Numbers come from the notes repo's specs/sixth-voice/11-purple-thorn.md Stats table, which is
# generated from the LCP. Neither the sheet nor its generator lives in this repo. A red here means
# the .tres drifted from the card, OR that the sheet was regenerated - check the sheet's git history
# (in the lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_purple_thorn_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const FRAME_ID := &'mf_purple_thorn'
const LICENSE_ID := &'li_purple_thorn'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table (specs/sixth-voice/11-purple-thorn.md), in the engine's field names. SIXTEEN
## FIELDS, not the card's fourteen columns: Statblock carries `reactions` and `activations` too,
## and every frame in this mod sets both to 1.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 0, evasion = 10, edef = 8,
	speed = 3, heat = 5, save_target = 10, sensor_range = 15, tech_attack = 0, repairs = 3,
	systems_points = 6, reactions = 1, activations = 1,
}

const THORN_TILE := Vector2i(4, 6)
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
	# file is the natural mistake.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Purple Thorn is a full size 1, not size 1/2.')

func test_the_mounts_are_two_aux_aux_pairs_then_a_flex():
	# Sheet line 24: "Mounts: Aux/Aux, Aux/Aux, Flex" - THREE mounts, in that order (ruling 16).
	# Player-visible: the mech sheet draws mounts in array order, and the fixture's mount_pair()
	# indexes them by it.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_aux_aux.tres', 'mount_aux_aux.tres', 'mount_flex.tres'],
		'Two Aux/Aux pairs and a Flex - the sheet.')

func test_the_role_is_artillery_alone():
	# Sheet line 6: "Roles: Artillery" - ONE role. Lancer.SQUAD_ROLE is { NONE, STRIKER, DEFENDER,
	# CONTROLLER, ARTILLERY, SUPPORT } (lancer.gd:181), so ARTILLERY is 4 and the secondary stays
	# NONE (0) - the Death's Head's values.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.ARTILLERY, 'Primary role ARTILLERY.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_purple_thorn.sprites.
	#
	# 80x80, the size-1 shape. The mod ships an 80x80 stand-in too (mf_placeholder.png), so the
	# size assertion alone cannot catch a revert to it - the resource_path checks are what pin the
	# author's own file, under the frame's OWN filename rather than a sibling's.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_false(sprite.resource_path.contains('placeholder'),
		'And it is the author\'s own file, not the shared stand-in.')
	assert_true(sprite.resource_path.ends_with('/mf_purple_thorn.png'),
		'The frame wears its OWN sprite - not a sibling frame\'s, and not the stand-in.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# LITERALS, NOT A RELATIONSHIP - the Naga's, the Sluagh's, the Vauban's and the Primrose's shape.
	# mf_purple_thorn.png (80x80, 2,327 opaque pixels) carries ZERO channel-encoded pixels against
	# palette_index_r.png's seven red values (measured 2026-09-23, the same test
	# palette_swap_func.gdshaderinc runs), so this scheme is INERT on the token today. Pinned anyway,
	# because the day channel-encoded art replaces this sprite these become the frame's default
	# paint, and an edit made between now and then would land unnoticed. The three are the sprite's
	# own most-common literal fill colours, most-used first, excluding the linework's pure black -
	# see the .tres comment for the counts.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Purple Thorn carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.6627451, 0.8, 0.7294118, 1), 'base_0 is the sprite\'s pale sage.')
	assert_eq(ours.base_1, Color(0.41176471, 0.34117648, 0.4, 1), 'base_1 is the sprite\'s dusky violet.')
	assert_eq(ours.base_2, Color(0.18823529, 0.18431373, 0.21176471, 1), 'base_2 is the sprite\'s slate.')

func test_the_name_and_flavour_and_tagline_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green, and then
	# end to end through tr(). A tr() that falls through to the raw key is the signature of a missing
	# CSV row OR of a stale compiled .translation; either way the card is blank in game.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_purple_thorn.name', 'frame.mf_purple_thorn.flavor', 'frame.mf_purple_thorn.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_purple_thorn.name'), 'Purple Thorn', 'The frame is named Purple Thorn.')
	assert_eq(X.tr('frame.mf_purple_thorn.flavor.short'), 'Odd Artillery',
		'The tagline the author picked (ruling 1) - the one invented string in SP1.')
	var flavour:String = X.tr('frame.mf_purple_thorn.flavor')
	assert_true(flavour.begins_with('Smith-Shimano were slow'), 'The flavour opens as the sheet does.')
	assert_true(flavour.ends_with('to moderate success.'), 'And ends as the sheet does, nothing after.')

func test_the_frame_carries_its_traits_in_sheet_order():
	# WRITTEN FINAL AT TASK 1 AND DELIBERATELY RED UNTIL THE CORE TASK LANDS: Task 1 lands the frame
	# with no traits, Task 2 appends Vigil, Task 3 Blessed Bolt System, and Task 4 appends the LAV
	# Tactical Engine last - and this line goes green at that moment and not before. One deliberate
	# red is a cleaner signal than three rewrites of the expected list.
	#
	# THIS ASSERTS ORDER, DELIBERATELY, and must not be relaxed to membership. The array order is
	# PLAYER-VISIBLE: catalog_license_focus_spread.gd:31 iterates core.frame.traits in array order
	# to fill the catalog's trait slots, and mech_section.gd:109 iterates
	# loadout.get_frame_traits(), which preserves it. The final order is the sheet's - the two traits
	# in the order it prints them, then the core system (design 1.1).
	#
	# IT SHOULD NOT GROW PAST THREE. SP2-SP4 add GEAR to li_purple_thorn's ranks, not traits.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried, [&'mt_vigil', &'mt_blessed_bolt_system', &'cp_lav_tactical_engine'],
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
	assert_not_null(license.rank_1, 'the licence has a rank_1.')
	assert_not_null(license.rank_2, 'the licence has a rank_2.')
	assert_not_null(license.rank_3, 'the licence has a rank_3.')
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_2_frames:Array = license.rank_2.granted_frames.map(
		func(f:Frame) -> StringName: return f.compcon_id)
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Purple Thorn, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_exactly_the_gear_built_so_far():
	# EXACT lists, not "contains ours": each line goes red exactly once, in the sub-project that
	# fills that rank (SP2 rank 1, SP3 rank 2, SP4 rank 3), and that sub-project rewrites this test
	# the way test_naga_frame.gd's own rewrite did.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1_ids:Array = license.rank_1.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_1_ids, [&'mw_blink_bolt_launcher', &'ms_trajectory_arc_mapper'],
		'Rank 1 grants the Blink Bolt Launcher and the Trajectory Arc Mapper, in sheet order (SP2).')
	var rank_2_ids:Array = license.rank_2.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_2_ids, [&'mw_shredder_cannon', &'ms_pinpoint_mark'],
		'Rank 2 grants the Shredder Cannon and Pinpoint Mark, in sheet order (SP3).')
	var rank_3_ids:Array = license.rank_3.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_3_ids, [&'ms_hyper_engineered_munitions', &'ms_superpositional_profile'],
		'Rank 3 grants Hyper Engineered Munitions and the Superpositional Profile, in sheet order (SP4).')

func test_the_licence_names_itself_after_the_frame():
	# THERE IS NO LICENCE NAME ROW, AND THAT IS THE ENGINE'S DESIGN: UnlockTree.license_name
	# (unlock_tree.gd:28-32) reads rank_2.granted_frames.front() and translates frame.<id>.name -
	# and an empty rank_2 renames the licence "???" (:32).
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_purple_thorn.name'),
		'The licence names itself after its granted frame, translated.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_purple_thorn():
	# THE PLAYER-FACING HALF OF THE LICENCE: PilotCore.get_available_frames (pilot_core.gd:390-397)
	# walks the pilot's OWN RankProgress rows for a non-GMS licence.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_purple_thorn at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Purple Thorn 2 pilot is offered the Purple Thorn.')

	# The rank actually gates it: get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:34-39).
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Purple Thorn 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var thorn:Unit = Fixture.create_thorn(game, THORN_TILE)
	assert_true(Unit.is_valid(thorn), 'A unit was created.')
	if not Unit.is_valid(thorn): return
	assert_eq(thorn.core.frame.compcon_id, FRAME_ID, 'It is wearing the Purple Thorn frame.')
	assert_eq(thorn.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or sensor range into
	# the current block.
	assert_eq(thorn.get_sensor_range(), SHEET_STATS.sensor_range,
		'It has the sheet Sensors, read the way the engine reads it.')
	assert_eq(thorn.get_evasion(), SHEET_STATS.evasion, 'And the sheet evasion.')
	assert_eq(thorn.get_save_target(), SHEET_STATS.save_target, 'And the sheet save target.')
	assert_eq(thorn.core.current.armor, SHEET_STATS.armor, 'And the sheet armor.')
	assert_eq(thorn.core.loadout.mounts.size(), 3, 'And three mounts to fill.')
	assert_true(thorn.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the ability specs depends on '
		+ 'it, and CommonActionUtil auto-accepts prompts for a non-player unit.')

func test_the_fixture_mounts_an_aux_pair_and_equips_an_integrated_rifle_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK. Two facts every ability spec leans on: mount_pair() really puts BOTH
	# Auxes on ONE mount (so the engine's Aux/Aux follow-up rule is reachable), and equip() files a
	# weapon as INTEGRATED - on no mount at all (test_spin.gd's header) - which is the shape whose
	# follow-up the engine never offers.
	var game:Gamemaster = Fixture.create_game(self)
	var thorn:Unit = Fixture.create_thorn(game, THORN_TILE)
	var mount:MountCore = Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS, Fixture.AUX_PISTOL)
	assert_true(mount.has_primary() and mount.has_secondary(), 'Both Aux slots are filled.')
	if not (mount.has_primary() and mount.has_secondary()): return
	assert_eq(mount.slot_primary.kit.compcon_id, Fixture.AUX_NEXUS, 'The Nexus is the primary.')
	assert_eq(mount.slot_secondary.kit.compcon_id, Fixture.AUX_PISTOL, 'The Pistol is the secondary.')
	assert_eq(thorn.core.loadout.get_mount_for_gear(mount.slot_primary), mount,
		'And the loadout knows which mount the Nexus is on.')
	assert_true(GearCore.is_valid(thorn.get_gear(Fixture.AUX_NEXUS)), 'get_gear finds a mounted weapon.')
	var rifle:GearCore = Fixture.arm_rifle(thorn)
	assert_true(GearCore.is_valid(rifle), 'The rifle equipped.')
	if not GearCore.is_valid(rifle): return
	assert_null(thorn.core.loadout.get_mount_for_gear(rifle), 'An equip()ped weapon sits on NO mount.')
	assert_false(thorn.core.loadout.is_gear_basic(rifle), 'And it is NOT basic gear.')
	var again:GearCore = Fixture.arm_rifle(thorn)
	assert_eq(again.persistent_id, rifle.persistent_id,
		'equip() is idempotent: a second call hands back the same gear and re-equips nothing.')

func test_the_fixture_can_shoot_a_hostile_with_the_rifle():
	# THE VACUITY GUARD FOR EVERY DAMAGE-TRIGGERED SPEC: the rifle's d20, hit die and crit die land
	# on a hostile for exactly the hit die, so a "did the trait fire" case is measuring the trait and
	# not a miss. THE RIFLE, NOT THE NEXUS: a Main weapon is the one shot on this frame that wakes no
	# trait - an Aux hit offers Blessed Bolt, and the stock responder says yes to it.
	var game:Gamemaster = Fixture.create_game(self)
	var thorn:Unit = Fixture.create_thorn(game, THORN_TILE)
	var hostile:Unit = Fixture.create_hostile(game, TARGET_TILE)
	Fixture.arm_rifle(thorn)
	Fixture.queue([19, 4, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'The rifle hit for its die (armor 0).')
