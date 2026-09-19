## THE ETERNITY HAMMER (Primrose rank III, SP4 Tasks 1 and 2). Task 1 built the weapon profile; Task
## 2 added the on-hit clause ("hostile characters adjacent to the target must make an Agility save or
## take 2 Burn") and tests 9-15 below, per this plan's stated split (the same shape SP3 used for the
## Falcata/Biting Retort pair).
##
## THE ON-HIT CLAUSE RUNS BEFORE THE SWING'S OWN DAMAGE, which is the ordering fact SP4 Task 2
## measured and which onhit_eternity_hammer.gd's header states in full: apply_on_hits is reached from
## event_unit_attack.gd:85-87, inside the attack-roll events that event_unit_attack_declared.gd:67
## executes, while the target's damage is not rolled until :74-121 and not executed until :199. Every
## bystander has saved and burned while the target is still at full health.
##
## "Superheavy Melee | SP 0 | Tags: HEAT SELF 1, OVERKILL | Damage: 1d6 Kinetic, 1d6 Explosive,
## 1d6 Energy, 2 Burn | Range: Threat 2"
## (specs/sixth-voice/07-primrose.md, Rank III, "Weapon: Eternity Hammer")
##
## SCRIPTLESS, like the Falcata and unlike the Rend Axe: the whole printed profile - four damage
## types, a flat self-heat, Overkill, threat 2 - is exports on the base ActionAttackWeapon
## (action_attack_weapon.gd) plus three DamageValue sub-resources (action_attack.gd:13
## additional_damage_values). No system_tags on the Kit: the card lists no Unique, matching the
## Falcata's own mw_acrasial_falcata.tres.
##
## FOUR DAMAGE TYPES, ONE FLAT ONE. The base damage_dice ("1d6" Kinetic) plus two more DamageValues
## (1d6 Explosive, 1d6 Energy) are ordinary dice; the fourth (2 Burn) is a DICE STRING WITH NO "d",
## exactly like vanilla mw_torch's flat 3 Burn (content/gear/ha/weapons/mw_torch.tres) - DamageValue
## takes any Lancer.DAMAGE_TYPE and Dice.roll_string("2") returns the literal 2, no roll involved.
##
## BURN LANDS IN current_damage() TOO, NOT ONLY IN state.burn - CORRECTED AT IMPLEMENTATION, against
## the plan's draft prediction of a clean 18-damage total. event_unit_damage.gd:117-122 calls
## damage(unit, damage_amount, damage_type) UNCONDITIONALLY for every non-HEAT type including BURN
## (the HP hit), and ONLY THEN separately adds the same amount to unit.state.burn for the future
## end-of-turn tick (:121-122) - the two are not alternatives. test_wormhole_grasp.gd's own
## test_a_hostiles_overwatch_is_not_halved_by_our_marker comment independently confirms this for the
## Torch's flat 3 Burn ("6 energy (5 after armour 1) plus the flat 3 Burn is EXACTLY its 8 HP"), so
## this was measurable before this task ever ran. test_the_swing_deals_all_four_damage_types therefore
## asserts current_damage() == 20 (three sixes plus the flat 2), not the plan's 18, and separately
## asserts state.burn == 2 as the fourth type's OWN evidence (kinetic/explosive/energy are otherwise
## indistinguishable from each other inside one HP total).
##
## LICENCE ACCESSOR: ContentLibrary has no get_license(); get_license_tree() (content_library.gd:254)
## is the real one, same correction test_rend_axe.gd and test_acrasial_falcata.gd already recorded.
##
## Run:
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_eternity_hammer.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')
## Only for create_deployable, which PrimroseFixture has no reason to re-expose - the same call
## test_sap.gd:39, test_draw_fire.gd:41 and test_rapier_carronade.gd reach for directly.
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const KIT_ID := &'mw_eternity_hammer'
const ATTACK_ID := &'action_eternity_hammer'

## The card's numbers, transcribed once so a typo in the .tres reads as a number and not as a vague
## "feels wrong".
const SP_COST := 0
const THREAT := 2
const THREAT_WITH_CARESS := 3
const SELF_HEAT := 1

## cheat_a_hit()'s buffer is all sixes: 1d6 Kinetic + 1d6 Explosive + 1d6 Energy = 6+6+6 = 18, and the
## flat 2 Burn (no die, see header) ALSO reduces HP on the hit (event_unit_damage.gd:117-122) before
## it is separately tracked as state.burn for the end-of-turn tick. 18 + 2 = 20.
const TOTAL_DAMAGE := 20
const BURN := 2

