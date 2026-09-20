# The Sluagh (HORUS) - SP1 Task 1, with the trait list pinned in Task 9.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix or resource group is
# wrong is silently filed somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT. Like the Fitzgerald and the Primrose and unlike the other five frames
# in this mod, the Sluagh ships its own li_sluagh.tres rather than extending a vanilla licence - so
# there is no .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no test_alt_frames.gd row.
#
# Numbers come from the notes repo's specs/sixth-voice/08-sluagh.md Stats table, which is generated
# from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in the
# lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_sluagh_frame.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const FRAME_ID := &'mf_sluagh'
const LICENSE_ID := &'li_sluagh'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run. Same
## pattern as test_content_integrity.gd, test_fitzgerald_frame.gd and test_primrose_frame.gd.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table (specs/sixth-voice/08-sluagh.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
##
## SIXTEEN FIELDS, not the card's fourteen columns: Statblock carries `reactions` and `activations`
## too, and every frame in this mod sets both to 1.
##
## armor IS 0 AND IS LISTED, which is worth one line: 0 is Statblock's own export default
## (statblock.gd:12), so Godot would omit it from a re-saved .tres and the assertion below would
## still pass - frame.stat.get('armor') reads the Resource, not the file. The .tres writes it
## anyway, because a reader of that file should not have to know the default to know the card.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 0, evasion = 10, edef = 10,
	speed = 4, heat = 4, save_target = 10, sensor_range = 10, tech_attack = 1, repairs = 4,
	systems_points = 7, reactions = 1, activations = 1,
}

const SLUAGH_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(5, 6)

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
	# is_size_half is a separate flag from size, and the Fitzgerald DOES set it, so a copy from that
	# file is the natural mistake. A size-1 frame that also set it would occupy one tile while
	# reporting height 0, and every adjacency assertion in this sub-project - three of the four
	# abilities - would quietly measure the wrong geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Sluagh is a full size 1, not size 1/2.')

func test_the_mount_is_a_single_main_aux():
	# Sheet line 22: "Mounts: Main/Aux" - ONE mount, and it is the compound Main/Aux type
	# (content/mounts/mount_main_aux.tres), not a Main and an Aux listed separately. Ruling 24.
	# It is player-visible: the mech sheet draws mounts in array order.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_main_aux.tres'], 'Exactly one Main/Aux mount - the sheet.')

