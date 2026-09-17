# REND (Maiden's Blush trait, SP1 Task 3).
#
#   "1/round, whenever the Maiden's Blush critically hits with a melee weapon, the target must make a
#    Hull save. On a failure, they become Impaired and Slowed until the end of their next turn."
#
# There is no crit trigger in the engine: crit effects come through Buff.TO.ONHIT_EFFECT carrying an
# OnHitEffect whose apply_on is the ON_CRIT stage, gathered from get_buffs_to(owner,
# Buff.TO.ONHIT_EFFECT, context). The engine enforces a per-round limit only for ActionReactions
# (reaction_bus.gd:116-124), never for a buff-triggered effect, so the 1/round is hand-rolled the way
# Crack Shot III does it: buff_rend.gd gates on GearCore.get_uses_this_round_alt, and
# onhit_rend.gd increments it.
#
# RULING 14 is the whole point of test_the_second_melee_crit_in_a_round_forces_no_save: the round is
# spent by FORCING the save, pass or fail - not by the target actually taking the statuses. So the
# increment happens in should_abort(), before super() rolls the save. That test lets the FIRST crit's
# save PASS and then proves the SECOND crit in the same round still does nothing, which is the only
# case that fails under the alternative (spend-on-a-failed-save) reading.
#
# CRITS ARE FORCED THROUGH THE ATTACK ROLL, NOT THROUGH HaseBlock. attack_roll.gd computes
# `crit = (total_roll >= 20) and hit and can_crit`, where total_roll is the cheated d20 plus the
# accuracy die. mw_variable_sword is Accurate (attack_accuracy = "1"), so every attack with it pops
# TWO values off Dice.CHEAT_ROLL_QUEUE and the helpers below queue a PAIR.
#
# THE HULL SAVE ITSELF IS PINNED THROUGH HaseBlock, NOT THE DICE QUEUE - the same reasoning as
# test_knock_em_down.gd: the attack ahead of the save pops an unpredictable number of damage dice out
# of the same global queue, so queuing a specific d20 for the save would be guessing how many the
# attack ate first. A hase.hull of +-30 dominates whatever the save's own d20 comes up as.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rend.gd
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')

const TRAIT_ID := &'mt_rend'
const USAGE_KEY := &'rend'

const BLUSH_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4) # adjacent, so every weapon here reaches without moving

var game:Gamemaster
var blush:Unit
var target:Unit

func before_each() -> void:
	game = MaidensBlushFixture.create_game(self)
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	MaidensBlushFixture.equip_melee(blush)
	MaidensBlushFixture.equip_ranged(blush)
	# evasion -10 so every cheated attack here lands; the crit half is the d20's job.
	target = MaidensBlushFixture.create_dummy(game, TARGET_TILE, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func trait_gear() -> GearCore:
	var gear:GearCore = blush.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

func uses_this_round() -> int:
	var gear := trait_gear()
	if gear == null: return -1
	return gear.get_uses_this_round_alt(USAGE_KEY)

## A guaranteed CRIT with the Variable Sword. 30 for the d20 and 6 for its Accurate die: 36, clear of
## the >= 20 crit threshold, and the target's -10 evasion guarantees the hit half. The trailing 6s
## are a buffer against however many damage dice a given shot pops.
##
## CLEARS THE QUEUE FIRST. Dice.cheat_attack only APPENDS, and this file fires more than once per test
## - a leftover buffer 6 from an earlier shot would be handed to the next attack roll as its d20,
## silently turning an intended crit into a plain hit. test_knock_em_down.gd learned this on a real
## run.
func cheat_a_melee_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([30, 6], [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])

## A guaranteed HIT with the Variable Sword that is never a crit: 13 for the d20 and 1 for the
## Accurate die is 14, short of 20, while the target's -10 evasion still guarantees hit = true. Both
## values are queued rather than trusting the die to roll low.
func cheat_a_melee_hit_no_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([13, 1], [6, 6, 6, 6, 6, 6, 6, 6])

## A guaranteed CRIT with a weapon that carries no accuracy modifier - the assault rifle and the
## Improvised Attack both. Only the d20 is queued; if some future modkit gave one of them an accuracy
## die it would eat a 6 from the buffer, which is also a 6, so the crit holds either way.
func cheat_an_unmodified_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([30], [6, 6, 6, 6, 6, 6, 6, 6])

func force_save_to_fail() -> void:
	target.core.frame.hase = HaseBlock.create(-30, 0, 0, 0)
	target.core.full_repair()

func force_save_to_pass() -> void:
	target.core.frame.hase = HaseBlock.create(30, 0, 0, 0)
	target.core.full_repair()

func strike(kit_id:StringName) -> void:
	await MaidensBlushFixture.open_turn(game, blush)
	await SpecFactory.use_solo(game, blush, kit_id, [target])

# ---------------------------------------------------------------- the wiring

func test_the_trait_and_its_buff_are_shaped_right():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_rend is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_true(kit.actions.is_empty(), 'It carries no action - it is a pure passive.')
	assert_eq(kit.passives.size(), 1, 'One passive: the buff applicator.')
	var buff:Buff = ContentLibrary.get_buff(&'buff_rend')
	assert_not_null(buff, 'buff_rend is in the buffs index.')
	if buff == null: return
	assert_true(buff is BuffWeaponTypeOnHit, 'It is a BuffWeaponTypeOnHit.')
	assert_eq(buff.to, Buff.TO.ONHIT_EFFECT, 'It supplies an on-hit effect.')
	assert_true(buff.hide_from_player, 'And it is trait plumbing, never a chip on the unit.')
	assert_eq(buff.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE],
		'MELEE only.')
	assert_false(buff.allow_basic,
		'Basic gear is excluded (ruling 12): Ram, Grapple and the Improvised Attack never Rend.')

