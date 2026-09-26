## STARSICKNESS's NAME, never a button (design 1.4). buff_starsickness does all the work; this action
## exists so the trait has a full SpecificAction to force its Systems save with and to ask its yes/no
## in - the save's log line and every Buff.TO.SAVE read the forcer only through a valid specific
## (unit_hasecheck.gd:141-146, :180-184), and SpecificAction.is_valid demands an action.
##
## NEVER ON THE HOTBAR: is_available_to_activate is false and the .tres sets hide_if_disabled, which
## takes both (gear_bar.gd:146-147, the Leoleth's Combust). NEVER IN A TOOLTIP: it has no effect row
## of its own, so Action.show_in_tooltip returns false (action.gd:341-353).
##
## AN AI-CONTROLLED SIX SKY DECLINES (ruling 11): CommonActionUtil.confirm_use asks this for a
## non-player unit (common_action_util.gd:304-310).
extends Action

func is_available_to_activate(_unit:Unit, _gear:GearCore) -> bool:
	return false

func ai_confirms_use(_context:Context, _target_units:Array[Unit] = []) -> bool:
	return false
