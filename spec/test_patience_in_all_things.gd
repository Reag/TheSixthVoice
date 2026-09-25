# PATIENCE IN ALL THINGS (Grutte Pier SP2). Design rulings 14-17.
#
#   "For the rest of the scene you gain the following effects: At the start of your turn, Zwarte Hoop
#    gains 3 additional charges, and you no longer lose charges at the end of your turn. 1/round,
#    when a hostile character in Line of Sight has rolled an attack roll, you may spend any number of
#    charges to reduce the number rolled by that much."
#
# THE PROBE COMES FIRST (design section 2): ruling 17 is the one mechanism in this design nothing in
# the tree had exercised - a BuffModifyAttackRoll hung on a HOSTILE by the Pier's aura, asked about
# that hostile's attack on someone else. "The buff never reached the roll" and "the roll was edited
# but the hit stood" look the same from a meta, so the probe asserts DAMAGE: the rifle is Reliable 2,
# so a hit lands 6 and a miss lands exactly the 2.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_patience_in_all_things.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')

const PIER_TILE := Vector2i(2, 5)
const ALLY_TILE := Vector2i(6, 5)
const HOSTILE_TILE := Vector2i(6, 9)
const ALLY_EVASION := 10
## A 6 on the rifle's 1d6; the Reliable 2 floor is what a miss lands.
const DAMAGE_DIE := 6
const RELIABLE := 2

var game:Gamemaster
var responder
var pier:Unit
var ally:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	pier = Fixture.create_pier(game, PIER_TILE)
	ally = Fixture.create_dummy(game, ALLY_TILE, ALLY_EVASION, Faction.PLAYER)
	hostile = Fixture.create_dummy(game, HOSTILE_TILE)
	Fixture.equip(hostile, Fixture.RIFLE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The hostile shoots the ally with the rifle, rolling `d20` (no accuracy) and a 6 for damage.
## Returns the damage the ally took.
func hostile_shoots(d20:int) -> int:
	var before := ally.core.current.health
	await Fixture.attack(game, hostile, ally, Fixture.RIFLE, [d20, DAMAGE_DIE])
	return before - ally.core.current.health

# ---------------------------------------------------------------- the probe (ruling 17)

func test_probe_a_spend_of_two_turns_an_eleven_into_a_miss():
	Fixture.set_charges(pier, 3)
	Fixture.give_patience(pier)
	assert_true(Fixture.has(hostile, Fixture.PATIENCE_REDUCE),
		'fixture: the aura hung the reduction on the hostile.')
	responder.multiple_choice_queue.assign([0]) # "Spend 2: 9, Miss"
	var taken := await hostile_shoots(11)
	assert_eq(taken, RELIABLE, 'An 11 against Evasion 10, lowered by 2 to a 9, misses: only Reliable 2 lands.')
	assert_eq(Fixture.charges(pier), 1, 'The two charges are spent.')
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'Asked once.')
	if responder.multiple_choice_prompts.size() == 1:
		var labels:PackedStringArray = responder.multiple_choice_prompts[0].labels
		assert_eq(labels.size(), 2, 'Two choices: the least spend that makes it miss, and decline.')
		assert_string_contains(labels[0], '2')
		assert_string_contains(labels[0], '9')

func test_probe_control_declining_lets_the_hit_stand():
	Fixture.set_charges(pier, 3)
	Fixture.give_patience(pier)
	responder.multiple_choice_queue.assign([1]) # decline
	var taken := await hostile_shoots(11)
	assert_eq(taken, DAMAGE_DIE, 'Declined: the 11 hits for the full 6.')
	assert_eq(Fixture.charges(pier), 3, 'Nothing spent.')

# ---------------------------------------------------------------- the protocol (rulings 14, 15)

func test_the_protocol_is_wired():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_not_null(kit)
	if kit == null: return
	var action = kit.get_action(Fixture.PATIENCE_ID)
	assert_not_null(action, 'The Kit carries the protocol.')
	if action == null: return
	assert_eq(kit.actions[0], action, 'actions[0], so get_solo_action() is the protocol.')
	var specific := SpecificAction.from_id(pier, Fixture.CORE_ID, Fixture.PATIENCE_ID)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.PROTOCOL, 'A PROTOCOL.')
	assert_eq(action.consumes_core_power(), 1, 'Costing the core power.')
	assert_eq(action.usage_group, &'patience_in_all_things', 'In its own usage group.')

func test_pressing_it_hangs_the_chip_adds_three_at_once_and_arms_every_hostile():
	await Fixture.press_patience(game, pier)
	assert_true(Fixture.has(pier, Fixture.PATIENCE_BUFF), 'The chip is on the Pier.')
	assert_false(pier.core.has_core_power, 'The core power is spent.')
	assert_eq(Fixture.charges(pier), 3, 'The pressing turn gets its +3 through the kickstart (ruling 15).')
	assert_true(Fixture.has(hostile, Fixture.PATIENCE_REDUCE), 'The hostile carries the reduction.')
	assert_false(Fixture.has(ally, Fixture.PATIENCE_REDUCE), 'An ally does not.')
	assert_false(Fixture.has(pier, Fixture.PATIENCE_REDUCE), 'Nor the Pier.')

func test_the_next_turn_start_adds_three_more():
	await Fixture.press_patience(game, pier)
	await SpecFactory.end_turn(game, pier)
	await SpecFactory.start_turn(game, pier)
	assert_eq(Fixture.charges(pier), 6, '3 kept past the turn end, 3 more at the next start.')

# ---------------------------------------------------------------- when it is NOT offered (ruling 17)

