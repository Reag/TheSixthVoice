## RAPID STABILIZATION JETS, the activation: a FREE action that opens the ordnance window and applies
## the buff that keeps it open.
##
## WHY THE DIRECT SET IS HERE AT ALL. This action is itself a non-protocol action, so
## ActionSystem.spend_actions closes the ordnance window inside super.activate()
## (unit_action.gd:269) - the Jets would shut the window on their way to opening it. Setting the
## flag afterwards is what makes the FIRST use work. Everything after this action is the buff's job.
##
## IT IS CURRENTLY REDUNDANT, AND IS KEPT ANYWAY - measured, not assumed. Deleting this line leaves
## the spec 10/10 green (.superpowers/sdd/mk2-sp1-task1-mutation-action.log), because the buff DOES
## hear its own applying activation's UNIT_ACTION POST and re-opens the window itself. That is an
## ORDERING, not a contract: the buff is applied inside apply_buffs_to_targets and the POST is
## queued afterwards by event_gear_activate.gd:110-111, so anything that moves the apply later - a
## save gate, a confirm, an engine change to when the virtual event is emitted - silently breaks the
## first use and nothing else in the trait would say so. One line is cheaper than that failure.
## Note this means the line is NOT protected by a red test; the mutation above is the record of it.
##
## Order matters: super() first (it applies the buff and spends the action), then the set.
extends ActionSystemApplyBuff

const BUFF_ID:StringName = &'buff_rapid_stabilization_jets'

## THE GUARD IS "DID THE BUFF LAND", NOT "activation.is_aborted()". The brief offered either; only
## this one exists. EventCore has no is_aborted() accessor - `aborted` is a plain bool var
## (event_core.gd:10) and the abort helpers (abort_when, abort_without_unit, event_core.gd:25-29)
## are call-site guards that RETURN it - so activation.is_aborted() would have been a runtime
## "Nonexistent function" the moment a player ever declined the confirm, i.e. never in a spec and
## always in play. Asking whether the buff is on the unit is also the stronger question: this
## action's whole contract is "apply the chip, then open the window", and every path that fails to
## apply it - a declined confirm (action_system_apply_buff.gd:103-104), an invalid unit, a buff the
## engine refused - must not leave the window open behind it. It is measurable from the spec, which
## is why the brief preferred it.
func activate(context:Context, activation:EventCore) -> void:
	await super.activate(context, activation)
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	if not UnitCondition.has_buff(unit, BUFF_ID): return
	unit.state.is_firing_ordnance = true
