# TOE TO TOE (the Leoleth's first sheet trait, SP1 Task 2).
#
#   "At the end of its turn, if the Leoleth has not spent any of its standard movement, it may
#    Skirmish as a free action with a melee weapon that has not been used this turn."
#
# AN ActionReactionSelf ON end_turn / PRE, point-free and free-action (ruling 3, the Raleigh's Full
# Metal Jacket shape - content/frames/ipsn/mf_raleigh/mt_full_metal_jacket/action_full_metal_jacket.tres
# is triggers_on [end_turn], trigger_timing 0, consumes_rxn false, counts_as_free_action true).
#
# THE OFFER IS READ AT ITS SOURCE, NOT COUNTED AS A PROMPT. The weapon-pick menu is a
# ChoiceBus.TYPE.gear request, which testkit/prompt_watcher.gd does not report (prompt_watcher.gd:18-26),
# and with exactly one eligible weapon CommonActionUtil.choose_and_use does not raise it at all -
# it picks possible_actions[0] automatically for a player-controlled unit (common_action_util.gd:658-659).
# So every case below reads action.eligible_attacks(leoleth) directly, and the positive cases also
# assert the target actually took damage.
#
# THE DICE. A MELEE attack by the Leoleth pops a d20 and then its damage dice, and NOTHING in
# between: Dice.roll_d6_accuracy returns 0 without rolling when the bonus is 0 (dice.gd:86-88), and
# the 43 As (Task 3) forbids MELEE so it contributes no accuracy at all. mw_tactical_melee_weapon is
# 1d6+2 with no tags, so the queue is [d20, damage die] exactly.
#
# THE TARGET IS A 200 HP DUMMY so it survives every swing, and it is AI_ENEMY so its own ms_brace
# never raises a prompt - CommonActionUtil.confirm_use returns without asking for a non-player unit
# (common_action_util.gd:304).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_toe_to_toe.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(4, 6)
## Adjacent east: inside a threat-1 melee weapon's reach.
const ADJACENT_TILE := Vector2i(5, 6)
## Four tiles east of the Leoleth's start and still adjacent to nothing: the walk destination.
const FOUR_EAST := Vector2i(8, 6)
## One tile north: a single step, which costs exactly 1 speed on flat ground.
const ONE_STEP := Vector2i(4, 5)
## Far enough that no melee weapon can reach it.
const FAR_TILE := Vector2i(14, 6)
## Adjacent to FOUR_EAST, and adjacent to ONE_STEP: where the punching bag is put BACK so the two
## movement-gate cases below are about the budget and nothing else.
##
## MEASURED, NOT DRAFTED. The plan's draft of those two cases stood the target at FAR_TILE and never
## brought it back, so the reach clause of eligible_attacks (Departure 15) shut the gate and both
## cases went red for a reason that has nothing to do with movement. The target has to be out of the
## way for the walk and back in reach for the poll, which is the same step-away/step-back shape
## test_a_melee_weapon_with_nothing_in_reach_is_not_offered already uses.
const EAST_OF_FOUR_EAST := Vector2i(9, 6)
const EAST_OF_ONE_STEP := Vector2i(5, 5)

const D20_HITS := 19
## mw_tactical_melee_weapon is 1d6+2 with no Reliable, so 1 is a clean floor and 3 is a clean hit.
const DAMAGE_DIE := 3

var game:Gamemaster
var leoleth:Unit
var target:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, ADJACENT_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The trait's one action, off the LIVE unit's gear rather than off ContentLibrary - which is the
## only way to be sure the frame really carries it.
func reaction() -> ActionReactionSelf:
	var gear:GearCore = leoleth.get_gear(LeolethFixture.TOE_TO_TOE_ID)
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == LeolethFixture.TOE_TO_TOE_ACTION: return action
	return null

func offered_ids() -> Array[StringName]:
	var ids:Array[StringName] = []
	var action := reaction()
	if action == null: return ids
	for specific:SpecificAction in action.eligible_attacks(leoleth): ids.append(specific.gear.kit.compcon_id)
	return ids

