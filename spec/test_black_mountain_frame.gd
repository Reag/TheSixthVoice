# The Black Mountain (SSC, Emperor alt) - SP1, design section 1.1. test_six_sky_frame.gd's shape,
# re-pointed at the second alt whose base licence ANOTHER MOD adds.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/20-black-mountain.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically.
#
# li_emperor comes from gavstarb-ssc_emperor, a resident since 2026-09-16 (testkit/compat_seams.gd
# RESIDENTS, criterion A: it contests the overshield seam), so it loads in every run;
# testkit/test_modkit_probe.gd fails if it goes missing. The guard section pins that a player WITHOUT
# that mod logs no error (design ruling 2), and test_late_licence_extension.gd pins the other install
# order.
#
# THE SPRITE IS THE AUTHOR'S OWN (supplied after the close, 2026-09-27): the placeholder test flipped
# to test_the_frame_has_a_sprite_that_actually_loaded, and the colour scheme is a 3-means over the art.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_black_mountain_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const ModMain := preload('res://unpacked/Reag-TheSixthVoice/mod_main.gd')

const MOD_ID := 'Reag-TheSixthVoice'
const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/unpacked/gavstarb-ssc_emperor/res/content/licenses/ssc/li_emperor.tres_ext.gd'
## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling mod loaded in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The Emperor licence's OWN rank 2 gear, pinned exactly (read off the resident's li_emperor.tres,
## 2026-09-27). An alt adds a frame and nothing else.
const EMPEROR_RANK_2_GEAR:Array[StringName] = [&'ms_the_imperial_eye', &'ms_shahnameh']

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins. SIZE 1/2 is size 1 + is_size_half (asserted separately).
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 6, armor = 1, evasion = 8, edef = 8,
	speed = 4, heat = 6, save_target = 10, sensor_range = 10, tech_attack = -2, repairs = 3,
	systems_points = 6, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order - Fragile is VANILLA (ruling 10) - then the core system (a shell at SP1).
const SHEET_TRAITS:Array[StringName] = [
	&'mt_an_end_to_all_things', &'mt_dread_harbinger', &'mt_fragile', &'cp_blackstone_bell',
]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _frame() -> Frame:
	var frame = ContentLibrary.get_mech_frame(Fixture.FRAME_ID)
	return frame if Frame.is_valid(frame) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(Fixture.LICENSE_ID)
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
		if frame.compcon_id == Fixture.FRAME_ID: count += 1
	return count

# ---------------------------------------------------------------- the frame

func test_the_frame_is_in_the_content_library():
	assert_not_null(_frame(), 'mf_black_mountain loads as a valid Frame through ContentLibrary.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_true(frame.stat.is_size_half, 'Size 1/2: size 1 plus is_size_half (ruling 2, the Fitzgerald\'s form).')

func test_the_stats_are_not_the_emperors():
	# An alt is its own sheet. Pinned against the resident's frame so a copy-paste from the base would
	# show here rather than in play.
	var frame:Frame = _frame()
	var emperor:Frame = ContentLibrary.get_mech_frame(Fixture.EMPEROR_ID)
	if frame == null or not Frame.is_valid(emperor):
		fail_test('Both frames load (the Emperor from the resident mod).')
		return
	assert_ne(frame.stat.sensor_range, emperor.stat.sensor_range, 'Sensors 10, not the Emperor\'s 15.')
	assert_ne(frame.stat.speed, emperor.stat.speed, 'Speed 4, not the Emperor\'s 5.')
	assert_ne(frame.stat.health, emperor.stat.health, 'HP 6, not the Emperor\'s 2.')
	assert_false(emperor.stat.is_size_half, 'CONTROL: the Emperor is a full size 1.')

func test_the_one_mount_is_flex():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres'], 'Flex alone, as the sheet lists it.')

func test_the_roles_are_support_then_controller():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.SUPPORT, 'Primary role SUPPORT.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.CONTROLLER, 'Secondary role CONTROLLER.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of every Emperor trait, and of its core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'An End to All Things, Dread Harbinger, Fragile, then the core.')

