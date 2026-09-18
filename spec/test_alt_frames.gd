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
#     mod holds one from mod_main.EXTENDED_RESOURCES, and every alt's entry is checked to be IN that
#     list (test_every_alt_frame_reaches_its_licence). A dropped reference looks exactly like a frame
#     that was never built - it just is not in the licence.
#     Note what that half can and cannot do: it proves the path is DECLARED for retention. Whether
#     the reference survives is a lifetime question, and a test run where ContentLibrary happens to
#     hold the licence would pass either way. The declaration check is the cheap half worth having.
#  2. The vanilla licence underneath can move. The grants below are read from the LIVE licence, not
#     transcribed, so a modkit update that reshuffles a rank shows red HERE, in one place, rather
#     than as a confusing failure inside whichever alt happened to be built that week.
#
# The baseline pin below is asserted alongside the alts themselves.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const MOD_ID := 'Reag-TheSixthVoice'
const OUR_MOD_MAIN := 'res://unpacked/Reag-TheSixthVoice/mod_main.gd'

## Our alt frames, by the licence they attach to. Each entry is
##   <base licence id> : { frame = <our mf_ id>, rank = <1|2> }
## Filled in as each alt ships.
const ALT_FRAMES := {
	&'li_gms': {frame = &'mf_mk2', rank = 1}, # M/K2, the Everest alt (spike 2, 2026-09-14)
	&'li_barbarossa': {frame = &'mf_subutai', rank = 2}, # Subutai, the Barbarossa alt (SP1, 2026-09-15)
	&'li_gorgon': {frame = &'mf_myconid', rank = 2}, # Myconid, the Gorgon alt (SP1, 2026-09-15)
	&'li_mourning_cloak': {frame = &'mf_maidens_blush', rank = 2}, # Maiden's Blush, the Mourning Cloak alt (SP1, 2026-09-17)
	&'li_iskander': {frame = &'mf_vauban', rank = 2}, # Vauban, the Iskander alt (SP1, 2026-09-18)
}

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
	'Six Sky': {license = &'li_sunzi', why = 'Sunzi (HA, Long Rim) - the ha-sunzi mod, optional dependency, phase 6'},
	'Black Mountain': {license = &'li_emperor', why = 'Emperor (SSC, KTB) - the ssc-emperor mod, optional dependency, phase 6'},
	'Seraphim': {license = &'li_lich', why = 'Lich (HORUS, Long Rim) - no mod adds the Lich; BLOCKED'},
}

func _license(license_id:StringName) -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(license_id)
	return tree if tree is UnlockTree else null

## Which resident mod supplies a licence, or '' when nothing does (or the modkit itself does).
## res://unpacked/gavstarb-ssc_emperor/res/content/licenses/ssc/li_emperor.tres => gavstarb-ssc_emperor
static func _supplier_of(license_paths:Dictionary, license_id:StringName) -> String:
	if not license_paths.has(license_id): return ''
	var path := String(license_paths[license_id])
	if not path.begins_with('res://unpacked/'): return ''
	return path.trim_prefix('res://unpacked/').get_slice('/', 0)

## Every licence path the engine knows, vanilla and modded, by id.
##
## Read off the ResourceGroup rather than ContentLibrary.compcon_id_to_path, which is an INSTANCE var
## on the autoload: the parser resolves the bare name `ContentLibrary` to the class, so naming that
## member is a PARSE error, and GUT skips an unparsable script instead of failing it - the suite goes
## green and two tests quietly vanish. (Done exactly that on 2026-09-13; the totals caught it.)
## RESOURCE_GROUPS is a const, so it is safe here.
func _license_paths_by_id() -> Dictionary:
	var by_id := {}
	var group:ResourceGroup = ContentLibrary.RESOURCE_GROUPS.get(&'licenses', null)
	if group == null: return by_id
	for path:String in group.get_paths(): by_id[ContentLibrary.get_compcon_id_from_path(path)] = path
	return by_id

# ---------------------------------------------------------------- the alts themselves

## How many alts are built. Bumped by each alt's sub-project, in the same commit that adds its
## ALT_FRAMES row. It is the tripwire for an alt silently dropping out of the table - a frame that
## stops being granted would otherwise just make the loop below shorter, and a shorter loop reads
## exactly like a pass.
const ALTS_BUILT := 5

## The same tripwire for BASE_LICENSES, which ALTS_BUILT does not cover. Three tests below loop over
## it, and emptying it ENTIRELY is caught indirectly (test_every_alt_frame_reaches_its_licence
## asserts its own licence is present) - but SHRINKING it from ten rows to one is caught by nothing:
## all three loops simply get quieter, and GUT marks a zero-assert test RISKY rather than FAILED
## (gut.gd:581, :821), so the suite still reads green while the baseline it pins has evaporated.
## Bump this only when a row is added or removed deliberately.
const BASE_LICENSES_PINNED := 10

