## Refills the Swivel Gun's three-round counter when the pilot reloads it.
##
## WITHOUT THIS, THE GUN IS A ONE-SCENE WEAPON. event_gear_reload.gd's execute() only flips
## GearCore.is_loaded back to true (:24-31) - it has no idea a PassiveDieCounter exists at all, so
## nothing else in the engine would ever put a round back in the magazine, and once emptied every
## profile on this Kit stays refused for the rest of the mission. See action_swivel_single_shot.gd
## and action_swivel_grapeshot.gd for the counter itself and why the engine's own LOADING tag could
## not be used to track it.
##
## THE ORDERING THAT MAKES THIS WORK, AND WHY IT HAS TO BE A REACTION RATHER THAN SOMETHING ON THE
## RELOAD EVENT ITSELF. event_gear_reload.gd sets is_loaded = true on every weapon it reloads
## BEFORE queueing RELOAD POST reactions (execute(), :24-33) - and reaction_bus.gd's
## does_reaction_trigger runs the FULL availability check (UnitAction.can_activate_gear) before ever
## asking triggers_on_event, so an unloaded gear would fail that check outright. By POST the gun
## already reads loaded, which is what lets this reaction fire at all. Precedent, near-exact:
## content/frames/ipsn/mf_raleigh/cp_m35_mjolnir_cannon/action_thunder_god_chamber_rounds.gd.
##
## consumes_rxn = false and counts_as_free_action = false ARE BOTH LOAD-BEARING DEFAULTS, not
## incidental. ActionReaction.can_be_used_while_unloaded() (action_reaction.gd:65) returns
## `not (requires_reaction_available() or counts_as_free_action)`, and requires_reaction_available()
## is just consumes_reaction() (action.gd:170) - so with both false this reaction is allowed to fire
## on gear the engine still considers unloaded going into the check, which matters here because
## is_loaded is exactly the flag this reaction's own trigger races to see flipped.
## get_per_round_hard_limit (action_reaction.gd:69) is 99 for the same reason: a "real" rxn defaults
## to 1/round, and refilling the gun on every reload must never be capped there.
##
## HIDDEN BOOKKEEPING, LIKE action_blasting_powder_spend.gd - not a rule the player reads, and
## nothing they choose to do. Reactions never reach the gear bar at all (gear_bar.gd:143 drops every
## ActionReaction); show_in_tooltip below keeps it out of the Kit tooltip too. activate() below does
## the state change directly, the same shape as action_blasting_powder_spend.gd, rather than through
## spend_actions() - which would try to log a usage line and gain self-heat for an action that has
## no player-facing name or effect text at all.
extends ActionReactionSelf

func show_in_tooltip(kit:Kit) -> bool: return false

## THE ONE THING THIS FILE HAS TO GET RIGHT: confirming THIS GEAR is among the weapons actually
## being reloaded, not merely that a reload happened to the unit at all. Without this check the
## reaction would refill the Swivel Gun whenever the pilot reloads ANY of their weapons -
## test_reloading_a_different_weapon_does_not_refill_the_swivel_gun (test_swivel_gun.gd) is what
## catches that.
##
## THIS DELIBERATELY DOES NOT CALL EventGearReload.get_weapons_to_reload(triggering_event.context)
## AGAIN. That helper is what event_gear_reload.gd's execute() itself uses to decide who to reload,
## and it FILTERS OUT anything that is already loaded (event_gear_reload.gd:39-41) - which is exactly
## every weapon the reload just touched, since execute() sets is_loaded = true before queueing this
## very reaction. Calling it again here, at POST, would therefore always return an empty list - not
## "the weapons that were just reloaded" but "the weapons still waiting for one" - and this reaction
## would never fire for ANYONE, ourselves included. The check below reads context.array and
## context.gear directly (the same two props get_weapons_to_reload reads) without that is_loaded
## filter, which is the one difference that makes it answer the right question.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var reload_context:Context = triggering_event.context
	if GearCore.is_valid(reload_context.gear) and reload_context.gear == gear: return true
	return reload_context.array != null and reload_context.array.has(gear)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	var counter:PassiveDieCounter = gear.get_die_counter_passive()
	if counter == null: return
	counter.reset(unit, gear)
