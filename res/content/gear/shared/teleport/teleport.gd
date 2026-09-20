# TELEPORT: the mod's shared teleport reader, tagger and interceptor. Born with the Maiden's Blush's
# Uncertainty Field (SP1 Task 1).
#
# FROZEN INTERFACE, OBSERVE/INTERCEPT HALF (roadmap §4, design §1.4). Six functions, exactly these
# names and signatures. Five later frames consume them - Purple Thorn, Leoleth (ZIP), Sluagh (Hunt),
# Koremasa (Vanish), Six Sky - so a rename is five frames' worth of churn.
#
# THE PERFORM HALF IS NOW IN THIS SAME FILE and frozen with it (SP2, design §2.4: candidate_tiles,
# pathfinder, pick_tile, move, move_along) - eleven functions in total, with every SP1 spec still
# green and unchanged. Additions, not reshapes: nothing here holds state, nothing here is an instance
# method, and neither half needs to know about the other. Its own block header, further down, carries
# the measurement that corrected the design's account of how an unpreventable teleport is issued.
#
# ADDITIONS ARE ALLOWED AND TWO MORE HAVE LANDED (SP2, the SLUAGH's Hunt of the Vagrant Sowche,
# design ruling 18): forced_movement_type() and shove(), the "somebody else's shove" half of is_own's
# question, which nothing built until a card needed to move a unit that is not the caller. THIRTEEN
# functions now, and not one of the eleven moved. See each one's own header.
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
## NULL IS THE NORMAL ANSWER FOR A VANILLA TELEPORT OF OUR OWN: Blinkspace Jump passes no specific to
## generate_events (action_blinkspace_jump.gd:64) and event_unit_teleport sets no `object` at all. A
## caller must read null as "nobody readable", never as "me".
##
## BUT OUR OWN move() AND move_along() DO PASS ONE (SP2), so this returns the MECH ITSELF for a Step of
## Mist and Thunder or an Abjuration of Metal - which is why they can be logged and telegraphed by
## name.
##
## A CALLER DISTINGUISHING "somebody is shoving me" from "this is mine" can no longer read
## resource.voluntary and is_own as a matched pair before ever reaching this function.
## action_uncertainty_field.triggers_on_event now has exactly ONE "ours" clause -
## context.resource.voluntary - and it is true only for a VOLUNTARY teleport. A Step of Mist and
## Thunder is own but INVOLUNTARY (reach design ruling C, 2026-09-17, reversing ruling 157), so it
## FALLS THROUGH to the forcer check below, and that fall-through is what keeps the exemption safe
## rather than accidental: forcer(context) returns the mech ITSELF for a Step (move() passes its own
## SpecificAction as the event's object, above), so UnitRelation.are_enemies(unit, forcer) reads
## Faction.is_enemy(f, f) - false (unit_relation.gd:361-362) - and the trait correctly declines to
## react to its own unpreventable teleport. A CONSUMER READING THE FORCER AND FINDING ITSELF THERE IS
## now how "this is my own unpreventable teleport" gets recognised - not a case this function fails
## to distinguish.
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
## OWN tag.
##
## ignore_rxns IS LEFT UNSET, AND NOT FOR THE REASON THIS COMMENT USED TO GIVE. It does NOT decide
## whether Uncertainty Field is offered: MovementType.ignores_reactions() is `ignore_rxns or teleport
## or not voluntary` (movement_type.gd:101-102), which is already true of EVERY teleport, so setting
## the flag would change nothing about that answer. The move event never consults that answer at all -
## NO_RXNS is "not enforced; reactions need to decide for themselves" (event_unit_move.gd:26), so each
## of the four judgements belongs to the listener - and for THIS shape (reach design ruling C,
## 2026-09-17) the listener's judgement is "not mine to veto": action_uncertainty_field's
## triggers_on_event no longer reads the NO_RXNS flag, or anything else on this type, for a Step of
## Mist and Thunder - it falls through to the forcer check and declines there instead (see forcer()'s
## docstring above). The flag stays unset anyway: it is vanilla's own signal for "do not react to
## this", and our own Step has no reason to send it.
static func movement_type(unit:Unit, own_involuntary:bool = false) -> MovementType:
	var type := MovementType.create(unit, not own_involuntary)
	type.teleport = true
	if own_involuntary:
		type.ignore_engagement = true
		# RE-ASSERTED AFTER THE ENGINE'S OWN BUFF MERGE, and load-bearing rather than redundant.
		# MovementType.create sets `type.voluntary = is_voluntary` (movement_type.gd:44) and THEN merges
		# every Buff.TO.MOVEMENT_TYPE resource the unit holds (:51), where merge_in is
		# `voluntary = voluntary or other.voluntary` (:81). So a single movement-type buff authored
		# voluntary = true would hand this shape back VOLUNTARY, and the whole "this teleportation
		# cannot be prevented" clause is that one flag: both Immobilized gates test it
		# (pathfinder.gd:333, event_unit_move.gd:451), and Pathfinder.create is where every
		# MOVEMENT_RESTRICTION ban lands. Latent today - no vanilla or resident movement-type resource
		# sets voluntary - which is exactly why nothing else would notice it going wrong.
		type.voluntary = false
		if not type.other_tags.has(OWN_TAG): type.other_tags.append(OWN_TAG)
	else:
		# THE SYMMETRIC HALF OF THE SAME MERGE (SP1 slice-1 close review, carried item 1). merge_in also
		# propagates other_tags wholesale (`other_tags.append_array(other.other_tags)`,
		# movement_type.gd:96), so a Buff.TO.MOVEMENT_TYPE resource whose OWN other_tags happened to
		# carry OWN_TAG would leak it into a VOLUNTARY teleport too, and is_own() would then read a
		# foreign, ordinary teleport as our own unpreventable Step. The tag means "ours", and only the
		# branch above - the one that just applied it - is allowed to leave it standing, which is why
		# this branch erases rather than merely ignores it. Latent today, same as the flag above:
		# nothing writes this string but Teleport itself, so nothing else would notice it going wrong.
		type.other_tags.erase(OWN_TAG)
	return type


