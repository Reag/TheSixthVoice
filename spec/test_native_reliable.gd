# NATIVE RELIABLE (res/content/gear/shared/reliable/native_reliable.gd) - the carrier Weight of Fire
# and the Statistical Compensator share since 2026-09-24, replacing reliable_topup.gd.
#
# Three things are pinned here that the two cards' own specs do not reach:
#   1. WHAT NATIVE BUYS: one damage event per roll (the top-up dealt two), and resistance halving
#      the raised floor ONCE (the top-up's recorded residue).
#   2. THE SHARED RESOURCE COMES BACK: the rifle's reliable_damage is the Kit's own export, shared by
#      every unit carrying one. It must read printed after an attack - including one that stops
#      early because the attacker died mid-attack, which skips ATTACK_DECLARED POST entirely.
#   3. ANOTHER WRITER: the Clark (fateofman-ipsn_clark, resident since 2026-09-24) raises the same
#      export between the same two points. Measured for real in the order the bus picks, and in
#      BOTH orders against a synthetic writer, since the bus order is not ours to choose.
#
# MUTATION, done by hand 2026-09-24: comment out raise()'s `declared.block.queue_block(...)` line and
# every "printed after" test goes red.
#
# THE INTERFACE IS FROZEN (close-out Pass F Task 21): raise and is_raised, plus the three constants,
# are pinned in section 0 below the test_lockon.gd way, and a third public function fails it.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_native_reliable.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')
const NativeReliable := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/native_reliable.gd')

const CLARK_ID := 'fateofman-ipsn_clark'
const CLARK_MOD := &'wm_redundant_scattering_module' # +damage-dice-count Reliable, PRE to POST

const RIFLE := Fixture.MAIN_RIFLE # MAIN RIFLE, 1d6, RELIABLE 2 - the shared export under test
const HAZARD_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(6, 6)
const BYSTANDER_TILE := Vector2i(4, 9)


## Records, or interferes, at one trigger of the holder's own attack.
class Watcher extends ActionReaction:
	var seen_reliable:Array[String] = []
	var damage_events:int = 0
	var kill_attacker:bool = false
	var victim:Unit

	func _init(trigger:StringName, timing:ReactionBus.TIMING) -> void:
		triggers_on = [trigger]
		trigger_timing = timing
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]: return [Context.PROP.unit]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if triggers_on.has(ReactionBus.TRIGGER.DAMAGE): return triggering_event.context.unit == victim
		return triggering_event.context.unit == unit

	func activate(context:Context, _activation:EventCore) -> void:
		var triggering:Context = context.event.context
		if triggers_on.has(ReactionBus.TRIGGER.DAMAGE):
			damage_events += 1
			return
		seen_reliable.append(triggering.action.reliable_damage)
		if kill_attacker: triggering.unit.is_alive = false


var game:Gamemaster
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE, 4) # Weight of Fire +2
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	Fixture.equip(hazard, RIFLE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var action := rifle_action()
	# a failing test must not hand the next one a raised rifle
	if action.has_meta(NativeReliable.STATE_META): action.remove_meta(NativeReliable.STATE_META)
	action.reliable_damage = '2'

# ---------------------------------------------------------------- helpers

## The ONE shared ActionAttackWeapon every assault rifle in the game reads.
func rifle_action() -> ActionAttackWeapon:
	return ContentLibrary.get_kit(RIFLE).actions.front()

## Fit a knockoff Kit carrying `reactions` onto the Hazard (test_spike_hazard_sp3_seams.fit_mod).
func fit_watchers(reactions:Array[Action]) -> void:
	var kit := Kit.new()
	kit.compcon_id = &'ms_spec_native_reliable_watchers'
	kit.actions.append_array(reactions)
	hazard.core.loadout.equipped_kits.append(kit)
	hazard.core.loadout.systems.append(GearCore.create(kit))
	hazard.core.loadout.regenerate_caches()

func miss() -> void:
	Fixture.queue([2])
	await Fixture.shoot(game, hazard, hostile, RIFLE)

func resist_everything(unit:Unit) -> void:
	var resist := BuffResistDamage.new()
	resist.to = Buff.TO.RESIST_DAMAGE
	resist.resist_everything = true
	resist.hide_from_player = true
	resist.multiple_copies_can_stack = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, resist)

