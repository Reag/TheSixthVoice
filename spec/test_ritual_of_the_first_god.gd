# RITUAL OF THE FIRST GOD - Six Sky SP2, design 2.2, rulings 15-20.
#
#   "You may immediately teleport to a free space within Range 50 and make attacks against all Hostile
#    characters within Range 5 with your DAYKEEPER CYCLER BOW. All characters successfully hit this way
#    must succeed on a Systems save or become Slowed until the end of their next turn. Attacks made this
#    way do not generate Heat."
#
# THE DICE, per target in list order (closest first): the d20; the accuracy d6 (every target is within
# 5, so the bow's +1 always rolls one); on a hit, the Slowed SAVE (on-hit effects resolve inside the
# attack event, before the declared attack rolls damage); then the damage, a HIT and a CRIT column;
# then any Overkill rerolls, then any Heavenly Weaver 1d6. NO TAIL: an attack the test did not plan
# for rolls a real die, and the attack recorder below counts it anyway.
#
# THE TELEPORT is a move picker (TargetActionUtil.ask_for_movement over the helper's pathfinder), a
# move_tile request the plan recorder never sees, so testkit/prompt_watcher.gd captures it. It is
# answered by responder.chosen_move_tile, and before_each "cancels" it by answering with the
# bystander's occupied space, which no pathfinder offers (test_phase_cloud.gd's UNREACHABLE) - so
# every test that does not name a landing attacks from where the Six Sky stands.
#
# THE MAP IS 56 WIDE for the one test that needs a space 50 away; every other test works near the left
# edge.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ritual_of_the_first_god.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const RakshasaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const MAP_SIZE := Vector2i(56, 12)
const SIX_SKY_TILE := Vector2i(4, 5)
const NEAR := Vector2i(6, 5)      # 2 away
const MIDDLE := Vector2i(8, 5)    # 4 away
const EDGE := Vector2i(9, 7)      # 5 away
const OUTSIDE := Vector2i(10, 5)  # 6 away
const ALLY_TILE := Vector2i(5, 6)
const DRONE_TILE := Vector2i(4, 7)
## Far from everything: where the recorders' holder stands.
const BYSTANDER_TILE := Vector2i(30, 10)
## Occupied, so never offered: the harness's cancel for the Ritual's move picker.
const CANCEL_TELEPORT := BYSTANDER_TILE

## Crit landings: two from NEAR, and two from MIDDLE.
const NEAR_LANDING := Vector2i(6, 3)
const MIDDLE_LANDING := Vector2i(8, 7)

const SAVE_FAILS := 10  # fails the Six Sky's Save 11 with Systems 0
const SAVE_PASSES := 20
const MISS := 1         # 1 + an accuracy 1 = 2, a miss
const CRIT := Fixture.CRIT_ROLL

## One hit that passes its save and rolls 6/6: 9 damage. The accuracy die is a 1 - with a 6 the 15 would
## total 21 and CRIT, and every "hit" here would raise the crit menu.
const HIT_PASSING:Array[int] = [15, 1, SAVE_PASSES, 6, 6]
## One hit that fails its save.
const HIT_FAILING:Array[int] = [15, 1, SAVE_FAILS, 6, 6]
## One miss: no save.
const MISSING:Array[int] = [MISS, 1, 6, 6]
## One crit that passes its save.
const CRIT_PASSING:Array[int] = [CRIT, 6, SAVE_PASSES, 6, 6]

var game:Gamemaster
var responder
var six_sky:Unit
var bystander:Unit
var attacks:AttackRecorder
var watcher:PromptWatcher

## Every per-target attack, in order, with how many multiple-choice prompts had been raised by then.
class AttackRecorder extends ActionReaction:
	var targets:Array[Unit] = []
	var menus_seen:Array[int] = []
	var seen_ids:Array[StringName] = []
	var responder

	func _init() -> void:
		original_id = &'spec_ritual_attack_recorder' # else the gate is polled twice (harness traps)
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]: return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if seen_ids.has(triggering_event.id): return false
		seen_ids.append(triggering_event.id)
		targets.append(triggering_event.context.target_unit)
		menus_seen.append(responder.multiple_choice_prompts.size() if responder else -1)
		return false

