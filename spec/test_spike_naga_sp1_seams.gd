# NAGA SP1 PROBES (design §1.0): the two engine seams this frame is built on and this mod has never
# used, measured with knockoff Kits on vanilla units before any content is written.
#
# PROBE 1 - WIRE SLITHER's trigger (ruling 6). Does a `unit_action` POST reaction on a TRAIT Kit
# reach the bus with the ACTION in the triggering context, and does ruling 6's tech predicate -
# `action is ActionAttackTech or (action is ActionSystem and action.is_tech)`, UnitAction.is_tech's
# own two clauses (unit_action.gd:567-571) applied to the action instead of the Kit - accept Lock On,
# Scan and an invade, and refuse Boost and a weapon attack? event_gear_activate queues UNIT_ACTION
# POST only when the gear's use count rose (:100-111), through a virtual event_unit_action whose
# context carries unit, gear, action, target_units and flags (:119-132). Universal Compatibility and
# Mine Deployers are the vanilla readers; neither asks whether the action was tech.
#
# PROBE 2 - SALVATION UPON THE WICKED's trigger (rulings 8 and 20). Does `statuses_changed` POST fire
# when Lock On is CONSUMED (action_consume_lock_on.gd:42 clears it with NO source, from inside the
# attack_declared PRE reaction) and when it is cleared by an ability (Stabilize's line is
# clear_status_via_ability -> clear_specific_status, unit_condition.gd:326-329, which hands the
# status's OWN source on), with `category_str == Lancer.STATUS.LOCKON`, and is `string` EMPTY in the
# consume case and the locker's gear id in the other? That last pair is the fact ruling 20 records
# for the Black Mountain: after a consume nobody can read whose lock it was.
#
# MUTATIONS. Probe 1: INCLUDE_TECH_ATTACKS := false drops the ActionAttackTech clause - the invade
# case must go red and the four others stay green. Probe 2: TIMING := PRE - the watcher is installed
# AFTER the lock lands, so the apply (which is what PRE reports, unit_condition.gd:165-167) is never
# seen and BOTH loss cases must go red on their count line.
#
# If either probe is red on its claim with its LIVENESS line green, stop and report (design §1.0):
# there is no fallback that keeps the card.
#
# No production code. The real reactions are built on mt_wire_slither and cp_shimmering_veil.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_naga_sp1_seams.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## MUTATION KNOBS. Both are the claim under test as written.
const INCLUDE_TECH_ATTACKS := true
const TIMING := ReactionBus.TIMING.POST

## Basic-loadout Kits every player mech carries (content/gear/basic/basic_loadout_mech_player.tres):
## three tech actions and two non-tech controls.
const LOCK_ON := &'ms_lock_on'
const LOCK_ON_ACTION := &'action_lock_on'
const SCAN := &'ms_scan'
const SCAN_ACTION := &'action_scan'
const INVADE := &'ms_fragment_signal' # an ActionAttackTech, is_invade
const BOOST := &'ms_boost'
const RIFLE := &'mw_assault_rifle' # a MAIN weapon, equipped by hand

const ACTOR_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(7, 4) # 3 out: inside Sensors, inside rifle range, outside threat

var game:Gamemaster
var actor:Unit
var target:Unit


## PROBE 1's reaction: ruling 6's predicate on a point-free, hidden ActionReactionSelf.
class TechWatcher extends ActionReactionSelf:
	## The action object of every trigger that passed the predicate, in order.
	var seen:Array[Action] = []
	## Every action the predicate was ASKED about - the liveness record, gate or no gate.
	var asked:Array[Action] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.UNIT_ACTION]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.action]

	func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
		if not super.triggers_on_event(unit, gear, triggering_event): return false
		var action:Action = triggering_event.context.action
		asked.append(action)
		return is_tech_action(action)

	static func is_tech_action(action:Action) -> bool:
		if INCLUDE_TECH_ATTACKS and action is ActionAttackTech: return true
		return action is ActionSystem and action.is_tech

	func activate(context:Context, _activation:EventCore) -> void:
		seen.append(context.event.context.action)


## PROBE 2's reaction: a statuses_changed watcher for LOCKON on ANY unit, point-free and hidden.
class LossWatcher extends ActionReaction:
	## One record per LOCKON change seen: {unit, source}.
	var seen:Array[Dictionary] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.STATUSES_CHANGED]
		trigger_timing = TIMING
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.category]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.category_str == Lancer.STATUS.LOCKON

	func activate(context:Context, _activation:EventCore) -> void:
		var triggering:Context = context.event.context
		seen.append({unit = triggering.unit, source = triggering.string})


func before_each() -> void:
	game = Fixture.create_game(self)
	actor = SpecFactory.create_unit(game.map, ACTOR_TILE, Faction.PLAYER)
	actor.core.full_repair()
	target = Fixture.create_dummy(game, TARGET_TILE, 10, Faction.AI_ENEMY)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## The knockoff Kit on the actor's own loadout as a runtime trait Kit (the Leoleth probe's idiom).