## The gate itself, polled directly against a real END_TURN event core. The Sluagh close's
## carry-forward: activate re-derives the same clauses and aborts quietly, so an outcome assertion
## alone cannot tell "the gate refused" from "the attack fizzled".
func gate_open() -> bool:
	var action := reaction()
	if action == null: return false
	var gear:GearCore = leoleth.get_gear(LeolethFixture.TOE_TO_TOE_ID)
	return action.triggers_on_event(leoleth, gear, EventCore.create(&'event_turn_end', {unit = leoleth}))

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_wired_the_way_the_ruling_says():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.TOE_TO_TOE_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % LeolethFixture.TOE_TO_TOE_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	# ON THE FRAME, and reachable as GEAR on a live unit - a different claim from "the resource
	# exists". core.frame = <frame> alone never runs loadout.regenerate_derived_gear, so a trait wired
	# into the array but not reachable through get_gear would leave this ability completely dead while
	# every resource assertion stayed green.
	assert_true(GearCore.is_valid(leoleth.get_gear(LeolethFixture.TOE_TO_TOE_ID)),
		'And the live Leoleth carries it as gear.')
	var action := reaction()
	assert_not_null(action, 'The Kit carries %s.' % LeolethFixture.TOE_TO_TOE_ACTION)
	if action == null: return
	# THE FOUR DECLARATIVE CLAIMS OF RULING 3, each of which a mutation below reddens.
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.END_TURN] as Array[StringName],
		'It triggers on end_turn and nothing else.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE,
		'PRE - the only timing where current.speed still exists (event_turn_end.gd:17 then :70).')
	assert_false(action.consumes_rxn, 'It spends no reaction point.')
	assert_true(action.counts_as_free_action, 'And it is a free action, which is what the card calls it.')
	# IT STAYS IN THE TOOLTIP, and that needs the action to have an `.effect` row of ITS OWN.
	# Action.show_in_tooltip returns FALSE when an action's effect text equals the Kit's generic one
	# (action.gd:350-353), and Translate.action falls through to the Kit's key when the action has no
	# row - so "name row only" would have hidden this reaction outright and made its ICON_TARGETS row
	# fail the integrity guard's reverse check. The Subutai's mt_juggernaut_drive is the same shape
	# (an end_turn free-action trait reaction that IS drawn) and carries both rows for exactly this
	# reason: localizations.csv:104-106, Kit = the whole card, action = the bare effect.
	assert_true(action.show_in_tooltip(kit),
		'It STAYS in the tooltip: this reaction IS the card, unlike the hidden bookkeeping ones.')
	# The card's own text, off this mod's artifact rather than through tr(), so a sibling Reag-* mod
	# cannot hold it green.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('gear.mt_toe_to_toe.name'), StringName(''), 'It has a name row.')
	assert_ne(translation.get_message('gear.mt_toe_to_toe.effect'), StringName(''), 'And an effect row.')
	assert_eq(X.tr('gear.mt_toe_to_toe.name'), 'Toe To Toe', 'Named off the card.')
	assert_true(X.tr('gear.mt_toe_to_toe.effect').contains('has not spent any of its standard movement'),
		'And the effect row is the card, verbatim.')

# ---------------------------------------------------------------- the movement gate

func test_a_turn_with_no_movement_at_all_offers_and_lands_a_skirmish():
	LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'fixture: the budget is full.')
	assert_true(gate_open(), 'The gate is open on a turn with no movement spent.')
	assert_eq(offered_ids(), [LeolethFixture.MELEE_KIT] as Array[StringName],
		'And the one melee weapon is the whole offer.')

	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await SpecFactory.end_turn(game, leoleth)
	assert_gt(target.current_damage(), 0, 'The free Skirmish actually landed.')

func test_one_voluntary_step_forfeits_it():
	# ONE STEP, not a whole move: the card says "has not spent ANY of its standard movement", and the
	# ruling reads that as the budget being untouched. MovementType.create_for_standard_move is what
	# sets spend_move (movement_type.gd:58-61), which is the only thing event_unit_move subtracts on
	# (:244-245) - SpecFactory.move's own default is voluntary but NOT spend_move, and would leave
	# this test green for the wrong reason.
	LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	await LeolethFixture.walk(game, leoleth, ONE_STEP)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() - 1, 'fixture: one space is spent.')
	assert_false(gate_open(), 'One step forfeits the Skirmish.')

	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(target.current_damage(), 0, 'And nothing was swung.')

