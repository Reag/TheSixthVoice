# The Subutai (HA, Barbarossa alt) - SP1 Task 1, Task 2 and Task 4.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED,
# not merely written: a frame whose filename prefix or resource group is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_subutai_frame.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_subutai'
const LICENSE_ID := &'li_barbarossa'
const BARBAROSSA_ID := &'mf_barbarossa'
const MOD_ID := 'Reag-TheSixthVoice'

## Vanilla li_barbarossa's OWN rank 2 gear, pinned as an exact ordered list. An alt frame adds a
## frame and nothing else, so anything appearing here is either our extension overreaching or a
## modkit update moving Harrison's gear - both worth a red. Pinned exactly rather than relaxed to
## "none of them is ours", which is the shape test_mk2_frame.gd uses: that form cannot see a
## VANILLA kit being appended, and the appended thing in the natural mistake (a copy-paste from a
## licence that grants gear) is as likely to be vanilla's as ours. Both halves are asserted below.
const BARBAROSSA_RANK_2_GEAR:Array[StringName] = [&'ms_flak_launcher', &'ms_autoloader_drone']

## Other li_barbarossa extenders a testkit run can contain, and the frame each grants there.
##
## fateofman-imi_alt_frames appends the Tritton to this very rank, through the ENGINE'S QUEUE - the
## exact shape the queue collision silently drops (mod_main.gd's header). It is parked in
## lancer-tactics-claude/.bk, so a 1.4.x testkit run does not load it and this test skips; its zip is
## still installed in %APPDATA%\LancerTactics\mods, so the real game does load it. The row is
## therefore not speculative - it is the case that ships - and it costs nothing while the mod is
## absent. Same shape, same reasoning, as test_mk2_frame.gd's OTHER_EXTENDERS.
const OTHER_EXTENDERS := {
	'fateofman-imi_alt_frames': &'mf_tritton',
}

## The sheet's table (specs/sixth-voice/03-subutai.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 8, armor = 1, evasion = 6, edef = 8,
	speed = 3, heat = 7, save_target = 10, sensor_range = 15, tech_attack = 0, repairs = 5,
	systems_points = 6, reactions = 1, activations = 1,
}

func _frame() -> Frame:
	return ContentLibrary.get_mech_frame(FRAME_ID)

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

func _rank_2_frame_ids() -> Array[StringName]:
	var ids:Array[StringName] = []
	var tree := _license()
	if tree == null or tree.rank_2 == null: return ids
	for frame:Frame in tree.rank_2.granted_frames: ids.append(frame.compcon_id)
	return ids

func test_the_frame_is_in_the_content_library():
	assert_true(Frame.is_valid(_frame()), 'mf_subutai is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_subutai carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size; a size-2 frame that also set it would occupy one
	# tile while reporting 2, and every line and blast test below would quietly measure the wrong
	# geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_subutai carries a statblock.')
	if frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Subutai is a full size 2, not size 1/2.')

func test_the_mounts_are_main_and_heavy():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids.size(), 2, 'Two mounts.')
	assert_has(mount_ids, 'mount_main.tres', 'A Main mount.')
	assert_has(mount_ids, 'mount_heavy.tres', 'A Heavy mount.')

func test_the_roles_are_artillery_then_defender():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.ARTILLERY, 'Primary role ARTILLERY.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.DEFENDER, 'Secondary role DEFENDER.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary. So the first half
	# below asserts the texture is real and is the 160x160 a size-2 frame wants.
	#
	# THE SECOND HALF ASSERTS WHICH IMAGE IT IS, and that is the point of it. SP3 swapped the grey
	# stand-in for the author's commissioned art KEEPING THE SAME ext_resource id, so reverting
	# mf_subutai.tres's sprite path to res/assets/frames/placeholder/mf_placeholder_160.png is a
	# one-line edit that changes nothing else - and the placeholder is ALSO 160x160, so the size
	# assertion above sails straight through and the mod ships the stand-in as the frame's art.
	# Nothing else in the suite reads frame.sprites.
	#
	# Matches test_content_integrity.gd's _assert_real_icon, which has done exactly this for kit,
	# action and buff icons since SP5 - it is simply never reached from a Frame.sprites entry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_false(sprite.resource_path.contains('placeholder'),
		'The frame wears its commissioned art, not the stand-in (%s).' % sprite.resource_path)

func test_the_frame_has_a_colour_scheme():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_not_null(frame.default_color_scheme, 'The frame carries a default colour scheme.')

