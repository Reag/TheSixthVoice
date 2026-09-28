# The Myconid (HORUS, Gorgon alt) - SP1 Task 2, with the trait list pinned in Task 6.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED,
# not merely written: a frame whose filename prefix or resource group is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
# Numbers come from the notes repo's specs/sixth-voice/04-myconid.md Stats table, which is generated
# from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in the
# lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_myconid_frame.gd
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_myconid'
const LICENSE_ID := &'li_gorgon'
const GORGON_ID := &'mf_gorgon'
const MOD_ID := 'Reag-TheSixthVoice'

## Vanilla li_gorgon's OWN rank 2 gear, pinned as an exact ordered list. An alt frame adds a frame
## and nothing else, so anything appearing here is either our extension overreaching or a modkit
## update moving HORUS' gear - both worth a red. Pinned exactly rather than relaxed to "none of them
## is ours": that weaker form cannot see a VANILLA kit being appended, and the appended thing in the
## natural mistake (a copy-paste from a licence that grants gear) is as likely to be vanilla's as
## ours. Both halves are asserted below, as test_subutai_frame.gd does for li_barbarossa.
const GORGON_RANK_2_GEAR:Array[StringName] = [&'ms_monitor_module', &'ms_scorpion_v70']

## Other li_gorgon extenders a testkit run can contain, and the frame each grants there.
##
## EMPTY, AND THAT IS A MEASUREMENT RATHER THAN AN OVERSIGHT (2026-09-15). All six third-party mods
## parked in lancer-tactics-claude/.bk were searched for a li_gorgon.tres_ext.gd and none has one -
## gavstarb-horus_alts_1st_party, the closest candidate, extends li_balor, li_manticore and
## li_minotaur and leaves the Gorgon alone. The dict and the loop stay so that the day one arrives it
## is one row, not a new test; test_subutai_frame.gd and test_mk2_frame.gd both have live rows and
## this is the same shape.
##
## BECAUSE IT IS EMPTY, test_the_other_extenders_of_li_gorgon_also_land's loop below never runs, so
## THAT TEST IS INERT AS A CO-EXISTENCE GUARD FOR THIS LICENCE - it reduces to a duplicate of
## test_the_gorgon_licence_grants_the_myconid_at_rank_two and cannot redden on a broken queue-erase.
##
## AND THE QUEUE-ERASE AT mod_main.gd:134 IS NOT OBSERVABLE FROM ANY SPEC AT ALL - measured at the
## frame close, 2026-09-16, DO NOT RE-PROPOSE THE OBVIOUS TEST. The whole-branch review's fix was to
## read `ModLibrary.get_installed_mod(MOD_ID).queued_resource_modifications` directly and assert our
## key is gone. That test was written, run, and MEASURED VACUOUS: deleting mod_main.gd:134 left the
## file 21/21 green. The reason is six lines past the fold the review stopped at -
## ModApplier.apply_installed_queued_extensions merges every mod's dictionary at mod_applier.gd:220
## and then calls mod.clear_installation_queues() on EVERY installed mod at :227, which empties
## queued_resource_modifications outright (mod_core.gd:41-45). pre_run_hook awaits all of that before
## GUT runs a single test, so the dict reads {} for every mod either way.
##
## The other candidate observable is no better: with no competitor installed, the granted-frames list
## is provably identical whether or not :110 ran, because li_gorgon.tres_ext.gd's
## `if not ...has(frame)` makes a second queue-path application of our OWN extension a no-op.
##
## So this is a REAL, RECORDED GAP and not a missing test someone forgot to write: the mechanism only
## does anything when a competing queue-path extender exists, and a 1.4.x testkit run cannot contain
## one. It belongs to the CROSS-MOD COMPATIBILITY SWEEP scheduled in the roadmap, which is the first
## context that will have a real competitor to point at. Adding a row above is still the fix the day
## a parked mod starts extending li_gorgon.
const OTHER_EXTENDERS := {}

