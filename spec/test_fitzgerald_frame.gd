# SP1 Task 1: the Fitzgerald frame and its licence.
#
# Loads both through ContentLibrary (get_mech_frame / get_license_tree), not by preloading the
# .tres directly, so this proves REGISTRATION - that the mirror-path overlay actually filed the
# resource under the right ContentLibrary index - rather than just that the file parses.
#
# TDD note: written before mf_fitzgerald.tres / li_fitzgerald.tres exist. Expect RED naming
# mf_fitzgerald / li_fitzgerald as missing (X.error "Unable to find frame/could not find compcon
# ID"), not a parse error inside this file.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FRAME_ID := &'mf_fitzgerald'
const LICENSE_ID := &'li_fitzgerald'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can
## be attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run.
## Same pattern as test_content_integrity.gd:107/118.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

var game:Gamemaster

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)

func _frame() -> Frame:
	var frame = ContentLibrary.get_mech_frame(FRAME_ID)
	return frame if Frame.is_valid(frame) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

# ---------------------------------------------------------------- the frame

func test_the_frame_is_registered():
	assert_not_null(_frame(), '%s loads as a valid Frame through ContentLibrary.' % FRAME_ID)

func test_the_statblock_matches_the_sheet():
	var frame := _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var stat:Statblock = frame.stat
	assert_not_null(stat, 'fixture: the frame has a statblock.')
	if stat == null: return

	# One assertion per stat from the rules sheet's "Stats" table, so a single wrong number names
	# itself instead of hiding behind an aggregate diff.
	assert_eq(stat.structure, 4, 'structure')
	assert_eq(stat.stress, 4, 'stress')
	assert_eq(stat.health, 6, 'health')
	assert_eq(stat.armor, 1, 'armor')
	assert_eq(stat.evasion, 10, 'evasion')
	assert_eq(stat.edef, 6, 'edef')
	assert_eq(stat.heat, 5, 'heat')
	assert_eq(stat.repairs, 4, 'repairs')
	assert_eq(stat.sensor_range, 10, 'sensor_range')
	assert_eq(stat.tech_attack, -2, 'tech_attack')
	assert_eq(stat.save_target, 10, 'save_target')
	assert_eq(stat.speed, 4, 'speed')
	assert_eq(stat.systems_points, 6, 'systems_points')

func test_the_frame_is_size_half():
	var frame := _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.stat.size, 1, 'stat.size is 1.')
	assert_true(frame.stat.is_size_half, 'stat.is_size_half is true.')

	# UnitCore.is_size_half() (unit_core.gd:391) is `frame.stat.is_size_half and bonus.size <= 0` -
	# a size bonus would mask the resource's own flag - so assert on a live unit, not only the
	# resource, the way the brief calls for.
	var unit:Unit = SpecFactory.create_unit(game.map, Vector2i(0, 0))
	unit.core.frame = frame
	unit.core.full_repair()
	assert_true(unit.core.is_size_half(), 'The live unit built on this frame reads as size-half.')
	assert_eq(unit.core.get_size_float(), 0.5, 'The live unit is size 0.5.')

func test_the_frame_has_one_main_mount():
	var frame := _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.mount_types.size(), 1, 'Exactly one mount.')
	if frame.mount_types.size() != 1: return
	var expected:MountType = load('res://content/mounts/mount_main.tres')
	assert_eq(frame.mount_types[0], expected, 'The one mount is content/mounts/mount_main.tres.')

func test_the_frame_carries_all_five_traits():
	# SP1 Task 2 landed the first of five trait Kits (Weak Computer), Task 3 the second (Broadside),
	# Task 5 the third (Hole Puncher), Task 6 the fourth (Knock 'em down) and Task 7 the fifth
	# (Blasting Powder) - so the frame is COMPLETE, and this list should not grow again. Each trait's
	# own behaviour is specced beside it - test_weak_computer.gd, test_bizarre_cannon.gd,
	# test_hole_puncher.gd, test_knock_em_down.gd, test_blasting_powder.gd - so this only pins that
	# it is wired onto the frame at all, and in a way that a new trait cannot quietly displace an old
	# one.
	#
	# (Task 2 folded this into the mount test to hit a predicted test count; split back out in
	# Task 3, because a mount regression and a trait regression are not the same failure.)
	#
	# THIS ASSERTS ORDER, DELIBERATELY, and must not be relaxed to membership. The array order is
	# PLAYER-VISIBLE: catalog_license_focus_spread.gd:31 iterates core.frame.traits in array order to
	# fill the catalog's trait slots (lifting the core power out into its own slot as it goes), and
	# mech_section.gd:109 iterates loadout.get_frame_traits(), which preserves it. The order below is
	# the one the design doc (2026-09-13-fitzgerald-design.md
	# §2.0) and the rules sheet (specs/sixth-voice/01-fitzgerald.md) both specify - abilities first,
	# the drawback second-to-last, the core system last. Whole-branch review, 2026-09-13: the build
	# tasks had left the array in the order the tasks happened to land in, which led the catalog with
	# the frame's drawback and buried the core system second.
	var frame := _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried,
		[&'mt_hole_puncher', &'mt_knock_em_down', &'mt_blasting_powder', &'mt_weak_computer',
			&'cp_broadside'],
		'The frame carries exactly its five traits, in the order the design and rules sheet specify.')

