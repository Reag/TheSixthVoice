# Does this mod collide with our other mods?
#
# All four Reag-* checkouts under res://unpacked/ load together in a testkit run (and a player may
# well have several installed), and ContentLibrary keys everything by the resource's FILENAME with
# no namespace. Two mods shipping `ms_flak_pod.tres` therefore produce one entry, not two: the
# second load takes over the path and one mod's gear silently becomes the other's.
#
# Nothing warns. The loser's specs go red in ways that point at the loser's own files, which is a
# long afternoon.
#
# THE TRAP THIS FILE IS WRITTEN AROUND: with an empty mod the overlap check passes for free - and it
# would pass just as happily if the sibling mods had failed to install, which is the case where a
# collision is actually possible and undetected. So the siblings being loaded is asserted FIRST, as
# its own test, before any overlap claim is made.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const ModResources := preload('res://testkit/mod_resources.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const MOD_ID := 'Reag-TheSixthVoice'
## Our other mods. Only ours: a third-party mod's ids are not ours to police, and on 1.4.x the
## testkit hook does not install the zips anyway (testkit/pre_run_hook.gd).
const SIBLING_MODS:Array[String] = [
	'Reag-ThyHubris', 'Reag-CrisisCoreCatalogEvolved', 'Reag-LancerKarmaDice',
]
## Every index a collision could happen in. Same list as test_content_integrity.gd's OUR_INDEXES.
const INDEXES:Array[StringName] = [&'frames', &'kits', &'buffs', &'licenses']

## id => the mod that contributed it, for one index.
func _ids_by_mod(mod_id:String, index_name:StringName) -> Dictionary:
	var ids := {}
	for path:String in ModResources.our_paths_in(mod_id, index_name):
		ids[ContentLibrary.get_compcon_id_from_path(path)] = path
	return ids

func test_the_sibling_mods_are_actually_loaded():
	# The gate. Without this, every assertion below is "no collisions found" from an empty search.
	for mod_id:String in SIBLING_MODS:
		assert_true(Compat.is_mod_active(mod_id),
			'%s is installed, so a collision with it could be detected.' % mod_id)

func test_this_mod_is_actually_loaded():
	assert_true(Compat.is_mod_active(MOD_ID), '%s is installed.' % MOD_ID)

func test_no_resource_id_is_shared_with_another_of_our_mods():
	var ours := {}
	for index_name:StringName in INDEXES:
		for id:StringName in _ids_by_mod(MOD_ID, index_name): ours[id] = index_name
	if ours.is_empty():
		gut.p('  This mod contributes no ids yet; the check becomes load-bearing with SP1.')
	for mod_id:String in SIBLING_MODS:
		for index_name:StringName in INDEXES:
			for id:StringName in _ids_by_mod(mod_id, index_name):
				assert_false(ours.has(id),
					'%s is ours alone; %s does not also ship it.' % [id, mod_id])

func test_no_resource_id_collides_with_a_vanilla_one():
	# The likeliest collision in a supplement this size, and the quietest.
	#
	# ContentLibrary builds ONE flat compcon_id_to_path from group.get_paths(), which is
	# `paths + mod_resource_paths` with the mod paths LAST (content_library.gd:328-332). So a mod file
	# whose BASENAME matches a vanilla resource sitting at a DIFFERENT folder silently wins the id -
	# and because the mirror path does not match, add_overwrite_extend_mod_resources treats it as a
	# brand new resource rather than an override: no replace_resource, no log line, no warning. The
	# vanilla gear simply stops being reachable by id.
	#
	# A deliberate override is the legitimate case and is NOT this: it shares the vanilla MIRROR PATH,
	# so the paths match and only one entry ever existed. That is why this compares paths, not ids
	# alone.
	for index_name:StringName in INDEXES:
		var group:ResourceGroup = ContentLibrary.RESOURCE_GROUPS.get(index_name, null)
		if group == null: continue
		var vanilla := {}
		for path:String in group.paths: vanilla[ContentLibrary.get_compcon_id_from_path(path)] = path
		var ours := _ids_by_mod(MOD_ID, index_name)
		assert_gt(vanilla.size(), 0, 'The %s index has vanilla entries to collide with.' % index_name)
		for id:StringName in ours:
			if not vanilla.has(id): continue
			var mirror:String = ours[id].replace('res://unpacked/%s/res/' % MOD_ID, 'res://')
			assert_eq(mirror, vanilla[id],
				'%s shares a vanilla id; it is an override at the vanilla path, not a collision.' % id)

func test_no_two_of_our_resources_share_an_id_within_this_mod():
	# The same collision one level down: two files with the same basename in different folders of
	# THIS mod overwrite each other just as thoroughly, and it is an easy mistake once a frame's
	# traits live in per-frame sub-folders.
	for index_name:StringName in INDEXES:
		var paths:Array[String] = ModResources.our_paths_in(MOD_ID, index_name)
		var seen := {}
		for path:String in paths:
			var id:StringName = ContentLibrary.get_compcon_id_from_path(path)
			if seen.has(id):
				fail_test('%s is used twice in %s: %s and %s.' % [id, index_name, seen[id], path])
			seen[id] = path
		# Asserted as a count rather than only inside the loop, so the claim is made even when the
		# index is empty - which is the whole of SP0.
		assert_eq(seen.size(), paths.size(),
			'%d %s resources, %d distinct ids.' % [paths.size(), index_name, seen.size()])

func test_the_id_census_is_reported():
	# A report rather than an assertion: the numbers are what tell you a "no collisions" pass had
	# anything to search. Read them when this file goes quiet after a sub-project that added content.
	for mod_id:String in [MOD_ID] + SIBLING_MODS:
		var total := 0
		for index_name:StringName in INDEXES:
			total += ModResources.our_paths_in(mod_id, index_name).size()
		gut.p('  %-34s %3d ids across %d indexes' % [mod_id, total, INDEXES.size()])
	assert_true(Compat.is_mod_active(MOD_ID), 'Reported against a mod that is actually installed.')
