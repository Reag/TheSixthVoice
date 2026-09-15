# The name the character sheet puts on an INTEGRATED WEAPON, for every frame in this mod that has
# one.
#
# WHY THIS FILE EXISTS. Bel's cards name the core SYSTEM and its integrated WEAPON separately - the
# Subutai's core system is SIEGE ENGINE and its weapon is the DIVERSION RAIL; the Fitzgerald's are
# BROADSIDE and the BIZARRE CANNON. The engine cannot express that with one Kit. The character
# sheet builds a virtual integrated mount per `loadout.get_integrated_weapons()` entry
# (`ui/page/character_sheet/mech_section.gd:159-170`) and then titles it from the KIT:
#
#     WeaponName.text = Translate.gear(core.kit.compcon_id, 'name')
#     (ui/page/character_sheet/widgets/weapon_mount_item.gd:101)
#
# - note the commented-out `Translate.action(core.kit, attack, 'name')` beside it, which is the
# road Wickworks did not take. So a Kit that is BOTH the core system and the weapon can only ever
# show one of the two names, and the file that decides which is base-game and off limits.
#
# The fix is structural and is vanilla's own shape for a standalone integrated weapon
# (`content/talents/other/t_nuclear_cavalier/rank_3/mw_fuel_rod_gun.tres`): the weapon gets its OWN
# `mw_` Kit with `is_trait = true`, listed in the frame's traits, while the `cp_` Kit keeps the core
# power. Author-ruled 2026-09-15, for both frames at once.
#
# WHAT THIS FILE ASSERTS, AND WHY IT IS SHAPED LIKE THIS. It re-derives the displayed name the same
# way the two UI files above do - walk `get_integrated_weapons()`, skip the entries the sheet skips
# (`not kit.has_weapon()`, which is how the omnigun and the Avenger silos stay out), and read
# `gear.<kit id>.name`. It deliberately does NOT call into the UI: WeaponMountItem is a scene script
# and instantiating it in a spec would test Godot, not us. The risk that buys is that this file
# tracks a derivation rather than the real widget, so BOTH the source lines above are cited here and
# in the test bodies - if a modkit update changes either, this file keeps passing while the game
# shows something else. That is the known limit of this guard.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')
const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## EACH TEST BUILDS ITS OWN GAME, deliberately, and there is no before_each.
##
## Since 87694e6 the fixtures share ONE Gamemaster at the tree root and RESET it per create_game
## call rather than constructing a fresh one (fitzgerald_fixture.gd; SubutaiFixture.create_game
## delegates to it). A before_each that made a Subutai game, followed by a Fitzgerald test calling
## create_game again, would therefore reset the instance mid-test - harmless here but confusing to
## read, and a trap for whoever adds the next test to this file. One call per test, first line.

## Every integrated weapon the character sheet would draw for this unit, as (kit id, shown name).
##
## Mirrors mech_section.gd:160-161 (walk get_integrated_weapons, skip kits with no weapon) and
## weapon_mount_item.gd:101 (title from Translate.gear(kit id, 'name')).
func shown_integrated_weapons(unit:Unit) -> Array:
	var shown:Array = []
	for gear:GearCore in unit.core.loadout.get_integrated_weapons():
		if not gear.kit.has_weapon(): continue
		shown.append([gear.kit.compcon_id, Translate.gear(gear.kit.compcon_id, 'name')])
	return shown

func names_of(shown:Array) -> Array:
	var names:Array = []
	for row:Array in shown: names.append(row[1])
	return names

# ---------------------------------------------------------------- Subutai

func test_the_subutais_integrated_weapon_is_called_the_diversion_rail() -> void:
	var game:Gamemaster = SubutaiFixture.create_game(self)
	var unit:Unit = SubutaiFixture.create_subutai(game, Vector2i(8, 8))
	var shown := shown_integrated_weapons(unit)

	# Asserted before the guard: a bare bail-out here would let the frame losing its weapon entirely
	# pass this test green with nothing asserted (GUT scores that RISKY, not FAILED).
	assert_eq(shown.size(), 1, 'The Subutai draws exactly one integrated weapon box.')
	if shown.is_empty(): return

	assert_eq(names_of(shown)[0], 'Diversion Rail',
		'The integrated weapon box is titled with the WEAPON, as Bel names it on the card.')
	assert_does_not_have(names_of(shown), 'Siege Engine',
		'and never with the core SYSTEM, which is a different thing with its own name.')

func test_the_subutai_still_has_siege_engine_as_its_core_system() -> void:
	var game:Gamemaster = SubutaiFixture.create_game(self)
	var unit:Unit = SubutaiFixture.create_subutai(game, Vector2i(8, 8))

	# The other half of the split, and the reason this is not just a rename: "Siege Engine" must
	# survive as the core system's own card, carrying GATHER ROUND and Draw Fire.
	var core:GearCore = unit.get_gear(&'cp_siege_engine')
	assert_true(GearCore.is_valid(core), 'cp_siege_engine is still equipped.')
	if not GearCore.is_valid(core): return

	assert_eq(Translate.gear(&'cp_siege_engine', 'name'), 'Siege Engine', 'and still carries its own name.')
	assert_false(core.kit.has_weapon(),
		'It no longer carries a weapon, which is what keeps it out of the integrated-weapon box.')

# ---------------------------------------------------------------- Fitzgerald

func test_the_fitzgeralds_integrated_weapon_is_called_the_bizarre_cannon() -> void:
	var game:Gamemaster = FitzgeraldFixture.create_game(self)
	var unit:Unit = FitzgeraldFixture.create_fitzgerald(game, Vector2i(7, 4))
	var shown := shown_integrated_weapons(unit)

	assert_eq(shown.size(), 1, 'The Fitzgerald draws exactly one integrated weapon box.')
	if shown.is_empty(): return

	assert_eq(names_of(shown)[0], 'Bizarre Cannon',
		'The integrated weapon box is titled with the WEAPON, as Bel names it on the card.')
	assert_does_not_have(names_of(shown), 'Broadside',
		'and never with the core SYSTEM.')

func test_the_fitzgerald_still_has_broadside_as_its_core_system() -> void:
	var game:Gamemaster = FitzgeraldFixture.create_game(self)
	var unit:Unit = FitzgeraldFixture.create_fitzgerald(game, Vector2i(7, 4))

	var core:GearCore = unit.get_gear(&'cp_broadside')
	assert_true(GearCore.is_valid(core), 'cp_broadside is still equipped.')
	if not GearCore.is_valid(core): return

	assert_eq(Translate.gear(&'cp_broadside', 'name'), 'Broadside', 'and still carries its own name.')
	assert_false(core.kit.has_weapon(),
		'It no longer carries a weapon: MORE BLACK POWDER is a protocol, not a gun.')