## full_repair() regenerates derived gear, which is where the Kit's reaction gets indexed by trigger.
func install(reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	actor.core.loadout.equipped_kits.append(kit)
	actor.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## Open the actor's turn: Lock On, Scan and Boost are QUICK actions and UnitAction refuses one
## outside a turn. Cycles it if already open, so every case starts from the same state.
func open_turn() -> void:
	if actor.state.is_taking_turn: await SpecFactory.end_turn(game, actor)
	await SpecFactory.start_turn(game, actor)

## [these], then a long tail of 1s - the Sluagh fixture's queue(), inline.
func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 40: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

func lock_on() -> void:
	await open_turn()
	await SpecFactory.use(game, actor, LOCK_ON, LOCK_ON_ACTION, target)

func scan() -> void:
	await open_turn()
	await SpecFactory.use(game, actor, SCAN, SCAN_ACTION, target)

## One invade d20; no accuracy die without a modifier; a tech attack's flat '2' rolls nothing.
func invade() -> void:
	await open_turn()
	queue([19])
	await SpecFactory.use_solo(game, actor, INVADE, target)

func boost() -> void:
	await open_turn()
	await SpecFactory.use_solo(game, actor, BOOST)

## The d20, then (only when a lock is consumed) its +1 accuracy die, then the damage die.
func shoot() -> void:
	actor.core.equip_system(RIFLE)
	SpecFactory.apply_passive_buffs(actor)
	await open_turn()
	queue([19, 3, 3])
	await SpecFactory.use_solo(game, actor, RIFLE, target)

## LIVENESS for probe 1: the bus asked the predicate about the activation - at least once - and every
## poll handed it an action of the class the case used.
##
## NOT "exactly once", AND NOT BY FILENAME. MEASURED on this file's first two runs (2026-09-22): the
## bus polls triggers_on_event FOUR times for a targeted action (Lock On, Scan, the invade) and THREE
## for Boost and the rifle shot, for ONE activation each - queue_reaction_events evaluates the trigger
## set when it queues and the block re-evaluates before it runs. And the action object it hands over
## is not always the same instance: an action inlined in its Kit's .tres reports its sub-resource path
## (`ms_fragment_signal.tres::Resource_5rq42`), and one poll per attack sees a DUPLICATE with an empty
## resource_path (the variant-composed copy event_gear_activate makes). AND THE REACTION'S OWN
## ACTIVATION IS A unit_action TOO: when the watcher fires, the bus polls it once more about ITSELF
## (measured on the third run - the fourth poll's action was this inner class, script path empty). So
## a production predicate must be PURE (no spend, no stamp, no prompt in triggers_on_event), must read
## the action by CLASS and FLAG, never by identity or path, and must refuse its own class - which
## ruling 6's predicate does, since an ActionReaction is neither an ActionAttackTech nor a tech
## ActionSystem. `seen` counts ACTIVATIONS and is exactly one either way.
func assert_asked_about(watcher:TechWatcher, is_expected:Callable, label:String) -> void:
	assert_gt(watcher.asked.size(), 0, 'LIVENESS: the bus asked the reaction about the activation.')
	var self_polls := 0
	for action:Action in watcher.asked:
		if action == watcher:
			self_polls += 1
			continue
		assert_true(is_expected.call(action), 'Every other poll was about %s.' % label)
	assert_eq(self_polls, watcher.seen.size(),
		'The reaction was polled about its OWN activation exactly as often as it fired.')

func names(actions:Array[Action]) -> Array[String]:
	var found:Array[String] = []
	for action:Action in actions: found.append(action.resource_path.get_file())
	return found


# ===================== PROBE 1: unit_action POST with the action in context =====================

func test_a_lock_on_reaches_the_reaction_with_the_action_in_context() -> void:
	var watcher := TechWatcher.new()
	install(watcher, &'naga_probe_tech_kit')
	await lock_on()
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the Lock On landed.')
	assert_asked_about(watcher, func(a:Action) -> bool: return a is ActionSystem and a.is_tech, 'the tech ActionSystem Lock On')
	assert_eq(watcher.seen.size(), 1, 'THE CLAIM: a Lock On offers the slither.')
	if watcher.seen.is_empty(): return
	assert_true(watcher.seen[0] is ActionSystem and watcher.seen[0].is_tech,
		'The action in context IS the tech ActionSystem that was used, not the Kit or a proxy.')
	assert_eq(names(watcher.seen), ['action_lock_on.tres'], 'And it is Lock On itself.')

func test_a_scan_reaches_the_reaction() -> void:
	var watcher := TechWatcher.new()
	install(watcher, &'naga_probe_tech_kit')
	assert_true(Scanpedia.is_anything_unscanned(target),
		'fixture: the target is scannable, so Scan is available at all (action_scan.gd:9-16).')
	await scan()
	assert_asked_about(watcher, func(a:Action) -> bool: return a is ActionSystem and a.is_tech, 'the tech ActionSystem Scan')
	assert_eq(names(watcher.seen), ['action_scan.tres'], 'THE CLAIM: a Scan offers the slither.')

func test_an_invade_reaches_the_reaction_through_the_tech_attack_clause() -> void:
	var watcher := TechWatcher.new()
	install(watcher, &'naga_probe_tech_kit')
	await invade()
	assert_asked_about(watcher, func(a:Action) -> bool: return a is ActionAttackTech, 'the ActionAttackTech invade')
	if watcher.asked.is_empty(): return
	assert_true(watcher.asked[0] is ActionAttackTech,
		'The action in context is an ActionAttackTech, which is NOT an ActionSystem - the second clause.')
	assert_eq(watcher.seen.size(), 1,
		'THE CLAIM (mutation 1 reddens this): an invade is a Tech Action and offers the slither.')

func test_a_boost_does_not() -> void:
	var watcher := TechWatcher.new()
	install(watcher, &'naga_probe_tech_kit')
	await boost()
	assert_asked_about(watcher, func(a:Action) -> bool: return a is ActionSystem and not a.is_tech, 'the non-tech ActionSystem Boost')
	assert_true(watcher.seen.is_empty(), 'CONTROL: Boost is not tech and does not offer.')

func test_a_weapon_attack_does_not() -> void:
	var watcher := TechWatcher.new()
	install(watcher, &'naga_probe_tech_kit')
	await shoot()
	assert_asked_about(watcher, func(a:Action) -> bool: return a is ActionAttackWeapon, 'the ActionAttackWeapon shot')
	assert_true(watcher.seen.is_empty(), 'CONTROL: a weapon attack is not a Tech Action.')


# ===================== PROBE 2: statuses_changed POST on a Lock On loss =====================

func test_a_consumed_lock_on_fires_post_with_no_source() -> void:
	await lock_on()
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'fixture: locked.')
	var locker_id:StringName = actor.get_gear(LOCK_ON).persistent_id
	assert_true(UnitCondition.has_status(target, Lancer.STATUS.LOCKON, locker_id),
		'LIVENESS: while it stands, the status carries the locker\'s ms_lock_on gear id as its source.')

	var watcher := LossWatcher.new()
	install(watcher, &'naga_probe_loss_kit') # AFTER the lock, so the apply is never seen
	await shoot() # the attack_declared PRE consume reaction asks; the responder says yes
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the lock was consumed by the shot.')
	assert_eq(watcher.seen.size(), 1, 'THE CLAIM (mutation 2 reddens this): the loss fired POST, once.')
	if watcher.seen.is_empty(): return
	assert_eq(watcher.seen[0].unit, target, 'For the unit that lost it.')
	assert_eq(watcher.seen[0].source, &'',
		'RULING 20: the consume clears with NO source (action_consume_lock_on.gd:42), so the event '
		+ 'cannot say whose lock it was.')

