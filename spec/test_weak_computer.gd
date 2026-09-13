# SP1 Task 2: Weak Computer (mf_fitzgerald / mt_weak_computer.tres).
#
# Design doc §2.4: "The Fitzgerald receives +1 Difficulty on all SYSTEMS saves and checks."
# Implemented as content only: content/frames/shared/mt_exposed_reactor.tres copied wholesale with
# save_type changed to Lancer.HASE.SYS (2) - a BuffSkillSave (mod = -1, to = &"save") wrapped in a
# PassiveBuffApplicator on a trait Kit.
#
# WHY THIS PROVES THE DIE, NOT JUST THE RETURN VALUE. unit_hasecheck.gd:161-186's roll_check pops
# the d20 unconditionally, then calls Dice.roll_d6_accuracy(accuracy_bonus) - which pops a SECOND
# die from Dice.CHEAT_ROLL_QUEUE only when accuracy_bonus != 0 (dice.gd:86-88). So instead of
# trusting the pass/fail bool alone - which make_systems_check/make_systems_save could return
# correctly for the wrong reason - each test queues exactly [d20, d6] and asserts the QUEUE ITSELF
# drained to empty (both dice popped) or stalled at one leftover (only the d20 popped), the same
# style of proof as test_spike_hole_puncher.gd:test_blind_cannon_shot_resolves counting pops.
#
# WHY A REAL EVENT BLOCK FOR THE SAVE TESTS. make_systems_save/make_hull_save route through
# run_save_event, which calls event.execute_events - a no-op unless event.block is a real,
# is_block_valid() EventBlock (event_core.gd:77-81, 48). Plain checks (make_systems_check) go
# straight through handle_check/roll_check and need no block. Same fixture as
# test/gear/test_ms_stable_structure.gd and test/talent/test_t_technophile.gd.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FRAME_ID := &'mf_fitzgerald'

var game:Gamemaster
var unit:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)
	unit = SpecFactory.create_unit(game.map)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + installs the frame's trait Kits' buffs

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## A real EventCore with a real, valid EventBlock - required for make_*_save, which executes
## event_unit_save.gd through it (event.execute_events -> is_block_valid()).
func _save_event() -> EventCore:
	var event := SpecFactory.dummy_event()
	event.block = EventBlock.create_multiple([event])
	add_child_autoqfree(event.block)
	return event

func test_a_systems_save_rolls_at_minus_one() -> void:
	var event := _save_event()
	Dice.CHEAT_ROLL_QUEUE.append_array([19, 6]) # d20, then the difficulty d6 the trait owes
	await UnitHasecheck.make_systems_save(event, unit, SpecificAction.from_id(unit, &'ms_fragment_signal'))
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 0,
		'Weak Computer pulled a second die for the SYSTEMS save: both the d20 and the difficulty d6 were popped.')

func test_a_systems_check_rolls_at_minus_one() -> void:
	Dice.CHEAT_ROLL_QUEUE.append_array([19, 6]) # d20, then the difficulty d6 the trait owes
	await UnitHasecheck.make_systems_check(SpecFactory.dummy_event(), unit)
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 0,
		'Weak Computer pulled a second die for the SYSTEMS check too - roll_check queries the same Buff.TO.SAVE list for both.')

func test_a_hull_save_is_untouched() -> void:
	var event := _save_event()
	Dice.CHEAT_ROLL_QUEUE.append_array([19, 7]) # d20, then a die that must NOT be touched
	await UnitHasecheck.make_hull_save(event, unit, SpecificAction.from_id(unit, &'ms_fragment_signal'))
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 1,
		'Only the d20 was popped for a HULL save - Weak Computer is scoped to save_type = SYS, not all_save_types.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE[0], 7, 'The untouched die is still the one queued, not some other roll.')
