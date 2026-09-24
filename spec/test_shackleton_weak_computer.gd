# WEAK COMPUTER (Shackleton, SP1): "The Shackleton receives +1 Difficulty on Systems checks and saves."
#
# Design specs/2026-09-24-shackleton-design.md ruling 2 (the author): the Shackleton's OWN trait
# file, mt_shackleton_weak_computer.tres, with its own buff_shackleton_weak_computer.tres - the
# Fitzgerald's two files copied with the ids renamed, so this card carries its own verbatim rows.
# These are the Fitzgerald's three tests (spec/test_weak_computer.gd, whose header explains the dice)
# re-pointed at this frame, plus a check that the two frames do NOT share one Kit.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_shackleton_weak_computer.gd
extends GutTest

const FRAME_ID := &'mf_shackleton'

var game:Gamemaster
var unit:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)
	unit = SpecFactory.create_unit(game.map, Vector2i(3, 3))
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

func test_it_is_the_shackletons_own_trait_not_the_fitzgeralds() -> void:
	assert_true(GearCore.is_valid(unit.get_gear(&'mt_shackleton_weak_computer')), 'the Shackleton wears its own Kit.')
	assert_false(GearCore.is_valid(unit.get_gear(&'mt_weak_computer')), "and not the Fitzgerald's.")
	assert_eq(X.tr('gear.mt_shackleton_weak_computer.effect'),
		'The Shackleton receives |+1 Difficulty| on Systems checks and saves.', "its own row, this card's words.")