## Was this movement type built by movement_type(unit, true)?
##
## False for everything else, including our own VOLUNTARY teleport - that one needs no tag, because a
## listener reads resource.voluntary for it. The tag exists for exactly one question: an involuntary
## teleport is either our own unpreventable Step or somebody else's shove, and the engine cannot tell
## them apart.
##
## THE PARAMETER NAME SHADOWS THE SIBLING STATIC FUNCTION, and the name is frozen by the signature
## contract (design §1.4, pinned by test_teleport's freeze test) so it cannot simply be renamed. Inside
## this body `movement_type` is this MovementType ARGUMENT, never the movement_type() above it, so a
## future is_own that wants the canonical shape cannot call that function - build the shape inline, or
## read the tag directly as below. SP2 adds five more functions to this file; this is the one name that
## cannot be reached from in here.
##
## NOTHING IN THIS MOD READS THIS TODAY, AND THAT IS A DECISION RATHER THAN ROT (reach design ruling C,
## 2026-09-17). action_uncertainty_field.triggers_on_event was the one caller, and dropping its
## is_own clause is what made Step of Mist and Thunder permanently exempt from the frame's own trait.
## The function stays because the QUESTION it answers is still the right one for the five later frames
## this helper is frozen for - an involuntary teleport is either our own unpreventable one or somebody
## else's shove, and the engine cannot tell them apart - and because the interface is frozen either
## way. Do not delete it as dead code.
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

