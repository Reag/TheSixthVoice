# The Leoleth (HA) - SP1 Task 1, with the trait list pinned in Task 13.
#
# Reads the frame and the licence off ContentLibrary rather than off disk, so this proves the
# resources were INDEXED, not merely written: a frame whose filename prefix or resource group is
# wrong is silently filed somewhere else and vanishes from get_mech_frame with no error.
#
# A FULL LICENCE, NOT AN ALT. Like the Fitzgerald, the Primrose and the Sluagh - and unlike the other
# five frames in this mod - the Leoleth ships its own li_leoleth.tres rather than extending a vanilla
# licence, so there is no .tres_ext.gd, no mod_main.EXTENDED_RESOURCES entry and no
# test_alt_frames.gd row.
#
# Numbers come from the notes repo's specs/sixth-voice/09-leoleth.md Stats table, which is generated
# from the LCP. Neither the sheet nor its generator lives in this repo. A red here means the .tres
# drifted from the card, OR that the sheet was regenerated - check the sheet's git history (in the
# lancer-tactics-claude repo) before touching the resource.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_leoleth_frame.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const FRAME_ID := &'mf_leoleth'
const LICENSE_ID := &'li_leoleth'
## The vanilla HA frame whose colour block this one clones until SP5 supplies art.
const ISKANDER_ID := &'mf_iskander'

## Read THIS MOD'S OWN compiled artifact, not the global tr(), so a passing display-text test can be
## attributed to this mod rather than to a sibling Reag-* mod loaded in the same testkit run. Same
## pattern as test_content_integrity.gd, test_sluagh_frame.gd and test_primrose_frame.gd.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The sheet's table (specs/sixth-voice/09-leoleth.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
##
## SIXTEEN FIELDS, not the card's fourteen columns: Statblock carries `reactions` and `activations`
## too (statblock.gd:31, :34), and every frame in this mod sets both to 1.
const SHEET_STATS := {
	size = 1, structure = 4, stress = 4, health = 8, armor = 1, evasion = 10, edef = 6,
	speed = 4, heat = 7, save_target = 10, sensor_range = 10, tech_attack = -2, repairs = 3,
	systems_points = 7, reactions = 1, activations = 1,
}

const LEOLETH_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(5, 6)
const SHOOTER_TILE := Vector2i(8, 6)

## The rifle is Reliable 2, and AttackUtil floors the TOTAL at reliable on every roll, hit or miss
## (attack_util.gd:143-147). A damage die of 3 is the smallest that keeps a hit and a miss apart.
const DAMAGE_DIE := 3
const RELIABLE := 2

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
	# is_size_half is a separate flag from size (statblock.gd:6), and the Fitzgerald DOES set it, so a
	# copy from that file is the natural mistake. A size-1 frame that also set it would occupy one tile
	# while reporting height 0, and Decimate's Blast 1 - measured tile by tile in Task 7 - would sit on
	# the wrong geometry.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Leoleth is a full size 1, not size 1/2.')

func test_the_mounts_are_flex_then_heavy():
	# Sheet line 22: "Mounts: Flex, Heavy" - ruling 21. ORDER matters: the mech sheet draws mounts in
	# array order, and check_content.py compares the wiring order against the LCP as an ordered
	# sequence rather than as a set (check_content.py:133-139).
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids, ['mount_flex.tres', 'mount_heavy.tres'], 'Flex then Heavy - the sheet.')

func test_the_role_is_striker_with_no_secondary():
	# Sheet line 6: "Roles: Striker" - one role. Lancer.SQUAD_ROLE is
	# { NONE, STRIKER, DEFENDER, CONTROLLER, ARTILLERY, SUPPORT } (lancer.gd:181), so STRIKER is 1 and
	# NONE is 0. frame.gd:81-82 declares both fields and role_secondary DEFAULTS to NONE, so the .tres
	# writes only role_primary - this assertion is what proves the default is really what ships.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.STRIKER, 'Primary role STRIKER.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.NONE, 'No secondary role.')

