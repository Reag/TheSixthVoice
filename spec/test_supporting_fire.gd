# SUPPORTING FIRE (Hazard, cp_int_type_command_systems - the core passive) - SP1 Task 4, rulings 4-5:
#
#   "1/round, when an adjacent allied character starts their turn, you may choose to give the first
#    attack they make +1 Accuracy. Until the end of your next turn, the next attack you make has +1
#    Difficulty."
#
# THE ROLLS. Every pilot here is Grit 0 and every target evasion 10, and no WoF bonus applies (the
# Hazard's Grit 0), so the d20 decides alone. An accuracy or difficulty d6 is popped right after the
# d20 and before the damage die: [7, 6, 5] HITS for 5 with +1 Accuracy (7 + 6 = 13) and MISSES for the
# rifle's Reliable 2 without it; [13, 6, 5] MISSES for 2 with +1 Difficulty (13 - 6 = 7) and HITS for
# 6 without it (the 6 is then the damage die).
#
# The ally's attacks are fired INSIDE its open turn (use_solo, then AS_FREEBIE for the second), never
# through Fixture.shoot, which cycles the turn - and the ally's +1 ends with its own turn.
#
# The House Guard pin (the widening reaches the trigger) lives in test_compat.gd.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_supporting_fire.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const HAZARD_TILE := Vector2i(4, 6)
const ADJACENT := Vector2i(5, 6)
const OTHER_ADJACENT := Vector2i(3, 6)
const TWO_OUT := Vector2i(6, 6)
const TARGET_TILE := Vector2i(9, 6)

var game:Gamemaster
var responder
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func uses() -> int:
	return Fixture.uses_this_round(hazard, Fixture.CORE_ID, Fixture.SUPPORTING_FIRE_ID)

func offers() -> int:
	return responder.yesno_prompts.size()

func start(unit:Unit) -> void:
	await SpecFactory.start_turn(game, unit)

func finish(unit:Unit) -> void:
	await SpecFactory.end_turn(game, unit)

## The ally's rifle shot inside its own open turn; `again` fires the second as a freebie.
func ally_fires(ally:Unit, rolls:Array[int], again:bool = false) -> void:
	Fixture.queue(rolls)
	await SpecFactory.use_solo(game, ally, Fixture.MAIN_RIFLE, hostile, [Action.FLAG.AS_FREEBIE] if again else [])

# ---------------------------------------------------------------- the offer

func test_an_adjacent_allys_turn_start_offers_and_yes_hangs_both_buffs():
	var ally := Fixture.create_ally(game, ADJACENT)
	await start(ally)
	assert_eq(offers(), 1, 'One offer at the adjacent ally\'s turn start.')
	assert_true(UnitCondition.has_buff(ally, Fixture.SF_BUFF), 'Yes: the ally carries +1 Accuracy.')
	assert_true(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'And the Hazard the +1 Difficulty.')
	assert_eq(uses(), 1, 'The use is recorded.')

func test_declining_spends_nothing_and_a_later_ally_is_offered_again():
	var ally := Fixture.create_ally(game, ADJACENT)
	var other := Fixture.create_ally(game, OTHER_ADJACENT)
	responder.yesno_queue.assign([false, true])
	await start(ally)
	assert_false(UnitCondition.has_buff(ally, Fixture.SF_BUFF), '"may": no.')
	assert_false(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'No price either.')
	assert_eq(uses(), 0, 'Nothing spent.')
	await finish(ally)
	await start(other)
	assert_eq(offers(), 2, 'The next ally that round is offered again.')
	assert_true(UnitCondition.has_buff(other, Fixture.SF_BUFF), 'And takes it.')

func test_the_second_offer_in_a_round_never_comes():
	var ally := Fixture.create_ally(game, ADJACENT)
	var other := Fixture.create_ally(game, OTHER_ADJACENT)
	await start(ally)
	await finish(ally)
	await start(other)
	assert_eq(offers(), 1, '1/round: the second adjacent ally is not offered.')
	assert_false(UnitCondition.has_buff(other, Fixture.SF_BUFF), 'And gets nothing.')

func test_the_hazards_own_turn_start_rearms_it():
	var ally := Fixture.create_ally(game, ADJACENT)
	await start(ally)
	await finish(ally)
	await start(hazard)
	await finish(hazard)
	await start(ally)
	assert_eq(offers(), 2, 'The Hazard\'s next turn start re-arms the 1/round.')

