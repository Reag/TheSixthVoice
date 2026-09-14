# SP1 Task 2: Weak Computer (mf_fitzgerald / mt_weak_computer.tres).
#
# Design doc §2.4: "The Fitzgerald receives +1 Difficulty on all SYSTEMS saves and checks."
# Implemented as content only: content/frames/shared/mt_exposed_reactor.tres copied with save_type
# changed to Lancer.HASE.SYS (2) - a BuffSkillSave (mod = -1, to = &"save") wrapped in a
# PassiveBuffApplicator on a trait Kit.
#
# THE BUFF IS A STANDALONE FILE, unlike vanilla's, which carries its BuffSkillSave as an inline
# SubResource. Whole-branch review 2026-09-13: the buff does not set hide_from_player, so
# mech_info.gd:34 renders it as a status chip on every Fitzgerald - and an inline Buff never enters
# the mod's `buffs` index, so test_content_integrity's icon guard could not see it and SP5 could have
# finished the icon pass with this chip still blank. It now lives beside the Kit as
# res/content/frames/ipsn/mf_fitzgerald/buff_weak_computer.tres, and is listed in VISIBLE_BUFFS.
#
# The conversion is behaviour-preserving, and the three tests below are what proves it: the buff is
# the same script with the same three properties, reached by ExtResource instead of SubResource. Two
# things it does change, both improvements: compcon_id goes from Buff.GENERIC_ID to
# &'buff_weak_computer' (buff.gd:106-111), so the buff serializes by id instead of by
# Util.serialize_generic; and its display text now resolves through the buff_weak_computer key path
# first, which carries no rows, so Translate.buff falls through to the owner gear's
# gear.mt_weak_computer.* rows - the same strings the chip showed before.
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

## WHY THE THREE TESTS ABOVE CANNOT CATCH A FLIPPED SIGN. Dice.roll_dice loops `for die in
## abs(dice.count)` (dice.gd:24), and Dice.sum_rolls only applies the sign AFTERWARDS, via
## `result *= signi(dice.count)` (dice.gd:65). buff_weak_computer.tres's mod = -1 becomes
## accuracy_bonus = -1 in UnitHasecheck.roll_check, and Dice.roll_d6_accuracy(-1) calls
## roll_and_sum({count = -1, ...}) - so accuracy +1 (a bonus) and -1 (Weak Computer's actual
## Difficulty) both pop exactly ONE die from CHEAT_ROLL_QUEUE. Every assertion above only checks
## how many dice were popped, which is identical either way - so changing mod = -1 to mod = 1 in
## res/content/frames/ipsn/mf_fitzgerald/buff_weak_computer.tres (turning the drawback into a
## +1 Accuracy bonus) would leave this whole file 3/3 green. This test pins the RESULT of the
## roll instead, which the sign does change.
func test_the_penalty_is_a_difficulty_not_a_bonus() -> void:
	# Queue [10 - sys, 6]: a d20 that would land exactly on save_target 10 once flat_bonus (get_sys())
	# is added back in, then the difficulty/accuracy d6. With mod = -1 (correct) the d6 is subtracted:
	# total = (10 - sys) - 6 + sys = 4, which fails. With mod flipped to +1 the same die is added
	# instead: total = (10 - sys) + 6 + sys = 16, which would pass - same one die popped, opposite
	# verdict.
	var sys:int = unit.core.get_sys()
	Dice.CHEAT_ROLL_QUEUE.append_array([10 - sys, 6])
	var passed:bool = await UnitHasecheck.make_systems_check(SpecFactory.dummy_event(), unit)
	assert_false(passed,
		'Weak Computer is a Difficulty die: a roll that would exactly clear save_target 10 falls to 4 once the d6 is subtracted. If mod were flipped to +1 (an Accuracy bonus) this same queue would clear the target instead.')
