# RAPID STABILIZATION JETS (M/K2, SP1 Task 1): "1/scene the M/K2 may ignore the Ordnance tag until
# the end of the current turn."
#
# WHAT ORDNANCE IS IN THIS ENGINE, and therefore what this trait actually does. The timing rule is
# ONE unit-state flag, unit.state.is_firing_ordnance: set at turn start (event_turn_start.gd:83),
# cleared by any non-protocol non-reaction action (unit_action.gd:269) and by any voluntary move
# (event_unit_move.gd:88-90), and read in exactly one place - unit_action.gd:146, which refuses an
# Ordnance attack with REASON.ORDNANCE when it is false. So every assertion below is about that
# reason code, not about whether damage landed: the reason names the gate, and a test that only
# watched for a shot could pass for six different reasons.
#
# WHAT IT DOES NOT DO (ruling 5, an ACCEPTED DIVERGENCE from the card, not a bug). Under the Jets an
# Ordnance weapon may be fired after moving or acting, but still NOT at a unit engaged with the
# M/K2: action_attack_weapon.gd:232-236 reads the ORDNANCE tag directly, no buff channel reaches it,
# and weapon tags are add-only. test_an_engaged_target_is_still_refused pins that, and a red there
# means the divergence closed, not that the trait broke.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rapid_stabilization_jets.gd
extends GutTest

const MK2Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/mk2_fixture.gd')

const TRAIT_ID := &'mt_rapid_stabilization_jets'
const ACTION_ID := &'action_rapid_stabilization_jets'
const BUFF_ID := &'buff_rapid_stabilization_jets'

## Vanilla GMS Heavy: accurate, ap, LOADING, ORDNANCE (content/gear/gms/weapons/mw_anti_materiel_rifle.tres:16).
const AMR := &'mw_anti_materiel_rifle'

const START := Vector2i(2, 2)
const DESTINATION := Vector2i(4, 2)
const TARGET_TILE := Vector2i(9, 2)

var game:Gamemaster
var mk2:Unit
var target:Unit
var amr:GearCore

func before_each() -> void:
	game = MK2Fixture.create_game(self)
	mk2 = MK2Fixture.create_mk2(game, START)
	target = MK2Fixture.create_dummy(game, TARGET_TILE, -10)
	amr = mk2.core.equip_system(AMR)
	SpecFactory.apply_passive_buffs(mk2)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Why the AMR is unavailable right now, as a REASON enum value.
func amr_reason() -> UnitAction.REASON:
	return UnitAction.get_gear_unavailable_reason(
		SpecificAction.create(mk2, amr, amr.get_solo_action()))

## A STANDARD move, the kind a player takes on their turn - and the ONLY kind that closes the
## ordnance window.
##
## NOT SpecFactory.move(game, unit, tile) on its own. That helper defaults to
## MovementType.create(unit, true), whose second argument is `is_voluntary`, NOT `spend_move`
## (movement_type.gd:34-44) - and event_unit_move.gd:88-90 gates end_ordnance_phase() on
## spend_move, not on voluntary. Only MovementType.create_for_standard_move sets it
## (movement_type.gd:58-61). Measured in this spec's first red run (mk2-sp1-task1-red.log):
## test_moving_closes_the_window came back REASON.NONE, i.e. the window never closed, which would
## have made every "the Jets reopened it" assertion below pass vacuously against a trait that did
## nothing at all.
func move_to(tile:Vector2i) -> void:
	await SpecFactory.move(game, mk2, tile, MovementType.create_for_standard_move(mk2))

func fire_the_jets() -> void:
	await SpecFactory.use_solo(game, mk2, TRAIT_ID)

func has_the_chip() -> bool:
	return mk2.state.buffs.any(func(core:BuffCore) -> bool: return core.base.compcon_id == BUFF_ID)

func jets_reason() -> UnitAction.REASON:
	var gear:GearCore = mk2.get_gear(TRAIT_ID)
	return UnitAction.get_gear_unavailable_reason(
		SpecificAction.create(mk2, gear, gear.get_solo_action()))

# ---------------------------------------------------------------- the window

func test_the_window_is_open_at_turn_start() -> void:
	# The control. Without this, every test below could pass because the AMR was never firable.
	await MK2Fixture.open_turn(game, mk2)
	assert_eq(amr_reason(), UnitAction.REASON.NONE, 'Ordnance is firable at turn start.')

func test_moving_closes_the_window() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await move_to(DESTINATION)
	assert_eq(amr_reason(), UnitAction.REASON.ORDNANCE, 'A voluntary move closed the window.')

func test_the_jets_reopen_the_window_after_a_move() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await move_to(DESTINATION)
	await fire_the_jets()
	assert_eq(amr_reason(), UnitAction.REASON.NONE, 'The Jets reopened it.')

func test_the_window_stays_open_across_a_later_action() -> void:
	# THE REASON THE BUFF EXISTS. The action's own direct set covers the first use; this is the part
	# that needs the reaction, and it is the assertion to read first when the trait misbehaves.
	#
	# ms_boost, NOT ms_stabilize. Task 0 measured Stabilize aborting at its unanswered cool-or-repair
	# prompt, and an aborted activation fires no UNIT_ACTION POST at all
	# (event_gear_activate.gd:96-101) - so a Stabilize here would fail for a reason that has nothing
	# to do with this trait. Boost is prompt-free and was measured firing the POST.
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	await SpecFactory.use_solo(game, mk2, &'ms_boost')
	assert_eq(amr_reason(), UnitAction.REASON.NONE, 'Still open after a Boost.')

func test_the_window_stays_open_across_a_later_move() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	await move_to(DESTINATION)
	assert_eq(amr_reason(), UnitAction.REASON.NONE, 'Still open after moving again.')

func test_the_ordnance_weapon_actually_fires() -> void:
	# The reason code is the gate, but something has to prove the gate is the only thing in the way.
	await MK2Fixture.open_turn(game, mk2)
	await move_to(DESTINATION)
	await fire_the_jets()
	var before:int = target.core.current.health
	Dice.cheat_attack([19], [3, 3, 3, 3, 3, 3, 3, 3])
	await game.execute_event(&'event_gear_activate', {
		action = amr.get_solo_action(), gear = amr, unit = mk2, target_unit = target,
	})
	assert_lt(target.core.current.health, before, 'The shot landed after the Jets.')

# ---------------------------------------------------------------- the limits

func test_the_jets_are_once_per_scene() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	assert_eq(jets_reason(), UnitAction.REASON.PER_SCENE, 'A second use in the scene is refused.')

func test_the_chip_is_gone_at_turn_end() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	assert_true(has_the_chip(), 'The chip is on while the turn runs.')
	await SpecFactory.end_turn(game, mk2)
	assert_false(has_the_chip(), 'END_OF_THIS_TURN cleared it.')

func test_the_next_turns_move_closes_the_window_again() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	await move_to(START)
	assert_eq(amr_reason(), UnitAction.REASON.ORDNANCE,
		'The effect did not leak into the next turn.')

func test_an_engaged_target_is_still_refused() -> void:
	# RULING 5, the accepted divergence. A red here means the engine gained a channel to the engaged
	# clause - re-read design §0.5 before "fixing" anything.
	var adjacent := MK2Fixture.create_dummy(game, START + Vector2i(1, 0), -10)
	await MK2Fixture.open_turn(game, mk2)
	await fire_the_jets()
	var specific := SpecificAction.create(mk2, amr, amr.get_solo_action())
	assert_false(amr.get_solo_action().can_target_unit(adjacent, specific),
		'An engaged target is still off limits under the Jets.')
