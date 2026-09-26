# The SHAPE of an integrated weapon, for every frame in this mod that has one.
#
# WHY THIS FILE EXISTS, AND WHY IT IS NOT THE RALEIGH'S SHAPE. Vanilla puts an integrated weapon ON
# the core-power Kit: `content/frames/ipsn/mf_raleigh/cp_m35_mjolnir_cannon/cp_m35_mjolnir_cannon.tres`
# is ONE `is_trait` Kit holding the weapon's attack, the core power and its siblings. A 2026-09-16
# author directive scheduled all three of our frames to be reworked into that shape. It was REVERSED
# on 2026-09-17 after measurement, and this file is the guard that keeps the decision from drifting
# back by accident.
#
# The measurement, from vanilla's own `assets/lcp_data/frames.json` joined to `weapons.json`: in all
# FOUR vanilla frames whose core system carries an integrated weapon, `core_system.name` and the
# weapon's name are the same hardware -
#
#     LANCASTER  Latch Drone                 / Supercharger      / Latch Drone
#     RALEIGH    M35 Mjolnir cannon          / Thunder God       / M35 Mjolnir
#     BARBAROSSA Apocalypse Rail             / Charge Rail       / Apocalypse Rail
#     SHERMAN    Zone-Focus Mk IV SOLIDCORE  / COREBURN Protocol / ZF4 SOLIDCORE
#
# - so vanilla has TWO names to place and one Kit to place them on, and the CORE POWER is the third
# name, which lives as an action. Nothing is lost and the Raleigh never faces a choice.
#
# Bel's cards name THREE things (`the-sixth-voice_2.170.51.lcp`): Broadside / MORE BLACK POWDER /
# Bizarre Cannon, Siege Engine / GATHER ROUND / Diversion Rail, QUIETUS MACHINES / Fungal Network /
# PFP// "PSYCHOPOMP" Fold Pike. One Kit titles exactly one box - `weapon_mount_item.gd:101` for the
# integrated mount, `trait_list_item.gd:28` for the CORE SYSTEM box, and neither shows an action row
# at rest - so merging would cost one of Bel's three names its place on the visible sheet. Two Kits
# is the only shape that shows both. Full reasoning:
# `D:\DEV\lancer-tactics-claude\specs\2026-09-17-integrated-weapon-consistency-design.md`.
#
# WHAT THIS FILE ASSERTS, AND HOW IT DIVIDES FROM ITS SIBLING. `test_integrated_weapon_names.gd`
# pins what the player READS - the two box titles per frame, and that the core Kit carries no weapon.
# This file pins the STRUCTURE that produces it, which that file cannot see: that the two Kits are
# filed together, that the weapon is a separate `is_trait` `mw_` Kit, that the core keeps a `cp_` id,
# and that the frame lists both as traits. Frame 5 (the Maiden's Blush) is the reason it exists -
# the convention has to outlive the session that set it.
#
# THE CO-LOCATION ASSERT WAS RED FIRST. Until 2026-09-17 the Myconid filed its pike in a sibling
# folder - `mf_myconid/` + `mw_psychopomp_fold_pike/`, spelled in two pieces here so a future
# path-rewrite sweep cannot silently retarget this sentence the way one already did - while the
# other two filed theirs beside the core-power Kit. That assert is the one that caught it.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec

extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const SixSkyFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')

## ONE create_game CALL PER TEST, FIRST LINE, and no before_each - the same rule as
## test_integrated_weapon_names.gd, and for the same reason: the fixtures share ONE Gamemaster at
## the tree root and RESET it per call, so a second call would reset the instance mid-test.

## The two Kits an integrated-weapon frame carries, as [core Kit, weapon Kit].
##
## Returns [] having already failed, so every caller bails on empty rather than dereferencing null.
func core_and_weapon_kits(unit:Unit, core_id:StringName, weapon_id:StringName) -> Array:
	var core:GearCore = unit.get_gear(core_id)
	var weapon:GearCore = unit.get_gear(weapon_id)
	assert_true(GearCore.is_valid(core), '%s is equipped.' % core_id)
	assert_true(GearCore.is_valid(weapon), '%s is equipped.' % weapon_id)
	if not GearCore.is_valid(core) or not GearCore.is_valid(weapon): return []
	return [core.kit, weapon.kit]

