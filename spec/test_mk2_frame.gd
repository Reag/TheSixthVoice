# THE M/K2's frame sheet (SP1 Task 4), and the home of the five licence tests SP1 absorbed from
# spec/test_spike_license_extension.gd when that probe was deleted.
#
# Numbers come from the notes repo's specs/sixth-voice/02-mk2.md Stats table, which is
# generated from the LCP by that repo's tools/lcp_to_sheets.py. Neither lives in
# this repo - the sheets and the generator are kept out of the mod repos on purpose. A red here
# means the .tres drifted from the card, OR that the sheet was regenerated - check the sheet's git
# history (in the lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mk2_frame.gd
extends GutTest

const Compat := preload('res://testkit/modkit_compat.gd')

const FRAME_ID := &'mf_mk2'
const LICENSE_ID := &'li_gms'
const EVEREST_ID := &'mf_standard_pattern_i_everest'
const MOD_ID := 'Reag-TheSixthVoice'
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## Other li_gms extenders a testkit run can contain, and the frame each grants there. Carried over
## from the probe (spike 2): Reag-SpikeLiGmsCompetitor is a throwaway mod, no longer on disk, that
## stood in for a queue-path extender during the spike. The row stays - the test skips an absent mod
## by design, and the row documents the exact shape (queue-path, third-party) that the queue
## collision broke.
const OTHER_EXTENDERS := {
	'Reag-CrisisCoreCatalogEvolved': &'mf_denali',       # direct applier, like us
	'Reag-SpikeLiGmsCompetitor': &'mf_blackbeard',       # queue path, the third-party shape
}

## Sheet order. Replaceable Parts is VANILLA'S OWN Kit, referenced by its vanilla path - see
## test_replaceable_parts_is_vanillas_own_instance for why that identity is asserted rather than
## assumed.
const EXPECTED_TRAITS:Array[StringName] = [
	&'mt_replaceable_parts',
	&'mt_rapid_stabilization_jets',
	&'mt_hybridized_shot',
	&'cp_auxiliary_power_rerouter',
]

func frame() -> Frame:
	return ContentLibrary.get_mech_frame(FRAME_ID)

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

func _rank_1_frame_ids() -> Array[StringName]:
	var ids:Array[StringName] = []
	var tree := _license()
	if tree == null or tree.rank_1 == null: return ids
	for f:Frame in tree.rank_1.granted_frames: ids.append(f.compcon_id)
	return ids

func test_the_frame_is_registered() -> void:
	assert_not_null(frame(), 'ContentLibrary knows mf_mk2.')

func test_the_statblock_matches_the_sheet() -> void:
	var stat:Statblock = frame().stat
	assert_eq(stat.size, 1, 'Size')
	assert_eq(stat.structure, 4, 'Structure')
	assert_eq(stat.stress, 4, 'Stress')
	assert_eq(stat.armor, 1, 'Armor')
	assert_eq(stat.health, 6, 'HP')
	assert_eq(stat.evasion, 8, 'Evasion')
	assert_eq(stat.edef, 8, 'E-Defence')
	assert_eq(stat.heat, 7, 'Heat cap')
	assert_eq(stat.repairs, 6, 'Repair cap')
	assert_eq(stat.sensor_range, 10, 'Sensors')
	assert_eq(stat.tech_attack, 0, 'Tech attack')
	assert_eq(stat.save_target, 10, 'Save')
	assert_eq(stat.speed, 4, 'Speed')
	assert_eq(stat.systems_points, 5, 'SP')

func test_the_mounts_match_the_sheet() -> void:
	var mounts:Array = []
	for mount:MountType in frame().mount_types: mounts.append(mount.resource_path.get_file())
	assert_eq(mounts, ['mount_flex.tres', 'mount_main.tres', 'mount_heavy.tres'],
		'Flex, Main, Heavy, in sheet order.')

