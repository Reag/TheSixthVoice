## MAKIBISHI MAGNETS, THE DETACH (design 3.1, rulings 22, 25):
##
##   "Characters can detach makibishi magnets from themselves by passing an Agility save as a quick
##    action on their turn."
##
## Vanilla's ActionSystemClearBuff - the Hornet's Remove Javelins, carried to the victim as the
## attached buff's situational gear - narrowed by ONE line: FROM THEMSELVES. UnitAction scans every
## unit's buffs for situational gear (unit_action.gd:33-36) and asks each one whether the ASKING unit
## may use it, so without this a victim would also be offered the detach that rides on every OTHER
## victim's magnets - one button per magnet on the board. Only the gear on the victim's own magnets
## answers now: one detach, however many magnets are out (ruling 22).
##
## The save is the archetype's: against the magnets' owner (the Koremasa) through the Kit's solo
## action, or a DC 10 check when the Koremasa is gone (action_system_clear_buff.gd:78-82).
extends ActionSystemClearBuff

func can_be_used_situationally_by(unit:Unit, situational_unit:Unit, situational_gear:GearCore) -> bool:
	if unit != situational_unit: return false
	return super(unit, situational_unit, situational_gear)
