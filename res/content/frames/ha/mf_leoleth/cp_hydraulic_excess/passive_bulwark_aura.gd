# BULWARK's dome (ruling 13): every hostile CHARACTER in the Leoleth's line of sight carries
# buff_bulwark_penalty while the Leoleth holds buff_rage_bulwark.
#
# EXTENDS PassiveAura DIRECTLY, AND MUST. Kit.is_passive_of_type matches the script or its DIRECT
# base and its own comment says "only goes one layer deep" (kit.gd:161-165); LoadoutCore indexes aura
# gear with kit.has_passive_type(PassiveAura). A subclass of a subclass would never be indexed, the
# aura would never run, and every resource assertion about it would still be green. Same note as
# passive_mark_cover_aura.gd, one frame over.
#
# "CHARACTER" HERE IS is_character(): a drone is a character, included (rulings.md, mod-wide row of
# 2026-09-27, reversing row 301/ruling 22). PassiveAura's own applies_only_to_characters clause is
# already moving_unit.is_character() (passive_aura.gd:73), so this override no longer narrows that
# test - it stays for the hostility check below, which the base aura cannot express.
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
#
# A SECOND OVERRIDE, ADDED FOR THE SAME CARD: HOSTILITY (bug fix, Leoleth frame close). The card says
# "ALL HOSTILE characters", and nothing above checked hostile. passive_aura.gd's three flags are
# EXCLUSIONS, not inclusions: "if not applies_to_allies and are_allies(...): return false" (:70) and
# "if not applies_to_enemies and are_enemies(...): return false" (:71). The .tres sets
# applies_to_enemies = true, which makes `not applies_to_enemies` false FOREVER, so the :71 branch can
# never return false - that does not mean "allow enemies", it means "this exclusion is switched off
# entirely". applies_to_allies = false only excludes an actual ALLY (:70). NEITHER clause excludes a
# Faction.NONE unit, because Faction.is_ally and Faction.is_enemy both read NONE as neither: the
# SIDE.NONE arm of is_enemy returns false (faction.gd:22-27, specifically :24) and the SIDE.NONE arm
# of is_ally also returns false (:29-36, specifically :32) - the enum's own doc comment says as much
# ("NONE is allied nor enemies with anyone", faction.gd:9). UnitRelation.can_affect, the other gate
# super() runs, does not touch faction at all (unit_relation.gd:393-404, read in full: exile,
# intangibility and shard membership, nothing about SIDE). So a genuinely neutral character - a
# hostage, a piece of wildlife, anything built the way tool_units.gd:419-428's `bod_` frames are -
# passed every clause above unfiltered. The card says HOSTILE; nothing here checked that.
#
# UnitRelation.are_enemies IS EXACTLY THE MISSING PREDICATE: Faction.is_enemy(moving_unit's faction,
# aura_unit's faction) (unit_relation.gd:361-362), which a Faction.NONE moving_unit fails outright.
#
# BELT AND SUSPENDERS, NOT DEAD CODE. As things stand, no Faction.NONE unit can reach this function's
# `true` at all, by a SECOND and entirely independent route: Unit.is_active() itself demands
# get_faction() != Faction.NONE (unit.gd:111), and is_character() requires is_active() (unit.gd:116)
# - so the is_character() check above already excludes it before this line ever runs.
# Verified against this mod's own construction path: SpecFactory.create_unit(map, tile, Faction.NONE)
# builds a real CHARACTER-entity frame (Frame.create_dummy() defaults entity_type to
# ENTITY.CHARACTER, frame.gd:63, :88-91) with that faction, and its is_character() is unconditionally
# false regardless of frame type, purely because of the faction clause in is_active(). The hostility
# check below stays anyway: it is what the CARD says, it is what THIS function is for, and it must
# not depend on an invariant that lives in a different file and that nothing here enforces - a change
# to Unit.is_active() elsewhere would silently reopen this hole otherwise.
extends PassiveAura

func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super.can_apply_buff_to_unit(moving_unit, aura_unit, aura_gear): return false
	if not moving_unit.is_character(): return false
	# "ALL HOSTILE characters" - the aura's applies_to_enemies=true flag cannot express an exclusion,
	# see header, so the hostility test is explicit here instead.
	return UnitRelation.are_enemies(moving_unit, aura_unit)
