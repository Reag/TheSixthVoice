# THE ZIP TYPE ENGINE'S CHIP (Leoleth rank II, design ruling 16):
#
#   "Whenever you would move from something that is not your standard movement or Boost, you may
#    treat that movement as if it were teleportation. If you do, you gain 1 Heat."
#
# TWO JOBS IN ONE BUFF. (1) A TO.MOVEMENT_TYPE buff (the BuffMovementType archetype, whose
# get_values hands MovementType.create the resource to merge, movement_type.gd:37-41) carrying
# teleport = true and other_tags [reag_zip]. (2) A trigger on entire_movement POST that reads the
# tag back off the resolved move and charges 1 heat.
#
# "NOT YOUR STANDARD MOVEMENT OR BOOST" IS ONE FLAG. MovementType.create puts
# EventUnitMove.FLAG.IS_STANDARD_MOVE in the buff context only when asked for a standard move
# (movement_type.gd:35), and the only callers that ask are the phase controllers - the player's
# (phase_ui_player_action.gd:127) and the AI's (ai_npc.gd:87) - plus Jump (action_jump.gd:51). A
# Boost is not a second pathfinder: it is the SAME standard move with USE_BOOST added at
# target_action_util.gd:473-476. So refusing that flag is exactly the card. A system move
# (action_system_movement.gd:41), a reaction move (action_reaction_movement.gd) and a pathfinder
# variant (variant_action.gd) all call MovementType.create(unit) with no flag and get the chip.
# Involuntary moves never reach get_buffs_to at all (create_for_involuntary, :64-72).
#
# WHY A TOGGLE AND NOT A PROMPT: a buff cannot prompt, and the movement type has to be in force when
# the path is PRICED - engagement (pathfinder.gd:434), difficult terrain (:99), overwatch
# (movement_type.gd:101-102) - long before any step is taken. The engage/disengage pair is vanilla's
# Retractable Profile shape.
#
# THE HEAT IS PER MOVEMENT EVENT. entire_movement fires once per event_unit_move
# (event_unit_move.gd:121), and the event's context.resource is the merged MovementType, so the
# tag says "this was a ZIP teleport" with no state to keep. Self-inflicted, HEAT category, the
# card's number. The mover must be the holder: the bus offers every chip on the map every move
# (reaction_bus.gd:61-67).
#
# activate DOES NOT CALL super - Buff.activate's default body clears the buff (buff.gd:254-255) and
# this chip stays until disengaged (buff_rage_hatred.gd omits it for the same reason).
#
# THE FX (fxe_zip_engaged.tscn) is a ring of short-lived pale-blue sparks locked to the token: the
# engine is charged and the next non-standard move will jump. Scene files cannot hold comments, so
# this is where that rationale lives.
extends BuffMovementType

const ZIP_TAG := &'reag_zip'
const HEAT := 1

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return not context.flags.has(EventUnitMove.FLAG.IS_STANDARD_MOVE)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if not MovementType.is_valid(context.resource): return false
	return context.resource.other_tags.has(ZIP_TAG)

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	CommonActionUtil.queue_damage_events(
		activation, unit, [unit] as Array[Unit], HEAT, Lancer.DAMAGE_TYPE.HEAT,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED]
	)
