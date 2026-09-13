# Alt frames: does each one actually reach the licence it attaches to?
#
# Thirteen of the supplement's twenty-one frames are ALTS - frame, traits and core only, hung off
# another licence's rank 2 (rank 1 for the Everest alt). Per the author's 2026-09-13 directive they
# EXTEND the vanilla licence in place with a .tres_ext.gd; they never clone it, the way Thy Hubris'
# variants did.
#
# That makes two things fragile, and this file guards both:
#
#  1. The extension can silently un-happen. Upstream bug 7 is unfixed on 1.4.3: ModLoader no longer
#     retains an extended resource, so the effect evaporates once nothing holds a reference. The
#     mod holds one from mod_main.EXTENDED_RESOURCES. A dropped reference looks exactly like a
#     frame that was never built - it just is not in the licence.
#  2. The vanilla licence underneath can move. The grants below are read from the LIVE licence, not
#     transcribed, so a modkit update that reshuffles a rank shows red HERE, in one place, rather
#     than as a confusing failure inside whichever alt happened to be built that week.
#
# ALT_FRAMES is empty until M/K2 (frame 2). The baseline pin below is what this file asserts in the
# meantime, and it keeps asserting it afterwards.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const MOD_ID := 'Reag-TheSixthVoice'

## Our alt frames, by the licence they attach to. Each entry is
##   <base licence id> : { frame = <our mf_ id>, rank = <1|2> }
## Filled in as each alt ships. Empty is correct in SP0: no alt exists yet.
const ALT_FRAMES := {}

## The vanilla licences the alts extend, with the rank each alt attaches to, and the frame that
## licence grants there today. Ten of the thirteen alts; the other three have no base in this
## modkit (see test_the_three_alts_without_a_base_are_known_absent).
##
## Read as: "before we touch it, li_barbarossa grants exactly mf_barbarossa at rank 2". An alt adds
## its frame to that array; it must never replace or reorder what is already there, because
## UnlockTree.license_name reads rank_2.granted_frames.FRONT() to name the licence in the UI.
const BASE_LICENSES := {
	&'li_gms':            {rank = 1, frame = &'mf_standard_pattern_i_everest',       alt = 'M/K2'},
	&'li_barbarossa':     {rank = 2, frame = &'mf_barbarossa',    alt = 'Subutai'},
	&'li_gorgon':         {rank = 2, frame = &'mf_gorgon',        alt = 'Myconid'},
	&'li_mourning_cloak': {rank = 2, frame = &'mf_mourning_cloak', alt = "Maiden's Blush"},
	&'li_iskander':       {rank = 2, frame = &'mf_iskander',      alt = 'Vauban'},
	&'li_nelson':         {rank = 2, frame = &'mf_nelson',        alt = 'Shackleton'},
	&'li_tortuga':        {rank = 2, frame = &'mf_tortuga',       alt = 'Gloire'},
	&'li_drake':          {rank = 2, frame = &'mf_drake',         alt = 'Grutte Pier'},
	&'li_goblin':         {rank = 2, frame = &'mf_goblin',        alt = 'Rakshasa'},
	&'li_deaths_head':    {rank = 2, frame = &'mf_deaths_head',   alt = 'Lovers Knot'},
}

## Alts whose base frame this modkit does not ship. Lancer Tactics has the core book complete and
## nothing from the KTB or the Long Rim, so these three have nowhere to attach. Named rather than
## quietly missing, so "why is Seraphim not built" has an answer in the suite and not just in a doc.
const ALTS_WITHOUT_A_BASE := {
	'Six Sky': 'Sunzi (HA, Long Rim) - the ha-sunzi mod, optional dependency, phase 6',
	'Black Mountain': 'Emperor (SSC, KTB) - the ssc-emperor mod, optional dependency, phase 6',
	'Seraphim': 'Lich (HORUS, Long Rim) - no mod adds the Lich; BLOCKED',
}

func _license(license_id:StringName) -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(license_id)
	return tree if tree is UnlockTree else null

# ---------------------------------------------------------------- the alts themselves

## How many alts are built. Bumped by each alt's sub-project, in the same commit that adds its
## ALT_FRAMES row. It is the tripwire for an alt silently dropping out of the table - a frame that
## stops being granted would otherwise just make the loop below shorter, and a shorter loop reads
## exactly like a pass.
const ALTS_BUILT := 0

