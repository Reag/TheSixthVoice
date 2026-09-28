# The LOCK ON helper (Naga SP1 Task 5), born with the Naga and frozen when that sub-project ships.
#
# Roadmap 4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Design ruling 20 names the
# five functions; the Black Mountain and the Koremasa's Slash have since consumed them.
# test_the_frozen_interface_pins_these_five_signatures
# is the guard, and pins the whole signature - names, argument names and types, return types, static.
#
# The two measured facts the helper's header records (probe spec/test_spike_naga_sp1_seams.gd) are
# re-pinned here as one test, through the helper: a consume loses LOCKON with an EMPTY source, an
# ability clear loses it with the locker's gear id.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_lockon.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const NAGA_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(8, 4) # 3 clear of the size-2 Naga: in rifle range, out of threat
const OTHER_TILE := Vector2i(8, 8)
const DRONE_TILE := Vector2i(4, 8)

# Script.get_script_method_list()'s dictionary shape (Godot 4.7), as test_overshield.gd records it:
# each entry is {name, args, default_args, flags, id, return}; each arg and the return are
# property-info dicts {name, class_name, type, ...}. `type` is a Variant.Type - TYPE_BOOL=1,
# TYPE_STRING_NAME=21, TYPE_OBJECT=24 - and for TYPE_OBJECT, `class_name` carries the class as a
# StringName (&'Unit'); for every other type it is &''.
const FROZEN_SIGNATURES := {
	was_consumed = {
		args = [['context', TYPE_OBJECT, &'Context']],
		return_type = TYPE_BOOL, return_class = &'',
	},
	consumer = {
		args = [['context', TYPE_OBJECT, &'Context']],
		return_type = TYPE_OBJECT, return_class = &'Unit',
	},
	is_lost = {
		args = [['triggering', TYPE_OBJECT, &'EventCore']],
		return_type = TYPE_BOOL, return_class = &'',
	},
	apply = {
		args = [
			['event', TYPE_OBJECT, &'EventCore'],
			['target', TYPE_OBJECT, &'Unit'],
			['source_gear', TYPE_OBJECT, &'GearCore'],
		],
		return_type = TYPE_BOOL, return_class = &'',
	},
	source_of = {
		args = [['unit', TYPE_OBJECT, &'Unit']],
		return_type = TYPE_STRING_NAME, return_class = &'',
	},
}


## A hidden, point-free ATTACK POST reaction that records what the helper says about each attack.
## The probe's knockoff idiom. Records in activate(), never in triggers_on_event - the bus polls a
## gate several times per event (the probe measured three to four), and activate runs once.
class AttackWatcher extends ActionReaction:
	var consumed:Array[bool] = []
	var consumers:Array[Unit] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, _triggering_event:EventCore) -> bool:
		return true

	func activate(context:Context, _activation:EventCore) -> void:
		var triggering:Context = context.event.context
		consumed.append(Lockon.was_consumed(triggering))
		consumers.append(Lockon.consumer(triggering))


## The probe's LossWatcher, gated through the helper's own is_lost. POST, so "true" means LOST.
class LossWatcher extends ActionReaction:
	var seen:Array[Dictionary] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.STATUSES_CHANGED]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.category]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return Lockon.is_lost(triggering_event)

	func activate(context:Context, _activation:EventCore) -> void:
		var triggering:Context = context.event.context
		seen.append({unit = triggering.unit, source = StringName(triggering.string)})


var game:Gamemaster
var naga:Unit
var hostile:Unit

func before_each() -> void:
	game = NagaFixture.create_game(self)
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	NagaFixture.arm_rifle(naga)
	hostile = NagaFixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The knockoff Kit on the Naga's loadout as a runtime trait Kit, then the Naga rebuilt the fixture's
