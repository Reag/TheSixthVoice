## SHIMMERING BLADE, the Naga's rank-I weapon (SP2 Task 1, design ruling 9).
##
## "Main Melee, SP 1. THROWN 5, SMART. 1d6 Kinetic, Threat 1. On crit: Gain 2 Overshield, your target
##  must succeed on a Systems save or become Slowed until the end of their next turn."
##  (specs/sixth-voice/10-naga.md, Rank I)
##
## DICE ORDER on a crit: the attack d20, then the SAVE's d20 (on_crit runs inside event_unit_attack,
## before any damage is rolled - event_unit_attack.gd:91 against event_unit_attack_declared's damage
## stage), then the damage dice. A Smart melee weapon with no accuracy modifier pops no accuracy die.
## The fixture's tail of 1s feeds the damage.
##
## THE SAVE IS ROLLED BY HAND, NOT THROUGH save_to_avoid - the one departure from ruling 9's wiring,
## and test_a_passed_save_still_leaves_the_shield is what pins it: OnHitEffect.should_abort returns
## true on a passed save at the effect's own stage (on_hit_effect.gd:66-70), which skips on_crit
## entirely, so a declarative save would take the Overshield away with the Slowed.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'mw_shimmering_blade'
const SHIELD := 2

const NAGA_TILE := Vector2i(4, 4)    # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(6, 4)  # adjacent to the Naga's east edge - inside Threat 1
const THROW_TILE := Vector2i(10, 4)  # exactly 5 from the Naga's east edge - Thrown 5, not Threat 1
const TARGET_EDEF := 8
const TARGET_EVASION := 15            # far above E-DEF, so a roll against the wrong one misses

const SAVE_FAILS := 1
const SAVE_PASSES := 20

var game:Gamemaster
var naga:Unit
var target:Unit
var blade:GearCore


func before_each() -> void:
	game = NagaFixture.create_game(self)
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE, TARGET_EVASION)
	NagaFixture.set_edef(target, TARGET_EDEF)
	blade = NagaFixture.equip(naga, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


## One swing, the ATC spec's `fire` shape: a real event_gear_activate so the DeclaredAttackSummary
## comes back and the roll itself can be read.
func swing(rolls:Array[int], at:Unit = target) -> AttackRoll:
	await NagaFixture.cycle_turn(game, naga)
	NagaFixture.queue(rolls)
	var core := EventCore.create(&'event_gear_activate', {
		action = blade.get_solo_action(), gear = blade, unit = naga, target_unit = at,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	if summary == null or summary.attack_rolls.is_empty():
		fail_test('fixture: the swing made no attack roll.')
		return null
	return summary.attack_rolls[0]


# ---------------------------------------------------------------- wiring

func test_the_blade_is_a_main_melee_smart_thrown_weapon() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes the Blade under its mw_ id.')
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	var attack := kit.actions[0] as ActionAttackWeapon
	assert_not_null(attack, 'Its one action is an ActionAttackWeapon.')
	if attack == null: return
	assert_eq(kit.actions.size(), 1, 'One profile.')
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.damage_dice, '1d6', '1d6...')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.KINETIC, '...Kinetic.')
	assert_eq(attack.threat, 1, 'Threat 1.')
	assert_eq(attack.thrown, 5, 'Thrown 5.')
	assert_eq(attack.tags, [&'thrown', &'smart'] as Array[StringName], 'THROWN and SMART, in the card order.')

func test_the_licence_grants_the_blade_at_rank_1() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_1.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'li_naga rank 1 grants the Shimmering Blade.')

func test_the_rows_resolve_through_the_mods_translation() -> void:
	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	assert_eq(String(translation.get_message('gear.mw_shimmering_blade.name')), 'Shimmering Blade')
	for key:String in ['gear.mw_shimmering_blade.flavor', 'gear.mw_shimmering_blade.on_crit']:
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)


# ---------------------------------------------------------------- the crit

