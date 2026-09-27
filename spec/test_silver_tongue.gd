# SILVER TONGUE (Rakshasa trait, design 1.3, rulings 7-11):
#
#   "1/round, when the Rakshasa misses with a tech attack, it may take 2 heat to reroll the attack
#    against a different target within Sensors and line of sight."
#
# TWO PIECES on the engine's own reroll-against-a-new-target seam (event_unit_attack.gd:308-339, the
# Executioner's No Escape):
#   - buff_silver_tongue: to = REROLL_MISS_AGAINST_NEW_TARGET, NOT onetime (ruling 9), so the engine
#     never consumes it and a cancelled pick costs nothing. Its gate reads the 1/round off the pay
#     reaction's own usage group, and refuses an AI-controlled holder (ruling 10: choose_unit has no AI
#     answerer).
#   - action_silver_tongue_pay: a hidden ATTACK PRE reaction on the Rakshasa's own REROLLED tech
#     attack (Action.FLAG.WAS_REROLLED_AGAINST_NEW_TARGET). spend_actions pays its self_heat of 2 and
#     spends the round - so both land only when the reroll actually runs.
#
# THE TARGET SET IS READ OFF THE PROMPT (responder.unit_prompts), never inferred from where the reroll
# landed: the stock responder picks whatever is first, so a widened set would still "land right".
#
# A MISS IS A TECH MISS ON PURPOSE: the vanilla Invade deals nothing on a miss (memory
# lancer-tactics-spec-harness-traps, the Reliable trap), so every heat number below is the invade's own
# 2 on a HIT, or Silver Tongue's 2 on the Rakshasa.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_silver_tongue.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')

## Wide enough to put a hostile past Sensors 20 on the Rakshasa's own row.
const MAP_SIZE := Vector2i(26, 10)
const RAKSHASA_TILE := Vector2i(2, 4)
const FIRST_TILE := Vector2i(5, 4)
const SECOND_TILE := Vector2i(8, 4)

## Tech attack 0 on the Rakshasa: 19 clears e-defense 8 and is not a crit; 1 cannot.
const HIT := 19
const MISS := 1

var game:Gamemaster
var responder
var rakshasa:Unit
var first:Unit
var second:Unit

func before_each() -> void:
	await get_tree().process_frame # a synchronous test's responder must not answer the next test
	var built:Array = Fixture.create_game_with_prompts(self, MAP_SIZE)
	game = built[0]
	responder = built[1]
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	first = Fixture.create_hostile(game, FIRST_TILE)
	second = Fixture.create_hostile(game, SECOND_TILE)
	# SP2: every Rakshasa turn start now raises the Mask menu, and the responder's default answer (0)
	# is Drain, which adds Impaired and 1 heat to an invade hit - a second effect on the very numbers
	# these tests read. Ensorcel changes nothing an attack does (it is a Scan variant, SP3).
	responder.chosen_multiple_choice_index = Fixture.MODE.ENSORCEL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _gear() -> GearCore: return rakshasa.get_gear(Fixture.SILVER_TONGUE_ID)

func _offered(prompt_index:int = 0) -> Array[Unit]:
	var units:Array[Unit] = []
	if responder.unit_prompts.size() <= prompt_index: return units
	units.assign(responder.unit_prompts[prompt_index].units)
	return units

func _is_invaded(unit:Unit) -> bool:
	return unit.has_status(Lancer.STATUS.IMPAIRED) and unit.has_status(Lancer.STATUS.SLOWED)

# ---------------------------------------------------------------- shape

