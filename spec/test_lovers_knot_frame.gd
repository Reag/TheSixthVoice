# The Lovers Knot (SSC, Death's Head alt) - SP1, design section 1.1 and 1.4. test_rakshasa_frame.gd's
# shape, re-pointed.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/18-lovers-knot.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically. A red here means the
# .tres drifted from the card, OR that the sheet was regenerated.
#
# NOT THE DEATH'S HEAD'S NUMBERS (design ruling 2): Sensors 15 (DH 20), Repair cap 4 (DH 2), and
# mounts Main + Heavy where the Death's Head has Heavy + Main/Aux.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_lovers_knot_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')
const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const FRAME_ID := &'mf_lovers_knot'
const LICENSE_ID := &'li_deaths_head'
const DEATHS_HEAD_ID := &'mf_deaths_head'
const MOD_ID := 'Reag-TheSixthVoice'

const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/content/licenses/ssc/li_deaths_head.tres_ext.gd'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## Vanilla li_deaths_head's OWN rank 2 gear, pinned exactly (read off
## content/licenses/ssc/li_deaths_head.tres, 2026-09-26). An alt adds a frame and nothing else.
const DEATHS_HEAD_RANK_2_GEAR:Array[StringName] = [&'mw_vulture_dmr', &'ms_core_siphon']

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 0, evasion = 10, edef = 8,
	speed = 5, heat = 6, save_target = 10, sensor_range = 15, tech_attack = 0, repairs = 4,
	systems_points = 6, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order, Fragile by path (vanilla's), then the core system (design 1.1). The core
## Kit ships empty at SP1; SP2-SP3 fill it without moving this pin.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_precision_venting', &'mt_fractured_silhouette', &'mt_fragile', &'cp_integrated_redirection_aggregate',
]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _frame() -> Frame:
	var frame = ContentLibrary.get_mech_frame(FRAME_ID)
	return frame if Frame.is_valid(frame) else null

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

# ---------------------------------------------------------------- the frame

func test_the_frame_is_in_the_content_library():
	assert_not_null(_frame(), 'mf_lovers_knot loads as a valid Frame through ContentLibrary.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_false(frame.stat.is_size_half, 'A full size 1.')

func test_the_mounts_are_main_then_heavy():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_main.tres', 'mount_heavy.tres'], 'Main, Heavy, as the sheet lists them.')

func test_the_role_is_artillery_alone():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.ARTILLERY, 'Primary role ARTILLERY.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role: the sheet names one.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of every Death's Head trait, and of its core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Precision Venting, Fractured Silhouette, Fragile, then the core.')

func test_fragile_is_vanillas_own_kit_by_path():
	# Design ruling 22: reused, never authored.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null: return
	var ours:Kit = null
	for kit:Kit in frame.traits: if kit.compcon_id == Fixture.FRAGILE_ID: ours = kit
	assert_not_null(ours, 'The Lovers Knot carries mt_fragile.')
	if ours == null: return
	assert_eq(ours.resource_path, 'res://content/frames/shared/mt_fragile.tres', 'Vanilla\'s own file.')

func test_no_deaths_head_trait_is_shared():
	var frame:Frame = _frame()
	var deaths_head:Frame = ContentLibrary.get_mech_frame(DEATHS_HEAD_ID)
	if frame == null or deaths_head == null:
		fail_test('Both frames load.')
		return
	for kit:Kit in deaths_head.traits:
		assert_false(frame.traits.has(kit), "The Lovers Knot does not carry the Death's Head's %s." % kit.compcon_id)

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_eq(kit.compcon_id, trait_id, '%s is itself, not the placeholder.' % trait_id)
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)
		assert_ne(X.tr('gear.%s.name' % trait_id), 'gear.%s.name' % trait_id, '%s has a name row.' % trait_id)

func test_the_frame_wears_its_own_sprite():
	# A .tres pointing at an unimported PNG fails the whole frame out of ContentLibrary silently.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')
	assert_true(sprite.resource_path.ends_with('/mf_lovers_knot.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_the_arts_own_three_means():
	# Transcribed literals (mf_lovers_knot.tres's comment has the census): the dusky plum plate, the
	# pale rose highlight and the deep indigo shadow. INERT - the sprite has no channel-encoded pixels -
	# and pinned so the day encoded art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_lovers_knot loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(_packed(ours.base_0), 0x61496b, 'base_0 is the dusky plum plate (97,73,107).')
	assert_eq(_packed(ours.base_1), 0xba9bae, 'base_1 is the pale rose highlight (186,155,174).')
	assert_eq(_packed(ours.base_2), 0x28223c, 'base_2 is the deep indigo shadow (40,34,60).')

func test_the_sprite_is_not_channel_encoded():
	# test_rakshasa_frame.gd's census, re-pointed: zero means the colour picker cannot repaint this
	# token (memory frame-sprites-not-channel-encoded), which is why the scheme above is inert.
	var frame:Frame = _frame()
	if frame == null or frame.sprites.is_empty() or frame.sprites[0] == null:
		fail_test('The frame has a sprite.')
		return
	var image:Image = frame.sprites[0].get_image()
	assert_not_null(image, 'The sprite hands back an Image.')
	if image == null: return
	var encoded := 0
	var opaque := 0
	for y:int in image.get_height():
		for x:int in image.get_width():
			var px:Color = image.get_pixel(x, y)
			if px.a < 0.98: continue
			opaque += 1
			var r := roundi(px.r * 255.0)
			var g := roundi(px.g * 255.0)
			var b := roundi(px.b * 255.0)
			for v:int in [51, 85, 119, 153, 187, 221, 255]:
				if [Vector3i(v, 0, 0), Vector3i(0, v, 0), Vector3i(0, 0, v), Vector3i(0, v, v)].has(Vector3i(r, g, b)):
					encoded += 1
	assert_eq(opaque, 1413, 'The 1,413 opaque pixels the census was taken over.')
	assert_eq(encoded, 0, 'None of them is channel-encoded.')

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.mf_lovers_knot.name', 'frame.mf_lovers_knot.flavor', 'frame.mf_lovers_knot.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_lovers_knot.name'), 'Lovers Knot', 'The frame is named Lovers Knot.')
	assert_eq(X.tr('frame.mf_lovers_knot.flavor.short'), 'Perfect Reflection', 'The tagline the author picked (ruling 1).')

func test_the_flavour_is_the_lcp_paragraph_entire():
	var flavour:String = X.tr('frame.mf_lovers_knot.flavor')
	assert_true(flavour.begins_with('One of the latest additions to SSC'), 'Opens on the LCP\'s first clause.')
	assert_true(flavour.ends_with('defying the laws of physical reality and violence.'), 'And ends on its last.')

func test_the_trait_rows_resolve_verbatim():
	assert_eq(X.tr('gear.mt_precision_venting.name'), 'Precision Venting', 'Precision Venting is named.')
	assert_eq(X.tr('gear.mt_fractured_silhouette.name'), 'Fractured Silhouette', 'Fractured Silhouette is named.')
	assert_eq(X.tr('gear.mt_fractured_silhouette.action_reposition.name'), 'Reposition', 'Reposition is named.')
	for key:String in [
		'gear.mt_precision_venting.effect',
		'gear.mt_fractured_silhouette.effect',
		'gear.mt_fractured_silhouette.action_reposition.trigger',
		'gear.mt_fractured_silhouette.action_reposition.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_string_contains(X.tr('gear.mt_precision_venting.effect'), 'critically hits with a')
	assert_string_contains(X.tr('gear.mt_fractured_silhouette.action_reposition.trigger'), 'at a lower elevation misses you')
	assert_string_contains(X.tr('gear.mt_fractured_silhouette.action_reposition.effect'), 'move up to half your')

func test_the_core_systems_rows_are_already_written():
	# Design 1.1: SP1 writes the core system's name so SP2-SP3 build against text that already exists.
	# The LCP's core_system carries no description, so there is no flavour row to write.
	assert_eq(X.tr('gear.cp_integrated_redirection_aggregate.name'), 'Integrated Redirection Aggregate', 'The LCP\'s name.')

# ---------------------------------------------------------------- the licence

func test_the_deaths_head_licence_grants_the_lovers_knot_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Lovers Knot.')
	assert_has(granted, DEATHS_HEAD_ID, "Rank 2 still grants the Death's Head.")

func test_the_deaths_head_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_deaths_head loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, DEATHS_HEAD_ID, "The Death's Head is still the front of rank 2.")
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_deaths_head.name'), "The licence is still named for the Death's Head.")

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_deaths_head loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Lovers Knot is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_deaths_head.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_lovers_knot():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, "A Death's Head 2 pilot is offered the Lovers Knot.")
	assert_has(ids, DEATHS_HEAD_ID, "And is still offered the Death's Head itself.")
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, "A Death's Head 1 pilot is not offered it yet.")

func test_the_deaths_heads_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_deaths_head loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, DEATHS_HEAD_RANK_2_GEAR, 'Rank 2 grants exactly SSC\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	assert_not_null(retained, 'mod_main still exposes _retained_resources.')
	assert_not_null(tree, 'ContentLibrary serves li_deaths_head.')
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_deaths_head instance ContentLibrary serves is the one mod_main holds.')

# ---------------------------------------------------------------- the live unit

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var knot:Unit = Fixture.create_knot(game, Vector2i(4, 4))
	assert_eq(knot.core.frame.compcon_id, FRAME_ID, 'It is wearing the Lovers Knot frame.')
	assert_eq(knot.core.current.health, SHEET_STATS.health, 'The sheet HP after a repair.')
	assert_eq(knot.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(knot.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(knot.get_heat_max(), SHEET_STATS.heat, 'The sheet heat cap.')
	assert_eq(knot.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(knot.is_player_controlled(), 'PLAYER controlled, which every relation here assumes.')
	assert_true(UnitCondition.has_buff(knot, Fixture.PRECISION_VENTING_BUFF), 'Precision Venting\'s buff is live.')
	assert_true(GearCore.is_valid(knot.get_gear(Fixture.FRACTURED_SILHOUETTE_ID)), 'Fractured Silhouette is on the unit.')

func test_fragile_puts_plus_one_difficulty_on_hull_saves_and_not_on_systems():
	# Ruling 22, measured on a live save rather than read off the resource: a d20 that makes an
	# unmodified Hull save by exactly the margin fails it with Fragile's -1, and the same d20 on a
	# Systems save still passes.
	var game:Gamemaster = Fixture.create_game(self)
	var knot:Unit = Fixture.create_knot(game, Vector2i(4, 4))
	var hostile:Unit = Fixture.create_hostile(game, Vector2i(6, 4))
	var hull_needed:int = hostile.get_save_target() - knot.core.get_hull()
	var sys_needed:int = hostile.get_save_target() - knot.core.get_sys()
	VaubanFixture.queue_save_dice(hull_needed)
	var hull_passed:bool = await VaubanFixture.force_hull_save(self, knot, VaubanFixture.forcer(hostile, &'ms_fragment_signal'))
	VaubanFixture.queue_save_dice(sys_needed)
	var sys_passed:bool = await UnitHasecheck.make_systems_save(VaubanFixture.save_event(self), knot, VaubanFixture.forcer(hostile, &'ms_fragment_signal'))
	assert_false(hull_passed, 'An exact-margin Hull save fails: Fragile is +1 Difficulty on Hull.')
	assert_true(sys_passed, 'The same margin on a Systems save passes: Fragile is Hull only.')

static func _packed(c:Color) -> int:
	return (roundi(c.r * 255.0) << 16) | (roundi(c.g * 255.0) << 8) | roundi(c.b * 255.0)
