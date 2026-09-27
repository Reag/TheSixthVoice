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
## "CHARACTER" ON THIS FRAME IS Unit.is_actor(), EVERYWHERE, AND A DRONE ACTS AS ITS OWNER. THIS
## PARAGRAPH IS THE CANONICAL ONE; the other eight sites cite it rather than re-arguing it.
##
## AUTHOR'S RULING, 2026-09-21 (the Sluagh close, FINAL - it reverses a unification on
## `Unit.is_character()` taken earlier the same day, and that earlier ruling is withdrawn entirely).
## The instruction was to fall in line with THE MOD'S OWN SETTLED PRECEDENT rather than with the
## engine's default, and the mod has ruled on this word three times already, always the same way:
##
##   - RULING 194 (Vauban, Gravity Well): "adjacent allied mechs" is `is_mech()`; drones and
##     deployables are not sheltered.
##   - RULINGS 64 and 70 (Subutai, Draw Fire, CONFIRMED): a hostile DRONE'S SHOT COUNTS AS ITS
##     OWNER'S for "hostile character", resolved through `Unit.get_attacker()` (unit.gd:276-282 ->
##     get_owner_unit_or_self).
##   - RULING 269 (this trait, at SP1): drones, deployables and wrecks excluded.
##
## So the rule in one sentence: **A DRONE IS NOT A CHARACTER IN ITS OWN RIGHT, AND WHERE A DRONE
## ACTS, IT ACTS AS ITS OWNER.** `Unit.is_actor()` is exactly the first half - is_character() and not
## is_drone (unit.gd:117) - and it is the predicate the engine itself uses for that meaning at
## action_system_apply_buff.gd:64 ("cannot apply buffs to drones / objects"). The second half is one
## file's business only: mt_wicked_host, the frame's single ATTACKER-side test, resolves through
## get_attacker() before asking, so an OWNED hostile drone's hit arms the chip as its owner's while
## an ownerless one arms nothing. Nowhere else on the frame does a drone ACT; everywhere else it is
## something the card is asked to shelter, guard, drag, target or count, and there it is not a
## character.
##
## WHAT ELSE DOES NOT COUNT, and it needs no clause of ours, because is_character() already refuses
## it under is_actor(): an OBJECT or a WRECK (Frame.ENTITY.OBJECT makes core.frame.is_character()
## false, frame.gd:100), a MARKER (unit.gd:110), and anything not is_active() - shut down, exiled,
## off the map. `test_a_hostile_object_death_grants_nothing` is the standing pin on that half.
##
## WHY THE UNIFICATION WAS REVERSED, AND IT WAS MEASURED, NOT ARGUED. Under is_character() an
## ENGAGING DRONE always won the Hunt's "closest character" search - only a character can engage
## (UnitRelation.can_be_engaged_by:154) and an engager is adjacent by definition, so it is always at
## distance 1 and every tile in its ring is beside it - and the Hunt could no longer drag a target
## clear of the thing holding it. One word, spelled the engine's way, silently deleted a card's
## whole point. The mod's precedent does not have that failure mode, and consistency ACROSS the mod
## is worth more than consistency with the engine inside one frame.
##
## THE SCOPE IS THE WHOLE FRAME, chosen explicitly by the author knowing it reverses two of their own
## earlier rulings: the SP3 ruling that a drone is a legal Crown target, and the SP4 ruling that a
## drone is a legal In Triumvirate partner. Both now need a `can_target_unit` override, because
## `requires_target_character` is the archetype's is_character() and cannot express this.
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
	# A CHARACTER: a mech or a pilot - never a DRONE, an object, a marker or a wreck. See the header's
	# canonical paragraph; this is the one site on the frame with no archetype gate above it.
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