# ================================================================================================
# THE PERFORM HALF (SP2, design §2.4). Five statics, frozen with the six above when SP2 ships.
#
# WHY THESE EXECUTE INLINE AND HAND THE CORE BACK, when vanilla's Blinkspace Jump queues its move and
# returns (action_blinkspace_jump.gd:64): both of this frame's teleports need what comes AFTER the
# move - Step's adjacent Systems saves, Abjuration's Skirmish - but for different reasons since reach
# design ruling C (2026-09-17). Abjuration still needs to know whether Uncertainty Field took its
# teleport - a vetoed one forfeits the Skirmish. Step needs the core handed back because the field can
# no longer take IT: what it needs instead is whether the move RESOLVED AT ALL, since the
# adjacent-characters saves are a consequence of arriving, and `move` can still report one that never
# resolved for other reasons - a null core, or another listener's abort. A queued move resolves after
# the activation has finished, so neither reason is reachable from there.
#
# THE ONE THING THAT COST A MEASUREMENT (SP2 probe, 2026-09-17, and it CORRECTED the design):
# "moves by target tile without a pathfinder" is FALSE. EventUnitMove.undergo_move takes
# context.array straight when it is handed a path (event_unit_move.gd:137-138) and otherwise builds a
# pathfinder ITSELF - Pathfinder.generate_for_given_tiles then path_to (:139-145). So a target-tile
# move reads every MOVEMENT_RESTRICTION ban after all, and the ONLY route that escapes one is an
# explicit path. Measured four ways:
#
#   route                             Immobilized   Interdiction Field ban
#   voluntary   + target tile          loses         loses
#   involuntary + target tile          BEATS         loses
#   voluntary   + one-step path        loses         BEATS
#   involuntary + one-step path        BEATS         BEATS
#
# Involuntariness buys the Immobilized gate and nothing else (Pathfinder.create's check at
# pathfinder.gd:333 is voluntariness-gated; the ban read at :345-352 is gated on nothing). Bypassing
# the pathfinder buys the ban and nothing else. "This teleportation cannot be prevented" needs both,
# so move() sends a hand-built single step.
# ================================================================================================


## Every free space this unit could teleport to within `range`.
##
## `range` SHADOWS GDScript's built-in range() inside this function, and the name is frozen by the
## design's signature contract (§2.4) so it cannot simply be renamed - the same situation is_own's
## `movement_type` parameter is in. Nothing in this body needs range().
##
## THE FILTER IS THE ENGINE'S OWN FREE-SPACE TEST, not a re-implementation:
## UnitTile.is_tile_standable (unit_tile.gd:127) with Katamari.create_solipsistic(unit), which is
## exactly the pair get_nearest_valid_tiles uses (:139-155). The katamari and the movement type are
## built ONCE - is_tile_standable defaults its movement_type argument to MovementType.create(unit),
## which walks every Buff.TO.MOVEMENT_TYPE the unit holds, and that is not a per-tile cost worth
## paying.
##
## The unit's OWN occupied tiles are dropped: a teleport to where you already are is not a move, and
## is_tile_standable says yes to them (the solipsistic katamari ignores the mover itself).
static func candidate_tiles(unit:Unit, range:int, require_line_of_sight:bool, keep:Callable = Callable()) -> Array[Vector2i]:
	if not Unit.is_valid(unit): return []
	var katamari := Katamari.create_solipsistic(unit)
	var type := movement_type(unit)
	var occupied := unit.occupied_tiles()
	var tiles := UnitTile.get_tiles_within(unit, range, require_line_of_sight)
	Util.filter(tiles, func(tile:Vector2i) -> bool:
		if occupied.has(tile): return false
		if not UnitTile.is_tile_standable(unit, tile, katamari, type): return false
		if keep.is_valid() and not keep.call(tile): return false
		return true
	)
	return tiles


## A teleport pathfinder over an explicit tile set - Blinkspace's shape
## (action_blinkspace_jump.gd:51-56), and THE PREVENTABLE ROUTE ON PURPOSE.
##
## generate_for_given_tiles calls Pathfinder.create (pathfinder.gd:294/:296), which is both the
## Immobilized gate (:333) and where every MOVEMENT_RESTRICTION ban is read and intersected
## (:345-352). Abjuration of Metal wants exactly that: its teleport is an ordinary one that an
## Interdiction Field or Immobilized should stop. Step of Mist and Thunder must NOT come through
## here - it uses move() below.
static func pathfinder(unit:Unit, tiles:Array[Vector2i]) -> Pathfinder:
	return await Pathfinder.generate_for_given_tiles(unit, tiles, movement_type(unit))