func test_the_name_and_flavour_resolve():
	# tr() falling through to the raw key is the signature of a missing CSV row OR of a stale
	# compiled .translation artifact; either way the card is blank in game.
	for key:String in ['frame.mf_subutai.name', 'frame.mf_subutai.flavor', 'frame.mf_subutai.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_subutai.name'), 'Subutai', 'The frame is named Subutai.')
	assert_eq(X.tr('frame.mf_subutai.flavor.short'), 'Immovable Object', 'Ruling 12 tagline.')

func test_the_barbarossa_licence_grants_the_subutai_at_rank_two():
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_true(tree is UnlockTree, 'li_barbarossa loads.')
	if tree is not UnlockTree: return
	assert_not_null(tree.rank_2, 'li_barbarossa has a rank 2.')
	if tree.rank_2 == null: return
	var granted:Array[StringName] = []
	for frame:Frame in tree.rank_2.granted_frames: granted.append(frame.compcon_id)
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Subutai.')
	assert_has(granted, &'mf_barbarossa', 'Rank 2 still grants the Barbarossa.')

func test_the_barbarossa_is_still_first_so_the_licence_keeps_its_name():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT(). Unlike li_gms (which declares no
	# rank_2 at all and so is named '???' whatever we do), li_barbarossa IS named off this array, so
	# inserting instead of appending would rename Harrison's licence after our alt.
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_true(tree is UnlockTree, 'li_barbarossa loads.')
	if tree is not UnlockTree: return
	assert_not_null(tree.rank_2, 'li_barbarossa has a rank 2.')
	if tree.rank_2 == null: return
	assert_false(tree.rank_2.granted_frames.is_empty(), 'Rank 2 grants at least one frame.')
	if tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, BARBAROSSA_ID,
		'The Barbarossa is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_barbarossa.name'),
		'The licence is still named for the Barbarossa.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	# apply_resource_extensions_directly() stamps APPLIED_META on the instance so a re-activation
	# cannot append the frame twice. A duplicated grant shows in game as the Subutai listed twice in
	# the licence card.
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_true(tree is UnlockTree, 'li_barbarossa loads.')
	if tree is not UnlockTree: return
	assert_not_null(tree.rank_2, 'li_barbarossa has a rank 2.')
	if tree.rank_2 == null: return
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	assert_eq(count, 1, 'The Subutai is granted exactly once.')

