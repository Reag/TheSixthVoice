# DONT GIVE UP THE MECH (Hazard, cp_int_type_command_systems - the core active), rulings 6-7:
#
#   "All allied characters within SENSORS may move up to their speed as a reaction. For the rest of
#    the scene, you and all adjacent allied characters can not be pushed, pulled, knocked back, or
#    knocked Prone."
#
# QUICK, consumes the core power (the .tres).
#
# STEP 1, THE MOVES. Every allied CHARACTER (is_character() - a drone included, ruling 2026-09-27;
# "you" is named separately in the second
# sentence, so not the Hazard) within the Hazard's live Sensors (distance_between, no LOS - the card
# names Sensors only), in map order, that CAN TAKE A REACTION (UnitAction.can_take_reactions: the
# point, not Jammed, not grappled - "as a reaction") is offered event_unit_pick_move with its own
# speed as the budget and a plain VOLUNTARY movement type (MovementType.create(ally, true)): engagement
# and reactions apply as for any walk - the card says nothing, unlike Emergency Armature's move. The
# Remote Reboot shape (action_remote_reboot_support.gd), awaited one ally at a time. The reticle's
# cancel is "no move" and spends nothing; a TAKEN move spends that ally's reaction point (author: RAW).
# An ally with no reaction is skipped silently. THE HAZARD DOES NOT MOVE.
#
# STEP 2, THE IMMUNITY, after the moves: the MANUAL buff_dgutm_active on the Hazard ("for the rest of
# the scene" - short repair clears buffs, which is the scene end). It switches on
# passive_dgutm_immunity, a range-1 aura on this same Kit (author: an AURA while adjacent, not a
# snapshot) - see that script.
extends ActionSystem

@export var active_buff:Buff

## Allied characters within Sensors that could take the move, in map order.
static func movers(hazard:Unit) -> Array[Unit]:
	var allies:Array[Unit] = []
	if not Unit.is_valid(hazard) or hazard.map == null: return allies
	for other:Unit in hazard.map.get_all_characters():
		if other == hazard or not Unit.is_valid(other): continue
		if not other.is_character(): continue
		if not UnitRelation.are_allies(hazard, other): continue
		if not UnitRelation.can_affect(hazard, other): continue
		if UnitRelation.distance_between(hazard, other) > hazard.get_sensor_range(): continue
		if not UnitAction.can_take_reactions(other, Context.create({unit = other})): continue
		allies.append(other)
	return allies

func activate(context:Context, activation:EventCore) -> void:
	var hazard:Unit = context.unit
	if not Unit.is_valid(hazard): return
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	spend_actions(activation)

	# STEP 1 - one ally at a time; each re-checked live, since an earlier move can change the board.
	for ally:Unit in movers(hazard):
		if not Unit.is_valid(hazard): return
		if not movers(hazard).has(ally): continue
		var from_tile:Vector2i = ally.tile()
		await activation.execute_event(&'event_unit_pick_move', {
			target_unit = ally,
			resource = MovementType.create(ally, true),
			number = ally.core.get_speed_max(),
			unit = hazard,
			gear = context.gear,
			action = context.action,
		})
		if Unit.is_valid(ally) and ally.tile() != from_tile:
			UnitAction.spend_reaction(ally)

	# STEP 2 - the immunity switch.
	if activation.abort_without_unit(hazard): return
	apply_buff(activation, hazard, active_buff)