## The reticle over an EXACT tile set. Tile.INVALID when the player cancels.
##
## MECHANISM (settled by the SP2 probe, which measured both candidates the design left open):
## TargetRequirements.targetable_tiles_override is returned VERBATIM by
## UnitTargeting.get_tiles_targetable, before any other filtering (unit_targeting.gd:68-74) - no
## range pattern to fight, no line-of-sight pass to disable, and no ACTION_TILE buffs merged in. The
## Thy Hubris reag_tile_set_picker port (roadmap SP0) is therefore NOT needed and stays deferred.
##
## THE TILE SET REACHES get_target_requirements THROUGH A PER-CALL COPY OF THE CALLING ACTION, which
## is the part that needs care. get_target_requirements is a method on the Action RESOURCE, and one
## Action resource is shared by every unit carrying the gear - so parking the tiles on the real
## action would have two Blushes picking from each other's sets, and parking them in a static here
## would break this file's "nothing holds state" invariant.
## Action.create_duplicate_for_variant() (action.gd:94-98) is the engine's own identity-preserving
## copy: it sets original_id = get_id(), and get_id() returns original_id when it is set (:90-92), so
## the copy still resolves Translate.action(kit, action, 'name') to the REAL action's localisation
## rows. The prompt says "Step of Mist and Thunder", not the name of a proxy.
##
## target_requirements_override is a plain @export on Action (:34) that get_target_requirements
## returns when set (:207-208), so no subclass hook is needed to install it.
static func pick_tile(context:Context, activation:EventCore, tiles:Array[Vector2i]) -> Vector2i:
	if tiles.is_empty(): return Tile.INVALID
	if not Unit.is_valid(context.unit): return Tile.INVALID

	var reqs := TargetRequirements.create(1, RangePattern.create(Lancer.AOE_TYPE.NONE, 0))
	reqs.can_target_empty_tiles = true # we are picking a SPACE, not a unit
	reqs.can_target_units = false
	reqs.requires_free_space = true
	reqs.targetable_tiles_override = func(
		_specific:SpecificAction,
		_picks:Array = [],
		_from_tile := Tile.INVALID,
		_los:PackedInt64Array = []
	) -> Array[Vector2i]: return tiles

	var proxy:Action = context.action.create_duplicate_for_variant()
	proxy.target_requirements_override = reqs
	var specific := SpecificAction.create(context.unit, context.gear, proxy)

	# No pathfinder: this is a pick, never a move-then-act. ask_for_targets_alt turns a null or
	# aborted plan into CompconPlan.create_aborted() (target_action_util.gd:203).
	var plan:CompconPlan = await TargetActionUtil.ask_for_targets_alt(activation, specific)
	if plan == null or plan.aborted: return Tile.INVALID
	if plan.target_tiles.is_empty(): return Tile.INVALID
	return plan.target_tiles.front()


## THE UNPREVENTABLE ROUTE: one event_unit_move carrying a hand-built SINGLE-STEP path, executed
## inline, with the move core handed back so the caller can read `aborted`.
##
## A PATH, NOT A TARGET TILE - see this block's header for the four-way measurement. One step of any
## length is legal because is_next_step_possible waives the "still adjacent to us" rule when
## movement_type.teleport (event_unit_move.gd:385), and has_enough_move_to_reach_end returns true at
## its `not movement_type.spend_move` early exit (:454) - spend_move defaults false
## (movement_type.gd:5) and movement_type() above never sets it. The step's cost is nominal for the
## same reason: nothing reads it.
##
## IT PASSES THE CALLING ACTION'S SpecificAction AS THE EVENT'S `object`, derived from the activation
## rather than taken as an argument, because the signature is frozen. LOGGING THE VETO BY NAME IS DEAD
## HERE, since reach design ruling C (2026-09-17) means Uncertainty Field can no longer take a Step to
## veto, so action_uncertainty_field.replaced_name never again reads this `object` for one. What it
## still buys is forcer() safety, not naming: a Step falls through to triggers_on_event's forcer check
## now, and this `object` is what lets Teleport.forcer(context) return the mech ITSELF - so
## UnitRelation.are_enemies(unit, unit) is false and the exemption is safe rather than accidental. See
## forcer()'s docstring above and action_uncertainty_field.triggers_on_event.
static func move(activation:EventCore, unit:Unit, tile:Vector2i, own_involuntary:bool = true) -> EventCore:
	if not Unit.is_valid(unit): return null
	if not Tile.is_valid(tile, unit.map): return null
	var path:Array[Pathfinder.Step] = [Pathfinder.Step.create(tile, 1)]
	return await _run(activation, {
		unit = unit,
		array = path,
		resource = movement_type(unit, own_involuntary),
		object = _source(activation),
	})


