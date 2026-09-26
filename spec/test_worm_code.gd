# WORM CODE (Rakshasa trait, design 1.2, rulings 3-6):
#
#   "1/round, when a hostile character fails a save the Rakshasa forced, it may have them take 2 heat."
#
# The Lesson of the Open Door's shape (action_the_lesson_of_the_open_door.gd) with the Vauban's gates
# (action_grav_amped_shock.gd): a forced_save POST reaction, no reaction point, 1/round on its own
# usage group, a yes/no BEFORE the round is spent. "The Rakshasa forced" is the forcer's
# get_owner_unit_or_self(), so a save its mine forces counts (ruling 4). "Hostile character" is
# is_actor() (rulings row 301, re-confirmed for this frame at SP1): a drone is not one.
#
# EVERY SAVE IS FORCED THROUGH UnitHasecheck WITH A FULL TRIFECTA (vauban_fixture.forcer), never by
# raising event_unit_save by hand: execute_event returns void, and roll_check drops a forcer that is
# not unit AND gear AND action.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_worm_code.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')

const RAKSHASA_TILE := Vector2i(3, 4)
const HOSTILE_TILE := Vector2i(7, 4)
## Vanilla Smite's own invade: it forces a Systems save on a hit (action_smite.gd:19).
const SMITE_ACTION := &'action_smite'

var game:Gamemaster
var responder
var rakshasa:Unit
var hostile:Unit

func before_each() -> void:
	# A synchronous test ahead of an async one leaves its responder on the bus for the next
	# (memory lancer-tactics-spec-harness-traps, Koremasa SP5).
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self)
	game = built[0]
	responder = built[1]
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _action() -> Action:
	var gear:GearCore = rakshasa.get_gear(Fixture.WORM_CODE_ID)
	return gear.get_action(Fixture.WORM_CODE_ACTION) if GearCore.is_valid(gear) else null

## Fail a save of `saver`'s in `forcing`'s name, and hand back whether it passed (for a vacuity guard).
func fail_hull(saver:Unit, forcing:SpecificAction) -> bool:
	Fixture.queue_a_failure()
	return await Fixture.force_hull_save(self, saver, forcing)

# ---------------------------------------------------------------- shape

func test_the_trait_carries_one_quiet_non_consuming_reaction():
	var gear:GearCore = rakshasa.get_gear(Fixture.WORM_CODE_ID)
	assert_true(GearCore.is_valid(gear), 'The Rakshasa carries Worm Code.')
	var action = _action()
	assert_not_null(action, 'Worm Code carries its reaction.')
	if action == null: return
	assert_true(action is ActionReaction, 'It is a reaction.')
	assert_eq(action.triggers_on, [&'forced_save'] as Array[StringName], 'It listens to forced saves.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, 'At POST, where the result exists.')
	assert_false(action.consumes_reaction(), 'It spends no reaction point: the card says 1/round, not Reaction.')
	assert_eq(action.get_per_round_hard_limit(SpecificAction.create(rakshasa, gear, action)), 1, '1/round.')
	assert_eq(action.usage_group, Fixture.WORM_CODE_USAGE, 'On its own usage group.')

# ---------------------------------------------------------------- the trigger

func test_a_hostile_failing_a_save_the_rakshasa_forced_takes_two_heat():
	var before := Fixture.heat(hostile)
	var passed := await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(hostile) - before, 2, '2 heat.')
	assert_eq(responder.yesno_prompts.size(), 1, 'After one "may" prompt.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 1, 'The round is spent.')

func test_the_heat_does_not_land_on_the_rakshasa():
	var before := Fixture.heat(rakshasa)
	var hostile_before := Fixture.heat(hostile)
	var passed := await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save really rolled.')
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(rakshasa), before, 'The saver takes it, not the forcer.')
	assert_eq(Fixture.heat(hostile) - hostile_before, 2, 'The hostile took the 2.')
	assert_eq(responder.yesno_prompts.size(), 1, 'After exactly one "may" prompt.')

