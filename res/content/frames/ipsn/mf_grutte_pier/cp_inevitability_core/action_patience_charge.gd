# PATIENCE IN ALL THINGS' "+3" (design ruling 15): "At the start of your turn, Zwarte Hoop gains 3
# additional charges".
#
# ITS OWN ACTION SO THE PROTOCOL CAN KICKSTART IT. A protocol is pressed in the protocol window, after
# the turn's new_turn reactions already ran (the mod's ruling 24), so action_patience_in_all_things
# names this in kickstart_sibling_action and the pressing turn gets its +3. A kickstarted activation
# skips triggers_on_event (action_system_apply_buff.gd:133-141), so the chip is checked in activate too.
extends ActionReactionSelf

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	return Core.has_patience(unit)

func activate(context:Context, _activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	if not Core.has_patience(unit): return
	Core.set_charges(unit, gear, Core.charges(gear) + Core.PATIENCE_GAIN)