func assert_rifle_printed(why:String) -> void:
	assert_eq(rifle_action().reliable_damage, '2', 'The shared rifle reads its printed Reliable 2 %s.' % why)
	assert_false(NativeReliable.is_raised(rifle_action()), 'No raise is left on the shared rifle %s.' % why)

# ---------------------------------------------------------------- 0. the frozen interface
#
# Close-out Pass F Task 21: the idiom of test_lockon.gd / test_overshield.gd FROZEN_SIGNATURES. Three
# consumers (Weight of Fire, the Statistical Compensator, Zwarte Hoop) spell NativeReliable.raise on
# the preloaded constant, and Zwarte Hoop also reuses SENTINEL_PRIORITY and CARRIER_EVENT for its own
# sentinel - so those two constants are part of the contract and pinned by value.
# Variant.Type: TYPE_NIL=0 (a void return), TYPE_BOOL=1, TYPE_INT=2, TYPE_STRING_NAME=21,
# TYPE_OBJECT=24; class_name is set only for TYPE_OBJECT. Underscore-prefixed (_lower) is private.
const FROZEN_SIGNATURES := {
	raise = {
		args = [
			['declared', TYPE_OBJECT, &'EventCore'],
			['amount', TYPE_INT, &''],
			['source', TYPE_STRING_NAME, &''],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
	is_raised = {
		args = [['action', TYPE_OBJECT, &'Action']],
		return_type = TYPE_BOOL, return_class = &'',
	},
}
const FROZEN_CONSTANTS := {
	STATE_META = &'reag_native_reliable',
	SENTINEL_PRIORITY = -1000,
	CARRIER_EVENT = &'event_delay',
}

func test_the_frozen_interface_pins_these_two_signatures_and_three_constants():
	# Through a Script-typed local: a preloaded constant in call position is read as a class and the
	# call refused at parse time (test_overshield.gd records the error).
	var script:Script = NativeReliable
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	var public:Array = by_name.keys().filter(func(name:String) -> bool: return not name.begins_with('_'))
	assert_eq(public.size(), FROZEN_SIGNATURES.size(),
		'Exactly %d public functions - a third is a new contract and belongs in this table: %s' % [FROZEN_SIGNATURES.size(), public])

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'NativeReliable.%s survives.' % required)
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

	var constants:Dictionary = script.get_script_constant_map()
	for name:String in FROZEN_CONSTANTS:
		assert_true(constants.has(name), 'NativeReliable.%s survives.' % name)
		if not constants.has(name): continue
		assert_eq(constants[name], FROZEN_CONSTANTS[name], 'NativeReliable.%s keeps its frozen value.' % name)

# ---------------------------------------------------------------- 1. what native buys

func test_a_miss_is_one_damage_event():
	var counter := Watcher.new(ReactionBus.TRIGGER.DAMAGE, ReactionBus.TIMING.PRE)
	counter.victim = hostile
	fit_watchers([counter] as Array[Action])
	await miss()
	assert_eq(hostile.current_damage(), 4, 'Reliable 2 + half Grit 4.')
	assert_eq(counter.damage_events, 1, 'One damage event, so a damage reaction fires once, not twice.')

func test_resistance_halves_the_raised_floor_once():
	resist_everything(hostile)
	# a hit rolling 3 is under the raised floor 4: resisted, ceil(4 / 2) = 2. The top-up dealt
	# ceil(3 / 2) + ceil(1 / 2) = 3 - the residue this carrier retires.
	Fixture.queue([19, 3])
	await Fixture.shoot(game, hazard, hostile, RIFLE)
	assert_eq(hostile.current_damage(), 2, 'Resisted Reliable 4 is 2.')

# ---------------------------------------------------------------- 2. the shared resource comes back

func test_the_engine_reads_the_raise_and_the_rifle_is_printed_after():
	var watcher := Watcher.new(ReactionBus.TRIGGER.ATTACK, ReactionBus.TIMING.POST)
	fit_watchers([watcher] as Array[Action])
	await miss()
	assert_eq(watcher.seen_reliable, ['4'] as Array[String], 'Mid-attack the export reads 2 + 2.')
	assert_rifle_printed('after the attack')

func test_an_attacker_killed_mid_attack_leaves_the_rifle_printed():
	# Dead at the roll's POST, so execute() returns at :69 and ATTACK_DECLARED POST never fires.
	var killer := Watcher.new(ReactionBus.TRIGGER.ATTACK, ReactionBus.TIMING.POST)
	killer.kill_attacker = true
	fit_watchers([killer] as Array[Action])
	await miss()
	assert_eq(hostile.current_damage(), 0, 'The attack stopped before damage.')
	assert_rifle_printed('after an attack that stopped early')

func test_a_bystander_with_the_same_rifle_misses_for_printed():
	await miss()
	var bystander := Fixture.create_ally(game, BYSTANDER_TILE + Vector2i(10, 0))
	Fixture.equip(bystander, RIFLE)
	var other := Fixture.create_hostile(game, BYSTANDER_TILE + Vector2i(12, 0))
	Fixture.queue([2])
	await Fixture.shoot(game, bystander, other, RIFLE)
	assert_eq(other.current_damage(), 2, 'An unbuffed rifle out of the Hazard\'s aura misses for its own 2.')

# ---------------------------------------------------------------- 3. another writer, both orders

## A declared-attack stand-in: the core raise() reads, in a live block, and the way to finish it.
func synthetic_attack() -> Array:
	var declared := EventCore.create(&'event_delay', {unit = hazard, action = rifle_action()})
	var block := EventBlock.create_multiple([declared])
	add_child_autoqfree(block)
	return [declared, block]

func test_a_writer_before_us_that_restores_its_own_save_is_left_alone():
	var pair := synthetic_attack()
	var action := rifle_action()
	var their_save := action.reliable_damage # '2'
	action.reliable_damage = '3'             # they raise first
	NativeReliable.raise(pair[0], 2, &'spec')
	assert_eq(action.reliable_damage, '5', 'We add on top of their 3.')
	action.reliable_damage = their_save      # their POST: back to what they saved
	await pair[1].execute()                  # the attack's block finishes: our sentinel runs
	assert_rifle_printed('when they raised first')

func test_a_writer_after_us_that_restores_its_own_save_is_lowered_by_us():
	var pair := synthetic_attack()
	var action := rifle_action()
	NativeReliable.raise(pair[0], 2, &'spec')
	var their_save := action.reliable_damage # '4' - ours
	action.reliable_damage = '5'             # they raise on top
	action.reliable_damage = their_save      # their POST
	await pair[1].execute()
	assert_rifle_printed('when they raised second')

func test_one_source_raises_once_per_attack():
	var pair := synthetic_attack()
	NativeReliable.raise(pair[0], 2, &'spec')
	NativeReliable.raise(pair[0], 2, &'spec')
	assert_eq(rifle_action().reliable_damage, '4', 'A second raise from the same source is a no-op.')
	await pair[1].execute()
	assert_rifle_printed('after a repeated raise')

func test_a_block_torn_down_before_it_finishes_still_lowers():
	var pair := synthetic_attack()
	NativeReliable.raise(pair[0], 2, &'spec')
	pair[1].clear_event_tree() # what a level exit does
	await get_tree().process_frame
	assert_rifle_printed('after the level tore the attack down')

# ---------------------------------------------------------------- the Clark, for real

func clark_loaded() -> bool:
	return ContentLibrary.get_kit(CLARK_MOD) != null

func fit_clark() -> GearCore:
	var mod := hazard.core.loadout.equip_weapon_mod(CLARK_MOD, hazard.get_gear(RIFLE))
	SpecFactory.apply_passive_buffs(hazard)
	return mod

func test_the_clarks_module_and_weight_of_fire_add_and_both_come_off():
	if not clark_loaded():
		fail_test('%s is resident and must be loaded - restore it with restore-links.ps1.' % CLARK_ID)
		return
	assert_not_null(fit_clark(), 'The Clark\'s module fits the rifle.')
	await miss()
	assert_eq(hostile.current_damage(), 5, 'A miss: 2 printed + 2 Weight of Fire + 1 (the Clark, one damage die).')
	assert_rifle_printed('after both mods raised it')
	assert_false(hazard.get_gear(RIFLE).has_meta(&'redundant_scattering_depth') and hazard.get_gear(RIFLE).get_meta(&'redundant_scattering_depth') != 0,
		'The Clark\'s own bookkeeping unwound too.')

func test_the_clarks_module_alone_is_untouched_by_us():
	if not clark_loaded():
		fail_test('%s is resident and must be loaded - restore it with restore-links.ps1.' % CLARK_ID)
		return
	Fixture.set_grit(hazard, 0) # no Weight of Fire
	fit_clark()
	await miss()
	assert_eq(hostile.current_damage(), 3, 'A miss: 2 printed + 1 (the Clark).')
	assert_rifle_printed('after the Clark alone')
