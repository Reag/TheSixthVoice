# ZWARTE HOOP's lapse (design ruling 8): "you lose all charges at the end of your turn" - unless the
# Pier holds Patience in All Things ("you no longer lose charges at the end of your turn").
#
# END_TURN PRE on the Pier itself, the Raleigh's action_thunder_god_chamber_rounds.tres timing.
extends ActionReactionSelf

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	return not Core.has_patience(unit) and Core.charges(gear) > 0

func activate(context:Context, _activation:EventCore) -> void:
	if not Unit.is_valid(context.unit) or not GearCore.is_valid(context.gear): return
	if Core.has_patience(context.unit): return
	Core.set_charges(context.unit, context.gear, 0)
