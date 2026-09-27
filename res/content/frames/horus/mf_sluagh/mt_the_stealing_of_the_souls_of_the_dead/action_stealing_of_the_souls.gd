## THE STEALING OF THE SOULS OF THE DEAD: the Sluagh feeds on every hostile that falls in its reach.
##
##   "Whenever a hostile character is destroyed within Sensors, the Sluagh gains OVERSHIELD equal to
##    GRIT."
##
## HALO'S FILE, RE-GATED. The Myconid's action_halo.gd is the same shape - a hidden, point-free
## ActionReaction on a trait Kit that grants Overshield through the shared helper - and the three
## differences are all in this header: a different trigger, no per-round limit, and no prompt.
##
## DEATH / POST, AND THE DEAD UNIT IS STILL READABLE THERE. event_unit_die sets current.health to 0
## (:75-77), queues its POST reactions (:80-81, whose own comment says "before we actually remove the
## unit, so triggers can inspect who died") and only then calls EventService.remove_unit_from_game
## (:83). EventCore.queue_reaction_events runs reaction_bus.trigger_occurred SYNCHRONOUSLY
## (event_core.gd:59-61), so this gate is evaluated while the unit is on the map, valid and at its
## tile: Unit.is_alive is set false only in Unit.remove_from_game (unit.gd:133), and is_active() reads
## core.frame.stat.health - the frame's MAXIMUM - rather than the zeroed current block (unit.gd:110).
## A meltdown reaches the same event: event_unit_meltdown executes event_unit_die itself at :63.
##
## activate() RUNS LATER, after the die event's body has drained, so it reads NOTHING about the dead
## unit. It grants to the Sluagh and stops.
##
## ===================================================================================================
## "CHARACTER" ON THIS FRAME, AND ACROSS THE MOD, IS Unit.is_character() - A DRONE IS A CHARACTER.
## THIS PARAGRAPH IS THE CANONICAL ONE; every other site cites it rather than re-arguing it.
##
## AUTHOR'S RULING, 2026-09-27 (mod-wide), REVERSING THE 2026-09-21 "row 301" RULING that had unified
## the mod on `is_actor()` instead. The LCP's own DRONE tag settles the membership question: "Drones
## are Size 1/2 characters." Objects, markers, deployables and wrecks are still NOT characters -
## Frame.ENTITY.OBJECT and is_active() already exclude them, with no clause of ours involved.
## `test_a_hostile_object_death_grants_nothing` is the standing pin on that half.
##
## WHAT SURVIVES IS ATTRIBUTION, a different question: where a card asks WHO did something, the actor
## still resolves through `Unit.get_attacker(context)` / `get_owner_unit_or_self()` - an OWNED drone's
## hit still counts as its OWNER'S. mt_wicked_host is this frame's one attacker-side clause and that
## code is unchanged by this ruling. What changed is that, after that resolution, an UNOWNED drone
## (which resolves to itself) now PASSES the character test too.
##
## `is_mech()` clauses (ruling 194, the Vauban's Gravity Well) are untouched: a drone is still not a
## mech.
##
## THE HUNT'S "CLOSEST CHARACTER" PROBLEM THAT MOTIVATED THE 2026-09-21 REVERSAL IS SOLVED
## DIFFERENTLY NOW: its search excludes whatever unit HOLDS the target (any engager, drone or not),
## not by excluding drones from being characters - see spec/test_hunt.gd.
##
## THIS IS THE ONE SITE WHERE THE CLAUSE IS LOAD-BEARING ON ITS OWN. This is a plain ActionReaction
## with no archetype gate above it, so deleting the line below would let an object's death grant, not
## merely a drone's. The other sites narrow a flag their archetype already applies; each says so in
## its own header.
## ===================================================================================================
##
## NO PER-ROUND LIMIT, unlike Halo. The card names none, so ActionReaction's own 99 for a point-free
## reaction (action_reaction.gd:69) is left alone: one Blast that destroys three hostiles grants three
## times, and every one of them is a separate event_unit_die.
##
## NO LINE OF SIGHT (Halo's reading, ruling 11). Bel writes "within Sensors and line of sight" when
## sight is meant - three times on Black Mountain alone - so bare "within Sensors" is range only.
##
## THE SENSORS VALUE IS READ LIVE, which is Inexorable Formation's whole point (ruling 11 says so
## explicitly). unit.get_sensor_range() is core.get_sensor_range() + state.stat_bonus.sensor_range
## (unit.gd:305), and the STATBLOCK buff Task 5 adds moves the second term. Nothing here caches it.
extends ActionReaction

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## Bookkeeping, not a rule the player reads twice: the trait card's effect row says everything there
## is to say, and a reaction never reaches the gear bar anyway. show_in_tooltip is a FUNCTION on
## Action (action.gd:341), not an exported property, so this is the only way to set it - the same as
## Halo's, ms_heaer's detonate and mt_blasting_powder's spend reaction.
func show_in_tooltip(_kit:Kit) -> bool: return false

## DELIBERATELY EMPTY, overriding the empty default only to say so out loud. A required triggering
## prop is re-checked at execution time, not only at collection time (event_gear_activate.gd:37), and
## the one prop this reads - context.unit, the dead unit - is exactly the thing that stops being
## valid between the queueing and the activation. Requiring it would abort every activation this
## ability exists for. Halo's reasoning, verbatim.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var dead:Unit = triggering_event.context.unit
	if not Unit.is_valid(dead): return false
	if dead == unit: return false
	# A CHARACTER - is_character(), a drone included (ruling 2026-09-27, mod-wide; see the header).
	# Still excludes an object, a marker or a wreck, and this is the one site on the frame with no
	# archetype gate above it.
	if not dead.is_character(): return false
	if not UnitRelation.are_enemies(unit, dead): return false
	# LIVE Sensors, on both sides of the comparison being a live read: distance_between measures
	# closest tiles, and the dead unit still occupies its own.
	if UnitRelation.distance_between(unit, dead) > unit.get_sensor_range(): return false
	# Grit 0 grants nothing, and Overshield.grant refuses an amount of 0 outright - so without this
	# the reaction would be offered, spend nothing, and write a battle-log line saying the Sluagh now
	# has 0 overshield, on every enemy death, for the whole of licence level 0. Halo's own gate.
	return Overshield.grit(unit) > 0

## NO PROMPT (ruling 11: automatic). Unlike Halo, which asks because it chooses an ALLY, this grants
## to the Sluagh itself - there is nothing to choose, so there is nothing to ask.
func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	# Re-derived LIVE rather than carried over from the gate: the gate ran when the reaction was
	# queued, and a pilot's licence level cannot change mid-combat - but reading it twice costs
	# nothing and states that the gate's value is not smuggled through.
	var amount:int = Overshield.grit(unit)
	if activation.abort_when(amount <= 0): return
	spend_actions(activation)
	await Overshield.grant(activation, unit, amount)
