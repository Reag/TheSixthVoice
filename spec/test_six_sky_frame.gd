# The Six Sky (HA, Sunzi alt) - SP1, design section 1.1. test_lovers_knot_frame.gd's shape, re-pointed.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written. Numbers come from the notes repo's specs/sixth-voice/19-six-sky.md Stats table,
# generated from the LCP; check_content.py checks the same numbers statically.
#
# THE FIRST ALT WHOSE BASE LICENCE ANOTHER MOD ADDS. li_sunzi comes from gavstarb-ha_sunzi, a resident
# since this sub-project (testkit/compat_seams.gd RESIDENTS, criterion B), so it loads in every run;
# testkit/test_modkit_probe.gd fails if it goes missing. The last section pins the guard that keeps a
# player WITHOUT that mod from logging an error (design ruling 2).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_six_sky_frame.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const ModMain := preload('res://unpacked/Reag-TheSixthVoice/mod_main.gd')

const MOD_ID := 'Reag-TheSixthVoice'
const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres_ext.gd'
## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling mod loaded in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The Sunzi licence's OWN rank 2 gear, pinned exactly (read off the resident's li_sunzi.tres,
## 2026-09-26). An alt adds a frame and nothing else.
const SUNZI_RANK_2_GEAR:Array[StringName] = [&'mw_warp_rifle', &'ms_blinkspace_tunneler']

## The sheet's table in the engine's field names; reactions/activations/limited_bonus are the engine
## defaults every frame here pins.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 1, evasion = 8, edef = 8,
	speed = 4, heat = 7, save_target = 11, sensor_range = 15, tech_attack = 0, repairs = 4,
	systems_points = 7, reactions = 1, activations = 1, limited_bonus = 0,
}

## The sheet's trait order, then the core system and its integrated weapon (design 1.1). Both were
## shells at SP1; SP2 filled them without moving this pin.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_heavenly_weaver', &'mt_starsickness', &'cp_ors_daykeeper_cycler_bow', &'mw_daykeeper_cycler_bow',
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
	assert_not_null(_frame(), 'mf_six_sky loads as a valid Frame through ContentLibrary.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null or frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)
	assert_false(frame.stat.is_size_half, 'A full size 1.')

func test_the_one_mount_is_flex():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres'], 'Flex alone, as the sheet lists it.')

func test_the_roles_are_striker_then_controller():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.CONTROLLER, 'Secondary role CONTROLLER.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Exact and ordered: it also pins the ABSENCE of every Sunzi trait, and of its core.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Heavenly Weaver, Starsickness, then the core and its bow.')

func test_no_sunzi_trait_is_shared():
	var frame:Frame = _frame()
	var sunzi:Frame = ContentLibrary.get_mech_frame(Fixture.SUNZI_ID)
	if frame == null or not Frame.is_valid(sunzi):
		fail_test('Both frames load (the Sunzi from the resident mod).')
		return
	assert_false(sunzi.traits.is_empty(), 'CONTROL: the Sunzi has traits to compare against.')
	for kit:Kit in sunzi.traits:
		assert_false(frame.traits.has(kit), 'The Six Sky does not carry the Sunzi\'s %s.' % kit.compcon_id)

func test_every_trait_kit_is_in_the_content_library():
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_eq(kit.compcon_id, trait_id, '%s is itself, not the placeholder.' % trait_id)
		assert_true(kit.is_trait, '%s is a trait.' % trait_id)
		assert_ne(X.tr('gear.%s.name' % trait_id), 'gear.%s.name' % trait_id, '%s has a name row.' % trait_id)

func test_the_core_is_a_core_power_and_the_bow_is_filed_beside_it():
	# The two-Kit rule (memory integrated-weapon-two-kit-rule). test_integrated_weapon_shape.gd took the
	# Six Sky over at SP2, once the bow carried its attack; this stays as the ContentLibrary-side pin.
	var core:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	var bow:Kit = ContentLibrary.get_kit(Fixture.BOW_ID)
	if not Kit.is_valid(core) or not Kit.is_valid(bow):
		fail_test('Both Kits load.')
		return
	assert_true(core.is_core_power(), 'cp_ keeps it a core power (kit.gd:66).')
	assert_ne(core.compcon_id, bow.compcon_id, 'Two Kits, so each titles its own box.')
	assert_eq(bow.resource_path.get_base_dir(), core.resource_path.get_base_dir(), 'Filed together.')

func test_the_frame_wears_its_own_sprite():
	# A .tres pointing at an unimported PNG fails the whole frame out of ContentLibrary silently.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null or frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_true(sprite.resource_path.ends_with('/mf_six_sky.png'), 'Its own art, not a sibling\'s.')

