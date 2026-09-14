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
## UNIT_ACTION POST is queued by event_gear_activate.gd:110-111, gated at :100-104 on the gear's
## usage counter having actually moved - so Boost, Skirmish, Stabilize, a free action, Overcharge,
## and freebies too, since the ROUND counter is incremented even for AS_FREEBIE (gear_core.gd:170-180).
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
	# THE TURN GUARD, AND THE WINDOW IT CLOSES. Without it this buff can put is_firing_ordnance back
	# AFTER the engine shut it at turn end, and the gap is measured, not imagined:
	# event_turn_end.execute calls handle_ending_unit at :36, which clears is_taking_turn (:64) and
	# calls end_ordnance_phase() (:66) - but this buff is not cleared until end_turn_for_statuses at
	# :40, which runs only once handle_ending_unit has RETURNED. In between, handle_ending_unit is
	# still running falling damage (:76-78), dangerous-terrain damage (:82-89) and the burn save and
	# burn damage (:93-106). Any of those can provoke a gear reaction on the M/K2; a reaction is an
	# event_gear_activate like any other, so it queues UNIT_ACTION POST (event_gear_activate.gd:110-111),
	# this buff is still applied to hear it, and the line below would re-open the window. The M/K2
	# could then take an Overwatch with an Ordnance weapon during somebody else's turn, which
	# unit_action.gd:146 refuses with REASON.ORDNANCE whenever the flag is false. It self-heals at our
	# own next turn start (event_turn_start.gd:83), so the leak is bounded - and one free Ordnance
	# reaction is worth more than most turns.
	#
	# It also settles a disagreement between the frame's two turn-scoped abilities: Hybridized Shot
	# has always asked this question (buff_hybridized_shot.qualifies(), "on your turn") and the Jets
	# did not.
	#
	# Pinned by test_rapid_stabilization_jets.test_the_window_does_not_reopen_once_the_turn_has_ended,
	# which stages exactly the handle_ending_unit :64-66 state and then fires a real activation in it.
	if not unit.state.is_taking_turn: return
	unit.state.is_firing_ordnance = true

## THE M/K2'S ONE ANSWER ON REQUIRED TRIGGERING CONTEXT, WRITTEN DOWN HERE AND NOWHERE ELSE. All
## three of the frame's reacting buffs declare [Context.PROP.unit]; buff_hybridized_shot.gd and
## buff_ors_hypercharge.gd point back at these lines rather than restating the reasoning, so a future
## frame's author finds one ruling instead of three.
##
## WHAT IT DOES. Buff.get_required_triggering_context defaults to an empty array (buff.gd:246-247),
## and Buff.check_required_triggering_context walks whatever it returns, refusing the buff when a
## named property is absent from the triggering event's context (buff.gd:258-262). Under the default,
## a trigger event carrying no `unit` at all still reaches triggers_on_event, which then compares a
## null context.unit against the holder.
##
## IT IS BEHAVIOUR-NEUTRAL TODAY, AND IS DECLARED ANYWAY. Every holder check in this frame refuses a
## null cleanly, so no failure is known to be reachable through the default. What the declaration
## buys is that each buff states the precondition its own triggers_on_event depends on, and the
## engine enforces it one layer before the comparison - which is also the shape this trait was
## originally measured in (spec/test_spike_mk2_reaction_timing.gd, since deleted).
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]
