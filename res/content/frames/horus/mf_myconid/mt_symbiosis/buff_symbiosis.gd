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
## AND WHY THAT IS NOT ENOUGH ON ITS OWN (SP2.5 Task 1, and an ADDITION - the reasoning above stands
## unchanged and the value path is still what makes an ordinary consuming reaction work). A reaction
## with consumes_rxn = false never moves the point budget at all, so the value test can never see it.
## Since buff_symbiosis_extra_use.gd started relieving the OTHER gate - the per-round hard limit at
## unit_action.gd:170-175 - such a reaction can now be used an extra time without a single point
## changing hands, and with only the value path the stamp would never be set and the player would get
## an unlimited supply of second Uffish Gyres. Hence the second condition, is_cap_relieved_use()
## below: the activation was a reaction whose ROUND counter now stands ABOVE its own hard cap, which
## is arithmetic nothing but an ACTION_PER_ROUND buff can produce.
##
## AND THE EXTRA MUST COST A POINT EVEN WHEN THE REACTION DID NOT. The card grants ONE additional use
## per round, not one per channel: without the take-back in activate() a Myconid that spent its extra
## on a second Gyre would still be holding both reaction points and could go on to take an extra
## ORDINARY reaction in the same turn - two extras from one round's "1/round". The take-back is
## maxi(current - 1, 0) rather than the new_turn branch's mini(current, max - 1) because it has to be
## right at every budget: at a full 2 it leaves the ordinary allowance intact, at 1 (an ordinary
## reaction already taken this turn) it leaves nothing, and at 0 the value path has already claimed
## the activation and this branch never runs. **A FOURTH STATE was missing from that list until the
## frame close (2026-09-16), and the sentence heading this paragraph is only true of a reaction that
## did not pay: when the cap-relieved use is itself a CONSUMING reaction, the engine has already
## taken its point and the budget reads 1 for a reason this branch cannot distinguish from the
## second state above. Taking another billed one activation twice and left a Myconid that had
## reacted ONCE on that turn holding nothing - a net gain of zero uses from the round's extra, where
## the Gyre path correctly gains one. spends_its_own_point() is that fourth state.** Pinned by
## test_the_same_consuming_reaction_twice_in_a_round_bills_one_point_per_use, and in both orders by
## test_an_extra_ordinary_reaction_is_refused_after_a_second_gyre and
## test_a_second_gyre_is_refused_after_an_extra_ordinary_reaction.
##
## THE TWO PATHS CANNOT STAMP TWICE FOR ONE USE, and cannot double-bill either. SPENT_KEY is a
## boolean, so a second set() is a no-op; the take-back is guarded on the stamp having been UNSET
## when activate() ran, so the value path's own "current <= max - 2" - which stays true for the rest
## of the turn and re-triggers on every later activation - can never reach it twice.
##
## WHAT THE CAP PATH DELIBERATELY DOES NOT RE-CHECK, and why that is safe. It does not ask whether
## the kit was 1/scene or 1/mission, i.e. whether OUR buff was the one that raised the cap. An
## excluded kit cannot reach an over-cap use in the first place: uses_per_scene is refused by
## unit_action.gd:147 and Limited X by :153, both against counters no buff channel reaches (measured;
## see buff_symbiosis_extra_use.gd's judgment call 2). Nothing else on a Myconid grants
## Buff.TO.ACTION_PER_ROUND - vanilla's only other user is the Tortuga's, filtered to Overwatch - so
## an over-cap reaction use on this unit is this trait's doing by construction. Re-checking would
## also mean the bookkeeping half preloading the exclusion half, which already preloads THIS file for
## SPENT_KEY, and a cyclic preload takes both scripts' parse down in silence.
##
## WHY A DIRECT ASSIGNMENT. Buff.TO.STATBLOCK reaches only state.stat_bonus, which the refill, the
## spend and the clamp all ignore (ruling 13, mod-wide, and test_symbiosis.gd holds the proof). The
## only way to move the budget is to write core.current.reactions, which is what
## common_action_util.gd:734 does to stop Flank and Overwatch double-billing.
##
## WHY THIS IS NOT THE SAME FILE AS buff_symbiosis_exclusion.gd. This half subscribes to bus
## triggers at POST; the exclusion (since Pass F, T21) names no trigger at all - it is a
## Buff.TO.ACTION_FORBIDDEN query that hides an excluded reaction's offer. Two jobs, two resources.
##
## THIS FILE OWNS THE STAMP, AND THE EXCLUSION READS IT. Two buffs mean two BuffCores and two separate
## `state` dictionaries, so the gate cannot see SPENT_KEY on its own core; it fetches this one's
## instead, through UnitCondition.get_buff(unit, &'buff_symbiosis') (unit_condition.gd:782), and
## preloads this script for SPENT_KEY so the key has a single definition. Nothing but this file ever
## WRITES the stamp. The gate needs it because "the point about to be spent is the extra" is not
## `current < max`: once the extra has gone, the new_turn branch below leaves the holder below its max
## for the rest of the round with its ordinary allowance untouched.
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
## requiring any of them here would silently stop the cap from running on those turns. The gear and
## action the cap path reads are checked by hand for the same reason, through SpecificAction.is_valid.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

