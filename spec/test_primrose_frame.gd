# The Primrose (SSC) - SP1 Task 1, with the trait list pinned in Task 7.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix or resource group is
# wrong is silently filed somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT. Unlike the M/K2, Subutai, Myconid, Maiden's Blush and Vauban, this
# frame ships its own li_primrose.tres rather than extending a vanilla licence - so there is no
# .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row. The Fitzgerald
# is the mod's only other full licence and this file is its shape.
#
# Numbers come from the notes repo's specs/sixth-voice/07-primrose.md Stats table, which is
# generated from the LCP. Neither the sheet nor its generator lives in this repo. A red here means
# the .tres drifted from the card, OR that the sheet was regenerated - check the sheet's git history
# (in the lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_primrose_frame.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const FRAME_ID := &'mf_primrose'
const LICENSE_ID := &'li_primrose'
const FITZGERALD_ID := &'mf_fitzgerald'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run. Same
## pattern as test_content_integrity.gd and test_fitzgerald_frame.gd.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table (specs/sixth-voice/07-primrose.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
##
## SIXTEEN FIELDS, not the card's fourteen columns: Statblock carries `reactions` and `activations`
## too, and every frame in this mod sets both to 1.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 1, evasion = 8, edef = 8,
	speed = 5, heat = 5, save_target = 10, sensor_range = 10, tech_attack = -1, repairs = 4,
	systems_points = 6, reactions = 1, activations = 1,
}

const PRIMROSE_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _frame() -> Frame:
	var frame = ContentLibrary.get_mech_frame(FRAME_ID)
	return frame if Frame.is_valid(frame) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

# ---------------------------------------------------------------- the frame

func test_the_frame_is_registered():
	assert_not_null(_frame(), '%s loads as a valid Frame through ContentLibrary.' % FRAME_ID)

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'fixture: the frame carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size, and the Fitzgerald - the mod's only other SSC-shaped
	# full licence - DOES set it, so a copy from that file is the natural mistake. A size-1 frame that
	# also set it would occupy one tile while reporting height 0, and every adjacency, threat and
	# line-of-sight assertion in the trait specs would quietly measure the wrong geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Primrose is a full size 1, not size 1/2.')

func test_the_mounts_are_main_main_heavy():
	# SHEET ORDER ("Mounts: Main, Main, Heavy"), and it is player-visible: the mech sheet draws mounts
	# in array order. Three mounts is rare - content/frames/ha/mf_barbarossa/mf_barbarossa.tres:36 is
	# the vanilla precedent - so this is also the guard against a two-mount copy from another frame.
	#
	# THE HEAVY MOUNT IS LOAD-BEARING FOR THIS WHOLE SUB-PROJECT: a SUPERHEAVY weapon needs it (plus a
	# Main to brace), and Wormhole Grasp's entire point is Overwatching with one.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_main.tres', 'mount_main.tres', 'mount_heavy.tres'],
		'Main, Main, Heavy - the sheet order.')

func test_the_role_is_striker_with_no_secondary():
	# Sheet line 6: "Roles: Striker". role_secondary is consumed by catalog_blurb.gd and
	# opfor_editor_modal.gd, not decorative - a stray value silently invents a second role.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_wears_the_shared_placeholder_sprite():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_primrose.sprites.
	#
	# ASSERTED AS *IS* THE PLACEHOLDER, NOT "is not", DELIBERATELY - the inverse of every other frame
	# spec in this mod. The design (1.1) says the Primrose ships on the shared stand-in and SP5
	# replaces it, so this assertion is the pin that makes that replacement a DELIBERATE edit in two
	# places rather than a silent drift. SP5 flips both halves: the ext_resource path in the .tres and
	# this line.
	#
	# 80x80, not the 160x160 sibling: the mod ships mf_placeholder.png (80x80, size 1) and
	# mf_placeholder_160.png (160x160, size 2), and pointing a size-1 frame at the larger one renders
	# it at double scale on the board.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')
	assert_true(sprite.resource_path.ends_with('/mf_placeholder.png'),
		'SP5 replaces this with the frame\'s own art and flips this assertion.')

