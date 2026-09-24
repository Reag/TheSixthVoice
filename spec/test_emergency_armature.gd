# EMERGENCY ARMATURE (Hazard rank I system, SP2 Task 2, design ruling 9 + the SP2 pool ruling).
#
#   LIMITED 2, UNIQUE. SP 2. "You gain the Activate Emergency Armature reaction."
#   Activate Emergency Armature (Reaction, 1/round). Trigger: You take damage from a hostile
#   character. Effect: Expend a charge, you reduce the incoming damage by 1d6 and may move two
#   spaces. This movement ignores engagement and doesn't provoke reactions.
#
# THE HITS ARE RAW event_unit_damage EVENTS with `target_unit` naming the dealer - the engine's own
# "who did this" slot on a damage event (event_unit_attack_declared.gd:166), so every trigger clause
# can be driven exactly. The frame is armor 1, HP 10: a 5 lands 4 before the armature, and stays
# under Brace's "more than half your HP" line (action_brace.gd), so the only yes/no a hit raises is
# ours.
#
# THE 1d6 IS ROLLED ONCE, when the reaction resolves, and is a POOL across the damage types of one
# hit (author, 2026-09-24: "one pool"). Vanilla's buff_leadership_reduce re-rolls on every
# get_values - twice per damage event - and reduces every type in full. test_a_two_type_hit_draws_
# on_one_pool is what separates the two.
#
# THE RETICLE: the responder's chosen_move_tile. OFF_BOARD is unreachable, which cancels the move.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_emergency_armature.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')
const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const KIT_ID := &'ms_emergency_armature'
const ACTION_ID := &'action_activate_emergency_armature'
const REDUCE_BUFF := &'buff_emergency_armature_reduce'
## The plain vanilla melee weapon, threat 1: what makes the adjacent hostile able to Overwatch.
const MELEE_KIT := &'mw_tactical_melee_weapon'

const HAZARD_TILE := Vector2i(6, 6)
## Two east of the Hazard: NOT adjacent, so the Hazard starts unengaged. (A unit already engaged is
## not stopped again by the same enemy - would_lose_movement_due_to_engagement_from counts only NEW
## engagers, unit_relation.gd:133-145 - which is what the first draft of the control ran into.)
const ENGAGER := Vector2i(8, 6)
## Diagonally two from the Hazard. The only two-step path runs through (7, 7), which is adjacent to
## ENGAGER - an engaging tile - while (8, 8) itself is not.
const PAST_ENGAGEMENT := Vector2i(8, 8)
const FAR := Vector2i(6, 1)
const OFF_BOARD := Vector2i(29, 11)

var game:Gamemaster
var responder
var watcher
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	Fixture.equip(hazard, KIT_ID)
	hostile = Fixture.create_hostile(game, FAR)
	responder.chosen_move_tile = OFF_BOARD

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func gear() -> GearCore: return hazard.get_gear(KIT_ID)

func hp() -> int: return hazard.core.current.health

func offers() -> int: return responder.yesno_prompts.size()

## One damage event on the Hazard. `from` is the dealer (target_unit); null = no source at all.
func hit(amount:int, from:Unit = hostile, type:Lancer.DAMAGE_TYPE = Lancer.DAMAGE_TYPE.KINETIC, flags:Array = []) -> void:
	var data := {unit = hazard, number = amount, category = type, flags = flags}
	if Unit.is_valid(from): data.target_unit = from
	await game.execute_event(&'event_unit_damage', data)

## The 1d6 the armature rolls, then a tail of 1s.
func roll(reduction:int) -> void:
	Fixture.queue([reduction])

func accept() -> void: responder.yesno_queue.assign([true])
func decline() -> void: responder.yesno_queue.assign([false])

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 2, 'LIMITED 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var rxn := kit.actions[0] as ActionReaction
	assert_not_null(rxn, 'It is a reaction.')
	if rxn == null: return
	assert_eq(rxn.get_id(), ACTION_ID, 'Its id.')
	assert_eq(rxn.triggers_on, [&'damage'] as Array[StringName], 'On damage.')
	assert_eq(rxn.trigger_timing, ReactionBus.TIMING.PRE, 'Before it lands.')
	assert_true(rxn.consumes_rxn, 'A real reaction: it costs the point.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Emergency Armature', 'The name row.')
	assert_eq(X.tr('gear.%s.%s.name' % [KIT_ID, ACTION_ID]), 'Activate Emergency Armature', 'The reaction\'s name row.')
	assert_eq(X.tr('gear.%s.%s.trigger' % [KIT_ID, ACTION_ID]), 'You take damage from a hostile character.', 'The trigger row.')

# ---------------------------------------------------------------- the offer and the price

