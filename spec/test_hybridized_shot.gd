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
# AND THE RULING-4 TEST READS THE RESOLVED ATTACK, NOT A PREVIEW. accuracy_for() below builds a
# throwaway PreAttack against an unspent counter, so calling it twice only ever proves that the payer
# ignores which target it is asked about - move the charge to a per-roll hook and two previews taken
# BEFORE any attack still both read +1. The real question is whether the charge can land BETWEEN the
# per-target rolls of one Blast, and only a resolved attack can answer it: every roll is appended to
# the shared DeclaredAttackSummary as its own event resolves (event_unit_attack_declared.gd:67 runs
# them all), and each AttackRoll keeps the PreAttack it was rolled with (attack_roll.gd:7, :29-33) -
# so the summary remembers what EACH target was actually given. fire_and_capture() below gets hold of
# that summary. Same measurement problem, and the same answer, as test_blasting_powder.gd's
# test_a_line_hitting_three_targets_deals_plus_zero_one_two_in_distance_order.
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
## The once-per-turn counter's key on the trait Kit's own GearCore (buff_hybridized_shot.gd:34).
## Restated here rather than preloaded, the way test_blasting_powder.gd:44 restates its own: the
## counter is what the charger writes, and a spec that read the key off the script under test could
## not notice the key being renamed out from under the content.
const USAGE_KEY := &'hybridized_shot'
## The key the engine ACTUALLY resolves the breakdown line through - see
## test_the_bonus_is_labelled_with_the_traits_name.
const BUFF_NAME_KEY := 'gear.%s.name' % BUFF_ID

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
## Well clear of the two blast tiles, for the one test that needs a THIRD unit taking its own turn.
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

## Fire once from some OTHER unit, hitting.
func shoot_from(shooter:Unit, weapon:GearCore, against:Unit) -> void:
	Dice.cheat_attack([19], [3, 3, 3, 3, 3, 3, 3, 3])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = against,
	})

## The M/K2's once-per-turn counter, read off the trait Kit's own GearCore. This is the charger's
## ONLY output, so it is the only place a charge taken at the wrong moment is visible at the moment
## it is taken - see test_an_enemys_loading_shot_does_not_spend_our_bonus for why that matters.
## Returns -1 rather than 0 if the trait gear is missing, so a broken fixture cannot read as "no
## charge taken".
func trait_uses() -> int:
	var trait_gear := mk2.get_gear(TRAIT_ID)
	return -1 if not GearCore.is_valid(trait_gear) else trait_gear.get_uses_this_turn_alt(USAGE_KEY)

## Every die in the run comes back a 6 until the queue runs dry - the strategy test_blasting_powder.gd
## explains in full at its own cheat_every_die_to_six(). Dice.CHEAT_ROLL_QUEUE is ONE global FIFO
## (dice.gd:9, :33-35), and a Blast fires an attack roll AND an accuracy die PER TARGET, so a queue of
## named values cannot be lined up with the rolls it is meant to feed. With every die a 6 the order
## stops mattering: base_roll 6 plus one accuracy die of 6 clears the fixture's -10 evasion and is
## nowhere near attack_roll.gd:73's crit threshold. CLEARS FIRST, because cheat_attack only appends.
func cheat_every_die_to_six() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([], buffer)

## Fire the weapon for real at a TILE, and hand back the DeclaredAttackSummary the attack resolved
## through - the one object that remembers what each per-target roll was handed.
##
## BUILDS THE EVENT BLOCK BY HAND instead of calling game.execute_event(). The summary is created
## inside the activation (action_attack.gd:253) and written onto the event's OWN context
## (action_attack.gd:259, reached through event_gear_activate.gd:80's
## `await context.action.activate(context, core)` where context IS core.context) - so the only way to
## see it afterwards is to hold the EventCore. level.gd:97 creates that core internally and returns
## void, and the block frees itself at level.gd:105 - but the core is a RefCounted we hold, and its
## context with it. core.context is re-read rather than cached because the variant-action path
## REPLACES it (event_gear_activate.gd:90-91); the RPG has no variants today, and this is a line of
## content away from having one.
func fire_and_capture(weapon:GearCore, tile:Vector2i) -> DeclaredAttackSummary:
	var tiles:Array[Vector2i] = [tile]
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = mk2, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

