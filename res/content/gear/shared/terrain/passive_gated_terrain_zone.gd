# A PassiveTerrainZone that projects NOTHING until a named key in its owning gear's state says so.
#
# WHY IT HAS TO EXIST. MapState.add_dynamic_terrain_and_zones_from_unit collects every
# PassiveTerrainZone on every gear of every unit UNCONDITIONALLY (map_state.gd:427-432). There is no
# per-zone switch: GearCore has is_aura_active for PassiveAura and is_dynamic_zone_active for
# PassiveDynamicZone, and nothing at all for a terrain zone. So a zone sitting on a Kit is ON from the
# moment the Kit is equipped, and overriding the voxel list is the ONLY way to keep it dark until an
# action lights it. Thy Hubris' passive_poisoned_soil.gd overrides the same function for the same
# structural reason (an arbitrary remembered tile set rather than a gate).
#
# ITS FIRST CONSUMER IS SP2's Grav-Amped Interference field, whose protocol sets
# gear.set_state('grav_amped', true) and whose passive_grav_amped_field.tres sets
# state_key = &"grav_amped". A later frame with a switchable field is the second. It is born here, in
# the shared folder, because it is a mechanism rather than a card.
#
# GEAR STATE SERIALISES. GearCore.state is an exported Dictionary, so a field lit by a protocol is
# still lit after a save/load, with no bookkeeping.
#
# This is an ordinary subclass of a class_name script used by our own resource, NOT a .gd_ext.gd
# engine extension, so Godot bug #83542 does not apply.
extends PassiveTerrainZone

## The key in the owning GEAR's state dictionary that has to be true for this zone to project.
##
## Empty by default, and an empty key means DARK rather than lit: an unconfigured zone that defaulted
## to projecting would put terrain on the map that no author asked for, and the failure would look
## like a bug in whatever walked through it.
@export var state_key:StringName = &''

func get_voxels_to_apply_terrain(gear:GearCore, unit_core:UnitCore, state:UnitBattleState) -> Array[Vector3i]:
	var dark:Array[Vector3i] = []
	if not GearCore.is_valid(gear): return dark
	if state_key == &'': return dark
	# GearCore.get_state takes a STRING key, not a StringName (gear_core.gd:259), and asserts the
	# default is not an Array. A StringName passed straight in would never match a key written by
	# set_state('grav_amped', true).
	if not gear.get_state(String(state_key), false): return dark
	return super(gear, unit_core, state)
