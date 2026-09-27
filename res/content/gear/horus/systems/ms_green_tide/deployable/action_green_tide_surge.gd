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
##   - a CHARACTER (is_character()): a drone included (ruling 2026-09-27, reversing the mod-wide
##     is_actor() reading rulings row 301 recorded).
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
## THE ALLY'S REACTION POINT, NOT THE MARKER'S: ActionReaction's own spend would charge the MARKER, so
## consumes_rxn = false on the .tres and the script spends the ally's through vanilla's
## UnitAction.spend_reaction (unit_action.gd:283-285: the decrement plus the "reaction spent" popcorn;
## not a buff, so the Symbiosis rule - no buff may grant or spend one - is untouched). The use is
## logged and popped with the action's name under the ALLY (Action.log_usage / popcorn_usage on a
## cloned specific), since nothing calls spend_actions here.
##
## AREA = THE DRAWN BLAST: triggers_regardless_of_elevation = true on the .tres (author decision 4,
## frame close). The Blast the player drew is flat; measured with elevation, an ally two levels up
## inside it was never offered.
##
## THE MOVER: the ALLY chooses this move; nothing forces it. So it is NOT an event_unit_pick_move:
## that event's budget branch is inlined here (event_unit_pick_move.gd:112-113, :145-162 - build the
## pathfinder, ask, execute) WITHOUT its knockback-immunity abort (:78). Frame-close slice 4 #1: with
## the marker as the pick_move's `unit`, buff_heavy_frame_knockback / Fomorian Frame compare that
## unit's size to the mover's, and a size-0.5 marker is smaller than everyone - a Heavy Frame ally
## said yes, lost its reaction and never moved. Omitting `unit` (vanilla Perimeter Command Plate,
## action_perimeter_command_plate_trigger.gd:29-36) clears those, but read against
## TargetActionUtil.ask_for_movement_alt (target_action_util.gd:37-38, :108-120) an invalid specific
## sends an AI-controlled ally to the reachable tile CLOSEST to where it stands (:115-116 - one step
## at best, never a choice) and a player's picker loses its label and the overwatch confirm (read,
## not measured); `unit = ally` instead keeps those
## but makes a BRACED Armor-Lock ally immune (buff_armor_lock_plating_knockback.gd compares the
## unit to size 5), and unconditional immunities (Fortress Protocol, Flash Anchor, mt_knockback_
## immunity) block every variant. A voluntary move is not knockback, so no immunity is asked at all.
## The specific handed to the picker and the move names the ally, so the picker is the ally's own.
## A cancelled picker spends nothing (the record is still written - ruling 23).
##
## THE MOVE: a pathfinder on the ally with a budget of its full speed (Quick March's budget,
## action_quick_march_commander.gd:9-19). A fixed budget is not halved by Slowed - Slowed gates
## availability, never a move event - so "not affected by Slowed" costs nothing. "Not affected by
## Immobilized" has no narrow flag: every Immobilized gate is `voluntary and is_immobilized`
## (pathfinder.gd:333, event_unit_move.gd:451), so an Immobilized ally's move must be INVOLUNTARY.
## AUTHOR DECISION 3 (frame close) NARROWS IT: the type is the ally's own voluntary one
## (MovementType.create - its MOVEMENT_TYPE buffs kept, no jump_downhill, no ignore_difficult flag)
## with `voluntary` cleared and ignore_fall_damage set, so it takes no fall damage as a voluntary move
## would. WHAT NO FLAG CAN NARROW, recorded: `not voluntary` alone still makes it ignore reactions and
## engagement (ruling 17, movement_type.gd ignores_reactions/ignores_engagement), ignore difficult
## terrain (ignores_difficult_terrain() ORs in `not voluntary`), and pay 1 per tile for every step,
## climbs included (pathfinder.gd:772 returns 1 for `not voluntary and not spend_move`; spend_move
## would charge the ally's standard move, which a reaction must not). Katamari also leaves riders
## behind on an involuntary move (katamari.gd:94-96) and the leave-attachment confirm is skipped
## (event_unit_move.gd:187). For this ally only, and only while Immobilized.
extends ActionReactionOnComingWithin

## Lives on a MARKER, which the player can never select (memory marker-units-cannot-be-picked), so no
## card ever draws it; the yes/no is where the player meets it. Hidden like the swarm's expiry.
func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	var mover:Unit = triggering_event.context.unit
	if not Unit.is_valid(mover) or not mover.is_character(): return false
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

	# THE ALLY IS THE ONE MOVING AND CHOOSING (see THE MOVER): the specific names it, so the picker is
	# the ally's own (player or AI) and is labelled with the surge.
	var as_ally := SpecificAction.clone(specific)
	as_ally.unit = ally

	var movement := MovementType.create(ally, true)
	if UnitCondition.is_immobilized(ally): narrow_to_involuntary(movement)
	var pathfinder := await Pathfinder.generate_for_movement_budget(ally, ally.core.get_speed_max(), movement)
	if activation.abort_without_unit(ally): return
	var plan := await TargetActionUtil.ask_for_movement_alt(ally, pathfinder, as_ally)
	if activation.abort_without_movement_plan(plan, ally): return

	# Logged and popped as the ALLY's use, and its reaction spent - only for a move actually taken.
	log_usage(as_ally)
	popcorn_usage(as_ally)
	UnitAction.spend_reaction(ally)
	await activation.execute_events(pathfinder.generate_events(ally, plan.move_path, [], as_ally))

## Author decision 3 (frame close): the Immobilized ally's move is the VOLUNTARY one with only the
## flag that gets it past Immobilized flipped. See the header for what that flag still drags along.
static func narrow_to_involuntary(movement:MovementType) -> void:
	movement.voluntary = false
	# takes_fall_damage() is `(straight_line or not voluntary)`: a voluntary move never falls for damage.
	movement.ignore_fall_damage = true
