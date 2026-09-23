# PURPLE THORN SP1 PROBES (design §1.0): the two engine seams this frame's traits and core are
# built on, measured with a knockoff Kit and a knockoff buff on a vanilla player unit before any
# content is written.
#
# PROBE 1 - VIGIL's trigger (ruling 2). Does a DAMAGE POST reaction on a TRAIT Kit reach the bus
# with the DEALER in `context.target_unit` (event_unit_damage.gd: `unit` is the receiver,
# `target_unit` the damaging unit), once per damage event, INSIDE the attack - i.e. before the
# declared attack's own ATTACK_DECLARED POST? And can the damage event be traced back to the
# declared attack that produced it, so a Blast can offer ONCE per attack rather than once per
# victim? The damage context carries NO `event` prop (the declared-attack core is not in it), so
# the trace walks the EventBlock tree instead: the damage core's `block` is the immediate block
# `core.execute_events(damage_events)` made, whose parent is the declared attack's own block
# (event_core.gd:77-81, event_block.gd:175-183).
#
# PROBE 2 - RULING 8's order. On ONE damage POST, does a BUFF activation (Rend's shape) run before
# or after a REACTION on a trait Kit (Vigil's shape)? ReactionBus.trigger_occurred appends every
# unit's gear reactions first and its buffs second, at equal priority 0, and EventBlock's tiebreak is
# first-created-first-run (event_block.gd:11-12) - so the reading is REACTION FIRST. The design
# recorded the opposite expectation ("Rend's shove resolves first"); whichever this measures, the
# spec pins it and the production files record it.
#
# MUTATION. Probe 1: DEALER_IS_TARGET_UNIT := false reads the dealer off `context.unit` instead -
# the actor's own rifle hit must then stop offering (the victim is not the actor) and the self-heat
# case must start offering for the wrong reason. Probe 2 has no mutation: it is a measurement.
#
# If probe 1 is red on its claim with its LIVENESS line green, stop and report (design §1.0): there
# is no fallback that keeps the card.
#
# No production code. The real reactions are built on mt_vigil, mt_blessed_bolt_system and
# cp_lav_tactical_engine.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_purple_thorn_sp1_seams.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## MUTATION KNOB. The claim under test as written.
const DEALER_IS_TARGET_UNIT := true

const RIFLE := &'mw_assault_rifle' # MAIN, RELIABLE 2, 1d6, aim_range 10
const ACTOR_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(7, 4)

## A shared, ordered record that a reaction and a buff can both write into.
class Trace extends RefCounted:
	var entries:Array[StringName] = []


## The two reads both knockoffs share. An INNER CLASS rather than script-level statics, because
## GDScript does not resolve an outer script's static functions from inside a nested class body
## (measured on this file's first run: "Function dealer_of() not found in base self").
class Seam extends RefCounted:
	## The dealer of a damage event, read the way ruling 2 reads it (or the mutation's way).
	static func dealer_of(context:Context) -> Unit:
		if DEALER_IS_TARGET_UNIT:
			if not Unit.is_valid(context.target_unit): return null
			return context.target_unit.get_attacker(context)
		return context.unit

	## The declared attack this damage event belongs to, by walking the block tree; the damage
	## core's own id when no declared attack encloses it (a bare event_unit_damage, e.g.
	## SpecFactory.damage).
	static func enclosing_attack_id(damage:EventCore) -> StringName:
		var node = damage.block
		while node is EventBlock:
			for core:EventCore in node.event_cores:
				if core.base.event_type == &'event_unit_attack_declared': return core.id
			node = node.get_parent()
		return damage.id


## PROBE 1's reaction: a point-free, hidden DAMAGE POST reaction gated only on the dealer.
class DamageWatcher extends ActionReaction:
	var trace:Trace
	## One record per activation: {victim, dealer, number, type, flags, attack}.
	var seen:Array[Dictionary] = []
	## Every poll of triggers_on_event - the liveness record.
	var asked:int = 0

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.DAMAGE]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.number]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		asked += 1
		return Seam.dealer_of(triggering_event.context) == unit

	func activate(context:Context, _activation:EventCore) -> void:
		var c:Context = context.event.context
		seen.append({
			victim = c.unit, dealer = c.target_unit, number = c.number, type = c.category_int,
			flags = c.flags.duplicate(), attack = Seam.enclosing_attack_id(context.event),
		})
		trace.entries.append(&'reaction')