const PRIMROSE_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4)    # threat 2 easily reaches adjacent
const CONTROL_TILE := Vector2i(20, 20) # far from everything else in this spec's map

## SP4 TASK 2 GEOMETRY, AND IT IS CHOSEN SO THE TWO CANDIDATE ORIGINS GENUINELY DISAGREE.
## The gather measures its radius from the TARGET (onhit_eternity_hammer.gd); the obvious mistake is
## to measure it from the ATTACKER. These two tiles are what make that mistake visible instead of
## degenerate - each is inside exactly ONE of the two radii:
##
##            (3,4)        (4,4)         (5,4)        (6,4)
##        FAR_HOSTILE    PRIMROSE       TARGET      BYSTANDER
##        d(target)=2   d(target)=1                d(target)=1   <- the correct radius takes (6,4)
##        d(prim)  =1                  d(prim)=1   d(prim)  =2   <- an attacker-origin radius would
##                                                                  take (5,4) and (3,4) instead
const BYSTANDER_TILE := Vector2i(6, 4)   # adjacent to the TARGET, two tiles from the Primrose
const FAR_HOSTILE_TILE := Vector2i(3, 4) # two tiles from the TARGET, adjacent to the Primrose
const ALLY_TILE := Vector2i(5, 5)        # adjacent to the target; the faction filter is the whole test

## The on-hit clause's own number, kept separate from the swing's flat BURN above even though both
## are 2: they are two different sentences on the card and a future errata could move one alone.
const BYSTANDER_BURN := 2

## test_a_miss_burns_nobody has to raise the dummy's evasion, and that is not fussiness.
## This file's before_each gives the dummy evasion -10 so no test ever needs to think about whether a
## swing connects - but hit is `total_roll >= pre.target_defense` (attack_roll.gd:72), with no
## natural-1 auto-miss anywhere in the sequence, so a cheated base roll of 1 still HITS a defence of
## -10. cheat_a_miss() is only a guaranteed miss against the positive evasions the other Primrose
## specs hand out (test_rend_axe.gd:58 uses 5 for exactly this reason). 20 clears 1 plus the grit and
## any stray accuracy die by a wide margin.
const MISSABLE_EVASION := 20

## The hostile deployable for test 15. Health and armor only have to be non-lethal and non-absorbing;
## the evasion is never rolled against, since nothing ever attacks it.
const DEPLOYABLE_HEALTH := 40
const DEPLOYABLE_ARMOR := 0
const DEPLOYABLE_EVASION := 10

var game:Gamemaster
var primrose:Unit
var dummy:Unit
var gear:GearCore