## Kills `victim` the first time `when_attacking` is attacked (ATTACK POST): a death in the middle of
## the Ritual's sequence. A REAL reaction on an AI bystander, so no prompt ever asks.
class KillProbe extends ActionReaction:
	var when_attacking:Unit
	var victim:Unit
	var fired := false

	func _init() -> void:
		original_id = &'spec_ritual_kill_probe'
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]: return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return not fired and triggering_event.context.target_unit == when_attacking

	func activate(_context:Context, activation:EventCore) -> void:
		if fired: return
		fired = true
		await activation.execute_event(&'event_unit_die', {unit = victim})

func before_each() -> void:
	await get_tree().process_frame
	var made:Array = Fixture.create_game_with_prompts(self, MAP_SIZE)
	game = made[0]
	responder = made[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	six_sky = Fixture.create_six_sky(game, SIX_SKY_TILE)
	bystander = Fixture.create_dummy(game, BYSTANDER_TILE, 10, Faction.AI_ALLY)
	attacks = AttackRecorder.new()
	attacks.responder = responder
	install_on(bystander, attacks, &'spec_ritual_attack_recorder_kit')
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_TELEPORT

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.multiple_choice_queue.clear()
	responder.chosen_plan_queue.clear()
	responder.chosen_move_tile = Tile.INVALID

# ---------------------------------------------------------------- helpers

func install_on(unit:Unit, reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func dice(per_target:Array) -> Array[int]:
	var all:Array[int] = []
	for rolls in per_target: all.append_array(rolls)
	return all

func ritual_specific() -> SpecificAction:
	var gear:GearCore = six_sky.get_gear(Fixture.CORE_ID)
	if not GearCore.is_valid(gear): return null
	return SpecificAction.create(six_sky, gear, gear.kit.get_action(Fixture.RITUAL_ACTION))

func teleport_pickers() -> Array:
	return watcher.kinds(PromptWatcher.KIND.move_tile)

func landing_plan(tile:Vector2i) -> CompconPlan: return CompconPlan.create([tile], [], [])

# ---------------------------------------------------------------- the action (rulings 15, 20)

func test_the_ritual_is_a_full_action_that_spends_the_core_power():
	var specific := ritual_specific()
	assert_true(SpecificAction.is_valid(specific), 'fixture: the core Kit carries the Ritual.')
	if not SpecificAction.is_valid(specific): return
	assert_eq(specific.action.get_action_type(specific), Lancer.ACTION.FULL, 'Full action.')
	assert_ne(specific.action.consumes_core_power(), 0, 'It is the core power.')

func test_the_ritual_is_reachable_on_the_six_skys_turn():
	await Fixture.open_turn(game, six_sky)
	assert_true(UnitAction.can_activate_gear(ritual_specific()), 'A player can press it.')

func test_with_no_hostile_it_is_still_a_legal_use_and_spends_the_core_power():
	assert_true(six_sky.core.has_core_power, 'fixture: the core power is available.')
	await Fixture.press_ritual(game, six_sky)
	assert_false(six_sky.core.has_core_power, 'The core power is spent though nobody was in range.')
	assert_eq(attacks.targets.size(), 0, 'and nobody was attacked.')

# ---------------------------------------------------------------- the teleport (ruling 15)

func test_the_teleport_reaches_fifty_without_line_of_sight_and_not_fifty_one():
	UnitTile.move_to(six_sky, Vector2i(2, 5))
	var wall:Array[Vector2i] = []
	for y in MAP_SIZE.y: wall.append(Vector2i(3, y))
	RakshasaFixture.raise_wall(game, wall)
	assert_false(UnitTile.get_tiles_within(six_sky, 50, true).has(Vector2i(52, 5)),
		'fixture: the wall hides the far space.')
	responder.chosen_move_tile = Vector2i(52, 5)
	await Fixture.press_ritual(game, six_sky)
	var pickers := teleport_pickers()
	assert_eq(pickers.size(), 1, 'The Ritual offers a teleport.')
	if pickers.is_empty(): return
	var pathfinder:Pathfinder = pickers.front().pathfinder
	assert_true(pathfinder.is_movable(Vector2i(52, 5)), 'A space 50 away, out of sight, is offered...')
	assert_false(pathfinder.is_movable(Vector2i(53, 5)), '...and one 51 away is not.')
	assert_eq(six_sky.tile(), Vector2i(52, 5), 'and the Six Sky lands there.')

func test_a_cancelled_teleport_attacks_from_where_the_six_sky_stands():
	var near := Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_eq(teleport_pickers().size(), 1, 'fixture: the teleport was offered.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'Cancelled: it stays.')
	assert_eq(attacks.targets, [near] as Array[Unit], 'and still attacks.')

func test_immobilized_means_no_teleport_and_the_attacks_still_happen():
	var near := Fixture.create_dummy(game, NEAR)
	UnitCondition.apply_status(SpecFactory.dummy_event(), six_sky, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	responder.chosen_move_tile = Vector2i(20, 5)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'Immobilized: the preventable teleport does not happen.')
	assert_eq(attacks.targets, [near] as Array[Unit], 'The attacks still do.')

func test_the_teleport_arms_the_weaver_and_the_first_hit_takes_it_unhalved():
	var landing := Vector2i(20, 5)
	var first := Fixture.create_dummy(game, Vector2i(22, 5))
	var second := Fixture.create_dummy(game, Vector2i(24, 5))
	responder.chosen_move_tile = landing
	await Fixture.press_ritual(game, six_sky, dice([[15, 1, SAVE_PASSES, 6, 6, 6], HIT_PASSING]))
	assert_eq(six_sky.tile(), landing, 'fixture: the Six Sky teleported.')
	assert_eq(200 - Fixture.health(first), 15, 'The first hit takes the full Weaver 1d6: 9 + 6.')
	assert_eq(200 - Fixture.health(second), 9, 'The second hit takes none.')
	assert_eq(Fixture.weaver_chips(six_sky), 0, 'The chip is spent.')

# ---------------------------------------------------------------- the targets (rulings 4, 16)

func test_every_hostile_within_five_is_attacked_once_closest_first():
	# Registered FARTHEST first, so a "closest first" that merely kept map order would fail.
	var edge := Fixture.create_dummy(game, EDGE)
	var middle := Fixture.create_dummy(game, MIDDLE)
	var near := Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING, MISSING, HIT_PASSING]))
	assert_eq(attacks.targets, [near, middle, edge] as Array[Unit], 'Each once, closest first.')
	assert_eq(200 - Fixture.health(near), 9, 'The first dice went to the closest...')
	assert_eq(Fixture.health(middle), 200, '...the miss to the next...')
	assert_eq(200 - Fixture.health(edge), 9, '...and the last hit to the farthest.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'Every planned die was used, and no more were planned.')

func test_no_ally_no_drone_and_nobody_six_away_is_attacked():
	var near := Fixture.create_dummy(game, NEAR)
	Fixture.create_ally(game, ALLY_TILE)
	Fixture.create_drone(game, DRONE_TILE)
	Fixture.create_dummy(game, OUTSIDE)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_eq(attacks.targets, [near] as Array[Unit], 'Only the hostile CHARACTER within 5.')

func test_a_hostile_the_bow_cannot_see_is_skipped():
	var near := Fixture.create_dummy(game, NEAR)
	var hidden := Fixture.create_dummy(game, Vector2i(4, 9)) # 4 away, behind the wall
	RakshasaFixture.raise_wall(game, [Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)] as Array[Vector2i])
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_eq(attacks.targets, [near] as Array[Unit], 'A listed hostile the bow cannot attack is skipped.')
	assert_eq(Fixture.health(hidden), 200)

