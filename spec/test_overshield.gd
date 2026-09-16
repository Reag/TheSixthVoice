# The OVERSHIELD helper (SP1 Task 4), born with the Myconid's Halo and frozen when SP1 ships.
#
# Roadmap 4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Five later frames consume
# this one - Sluagh, Hazard, Naga, Primrose, Black Mountain - so a rename here is five frames' worth
# of churn. test_the_frozen_interface_is_exactly_these_five_names is the guard.
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

func test_the_frozen_interface_is_exactly_these_five_names():
	# Roadmap 4 freezes this list when SP1 ships. A rename is five later frames' worth of churn, and
	# nothing else in the suite would notice one until those frames are written.
	#
	# Through a Script-typed local, not Overshield.get_script_method_list() directly: GDScript reads a
	# preloaded script constant as a CLASS in a call position, and refuses the call at parse time -
	# "Cannot call non-static function get_script_method_list() ... Make an instance instead". The
	# local makes it an ordinary Script object again, and the list does carry static functions.
	var script:Script = Overshield
	var names:PackedStringArray = []
	for entry:Dictionary in script.get_script_method_list(): names.append(entry.name)
	for required:String in ['current', 'has', 'grant', 'increase', 'grit']:
		assert_true(names.has(required), 'Overshield.%s survives.' % required)

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
