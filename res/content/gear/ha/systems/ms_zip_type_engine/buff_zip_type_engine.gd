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
#
# "INVOLUNTARY MOVES NEVER REACH get_buffs_to AT ALL" WAS STATED HERE AND WAS INCOMPLETE - CORRECTED
# 2026-09-22. That is true only of create_for_involuntary (movement_type.gd:63-71), which builds a
# bare MovementType and never calls get_buffs_to at all - a knockback goes this way (e.g.
# action_impale_cataphract.gd:7) and really is safe. But a FORCED move is not always routed through
# create_for_involuntary: MovementType.create(unit, false) is a SEPARATE path that passes
# is_voluntary=false yet DOES call get_buffs_to (movement_type.gd:34-41) and so DOES merge this
# chip's teleport/other_tags in. Three vanilla callers build a forced move exactly this way -
# content/gear/horus/systems/ms_h0r_os_system_upgrade_i/action_puppet_system.gd:8 (a HORUS puppet,
# commented "counts as involuntary!!" but taking the merging path regardless),
# content/events/event_unit_teleport.gd:26, and
# content/frames/deployables/bod_human/mt_mount_up/action_mount_up.gd:56 - so a hostile puppeting a
# ZIP-engaged Leoleth merges the chip, gets tagged a teleport, and WOULD charge 1 Heat for a move the
# Leoleth never chose. FIX: triggers_on_event below now gates on movement_type.voluntary, matching
# the vanilla precedent at
# content/frames/npc/npcc_barricade/drag_down/buff_drag_down_barricade.gd:19 (also a
# triggers_on_event, also checking triggering_context.resource.voluntary). Job (1) above - the
# passive merge itself - is untouched: a forced move through this path still becomes a teleport for
# pathfinding/engagement purposes, which is correct (see puppet_system's own comment); only the HEAT
# CHARGE is gated to a move the holder actually chose.
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
	var movement_type:MovementType = context.resource
	# "Whenever YOU WOULD move" - a move the holder chose. Without this an involuntary move built
	# via MovementType.create(unit, false) (not create_for_involuntary) still carries the tag once
	# merged, and would otherwise charge Heat for a puppeted/forced move - see the file header.
	if not movement_type.voluntary: return false
	return movement_type.other_tags.has(ZIP_TAG)

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	CommonActionUtil.queue_damage_events(
		activation, unit, [unit] as Array[Unit], HEAT, Lancer.DAMAGE_TYPE.HEAT,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED]
	)