func test_the_frame_has_the_fitzgeralds_neutral_colour_scheme():
	# A NEUTRAL STAND-IN, and a decision rather than a default - see the NOTE in the plan. The icon
	# directive derives a frame's ColorScheme FROM ITS SPRITE at the icon pass, and the sprite today is
	# the shared placeholder, so any chosen palette now would be invented twice. The Fitzgerald's own
	# scheme is the mod's one existing colourless block (no toneramp at all), which is exactly what
	# "provisional" should look like on the board.
	#
	# PINNED AGAINST BOTH FRAMES, not against transcribed literals: reading the Fitzgerald's live
	# scheme makes this a statement about the relationship, and it is also the guard on the palette
	# SLOT - the Maiden's Blush sets palette_1 and the Iskander sets palette_2, so a copy from the
	# wrong sibling would drop or add a toneramp silently.
	#
	# CORRECTED AT IMPLEMENTATION (2026-09-19): the brief's draft asserted assert_null on palette_1/2,
	# on the claim that the Fitzgerald's block carries "no toneramp at all". That is not what the
	# engine does: color_scheme.gd:60-61 declares `@export var palette_1/2:Texture2D = DEFAULT_TONERAMP`,
	# so a .tres that never writes those keys - which is exactly what mf_fitzgerald.tres and this file
	# both do - inherits the non-null default toneramp, not null. assert_null could never pass for ANY
	# resource, including the Fitzgerald's own; confirmed by reading color_scheme.gd directly, not by
	# guessing around the red. Asserting equality against the Fitzgerald (matching the base_0/1/2 lines
	# just above) preserves the actual claim - neither frame carries a CUSTOM toneramp, both sit on the
	# same script default - without asserting a nullness the engine never produces.
	var frame:Frame = _frame()
	var fitzgerald:Frame = ContentLibrary.get_mech_frame(FITZGERALD_ID)
	assert_not_null(frame, 'fixture: the frame loads.')
	assert_not_null(fitzgerald, 'fixture: the Fitzgerald loads, to compare against.')
	if frame == null or fitzgerald == null: return
	var ours:ColorScheme = frame.default_color_scheme
	var theirs:ColorScheme = fitzgerald.default_color_scheme
	assert_not_null(ours, 'The Primrose carries a default colour scheme.')
	assert_not_null(theirs, 'And the Fitzgerald carries one to compare against.')
	if ours == null or theirs == null: return
	assert_eq(ours.base_0, theirs.base_0, 'base_0 matches the Fitzgerald.')
	assert_eq(ours.base_1, theirs.base_1, 'base_1 matches the Fitzgerald.')
	assert_eq(ours.base_2, theirs.base_2, 'base_2 matches the Fitzgerald.')
	assert_eq(ours.palette_1, theirs.palette_1,
		'palette_1 matches the Fitzgerald - both left at the script default toneramp, neither custom.')
	assert_eq(ours.palette_2, theirs.palette_2, 'And palette_2 matches too.')

func test_the_name_and_flavour_and_tagline_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green, and then
	# end to end through tr(). A tr() that falls through to the raw key is the signature of a missing
	# CSV row OR of a stale compiled .translation; either way the card is blank in game.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_primrose.name', 'frame.mf_primrose.flavor', 'frame.mf_primrose.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_primrose.name'), 'Primrose', 'The frame is named Primrose.')
	assert_eq(X.tr('frame.mf_primrose.flavor.short'), 'Elegant Melee',
		'The tagline the author picked (ruling 5) - the one invented string in SP1.')
	# The flavour is Bel's paragraph verbatim; its closing clause is the cheapest end-to-end check that
	# the whole paragraph landed rather than a truncation, and it is where the tagline came from.
	assert_true(X.tr('frame.mf_primrose.flavor').ends_with('immaculately done.'),
		'The flavour is the sheet paragraph, entire.')

