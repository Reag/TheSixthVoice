# WEIGHT OF FIRE's aura (Hazard, mt_weight_of_fire), ruling 2: the Hazard and "adjacent allied
# mechs". The Vauban's Gravity Well shape (passive_gravity_well_aura.gd): range 1, self and allies,
# not enemies, on the .tres; this script adds the one clause the base class cannot express -
# MECHS. applies_only_to_characters is not enough, because a drone is a character (unit.gd:116);
# the card says mech, so is_mech() (is_character() is the mod-wide rule for "character", ruling
# 2026-09-27 - a drone included there, but never a mech).
#
# ADJACENCY IS MEASURED BY THE AURA (passive_aura.gd:85, distance_between against aura_range), so a
# third-party widening of adjacent_characters (House Guard) does NOT reach this - author's ruling,
# pinned by spec/test_compat.gd.
#
# The Hazard itself passes the early return: it is a mech anyway, and the card's first clause is
# about "the Hazard", not about what it is.
#
# An ordinary subclass of a class_name script used by our own resource, NOT a .gd_ext.gd engine
# extension, so Godot bug #83542 does not apply.
extends PassiveAura

func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super(moving_unit, aura_unit, aura_gear): return false
	if moving_unit == aura_unit: return true
	return moving_unit.is_mech()