## THE POINT PATH. Two points below the max means the EXTRA has gone. See the header for why this is
## a value read and not a count of activations.
static func is_point_spend(unit:Unit) -> bool:
	return unit.core.current.reactions <= unit.core.get_reactions_max() - 2

## THE CAP PATH. A reaction used more times this round than its OWN hard limit allows - which
## is_under_per_round_limit (unit_action.gd:170-175) only ever permits when a Buff.TO.ACTION_PER_ROUND
## buff has raised the cap, and on a Myconid that is buff_symbiosis_extra_use.
##
## The ROUND counter, not the turn one, because that is the counter the gate itself reads; both are
## keyed by usage GROUP, and get_uses_this_round(action) resolves the group the same way the gate does
## (gear_core.gd:190-195).
##
## The virtual event_unit_action core carries gear and action alongside the unit
## (event_gear_activate.gd:121-131), and it is queued at :111 only once the usage counter has actually
## MOVED (:100-104) - so by the time this runs the count below already includes the activation being
## judged. That is what makes `>` the right comparison and not `>=`.
static func is_cap_relieved_use(context:Context) -> bool:
	if context == null or not (context.action is ActionReaction): return false
	var specific:SpecificAction = SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return false
	return (
		context.gear.get_uses_this_round(context.action) >
		context.action.get_per_round_hard_limit(specific)
	)

## DID THE ACTIVATION PAY ITS OWN POINT? UnitAction.spend takes one for any action whose
## consumes_reaction() is true (unit_action.gd:257), and it does so BEFORE the usage counter moves
## (:279) and before this POST is queued (event_gear_activate.gd:111) - so by the time we run, that
## point has already gone. The take-back must not bill the same activation a second time.
##
## This is the case the cap path did not originally separate. A non-consuming reaction (the Gyre,
## Halo) trips the cap while moving no point, which is what the take-back exists for; an ORDINARY
## consuming reaction trips the same cap having already paid, and is_point_spend() only notices when
## the budget has reached 0. On a turn the Myconid entered with both points, it does not have.
static func spends_its_own_point(context:Context) -> bool:
	return context != null and context.action != null and context.action.consumes_reaction()

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	match triggering_event.base.event_type:
		&'event_unit_action':
			# OUR activation only. reaction_bus.trigger_occurred polls every unit's buffs on every
			# trigger and hands each of them the SAME event (reaction_bus.gd:50, :61-62), so without
			# this line the Myconid stamps itself off somebody else's gear.
			if triggering_event.context.unit != unit: return false
			# EITHER channel: the point budget fell by the extra, or a reaction was used past its own
			# per-round cap. See the header - a non-consuming reaction can only ever trip the second.
			return is_point_spend(unit) or is_cap_relieved_use(triggering_event.context)
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
			var was_already_spent:bool = bool(core.get_state(SPENT_KEY, false))
			core.set_state(SPENT_KEY, true)
			# THE TAKE-BACK, and only on the FIRST stamp of the round. A cap-relieved use by a
			# NON-CONSUMING reaction spends no reaction point of its own, so without this the round's
			# extra would be available a second time through the point economy. The value path needs
			# nothing: its point has already gone. Nor does a CONSUMING reaction that tripped the cap -
			# the engine billed it at unit_action.gd:257 before we ran, and taking another point here
			# charges one activation twice (see spends_its_own_point).
			# See the header for why maxi(current - 1, 0) and not the new_turn branch's mini().
			if was_already_spent or is_point_spend(unit) or spends_its_own_point(triggering.context): return
			unit.core.current.reactions = maxi(unit.core.current.reactions - 1, 0)
		&'event_turn_start':
			# The refill has already run for every unit on the map (event_turn_start.gd:43-44) and
			# these POST reactions are queued at :56. mini() rather than a bare assignment: a Myconid
			# that has ALREADY reacted during this turn must not be handed a point back.
			unit.core.current.reactions = mini(
				unit.core.current.reactions, unit.core.get_reactions_max() - 1
			)
		&'event_round_new':
			core.set_state(SPENT_KEY, false)