## Every structural clause, for one frame. Each assert carries the frame id so a failure in the
## shared helper still names which frame broke.
func assert_integrated_weapon_shape(unit:Unit, core_id:StringName, weapon_id:StringName) -> void:
	var kits:Array = core_and_weapon_kits(unit, core_id, weapon_id)
	if kits.is_empty(): return
	var core_kit:Kit = kits[0]
	var weapon_kit:Kit = kits[1]

	# THE CLAUSE THAT WAS RED. A resource's index is decided by its filename prefix and not its
	# folder (ContentLibrary.get_compcon_id_from_path), so this is organisation rather than
	# behaviour - which is exactly why nothing else would ever catch it drifting.
	assert_eq(
		weapon_kit.resource_path.get_base_dir(),
		core_kit.resource_path.get_base_dir(),
		'%s is filed in the same folder as %s, as vanilla files the Raleigh and as the other frames here do.' % [weapon_id, core_id])

	# TWO KITS, NOT ONE. The whole ruling in one assert: merging them would cost one of Bel's three
	# names its box title.
	assert_ne(weapon_kit.compcon_id, core_kit.compcon_id,
		'%s and %s are separate Kits, so each can title its own box.' % [weapon_id, core_id])

	# The weapon half: an mw_ Kit, and a trait so it costs no SP and cannot be unequipped.
	assert_true(String(weapon_kit.compcon_id).begins_with('mw_'),
		'%s is an mw_ Kit, vanilla-s own shape for a standalone integrated weapon (mw_fuel_rod_gun.tres).' % weapon_id)
	assert_true(weapon_kit.is_trait, '%s is a frame trait, not equippable gear.' % weapon_id)
	assert_true(weapon_kit.has_weapon(), '%s actually carries the weapon.' % weapon_id)

	# The core half. THE cp_ PREFIX IS LOAD-BEARING: Kit.is_core_power() is literally
	# compcon_id.begins_with('cp_') (kit.gd:66), and it is what routes the Kit to the CORE SYSTEM box
	# (mech_section.gd:181) rather than FRAME TRAITS, and what the license catalog and the tooltip
	# type read. Renaming the id out of cp_ would silently demote the core system.
	assert_true(core_kit.is_core_power(),
		'%s keeps a cp_ id, which is the whole test Kit.is_core_power() applies.' % core_id)

	# Both are the FRAME's, not loadout choices - this is what puts them on the sheet at all.
	assert_true(unit.core.frame.traits.has(core_kit), '%s is listed in the frame traits.' % core_id)
	assert_true(unit.core.frame.traits.has(weapon_kit), '%s is listed in the frame traits.' % weapon_id)

# ---------------------------------------------------------------- Myconid

func test_the_myconids_pike_is_shaped_like_the_other_frames() -> void:
	var game:Gamemaster = MyconidFixture.create_game(self)
	var unit:Unit = MyconidFixture.create_myconid(game, Vector2i(8, 8))

	assert_integrated_weapon_shape(unit, &'cp_quietus_machines', &'mw_psychopomp_fold_pike')

# ---------------------------------------------------------------- Subutai

func test_the_subutais_rail_is_shaped_like_the_other_frames() -> void:
	var game:Gamemaster = SubutaiFixture.create_game(self)
	var unit:Unit = SubutaiFixture.create_subutai(game, Vector2i(8, 8))

	assert_integrated_weapon_shape(unit, &'cp_siege_engine', &'mw_diversion_rail')

# ---------------------------------------------------------------- Fitzgerald

func test_the_fitzgeralds_cannon_is_shaped_like_the_other_frames() -> void:
	var game:Gamemaster = FitzgeraldFixture.create_game(self)
	var unit:Unit = FitzgeraldFixture.create_fitzgerald(game, Vector2i(7, 4))

	assert_integrated_weapon_shape(unit, &'cp_broadside', &'mw_bizarre_cannon')

# ---------------------------------------------------------------- Six Sky

func test_the_six_skys_bow_is_shaped_like_the_other_frames() -> void:
	var game:Gamemaster = SixSkyFixture.create_game(self)
	var unit:Unit = SixSkyFixture.create_six_sky(game, Vector2i(8, 4))

	assert_integrated_weapon_shape(unit, &'cp_ors_daykeeper_cycler_bow', &'mw_daykeeper_cycler_bow')
