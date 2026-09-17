# The Maiden's Blush (SSC, Mourning Cloak alt) - SP1 Task 2, with the trait list pinned in Task 6.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written: a frame whose filename prefix or resource group is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
# Numbers come from the notes repo's specs/sixth-voice/05-maidens-blush.md Stats table, which is
# generated from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the
# .tres drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in
# the lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_maidens_blush_frame.gd
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_maidens_blush'
const LICENSE_ID := &'li_mourning_cloak'
const MOURNING_CLOAK_ID := &'mf_mourning_cloak'
const MOD_ID := 'Reag-TheSixthVoice'

## Vanilla li_mourning_cloak's OWN rank 2 gear, pinned as an exact ordered list (read off
## content/licenses/ssc/li_mourning_cloak.tres, 2026-09-17). An alt frame adds a frame and nothing
## else, so anything appearing here is either our extension overreaching or a modkit update moving
## SSC's gear - both worth a red. Pinned exactly rather than relaxed to "none of them is ours": that
## weaker form cannot see a VANILLA kit being appended, and the appended thing in the natural mistake
## (a copy-paste from a licence that grants gear) is as likely to be vanilla's as ours.
##
## Note what is NOT here: mw_variable_sword is li_mourning_cloak RANK 3 gear, not rank 2. The fixture
## equips it directly, which needs no licence at all.
const CLOAK_RANK_2_GEAR:Array[StringName] = [&'ms_hunter_logic_suite', &'ms_singularity_motivator']

## Other li_mourning_cloak extenders a testkit run can contain, and the frame each grants there.
##
## EMPTY, AND THAT IS A MEASUREMENT RATHER THAN AN OVERSIGHT (2026-09-17). All 24 mod zips installed
## in %APPDATA%/LancerTactics/mods were swept for any file naming li_mourning_cloak and not one has
## one - including the three SSC candidates (gavstarb-ssc_alts_1st_party, fateofman-ssc_atlas,
## fateofman-ssc_white_witch) and fateofman-imi_alt_frames, which is the mod that contends for
## li_gms, li_barbarossa and li_goblin. The dict and the loop stay so that the day one arrives it is
## one row, not a new test; test_subutai_frame.gd and test_mk2_frame.gd both have live rows and this
## is the same shape.
const OTHER_EXTENDERS := {}

## The sheet's table (specs/sixth-voice/05-maidens-blush.md), in the engine's field names.
## Transcribed once, here, so a typo in the .tres shows up as a number and not as a vague "feels
## wrong".
##
## Worth reading beside the Mourning Cloak's own (12 evasion, 6 edef, 5 speed, 4 heat, save 10,
## Sensors 15): the Blush is slower, blinder, harder to hack and easier to hit, and every one of
## those differences is deliberate.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 0, evasion = 10, edef = 8,
	speed = 4, heat = 5, save_target = 11, sensor_range = 10, tech_attack = 0, repairs = 3,
	systems_points = 6, reactions = 1, activations = 1,
}

## The sheet's trait order (specs/sixth-voice/05-maidens-blush.md). The frame card lists traits in
## ARRAY order, so this is player-visible - and it is the one thing guarding an array that four
## separate tasks appended to, one at a time, each rewriting the whole file.
##
## SP2 APPENDS cp_caj_overhaul_modules AFTER these three (design §2.1) and will extend this list
## rather than replace it. The Maiden's Blush has no integrated weapon, so nothing follows the core.
const SHEET_TRAITS:Array[StringName] = [&'mt_rend', &'mt_uncertainty_field', &'mt_fade_strike']

