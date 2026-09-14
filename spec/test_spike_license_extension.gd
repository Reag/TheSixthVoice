# Spike 2: does an alt frame reach its vanilla licence on 1.4.3, and does it STAY there?
#
# The M/K2 is an Everest alt. Per the author's directive it EXTENDS li_gms with a .tres_ext.gd
# rather than cloning the licence. Three upstream facts make that fragile on 1.4.x, and this probe
# exists to show each one bites or does not:
#
#   1. Retention (bug 7). _ModLoaderResourceExtension._save_resource no longer keeps the extended
#      resource alive, so the effect evaporates once nothing holds a reference. mod_main holds one.
#   2. The queue collision. ModApplier.apply_installed_queued_extensions merges every mod's queued
#      resource modifications into one Dictionary keyed by target path, and Dictionary.merge keeps
#      the FIRST value per key. Two mods extending li_gms through the engine's queue: only the
#      first-installed one runs, silently. In the real game li_gms is contended by
#      gavstarb-gms_1st_party, fateofman-imi_alt_frames and our own Crisis Core Catalog.
#   3. Co-existence with another DIRECT applier (CCC stands down from the queue and edits the cached
#      instance itself). Two direct appliers on one path is a combination nobody has run before.
#
# The competitor tests skip with a printed line when the competitor is not installed, so this file
# reads identically with or without them - which is why each skip PRINTS. A testkit run loads only
# res://unpacked/ checkouts, so the third-party zips never take part; the throwaway
# Reag-SpikeLiGmsCompetitor mod (a stock queue-path extension appending mf_blackbeard to li_gms)
# stands in for them during the spike and is deleted afterwards.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const Compat := preload('res://testkit/modkit_compat.gd')

const MOD_ID := 'Reag-TheSixthVoice'
const LICENSE_ID := &'li_gms'
const FRAME_ID := &'mf_mk2'
const BASE_FRAME_ID := &'mf_standard_pattern_i_everest'

## Other li_gms extenders a testkit run can contain, and the frame each grants there.
const OTHER_EXTENDERS := {
	'Reag-CrisisCoreCatalogEvolved': &'mf_denali',       # direct applier, like us
	'Reag-SpikeLiGmsCompetitor': &'mf_blackbeard',       # queue path, the third-party shape
}

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

func _rank_1_frame_ids() -> Array[StringName]:
	var ids:Array[StringName] = []
	var tree := _license()
	if tree == null or tree.rank_1 == null: return ids
	for frame:Frame in tree.rank_1.granted_frames: ids.append(frame.compcon_id)
	return ids

# ---------------------------------------------------------------- the frame reaches the licence

func test_the_frame_is_registered():
	var frame = ContentLibrary.get_mech_frame(FRAME_ID)
	assert_true(Frame.is_valid(frame), '%s loads as a valid Frame through ContentLibrary.' % FRAME_ID)

func test_li_gms_rank_1_grants_the_mk2():
	assert_has(_rank_1_frame_ids(), FRAME_ID, 'li_gms rank 1 grants %s.' % FRAME_ID)

func test_a_fresh_pilot_can_pick_the_mk2():
	# The player-facing half. get_available_frames walks every GMS licence at rank 3 regardless of
	# the pilot's level, so a frame at li_gms rank 1 is offered to a licence-level-0 pilot.
	var pilot := PilotCore.create()
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A fresh pilot is offered %s.' % FRAME_ID)
	assert_has(ids, BASE_FRAME_ID, 'A fresh pilot is still offered the Everest.')

func test_the_everest_still_names_the_licence_and_its_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_gms loads.')
	if tree == null or tree.rank_1 == null: return
	assert_eq(tree.rank_1.granted_frames.front().compcon_id, BASE_FRAME_ID,
		'The Everest is still the first frame in rank 1; the alt is appended, never inserted.')
	for kit:Kit in tree.rank_1.granted_gear:
		assert_false(kit.resource_path.contains(MOD_ID),
			'%s is not ours: an alt adds no gear to the base licence.' % kit.compcon_id)

# ---------------------------------------------------------------- retention

func test_the_instance_content_library_serves_is_the_one_mod_main_retains():
	# Bug 7 in one assertion: if the engine dropped the extended instance and ContentLibrary loaded
	# a fresh copy off disk, these would be two different objects and the fresh one would be vanilla.
	var embassy:Node = get_tree().root.find_child(MOD_ID, true, false)
	assert_not_null(embassy, 'The mod embassy node "%s" is in the tree.' % MOD_ID)
	if embassy == null: return
	var retained:Array = embassy.get('_retained_resources')
	assert_not_null(retained, 'mod_main has a _retained_resources array.')
	if retained == null: return
	var tree := _license()
	assert_not_null(tree, 'li_gms loads.')
	if tree == null: return
	var same := false
	for resource in retained: if resource == tree: same = true
	assert_true(same, 'The li_gms instance ContentLibrary serves is the one mod_main holds.')

# ---------------------------------------------------------------- co-existence

func test_the_other_extenders_of_li_gms_also_land():
	# Whoever else touched li_gms in this run must still have their frame in it. A queue-path
	# competitor installed before us is the case that would have taken the M/K2 out of the game had
	# we stayed in the engine's queue; a direct applier beside us is the CCC case.
	var granted := _rank_1_frame_ids()
	gut.p('  installed, in order: %s' % [Compat.installed_mod_ids()])
	gut.p('  li_gms rank 1 frames: %s' % [granted])
	var checked := 0
	for mod_id:String in OTHER_EXTENDERS:
		if not Compat.is_mod_active(mod_id):
			gut.p('  %s not installed; skipping.' % mod_id)
			continue
		checked += 1
		assert_has(granted, OTHER_EXTENDERS[mod_id],
			'%s still grants %s alongside ours.' % [mod_id, OTHER_EXTENDERS[mod_id]])
	assert_has(granted, FRAME_ID, 'And ours is there too.')
	if checked == 0: pass_test('No other li_gms extender installed; nothing to co-exist with.')