func before_each() -> void:
	game = Fixture.create_game(self)
	primrose = Fixture.create_primrose(game, PRIMROSE_TILE)
	dummy = Fixture.create_dummy(game, TARGET_TILE, -10) # evasion -10: every swing hits even uncheated
	dummy.core.frame.stat.health = 200 # never dies mid-spec; damage numbers are the weapon's alone
	dummy.core.full_repair()
	gear = Fixture.equip(primrose, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func weapon() -> ActionAttackWeapon:
	return gear.get_action(ATTACK_ID) as ActionAttackWeapon

func specific() -> SpecificAction:
	return Fixture.specific(primrose, KIT_ID)

## Fires the Hammer at `target_unit` (default `dummy`), opening the turn first. Does NOT clear the
## dice queue - the caller's cheat_* call is what decides the roll, same idiom as the Falcata/Rend Axe
## specs' own swing().
func swing(target_unit:Unit = null) -> void:
	await Fixture.attack(game, primrose, KIT_ID, target_unit if target_unit else dummy)

# ------------------------------------------------- pinning an AGILITY save (SP4 Task 2)
#
# THE FROZEN HULL HELPERS DO NOT FIT THIS CARD, AND THIS IS NOT A STYLE PREFERENCE.
# PrimroseFixture.force_save_to_fail / force_save_to_pass write HaseBlock.create(-+30, 0, 0, 0) -
# hull only, the other three left at 0 - because every caller before this one forces a HULL save
# (Dazzling Wind's leap, Magnetic Weight Redistribution, Biting Retort, the Falcata). The Eternity
# Hammer's clause is an AGILITY save, so:
#
#   force_save_to_fail would leave agi at 0, and the save would fail for the WRONG reason - the d20
#   pops a 6 out of cheat_a_hit()'s buffer (dice.gd:33-35, ONE global FIFO) and 6 + 0 < the target of
#   10 (unit_hasecheck.gd:134). Green, and proving nothing about Agility.
#   force_save_to_pass is worse: agi still 0, so 6 + 0 < 10 and the "passed" save FAILS. The test
#   would be red for a reason that has nothing to do with the code under test.
#
# SO THE MOD USES A SECOND, AGILITY PAIR - PrimroseFixture.force_agility_save_to_fail /
# force_agility_save_to_pass. Those pin AGI against an opposite-signed HULL, SYS and ENG, which is
# what makes them a PAIR rather than one helper: a hopeless Agility beside an excellent everything
# else can only burn if the save really reads AGI, and an excellent Agility beside a hopeless
# everything else can only escape if it does. Neither of tests 9 and 10 alone would notice the clause
# quietly becoming a Hull save; together they cannot both hold unless it is Agility. That is the same
# argument test_leap.gd's inline pair makes for its own HULL save, folded into tests 9 and 10 rather
# than spent on a ninth test.
#
# THEY LIVE IN THE FIXTURE, NOT HERE, and that was a Task 2 review correction: the first draft wrote
# them inline on the grounds that this is "one card's save type, not a shared need", which is wrong
# about the very next task. SP4 Task 3's Flourishing Twirl forces its whole radius through
# UnitHasecheck.make_saves(..., Lancer.HASE.AGI, ...) and needs exactly this pair. The two hull
# signatures already in the fixture are untouched and unrenamed; the Agility pair is additive.

# ---------------------------------------------------------------- the weapon as data

func test_the_licence_grants_the_hammer_at_rank_three() -> void:
	var license:UnlockTree = ContentLibrary.get_license_tree(Fixture.LICENSE_ID)
	assert_not_null(license, 'li_primrose is registered.')
	if license == null or license.rank_3 == null: return
	# COMPARE BY has(), NEVER BY sort() - Array[StringName].sort() compares interned pointers, not
	# alphabetically (SP3's finding, restated in the global constraints).
	var ids:Array[StringName] = []
	for kit:Kit in license.rank_3.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'rank 3 grants the Eternity Hammer.')

func test_the_swing_deals_all_four_damage_types() -> void:
	Fixture.cheat_a_hit()
	await swing()
	# VACUITY + exact damage, per the header's correction: 3 sixes (18) plus the flat 2 Burn, which
	# ALSO reduces HP on the hit and is not only a state.burn bookkeeping entry.
	assert_eq(dummy.current_damage(), TOTAL_DAMAGE,
		'kinetic + explosive + energy (6 each, indistinguishable from each other here) + the flat Burn.')
	# Burn's OWN evidence, since the three dice types cannot be told apart inside current_damage().
	assert_eq(dummy.state.burn, BURN, 'the flat 2 Burn also landed as its own tracked value.')

func test_the_swing_heats_the_pilot() -> void:
	# BEFORE/AFTER DELTA, not an absolute read: matches this mod's own test_ors_hypercharge.gd idiom,
	# and is robust to whatever baseline heat SpecFactory.create_unit/create_primrose leaves behind.
	var before:int = primrose.core.current.heat
	Fixture.cheat_a_hit()
	await swing()
	assert_eq(primrose.core.current.heat - before, SELF_HEAT,
		'HEAT SELF 1: self_heat_dice = "1" is a flat value, not a die (action.gd:39, :149).')

func test_overkill_is_on_the_profile() -> void:
	# DECLARATIVE, DELIBERATELY. Overkill's behaviour (apply_overkill, action_attack_weapon.gd:259) is
	# the engine's and vanilla specs already cover it; a mod spec that re-tests it measures Wickworks,
	# not us (global constraints, "Two things the plan deliberately leaves unpinned").
	var attack := weapon()
	assert_not_null(attack, 'the Kit carries action_eternity_hammer.')
	if attack == null: return
	assert_true(attack.tags.has(&'overkill'), 'OVERKILL is on the printed profile.')

