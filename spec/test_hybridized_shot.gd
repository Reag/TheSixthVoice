# HYBRIDIZED SHOT (M/K2, SP1 Task 2): "Gain +1 Accuracy on the first attack roll you make with a
# loading weapon that is not SUPERHEAVY on your turn."
#
# RULING 4 SCOPES IT TO THE WHOLE FIRST QUALIFYING ATTACK, not to the first die. A Blast or Line
# fired first gets +1 against EACH target. That is not a liberty: attack_roll.gd:183-189 reads an
# accuracy buff's value with get_values() called BARE, with no roll context, so a per-roll spend is
# not expressible as content at all - and vanilla's own "next Loading attack" system, the Roland
# Chamber, sticks to the declared attack the same way.
#
# ASSERTED ON THE NUMBER, THROUGH AttackRoll.PreAttack. Checking that the buff is present, or that a
# tag is set, would pass while the +1 never reached a roll. accuracy_mods_total() is the number the
# player sees on the breakdown.
#
# MIND THE CHEAT QUEUE. The AMR carries attack_accuracy = "1" (mw_anti_materiel_rifle.tres:17), so
# each of its attacks pops a d20 AND an accuracy die from Dice.CHEAT_ROLL_QUEUE; so does the Cyclone
# Pulse Rifle (accurate). Queue generously and clear in after_each.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hybridized_shot.gd
extends GutTest

const MK2Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/mk2_fixture.gd')

const TRAIT_ID := &'mt_hybridized_shot'
const BUFF_ID := &'buff_hybridized_shot'

## Heavy, LOADING, not superheavy: the qualifying case (mw_anti_materiel_rifle.tres:14,16).
const AMR := &'mw_anti_materiel_rifle'
## SUPERHEAVY and Loading - weapon_size = 3 (mw_cyclone_pulse_rifle.tres:16,18). The card's exclusion.
## NOTE: the Railgun is NOT this weapon - it is Heavy and carries no loading tag at all.
const SUPERHEAVY_LOADING := &'mw_cyclone_pulse_rifle'
## Heavy, NOT loading (mw_heavy_machine_gun.tres:16,19): the other exclusion.
const PLAIN_HEAVY := &'mw_heavy_machine_gun'
## Blast 1, LOADING, Ordnance (mw_rocket_propelled_grenade.tres:24): ruling 4's multi-target case.
const RPG := &'mw_rocket_propelled_grenade'

const START := Vector2i(2, 2)
const TARGET_TILE := Vector2i(7, 2)
const SECOND_TILE := Vector2i(7, 3)

var game:Gamemaster
var mk2:Unit
var target:Unit

func before_each() -> void:
	game = MK2Fixture.create_game(self)
	mk2 = MK2Fixture.create_mk2(game, START)
	target = MK2Fixture.create_dummy(game, TARGET_TILE, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func equip(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = mk2.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(mk2)
	return weapon

## The accuracy the breakdown would show for this weapon against this target, right now.
func accuracy_for(weapon:GearCore, against:Unit) -> int:
	var specific := SpecificAction.create(mk2, weapon, weapon.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context).accuracy_mods_total()

## Fire once, hitting.
func shoot(weapon:GearCore, against:Unit) -> void:
	Dice.cheat_attack([19], [3, 3, 3, 3, 3, 3, 3, 3])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = mk2, target_unit = against,
	})

# ---------------------------------------------------------------- the bonus

func test_the_first_loading_attack_of_the_turn_gets_the_bonus() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	assert_eq(accuracy_for(amr, target), 2,
		'+1 from the AMR itself and +1 from Hybridized Shot.')

func test_the_bonus_is_labelled_with_the_traits_name() -> void:
	# The breakdown line reads buff_core.name_text() (attack_roll.gd:189); a nameless line reads as a
	# bug to the player even when the arithmetic is right.
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	var specific := SpecificAction.create(mk2, amr, amr.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = target})
	var titles:Array = []
	for mod in AttackRoll.PreAttack.create(context).accuracy_mods: titles.append(mod.title_key)
	assert_has(titles, tr('gear.mt_hybridized_shot.name'), 'The +1 line names the trait.')

func test_the_second_loading_attack_of_the_turn_does_not() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr, target)
	assert_eq(accuracy_for(amr, target), 1, 'Only the AMR own accuracy is left.')

func test_the_bonus_is_back_next_turn() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr, target)
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	assert_eq(accuracy_for(amr, target), 2, 'every_new_turn_refresh cleared the per-turn counter.')

func test_a_miss_still_spends_it() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	Dice.cheat_attack([1], [3, 3, 3, 3, 3, 3, 3, 3])
	await game.execute_event(&'event_gear_activate', {
		action = amr.get_solo_action(), gear = amr, unit = mk2, target_unit = target,
	})
	assert_eq(accuracy_for(amr, target), 1, 'Ruling 4: a miss spends it.')

# ---------------------------------------------------------------- the exclusions

func test_a_superheavy_loading_weapon_gets_nothing() -> void:
	var cyclone := equip(SUPERHEAVY_LOADING)
	await MK2Fixture.open_turn(game, mk2)
	# The Cyclone is Accurate, so the expected number is its own +1 and no more.
	assert_eq(accuracy_for(cyclone, target), 1, 'SUPERHEAVY is excluded by the card.')

func test_a_superheavy_attack_does_not_spend_the_bonus() -> void:
	# Two weapons, one turn: fire the excluded one first and the AMR must STILL have its +1. Without
	# this, a charger that fired on every attack would look correct in every other test here.
	var cyclone := equip(SUPERHEAVY_LOADING)
	var amr := equip(AMR)
	SpecFactory.apply_passive_buffs(mk2)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(cyclone, target)
	assert_eq(accuracy_for(amr, target), 2, 'The excluded shot charged nothing.')

func test_a_non_loading_weapon_gets_nothing() -> void:
	var hmg := equip(PLAIN_HEAVY)
	await MK2Fixture.open_turn(game, mk2)
	assert_eq(accuracy_for(hmg, target), -1, 'Inaccurate only: no Loading, no bonus.')

func test_it_does_nothing_on_someone_elses_turn() -> void:
	# "on your turn". Overwatch on an enemy turn gets nothing and spends nothing.
	var amr := equip(AMR)
	assert_false(mk2.state.is_taking_turn, 'The fixture has not opened our turn.')
	assert_eq(accuracy_for(amr, target), 1, 'No bonus outside our own turn.')

# ---------------------------------------------------------------- ruling 4

func test_a_blast_gives_the_bonus_against_every_target() -> void:
	# RULING 4, the whole point of the ruling. If this ever goes red because the engine started
	# handing get_values() a roll context, re-read design §0.4 - the ruling would be revisitable,
	# not broken.
	var second := MK2Fixture.create_dummy(game, SECOND_TILE, -10)
	var rpg := equip(RPG)
	await MK2Fixture.open_turn(game, mk2)
	assert_eq(accuracy_for(rpg, target), 1, 'First target gets +1.')
	assert_eq(accuracy_for(rpg, second), 1, 'So does the second, in the same attack.')
