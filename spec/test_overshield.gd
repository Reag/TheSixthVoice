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