func test_the_printed_threat_is_two() -> void:
	var attack := weapon()
	assert_not_null(attack, 'the Kit carries action_eternity_hammer.')
	if attack == null: return
	assert_eq(attack.threat, THREAT, 'printed threat 2, per the card.')

	# THE BARE CONTROL: a plain unit with no Primrose frame, so it cannot carry the Artful Caress
	# trait Kit at all - built with SpecFactory.create_unit + Fixture.equip() directly, the same shape
	# test_acrasial_falcata.gd's control uses. Proves the printed field alone, before the frame's own
	# trait is anywhere near it (test_artful_caress_widens_the_hammer_to_three is that half).
	var control:Unit = SpecFactory.create_unit(game.map, CONTROL_TILE)
	var control_gear:GearCore = Fixture.equip(control, KIT_ID)
	assert_false(control.has_kit(Fixture.CARESS_ID),
		'GUARD: the control carries no mt_artful_caress trait Kit.')
	var control_weapon:ActionAttackWeapon = control_gear.get_action(ATTACK_ID) as ActionAttackWeapon
	var control_specific := Fixture.specific(control, KIT_ID)
	assert_eq(control_weapon.threat_distance(control_specific), THREAT,
		'without the trait, threat_distance() reads the printed field back unchanged.')

func test_artful_caress_widens_the_hammer_to_three() -> void:
	# `primrose` already carries Artful Caress: Fixture.create_primrose -> SpecFactory.apply_passive_
	# buffs applies every trait Kit's passive buff, and mt_artful_caress (Heavy/Superheavy melee, +1
	# threat) is one of them. Proves the Hammer sits inside the frame's own threat channel, the same
	# claim test_acrasial_falcata.gd's test_artful_caress_widens_it_to_four makes for the Falcata.
	assert_eq(weapon().threat_distance(specific()), THREAT_WITH_CARESS,
		'threat 2 printed, widened to 3 by the frame\'s own Artful Caress trait.')

func test_the_name_and_flavour_and_effect_resolve() -> void:
	# THIS MOD'S OWN compiled artifact, not the global tr() - get_message returns an EMPTY StringName
	# for a key the artifact does not carry, where the global tr() falls back to the raw key, so only
	# this lookup can attribute the row to THIS mod and not to a sibling Reag-* mod answering the same
	# key (test_acrasial_falcata.gd's identical const and rationale).
	const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['gear.mw_eternity_hammer.name', 'gear.mw_eternity_hammer.flavor',
			'gear.mw_eternity_hammer.effect']:
		assert_ne(translation.get_message(key), StringName(''),
			'%s resolves to something other than the raw key - carried by THIS mod.' % key)

	# THE LCP'S OWN GRAMMAR, PINNED DELIBERATELY (ambiguity note in the task brief): "When you have
	# biggest and best hammer there is" reads wrong and is correct - it is the sheet's `description`
	# verbatim (specs/sixth-voice/07-primrose.md, Rank III), not ours to fix.
	var flavor := String(translation.get_message('gear.mw_eternity_hammer.flavor'))
	assert_true(flavor.contains('When you have biggest and best hammer there is'),
		'the LCP\'s own ungrammatical clause survived verbatim.')

	# THE ON-HIT CLAUSE, WRITTEN NOW BUT NOT YET TRUE (Task 2 makes it true). Checked for its exact
	# glossary markup surviving the CSV round-trip, the same way test_acrasial_falcata.gd checks its
	# doubled-quote escaping.
	var effect := String(translation.get_message('gear.mw_eternity_hammer.effect'))
	assert_true(effect.contains('|Agility save|') and effect.contains('|Burn|'),
		'the glossary markup for the not-yet-implemented on-hit clause landed intact.')

func test_the_kit_is_a_superheavy_melee_weapon() -> void:
	var attack := weapon()
	assert_not_null(attack, 'the Kit carries action_eternity_hammer.')
	if attack == null: return
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.SUPERHEAVY, 'Superheavy.')
	assert_true(attack.is_weapon_type(Lancer.WEAPON_TYPE.MELEE, gear), 'Melee.')
	# THE LAST ONE IS WHAT THE SP1 OVERWATCH WAIVER KEYS ON (unit_relation.gd, through
	# is_weapon_available_as_a_rxn) - kit.gd:127-128 has_weapon_superheavy(), not the action field
	# alone, is what that extension actually reads.
	assert_true(gear.kit.has_weapon_superheavy(),
		'has_weapon_superheavy() is true, which is what the SP1 Overwatch waiver keys on.')