func test_the_colour_scheme_is_the_arts_own_three_means():
	# Transcribed literals (mf_six_sky.tres's comment has the census). INERT - the sprite has no
	# channel-encoded pixels - and pinned so the day encoded art lands it inherits these.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_six_sky loads.')
	if frame == null or frame.default_color_scheme == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_eq(_packed(ours.base_0), 0x5e5b5b, 'base_0 is the gunmetal plate (94,91,91).')
	assert_eq(_packed(ours.base_1), 0x96a2a2, 'base_1 is the pale steel highlight (150,162,162).')
	assert_eq(_packed(ours.base_2), 0x101110, 'base_2 is the near-black shadow (16,17,16).')

func test_the_name_and_flavour_and_tagline_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['frame.mf_six_sky.name', 'frame.mf_six_sky.flavor', 'frame.mf_six_sky.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_six_sky.name'), 'Six Sky', 'The frame is named Six Sky.')
	assert_eq(X.tr('frame.mf_six_sky.flavor.short'), 'Apex of Form', 'The tagline the author picked (ruling 1).')

func test_the_flavour_is_the_lcp_text_entire():
	# Full-string equality against the LCP's frames.json, whose two <br> breaks read as one space each
	# (every flavour row here since the Fitzgerald). The LCP's apostrophes are all STRAIGHT here; the
	# sheet is never the reference for punctuation - check_content.py is.
	assert_eq(X.tr('frame.mf_six_sky.flavor'), "The Six Sky is a rare instance of corporate alliance, a combination of SSC's relentless perfection and Harrison's perpetual pursuit of progress. Utilizing the Armory's preexisting blinkspace technology and SSC's TIAX-UYL new slipstream innovations the Six Sky excels at rapid maneuverability in all theaters. Additionally, it boasts the ability to store excess potential energy formed from each blink, redirecting it towards hostile forces on demand. None of this however, is what the Six Sky is truly known for, that title goes to its signature weapon, the \"Daykeeper\" Cycler Bow. Built from SSC exotic materials frameworks and the Armory's O.R.S stabilization systems the Daykeeper serves as the best of both worlds, elegant, powerful, yet scalable enough to be used by Armory forces galaxy wide. Utilizing the unique blink-siphon technology and relying on the extreme built in mobility of the Six Sky to make full use of the unstable plasma, the Daykeeper is a formidable weapon. Unfortunately, the same collaboration that produced the Daykeeper is what keeps it solely as part of the Six Sky Licensing, with both companies needing to sign off on any would be pilots. SSC regards the bow as the apex of its form, unmistakable and iconic in its simple effectiveness, a timeless tool of conflict resolution. Harrison Agrees.",
		"Matches the LCP's flavour text verbatim (check_content.py).")

func test_the_trait_rows_resolve_verbatim():
	assert_eq(X.tr('gear.mt_heavenly_weaver.name'), 'Heavenly Weaver', 'Heavenly Weaver is named.')
	assert_eq(X.tr('gear.mt_starsickness.name'), 'Starsickness', 'Starsickness is named.')
	assert_eq(X.tr('gear.buff_heavenly_weaver.name'), 'Heavenly Weaver', 'The chip has its own name row (2026-09-22 house rule).')
	assert_eq(X.tr('gear.mt_starsickness.action_starsickness.name'), 'Starsickness', 'The save names its source.')
	assert_eq(X.tr('gear.mt_heavenly_weaver.effect'),
		'1/round, when the Six Sky |teleports| itself, or another |character|, the next successful attack it makes deals +1d6 |Bonus damage|.')
	assert_eq(X.tr('gear.mt_starsickness.effect'),
		'When the Six Sky |teleports| a hostile |character|, it may take |1 Heat|. If it does, that character must succeed on a |Systems save| or become |Impaired| until the end of their next turn.')

func test_the_core_and_bow_rows_are_already_written():
	# Design 1.1: SP1 writes the core system's and the bow's rows so SP2 builds against text that
	# already exists. The LCP's core_system carries no description, so there is no flavour row.
	assert_eq(X.tr('gear.cp_ors_daykeeper_cycler_bow.name'), 'ORS "DAYKEEPER" CYCLER BOW', 'The LCP\'s core name.')
	assert_eq(X.tr('gear.cp_ors_daykeeper_cycler_bow.action_ritual_of_the_first_god.name'), 'Ritual of the First God')
	assert_string_contains(X.tr('gear.cp_ors_daykeeper_cycler_bow.action_ritual_of_the_first_god.effect'), 'free space within |Range| 50')
	assert_eq(X.tr('gear.mw_daykeeper_cycler_bow.name'), 'DAYKEEPER CYCLER BOW', 'The LCP\'s weapon name.')
	assert_string_contains(X.tr('gear.mw_daykeeper_cycler_bow.effect'), '+1 |Accuracy| against targets within |Range| 5')
	assert_string_contains(X.tr('gear.mw_daykeeper_cycler_bow.on_crit'), 'Choose yourself or the target')