func test_fragile_is_the_vanilla_trait_not_a_copy():
	var frame:Frame = _frame()
	if frame == null:
		fail_test('The frame loads.')
		return
	var fragile:Kit = null
	for kit:Kit in frame.traits:
		if kit.compcon_id == Fixture.FRAGILE_ID: fragile = kit
	assert_not_null(fragile, 'Fragile is on the frame.')
	if fragile == null: return
	assert_eq(fragile.resource_path, 'res://content/frames/shared/mt_fragile.tres', 'The vanilla shared trait, referenced (ruling 10).')
	assert_eq(fragile, ContentLibrary.get_kit(Fixture.FRAGILE_ID), 'The very instance ContentLibrary serves.')

func test_no_emperor_trait_is_shared():
	var frame:Frame = _frame()
	var emperor:Frame = ContentLibrary.get_mech_frame(Fixture.EMPEROR_ID)
	if frame == null or not Frame.is_valid(emperor):
		fail_test('Both frames load (the Emperor from the resident mod).')
		return
	assert_false(emperor.traits.is_empty(), 'CONTROL: the Emperor has traits to compare against.')
	for kit:Kit in emperor.traits:
		assert_false(frame.traits.has(kit), 'The Black Mountain does not carry the Emperor\'s %s.' % kit.compcon_id)

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_eq(kit.compcon_id, trait_id, '%s is itself, not the placeholder.' % trait_id)
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)
		assert_ne(X.tr('gear.%s.name' % trait_id), 'gear.%s.name' % trait_id, '%s has a name row.' % trait_id)

func test_the_core_is_a_core_power_carrying_exalt_fell_the_mighty_and_the_efficient_pair():
	# SP1 shipped the core Kit empty (design 1.1); SP2 filled it (design section 2).
	var core:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	if not Kit.is_valid(core):
		fail_test('The core Kit loads.')
		return
	assert_true(core.is_core_power(), 'cp_ keeps it a core power (kit.gd:66).')
	var ids:Array = core.actions.map(func(a:Action) -> StringName: return a.get_id())
	assert_eq(ids, [Fixture.EXALT_ACTION, Fixture.FELL_ACTION, Fixture.EFFICIENT_REFUND],
		'Exalt, Fell the Mighty, the Efficient refund.')
	assert_eq(core.passives.size(), 1, 'One passive: the shared Efficient stamp.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# THE AUTHOR SUPPLIED THE ART AFTER THE CLOSE, 2026-09-27, and this test flipped with it (the
	# Leoleth's shape). It used to assert the OPPOSITE - that the frame still wore the shared placeholder -
	# so that the swap would redden one named test and be a deliberate edit. This is that edit.
	#
	# A .tres pointing at an unimported PNG does not fail loudly: the whole frame drops out of
	# ContentLibrary with no error a player would see. Both halves are asserted - not the placeholder, AND
	# this frame's own filename - because several of this mod's frames are 80x80 with no "placeholder" in
	# their paths, so a sibling's sprite would pass the weaker check alone.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 (half) frame uses an 80x80 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'), "The author's own art, not the shared stand-in.")
	assert_true(sprite.resource_path.ends_with('/mf_black_mountain.png'),
		"The frame wears its OWN sprite - not a sibling frame's, and not the stand-in.")

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# A 3-MEANS OVER THE AUTHOR'S ART (the Lovers Knot's method), replacing the Lovers Knot's plum that
	# SP1 borrowed as a stand-in. mf_black_mountain.png (80x80, 1,596 opaque pixels) has ZERO
	# channel-encoded pixels, so the scheme cannot repaint the token and is INERT (memory
	# frame-sprites-not-channel-encoded) - pinned anyway, so the .tres cannot drift from the art it was
	# counted from. Most-used first, per the Iskander's slot convention.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_black_mountain loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Black Mountain carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.11764706, 0.07058824, 0.13725490, 1),
		"base_0 is the sprite's near-black violet body (30,18,35 - 735px).")
	assert_eq(ours.base_1, Color(0.25490196, 0.75294118, 0.82352941, 1),
		"base_1 is the sprite's cyan glow (65,192,210 - 513px).")
	assert_eq(ours.base_2, Color(0.29019608, 0.30980392, 0.43921569, 1),
		"base_2 is the sprite's slate (74,79,112 - 348px).")

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.mf_black_mountain.name', 'frame.mf_black_mountain.flavor', 'frame.mf_black_mountain.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_black_mountain.name'), 'Black Mountain', 'The frame is named Black Mountain.')
	assert_eq(X.tr('frame.mf_black_mountain.flavor.short'), 'Herald of Glory', 'The tagline the author chose (ruling 1).')

