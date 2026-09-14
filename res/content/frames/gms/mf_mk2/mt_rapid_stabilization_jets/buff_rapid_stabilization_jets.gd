## RAPID STABILIZATION JETS, the half that keeps the window open: re-opens
## unit.state.is_firing_ordnance after every action and every move, until the turn ends.
##
## WHY A REACTION AND NOT A ONE-TIME SET. The flag is cleared by MANY things - any non-protocol,
## non-reaction action (unit_action.gd:269 via does_action_end_ordnance_phase), any move that
## SPENDS movement (event_unit_move.gd:88-90), and turn end - so "ignore the Ordnance tag until the
## end of the current turn" cannot be a single write. This buff re-asserts the flag after each of
## those.
##
## WHY THE TIMING WORKS. The availability check runs when the action menu is rebuilt, after the whole
## event block has finished, so a POST reaction anywhere in that block restores the flag in time.
## UNIT_ACTION POST is queued by event_gear_activate.gd:104-111 for every gear activation that
## actually moved its usage counter - Boost, Skirmish, Stabilize, a free action, Overcharge, and
## freebies too, since the ROUND counter is incremented even for AS_FREEBIE (gear_core.gd:170-180).
## ENTIRE_MOVEMENT POST is emitted at event_unit_move.gd:121, after the steps, and the
## phase-ending call at :88-90 runs before it. A move that does NOT spend_move never closes the
## window in the first place (that is the `spend_move` gate at :88, not `voluntary` - measured in
## this trait's first red run), so there is nothing to re-open there either.
##
## MEASURED BEFORE IT WAS BUILT (SP1 Task 0, .superpowers/sdd/mk2-sp1-task0-report.md):
## Both triggers were measured against a buff before this was built
## (spec/test_spike_mk2_reaction_timing.gd, 2026-09-14): ENTIRE_MOVEMENT POST reached a buff once
## after a move, and UNIT_ACTION POST reached one after a rifle shot and after a Boost. STEP POST
## also works (once per step) and is not needed.
##
## activate() DOES NOT CALL super(). Buff.activate's default body (buff.gd:254-255) clears the buff
## from the unit, which would end the Jets after the first action rather than at end of turn - the
## Lockbreaker shape. A buff activation spends no reaction and has no per-turn limit, so re-firing
## on every action costs the M/K2 nothing.
extends Buff

## The holder only. reaction_bus.trigger_occurred (reaction_bus.gd:61-67) polls EVERY unit's buffs on
## every trigger, so without this an enemy's Boost would re-open our window - harmlessly today, but
## it would also mean the spec could not tell a working trait from a broken one.
func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	return triggering_event.context.unit == unit

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	unit.state.is_firing_ordnance = true

## Restores the shape this trait was measured with (spec/test_spike_mk2_reaction_timing.gd, since
## deleted): without this, Buff.check_required_triggering_context (buff.gd, bottom of file) lets
## this buff be evaluated against trigger events carrying no unit at all, and triggers_on_event
## above would compare against a null context.unit instead of refusing cleanly.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]