func test_a_hostile_hit_offers_and_yes_spends_a_charge_and_the_point_and_reduces_by_the_roll():
	accept()
	roll(3)
	await hit(5)
	assert_eq(offers(), 1, 'Offered once.')
	assert_eq(gear().charges_current, 1, 'A charge spent.')
	assert_eq(hazard.core.current.reactions, 0, 'The reaction point spent.')
	assert_eq(hp(), 10 - (5 - 1 - 3), '5, less armor 1, less the rolled 3: 1 lands.')
	assert_false(UnitCondition.has_buff(hazard, REDUCE_BUFF), 'The reduction is used up by the hit.')

func test_no_spends_nothing_and_reduces_nothing():
	decline()
	roll(3)
	await hit(5)
	assert_eq(offers(), 1, 'Offered.')
	assert_eq(gear().charges_current, 2, 'No charge spent.')
	assert_eq(hazard.core.current.reactions, 1, 'No point spent.')
	assert_eq(hp(), 10 - 4, 'The full 4 lands.')

func test_the_second_hit_in_a_round_is_not_offered():
	accept()
	await hit(5)
	responder.yesno_queue.assign([true])
	await hit(5)
	assert_eq(offers(), 1, 'The point is gone: the second hit raises nothing.')
	assert_eq(gear().charges_current, 1, 'And spends nothing.')

func test_two_uses_then_the_kit_is_silent():
	responder.yesno_queue.assign([true, true, true])
	await hit(3)
	await Fixture.cycle_turn(game, hazard) # the point comes back; charges do not
	await hit(3)
	assert_eq(gear().charges_current, 0, 'Both charges spent.')
	await Fixture.cycle_turn(game, hazard)
	await hit(3)
	assert_eq(offers(), 2, 'The third hit is not offered: LIMITED 2.')

# ---------------------------------------------------------------- the move

func test_the_reticle_offers_two_spaces():
	accept()
	await hit(5)
	var moves:Array = watcher.kinds(&'move_tile')
	assert_eq(moves.size(), 1, 'One reticle.')
	if moves.is_empty(): return
	assert_eq(moves[0].unit, hazard, 'For the Hazard.')
	var movable:Array = moves[0].pathfinder.movable_tiles
	assert_has(movable, HAZARD_TILE + Vector2i(2, 0), 'Two spaces is reachable.')
	assert_does_not_have(movable, HAZARD_TILE + Vector2i(3, 0), 'Three is not.')

## The tiles the armature's reticle offered, read off the pathfinder the player is shown.
##
## NOT THE TILE THE HAZARD ENDS ON. The spec responder answers a move request with its chosen tile
## outright, and the event walks there whatever the budget: measured 2026-09-24, a mutation that
## dropped ignore_engagement still "reached" PAST_ENGAGEMENT, by a THREE-step path on a budget of 2.
## What the rule governs is what the player can pick, so that is what is asserted.
func offered_tiles() -> Array:
	var moves:Array = watcher.kinds(&'move_tile')
	if moves.is_empty(): return []
	return moves[0].pathfinder.movable_tiles

func test_the_move_ignores_engagement():
	Fixture.step(hostile, ENGAGER)
	Fixture.equip(hostile, MELEE_KIT)
	accept()
	await hit(5)
	assert_has(offered_tiles(), PAST_ENGAGEMENT, 'The only two-step path to it crosses an engaging tile, and it is offered.')

func test_control_an_ordinary_two_space_move_is_stopped_by_engagement():
	# The same geometry through the engine's own pathfinder for an ordinary voluntary move: the
	# engaging tile ends it, so PAST_ENGAGEMENT is not offered. This is what makes the test above
	# discriminate.
	Fixture.step(hostile, ENGAGER)
	var plain:Pathfinder = await Pathfinder.generate_for_movement_budget(hazard, 2, MovementType.create(hazard, true))
	assert_does_not_have(plain.movable_tiles, PAST_ENGAGEMENT, 'Engagement holds an ordinary move short.')
	assert_has(plain.movable_tiles, HAZARD_TILE + Vector2i(-2, 0), 'fixture: the budget itself reaches two.')

## Start ADJACENT to an armed hostile - inside its threat, which is what arms vanilla's Overwatch
## (action_overwatch.gd: ENTIRE_MOVEMENT PRE, a reactable move by a unit in threat) - and step
## two away from it.
const ADJACENT := Vector2i(7, 6)
const AWAY := Vector2i(4, 6)

func test_the_move_provokes_no_overwatch():
	Fixture.step(hostile, ADJACENT)
	Fixture.equip(hostile, MELEE_KIT)
	responder.chosen_move_tile = AWAY
	accept()
	roll(3)
	await hit(5)
	assert_eq(hazard.tile(), AWAY, 'It moved out of threat.')
	assert_eq(hostile.core.current.reactions, 1, 'The hostile took no reaction.')

func test_control_an_ordinary_move_out_of_threat_is_overwatched():
	Fixture.step(hostile, ADJACENT)
	Fixture.equip(hostile, MELEE_KIT)
	responder.chosen_move_tile = AWAY
	await game.execute_event_block(EventBlock.create_multiple([EventCore.create(&'event_unit_pick_move', {
		target_unit = hazard, resource = MovementType.create(hazard, true), number = 2,
	})]))
	assert_eq(hostile.core.current.reactions, 0, 'An ordinary move out of threat spends the hostile Overwatch.')