func test_the_flavour_is_the_lcp_text_entire():
	# Full-string equality against the LCP's frames.json (check_content.py is the authority).
	assert_eq(X.tr('frame.mf_black_mountain.flavor'), "The Emperor speaks of progress, of solutions to doors and breaking down the world atom by atom. The Black Mountain is the secondary approach, the soft key, the twisting of the locks and teasing apart of secrets. The Broadcasts provided the perfect set of doors for Smith Shimano to pick, and behind them lay secrets long left hidden. Here! In this code, is the key to that which is truly immortal, the door whom has plagued all mankind for so long. This is no fair task. The Emperor stood as the peak of accomplishment, an unimpeded leviathan of the sum total of all the greatest works. One can not reinvent the bow, it is the apex of its own form. And yet, there is always another peak to climb, another height to reach, another life to live, and another story to tell. Here! Take up your arms, brace your spirit, take heart oh implement of violence, climb that Black Mountain, and write your name in fire across the sky!",
		"Matches the LCP's flavour text verbatim (check_content.py).")

func test_the_trait_rows_resolve_verbatim():
	assert_eq(X.tr('gear.mt_an_end_to_all_things.name'), 'An End to All Things', 'An End to All Things is named.')
	assert_eq(X.tr('gear.mt_dread_harbinger.name'), 'Dread Harbinger', 'Dread Harbinger is named.')
	assert_eq(X.tr('gear.mt_an_end_to_all_things.action_an_end_to_all_things.name'), 'An End to All Things', 'The reaction names itself in the log and the confirm.')
	assert_eq(X.tr('gear.mt_dread_harbinger.action_dread_harbinger.name'), 'Dread Harbinger', 'The lock reaction names itself in the log.')
	assert_eq(X.tr('gear.buff_dread_harbinger_mark.name'), 'Dread Harbinger', 'The visible mark has its own name row (ruling 15).')
	assert_eq(X.tr('gear.buff_an_end_to_all_things_bonus.name'), 'An End to All Things', 'The +3 names the trait in the battle log, not a sibling action.')
	assert_eq(X.tr('gear.mt_an_end_to_all_things.effect'),
		'2/round, when an allied |character| with |OVERSHIELD| you granted makes a successful attack roll against a hostile |character| within |sensors| and |line of sight|, you may take 1 |heat| to have them deal +3 |bonus damage|.')
	assert_eq(X.tr('gear.mt_dread_harbinger.effect'),
		'1/round, whenever the Black Mountain or an allied |character| within |Sensors| and |line of sight| critically hits, the target receives |Lock On|. Additionally, when this |Lock On| is consumed, the Black Mountain gains 1d6 |Overshield|.')

func test_the_core_rows_are_already_written():
	# Design 1.1: SP1 writes the core system's rows so SP2 builds against text that already exists. The
	# LCP's core_system carries no description, so there is no flavour row.
	assert_eq(X.tr('gear.cp_blackstone_bell.name'), 'Blackstone Bell', 'The LCP\'s core name.')
	# The close (author): the passive's name leads the Kit's row, since Bringer of Glory has no action to carry it.
	assert_eq(X.tr('gear.cp_blackstone_bell.effect'), 'Bringer of Glory: Gain the Exalt |reaction|.')
	assert_eq(X.tr('gear.cp_blackstone_bell.action_exalt.name'), 'Exalt')
	assert_string_contains(X.tr('gear.cp_blackstone_bell.action_exalt.effect'), 'equal to 1 + |GRIT|')
	assert_eq(X.tr('gear.cp_blackstone_bell.action_fell_the_mighty.name'), 'Fell the mighty', 'The LCP\'s own capitalisation.')
	assert_string_contains(X.tr('gear.cp_blackstone_bell.action_fell_the_mighty.effect'), 'DOOMED for the rest of the scene')

