# ZWARTE HOOP's spend loop (Grutte Pier SP2). Design rulings 9, 12, 13.
#
#   "On your first attack roll each round, you may expend any number of charges. For each charge
#    expended choose one of the following options: Gain +1 Reliable for the attack. [...] Gain +1
#    KNOCKBACK on the attack. Gain +1 to the attack roll. Increase your Overshield by +1 on hit.
#    Clear +1 heat on hit. You may choose the same option up to twice"
#
# One multiple-choice prompt per charge, at the Pier's ATTACK_DECLARED PRE. Every assertion checks
# the OUTCOME - damage taken, a tile moved to, overshield and heat - not the buff that carries it.
#
# THE TURN IS OPENED BEFORE THE CHARGES ARE SET: the Pier's own turn start runs the gain, which
# replaces the bank without Patience (ruling 8).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_zwarte_hoop_spend.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')
const NativeReliable := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/native_reliable.gd')

## The menu, in order (action_zwarte_hoop_spend.MENU), then Done.
const RELIABLE := 0
const KNOCKBACK := 1
const ATTACK_ROLL := 2
const OVERSHIELD := 3
const HEAT := 4
const DONE := 5

## Line 8, 1d3+1 kinetic, no Reliable, no accuracy: a real multi-target weapon. Each HIT also forces
## a Hull save, which pops its own d20 straight after that roll - hence the save dice interleaved in
## the queues below (the log: "CHEATING roll, popping" inside event_unit_save).
const CANNON := &'mw_magnetic_cannon'
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const PIER_TILE := Vector2i(2, 5)
const TARGET_TILE := Vector2i(5, 5)
const SECOND_TILE := Vector2i(7, 5)

var game:Gamemaster
var responder
var pier:Unit
var target:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	pier = Fixture.create_pier(game, PIER_TILE)
	target = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(pier, Fixture.RIFLE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Open the Pier's turn, then set the bank and the answers - in that order (the header).
func ready_pier(charges:int, answers:Array[int] = []) -> void:
	await Fixture.open_turn(game, pier)
	Fixture.set_charges(pier, charges)
	responder.multiple_choice_queue.assign(answers)

func shoot(unit_target:Unit, kit_id:StringName, dice:Array[int]) -> int:
	var before := unit_target.core.current.health
	await Fixture.attack(game, pier, unit_target, kit_id, dice)
	return before - unit_target.core.current.health

func prompts() -> Array[Dictionary]:
	return responder.multiple_choice_prompts

# ---------------------------------------------------------------- the menu

func test_the_menu_offers_the_five_options_and_done():
	await ready_pier(1, [DONE])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 1, 'Asked once.')
	if prompts().size() != 1: return
	assert_eq(prompts()[0].labels.size(), 6, 'Reliable, Knockback, attack roll, Overshield, heat, Done.')
	for reason:String in prompts()[0].disabled_reasons: assert_eq(reason, '', 'Everything open on a weapon.')
	assert_eq(Fixture.charges(pier), 1, 'Done at once spends nothing.')

func test_done_keeps_the_rest_until_the_turn_ends():
	await ready_pier(3, [RELIABLE, DONE])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(Fixture.charges(pier), 2, 'One spent, two kept.')
	await SpecFactory.end_turn(game, pier)
	assert_eq(Fixture.charges(pier), 0, 'And they lapse at the turn end.')

func test_cancelling_is_done():
	await ready_pier(2, [-1])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 1)
	assert_eq(Fixture.charges(pier), 2)

func test_the_loop_ends_when_the_charges_run_out():
	await ready_pier(2, [ATTACK_ROLL, OVERSHIELD])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 2, 'Two charges, two prompts, no third.')
	assert_eq(Fixture.charges(pier), 0)

func test_a_third_pick_of_one_option_is_refused_and_costs_nothing():
	await ready_pier(5, [RELIABLE, RELIABLE, RELIABLE, DONE])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 4)
	if prompts().size() != 4: return
	assert_ne(prompts()[2].disabled_reasons[RELIABLE], '', 'The third prompt greys Reliable out.')
	assert_eq(prompts()[2].disabled_reasons[KNOCKBACK], '', 'But nothing else.')
	assert_eq(Fixture.charges(pier), 3, 'Two spent; the refused third cost nothing.')

func test_a_tech_attack_greys_out_reliable_and_knockback():
	Fixture.equip(pier, Fixture.INVADE)
	await ready_pier(1, [DONE])
	await Fixture.attack(game, pier, target, Fixture.INVADE, [10])
	assert_eq(prompts().size(), 1)
	if prompts().size() != 1: return
	assert_ne(prompts()[0].disabled_reasons[RELIABLE], '', 'Reliable: not a weapon.')
	assert_ne(prompts()[0].disabled_reasons[KNOCKBACK], '', 'Knockback: not a weapon.')
	assert_eq(prompts()[0].disabled_reasons[ATTACK_ROLL], '', 'The attack roll is open to a tech attack.')
	assert_eq(prompts()[0].disabled_reasons[OVERSHIELD], '')
	assert_eq(prompts()[0].disabled_reasons[HEAT], '')