func test_the_frame_carries_its_three_traits_in_sheet_order():
	# APPENDED ONCE PER TASK and pinned here at the close - Task 2 added Magnetic Weight
	# Redistribution, Task 3 Artful Caress, Task 4 MÖBIAN RAINBOW, each a pure APPEND.
	#
	# THIS ASSERTS ORDER, DELIBERATELY, and must not be relaxed to membership. The array order is
	# PLAYER-VISIBLE: catalog_license_focus_spread.gd:31 iterates core.frame.traits in array order to
	# fill the catalog's trait slots (lifting the core power out into its own slot as it goes), and
	# mech_section.gd:109 iterates loadout.get_frame_traits(), which preserves it. The order below is
	# the sheet's (specs/sixth-voice/07-primrose.md: the two traits, then the core system) and design
	# 1.1 names it explicitly. The Fitzgerald's whole-branch review found its array in
	# task-completion order, which put the frame's drawback first in the catalog and buried the core
	# system second; this is the pin that stops the same thing happening here.
	#
	# IT SHOULD NOT GROW. SP2, SP3 and SP4 add GEAR to li_primrose's ranks, not traits to the frame -
	# a trait is something the mech always has, and every remaining Primrose ability is licensed
	# equipment. A red here from a later sub-project means a piece of gear was wired as a trait.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried,
		[&'mt_magnetic_weight_redistribution', &'mt_artful_caress', &'cp_mobian_rainbow'],
		'The frame carries exactly its three traits, in the order the sheet prints them.')

# ---------------------------------------------------------------- the licence

func test_the_licence_is_registered():
	assert_not_null(_license(), '%s loads as an UnlockTree through ContentLibrary.' % LICENSE_ID)

func test_the_licence_grants_the_frame_at_rank_two_and_nowhere_else():
	var license := _license()
	var frame := _frame()
	assert_not_null(license, 'fixture: the licence loads.')
	assert_not_null(frame, 'fixture: the frame loads.')
	if license == null or frame == null: return
	assert_not_null(license.rank_1, 'the licence has a rank_1.')
	assert_not_null(license.rank_2, 'the licence has a rank_2.')
	assert_not_null(license.rank_3, 'the licence has a rank_3.')
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_2_frames:Array = license.rank_2.granted_frames.map(
		func(f:Frame) -> StringName: return f.compcon_id)
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Primrose, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_no_gear_at_any_rank_yet():
	# SP2 fills rank 1 (the Rend Axe and Dazzling Wind), SP3 rank 2 (the Acrasial Falcata and the
	# DDMR) and SP4 rank 3 (the Eternity Hammer and Flourishing Twirl). Asserted as EXACT empty lists
	# rather than "does not contain ours": the natural mistake when copying li_fitzgerald.tres is to
	# carry over ITS granted_gear entries, and those are vanilla-shaped ids this mod really does ship.
	# Each of the three lines below goes red exactly once, in the sub-project that fills that rank.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	assert_eq(license.rank_1.granted_gear.size(), 0, 'Rank 1 grants no gear yet (SP2 fills it).')
	assert_eq(license.rank_2.granted_gear.size(), 0, 'Rank 2 grants no gear yet (SP3 fills it).')
	assert_eq(license.rank_3.granted_gear.size(), 0, 'Rank 3 grants no gear yet (SP4 fills it).')

