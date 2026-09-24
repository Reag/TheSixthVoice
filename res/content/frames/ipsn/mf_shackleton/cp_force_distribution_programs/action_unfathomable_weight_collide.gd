## UNFATHOMABLE WEIGHT, the collision half: "If this would knock them into a wall, mech, or other
## obstruction that would stop them from moving, you may force the target to succeed on a Hull save or
## be knocked Prone." Design rulings 9-10.
##
## Ferrous Lash's collide reaction line for line (action_ferrous_lash_collide.gd), narrowed from "our
## gear" to "our Unfathomable Weight ACTION", because this Kit carries Calamitous Impact too and that
## card's Prone comes from its own save, not from a collision (ruling 12). Kinetic Mass Transfer is
## the Hull-save half of the shape.
##
## WHAT COUNTS AS AN OBSTRUCTION IS WHAT THE ENGINE CALLS A COLLISION (ruling 10): an obstruction tile,
## a step uphill, or an obstructing unit (event_unit_move.gd is_next_step_blocked is the only place
## event_unit_collide is fired from). THE MAP EDGE IS NOT ONE: is_next_step_possible fails first and
## the walk ends silently, so a push that runs out of board gets no save. A recorded divergence.
##
## "YOU MAY": a yes/no to the Shackleton's controller through CommonActionUtil.confirm_use (an AI
## always says yes, Action.ai_confirms_use). Declining forces no save.
##
## HIDDEN FROM THE CARD. localization_key_override (in the .tres) points this reaction's name at
## Unfathomable Weight's own rows, so the prompt says "Unfathomable Weight"; the override is also what
## makes Action.show_in_tooltip answer false (action.gd:348), so the Kit card shows the one action.
##
## NOT A REACTION POINT and not 1/round: every collision the push causes may be answered
## (ActionReaction.get_per_round_hard_limit is 99 when consumes_rxn is false).
extends ActionReaction

const PUSH_ACTION_ID := &'action_unfathomable_weight'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.event]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var collision_context:Context = triggering_event.context
	if not Unit.is_valid(collision_context.unit): return false
	if not UnitRelation.are_enemies(unit, collision_context.unit): return false # "hostile characters"
	var movement_context:Context = collision_context.event.context
	var source = movement_context.object # the SpecificAction that forced the move
	if not SpecificAction.is_valid(source): return false
	if source.unit != unit or source.gear != gear: return false
	return source.action.get_id() == PUSH_ACTION_ID

func activate(context:Context, activation:EventCore) -> void:
	var specific := SpecificAction.from_context(context)
	var mover:Unit = context.event.context.unit
	if not Unit.is_valid(mover): return

	var confirmed:bool = await CommonActionUtil.confirm_use(context, [mover])
	if not confirmed: return
	if activation.abort_without_units([specific.unit, mover]): return

	var passed := await UnitHasecheck.make_hull_save(activation, mover, specific,
		[EventService.SAVE_FLAG.KNOCKBACK, Lancer.STATUS.PRONE])
	if activation.abort_without_unit(mover): return
	if not passed:
		apply_status(activation, mover, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL)
