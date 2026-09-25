## RPA PULLBACK, the collision half: "If this movement would cause a character to hit another mech
## or an obstruction, then they must succeed a Hull save or be knocked Prone." Design ruling 13.
##
## The Shackleton's action_unfathomable_weight_collide.gd line for line, with three differences the
## card dictates. The MOVE IS KEYED BY VARIANT, not by action id: the pull is queued by whatever
## weapon fired, so the SpecificAction on the move is that weapon's composed action, and what marks
## it as Pullback's is &'rpa_pullback' in modified_by_variants. ANY CHARACTER saves - "a character",
## not "a hostile": a pulled ally saves too (the Gloire's own line can catch one). And NO CONFIRM:
## the card has no "may", so the save is forced without asking - AI-automatic, a player never asked.
##
## WHAT COUNTS AS AN OBSTRUCTION IS WHAT THE ENGINE CALLS A COLLISION (Shackleton ruling 10): an
## obstruction tile, a step uphill, or an obstructing unit (event_unit_move.gd is_next_step_blocked
## is the only place event_unit_collide is fired from). THE MAP EDGE IS NOT ONE. And THE GLOIRE'S
## OWN TILES ARE NOT ONE EITHER: arriving is not "hitting another mech", so a collision whose tile
## is under the Gloire is a non-event here - whatever the pull helper does about the last step, the
## pulled unit never saves for reaching its destination.
##
## THE PRONE'S SOURCE IS THIS KIT (action.gd:378-379 uses the activation's gear), so Hydraulic
## Punisher's get_origin_unit_for_source resolves the Gloire as the knocker and, once a round, adds
## the Impaired - the frame's loop.
##
## HIDDEN FROM THE CARD. localization_key_override (in the .tres) points this reaction's rows at RPA
## Pullback's own, so the log says "RPA Pullback"; the override is also what makes
## Action.show_in_tooltip answer false (action.gd:348).
##
## THE MOVE MUST BE THE PULL, not merely Pullback's (close review, 2026-09-25): the weapon's own
## Knockback carries the same composed action, and "this movement" is the pull alone. The pull's
## MovementType carries onhit_rpa_pullback.gd's PULL_TAG; a push into a wall never does.
##
## NOT A REACTION POINT and not 1/round: every collision a Pullback line causes is answered
## (ActionReaction.get_per_round_hard_limit is 99 when consumes_rxn is false).
extends ActionReaction

const VARIANT_KEY := &'rpa_pullback'
const PULL_TAG := &'reag_rpa_pullback_pull' # onhit_rpa_pullback.gd's

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.event]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var collision_context:Context = triggering_event.context
	var mover:Unit = collision_context.unit
	if not Unit.is_valid(mover) or mover == unit: return false
	if not mover.is_character(): return false # "a character" - any faction
	var movement_context:Context = collision_context.event.context
	var source = movement_context.object # the SpecificAction that forced the move
	if not SpecificAction.is_valid(source): return false
	if source.unit != unit: return false
	if not Action.is_valid(source.action) or not source.action.modified_by_variants.has(VARIANT_KEY): return false
	var movement_type = movement_context.resource
	if not (movement_type is MovementType) or not movement_type.other_tags.has(PULL_TAG): return false # "this movement": the pull, not the weapon's own push
	# arriving is not hitting: a collision with one of the Gloire's own tiles is a non-event
	if collision_context.target_tiles.any(func(tile:Vector2i) -> bool: return unit.occupied_tiles().has(tile)): return false
	return true

func activate(context:Context, activation:EventCore) -> void:
	var specific := SpecificAction.from_context(context)
	var mover:Unit = context.event.context.unit
	if not Unit.is_valid(mover): return
	if activation.abort_without_units([specific.unit, mover]): return

	var passed := await UnitHasecheck.make_hull_save(activation, mover, specific,
		[EventService.SAVE_FLAG.KNOCKBACK, Lancer.STATUS.PRONE])
	if activation.abort_without_unit(mover): return
	if not passed:
		apply_status(activation, mover, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL)
