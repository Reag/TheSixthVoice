# ZWARTE HOOP's gain (design ruling 8): "At the start of your turn, this system gains charges equal to
# the number of hostile activations that have already happened that round, to a maximum of 5."
#
# POST, ON THE PIER'S OWN NEW_TURN (ActionReactionSelf). Only the GAIN is capped (ruling 11): under
# Patience the bank carries over and this adds on top of it; without Patience the bank is REPLACED,
# which also zeroes a leftover a turn that ended through death never lapsed (event_turn_end.gd:33-35).
#
# NEVER KICKSTARTED. Patience's +3 is its own action (action_patience_charge) precisely so the protocol
# can kickstart that alone - kickstarting this would add min(5, tally) a second time (ruling 15).
extends ActionReactionSelf

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

func show_in_tooltip(_kit:Kit) -> bool: return false

func activate(context:Context, _activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	var gained := mini(Core.GAIN_CAP, Core.tally(unit, gear))
	var bank := Core.charges(gear) if Core.has_patience(unit) else 0
	Core.set_charges(unit, gear, bank + gained)