func test_the_frame_carries_its_four_traits_in_sheet_order():
	# WRITTEN LAST, because the array is appended to in Tasks 2, 3, 4 and 5 and a pin written earlier
	# would be a moving target. ORDER is asserted, not membership: the mech sheet draws traits in
	# array order, and the sheet (specs/sixth-voice/09-leoleth.md) lists Toe To Toe, the 43 As and
	# Fleet of Foot in that order with the core system last - which is design 1.1's own wording.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, [
		LeolethFixture.TOE_TO_TOE_ID,
		LeolethFixture.AAAA_ID,
		LeolethFixture.FLEET_ID,
		LeolethFixture.CORE_ID,
	] as Array[StringName], 'The four traits, in sheet order, with the core system last.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# THE AUTHOR SUPPLIED THE ART AT THE FRAME CLOSE, 2026-09-22, and this test flipped with it. It
	# used to assert the OPPOSITE - that the frame still wore res/assets/frames/placeholder/
	# mf_placeholder.png - precisely so that the swap would redden one named test and have to be a
	# deliberate edit rather than sliding in unremarked. It did; this is that edit. The Leoleth now
	# asserts what the other eight shipped frames assert.
	#
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary with no error a player
	# would ever see. This is the only thing in the suite that reads mf_leoleth.sprites.
	#
	# CHECKING THE FRAME'S OWN FILENAME, not just "not placeholder" - test_sluagh_frame.gd's,
	# test_vauban_frame.gd's and test_primrose_frame.gd's reasoning: several of this mod's frames are
	# 80x80 with no "placeholder" in their paths, so a copy-paste from a SIBLING frame would pass the
	# weaker check on its own. Both halves are asserted.
	#
	# 80x80, not the 160x160 sibling: the mod ships mf_placeholder.png (80x80, size 1) and
	# mf_placeholder_160.png (160x160, for the size-2 Myconid), and pointing a size-1 frame at the
	# larger one renders it at double scale on the board.
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
	assert_true(sprite.resource_path.ends_with('/mf_leoleth.png'),
		'The frame wears its OWN sprite - not a sibling frame\'s, and not the stand-in.')

func test_the_colour_scheme_is_derived_from_the_frames_own_art():
	# RE-DERIVED AT THE FRAME CLOSE from the art the author supplied, re-running the Vauban's SP5
	# ruling exactly as the Sluagh did. This test used to assert the Iskander's HA block, which SP1
	# cloned as a stand-in because there was no art to count (the Maiden's Blush shape); the three
	# base colours are now the sprite's own, so the Iskander's VALUES are no longer ours and those
	# cross-assertions are gone with them.
	#
	# LITERALS, NOT A RELATIONSHIP - the Vauban's, the Primrose's and the Sluagh's shape.
	# mf_leoleth.png (80x80, 1,618 opaque pixels) has ZERO channel-encoded pixels under the shader's
	# own literal test, so this scheme cannot repaint the token at all and is INERT. It is pinned
	# anyway, because the day channel-encoded art replaces this sprite these become the frame's real
	# palette, and a silent drift between the .tres and the art it was counted from would go unseen.
	# The three are the sprite's most-common literal fill colours (census excluding the pure-black
	# linework), most-used first, per the Iskander's own slot convention.
	#
	# THE TONERAMP CROSS-CHECK SURVIVES. palette_2 is still the Iskander's own slot and ramp - the
	# census speaks only to the base colours - so the live Iskander is still asserted on that one
	# property: if only ours fails we drifted, if only theirs fails a modkit update restyled HA.
	#
	# NOTHING IS ASSERTED ABOUT palette_1 OR palette_3. ColorScheme declares every palette slot
	# `@export var palette_N:Texture2D = DEFAULT_TONERAMP` (color_scheme.gd:59-62), so a sub-resource
	# that never sets one reads back the standard toneramp and never null - the Sluagh's Task 1 lost a
	# run to an assert_null on exactly that.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	var ours:ColorScheme = frame.default_color_scheme
	assert_not_null(ours, 'The Leoleth carries a default colour scheme.')
	if ours == null: return
	assert_eq(ours.palette_2.resource_path, 'res://assets/palettes/toneramps/tone_highcontrast.png',
		'palette_2 is the high-contrast toneramp, the Iskander\'s own slot and ramp.')
	assert_eq(ours.base_0, Color(0.32156863, 0.29803922, 0.30196078, 1),
		'base_0 is the sprite\'s gunmetal grey-brown (82,76,77 - 252px).')
	assert_eq(ours.base_1, Color(0.47058824, 0.50588235, 0.51764706, 1),
		'base_1 is the sprite\'s light steel grey (120,129,132 - 116px).')
	assert_eq(ours.base_2, Color(0.21960784, 0.28235294, 0.35294118, 1),
		'base_2 is the sprite\'s slate blue-grey (56,72,90 - 75px).')

	var iskander:Frame = ContentLibrary.get_mech_frame(ISKANDER_ID)
	assert_not_null(iskander, 'mf_iskander loads.')
	if iskander == null or iskander.default_color_scheme == null: return
	var theirs:ColorScheme = iskander.default_color_scheme
	assert_eq(theirs.palette_2.resource_path, ours.palette_2.resource_path,
		'The Iskander still wears the same toneramp we kept.')

