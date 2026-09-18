## GRAV-AMPED INTERFERENCE, the active half of EARTH SHAKER GRAV-GEN: "For the rest of the scene, you
## gain the following benefits: The Vauban generates a Burst 1 field of difficult terrain. Saves you
## force are made with +1 Difficulty. When a hostile character fails a save you forced, they take 3
## AP Kinetic damage. Each character can be affected by this ability only once per round."
##
## THAT SECOND SENTENCE IS THE ONE PLACE THE CARD DIVERGES FROM THE LCP, DELIBERATELY. Bel's sheet
## spells it "+1 Difficultly"; the author escalated the typo under the LCP-verbatim directive at the
## 2026-09-18 frame close and it ships corrected (ruling R1, and localizations.csv carries
## "+1 Difficulty"). Quoted here as SHIPPED, so nobody diffs the row against the sheet and "fixes" it
## back.
##
## FOUR LINES, BECAUSE NONE OF THE THREE CLAUSES IS THIS SCRIPT'S JOB. The field is
## passive_grav_amped_field.tres, the save difficulty is passive_grav_amped_aura.tres carrying
## buff_grav_amped_saves.tres, and the 3 AP is action_grav_amped_shock.tres. All three are dark until
## this runs; all this does is light them. The Myconid's action_fungal_network.gd is the same shape,
## and the Drake's Fortress Protocol is the vanilla one.
##
## THE TWO FLAGS ARE NOT THE MYCONID'S TWO FLAGS. That frame sets is_dynamic_zone_active and
## is_aura_active, both per-gear booleans on GearCore. This frame sets a GEAR STATE KEY and
## is_aura_active, and the difference is the whole reason PassiveGatedTerrainZone exists:
## MapState.add_dynamic_terrain_and_zones_from_unit collects every PassiveTerrainZone on every gear
## UNCONDITIONALLY (map_state.gd:427-433). There is no is_terrain_zone_active. A terrain zone sitting
## on an equipped Kit is ON, and overriding its voxel list from gear state is the only way to keep it
## dark until a button is pressed.
##
## SO THE ORDER IS LOAD-BEARING, AND IT IS NOT THE MYCONID'S ORDER EITHER. set_aura_active does the
## work of both halves: it flips the aura flag and then calls UnitTile.update_tracking_and_statuses
## (gear_core.gd:297-300), which is the pass that applies aura buffs to everyone already in range AND
## rebuilds MapState.dynamic_terrain from every terrain zone on the map (map_state.gd:371-378), then
## recalculates the merged surface (the calculate_surface_merged_terrain_and_height_at call at :413,
## inside the :409-414 loop). Set the state key FIRST and that one pass raises the field too. Set it
## second and the field stays dark until some unrelated tracking pass happens to run - in play, the
## next time anybody moves; in a spec, never.
##
## MUTATION T1-M1, MEASURED 2026-09-18: swapping the two lines takes
## test_grav_amped_interference.gd from 12/12 to 6/12. The five it reddens beyond
## test_the_press_raises_a_burst_1_field_of_difficult_terrain are every other test that reads the
## ground straight after the press. The one that stays GREEN is the tell, and it is the mechanism
## stated exactly: test_the_field_survives_a_later_tracking_pass calls track() itself afterwards, so
## the field comes up on THAT pass instead. Wrong order = a field that arrives whenever somebody else
## happens to move.
##
## THE KEY IS A STRING, NOT A StringName. GearCore.set_state and get_state both take key:String
## (gear_core.gd:256-261), and PassiveGatedTerrainZone accordingly reads
## gear.get_state(String(state_key), false). A StringName written here would never match the key the
## zone looks up. FIELD_STATE_KEY is declared as a String for that reason and
## passive_grav_amped_field.tres's state_key must spell it identically.
##
## WHY THERE IS NO DEACTIVATE. The card says FOR THE REST OF THE SCENE, so there is no off switch to
## build (the Drake has one because Fortress is a stance the pilot can drop). The field and the aura
## end exactly two ways: the Vauban dying - unit-projected terrain is rebuilt only from units still on
## the map (map_state.gd:374-377 into add_dynamic_terrain_and_zones_from_unit), and aura buffs carry
## the aura gear as from_gear (PassiveAura.apply_aura_buffs_to_unit passes aura_gear to
## UnitCondition.apply_buffs, passive_aura.gd:82) so they go with it when
## EventService.remove_unit_from_game clears every outgoing buff from the dying unit
## (event_service.gd:71) - and the scene ending, because GearCore.short_repair throws gear state away
## (gear_core.gd:143-150).
## Design §2.2 settles this; do not add a deactivate later without going back to the card.
##
## hibernate_action IS BELT-AND-BRACES AND STAYS ANYWAY. UnitAction.get_gear_unavailable_reason is an
## elif chain and `consumes_core_power() and not unit.core.has_core_power` sits nine branches above
## the hibernation test (unit_action.gd:145), so the spent core power already refuses a second press
## and REASON.HIBERNATING is unreachable while that holds. The line stays for the three reasons the
## Myconid's does: it is what the card literally says, it survives any future effect that refreshes
## core power mid-mission, and it takes the button OFF the gear bar rather than greying it out.
##
## THE usage_group ON THE .tres IS NOT DECORATION: a protocol and a pressable on one Kit need a group
## EACH (unit_action.gd:167-168, the Subutai SP2 lesson). This Kit has two pressables from Task 4 on,
## so the two groups are load-bearing rather than precautionary.
extends ActionSystem

## The gear-state key passive_grav_amped_field.tres gates on. A String, not a StringName - see above.
const FIELD_STATE_KEY := 'grav_amped'

func activate(context:Context, activation:EventCore) -> void:
	spend_actions(activation)

	var gear:GearCore = context.gear
	gear.set_state(FIELD_STATE_KEY, true) # FIRST: the field, so the pass below raises it
	gear.set_aura_active(true, context.unit, activation) # wakes the save aura AND runs the tracking pass
	gear.hibernate_action(&'action_grav_amped_interference') # for the rest of the scene: no second press
