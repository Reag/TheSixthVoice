# Script extension on the UnitPrinter autoload - the mod's SECOND autoload extension (the first is
# unit_relation.gd_ext.gd, whose header explains why a .gd_ext.gd's PATH is its declaration and
# every rule for this file has to live here, each under its own banner).
#
# The install log is NOT evidence that any override here runs; spec/test_spike_unit_printer_seam.gd
# is (it measures the override from the structure check's real entry points, at both depths the
# ONE-LEVEL rule allows), and mod_main.gd's EXTENDED_AUTOLOADS entry is load-bearing: without the
# deferred reload the live node keeps its pre-extension script (upstream bug 5, unfixed in 1.4.3).
# gavstarb-ssc_emperor (resident) extends this same file for full_repair and calls super; so does
# Thy Hubris for this very function. All three compose in any install order because each calls
# super first - spec/test_compat.gd pins ours against the resident.
#
# ============================================================================================
# THERMAL DEATH AXE (Leoleth, mw_thermal_death_axe) - "this weapon can be destroyed even if it has
# no charges remaining."
#
# Vanilla's get_destructable_gear (unit_printer.gd:311-320) requires gear.has_charges_left(), which
# for a Limited kit means charges_current > 0 (gear_core.gd:249). Right for Limited gear in general -
# an empty Stub Cannon is not a system that can be shot off - but the axe's card says the opposite
# in so many words, so it is whitelisted here by kit id. Nothing else changes: kit.is_destructable()
# and not gear.is_destroyed still apply, and every other kit goes through the vanilla check.
#
# Reached from event_unit_structure.execute_structure_check_result two ways: LoadoutCore
# .get_destructable_gear (level 0, qualified through the node) for mount-less units, and
# LoadoutCore.get_destructable_mounts -> vanilla get_destructable_mounts -> UNQUALIFIED
# get_destructable_gear (level 1) for mechs with mounts, which the Leoleth is. Both measured.
#
# Why an extension and not a Kit property: Kit has no "destructible while empty" export and the
# base game is off limits. Design: specs/2026-09-21-leoleth-design.md ruling 15.
#
# BINDING FANGS (Naga, mw_binding_fangs) joined the list at Naga SP3 - its card carries the same
# sentence, "this weapon can be destroyed (due to critical damage or other effects) even if it has
# no charges remaining". One id appended, nothing else changed (specs/2026-09-22-naga-design.md
# ruling 14); spec/test_binding_fangs.gd and spec/test_compat.gd pin it.
#
# FLEX SECONDARY - ONLY AS THE PRIMARY (Naga frame close, author decision 5). Leoleth's recorded
# choose_to_destroy warning: a structure check's DESTROY_WEAPON offers MOUNTS
# (event_unit_structure.gd:176), and picking one destroys its PRIMARY whenever it has one (:213-214).
# The axe is HEAVY and always a primary, so it never met this; the Fangs are AUX and fit a flex
# mount's secondary. Beside an empty Limited aux primary (mw_stub_cannon), an empty Fangs secondary
# made the mount destructible through the whitelist and the pick destroyed the empty primary - a
# weapon vanilla says cannot be. So get_destructable_mounts drops a mount whose ONLY destructible
# gear is an empty whitelisted secondary: in that niche the Fangs survive rather than the wrong weapon
# going. A secondary WITH charges is vanilla's own business and untouched. super-first, so the
# resident and Thy Hubris compose as before; the level-1 dispatch the probe measured is kept
# (super.get_destructable_mounts keeps the instance for its one level - memory
# lancer-tactics-extension-seams), and spec/test_spike_unit_printer_seam.gd still measures it.
# ============================================================================================
extends "res://engine/character/unit/service/unit_printer.gd"

## Kits whose rules text says they stay destructible with no charges left.
const DESTRUCTIBLE_WHILE_EMPTY:Array[StringName] = [&'mw_thermal_death_axe', &'mw_binding_fangs']

static func get_destructable_gear(gear_list:Array[GearCore]) -> Array[GearCore]:
	var destructable_gear := super.get_destructable_gear(gear_list)
	for gear:GearCore in gear_list:
		if destructable_gear.has(gear): continue
		if not GearCore.is_valid(gear) or gear.is_destroyed: continue
		if not gear.kit.is_destructable(): continue
		if not DESTRUCTIBLE_WHILE_EMPTY.has(gear.kit.compcon_id): continue
		destructable_gear.append(gear)
	return destructable_gear

## The whitelist counts toward a MOUNT only as its PRIMARY - see the banner above (FLEX SECONDARY).
static func get_destructable_mounts(from_mounts:Array[MountCore]) -> Array[MountCore]:
	var destructable_mounts := super.get_destructable_mounts(from_mounts)
	return destructable_mounts.filter(func(mount:MountCore) -> bool:
		return not is_destructable_only_by_an_empty_whitelisted_secondary(mount))

## True when the one thing making `mount` destructible is a whitelisted Kit, EMPTY, in its secondary
## slot - vanilla would have refused that gear, and the pick would destroy the primary instead.
## Qualified through the node so every extender's whitelist is asked (the chain dispatches fully).
static func is_destructable_only_by_an_empty_whitelisted_secondary(mount:MountCore) -> bool:
	var secondary := mount.slot_secondary
	if not GearCore.is_valid(secondary): return false
	if not DESTRUCTIBLE_WHILE_EMPTY.has(secondary.kit.compcon_id): return false
	if secondary.has_charges_left(): return false # vanilla admits it on its own
	var destructable := UnitPrinter.get_destructable_gear(mount.get_gear())
	destructable.erase(secondary)
	return destructable.is_empty()