func test_a_boost_and_a_full_boosts_worth_of_steps_still_offers():
	# RULING 2'S WHOLE POINT, and the reason the gate is a number rather than a flag. Boost ADDS
	# get_boost_speed to the same pool the standard move spends from (event_unit_boost.gd:37,
	# unit_action.gd:474-478 = get_speed_max, so +4 here), and four steps take it back to exactly 4.
	# The Leoleth has moved four spaces and has still not spent any of its STANDARD movement.
	LeolethFixture.arm_melee(leoleth)
	LeolethFixture.step(target, FAR_TILE) # out of the way of the walk
	await LeolethFixture.open_turn(game, leoleth)
	await game.execute_event(&'event_unit_boost', {unit = leoleth})
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() * 2,
		'fixture: the Boost doubled the pool (get_boost_speed is get_speed_max).')
	await LeolethFixture.walk(game, leoleth, FOUR_EAST)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(),
		'fixture: four steps spent the Boost exactly, and the pool is back at max.')
	LeolethFixture.step(target, EAST_OF_FOUR_EAST) # back in reach: this case is about the budget
	assert_true(gate_open(), 'So the Skirmish is still offered - ruling 2.')
	assert_eq(leoleth.state.spaces_moved_this_turn, 4,
		'And spaces_moved_this_turn says 4, which is why the gate cannot be that number.')

func test_a_knockback_keeps_it():
	# An involuntary move never touches the budget: MovementType.create_for_involuntary builds a type
	# with spend_move left false (movement_type.gd:63-71), and event_unit_move subtracts only when
	# spend_move is set (:244-245). The Leoleth was shoved, not walked.
	LeolethFixture.arm_melee(leoleth)
	LeolethFixture.step(target, FAR_TILE)
	await LeolethFixture.open_turn(game, leoleth)
	await SpecFactory.move(game, leoleth, ONE_STEP, MovementType.create_for_involuntary(leoleth))
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'fixture: the budget is untouched.')
	assert_gt(leoleth.state.spaces_moved_this_turn, 0, 'fixture: but it really did move.')
	LeolethFixture.step(target, EAST_OF_ONE_STEP) # back in reach: this case is about the budget
	assert_true(gate_open(), 'A knockback keeps the Skirmish.')

# ---------------------------------------------------------------- the weapon filter

func test_a_melee_weapon_already_used_this_turn_is_not_offered():
	# "a melee weapon that has not been used this turn" IS the engine's per-turn usage tally:
	# GearCore.get_uses_this_turn(action) reads the action's usage group (gear_core.gd:183-188), and
	# spend() increments it for any non-freebie use (unit_action.gd:279).
	LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MELEE_KIT, target)
	var blade:GearCore = leoleth.get_gear(LeolethFixture.MELEE_KIT)
	assert_eq(blade.get_uses_this_turn(), 1, 'fixture: the swing was recorded against the turn.')
	assert_eq(offered_ids(), [] as Array[StringName], 'A weapon swung this turn is not offered again.')
	assert_false(gate_open(), 'And with nothing eligible the gate is shut.')

func test_a_superheavy_melee_weapon_is_never_offered():
	# ActionAttackWeapon.get_action_type returns FULL for a SUPERHEAVY and QUICK for everything else
	# (:87-91). A Superheavy needs Barrage, which is not a Skirmish, so the card cannot reach it.
	LeolethFixture.equip(leoleth, LeolethFixture.SUPERHEAVY_MELEE)
	await LeolethFixture.open_turn(game, leoleth)
	var drill:GearCore = leoleth.get_gear(LeolethFixture.SUPERHEAVY_MELEE)
	assert_true(GearCore.is_valid(drill), 'fixture: the Superheavy really is equipped.')
	assert_eq(offered_ids(), [] as Array[StringName], 'A SUPERHEAVY melee weapon is not a Skirmish.')
	assert_false(gate_open(), 'So the gate is shut with only that weapon aboard.')

