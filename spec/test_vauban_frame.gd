# The Vauban (HA, Iskander alt) - SP1 Task 1, with the trait list pinned in Task 6.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED, not
# merely written: a frame whose filename prefix or resource group is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
# Numbers come from the notes repo's specs/sixth-voice/06-vauban.md Stats table, which is generated
# from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in the
# lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_vauban_frame.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_vauban'
const LICENSE_ID := &'li_iskander'
const ISKANDER_ID := &'mf_iskander'
const MOD_ID := 'Reag-TheSixthVoice'

## The licence extension script, by path, so this file can run it a SECOND time itself - which is the
## only way a single-install test run can say anything about idempotence.
const LICENSE_EXTENDER := 'res://unpacked/Reag-TheSixthVoice/res/content/licenses/ha/li_iskander.tres_ext.gd'

## Vanilla li_iskander's OWN rank 2 gear, pinned as an exact ordered list (read off
## content/licenses/ha/li_iskander.tres, 2026-09-18). An alt frame adds a frame and nothing else, so
## anything appearing here is either our extension overreaching or a modkit update moving HA's gear -
## both worth a red. Pinned exactly rather than relaxed to "none of them is ours": that weaker form
## cannot see a VANILLA kit being appended, and the appended thing in the natural mistake (a
## copy-paste from a licence that grants gear) is as likely to be vanilla's as ours.
##
## Note what is NOT here: ms_grounding_charges and mw_stub_cannon are RANK 1, ms_clamp_bombs and
## ms_tesseract are RANK 3. Rank 2 grants exactly these two alongside the Iskander itself.
const ISKANDER_RANK_2_GEAR:Array[StringName] = [&'mw_gravity_gun', &'ms_repulser_field']

## Other li_iskander extenders a testkit run can contain, and the frame each grants there.
##
## EMPTY, AND THAT IS A MEASUREMENT RATHER THAN AN OVERSIGHT (2026-09-18, design's Contested seams
## line). All 24 mod zips installed in %APPDATA%/LancerTactics/mods were swept for any file naming
## li_iskander and not one has one - including fateofman-imi_alt_frames, which is the mod that
## contends for li_gms, li_barbarossa and li_goblin. The dict and the loop stay so that the day one
## arrives it is one row, not a new test; test_subutai_frame.gd and test_mk2_frame.gd both have live
## rows and this is the same shape.
const OTHER_EXTENDERS := {}

## The sheet's table (specs/sixth-voice/06-vauban.md), in the engine's field names. Transcribed once,
## here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
##
## SEVENTEEN FIELDS, not the card's fourteen columns. `reactions` and `activations` are the vanilla
## default and the Iskander's own values (mf_iskander.tres:44-45); neither the card nor design ruling
## 14 names them, so they are pinned as an engine default rather than as sourced numbers (close review
## M4, 2026-09-18 - the sentence here used to claim ruling 14 listed both, and it does not).
## `limited_bonus` is the seventeenth Statblock PROP field (statblock.gd:28) and the one this loop
## used to leave unpinned. It is not inert - GearCore.get_max_charges adds it to every limited gear's
## max charges (gear_core.gd:236-238, :244) - and no vanilla frame under content/frames/ sets it at
## all, so a non-zero here would be both unprecedented and silent.
##
## Worth reading beside the Iskander's own (size 2, armor 1, evasion 8, edef 10, speed 3, Sensors 15,
## tech attack +1, repairs 3): the Vauban is SMALLER, better armoured, easier to hit, far blinder and
## worse at hacking, and every one of those differences is deliberate.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 2, evasion = 6, edef = 8,
	speed = 4, heat = 7, save_target = 12, sensor_range = 8, tech_attack = -1, repairs = 4,
	systems_points = 6, reactions = 1, activations = 1, limited_bonus = 0,
}

const VAUBAN_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(7, 4)
const FIELD:Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 4)]

## The sheet's trait order (specs/sixth-voice/06-vauban.md). The frame card lists traits in ARRAY
## order, so this is player-visible - and it is the one thing guarding an array that four separate
## tasks appended to, one at a time, each rewriting the whole file.
##
## SP2 appended cp_earth_shaker_grav_gen after the three traits (design §2.1). The Vauban has no
## integrated weapon, so nothing follows the core.
const SHEET_TRAITS:Array[StringName] = [&'mt_solfataric_breach', &'mt_sap', &'mt_gravity_well', &'cp_earth_shaker_grav_gen']

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

