# SUPPORTING FIRE (Hazard, cp_int_type_command_systems - the core passive), rulings 4-5:
#
#   "1/round, when an adjacent allied character starts their turn, you may choose to give the first
#    attack they make +1 Accuracy. Until the end of your next turn, the next attack you make has +1
#    Difficulty."
#
# A NEW_TURN POST reaction whose holder is NOT the turn unit - the Goblin's Symbiosis shape
# (action_symbiosis_shared_turn.gd). POST runs after every_new_turn_refresh, so the ally's turn is
# fully open. Measured by spec/test_spike_hazard_sp1_seams.gd: the starter is context.unit, and a
# point-free hard limit of 1 holds across two allies' turn starts, re-arming only at the HAZARD's own
# turn start (new_turn_refresh resets the holder's per-round usage) - "1/round" per Hazard round.
#
# THE GATE: the starter is an allied CHARACTER (is_actor - a deployable's virtual turn start with its
# owner, event_turn_start.gd:56-59, never offers), not the Hazard, and ADJACENT through
# UnitRelation.is_adjacent - which TAKES House Guard's widening on the HAZARD (author's ruling;
# is_adjacent(a, b) reads a's buffs). spec/test_compat.gd pins it.
#
# "YOU MAY": confirm_use for the HAZARD's controller (it pays the Difficulty); the AI always accepts
# (Follow Order's shape). A "no" spends nothing, so a later turn start that round offers again.
#
# YES: spend, then TWO VISIBLE ONE-TIME ATTACK_ROLL buffs - +1 Accuracy on the ALLY, gone at the end of
# its own turn if unused; -1 (+1 Difficulty) on the HAZARD, until the end of its NEXT turn. Two costs
# CAN coexist and both land on the Hazard's next attack (used late in round N after the Hazard's
# turn, then early in round N+1 before it) - what the card's timing produces, recorded.
extends ActionReaction

@export var ally_buff:Buff
@export var cost_buff:Buff

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var starter:Unit = triggering_event.context.unit
	if not Unit.is_valid(starter) or starter == unit: return false
	if not starter.is_actor(): return false
	if not UnitRelation.are_allies(unit, starter): return false
	return UnitRelation.is_adjacent(unit, starter)

## The AI always gives the bonus: Follow Order's `confirmed = true` for a non-player payer.
func ai_confirms_use(_context:Context, _target_units:Array[Unit] = []) -> bool: return true

func activate(context:Context, activation:EventCore) -> void:
	var hazard:Unit = context.unit
	var starter:Unit = context.event.context.unit
	if activation.abort_without_units([hazard, starter]): return

	var confirmed:bool = await CommonActionUtil.confirm_use(context, [starter])
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([hazard, starter]): return

	spend_actions(activation)
	apply_buff(activation, starter, ally_buff)
	apply_buff(activation, hazard, cost_buff)
