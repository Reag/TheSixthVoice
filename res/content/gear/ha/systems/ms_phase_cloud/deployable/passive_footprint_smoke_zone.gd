## PHASE CLOUD'S SMOKE: a PassiveTerrainZone whose burst is measured from the footprint of whoever
## laid it, not from the marker's own single tile (design 3.2, ruling 27).
##
## "A Blast one area centered on you." For a Koremasa on foot that is a 3x3, which a size-1 marker's
## BURST 1 already is. For a RIDER it is the mount's footprint plus 1, because a rider occupies the
## mount's whole space (occupying_size, unit_battle_state.gd:211) - and a size-1 marker at the shared
## anchor cannot project that. AoeCalculator.burst takes the ORIGIN SIZE as an argument
## (range_pattern.gd:46), so this reads it from the zone gear's own state, where action_vanish.gd
## writes the Koremasa's occupying_size at the moment the smoke is laid. Gear state is an exported
## Dictionary, so the footprint survives a save and a load.
##
## Why not a sized frame per mount size, the Shackleton crater's inline size-2 statblock: a mount can
## be size 1, 2, 3 or larger, and one frame per size is a table to keep in step for no gain. Why not a
## duplicated frame at lay time: a runtime Frame is not a resource on disk, and its trait Kits lose
## their lazily derived compcon_id (koremasa_fixture.gd's header).
##
## The fx follow for free: PassiveTerrainZone.get_attached_fx walks get_voxels_to_apply_terrain.
## An ordinary subclass used by our own resource, not a .gd_ext.gd, so Godot bug #83542 does not apply.
extends PassiveTerrainZone

## Gear state key: the origin size the burst is measured from. Absent = the marker's own size.
const FOOTPRINT_KEY := 'reag_footprint'

func get_voxels_to_apply_terrain(gear:GearCore, unit_core:UnitCore, state:UnitBattleState) -> Array[Vector3i]:
	var map:MapState = X.map()
	var size:int = state.occupying_size
	if GearCore.is_valid(gear): size = maxi(size, int(gear.get_state(FOOTPRINT_KEY, size)))
	if map == null or range_pattern == null or size <= state.occupying_size:
		return super(gear, unit_core, state)
	# UnitTile.get_voxels_from_pattern's own body (unit_tile.gd:393-397), with the origin size swapped.
	var aoe_height:int = height if height > 0 else range_pattern.value
	var starting_height:int = map.elevation_ground(state.tile)
	var voxels:Array[Vector3i] = []
	voxels.assign(RangePattern.get_aoe_voxels(
		range_pattern.pattern, range_pattern.value, starting_height, aoe_height,
		state.tile, state.tile, size, map.shape
	))
	return voxels
