## REINFORCEMENT BLAST'S AGEING REACTION (close-out Pass F Task 11b; the author's ruling on the Task 11
## probe, "Clear it myself"). "All characters within the area gain 1 armor until the end of your next
## turn" - and a drone is a character (Pass A, T14).
##
## THE GAP IT CLOSES. Both halves of the pair are until = 7, END_OF_OWNERS_NEXT_TURN. At the end of the
## Fitzgerald's turn the engine clears them from every holder whose copy has turn_count > 0
## (unit_condition.gd:56-62), and turn_count rises only in new_turn_for_statuses, which
## event_turn_start.handle_starting_unit runs for the unit whose turn starts AND its OWNED deployables.
## A drone never starts a turn of its own, so on a drone NO unit on the map owns, the copies never aged
## and the pair stayed for the whole scene (measured in Task 11).
##
## THE MECHANISM: an ActionReactionSelf on the Fitzgerald's new_turn at PRE, point-free and hidden, that
## does for those copies exactly what new_turn_for_statuses does for every other holder - turn_count
## += 1 (unit_condition.gd:24) - so the ENGINE's own end-of-turn clear then takes both halves at the end
## of this turn. Chosen over an explicit clear at turn end because it needs no state of its own: a clear
## at turn end would have to tell the turn the blast was thrown (must survive) from the next one (must
## go), which is exactly what turn_count already records. Ageing also keeps both halves on the
## engine's one clear, so they can never part (the file's "same clock" rule).
##
## ONLY a drone no unit on the map owns: an owned drone is aged by its owner's turn start (the
## Fitzgerald's, or a hostile NPC's), and ageing it here too would clear it on the Fitzgerald's next
## turn end even when its owner had not yet had a turn - unlike every other holder. ONLY copies from
## THIS gear (from_gear), with the pair's until.
##
## Kept in the Reinforcement Blast gear, not shared (author, T11b). Nothing is spent: no
## spend_actions() call, so no usage tally, no charge and no battle-log line (action_tda_recharge.gd's
## reasoning).
extends ActionReactionSelf

func show_in_tooltip(_kit:Kit) -> bool: return false

## Action.consumes_charges defaults TRUE (action.gd:108) and the reaction bus asks can_activate_gear
## first (reaction_bus.gd:119-124): on a LIMITED 3 Kit with its last charge thrown, the default would
## refuse this reaction - and the third blast's pair on an unowned drone would never age.
func consumes_charges(_specific:SpecificAction) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return false
	return not copies_to_age(unit, gear).is_empty()

func activate(context:Context, _activation:EventCore) -> void:
	for buff_core:BuffCore in copies_to_age(context.unit, context.gear):
		buff_core.turn_count += 1

## This gear's END_OF_OWNERS_NEXT_TURN copies on every drone no unit on the map owns.
static func copies_to_age(unit:Unit, gear:GearCore) -> Array[BuffCore]:
	var found:Array[BuffCore] = []
	var all_units:Array[Unit] = unit.map.get_all_units()
	for holder:Unit in all_units:
		if not holder.is_drone(): continue
		if all_units.any(func(other:Unit) -> bool: return holder.state.is_owned_by(other)): continue
		for buff_core:BuffCore in holder.state.buffs:
			if buff_core.from_gear != gear.persistent_id: continue
			if buff_core.base.until != Lancer.UNTIL.END_OF_OWNERS_NEXT_TURN: continue
			found.append(buff_core)
	return found