func test_the_trait_carries_a_hidden_non_onetime_reroll_buff_and_a_pay_reaction():
	var gear := _gear()
	assert_true(GearCore.is_valid(gear), 'The Rakshasa carries Silver Tongue.')
	assert_true(UnitCondition.has_buff(rakshasa, Fixture.SILVER_TONGUE_BUFF), 'Its buff is on the Rakshasa.')
	var buff:Buff = ContentLibrary.get_buff(Fixture.SILVER_TONGUE_BUFF)
	assert_not_null(buff, 'buff_silver_tongue is in the buffs index.')
	if buff != null:
		assert_eq(buff.to, Buff.TO.REROLL_MISS_AGAINST_NEW_TARGET, 'The engine\'s own reroll-against-a-new-target hook.')
		assert_false(buff.is_onetime, 'NOT onetime (ruling 9): the engine never consumes it, so a cancel is free.')
		assert_true(buff.hide_from_player, 'Plumbing, never a chip.')
	if not GearCore.is_valid(gear): return
	var pay = gear.get_action(Fixture.SILVER_TONGUE_PAY)
	assert_not_null(pay, 'The pay reaction is on the Kit.')
	if pay == null: return
	assert_false(pay.consumes_reaction(), 'It spends no reaction point.')
	assert_eq(pay.get_per_round_hard_limit(SpecificAction.create(rakshasa, gear, pay)), 1, '1/round.')
	assert_eq(pay.usage_group, Fixture.SILVER_TONGUE_USAGE, 'On its own usage group.')
	assert_eq(pay.self_heat_dice, '2', 'Its self heat is the card\'s 2.')

# ---------------------------------------------------------------- the reroll

func test_a_missed_invade_rerolled_against_a_second_hostile_lands_on_it():
	responder.unit_queue.assign([second])
	await Fixture.invade(game, rakshasa, first, [MISS, HIT])
	assert_eq(responder.unit_prompts.size(), 1, 'One pick was offered.')
	assert_true(_is_invaded(second), 'The rerolled hit Impaired and Slowed the new target.')
	assert_eq(Fixture.heat(second), 2, 'And dealt the invade\'s own 2 heat to it (ruling 11).')
	assert_false(_is_invaded(first), 'The first target was missed and stays clean.')
	assert_eq(Fixture.heat(first), 0, 'And takes no heat.')
	assert_eq(Fixture.heat(rakshasa), 2, 'The Rakshasa paid 2 heat.')
	assert_eq(Fixture.silver_tongue_uses(rakshasa), 1, 'And spent its round.')

func test_cancelling_the_pick_costs_nothing_and_keeps_the_round():
	responder.unit_queue.assign([null, second])
	await Fixture.invade(game, rakshasa, first, [MISS])
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: the pick was offered, and cancelled.')
	assert_eq(Fixture.heat(rakshasa), 0, 'A cancel costs no heat (ruling 9).')
	assert_eq(Fixture.silver_tongue_uses(rakshasa), 0, 'And no round.')
	assert_false(_is_invaded(second), 'And nothing reached the second hostile.')
	# The positive control in the same round: the next miss is offered again, and this time taken.
	await Fixture.invade(game, rakshasa, first, [MISS, HIT])
	assert_eq(responder.unit_prompts.size(), 2, 'The next miss that round is offered again.')
	assert_true(_is_invaded(second), 'And taken.')
	assert_eq(Fixture.heat(rakshasa), 2, 'Paid once.')

func test_a_second_reroll_in_one_round_is_not_offered():
	responder.unit_queue.assign([second])
	await Fixture.invade(game, rakshasa, first, [MISS, HIT])
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: the first reroll was taken.')
	await Fixture.invade(game, rakshasa, first, [MISS])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the second invade really rolled its d20.')
	assert_eq(responder.unit_prompts.size(), 1, 'The second miss that round is not offered.')
	assert_eq(Fixture.heat(rakshasa), 2, 'And nothing more is paid.')

func test_the_round_resets_at_the_rakshasas_own_turn_start():
	responder.unit_queue.assign([second, second])
	await Fixture.invade(game, rakshasa, first, [MISS, HIT])
	await Fixture.cycle_turn(game, rakshasa)
	await Fixture.invade(game, rakshasa, first, [MISS, HIT])
	assert_eq(responder.unit_prompts.size(), 2, 'A new turn of its own, a new offer (ruling 3).')
	assert_eq(Fixture.heat(rakshasa), 4, 'Paid twice.')