const BLUSH_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(7, 4)

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

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func test_the_frame_is_in_the_content_library():
	assert_true(Frame.is_valid(_frame()), 'mf_maidens_blush is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_maidens_blush carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size; a size-1 frame that also set it would occupy one tile
	# while reporting height 0, and every adjacency and line-of-sight assertion in the trait specs
	# would quietly measure the wrong geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Maiden\'s Blush is a full size 1, not size 1/2.')

func test_the_mounts_are_aux_aux_then_main_aux():
	# Sheet order ("Mounts: Aux/Aux, Main/Aux"), and it is player-visible: the mech sheet draws mounts
	# in array order. Note this is the REVERSE of the Mourning Cloak's own (Main/Aux then Flex).
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_aux_aux.tres', 'mount_main_aux.tres'], 'Aux/Aux then Main/Aux.')

func test_the_role_is_striker_with_no_secondary():
	# The sheet lists one role, Striker. The Mourning Cloak itself is role_primary 1 with no
	# secondary, and the alt inherits that shape rather than inventing a second role.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_maidens_blush.sprites.
	#
	# 80x80 because the Blush is size 1, and the mod ships two stand-ins - mf_placeholder.png (80x80)
	# and mf_placeholder_160.png (160x160, for the size-2 Myconid) - so pointing a size-1 frame at the
	# 160x160 one renders it at double scale on the board.
	#
	# THE "NOT THE PLACEHOLDER" HALF IS SP3's, DELIBERATELY. SP1 and SP2 ship no art (ruling 16), so
	# the assertion test_subutai_frame.gd carries -
	# assert_false(sprite.resource_path.contains('placeholder')) - would be a THIRD deliberate red
	# here, and this sub-project's Global Constraints allow exactly two. SP3 adds that line in the
	# same commit that drops in the commissioned art.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')

func test_the_frame_has_a_colour_scheme():
	# Cloned from the Mourning Cloak's own inline scheme (tone_highcontrast on palette_1, a pale grey,
	# a teal and a deep red), so the stand-in sprite still reads as SSC on the board until SP3.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	assert_not_null(frame.default_color_scheme, 'The frame carries a default colour scheme.')

func test_the_name_and_flavour_resolve():
	# tr() falling through to the raw key is the signature of a missing CSV row OR of a stale compiled
	# .translation artifact; either way the card is blank in game.
	for key:String in ['frame.mf_maidens_blush.name', 'frame.mf_maidens_blush.flavor', 'frame.mf_maidens_blush.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_maidens_blush.name'), 'Maiden\'s Blush', 'The frame is named Maiden\'s Blush.')
	assert_eq(X.tr('frame.mf_maidens_blush.flavor.short'), 'Strange and Beautiful',
		'The tagline the author picked (ruling 16).')
	# THE LCP SPELLS THE FRAME'S OWN NAME WITHOUT AN APOSTROPHE INSIDE THE FLAVOUR PARAGRAPH, and the
	# localisation directive is verbatim: "Or you could get the Maidens Blush". This is the assertion
	# standing between that and a well-meaning correction.
	assert_true(X.tr('frame.mf_maidens_blush.flavor').contains('the Maidens Blush'),
		'The flavour keeps Bel\'s own spelling, "Maidens Blush", uncorrected.')

func test_the_mourning_cloak_licence_grants_the_maidens_blush_at_rank_two():
	var tree := _license()
	assert_not_null(tree, 'li_mourning_cloak loads.')
	if tree == null: return
	assert_not_null(tree.rank_2, 'li_mourning_cloak has a rank 2.')
	if tree.rank_2 == null: return
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Maiden\'s Blush.')
	assert_has(granted, MOURNING_CLOAK_ID, 'Rank 2 still grants the Mourning Cloak.')