## The ATTACK_DECLARED POST marker: records the declared attack's id and its place in the order.
class DeclaredWatcher extends ActionReaction:
	var trace:Trace
	var ids:Array[StringName] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == unit

	func activate(context:Context, _activation:EventCore) -> void:
		ids.append(context.event.id)
		trace.entries.append(&'declared_post')


## PROBE 2's buff: the same gate as the watcher, on Rend's shape - a hidden buff with a DAMAGE POST
## trigger whose activate records its place in the order.
class OrderBuff extends Buff:
	var trace:Trace

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.DAMAGE]
		trigger_timing = ReactionBus.TIMING.POST
		hide_from_player = true

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.number]

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		return Seam.dealer_of(triggering_event.context) == unit

	func activate(_core:BuffCore, _activation:EventCore) -> void:
		trace.entries.append(&'buff')


var game:Gamemaster
var actor:Unit
var target:Unit
var trace:Trace
var watcher:DamageWatcher
var declared:DeclaredWatcher


func before_each() -> void:
	game = Fixture.create_game(self)
	actor = SpecFactory.create_unit(game.map, ACTOR_TILE, Faction.PLAYER)
	actor.core.equip_system(RIFLE)
	actor.core.full_repair()
	target = Fixture.create_dummy(game, TARGET_TILE, 10, Faction.AI_ENEMY)
	trace = Trace.new()
	watcher = DamageWatcher.new()
	watcher.trace = trace
	declared = DeclaredWatcher.new()
	declared.trace = trace
	install(watcher, &'spike_damage_watcher')
	install(declared, &'spike_declared_watcher')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## The knockoff Kit on the actor's own loadout as a runtime trait Kit (the Naga probe's idiom).
