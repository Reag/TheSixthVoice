## SYMBIOSIS, the per-round half: the extra use a reaction POINT cannot buy.
##
##   "1/round, the Myconid may use a reaction an additional time."
##
## THE BUG THIS FILE FIXES (author playtest, 2026-09-16). An ally moved and the Uffish Gyre fired; on
## the next ally's turn - the same round, since the Myconid had not taken its own turn - another ally
## moved and Symbiosis did not offer the Gyre again. The card says it should.
##
## TWO GATES, AND THE OTHER TWO FILES ONLY EVER REACHED ONE OF THEM. A reaction can be refused by
## either of two independent checks inside UnitAction.can_activate_gear:
##
##   is_gear_affordable        unit_action.gd:182, `requires_reaction_available() and not
##                             has_reaction` - the reaction POINT. This is the one buff_symbiosis.gd
##                             relieves, by having mt_symbiosis grant Statblock.reactions = 1.
##   is_under_per_round_limit  unit_action.gd:170-175, `gear.get_uses_this_round(action) <
##                             action.get_per_round_hard_limit(specific)` - a COUNTER, nothing to do
##                             with the point.
##
## The Gyre is consumes_rxn = false, so requires_reaction_available() is false and the first gate
## never refuses it - it never needed a point and never spends one. Its 1/round is the SECOND gate:
## ActionReaction hands a non-consuming reaction a per-round limit of 99 (action_reaction.gd:69) and
## action_uffish_gyre.gd overrides it back to 1. Symbiosis touched nothing on that path, so a second
## Gyre was not refused with a reason - it was never OFFERED at all, because the limit is consulted
## inside ReactionBus.does_reaction_trigger via can_activate_gear. MEASURED in the RED run of
## test_a_second_gyre_in_the_round_is_offered_after_symbiosis: the second ally's event_unit_move
## carries no event_gear_activate child whatsoever, and no "[ Gear not available ]" line either. That
## silence is what the author saw in play.
##
## THE CHANNEL IS THE ENGINE'S OWN, AND ITS COMMENT NAMES THIS USE. is_under_per_round_limit sums
## Buff.TO.ACTION_PER_ROUND buffs into the cap before comparing, and buff.gd:44 declares the key as
## "increase number of times something can be used per-round: tortuga overwatch". The only user of it
## in the whole tree is
## content/frames/ipsn/mf_tortuga/cp_watchdog_co_pilot/buff_hyper_reflex_mode_additional_overwatch.gd
## - `to = &"action_per_round"`, `hide_from_player = true`, an is_buff_context_valid_for_passive that
## asks SpecificAction.is_valid(SpecificAction.from_context(context)), a check_if_passive_applies
## filtering to one action, and get_values returning number = 1. This file is that shape with the
## filter generalised from "overwatch" to "any reaction the card does not exclude".
##
## JUDGMENT CALL 1: WHAT "IS A REACTION" MEANS HERE, AND THE ANSWER IS THE CLASS.
## Three candidates, and they are three different questions:
##   `action is ActionReaction`     what the player is told: ActionReaction.get_flavor returns
##                                  FLAVOR.REACTION (action_reaction.gd:17-19) and its
##                                  type_description prints "Reaction" or "Trait" (:26-29). 296
##                                  scripts in engine/ and content/ extend it.
##   get_action_type() == RXN       the same set in practice - ActionReaction returns RXN
##                                  unconditionally (action_reaction.gd:43-44) - but reached through
##                                  an override any Action may make, and it needs a SpecificAction to
##                                  ask.
##   requires_reaction_available()  REJECTED OUTRIGHT. It is `consumes_reaction()` (action.gd:170),
##                                  which is FALSE for the Uffish Gyre - so it would exclude the very
##                                  action this file exists to fix, while looking perfectly
##                                  reasonable. It is the trap the brief flagged and it is real.
## The class test is chosen: it is the one that cannot be changed by an unrelated override, and
## get_flavor is not usable in its place because flavor_override (action.gd:61) lets any action
## rename itself. Pinned by test_a_non_reaction_1_per_round_action_gets_no_extra_use, which puts a
## naturally-free ORDINARY action - 1/round by action.gd:156-158, the same cap, reached without being
## a reaction at all - beside a reaction in the same fixture and asserts only the reaction's cap moves.
##
## JUDGMENT CALL 2: A 1/SCENE OR 1/MISSION REACTION CANNOT BE HELPED BY THIS CHANNEL ANYWAY, AND THE
## CLAUSE STAYS. Measured, not assumed: uses_per_scene is read in exactly one gate,
## `gear.get_uses_this_scene(action) >= kit.uses_per_scene` (unit_action.gd:147), and Limited X in
## `action.consumes_charges(specific) and not gear.has_charges_left()` (unit_action.gd:153). Both are
## separate counters (gear_core.gd:197-202 for the scene one) and NEITHER has a buff channel of any
## kind - grep uses_per_scene across engine/ returns five lines and not one of them is a buff. So a
## kit the card excludes is refused by a gate this buff does not touch, whatever the round cap says,
## and the clause below is belt-and-braces rather than load-bearing. It is kept for two reasons: the
## card says so in as many words, and an excluded reaction whose cap this buff had silently raised
## would be a lie in every debugger and every future reading of is_under_per_round_limit. What the
## measurement costs is honesty about the mutation: deleting the clause does NOT change whether such
## a reaction fires, so test_a_1_per_scene_reaction_gets_no_extra_use asserts on the GATE
## (UnitAction.is_under_per_round_limit) and not on an activation - that is the only assertion the
## clause can discriminate, and a test written against the activation would have passed either way.
##
## JUDGMENT CALL 3: ONE EXTRA USE PER ROUND, TOTAL - AND THE SPEND IS buff_symbiosis.gd'S. The card
## is singular. This buff therefore reads the stamp before applying, so the extra is offered only
## while it is unspent; and buff_symbiosis.gd gained a second detection path so that a use taken
## through THIS channel really sets it. The two orders are tested against each other
## (test_an_extra_ordinary_reaction_is_refused_after_a_second_gyre and
## test_a_second_gyre_is_refused_after_an_extra_ordinary_reaction).
##
## THE PREDICATES ARE THE EXCLUSION HALF'S, CALLED AND NOT COPIED, AND THE PRELOAD RUNS THIS WAY FOR
## A REASON. buff_symbiosis_exclusion.gd already owns both of them as statics - is_excluded(kit) for
## the card's 1/scene and 1/mission clause and is_extra_spent(unit) for the stamp - so this file
## preloads it and calls them. The direction matters: the exclusion already preloads
## buff_symbiosis.gd for SPENT_KEY, so the dependency graph is bookkeeping <- exclusion <- this file,
## a chain and not a cycle. Moving either predicate the other way, or having the BOOKKEEPING half
## call into this one, would close the loop - and a cyclic preload in GDScript takes both scripts'
## parse down with it, which is the silent failure mode CLAUDE.md warns about.
##
## NOT A REACTION ITSELF, so no triggers_on and no trigger_timing on the .tres: this buff is read
## through UnitCondition.get_buffs_to (unit_condition.gd:822-851), which asks to == ACTION_PER_ROUND
## first and only then calls the two functions below. They therefore never run for any other channel.
extends Buff

## The exclusion half, preloaded for its two static predicates. See the header for why the preload
## points this way round and not the other.
const Exclusion := preload(
	'res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_myconid/mt_symbiosis/buff_symbiosis_exclusion.gd'
)

## Tortuga's line verbatim (buff_hyper_reflex_mode_additional_overwatch.gd:5-6). It is what lets
## check_if_passive_applies dereference all three of unit, gear and action without a guard apiece:
## SpecificAction.is_valid requires Unit.is_valid, GearCore.is_valid and Action.is_valid together
## (specific_action.gd:16-23), and does_buff_apply calls this one FIRST (unit_condition.gd:848-849).
func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return SpecificAction.is_valid(SpecificAction.from_context(context))

## "a reaction", "not 1/scene or 1/mission", "1/round". All three, and the header has the whole of
## each.
func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
	if not (context.action is ActionReaction): return false
	if Exclusion.is_excluded(context.gear.kit): return false
	return not Exclusion.is_extra_spent(context.unit)

## "an additional time" - one, so +1 on the cap. Tortuga's get_values with its comment changed.
func get_values(_core:BuffCore, _context:Context) -> Context:
	return Context.create({
		number = 1, # one additional use of this reaction
	})
