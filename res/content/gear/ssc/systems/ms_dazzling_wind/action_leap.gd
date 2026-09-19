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
## SP2 TASK 4 APPENDS THE END-OF-MOVEMENT CLAUSE BELOW. Until then activate() is super plus the two
## guards every sibling in this mod carries, and that is deliberate - the flight gets its own red and
## its own green before the pick is written.
extends ActionSystemMovement

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var start_tile := unit.tile()

	await super.activate(context, activation)
	if activation.abort_without_unit(unit): return
	# Cancelled at the picker, or refused: nothing was entered, so there is nothing to follow up.
	# action_full_speed_ahead.gd makes the identical pair of checks for the identical reason.
	if unit.tile() == start_tile: return
