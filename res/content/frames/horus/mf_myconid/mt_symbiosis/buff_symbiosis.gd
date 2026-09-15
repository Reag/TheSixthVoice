## SYMBIOSIS, the bookkeeping half: "1/round" on a budget the engine issues per TURN.
##
##   "1/round, the Myconid may use a reaction an additional time."
##
## THE PROBLEM. The reaction budget is per-TURN by construction: every_new_turn_refresh assigns
## current.reactions = core.get_reactions_max() for EVERY unit at EVERY turn start
## (unit_action.gd:69, event_turn_start.gd:43-44), and Statblock.reactions is even commented
## "## Per turn". There is no per-round reaction counter anywhere to hook. So the Gaze-shaped +1 on
## mt_symbiosis, left alone, would be an extra reaction on every turn - strictly stronger than Bel's
## card. This script is what makes it once per round, and the author chose the card (ruling,
## 2026-09-15).
##
## THE SHAPE. One stamp, three triggers, all POST:
##
##   unit_action  the holder has just activated something, and the activation left it at two points
##                below its max - so the point it spent was the EXTRA. Stamp it.
##   new_turn     ANY unit's turn start, queued at event_turn_start.gd:56, AFTER the refill at
##                :43-44. While the stamp is set, hand the refilled extra straight back.
##   new_round    event_round_new.gd:77, which runs before the round's first turn starts (:84).
##                Clear the stamp.
##
## WHY THE POST-ACTION CHECK IS VALUE-BASED rather than counting activations: a choose_and_use
## follow-up activates as gear too, and a reaction that queues one would otherwise be counted twice.
## Asking "how many points are gone" cannot double-count anything.
##
## WHY A DIRECT ASSIGNMENT. Buff.TO.STATBLOCK reaches only state.stat_bonus, which the refill, the
## spend and the clamp all ignore (ruling 13, mod-wide, and test_symbiosis.gd holds the proof). The
## only way to move the budget is to write core.current.reactions, which is what
## common_action_util.gd:734 does to stop Flank and Overwatch double-billing.
##
## WHY THIS IS NOT THE SAME FILE AS buff_symbiosis_exclusion.gd. Buff.trigger_timing is a single
## @export (buff.gd:139) that ReactionBus.does_buff_trigger compares directly (reaction_bus.gd:135);
## a Buff subscribes at ONE timing for every trigger it names. The exclusion has to abort from
## UNIT_ACTION PRE, before event_gear_activate.gd:56 reads virtual_core.aborted. Two timings, two
## resources. They share no state: this file owns the stamp and the gate never reads it.
##
## activate() DOES NOT CALL super(): the default (buff.gd:254-255) clears the buff off the unit, and
## this one has to survive the whole scene. For the same reason the applicator must NOT set
## reapply_at_the_start_of_each_turn - a re-application hands over a fresh BuffCore and wipes the
## stamp mid-round.
extends Buff

## The one key, in this BuffCore's own state dictionary. True from the moment the round's extra
## reaction is spent until the next NEW_ROUND.
const SPENT_KEY := 'extra_spent'

## Nothing is read off the triggering context except the unit on a unit_action, and that one is
## checked by hand - a turn start for a DEPLOYABLE runs on a virtual core whose props are sparse, and
## requiring any of them here would silently stop the cap from running on those turns.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	match triggering_event.base.event_type:
		&'event_unit_action':
			# OUR activation only. reaction_bus.trigger_occurred polls every unit's buffs on every
			# trigger and hands each of them the SAME event (reaction_bus.gd:50, :61-62), so without
			# this line the Myconid stamps itself off somebody else's gear.
			if triggering_event.context.unit != unit: return false
			# Value-based: two points below the max means the EXTRA has gone.
			return unit.core.current.reactions <= unit.core.get_reactions_max() - 2
		&'event_turn_start':
			return bool(core.get_state(SPENT_KEY, false))
		&'event_round_new':
			return bool(core.get_state(SPENT_KEY, false))
	return false

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	var triggering:EventCore = activation.context.event
	if not Unit.is_valid(unit) or not is_instance_valid(triggering): return
	match triggering.base.event_type:
		&'event_unit_action':
			core.set_state(SPENT_KEY, true)
		&'event_turn_start':
			# The refill has already run for every unit on the map (event_turn_start.gd:43-44) and
			# these POST reactions are queued at :56. mini() rather than a bare assignment: a Myconid
			# that has ALREADY reacted during this turn must not be handed a point back.
			unit.core.current.reactions = mini(
				unit.core.current.reactions, unit.core.get_reactions_max() - 1
			)
		&'event_round_new':
			core.set_state(SPENT_KEY, false)