## How many times rank 2 grants OUR frame. Counted rather than asked with has(), because the failure
## this guards is a DUPLICATE grant, which has() cannot see.
func _vauban_grants_in(tree:UnlockTree) -> int:
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	return count

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func test_the_frame_is_in_the_content_library():
	assert_true(Frame.is_valid(_frame()), 'mf_vauban is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_vauban carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size; a size-1 frame that also set it would occupy one tile
	# while reporting height 0, and every adjacency and line-of-sight assertion in the trait specs
	# would quietly measure the wrong geometry. Gravity Well's aura measures range 1 through
	# UnitRelation.distance_between, which takes the vertical term from get_height().
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Vauban is a full size 1, not size 1/2.')

func test_the_mounts_are_flex_then_heavy():
	# SHEET ORDER ("Mounts: Flex, Heavy"), and it is player-visible: the mech sheet draws mounts in
	# array order. THE SHEET AND THE BASE FRAME DISAGREE, DELIBERATELY - vanilla mf_iskander.tres
	# lists mount_heavy then mount_flex. The sheet wins (design ruling 14 pins the stats "verbatim
	# from the sheet"), and this assertion is the reason that disagreement can never be silently
	# "corrected" back to the Iskander's order by someone copying its file.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_heavy.tres'], 'Flex then Heavy, as the sheet lists them.')

func test_the_role_is_controller_with_no_secondary():
	# The sheet lists one role, Controller. The Iskander itself is role_primary 3 with no secondary,
	# and the alt inherits that shape rather than inventing a second role.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.CONTROLLER, 'Primary role CONTROLLER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_vauban.sprites.
	#
	# 80x80 because the Vauban is size 1. The art is the frame's OWN file rather than the shared
	# mf_placeholder.png stand-in, so unlike the Maiden's Blush at SP1 this file CAN assert the
	# "not the placeholder" half now rather than deferring it to SP3. Note the frame close uses the
	# word in a SECOND sense: ruling R4 calls this art a placeholder because it is not
	# channel-encoded yet, so the ColorScheme cannot repaint it. Both are true and they are not the
	# same claim - see test_the_colour_scheme_is_derived_from_the_frames_own_art.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_false(sprite.resource_path.contains('placeholder'),
		'And it is the author\'s own art, not the shared stand-in.')
	# NEITHER ASSERTION ABOVE CAN SEE THE LIKELIEST REGRESSION (close review I1, 2026-09-18), and the
	# mitigation this file used to lean on only covers half of it: the Iskander's own three sprites are
	# 160x160, so a copy-paste from the BASE frame is caught by the size check - but three of this
	# mod's own frames (mf_maidens_blush, ipsn_fitzgerald, mk2_bombard) are 80x80 with no "placeholder"
	# in their paths, so pointing the ext_resource at a SIBLING is invisible to the whole suite. Only
	# checking the frame's own filename does. Matches test_maidens_blush_frame.gd:160-161.
	assert_true(sprite.resource_path.ends_with('/mf_vauban.png'),
		'The frame wears its OWN sprite - not a sibling frame\'s, and not the stand-in.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# LITERALS, NOT A RELATIONSHIP, AND THAT IS THE WHOLE POINT (ruling R4, 2026-09-18). This test used
	# to assert equality against the LIVE Iskander, because the scheme was a byte-for-byte clone of
	# mf_iskander.tres:20-26 - the shape test_maidens_blush_frame.gd and test_myconid_frame.gd still
	# use, where the statement worth making is "the alt is painted like its base, so a modkit update
	# that repaints the base should say so". The Vauban's scheme is not that. It is generated by a
	# colour census of OUR OWN mf_vauban.png, so there is no relationship left to assert and the
	# Iskander's values are no longer what would notice a drift. Only transcribed literals can.
	#
	# The four are the sprite's four materials - dark plum chassis, bone plating, teal glow, gold
	# accent - in vanilla's most-used-channel-first slot order, and they agree with the .tres byte for
	# byte. They are INERT on the token today: mf_vauban.png carries 2,515 opaque pixels and not one
	# channel-encoded pixel, so nothing routes through the scheme at all. (That is what ruling R4 means
	# by calling the art a placeholder - it is the frame's own file, not the shared mf_placeholder.png
	# stand-in the sprite test above rules out; the two senses of the word are unrelated.) Pinned
	# anyway, because the day channel-encoded art is dropped in these become the frame's default paint,
	# and an edit made between now and then would land unnoticed.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Vauban carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.29411766, 0.22745098, 0.2901961, 1), 'base_0 is the dark plum chassis.')
	assert_eq(ours.base_1, Color(0.8784314, 0.87058824, 0.827451, 1), 'base_1 is the bone plating.')
	assert_eq(ours.base_2, Color(0.1882353, 0.6431373, 0.5647059, 1), 'base_2 is the teal glow.')
	assert_eq(ours.base_3, Color(0.89411765, 0.78431374, 0.4392157, 1), 'base_3 is the gold accent.')
	assert_not_null(ours.palette_2, 'The toneramp is on palette_2, the slot the Iskander uses.')
	if ours.palette_2 == null: return
	assert_eq(ours.palette_2.resource_path, 'res://assets/palettes/toneramps/tone_highcontrast.png',
		'And it is still tone_highcontrast - the ramp is the one thing kept from the base frame.')
	# THE OTHER THREE SLOTS (Pass F task 23, open-items I): the .tres writes none of them, so each is
	# ColorScheme's own export default (color_scheme.gd:59-62). Pinned so all eight fields are, and a
	# stray palette written into the block says so here.
	assert_eq(ours.palette_0, ColorScheme.DEFAULT_TONERAMP, 'palette_0 is the engine default toneramp.')
	assert_eq(ours.palette_1, ColorScheme.DEFAULT_TONERAMP, 'palette_1 is the engine default toneramp.')
	assert_eq(ours.palette_3, ColorScheme.DEFAULT_TONERAMP, 'palette_3 is the engine default toneramp.')

	# AND IT IS DELIBERATELY NOT THE ISKANDER'S ANY MORE. Read off the live frame rather than
	# transcribed, so this stays honest if a modkit update repaints HA: whatever the Iskander wears,
	# ours differs. A revert of the .tres block to its cloned state fails here as well as above.
	var iskander:Frame = ContentLibrary.get_mech_frame(ISKANDER_ID)
	assert_not_null(iskander, 'mf_iskander loads.')
	if iskander == null or iskander.default_color_scheme == null: return
	var theirs:ColorScheme = iskander.default_color_scheme
	assert_true(ours.base_0 != theirs.base_0 or ours.base_1 != theirs.base_1 or ours.base_2 != theirs.base_2,
		'The Vauban is distinguishable from the Iskander in data, not a clone of its scheme.')

## THE PROVENANCE COMMENT IS PART OF THE PIN (Pass F task 23, open-items I). The literals above say
## WHAT the scheme is; only the .tres comment block says WHERE it came from (a colour census of
## mf_vauban.png, ruling R4) and how to re-derive it. An editor save of the frame strips `;` comments
## (memory editor-tres-cache-clobber, headless-import-strips-mod-comments), leaving the values intact
## and every other test green - so the text itself is asserted. Raw source, the test_spin.gd /
## test_draw_fire.gd idiom: the UNPACKED path, because FileAccess on the mirror path comes back empty.
func test_the_colour_scheme_keeps_its_derivation_note():
	const SOURCE := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_vauban/mf_vauban.tres'
	var src := FileAccess.get_file_as_string(SOURCE)
	assert_false(src.is_empty(), 'mf_vauban.tres reads back.')
	if src.is_empty(): return
	assert_true(src.contains('DERIVED FROM THE SPRITE ART'),
		'The colour scheme block still carries its derivation note (ruling R4).')

func test_the_name_and_flavour_resolve():
	# tr() falling through to the raw key is the signature of a missing CSV row OR of a stale compiled
	# .translation artifact; either way the card is blank in game.
	for key:String in ['frame.mf_vauban.name', 'frame.mf_vauban.flavor', 'frame.mf_vauban.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_vauban.name'), 'Vauban', 'The frame is named Vauban.')
	assert_eq(X.tr('frame.mf_vauban.flavor.short'), 'Gravity Wins', 'The tagline the author picked (ruling 12).')
	# The flavour is Bel's paragraph verbatim; its closing line is where the tagline comes from, and
	# it is the cheapest end-to-end check that the whole paragraph landed rather than a truncation.
	assert_true(X.tr('frame.mf_vauban.flavor').ends_with('No one can beat gravity forever.'),
		'The flavour is the sheet paragraph, ending on the line the tagline came from.')

