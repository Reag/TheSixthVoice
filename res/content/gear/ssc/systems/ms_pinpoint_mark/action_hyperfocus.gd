## HYPERFOCUS (Purple Thorn SP3 Task 2, rulings 12-13): "Expend a charge, choose a character within
## Sensors: You have an additional +1 to attack rolls against them and they always count as within
## range of your ranged weapons. This effect ends if you take any actions that affect a different
## hostile character. You cannot choose a new target unless the current target is destroyed or the
## scene ends."
##
## ActionSystemTargetUnit (the .tres: QUICK, target_range_is_sensors, enemies only, LOS as the
## archetype's baseline - Mark for Death's "within Sensors, seen"). A charge is spent by the default
## consumes_charges inside spend_actions. "A character" is is_character() (a drone included, ruling
## 2026-09-27).
##
## THE LOCK is is_available_to_activate: refused while the stored focus is alive and on the map
## (Mark for Death's own gate, action_mark_for_death.gd:6-7).
##
## THE EFFECT is three buffs and the stored id (hyperfocus.gd). The "ends" half lives on the Thorn's
## chip, buff_hyperfocus.gd - attacks only; the tech-system half was dropped by the SP3 probe.
extends ActionSystemTargetUnit

const Hyperfocus := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/hyperfocus.gd')
const BONUS := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/buff_hyperfocus.tres')
const RANGE := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/buff_hyperfocus_range.tres')
const MARKER := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/buff_hyperfocused.tres')

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return Hyperfocus.focus_of(gear, unit.map) == null

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super(potential_target, specific): return false
	return potential_target.is_character()

func activate_for_target(context:Context, activation:EventCore, target_unit:Unit) -> void:
	var thorn:Unit = context.unit
	var gear:GearCore = context.gear
	gear.set_state(Hyperfocus.FOCUS_KEY, String(target_unit.core.persistent_id))
	UnitCondition.apply_buff(activation, thorn, BONUS, gear)
	UnitCondition.apply_buff(activation, thorn, RANGE, gear)
	UnitCondition.apply_buff(activation, target_unit, MARKER, gear)
