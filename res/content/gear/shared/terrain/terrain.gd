# TERRAIN: the mod's shared reader and layer for difficult ground. Born with the Vauban's Sap and
# Gravity Well (SP1 Task 2).
#
# FROZEN INTERFACE (design §1.2, rulings row 2026-09-18). Four functions, exactly these names and
# signatures. Leoleth and the Shackleton consume them, and SP2's Mastication of the Maar is lay()'s
# first real caller, so a rename is three frames' worth of churn. Additions are allowed and reshapes
# are not; spec/test_terrain.gd is the guard.
#
# Not born here, deliberately (design §1.2): a lifetime for laid terrain (Leoleth's Decimate lasts
# until the start of its next turn, and that frame will add a die-at-turn-start trait to its own
# deployable rather than push a lifetime into this file), a Burst 2 frame (the Shackleton brings its
# own), and "damage in" (no consumer).
#
# No class_name (res/content/gear/shared/README.md): global class names are registered from
# project.godot's class list, which is built at startup, so one declared in a script a mod loads at
# runtime is never registered and cannot be referenced by that name at all. Callers preload this
# file. Same shape as overshield.gd, teleport.gd and Thy Hubris' infection.gd.
#
# THE ONE ENGINE FACT WORTH KNOWING: difficult terrain is a FACTIONLESS property of a map TILE
# (TerrainData.difficult_terrain, terrain_data.gd:43, merged by OR at :64). There is no such thing as
# terrain that is difficult for one side only - the pathfinder reads terrain.is_difficult() and
# nothing else (pathfinder.gd:93-100) and is a class_name script no mod can extend. MapState has
# FOUR accessors that sound like they answer the question:
#   - get_surface_terrain_at (map_state.gd:140)         <- ground PLUS unit-projected zones. THIS one.
#   - get_ground_terrain_at (:145)                       <- the topmost obstructing voxel only
#   - get_ground_surface_terrain_at (:152)               <- setpieces, no unit zones
#   - get_dynamic_terrain_at (:157)                      <- unit zones ONLY, keyed by voxel
# Every consumer should use the first, and that choice is written once here rather than re-derived.
#
# NOT terrain, whatever the pathfinder does with them: being Prone and standing below water level
# without EVA are pathfinder SYNTHETICS (pathfinder.gd:96-97) that never touch the tile property, so
# nothing here sees them. Design ruling 4 takes that as the rule rather than the exception.
extends RefCounted


## Is this map tile difficult ground?
##
## Ground terrain merged with every unit-projected PassiveTerrainZone, which is what
## get_surface_terrain_at returns and what every other accessor leaves out half of. False off the map
## (get_surface_terrain_at bounds-checks itself and returns TerrainBlockData.BLANK, map_state.gd:141)
## and false for a null map, because a gate that runs on every event must answer rather than throw.
static func is_difficult(map:MapState, tile:Vector2i) -> bool:
	if map == null: return false
	return map.get_surface_terrain_at(tile).is_difficult()


## Does this unit stand in difficult ground - "in at least one space of" it, as Gravity Well's card
## puts it?
##
## ANY of its occupied tiles, not its anchor: a size-2 mech with one corner in the field is in it.
static func is_unit_in_difficult(unit:Unit) -> bool:
	if not Unit.is_valid(unit): return false
	var map:MapState = unit.map
	if map == null: return false
	for tile:Vector2i in unit.occupied_tiles():
		if is_difficult(map, tile): return true
	return false


## Is this unit about to ENTER difficult ground by moving its anchor to `next_anchor`?
##
## Design ruling 3's test, exactly: the destination footprint touches difficult ground AND the current
## footprint does not. Walking from one difficult tile to the next is not a new entry; walking out and
## back in again is two.
##
## The destination footprint is UnitTile.get_occupied(next_anchor, state.occupying_size, map.size)
## (unit_tile.gd:45) - the ANCHOR ALONE IS NOT ENOUGH, because a size-2 unit can anchor on clean
## ground with its body over the field. occupying_size rather than core.get_size() because a unit
## riding another reports the bigger footprint (unit_battle_state.gd:65, :211).
##
## Tile.INVALID is refused rather than treated as (0,0): a `new_turn` context carries no target_tiles
## at all, and a caller that forgets to guard that should get "no" rather than an answer about the
## map's corner.
static func is_entering_difficult(unit:Unit, next_anchor:Vector2i) -> bool:
	if not Unit.is_valid(unit): return false
	if next_anchor == Tile.INVALID: return false
	var map:MapState = unit.map
	if map == null: return false
	var entering := false
	for tile:Vector2i in UnitTile.get_occupied(next_anchor, unit.state.occupying_size, map.size):
		if is_difficult(map, tile):
			entering = true
			break
	if not entering: return false
	return not is_unit_in_difficult(unit)