func test_the_frame_has_the_sheets_roles():
	# Rules sheet (01-fitzgerald.md line 6): "Roles: Artillery, Striker". role_secondary is
	# consumed by catalog_blurb.gd and opfor_editor_modal.gd, not decorative - a missing value
	# silently drops the frame's second role from both.
	var frame := _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.ARTILLERY, 'role_primary is Artillery.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.STRIKER, 'role_secondary is Striker.')

# ---------------------------------------------------------------- the licence

func test_the_licence_is_registered():
	assert_not_null(_license(), '%s loads as an UnlockTree through ContentLibrary.' % LICENSE_ID)

func test_the_licence_grants_the_frame_at_rank_2():
	var license := _license()
	var frame := _frame()
	assert_not_null(license, 'fixture: the licence loads.')
	assert_not_null(frame, 'fixture: the frame loads.')
	if license == null or frame == null: return
	assert_not_null(license.rank_1, 'the licence has a rank_1.')
	assert_not_null(license.rank_2, 'the licence has a rank_2.')
	assert_not_null(license.rank_3, 'the licence has a rank_3.')
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return

	assert_true(license.rank_2.granted_frames.has(frame), 'rank_2.granted_frames contains the frame.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1.granted_frames is empty.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3.granted_frames is empty.')

## SP2 Task 1 replaced SP1's test_the_licence_grants_no_gear_yet, which pinned a frame-only licence
## and was never meant to stay true: rank 1 now grants the Breech-loading Swivel Gun and, since SP2
## Task 4, HEAER. Ranks 2 and 3 are still empty of gear and stay asserted, so a rank-2 or rank-3 item
## cannot arrive unannounced.
##
## ASSERTED AS AN EXACT LIST, NOT AS MEMBERSHIP, matching the deliberate order assertion in
## test_the_frame_carries_all_five_traits above: granted_gear order is player-visible in the catalog's
## licence spread the same way the trait array is, and "contains" would not notice a duplicate entry
## or a second item landing in the wrong rank. The gun's own behaviour is specced in
## test_swivel_gun.gd; this only pins where the licence hands it out.
func test_the_licence_grants_the_rank_1_gear():
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	for rank:UnlockRank in license.get_ranks():
		assert_not_null(rank, 'fixture: every rank exists.')
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return

	var rank_1_gear:Array = license.rank_1.granted_gear.map(
		func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_1_gear, [&'mw_breech_loading_swivel_gun', &'ms_heaer'],
		'Rank 1 grants exactly the Breech-loading Swivel Gun and HEAER, in that order.')
	assert_true(license.rank_2.granted_gear.is_empty(), 'Rank 2 grants no gear yet.')
	assert_true(license.rank_3.granted_gear.is_empty(), 'Rank 3 grants no gear yet.')

# ---------------------------------------------------------------- display text

func test_the_frame_and_licence_have_display_text():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	assert_ne(translation.get_message('frame.mf_fitzgerald.name'), StringName(''),
		'Our own artifact carries frame.mf_fitzgerald.name.')

	# And end to end: tr() resolves it (through the global TranslationServer, which is fine here -
	# frame.mf_fitzgerald.name is a key only this mod could ever supply, unlike the shared glossary
	# terms in test_content_integrity.gd).
	assert_ne(tr('frame.mf_fitzgerald.name'), 'frame.mf_fitzgerald.name',
		"tr('frame.mf_fitzgerald.name') does not come back as the key.")

	var frame := _frame()
	var license := _license()
	assert_not_null(frame, 'fixture: the frame loads.')
	assert_not_null(license, 'fixture: the licence loads.')
	if frame == null or license == null: return
	assert_ne(frame.name(), 'frame.mf_fitzgerald.name', 'Frame.name() resolves through tr().')
	assert_ne(license.license_name(), 'frame.mf_fitzgerald.name',
		'The licence names itself after its granted frame, translated.')