func test_the_roles_are_support_then_defender():
	# Sheet line 6: "Roles: Support, Defender" - and ORDER matters, because role_primary and
	# role_secondary are different fields read by catalog_blurb.gd and opfor_editor_modal.gd, not
	# decorative. Lancer.SQUAD_ROLE is { NONE, STRIKER, DEFENDER, CONTROLLER, ARTILLERY, SUPPORT }
	# (lancer.gd:181), so SUPPORT is 5 and DEFENDER is 2; frame.gd:81-82 declares both fields.
	# This is the mod's first frame with a SECONDARY role at all.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.SUPPORT, 'Primary role SUPPORT.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.DEFENDER, 'Secondary role DEFENDER.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_sluagh.sprites.
	#
	# CHECKING THE FRAME'S OWN FILENAME, not just "not placeholder" - test_vauban_frame.gd's and
	# test_primrose_frame.gd's reasoning: four of this mod's frames are 80x80 with no "placeholder"
	# in their paths, so a copy-paste from a SIBLING frame would pass the weaker check.
	#
	# 80x80, not the 160x160 size-2 shape: the Sluagh is size 1, and pointing a size-1 frame at a
	# 160x160 texture renders it at double scale on the board.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(80, 80), 'A size-1 frame uses an 80x80 sprite.')
	assert_false(sprite.resource_path.contains('placeholder'),
		'And it is the author\'s own art, not the shared stand-in.')
	assert_true(sprite.resource_path.ends_with('/mf_sluagh.png'),
		'The frame wears its OWN sprite - not a sibling frame\'s, and not the stand-in.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# LITERALS, NOT A RELATIONSHIP - the Vauban's and the Primrose's shape. mf_sluagh.png (80x80,
	# 2,875 opaque pixels) carries ZERO channel-encoded pixels against palette_index_r.png's seven
	# red values (measured 2026-09-20, the same test palette_swap_func.gdshaderinc runs), so this
	# scheme is INERT on the token today: whatever it holds, nothing routes through it. Pinned
	# anyway, because the day channel-encoded art replaces this sprite these become the frame's
	# default paint, and an edit made between now and then would land unnoticed.
	#
	# The three are the sprite's own most-common literal fill colours (a plain colour census,
	# excluding the linework's 49px of pure black), most-used first per the Iskander's own slot
	# convention - see the .tres comment for the full counts.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Sluagh carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.base_0, Color(0.44313726, 0.42352942, 0.48235294, 1), 'base_0 is the sprite\'s grey-violet.')
	assert_eq(ours.base_1, Color(0.5529412, 0.42745098, 0.7647059, 1), 'base_1 is the sprite\'s bright violet.')
	assert_eq(ours.base_2, Color(0.20784314, 0.1882353, 0.24705882, 1), 'base_2 is the sprite\'s near-black violet-grey.')
	# NOT asserted null: ColorScheme.palette_1/palette_2 (color_scheme.gd:60-61) are @export vars
	# whose own default is DEFAULT_TONERAMP (tone_standard.png), never null, for any scheme that
	# does not explicitly override them - the same as mf_primrose.tres and mf_vauban.tres, and
	# neither test_primrose_frame.gd nor test_vauban_frame.gd asserts anything about them. The
	# plan's draft assumed an unset palette_1/2 reads null; measured false against the engine on
	# this run (both read the standard toneramp), so this follows the two shipped frames' own
	# precedent and only pins the base colours a plain census can speak to.

func test_the_name_and_flavour_and_tagline_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green, and then
	# end to end through tr(). A tr() that falls through to the raw key is the signature of a missing
	# CSV row OR of a stale compiled .translation; either way the card is blank in game.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_sluagh.name', 'frame.mf_sluagh.flavor', 'frame.mf_sluagh.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_sluagh.name'), 'Sluagh', 'The frame is named Sluagh.')
	assert_eq(X.tr('frame.mf_sluagh.flavor.short'), 'Obsessive Support',
		'The tagline the author picked (ruling 1) - the one invented string in SP1.')

func test_the_flavours_two_literal_backslashes_survived_the_csv_importer():
	# THE ONE ROW IN THIS MOD THAT CONTAINS A BACKSLASH, and it needs FOUR in the CSV to ship TWO.
	#
	# Godot's csv_translation importer c_unescapes every message before it reaches the game -
	# measured 2026-09-20 in an isolated project on 4.7.2: a field of two backslashes comes out as
	# one, a field of four comes out as two. The sheet (specs/sixth-voice/08-sluagh.md, the Flavour
	# block) ends the poem `(not operational) \\ - RA` with two, and the LCP's own description
	# carries two, so the CSV has to carry four.
	#
	# ASSERTED ON THE WHOLE TAIL rather than on a backslash count: the tail is also the cheapest
	# end-to-end check that the entire poem landed rather than a truncation, and it is the clause
	# most likely to be lost to a quoting mistake. The literal below is GDScript-escaped: '\\\\' is
	# two characters.
	#
	# IF THIS FAILS WITH ONE BACKSLASH, the CSV has two where it needs four - it is not a content
	# error. If it fails with four, the importer stopped unescaping and the CSV needs two.
	var flavour:String = X.tr('frame.mf_sluagh.flavor')
	assert_true(flavour.begins_with('"Here I am my beloved'),
		'The flavour opens on the poem\'s own quotation mark.')
	assert_true(flavour.ends_with('(not operational) \\\\ - RA'),
		'And ends with TWO literal backslashes, the attribution, and nothing after it.')
	assert_eq(flavour.count('\\'), 2, 'Exactly two backslashes in the whole row.')

func test_the_frame_carries_its_four_traits_in_sheet_order():
	# APPENDED ONCE PER TASK and pinned here at the close - Task 2 added Wicked Host, Task 3 the
	# Stealing, Task 5 Inexorable Formation, Task 6 CRY OF THE HOSTED DEAD, each a pure APPEND.
	#
	# THIS ASSERTS ORDER, DELIBERATELY, and must not be relaxed to membership. The array order is
	# PLAYER-VISIBLE: catalog_license_focus_spread.gd:31 iterates core.frame.traits in array order to
	# fill the catalog's trait slots (lifting the core power out into its own slot as it goes), and
	# mech_section.gd:109 iterates loadout.get_frame_traits(), which preserves it. The order below is
	# the sheet's - the three traits in the order it prints them, then the core system - and design
	# 1.1 names it explicitly. The Fitzgerald's whole-branch review found its array in
	# task-completion order, which buried the core system; this is the pin that stops the same thing
	# happening here.
	#
	# IT SHOULD NOT GROW. SP2, SP3 and SP4 add GEAR to li_sluagh's ranks, not traits to the frame -
	# a trait is something the mech always has, and every remaining Sluagh ability is licensed
	# equipment. A red here from a later sub-project means a piece of gear was wired as a trait.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var carried:Array = frame.traits.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(carried,
		[&'mt_wicked_host', &'mt_the_stealing_of_the_souls_of_the_dead', &'mt_inexorable_formation',
		 &'cp_cry_of_the_hosted_dead'],
		'The frame carries exactly its three traits and its core system, in the sheet\'s order.')

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
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Sluagh, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_exactly_the_gear_built_so_far():
	# RENAMED AND REWRITTEN, SP2 Task 3 (2026-09-20). It was test_the_licence_grants_no_gear_at_any_
	# rank_yet, and its own comment said each line "goes red exactly once, in the sub-project that
	# fills that rank... that sub-project rewrites this test the way the Primrose's own rewrote it" -
	# which it duly did the moment the Rend Nexus was wired into rank 1 this task (measured: this test
	# was part of the tier-2 run this task's own verification ran, not something its scoped
	# --gut-script=test_rend_nexus.gd run would have caught on its own). Rewriting it now rather than
	# at the end of SP2 keeps the suite at its three deliberate icon reds between tasks, so a
	# genuinely new red is visible instead of hiding in a crowd - the same reasoning
	# test_primrose_frame.gd's own rewrite recorded.
	#
	# UPDATED, SP2 Task 7 (2026-09-20): O' Trickery is now wired into rank 1 alongside the Rend
	# Nexus, exactly as this comment predicted - "When it lands, this line grows to two ids, sorted."
	# Rank I is now the whole of rank I; ranks 2 and 3 still wait on SP3 and SP4.
	#
	# EXACT LISTS, not "contains ours": the natural mistake when copying li_primrose.tres is to carry
	# over ITS granted_gear entries, and those are ids this mod really does ship, so a has-assertion
	# would pass over them.
	#
	# Strings, not StringNames: test_primrose_frame.gd found (and fixed) that Array[StringName].sort()
	# orders by the interned _data pointer, not the text, so a sorted assertion of more than one id
	# must sort String, not StringName, to stay independent of script load order. Built that way here
	# from the start, even with one id before this task, so this file did not have to re-learn that
	# lesson when O' Trickery made it two.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1_ids:Array[String] = []
	for kit:Kit in license.rank_1.granted_gear: rank_1_ids.append(String(kit.compcon_id))
	rank_1_ids.sort()
	assert_eq(rank_1_ids, ['ms_o_trickery', 'mw_rend_nexus'] as Array[String],
		'Rank 1 grants exactly O\' Trickery and the Rend Nexus, sorted.')
	assert_eq(license.rank_2.granted_gear.size(), 0, 'Rank 2 grants no gear yet (SP3 fills it).')
	assert_eq(license.rank_3.granted_gear.size(), 0, 'Rank 3 grants no gear yet (SP4 fills it).')

