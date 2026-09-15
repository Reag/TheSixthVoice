## SYMBIOSIS, the exclusion half.
##
##   "This cannot be used on reactions that are 1/scene or 1/mission."
##
## A reaction POINT does not know what it will be spent on, so enforcing this clause means seeing the
## ACTIVATION. The natural place - UnitAction.can_take_reactions - is in the one autoload whose
## script extensions install and then never run (CLAUDE.md; measured 2026-09-02 on that very
## function), so this is done from the UNIT_ACTION PRE seam instead.
##
## THE SEAM. event_gear_activate.execute_preblock (:53-56) builds a virtual event_unit_action core
## carrying the activating unit, gear and action (:119-132), awaits the UNIT_ACTION PRE reactions AND
## BUFFS on it (reaction_bus.gd:61-67 fires both, with the same EventCore), and then calls
## core.abort_when(virtual_core.aborted). EventBlock.execute then skips execute() entirely for an
## aborted event (event_block.gd:100-103). Marking that core aborted is therefore a content-reachable
## veto on any activation, and SP1 opened with a probe that measured it end to end before this file
## was written.
##
## WHAT COUNTS AS EXCLUDED (ruling, 2026-09-15): "1/scene" is a reaction whose Kit declares
## uses_per_scene == 1 (kit.gd:39); "1/mission" is Limited 1, charges_max == 1 (kit.gd:35). A
## Limited 2+ reaction is NEITHER, and Symbiosis works on it.
##
## WHEN IT REFUSES: only when the point about to be spent is the EXTRA one - that is,
## current.reactions < get_reactions_max(), meaning the Myconid has already reacted this turn. The
## reaction point is not spent until Action.spend_actions runs inside activate(), which is after this
## preblock, so the count read here is the count BEFORE this activation.
##
## CONSEQUENCE, ACCEPTED BY THE AUTHOR: a player who wants a 1/scene reaction on a turn must take it
## as that turn's FIRST reaction. The alternative - letting the extra be spent on it and refunding
## afterwards - cannot be built, because by the time we could see what it was spent on the effect has
## already happened.
##
## WHY NOT ONE FILE WITH buff_symbiosis.gd. Buff.trigger_timing is a single @export (buff.gd:139)
## compared directly by ReactionBus.does_buff_trigger (reaction_bus.gd:135): a Buff subscribes at ONE
## timing for every trigger it names. The bookkeeping half needs POST. Two timings, two resources.
##
## activate() DOES NOT CALL super(): the default (buff.gd:254-255) would clear the buff off the unit
## after the first refusal.
extends Buff

## The Kit properties the clause names. Read off the KIT rather than the action, because that is
## where the engine keeps both limits and where any content author would have declared them.
static func is_excluded(kit:Kit) -> bool:
	if kit == null: return false
	return kit.uses_per_scene == 1 or kit.charges_max == 1

## The virtual event_unit_action core carries all three (event_gear_activate.gd:121-131), and every
## one of them is dereferenced below, so requiring them costs nothing and turns a malformed context
## into a silent no-trigger rather than an error inside a preblock.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	# OURS. The bus polls every unit's buffs on every trigger with the same event.
	if context.unit != unit: return false
	# A REAL reaction: ActionReaction.consumes_reaction() returns consumes_rxn
	# (action_reaction.gd:58), and Action's own returns false - so an ordinary action, and a
	# non-consuming trait reaction like Halo, are both untouched.
	var action:Action = context.action
	if action == null or not action.consumes_reaction(): return false
	if not GearCore.is_valid(context.gear): return false
	if not is_excluded(context.gear.kit): return false
	# And only when the point about to be spent is the EXTRA.
	return unit.core.current.reactions < unit.core.get_reactions_max()

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	var triggering:EventCore = activation.context.event
	if not is_instance_valid(triggering): return
	triggering.set_aborted()
	# Without this the refusal reads as the activation simply not happening, which in play is
	# indistinguishable from a bug. The row names the trait so the player can find out why.
	if Unit.is_valid(unit): battle_log.log_unit(&'gear.mt_symbiosis.refused.log', unit)
