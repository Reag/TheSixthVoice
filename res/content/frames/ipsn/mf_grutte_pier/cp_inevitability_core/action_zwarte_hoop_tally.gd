# ZWARTE HOOP's count of "hostile activations that have already happened that round" (design ruling 7).
#
# A TALLY, NOT A SUBTRACTION. There is no turn history (gamemaster_core.gd:29, :48-49); the only per-
# unit record is core.current.activations, decremented at each turn start (event_turn_start.gd:73),
# and a subtraction over map.get_all_units() loses a hostile that acted and then died
# (map_state.gd:222-229). So this hidden reaction counts every hostile turn start as it happens: the
# bus offers every unit's reactions on every event (reaction_bus.gd:50-59), the Pier's included.
#
# is_actor() FILTERS THE MIRRORS - NOT the card's word "character" (the 2026-09-27 ruling does not
# reach here). event_turn_start re-runs NEW_TURN for each deployable its owner
# holds (:17-21, :57-59), and a deployable or drone is not an actor (unit.gd:117): a drone has no turn
# of its own, so its NEW_TURN is its owner's mirrored one, not an activation. An Elite's two
# activations are two turn starts and count two.
#
# THE ROUND STAMP IS THE RESET. Core.add_to_tally reads a tally stamped with an older round as 0, so
# the new_round reaction ruling 7 names is not needed: the first hostile of a round starts from 0.
extends ActionReaction

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var starting:Unit = triggering_event.context.unit
	return Unit.is_valid(starting) and starting.is_actor() and UnitRelation.are_enemies(unit, starting)

func activate(context:Context, _activation:EventCore) -> void:
	if not Unit.is_valid(context.unit) or not GearCore.is_valid(context.gear): return
	Core.add_to_tally(context.unit, context.gear)
