# The Subutai (HA, Barbarossa alt) - SP1 Task 1, Task 2 and Task 4.
#
# Reads the frame off ContentLibrary rather than off disk, so it proves the resource was INDEXED,
# not merely written: a frame whose filename prefix or resource group is wrong is silently filed
# somewhere else and vanishes from get_mech_frame with no error.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_subutai_frame.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')

const FRAME_ID := &'mf_subutai'
const LICENSE_ID := &'li_barbarossa'

## The sheet's table (specs/sixth-voice/03-subutai.md), in the engine's field names. Transcribed
## once, here, so a typo in the .tres shows up as a number and not as a vague "feels wrong".
const SHEET_STATS := {
	size = 2, structure = 4, stress = 4, health = 8, armor = 1, evasion = 6, edef = 8,
	speed = 3, heat = 7, save_target = 10, sensor_range = 15, tech_attack = 0, repairs = 5,
	systems_points = 6, reactions = 1, activations = 1,
}

func _frame() -> Frame:
	return ContentLibrary.get_mech_frame(FRAME_ID)

func test_the_frame_is_in_the_content_library():
	assert_true(Frame.is_valid(_frame()), 'mf_subutai is in the frames index.')

func test_every_stat_matches_the_sheet():
	var frame:Frame = _frame()
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	assert_not_null(frame.stat, 'mf_subutai carries a statblock.')
	if frame.stat == null: return
	for field:String in SHEET_STATS:
		assert_eq(frame.stat.get(field), SHEET_STATS[field], 'stat.%s' % field)

func test_the_frame_is_not_size_half():
	# is_size_half is a separate flag from size; a size-2 frame that also set it would occupy one
	# tile while reporting 2, and every line and blast test below would quietly measure the wrong
	# geometry.
	var frame:Frame = _frame()
	if frame == null or frame.stat == null: return
	assert_false(frame.stat.is_size_half, 'The Subutai is a full size 2, not size 1/2.')

func test_the_mounts_are_main_and_heavy():
	var frame:Frame = _frame()
	if frame == null: return
	var mount_ids:Array[String] = []
	for mount:MountType in frame.mount_types: mount_ids.append(mount.resource_path.get_file())
	assert_eq(mount_ids.size(), 2, 'Two mounts.')
	assert_has(mount_ids, 'mount_main.tres', 'A Main mount.')
	assert_has(mount_ids, 'mount_heavy.tres', 'A Heavy mount.')

func test_the_roles_are_artillery_then_defender():
	var frame:Frame = _frame()
	if frame == null: return
	assert_eq(frame.role_primary, Lancer.SQUAD_ROLE.ARTILLERY, 'Primary role ARTILLERY.')
	assert_eq(frame.role_secondary, Lancer.SQUAD_ROLE.DEFENDER, 'Secondary role DEFENDER.')

func test_the_frame_has_a_sprite_that_actually_loaded():
	# A .tres pointing at an unimported PNG does not fail loudly: the ext_resource fails, the whole
	# frame resource fails to parse, and the frame drops out of ContentLibrary. This asserts the
	# texture is real AND that it is the size-2 placeholder, not the size-1 one.
	var frame:Frame = _frame()
	if frame == null: return
	assert_false(frame.sprites.is_empty(), 'The frame carries at least one sprite.')
	if frame.sprites.is_empty(): return
	var sprite:Texture2D = frame.sprites[0]
	assert_not_null(sprite, 'The sprite texture loaded.')
	if sprite == null: return
	assert_eq(sprite.get_size(), Vector2(160, 160),
		'A size-2 frame uses the 160x160 placeholder, not the size-1 80x80 one.')

func test_the_frame_has_a_colour_scheme():
	var frame:Frame = _frame()
	if frame == null: return
	assert_not_null(frame.default_color_scheme, 'The frame carries a default colour scheme.')

func test_the_name_and_flavour_resolve():
	# tr() falling through to the raw key is the signature of a missing CSV row OR of a stale
	# compiled .translation artifact; either way the card is blank in game.
	for key:String in ['frame.mf_subutai.name', 'frame.mf_subutai.flavor', 'frame.mf_subutai.flavor.short']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('frame.mf_subutai.name'), 'Subutai', 'The frame is named Subutai.')
	assert_eq(X.tr('frame.mf_subutai.flavor.short'), 'Immovable Object', 'Ruling 12 tagline.')

