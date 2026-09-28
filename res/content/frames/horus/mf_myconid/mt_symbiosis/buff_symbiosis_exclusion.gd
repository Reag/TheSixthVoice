## SYMBIOSIS, the exclusion half.
##
##   "This cannot be used on reactions that are 1/scene or 1/mission."
##
## HIDDEN, NOT REFUSED (Pass F, author decision T21; ruling "Myconid | Symbiosis"). While the point a
## reaction would spend is the round's EXTRA, an excluded reaction is simply not offered: "the player
## loses nothing: point and usage are not spent". This file used to be a UNIT_ACTION PRE veto that
## let the offer through, aborted the activation after the player had chosen it, and wrote a
## battle-log line explaining why. Both the veto and that log row are gone.
##
## THE CHANNEL. Buff.TO.ACTION_FORBIDDEN, a channel the engine QUERIES rather than one the bus fires,
## so this buff names no trigger and no timing. UnitAction.get_gear_unavailable_reason ends with
## `has_buff_to(unit, ACTION_FORBIDDEN, buff_context)` -> REASON.FORBIDDEN (unit_action.gd:157), and
## ReactionBus.does_reaction_trigger asks UnitAction.can_activate_gear BEFORE triggers_on_event
## (reaction_bus.gd:121-123) - so a forbidden reaction never becomes an event_gear_activate and never
## reaches the player's prompt. The Trueblack Aegis restrictions
## (content/frames/ha/mf_napoleon/cp_trueblack_aegis/buff_trueblack_aegis_restrictions.gd) are the
## vanilla precedent for a predicate-gated ACTION_FORBIDDEN buff. The context is
## SpecificAction.to_context(), which carries unit, gear and action, plus flags = [AS_FREEBIE] on a
## freebie check; the FORBIDDEN clause is not skipped for freebies, and neither was the old veto.
##
## WHAT COUNTS AS EXCLUDED (ruling, 2026-09-15): "1/scene" is a reaction whose Kit declares
## uses_per_scene == 1 (kit.gd:39); "1/mission" is Limited 1, charges_max == 1 (kit.gd:35). A
## Limited 2+ reaction is NEITHER, and Symbiosis works on it.
##
## WHEN IT HIDES: only when the point about to be spent really is the EXTRA one, which takes TWO
## conditions and not one.
##
##   current.reactions < get_reactions_max()   the Myconid is already below a full budget, and
##   the round's extra is still UNSPENT        the point missing from that budget is this round's
##                                             extra rather than a turn's ordinary allowance.
##
## The first condition alone was a bug this file once shipped with. Once the extra HAS been spent,
## buff_symbiosis caps every later turn start back to max - 1 (that is the whole point of it), so the
## Myconid stands at 1 of 2 with nothing spent that turn - and `current < max` is true there too. The
## turn's FIRST reaction, which the card never restricts, would be withheld. Reachable in play: react
## twice on one turn, then face any 1/scene reaction later in the same round.
##
## The query runs before the activation, so the count read here is the count BEFORE it.
##
## CONSEQUENCE, ACCEPTED BY THE AUTHOR: a player who wants a 1/scene reaction on a turn must take it
## as that turn's FIRST reaction.
##
## WHY NOT ONE FILE WITH buff_symbiosis.gd. The bookkeeping half subscribes to bus triggers at POST;
## this half is a query channel with its own `to`. Two jobs, two resources.
##
## THE TWO HALVES DO SHARE ONE FACT, IN ONE DIRECTION. Two buffs mean two BuffCores and two separate
## `state` dictionaries, so the stamp cannot simply be read off `_core` here. It is fetched instead
## through UnitCondition.get_buff(unit, &'buff_symbiosis') (unit_condition.gd:782), which finds the
## sibling's BuffCore on the same holder. buff_symbiosis.gd remains the stamp's only owner - it is the
## only file that ever writes SPENT_KEY - and this file only ever READS it.
extends Buff

## The sibling half, preloaded for its SPENT_KEY alone, so the state key has exactly one definition
## and cannot drift between the file that writes it and the file that reads it.
const Bookkeeping := preload(
	'res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_myconid/mt_symbiosis/buff_symbiosis.gd'
)

## Its compcon_id, which the loader takes from the basename of buff_symbiosis.tres
## (ContentLibrary.get_compcon_id_from_path).
const BOOKKEEPING_BUFF_ID := &'buff_symbiosis'

## Has this round's extra reaction already gone? Read off the sibling BuffCore on the same unit.
##
## If the bookkeeping buff is somehow ABSENT this reports false - the extra treated as unspent, which
## keeps the gate hiding exactly as it did before this clause existed. It should never happen (one
## PassiveBuffApplicator on mt_symbiosis carries both, so either both are on the unit or neither is,
## and with neither on the unit this function is not reached at all), and the deliberate choice is to
## stay strict rather than to fail open and silently let an excluded reaction through unnoticed.
static func is_extra_spent(unit:Unit) -> bool:
	var core:BuffCore = UnitCondition.get_buff(unit, BOOKKEEPING_BUFF_ID)
	if not BuffCore.is_valid(core): return false
	return bool(core.get_state(Bookkeeping.SPENT_KEY, false))

## The Kit properties the clause names. Read off the KIT rather than the action, because that is
## where the engine keeps both limits and where any content author would have declared them.
static func is_excluded(kit:Kit) -> bool:
	if kit == null: return false
	return kit.uses_per_scene == 1 or kit.charges_max == 1

## ACTION_FORBIDDEN is also asked with contexts that name no action - the boost check
## (unit_action.gd:504) and the end-turn button (non_gear.gd:120) - so only a full unit/gear/action
## context is considered, the way the Trueblack Aegis restrictions do it.
func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return SpecificAction.is_valid(SpecificAction.from_context(context))

func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return false
	# A REAL reaction: ActionReaction.consumes_reaction() returns consumes_rxn
	# (action_reaction.gd:58), and Action's own returns false - so an ordinary action, and a
	# non-consuming trait reaction like Halo, are both untouched.
	var action:Action = context.action
	if action == null or not action.consumes_reaction(): return false
	if not GearCore.is_valid(context.gear): return false
	if not is_excluded(context.gear.kit): return false
	# And only when the point about to be spent is the EXTRA, which is both of these and not just the
	# first: below a full budget AND the round's extra still unspent. After the cap has fired the
	# Myconid sits below its max all round with its ORDINARY allowance intact, and that one the card
	# never restricts.
	if unit.core.current.reactions >= unit.core.get_reactions_max(): return false
	return not is_extra_spent(unit)
