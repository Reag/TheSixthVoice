# OVERSHIELD: the mod's shared reader and granter. Born with the Myconid's Halo (SP1 Task 4).
#
# FROZEN INTERFACE (roadmap 4, and design 1.3 of the Myconid). Five functions, exactly these names
# and signatures. Five later frames consume them - Sluagh, Hazard, Naga, Primrose, Black Mountain -
# so a rename is five frames' worth of churn. A later frame that needs MORE extends this file in its
# own sub-project, with every earlier spec still green; "granted by" tracking is explicitly not born
# here, and is assigned to Black Mountain's SP1.
#
# No class_name (lancer-tactics-gdscript skill, and res/content/gear/shared/README.md): global class
# names are registered from project.godot's class list, which is built at startup, so one declared in
# a script a mod loads at runtime is never registered and cannot be referenced by that name at all.
# Callers preload this file. Same shape as Thy Hubris' infection.gd, which is the mod-side precedent
# for the whole pattern.
#
# THE ONE ENGINE RULE WORTH KNOWING: event_unit_overshield sets
# state.overshield = max(0, max(old, amount)) (event_unit_overshield.gd:15). It NEVER adds. Every
# card that says "gains OVERSHIELD equal to X" wants exactly that, which is what grant() is; the
# handful that say "increases by that much instead" want increase(), which is the same event handed
# current + X.
extends RefCounted

const OVERSHIELD_EVENT := &'event_unit_overshield'

## This unit's overshield. 0 for anything that is not a live Unit - every consumer calls this from
## inside a reaction gate, which the bus runs for every unit's every gear on every event, so a null
## here would be an error storm rather than a wrong answer. Unit.is_valid includes is_alive, so a
## DEAD unit reads 0 here too, not whatever overshield it held before dying.
static func current(unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	return unit.state.overshield

## True only above zero - see current() for what makes a unit read as having none.
static func has(unit:Unit) -> bool:
	return current(unit) > 0

## Grant `amount` overshield, the engine's way: the target ends with max(what it had, amount).
##
## amount <= 0 IS A NO-OP AND FIRES NO EVENT. The event always plays a popcorn and writes a battle
## log line (event_unit_overshield.gd:17-22), so a zero grant would put "now has 0 overshield" on
## screen and in the log - which is what a Grit 0 pilot's Halo would do on every hit it took.
##
## Runs the event on the caller's own block when there is one, and through the level when there is
## not. Infection.apply's idiom, for the same reason: a caller inside a live activation wants its
## event ordered inside that activation, and a caller holding a spec's dummy event (or no event at
## all) has no block to queue onto.
static func grant(event:EventCore, target:Unit, amount:int) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	var data := {unit = target, number = amount}
	if event != null and event.is_block_valid():
		await event.execute_event(OVERSHIELD_EVENT, data)
		return
	var level := X.current_level()
	if level != null: await level.execute_event(OVERSHIELD_EVENT, data)

## Additive: the target ends with what it had PLUS amount. For the cards that say "increases by that
## much instead" - Black Mountain's Exalt, Fell the Mighty, Dread Harbinger.
##
## Built on grant() rather than on state.overshield directly, so it inherits the no-op, the validity
## guard and the event plumbing rather than re-deriving them.
static func increase(event:EventCore, target:Unit, amount:int) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	await grant(event, target, current(target) + amount)

## The pilot's Grit: half licence level, ROUNDED UP (PilotCore.get_grit -> Util.half -> ceili,
## util.gd:14-15; the engine's own glossary row for lancer.term.grit says "rounded up" too). So only
## licence level 0 is Grit 0.
##
## Guarded the Aceso way (action_aceso_stabilizer.gd:9): deployables, drones and NPC props have no
## pilot at all, and a gate that dereferenced one would throw from inside a reaction poll.
static func grit(unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	if not PilotCore.is_valid(unit.core.pilot): return 0
	return unit.core.pilot.get_grit()