## full_repair() regenerates derived gear, which is where the Kit's reaction gets indexed by trigger.
func install(reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	actor.core.loadout.equipped_kits.append(kit)
	actor.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func open_turn() -> void:
	if actor.state.is_taking_turn: await SpecFactory.end_turn(game, actor)
	await SpecFactory.start_turn(game, actor)

## [these], then a long tail of 1s.
func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 40: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## The rifle: the d20, then the damage d6. A 19 hits evasion 10 with no accuracy die to pop.
func shoot(damage_die:int = 4) -> void:
	await open_turn()
	queue([19, damage_die])
	await SpecFactory.use_solo(game, actor, RIFLE, target)


# ---------------------------------------------------------------- probe 1

func test_a_rifle_hit_reaches_a_damage_post_reaction_with_the_dealer_in_target_unit():
	var before:int = target.core.current.health
	await shoot(4)
	assert_gt(watcher.asked, 0, 'LIVENESS: the bus asked the reaction about the damage.')
	assert_eq(before - target.core.current.health, 4, 'fixture: the hit landed 4 (armor 0).')
	assert_eq(watcher.seen.size(), 1, 'CLAIM: exactly one activation for one damage event.')
	if watcher.seen.is_empty(): return
	var record:Dictionary = watcher.seen[0]
	assert_eq(record.dealer, actor, 'CLAIM: context.target_unit is the DEALER.')
	assert_eq(record.victim, target, 'CLAIM: context.unit is the VICTIM.')
	assert_eq(record.number, 4, 'context.number is the amount after reduction.')
	assert_eq(record.type, Lancer.DAMAGE_TYPE.KINETIC, 'context.category_int is the damage type.')
	assert_false(record.flags.has(EventService.DAMAGE_FLAG.SELF_INFLICTED), 'An attack is not SELF_INFLICTED.')

func test_the_damage_post_reaction_runs_inside_the_attack_before_attack_declared_post():
	await shoot(4)
	assert_eq(declared.ids.size(), 1, 'fixture: the declared attack POST fired once.')
	assert_eq(trace.entries, [&'reaction', &'declared_post'] as Array[StringName],
		'CLAIM: DAMAGE POST is queued onto the attack and runs before ATTACK_DECLARED POST.')

func test_the_damage_event_traces_back_to_its_declared_attack():
	await shoot(4)
	if watcher.seen.is_empty() or declared.ids.is_empty():
		fail_test('fixture: both watchers fired.')
		return
	assert_ne(watcher.seen[0].attack, &'', 'The trace found SOME id.')
	assert_eq(watcher.seen[0].attack, declared.ids[0],
		'CLAIM: walking the block tree from the damage core reaches the declared attack, and its id is the one ATTACK_DECLARED POST saw.')

func test_two_shots_are_two_different_attacks():
	await shoot(4)
	await shoot(4)
	assert_eq(watcher.seen.size(), 2, 'fixture: two activations.')
	assert_eq(declared.ids.size(), 2, 'fixture: two declared attacks.')
	if watcher.seen.size() < 2: return
	assert_ne(watcher.seen[0].attack, watcher.seen[1].attack, 'The traced ids differ per attack.')

func test_an_armor_zeroed_hit_still_queues_damage_post_with_number_zero():
	# MEASURED on this file's second run, and it CORRECTS the first draft of this case: Reliable 2
	# floors the die at 2 (attack_util.gd:144-147) and armor 3 zeroes it, but the POST is STILL
	# queued - the guard at event_unit_damage.gd:93 reads capped_damage, which armor never touches
	# (Halo's header; the design's own §7 says so). What armor zeroes is context.number. So the
	# production gate is `number > 0`, exactly as ruling 2 says, and a reaction gated on the dealer
	# alone WOULD offer Vigil on a hit that dealt nothing. The victim's HP is the fixture's proof.
	target.core.frame.stat.armor = 3
	target.core.full_repair()
	var before:int = target.core.current.health
	await shoot(1)
	assert_eq(declared.ids.size(), 1, 'fixture: the attack resolved.')
	assert_eq(target.core.current.health, before, 'fixture: armor 3 ate the 2 (Reliable floor).')
	assert_eq(watcher.seen.size(), 1, 'FACT: DAMAGE POST is queued even when armor zeroed the hit.')
	if watcher.seen.is_empty(): return
	assert_eq(watcher.seen[0].number, 0, 'FACT: and context.number reads 0 - the gate ruling 2 needs.')

func test_self_inflicted_heat_names_the_victim_as_its_own_dealer_and_carries_the_flag():
	# The shape unit_action.gd:299-306 issues for self-heat and overkill: target_unit = self plus
	# SELF_INFLICTED. Ruling 2 reads both to refuse it; this measures both are there to read.
	await game.execute_event(&'event_unit_damage', {
		unit = actor, target_unit = actor, number = 1, category = Lancer.DAMAGE_TYPE.HEAT,
		flags = [EventService.DAMAGE_FLAG.SELF_INFLICTED],
	})
	assert_eq(watcher.seen.size(), 1, 'fixture: the dealer gate alone accepts it (the dealer IS the actor).')
	if watcher.seen.is_empty(): return
	assert_eq(watcher.seen[0].dealer, actor, 'target_unit is the actor itself.')
	assert_eq(watcher.seen[0].type, Lancer.DAMAGE_TYPE.HEAT, 'The type reads HEAT.')
	assert_true(watcher.seen[0].flags.has(EventService.DAMAGE_FLAG.SELF_INFLICTED), 'And the flag is there to refuse it by.')

func test_damage_with_no_dealer_does_not_offer():
	# SpecFactory.damage sends no target_unit: a hazard, a burn tick. Nobody dealt it.
	await SpecFactory.damage(game, target, 2, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(watcher.seen.size(), 0, 'No dealer, no offer.')

func test_being_shot_does_not_offer():
	# The actor is the VICTIM here: a hostile rifle. Under the mutation this is the case that flips.
	var shooter := Fixture.create_dummy(game, Vector2i(10, 4), 10, Faction.AI_ENEMY)
	shooter.core.equip_system(RIFLE)
	shooter.core.full_repair()
	if shooter.state.is_taking_turn: await SpecFactory.end_turn(game, shooter)
	await SpecFactory.start_turn(game, shooter)
	queue([19, 4])
	await SpecFactory.use_solo(game, shooter, RIFLE, actor)
	assert_gt(watcher.asked, 0, 'LIVENESS: the bus asked.')
	assert_eq(watcher.seen.size(), 0, 'CLAIM: taking damage is not dealing it.')


# ---------------------------------------------------------------- probe 2

func test_on_one_damage_post_the_trait_reaction_runs_before_the_buff():
	var buff := OrderBuff.new()
	buff.trace = trace
	UnitCondition.apply_buff(SpecFactory.dummy_event({unit = actor}), actor, buff)
	await shoot(4)
	assert_true(trace.entries.has(&'buff'), 'fixture: the buff fired.')
	assert_true(trace.entries.has(&'reaction'), 'fixture: the reaction fired.')
	assert_eq(trace.entries, [&'reaction', &'buff', &'declared_post'] as Array[StringName],
		'MEASURED (ruling 8): the gear reaction first, the buff second, both inside the attack.')