## The sheet's table (specs/sixth-voice/04-myconid.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
##
## Worth reading beside the Gorgon's own (12 HP, 8 evasion, 12 edef, 4 speed, 3 repairs, armor 0):
## the Myconid is slower, tougher and blinder, and every one of those differences is deliberate.
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 8, armor = 2, evasion = 6, edef = 10,
	speed = 3, heat = 5, save_target = 10, sensor_range = 8, tech_attack = 0, repairs = 4,
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
	assert_true(Frame.is_valid(_frame()), 'mf_myconid is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_myconid carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size; a size-2 frame that also set it would occupy one
	# tile while reporting 2, and every range and adjacency assertion in the trait specs would
	# quietly measure the wrong geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Myconid is a full size 2, not size 1/2.')

func test_the_mounts_are_flex_then_main():
	# Sheet order, and it is player-visible: the mech sheet draws mounts in array order.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_main.tres'], 'Flex then Main, in sheet order.')

func test_the_role_is_defender_with_no_secondary():
	# The sheet lists one role. The Gorgon itself is role_primary 2 with no secondary, and the alt
	# inherits that shape rather than inventing a second role.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.DEFENDER, 'Primary role DEFENDER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_myconid.sprites.
	#
	# 160x160 because the Myconid is size 2, and the mod ships two stand-ins - mf_placeholder.png
	# (80x80) and mf_placeholder_160.png - so pointing a size-2 frame at the 80x80 one renders it at
	# half scale on the board.
	#
	# THE "NOT THE PLACEHOLDER" HALF IS LIVE, as of SP3's commissioned art (e8eb61f). It was
	# deliberately deferred through SP1 and SP2, which shipped no art (ruling, 2026-09-15) and would
	# have made the assertion test_subutai_frame.gd carries a SECOND deliberate red here, against the
	# Global Constraints of this sub-project allowing exactly one. Now that the real art has landed,
	# the size assertion alone cannot catch a revert to the stand-in - mf_placeholder_160.png is ALSO
	# 160x160 - so the resource_path check below is what actually pins the art, matching
	# test_subutai_frame.gd:123-124, test_mk2_frame.gd:104-105 and test_fitzgerald_frame.gd:98-99.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(160, 160), 'A size-2 frame uses a 160x160 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'),
		'The frame wears its commissioned art, not the stand-in (%s).' % sprite.resource_path)
	# THE SIZE CHECK ABOVE ALONE CANNOT CATCH A REVERT TO THE GORGON'S OWN SPRITE (frame close I1,
	# 2026-09-17, extended to this frame): the Gorgon's own art is also 160x160 and its path contains
	# no "placeholder", so a copy-paste from mf_gorgon.tres - the same mistake shape the Blush's .tres
	# was built from - would pass both assertions above. Only checking the frame's OWN filename does.
	assert_true(sprite.resource_path.ends_with('/mf_myconid.png'),
		'The frame wears its OWN sprite - not the placeholder, and not the Gorgon\'s.')

func test_the_frame_has_a_colour_scheme():
	# Cloned from the Gorgon's own inline scheme (tone_highhue, a grey, a plum and a rose), so the
	# stand-in sprite still reads as HORUS on the board until SP3.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	assert_not_null(frame.default_color_scheme, 'The frame carries a default colour scheme.')

func test_the_name_and_flavour_resolve():
	# tr() falling through to the raw key is the signature of a missing CSV row OR of a stale
	# compiled .translation artifact; either way the card is blank in game.
	for key:String in ['frame.mf_myconid.name', 'frame.mf_myconid.flavor', 'frame.mf_myconid.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_myconid.name'), 'Myconid', 'The frame is named Myconid.')
	assert_eq(X.tr('frame.mf_myconid.flavor.short'), 'Halos of Shimmering Spores',
		'The tagline the author picked.')

