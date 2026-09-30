# The Rakshasa (HORUS, Goblin alt) - SP1, design section 1.1 and 1.4. test_grutte_pier_frame.gd's
# shape, re-pointed.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/17-rakshasa.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically. A red here means the
# .tres drifted from the card, OR that the sheet was regenerated.
#
# NOT SIZE 1/2, unlike the Goblin it replaces (design 1.1): the sheet says size 1, and a copied Goblin
# statblock would carry is_size_half along with it.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rakshasa_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_rakshasa'
const LICENSE_ID := &'li_goblin'
const GOBLIN_ID := &'mf_goblin'
const MOD_ID := 'Reag-TheSixthVoice'

const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_goblin.tres_ext.gd'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## Vanilla li_goblin's OWN rank 2 gear, pinned exactly (read off content/licenses/horus/li_goblin.tres,
## 2026-09-26). An alt adds a frame and nothing else.
const GOBLIN_RANK_2_GEAR:Array[StringName] = [&'ms_metahook', &'ms_h0r_os_system_upgrade_ii']

## Other li_goblin extenders a testkit run can contain, and the frame each grants there (design
## "Contested seams"). fateofman-imi_alt_frames appends its Cambion to this very rank from its own
## mod_main._init (the live zip; the .bk copy used a .tres_ext.gd). It is parked in
## lancer-tactics-claude/.bk, so a 1.4.x testkit run does not load it and the check below skips - but
## its zip is installed, so the real game does. Same shape and
## reasoning as test_subutai_frame.gd's OTHER_EXTENDERS.
const OTHER_EXTENDERS := {
	'fateofman-imi_alt_frames': &'mf_cambion',
}

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 0, evasion = 8, edef = 11,
	speed = 4, heat = 5, save_target = 12, sensor_range = 20, tech_attack = 0, repairs = 3,
	systems_points = 7, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order, Fragile by path (vanilla's), then the core system (design 1.1). The core
## Kit ships empty at SP1; SP2-SP4 fill it without moving this pin.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_worm_code', &'mt_silver_tongue', &'mt_fragile', &'cp_short_wave_disruptors',
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
	assert_not_null(_frame(), 'mf_rakshasa loads as a valid Frame through ContentLibrary.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_false(frame.stat.is_size_half, 'A full size 1, not the Goblin\'s half size.')

func test_the_mounts_are_flex_then_main():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_main.tres'], 'Flex, Main, as the sheet lists them.')

func test_the_role_is_controller_alone():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.CONTROLLER, 'Primary role CONTROLLER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role: the sheet names one.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of every Goblin trait but Fragile, and of the
	# Goblin's core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Worm Code, Silver Tongue, Fragile, then Short Wave Disruptors.')

func test_fragile_is_vanillas_own_kit_by_path():
	# Design ruling 32: reused, never authored. The SAME resource the Goblin carries, so a player
	# reading either frame's Fragile reads one card.
	var frame:Frame = _frame()
	var goblin:Frame = ContentLibrary.get_mech_frame(GOBLIN_ID)
	assert_not_null(frame, 'mf_rakshasa loads.')
	assert_not_null(goblin, 'mf_goblin loads.')
	if frame == null or goblin == null: return
	var ours:Kit = null
	for kit:Kit in frame.traits: if kit.compcon_id == Fixture.FRAGILE_ID: ours = kit
	assert_not_null(ours, 'The Rakshasa carries mt_fragile.')
	if ours == null: return
	assert_eq(ours.resource_path, 'res://content/frames/shared/mt_fragile.tres', 'Vanilla\'s own file.')
	assert_true(goblin.traits.has(ours), 'The very Kit the Goblin carries.')

func test_no_other_goblin_trait_is_shared():
	var frame:Frame = _frame()
	var goblin:Frame = ContentLibrary.get_mech_frame(GOBLIN_ID)
	if frame == null or goblin == null:
		fail_test('Both frames load.')
		return
	for kit:Kit in goblin.traits:
		if kit.compcon_id == Fixture.FRAGILE_ID: continue
		assert_false(frame.traits.has(kit), "The Rakshasa does not carry the Goblin's %s." % kit.compcon_id)

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
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_true(sprite.resource_path.ends_with('/mf_rakshasa.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_the_arts_own_three_means():
	# Transcribed literals (mf_rakshasa.tres's comment has the census): the dark oxblood plate, the
	# lavender glow and the gunmetal grey. INERT - the sprite has no channel-encoded pixels - and
	# pinned so the day encoded art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_rakshasa loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(_packed(ours.base_0), 0x5e3533, 'base_0 is the dark oxblood plate (94,53,51).')
	assert_eq(_packed(ours.base_1), 0xad96cf, 'base_1 is the lavender glow (173,150,207).')
	assert_eq(_packed(ours.base_2), 0x646468, 'base_2 is the gunmetal grey (100,100,104).')
	var goblin:Frame = ContentLibrary.get_mech_frame(GOBLIN_ID)
	if goblin == null or goblin.default_color_scheme == null: return
	assert_ne(ours.base_0, goblin.default_color_scheme.base_0, 'Not a clone of the Goblin\'s scheme.')

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.mf_rakshasa.name', 'frame.mf_rakshasa.flavor', 'frame.mf_rakshasa.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_rakshasa.name'), 'Rakshasa', 'The frame is named Rakshasa.')
	assert_eq(X.tr('frame.mf_rakshasa.flavor.short'), 'Mask Code', 'The tagline the author picked (ruling 1).')

func test_the_flavour_is_the_lcp_paragraph_entire():
	var flavour:String = X.tr('frame.mf_rakshasa.flavor')
	assert_true(flavour.begins_with('The Rakshasa was the first identifiable Horus pattern'), 'Opens on the LCP\'s first clause.')
	assert_true(flavour.ends_with('Surely nothing bad could come of this.'), 'And ends on its last.')

func test_the_trait_rows_resolve_verbatim():
	assert_eq(X.tr('gear.mt_worm_code.name'), 'Worm Code', 'Worm Code is named.')
	assert_eq(X.tr('gear.mt_silver_tongue.name'), 'Silver Tongue', 'Silver Tongue is named.')
	for key:String in ['gear.mt_worm_code.effect', 'gear.mt_silver_tongue.effect']:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_string_contains(X.tr('gear.mt_worm_code.effect'), 'fails a save the Rakshasa forced')
	assert_string_contains(X.tr('gear.mt_silver_tongue.effect'), 'reroll the attack against a different target')

func test_the_core_systems_rows_are_already_written():
	# Design 1.1: SP1 writes the core system's rows so SP2-SP4 build against text that already exists.
	for key:String in [
		'gear.cp_short_wave_disruptors.name',
		'gear.cp_short_wave_disruptors.flavor',
	]:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.cp_short_wave_disruptors.name'), 'Short Wave Disruptors', 'The LCP\'s name.')
	assert_true(X.tr('gear.cp_short_wave_disruptors.flavor').begins_with('//MOLD ME//'), 'The LCP\'s core flavour.')

# ---------------------------------------------------------------- the licence

func test_the_goblin_licence_grants_the_rakshasa_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Rakshasa.')
	assert_has(granted, GOBLIN_ID, 'Rank 2 still grants the Goblin.')

func test_the_goblin_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_goblin loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, GOBLIN_ID, 'The Goblin is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_goblin.name'), 'The licence is still named for the Goblin.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_goblin loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Rakshasa is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_goblin.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_rakshasa():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Goblin 2 pilot is offered the Rakshasa.')
	assert_has(ids, GOBLIN_ID, 'And is still offered the Goblin itself.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Goblin 1 pilot is not offered it yet.')

func test_the_goblins_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_goblin loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, GOBLIN_RANK_2_GEAR, 'Rank 2 grants exactly HORUS\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	assert_not_null(retained, 'mod_main still exposes _retained_resources.')
	assert_not_null(tree, 'ContentLibrary serves li_goblin.')
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_goblin instance ContentLibrary serves is the one mod_main holds.')

func test_another_mods_goblin_alt_still_coexists_when_it_is_loaded():
	# The contested seam (design "Contested seams": imi_alt_frames' Cambion), test_mk2_frame.gd's shape.
	# Skips while that mod is parked; asserts the moment it is in the run.
	var granted := _rank_2_frame_ids()
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is granted either way.')
	if checked == 0: pass_test('No other li_goblin extender installed; nothing to co-exist with.')

# ---------------------------------------------------------------- the live unit

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var rakshasa:Unit = Fixture.create_rakshasa(game, Vector2i(4, 4))
	assert_eq(rakshasa.core.frame.compcon_id, FRAME_ID, 'It is wearing the Rakshasa frame.')
	assert_eq(rakshasa.core.current.health, SHEET_STATS.health, 'The sheet HP after a repair.')
	assert_eq(rakshasa.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(rakshasa.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(rakshasa.get_heat_max(), SHEET_STATS.heat, 'The sheet heat cap.')
	assert_eq(rakshasa.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(rakshasa.is_player_controlled(), 'PLAYER controlled, which every relation here assumes.')
	assert_true(UnitCondition.has_buff(rakshasa, Fixture.SILVER_TONGUE_BUFF), 'Silver Tongue\'s buff is live.')

func test_fragile_puts_plus_one_difficulty_on_hull_saves_and_not_on_systems():
	# Ruling 32, measured on a live save rather than read off the resource: a d20 that makes an
	# unmodified Hull save by exactly the margin fails it with Fragile's -1, and the same d20 on a
	# Systems save still passes. The Rakshasa's save target 12, Hull 0 and Systems 0 on the dummy
	# pilot, so 12 is the exact-pass roll.
	var game:Gamemaster = Fixture.create_game(self)
	var rakshasa:Unit = Fixture.create_rakshasa(game, Vector2i(4, 4))
	var hostile:Unit = Fixture.create_hostile(game, Vector2i(6, 4))
	var hull_needed:int = hostile.get_save_target() - rakshasa.core.get_hull()
	var sys_needed:int = hostile.get_save_target() - rakshasa.core.get_sys()
	Fixture.queue([hull_needed])
	var hull_passed:bool = await Fixture.force_hull_save(self, rakshasa, Fixture.forcer(hostile))
	Fixture.queue([sys_needed])
	var sys_passed:bool = await Fixture.force_systems_save(self, rakshasa, Fixture.forcer(hostile))
	assert_false(hull_passed, 'An exact-margin Hull save fails: Fragile is +1 Difficulty on Hull.')
	assert_true(sys_passed, 'The same margin on a Systems save passes: Fragile is Hull only.')

static func _packed(c:Color) -> int:
	return (roundi(c.r * 255.0) << 16) | (roundi(c.g * 255.0) << 8) | roundi(c.b * 255.0)