func test_an_ability_clear_fires_post_with_the_lockers_source() -> void:
	await lock_on()
	var locker_id:StringName = actor.get_gear(LOCK_ON).persistent_id
	var watcher := LossWatcher.new()
	install(watcher, &'naga_probe_loss_kit')
	# Stabilize's own line: clear_status_via_ability -> clear_specific_status, which hands the
	# status's OWN source to on_status_clear (unit_condition.gd:479-483, :326-329). Driven inside
	# a real event so the reaction queue it fills is actually run.
	await game.execute_event(&'event_unit_clear_status', {
		unit = target, category = Lancer.STATUS.LOCKON, string = locker_id,
	})
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the lock is gone.')
	assert_eq(watcher.seen.size(), 1, 'THE CLAIM (mutation 2 reddens this): the loss fired POST, once.')
	if watcher.seen.is_empty(): return
	assert_eq(watcher.seen[0].unit, target, 'For the unit that lost it.')
	assert_eq(watcher.seen[0].source, locker_id,
		'A sourced clear carries the source through - only the consume is anonymous.')

func test_an_unrelated_status_change_does_not_fire() -> void:
	var watcher := LossWatcher.new()
	install(watcher, &'naga_probe_loss_kit')
	SpecFactory.apply(target, Lancer.STATUS.SLOWED)
	await game.execute_event(&'event_unit_clear_status', {unit = target, category = Lancer.STATUS.SLOWED})
	assert_false(target.has_status(Lancer.STATUS.SLOWED), 'LIVENESS: Slowed was cleared.')
	assert_true(watcher.seen.is_empty(), 'CONTROL: the category gate holds - Slowed is not Lock On.')
