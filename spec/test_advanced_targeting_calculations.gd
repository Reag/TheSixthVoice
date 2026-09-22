## ADVANCED TARGETING CALCULATIONS (Naga trait, design 1.3, rulings 2-5):
##   "The Naga's Smart weapons Critically Hit on an attack roll of 18 or higher rather than 20."
##
## The production spec for mt_advanced_targeting_calculations. It RETIRES the Spike 6 probe
## (test_spike_crit_threshold.gd), whose in-file Crit18 stand-in was this same class - both would
## apply at once if the probe stayed. The seam is the one the probe measured: attack_roll.gd:73
## decides a crit on a class_name RefCounted no extension reaches, but EventUnitAttack.prospective_hit
## (event_unit_attack.gd:196-210) re-asks every MODIFY_ATTACK_ROLL buff at
## SEQUENCE_STEP.turn_hit_to_crit with the AttackRoll in context.object and the weapon in
## context.action, and a confirmation re-routes the roll through prospective_crit. The production
## buff (buff_advanced_targeting_calculations.gd) is a permanent, visible attacker-side
## BuffModifyAttackRoll gated on ActionAttackWeapon + has_tag(SMART, context) + total_roll >= threshold.
##
## WHAT EACH TEST PROVES:
##   a. vanilla control, a shooter WITHOUT the trait: an 18 hits and is no crit, a 20 crits
##   b. the Naga's Nexus (Smart) crits on an 18 and on a 19
##   c. the threshold is exact: a Smart 17 is a plain hit
##   d. the Smart gate is live: a NON-Smart rifle 18 is a plain hit
##   e. never a crit out of a miss: an 18 against E-DEF 19 stays a miss (the step is a step of
##      prospective_HIT, :205, so a miss is never asked)
##   f. permanence: a trait buff is not is_onetime, so consume_buffs (unit_condition.gd:938) keeps it
##      and a second 18 crits again, the chip still on the Naga between the two shots
##   g. CRIT_IMMUNITY on the target still demotes the crit (prospective_crit :222-223 runs after us)
##   h. "Smart" is the LIVE tag set (ruling 3): a rifle made Smart by a Buff.TO.WEAPON_TAG grant
##      (BuffWeaponTypeTag; get_weapon_tags merges those at action_attack_weapon.gd:165-170) crits on 18
##   i. wiring: the Kit is a trait on the live Naga, the chip is on it and visible, threshold reads 18,
##      and the four CSV rows resolve through the mod's own compiled translation
##
## LIVENESS: the Naga has pilot licence level 0, so grit is 0 (pilot_core.gd:204) and a Smart weapon
## adds no tech-attack flat bonus (calculate_flat_bonus reads `using`, WEAPON for a weapon); no
## accuracy die is rolled without a modifier. So total_roll == the cheated d20, and fire() asserts
## that on every shot - a silent flat bonus cannot fake a threshold.
##
## MUTATION: threshold = 20 in buff_advanced_targeting_calculations.tres -> b (both), f and h RED.
##
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_advanced_targeting_calculations.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const NAGA_TILE := Vector2i(4, 4)    # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(9, 4)  # inside Range 10
const CONTROL_TILE := Vector2i(4, 8) # the trait-less control shooter, (a) only
const TARGET_EDEF := 8
const EDEF_THAT_ONLY_A_19_BEATS := 19

## Regenerative Shielding's crit immunity is a BARE Buff with to = &'crit_immunity' and no gate
## (npcf_regenerative_shielding_aegis.tres); this is that, in code. NOT the Defense Net one, which is
## gated on its owner's distance and never applies with no from_gear (the spike measured it).
class CritImmunity extends Buff:
	func _init() -> void:
		compcon_id = &'buff_spec_atc_crit_immunity'
		to = Buff.TO.CRIT_IMMUNITY

## Some other effect making every weapon Smart - the shape of a mod, Smart Ammo, or the mod's own
## Hypnotize grant (SP2). allow_basic so nothing about the loadout slot can gate it out.
class GrantSmart extends BuffWeaponTypeTag:
	func _init() -> void:
		compcon_id = &'buff_spec_atc_grant_smart'
		to = Buff.TO.WEAPON_TAG
		added_tag = Lancer.WEAPON_TAG.SMART
		allow_basic = true

