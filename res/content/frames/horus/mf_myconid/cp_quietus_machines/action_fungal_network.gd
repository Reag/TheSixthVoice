## FUNGAL NETWORK, the active half of QUIETUS MACHINES: "The Myconid releases a cloud of nanite
## spores around itself. For the rest of the scene all adjacent allies gain immunity to Impaired and
## have +1 armor. Hostile characters within burst 2 of the Myconid are Slowed and Impaired."
##
## THIS SCRIPT IS FOUR LINES BECAUSE THE ZONE IS NOT ITS JOB. Everything the card describes lives in
## the two PassiveAuras on this Kit, which are declared with `starts_active = false` and are
## therefore dark from the start of the scene. All this action does is wake them and then remove
## itself. The Drake's Fortress Protocol is the vanilla shape, line for line
## (content/frames/ipsn/mf_drake/cp_fortress_protocol/action_fortress_protocol.gd:9-18), minus the
## deploy and minus one thing - see below.
##
## WHY THERE IS NO DEACTIVATE, AND THE DRAKE HAS ONE. The Drake wakes an
## action_fortress_protocol_deactivate beside itself, because Fortress is a stance the pilot can
## drop. The card here says "FOR THE REST OF THE SCENE", so there is no off switch to build: the
## protocol hibernates ITSELF and nothing wakes it again. Ruling 6 (2026-09-15) settles this; do not
## add a deactivate later without going back to the card.
##
## The zone therefore ends exactly one way, by the Myconid dying. Aura buffs carry the aura gear as
## `from_gear` (passive_aura.gd:82, via UnitCondition.apply_buffs), and owner death clears them -
## measured end to end in spec/test_spike_status_aura.gd before any of this was written.
##
## WHY set_aura_active IS NOT FOLLOWED BY AN UPDATE CALL. GearCore.set_aura_active does it itself:
## gear_core.gd:297-299 flips the flag and then calls UnitTile.update_tracking_and_statuses(unit.map,
## event), which is the pass that runs PassiveAura.update_unit for every unit on the map
## (unit_tile.gd:20-24). That is what applies both auras' buffs to everyone ALREADY standing in range
## at the moment of the press - without it the cloud would only catch units that moved afterwards.
## Calling it a second time by hand would be a second whole O(n^2) map pass for no effect.
##
## WHY hibernate_action RATHER THAN A USAGE COUNTER. `gear.is_action_hibernating` is consulted by
## UnitAction.get_gear_unavailable_reason at unit_action.gd:154 and yields REASON.HIBERNATING - a
## real, named refusal the UI can explain, ahead of the generic REASON.SPECIFIC. It is cleared only
## by GearCore.reset() (gear_core.gd:139-142), which is scene setup and not a turn or round
## boundary, so "the rest of the scene" is precisely what it buys.
##
## AND IT IS BELT-AND-BRACES, MEASURED. get_gear_unavailable_reason is an elif chain, and
## `consumes_core_power() and not unit.core.has_core_power` sits at unit_action.gd:145 - NINE
## branches ABOVE the hibernation test. Since this action sets consumes_cp, the press spends the
## frame's core power and the reason reported for a second press is NO_CORE_POWER; REASON.HIBERNATING
## is unreachable while that holds. So the core power alone already refuses the second press.
##
## The line stays for three reasons: it is what the card literally says ("for the rest of the
## scene"), it survives any future effect that refreshes core power mid-mission, and it takes the
## button OFF the gear bar rather than merely greying it out.
## test_a_second_press_in_the_same_scene_is_refused asserts the flag directly as well as the refusal,
## so deleting this line still reddens something.
##
## THE usage_group ON THE .tres IS NOT DECORATION. A protocol and a pressable on one Kit need a
## group EACH (unit_action.gd:167-168, the Subutai SP2 lesson). This Kit has only the protocol today
## and gains no second button later - the Pike is its own Kit, per ruling 9 and the integrated-weapon
## lesson of 8604d00 - but the group costs nothing and removes the trap if that ever changes.
extends ActionSystem


func activate(context:Context, activation:EventCore) -> void:
	spend_actions(activation)

	var gear:GearCore = context.gear
	gear.set_aura_active(true, context.unit, activation) # wakes BOTH passives; updates tracking itself
	gear.hibernate_action(&'action_fungal_network') # for the rest of the scene: no second press