func test_the_manifest_declares_the_emperor_and_names_the_black_mountain():
	var manifest:Dictionary = JSON.parse_string(FileAccess.get_file_as_string('res://unpacked/Reag-TheSixthVoice/manifest.json'))
	assert_not_null(manifest, 'The manifest parses.')
	if manifest == null: return
	assert_has(manifest.get('optional_dependencies', []), Fixture.EMPEROR_MOD,
		'Declared - inert while vanilla modset.gd:253 aborts the ordering, so the late extension in mod_main carries either order.')
	assert_does_not_have(manifest.get('dependencies', []), Fixture.EMPEROR_MOD, 'Optional: never required.')
	assert_string_contains(manifest.get('description', ''), 'the Black Mountain (SSC, an Emperor alt frame, which needs the SSC Emperor mod)')
	assert_string_contains(manifest.get('description', ''), 'SSC Emperor\'s in Mod Manage', 'The player-side workaround names the Emperor too.')

# ---------------------------------------------------------------- the licence

func test_the_emperor_licence_is_the_resident_mods_own():
	# Spike 9: the licence exists only at the other mod's unpacked path; nothing takes over a mirror.
	assert_true(ResourceLoader.exists(Fixture.LICENSE_PATH), 'li_emperor is at the Emperor mod\'s own path.')
	assert_false(ResourceLoader.exists('res://content/licenses/ssc/li_emperor.tres'), 'And there is no mirrored copy.')
	var tree := _license()
	assert_not_null(tree, 'ContentLibrary serves li_emperor.')
	if tree == null: return
	assert_eq(tree.resource_path, Fixture.LICENSE_PATH, 'The instance ContentLibrary serves is that file.')

func test_the_emperor_licence_grants_the_black_mountain_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, Fixture.FRAME_ID, 'Rank 2 grants the Black Mountain.')
	assert_has(granted, Fixture.EMPEROR_ID, 'Rank 2 still grants the Emperor.')