func test_every_alt_frame_reaches_its_licence():
	assert_eq(ALT_FRAMES.size(), ALTS_BUILT, '%d alt frames built, %d in the table.' % [ALTS_BUILT, ALT_FRAMES.size()])
	for license_id:StringName in ALT_FRAMES:
		# Consistency first: an alt may only be built against a base whose baseline is pinned below.
		assert_true(BASE_LICENSES.has(license_id), '%s is pinned in BASE_LICENSES.' % license_id)
		var entry:Dictionary = ALT_FRAMES[license_id]
		var tree:UnlockTree = _license(license_id)
		assert_not_null(tree, '%s loads.' % license_id)
		if tree == null: continue
		var rank:UnlockRank = tree.get_rank(entry.rank)
		assert_not_null(rank, '%s has a rank %d.' % [license_id, entry.rank])
		if rank == null: continue
		var granted:Array[StringName] = []
		for frame:Frame in rank.granted_frames: granted.append(frame.compcon_id)
		assert_has(granted, entry.frame,
			'%s grants %s at rank %d.' % [license_id, entry.frame, entry.rank])

func test_no_licence_is_renamed_by_what_we_add_to_it():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT(), so whichever frame sits first
	# names the licence everywhere the UI shows it. Appending an alt is safe; inserting at the front
	# renames the vanilla licence after our frame.
	#
	# Walks every pinned base, not just the ones with an alt built, so it pins vanilla's own ordering
	# today and catches a bad insertion the moment one lands.
	for license_id:StringName in BASE_LICENSES:
		var entry:Dictionary = BASE_LICENSES[license_id]
		if entry.rank != 2: continue
		var tree:UnlockTree = _license(license_id)
		assert_not_null(tree, '%s loads.' % license_id)
		if tree == null or tree.rank_2 == null: continue
		assert_false(tree.rank_2.granted_frames.is_empty(), '%s rank 2 grants a frame.' % license_id)
		if tree.rank_2.granted_frames.is_empty(): continue
		assert_eq(tree.rank_2.granted_frames.front().compcon_id, entry.frame,
			'%s is still named for %s.' % [license_id, entry.frame])

# ---------------------------------------------------------------- the vanilla baseline

func test_every_base_licence_we_will_extend_exists():
	for license_id:StringName in BASE_LICENSES:
		assert_not_null(_license(license_id),
			'%s loads (base for %s).' % [license_id, BASE_LICENSES[license_id].alt])

func test_every_base_licence_grants_its_own_frame_at_the_rank_the_alt_attaches_to():
	# The attachment point, pinned. If a modkit update moves a frame to another rank, the alt that
	# extends it would attach to the wrong one and nothing else in the suite would notice.
	for license_id:StringName in BASE_LICENSES:
		var entry:Dictionary = BASE_LICENSES[license_id]
		var tree:UnlockTree = _license(license_id)
		if tree == null: continue
		var rank:UnlockRank = tree.get_rank(entry.rank)
		assert_not_null(rank, '%s has a rank %d.' % [license_id, entry.rank])
		if rank == null: continue
		var granted:Array[StringName] = []
		for frame:Frame in rank.granted_frames: granted.append(frame.compcon_id)
		assert_has(granted, entry.frame,
			'%s grants %s at rank %d, where %s will attach.' % [license_id, entry.frame, entry.rank, entry.alt])

func test_the_everest_is_reachable_at_any_licence_level():
	# M/K2 is the only alt attaching at rank 1, and it does so because PilotCore.get_available_frames
	# takes every GMS licence frame regardless of level - which is what makes an Everest alt playable
	# from the start. If that stops being true, M/K2's whole shape changes.
	var tree:UnlockTree = _license(&'li_gms')
	assert_not_null(tree, 'li_gms loads.')
	if tree == null: return
	assert_not_null(tree.rank_1, 'li_gms has a rank 1.')
	if tree.rank_1 == null: return
	assert_false(tree.rank_1.granted_frames.is_empty(), 'li_gms rank 1 grants at least one frame.')

func test_the_three_alts_without_a_base_are_known_absent():
	# Not a to-do: a guard. If a future modkit ships the Sunzi, the Emperor or the Lich, these
	# licences appear and this test goes red - which is the signal to re-plan phase 6 rather than
	# keep paying for an optional-dependency release nobody needs.
	for license_id:StringName in [&'li_sunzi', &'li_emperor', &'li_lich']:
		assert_null(_license(license_id),
			'%s is still absent from the modkit.' % license_id)
	for alt:String in ALTS_WITHOUT_A_BASE:
		gut.p('  %-16s blocked on %s' % [alt, ALTS_WITHOUT_A_BASE[alt]])