## The same, for a move the player planned through a pathfinder: Abjuration's route.
##
## generate_events returns an ARRAY (pathfinder.gd:908-916) that today holds exactly one core, and
## the one this returns is the one whose context.unit is the mover - a caller reading `aborted` must
## be reading the mech's own move, not a katamari passenger's. Its fourth argument is the
## SpecificAction (:903), passed for the same reason move() passes `object`.
static func move_along(activation:EventCore, unit:Unit, pathfinder:Pathfinder, plan:CompconPlan) -> EventCore:
	if not Unit.is_valid(unit): return null
	if pathfinder == null or plan == null or plan.move_path.is_empty(): return null
	var cores := pathfinder.generate_events(unit, plan.move_path, [], _source(activation))
	if cores.is_empty(): return null
	if activation != null and activation.is_block_valid():
		await activation.execute_events(cores)
	else:
		var level := X.current_level()
		if level == null: return null
		await level.execute_event_block(EventBlock.create_multiple(cores))
	for core:EventCore in cores:
		if core.context.unit == unit: return core
	return cores.front()


## SOMEBODY ELSE'S SHOVE - the third movement-type shape, and the one is_own's docstring above names
## as the other half of its question (SP2, the Sluagh's Hunt of the Vagrant Sowche, design ruling 18).
##
## INVOLUNTARY LIKE OUR OWN STEP, AND DELIBERATELY NOT TAGGED. That is the entire distinction: both
## shapes are involuntary, the engine cannot tell them apart, and OWN_TAG is the one bit that says
## "this one is the holder's own unpreventable teleport". A hostile shoving us must NOT set it, or a
## self-exemption reading is_own would wave the shove through.
##
## NO own_involuntary PARAMETER, unlike movement_type(). A shove is never ours, so a flag with one
## legal value would be a reshape waiting to happen; the frozen signature is deliberately narrow.
##
## voluntary IS RE-ASSERTED AFTER create()'s BUFF MERGE, for the same reason movement_type(unit, true)
## does it: MovementType.create sets `type.voluntary = is_voluntary` (movement_type.gd:44) and THEN
## merges every Buff.TO.MOVEMENT_TYPE resource the unit holds (:51), where merge_in is
## `voluntary = voluntary or other.voluntary` (:81). One buffed movement type authored voluntary = true
## would make this shape preventable by Immobilized (event_unit_move.gd:451), and the card says the
## target IS moved. Latent today - nothing vanilla or resident sets that flag - which is why nothing
## else would notice it going wrong.
##
## AND other_tags IS ERASED, the symmetric half: merge_in propagates other_tags wholesale
## (movement_type.gd:96), so a movement-type buff carrying our own tag would smuggle it in here too.
## The tag means "ours", and only movement_type(unit, true) is allowed to leave it standing.
##
## NOT MovementType.create_for_involuntary (movement_type.gd:63-71), which already exists and is what
## a knockback uses. Three reasons, all measured off that function: it never sets teleport, so
## is_teleport() answers false and no listener sees the move at all; it sets ignore_rxns, vanilla's
## own "do not react to this" signal, which is precisely what ruling 18 does not want, since a Maiden's
## Blush must be able to veto a Hunt; and it skips the buff merge entirely, so a FLYING or INTANGIBLE
## target would lose those flags mid-shove.
static func forced_movement_type(unit:Unit) -> MovementType:
	var type := MovementType.create(unit, false)
	type.teleport = true
	type.ignore_engagement = true
	type.voluntary = false
	type.other_tags.erase(OWN_TAG)
	return type