func test_the_colour_scheme_literals_are_still_the_arts_own_census():
	# THE ASSERTION THE TEST ABOVE WAS MISSING. That one reads three literals off the .tres and never
	# opens the sprite, so swapping in different art leaves it green while its own comment about
	# silent drift becomes false. This one re-derives the census from the shipped texture, so the
	# .tres and the art cannot part company unnoticed - which matters because the day channel-encoded
	# art lands, these three stop being inert and become the frame's real palette.
	#
	# SAFE TO READ IN-ENGINE. mf_leoleth.png.import sets compress/mode=0 (lossless), so get_image()
	# hands back the source pixels exactly; a VRAM-compressed texture would not, and this test would
	# have to read the PNG off disk instead.
	#
	# THE CENSUS RULE, from the Vauban's SP5 ruling as the Sluagh re-ran it: most-common literal fill
	# colours among pixels at alpha >= 250, EXCLUDING pure black, which is linework rather than fill.
	# Compared as 8-bit ints rather than Colors - Image.get_pixel returns v/255 floats, and exact
	# float equality on those is a coin toss.
	var frame:Frame = _frame()
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	if sprite == null: return
	var image:Image = sprite.get_image()
	assert_not_null(image, 'The sprite hands back an Image to count.')
	if image == null: return

	var counts:Dictionary = {}
	var opaque:int = 0
	for y:int in image.get_height():
		for x:int in image.get_width():
			var px:Color = image.get_pixel(x, y)
			if px.a < 0.98: continue # alpha >= 250/255
			opaque += 1
			var packed:int = (roundi(px.r * 255.0) << 16) | (roundi(px.g * 255.0) << 8) | roundi(px.b * 255.0)
			if packed == 0: continue # pure-black linework is not a fill colour
			counts[packed] = counts.get(packed, 0) + 1
	assert_eq(opaque, 1618, 'The sprite still has the 1,618 opaque pixels the census was taken over.')

	var ranked:Array = counts.keys()
	ranked.sort_custom(func(a:int, b:int) -> bool: return counts[a] > counts[b])
	assert_true(ranked.size() >= 3, 'The census found at least three fill colours.')
	if ranked.size() < 3: return

	var ours:ColorScheme = frame.default_color_scheme
	if ours == null: return
	var written:Array[Color] = [ours.base_0, ours.base_1, ours.base_2]
	var labels:Array[String] = ['base_0', 'base_1', 'base_2']
	for i:int in 3:
		var packed:int = (roundi(written[i].r * 255.0) << 16) | (roundi(written[i].g * 255.0) << 8) | roundi(written[i].b * 255.0)
		assert_eq(packed, ranked[i],
			'%s is still the sprite\'s #%d most-used fill colour (#%06x in the art, #%06x on the .tres).'
				% [labels[i], i + 1, ranked[i], packed])

func test_the_name_and_flavour_and_tagline_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green, and then
	# end to end through tr(). A tr() that falls through to the raw key is the signature of a missing
	# CSV row OR of a stale compiled .translation; either way the card is blank in game.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['frame.mf_leoleth.name', 'frame.mf_leoleth.flavor', 'frame.mf_leoleth.flavor.short']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_leoleth.name'), 'Leoleth', 'The frame is named Leoleth.')
	assert_eq(X.tr('frame.mf_leoleth.flavor.short'), 'Kinetic Rage',
		'The tagline the author picked (ruling 1) - the one invented string in SP1.')