func test_the_iskander_licence_grants_the_vauban_at_rank_two():
	var tree := _license()
	assert_not_null(tree, 'li_iskander loads.')
	if tree == null: return
	assert_not_null(tree.rank_2, 'li_iskander has a rank 2.')
	if tree.rank_2 == null: return
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Vauban.')
	assert_has(granted, ISKANDER_ID, 'Rank 2 still grants the Iskander.')

func test_the_iskander_is_still_first_so_the_licence_keeps_its_name():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT() (unlock_tree.gd:28-32). Vanilla
	# li_iskander DOES declare rank_2 granting mf_iskander, so it IS named off this array - inserting
	# instead of appending would rename Harrison's licence after our alt everywhere the UI shows it.
	var tree := _license()
	assert_not_null(tree, 'li_iskander loads.')
	if tree == null or tree.rank_2 == null: return
	assert_false(tree.rank_2.granted_frames.is_empty(), 'Rank 2 grants at least one frame.')
	if tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, ISKANDER_ID,
		'The Iskander is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_iskander.name'),
		'The licence is still named for the Iskander.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	# COUNTING ONCE PROVES NOTHING (close review M1, 2026-09-18): a testkit run installs the mod
	# exactly once, so the count below is 1 whether or not any idempotence guard exists, and the
	# version of this test that stopped there was only catching a double-grant shipped in the file.
	# The second half is what earns the name - it runs li_iskander.tres_ext.gd again, by hand, on the
	# live licence and re-counts.
	#
	# IT IS THE EXTENSION'S OWN GUARD THIS PINS, not mod_main's. There are two, on different layers:
	# li_iskander.tres_ext.gd:38 refuses to append a frame the rank already grants, and mod_main's
	# APPLIED_META stamp stops a re-activation calling the extension at all. Calling modify_resource
	# directly steps past the second on purpose, because the first is the one that has to hold when
	# anything else - the engine's own queue, a later mod - loads and edits the same cached instance.
	# A duplicated grant shows in game as the Vauban listed twice on the licence card.
	var tree := _license()
	assert_not_null(tree, 'li_iskander loads.')
	if tree == null or tree.rank_2 == null: return
	assert_eq(_vauban_grants_in(tree), 1, 'The Vauban is granted exactly once.')

	var extender:Script = load(LICENSE_EXTENDER)
	assert_not_null(extender, 'li_iskander.tres_ext.gd loads.')
	if extender == null: return
	extender.new().modify_resource(tree)

	assert_eq(_vauban_grants_in(tree), 1, 'And still exactly once after the extension runs again.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_vauban():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back.
	#
	# The Vauban does NOT ride the M/K2's free-for-all branch. PilotCore.get_available_frames
	# (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3 regardless of pilot level,
	# and get_unlocked_licensed_frames, which walks the pilot's OWN RankProgress rows. HA is not GMS,
	# so only the second half can ever reach us.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_iskander at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'An Iskander 2 pilot is offered the Vauban.')
	assert_has(ids, ISKANDER_ID, 'And is still offered the Iskander itself.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:34-39),
	# so an extension that appended to rank_1 by mistake would still show up at rank 2 and every
	# assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'An Iskander 1 pilot is not offered it yet.')

func test_the_iskanders_own_gear_is_untouched():
	# LICENCE GUARD 2 of 3. An alt frame adds a FRAME to the base licence and nothing else. Nothing
	# else in the suite reads li_iskander.granted_gear at all, so appending a kit in
	# li_iskander.tres_ext.gd - the natural shape of a copy-paste from a licence that grants gear -
	# would redden nothing without this.
	var tree := _license()
	assert_not_null(tree, 'li_iskander loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, ISKANDER_RANK_2_GEAR, 'Rank 2 grants exactly HA\'s own two pieces of gear.')
	# And named explicitly, because the list above is also what a modkit update would move: whatever
	# arrives here, it must at least not be ours.
	for kit:Kit in tree.rank_2.granted_gear:
		assert_false(kit.resource_path.contains(MOD_ID),
			'%s is not ours: an alt adds no gear to the base licence.' % kit.compcon_id)

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# LICENCE GUARD 1 of 3 - upstream bug 7 in one assertion, and the only thing on the branch that
	# asks it of li_iskander. _ModLoaderResourceExtension._save_resource no longer retains an extended
	# resource, so the extension evaporates the moment nothing holds the instance and the next load()
	# reads the unextended file off disk. Deleting mod_main.gd:169's retained.append(extended)
	# reddens NOTHING else: test_alt_frames.gd only checks the path is DECLARED in EXTENDED_RESOURCES,
	# and every other test in this file compares compcon_id strings, which a freshly loaded vanilla
	# licence would still answer for the Iskander.
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node "%s" is in the tree.' % MOD_ID)
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	assert_not_null(retained, 'mod_main has a _retained_resources array.')
	if retained == null: return
	var tree := _license()
	assert_not_null(tree, 'li_iskander loads.')
	if tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_iskander instance ContentLibrary serves is the one mod_main holds.')

func test_the_other_extenders_of_li_iskander_also_land():
	# LICENCE GUARD 3 of 3. Whoever else touched li_iskander in this run must still have their frame
	# in it - the queue collision (mod_main.gd's header) drops a queue-path extender silently, and
	# apply_resource_extensions_directly erases OUR key from the shared dictionary at :134 precisely
	# so that theirs survives.
	#
	# OTHER_EXTENDERS is empty today (see its own comment: no installed mod names this licence at
	# all), so the loop is silent and the assert_has below is what keeps this test from asserting
	# nothing.
	var granted := _rank_2_frame_ids()
	gut.p('  installed, in order: %s' % [Compat.installed_mod_ids()])
	gut.p('  li_iskander rank 2 frames: %s' % [granted])
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is there too.')
	if checked == 0: pass_test('No other li_iskander extender installed; nothing to co-exist with.')

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = VaubanFixture.create_game(self)
	var vauban:Unit = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	assert_true(Unit.is_valid(vauban), 'A unit was created.')
	if not Unit.is_valid(vauban): return
	assert_eq(vauban.core.frame.compcon_id, FRAME_ID, 'It is wearing the Vauban frame.')
	assert_eq(vauban.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or sensor range into
	# the current block (only health/armor/heat/speed/structure/stress/repairs are synced). Both are
	# frame value plus buff bonus - Unit.get_sensor_range is unit.gd:305 and Unit.get_evasion is :306.
	assert_eq(vauban.get_evasion(), SHEET_STATS.evasion, 'It has the sheet evasion, read the way the engine reads it.')
	assert_eq(vauban.get_sensor_range(), SHEET_STATS.sensor_range,
		'And the sheet Sensors - which both Sap and Solfataric Breach measure their trigger with.')
	assert_eq(vauban.get_save_target(), SHEET_STATS.save_target,
		'And the sheet save target, which is what Sap\'s Hull save is rolled against.')
	assert_eq(vauban.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(vauban.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the trait specs depends on it.')

func test_the_fixture_lays_difficult_terrain_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK, and it is the only thing that exercises the three helpers Tasks 2-5 lean
	# on before their own specs do. lay_difficult has to produce ground the ENGINE agrees is difficult
	# (game.map.get_surface_terrain_at(tile).is_difficult(), which is what
	# test/gear/test_cp_magnetic_field_projector.gd:24 asserts), create_drone has to produce a unit
	# that is a character but NOT a mech, and track() has to be the call that hangs aura buffs.
	var game:Gamemaster = VaubanFixture.create_game(self)
	VaubanFixture.lay_difficult(game, FIELD)

	for tile:Vector2i in FIELD:
		assert_true(game.map.get_surface_terrain_at(tile).is_difficult(),
			'%s is difficult ground.' % tile)
	assert_false(game.map.get_surface_terrain_at(VAUBAN_TILE).is_difficult(),
		'And the tile beside it is not - lay_difficult writes the WHOLE map, so this is the control.')

	var drone:Unit = VaubanFixture.create_drone(game, HOSTILE_TILE)
	assert_true(drone.is_character(), 'A drone IS a character - applies_only_to_characters passes it.')
	assert_false(drone.is_mech(), 'And is NOT a mech - which is the clause Gravity Well needs.')

func test_the_traits_are_the_sheet_traits_in_sheet_order():
	# Asserted as an exact ORDERED list rather than as a set: the sheet prints Solfataric Breach, Sap,
	# Gravity Well and then the core system in that order and the character sheet draws them in array
	# order, so a reshuffle is
	# a visible change with no other guard anywhere in the suite. It also catches the natural mistake
	# in the append-per-task shape this sub-project used - an entry added to the ext_resource block and
	# forgotten in the array, or added twice.
	#
	# AND IT PINS THE ABSENCE OF THE ISKANDER'S OWN FOUR. The Vauban carries NONE of
	# mt_assault_launcher, mt_mine_deployers, mt_skeleton_key or cp_broad_sweep_seeder (ruling 14),
	# and an exact list is the only assertion that would notice one arriving by copy-paste from the
	# base frame.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_vauban loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS,
		'Solfataric Breach, Sap, Gravity Well, Earth shaker Grav-gen - in sheet order, and nothing else.')

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

func test_the_core_system_is_the_frames_last_trait() -> void:
	# The sheet lists the three traits and then the core system; the frame card shows them in array
	# order, so this is player-visible ordering rather than bookkeeping.
	var ids:Array[StringName] = []
	for kit:Kit in _frame().traits: ids.append(kit.compcon_id)
	assert_eq(ids.back(), &'cp_earth_shaker_grav_gen', 'the core comes last')