func test_the_barbarossa_licence_grants_the_subutai_at_rank_two():
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	assert_true(tree is UnlockTree, 'li_barbarossa loads.')
	if tree is not UnlockTree: return
	assert_not_null(tree.rank_2, 'li_barbarossa has a rank 2.')
	if tree.rank_2 == null: return
	var granted:Array[StringName] = []
	for frame:Frame in tree.rank_2.granted_frames: granted.append(frame.compcon_id)
	assert_has(granted, FRAME_ID, 'Rank 2 grants the Subutai.')
	assert_has(granted, &'mf_barbarossa', 'Rank 2 still grants the Barbarossa.')

func test_the_barbarossa_is_still_first_so_the_licence_keeps_its_name():
	# UnlockTree.license_name reads rank_2.granted_frames.FRONT(). Unlike li_gms (which declares no
	# rank_2 at all and so is named '???' whatever we do), li_barbarossa IS named off this array, so
	# inserting instead of appending would rename Harrison's licence after our alt.
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	if tree is not UnlockTree or tree.rank_2 == null or tree.rank_2.granted_frames.is_empty(): return
	assert_eq(tree.rank_2.granted_frames.front().compcon_id, &'mf_barbarossa',
		'The Barbarossa is still the front of rank 2.')
	assert_eq(X.tr(tree.license_name()), X.tr('frame.mf_barbarossa.name'),
		'The licence is still named for the Barbarossa.')

func test_the_extension_is_applied_only_once_however_many_times_it_runs():
	# apply_resource_extensions_directly() stamps APPLIED_META on the instance so a re-activation
	# cannot append the frame twice. A duplicated grant shows in game as the Subutai listed twice in
	# the licence card.
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	if tree is not UnlockTree or tree.rank_2 == null: return
	var count := 0
	for frame:Frame in tree.rank_2.granted_frames:
		if frame.compcon_id == FRAME_ID: count += 1
	assert_eq(count, 1, 'The Subutai is granted exactly once.')

func test_a_unit_can_actually_wear_the_frame():
	var game:Gamemaster = SubutaiFixture.create_game(self)
	var subutai:Unit = SubutaiFixture.create_subutai(game, Vector2i(4, 4))
	assert_true(Unit.is_valid(subutai), 'A unit was created.')
	if not Unit.is_valid(subutai): return
	assert_eq(subutai.core.frame.compcon_id, FRAME_ID, 'It is wearing the Subutai frame.')
	assert_eq(subutai.core.current.health, SHEET_STATS.health, 'It has the sheet HP after a repair.')
	assert_eq(subutai.core.current.armor, SHEET_STATS.armor, 'It has the sheet armor.')
	assert_eq(subutai.occupied_tiles().size(), 4, 'A size-2 unit occupies four tiles.')

## The sheet's trait order. The frame card lists traits in array order, so this is player-visible.
## The two vanilla entries are asserted by identity against ContentLibrary rather than by id, which
## is what proves the frame REUSES them instead of shipping a same-named copy - the author's
## standing directive for alt frames.
const SHEET_TRAITS:Array[StringName] = [
	&'mt_juggernaut_drive', &'mt_reinforced_chassis', &'mt_guardian', &'mt_slow',
]

func test_the_traits_are_the_sheets_four_in_the_sheets_order():
	var frame:Frame = _frame()
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids, SHEET_TRAITS, 'Four traits, in sheet order.')

func test_the_two_vanilla_traits_are_vanillas_own_resources():
	var frame:Frame = _frame()
	if frame == null: return
	var by_id := {}
	for kit:Kit in frame.traits: by_id[kit.compcon_id] = kit
	for vanilla_id:StringName in [&'mt_guardian', &'mt_slow']:
		assert_true(by_id.has(vanilla_id), 'The frame carries %s.' % vanilla_id)
		if not by_id.has(vanilla_id): continue
		assert_eq(by_id[vanilla_id], ContentLibrary.get_kit(vanilla_id),
			'%s is vanillas own resource, not a copy.' % vanilla_id)