func test_a_target_killed_earlier_in_the_sequence_is_skipped():
	var near := Fixture.create_dummy(game, NEAR)
	var middle := Fixture.create_dummy(game, MIDDLE)
	var edge := Fixture.create_dummy(game, EDGE)
	var probe := KillProbe.new()
	probe.when_attacking = near
	probe.victim = middle
	install_on(bystander, probe, &'spec_ritual_kill_probe_kit')
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING, HIT_PASSING]))
	assert_true(probe.fired, 'fixture: the middle hostile died during the first attack.')
	assert_false(Unit.is_valid(middle), 'fixture: and is dead.')
	assert_eq(attacks.targets, [near, edge] as Array[Unit], 'The dead one is skipped; the list goes on.')

# ---------------------------------------------------------------- no heat (ruling 18)

func test_no_heat_self_and_no_overkill_heat_while_overkill_still_rerolls():
	var near := Fixture.create_dummy(game, NEAR)
	# hit column 1, crit column 6, then the Overkill reroll of the 1: a 5.
	await Fixture.press_ritual(game, six_sky, [15, 1, SAVE_PASSES, 1, 6, 5])
	assert_eq(200 - Fixture.health(near), 8, 'The 1 was rerolled to a 5: 5 + 3.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'The reroll consumed its die.')
	assert_eq(Fixture.heat(six_sky), 0, 'Neither Heat Self nor Overkill heat.')

# ---------------------------------------------------------------- Slowed (ruling 19)

func test_a_failed_save_slows_until_the_end_of_the_targets_next_turn():
	var near := Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([HIT_FAILING]))
	assert_true(Fixture.is_slowed(near), 'Hit, failed save: Slowed.')
	assert_eq(StatusType.get_standard_until(Lancer.STATUS.SLOWED), Lancer.UNTIL.END_OF_NEXT_TURN,
		'Slowed carries the standard END_OF_NEXT_TURN, which is what the on-hit applies.')
	await SpecFactory.start_turn(game, near)
	assert_true(Fixture.is_slowed(near), 'It lasts through the target next turn...')
	await SpecFactory.end_turn(game, near)
	assert_false(Fixture.is_slowed(near), '...and ends with it.')

