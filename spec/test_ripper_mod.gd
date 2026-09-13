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
	# with from_gear set to the mod's own GearCore (unit_condition.gd:884-891 - CORRECTED from the
	# 885-893 this line carried, verified against the 1.4.3 tree), and both buffs compare that against
	# weapon.get_weapon_mod(loadout).persistent_id.
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

# ---------------------------------------------------------------- "lose AP, and cannot gain AP"
#
# Spike 10's seam (specs/2026-09-13-ap-strip-feasibility.md 1-2): event_unit_damage.gd's
# execute_preblock computes DamageModifications TWICE - at :52 and again at :63 - with
# execute_reaction_events(TRIGGER.DAMAGE, TIMING.PRE) at :59 between the two reads, and
# damage_modifications.gd:103 only skips armor when the FINAL read still carries the flag. The
# reaction bus fires triggered BUFFS on every unit for that trigger (reaction_bus.gd:61-67), so a
# hidden PRE buff on the attacker can erase the flag in between.
#
# THE TAG SIDE IS UNTOUCHED AND THAT IS RULED, NOT AN OVERSIGHT. Weapon tags are add-only, so the
# card still reads AP; the author accepted that 2026-09-13 (rulings.md). test_the_card_still_says_ap
# pins it, so a future change that DID hide the chip shows up as a decision rather than a surprise.
const ARMOR := 2
const AP_RIFLE_DAMAGE := 5    # 1d3+2 with the die pinned to 3

## A vanilla weapon mod that is NOT ours, for the "which mod is this" half of the predicate. Fits any
## Auxiliary/Main/Heavy weapon (allowed_sizes [0,1,2], no type filter) and its only effect is an
## inaccuracy buff, so it never moves a damage number - the Spike 10 probe used it exactly this way.
const OTHER_MOD := &'wm_uncle_class_comp_con'

func has_ap(weapon:GearCore) -> bool:
	var specific := SpecificAction.create(fitz, weapon, weapon.get_solo_action())
	return specific.action.has_tag(Lancer.WEAPON_TAG.AP, specific)

## A WEAPON_TAG buff granting AP to everything - the Rainmaker's Huntsman shape - for the
## "cannot gain AP by any means" half. weapon_types left empty so BuffWeaponType's gate lets
## everything through.
class GrantApToEverything extends BuffWeaponType:
	func _init() -> void:
		to = Buff.TO.WEAPON_TAG
		hide_from_player = true
	func get_values(core:BuffCore, context:Context) -> Context:
		return Context.create({category = Lancer.WEAPON_TAG.AP, number = 0})

func armour_the_target() -> void:
	target.core.frame.stat.armor = ARMOR
	target.core.full_repair()

## Equip TWO weapons and fit a mod to EACH, ours to the first and `other_mod` to the second. EQUIP
## BOTH BEFORE APPLYING THE BUFFS, for the reason equip_modded's header gives: equip_system() calls
## full_repair(), which empties every equipped gear's state dictionary.
func equip_two(ours_id:StringName, theirs_id:StringName, other_mod:StringName) -> Array:
	var ours:GearCore = fitz.core.equip_system(ours_id)
	var theirs:GearCore = fitz.core.equip_system(theirs_id)
	fitz.core.loadout.equip_weapon_mod(MOD_ID, ours)
	if other_mod != &'': fitz.core.loadout.equip_weapon_mod(other_mod, theirs)
	SpecFactory.apply_passive_buffs(fitz)
	return [ours, theirs]

func test_a_modded_ap_weapon_stops_ignoring_armor() -> void:
	armour_the_target()
	var weapon := equip_modded(AP_RIFLE)
	var lost := await shoot(weapon, 3)
	# The +1d6 is in this number too: it is rolled from the same cheated buffer, so it comes out 3.
	# The armor bite is what the unmodded control below pins out.
	assert_eq(lost, AP_RIFLE_DAMAGE - ARMOR + 3, 'Armor bit, and the bonus d6 landed: AP was stripped.')

func test_an_unmodded_ap_weapon_keeps_ignoring_armor() -> void:
	armour_the_target()
	var weapon := equip_plain(AP_RIFLE)
	var lost := await shoot(weapon, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE, 'Full damage: this one still has its AP.')

func test_the_card_still_says_ap() -> void:
	var weapon := equip_modded(AP_RIFLE)
	assert_true(has_ap(weapon), 'The TAG is add-only and stays; only the damage flag is taken away.')

func test_ap_gained_from_a_buff_is_stripped_too() -> void:
	armour_the_target()
	var weapon := equip_modded(PLAIN_RIFLE)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), fitz, GrantApToEverything.new())
	assert_true(has_ap(weapon), 'The tag side says AP.')
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6 - ARMOR + 6, 'The strip runs after every source of AP.')

