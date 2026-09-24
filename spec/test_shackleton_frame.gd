# The Shackleton (IPS-N, Nelson alt) - SP1. test_vauban_frame.gd's shape, re-pointed.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/13-shackleton.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically. A red here means the
# .tres drifted from the card, OR that the sheet was regenerated.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_shackleton_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_shackleton'
const LICENSE_ID := &'li_nelson'
const NELSON_ID := &'mf_nelson'
const MOD_ID := 'Reag-TheSixthVoice'

const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/content/licenses/ipsn/li_nelson.tres_ext.gd'

## Vanilla li_nelson's OWN rank 2 gear, pinned exactly (read off content/licenses/ipsn/li_nelson.tres,
## 2026-09-24). An alt adds a frame and nothing else.
const NELSON_RANK_2_GEAR:Array[StringName] = [&'wm_thermal_charge', &'ms_armor_lock_plating']

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins (test_vauban_frame.gd's SHEET_STATS note).
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 8, armor = 1, evasion = 8, edef = 6,
	speed = 5, heat = 6, save_target = 11, sensor_range = 8, tech_attack = -2, repairs = 5,
	systems_points = 6, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order. The core system is appended at SP2.
const SHEET_TRAITS:Array[StringName] = [&'mt_spatial_rerouting', &'mt_mobilized_hydraulics', &'mt_shackleton_weak_computer']

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

func _grants_in(tree:UnlockTree) -> int:
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	return count

func test_the_frame_is_in_the_content_library():
	assert_true(Frame.is_valid(_frame()), 'mf_shackleton is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_false(frame.stat.is_size_half, 'A full size 2, not a half size.')

func test_the_mounts_are_flex_flex_main_aux():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_flex.tres', 'mount_main_aux.tres'],
		'Flex, Flex, Main/Aux, as the sheet lists them.')

func test_the_role_is_controller_with_no_secondary():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.CONTROLLER, 'Primary role CONTROLLER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_wears_its_own_sprite():
	# A .tres pointing at an unimported PNG fails the whole frame out of ContentLibrary silently.
	# 160x160 because the Shackleton is size 2 (the Subutai, Myconid and Naga are the same size).
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(160, 160), 'A size-2 frame uses a 160x160 sprite.')
	assert_true(sprite.resource_path.ends_with('/mf_shackleton.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# Transcribed literals, the Vauban's shape (mf_shackleton.tres's comment has the census). INERT on
	# this sprite, which is not channel-encoded; pinned so the day real art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(ours.base_0, Color(0.5882353, 0.11764706, 0.17254902, 1), 'base_0 is the crimson plate.')
	assert_eq(ours.base_1, Color(0.30980393, 0.23921569, 0.28235295, 1), 'base_1 is the grey-mauve shadow.')
	assert_eq(ours.base_2, Color(0.7882353, 0.5803922, 0.6627451, 1), 'base_2 is the pale mauve highlight.')
	var nelson:Frame = ContentLibrary.get_mech_frame(NELSON_ID)
	if nelson == null or nelson.default_color_scheme == null: return
	assert_ne(ours.base_0, nelson.default_color_scheme.base_0, 'Not a clone of the Nelson\'s scheme.')

func test_the_name_and_flavour_resolve():
	for key:String in ['frame.mf_shackleton.name', 'frame.mf_shackleton.flavor', 'frame.mf_shackleton.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_shackleton.name'), 'Shackleton', 'The frame is named Shackleton.')
	assert_eq(X.tr('frame.mf_shackleton.flavor.short'), 'Heavy. Dense. Immutable.', 'The tagline the author picked (ruling 1).')
	assert_true(X.tr('frame.mf_shackleton.flavor').ends_with('The Shackleton is a fact.'),
		'The flavour is the whole sheet paragraph.')

func test_the_nelson_licence_grants_the_shackleton_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Shackleton.')
	assert_has(granted, NELSON_ID, 'Rank 2 still grants the Nelson.')

func test_the_nelson_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_nelson loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, NELSON_ID, 'The Nelson is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_nelson.name'), 'The licence is still named for the Nelson.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_nelson loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Shackleton is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_nelson.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_shackleton():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Nelson 2 pilot is offered the Shackleton.')
	assert_has(ids, NELSON_ID, 'And is still offered the Nelson itself.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Nelson 1 pilot is not offered it yet.')

func test_the_nelsons_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_nelson loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, NELSON_RANK_2_GEAR, 'Rank 2 grants exactly IPS-N\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_nelson instance ContentLibrary serves is the one mod_main holds.')

func test_a_unit_can_actually_wear_the_frame():
	var made:Array = Fixture.create_game(self)
	var shackleton:Unit = Fixture.create_shackleton(made[0], Vector2i(4, 4))
	assert_eq(shackleton.core.frame.compcon_id, FRAME_ID, 'It is wearing the Shackleton frame.')
	assert_eq(shackleton.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(shackleton.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(shackleton.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(shackleton.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of the Nelson's own Momentum, Skirmisher and core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_shackleton loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Spatial Rerouting, Mobilized Hydraulics, Weak Computer - and nothing else.')

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)
		assert_ne(X.tr('gear.%s.name' % trait_id), 'gear.%s.name' % trait_id, '%s has a name row.' % trait_id)