func test_a_passed_save_gives_no_slowed():
	var near := Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_lt(Fixture.health(near), 200, 'fixture: the hit landed.')
	assert_false(Fixture.is_slowed(near), 'Passed: no Slowed.')

func test_a_miss_forces_no_save():
	var near := Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([MISSING]))
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'The miss popped no save die.')
	assert_false(Fixture.is_slowed(near))

func test_a_bow_shot_without_the_rituals_flag_carries_no_slowed_even_while_the_scope_is_live():
	# An Overwatch, or any reaction fired DURING the sequence, is an ordinary bow shot: no NO_SELF_HEAT.
	# Driven by hand, with the scope buff held as it is mid-Ritual. The control fires the same shot
	# WITH the flag.
	var target := Fixture.create_dummy(game, Vector2i(11, 5)) # 7 away: no accuracy die
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), six_sky, Fixture.RITUAL_BUFF, six_sky.get_gear(Fixture.CORE_ID))
	await Fixture.open_turn(game, six_sky)
	Dice.CHEAT_ROLL_QUEUE.assign([15, SAVE_FAILS, 6, 6])
	await SpecFactory.use_solo(game, six_sky, Fixture.BOW_ID, [target], [Action.FLAG.AS_FREEBIE])
	assert_lt(Fixture.health(target), 200, 'fixture: the shot landed.')
	assert_false(Fixture.is_slowed(target), 'No Ritual flag: no Slowed save.')
	Dice.CHEAT_ROLL_QUEUE.assign([15, SAVE_FAILS, 6, 6])
	await SpecFactory.use_solo(game, six_sky, Fixture.BOW_ID, [target], [Action.FLAG.AS_FREEBIE, Action.FLAG.NO_SELF_HEAT])
	assert_true(Fixture.is_slowed(target), 'Control: the Ritual-shaped shot does force it.')