func test_the_manifest_declares_the_sunzi_and_names_the_six_sky():
	var manifest:Dictionary = JSON.parse_string(FileAccess.get_file_as_string('res://unpacked/Reag-TheSixthVoice/manifest.json'))
	assert_not_null(manifest, 'The manifest parses.')
	if manifest == null: return
	assert_has(manifest.get('optional_dependencies', []), Fixture.SUNZI_MOD,
		'Declared - inert while vanilla modset.gd:253 aborts the ordering, so the late extension in mod_main carries either order.')
	assert_does_not_have(manifest.get('dependencies', []), Fixture.SUNZI_MOD, 'Optional: never required.')
	assert_string_contains(manifest.get('description', ''), 'the Six Sky (HA, a Sunzi alt frame, which needs the HA Sunzi mod')
	assert_string_contains(manifest.get('description', ''), 'Load priority above HA Sunzi', 'The player-side workaround (close review).')

# ---------------------------------------------------------------- the licence

func test_the_sunzi_licence_is_the_resident_mods_own():
	# Spike 9: the licence exists only at the other mod's unpacked path; nothing takes over a mirror.
	assert_true(ResourceLoader.exists(Fixture.LICENSE_PATH), 'li_sunzi is at the Sunzi mod\'s own path.')
	assert_false(ResourceLoader.exists('res://content/licenses/ha/li_sunzi.tres'), 'And there is no mirrored copy.')
	var tree := _license()
	assert_not_null(tree, 'ContentLibrary serves li_sunzi.')
	if tree == null: return
	assert_eq(tree.resource_path, Fixture.LICENSE_PATH, 'The instance ContentLibrary serves is that file.')

func test_the_sunzi_licence_grants_the_six_sky_at_rank_two():
	var granted := _rank_2_frame_ids()
	assert_has(granted, Fixture.FRAME_ID, 'Rank 2 grants the Six Sky.')
	assert_has(granted, Fixture.SUNZI_ID, 'Rank 2 still grants the Sunzi.')

func test_the_sunzi_is_still_first_so_the_licence_keeps_its_name():
	var tree := _license()
	assert_not_null(tree, 'li_sunzi loads.')
	if tree == null or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, Fixture.SUNZI_ID, 'The Sunzi is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_sunzi.name'), 'The licence is still named for the Sunzi.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	var tree := _license()
	assert_not_null(tree, 'li_sunzi loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_grants_in(tree), 1, 'The Six Sky is granted exactly once.')
	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_sunzi.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)
	assert_eq(_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_the_extension_is_at_the_path_mod_main_computes():
	assert_eq(ModMain.extension_script_path_for(Fixture.LICENSE_PATH), LICENSE_EXTENDER,
		'extension_script_path_for maps another mod\'s licence into res/unpacked/<that mod>/ (spike 9).')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_six_sky():
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(Fixture.LICENSE_ID, 2)
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, Fixture.FRAME_ID, 'A Sunzi 2 pilot is offered the Six Sky.')
	assert_has(ids, Fixture.SUNZI_ID, 'And is still offered the Sunzi itself.')
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(Fixture.LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, Fixture.FRAME_ID, 'A Sunzi 1 pilot is not offered it yet.')

