## THE GREENWASH SWARM'S SURGE (Naga SP3 Task 2, design rulings 16-17 and SP3 rulings 22-23).
##
## "Until the start of your next turn, allied characters that start their turn at least partially
##  within the area or move into it for the first time in a round, may immediately move up to their
##  speed as a reaction. This movement is not affected by Slowed or Immobilized."
##  (specs/sixth-voice/10-naga.md, Rank II - Green Tide, Charging Swarm)
##
## THE BARBAROSSA'S BURN ZONE, POINTED AT ALLIES (action_apocalypse_burn.gd). This lives on the
## MARKER's trait Kit, so the reaction's `unit` is the swarm and the archetype measures "within" from
## it: triggers_on_coming_within_range = 1 around a size-1 marker is exactly the Blast 1, and
## UnitRelation.distance_between reads the CLOSEST occupied tiles, so a size-2 ally with one corner
## in the area is "at least partially within". step + new_turn, when_enter_within +
## when_start_turn_within, allies only, characters only - all on the .tres.
##
## WHO IS OFFERED (triggers_on_event, below the archetype's own filter):
##   - an ACTOR (is_actor): a drone is not a character - the mod-wide rule (rulings row 301).
##   - NOT THE NAGA ITSELF (SP3 ruling 22): the archetype would count the marker's owner as an ally.
##     The card says "allied characters"; the frame's own core passive says "you or an allied
##     character" when it means both, so the owner is excluded.
##   - one that CAN TAKE A REACTION (UnitAction.can_take_reactions): the design said
##     `reactions > 0`, and the engine's own gate is that plus Jammed and Grappled - a Grappled ally
##     cannot react to anything, and this is a reaction. Refusing it here, in the pure predicate,
##     is what leaves its once-per-round unburned (the design's own spec line).
##
## ONCE PER ROUND PER ALLY - ruling 16's simplification - and SP3 RULING 23: THE OFFER IS THE CHANCE.
## The record is written BEFORE the yes/no, so a decline spends it too. A STEP POST fires on every tile
## of a path (event_unit_move.gd:285), so recording only a yes would re-ask a player who declined on
## every tile they crossed inside the area. The record is the archetype's buff_track_affection, whose
## lifetime is START_OF_TURN (until = 3): it clears at the ALLY's own next turn start, just before the
## zone's turn-start offer is asked, so "once per round" is measured from turn start to turn start.
##
## THE REACTION POINT IS SPENT BY HAND - the Symbiosis rule (no buff may grant or spend one), and
## ActionReaction's own spend would charge the MARKER. consumes_rxn = false on the .tres for the same
## reason.
##
## THE MOVE: event_unit_pick_move on the ally with a budget of its full speed (Quick March's shape,
## action_quick_march_commander.gd:9-19). A fixed budget is not halved by Slowed - Slowed gates
## availability, never a move event - so "not affected by Slowed" costs nothing. "Not affected by
## Immobilized" has no narrow flag: every Immobilized gate is `voluntary and is_immobilized`
## (pathfinder.gd:333, event_unit_move.gd:451), so an Immobilized ally is moved INVOLUNTARILY, which
## also ignores engagement and reactions - ruling 17's recorded divergence, for that ally only.
extends ActionReactionOnComingWithin

## Lives on a MARKER, which the player can never select (memory marker-units-cannot-be-picked), so no
## card ever draws it; the yes/no is where the player meets it. Hidden like the swarm's expiry.
func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	var mover:Unit = triggering_event.context.unit
	if not Unit.is_valid(mover) or not mover.is_actor(): return false
	if mover == unit.get_owner_unit(): return false
	return UnitAction.can_take_reactions(mover)

func activate(context:Context, activation:EventCore) -> void:
	var ally:Unit = activation.context.event.context.unit
	if activation.abort_without_unit(ally): return

	# The once-per-round record comes FIRST - ruling 23, see the header.
	if record_unit_affected_and_abort_if_already_affected(activation, ally): return

	var specific := SpecificAction.from_context(context)
	var confirmed:bool = true
	if ally.is_player_controlled():
		confirmed = await CommonActionUtil.confirm_use_alt(specific, [ally], [], context.flags)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(ally): return
	if activation.abort_when(not UnitAction.can_take_reactions(ally)): return

	ally.core.current.reactions = maxi(0, ally.core.current.reactions - 1)

	var movement := MovementType.create_for_involuntary(ally) if UnitCondition.is_immobilized(ally) \
		else MovementType.create(ally, true)
	activation.queue_event(&'event_unit_pick_move', {
		target_unit = ally,
		resource = movement,
		number = ally.core.get_speed_max(),
		# tell the event who did it
		unit = context.unit,
		gear = context.gear,
		action = context.action,
	})