func test_a_ranged_weapon_is_never_offered_and_neither_is_an_empty_rack():
	# Both halves of the same claim: the filter is MELEE, and a Leoleth carrying only a rifle has
	# nothing to offer. UnitAction.is_melee_weapon is the engine's own predicate
	# (unit_action.gd:549-553), which asks the ACTION's weapon_type rather than the Kit's name.
	LeolethFixture.arm_rifle(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	assert_true(GearCore.is_valid(leoleth.get_gear(LeolethFixture.MAIN_RIFLE)), 'fixture: the rifle is on.')
	assert_eq(offered_ids(), [] as Array[StringName], 'A rifle is not a melee weapon.')
	assert_false(gate_open(), 'And an all-ranged loadout shuts the gate.')

func test_a_destroyed_melee_weapon_is_not_offered():
	# GearCore.is_destroyed (:10) is the structure table's own flag, and a destroyed weapon cannot be
	# fired at all - offering it would raise a pick menu whose only entry then refuses.
	var blade:GearCore = LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(offered_ids(), [LeolethFixture.MELEE_KIT] as Array[StringName], 'fixture: it is offered first.')
	blade.is_destroyed = true
	assert_eq(offered_ids(), [] as Array[StringName], 'A destroyed weapon is not offered.')
	assert_false(gate_open(), 'And the gate shuts with it.')

func test_a_melee_weapon_with_nothing_in_reach_is_not_offered():
	# The Predator/Prey filter, verbatim in shape (action_predator_prey_concepts.gd:31-38): a weapon
	# that cannot hit anything is not an offer, it is an empty targeting screen at the end of every
	# single turn. UnitTargeting.get_tiles_targetable returns only tiles carrying a unit this action
	# can target, because a weapon's TargetRequirements leaves can_target_empty_tiles false
	# (unit_targeting.gd:91-106).
	LeolethFixture.arm_melee(leoleth)
	LeolethFixture.step(target, FAR_TILE)
	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(offered_ids(), [] as Array[StringName], 'Nothing in threat, nothing offered.')
	assert_false(gate_open(), 'So no prompt is raised at the end of a turn with no one nearby.')

	LeolethFixture.step(target, ADJACENT_TILE)
	assert_eq(offered_ids(), [LeolethFixture.MELEE_KIT] as Array[StringName],
		'And it comes back the moment something steps into reach.')

# ---------------------------------------------------------------- what "free" means

func test_the_free_skirmish_costs_no_reaction_and_no_per_turn_use():
	# "FREE ACTION" IS TWO ENGINE FACTS, not one. (1) consumes_rxn false means ActionReaction's own
	# is_available_to_activate returns early without asking UnitAction.can_take_reactions
	# (action_reaction.gd:49) and consumes_reaction() is false, so spend() never calls spend_reaction
	# (unit_action.gd:257). (2) The chosen Skirmish is activated with Action.FLAG.AS_FREEBIE, which
	# choose_and_use puts in the flag list itself (common_action_util.gd:693-696), and a freebie's
	# usage is recorded against the ROUND but not the TURN (unit_action.gd:279 passes
	# `not as_freebie` to increment_action_usage_for_action).
	#
	# THE ROUND TALLY IS ASSERTED TOO, and it is the half that proves the swing really happened
	# through the reaction rather than not at all.
	var blade:GearCore = LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	var reactions_before:int = leoleth.core.current.reactions
	assert_gt(reactions_before, 0, 'fixture: the Leoleth has a reaction point to lose.')

	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await SpecFactory.end_turn(game, leoleth)

	assert_gt(target.current_damage(), 0, 'LIVENESS: the Skirmish landed.')
	assert_eq(leoleth.core.current.reactions, reactions_before,
		'It spent no reaction point - consumes_rxn is false.')
	assert_eq(blade.get_uses_this_turn(), 0,
		'And no per-turn use: the Skirmish went through as a freebie.')
	assert_eq(blade.get_uses_this_round(), 1,
		'But the ROUND tally moved, which is how we know it really swung.')

func test_the_reaction_fires_inside_the_turn_while_actions_are_still_live():
	# WHY PRE RATHER THAN POST, measured rather than asserted from the .tres. handle_ending_unit
	# zeroes current.speed AND state.actions (event_turn_end.gd:69-70) inside execute, which runs
	# after the PRE block (:15-17) and before the POST queue (:46). At POST the gate would read 0
	# against a max of 4 and could never open again; the number the gate needs only exists at PRE.
	#
	# Asserted from the OTHER side - the numbers after the turn has ended - because the reaction
	# itself cannot report what it saw. If the swing landed, the gate read a full budget, and the only
	# moment that was true is inside the PRE block.
	LeolethFixture.arm_melee(leoleth)
	await LeolethFixture.open_turn(game, leoleth)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await SpecFactory.end_turn(game, leoleth)
	assert_gt(target.current_damage(), 0, 'The Skirmish landed.')
	assert_eq(leoleth.core.current.speed, 0, 'And by the time the turn is over the budget is zeroed.')
	assert_false(leoleth.state.is_taking_turn, 'The turn really did end.')
	assert_false(gate_open(), 'So the same gate, asked now, is shut - PRE was the only window.')
