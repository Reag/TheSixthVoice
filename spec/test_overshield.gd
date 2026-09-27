# The OVERSHIELD helper (SP1 Task 4), born with the Myconid's Halo and frozen when SP1 ships.
#
# Roadmap 4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Five later frames consume
# this one - Sluagh, Hazard, Naga, Primrose, Black Mountain - so a rename here is five frames' worth
# of churn. test_the_frozen_interface_pins_these_five_signatures is the guard, and it pins the whole
# signature - argument order, names, types, and return type - not only that a name survives.
#
# THE BLACK MOUNTAIN (SP1, 2026-09-27) ADDED THREE PUBLIC FUNCTIONS - grant_by, increase_by,
# is_granted_by - and the hidden mark buff_overshield_granted_by (design ruling 5), and changed ONE
# frozen body: increase() now sends `boolean = true` on the event (ruling 6, a compat fix the resident
# Emperor mod reads). The pin below now names EIGHT public functions and FAILS ON A NINTH: the
# underscore-prefixed helpers are private by convention and are not counted. The "granted by" section
# at the end of this file is that sub-project's addition.
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
const BlackMountainFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
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
	# The Black Mountain's three (SP1, ruling 5). Frozen the moment SP1 ships, like the five above.
	grant_by = {
		args = [
			['event', TYPE_OBJECT, &'EventCore'],
			['target', TYPE_OBJECT, &'Unit'],
			['amount', TYPE_INT, &''],
			['granter_gear', TYPE_OBJECT, &'GearCore'],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
	increase_by = {
		args = [
			['event', TYPE_OBJECT, &'EventCore'],
			['target', TYPE_OBJECT, &'Unit'],
			['amount', TYPE_INT, &''],
			['granter_gear', TYPE_OBJECT, &'GearCore'],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
	is_granted_by = {
		args = [
			['unit', TYPE_OBJECT, &'Unit'],
			['granter', TYPE_OBJECT, &'Unit'],
		],
		return_type = TYPE_BOOL, return_class = &'',
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

func test_the_frozen_interface_pins_these_eight_signatures():
	# Roadmap 4 freezes this list when SP1 ships. This pins the FULL signature of each of the five -
	# argument count, each argument's name and order, each argument's type, and the return type - not
	# only that the name survives. A rename, a reordered parameter, or a changed argument/return type
	# is five later frames' worth of churn, and nothing else in the suite would notice any of those
	# until those frames are written.
	#
	# It FAILS ON A NINTH PUBLIC FUNCTION (Black Mountain SP1, design 1.2 - the Lock-on pin's shape).
	# The Infection precedent (a later sub-project extends the file with every earlier spec still
	# green) still holds for BEHAVIOUR; a new NAME is a new contract, and the sub-project that adds
	# one updates this table in the same commit. Underscore-prefixed functions are private by
	# convention (the shared _fire / _mark_if_took paths) and are not counted.
	#
	# Through a Script-typed local, not Overshield.get_script_method_list() directly: GDScript reads a
	# preloaded script constant as a CLASS in a call position, and refuses the call at parse time -
	# "Cannot call non-static function get_script_method_list() ... Make an instance instead". The
	# local makes it an ordinary Script object again, and the list does carry static functions.
	var script:Script = Overshield
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	var public:Array = by_name.keys().filter(func(name:String) -> bool: return not name.begins_with('_'))
	assert_eq(public.size(), FROZEN_SIGNATURES.size(),
		'Exactly %d public functions - a ninth is a new contract and belongs in this table: %s' % [FROZEN_SIGNATURES.size(), public])

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
	# increase() IS BUILT ON grant() (overshield.gd:96), so the refresh is inherited rather than
	# written twice - and the arithmetic is what makes that safe: increase's own amount <= 0 guard
	# (:95) means the number it hands grant is always positive, so grant can never take its early
	# return (:78) from this path and can never skip the refresh. (Those three numbers were the SP1
	# ones until the close: this branch added 40 lines of header above them.)
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

# ---------------------------------------------------------------- "granted by" (Black Mountain SP1)
#
# Design ruling 5: grant_by / increase_by are grant / increase plus a hidden mark
# (buff_overshield_granted_by, until = LOSE_OVERSHIELD, from_gear = the granter's gear) applied only when
# the grant TOOK; is_granted_by resolves the mark's owner. The granter here is another dummy's own
# basic improvised attack gear - any GearCore with an owner will do, and the fixture's dummies carry the
# basic loadout.

const MARK := &'buff_overshield_granted_by'
const GRANTER_GEAR := &'mw_improvised_attack'

func granter_gear(granter:Unit) -> GearCore: return granter.get_gear(GRANTER_GEAR)
func marks_on(target:Unit) -> int: return UnitCondition.get_buffs(target, MARK).size()

func test_a_grant_that_took_marks_the_target_as_granted_by_the_granter():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant_by(dummy(), unit, 3, granter_gear(granter))
	assert_eq(Overshield.current(unit), 3, 'fixture: the grant landed.')
	assert_eq(marks_on(unit), 1, 'One mark.')
	assert_true(Overshield.is_granted_by(unit, granter), 'And it resolves to the granter.')
	assert_false(Overshield.is_granted_by(unit, unit), 'Not to anyone else.')
	if marks_on(unit) < 1: return
	assert_true(UnitCondition.get_buffs(unit, MARK)[0].base.hide_from_player, 'The mark is hidden (ruling 15).')
	assert_eq(UnitCondition.get_buffs(unit, MARK)[0].base.until, Lancer.UNTIL.LOSE_OVERSHIELD, 'And lives while any Overshield remains.')

func test_a_grant_that_lost_to_a_larger_shield_marks_nothing():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant(dummy(), unit, 5)
	await Overshield.grant_by(dummy(), unit, 3, granter_gear(granter))
	assert_eq(Overshield.current(unit), 5, 'fixture: the max rule kept the 5.')
	assert_eq(marks_on(unit), 0, 'The granter did not grant that shield.')
	assert_false(Overshield.is_granted_by(unit, granter), 'So is_granted_by is false.')

func test_a_grant_equal_to_the_current_shield_still_marks():
	# The max rule made the NUMBER a no-op; the card did not. "amount asked >= what it held" marks.
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant(dummy(), unit, 3)
	await Overshield.grant_by(dummy(), unit, 3, granter_gear(granter))
	assert_eq(Overshield.current(unit), 3, 'fixture: unchanged.')
	assert_true(Overshield.is_granted_by(unit, granter), 'Refreshed as the granter\'s.')

func test_a_shield_lost_outside_the_damage_event_is_not_granted_by_anyone():
	# Frame close finding 1 (Important): event_unit_damage's own damage() static (called directly by
	# the Pegasus's Ushabti Omnigun, action_fire_omnigun.gd:60, and reached internally by heat() on a
	# zero-heat-cap actor) spends Overshield with NO event and NO LOSE_OVERSHIELD clear - so the mark
	# is left behind on a unit that no longer holds any Overshield at all. is_granted_by() must read
	# false regardless, not just "no larger grant beat it".
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant_by(dummy(), unit, 1, granter_gear(granter))
	EventUnitDamage.damage(unit, 1, Lancer.DAMAGE_TYPE.KINETIC) # the Omnigun's path: no event, no clear
	assert_eq(Overshield.current(unit), 0, 'fixture: the shield is gone.')
	assert_eq(marks_on(unit), 1, 'fixture: and the engine left the mark behind (the gap this pins).')
	assert_false(Overshield.is_granted_by(unit, granter), 'No Overshield, so nothing is "granted by" anyone.')

func test_the_granters_death_ends_the_mark_when_the_granter_is_core_gear():
	# Finding 3b: every OTHER granter in this file is BASIC gear (mw_improvised_attack), and basic
	# gear is skipped by clear_outgoing_buffs_from_unit's get_all_gear(false) (loadout_core.gd:
	# 511-518), so a mark from a basic-gear granter actually SURVIVES that granter's death - the
	# helper's header claim ("ends the mark with the granter") is untrue for that shape and only
	# reads correct because is_granted_by's OWN Unit.is_valid(granter) guard also goes false. Pin the
	# real production shape instead: the Black Mountain's CORE gear (traits ARE in get_all_gear), the
	# one grant_overshield_by actually uses.
	var bm_game := BlackMountainFixture.create_game(self)
	var black_mountain := BlackMountainFixture.create_black_mountain(bm_game, Vector2i(4, 4))
	var target := BlackMountainFixture.create_ally(bm_game, Vector2i(6, 4))
	await BlackMountainFixture.grant_overshield_by(black_mountain, target, 3)
	assert_true(Overshield.is_granted_by(target, black_mountain), 'fixture: marked.')
	await bm_game.execute_event(&'event_unit_die', {unit = black_mountain})
	assert_eq(UnitCondition.get_buffs(target, MARK).size(), 0,
		'The mark went with the granter: core gear IS cleared on owner death.')
	assert_false(Overshield.is_granted_by(target, black_mountain), 'is_granted_by reads false too.')

func test_damage_that_zeroes_the_shield_clears_the_mark():
	# event_unit_damage.gd:175-177: the moment old_overshield != new and new <= 0, every LOSE_OVERSHIELD
	# buff on the unit is cleared. The subject is a 200-HP dummy, so nobody dies.
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant_by(dummy(), unit, 3, granter_gear(granter))
	assert_true(Overshield.is_granted_by(unit, granter), 'fixture: marked.')
	await game.execute_event(&'event_unit_damage', {unit = unit, number = 2, category = Lancer.DAMAGE_TYPE.KINETIC})
	assert_eq(Overshield.current(unit), 1, 'fixture: 2 of the 3 soaked, 1 remains.')
	assert_true(Overshield.is_granted_by(unit, granter), 'Still marked while any remains.')
	await game.execute_event(&'event_unit_damage', {unit = unit, number = 4, category = Lancer.DAMAGE_TYPE.KINETIC})
	assert_eq(Overshield.current(unit), 0, 'fixture: the shield is gone.')
	assert_eq(marks_on(unit), 0, 'And the mark went with it.')
	assert_false(Overshield.is_granted_by(unit, granter), 'is_granted_by reads false.')

func test_a_larger_grant_from_somebody_else_leaves_the_mark():
	# The author's call (ruling 5): the mark lives while ANY Overshield remains, whoever topped it up.
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant_by(dummy(), unit, 3, granter_gear(granter))
	await Overshield.grant(dummy(), unit, 9)
	assert_eq(Overshield.current(unit), 9, 'fixture: the foreign grant won the number.')
	assert_true(Overshield.is_granted_by(unit, granter), 'The mark stays.')

func test_the_same_granter_granting_again_refreshes_rather_than_stacks():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant_by(dummy(), unit, 2, granter_gear(granter))
	await Overshield.grant_by(dummy(), unit, 4, granter_gear(granter))
	assert_eq(marks_on(unit), 1, 'apply_buff_alt\'s same-source replacement: one mark, not two.')

func test_two_granters_hold_two_marks():
	var first := MyconidFixture.create_ally(game, Vector2i(6, 4))
	var second := MyconidFixture.create_ally(game, Vector2i(8, 4))
	await Overshield.grant_by(dummy(), unit, 2, granter_gear(first))
	await Overshield.grant_by(dummy(), unit, 4, granter_gear(second))
	assert_eq(marks_on(unit), 2, 'Two sources, two marks.')
	assert_true(Overshield.is_granted_by(unit, first), 'The first is still a granter (the shield never hit 0).')
	assert_true(Overshield.is_granted_by(unit, second), 'And so is the second.')

func test_increase_by_adds_and_marks():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	await Overshield.grant(dummy(), unit, 2)
	await Overshield.increase_by(dummy(), unit, 3, granter_gear(granter))
	assert_eq(Overshield.current(unit), 5, '2 + 3.')
	assert_true(Overshield.is_granted_by(unit, granter), 'Marked.')

func test_a_null_or_invalid_granter_gear_degrades_to_the_plain_call_with_no_mark():
	# DOOMED's +1 after the Black Mountain is destroyed takes this path (ruling 13).
	await Overshield.grant_by(dummy(), unit, 3, null)
	assert_eq(Overshield.current(unit), 3, 'The shield still lands.')
	assert_eq(marks_on(unit), 0, 'No mark without a granter.')
	await Overshield.increase_by(dummy(), unit, 2, null)
	assert_eq(Overshield.current(unit), 5, 'increase_by too.')
	assert_eq(marks_on(unit), 0, 'Still no mark.')

func test_granted_by_calls_inherit_the_no_op_and_validity_guards():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	log_lines = []
	await Overshield.grant_by(dummy(), unit, 0, granter_gear(granter))
	await Overshield.increase_by(dummy(), unit, -1, granter_gear(granter))
	await Overshield.grant_by(dummy(), null, 3, granter_gear(granter))
	assert_eq(Overshield.current(unit), 0, 'Nothing changed.')
	assert_eq(marks_on(unit), 0, 'Nothing marked.')
	assert_true(log_lines.is_empty(), 'No event fired.')

func test_is_granted_by_is_null_safe():
	var granter := MyconidFixture.create_ally(game, Vector2i(6, 4))
	assert_false(Overshield.is_granted_by(null, granter), 'No unit.')
	assert_false(Overshield.is_granted_by(unit, null), 'No granter.')
	assert_false(Overshield.is_granted_by(unit, granter), 'Nothing granted yet.')

# ---------------------------------------------------------------- the event data (ruling 6)

## Reads what the resident Emperor mod's Imperial Vestment reads: the overshield event's context at
## PRE, through the trigger that mod's event_unit_overshield.gd_ext.gd fires. Vanilla has no overshield
## trigger, so this is the only listener that can see the data - and it is exactly the consumer the flag
## exists for. Records `boolean` and never acts.
class BooleanWatcher extends ActionReaction:
	var seen:Array[bool] = []
	func _init() -> void:
		triggers_on = [&'overshield_emperor']
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false
	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]: return [Context.PROP.unit]
	func triggers_on_event(_unit:Unit, _gear:GearCore, _triggering_event:EventCore) -> bool: return true
	func activate(context:Context, _activation:EventCore) -> void:
		seen.append(context.event.context.boolean)

func skipped_without_the_emperor_trigger() -> bool:
	var script:Script = load('res://content/events/event_unit_overshield.gd')
	while script != null:
		if script.source_code.contains('overshield_emperor'): return false
		script = script.get_base_script()
	var message := 'SKIPPED: gavstarb-ssc_emperor is not resident, so no trigger exposes the overshield event data. Restore the residency set with restore-links.ps1.'
	gut.p(message)
	pass_test(message)
	return true

func test_increase_sends_boolean_true_on_the_event_and_grant_does_not():
	if skipped_without_the_emperor_trigger(): return
	var watcher := BooleanWatcher.new()
	var kit := Kit.new()
	kit.compcon_id = &'overshield_spec_boolean_watcher'
	kit.is_trait = true
	kit.actions.append(watcher)
	unit.core.loadout.equipped_kits.append(kit)
	SpecFactory.apply_passive_buffs(unit)
	await Overshield.grant(dummy(), unit, 2)
	await Overshield.increase(dummy(), unit, 1)
	await Overshield.grant_by(dummy(), unit, 4, granter_gear(unit))
	await Overshield.increase_by(dummy(), unit, 1, granter_gear(unit))
	assert_eq(watcher.seen, [false, true, false, true] as Array[bool],
		'grant and grant_by carry no boolean; increase and increase_by say boolean = true (ruling 6).')
	assert_eq(Overshield.current(unit), 5, 'fixture: 2, 3, 4, 5 - the arithmetic is untouched on a non-Emperor.')