func test_a_systems_save_counts_the_same_as_a_hull_save():
	var before := Fixture.heat(hostile)
	Fixture.queue_a_failure()
	var passed:bool = await Fixture.force_systems_save(self, hostile, Fixture.forcer(rakshasa))
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'Any save: a Systems save too.')

func test_a_passed_save_costs_nothing_and_asks_nothing():
	var before := Fixture.heat(hostile)
	Fixture.queue_a_pass()
	var passed:bool = await Fixture.force_hull_save(self, hostile, Fixture.forcer(rakshasa))
	assert_true(passed, 'fixture: the save passed.')
	assert_eq(Fixture.heat(hostile), before, 'The card says FAILS.')
	assert_eq(responder.yesno_prompts.size(), 0, 'No prompt.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 0, 'The round is untouched.')

func test_a_save_somebody_else_forced_costs_nothing():
	var stranger := Fixture.create_ally(game, Vector2i(3, 7))
	var before := Fixture.heat(hostile)
	var passed := await fail_hull(hostile, Fixture.forcer(stranger))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save really rolled.')
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(hostile), before, 'The card says a save THE RAKSHASA forced.')
	assert_eq(responder.yesno_prompts.size(), 0, 'No prompt.')

func test_a_save_the_rakshasas_mine_forced_counts():
	# Ruling 4: the forcer's owner-or-self. The mine is deployed for real and then asked to force a
	# save directly (test_grav_amped_interference.gd's reasoning: detonation is an interactive pick).
	var gear := Fixture.equip(rakshasa, Fixture.MINES)
	await Fixture.open_turn(game, rakshasa)
	await SpecFactory.use(game, rakshasa, Fixture.MINES, Fixture.MINE_ACTION, Vector2i(5, 6))
	var deployed:Array = UnitAction.get_deployables_from(rakshasa, gear)
	assert_false(deployed.is_empty(), 'fixture: a mine was deployed.')
	if deployed.is_empty(): return
	var mine:Unit = deployed.front()
	var before := Fixture.heat(hostile)
	var passed := await fail_hull(hostile, Fixture.forcer(mine, Fixture.MINE_KIT))
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'The mine forced it, and the mine is the Rakshasa.')

func test_an_ally_failing_the_same_save_takes_nothing():
	var ally := Fixture.create_ally(game, Vector2i(5, 7))
	var before := Fixture.heat(ally)
	var passed := await fail_hull(ally, Fixture.forcer(rakshasa))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save really rolled.')
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(ally), before, 'The card says a HOSTILE character.')
	assert_eq(responder.yesno_prompts.size(), 0, 'No prompt.')

func test_a_hostile_drone_failing_the_same_save_takes_nothing():
	# is_actor(), not is_character(): make_hull_save lets a drone roll (it IS is_character), so the
	# event is raised and only the trait's own clause can refuse it.
	var drone := Fixture.create_hostile_drone(game, Vector2i(9, 6))
	var before := Fixture.heat(drone)
	var passed := await fail_hull(drone, Fixture.forcer(rakshasa))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save really rolled.')
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(drone), before, 'A drone is not a character (rulings row 301).')
	assert_eq(responder.yesno_prompts.size(), 0, 'No prompt.')

func test_a_save_forced_with_no_gear_or_action_costs_nothing():
	# The Vauban's M-3: the saver's buffs never see a forcer that is not a full trifecta, so neither
	# does this trait. No vanilla caller forces a save this way.
	var before := Fixture.heat(hostile)
	var passed := await fail_hull(hostile, SpecificAction.create(rakshasa, null, null))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save really rolled.')
	assert_false(passed, 'fixture: the save failed.')
	assert_eq(Fixture.heat(hostile), before, 'An incomplete forcer does not reach Worm Code.')

# ---------------------------------------------------------------- 1/round and the "may"

