# RIPPER MOD (Fitzgerald rank II, SP3 Tasks 3 and 4). A weapon mod fitting Cannon, Rifle and CQB of
# any size: "+1d6 bonus damage against targets with at least 1 Armor. Attacks made with this weapon
# lose |AP| and cannot gain |AP| by any means."
#
# This file replaces spec/test_spike_ripper_mod_ap.gd, the Spike 10 probe, which built the strip buff
# in memory against a vanilla stand-in mod. Task 4 rewrites the probe's five strip tests against the
# real .tres and deletes it. The feasibility write-up is
# D:\DEV\lancer-tactics-claude\specs\2026-09-13-ap-strip-feasibility.md.
#
# WHY THE TARGET'S ARMOR IS SET TWO DIFFERENT WAYS. unit.get_armor() is
# core.get_armor() + state.stat_bonus.armor (unit.gd:309). The frame's own armor is the ordinary
# case; stat_bonus is what a Buff.TO.STATBLOCK buff writes, which is how SP4's Reinforcement Blast
# will grant armor - so the "temporary armor counts" test sets stat_bonus directly rather than
# waiting for SP4 to exist.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ripper_mod.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const MOD_ID := &'wm_ripper_mod'

## Vanilla Main Rifle, 1d3+2 energy, AP on its one profile (mw_thermal_rifle.tres:13-15).
const AP_RIFLE := &'mw_thermal_rifle'
## Vanilla Main Rifle, 1d6 kinetic, no AP (mw_assault_rifle.tres:13-15).
const PLAIN_RIFLE := &'mw_assault_rifle'
## Vanilla Main Launcher - the mod must refuse it.
const LAUNCHER := &'mw_missile_rack'

const START := Vector2i(0, 2)
const TARGET_TILE := Vector2i(4, 2)

var game:Gamemaster
var fitz:Unit
var target:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	fitz = Fixture.create_fitzgerald(game, START)
	target = Fixture.create_dummy(game, TARGET_TILE, -10) # every shot hits; the dice fix the numbers
	target.core.frame.stat.health = 200
	target.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Equip a weapon, fit the Ripper Mod to it, and apply the passive buffs. EQUIP EVERYTHING FIRST:
## unit.core.equip_system() calls full_repair(), which empties every equipped gear's state dictionary
## - so equipping a second weapon after setting state silently resets the first.
func equip_modded(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = fitz.core.equip_system(weapon_id)
	fitz.core.loadout.equip_weapon_mod(MOD_ID, weapon)
	SpecFactory.apply_passive_buffs(fitz)
	return weapon

func equip_plain(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = fitz.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(fitz)
	return weapon

## Fire a weapon's solo profile once and return the health the target lost. ONE SHOT PER TEST: a
## second activation of the same gear in one turn is silently refused by the per-turn soft limit.
func shoot(weapon:GearCore, die:int) -> int:
	var before:int = target.core.current.health
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [die, die, die, die, die, die, die, die])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(),
		gear = weapon,
		unit = fitz,
		target_unit = target,
	})
	return before - target.core.current.health

func fits(weapon_id:StringName) -> bool:
	var weapon:GearCore = fitz.core.equip_system(weapon_id)
	var passive:PassiveWeaponMod = ContentLibrary.get_kit(MOD_ID).get_passives(PassiveWeaponMod).front()
	return passive.is_applicable_to(weapon)

# ---------------------------------------------------------------- the kit and its fit rules

func test_the_mod_is_a_two_sp_weapon_mod() -> void:
	var kit:Kit = ContentLibrary.get_kit(MOD_ID)
	assert_true(Kit.is_valid(kit), 'wm_ripper_mod is in the kits index.')
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.get_passives(PassiveWeaponMod).size(), 1, 'Exactly one PassiveWeaponMod.')

func test_it_fits_a_rifle_and_a_cannon() -> void:
	assert_true(fits(PLAIN_RIFLE), 'A Rifle takes the mod.')
	assert_true(fits(&'mw_breech_loading_swivel_gun'), 'And the Fitzgerald\'s own Cannon.')