func test_a_reroll_that_misses_is_not_rerolled_again_but_is_still_paid_for():
	responder.unit_queue.assign([second, first])
	await Fixture.invade(game, rakshasa, first, [MISS, MISS])
	assert_eq(responder.unit_prompts.size(), 1, 'One pick: the reroll carries WAS_REROLLED_AGAINST_NEW_TARGET.')
	assert_false(_is_invaded(second), 'The reroll missed.')
	assert_eq(Fixture.heat(rakshasa), 2, 'It still ran, so it was paid for.')

func test_a_hit_is_not_offered():
	await Fixture.invade(game, rakshasa, first, [HIT])
	assert_true(_is_invaded(first), 'fixture: the invade hit.')
	assert_eq(responder.unit_prompts.size(), 0, 'Only a MISS is offered.')
	assert_eq(Fixture.heat(rakshasa), 0, 'Nothing paid.')

func test_a_weapon_miss_is_not_offered():
	# Ruling 7: a TECH attack. The GMS melee against an adjacent hostile, a plain miss.
	Fixture.equip(rakshasa, Fixture.MELEE)
	var adjacent := Fixture.create_hostile(game, RAKSHASA_TILE + Vector2i(0, 1))
	await Fixture.open_turn(game, rakshasa)
	Fixture.queue([MISS])
	await SpecFactory.use_solo(game, rakshasa, Fixture.MELEE, adjacent)
	assert_true(Fixture.d20_was_rolled(), 'fixture: the swing really rolled its d20.')
	assert_eq(responder.unit_prompts.size(), 0, 'A weapon miss is not offered.')
	assert_eq(Fixture.heat(rakshasa), 0, 'Nothing paid.')

func test_an_ai_controlled_rakshasa_is_never_offered():
	# Ruling 10. The same geometry with the sides swapped: the Rakshasa is AI_ENEMY, its targets PLAYER.
	var ai := Fixture.create_rakshasa(game, Vector2i(2, 8), Faction.AI_ENEMY)
	var mark := Fixture.create_hostile(game, Vector2i(5, 8), 8, Faction.PLAYER)
	Fixture.create_hostile(game, Vector2i(8, 8), 8, Faction.PLAYER)
	assert_false(ai.is_player_controlled(), 'fixture: the Rakshasa is AI-controlled.')
	await Fixture.invade(game, ai, mark, [MISS])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade really rolled its d20.')
	assert_eq(responder.unit_prompts.size(), 0, 'No pick: the human would be asked on the AI\'s behalf.')
	assert_eq(Fixture.heat(ai), 0, 'Nothing paid.')

# ---------------------------------------------------------------- the target set

func test_the_target_set_is_every_character_in_sensors_and_sight_drone_included_but_not_the_first_target():
	# Ruling 8: the tech action's own targetable set (Sensors, line of sight) of is_character() units
	# (a drone included, ruling 2026-09-27), allies included, minus the original target and the Rakshasa.
	var beyond_sensors := Fixture.create_hostile(game, Vector2i(24, 4)) # 22 away: Sensors is 20
	var behind_wall := Fixture.create_hostile(game, Vector2i(2, 8))
	Fixture.raise_wall(game, [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6)] as Array[Vector2i])
	var ally := Fixture.create_ally(game, Vector2i(6, 1))
	var drone := Fixture.create_hostile_drone(game, Vector2i(6, 7))
	UnitTile.update_tracking_and_statuses(game.map)
	responder.unit_queue.assign([null])
	await Fixture.invade(game, rakshasa, first, [MISS])
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: the pick was offered.')
	var offered := _offered()
	assert_has(offered, second, 'A hostile in Sensors and sight is offered.')
	assert_has(offered, ally, 'An ally is offered too: "a different target" (ruling 8).')
	assert_does_not_have(offered, first, 'Not the target it just missed.')
	assert_does_not_have(offered, rakshasa, 'Not itself.')
	assert_does_not_have(offered, beyond_sensors, 'Not a hostile beyond Sensors.')
	assert_does_not_have(offered, behind_wall, 'Not a hostile out of sight.')
	assert_has(offered, drone, 'A drone is a character too (ruling 2026-09-27).')
	assert_eq(offered.size(), 3, 'Exactly the second hostile, the ally, and the drone.')
	# The two negative controls really are where the test thinks: in range but unseen, and seen but
	# out of range.
	assert_lt(UnitRelation.distance_between(rakshasa, behind_wall), rakshasa.get_sensor_range(),
		'fixture: the hidden hostile is within Sensors, so only sight excludes it.')
	assert_false(UnitRelation.can_see(rakshasa, behind_wall), 'fixture: and the wall does block it.')
	assert_gt(UnitRelation.distance_between(rakshasa, beyond_sensors), rakshasa.get_sensor_range(),
		'fixture: the far hostile is beyond Sensors.')