func test_the_baseline_table_is_intact():
	assert_eq(BASE_LICENSES.size(), BASE_LICENSES_PINNED,
		'%d base licences pinned, %d in the table.' % [BASE_LICENSES_PINNED, BASE_LICENSES.size()])

func test_every_alt_frame_reaches_its_licence():
	assert_eq(ALT_FRAMES.size(), ALTS_BUILT, '%d alt frames built, %d in the table.' % [ALTS_BUILT, ALT_FRAMES.size()])
	var retained:Array = load(OUR_MOD_MAIN).get_script_constant_map().get('EXTENDED_RESOURCES', [])
	var license_paths := _license_paths_by_id()
	for license_id:StringName in ALT_FRAMES:
		# Consistency first: an alt may only be built against a base whose baseline is pinned below.
		assert_true(BASE_LICENSES.has(license_id), '%s is pinned in BASE_LICENSES.' % license_id)
		# And its licence must be declared for retention, or upstream bug 7 drops the extension the
		# moment nothing else holds the resource - which reads as a frame that was never built.
		var vanilla_path:String = license_paths.get(license_id, '')
		assert_true(retained.has(vanilla_path),
			'mod_main.EXTENDED_RESOURCES declares %s (%s).' % [license_id, vanilla_path])
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
	# The fragile part is not the licence's contents but the lookup that reaches it: get_available_frames
	# (pilot_core.gd:394-396) walks Manufacturer.all_licenses[&'gms'] and asks each for rank 3, so a
	# frame granted at GMS rank 1 is available at any level. Both halves are pinned.
	assert_true(Manufacturer.all_licenses.has(&'gms'), 'There is a GMS licence list.')
	assert_true(Array(Manufacturer.all_licenses.get(&'gms', [])).has(&'li_gms'),
		'li_gms is in the GMS licence list get_available_frames walks.')
	var tree:UnlockTree = _license(&'li_gms')
	assert_not_null(tree, 'li_gms loads.')
	if tree == null: return
	assert_not_null(tree.rank_1, 'li_gms has a rank 1.')
	if tree.rank_1 == null: return
	assert_false(tree.rank_1.granted_frames.is_empty(), 'li_gms rank 1 grants at least one frame.')

func test_the_three_alts_without_a_base_are_known_absent():
	# Not a to-do: a guard. If one of these licences APPEARS, this test says WHERE IT CAME FROM,
	# because the two routes mean opposite things:
	#
	#  - THE MODKIT ships it -> RED. The base is now universal, phase 6 needs no optional dependency
	#    at all, and the release plan should be re-cut. That is this guard's original trigger.
	#  - A RESIDENT MOD supplies it -> green, and reported. The base is available to US, so the alt
	#    becomes buildable - but it is still optional for players, so the dependency stands and the
	#    phase 6 plan is unchanged.
	#
	# The second case was added 2026-09-16, when gavstarb-ssc_emperor joined the residency set and
	# tripped the old blanket assert_false. Before that the distinction could not arise: no
	# third-party mod was ever installed in a test run.
	# See lancer-tactics-claude/specs/2026-09-16-mod-compatibility-design.md §1.7.
	#
	# Asked of the licence paths rather than through _license(), which would route each miss through
	# ContentLibrary.load_compcon_id_resource and printerr three "Could not find compcon ID" lines
	# into every run forever. Those do not fail the suite, but noise in a green run is how a real
	# error stops being noticed.
	var license_paths := _license_paths_by_id()
	assert_gt(license_paths.size(), 0, 'The licences index loaded, so absence means something.')
	for license_id:StringName in [&'li_sunzi', &'li_emperor', &'li_lich']:
		if not license_paths.has(license_id): continue
		assert_true(String(license_paths[license_id]).begins_with('res://unpacked/'),
			'%s exists only because a MOD adds it (%s); the modkit still does not ship it.'
			% [license_id, license_paths[license_id]])
	for alt:String in ALTS_WITHOUT_A_BASE:
		var supplier := _supplier_of(license_paths, ALTS_WITHOUT_A_BASE[alt].license)
		if supplier.is_empty():
			gut.p('  %-16s blocked on %s' % [alt, ALTS_WITHOUT_A_BASE[alt].why])
		else:
			gut.p('  %-16s BASE NOW SUPPLIED BY %s - buildable; dependency stays optional'
				% [alt, supplier])
