# The Koremasa (HA) - SP1, design section 1.1 and 1.5.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT (design ruling 33). Like the Leoleth, the Koremasa ships its own
# li_koremasa.tres rather than extending a vanilla licence, so there is no .tres_ext.gd, no
# mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row.
#
# THE SECOND SIZE-1/2 PLAYER FRAME. The Fitzgerald is the first (mf_fitzgerald.tres:26), and its
# test_the_frame_is_size_half is the shape copied here: the flag on the resource AND on a live unit,
# because UnitCore.is_size_half() (unit_core.gd:391) also reads the size bonus.
#
# Numbers come from the notes repo's specs/sixth-voice/16-koremasa.md Stats table, which is generated
# from the LCP; check_content.py checks the same numbers statically. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_koremasa_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const FRAME_ID := &'mf_koremasa'
const LICENSE_ID := &'li_koremasa'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table in the engine's field names. SIZE IS 1 WITH is_size_half SET - the Fitzgerald's
## form (statblock.gd:6); `size = 0` would be a different thing entirely.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 6, armor = 0, evasion = 10, edef = 8,
	speed = 4, heat = 8, save_target = 10, sensor_range = 5, tech_attack = 1, repairs = 4,
	systems_points = 6, reactions = 1, activations = 1,
}

## The sheet's trait order, then the core system (design ruling 33): appended at SP2, the one
## sub-project that moved this pin.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_plasma_shimmer', &'mt_exploit_weakness', &'mt_entrap', &'cp_overdrive_exploitation_sequences',
]

const KOREMASA_TILE := Vector2i(4, 4)

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

func test_the_frame_is_size_half():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_true(frame.stat.is_size_half, 'stat.is_size_half is true.')
	var game:Gamemaster = Fixture.create_game(self)
	var koremasa:Unit = Fixture.create_koremasa(game, KOREMASA_TILE)
	assert_true(koremasa.core.is_size_half(), 'The live unit reads as size-half.')
	assert_eq(koremasa.core.get_size_float(), 0.5, 'The live unit is size 0.5.')
	assert_eq(koremasa.occupied_tiles().size(), 1, 'And it occupies one tile.')

func test_the_mounts_are_flex_then_main_aux():
	# Sheet: "Mounts: Flex, Main/Aux". ORDER matters: the mech sheet draws mounts in array order and
	# check_content.py compares the wiring as an ordered sequence.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_main_aux.tres'], 'Flex then Main/Aux - the sheet.')

func test_the_roles_are_striker_then_controller():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.CONTROLLER, 'Secondary role CONTROLLER.')

func test_the_frame_carries_its_traits_in_sheet_order():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Plasma Shimmer, Exploit Weakness, Entrap, then the core system.')

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)

