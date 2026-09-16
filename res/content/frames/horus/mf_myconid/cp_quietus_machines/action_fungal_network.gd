## FUNGAL NETWORK, the active half of QUIETUS MACHINES: "The Myconid releases a cloud of nanite
## spores around itself. For the rest of the scene all adjacent allies gain immunity to Impaired and
## have +1 armor. Hostile characters within burst 2 of the Myconid are Slowed and Impaired."
##
## THIS SCRIPT IS FIVE LINES BECAUSE THE ZONE IS NOT ITS JOB. Everything the card describes lives in
## the two PassiveAuras that carry it, and everything the PLAYER sees lives in the other two passives
## beside them - the chip aura (SP2.5 Task 4) and the ground cloud (SP2.5 Task 5). All four declare
## `starts_active = false` and are therefore dark from the start of the scene. All this action does is
## wake them and then remove itself. (It was four lines until Task 5; the fifth is the second
## activation flag, explained below.) The Drake's Fortress Protocol is the vanilla shape, line for line
## (content/frames/ipsn/mf_drake/cp_fortress_protocol/action_fortress_protocol.gd:17-19), minus the
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
## measured end to end by the probe (spec/test_spike_status_aura.gd) before any of this was written.
## The probe was deleted at SP2 Task 5 (d6f1ab3); the claim is now pinned against the real Kit by
## test_fungal_network.gd's test_the_myconids_death_strips_everything (section E).
##
## WHY set_aura_active IS NOT FOLLOWED BY AN UPDATE CALL. GearCore.set_aura_active does it itself:
## gear_core.gd:297-299 flips the flag and then calls UnitTile.update_tracking_and_statuses(unit.map,
## event), which is the pass that runs PassiveAura.update_unit for every unit on the map
## (unit_tile.gd:20-24). That is what applies both auras' buffs to everyone ALREADY standing in range
## at the moment of the press - without it the cloud would only catch units that moved afterwards.
## Calling it a second time by hand would be a second whole O(n^2) map pass for no effect.
##
## WHY THE PROTOCOL SETS TWO FLAGS (SP2.5 Task 5). The Kit's fourth passive,
## passive_fungal_network_zone.tres, is a PassiveDynamicZone and draws the cloud on the ground. It is
## NOT gated on is_aura_active: PassiveDynamicZone.should_show_attached_fx returns
## `gear.is_dynamic_zone_active` (passive_dynamic_zone.gd:13-14), a second per-gear flag declared
## three lines above the aura one (gear_core.gd:25 and :28). Wherever the engine moves these flags of
## its own accord it moves BOTH - unit_printer.gd:16-21 at spawn, unit_condition.gd:879-880 and
## :898-899 on a gear reapplication, event_service.gd:67-68 on the owner's death, and
## gear_core.gd:112-113 when a save is restored (mirroring :81-82 on the way out) - and the only
## writers that move one without the other are the two setters themselves,
## GearCore.set_dynamic_zone_active (gear_core.gd:293-295) and GearCore.set_aura_active (:297-300).
##
## THERE IS AN ENGINE-SIDE ROUTE TO THE ZONE SETTER, AND IT HAS NO AURA TWIN. BuffCore carries a
## set_dynamic_zone_active(is_active, map) of its own at buff_core.gd:177-181: it resolves the buff's
## from_gear to a GearCore (buff_core.gd:113-116) and forwards to the GearCore setter above.
## buff_core.gd declares nothing equivalent for auras - the string "aura" does not occur anywhere in
## that file - so a buff reaching through it moves the picture and leaves the mechanic alone. That is
## how four vanilla cards drive a zone: buff_defense_net_aegis.gd, buff_cloaking_field_scout_active.gd,
## buff_swarm_body.gd, and buff_hardlight_defense_system.gd - the one that wants both, and pairs them
## BY HAND at :17 and :19. (Others skip the forwarder and call the GearCore setters directly, the way
## this file does: action_self_destruct.gd:16, and the Drake's Fortress Protocol and its deactivate.)
##
## THAT ROUTE CANNOT FIRE ON THIS KIT AS BUILT, because the forwarder runs only when a buff SCRIPT
## calls it, and only against the gear that APPLIED that buff - and no buff of ours calls it. The only
## calls to either setter anywhere in this mod are the two lines at the bottom of this file. But it is
## precisely the tool someone would reach for to write a "put the cloud out" buff later, and reaching
## for it alone WOULD split the flags. If you add one, set both.
##
## So the two flags agree in play if and only if every caller keeps them agreeing, and today there is
## exactly one caller: this function. Hence two lines rather than one. Delete the
## set_dynamic_zone_active line and the mechanic still works and the cloud is never drawn (mutation
## T5-M4); light the zone without the aura and the board shows a burst that does nothing. Both are
## reddened by section H of test_fungal_network.gd, which asserts the two flags' VALUES against each
## other rather than trusting this comment.
##
## THE ORDER MATTERS, THOUGH NOT BY SAVING ANY WORK. Both orders cost the same two token rebuilds:
## set_dynamic_zone_active calls unit.update_token() unconditionally (gear_core.gd:295) and
## set_aura_active calls it again (:300). What the order actually buys is REGISTRATION WITH THE MAP.
## set_dynamic_zone_active does nothing but the flag and that rebuild; only set_aura_active runs
## UnitTile.update_tracking_and_statuses (:299), which emits map_bus.update_unit_tile_tracking
## (unit_tile.gd:19) and so reaches MapState.update_unit_tile_tracking - a pass that CLEARS
## map.dynamic_zones (map_state.gd:371) and rebuilds it from add_dynamic_terrain_and_zones_from_unit
## (:377), whose `if gear.is_dynamic_zone_active` gate at :435 is what appends this zone (:435-438).
## Zone flag first: the gate is already open and the zone registers on that pass. Aura first: the
## gate is shut, the zone is skipped, and it sits drawn-but-unregistered until the next tracking pass
## from anywhere else. Nothing reads that registration for THIS zone today - every gameplay knob is
## at its inert default, and the one list it does land in is written and never read (see
## passive_fungal_network_zone.tres) - so the reverse order would not be visible in play. It would
## simply be wrong the moment a knob was turned on. Section H's picture-not-a-rule test does not lean
## on this either way: it calls UnitTile.update_tracking_and_statuses itself before asserting.
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
	gear.set_dynamic_zone_active(true, context.unit) # the ground cloud: a SECOND flag, see above
	gear.set_aura_active(true, context.unit, activation) # wakes all three auras; updates tracking itself
	gear.hibernate_action(&'action_fungal_network') # for the rest of the scene: no second press
