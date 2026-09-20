# The OVERSHIELD helper (SP1 Task 4), born with the Myconid's Halo and frozen when SP1 ships.
#
# Roadmap 4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Five later frames consume
# this one - Sluagh, Hazard, Naga, Primrose, Black Mountain - so a rename here is five frames' worth
# of churn. test_the_frozen_interface_pins_these_five_signatures is the guard, and it pins the whole
# signature - argument order, names, types, and return type - not only that a name survives.
#
# WHAT THE HELPER IS FOR. Overshield is one engine event, and it does exactly one surprising thing:
# event_unit_overshield sets max(old, amount) and NEVER adds (event_unit_overshield.gd:15). Every
# card that says "gains OVERSHIELD equal to X" wants that; the three that say "increases by that much
# instead" (Black Mountain's Exalt, Fell the Mighty, Dread Harbinger) want the other, and would each
# have re-derived current + X on their own. increase() is that one line, written once.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_overshield.gd
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const SUBJECT_TILE := Vector2i(4, 4)

# The frozen contract itself (roadmap 4, design 1.3). Read off Script.get_script_method_list()'s own
# dictionary shape (Godot 4.7): each entry is {name, args, default_args, flags, id, return}; each arg
# and the return are property-info dicts {name, class_name, type, hint, hint_string, usage}. `type`
# is a core/variant_types.h Variant.Type value - TYPE_NIL=0, TYPE_BOOL=1, TYPE_INT=2, TYPE_OBJECT=24
# - and for a TYPE_OBJECT argument or return, `class_name` carries the script's class as a StringName
# (&'Unit', &'EventCore'); for every other type it is the empty StringName &''. Confirmed against a
# live run (test_the_frozen_interface_pins_these_five_signatures' mutation checks, task-4-report.md
# fix round 1): `current`'s single arg came back
# `{name:"unit", class_name:&"Unit", type:24, ...}` and its return
# `{name:"", class_name:&"", type:2, ...}`; `grant`'s three args came back `event`/`target` as
# TYPE_OBJECT with class_name `EventCore`/`Unit` and `amount` as TYPE_INT with class_name `&""`, and
# its return as `{type:0, class_name:&"", ...}` - TYPE_NIL, i.e. `-> void`.
const FROZEN_SIGNATURES := {
	current = {
		args = [['unit', TYPE_OBJECT, &'Unit']],
		return_type = TYPE_INT, return_class = &'',
	},
	has = {
		args = [['unit', TYPE_OBJECT, &'Unit']],
		return_type = TYPE_BOOL, return_class = &'',
	},
	grant = {
		args = [
			['event', TYPE_OBJECT, &'EventCore'],
			['target', TYPE_OBJECT, &'Unit'],
			['amount', TYPE_INT, &''],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
	increase = {
		args = [
			['event', TYPE_OBJECT, &'EventCore'],
			['target', TYPE_OBJECT, &'Unit'],
			['amount', TYPE_INT, &''],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
	grit = {
		args = [['unit', TYPE_OBJECT, &'Unit']],
		return_type = TYPE_INT, return_class = &'',
	},
}

## A STATBLOCK buff that reports its holder's CURRENT Overshield as a sensor-range bonus - the shape
## the Sluagh's Inexorable Formation ships in SP1 Task 5, reduced to the one property this file is
## about.
##
## IN-FILE AND NOT THE REAL BUFF, deliberately. This file's subject is the SHARED helper, which four
## frames consume; giving it a dependency on any one of them would make a Sluagh change able to
## redden the Myconid's helper spec. It is also the only way to write this test before that content
## exists, which is the order the plan builds in.
##
## get_values IS CALLED WITH A BARE CONTEXT. unit_battle_state.gd:232 calls buff.get_values() with no
## argument at all, so BuffCore.get_values builds Context.create({}) and context.map falls back to
## X.map() (context.gd:76-80). get_holder_unit(context.map) therefore resolves through the live map -
## get_owner_unit would not, because a hand-applied buff has an empty from_gear (buff_core.gd:104).
class OvershieldSensors extends Buff:
	func get_values(core:BuffCore, context:Context) -> Context:
		var block := Statblock.new()
		block.sensor_range = Overshield.current(core.get_holder_unit(context.map))
		return Context.create({ object = block })

	static func hang_on(target:Unit) -> void:
		var probe := OvershieldSensors.new()
		probe.to = Buff.TO.STATBLOCK
		probe.hide_from_player = true
		UnitCondition.apply_buff(SpecFactory.dummy_event({unit = target}), target, probe)

var game:Gamemaster
var unit:Unit

var log_lines:PackedStringArray = []
var battle_log:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

func before_each() -> void:
	game = MyconidFixture.create_game(self)
	unit = MyconidFixture.create_ally(game, SUBJECT_TILE)
	log_lines = []
	battle_log.on_log_text.connect(_record_log)

func after_each() -> void:
	if battle_log.on_log_text.is_connected(_record_log): battle_log.on_log_text.disconnect(_record_log)
	Dice.CHEAT_ROLL_QUEUE.clear()

func _record_log(line:String) -> void: log_lines.append(line)

## Every call in this file goes through a dummy event, which has no live block - so it takes the
## helper's SECOND path, through X.current_level(). That is the path a spec always takes and the one
## Infection.apply established (spec/test_infection.gd:29); the live-block path is exercised for real
## by test_halo.gd, from inside a reaction's activation.
func dummy() -> EventCore:
	return SpecFactory.dummy_event({unit = unit})

# ---------------------------------------------------------------- the interface itself

func test_the_frozen_interface_pins_these_five_signatures():
	# Roadmap 4 freezes this list when SP1 ships. This pins the FULL signature of each of the five -
	# argument count, each argument's name and order, each argument's type, and the return type - not
	# only that the name survives. A rename, a reordered parameter, or a changed argument/return type
	# is five later frames' worth of churn, and nothing else in the suite would notice any of those
	# until those frames are written.
	#
	# Deliberately does NOT fail if a sixth function is added: the Infection precedent
	# (infection.gd, task-4-brief.md) is that a later sub-project extends the file with every earlier
	# spec still green, so this only pins the five that exist today.
	#
	# Through a Script-typed local, not Overshield.get_script_method_list() directly: GDScript reads a
	# preloaded script constant as a CLASS in a call position, and refuses the call at parse time -
	# "Cannot call non-static function get_script_method_list() ... Make an instance instead". The
	# local makes it an ordinary Script object again, and the list does carry static functions.
	var script:Script = Overshield
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'Overshield.%s survives.' % required)
		if not by_name.has(required): continue

		var entry:Dictionary = by_name[required]
		var expected:Dictionary = FROZEN_SIGNATURES[required]
		var expected_args:Array = expected.args

		assert_eq(entry.args.size(), expected_args.size(),
			'%s takes exactly %d argument(s).' % [required, expected_args.size()])
		for i:int in range(min(entry.args.size(), expected_args.size())):
			var actual_arg:Dictionary = entry.args[i]
			var expected_arg:Array = expected_args[i]
			assert_eq(actual_arg.name, expected_arg[0],
				'%s arg %d is named "%s".' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.type, expected_arg[1],
				'%s arg %d ("%s") has the frozen Variant.Type.' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.class_name, expected_arg[2],
				'%s arg %d ("%s") has the frozen class_name.' % [required, i, expected_arg[0]])

		# PINS `static`, NOT ONLY THE NAME (frame close, finding 4, 2026-09-16). Every caller spells
		# Overshield.<fn>(...) on the preloaded script CONSTANT, never on an instance, and GDScript
		# refuses that at PARSE time if `static` is dropped. That is not one failing assertion - it is
		# this whole file AND test_halo.gd (which preloads the same constant) going unparsable, and GUT
		# logs 'Ignoring script ...' and drops each one from the totals rather than failing it
		# (test_collector.gd:130) - the suite reads GREEN, with two scripts' worth of tests missing from
		# it. A bitwise AND against the single bit, not equality against a guessed total flags value, so
		# some other bit a future engine build sets on an ordinary static method cannot fail this for an
		# unrelated reason - addons/gut/script_parser.gd:41-42 tests the same bit the same way, to decide
		# whether a method is safe to double.
		#
		# MEASURED AT THE FRAME CLOSE, AND THE ASSERTION BELOW IS NOT WHAT CATCHES THAT PARSE BREAK -
		# it CANNOT be, because this file never runs when it happens. Dropping `static` from grit()
		# was run for real on 2026-09-16: GUT logged 'Ignoring script ... because it does not extend
		# GutTest', all 14 tests here vanished from the totals, and the process exited ZERO. What
		# catches that is the ignored-scripts / test-count check the suite is read with, never an
		# assertion inside the file that stopped parsing.
		#
		# So what IS this assertion for? The case that still parses: a future session converting the
		# helper to instance methods and updating every caller to match. That leaves the suite green
		# and fully populated while silently breaking a contract FIVE LATER FRAMES depend on (roadmap
		# section 4 freezes it). This is the only thing that would notice.
		assert_true((entry.flags & METHOD_FLAG_STATIC) != 0,
			'%s is still static - a caller spells it on the class, not an instance.' % required)
		# default_args is unpinned for the same reason, to a smaller effect (finding 4): none of the
		# five takes a default argument today, and one that silently grew one would change calling
		# semantics for five later frames with nothing here to notice.
		assert_eq(entry.default_args.size(), 0, '%s takes no default arguments.' % required)

		assert_eq(entry.return.type, expected.return_type,
			'%s has the frozen return Variant.Type.' % required)
		assert_eq(entry.return.class_name, expected.return_class,
			'%s has the frozen return class_name.' % required)

# ---------------------------------------------------------------- reading

func test_current_is_zero_for_an_invalid_unit():
	# Every consumer calls this from inside a reaction gate, which runs for every unit's every gear on
	# every event - a null here would be an error storm, not a wrong answer.
	assert_eq(Overshield.current(null), 0, 'null reads as no overshield.')

func test_current_reads_the_units_overshield():
	assert_eq(Overshield.current(unit), 0, 'A fresh unit has none.')
	await Overshield.grant(dummy(), unit, 3)
	assert_eq(Overshield.current(unit), 3, 'And reads back what was granted.')

func test_has_is_true_only_above_zero():
	assert_false(Overshield.has(unit), 'None to start.')
	await Overshield.grant(dummy(), unit, 1)
	assert_true(Overshield.has(unit), 'One is enough.')
	assert_false(Overshield.has(null), 'And an invalid unit has none.')

# ---------------------------------------------------------------- granting

func test_grant_sets_the_overshield():
	await Overshield.grant(dummy(), unit, 4)
	assert_eq(unit.state.overshield, 4, 'The engine event ran and set it.')

func test_grant_never_lowers_an_existing_overshield():
	# THE ENGINE RULE, and the reason increase() has to exist at all:
	# event_unit_overshield.gd:15 is max(old, amount). A helper that quietly added would diverge from
	# every vanilla source of Overshield in the game.
	await Overshield.grant(dummy(), unit, 5)
	await Overshield.grant(dummy(), unit, 2)
	assert_eq(unit.state.overshield, 5, 'The smaller grant does not replace the larger.')
	await Overshield.grant(dummy(), unit, 7)
	assert_eq(unit.state.overshield, 7, 'A larger one does.')

func test_granting_zero_or_less_is_a_no_op_and_fires_no_event():
	# Halo at Grit 0 would otherwise pop "Overshield 0" over an ally and write a line into the battle
	# log saying nothing happened. The gate in Halo refuses Grit 0 too, but the helper is the one that
	# has to hold for the five frames to come.
	log_lines = []
	await Overshield.grant(dummy(), unit, 0)
	await Overshield.grant(dummy(), unit, -3)
	assert_eq(unit.state.overshield, 0, 'Nothing changed.')
	assert_true(log_lines.is_empty(), 'No battle-log line was written by a zero or negative grant.')
	for line:String in log_lines:
		assert_false(line.to_lower().contains('overshield'),
			'No overshield line was logged: %s' % line)

func test_grant_leaves_an_invalid_target_alone():
	# Asserted because it cannot be observed any other way: the point is that it does not throw.
	await Overshield.grant(dummy(), null, 4)
	assert_eq(unit.state.overshield, 0, 'Nobody else gained anything either.')

# ---------------------------------------------------------------- increasing

func test_increase_adds_to_what_is_there():
	# For the cards that say "increases by that much instead". Built on grant(), so it inherits the
	# engine rule rather than writing state.overshield by hand.
	await Overshield.grant(dummy(), unit, 3)
	await Overshield.increase(dummy(), unit, 2)
	assert_eq(unit.state.overshield, 5, '3 + 2, not max(3, 2).')

func test_increase_from_nothing_is_just_a_grant():
	await Overshield.increase(dummy(), unit, 4)
	assert_eq(unit.state.overshield, 4, 'Starting from zero, increase and grant agree.')

func test_increasing_by_zero_or_less_is_a_no_op_and_fires_no_event():
	# Mirrors the no-op guard on grant() (test_granting_zero_or_less_is_a_no_op_and_fires_no_event) -
	# but increase() needs its OWN amount <= 0 guard, not just grant()'s. increase() computes
	# current(target) + amount before ever calling grant(), so on a unit already at 5,
	# increase(event, unit, -3) would call grant(event, unit, 2) - positive, so grant()'s own guard
	# would not catch it, and the call would fire a real (if silly) event.
	await Overshield.grant(dummy(), unit, 5)
	log_lines = []
	await Overshield.increase(dummy(), unit, -3)
	await Overshield.increase(dummy(), unit, 0)
	assert_eq(unit.state.overshield, 5, 'Still 5 - neither call changed it.')
	assert_true(log_lines.is_empty(), 'No battle-log line was written by a zero or negative increase.')
	for line:String in log_lines:
		assert_false(line.to_lower().contains('overshield'),
			'No overshield line was logged: %s' % line)

# ---------------------------------------------------------------- grit

func test_grit_is_half_the_licence_level_rounded_up():
	# Util.half is CEILI (util.gd:14-15), and the engine's own glossary row for lancer.term.grit says
	# "rounded up" - so licence level 1 is Grit 1, not Grit 0. Worth pinning: the design doc's ruling 4
	# says "Grit 0 (licence level 0-1)", which is the tabletop's floor and NOT what this engine does.
	# Only licence level 0 is Grit 0.
	unit.core.pilot.license_level = 0
	assert_eq(Overshield.grit(unit), 0, 'Level 0 is Grit 0.')
	unit.core.pilot.license_level = 1
	assert_eq(Overshield.grit(unit), 1, 'Level 1 is Grit 1 - ceili, not floor.')
	unit.core.pilot.license_level = 4
	assert_eq(Overshield.grit(unit), 2, 'Level 4 is Grit 2.')

func test_grit_is_zero_without_a_valid_pilot():
	# The Aceso idiom (action_aceso_stabilizer.gd:9). Deployables, drones and NPC props have no pilot,
	# and a gate that dereferenced one would throw from inside a reaction poll.
	unit.core.pilot = null
	assert_eq(Overshield.grit(unit), 0, 'No pilot, no Grit.')
	assert_eq(Overshield.grit(null), 0, 'And no unit, no Grit.')

func test_the_fixture_helper_and_the_helper_agree_about_grit():
	# MyconidFixture.set_grit takes the GRIT a spec wants and doubles it into a licence level, so no
	# spec has to do the rounding in its head. This is the one place the two derivations are checked
	# against each other - test_halo.gd leans on set_grit for every positive case.
	MyconidFixture.set_grit(unit, 2)
	assert_eq(Overshield.grit(unit), 2, 'set_grit(2) really is Grit 2.')

# ---------------------------------------------------------------- the cache refresh

func test_grant_refreshes_the_targets_cached_stats_immediately():
	# ADDED FOR THE SLUAGH (SP1 Task 4, ruling 12), and it is an ADDITION to the frozen interface's
	# behaviour rather than a change to its shape: no name, argument or return type moved, which
	# test_the_frozen_interface_pins_these_five_signatures above is what guarantees.
	#
	# THE PROBLEM IT SOLVES. state.stat_bonus is rebuilt ONLY by UnitBattleState.update_cached_values
	# (unit_battle_state.gd:229-234), and event_unit_overshield does not call it - its entire body is
	# state.overshield = maxi(0, maxi(old, amount)) plus a popcorn and a log line
	# (event_unit_overshield.gd:10-22). So a STATBLOCK buff that reads Overshield reported a stale
	# number until something unrelated refreshed the cache. The reaction bus has no overshield
	# trigger to listen on (reaction_bus.gd:9-42), which is why this lives in the helper.
	#
	# WITHOUT THE REFRESH this reads `base`, not `base + 3`. That is the whole test.
	OvershieldSensors.hang_on(unit)
	var base:int = unit.get_sensor_range()
	await Overshield.grant(dummy(), unit, 3)
	assert_eq(Overshield.current(unit), 3, 'fixture: the grant landed.')
	assert_eq(unit.get_sensor_range(), base + 3,
		'And a STATBLOCK buff reading Overshield reports the new value IMMEDIATELY - '
		+ 'Unit.get_sensor_range is core + state.stat_bonus.sensor_range (unit.gd:305).')

func test_increase_refreshes_the_cache_too_by_inheriting_grants():
	# increase() IS BUILT ON grant() (overshield.gd:62), so the refresh is inherited rather than
	# written twice - and the arithmetic is what makes that safe: increase's own amount <= 0 guard
	# (:61) means the number it hands grant is always positive, so grant can never take its early
	# return (:47) from this path and can never skip the refresh.
	#
	# PINNED SEPARATELY ANYWAY. If a later session decides to write the line into increase() as well,
	# nothing here changes; if someone moves it OUT of grant() and into increase() only, the test
	# above catches it. Between them the two say where the line has to be.
	OvershieldSensors.hang_on(unit)
	var base:int = unit.get_sensor_range()
	await Overshield.grant(dummy(), unit, 2)
	await Overshield.increase(dummy(), unit, 3)
	assert_eq(Overshield.current(unit), 5, 'fixture: 2 + 3, not max(2, 3).')
	assert_eq(unit.get_sensor_range(), base + 5, 'And the cache followed the additive gain too.')
