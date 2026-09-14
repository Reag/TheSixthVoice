# AUXILIARY POWER REROUTER / O.R.S HYPERCHARGE (M/K2, SP1 Task 3): "For the rest of the scene, you
# ignore the loading property of your weapons but gain 1d3 heat each time you fire a Loading weapon."
#
# LOADING IS ONE BOOLEAN, GearCore.is_loaded. unit_action.gd:276 sets it false after any Loading
# weapon attack's spend_actions, :151 refuses an unloaded weapon unless the action overrides
# can_be_used_while_unloaded(), and only event_gear_reload sets it back. So the ability is a reacting
# buff that restores the flag after every firing, and the heat is charged from the same reaction.
# Between the drop and the restore nothing reads the flag: the UI never shows the weapon unloaded,
# and Stabilize never offers a reload (UnitAction.get_unloaded_weapons, unit_action.gd:411-416).
#
# RULING 6: activating the protocol also READIES every intact Loading weapon on the spot. "Ignore the
# Loading property" means the weapon behaves as if it never had it, so a weapon already fired and
# empty is loaded when the protocol resolves. The heat cost applies only to shots fired afterwards.
#
# RULING 7: the heat is PER FIRING ACTION. One 1d3 per Blast, two per two-weapon Skirmish, and
# reactions and freebies pay too ("each time you fire"). That falls straight out of the trigger:
# UNIT_ACTION POST fires once per gear activation that actually moved its usage counter
# (event_gear_activate.gd:100-111), so an aborted attack pays nothing and stays loaded.
#
# THE DICE STRATEGY IS "EVERY DIE THE SAME NUMBER", not a lined-up queue, and that is not laziness.
# Dice.CHEAT_ROLL_QUEUE is ONE global FIFO (dice.gd:9, :32-35) and the heat d3 is rolled LAST, after
# the attack has popped its d20, its accuracy die and however many damage dice the weapon rolls - a
# count this file must not have to know. Filling the queue with one repeated value makes the d3 come
# back that value whatever the attack consumed first, so the heat assertions can name an exact
# number. The same trick, for the same reason, as test_hybridized_shot.cheat_every_die_to_six().
# NEVER 1: Overkill rerolls damage dice that come up 1 (which is why dice.gd:30 picks 2 for its own
# CHEAT_ROLL_LOW), and a rerolling damage die would drain the queue unpredictably.
#
# AND THE TWO HEAT TESTS USE DIFFERENT NUMBERS ON PURPOSE. A single test asserting "3" passes just as
# well against a hard-coded 3 as against a rolled d3; test_two_loading_shots_pay_twice rolls a 3 and
# then a 2 and asserts 5, which no constant reproduces.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ors_hypercharge.gd
extends GutTest

const MK2Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/mk2_fixture.gd')

const CORE_ID := &'cp_auxiliary_power_rerouter'
const PROTOCOL_ID := &'action_ors_hypercharge'
const BUFF_ID := &'buff_ors_hypercharge'

## Heavy, LOADING, Ordnance (mw_anti_materiel_rifle.tres:14,16).
const AMR := &'mw_anti_materiel_rifle'
## Heavy, NOT loading (mw_heavy_machine_gun.tres:16,19) - the control for the LOADING gate.
const PLAIN_HEAVY := &'mw_heavy_machine_gun'
## AUX, LOADING, no Ordnance (mw_missile_rack.tres:22,25). A SECOND Loading weapon, so
## test_two_loading_shots_pay_twice does not have to fire one weapon twice.
const LOADING_AUX := &'mw_missile_rack'

const START := Vector2i(2, 2)
const TARGET_TILE := Vector2i(7, 2)
## Well clear of the M/K2 and its target, for the one test that needs a third unit taking its own turn.
const ENEMY_TILE := Vector2i(2, 6)

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

func hypercharge() -> void:
	await SpecFactory.use(game, mk2, CORE_ID, PROTOCOL_ID)

## Every die in the rest of this activation comes back `every_die`. See the file header.
func cheat_every_die_to(every_die:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(every_die)
	Dice.cheat_attack([], buffer)

## Fire once at the punching bag, with every die in the activation fixed to `every_die` - so the
## heat d3 the buff rolls afterwards comes back `every_die` too.
func shoot(weapon:GearCore, every_die:int = 2) -> void:
	cheat_every_die_to(every_die)
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = mk2, target_unit = target,
	})

## Fire once from some OTHER unit, at us.
func shoot_from(shooter:Unit, weapon:GearCore, every_die:int = 2) -> void:
	cheat_every_die_to(every_die)
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = mk2,
	})

func has_the_chip() -> bool:
	return mk2.state.buffs.any(func(core:BuffCore) -> bool: return core.base.compcon_id == BUFF_ID)

# ---------------------------------------------------------------- the control

## Not decoration: every "stays loaded" assertion below is vacuous if firing never emptied the weapon
## in the first place. This is the one test in the file that must pass with the whole ability deleted.
func test_without_the_protocol_a_loading_weapon_empties() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr)
	assert_false(amr.is_loaded, 'Vanilla: the AMR is empty after one shot.')