# ------------------------------------------------- the bystander burn (SP4 Task 2)

func test_a_hostile_adjacent_to_the_target_saves_and_burns_on_failure() -> void:
	var bystander := Fixture.create_hostile(game, BYSTANDER_TILE)
	Fixture.force_agility_save_to_fail(bystander)
	# GEOMETRY GUARD, not decoration: if the bystander were also adjacent to the PRIMROSE this test
	# would stay green with the radius measured from either unit, and the origin mutation would have
	# nothing to say. See the ASCII block beside BYSTANDER_TILE.
	assert_eq(UnitRelation.distance_between(dummy, bystander), 1,
		'fixture: the bystander is adjacent to the TARGET.')
	assert_eq(UnitRelation.distance_between(primrose, bystander), 2,
		'fixture: and two tiles from the Primrose, so only a target-origin radius reaches it.')

	Fixture.cheat_a_hit()
	await swing()

	assert_gt(dummy.current_damage(), 0, 'VACUITY: the swing landed.')
	# BOTH HALVES OF BURN, DELIBERATELY. event_unit_damage.gd:119 calls damage() unconditionally for
	# every non-HEAT type and :121-122 adds unit.state.burn on top - they are not alternatives (Task 1
	# measured the same thing on the Hammer's own flat 2). Asserting the stack alone would miss a
	# damage regression; asserting the damage alone would miss a stack regression.
	assert_eq(bystander.state.burn, BYSTANDER_BURN, 'a failed Agility save takes 2 Burn as a stack.')
	assert_eq(bystander.current_damage(), BYSTANDER_BURN, 'and the same 2 as immediate HP damage.')

func test_a_passed_save_takes_no_burn() -> void:
	var bystander := Fixture.create_hostile(game, BYSTANDER_TILE)
	Fixture.force_agility_save_to_pass(bystander)
	Fixture.cheat_a_hit()
	await swing()

	assert_gt(dummy.current_damage(), 0, 'VACUITY: the swing landed.')
	assert_eq(bystander.state.burn, 0, 'a passed Agility save takes no Burn stack.')
	assert_eq(bystander.current_damage(), 0, 'and no damage either - the save avoids the whole clause.')

func test_the_target_itself_is_not_in_the_loop() -> void:
	# THIS ONLY DISCRIMINATES BECAUSE THE SWING ITSELF DEALS BURN. The printed profile's fourth damage
	# value is a flat 2 Burn, so the target is already carrying exactly the number this clause would
	# add. If the target were in its own radius it would burn TWICE - 4 stacked and 22 damage instead
	# of 2 and 20 - and that difference is the only evidence a missing self-exclusion would leave.
	#
	# THE FORCED FAILURE IS WHAT MAKES IT AN ASSERTION RATHER THAN A COIN FLIP: without it the dummy
	# might simply pass the save it should never have been asked to make, and the test would go green
	# with the exclusion broken.
	#
	# The exclusion itself is the ENGINE's (other_unit != unit, unit_relation.gd:58), not ours - there
	# is deliberately no filter of our own in onhit_eternity_hammer.gd. This is the test that would
	# notice if that ever changed.
	Fixture.force_agility_save_to_fail(dummy)
	Fixture.cheat_a_hit()
	await swing()

	assert_eq(dummy.state.burn, BURN,
		'the target carries the swing\'s own 2 Burn and NOT a second 2 from its own on-hit clause.')
	assert_eq(dummy.current_damage(), TOTAL_DAMAGE,
		'and 20 damage, not 22: the target is not a bystander to itself.')

func test_an_ally_adjacent_to_the_target_is_untouched() -> void:
	# The save is forced to FAIL, so the faction filter is the only thing standing between this ally
	# and 2 Burn. Delete the are_enemies filter and this is the test that reddens.
	var ally := Fixture.create_ally(game, ALLY_TILE)
	Fixture.force_agility_save_to_fail(ally)
	assert_eq(UnitRelation.distance_between(dummy, ally), 1,
		'fixture: the ally really is adjacent to the target.')

	Fixture.cheat_a_hit()
	await swing()

	assert_gt(dummy.current_damage(), 0, 'VACUITY: the swing landed.')
	assert_eq(ally.state.burn, 0, 'the card says HOSTILE characters; an ally takes no Burn.')
	assert_eq(ally.current_damage(), 0, 'and no damage.')

