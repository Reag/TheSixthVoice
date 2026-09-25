# ZWARTE HOOP's "+1 range on the attack" (Grutte Pier SP2). Design ruling 10.
#
# The one option picked BEFORE targeting: a blankable variant row, +1 or +2, on a ranged weapon's
# first attack roll of the round. The composed action is read the way targeting reads it -
# get_target_range - and a LINE weapon must get a NEW pattern, never an edit to the Kit's own shared
# sub-resource.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_zwarte_hoop_range.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')

const GROUP := &'zwarte_hoop_range'
const PLUS_1 := &'zwarte_hoop_range_1'
const PLUS_2 := &'zwarte_hoop_range_2'
## Index into the group's get_variant_actions(): 0 is the blank "no modification" row.
const INDEX_PLUS_1 := 1
const INDEX_PLUS_2 := 2

## Line 8.
const CANNON := &'mw_magnetic_cannon'
const MELEE := &'mw_tactical_melee_weapon'
## Burst: no range to widen.
const BURST := &'mw_bristlecrown_flechette_launcher'

const PIER_TILE := Vector2i(2, 5)

var game:Gamemaster
var responder
var pier:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	pier = Fixture.create_pier(game, PIER_TILE)
	for kit_id:StringName in [Fixture.RIFLE, CANNON, MELEE, BURST, Fixture.INVADE]: Fixture.equip(pier, kit_id)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func specific_for(kit_id:StringName) -> SpecificAction:
	var gear := pier.get_gear(kit_id)
	return SpecificAction.create(pier, gear, gear.get_solo_action())

func range_group(kit_id:StringName) -> VariantActionGroup:
	var specific := specific_for(kit_id)
	for group:VariantActionGroup in specific.action.get_alternate_actions(specific):
		if group.key == GROUP: return group
	return null

func composed(kit_id:StringName, index:int) -> ActionAttackWeapon:
	var specific := specific_for(kit_id)
	return VariantActionGroup.generate_composed_action([range_group(kit_id)], specific.action, {GROUP: index})

func range_of(kit_id:StringName, action:Action) -> int:
	var specific := specific_for(kit_id)
	return action.get_target_range(SpecificAction.create(pier, specific.gear, action))

# ---------------------------------------------------------------- when it is offered

func test_offered_on_a_rifle_with_a_charge():
	Fixture.set_charges(pier, 1)
	var group := range_group(Fixture.RIFLE)
	assert_not_null(group, 'The row is on the rifle.')
	if group == null: return
	assert_true(group.is_blankable, 'Blankable: "you may".')
	var keys:Array = group.list.map(func(v:VariantAction) -> StringName: return v.key)
	assert_eq(keys, [PLUS_1, PLUS_2])

func test_plus_two_is_disabled_below_two_charges():
	Fixture.set_charges(pier, 1)
	var group := range_group(Fixture.RIFLE)
	if group == null: return fail_test('no row')
	assert_false(group.list[0].is_disabled, '+1 open on one charge.')
	assert_true(group.list[1].is_disabled, '+2 closed on one charge.')
	Fixture.set_charges(pier, 2)
	assert_false(range_group(Fixture.RIFLE).list[1].is_disabled, '+2 open on two.')

func test_not_offered_without_charges():
	assert_null(range_group(Fixture.RIFLE))

func test_not_offered_on_a_melee_weapon():
	Fixture.set_charges(pier, 2)
	assert_null(range_group(MELEE), 'Threat, not range.')

func test_not_offered_on_a_burst_weapon():
	Fixture.set_charges(pier, 2)
	assert_null(range_group(BURST), 'A Burst has no range.')

func test_not_offered_on_a_tech_attack():
	Fixture.set_charges(pier, 2)
	assert_null(range_group(Fixture.INVADE))

func test_not_offered_once_the_first_attack_roll_of_the_round_is_made():
	var target := Fixture.create_dummy(game, Vector2i(6, 5))
	await Fixture.open_turn(game, pier)
	Fixture.set_charges(pier, 3)
	responder.multiple_choice_queue.assign([5]) # Done
	await Fixture.attack(game, pier, target, Fixture.RIFLE, [10, 6])
	assert_null(range_group(Fixture.RIFLE), 'The round stamp closes the row too.')

# ---------------------------------------------------------------- what it does

func test_plus_one_puts_a_rifle_one_tile_further():
	Fixture.set_charges(pier, 1)
	var printed := range_of(Fixture.RIFLE, specific_for(Fixture.RIFLE).action)
	assert_eq(range_of(Fixture.RIFLE, composed(Fixture.RIFLE, INDEX_PLUS_1)), printed + 1)

func test_plus_two_draws_a_line_two_longer_and_leaves_the_kit_alone():
	Fixture.set_charges(pier, 2)
	var kit_pattern:RangePattern = specific_for(CANNON).action.range_pattern
	var printed := kit_pattern.value
	var widened := composed(CANNON, INDEX_PLUS_2)
	assert_eq(widened.range_pattern.value, printed + 2, 'Line 8 -> Line 10.')
	assert_eq(range_of(CANNON, widened), printed + 2, 'And targeting reads it.')
	assert_eq(kit_pattern.value, printed, 'The shared sub-resource is untouched: a NEW pattern.')

func test_composing_alone_spends_nothing():
	Fixture.set_charges(pier, 2)
	composed(Fixture.RIFLE, INDEX_PLUS_2)
	assert_eq(Fixture.charges(pier), 2, 'Only variant_spend, after targeting, pays.')

func test_firing_with_plus_one_pays_one_and_the_loop_sees_the_rest():
	var target := Fixture.create_dummy(game, Vector2i(13, 5))
	await Fixture.open_turn(game, pier)
	Fixture.set_charges(pier, 3)
	responder.multiple_choice_queue.assign([5]) # Done at the loop
	Dice.CHEAT_ROLL_QUEUE.append_array([10, 6])
	await SpecFactory.use_solo(game, pier, Fixture.RIFLE, target, [], PLUS_1)
	assert_eq(Fixture.charges(pier), 2, 'One paid for +1 range.')
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'The loop then offered the remaining two.')
	if responder.multiple_choice_prompts.size() == 1:
		assert_string_contains(responder.multiple_choice_prompts[0].desc, '2')
	assert_lt(target.core.current.health, 200, 'fixture: the shot from 11 landed.')