## The other half of the control, and the reason test_a_non_loading_weapon_costs_nothing means
## anything: the HMG must actually FIRE. A weapon whose activation silently aborted would also cost
## no heat, and would read as the LOADING gate working.
func test_the_control_weapon_really_fires() -> void:
	var hmg := equip(PLAIN_HEAVY)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(hmg)
	assert_gt(hmg.get_uses_this_round_alt(hmg.get_usage_group_for_action(hmg.get_solo_action())), 0,
		'The HMG activation moved its round usage counter, so it really went off.')

# ---------------------------------------------------------------- the protocol

func test_the_protocol_is_refused_outside_the_protocol_window() -> void:
	var core_gear:GearCore = mk2.get_gear(CORE_ID)
	assert_true(GearCore.is_valid(core_gear), 'Fixture: the frame carries %s.' % CORE_ID)
	if not GearCore.is_valid(core_gear): return
	assert_false(mk2.state.is_using_protocols, 'The fixture has not opened a turn.')
	assert_eq(
		UnitAction.get_gear_unavailable_reason(
			SpecificAction.create(mk2, core_gear, core_gear.get_action(PROTOCOL_ID))),
		UnitAction.REASON.PROTOCOL,
		'A protocol needs the protocol window.')

func test_the_protocol_spends_the_core_power() -> void:
	await MK2Fixture.open_turn(game, mk2)
	assert_true(mk2.core.has_core_power, 'We start with it.')
	await hypercharge()
	assert_false(mk2.core.has_core_power, 'The protocol consumed it.')
	assert_true(has_the_chip(), 'And left its chip.')

## RULING 6. The reload is the ACTION's job, not the buff's: the buff only ever reacts to a firing,
## and this weapon was fired before the protocol existed.
##
## THE TURN FLIP IN THE MIDDLE IS THE REAL ORDER OF PLAY, not spec scaffolding. Firing ends the
## protocol window - any non-protocol, non-reaction action does (unit_action.gd:268 via
## does_action_end_protocol_phase) - and event_gear_activate refuses an unavailable action outright,
## so "shoot, then hypercharge" is only reachable across a turn boundary. Measured: written as
## shoot-then-hypercharge inside one turn, the activation aborts with
## `[ Gear not available ] reason : protocol` and this test fails for a reason that has nothing to do
## with reloading (.superpowers/sdd/task3-green-1.log).
##
## And the extra assertion after the flip is what makes the last one mean something: if a new turn
## reloaded weapons by itself, the protocol would be getting credit for the engine's work.
func test_activating_it_reloads_an_empty_weapon() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr)
	assert_false(amr.is_loaded, 'Empty before.')
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	assert_false(amr.is_loaded,
		'Fixture: still empty at the start of the next turn - only a reload clears Loading.')
	await hypercharge()
	assert_true(amr.is_loaded, 'The protocol readied it.')

# ---------------------------------------------------------------- firing under it

func test_a_loading_weapon_stays_loaded() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await shoot(amr)
	assert_true(amr.is_loaded, 'The buff put the flag straight back.')

func test_firing_it_costs_the_rolled_d3_in_heat() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(amr, 3)
	assert_eq(mk2.core.current.heat - before, 3, 'Exactly the cheated d3.')

func test_a_non_loading_weapon_costs_nothing() -> void:
	var hmg := equip(PLAIN_HEAVY)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(hmg, 3)
	assert_eq(mk2.core.current.heat, before, 'No Loading tag, no heat.')

func test_two_loading_shots_pay_twice() -> void:
	# RULING 7: per firing action. Two DIFFERENT weapons, so the per-turn soft limit is not in play.
	# Two DIFFERENT die values, so no constant charge reproduces the total (3 + 2 = 5).
	var amr := equip(AMR)
	var rack := equip(LOADING_AUX)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(amr, 3)
	await shoot(rack, 2)
	assert_eq(mk2.core.current.heat - before, 5,
		'One 1d3 per firing, not one per turn - and the ROLLED value each time, not a constant.')

func test_the_chip_is_still_there_next_turn() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	assert_true(has_the_chip(), 'until = MANUAL: it lasts the scene.')

## THE HOLDER GUARD, which nothing else in this file reaches.
## reaction_bus.trigger_occurred polls EVERY unit's buffs on every trigger (reaction_bus.gd:50,
## :61-62) and hands each of them the SAME triggering event, so our buff is asked about an enemy's
## Loading shot. Without the holder check it would put the ENEMY's weapon back and heat US for it.
## Both halves are asserted: our heat, and the enemy's weapon staying empty.
func test_an_enemys_loading_shot_neither_heats_us_nor_reloads_them() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()

	var enemy := MK2Fixture.create_dummy(game, ENEMY_TILE, -10)
	var enemy_amr:GearCore = enemy.core.equip_system(AMR)
	SpecFactory.apply_passive_buffs(enemy)
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, enemy)

	var before:int = mk2.core.current.heat
	await shoot_from(enemy, enemy_amr, 3)
	assert_eq(mk2.core.current.heat, before, "Somebody else's Loading shot does not heat us.")
	assert_false(enemy_amr.is_loaded, 'And it does not reload their weapon either.')

# ---------------------------------------------------------------- integration

func test_hybridized_shot_still_applies_under_hypercharge() -> void:
	# The card's own synergy: Hypercharge does not remove the LOADING tag, so the +1 keeps applying.
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var specific := SpecificAction.create(mk2, amr, amr.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = target})
	assert_eq(AttackRoll.PreAttack.create(context).accuracy_mods_total(), 2,
		'Hybridized Shot is untouched by Hypercharge.')