func test_the_frame_wears_its_own_sprite():
	# 80x80: a size-1/2 frame uses the size-1 token canvas, as the Fitzgerald's does. A .tres pointing
	# at an unimported PNG fails the whole frame out of ContentLibrary silently.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'An 80x80 token.')
	assert_true(sprite.resource_path.ends_with('/mf_koremasa.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_the_arts_own_three_means():
	# Transcribed literals (mf_koremasa.tres's comment has the census): the grey-violet plate, the pale
	# cyan plasma and the dark violet shadow. INERT - the sprite has no channel-encoded pixels - and
	# pinned so the day encoded art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(_packed(ours.base_0), 0x625f6b, 'base_0 is the grey-violet plate (98,95,107).')
	assert_eq(_packed(ours.base_1), 0x97b7c0, 'base_1 is the pale cyan plasma (151,183,192).')
	assert_eq(_packed(ours.base_2), 0x3b333d, 'base_2 is the dark violet shadow (59,51,61).')

func test_the_sprite_is_not_channel_encoded():
	# The shader-literal test palette_swap_func.gdshaderinc uses: pixel == (v,0,0)/(0,v,0)/(0,0,v)/
	# (0,v,v) for v in palette_index_r.png's seven values. Zero means the colour picker cannot repaint
	# this token (memory frame-sprites-not-channel-encoded), which is why the scheme above is inert.
	var frame:Frame = _frame()
	if frame == null or frame.sprites.is_empty() or frame.sprites[0] == null: return
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
	assert_eq(opaque, 1314, 'The 1,314 opaque pixels the census was taken over.')
	assert_eq(encoded, 0, 'None of them is channel-encoded.')

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.mf_koremasa.name', 'frame.mf_koremasa.flavor', 'frame.mf_koremasa.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_koremasa.name'), 'Koremasa', 'The frame is named Koremasa.')
	assert_eq(X.tr('frame.mf_koremasa.flavor.short'), 'Discrete Operative',
		'The tagline the author picked, the LCP\'s own spelling (ruling 1).')

func test_the_flavour_is_the_lcp_paragraph_entire():
	# The LCP breaks it twice with <br>; this mod renders a <br> as a space, one paragraph (the
	# Shackleton's and the Naga's rows), which is also check_localization's normalisation.
	var flavour:String = X.tr('frame.mf_koremasa.flavor')
	assert_true(flavour.begins_with('Developed in several blacksites on Ras Shamra'), 'Opens on the LCP\'s first clause.')
	assert_true(flavour.ends_with('who value results over continued survival.'), 'And ends on its last.')
	assert_eq(flavour.length(), 1134, 'The paragraph entire: 1134 characters.')

func test_the_trait_rows_resolve():
	# The three traits only: the core system's rows are its actions', not a Kit-level `.effect`
	# (vanilla's cp_instinct_rig has none either), and the test below checks those.
	for trait_id:StringName in SHEET_TRAITS.slice(0, 3):
		for field:String in ['name', 'effect']:
			var key := 'gear.%s.%s' % [trait_id, field]
			assert_ne(X.tr(key), key, '%s resolves.' % key)
	for field:String in ['name', 'trigger', 'effect']:
		var key := 'gear.mt_entrap.action_entrap_koremasa.%s' % field
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.mt_plasma_shimmer.effect'),
		'While it’s in the |DANGER ZONE|, attacks against the Koremasa have |+1 Difficulty|.',
		'Plasma Shimmer, verbatim (the LCP\'s curly apostrophe).')

func test_the_core_power_rows_are_already_written():
	# Design 1.1: SP1 writes the core power's rows so SP2 builds against text that already exists.
	for key:String in [
		'gear.cp_overdrive_exploitation_sequences.name',
		'gear.cp_overdrive_exploitation_sequences.action_lassissian_folly.name',
		'gear.cp_overdrive_exploitation_sequences.action_lassissian_folly.effect',
		'gear.cp_overdrive_exploitation_sequences.action_gut_reactor.name',
		'gear.cp_overdrive_exploitation_sequences.action_gut_reactor.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves.' % key)

# ---------------------------------------------------------------- the licence

func test_the_licence_is_registered():
	assert_not_null(_license(), '%s loads as an UnlockTree through ContentLibrary.' % LICENSE_ID)

func test_the_licence_grants_the_frame_at_rank_two_and_nowhere_else():
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null:
		fail_test('The licence has all three ranks.')
		return
	var rank_2_frames:Array = license.rank_2.granted_frames.map(func(f:Frame) -> StringName: return f.compcon_id)
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Koremasa, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_its_gear_rank_by_rank():
	# SP3 filled rank 1 (Makibishi Magnets, Phase Cloud); SP4 fills rank 2 (Rendwire Sickle,
	# Blinkblade Slice), SP5 rank 3 (Fusionbleed shuriken, Juxtaposition Augments). Each empty line
	# reddens exactly once, in the sub-project that fills it.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null or license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1:Array[StringName] = []
	for kit:Kit in license.rank_1.granted_gear: rank_1.append(kit.compcon_id)
	assert_eq(rank_1, [&'ms_makibishi_magnets', &'ms_phase_cloud'] as Array[StringName],
		'Rank 1: Makibishi Magnets and Phase Cloud, in sheet order (SP3).')
	assert_true(license.rank_2.granted_gear.is_empty(), 'Rank 2 grants no gear yet (SP4).')
	assert_true(license.rank_3.granted_gear.is_empty(), 'Rank 3 grants no gear yet (SP5).')

func test_the_licence_names_itself_after_the_frame_and_wears_its_sprite():
	# UnlockTree.license_name reads rank_2.granted_frames.front() (unlock_tree.gd:28-32): no row of
	# its own. The icon is the frame's own sprite, the li_leoleth.tres convention.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_koremasa.name'), 'Named for its frame.')
	assert_not_null(license.icon, 'The licence has an icon.')
	if license.icon == null: return
	assert_true(license.icon.resource_path.ends_with('/mf_koremasa.png'), 'The frame\'s own sprite.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_koremasa():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Koremasa 2 pilot is offered the Koremasa.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Koremasa 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var koremasa:Unit = Fixture.create_koremasa(game, KOREMASA_TILE)
	assert_eq(koremasa.core.frame.compcon_id, FRAME_ID, 'It is wearing the Koremasa frame.')
	assert_eq(koremasa.core.current.health, SHEET_STATS.health, 'The sheet HP after a repair.')
	assert_eq(koremasa.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(koremasa.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(koremasa.get_heat_max(), SHEET_STATS.heat, 'The sheet heat cap.')
	assert_true(koremasa.is_player_controlled(), 'PLAYER controlled, which every relation here assumes.')
	assert_true(UnitCondition.has_buff(koremasa, Fixture.SHIMMER_BUFF), 'Plasma Shimmer\'s chip is live.')

static func _packed(c:Color) -> int:
	return (roundi(c.r * 255.0) << 16) | (roundi(c.g * 255.0) << 8) | roundi(c.b * 255.0)