func test_the_flavour_is_the_lcp_paragraph_entire():
	# THE WHOLE PARAGRAPH, HEAD AND TAIL, rather than a substring in the middle: the clause most likely
	# to be lost is the last one, to a CSV quoting mistake that truncates at a comma. The sheet
	# (specs/sixth-voice/09-leoleth.md, the Flavour block) renders it as one line, and the LCP's own
	# description carries no HTML and no backslashes at all - only commas, apostrophes and full stops
	# (measured 2026-09-21) - so the only thing the CSV needs is RFC-4180 quoting for the commas.
	var flavour:String = X.tr('frame.mf_leoleth.flavor')
	assert_true(flavour.begins_with('Originally meant to act as Harrison Armory\'s primary skirmisher unit,'),
		'The flavour opens on the LCP\'s own first clause.')
	assert_true(flavour.ends_with('useful for variable engagement zones and complex environments.'),
		'And ends on its last, with nothing after it.')
	assert_eq(flavour.length(), 1083, 'The paragraph is the LCP\'s, entire: 1083 characters.')

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
	assert_eq(rank_2_frames, [FRAME_ID] as Array, 'Rank 2 grants exactly the Leoleth, once.')
	assert_true(license.rank_1.granted_frames.is_empty(), 'rank_1 grants no frame.')
	assert_true(license.rank_3.granted_frames.is_empty(), 'rank_3 grants no frame.')

func test_the_licence_grants_exactly_the_rank_one_and_two_gear_and_nothing_else_yet():
	# SP2 filled rank 1 with the two rank-I items, in sheet order. SP3 fills rank 2 (Thermal Death
	# Axe, ZIP Type Engine) and SP4 rank 3 (the Joermungandr-class NHP, GreenLight Projection).
	# Asserted as EXACT lists rather than "contains ours": the natural mistake when copying
	# li_sluagh.tres is to carry over ITS granted_gear entries, and those are ids this mod really
	# does ship. The two empty lines below each go red exactly once, in the sub-project that fills
	# that rank.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	if license.rank_1 == null or license.rank_2 == null or license.rank_3 == null: return
	var rank_1:Array = license.rank_1.granted_gear.map(
		func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_1, [LeolethFixture.THUNDER_SWORD_ID, LeolethFixture.WING_ID] as Array,
		'Rank 1 grants exactly the Thunder Sword and W.I.N.G, once each, in sheet order.')
	var rank_2:Array = license.rank_2.granted_gear.map(
		func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_2, [LeolethFixture.TDA_ID, LeolethFixture.ZIP_ID] as Array,
		'Rank 2 grants exactly the Thermal Death Axe and the ZIP Type Engine, once each, in sheet order.')
	var rank_3:Array = license.rank_3.granted_gear.map(
		func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_3, [LeolethFixture.JORMUNGANDR_ID, LeolethFixture.GREENLIGHT_ID] as Array,
		'Rank 3 grants exactly the Jörmungandr-Class NHP and GreenLight Projection, once each, in '
		+ 'sheet order.')

func test_the_licence_names_itself_after_the_frame():
	# THERE IS NO LICENCE NAME ROW, AND THAT IS THE ENGINE'S DESIGN rather than an omission.
	# UnlockTree.license_name (unlock_tree.gd:28-32) reads rank_2.granted_frames.FRONT() and translates
	# frame.<id>.name - so the licence is named "Leoleth" off the frame's own row, and writing a
	# gear.li_leoleth.name row would do nothing at all. li_sluagh.tres has none either.
	#
	# This also means an empty rank_2 renames the licence "???" (:32), which the exact-list assertion
	# above is what prevents.
	var license := _license()
	assert_not_null(license, 'fixture: the licence loads.')
	if license == null: return
	assert_eq(license.license_name(), X.tr('frame.mf_leoleth.name'),
		'The licence names itself after its granted frame, translated.')
	assert_ne(license.license_name(), '???', 'And not the empty-rank fallback.')

