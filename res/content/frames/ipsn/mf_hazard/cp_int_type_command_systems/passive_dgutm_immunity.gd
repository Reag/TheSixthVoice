# DONT GIVE UP THE MECH's immunity (Hazard, cp_int_type_command_systems), ruling 7 - author's ruling:
# an AURA WHILE ADJACENT, not a snapshot. A range-1 PassiveAura switched on by buff_dgutm_active on the
# Hazard (requires_buff, the .tres). The Hazard carries both buffs for the scene; an ally carries them
# while adjacent and loses them when it steps away (passive_aura.gd strips out of range).
#
# "ALLIED CHARACTERS": is_actor() (the mod-wide row) - a drone is a character and is excluded here.
# The Hazard itself passes the early return.
#
# ADJACENCY IS MEASURED BY THE AURA (distance_between), so House Guard does NOT widen it (author's
# ruling; spec/test_compat.gd).
extends PassiveAura

func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super(moving_unit, aura_unit, aura_gear): return false
	if moving_unit == aura_unit: return true
	return moving_unit.is_character()
