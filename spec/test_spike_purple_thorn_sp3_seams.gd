# PURPLE THORN SP3 PROBE (design §3.0, ruling 13(b)): does a PLAYER-targeted Lock On's UNIT_ACTION
# POST carry the chosen target in `target_units`?
#
# Hyperfocus ends "if you take any actions that affect a different hostile character"; the author
# chose attacks PLUS tech systems. Attacks carry their targets in the declared-attack summary. A
# tech SYSTEM like Lock On does not attack, so the only place its target could reach a buff is the
# virtual event_unit_action that event_gear_activate queues at POST (event_gear_activate.gd:110-111),
# whose `target_units` is the activation context's own array, passed by reference (:126).
#
# THE READING PREDICTS NO. The player's bar calls event_gear_activate with no targets at all
# (phase_ui_player_action.gd:172-179), and ActionSystemApplyStatus.activate takes the player's plan
# into a LOCAL array (action_system_apply_status.gd:53-56) - nothing writes it back to the context.
# So this probe mimics the bar exactly: no targets, [CAN_FOLLOWUP], the responder picking the second
# hostile through the compcon plan.
#
# CONTROL (the liveness of the reader): an AI-shaped activation, the target SUPPLIED in the event,
# must show it - otherwise an empty array would be the watcher's fault, not the engine's.
#
# Yes = build 13(b). No = drop 13(b), record the divergence in rulings.md, build 13(a) only.
#
# No production code.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_purple_thorn_sp3_seams.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const LOCK_ON := &'ms_lock_on'
const ACTOR_TILE := Vector2i(4, 6)
const FIRST_TILE := Vector2i(7, 6)
const SECOND_TILE := Vector2i(9, 6)


## A point-free, hidden UNIT_ACTION POST reaction: records what the actor's own activations carry.
class ActionWatcher extends ActionReaction:
	## One record per activation: {kit, targets:Array[Unit]}.
	var seen:Array[Dictionary] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.UNIT_ACTION]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == unit

	func activate(context:Context, _activation:EventCore) -> void:
		var c:Context = context.event.context
		var targets:Array[Unit] = []
		targets.assign(c.target_units)
		seen.append({kit = c.string, targets = targets})


var game:Gamemaster
var responder
var actor:Unit
var first:Unit
var second:Unit
var watcher:ActionWatcher


func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	actor = SpecFactory.create_unit(game.map, ACTOR_TILE, Faction.PLAYER)
	first = Fixture.create_hostile(game, FIRST_TILE)
	second = Fixture.create_hostile(game, SECOND_TILE)
	watcher = ActionWatcher.new()
	var kit := Kit.new()
	kit.compcon_id = &'spike_unit_action_watcher'
	kit.is_trait = true
	kit.actions.append(watcher)
	actor.core.loadout.equipped_kits.append(kit)
	actor.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	await Fixture.open_turn(game, actor)

func after_each() -> void:
	responder.chosen_plan_queue.clear()


func lock_on_records() -> Array[Dictionary]:
	var records:Array[Dictionary] = []
	for record:Dictionary in watcher.seen:
		if StringName(record.kit) == LOCK_ON: records.append(record)
	return records

func lock_on_gear() -> GearCore:
	return actor.get_gear(LOCK_ON)


func test_control_a_supplied_target_is_carried():
	assert_true(GearCore.is_valid(lock_on_gear()), 'fixture: every unit carries the basic Lock On.')
	await game.execute_event(&'event_gear_activate', {
		unit = actor, gear = lock_on_gear(), action = lock_on_gear().get_solo_action(),
		target_units = [second],
	})
	assert_true(second.has_status(Lancer.STATUS.LOCKON), 'fixture: the supplied target was locked.')
	var records := lock_on_records()
	assert_eq(records.size(), 1, 'LIVENESS: the watcher saw the Lock On at UNIT_ACTION POST.')
	if records.is_empty(): return
	assert_eq(records[0].targets, [second] as Array[Unit], 'CONTROL: a supplied target IS in target_units.')

func test_probe_a_player_picked_target_reaches_unit_action_post():
	responder.chosen_plan_queue.append(CompconPlan.create([SECOND_TILE], [], [second]))
	# The bar's own call: no targets, CAN_FOLLOWUP (phase_ui_player_action.gd:172-179).
	await game.execute_event(&'event_gear_activate', {
		unit = actor, gear = lock_on_gear(), action = lock_on_gear().get_solo_action(),
		flags = [Action.FLAG.CAN_FOLLOWUP],
	})
	assert_true(second.has_status(Lancer.STATUS.LOCKON), 'fixture: the player picked the second hostile and it was locked.')
	assert_false(first.has_status(Lancer.STATUS.LOCKON), 'fixture: the first was not.')
	var records := lock_on_records()
	assert_eq(records.size(), 1, 'LIVENESS: the watcher saw the Lock On at UNIT_ACTION POST.')
	if records.is_empty(): return
	# THE MEASUREMENT. Whatever this reads is recorded; the claim the design needed is [second].
	gut.p('PROBE: player-picked Lock On target_units = %s' % [records[0].targets])
	assert_eq(records[0].targets, [] as Array[Unit],
		'MEASURED: a player-picked target does NOT reach UNIT_ACTION POST - the plan is local to activate.')
