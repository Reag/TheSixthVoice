# EFFICIENT: a core power that hands its Core Point back at the end of a scene it was used in. Born
# with the Maiden's Blush's Step of Mist and Thunder (SP2); consumers to come are the Lovers Knot and
# Black Mountain.
#
# FROZEN INTERFACE (roadmap §4, design §2.5): mark_used, is_marked, refund, and the USED_KEY they
# share. A consumer does two things - call Efficient.mark_used(gear) where it spends, and put an
# action_efficient_refund.tres on its core Kit pointing at the sibling script in this folder.
#
# THE STAMP IS GEAR STATE, AND A CONSUMER MUST ALSO CARRY passive_efficient_used.tres FROM THIS
# FOLDER. That is not optional decoration: GearCore.short_repair throws away ALL gear state except
# the keys of PassiveDieCounter passives with resets_on_spawn = false (gear_core.gd:144-150), and
# every spawn runs short_repair (unit_printer.gd:8-10 via map_bus.gd:8). Measured 2026-09-17 - see
# that .tres's header for the trace. Without the passive the stamp is serialised faithfully and then
# wiped before any UNIT_SPAWN reaction can read it, and the refund's safety net is dead code.
#
# A full repair clears the whole loadout's state AND restores the point by itself
# (gear_core.gd:154, unit_printer.gd:76), so the stamp going with it is correct rather than a loss.
#
# CONDITIONAL ON THE STAMP, unlike Thy Hubris' action_cupiditas_vitae_efficient and the Barbarossa's
# action_regain_cp.gd, which restore the point unconditionally on spawn. Unconditional is safe on a
# frame whose ONLY core-point spender is the Efficient ability - a mech has exactly one core power -
# and this helper is shared, so a later consumer's core Kit may hold an action that spends the point
# and is not Efficient. The stamp is what tells those two apart.
#
# No class_name (res/content/gear/shared/README.md): global class names are registered from
# project.godot's class list, built at startup, so one declared in a script a mod loads at runtime is
# never registered. Callers preload this file.
extends RefCounted

## Loaded the way the engine's own Action does it (action.gd:29) and the way this mod already does it
## in Thy Hubris' acid_spill_highlight.gd:27. It is a `static var` but not mutable state: it is a
## handle on a bus resource, assigned once at script load and never written.
static var battle_log:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

## The gear-state key, and it MUST match passive_efficient_used.tres's `key` exactly - that passive is
## what keeps this value alive across a spawn, and it preserves by key.
##
## A String, not a StringName: GearCore.state is a plain Dictionary that goes through JSON, where
## StringName keys do not survive the round trip (gear_core.gd:282 says so about string arrays for the
## same reason).
const USED_KEY := 'efficient_used'

## 0 unused, 1 used. Ints rather than a bool because the value lives in a PassiveDieCounter's slot,
## whose starting_value is an int and whose preserve loop defaults a missing key to it.
const UNUSED := 0
const USED := 1


## Stamp the gear as used. Called by the consumer WHERE IT SPENDS, not where it succeeds: a boxed-in
## Step of Mist and Thunder that spends the core point and the quick action and then fizzles without
## moving still refunds (ruling 9 and ruling 15).
static func mark_used(gear:GearCore) -> void:
	if not GearCore.is_valid(gear): return
	gear.set_state(USED_KEY, USED)


static func is_marked(gear:GearCore) -> bool:
	if not GearCore.is_valid(gear): return false
	return gear.get_state(USED_KEY, UNUSED) == USED


## Give the point back, once. Returns whether it actually did.
##
## THE RETURN VALUE IS THE POINT OF THE SIGNATURE, and it is what makes this idempotent: the refund
## fires from TWO triggers (combat_end for a living mech, unit_spawn as the safety net for one that
## was destroyed or Stunned), and erasing the stamp before returning is what stops the second one
## handing back a second point in the scene after.
##
## SET BACK TO UNUSED, NOT ERASED, which is the opposite of what the Barbarossa's action_regain_cp.gd
## does (it reaches into gear.state.erase). The key is a PassiveDieCounter's slot, and short_repair's
## preserve loop writes `state.get(key, starting_value)` back on every spawn - so an erased key simply
## reappears as starting_value, and erasing it buys nothing while diverging from the passive's model of
## its own value.
static func refund(unit:Unit, gear:GearCore) -> bool:
	if not Unit.is_valid(unit): return false
	if not is_marked(gear): return false
	gear.set_state(USED_KEY, UNUSED)
	unit.core.has_core_power = true
	battle_log.log_gear(&'gear.shared.efficient.refund.log', unit, gear)
	return true
