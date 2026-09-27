## WHO TELEPORTED THIS UNIT? The Six Sky's one reading of "when the Six Sky teleports X" (design 1.2,
## ruling 5 as amended at the close), shared by both traits. Not a shared helper: no second consumer is
## planned.
##
## A COMPLETED teleport only. Both traits read at ENTIRE_MOVEMENT POST, and a vetoed move never gets
## there - event_unit_move.gd:72 returns on set_aborted() before POST at :121. So a teleport an
## Uncertainty Field or a Flash Anchor refused does not count, with no clause here to say so.
##
## THE AGENT, in order, always resolved OWNER-OR-SELF so the Six Sky's own deployables credit it:
##   1. THE DEVICE. The move's SpecificAction names gear the named unit does not hold: the Sunzi's
##      Realspace Breach and Blinkspace Tunnel build theirs from the DEVICE's reaction and then overwrite
##      `unit` with the mover (action_teleport.gd:33-36, action_use_blinkspace_tunnel.gd:31-34). The
##      unit on the map holding that gear is the agent. Close review, the author's call: this reverses
##      ruling 6 - an ally using the Six Sky's tunnel now credits the Six Sky.
##   2. The forcer, Teleport.forcer(context): the Sunzi Blink Mine's detonation, the warp grenade, rifle
##      and Final Secret, and our helper's move / move_along / shove.
##   3. No forcer and the move is VOLUNTARY: the mover - the vanilla Blinkspace shape, which passes no
##      object at all (action_blinkspace_jump.gd:64).
##   4. No forcer and INVOLUNTARY: the unit of the nearest enclosing gear activation. Vanilla Beckoner
##      (action_beckon.gd:18-35) and the Celestial Shackles return swap with no object; their moves are
##      queued under the activation that did it. With no enclosing activation, nobody.
##
## NOT a teleport, so never seen here: the Sunzi's Accelerate is a straight-line involuntary move with no
## `teleport` flag (action_accelerate.gd:37-40). The design listed it; the close corrected that.
extends RefCounted

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

## The unit that caused this move, or null. Meaningful only for a teleport; callers check that first.
## `move` is the move's own EventCore, whose block is walked for rule 4.
static func agent_of(move:EventCore) -> Unit:
	if move == null or move.context == null: return null
	var context:Context = move.context
	var forcer:Unit = Teleport.forcer(context)
	if Unit.is_valid(forcer):
		var holder := device_holder(context.object, forcer)
		if Unit.is_valid(holder): return holder.get_owner_unit_or_self()
		return forcer.get_owner_unit_or_self()
	if not MovementType.is_valid(context.resource): return null
	if context.resource.voluntary: return context.unit if Unit.is_valid(context.unit) else null
	var activator := enclosing_activator(move)
	return activator.get_owner_unit_or_self() if Unit.is_valid(activator) else null

## Rule 1: the unit holding `specific.gear`, when that is not `named` (who the SpecificAction names).
static func device_holder(specific:SpecificAction, named:Unit) -> Unit:
	if not GearCore.is_valid(specific.gear) or specific.gear.kit == null: return null
	var compcon_id:StringName = specific.gear.kit.compcon_id
	if named.get_gear(compcon_id) == specific.gear: return null
	for unit:Unit in named.map.get_all_units():
		if unit.get_gear(compcon_id) == specific.gear: return unit
	return null

## Rule 4: the unit of the nearest event_gear_activate at or above `move` in the block tree - the walk
## buff_heavenly_weaver_watch.enclosing_declared_attack makes for a declared attack.
static func enclosing_activator(move:EventCore) -> Unit:
	var node = move.block
	while node is EventBlock:
		for core:EventCore in node.event_cores:
			if core.base.event_type == &'event_gear_activate' and Unit.is_valid(core.context.unit):
				return core.context.unit
		node = node.get_parent()
	return null

## Is `move` a teleport that `six_sky` caused?
##
## NOT A TUNNEL (close-out Pass F Task 4, 2026-09-27): the talents mod's Prospector hands the move event
## a MovementType subclass that answers is_teleport() true but is digging through solid rock, not
## teleporting - neither "the Six Sky teleports itself, or another character" (Heavenly Weaver) nor "the
## Six Sky teleports a hostile character" (Starsickness) means a tunnel, so both traits exclude it here,
## the one place both read.
static func is_teleport_by(six_sky:Unit, move:EventCore) -> bool:
	if not Unit.is_valid(six_sky): return false
	if move == null or not Teleport.is_teleport(move.context) or Teleport.is_tunnel(move.context):
		return false
	return agent_of(move) == six_sky