## Spawn `deployable` at `center`, owned by `specific.unit`, and hand the spawned unit back - or NULL
## if it did not land.
##
## The Apocalypse Rail's recipe (action_charge_rail_fire.gd:49-53): a Faction.NONE unit built from the
## frame, spawned with SKIP_ANIMATION. The frame decides the shape - MARKER or OBJECT, obstructing or
## not, what terrain zone it carries, what sprite it wears - and this helper owns none of that.
##
## OWNERSHIP is UnitAction.set_deployable_owner (unit_action.gd:517), the call every vanilla deploy
## makes: it records the owner on the deployable's state, appends the deployable's id to the gear's
## `deployed_ids` state (:519-523), copies the owner's token colours, and inherits the owner's save
## target and tier. Only the unit and the gear are required for that, so this refuses a specific with
## no gear and does NOT require an `action` - SpecificAction.is_valid would, and a caller with a
## legitimate gear-but-no-action shape should not be turned away.
##
## *** WHETHER THE DEPLOYABLE OUTLIVES ITS OWNER IS THE FRAME'S DECISION, NOT THIS HELPER'S, AND THE
## DEFAULT IS "NO". *** Frame.is_deactivated_on_owner_death defaults to TRUE (frame.gd:65), and
## EventService.remove_unit_from_game walks every unit owned by a dying one and queues event_unit_die
## on each MARKER that has it set (event_service.gd:56-63; an OBJECT gets Shutdown instead). So a
## frame that is meant to persist - the Maar, design ruling 8 - MUST set
## `is_deactivated_on_owner_death = false` in its own .tres. dep_apocalypse_difficult.tres does not
## set it and survives only because the Rail never calls set_deployable_owner at all. This corrects
## design §1.2, which said ownership alone never ends a unit.
## (mt_die_on_owner_death is a SECOND, earlier mechanism - a DEATH-PRE reaction on the deployable -
## and is what a frame adds when it wants to die with its owner promptly rather than by default.)
##
## RUNS INLINE AND AWAITS, rather than queueing at a priority the way the Rail does. The Rail's
## priority orders its crater against its own attack; a caller whose whole effect is the spawn has
## nothing to order against, and a queued spawn would hand back a Unit that is not on the map yet.
## Same shape, and the same X.current_level() fallback for a caller with no live activation, as
## Teleport._run (teleport.gd:383-390).
##
## *** NULL MEANS "DID NOT LAND", AND THE SPAWN'S OWN EventCore IS WHAT SAYS SO. *** Teleport._run
## hands its core back precisely so a caller can check; this helper's contract is the unit, so it does
## the checking here instead and returns null. THE UNIT ALONE CANNOT BE THAT ANSWER: Unit.is_valid
## does not include is_on_map (unit.gd:82-91), so an aborted spawn leaves a perfectly "valid" Unit with
## no token, no tile and no terrain zone - and since every other failure path above returns null, a
## caller reading non-null as success would take that corpse for a laid field. Three things are
## checked, because they are three different failures:
##   - a null core: execute_event returns bare when the block died under us (event_core.gd:72)
##   - `aborted`: EventBlock sets it when the event's required context does not hold (event_block.gd:103,
##     :121) - Tile.contains_valid(target_tiles, map) is measured against X.map(), not against the map
##     this function bounds-checked, because the spawning unit is by definition not on the map yet
##     (context.gd:79, :147)
##   - not on the map: the level exited during the await, so EventBlock.execute returned at its own
##     X.is_current_level_valid() guard and nothing was ever aborted OR spawned. Unit.is_valid is asked
##     first here only so a unit freed under us is a null rather than a throw.
static func lay(activation:EventCore, specific:SpecificAction, center:Vector2i, deployable:Frame) -> Unit:
	if deployable == null: return null
	if not SpecificAction.has_valid_unit(specific): return null
	if not GearCore.is_valid(specific.gear): return null
	var owner_unit:Unit = specific.unit
	var map:MapState = owner_unit.map
	if map == null: return null
	if not Tile.within_bounds(center, map.size): return null

	var laid := Unit.create(UnitCore.create(Faction.NONE, deployable))
	if not is_instance_valid(laid): return null
	UnitAction.set_deployable_owner(laid, owner_unit, specific.gear)

	var data := {
		unit = laid,
		target_tiles = [center],
		flags = [EventUnitSpawn.FLAG.SKIP_ANIMATION],
	}
	var spawn:EventCore = null
	if activation != null and activation.is_block_valid():
		spawn = await activation.execute_event(&'event_unit_spawn', data)
	else:
		var level := X.current_level()
		if level == null: return null
		spawn = EventCore.create(&'event_unit_spawn', data)
		await level.execute_event_block(EventBlock.create_multiple([spawn]))
	if spawn == null or spawn.aborted: return null
	if not Unit.is_valid(laid) or not laid.is_on_map(): return null
	return laid