func test_it_refuses_a_launcher() -> void:
	assert_false(fits(LAUNCHER), 'A Launcher is not on the list.')

func test_it_fits_an_ap_weapon() -> void:
	# Ruling confirmed 2026-09-13: ruling 9's fallback is withdrawn, so an AP weapon is legal and
	# the +1d6 applies to it. Task 4 is what takes its AP away.
	assert_true(fits(AP_RIFLE), 'An AP rifle takes the mod.')

func test_the_mod_hangs_its_buff_off_its_own_gear() -> void:
	# What makes "is this MY weapon" answerable at all: PassiveWeaponMod.applied_buffs are applied
	# with from_gear set to the mod's own GearCore (unit_condition.gd:885-893), and both buffs compare
	# that against weapon.get_weapon_mod(loadout).persistent_id.
	var weapon := equip_modded(PLAIN_RIFLE)
	var mod:GearCore = weapon.get_weapon_mod(fitz.core.loadout)
	assert_true(GearCore.is_valid(mod), 'The mod is fitted.')
	var ours:Array = fitz.state.buffs.filter(
		func(core:BuffCore) -> bool: return core.from_gear == mod.persistent_id)
	assert_false(ours.is_empty(), 'At least one buff on the Fitzgerald is attributed to the mod.')

# ---------------------------------------------------------------- the bonus damage

func test_a_modded_weapon_adds_a_d6_against_one_armor() -> void:
	target.core.frame.stat.armor = 1
	target.core.full_repair()
	var weapon := equip_modded(PLAIN_RIFLE)
	# 1d6 pinned to 6, minus 1 armor, plus the mod's 1d6 also pinned to 6.
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6 - 1 + 6, 'The bonus d6 landed.')

func test_a_modded_weapon_adds_nothing_against_no_armor() -> void:
	target.core.frame.stat.armor = 0
	target.core.full_repair()
	var weapon := equip_modded(PLAIN_RIFLE)
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6, 'No armor, no bonus.')

func test_temporary_armor_counts() -> void:
	# stat_bonus.armor is what a Buff.TO.STATBLOCK buff writes - SP4's Reinforcement Blast grants
	# armor exactly this way, and unit.get_armor() sums it (unit.gd:309). That is the getter this
	# buff's check_if_passive_applies calls, so the +1d6 gate does see it.
	#
	# CORRECTED FROM THE BRIEF: the brief expected 6 - 1 + 6 = 11, i.e. that this armor would ALSO
	# reduce the base weapon's own damage the way frame.stat.armor does. Verified against the engine
	# that it does not. The incoming-damage armor mitigation in damage_modifications.gd:97 reads
	# `unit.core.current.armor`, a UnitCore-level pool value written only by
	# UnitPrinter.full_repair/short_repair from `core.get_armor()` (unit_core.gd:408) - which sums
	# `frame.stat.armor` and UnitCore's OWN `bonus.armor`, never `Unit.state.stat_bonus`. A
	# Buff.TO.STATBLOCK buff's armor is folded into `state.stat_bonus` by the per-tile recalculation
	# (unit_battle_state.gd:230-234), which runs on the Unit, not the UnitCore, and never touches
	# `core.current.armor` either. So `unit.get_armor()` is the only place the two numbers are ever
	# added together; the damage pipeline never calls it. A buff-granted "temporary armor" therefore
	# satisfies any gate written against unit.get_armor() - this mod's own clause included - but does
	# not blunt the hit that triggers it. The actual roll is 6 (base) + 6 (bonus) = 12, unreduced.
	target.core.frame.stat.armor = 0
	target.core.full_repair()
	target.state.stat_bonus.armor = 1
	var weapon := equip_modded(PLAIN_RIFLE)
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6 + 6, 'Armor from a buff satisfies the gate, but does not reduce the hit.')

func test_an_unmodded_weapon_gets_no_bonus() -> void:
	target.core.frame.stat.armor = 1
	target.core.full_repair()
	var weapon := equip_plain(PLAIN_RIFLE)
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6 - 1, 'No mod, no bonus.')