func test_the_licence_names_itself_after_the_frame():
	# THERE IS NO LICENCE NAME ROW, AND THAT IS THE ENGINE'S DESIGN rather than an omission.
	# UnlockTree.license_name (unlock_tree.gd:28-32) reads rank_2.granted_frames.FRONT() and
	# translates frame.<id>.name - so the licence is named "Primrose" off the frame's own row, and
	# writing a gear.li_primrose.name row would do nothing at all. li_fitzgerald.tres has none either.
	#
	# This also means an empty rank_2 renames the licence "???" (:31), which the exact-list assertion
	# above is what prevents.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_primrose.name'),
		'The licence names itself after its granted frame, translated.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_primrose():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back.
	#
	# PilotCore.get_available_frames (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3
	# regardless of pilot level, and get_unlocked_licensed_frames, which walks the pilot's OWN
	# RankProgress rows. li_primrose is not GMS, so only the second half can ever reach us.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_primrose at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Primrose 2 pilot is offered the Primrose.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:44-49),
	# so a licence that granted the frame at rank_1 by mistake would still show up at rank 2 and the
	# assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Primrose 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = PrimroseFixture.create_game(self)
	var primrose:Unit = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	assert_true(Unit.is_valid(primrose), 'A unit was created.')
	if not Unit.is_valid(primrose): return
	assert_eq(primrose.core.frame.compcon_id, FRAME_ID, 'It is wearing the Primrose frame.')
	assert_eq(primrose.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or sensor range into the
	# current block (only health/armor/heat/speed/structure/stress/repairs are synced); Unit.get_evasion
	# is core.get_evasion() + state.stat_bonus.evasion (unit.gd:306). That accessor is exactly what
	# Effervescent Immunity moves in Task 4, so pinning its BASE value here is what makes "+1" mean
	# something there.
	assert_eq(primrose.get_evasion(), SHEET_STATS.evasion,
		'It has the sheet evasion, read the way the engine reads it and the way Task 4 moves it.')
	assert_eq(primrose.get_save_target(), SHEET_STATS.save_target, 'And the sheet save target.')
	assert_eq(primrose.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(primrose.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the trait specs depends on it, '
		+ 'and CommonActionUtil auto-accepts prompts for a non-player unit.')

func test_the_fixture_arms_the_primrose_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK, and it is the only thing that exercises the equip helpers before Tasks 2-6
	# lean on them. Three separate claims, and each has bitten a frame in this mod before:
	#
	# 1. THE WEAPON REACHES A MOUNT. equip_system appends the Kit to loadout.equipped_kits
	#    (loadout_core.gd:338-340) and full_repair's regenerate_derived_gear distributes it into the
	#    mounts; get_all_weapons() reads ONLY integrated weapons plus mounts (loadout_core.gd:521-525).
	#    The Primrose has Main/Main/Heavy and a SUPERHEAVY drill needs the Heavy mount plus a Main to
	#    brace - so if the three-mount block were wrong, the drill would equip and be invisible to
	#    UnitRelation.get_weapons_that_can_overwatch, and Task 5 would fail for a reason that has
	#    nothing to do with Wormhole Grasp.
	# 2. IT IS NOT BASIC. BuffWeaponType.check_if_passive_applies refuses basic gear unless allow_basic
	#    (buff_weapon_type.gd:55), so a weapon handed over any other route would be invisible to Artful
	#    Caress and to Magnetic Weight Redistribution.
	# 3. equip() IS IDEMPOTENT. Every equip call runs SpecFactory.apply_passive_buffs, which runs
	#    full_repair, which sets core.has_core_power = true (unit_printer.gd:76) and re-applies the
	#    frame's passive buffs from scratch. A second call has to be a no-op, or a spec that equips
	#    mid-test silently refunds the core power and resets Effervescent Immunity's counter.
	var game:Gamemaster = PrimroseFixture.create_game(self)
	var primrose:Unit = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)

	var drill:GearCore = PrimroseFixture.equip_superheavy_melee(primrose)
	assert_true(GearCore.is_valid(drill), 'The Superheavy melee weapon equipped.')
	if not GearCore.is_valid(drill): return
	var mounted_ids:Array[StringName] = []
	for gear:GearCore in primrose.core.loadout.get_all_weapons(): mounted_ids.append(gear.kit.compcon_id)
	assert_has(mounted_ids, PrimroseFixture.SUPERHEAVY_MELEE,
		'And it reached a mount, so every weapon list in the engine can see it.')
	assert_false(primrose.core.loadout.is_gear_basic(drill),
		'And it is NOT basic gear, so weapon-type buffs can apply to it.')

	var again:GearCore = PrimroseFixture.equip_superheavy_melee(primrose)
	assert_eq(again.persistent_id, drill.persistent_id,
		'equip() is idempotent: a second call hands back the same gear and re-equips nothing.')

	var action = drill.get_solo_action()
	assert_true(action is ActionAttackWeapon, 'fixture: the drill action is a weapon attack.')
	if action is not ActionAttackWeapon: return
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.SUPERHEAVY, 'SUPERHEAVY, as Task 5 needs.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'and MELEE, as Task 2 needs.')
	assert_eq(action.threat, 1, 'with the printed threat 1 that Task 3 adds one to.')

func test_the_fixture_can_land_a_hit_a_miss_and_a_crit():
	# THE VACUITY GUARD FOR EVERY LATER TASK. Task 2 reads "did a crit fire the trait", Task 4 reads
	# "did a MISS raise evasion", Task 5 reads "was the damage halved" - and all three are worthless if
	# the dice helpers do not actually produce what they claim. Checked here, once, against the plain
	# vanilla rifle so no trait is in the way.
	#
	# attack_roll.gd:73 computes crit = (total_roll >= 20) and hit and can_crit, where total_roll is the
	# cheated d20 plus the (possibly negative) accuracy die - which is why cheat_a_crit queues 30 and
	# not 20.
	#
	# CORRECTED AT IMPLEMENTATION (2026-09-19): the brief's draft fired MAIN_RIFLE without equipping it
	# first. SpecFactory.create_unit_core hands every spec unit a bare Frame.create_dummy() with no
	# gear, and create_primrose() does not equip anything either - so mw_assault_rifle is never on the
	# unit and SpecFactory.use_solo dies on get_solo_action in base 'Nil'. test_maidens_blush_frame.gd's
	# own equivalent guard (:374-375) calls equip_melee/equip_ranged first for the same reason; this
	# test needs the same equip_main_rifle() call before it can fire.
	#
	# CORRECTED AT IMPLEMENTATION (2026-09-19), second bug: the brief's draft also fired the SAME
	# weapon twice in the SAME open turn. Action.get_per_turn_soft_limit (action.gd:161-163) caps any
	# non-free action at 1 use per turn ("no repeat actions unless you overcharge"), so the second
	# use_solo call aborted at event_gear_activate's check_specific_context with no damage dealt at
	# all - the log showed "ABORT event_gear_activate ... specific: invalid", not a genuine miss.
	# test_rapid_stabilization_jets.gd's test_the_next_turns_move_closes_the_window_again (:148-155)
	# is the mod's own precedent for end_turn() then start_turn() on the SAME unit inside one spec to
	# reset exactly this per-turn tracking; PrimroseFixture.attack()'s open_turn() only starts a turn
	# if one is not already running (fitzgerald_fixture.gd:125), so an explicit end_turn is required
	# between the two shots.
	var game:Gamemaster = PrimroseFixture.create_game(self)
	var primrose:Unit = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	var target:Unit = PrimroseFixture.create_dummy(game, TARGET_TILE, 10)
	PrimroseFixture.equip_main_rifle(primrose)

	PrimroseFixture.cheat_a_miss()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.MAIN_RIFLE, target)
	# The assault rifle is Reliable 2, so a miss still deals 2. That is the floor every later "nothing
	# happened" assertion in this mod measures against when the rifle is the vehicle.
	assert_eq(target.current_damage(), 2, 'A cheated miss deals only the rifle\'s Reliable 2.')

	await SpecFactory.end_turn(game, primrose)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.MAIN_RIFLE, target)
	assert_gt(target.current_damage(), 2, 'A cheated hit deals more than the reliable floor.')