## THE CONTROL for the test above (review finding: without it, the strip test can go falsely green).
## If the engine's buff-granted-tag -> DAMAGE_FLAG.AP conversion ever broke, NO AP flag would be set
## at all, armor would bite for that reason instead of because of the strip, and
## test_ap_gained_from_a_buff_is_stripped_too's damage assertion would land on the same number either
## way - passing while proving nothing about the strip. This test is identical except the weapon is
## UNMODDED, so there is nothing to strip: it proves the buff's grant reaches the damage flag at all,
## which is what makes the stripped case meaningful. No mod, no bonus d6 - see
## test_an_unmodded_weapon_gets_no_bonus - so full damage here is the base 6, unreduced by armor.
func test_ap_granted_by_a_buff_reaches_an_unmodded_weapon() -> void:
	armour_the_target()
	var weapon := equip_plain(PLAIN_RIFLE)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), fitz, GrantApToEverything.new())
	assert_true(has_ap(weapon), 'The tag side says AP.')
	var lost := await shoot(weapon, 6)
	assert_eq(lost, 6, 'No mod to strip it: buff-granted AP ignored the armor, in full.')

func test_the_strip_buff_survives_the_shot() -> void:
	armour_the_target()
	var weapon := equip_modded(AP_RIFLE)
	var before:int = fitz.state.buffs.size()
	await shoot(weapon, 3)
	assert_eq(fitz.state.buffs.size(), before, 'It was not consumed by firing.')

# ---------------------------------------------------------------- one mod, two weapons, one owner
#
# ADDED BY TASK 4 BEYOND THE BRIEF, from Task 3's review. Both buffs gate on
# RipperBonus.is_modded_weapon, whose second half is `mod.persistent_id == from_gear`; until these
# two tests existed nothing on the Fitzgerald carried a weapon it did NOT own, so a mutant reading
# `return GearCore.is_valid(mod)` passed the whole suite.
#
# TWO TESTS, NOT ONE, AND THE SECOND IS THE ONE THAT BITES. A second weapon carrying NO mod does not
# discriminate against that mutant at all: get_weapon_mod() returns null, GearCore.is_valid(null) is
# false, and the mutant answers "not mine" for the right result by accident. Only a second weapon
# wearing a DIFFERENT mod forces the id comparison to be the thing that decides. The mod-less case is
# kept anyway, because it is the ordinary loadout and it proves the buff's attribution survives the
# Fitzgerald holding two weapons at once.

func test_a_second_unmodded_weapon_on_the_same_unit_is_untouched() -> void:
	armour_the_target()
	var weapons := equip_two(PLAIN_RIFLE, AP_RIFLE, &'')
	var theirs:GearCore = weapons[1]
	assert_null(theirs.get_weapon_mod(fitz.core.loadout), 'The second weapon carries no mod.')
	assert_true(GearCore.is_valid(weapons[0].get_weapon_mod(fitz.core.loadout)), 'The first one does.')
	var lost := await shoot(theirs, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE, 'Neither the +1d6 nor the strip reached the other weapon.')

func test_a_weapon_wearing_someone_elses_mod_is_untouched() -> void:
	armour_the_target()
	var weapons := equip_two(PLAIN_RIFLE, AP_RIFLE, OTHER_MOD)
	var theirs:GearCore = weapons[1]
	var their_mod:GearCore = theirs.get_weapon_mod(fitz.core.loadout)
	assert_true(GearCore.is_valid(their_mod), 'The second weapon wears a mod of its own.')
	assert_ne(their_mod.persistent_id, weapons[0].get_weapon_mod(fitz.core.loadout).persistent_id,
		'A DIFFERENT mod - this is what the id comparison has to tell apart.')
	# This test only survives because Dice.CHEAT_ROLL_QUEUE is ONE queue shared by attack AND damage
	# dice (dice.gd:22-40: cheat_attack appends attacks then damage into the same array, and every
	# roll - accuracy included - pops from the front), and OTHER_MOD's -2 accuracy pops two EXTRA d6
	# through roll_d6_accuracy before the attack die is even reached. shoot()'s buffer is uniform
	# (every slot pinned to the same `die`) and 8 deep, so those two stolen accuracy dice are
	# invisible - they just consume two of the spare pinned values instead of misaligning anything.
	# Shortening the buffer would silently break this without any assertion telling you why.
	var lost := await shoot(theirs, 3)
	assert_eq(lost, AP_RIFLE_DAMAGE,
		'Being modded is not enough: our buffs only reach the weapon OUR mod is fitted to.')