func test_a_natural_20_shields_the_naga_and_a_failed_save_slows() -> void:
	var roll := await swing([20, SAVE_FAILS])
	if roll == null: return
	assert_true(roll.crit, 'LIVENESS: a natural 20 crits.')
	assert_eq(Overshield.current(naga), SHIELD, 'The Naga gains 2 Overshield.')
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'A failed Systems save: the target is Slowed.')

func test_a_passed_save_still_leaves_the_shield() -> void:
	var roll := await swing([20, SAVE_PASSES])
	if roll == null: return
	assert_true(roll.crit, 'LIVENESS: a natural 20 crits.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'A passed save: no Slowed.')
	assert_eq(Overshield.current(naga), SHIELD,
		'...but the shield stands - it is the Naga\'s, not the target\'s to save against.')

func test_the_slow_lasts_to_the_end_of_the_targets_next_turn() -> void:
	var roll := await swing([20, SAVE_FAILS])
	if roll == null: return
	await SpecFactory.end_turn(game, naga)
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'Still Slowed after the NAGA\'s turn ends.')
	await SpecFactory.start_turn(game, target)
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'Still Slowed through the target\'s own turn...')
	await SpecFactory.end_turn(game, target)
	assert_false(target.has_status(Lancer.STATUS.SLOWED), '...and gone when that turn ends ("their next turn").')

func test_an_18_crits_through_advanced_targeting_calculations() -> void:
	assert_true(UnitCondition.has_buff(naga, NagaFixture.ATC_CHIP), 'fixture: the Naga carries the ATC chip.')
	var roll := await swing([18, SAVE_FAILS])
	if roll == null: return
	assert_true(roll.crit, 'A Smart 18 is a crit on this frame (ruling 3).')
	assert_eq(Overshield.current(naga), SHIELD, 'So the Blade\'s crit clause fires on it.')
	assert_true(target.has_status(Lancer.STATUS.SLOWED), 'Save and Slowed included.')

func test_a_plain_hit_does_neither() -> void:
	var roll := await swing([12])
	if roll == null: return
	assert_true(roll.hit, 'LIVENESS: 12 against E-DEF 8 hits.')
	assert_false(roll.crit, '...and is no crit.')
	assert_eq(Overshield.current(naga), 0, 'No shield on a plain hit.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'No save, no Slowed.')

func test_a_miss_does_neither() -> void:
	var roll := await swing([1])
	if roll == null: return
	assert_false(roll.hit, 'LIVENESS: a 1 misses.')
	assert_eq(Overshield.current(naga), 0, 'No shield.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'No Slowed.')


# ---------------------------------------------------------------- Smart, Thrown

func test_the_blade_rolls_against_e_defense() -> void:
	var roll := await swing([12])
	if roll == null: return
	assert_eq(roll.pre.against, AttackRoll.ATTACK_TYPE.TECH, 'SMART: rolled against E-DEF...')
	assert_eq(roll.pre.target_defense, TARGET_EDEF, '...the target\'s 8, not its Evasion 15.')

func test_a_throw_at_range_5_crits_and_shields() -> void:
	var far := NagaFixture.create_hostile(game, THROW_TILE, TARGET_EVASION)
	NagaFixture.set_edef(far, TARGET_EDEF)
	assert_eq(UnitRelation.distance_between(naga, far), 5, 'fixture: the far target is exactly 5 away.')
	await NagaFixture.cycle_turn(game, naga)
	NagaFixture.queue([20, SAVE_FAILS])
	await SpecFactory.use_solo(game, naga, KIT_ID, far, [], 'thrown')
	assert_false(blade.is_thrown_retrieved, 'LIVENESS: the Blade left the Naga\'s hand (a throw).')
	assert_eq(Overshield.current(naga), SHIELD, 'The thrown crit shields the THROWER.')
	assert_true(far.has_status(Lancer.STATUS.SLOWED), 'And the far target saves or is Slowed.')