func test_the_effect_row_resolves():
	assert_ne(X.tr('gear.mt_rend.name'), 'gear.mt_rend.name', 'The trait is named.')
	assert_ne(X.tr('gear.mt_rend.effect'), 'gear.mt_rend.effect', 'It has rule text.')

# ---------------------------------------------------------------- the trait

func test_a_melee_crit_forces_a_hull_save_and_a_failure_lands_impaired_and_slowed():
	force_save_to_fail()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)

	assert_gt(target.current_damage(), 0, 'Fixture: the sword landed.')
	assert_true(target.has_status(Lancer.STATUS.IMPAIRED), 'The failed save left it Impaired...')
	assert_true(target.has_status(Lancer.STATUS.SLOWED), '...and Slowed. One save, both statuses.')
	assert_eq(uses_this_round(), 1, 'Rend spent its 1/round.')

func test_both_statuses_expire_at_the_end_of_the_targets_next_turn():
	# The card says "until the end of their next turn", and that is exactly StatusType's own standard
	# duration for both: status_impaired.tres and status_slowed.tres each carry standard_until = 1
	# (END_OF_NEXT_TURN), and OnHitEffect.apply_statuses_and_buffs lands them with
	# StatusType.get_standard_until (on_hit_effect.gd:82, :91-92). Nothing in our .tres sets a
	# duration, and this is the test that says the engine's default really is the card's.
	force_save_to_fail()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)
	assert_true(target.has_status(Lancer.STATUS.IMPAIRED), 'Fixture: Impaired landed.')

	# The target's own turn START converts END_OF_NEXT_TURN to END_OF_THIS_TURN
	# (unit_condition.gd:17-19); its turn END is what clears it.
	await SpecFactory.start_turn(game, target)
	assert_true(target.has_status(Lancer.STATUS.IMPAIRED),
		'Still Impaired through its next turn - the card gives it the whole turn.')
	await SpecFactory.end_turn(game, target)
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED), 'Gone at the end of that turn.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'And so is Slowed.')

func test_a_passed_save_applies_nothing_and_still_spends_the_round():
	force_save_to_pass()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)

	assert_gt(target.current_damage(), 0,
		'Fixture: the sword still landed, so the save is what spared it and not a miss.')
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED), 'A passed Hull save applies nothing.')
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'Neither status.')
	# Without this the test would pass identically if the trait never fired at all - a passed save and
	# "never triggered" both leave the target clean. The counter is what proves the save was forced.
	assert_eq(uses_this_round(), 1, 'Rend still spent its 1/round, because the trigger is the crit.')

func test_the_second_melee_crit_in_a_round_forces_no_save():
	# RULING 14. The first crit's save PASSES on purpose: if the round were spent only by a FAILED
	# save, this pass would leave the 1/round untouched and the second crit below would be free to
	# force (and fail) its own.
	force_save_to_pass()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)
	assert_eq(uses_this_round(), 1, 'Fixture: the first crit spent the round despite the passed save.')

	force_save_to_fail()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED),
		'The second crit in the same round forces nothing: the 1/round was already spent.')
	assert_eq(uses_this_round(), 1, 'And the counter did not move again.')