func test_a_pilot_with_the_licence_at_rank_two_can_pick_the_leoleth():
	# THE PLAYER-FACING HALF OF THE LICENCE. The tests above read the UnlockTree directly and
	# test_a_unit_can_actually_wear_the_frame assigns unit.core.frame by hand; neither touches the
	# pilot path, which is the only way a player ever gets this frame. The Subutai lost this case to
	# its own plan twice before the frame close put it back.
	#
	# PilotCore.get_available_frames (pilot_core.gd:390-397) is two halves: every GMS licence at rank 3
	# regardless of pilot level, and get_unlocked_licensed_frames, which walks the pilot's OWN
	# RankProgress rows. li_leoleth is not GMS, so only the second half can ever reach us.
	var pilot := PilotCore.create()
	pilot.set_license_to_rank(LICENSE_ID, 2)
	assert_eq(pilot.get_license_rank(LICENSE_ID), 2, 'The pilot holds li_leoleth at rank 2.')
	var ids:Array[StringName] = []
	for frame:Frame in pilot.get_available_frames(): ids.append(frame.compcon_id)
	assert_has(ids, FRAME_ID, 'A Leoleth 2 pilot is offered the Leoleth.')

	# The rank actually gates it. get_all_unlocked_ranks_for_rank is cumulative (unlock_tree.gd:34-39),
	# so a licence that granted the frame at rank_1 by mistake would still show up at rank 2 and the
	# assertion above would stay green - this is the half that notices.
	var rank_1_pilot := PilotCore.create()
	rank_1_pilot.set_license_to_rank(LICENSE_ID, 1)
	var rank_1_ids:Array[StringName] = []
	for frame:Frame in rank_1_pilot.get_available_frames(): rank_1_ids.append(frame.compcon_id)
	assert_does_not_have(rank_1_ids, FRAME_ID, 'A Leoleth 1 pilot is not offered it yet.')