## Did THIS resolved roll - the one this target actually got - carry Hybridized Shot's +1?
##
## Reads the MOD LIST rather than accuracy_mods_total() on purpose: cover is an accuracy mod like any
## other (attack_roll.gd:168-169), so a target that happens to stand behind its neighbour would move
## the total without anything being wrong with the trait, and the test would be measuring the map.
## The title is the buff's own name_text(), which is what attack_roll.gd:189 puts on the line.
func got_the_bonus(roll:AttackRoll) -> bool:
	for mod:AttackRoll.AccuracyMod in roll.pre.accuracy_mods:
		if mod.title_key == tr(BUFF_NAME_KEY) and mod.mod == 1: return true
	return false

# ---------------------------------------------------------------- the bonus

func test_the_first_loading_attack_of_the_turn_gets_the_bonus() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	assert_eq(accuracy_for(amr, target), 2,
		'+1 from the AMR itself and +1 from Hybridized Shot.')

## The breakdown line reads buff_core.name_text() (attack_roll.gd:189); a nameless line reads as a bug
## to the player even when the arithmetic is right.
##
## THE KEY IS THE BUFF'S, NOT THE TRAIT'S, AND THE DIFFERENCE IS INVISIBLE HERE BY COINCIDENCE. The
## resolution path is buff_core.name_text() -> Buff.name_text (buff.gd:184-185) -> Translate.buff
## (translate.gd:49), which with no localization_key_override takes the BUFF's compcon_id and asks for
## gear.buff_hybridized_shot.name (translate.gd:54-58). This trait ships that row AND
## gear.mt_hybridized_shot.name holding the identical string ('Hybridized Shot',
## localizations.csv:89,91), so asserting the trait's key passed while measuring a key the engine
## never reads - and would have gone on passing if the buff row were renamed. Do not "simplify" this
## back to the trait key.
func test_the_bonus_is_labelled_with_the_traits_name() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	var specific := SpecificAction.create(mk2, amr, amr.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = target})
	var titles:Array = []
	for mod in AttackRoll.PreAttack.create(context).accuracy_mods: titles.append(mod.title_key)
	assert_has(titles, tr(BUFF_NAME_KEY), 'The +1 line names the trait.')

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
	await MK2Fixture.open_turn(game, mk2)
	await shoot(cyclone, target)
	# The positive control: without it a Cyclone activation that was refused or aborted - a mount or
	# size rule, a heat gate, a can_target_unit change - would leave the SUPERHEAVY exclusion
	# untested and this assertion trivially true. The Cyclone is Loading, so its spent flag is the
	# cheapest proof the excluded shot really fired.
	assert_false(cyclone.is_loaded, 'Fixture: the excluded shot really did go off.')
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