var game:Gamemaster
var naga:Unit
var target:Unit


func before_each() -> void:
	game = NagaFixture.create_game(self)
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE)
	NagaFixture.set_edef(target, TARGET_EDEF)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## Cycle the shooter's turn (the per-turn soft limit silently swallows a second shot), cheat
## [d20] + a tail of 1s, run ONE event_gear_activate for the weapon's solo action at the target, and
## return the AttackRoll off the DeclaredAttackSummary the event leaves in context.resource.
func fire(shooter:Unit, weapon:GearCore, d20:int) -> AttackRoll:
	await NagaFixture.cycle_turn(game, shooter)
	NagaFixture.queue([d20])
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = target,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	assert_not_null(summary, 'fixture: the shot resolved to a DeclaredAttackSummary.')
	if summary == null or summary.attack_rolls.is_empty():
		fail_test('fixture: no attack roll was made.')
		return null
	var roll:AttackRoll = summary.attack_rolls[0]
	assert_eq(roll.total_roll, d20,
		'LIVENESS: total_roll is the cheated d20 - no flat bonus, no accuracy die.')
	return roll

func is_smart_for_this_shot(weapon:GearCore) -> bool:
	var action:ActionAttackWeapon = weapon.get_solo_action()
	return action.has_tag(Lancer.WEAPON_TAG.SMART, Context.create({
		unit = naga, gear = weapon, action = action, target_unit = target,
	}))


# ===================== a. vanilla control =====================

func test_vanilla_control_without_the_trait_18_hits_and_20_crits() -> void:
	var shooter := SpecFactory.create_unit(game.map, CONTROL_TILE)
	shooter.core.full_repair()
	assert_false(UnitCondition.has_buff(shooter, NagaFixture.ATC_CHIP),
		'CONTROL: the plain shooter does not carry the chip.')
	var nexus := NagaFixture.arm_nexus(shooter)
	var eighteen := await fire(shooter, nexus, 18)
	if eighteen == null: return
	assert_true(eighteen.hit, 'An 18 against E-DEF 8 hits...')
	assert_false(eighteen.crit, '...and is NOT a crit under vanilla (attack_roll.gd:73).')
	var twenty := await fire(shooter, nexus, 20)
	if twenty == null: return
	assert_true(twenty.crit, 'CONTROL: a 20 is a crit with no trait in play.')


# ===================== b. the seam =====================

func test_the_nagas_smart_18_is_a_crit() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	var roll := await fire(naga, nexus, 18)
	if roll == null: return
	assert_true(roll.hit, 'It hits...')
	assert_true(roll.crit,
		'...AND IT IS A CRIT: turn_hit_to_crit re-routed the Smart 18 through prospective_crit.')

func test_the_nagas_smart_19_is_a_crit() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	var roll := await fire(naga, nexus, 19)
	if roll == null: return
	assert_true(roll.crit, 'A Smart 19 is a crit too - "18 or higher".')


# ===================== c. the threshold is exact =====================

func test_the_nagas_smart_17_is_a_plain_hit() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	var roll := await fire(naga, nexus, 17)
	if roll == null: return
	assert_true(roll.hit, 'A 17 hits...')
	assert_false(roll.crit, '...and is not a crit: the threshold is 18, not "any hit".')


# ===================== d. the Smart gate =====================

func test_the_nagas_non_smart_18_is_a_plain_hit() -> void:
	var rifle := NagaFixture.arm_rifle(naga)
	assert_false(is_smart_for_this_shot(rifle),
		'fixture: the assault rifle is not Smart for this shot (live tag set, per-target context).')
	var roll := await fire(naga, rifle, 18)
	if roll == null: return
	assert_true(roll.hit, 'The rifle hits on an 18...')
	assert_false(roll.crit, '...and does not crit: the chip reads the weapon, and it is not Smart.')


# ===================== e. never a crit out of a miss =====================

func test_the_nagas_smart_18_that_misses_stays_a_miss() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	NagaFixture.set_edef(target, EDEF_THAT_ONLY_A_19_BEATS)
	var roll := await fire(naga, nexus, 18)
	if roll == null: return
	assert_eq(roll.pre.target_defense, EDEF_THAT_ONLY_A_19_BEATS,
		'LIVENESS: the roll was made against the raised E-DEF (a Smart weapon rolls against E-DEF).')
	assert_false(roll.hit, 'An 18 against 19 misses...')
	assert_false(roll.crit, '...and is no crit: turn_hit_to_crit is a step of prospective_HIT.')


