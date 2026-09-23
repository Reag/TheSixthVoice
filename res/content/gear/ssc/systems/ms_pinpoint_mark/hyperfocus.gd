## HYPERFOCUS'S SHARED STATE (Purple Thorn SP3 Task 2, rulings 12-13). Statics only, no class_name,
## preload it - the Teleport helper's shape. Held apart from action_hyperfocus.gd so the buffs can
## read the focus without a preload cycle (the action preloads the buffs' .tres files).
##
## THE FOCUS IS AN ID IN THE PINPOINT MARK GEAR'S STATE, Mark for Death's FOCUSING_TARGET_KEY
## (action_mark_for_death.gd:4-23). Gear state is wiped by a short repair, which is the scene end -
## "or the scene ends". Every buff reaches that gear as its own source (BuffCore.get_owner_gear).
extends RefCounted

const FOCUS_KEY := 'hyperfocus_target_id'

const BONUS_ID := &'buff_hyperfocus'        # the Thorn's visible chip: flat +1, and the two end triggers
const RANGE_ID := &'buff_hyperfocus_range'  # the Thorn's hidden ACTION_TILES waiver
const MARKER_ID := &'buff_hyperfocused'     # the focus's visible marker, no effect

## The focused unit, or null when there is none (never chosen, ended, or the unit is gone).
static func focus_of(gear:GearCore, map:MapState) -> Unit:
	if not GearCore.is_valid(gear) or map == null: return null
	var id := StringName(gear.get_state(FOCUS_KEY, ''))
	if id == &'': return null
	var unit:Unit = map.get_unit_by_id(id)
	return unit if Unit.is_valid(unit) else null

## "This effect ends": the Thorn's two buffs, the focus's marker, and the stored id - so a new
## Hyperfocus may be chosen (design ruling 13 clears the state; the SP3 ledger's J-6 is the reading).
static func end_focus(event:EventCore, thorn:Unit, gear:GearCore) -> void:
	if not GearCore.is_valid(gear): return
	var focus := focus_of(gear, thorn.map if Unit.is_valid(thorn) else null)
	gear.set_state(FOCUS_KEY, '')
	if Unit.is_valid(thorn):
		UnitCondition.clear_buff_id(event, thorn, BONUS_ID, gear.persistent_id)
		UnitCondition.clear_buff_id(event, thorn, RANGE_ID, gear.persistent_id)
	if Unit.is_valid(focus):
		UnitCondition.clear_buff_id(event, focus, MARKER_ID, gear.persistent_id)
