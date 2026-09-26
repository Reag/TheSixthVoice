## WHO TELEPORTED THIS UNIT? The Six Sky's one reading of "when the Six Sky teleports X" (design 1.2,
## ruling 5), shared by both traits. Not a shared helper: no second consumer is planned.
##
## A COMPLETED teleport only. Both traits read at ENTIRE_MOVEMENT POST, and a vetoed move never gets
## there - event_unit_move.gd:72 returns on set_aborted() before POST at :121. So a teleport an
## Uncertainty Field or a Flash Anchor refused does not count, with no clause here to say so.
##
## THE AGENT, in order:
##   1. Teleport.forcer(context) - the unit on the move's SpecificAction - resolved OWNER-OR-SELF, so a
##      Six Sky's own deployable (a Sunzi Blink Mine, a Realspace Breach, the Accelerate grenade) credits
##      the Six Sky. Every teleport the Sunzi mod adds carries a SpecificAction, and so do our helper's
##      move / move_along / shove.
##   2. No forcer and the move is VOLUNTARY: the mover. That is a vanilla-shaped self-teleport, which
##      passes no object at all (Blinkspace Jump, action_blinkspace_jump.gd:64).
##   3. Otherwise nobody: an involuntary teleport with no readable forcer (a scripted placement).
##
## RECORDED GAP (ruling 6): an ally using the Six Sky's own Blinkspace Tunnel is its OWN forcer - the
## tunnel's action sets SpecificAction.unit to the mover - so it does not credit the Six Sky.
extends RefCounted

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

## The unit that caused this move, or null. Meaningful only for a teleport; callers check that first.
static func agent_of(context:Context) -> Unit:
	if context == null: return null
	var forcer:Unit = Teleport.forcer(context)
	if Unit.is_valid(forcer): return forcer.get_owner_unit_or_self()
	if MovementType.is_valid(context.resource) and context.resource.voluntary and Unit.is_valid(context.unit):
		return context.unit
	return null

## Is this move a teleport that `six_sky` caused?
static func is_teleport_by(six_sky:Unit, context:Context) -> bool:
	if not Unit.is_valid(six_sky): return false
	if not Teleport.is_teleport(context): return false
	return agent_of(context) == six_sky