## way (passive buffs re-applied, tile index refreshed for size 2).
func install(reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	naga.core.loadout.equipped_kits.append(kit)
	SpecFactory.apply_passive_buffs(naga)
	UnitTile.move_to(naga, NAGA_TILE)
	UnitTile.update_tracking_and_statuses(game.map)

func dummy() -> EventCore:
	return SpecFactory.dummy_event({unit = naga})

func lock_gear() -> GearCore:
	return naga.get_gear(NagaFixture.LOCK_ON)

func lockon_count(unit:Unit) -> int:
	var count := 0
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == Lancer.STATUS.LOCKON: count += 1
	return count

# ---------------------------------------------------------------- the interface itself

func test_the_frozen_interface_pins_these_five_signatures():
	# Through a Script-typed local: a preloaded constant in call position is read as a class and the
	# call refused at parse time (test_overshield.gd records the error).
	var script:Script = Lockon
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	var names:Array = by_name.keys()
	names.sort()
	# As Strings: the FROZEN_SIGNATURES keys are StringNames, and Array.sort orders StringNames by
	# pointer, not alphabetically (measured - a sorted key list came back unsorted).
	var expected_names:Array = []
	for key in FROZEN_SIGNATURES: expected_names.append(String(key))
	expected_names.sort()
	assert_eq(names, expected_names, 'Exactly these five methods exist today (additions update this list).')

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'Lockon.%s survives.' % required)
		if not by_name.has(required): continue
		var entry:Dictionary = by_name[required]
		var expected:Dictionary = FROZEN_SIGNATURES[required]
		var expected_args:Array = expected.args

		assert_eq(entry.args.size(), expected_args.size(),
			'%s takes exactly %d argument(s).' % [required, expected_args.size()])
		for i:int in range(min(entry.args.size(), expected_args.size())):
			var actual_arg:Dictionary = entry.args[i]
			var expected_arg:Array = expected_args[i]
			assert_eq(actual_arg.name, expected_arg[0], '%s arg %d is named "%s".' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.type, expected_arg[1], '%s arg %d has the frozen Variant.Type.' % [required, i])
			assert_eq(actual_arg.class_name, expected_arg[2], '%s arg %d has the frozen class_name.' % [required, i])

		# The bit, not a guessed flags total (test_overshield.gd's finding 4).
		assert_true((entry.flags & METHOD_FLAG_STATIC) != 0, '%s is static.' % required)
		assert_eq(entry.default_args.size(), 0, '%s takes no default arguments.' % required)
		assert_eq(entry.return.type, expected.return_type, '%s has the frozen return Variant.Type.' % required)
		assert_eq(entry.return.class_name, expected.return_class, '%s has the frozen return class_name.' % required)

# ---------------------------------------------------------------- was_consumed / consumer

func test_was_consumed_reads_the_attack_post_roll():
	var watcher := AttackWatcher.new()
	install(watcher, &'lockon_spec_attack_watcher')

	await NagaFixture.lock_on(game, naga, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'fixture: locked.')
	NagaFixture.queue([19, 3, 3]) # d20, the consumed lock's +1 accuracy d6, damage
	await NagaFixture.shoot(game, naga, hostile) # the stock responder answers the consume prompt yes
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the shot consumed the lock.')
	assert_eq(watcher.consumed, [true] as Array[bool], 'ATTACK POST after a consume reads as consumed.')
	assert_eq(watcher.consumers, [naga] as Array[Unit], 'And the consumer is the Naga.')

	NagaFixture.queue([19, 3])
	await NagaFixture.shoot(game, naga, hostile)
	assert_eq(watcher.consumed, [true, false] as Array[bool], 'A shot with no lock reads as not consumed.')

func test_was_consumed_reads_an_attack_declared_shaped_context():
	var context := Context.create({unit = naga, target_unit = hostile})
	assert_false(Lockon.was_consumed(context), 'No buff_lock_consumed yet.')
	SpecFactory.apply_buff(hostile, &'buff_lock_consumed')
	assert_true(Lockon.was_consumed(context), 'The target holds buff_lock_consumed.')

func test_was_consumed_is_null_safe():
	assert_false(Lockon.was_consumed(null), 'null context.')
	assert_false(Lockon.was_consumed(Context.create({unit = naga})), 'Neither a roll nor a target.')
	assert_false(Lockon.was_consumed(Context.create({unit = naga, object = 'a string'})),
		'A non-AttackRoll object is refused, not handed to AttackRoll.check.')

func test_consumer_is_relay_safe():
	var drone := NagaFixture.create_drone(game, DRONE_TILE)
	assert_eq(Lockon.consumer(Context.create({unit = drone})), drone, 'An unowned drone is its own attacker.')
	NagaFixture.own_drone(drone, naga)
	assert_eq(Lockon.consumer(Context.create({unit = drone})), naga, 'An owned drone resolves to its owner.')
	assert_eq(Lockon.consumer(Context.create({unit = naga})), naga, 'The Naga is its own attacker.')
	assert_null(Lockon.consumer(null), 'null context -> null.')
	assert_null(Lockon.consumer(Context.create({})), 'No unit -> null.')

# ---------------------------------------------------------------- is_lost