## THERE WAS NO SPRITE TEST ON THIS FILE AT ALL until the frame close. Nothing in the suite read
## mf_mk2.sprites, so an empty array, an ext_resource that failed to load, or a revert to the grey
## stand-in all shipped green.
##
## sprites[0] IS THE ONE THIS MOD SUPPLIES. The other nine entries are vanilla textures the M/K2
## offers as alternate skins (the Everest's own art and a row of NPC sprites, all at res://assets/),
## so the placeholder guard is aimed at the first entry rather than swept over the array - the
## vanilla nine are not ours to pin.
##
## 80x80 because the M/K2 is size 1, which is also what makes this the M/K2's version of the
## Subutai's guard rather than a copy of it: the mod's two placeholders are mf_placeholder.png
## (80x80) and mf_placeholder_160.png (160x160), so a size assertion alone would NOT notice a revert
## to the size-matched stand-in. The resource_path check is what does.
func test_the_frame_has_a_sprite_that_actually_loaded() -> void:
	var mk2:Frame = frame()
	assert_not_null(mk2, 'mf_mk2 loads.')
	if mk2 == null: return
	assert_false(mk2.sprites.is_empty(), 'The frame carries at least one sprite.')
	if mk2.sprites.is_empty(): return
	var sprite:Texture2D = mk2.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'),
		'The frame wears its commissioned art, not the stand-in (%s).' % sprite.resource_path)

func test_the_traits_are_the_sheets_four_in_order() -> void:
	var ids:Array[StringName] = []
	for kit:Kit in frame().traits: ids.append(kit.compcon_id)
	assert_eq(ids, EXPECTED_TRAITS, 'Four traits, sheet order.')

func test_replaceable_parts_is_vanillas_own_instance() -> void:
	# Ruling 1: the trait is TEXT-ONLY in this engine (a Kit with is_trait, an icon, no actions and no
	# passives, and no reader anywhere under engine/ or ui/), so the Everest already diverges from the
	# book here and the M/K2 inherits exactly that divergence. We therefore reference VANILLA'S Kit at
	# its vanilla path and ship no copy of it.
	#
	# assert_same is pointer identity (test.gd:2192 wraps @GlobalScope.is_same); assert_eq would do
	# the same for two Objects (comparator.gd:53-54 falls through to `v1 == v2` once the datatypes
	# match), but same states the intent.
	#
	# WHAT THIS CATCHES, exactly - it is narrower than "nobody copied the Kit":
	#   CAUGHT: a copy of the Kit at a NEW path under our res/ while mf_mk2.tres still points at the
	#     vanilla path. The copy is a new file, so it joins new_resource_paths
	#     (lancer_tactics_mod.gd:91), the resgrp_kits mt_*.tres glob picks it up, and
	#     compcon_id_to_path[basename] is last-writer-wins (content_library.gd:329-332) over
	#     get_paths()'s `paths + mod_resource_paths` (resource_group.gd:28) - so get_kit resolves to
	#     the copy (content_library.gd:409-411) while traits[0] is still vanilla's. Two instances,
	#     red.
	#   NOT CAUGHT: a MIRROR-PATH copy. replace_resource take_over_path's it onto the vanilla path
	#     (lancer_tactics_mod.gd:119-125), so both sides are then the same instance. Green, wrongly.
	#   NOT CAUGHT, and this is THE MOST NATURAL FORM OF THE MISTAKE: a copy at a new path with
	#     mf_mk2.tres repointed at it. By the same last-writer-wins rule get_kit returns the copy too,
	#     so both sides are the copy and this test is green while the mod ships a duplicate
	#     mt_replaceable_parts that has displaced vanilla's in the kits index for the whole game.
	#     Nothing here guards that; testkit/mod_content_audit.gd and a reviewer's eye do.
	var ours:Kit = frame().traits[0]
	assert_same(ours, ContentLibrary.get_kit(&'mt_replaceable_parts'),
		'The very same Resource instance vanilla registered, not a copy of it.')