func test_the_licence_names_itself_after_the_frame():
	# THERE IS NO LICENCE NAME ROW, AND THAT IS THE ENGINE'S DESIGN rather than an omission.
	# UnlockTree.license_name (unlock_tree.gd:28-32) reads rank_2.granted_frames.FRONT() and
	# translates frame.<id>.name - so the licence is named "Sluagh" off the frame's own row, and
	# writing a gear.li_sluagh.name row would do nothing at all. li_primrose.tres has none either.
	#
	# This also means an empty rank_2 renames the licence "???" (:32), which the exact-list assertion
	# above is what prevents.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_sluagh.name'),
		'The licence names itself after its granted frame, translated.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_sluagh():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back.
	#
	# PilotCore.get_available_frames (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3
	# regardless of pilot level, and get_unlocked_licensed_frames, which walks the pilot's OWN
	# RankProgress rows. li_sluagh is not GMS, so only the second half can ever reach us.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_sluagh at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Sluagh 2 pilot is offered the Sluagh.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:34-39),
	# so a licence that granted the frame at rank_1 by mistake would still show up at rank 2 and the
	# assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Sluagh 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	assert_true(Unit.is_valid(sluagh), 'A unit was created.')
	if not Unit.is_valid(sluagh): return
	assert_eq(sluagh.core.frame.compcon_id, FRAME_ID, 'It is wearing the Sluagh frame.')
	assert_eq(sluagh.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or sensor range into
	# the current block (only health/armor/heat/speed/structure/stress/repairs are synced).
	# Unit.get_sensor_range is core.get_sensor_range() + state.stat_bonus.sensor_range (unit.gd:305),
	# which is EXACTLY what Inexorable Formation moves in Task 5 - so pinning its BASE value here is
	# what makes "13 after a grant of 3" mean something there.
	assert_eq(sluagh.get_sensor_range(), SHEET_STATS.sensor_range,
		'It has the sheet Sensors, read the way the engine reads it and the way Task 5 moves it.')
	assert_eq(sluagh.get_evasion(), SHEET_STATS.evasion, 'And the sheet evasion.')
	assert_eq(sluagh.get_save_target(), SHEET_STATS.save_target, 'And the sheet save target.')
	assert_eq(sluagh.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(sluagh.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the ability specs depends on '
		+ 'it, and CommonActionUtil auto-accepts prompts for a non-player unit.')

func test_the_fixture_arms_a_shooter_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK, and it is the only thing that exercises equip() before Tasks 2-9 lean on
	# it. Three separate claims, each of which has bitten a frame in this mod before:
	#
	# 1. THE WEAPON REACHES A MOUNT. equip_system appends the Kit to loadout.equipped_kits and
	#    full_repair's regenerate_derived_gear distributes it into the mounts; get_all_weapons()
	#    reads ONLY integrated weapons plus mounts (loadout_core.gd:521-525).
	# 2. IT IS NOT BASIC. ActionReactionAttacked refuses an attack made with basic gear unless
	#    allow_basic (action_reaction_attacked.gd:113), and both of this frame's reactions DO set it -
	#    so the hostile's rifle being non-basic is what makes the allow_basic cases in Tasks 6 and 8
	#    tests of the flag rather than of the weapon.
	# 3. equip() IS IDEMPOTENT. Every equip call runs SpecFactory.apply_passive_buffs, which runs
	#    full_repair, which sets core.has_core_power = true (unit_printer.gd:76) and re-applies the
	#    frame's passive buffs from scratch. A second call has to be a no-op, or a spec that equips
	#    mid-test silently refunds the core power the Mark spends.
	var game:Gamemaster = SluaghFixture.create_game(self)
	var hostile:Unit = SluaghFixture.create_hostile(game, TARGET_TILE)

	var rifle:GearCore = SluaghFixture.arm_rifle(hostile)
	assert_true(GearCore.is_valid(rifle), 'The rifle equipped.')
	if not GearCore.is_valid(rifle): return
	var mounted_ids:Array[StringName] = []
	for gear:GearCore in hostile.core.loadout.get_all_weapons(): mounted_ids.append(gear.kit.compcon_id)
	assert_has(mounted_ids, SluaghFixture.MAIN_RIFLE,
		'And it reached a mount, so every weapon list in the engine can see it.')
	assert_false(hostile.core.loadout.is_gear_basic(rifle),
		'And it is NOT basic gear, so the allow_basic cases in Tasks 6 and 8 test the flag.')

	var again:GearCore = SluaghFixture.arm_rifle(hostile)
	assert_eq(again.persistent_id, rifle.persistent_id,
		'equip() is idempotent: a second call hands back the same gear and re-equips nothing.')

func test_the_fixture_can_land_a_hit_and_a_miss_on_the_sluagh():
	# THE VACUITY GUARD FOR EVERY LATER TASK. Task 2 reads "did a hostile HIT arm the chip", Task 6
	# reads "did a hostile hit on an ally fire the reaction", Task 8 reads "did a hostile MISS offer
	# the retort" - and all three are worthless if the dice helpers do not produce what they claim.
	# Checked here, once, on a bare Sluagh with no traits yet in the way.
	#
	# THE DAMAGE DIE IS CHEATED TO 1, NOT 6, AND THAT IS THE FRAME: the Sluagh has 8 HP and 0 armor,
	# so two cheated sixes would destroy it mid-spec. queue() takes the whole FIFO explicitly for
	# exactly this reason; cheat_a_hit()/cheat_a_miss() wrap the common case.
	#
	# THE RIFLE IS RELIABLE 2, so a miss still lands 2. That is the floor every later "nothing
	# happened" assertion in this sub-project measures against when the rifle is the vehicle, and it
	# is why a PURE-miss case uses ms_fragment_signal instead (memory
	# lancer-tactics-spec-harness-traps).
	var game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	var hostile:Unit = SluaghFixture.create_hostile(game, TARGET_TILE)
	SluaghFixture.arm_rifle(hostile)

	SluaghFixture.cheat_a_miss()
	await SluaghFixture.shoot(game, hostile, sluagh)
	assert_eq(sluagh.current_damage(), 2, 'A cheated miss deals only the rifle\'s Reliable 2.')

	SluaghFixture.cheat_a_hit()
	await SluaghFixture.shoot(game, hostile, sluagh)
	assert_gt(sluagh.current_damage(), 2, 'A cheated hit deals more than the reliable floor.')
	assert_true(Unit.is_valid(sluagh), 'And the 8 HP frame survived both, because the die is a 1.')