func test_the_second_failure_in_a_round_costs_nothing_more():
	var before := Fixture.heat(hostile)
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	var second := await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_false(second, 'fixture: the second save failed too.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'Two failures, one Worm Code.')
	assert_eq(responder.yesno_prompts.size(), 1, 'And one prompt: the second is not offered.')

func test_a_second_hostile_in_the_same_round_is_not_offered_either():
	# 1/round on the Rakshasa, not per character (the Vauban's shock is per character; this is not).
	var other := Fixture.create_hostile(game, Vector2i(9, 2))
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	var before := Fixture.heat(other)
	await fail_hull(other, Fixture.forcer(rakshasa))
	assert_eq(Fixture.heat(other), before, 'The round was spent on the first.')

func test_declining_keeps_the_round():
	responder.yesno_queue.assign([false])
	var before := Fixture.heat(hostile)
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_eq(Fixture.heat(hostile), before, 'Declined: no heat.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 0, 'And the round is not spent.')
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_eq(Fixture.heat(hostile) - before, 2, 'So the next failure that round is offered, and taken.')
	assert_eq(responder.yesno_prompts.size(), 2, 'Two prompts, one per failure.')

func test_the_round_resets_at_the_rakshasas_own_turn_start():
	var before := Fixture.heat(hostile)
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	await Fixture.cycle_turn(game, rakshasa)
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_eq(Fixture.heat(hostile) - before, 4, 'The cadence reset when its turn started (ruling 3).')

func test_a_rakshasa_with_no_reaction_point_left_still_offers():
	# consumes_rxn = false is load-bearing only through availability: a consuming reaction is refused
	# at zero points (unit_action.gd can_take_reactions). The card is not a Reaction.
	rakshasa.core.current.reactions = 0
	var before := Fixture.heat(hostile)
	await fail_hull(hostile, Fixture.forcer(rakshasa))
	assert_eq(Fixture.heat(hostile) - before, 2, 'No reaction point needed.')
	assert_eq(rakshasa.core.current.reactions, 0, 'And none was spent.')

# ---------------------------------------------------------------- inside the Ensorcel window

func test_worm_code_is_not_offered_inside_the_ensorcel_window():
	# AUTHOR'S RULING (rulings "Worm Code inside the Ensorcel window"): Ensorcel "cannot apply any heat",
	# so while the saver holds the Ensorcel suppressor Worm Code is not offered and does not spend - its
	# round is kept for a later save. Smite through Ensorcel forces a Systems save inside the window.
	Fixture.equip(rakshasa, Fixture.SMITE)
	responder.chosen_yesnos = true
	await Fixture.choose_mode(game, rakshasa, responder, Fixture.MODE.ENSORCEL)
	var before := Fixture.heat(hostile)
	Fixture.queue_a_failure()
	await Fixture.ensorcel(game, rakshasa, hostile, responder, Fixture.SMITE, SMITE_ACTION)
	assert_true(Fixture.d20_was_rolled(), 'fixture: Smite\'s save really rolled.')
	assert_true(hostile.has_status(Lancer.STATUS.STUNNED), 'fixture: and failed (Smite Stunned them).')
	assert_false(UnitCondition.has_buff(hostile, Fixture.ENSORCEL_SUPPRESSOR), 'fixture: the window is closed.')
	assert_eq(responder.yesno_prompts.size(), 0, 'Worm Code is not offered in the window.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 0, 'And its round is kept.')
	assert_eq(Fixture.heat(hostile), before, 'No heat reached the hostile.')

	# The same round, outside the window: an ordinary forced save IS offered, and takes the round.
	Fixture.queue_a_failure()
	var passed:bool = await Fixture.force_systems_save(self, hostile, Fixture.forcer(rakshasa))
	assert_true(Fixture.d20_was_rolled(), 'fixture: the follow-up save really rolled.')
	assert_false(passed, 'fixture: and failed.')
	assert_eq(responder.yesno_prompts.size(), 1, 'Offered once, now.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'And the 2 heat lands.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 1, 'The kept round is spent here.')