func test_a_hostile_two_tiles_from_the_target_is_untouched() -> void:
	# Hostile, and its save forced to fail, so DISTANCE is the only thing saving it. Placed adjacent
	# to the PRIMROSE on purpose: that is what makes this the test the origin-swap mutation reddens.
	var far_hostile := Fixture.create_hostile(game, FAR_HOSTILE_TILE)
	Fixture.force_agility_save_to_fail(far_hostile)
	assert_eq(UnitRelation.distance_between(dummy, far_hostile), 2,
		'fixture: two tiles from the target, so outside the card\'s "adjacent".')
	assert_eq(UnitRelation.distance_between(primrose, far_hostile), 1,
		'fixture: but adjacent to the PRIMROSE, so a radius measured from the attacker would take it.')

	Fixture.cheat_a_hit()
	await swing()

	assert_gt(dummy.current_damage(), 0, 'VACUITY: the swing landed.')
	assert_eq(far_hostile.state.burn, 0, 'distance 2 is not adjacent; no Burn.')
	assert_eq(far_hostile.current_damage(), 0, 'and no damage.')

func test_a_miss_burns_nobody() -> void:
	# THE EVASION RAISE IS LOAD-BEARING - see MISSABLE_EVASION. This file's dummy sits at -10 so that
	# no other test has to think about connecting, and a cheated base roll of 1 beats -10.
	dummy.core.frame.stat.evasion = MISSABLE_EVASION
	dummy.core.full_repair()

	var bystander := Fixture.create_hostile(game, BYSTANDER_TILE)
	Fixture.force_agility_save_to_fail(bystander)
	Fixture.cheat_a_miss()
	await swing()

	assert_eq(dummy.current_damage(), 0, 'fixture: the swing MISSED (this is what the evasion raise buys).')
	# WHAT THIS ACTUALLY PINS is event_unit_attack.gd:83's `if roll.hit:` - the engine never reaches
	# apply_on_hits on a miss. It does NOT pin onhit_eternity_hammer.tres's apply_on: apply_on_hits
	# calls effect.on_hit() unconditionally (on_hit_effect.gd:42-46) and apply_on is read only by the
	# should_abort gates this effect does not use. Measured: apply_on = 0 reddens nothing.
	assert_eq(bystander.state.burn, 0, 'a miss burns nobody: the clause is "on hit".')
	assert_eq(bystander.current_damage(), 0, 'and damages nobody.')

func test_a_hostile_deployable_adjacent_to_the_target_is_untouched() -> void:
	# THE AUTO-FAIL EDGE, and without this test it is unmeasured. UnitHasecheck.make_agility_save
	# short-circuits a non-character to FALSE - the FAILURE branch - without rolling anything
	# (unit_hasecheck.gd:47-48, "noncharacters always fail; doesn't even count as a force"). So the
	# only thing between a hostile crate and an unsaveable 2 Burn is get_characters_within's
	# is_character() filter (unit_relation.gd:42). SP3's Biting Retort ruling records the same engine
	# edge from the other side.
	#
	# dep_jericho_cover is the HARDER of the two non-characters on purpose: it is entity OBJECT, so it
	# passes get_units_within's marker exclusion at :59 and is dropped by the character filter at :42.
	# A MARKER would never reach :42 at all and would prove the weaker claim.
	var dep := FitzgeraldFixture.create_deployable(
		game, BYSTANDER_TILE, DEPLOYABLE_HEALTH, DEPLOYABLE_ARMOR, DEPLOYABLE_EVASION)
	assert_false(dep.is_character(), 'fixture: the Jericho cover is not a character.')
	assert_false(dep.is_marker(), 'fixture: and not a marker either - it is an OBJECT.')
	assert_true(dep.is_deployable(), 'fixture: a real deployable, the thing the card would meet in play.')
	assert_eq(UnitRelation.distance_between(dummy, dep), 1, 'fixture: adjacent to the target.')

	Fixture.cheat_a_hit()
	await swing()

	assert_gt(dummy.current_damage(), 0, 'VACUITY: the swing landed.')
	assert_eq(dep.state.burn, 0, 'a hostile deployable is not a hostile CHARACTER: no Burn.')
	assert_eq(dep.current_damage(), 0, 'and it takes no damage from a save it was never asked to make.')
