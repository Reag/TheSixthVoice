# DONT GIVE UP THE MECH - "can not be pushed, pulled, knocked back" (ruling 7), on the Drake's
# buff_fortress_knockback shape WITH ONE CLAUSE ADDED: INVOLUNTARY MOVES ONLY.
#
# event_unit_pick_move asks UnitCondition.is_immune_to_knockback_from for EVERY pick move that is not
# a shunt - voluntary ones included - and a plain KNOCKBACK_IMMUNITY buff answers yes to all of them.
# Vanilla's Fortress Protocol lives with that; here it would refuse the Hazard's own "may move"
# effects (Emergency Armature's two spaces at SP2) and any ally's voluntary pick move (Remote
# Reboot's "move up to their speed") for the rest of the scene. The card forbids being MOVED - pushed,
# pulled, knocked back - so the buff answers only for a movement type that is not voluntary.
# is_immune_to_knockback_from puts the movement type in the context's `resource`.
extends Buff

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	if not MovementType.is_valid(context.resource): return true # no movement type: fail closed, stay immune
	return not context.resource.voluntary