func test_the_tagline_is_the_one_the_author_ruled() -> void:
	# Ruling 2: the stand-in role word from the spike is gone.
	#
	# ASSERTED AGAINST OUR OWN ARTIFACT AS WELL AS tr(), which is the stronger of the two shapes
	# available and the one test_fitzgerald_frame.gd already uses. A bare tr() reads the global
	# TranslationServer, and Translate.add_translation_from_file globs the mod's directory for
	# *.translation and loads THAT - so an outdated compiled artifact answers while the CSV on disk
	# says something else, and the test passes against text nobody ships. Reading the artifact
	# directly is what notices.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation != null:
		assert_eq(String(translation.get_message('frame.mf_mk2.flavor.short')), 'Archival Artillerist',
			'Ruling 2, in the artifact that actually ships.')
	assert_eq(tr('frame.mf_mk2.flavor.short'), 'Archival Artillerist', 'Ruling 2.')

## THE M/K2's DISPLAY TEXT, DRIVEN OFF THE FRAME ITSELF.
##
## The branch added 21 localisation rows and, before this test, exactly one of them was asserted
## anywhere. Delete frame.mf_mk2.name - the string mech select shows - or any trait's .name/.effect,
## and the player reads a raw translation key off a card while the suite stays green.
##
## DRIVEN OFF frame().traits RATHER THAN A HAND-WRITTEN LIST on purpose: a fifth trait cannot ship
## without its rows, because the loop grows with the frame. Replaceable Parts is vanilla's own Kit
## and its rows are vanilla's, which is exactly why asking the ARTIFACT about it would be wrong -
## the loop below asks tr() for every trait (vanilla's included, and it must resolve) and asks our
## own artifact only about the keys this mod is the sole possible supplier of.
func test_every_new_display_row_resolves() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return

	for key:String in ['frame.mf_mk2.name', 'frame.mf_mk2.flavor', 'frame.mf_mk2.flavor.short']:
		assert_ne(String(translation.get_message(key)), '', 'Our artifact carries %s.' % key)
		assert_ne(tr(key), key, 'tr(%s) does not come back as the key.' % key)

	var traits:Array = frame().traits
	assert_eq(traits.size(), EXPECTED_TRAITS.size(), 'Guard: the trait list is not empty.')
	for kit:Kit in traits:
		assert_ne(kit.name(), 'gear.%s.name' % kit.compcon_id,
			'%s resolves a display name.' % kit.compcon_id)
		# Our three carry their own rows; vanilla's Replaceable Parts is answered by the base game.
		if kit.compcon_id == &'mt_replaceable_parts': continue
		for suffix:String in ['name', 'effect']:
			var key := 'gear.%s.%s' % [kit.compcon_id, suffix]
			assert_ne(String(translation.get_message(key)), '', 'Our artifact carries %s.' % key)

# ---------------------------------------------------------------- the licence
#
# The five tests below came from spec/test_spike_license_extension.gd (spike 2, 2026-09-14) when that
# probe was deleted at the end of SP1. They are its proof that the direct-apply licence extension
# works and co-exists with other mods' extensions of the same .tres, and they belong with the frame
# they grant. Pasted UNCHANGED apart from BASE_FRAME_ID -> EVEREST_ID (same constant, two names -
# this file keeps the template's), together with the Compat preload, the LICENSE_ID / OTHER_EXTENDERS
# constants and the _license() / _rank_1_frame_ids() helpers above.

func test_li_gms_rank_1_grants_the_mk2():
	assert_has(_rank_1_frame_ids(), FRAME_ID, 'li_gms rank 1 grants %s.' % FRAME_ID)

func test_a_fresh_pilot_can_pick_the_mk2():
	# The player-facing half. get_available_frames walks every GMS licence at rank 3 regardless of
	# the pilot's level, so a frame at li_gms rank 1 is offered to a licence-level-0 pilot.
	var pilot := PilotCore.create()
	var ids:Array[StringName] = []
	for f:Frame in pilot.get_available_frames(): ids.append(f.compcon_id)
	assert_has(ids, FRAME_ID, 'A fresh pilot is offered %s.' % FRAME_ID)
	assert_has(ids, EVEREST_ID, 'A fresh pilot is still offered the Everest.')

func test_the_everest_still_names_the_licence_and_its_gear_is_untouched():
	var tree := _license()
	assert_not_null(tree, 'li_gms loads.')
	if tree == null or tree.rank_1 == null: return
	assert_eq(tree.rank_1.granted_frames.front().compcon_id, EVEREST_ID,
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
