# TELEPORT: the mod's shared teleport reader, tagger and interceptor. Born with the Maiden's Blush's
# Uncertainty Field (SP1 Task 1).
#
# FROZEN INTERFACE, OBSERVE/INTERCEPT HALF (roadmap §4, design §1.4). Six functions, exactly these
# names and signatures. Five later frames consume them - Purple Thorn, Leoleth (ZIP), Sluagh (Hunt),
# Koremasa (Vanish), Six Sky - so a rename is five frames' worth of churn.
#
# SP2 ADDS THE PERFORM HALF to this same file (design §2.4: candidate_tiles, pathfinder, pick_tile,
# move, move_along), with every spec in test_teleport.gd still green. Additions, not reshapes:
# nothing here holds state, nothing here is an instance method, and neither half needs to know about
# the other.
#
# No class_name (res/content/gear/shared/README.md): global class names are registered from
# project.godot's class list, which is built at startup, so one declared in a script a mod loads at
# runtime is never registered and cannot be referenced by that name at all. Callers preload this
# file. Same shape as overshield.gd and Thy Hubris' infection.gd.
#
# THE ONE ENGINE FACT WORTH KNOWING: every teleport in the engine is ONE event_unit_move whose
# context.resource is a MovementType with teleport = true (spike 5, 2026-09-17; the source table is
# in specs/2026-09-17-teleport-interception-feasibility.md §1). ENTIRE_MOVEMENT / PRE fires at
# event_unit_move.gd:71 on the REAL core for the mover, and :72 returns on a listener's
# set_aborted(). The bus filters on nothing - not on the movement type, not on NO_RXNS ("not
# enforced; reactions need to decide for themselves", event_unit_move.gd:26), not on voluntariness -
# so every one of those four judgements belongs to the listener, and is written once here.
extends RefCounted

## Marks a movement type as one of our OWN mech's teleports, so a self-reaction can tell its own
## unpreventable Step from a hostile shove while both are INVOLUNTARY (design §0.8).
##
## other_tags, NOT set_meta - a deliberate divergence from design §1.4. other_tags is MovementType's
## own purpose-built channel (movement_type.gd:28, "e.g. Follower Count telling the pathfinder buff
## that the movement came from it"), it is a typed Array[StringName] that merge_in propagates
## (movement_type.gd:96) and that an exported-property duplicate() carries without question -
## event_unit_move.gd:103 really does duplicate a movement type when a unit's flight fails. The one
## vanilla reader tests only for its own key
## (buff_follower_count_breacher_movement_restriction.gd:18), so an extra StringName is inert.
const OWN_TAG := &'reag_own_teleport'


## Is this move context a teleport? The bus offers EVERY move at ENTIRE_MOVEMENT and nothing in the
## engine filters on movement type, so the listener does it itself.
##
## Guarded against a null context and an absent resource: context.resource is OPTIONAL on
## event_unit_move (:52) and :68 falls back to MovementType.create(unit) when it is missing, so a
## listener really can be handed a context without one - and a gate runs for every unit's every buff
## and reaction on every event, where a throw is an error storm rather than a wrong answer.
static func is_teleport(context:Context) -> bool:
	if context == null: return false
	if not MovementType.is_valid(context.resource): return false
	return context.resource.teleport


## Where the move is going. A move arrives in exactly TWO shapes and a listener has to read both: a
## full path (context.array of Pathfinder.Step, from Pathfinder.generate_events, pathfinder.gd:908-916)
## or a single target tile (event_unit_teleport, SpecFactory.move, and SP2's own Teleport.move).
## Tile.INVALID when the context carries neither - which check_specific_context
## (event_unit_move.gd:58-62) makes impossible for a real move, but is reachable from a hand-built
## context and must not read as (0, 0).
static func destination(context:Context) -> Vector2i:
	if context == null: return Tile.INVALID
	if not context.target_tiles.is_empty(): return context.target_tiles.front()
	if not context.array.is_empty() and context.array.back() is Pathfinder.Step:
		return context.array.back().tile
	return Tile.INVALID


## Who forced this move, or null. Flash Anchor's read exactly (action_flash_lock.gd:43-48): for an
## event_unit_move the source is context.object, a SpecificAction.
##
## VALIDATED WITH has_valid_unit, NOT is_valid. EventUnitMove builds a katamari passenger's mover
## specific with NULL gear and NULL action (event_unit_move.gd:318), and SpecificAction.is_valid
## demands all three (specific_action.gd:16-23) - so is_valid would answer null for the very case
## this exists to catch.
##
## NULL IS THE NORMAL ANSWER FOR OUR OWN TELEPORT: Blinkspace Jump passes no specific to
## generate_events (action_blinkspace_jump.gd:64) and event_unit_teleport sets no `object` at all. A
## caller must read null as "nobody readable", never as "me".
static func forcer(context:Context) -> Unit:
	if context == null: return null
	var source = context.object
	if not SpecificAction.has_valid_unit(source): return null
	return source.unit


## The movement type one of our teleports is issued with.
##
## DEFAULT: VOLUNTARY, the Blinkspace shape (MovementType.create(unit) with teleport = true), and
## PREVENTABLE on purpose - both Immobilized gates test movement_type.voluntary (pathfinder.gd:333
## and event_unit_move.gd:451), and Pathfinder.create is also where every MOVEMENT_RESTRICTION ban
## lands (:345-352), bans winning over adds.
##
## own_involuntary = true is the "this teleportation cannot be prevented" shape (design §0.8): the map
## editor's event_unit_teleport type (event_unit_teleport.gd:26-29) MINUS the NO_RXNS flag, plus the
## OWN tag. ignore_rxns is deliberately NOT set: it is what vanilla uses to mean "do not react to
## this", and Uncertainty Field must still be offered on our own Step.
static func movement_type(unit:Unit, own_involuntary:bool = false) -> MovementType:
	var type := MovementType.create(unit, not own_involuntary)
	type.teleport = true
	if own_involuntary:
		type.ignore_engagement = true
		if not type.other_tags.has(OWN_TAG): type.other_tags.append(OWN_TAG)
	return type


## Was this movement type built by movement_type(unit, true)?
##
## False for everything else, including our own VOLUNTARY teleport - that one needs no tag, because a
## listener reads resource.voluntary for it. The tag exists for exactly one question: an involuntary
## teleport is either our own unpreventable Step or somebody else's shove, and the engine cannot tell
## them apart.
static func is_own(movement_type:MovementType) -> bool:
	if not MovementType.is_valid(movement_type): return false
	return movement_type.other_tags.has(OWN_TAG)


## Stop the teleport being offered to us. One line, kept here because this is where the seam's
## knowledge lives: event_unit_move.gd:72's abort_without_unit is abort_when(false), and abort_when
## returns the core's EXISTING aborted flag (event_core.gd:26-29, "if we aborted some other way, also
## return that it's time to pull the cord"), so a PRE listener's set_aborted() makes the move return
## one line later - before the pathfinder's deferred spend (:76-78) and before undergo_move (:113).
## Flash Anchor does exactly this (action_flash_lock.gd:66).
##
## TAKES THE TRIGGERING CORE, NEVER THE ACTIVATION. A reaction reads it off context.event; a buff off
## activation.context.event. Vetoing the activation instead would abort our own reaction and leave
## the teleport untouched.
static func veto(triggering:EventCore) -> void:
	if not is_instance_valid(triggering): return
	triggering.set_aborted()