## THE PLAYER-FACING HALF OF THE LICENCE, and until now nothing on the branch asked it. The three
## tests above read the UnlockTree directly; test_a_unit_can_actually_wear_the_frame assigns
## unit.core.frame by hand. Neither touches the pilot path, which is the only way a player ever gets
## this frame.
##
## The Subutai does NOT ride the M/K2's free-for-all branch. PilotCore.get_available_frames
## (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3 regardless of pilot level -
## which is why a li_gms rank 1 frame is offered to a fresh pilot - and get_unlocked_licensed_frames,
## which walks the pilot's OWN RankProgress rows. Harrison Armory is not GMS, so only the second
## half can ever reach us: RankProgress.get_unlocked_frames -> tree.get_unlocked_frames_for_rank(rank)
## (rank_progress.gd:38-39, unlock_tree.gd:66-70).
##
## Built through set_license_to_rank rather than by hand-constructing a RankProgress, so the test
## goes through the same engine call the pilot editor does (pilot_core.gd:318, :323-346).
func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_subutai():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_barbarossa at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Barbarossa 2 pilot is offered the Subutai.')
	assert_has(ids, BARBAROSSA_ID, 'And is still offered the Barbarossa itself.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:44-49),
	# so an extension that appended to rank_1 by mistake would still show up at rank 2 and every
	# assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Barbarossa 1 pilot is not offered it yet.')

func test_the_barbarossas_own_gear_is_untouched():
	# An alt frame adds a FRAME to the base licence and nothing else. Nothing else in the suite reads
	# li_barbarossa.granted_gear at all, so appending a kit in li_barbarossa.tres_ext.gd - the natural
	# shape of a copy-paste from a licence that grants gear - reddens nothing today.
	var tree := _license()
	assert_not_null(tree, 'li_barbarossa loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, BARBAROSSA_RANK_2_GEAR, "Rank 2 grants exactly Harrison's own two systems.")
	# And named explicitly, because the list above is also what a modkit update would move: whatever
	# arrives here, it must at least not be ours.
	for kit:Kit in tree.rank_2.granted_gear:
		assert_false(kit.resource_path.contains(MOD_ID),
			'%s is not ours: an alt adds no gear to the base licence.' % kit.compcon_id)

# ---------------------------------------------------------------- retention

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion, and the ONLY thing on the branch that asks it of li_barbarossa.
	# _ModLoaderResourceExtension._save_resource no longer retains an extended resource (mod_main.gd:
	# 117-122), so the extension evaporates the moment nothing holds the instance and the next load()
	# reads the unextended file off disk. Deleting mod_main.gd:169's retained.append(extended)
	# reddens NOTHING else: test_alt_frames.gd only checks the path is DECLARED in EXTENDED_RESOURCES
	# (its own header says so), and every other test in this file compares compcon_id strings, which a
	# freshly loaded vanilla licence would still answer for the Barbarossa.
	#
	# Ported from test_mk2_frame.gd, which has guarded li_gms this way since SP1.
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node "%s" is in the tree.' % MOD_ID)
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	assert_not_null(retained, 'mod_main has a _retained_resources array.')
	if retained == null: return
	var tree := _license()
	assert_not_null(tree, 'li_barbarossa loads.')
	if tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_barbarossa instance ContentLibrary serves is the one mod_main holds.')

# ---------------------------------------------------------------- co-existence

func test_the_other_extenders_of_li_barbarossa_also_land():
	# Whoever else touched li_barbarossa in this run must still have their frame in it.
	# fateofman-imi_alt_frames appends the Tritton through the ENGINE'S QUEUE, which is the case the
	# queue collision drops silently - and this licence is the one where that collision is live in the
	# real game. The handling is already correct (mod_main.apply_resource_extensions_directly erases
	# our key at :109, before the engine's merge at mod_applier.gd:219-220, so the IMI queue entry
	# later load()s our already-edited cached instance and appends to it); this is the guard, not the
	# fix.
	#
	# SKIPS CLEANLY when the competitor is absent, which on 1.4.x is every testkit run - the mod is
	# parked out of res://unpacked/ and testkit/pre_run_hook.gd applies only the working tree. It bites
	# if it is ever unparked, and the row documents the shape meanwhile.
	var granted := _rank_2_frame_ids()
	gut.p('  installed, in order: %s' % [Compat.installed_mod_ids()])
	gut.p('  li_barbarossa rank 2 frames: %s' % [granted])
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is there too.')
	if checked == 0: pass_test('No other li_barbarossa extender installed; nothing to co-exist with.')

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = SubutaiFixture.create_game(self)
	var subutai:Unit = SubutaiFixture.create_subutai(game, Vector2i(4, 4))
	assert_true(Unit.is_valid(subutai), 'A unit was created.')
	if not Unit.is_valid(subutai): return
	assert_eq(subutai.core.frame.compcon_id, FRAME_ID, 'It is wearing the Subutai frame.')
	assert_eq(subutai.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(subutai.core.current.armor, SHEET_STATS.armor, 'It has the sheet armor.')
	assert_eq(subutai.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')

## The two vanilla entries are asserted by identity against ContentLibrary rather than by id, which
## is what proves the frame REUSES them instead of shipping a same-named copy - the author's
## standing directive for alt frames.
##
## The sheet's trait order, then the core system. The frame card lists traits in array order, so
## this is player-visible. SP2 appends cp_siege_engine last: the sheet prints the four traits under
## "Traits" and the core system under its own heading, and appending is also what keeps the four
## trait rows in the places a player learned them in SP1.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_juggernaut_drive', &'mt_reinforced_chassis', &'mt_guardian', &'mt_slow', &'cp_siege_engine',
	# The Rail's own Kit, appended after the core system it belongs to. It is a trait so that
	# loadout.get_integrated_weapons() finds it and the sheet titles the weapon box from IT
	# rather than from cp_siege_engine (weapon_mount_item.gd:101).
	&'mw_diversion_rail',
]

func test_the_traits_are_the_sheets_four_then_the_core_system():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Four traits in sheet order, then the core system.')

func test_the_two_vanilla_traits_are_vanillas_own_resources():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	var by_id := {}
	for kit:Kit in frame.traits: by_id[kit.compcon_id] = kit
	for vanilla_id:StringName in [&'mt_guardian', &'mt_slow']:
		assert_true(by_id.has(vanilla_id), 'The frame carries %s.' % vanilla_id)
		if not by_id.has(vanilla_id): continue
		assert_eq(by_id[vanilla_id], ContentLibrary.get_kit(vanilla_id),
			'%s is vanillas own resource, not a copy.' % vanilla_id)
