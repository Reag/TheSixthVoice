# The greenwash swarm's own lifetime: "Until the start of your next turn" (Naga SP3 Task 2, ruling 15).
#
# Decimate's expiry verbatim (res/content/frames/ha/mf_leoleth/cp_hydraulic_excess/deployable/
# action_decimate_expiry.gd, whose header has the whole argument): a point-free ActionReactionSelf on
# new_turn at PRE, living on the MARKER. Deployables get a VIRTUAL new_turn core beside their owner's
# (event_turn_start.gd:19-21), and ActionReactionSelf's own filter refuses any turn start that is not
# this unit's, so the swarm dies at the Naga's next turn start and on nobody else's. Kept as the
# swarm's own file rather than pointing at the Leoleth's, so neither frame's folder owns the other's.
extends ActionReactionSelf

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func activate(context:Context, activation:EventCore) -> void:
	activation.queue_event(&'event_unit_die', { unit = context.unit })