func test_no_prompt_when_no_spend_can_flip_the_result():
	Fixture.set_charges(pier, 2)
	Fixture.give_patience(pier)
	var taken := await hostile_shoots(12) # 12 vs 10 needs 3 to miss
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'Two charges cannot bring a 12 below 10: not asked.')
	assert_eq(taken, DAMAGE_DIE, 'The hit stands.')
	assert_eq(Fixture.charges(pier), 2)

func test_no_prompt_for_a_hostile_out_of_sight():
	# A wall along x = 4 below the Pier's row: the Pier-hostile line crosses it at (4, 7); the
	# hostile-ally line (x = 6) and the Pier-ally line (y = 5) do not.
	var wall:Array[Vector2i] = []
	for y in range(6, 12): wall.append(Vector2i(4, y))
	SpecFactory.set_tiles_elevation(game.map, 10, wall)
	UnitTile.update_tracking_and_statuses(game.map)
	assert_false(UnitRelation.can_see(pier, hostile), 'fixture: the wall blocks the Pier\'s sight of the hostile.')
	assert_true(UnitRelation.can_see(hostile, ally), 'fixture: but not the hostile\'s shot.')
	Fixture.set_charges(pier, 3)
	Fixture.give_patience(pier)
	var taken := await hostile_shoots(11)
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'Out of Line of Sight: not asked.')
	assert_eq(taken, DAMAGE_DIE)

func test_a_crit_lowered_below_20_still_hits_but_is_no_crit():
	Fixture.set_charges(pier, 3)
	Fixture.give_patience(pier)
	responder.multiple_choice_queue.assign([0]) # "Spend 1: 19, Hit" - a miss would cost 11
	var before := ally.core.current.health
	# A crit rolls the damage twice and keeps the higher: 1 then 6 would land 6. A plain hit rolls
	# once, the 1, which the rifle's Reliable 2 floors to 2.
	await Fixture.attack(game, hostile, ally, Fixture.RIFLE, [20, 1, 6])
	assert_eq(before - ally.core.current.health, RELIABLE, 'Lowered to 19: a plain hit, one damage roll.')
	assert_eq(Fixture.charges(pier), 2, 'One charge spent.')
	if responder.multiple_choice_prompts.size() == 1:
		assert_eq(responder.multiple_choice_prompts[0].labels.size(), 2,
			'Offered: to a hit for 1 (to a miss would need 11, unaffordable), and decline.')

func test_the_second_qualifying_roll_in_a_round_is_not_offered():
	var second := Fixture.create_dummy(game, Vector2i(8, 9))
	Fixture.equip(second, Fixture.RIFLE)
	Fixture.set_charges(pier, 6)
	Fixture.give_patience(pier)
	responder.multiple_choice_queue.assign([0])
	await hostile_shoots(11)
	assert_eq(Fixture.charges(pier), 4, 'fixture: the first roll was reduced.')
	var before := ally.core.current.health
	await Fixture.attack(game, second, ally, Fixture.RIFLE, [11, DAMAGE_DIE])
	assert_eq(responder.multiple_choice_prompts.size(), 1, '1/round: the second roll is not offered.')
	assert_eq(before - ally.core.current.health, DAMAGE_DIE)
	assert_eq(Fixture.charges(pier), 4)

func test_the_one_per_round_frees_up_at_the_piers_turn_start():
	Fixture.set_charges(pier, 6)
	Fixture.give_patience(pier)
	responder.multiple_choice_queue.assign([0, 0])
	await hostile_shoots(11)
	await SpecFactory.end_turn(game, hostile)
	await SpecFactory.start_turn(game, pier)
	await SpecFactory.end_turn(game, pier)
	var taken := await hostile_shoots(11)
	assert_eq(responder.multiple_choice_prompts.size(), 2, 'Asked again after the Pier\'s own turn start.')
	assert_eq(taken, RELIABLE)

func test_an_auto_hit_is_not_offered():
	var auto_hit := BuffModifyAttackRoll.new()
	auto_hit.step = EventUnitAttack.SEQUENCE_STEP.auto_hit
	auto_hit.to = Buff.TO.MODIFY_ATTACK_ROLL
	UnitCondition.apply_buff(SpecFactory.dummy_event(), hostile, auto_hit)
	Fixture.set_charges(pier, 30)
	Fixture.give_patience(pier)
	var before := ally.core.current.health
	await Fixture.attack(game, hostile, ally, Fixture.RIFLE, [DAMAGE_DIE]) # an auto-hit rolls no d20
	var taken := before - ally.core.current.health
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'An auto-hit rolled no number to reduce.')
	assert_eq(taken, DAMAGE_DIE, 'fixture: and it did hit.')

func test_an_ai_controlled_pier_never_spends():
	var ai_pier := Fixture.create_pier(game, Vector2i(2, 9), Faction.AI_ENEMY)
	var player_shooter := Fixture.create_dummy(game, Vector2i(10, 9), 8, Faction.PLAYER)
	var ai_ally := Fixture.create_dummy(game, Vector2i(10, 5), ALLY_EVASION)
	Fixture.equip(player_shooter, Fixture.RIFLE)
	Fixture.set_charges(ai_pier, 3)
	Fixture.give_patience(ai_pier)
	assert_true(Fixture.has(player_shooter, Fixture.PATIENCE_REDUCE), 'fixture: the AI Pier arms the player unit.')
	var before := ai_ally.core.current.health
	await Fixture.attack(game, player_shooter, ai_ally, Fixture.RIFLE, [11, DAMAGE_DIE])
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'No prompt.')
	assert_eq(before - ai_ally.core.current.health, DAMAGE_DIE, 'And no automatic spend: the base would have confirmed (buff_modify_attack_roll.gd:64).')
	assert_eq(Fixture.charges(ai_pier), 3)