func test_the_emperor_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_emperor loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, Fixture.EMPEROR_ID, 'The Emperor is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_emperor.name'), 'The licence is still named for the Emperor.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_emperor loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Black Mountain is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_emperor.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_the_extension_is_at_the_path_mod_main_computes():
	assert_eq(ModMain.extension_script_path_for(Fixture.LICENSE_PATH), LICENSE_EXTENDER,
		'extension_script_path_for maps another mod\'s licence into res/unpacked/<that mod>/ (spike 9).')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_black_mountain():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(Fixture.LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, Fixture.FRAME_ID, 'An Emperor 2 pilot is offered the Black Mountain.')
	assert_has(ids, Fixture.EMPEROR_ID, 'And is still offered the Emperor itself.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(Fixture.LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, Fixture.FRAME_ID, 'An Emperor 1 pilot is not offered it yet.')

func test_the_emperors_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_emperor loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, EMPEROR_RANK_2_GEAR, 'Rank 2 grants exactly the Emperor mod\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	assert_not_null(retained, 'mod_main still exposes _retained_resources.')
	assert_not_null(tree, 'ContentLibrary serves li_emperor.')
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_emperor instance ContentLibrary serves is the one mod_main holds.')

# ---------------------------------------------------------------- the guard (design ruling 2)

func test_an_absent_other_mods_licence_is_dropped_before_anything_loads_it():
	# The case a player WITHOUT the Emperor mod is in: extendable() drops the path, so it is never
	# load()ed and never reaches mod_main's "Cannot extend %s: it did not load." error.
	var absent := 'res://unpacked/nobody-no_such_mod/res/content/licenses/ssc/li_nothing.tres'
	assert_false(ResourceLoader.exists(absent), 'PRECONDITION: the path really is absent.')
	var paths:Array[String] = [absent, Fixture.LICENSE_PATH]
	var kept:Array[String] = ModMain.extendable(paths)
	assert_does_not_have(kept, absent, 'An absent other-mod licence is dropped.')
	assert_has(kept, Fixture.LICENSE_PATH, 'CONTROL: the PRESENT Emperor licence is kept.')

func test_the_emperor_entry_is_declared_for_retention():
	assert_has(ModMain.EXTENDED_RESOURCES, Fixture.LICENSE_PATH,
		'mod_main.EXTENDED_RESOURCES declares li_emperor by the other mod\'s path.')

# ---------------------------------------------------------------- the live unit

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var black_mountain:Unit = Fixture.create_black_mountain(game, Vector2i(4, 4))
	assert_eq(black_mountain.core.frame.compcon_id, Fixture.FRAME_ID, 'It is wearing the Black Mountain frame.')
	assert_eq(black_mountain.core.current.health, SHEET_STATS.health, 'The sheet HP after a repair.')
	assert_eq(black_mountain.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(black_mountain.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(black_mountain.get_heat_max(), SHEET_STATS.heat, 'The sheet heat cap.')
	assert_eq(black_mountain.get_save_target(), SHEET_STATS.save_target, 'The sheet Save target.')
	assert_true(black_mountain.core.is_size_half(), 'Size 1/2 on the live unit (unit_core.gd:391).')
	assert_eq(black_mountain.occupied_tiles().size(), 1, 'A size-1/2 unit occupies one tile.')
	assert_true(black_mountain.is_player_controlled(), 'PLAYER controlled, which every relation here assumes.')
	assert_true(GearCore.is_valid(black_mountain.get_gear(Fixture.AN_END_ID)), 'An End to All Things is on the loadout.')
	assert_true(GearCore.is_valid(black_mountain.get_gear(Fixture.HARBINGER_ID)), 'Dread Harbinger is on the loadout.')
	assert_true(GearCore.is_valid(black_mountain.get_gear(Fixture.FRAGILE_ID)), 'Fragile is on the loadout.')
	assert_true(GearCore.is_valid(black_mountain.get_gear(Fixture.CORE_ID)), 'The core Kit is on the loadout.')

func test_fragile_really_bites_the_live_unit():
	# Vanilla's shared trait, applied by the loadout: +1 difficulty on Hull checks and saves is a
	# SAVE-channel buff on the unit (buff_skill_save). Finding 6 (Minor): has_buff_to(SAVE) alone would
	# pass for ANY SAVE-channel buff from ANY source, not specifically mt_fragile - assert the SOURCE
	# too (from_gear traces to the frame's own Fragile gear), plus a negative control with no Fragile.
	var game:Gamemaster = Fixture.create_game(self)
	var black_mountain:Unit = Fixture.create_black_mountain(game, Vector2i(4, 4))
	assert_true(UnitCondition.has_buff_to(black_mountain, Buff.TO.SAVE), 'Fragile\'s save buff is live on the unit.')
	var fragile_gear:GearCore = black_mountain.get_gear(Fixture.FRAGILE_ID)
	assert_true(GearCore.is_valid(fragile_gear), 'fixture: mt_fragile is on the loadout.')
	if not GearCore.is_valid(fragile_gear): return
	var save_buffs_from_fragile:Array = UnitCondition.get_buffs_to(black_mountain, Buff.TO.SAVE)
	save_buffs_from_fragile = save_buffs_from_fragile.filter(
		func(core:BuffCore) -> bool: return core.from_gear == fragile_gear.persistent_id)
	assert_false(save_buffs_from_fragile.is_empty(), 'The SAVE buff traces to mt_fragile specifically, not just any SAVE-channel source.')
	# CONTROL: a plain dummy has no Fragile trait, so no SAVE buff at all.
	var dummy:Unit = Fixture.create_dummy(game, Vector2i(6, 6))
	assert_false(UnitCondition.has_buff_to(dummy, Buff.TO.SAVE), 'CONTROL: nobody else on the map has a SAVE buff.')