func test_is_lost_reads_the_lockon_category():
	var lost := EventCore.create(&'event_unit_apply_status', {unit = hostile, category = Lancer.STATUS.LOCKON, string = ''})
	assert_true(Lockon.is_lost(lost), 'A LOCKON statuses_changed event.')
	var slowed := EventCore.create(&'event_unit_apply_status', {unit = hostile, category = Lancer.STATUS.SLOWED, string = ''})
	assert_false(Lockon.is_lost(slowed), 'Slowed is not Lock On.')
	assert_false(Lockon.is_lost(null), 'null event.')

# ---------------------------------------------------------------- apply / source_of

func test_apply_locks_with_the_gears_id_and_refuses_a_relock():
	var gear := lock_gear()
	assert_true(GearCore.is_valid(gear), 'fixture: the Naga carries ms_lock_on.')
	assert_true(Lockon.apply(dummy(), hostile, gear), 'A fresh hostile is locked.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'It has LOCKON.')
	assert_eq(Lockon.source_of(hostile), gear.persistent_id, 'Sourced to the given gear.')

	var rifle := naga.get_gear(NagaFixture.MAIN_RIFLE)
	assert_false(Lockon.apply(dummy(), hostile, rifle), 'A second apply is refused (action_lock_on.gd:5-11).')
	assert_eq(lockon_count(hostile), 1, 'No second LOCKON condition stacked.')
	assert_eq(Lockon.source_of(hostile), gear.persistent_id, 'The source is unchanged.')

func test_apply_refuses_invalid_arguments():
	var other := NagaFixture.create_hostile(game, OTHER_TILE)
	assert_false(Lockon.apply(dummy(), other, null), 'A null gear is refused.')
	assert_false(other.has_status(Lancer.STATUS.LOCKON), 'And nothing was applied.')
	assert_false(Lockon.apply(dummy(), null, lock_gear()), 'A null target is refused.')
	# Close-out Pass F Task 21: a NULL EVENT is not refused - with a level live it applies on a
	# stand-in carrier (the dummy-event shape) and queues no statuses_changed reactions; it does NOT
	# run on the level's block as Overshield._fire, Teleport._run and Terrain.lay do. Before the guard
	# apply_status reached on_status_application's event.queue_reaction_events on a null event.
	assert_true(Lockon.apply(null, other, lock_gear()), 'A null event falls back to the level and locks.')
	assert_eq(Lockon.source_of(other), lock_gear().persistent_id, 'Sourced to the gear as usual.')

func test_source_of_follows_a_real_lock_and_its_consume():
	assert_eq(Lockon.source_of(hostile), &'', 'Unlocked reads empty.')
	assert_eq(Lockon.source_of(null), &'', 'An invalid unit reads empty.')
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(Lockon.source_of(hostile), lock_gear().persistent_id, 'A real Lock On is sourced to ms_lock_on.')
	NagaFixture.queue([19, 3, 3])
	await NagaFixture.shoot(game, naga, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'The shot consumed it.')
	assert_eq(Lockon.source_of(hostile), &'', 'And source_of reads empty again.')

# ---------------------------------------------------------------- the two measured facts

func test_a_consume_loses_the_lock_anonymously_and_an_ability_clear_does_not():
	await NagaFixture.lock_on(game, naga, hostile)
	var watcher := LossWatcher.new()
	install(watcher, &'lockon_spec_loss_watcher') # AFTER the lock: the apply is never seen
	NagaFixture.queue([19, 3, 3])
	await NagaFixture.shoot(game, naga, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: consumed.')
	assert_eq(watcher.seen.size(), 1, 'One LOCKON loss seen through is_lost.')
	if watcher.seen.size() >= 1:
		assert_eq(watcher.seen[0].unit, hostile, 'On the hostile.')
		assert_eq(watcher.seen[0].source, &'', 'A consume carries NO source (action_consume_lock_on.gd:42).')

	await NagaFixture.cycle_turn(game, naga)
	await NagaFixture.lock_on(game, naga, hostile)
	var source := Lockon.source_of(hostile)
	assert_eq(source, lock_gear().persistent_id, 'fixture: relocked, sourced.')
	assert_eq(watcher.seen.size(), 1, 'The APPLY is PRE, so the POST watcher did not see it.')
	# Stabilize's own clear line (clear_status_via_ability), which is handed NO source - so the
	# source the watcher sees is one the ENGINE read off the status, not one this spec supplied.
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: cleared by ability.')
	assert_eq(watcher.seen.size(), 2, 'A second LOCKON loss seen.')
	if watcher.seen.size() >= 2:
		assert_eq(watcher.seen[1].source, source, 'An ability clear carries the locker\'s source.')