# ---------------------------------------------------------------- crits after the Ritual (ruling 17)

func test_a_crit_resolves_only_after_the_last_attack():
	var near := Fixture.create_dummy(game, NEAR)
	var middle := Fixture.create_dummy(game, MIDDLE)
	responder.multiple_choice_queue.assign([-1])
	await Fixture.press_ritual(game, six_sky, dice([CRIT_PASSING, HIT_PASSING]))
	assert_eq(attacks.targets, [near, middle] as Array[Unit], 'fixture: both attacked.')
	assert_eq(attacks.menus_seen, [0, 0] as Array[int], 'No crit menu was raised while the attacks ran...')
	assert_eq(responder.multiple_choice_prompts.size(), 1, '...and the crit resolved after them.')

func test_two_crits_resolve_in_attack_order():
	var middle := Fixture.create_dummy(game, MIDDLE)
	var near := Fixture.create_dummy(game, NEAR)
	responder.multiple_choice_queue.assign([1, 1])
	responder.chosen_plan_queue.append(landing_plan(NEAR_LANDING))
	responder.chosen_plan_queue.append(landing_plan(MIDDLE_LANDING))
	await Fixture.press_ritual(game, six_sky, dice([CRIT_PASSING, CRIT_PASSING]))
	assert_eq(responder.multiple_choice_prompts.size(), 2, 'Two crits, two menus.')
	assert_eq(near.tile(), NEAR_LANDING, 'The first crit (the closer target) resolved first...')
	assert_eq(middle.tile(), MIDDLE_LANDING, '...and the second after it.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'Every attack was fired from the Ritual space.')

func test_a_recorded_crit_whose_target_died_offers_only_yourself():
	var near := Fixture.create_dummy(game, NEAR)
	var middle := Fixture.create_dummy(game, MIDDLE)
	var probe := KillProbe.new()
	probe.when_attacking = middle
	probe.victim = near
	install_on(bystander, probe, &'spec_ritual_kill_probe_kit')
	responder.multiple_choice_queue.assign([-1])
	await Fixture.press_ritual(game, six_sky, dice([CRIT_PASSING, HIT_PASSING]))
	assert_false(Unit.is_valid(near), 'fixture: the critted target died later in the sequence.')
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'Its crit still resolves...')
	if responder.multiple_choice_prompts.is_empty(): return
	assert_eq(responder.multiple_choice_prompts.front().labels,
		PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_self')]), '...offering only yourself.')

# ---------------------------------------------------------------- the scope ends (ruling 19)

func test_the_scope_buff_is_gone_after_the_ritual():
	Fixture.create_dummy(game, NEAR)
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING]))
	assert_eq(Fixture.ritual_buffs(six_sky), 0, 'The Ritual scope ends with the Ritual.')

func test_the_six_sky_dying_mid_sequence_leaves_no_scope_behind():
	var near := Fixture.create_dummy(game, NEAR)
	var middle := Fixture.create_dummy(game, MIDDLE)
	var probe := KillProbe.new()
	probe.when_attacking = near
	probe.victim = six_sky
	install_on(bystander, probe, &'spec_ritual_kill_probe_kit')
	await Fixture.press_ritual(game, six_sky, dice([HIT_PASSING, HIT_PASSING]))
	assert_true(probe.fired, 'fixture: the Six Sky died during the first attack.')
	assert_eq(attacks.targets, [near] as Array[Unit], 'Nothing is fired after it dies.')
	assert_eq(Fixture.health(middle), 200)
	assert_eq(Fixture.ritual_buffs(six_sky), 0, 'and no Ritual scope is left on it.')