func test_no_other_character_means_no_offer():
	# check_if_passive_applies's last clause: an empty set offers nothing (vanilla's own rule).
	UnitTile.move_to(second, Vector2i(24, 8)) # past Sensors: the only other character, gone from the set
	await Fixture.invade(game, rakshasa, first, [MISS])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade really rolled its d20.')
	assert_eq(responder.unit_prompts.size(), 0, 'Nobody else in Sensors and sight: nothing to offer.')

# ---------------------------------------------------------------- polled guards
#
# TWO OF THE BUFF'S CLAUSES ARE OVER-DETERMINED IN PLAY, so no behavioural test can redden when either
# is deleted (measured at SP1: both mutations left the eleven tests above green):
#   - the WAS_REROLLED_AGAINST_NEW_TARGET guard: the pay reaction spends the round at the reroll's own
#     ATTACK PRE, so by the time a reroll misses, the round gate refuses it too;
#   - the `is ActionAttackTech` context clause: get_valid_reroll_targets returns [] for a weapon.
# Each still matters on its own - the first the day the round is paid anywhere else, the second the
# day the target set is widened - so they are pinned by POLLING the buff directly (memory
# lancer-tactics-spec-harness-traps, the Sluagh SP1 entry), each with a control half.

func _silver_tongue_core() -> BuffCore:
	for core:BuffCore in rakshasa.state.buffs:
		if core.base.compcon_id == Fixture.SILVER_TONGUE_BUFF: return core
	return null

## A context shaped like the one event_unit_attack hands the reroll hook: a real (missed) AttackRoll
## on `first`, a declared summary, the Rakshasa's own `kit_id` attack.
func _polled_context(kit_id:StringName, flags:Array = []) -> Context:
	var gear:GearCore = rakshasa.get_gear(kit_id)
	var context := Context.create({
		unit = rakshasa, gear = gear, action = gear.get_solo_action(), target_unit = first, map = game.map,
	})
	context.flags = flags
	var roll := AttackRoll.new()
	roll.pre = AttackRoll.PreAttack.new()
	roll.target_unit = first
	roll.hit = false
	context.object = roll
	context.resource = DeclaredAttackSummary.new()
	return context

func test_a_rerolled_attack_is_never_offered_even_with_the_round_unspent():
	var core := _silver_tongue_core()
	assert_not_null(core, 'fixture: the buff is on the Rakshasa.')
	if core == null: return
	assert_eq(Fixture.silver_tongue_uses(rakshasa), 0, 'fixture: the round is unspent.')
	assert_true(core.base.check_if_passive_applies(core, _polled_context(Fixture.TECH)),
		'CONTROL: a plain missed invade is offered.')
	assert_false(core.base.check_if_passive_applies(core,
		_polled_context(Fixture.TECH, [Action.FLAG.WAS_REROLLED_AGAINST_NEW_TARGET])),
		'The same miss on a reroll is not: a non-onetime reroll buff would otherwise roll forever.')

func test_a_weapon_attack_context_is_not_this_buffs_business():
	Fixture.equip(rakshasa, Fixture.MELEE)
	var core := _silver_tongue_core()
	assert_not_null(core, 'fixture: the buff is on the Rakshasa.')
	if core == null: return
	assert_true(core.base.is_buff_context_valid_for_passive(core, _polled_context(Fixture.TECH)),
		'CONTROL: a tech attack context is valid.')
	assert_false(core.base.is_buff_context_valid_for_passive(core, _polled_context(Fixture.MELEE)),
		'A weapon attack context is not (ruling 7).')
