## LEAP: the Primrose flies up to its Speed along a straight ray, and may then knock down one hostile
## it has landed beside.
##
## THE MOVE ITSELF IS DATA, NOT CODE. The .tres beside this file carries an inline MovementType with
## flying and straight_line and nothing else; ActionSystemMovement merges that with the unit's own
## movement type and pathfinds it (action_system_movement.gd:36-45), and with movement_range_fixed 0
## and spend_move false the budget is get_speed_max() - the printed Speed, not what is left of this
## turn's movement (:30-35). So this script overrides nothing about the movement.
##
## RULING 15, IN THREE PARTS. "Up to Speed" is must_move_max_possible left false. "No engagement or
## reaction waiver" is ignore_engagement and ignore_rxns left false, because the card names neither -
## contrast this mod's own action_full_speed_ahead.tres, whose card does. And "cancelling at the
## picker spends nothing" costs no code at all: activate() returns on abort_without_movement_plan
## before spend_actions, and spend_actions is the only route to gear.spend_charge()
## (unit_action.gd:275).
##
## FLYING ALREADY MOVES THROUGH ENEMIES. movement_type.gd:99 is
## `return can_move_through_enemies or flying  # NEW RULE: FLYING CAN MOVE THROUGH ENEMIES`, so the
## flavour's "easily clearing any terrain or hostile forces" needs no flag. Setting
## can_move_through_enemies as well would be an inert line that reads as load-bearing.
##
## THE KNOCK-DOWN IS A RIDER ON A COMPLETED MOVE, NOT A SECOND COST (SP2 Task 4). The Quick and the
## charge both paid for the FLIGHT, and the flight has already happened by the time the pick is
## offered - so declining the pick refunds nothing, and this file never calls spend_actions itself.
## That is the opposite of this mod's action_halo.gd, which returns BEFORE spend_actions precisely so
## that cancelling its prompt is free; there, the prompt IS the action.
extends ActionSystemMovement

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var start_tile := unit.tile()

	await super.activate(context, activation)
	# THIS LINE, NOT THE ONE BELOW IT, IS WHAT CATCHES A CANCEL - measured at SP2 Task 4, correcting
	# what Task 3 recorded here. EventCore.abort_when returns the ALREADY-aborted flag as well as the
	# check it was handed ("if we aborted some other way, also return that it's time to pull the
	# cord", event_core.gd:26-32), and super.activate has already aborted the activation on
	# abort_without_movement_plan. So a Leap cancelled at the picker returns HERE, one line early.
	if activation.abort_without_unit(unit): return
	# The second net, for a move that was NOT aborted and still went nowhere - a plan the engine
	# accepted whose execution was then prevented, which nothing in the suite can currently stage.
	# Individually inert as a result (Task 3 M4 and Task 4 M3 both measured it so); the pair is what
	# test_a_leap_that_never_moved_offers_nothing discriminates, and removing BOTH does redden it.
	# Kept, not deleted: it is the only guard that survives a future engine change to abort_when, and
	# action_full_speed_ahead.gd carries the identical pair.
	if unit.tile() == start_tile: return

	# ---------------------------------------------------------------- the end-of-movement pick
	# "you MAY choose a hostile character adjacent to you" - so it is a prompt, and a declinable one.
	#
	# COLLECTED AFTER THE MOVE, FROM WHERE THE MECH NOW STANDS. get_characters_within measures from
	# the unit's own tiles (unit_relation.gd:34-43), which is ruling 18's measure and is the reason
	# the talents mod's adjacency widening never arrives here: it widens adjacent_characters, and a
	# radius query never asks that question. spec/test_compat.gd pins that from the other side.
	#
	# require_los = false. The card says "adjacent", not "adjacent and visible", and at distance 1
	# line of sight is very nearly always true anyway - which is exactly why leaving the default
	# would be a difference nobody would ever see in a test and somebody would eventually see in play.
	var hostiles:Array[Unit] = UnitRelation.get_characters_within(
		unit, 1, false,
		func(other:Unit) -> bool: return UnitRelation.are_enemies(unit, other)
	)
	if hostiles.is_empty(): return # a prompt about nobody is worse than no prompt

	var specific := SpecificAction.from_context(context)
	var chosen:Unit = await choice_bus.choose_unit(hostiles, true, specific)
	# Declined. Nothing to refund - the charge and the Quick paid for the flight, which happened.
	if not Unit.is_valid(chosen): return
	if activation.abort_without_unit(unit): return
	# Guarded like every sibling in this frame: context.gear is valid in any real gear-activate
	# context, so this is consistency rather than a reachable crash - but the persistent_id read
	# below is the one deref in this file that would take the whole activation down with it.
	if not GearCore.is_valid(context.gear): return

	var passed:bool = await UnitHasecheck.make_hull_save(
		activation, chosen, specific, [Lancer.STATUS.PRONE]
	)
	if not Unit.is_valid(chosen): return
	if passed: return
	UnitCondition.apply_status(
		activation, chosen, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, context.gear.persistent_id
	)