# ===================== f. permanence =====================

func test_the_chip_survives_its_own_use_and_fires_again() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	var first := await fire(naga, nexus, 18)
	if first == null: return
	assert_true(first.crit, 'The first 18 crits.')
	assert_true(UnitCondition.has_buff(naga, NagaFixture.ATC_CHIP),
		'The chip is still on the Naga: consume_buffs keeps only is_onetime buffs '
		+ '(unit_condition.gd:938) and a trait buff is not one.')
	var second := await fire(naga, nexus, 18)
	if second == null: return
	assert_true(second.crit, 'And the second 18 crits again.')
	assert_true(UnitCondition.has_buff(naga, NagaFixture.ATC_CHIP), 'Still there after the second.')


# ===================== g. crit immunity still wins =====================

func test_crit_immunity_on_the_target_demotes_the_trait_crit() -> void:
	var nexus := NagaFixture.arm_nexus(naga)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), target, CritImmunity.new())
	assert_true(UnitCondition.has_buff_to(target, Buff.TO.CRIT_IMMUNITY),
		'fixture: the target holds a live CRIT_IMMUNITY buff.')
	var roll := await fire(naga, nexus, 18)
	if roll == null: return
	assert_true(roll.hit, 'It hits...')
	assert_false(roll.crit,
		'...but CRIT_IMMUNITY demotes it (prospective_crit :222-223 runs AFTER our step), as it would a 20.')


# ===================== h. Smart is the live tag set =====================

func test_a_rifle_made_smart_by_a_weapon_tag_buff_crits_on_18() -> void:
	var rifle := NagaFixture.arm_rifle(naga)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), naga, GrantSmart.new())
	assert_true(UnitCondition.has_buff(naga, &'buff_spec_atc_grant_smart'),
		'fixture: the Naga holds the WEAPON_TAG grant (has_buff_to asks with no weapon in context, so it reads false).')
	assert_true(is_smart_for_this_shot(rifle),
		'LIVENESS: the grant makes the rifle Smart through get_weapon_tags (action_attack_weapon.gd:165-170).')
	var roll := await fire(naga, rifle, 18)
	if roll == null: return
	assert_true(roll.hit, 'The granted-Smart rifle hits on an 18...')
	assert_true(roll.crit, '...and crits: the chip reads the LIVE tag set, not the printed one (ruling 3).')


# ===================== i. wiring =====================

func test_the_trait_is_wired_onto_the_naga_and_localized() -> void:
	var kit := ContentLibrary.get_kit(NagaFixture.ATC_ID)
	assert_not_null(kit, 'ContentLibrary indexes mt_advanced_targeting_calculations as a Kit.')
	if kit == null: return
	assert_true(kit.is_trait, 'It is a trait Kit.')
	assert_true(GearCore.is_valid(naga.get_gear(NagaFixture.ATC_ID)), 'The live Naga carries it as gear.')
	assert_true(UnitCondition.has_buff(naga, NagaFixture.ATC_CHIP),
		'create_naga leaves the chip on the Naga (the PassiveBuffApplicator ran).')

	var chip := ContentLibrary.get_buff(NagaFixture.ATC_CHIP)
	assert_not_null(chip, 'ContentLibrary indexes the chip as a Buff.')
	if chip == null: return
	assert_false(chip.hide_from_player, 'The chip is VISIBLE (ruling 2).')
	assert_eq(chip.get('threshold'), 18, 'threshold reads 18 off the ContentLibrary buff (ruling 4).')

	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	for key:String in [
		'gear.mt_advanced_targeting_calculations.name',
		'gear.mt_advanced_targeting_calculations.effect',
		'gear.buff_advanced_targeting_calculations.name',
		'gear.buff_advanced_targeting_calculations.effect',
	]:
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves through tr().' % key)
	assert_eq(X.tr('gear.mt_advanced_targeting_calculations.name'), 'Advanced Targeting Calculations',
		'The trait name is the card name.')
