# BULWARK's dome (ruling 13): every hostile CHARACTER in the Leoleth's line of sight carries
# buff_bulwark_penalty while the Leoleth holds buff_rage_bulwark.
#
# EXTENDS PassiveAura DIRECTLY, AND MUST. Kit.is_passive_of_type matches the script or its DIRECT
# base and its own comment says "only goes one layer deep" (kit.gd:161-165); LoadoutCore indexes aura
# gear with kit.has_passive_type(PassiveAura). A subclass of a subclass would never be indexed, the
# aura would never run, and every resource assertion about it would still be green. Same note as
# passive_mark_cover_aura.gd, one frame over.
#
# THE ONE OVERRIDE IS is_actor(). PassiveAura's own applies_only_to_characters clause is
# moving_unit.is_character() (passive_aura.gd:73), and Unit.is_character() returns TRUE for a drone -
# its own comment says "active mech/pilot/drone" (unit.gd:116). Every "character" on this frame is
# is_actor() (ruling 22), so the narrowing goes here.
#
# MARKERS NEED NO CLAUSE: PassiveAura.update_unit returns on its first line for a marker (:25), so the
# Decimate crater never enters the dome.
#
# RANGE 99 PLUS applies_only_when_in_los IS "line of sight" AND NOTHING ELSE. is_within_range asks
# UnitRelation.distance_between first and can_see second (:84-92); a unit off the map reads the 1000
# sentinel, so 99 is "anywhere on this map" without being unbounded.
#
# THE DOME GOES UP IN THE SAME EVENT AS THE CHIP, with no explicit tracking pass, because
# UnitCondition.apply_buffs sets update_tracking_and_statuses when the applying gear's Kit
# has_passive_type(PassiveAura) and ends in post_apply_buff_cache_update -> update_cached_values_and_token
# -> UnitTile.move_to -> update_tracking_and_statuses -> PassiveAura.update_unit
# (unit_condition.gd:703-715, unit_tile.gd:12, :24). The RAGE roll applies the chip FROM this Kit
# (Action.apply_buffs passes event.context.gear, action.gd:370-371), so that chain runs. A unit that
# MOVES afterwards is caught by its own move_to.
extends PassiveAura

func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super.can_apply_buff_to_unit(moving_unit, aura_unit, aura_gear): return false
	return moving_unit.is_actor()
