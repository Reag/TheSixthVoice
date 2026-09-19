## THE ETERNITY HAMMER (Primrose rank III, SP4 Task 1). The weapon profile only - the on-hit clause
## ("hostile characters adjacent to the target must make an Agility save or take 2 Burn") is Task 2's
## job, per this plan's stated split (the same shape SP3 used for the Falcata/Biting Retort pair).
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