# ---------------------------------------------------------------- first attack roll each round (ruling 9)

func test_the_second_attack_of_the_round_is_not_offered():
	await ready_pier(3, [DONE])
	await shoot(target, Fixture.RIFLE, [10, 6])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 1, 'Only the first attack roll of the round.')

func test_a_first_attack_with_no_charges_still_uses_up_the_first_roll():
	await ready_pier(0)
	await shoot(target, Fixture.RIFLE, [10, 6])
	Fixture.set_charges(pier, 2)
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 0, 'RAW: the first attack roll was the first one, charges or not.')

func test_a_new_round_offers_it_again():
	await ready_pier(3, [DONE, DONE])
	await shoot(target, Fixture.RIFLE, [10, 6])
	await SpecFactory.end_turn(game, pier)
	await Fixture.new_round(game)
	await ready_pier(3, [DONE]) # the new turn's gain replaced the bank (ruling 8)
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 2)

func test_an_ai_controlled_pier_never_asks():
	var ai_pier := Fixture.create_pier(game, Vector2i(2, 9), Faction.AI_ENEMY)
	var mark := Fixture.create_dummy(game, Vector2i(5, 9), -10, Faction.PLAYER)
	Fixture.equip(ai_pier, Fixture.RIFLE)
	await Fixture.open_turn(game, ai_pier)
	Fixture.set_charges(ai_pier, 3)
	await Fixture.attack(game, ai_pier, mark, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 0)
	assert_eq(Fixture.charges(ai_pier), 3)

# ---------------------------------------------------------------- what each pick does (ruling 13)

func test_two_reliable_raise_the_floor_on_a_miss_and_restore_the_export():
	var action:ActionAttackWeapon = ContentLibrary.get_kit(Fixture.RIFLE).actions[0]
	var printed := action.reliable_damage
	await ready_pier(2, [RELIABLE, RELIABLE])
	var taken := await shoot(target, Fixture.RIFLE, [1, 1])
	assert_eq(taken, 4, 'A miss lands Reliable 2 + 2.')
	assert_eq(action.reliable_damage, printed, 'The shared export is restored after the attack.')
	assert_false(NativeReliable.is_raised(action), 'And no raise is left live.')

func test_one_to_the_attack_roll_turns_a_one_short_roll_into_a_hit():
	target.core.frame.stat.evasion = 12
	target.core.full_repair()
	await ready_pier(1, [ATTACK_ROLL])
	var taken := await shoot(target, Fixture.RIFLE, [11, 6])
	assert_eq(taken, 6, '11 + 1 meets Evasion 12: a hit for the full 6.')

func test_the_attack_roll_bonus_reaches_every_target_of_a_multi_target_attack():
	var second := Fixture.create_dummy(game, SECOND_TILE, 12)
	target.core.frame.stat.evasion = 12
	target.core.full_repair()
	Fixture.equip(pier, CANNON)
	await ready_pier(1, [ATTACK_ROLL])
	var before_first := target.core.current.health
	var before_second := second.core.current.health
	Dice.CHEAT_ROLL_QUEUE.append_array([11, 10, 11, 10, 3]) # roll, save, roll, save, damage
	await Fixture.open_turn(game, pier)
	await SpecFactory.use(game, pier, CANNON, ContentLibrary.get_kit(CANNON).actions[0].get_id(), TARGET_TILE)
	assert_eq(before_first - target.core.current.health, 4, 'The first 11 + 1 hits: 1d3+1 = 4.')
	assert_eq(before_second - second.core.current.health, 4, 'And so does the second.')

func test_one_knockback_pushes_a_target_one_space_on_a_weapon_that_has_none():
	await ready_pier(1, [KNOCKBACK])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(target.tile(), TARGET_TILE + Vector2i(1, 0), 'Pushed one space straight away from the Pier.')

func test_overshield_and_heat_land_once_on_a_multi_target_hit():
	var second := Fixture.create_dummy(game, SECOND_TILE)
	Fixture.equip(pier, CANNON)
	await ready_pier(3, [OVERSHIELD, OVERSHIELD, HEAT])
	pier.core.current.heat = 3
	Dice.CHEAT_ROLL_QUEUE.append_array([10, 10, 10, 10, 3]) # roll, save, roll, save, damage
	await SpecFactory.use(game, pier, CANNON, ContentLibrary.get_kit(CANNON).actions[0].get_id(), TARGET_TILE)
	assert_lt(second.core.current.health, 200, 'fixture: the second target was hit too (a 200-HP dummy).')
	assert_eq(Overshield.current(pier), 2, '+2 Overshield, once for the attack, not per target.')
	assert_eq(pier.core.current.heat, 2, '1 heat cleared, once.')

