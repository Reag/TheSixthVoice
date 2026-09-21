# OVERSHIELD: the mod's shared reader and granter. Born with the Myconid's Halo (SP1 Task 4).
#
# FROZEN INTERFACE (roadmap 4, and design 1.3 of the Myconid). Five functions, exactly these names
# and signatures. Five later frames consume them - Sluagh, Hazard, Naga, Primrose, Black Mountain -
# so a rename is five frames' worth of churn. A later frame that needs MORE extends this file in its
# own sub-project, with every earlier spec still green; "granted by" tracking is explicitly not born
# here, and is assigned to Black Mountain's SP1.
#
# ADDITIONS ARE ALLOWED AND ONE HAS LANDED. The Sluagh (SP1 Task 4) needed grant() to refresh the
# target's cached stats after the event, because its Inexorable Formation reads Overshield through a
# STATBLOCK buff and nothing else rebuilds that cache. No signature moved; see grant()'s own header.
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
##
## IT REFRESHES THE TARGET'S CACHED STATS AFTERWARDS - THE ONE ADDITION TO THIS FROZEN FILE (the
## Sluagh, SP1 Task 4, ruling 12). Its Inexorable Formation is a Buff.TO.STATBLOCK buff whose
## get_values reports the holder's CURRENT Overshield as a sensor-range bonus, and state.stat_bonus
## is rebuilt only by UnitBattleState.update_cached_values (unit_battle_state.gd:229-234), which
## event_unit_overshield never calls - its whole body is one assignment, a popcorn and a log line.
## The reaction bus has no overshield trigger to hang a listener on (reaction_bus.gd:9-42), so
## without this line every gain through this helper would be invisible to that frame's Sensors until
## something unrelated rebuilt the cache. Overshield the Sluagh gains from a VANILLA or third-party
## source is still seen only at the next rebuild; that lag is recorded and cosmetic (design 1.4).
##
## NO EVENT IS PASSED TO THE REFRESH, and that matters. update_cached_values_and_token(event) with a
## NON-null event runs UnitTile.move_to(self, tile, true, event) -> update_tracking_and_statuses
## (unit.gd:158-160, unit_tile.gd:12), a MAP-WIDE pass that re-evaluates every aura, engagement and
## water status on every unit and can queue real events. On every Overshield grant in the game that
## would be both expensive and wrong: a shield gain is not a tile update. The bare form refreshes the
## cached values and the token and stops, which is what buff_effervescent_immunity does for the same
## reason.
##
## increase() INHERITS THIS AND DOES NOT REPEAT IT. It calls grant() with current + amount behind its
## own amount <= 0 guard, so the value it passes is always positive and grant can never take the
## early return above without doing the refresh. test_increase_refreshes_the_cache_too_by_inheriting_grants
## is the pin.
##
## THE TWO BRANCHES ARE AN if/else NOW, where they used to be an if-with-a-return. Nothing about
## which event runs changed; the shape changed so that one refresh sits after both paths instead of
## being written twice.
static func grant(event:EventCore, target:Unit, amount:int) -> void:
	if amount <= 0 or not Unit.is_valid(target): return
	var data := {unit = target, number = amount}
	if event != null and event.is_block_valid():
		await event.execute_event(OVERSHIELD_EVENT, data)
	else:
		var level := X.current_level()
		if level != null: await level.execute_event(OVERSHIELD_EVENT, data)
	# Re-checked: the event ran, and something reacting to it could in principle have removed the
	# target from the game.
	if Unit.is_valid(target): target.update_cached_values_and_token()

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