## THE HOLDER GUARD IN triggers_on_event, which nothing else in this file reaches.
## reaction_bus.trigger_occurred polls EVERY unit's buffs on every trigger (reaction_bus.gd:50, :61-62)
## and hands each of them the SAME triggering event, so our buff is asked about an enemy's Loading
## shot on the enemy's own turn - where qualifies() is perfectly happy: the weapon is Loading, is not
## SUPERHEAVY, and context.unit (the ENEMY) is indeed taking its turn.
##
## ASSERTED ON THE COUNTER, NOT ON THE NEXT TURN'S ACCURACY, AND THAT IS THE POINT. The counter is the
## only place the wrong charge is visible at the moment it is taken. By the time our own turn opens,
## UnitAction.every_new_turn_refresh has cleared uses_this_turn for EVERY unit on the map
## (unit_action.gd:67-70, called from event_turn_start.gd:44), so a charge stolen during someone
## else's turn would be wiped before we could feel it. See the guard's own comment in
## buff_hybridized_shot.gd for what that means about how much defence this is: measured, deleting the
## guard turns the FIRST assertion below red and leaves the second green.
func test_an_enemys_loading_shot_does_not_spend_our_bonus() -> void:
	var amr := equip(AMR)
	var enemy := MK2Fixture.create_dummy(game, ENEMY_TILE, -10)
	var enemy_amr:GearCore = enemy.core.equip_system(AMR)
	SpecFactory.apply_passive_buffs(enemy)

	await SpecFactory.start_turn(game, enemy)
	assert_true(enemy.state.is_taking_turn,
		'Fixture: it is the enemy that is taking a turn, so ITS shot passes qualifies().')
	assert_false(mk2.state.is_taking_turn, 'Fixture: and we are not.')

	# FIRED AT THE DUMMY, NOT AT US, AND THAT IS DELIBERATE. The guard under test cares only about
	# WHO SHOT; the victim is irrelevant to it. Aiming this at the M/K2 made the test a live flake:
	# d20 19 + accuracy 3 = 22 against our 8 Evasion is a CRIT, a crit doubles the damage dice, and
	# 6 AP damage against a 6 HP frame structures us - which then rolls the structure table, taking
	# the queued values to 8 of the 9 this helper queues. One extra die anywhere (an added tag, a
	# structure-table change, a third-party event_unit_structure extension) drains the FIFO, hands
	# the structure roll to real RNG, and a rolled 1 destroys the M/K2 mid-spec. The dummy has 200 HP
	# and -10 Evasion, so nothing downstream of the hit can vary.
	await shoot_from(enemy, enemy_amr, target)
	# THE POSITIVE CONTROL. Without it the assertion below is trivially true whenever the enemy's
	# activation never resolves at all - a faction, range or availability change would leave the
	# holder guard untested and this test green. The AMR is Loading, so its spent flag is the
	# cheapest proof the shot actually went off.
	assert_false(enemy_amr.is_loaded, 'Fixture: their Loading shot really did go off.')
	assert_eq(trait_uses(), 0, "An enemy's Loading shot did not spend OUR once-per-turn charge.")

	await SpecFactory.end_turn(game, enemy)
	await SpecFactory.start_turn(game, mk2)
	assert_eq(accuracy_for(amr, target), 2, 'And our own first shot still gets the +1.')

# ---------------------------------------------------------------- ruling 4

## RULING 4, the whole point of the ruling, measured on a REAL resolved Blast.
##
## One shot, two targets, and what EACH of them was actually handed asserted separately off the
## DeclaredAttackSummary the attack resolved through - which is what tells "the charge is spent once
## per ATTACK" apart from "once per target". The counter assertion at the end is the other half: it is
## what separates a correctly-once charge from a charger that never ran at all.
##
## THIS IS THE TEST THE NAIVE SHAPE FAILS, MEASURED. Move the increment into
## check_if_passive_applies - the payer, which the engine calls once per target - guarded on
## DeclaredAttackSummary.is_valid(context.resource) so a hovering preview cannot reach it, and this
## file goes 10/11: everything else stays green, including the two accuracy_for() previews this test
## used to consist of, and only the second target's assertion below goes red.
##
## If it ever goes red because the engine started handing get_values() a roll context, re-read design
## §0.4 - the ruling would be revisitable, not broken.
func test_a_blast_gives_the_bonus_against_every_target() -> void:
	var second := MK2Fixture.create_dummy(game, SECOND_TILE, -10)
	var rpg := equip(RPG)
	await MK2Fixture.open_turn(game, mk2)

	cheat_every_die_to_six()
	var declared := await fire_and_capture(rpg, TARGET_TILE)

	assert_true(DeclaredAttackSummary.is_valid(declared),
		'Fixture: the shot actually resolved and handed back its declared attack.')
	if not DeclaredAttackSummary.is_valid(declared): return

	var bonused_targets:Array[Unit] = []
	for roll:AttackRoll in declared.attack_rolls:
		if got_the_bonus(roll): bonused_targets.append(roll.target_unit)

	assert_eq(declared.attack_rolls.size(), 2,
		'Fixture: one Blast, two per-target attack rolls in the same declared attack.')
	assert_has(bonused_targets, target, "The first target's own roll carried the +1.")
	assert_has(bonused_targets, second,
		"And so did the second target's roll, inside that same attack - the charge did not land"
		+ ' between them.')
	assert_eq(trait_uses(), 1,
		'The charge landed exactly once for the whole attack - not once per target, and not never.')