func test_cancelling_the_reticle_keeps_the_reduction():
	accept()
	roll(3)
	await hit(5)
	assert_eq(hazard.tile(), HAZARD_TILE, 'The move was cancelled.')
	assert_eq(hp(), 10 - 1, 'The reduction still applied.')

func test_the_move_does_not_spend_the_hazards_own_movement():
	await Fixture.open_turn(game, hazard)
	var speed_before:int = hazard.core.current.speed
	responder.chosen_move_tile = HAZARD_TILE + Vector2i(-2, 0)
	accept()
	await hit(5)
	assert_eq(hazard.tile(), HAZARD_TILE + Vector2i(-2, 0), 'It moved.')
	assert_eq(hazard.core.current.speed, speed_before, 'A free move: its own speed is untouched.')

# ---------------------------------------------------------------- who counts as the dealer

func test_a_hostile_drones_hit_offers_because_its_owner_is_the_attacker():
	var drone := Fixture.create_drone(game, Vector2i(10, 6), Faction.AI_ENEMY)
	LeolethFixture.own_drone(drone, hostile)
	accept()
	await hit(5, drone)
	assert_eq(offers(), 1, 'An owned hostile drone\'s hit is its owner\'s.')

func test_an_unowned_hostile_drones_hit_does_not_offer():
	var drone := Fixture.create_drone(game, Vector2i(10, 6), Faction.AI_ENEMY)
	await hit(5, drone)
	assert_eq(offers(), 0, 'A drone is not a character.')

func test_an_allys_hit_does_not_offer():
	var ally := Fixture.create_ally(game, Vector2i(10, 6))
	await hit(5, ally)
	assert_eq(offers(), 0, 'Friendly fire is not from a hostile.')

func test_self_inflicted_damage_does_not_offer():
	await hit(5, hazard, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.SELF_INFLICTED])
	assert_eq(offers(), 0, 'Our own damage is not from a hostile.')

func test_heat_does_not_offer():
	await hit(2, hostile, Lancer.DAMAGE_TYPE.HEAT)
	assert_eq(offers(), 0, 'Heat is not damage.')

func test_an_end_of_turn_burn_tick_does_not_offer():
	# event_turn_end.gd:101-106: the tick names no dealer and is NO_REDUCE, so "from a hostile
	# character" cannot be established and the 1d6 could not reduce it anyway.
	await hit(3, null, Lancer.DAMAGE_TYPE.BURN, [EventService.DAMAGE_FLAG.NO_REDUCE, EventService.DAMAGE_FLAG.IS_EOT_BURN])
	assert_eq(offers(), 0, 'A sourceless burn tick raises nothing.')

func test_a_hostile_burn_hit_offers():
	accept()
	await hit(3, hostile, Lancer.DAMAGE_TYPE.BURN)
	assert_eq(offers(), 1, 'Burn dealt by a hostile is damage from a hostile.')

func test_a_hit_zeroed_by_armor_does_not_offer():
	await hit(1)
	assert_eq(offers(), 0, 'Armor 1 took the whole 1: no damage taken, nothing to answer.')

# ---------------------------------------------------------------- the pool

func test_a_two_type_hit_draws_on_one_pool():
	# Two damage events in one block, the first flagged SKIP_CONSUMING_RESIST_BUFFS - exactly how
	# event_unit_attack_declared.gd:154-169 delivers a two-type hit. No AttackRoll object, so armor
	# 1 applies to each: Kinetic 3 lands 2, Energy 4 lands 3, 5 in all. The pool is 3: the first
	# type uses 2 of it (landing 0), the second the last 1 (landing 2).
	#   one pool:            10 - 2 = 8
	#   one roll every type: 10 - 0 = 10
	accept()
	roll(3)
	var hostile_flags:Array = [EventService.DAMAGE_FLAG.SKIP_CONSUMING_RESIST_BUFFS]
	await game.execute_event_block(EventBlock.create_multiple([
		EventCore.create(&'event_unit_damage', {unit = hazard, number = 3, category = Lancer.DAMAGE_TYPE.KINETIC, flags = hostile_flags, target_unit = hostile}),
		EventCore.create(&'event_unit_damage', {unit = hazard, number = 4, category = Lancer.DAMAGE_TYPE.ENERGY, flags = [], target_unit = hostile}),
	]))
	assert_eq(offers(), 1, 'Offered once, on the first type.')
	assert_eq(hp(), 8, 'The 3 covered the first type\'s 2 and one of the second\'s 3.')
	assert_false(UnitCondition.has_buff(hazard, REDUCE_BUFF), 'Consumed after the last type.')

func test_the_pool_is_rolled_once():
	# A re-rolling reduction would pop the tail's 1s on every get_values and reduce by 1, not 4.
	accept()
	roll(4)
	await hit(5)
	assert_eq(hp(), 10, '5, less armor 1, less the one rolled 4: nothing lands.')