# ---------------------------------------------------------------- the live unit and the fixture

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = LeolethFixture.create_game(self)
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	assert_true(Unit.is_valid(leoleth), 'A unit was created.')
	if not Unit.is_valid(leoleth): return
	assert_eq(leoleth.core.frame.compcon_id, FRAME_ID, 'It is wearing the Leoleth frame.')
	assert_eq(leoleth.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	# Through the ACCESSORS, not core.current: the engine never writes evasion or save target into the
	# current block (only health/armor/heat/speed/structure/stress/repairs are synced).
	# Unit.get_evasion is what Swift moves in Task 8 and Unit.get_speed_max is what Toe To Toe compares
	# against in Task 2, so pinning their BASE values here is what makes "12 after the chip" and
	# "4 unspent" mean something there.
	assert_eq(leoleth.get_evasion(), SHEET_STATS.evasion, 'And the sheet evasion, read the way Task 8 moves it.')
	assert_eq(leoleth.get_speed_max(), SHEET_STATS.speed, 'And the sheet speed, read the way Task 2 compares it.')
	assert_eq(leoleth.get_save_target(), SHEET_STATS.save_target, 'And the sheet save target.')
	assert_eq(leoleth.get_sensor_range(), SHEET_STATS.sensor_range, 'And the sheet Sensors, which bounds Combust.')
	assert_eq(leoleth.occupied_tiles().size(), 1, 'A size-1 unit occupies one tile.')
	assert_true(leoleth.is_player_controlled(),
		'And it is PLAYER controlled - every hostile/ally relation in the ability specs depends on it, '
		+ 'and CommonActionUtil.confirm_use returns true WITHOUT asking for a non-player unit.')

func test_the_fixture_arms_a_shooter_and_a_swordsman_the_way_its_callers_assume():
	# A FIXTURE SELF-CHECK, and it is the only thing that exercises equip() before Tasks 2-13 lean on
	# it. Four separate claims, each of which has bitten a frame in this mod before:
	#
	# 1. THE WEAPON REACHES A MOUNT. equip_system appends the Kit to loadout.equipped_kits and
	#    full_repair's regenerate_derived_gear distributes it into the mounts; get_all_weapons() reads
	#    ONLY integrated weapons plus mounts (loadout_core.gd:521-525) - which is the exact list Toe To
	#    Toe walks in Task 2, so a weapon that never reached a mount would make that trait dead.
	# 2. IT IS NOT BASIC. The 43 As sets allow_basic (Task 3) precisely so basics DO get the penalty;
	#    an equipped rifle being non-basic is what makes that a test of the flag rather than of luck.
	# 3. THE MELEE KIT REALLY IS MELEE AND QUICK. Toe To Toe's whole eligibility test is
	#    weapon_type == MELEE and get_action_type == QUICK (action_attack_weapon.gd:87-91 returns FULL
	#    for a SUPERHEAVY), so this is the fixture's half of that claim.
	# 4. equip() IS IDEMPOTENT. Every equip call runs SpecFactory.apply_passive_buffs, which runs
	#    full_repair, which sets core.has_core_power = true (unit_printer.gd:76) and re-applies the
	#    frame's passive buffs from scratch. A second call has to be a no-op, or a spec that equips
	#    mid-test silently refunds the core power the RAGE protocol spends.
	var game:Gamemaster = LeolethFixture.create_game(self)
	var hostile:Unit = LeolethFixture.create_hostile(game, TARGET_TILE)

	var rifle:GearCore = LeolethFixture.arm_rifle(hostile)
	assert_true(GearCore.is_valid(rifle), 'The rifle equipped.')
	if not GearCore.is_valid(rifle): return
	var mounted_ids:Array[StringName] = []
	for gear:GearCore in hostile.core.loadout.get_all_weapons(): mounted_ids.append(gear.kit.compcon_id)
	assert_has(mounted_ids, LeolethFixture.MAIN_RIFLE,
		'And it reached a mount, so every weapon list in the engine can see it.')
	assert_false(hostile.core.loadout.is_gear_basic(rifle),
		'And it is NOT basic gear, so Task 3\'s allow_basic case tests the flag.')

	var blade:GearCore = LeolethFixture.arm_melee(hostile)
	assert_true(GearCore.is_valid(blade), 'The tactical melee weapon equipped.')
	if not GearCore.is_valid(blade): return
	var swing:ActionAttackWeapon = blade.kit.get_weapon_actions().front()
	assert_not_null(swing, 'It carries an ActionAttackWeapon.')
	if swing == null: return
	assert_eq(swing.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'And that action is MELEE.')
	assert_eq(swing.get_action_type(SpecificAction.create(hostile, blade, swing)), Lancer.ACTION.QUICK,
		'And QUICK, which is the other half of Toe To Toe\'s eligibility test.')

	var again:GearCore = LeolethFixture.arm_rifle(hostile)
	assert_eq(again.persistent_id, rifle.persistent_id,
		'equip() is idempotent: a second call hands back the same gear and re-equips nothing.')

func test_the_fixture_can_land_a_hit_and_a_miss_on_the_leoleth():
	# THE VACUITY GUARD FOR EVERY LATER TASK. Task 5 reads "did the structure hook fire", Task 11 reads
	# "did a hostile roll at -1", Task 12 reads "did a hostile hit cost it 3 energy" - and all of them
	# are worthless if the dice helpers do not produce what they claim. Checked here, once, on a bare
	# Leoleth with no traits yet in the way.
	#
	# THE DAMAGE DIE IS 3, NOT 1, AND THAT IS THE RIFLE: mw_assault_rifle is Reliable 2, and AttackUtil
	# floors the TOTAL at reliable on every roll, hit or miss (attack_util.gd:143-147). A cheated 1
	# lands 2 either way and the two cases stop being distinguishable - the Sluagh's Task 2 measured
	# exactly that.
	#
	# AND IT IS 3 RATHER THAN 6 BECAUSE THIS FRAME HAS 8 HP AND ARMOR 1: two cheated sixes would
	# structure it mid-test and drag a structure-table d6 and a brochure into every assertion after.
	var game:Gamemaster = LeolethFixture.create_game(self)
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	var hostile:Unit = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	LeolethFixture.arm_rifle(hostile)

	LeolethFixture.queue([1, DAMAGE_DIE])
	await LeolethFixture.shoot(game, hostile, leoleth)
	assert_eq(leoleth.current_damage(), RELIABLE - 1,
		'A cheated miss lands the rifle\'s Reliable 2, less the frame\'s armor 1.')

	LeolethFixture.queue([19, DAMAGE_DIE])
	await LeolethFixture.shoot(game, hostile, leoleth)
	assert_gt(leoleth.current_damage(), RELIABLE,
		'A cheated hit deals more than the reliable floor.')
	assert_true(Unit.is_valid(leoleth), 'And the 8 HP frame survived both, because the die is a 3.')