func test_the_hazards_own_turn_start_does_not_offer():
	Fixture.create_ally(game, ADJACENT)
	await start(hazard)
	assert_eq(offers(), 0, 'Only an ALLY starting its turn.')

func test_an_ally_two_tiles_out_is_not_offered():
	var far := Fixture.create_ally(game, TWO_OUT)
	await start(far)
	assert_eq(offers(), 0, 'Not adjacent: no offer.')

func test_an_allied_drones_turn_start_is_not_offered():
	var drone := Fixture.create_drone(game, ADJACENT)
	await start(drone)
	assert_eq(offers(), 0, 'A drone has no turn of its own: its NEW_TURN is its owner\'s mirrored one, not an activation.')

func test_a_hostiles_turn_start_is_not_offered():
	var enemy := Fixture.create_hostile(game, ADJACENT)
	await start(enemy)
	assert_eq(offers(), 0, 'Not an ally.')

# ---------------------------------------------------------------- the ally's +1

func test_the_allys_first_attack_has_plus_one_accuracy_and_its_second_does_not():
	var ally := Fixture.create_ally(game, ADJACENT)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	await start(ally)
	await ally_fires(ally, [7, 6, 5])
	assert_eq(hostile.current_damage(), 5, 'The first attack: 7 + the accuracy d6 = 13 hits for 5.')
	assert_false(UnitCondition.has_buff(ally, Fixture.SF_BUFF), 'The +1 is spent on it.')
	await ally_fires(ally, [7, 6, 5], true)
	assert_eq(hostile.current_damage(), 5 + 2, 'The second: 7 misses, Reliable 2.')

func test_an_unused_plus_one_is_gone_at_the_allys_turn_end():
	var ally := Fixture.create_ally(game, ADJACENT)
	await start(ally)
	assert_true(UnitCondition.has_buff(ally, Fixture.SF_BUFF), 'fixture: taken.')
	await finish(ally)
	assert_false(UnitCondition.has_buff(ally, Fixture.SF_BUFF), 'It ends with the ally\'s own turn.')

# ---------------------------------------------------------------- the Hazard's +1 Difficulty

func test_the_hazards_next_attack_rolls_minus_one_and_the_one_after_does_not():
	var ally := Fixture.create_ally(game, ADJACENT)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	await start(ally)
	await finish(ally)
	await start(hazard)
	Fixture.queue([13, 6, 5])
	await SpecFactory.use_solo(game, hazard, Fixture.MAIN_RIFLE, hostile)
	assert_eq(hostile.current_damage(), 2, 'The Hazard\'s next attack: 13 - the difficulty d6 = 7 misses, Reliable 2.')
	assert_false(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'The price is paid.')
	Fixture.queue([13, 6, 5])
	await SpecFactory.use_solo(game, hazard, Fixture.MAIN_RIFLE, hostile, [Action.FLAG.AS_FREEBIE])
	assert_eq(hostile.current_damage(), 2 + 6, 'The one after hits clean for 6.')

func test_an_unpaid_price_lasts_to_the_end_of_the_hazards_next_turn():
	var ally := Fixture.create_ally(game, ADJACENT)
	await start(ally)
	await finish(ally)
	assert_true(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'It survives the ally\'s turn end.')
	await start(hazard)
	assert_true(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'And the Hazard\'s next turn start.')
	await finish(hazard)
	assert_false(UnitCondition.has_buff(hazard, Fixture.SF_COST_BUFF), 'It is gone at the end of that turn.')

# ---------------------------------------------------------------- the AI

func test_an_ai_hazard_always_gives_it():
	var ai_game := Fixture.create_game(self)
	var ai_hazard := SpecFactory.create_unit(ai_game.map, HAZARD_TILE, Faction.AI_ENEMY)
	ai_hazard.core.frame = ContentLibrary.get_mech_frame(Fixture.FRAME_ID)
	SpecFactory.apply_passive_buffs(ai_hazard)
	var ai_ally := Fixture.FitzgeraldFixture.create_dummy(ai_game, ADJACENT, 10, Faction.AI_ENEMY)
	UnitTile.update_tracking_and_statuses(ai_game.map)
	await SpecFactory.start_turn(ai_game, ai_ally)
	assert_true(UnitCondition.has_buff(ai_ally, Fixture.SF_BUFF), 'The AI accepts: its ally carries the +1.')
	assert_true(UnitCondition.has_buff(ai_hazard, Fixture.SF_COST_BUFF), 'And pays for it.')