## Shove a unit that is NOT the caller: move()'s body with the untagged involuntary type, executed
## inline, with the move core handed back so the caller can read `aborted`.
##
## THE `object` IS THE SHOVER, AND THAT IS THE POINT. move() derives it from the activation too, but
## there the activation belongs to the mover, so forcer(context) returns the mech itself and
## are_enemies(unit, unit) is false. Here the activation belongs to the SLUAGH, so forcer() returns
## the Sluagh, are_enemies is true, and a Maiden's Blush's Uncertainty Field correctly offers to fade
## instead of being shoved - which is the reading design ruling 18 records for this card.
##
## A TARGET TILE, NOT A PATH - THE ONE LINE WHERE THIS DIFFERS FROM move(), AND IT IS A DECISION
## (SP2 controller ruling, 2026-09-20, reversing the plan's departure 7; PROPOSED to the author).
## See this block's header for the four-way measurement: "involuntary + target tile" BEATS
## Immobilized and LOSES to a MOVEMENT_RESTRICTION ban, because EventUnitMove.undergo_move builds a
## pathfinder of its own for a target-tile move (event_unit_move.gd:139-145) and Pathfinder.create is
## where every ban is read (:345-352) - while the Immobilized gate there (:333) and the one in the
## move event (:451) both test voluntary, which this type is not. That is EXACTLY design ruling 18's
## claim and no more: "Immobilized gates only voluntary moves, so the shove lands on an Immobilized
## target". A shove is somebody ELSE's move, and the fence a unit's own effects put around it (an
## Interdiction Field, Thy Hubris' chain) is the engine's ban channel - a hostile Hunt does not get
## to break that fence, where the frame's OWN unpreventable Step (move()) deliberately does. It also
## keeps the two routes distinct in substance and not only in the tag. An Uncertainty Field's veto
## is an ENTIRE_MOVEMENT PRE listener (:71-72) and fires before undergo_move either way.
##
## If the author wants a Hunt to beat a ban too, the change is one line here: array = one
## Pathfinder.Step in place of target_tiles, exactly as move() sends.
static func shove(activation:EventCore, unit:Unit, tile:Vector2i) -> EventCore:
	if not Unit.is_valid(unit): return null
	if not Tile.is_valid(tile, unit.map): return null
	return await _run(activation, {
		unit = unit,
		target_tiles = [tile],
		resource = forced_movement_type(unit),
		object = _source(activation),
	})


## The SpecificAction to hang on a move as its `object`, or null when the activation has none.
##
## SpecificAction.from_context on a context missing any of unit/gear/action yields something
## has_valid_unit refuses, which is the right answer - "nobody readable" - and is what a spec's dummy
## event produces. Kept as one function so move() and move_along() cannot drift apart on it.
static func _source(activation:EventCore) -> SpecificAction:
	if activation == null or activation.context == null: return null
	return SpecificAction.from_context(activation.context)


## Run one event on the caller's own block when there is one, and through the level when there is not
## - the Overshield helper's idiom (overshield.gd:46-53), for the same two reasons: a caller inside a
## live activation wants its move ordered inside that activation, and a caller holding a spec's dummy
## event has no block to queue onto. Hands the core back either way, which is the whole point of this
## half of the helper.
static func _run(activation:EventCore, data:Dictionary) -> EventCore:
	if activation != null and activation.is_block_valid():
		return await activation.execute_event(&'event_unit_move', data)
	var level := X.current_level()
	if level == null: return null
	var core := EventCore.create(&'event_unit_move', data)
	await level.execute_event_block(EventBlock.create_multiple([core]))
	return core