func test_a_melee_hit_that_is_not_a_crit_forces_nothing():
	force_save_to_fail() # would guarantee both statuses if a save were forced
	cheat_a_melee_hit_no_crit()
	await strike(MaidensBlushFixture.MELEE_ID)

	assert_gt(target.current_damage(), 0, 'Fixture: the sword landed.')
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED), 'A hit that is not a crit does nothing.')
	assert_eq(uses_this_round(), 0, 'And spends no round either.')

func test_a_ranged_crit_forces_nothing():
	force_save_to_fail()
	cheat_an_unmodified_crit()
	await strike(MaidensBlushFixture.RANGED_ID)

	assert_gt(target.current_damage(), MaidensBlushFixture.RELIABLE_ON_MISS,
		'Fixture: the rifle shot landed - more than its Reliable 2, so it really hit.')
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED),
		'A crit with a weapon that is not MELEE does nothing: the weapon_types gate holds.')
	assert_eq(uses_this_round(), 0,
		'The rifle crit never even reached the buff - the gate is on weapon_types, not a fluke of'
		+ ' damage.')

func test_an_improvised_attack_crit_forces_nothing():
	# RULING 12. The Improvised Attack IS weapon_type MELEE, so weapon_types alone would let it
	# through; what refuses it is BuffWeaponType.allow_basic defaulting to false
	# (buff_weapon_type.gd:52, loadout_core.gd:414). Without this test that default is invisible, and
	# a Ram before the real strike would burn the round.
	MaidensBlushFixture.equip_basic_melee(blush)
	force_save_to_fail()
	cheat_an_unmodified_crit()
	await strike(MaidensBlushFixture.BASIC_MELEE_ID)

	assert_gt(target.current_damage(), 0, 'Fixture: the improvised attack landed.')
	assert_false(target.has_status(Lancer.STATUS.IMPAIRED), 'Basic melee does not Rend.')
	assert_eq(uses_this_round(), 0, 'And spends no round.')

func test_a_crit_on_a_non_character_forces_nothing_and_leaves_the_round_unspent():
	# event_unit_attack.gd's apply_on_crits is reached for ANY valid target unit, character or not -
	# it only checks is_character() two lines later, for the crit bark. So without onhit_rend's own
	# gate, a melee crit on a destructible object would spend the 1/round and force a save that can do
	# nothing.
	#
	# The target here is the SAME fixture unit as every other test, just re-flagged as an OBJECT, so it
	# stays valid, active, hostile and hittable; only is_character() flips.
	target.core.frame.entity_type = Frame.ENTITY.OBJECT
	target.core.full_repair()
	assert_false(target.is_character(), 'fixture: the target is no longer a character.')
	force_save_to_fail()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot still landed and crit.')
	# THE COUNTER IS THE CLAIM, not the statuses. A non-character cannot end up Impaired whether or not
	# this gate exists - unit_hasecheck auto-fails a non-character's save without rolling and
	# UnitCondition makes it immune - so the status assertion would read green against a version of the
	# trait with the gate torn out.
	assert_eq(uses_this_round(), 0,
		'Rend does not spend its round on a non-character: the is_character() gate refused before it'
		+ ' ever incremented.')

func test_the_counter_clears_at_the_blushs_own_next_turn_start():
	# "1/round" is the per-ROUND counter, and UnitAction.new_turn_refresh resets it inside
	# handle_starting_unit - for the STARTING unit only. So it is per turn in truth (the Myconid's
	# ruling 5), and somebody else's turn start must not clear it. Both halves are asserted, because
	# the negative is what makes the positive mean something.
	force_save_to_pass()
	cheat_a_melee_crit()
	await strike(MaidensBlushFixture.MELEE_ID)
	assert_eq(uses_this_round(), 1, 'Fixture: the round is spent.')

	await SpecFactory.start_turn(game, target)
	assert_eq(uses_this_round(), 1, 'Another unit starting its turn does NOT give the round back.')
	await SpecFactory.end_turn(game, target)

	await SpecFactory.end_turn(game, blush)
	await SpecFactory.start_turn(game, blush)
	assert_eq(uses_this_round(), 0, 'The Blush\'s own turn start does.')