func test_overshield_is_not_granted_on_a_miss():
	target.core.frame.stat.evasion = 30
	target.core.full_repair()
	await ready_pier(1, [OVERSHIELD])
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(Overshield.current(pier), 0, '"on hit".')

# ---------------------------------------------------------------- a reaction attack (ruling 9, measured)

## Overwatch fires the weapon through CommonActionUtil.choose_and_use with these two flags
## (action_overwatch.gd:32-39); this is that activation without the weapon pick.
func overwatch(at:Unit) -> void:
	Dice.CHEAT_ROLL_QUEUE.append_array([10, 6])
	await SpecFactory.use_solo(game, pier, Fixture.RIFLE, at, [Action.FLAG.CAN_FOLLOWUP, Action.FLAG.IS_OVERWATCH])

func test_an_overwatch_before_the_piers_turn_is_the_first_attack_roll():
	Fixture.give_patience(pier) # banked charges are only there before its turn under Patience
	Fixture.set_charges(pier, 3)
	await SpecFactory.start_turn(game, target) # the hostile's turn; the Pier is not taking one
	responder.multiple_choice_queue.assign([ATTACK_ROLL, DONE])
	await overwatch(target)
	assert_eq(prompts().size(), 2, 'The loop runs on the reaction attack.')
	assert_eq(Fixture.charges(pier), 2)
	await SpecFactory.end_turn(game, target)
	await Fixture.open_turn(game, pier)
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 2, 'Its own later attack that round is not the first.')

# ---------------------------------------------------------------- close review (2026-09-25)

## An attack a reaction cancels never reaches the FINISH_DAMAGE clear: the Gorgon's Basilisk aborts the
## DECLARED event from ATTACK PRE (action_extrude_basilisk_reaction.gd:40), and execute() returns at
## event_unit_attack_declared.gd:68, before :203-205. The picks must not outlive the attack.
func test_an_attack_a_reaction_cancels_leaves_no_pick_on_the_pier():
	var basilisk_id := &'cp_basilisk_directed_anticognition_hyperfractal'
	var basilisk := Fixture.equip(target, basilisk_id)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), target, &'buff_extrude_basilisk', basilisk)
	await ready_pier(3, [ATTACK_ROLL, ATTACK_ROLL, KNOCKBACK])
	var taken := await shoot(target, Fixture.RIFLE, [1, 10, 6]) # the Pier's Systems save: a 1
	assert_true(pier.has_status(Lancer.STATUS.STUNNED), 'fixture: the Basilisk cancelled the attack.')
	assert_eq(taken, 0, 'fixture: nothing landed.')
	assert_eq(UnitCondition.get_buffs_to(pier, Buff.TO.ATTACK_ROLL).size(), 0, 'No +attack roll left for a later attack.')
	assert_eq(UnitCondition.get_buffs_to(pier, Buff.TO.EXTRA_KNOCKBACK).size(), 0, 'No +Knockback either.')

## "On your first attack ROLL each round": a Line fired at bare ground rolls nothing (one roll per
## attacked unit, event_unit_attack_declared.gd:53-66), so it neither asks nor uses up the round.
func test_an_attack_that_rolls_nothing_is_not_the_first_attack_roll():
	Fixture.equip(pier, CANNON)
	await ready_pier(2, [DONE])
	responder.yesno_queue.assign([true]) # confirm_aoe_no_targets
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 3])
	await SpecFactory.use(game, pier, CANNON, ContentLibrary.get_kit(CANNON).actions[0].get_id(), PIER_TILE + Vector2i(0, 3))
	assert_eq(prompts().size(), 0, 'Nothing rolled, nothing asked.')
	Dice.CHEAT_ROLL_QUEUE.clear()
	await shoot(target, Fixture.RIFLE, [10, 6])
	assert_eq(prompts().size(), 1, 'The rifle shot is the first attack roll of the round.')

func test_the_range_row_is_offered_on_a_reaction_attack_too():
	Fixture.set_charges(pier, 2)
	var gear := pier.get_gear(Fixture.RIFLE)
	var specific := SpecificAction.create(pier, gear, gear.get_solo_action())
	var keys:Array = specific.action.get_alternate_actions(specific, [Action.FLAG.CAN_FOLLOWUP, Action.FLAG.IS_OVERWATCH]).map(
		func(group:VariantActionGroup) -> StringName: return group.key)
	assert_has(keys, &'zwarte_hoop_range', 'MEASURED: the variant row reads no flags, so an Overwatch offers it.')