func test_the_mourning_cloak_is_still_first_so_the_licence_keeps_its_name():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT(). Vanilla li_mourning_cloak DOES
	# declare rank_2 granting mf_mourning_cloak, so it IS named off this array - inserting instead of
	# appending would rename SSC's licence after our alt everywhere the UI shows it.
	var tree := _license()
	assert_not_null(tree, 'li_mourning_cloak loads.')
	if tree == null or tree.rank_2 == null: return
	assert_false(tree.rank_2.granted_frames.is_empty(), 'Rank 2 grants at least one frame.')
	if tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, MOURNING_CLOAK_ID,
		'The Mourning Cloak is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_mourning_cloak.name'),
		'The licence is still named for the Mourning Cloak.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	# apply_resource_extensions_directly() stamps APPLIED_META on the instance so a re-activation
	# cannot append the frame twice. A duplicated grant shows in game as the Maiden's Blush listed
	# twice on the licence card.
	var tree := _license()
	assert_not_null(tree, 'li_mourning_cloak loads.')
	if tree == null or tree.rank_2 == null: return
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	assert_eq(count, 1, 'The Maiden\'s Blush is granted exactly once.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_maidens_blush():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back.
	#
	# The Blush does NOT ride the M/K2's free-for-all branch. PilotCore.get_available_frames
	# (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3 regardless of pilot level, and
	# get_unlocked_licensed_frames, which walks the pilot's OWN RankProgress rows. SSC is not GMS, so
	# only the second half can ever reach us.
	#
	# Built through set_license_to_rank rather than by hand-constructing a RankProgress, so the test
	# goes through the same engine call the pilot editor does.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_mourning_cloak at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Mourning Cloak 2 pilot is offered the Maiden\'s Blush.')
	assert_has(ids, MOURNING_CLOAK_ID, 'And is still offered the Mourning Cloak itself.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative
	# (unlock_tree.gd:44-49), so an extension that appended to rank_1 by mistake would still show up at
	# rank 2 and every assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Mourning Cloak 1 pilot is not offered it yet.')

func test_the_mourning_cloaks_own_gear_is_untouched():
	# LICENCE GUARD 2 of 3. An alt frame adds a FRAME to the base licence and nothing else. Nothing
	# else in the suite reads li_mourning_cloak.granted_gear at all, so appending a kit in
	# li_mourning_cloak.tres_ext.gd - the natural shape of a copy-paste from a licence that grants
	# gear - would redden nothing without this.
	var tree := _license()
	assert_not_null(tree, 'li_mourning_cloak loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, CLOAK_RANK_2_GEAR, 'Rank 2 grants exactly SSC\'s own two systems.')
	# And named explicitly, because the list above is also what a modkit update would move: whatever
	# arrives here, it must at least not be ours.
	for kit:Kit in tree.rank_2.granted_gear:
		assert_false(kit.resource_path.contains(MOD_ID),
			'%s is not ours: an alt adds no gear to the base licence.' % kit.compcon_id)

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# LICENCE GUARD 1 of 3 - upstream bug 7 in one assertion, and the only thing on the branch that
	# asks it of li_mourning_cloak. _ModLoaderResourceExtension._save_resource no longer retains an
	# extended resource, so the extension evaporates the moment nothing holds the instance and the next
	# load() reads the unextended file off disk. Deleting mod_main.gd's
	# _retained_resources.append(extended) reddens NOTHING else: test_alt_frames.gd only checks the
	# path is DECLARED in EXTENDED_RESOURCES, and every other test in this file compares compcon_id
	# strings, which a freshly loaded vanilla licence would still answer for the Mourning Cloak.
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node "%s" is in the tree.' % MOD_ID)
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	assert_not_null(retained, 'mod_main has a _retained_resources array.')
	if retained == null: return
	var tree := _license()
	assert_not_null(tree, 'li_mourning_cloak loads.')
	if tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_mourning_cloak instance ContentLibrary serves is the one mod_main holds.')

func test_the_other_extenders_of_li_mourning_cloak_also_land():
	# LICENCE GUARD 3 of 3. Whoever else touched li_mourning_cloak in this run must still have their
	# frame in it - the queue collision (mod_main.gd's header) drops a queue-path extender silently,
	# and apply_resource_extensions_directly erases OUR key from the shared dictionary at :110
	# precisely so that theirs survives.
	#
	# OTHER_EXTENDERS is empty today (see its own comment: no installed mod names this licence at
	# all), so the loop is silent and the assert_has below is what keeps this test from asserting
	# nothing.
	var granted := _rank_2_frame_ids()
	gut.p('  installed, in order: %s' % [Compat.installed_mod_ids()])
	gut.p('  li_mourning_cloak rank 2 frames: %s' % [granted])
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is there too.')
	if checked == 0: pass_test('No other li_mourning_cloak extender installed; nothing to co-exist with.')

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = MaidensBlushFixture.create_game(self)
	var blush:Unit = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	assert_true(Unit.is_valid(blush), 'A unit was created.')
	if not Unit.is_valid(blush): return
	assert_eq(blush.core.frame.compcon_id, FRAME_ID, 'It is wearing the Maiden\'s Blush frame.')
	assert_eq(blush.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSOR, not core.current: the engine never writes evasion into the current block
	# (only health/armor/heat/speed/structure/stress/repairs are synced); Unit.get_evasion is
	# core.get_evasion() + state.stat_bonus.evasion (unit.gd:306, unit_core.gd:405).
	assert_eq(blush.get_evasion(), SHEET_STATS.evasion, 'It has the sheet evasion, read the way the engine reads it.')
	assert_eq(blush.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(blush.is_player_controlled(),
		'And it is PLAYER controlled - CommonActionUtil.confirm_use returns true without asking for '
		+ 'anyone else, so every prompt case in the trait specs depends on this.')

func test_the_fixture_arms_and_misses_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK, and it is the only thing that exercises three helpers Tasks 3-5 and SP2
	# lean on. equip_melee/equip_ranged have to land a weapon that is NOT basic gear (both the Rend
	# buff and the Fade Strike chip refuse basic gear by default, BuffWeaponType.allow_basic and
	# BuffModifyAttackRoll.allow_basic), and miss_from has to actually MISS - which is not observable
	# from "no damage", because the assault rifle is Reliable 2 and deals exactly that on a miss.
	var game:Gamemaster = MaidensBlushFixture.create_game(self)
	var blush:Unit = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	var hostile:Unit = MaidensBlushFixture.create_hostile(game, TARGET_TILE)

	MaidensBlushFixture.equip_melee(blush)
	MaidensBlushFixture.equip_ranged(blush)
	var melee:GearCore = blush.get_gear(MaidensBlushFixture.MELEE_ID)
	var ranged:GearCore = blush.get_gear(MaidensBlushFixture.RANGED_ID)
	assert_true(GearCore.is_valid(melee), 'The melee weapon is on the Blush.')
	assert_true(GearCore.is_valid(ranged), 'The ranged weapon is on the Blush.')
	if not (GearCore.is_valid(melee) and GearCore.is_valid(ranged)): return
	assert_false(blush.core.loadout.is_gear_basic(melee),
		'And the melee weapon is NOT basic gear - which is what lets Rend and Fade Strike see it.')
	assert_false(blush.core.loadout.is_gear_basic(ranged), 'Nor is the ranged one.')

	# The Blush's own evasion is 10, and miss_from cheats a d20 of 1 against it.
	await MaidensBlushFixture.miss_from(game, hostile, blush)
	assert_eq(blush.current_damage(), MaidensBlushFixture.RELIABLE_ON_MISS,
		'miss_from missed: the Blush took exactly the rifle\'s Reliable 2 and no more.')

func test_the_traits_are_the_three_sheet_traits_in_sheet_order():
	# Asserted as an exact ORDERED list rather than as a set: the sheet prints Rend, Uncertainty
	# Field, Fade Strike in that order and the character sheet draws them in array order, so a
	# reshuffle is a visible change with no other guard anywhere in the suite. It also catches the
	# natural mistake in the append-per-task shape this sub-project used - an entry added to the
	# ext_resource block and forgotten in the array, or added twice.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_maidens_blush loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Rend, Uncertainty Field, Fade Strike - in sheet order.')

func test_every_trait_kit_is_in_the_content_library():
	# The frame holding a Kit and ContentLibrary indexing it are different facts: a Kit whose filename
	# prefix or resource group is wrong is filed somewhere else and vanishes from get_kit with no
	# error, while the frame's own ext_resource keeps working perfectly. Everything that looks a trait
	# up by id - unit.get_gear, every trait spec's fixture, the icon guard - goes through the index.
	for trait_id:StringName in SHEET_TRAITS:
		var kit:Kit = ContentLibrary.get_kit(trait_id)
		assert_true(Kit.is_valid(kit), '%s is in the kits index.' % trait_id)
		if not Kit.is_valid(kit): continue
		assert_true(kit.is_trait, '%s is a trait, so it costs no SP and cannot be unequipped.' % trait_id)
