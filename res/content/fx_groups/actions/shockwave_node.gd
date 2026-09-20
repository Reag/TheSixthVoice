## SPIN'S SHOCKWAVE - the ring emitter (Primrose rank III, Flourishing Twirl).
##
##   "Spin (Quick): Choose a weapon you have mounted, all hostile characters within its threat and
##    line of sight must succeed an Agility save or take 4 kinetic damage and become Impaired until
##    the end of their next turn."
##
## The wave travels exactly as far as the chosen weapon reaches, which is why this node exists at
## all: the radius is not known until the player picks a weapon, and a PackedScene cannot carry it.
##
## ================== HOW THE RADIUS GETS IN ==================
##
## FxGroup.create_from_scene calls initialize and RETURNS THE GROUP (fx_group.gd:101-113); run() is
## the caller's to make. So a caller may configure a group in between, and vanilla does exactly that
## - event_unit_damage.gd:225-233 is create_from_id -> scale_bumps -> run. action_spin.gd's
## fire_shockwave is the same three lines with set_radius_in_tiles in the middle. No static-var
## handshake, no run_system_fxgs override; the engine already has the seam.
##
## ================== WHY THE MESH IS 2x2 ==================
##
## Tile.SIZE is Vector3(1.0, 0.5, 1.0) (tile.gd:15), so one tile is 1.0 world unit in X and Z. The
## scene's QuadMesh is size (2, 2), so a particle at scale S draws a ring of DIAMETER 2*S, i.e.
## RADIUS S tiles. The mesh size was chosen to make set_radius_in_tiles a straight assignment with
## no conversion factor to get wrong. Change the mesh and the arithmetic below is wrong;
## test_set_radius_in_tiles_scales_the_emitter is what notices.
##
## ================== WHY IT DUPLICATES BEFORE WRITING ==================
##
## A ParticleProcessMaterial set in a PackedScene is SHARED by every instance of that scene. Writing
## the scale straight onto it would make the last Spin's radius apply to every ring already on
## screen - and with no error, because sharing an exported sub-resource is what Godot is supposed to
## do. Wickworks hit the identical defect and left the note in line_3d_anchored.gd:52:
## `points = [] # they were all sharing the same array`. resource_local_to_scene on the sub-resource
## would also fix it (fxg_celestial_shackle.tscn does it that way), but a flag in a .tscn is exactly
## the thing an inspector save can drop, and this is a one-line guarantee at the point of the write.
## test_two_rings_do_not_share_a_process_material holds it.
##
## ================== WHAT DRIVES IT ==================
##
## Nothing here starts the emitter. FxGroup.activate_emitter sets emitting = true and show() on
## every GPUParticles3D child during run() (fx_group.gd:330-339), and hides it beforehand as a plain
## Node3D during initialize (:172-173). This node only has to be the right type and carry the right
## numbers.
extends GPUParticles3D

## Has the shared process material been replaced with this instance's own copy yet? See the header.
var _owns_process_material:bool = false

## Set the ring's final radius, in TILES. Call between FxGroup.create_from_scene and FxGroup.run.
func set_radius_in_tiles(tiles:int) -> void:
	# A radius of zero is not a ring. Spin cannot reach this today - collect_mounted_profiles only
	# yields weapons whose printed threat is above zero - but the method is public and the next
	# caller will not know that. Leaving the previous value alone rather than clamping to some
	# minimum keeps a bad call visible in the FX tester instead of silently drawing a dot.
	if tiles <= 0: return
	if process_material == null: return

	if not _owns_process_material:
		process_material = process_material.duplicate()
		_owns_process_material = true

	process_material.scale_min = float(tiles)
	process_material.scale_max = float(tiles)
