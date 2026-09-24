# The Gloire (IPS-N, Tortuga alt) - SP1. test_shackleton_frame.gd's shape, re-pointed.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/14-gloire.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically. A red here means the
# .tres drifted from the card, OR that the sheet was regenerated.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gloire_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')

const FRAME_ID := &'mf_gloire'
const LICENSE_ID := &'li_tortuga'
const TORTUGA_ID := &'mf_tortuga'
const MOD_ID := 'Reag-TheSixthVoice'

const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/content/licenses/ipsn/li_tortuga.tres_ext.gd'

## Vanilla li_tortuga's OWN rank 2 gear, pinned exactly (read off content/licenses/ipsn/li_tortuga.tres,
## 2026-09-24). An alt adds a frame and nothing else.
const TORTUGA_RANK_2_GEAR:Array[StringName] = [&'mw_daisy_cutter', &'mw_catalytic_hammer']

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins.
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 8, armor = 2, evasion = 6, edef = 7,
	speed = 3, heat = 5, save_target = 10, sensor_range = 8, tech_attack = -1, repairs = 6,
	systems_points = 6, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order (Guardian is vanilla's shared Kit), then the core system (SP2).
const SHEET_TRAITS:Array[StringName] = [&'mt_guardian', &'mt_hydraulic_punisher', &'mt_extended_zone_control']

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
	assert_true(Frame.is_valid(_frame()), 'mf_gloire is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_false(frame.stat.is_size_half, 'A full size 2, not a half size.')

func test_the_mounts_are_main_main_heavy():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_main.tres', 'mount_main.tres', 'mount_heavy.tres'],
		'Main, Main, Heavy, as the sheet lists them.')

func test_the_roles_are_striker_then_defender():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.DEFENDER, 'Secondary role DEFENDER.')

func test_the_frame_wears_its_own_sprite():
	# A .tres pointing at an unimported PNG fails the whole frame out of ContentLibrary silently.
	# 160x160 because the Gloire is size 2 (the Tortuga's own ipsn_tortuga.png is 160x160).
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(160, 160), 'A size-2 frame uses a 160x160 sprite.')
	assert_true(sprite.resource_path.ends_with('/mf_gloire.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# Transcribed literals, the Shackleton's shape (mf_gloire.tres's comment has the census). INERT on
	# this sprite, which is not channel-encoded; pinned so the day real art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(ours.base_0, Color(0.1960784, 0.2196078, 0.2313725, 1), 'base_0 is the dark slate plate.')
	assert_eq(ours.base_1, Color(0.3411765, 0.3803922, 0.3960784, 1), 'base_1 is the mid steel.')
	assert_eq(ours.base_2, Color(0.4901961, 0.5490196, 0.5686275, 1), 'base_2 is the light steel highlight.')
	var tortuga:Frame = ContentLibrary.get_mech_frame(TORTUGA_ID)
	if tortuga == null or tortuga.default_color_scheme == null: return
	assert_ne(ours.base_0, tortuga.default_color_scheme.base_0, 'Not a clone of the Tortuga\'s scheme.')

func test_the_name_and_flavour_resolve():
	for key:String in ['frame.mf_gloire.name', 'frame.mf_gloire.flavor', 'frame.mf_gloire.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_gloire.name'), 'Gloire', 'The frame is named Gloire.')
	assert_eq(X.tr('frame.mf_gloire.flavor.short'), 'Angry Steel', 'The tagline the author picked (ruling 1).')
	assert_true(X.tr('frame.mf_gloire.flavor').ends_with('god help anyone trying to run away.'),
		'The flavour is the whole sheet paragraph.')

func test_the_tortuga_licence_grants_the_gloire_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Gloire.')
	assert_has(granted, TORTUGA_ID, 'Rank 2 still grants the Tortuga.')

func test_the_tortuga_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_tortuga loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, TORTUGA_ID, 'The Tortuga is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_tortuga.name'), 'The licence is still named for the Tortuga.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_tortuga loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Gloire is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_tortuga.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_gloire():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Tortuga 2 pilot is offered the Gloire.')
	assert_has(ids, TORTUGA_ID, 'And is still offered the Tortuga itself.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Tortuga 1 pilot is not offered it yet.')

func test_the_tortugas_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_tortuga loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, TORTUGA_RANK_2_GEAR, 'Rank 2 grants exactly IPS-N\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	assert_not_null(retained, 'mod_main still exposes _retained_resources.')
	assert_not_null(tree, 'ContentLibrary serves li_tortuga.')
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_tortuga instance ContentLibrary serves is the one mod_main holds.')

func test_a_unit_can_actually_wear_the_frame():
	var made:Array = Fixture.create_game(self)
	var gloire:Unit = Fixture.create_gloire(made[0], Vector2i(4, 4))
	assert_eq(gloire.core.frame.compcon_id, FRAME_ID, 'It is wearing the Gloire frame.')
	assert_eq(gloire.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(gloire.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(gloire.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(gloire.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')
	# Guardian is vanilla's, and its passive lands the same buff the Tortuga wears.
	assert_true(UnitCondition.has_buff(gloire, &'buff_guardian'), 'Guardian is live: the Tortuga\'s own buff_guardian.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of the Tortuga's own Sentinel and core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_gloire loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Guardian, Hydraulic Punisher, Extended Zone Control - and nothing else.')

func test_guardian_is_the_tortugas_own_resource_not_a_copy():
	var frame:Frame = _frame()
	var tortuga:Frame = ContentLibrary.get_mech_frame(TORTUGA_ID)
	assert_not_null(frame, 'mf_gloire loads.')
	assert_not_null(tortuga, 'mf_tortuga loads.')
	if frame == null or tortuga == null: return
	var ours:Kit = null
	for kit:Kit in frame.traits: if kit.compcon_id == &'mt_guardian': ours = kit
	var theirs:Kit = null
	for kit:Kit in tortuga.traits: if kit.compcon_id == &'mt_guardian': theirs = kit
	assert_not_null(ours, 'The Gloire carries Guardian.')
	assert_not_null(theirs, 'So does the Tortuga.')
	if ours == null or theirs == null: return
	assert_true(ours == theirs, 'One shared resource (ruling 2), not a mod-side clone.')
	assert_true(ours.resource_path.begins_with('res://content/frames/shared/'), 'From the vanilla shared path.')

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)
		assert_ne(X.tr('gear.%s.name' % trait_id), 'gear.%s.name' % trait_id, '%s has a name row.' % trait_id)
