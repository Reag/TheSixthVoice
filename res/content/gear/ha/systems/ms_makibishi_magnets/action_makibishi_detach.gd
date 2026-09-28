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
##
## THE OWNER COMES FROM THE MAGNET'S STORED ID (Pass F 7b), not from the archetype's
## get_applier_specific, whose core.get_owner_unit() goes through vanilla's source lookup - which can
## answer "the victim" (map_state.gd:290-293; buff_makibishi_attached.gd's header has the whole
## story) and turn the save into the DC 10 fallback while the Koremasa is alive. The magnet's own
## owner_of reads the stored id; the cache entry is seeded as well, for the engine's reads that follow.
## A magnet without the helper (none today) falls back to the archetype.
extends ActionSystemClearBuff

func can_be_used_situationally_by(unit:Unit, situational_unit:Unit, situational_gear:GearCore) -> bool:
	if unit != situational_unit: return false
	return super(unit, situational_unit, situational_gear)

func get_applier_specific(core:BuffCore) -> SpecificAction:
	if not core.base.has_method(&'owner_of'): return super(core)
	var map:MapState = X.map()
	core.base.seed_owner_cache(core, map)
	var owner:Unit = core.base.owner_of(core, map)
	if not Unit.is_valid(owner): return null
	var gear:GearCore = owner.core.loadout.get_by_persistent_id(core.from_gear)
	if not GearCore.is_valid(gear): return null
	return SpecificAction.create(owner, gear, gear.get_solo_action()) # the archetype's own choice of action (:99)