func test_the_sunzis_own_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_sunzi loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, SUNZI_RANK_2_GEAR, 'Rank 2 grants exactly the Sunzi mod\'s own two pieces of gear.')

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Upstream bug 7 in one assertion (test_vauban_frame.gd's LICENCE GUARD 1).
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node is in the tree.')
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	var tree := _license()
	assert_not_null(retained, 'mod_main still exposes _retained_resources.')
	assert_not_null(tree, 'ContentLibrary serves li_sunzi.')
	if retained == null or tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_sunzi instance ContentLibrary serves is the one mod_main holds.')

# ---------------------------------------------------------------- the guard (design ruling 2)

func test_an_absent_other_mods_licence_is_dropped_before_anything_loads_it():
	# The case a player WITHOUT the Sunzi mod is in. extendable() is what apply_resource_extensions_directly
	# loops over, so a path it drops is never load()ed and never reaches the ModLoaderLog.error on a miss
	# (mod_main.gd, "Cannot extend %s: it did not load.").
	var absent := 'res://unpacked/nobody-no_such_mod/res/content/licenses/ha/li_nothing.tres'
	assert_false(ResourceLoader.exists(absent), 'PRECONDITION: the path really is absent.')
	var paths:Array[String] = [absent, Fixture.LICENSE_PATH, 'res://content/licenses/ha/li_iskander.tres']
	var kept:Array[String] = ModMain.extendable(paths)
	assert_does_not_have(kept, absent, 'An absent other-mod licence is dropped.')
	assert_has(kept, Fixture.LICENSE_PATH, 'CONTROL: a PRESENT other-mod licence is kept.')
	assert_has(kept, 'res://content/licenses/ha/li_iskander.tres', 'CONTROL: a vanilla licence is always kept.')

func test_a_missing_vanilla_path_is_never_dropped():
	# The guard is for OTHER MODS only. A vanilla path that vanished is a real error and must still be
	# loaded, and so logged, by apply_resource_extensions_directly.
	var missing := 'res://content/licenses/ha/li_no_such_vanilla.tres'
	assert_false(ResourceLoader.exists(missing), 'PRECONDITION: the path really is absent.')
	var paths:Array[String] = [missing]
	assert_has(ModMain.extendable(paths), missing, 'A missing vanilla path is kept, so its miss is logged.')

func test_the_sunzi_entry_is_declared_for_retention():
	assert_has(ModMain.EXTENDED_RESOURCES, Fixture.LICENSE_PATH,
		'mod_main.EXTENDED_RESOURCES declares li_sunzi by the other mod\'s path.')

# ---------------------------------------------------------------- the live unit

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = Fixture.create_game(self)
	var six_sky:Unit = Fixture.create_six_sky(game, Vector2i(4, 4))
	assert_eq(six_sky.core.frame.compcon_id, Fixture.FRAME_ID, 'It is wearing the Six Sky frame.')
	assert_eq(six_sky.core.current.health, SHEET_STATS.health, 'The sheet HP after a repair.')
	assert_eq(six_sky.get_evasion(), SHEET_STATS.evasion, 'The sheet evasion.')
	assert_eq(six_sky.get_sensor_range(), SHEET_STATS.sensor_range, 'The sheet Sensors.')
	assert_eq(six_sky.get_heat_max(), SHEET_STATS.heat, 'The sheet heat cap.')
	assert_eq(six_sky.get_save_target(), SHEET_STATS.save_target, 'The sheet Save target.')
	assert_eq(six_sky.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(six_sky.is_player_controlled(), 'PLAYER controlled, which every relation here assumes.')
	assert_true(UnitCondition.has_buff(six_sky, Fixture.WEAVER_WATCH), 'Heavenly Weaver\'s watch is live.')
	assert_true(UnitCondition.has_buff(six_sky, Fixture.STARSICKNESS_BUFF), 'Starsickness\'s trigger is live.')
	assert_eq(UnitCondition.get_buffs(six_sky, Fixture.WEAVER_WATCH).size(), 1, 'Exactly one watch, however often it is reapplied.')
	assert_eq(UnitCondition.get_buffs(six_sky, Fixture.STARSICKNESS_BUFF).size(), 1, 'Exactly one trigger.')

func test_starsicknesss_action_is_never_a_button():
	# It names the save's forcer and nothing else (design 1.4, the script's header).
	var game:Gamemaster = Fixture.create_game(self)
	var six_sky:Unit = Fixture.create_six_sky(game, Vector2i(4, 4))
	var gear:GearCore = six_sky.get_gear(Fixture.STARSICKNESS_ID)
	assert_true(GearCore.is_valid(gear), 'Starsickness is on the unit.')
	if not GearCore.is_valid(gear): return
	var action:Action = gear.get_action(Fixture.STARSICKNESS_ACTION)
	assert_true(Action.is_valid(action), 'The hidden action is on the trait.')
	if not Action.is_valid(action): return
	assert_true(action.hide_if_disabled, 'hide_if_disabled, half of what keeps it off the hotbar.')
	assert_false(UnitAction.can_activate_gear(SpecificAction.create(six_sky, gear, action)),
		'And it can never be activated, the other half (gear_bar.gd:146-147).')
	assert_false(action.show_in_tooltip(gear.kit), 'It never appears in a tooltip either.')

static func _packed(c:Color) -> int:
	return (roundi(c.r * 255.0) << 16) | (roundi(c.g * 255.0) << 8) | roundi(c.b * 255.0)