func test_the_gorgon_licence_grants_the_myconid_at_rank_two():
	var tree := _license()
	assert_not_null(tree, 'li_gorgon loads.')
	if tree == null: return
	assert_not_null(tree.rank_2, 'li_gorgon has a rank 2.')
	if tree.rank_2 == null: return
	var granted := _rank_2_frame_ids()
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Myconid.')
	assert_has(granted, GORGON_ID, 'Rank 2 still grants the Gorgon.')

func test_the_gorgon_is_still_first_so_the_licence_keeps_its_name():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT(). Unlike li_gms (which declares no
	# rank_2 at all and so is named '???' whatever a mod does), li_gorgon IS named off this array, so
	# inserting instead of appending would rename HORUS' licence after our alt everywhere the UI
	# shows it.
	var tree := _license()
	assert_not_null(tree, 'li_gorgon loads.')
	if tree == null or tree.rank_2 == null: return
	assert_false(tree.rank_2.granted_frames.is_empty(), 'Rank 2 grants at least one frame.')
	if tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, GORGON_ID,
		'The Gorgon is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_gorgon.name'),
		'The licence is still named for the Gorgon.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	# apply_resource_extensions_directly() stamps APPLIED_META on the instance so a re-activation
	# cannot append the frame twice. A duplicated grant shows in game as the Myconid listed twice on
	# the licence card.
	var tree := _license()
	assert_not_null(tree, 'li_gorgon loads.')
	if tree == null or tree.rank_2 == null: return
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	assert_eq(count, 1, 'The Myconid is granted exactly once.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_myconid():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back - it is named in design 1.4 and it is
	# here.
	#
	# The Myconid does NOT ride the M/K2's free-for-all branch. PilotCore.get_available_frames
	# (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3 regardless of pilot level,
	# and get_unlocked_licensed_frames, which walks the pilot's OWN RankProgress rows. HORUS is not
	# GMS, so only the second half can ever reach us.
	#
	# Built through set_license_to_rank rather than by hand-constructing a RankProgress, so the test
	# goes through the same engine call the pilot editor does (pilot_core.gd:318, :323-346).
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_gorgon at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Gorgon 2 pilot is offered the Myconid.')
	assert_has(ids, GORGON_ID, 'And is still offered the Gorgon itself.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative
	# (unlock_tree.gd:34-39), so an extension that appended to rank_1 by mistake would still show up
	# at rank 2 and every assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Gorgon 1 pilot is not offered it yet.')

func test_the_gorgons_own_gear_is_untouched():
	# LICENCE GUARD 2 of 3. An alt frame adds a FRAME to the base licence and nothing else. Nothing
	# else in the suite reads li_gorgon.granted_gear at all, so appending a kit in
	# li_gorgon.tres_ext.gd - the natural shape of a copy-paste from a licence that grants gear -
	# would redden nothing without this.
	var tree := _license()
	assert_not_null(tree, 'li_gorgon loads.')
	if tree == null or tree.rank_2 == null: return
	var gear_ids:Array[StringName] = []
	for kit:Kit in tree.rank_2.granted_gear: gear_ids.append(kit.compcon_id)
	assert_eq(gear_ids, GORGON_RANK_2_GEAR, "Rank 2 grants exactly HORUS' own two systems.")
	# And named explicitly, because the list above is also what a modkit update would move: whatever
	# arrives here, it must at least not be ours.
	for kit:Kit in tree.rank_2.granted_gear:
		assert_false(kit.resource_path.contains(MOD_ID),
			'%s is not ours: an alt adds no gear to the base licence.' % kit.compcon_id)

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# LICENCE GUARD 1 of 3 - upstream bug 7 in one assertion, and the only thing on the branch that
	# asks it of li_gorgon. _ModLoaderResourceExtension._save_resource no longer retains an extended
	# resource (mod_main.gd:117-122), so the extension evaporates the moment nothing holds the instance
	# and the next load() reads the unextended file off disk. Deleting
	# mod_main.gd:169's retained.append(extended) reddens NOTHING else: test_alt_frames.gd
	# only checks the path is DECLARED in EXTENDED_RESOURCES (its own header says so), and every
	# other test in this file compares compcon_id strings, which a freshly loaded vanilla licence
	# would still answer for the Gorgon.
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node "%s" is in the tree.' % MOD_ID)
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	assert_not_null(retained, 'mod_main has a _retained_resources array.')
	if retained == null: return
	var tree := _license()
	assert_not_null(tree, 'li_gorgon loads.')
	if tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_gorgon instance ContentLibrary serves is the one mod_main holds.')

func test_the_other_extenders_of_li_gorgon_also_land():
	# LICENCE GUARD 3 of 3. Whoever else touched li_gorgon in this run must still have their frame in
	# it - the queue collision (mod_main.gd's header) drops a queue-path extender silently, and
	# apply_resource_extensions_directly erases OUR key from the shared dictionary at :134 precisely
	# so that theirs survives.
	#
	# OTHER_EXTENDERS is empty today (see its own comment: no parked mod extends this licence), so
	# the loop is silent and the assert_has below is what keeps this test from asserting nothing.
	var granted := _rank_2_frame_ids()
	gut.p('  installed, in order: %s' % [Compat.installed_mod_ids()])
	gut.p('  li_gorgon rank 2 frames: %s' % [granted])
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is there too.')
	if checked == 0: pass_test('No other li_gorgon extender installed; nothing to co-exist with.')

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = MyconidFixture.create_game(self)
	var myconid:Unit = MyconidFixture.create_myconid(game, Vector2i(4, 4))
	assert_true(Unit.is_valid(myconid), 'A unit was created.')
	if not Unit.is_valid(myconid): return
	assert_eq(myconid.core.frame.compcon_id, FRAME_ID, 'It is wearing the Myconid frame.')
	assert_eq(myconid.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(myconid.core.current.armor, SHEET_STATS.armor, 'It has the sheet armor.')
	assert_eq(myconid.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')

func test_the_map_indexes_the_whole_footprint():
	# SpecFactory.create_unit adds the unit at SIZE 1 and only full_repair() grows it to the frame's
	# size 2; MapState.unit_tiles is rebuilt only when map_bus.update_unit_tile_tracking fires, which
	# nothing in that sequence does. MyconidFixture.create_myconid ends with UnitTile.move_to for
	# exactly that reason (the Subutai's SP2 recentre bug), and this is the assertion that would
	# notice the line going away - Halo's Sensors range and Symbiosis' reaction plumbing both read
	# positions off this index.
	var game:Gamemaster = MyconidFixture.create_game(self)
	var myconid:Unit = MyconidFixture.create_myconid(game, Vector2i(4, 4))
	if not Unit.is_valid(myconid): return
	for tile:Vector2i in myconid.occupied_tiles():
		assert_true(game.map.get_all_units_at_tile(tile).has(myconid),
			'The map indexes the Myconid at %s.' % tile)

# ---------------------------------------------------------------- the trait list
#
# Kept to the END of SP1 because the array is assembled across three tasks: Task 2 puts Guardian on,
# Task 3 prepends Symbiosis, Task 5 inserts Halo. SP2 appends cp_quietus_machines and then
# mw_psychopomp_fold_pike, in that order - the sheet prints the traits under "Traits" and the core
# system under its own heading, and appending is also what keeps the three trait rows in the places a
# player learned them in SP1.

## The sheet's trait order (specs/sixth-voice/04-myconid.md). The frame card lists traits in array
## order, so this is player-visible.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_symbiosis', &'mt_halo', &'mt_guardian', &'cp_quietus_machines', &'mw_psychopomp_fold_pike',
]

func test_the_traits_are_the_sheets_three_in_the_sheets_order_then_the_core():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS,
		'Three traits in sheet order, then the core system, then the integrated weapon.')

func test_guardian_is_vanillas_own_resource():
	# Asserted by IDENTITY against ContentLibrary rather than by id, which is what proves the frame
	# REUSES vanilla's Kit instead of shipping a same-named copy - the author's standing directive for
	# alt frames, and the sheet says so outright ("Vanilla shared trait: reuse
	# content/frames/shared/mt_guardian/, do not author").
	#
	# Note what this catches and what it does not, as test_mk2_frame.gd records at length: a copy at a
	# NEW path with the frame still pointing at vanilla's is caught (two instances); a MIRROR-PATH
	# copy is not (take_over_path makes both sides the same instance); and a copy at a new path with
	# the frame repointed at it is not either (get_kit resolves to the copy too). Those last two are
	# testkit/mod_content_audit.gd's job and a reviewer's.
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_myconid loads.')
	if frame == null: return
	var by_id := {}
	for kit:Kit in frame.traits: by_id[kit.compcon_id] = kit
	assert_true(by_id.has(&'mt_guardian'), 'The frame carries mt_guardian.')
	if not by_id.has(&'mt_guardian'): return
	assert_same(by_id[&'mt_guardian'], ContentLibrary.get_kit(&'mt_guardian'),
		'The very same Resource instance vanilla registered, not a copy of it.')

func test_every_new_display_row_resolves():
	# DRIVEN OFF frame().traits rather than a hand-written list, so a fourth trait cannot ship without
	# its rows: the loop grows with the frame. Guardian is vanilla's own Kit and its rows are
	# vanilla's, which is why it is asked of tr() and not of our artifact.
	#
	# Reading OUR OWN compiled artifact for our own keys is the stronger of the two shapes and the one
	# test_mk2_frame.gd already uses: a bare tr() reads the global TranslationServer, and an outdated
	# artifact answers while the CSV on disk says something else - so the test would pass against text
	# nobody ships.
	var translation:Translation = load('res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation')
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	var traits:Array = _frame().traits
	assert_eq(traits.size(), SHEET_TRAITS.size(), 'Guard: the trait list is the pinned one.')
	for kit:Kit in traits:
		assert_ne(kit.name(), 'gear.%s.name' % kit.compcon_id,
			'%s resolves a display name.' % kit.compcon_id)
		if kit.compcon_id == &'mt_guardian': continue # vanilla's own rows

		# THE CORE SYSTEM HAS NO .effect ROW, ON PURPOSE (ruling 14, 2026-09-15). The LCP's core
		# `description` field is EMPTY for this frame, and the standing localisation directive is that
		# an empty LCP field means NO ROW rather than invented prose - vanilla itself leaves 189 of its
		# 431 kits without one. Its effect text lives on the PROTOCOL instead
		# (gear.cp_quietus_machines.action_fungal_network.effect), which is where the card puts it and
		# where the character sheet reads it, and both of those rows are asserted just below.
		#
		# The absence is pinned by test_fungal_network.gd's
		# test_the_core_kit_has_no_effect_row_because_the_lcp_has_no_description, so skipping it here
		# cannot quietly become "nobody checks this key at all".
		# Spelled out rather than as a ternary: `['name'] if c else ['name','effect']` builds an
		# untyped Array, which GDScript refuses to assign to an Array[String] at runtime.
		var suffixes:Array[String] = ['name', 'effect']
		if kit.compcon_id == &'cp_quietus_machines': suffixes = ['name']
		for suffix:String in suffixes:
			var key := 'gear.%s.%s' % [kit.compcon_id, suffix]
			assert_ne(String(translation.get_message(key)), '', 'Our artifact carries %s.' % key)

	# The core system's own rows, which the loop above deliberately does not cover: its ACTION carries
	# the card text, and a name row of its own.
	for key:String in ['gear.cp_quietus_machines.action_fungal_network.name',
			'gear.cp_quietus_machines.action_fungal_network.effect']:
		assert_ne(String(translation.get_message(key)), '', 'Our artifact carries %s.' % key)
