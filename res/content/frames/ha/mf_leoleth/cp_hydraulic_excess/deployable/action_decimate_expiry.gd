# The Decimate crater's own lifetime (ruling 8): it dies at the start of the Leoleth's next turn.
#
# A POINT-FREE ActionReactionSelf on new_turn at PRE, living on the MARKER rather than on the
# Leoleth. mt_die_on_owner_death (content/gear/shared/die_on_owner_death/) is the shape one trigger
# over.
#
# WHY IT IS A REACTION ON THE CRATER RATHER THAN A LIFETIME ON A BUFF. Deployables get a VIRTUAL
# NEW_TURN core alongside their owner: PRE at event_turn_start.gd:19-21 and POST at :57-59. The
# owner's own NEW_TURN POST - the RAGE roll that may lay a NEW crater - is queued at :56. So the old
# crater's PRE always runs before the new roll, and rolling a 1 twice in a row replaces the field
# rather than stacking two of them, with no special case anywhere.
#
# ActionReactionSelf's own triggers_on_event is the whole gate: it refuses any triggering event whose
# context.unit is not this unit (action_reaction_self.gd:11-15), and the virtual core carries the
# marker as its unit. So this fires on the crater's own turn start and on nobody else's.
extends ActionReactionSelf

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func activate(context:Context, activation:EventCore) -> void:
	activation.queue_event(&'event_unit_die', { unit = context.unit })
