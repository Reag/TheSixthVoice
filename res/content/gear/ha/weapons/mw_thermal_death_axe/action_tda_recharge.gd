# THE THERMAL DEATH AXE'S RECHARGE (Leoleth rank II, design ruling 15):
#
#   "At the end of your turn, this weapon gains 1 charge if you have at least 4 spaces of unspent
#    movement."
#
# TOE TO TOE'S SHAPE AND TIMING (mt_toe_to_toe/action_toe_to_toe.gd): an ActionReactionSelf on
# end_turn at PRE, point-free, hidden. PRE because event_turn_end awaits its PRE reactions in
# execute_preblock (:15-17) while handle_ending_unit zeroes current.speed at :70 inside execute -
# at POST the budget is always zero and this could never fire.
#
# "UNSPENT MOVEMENT" IS current.speed, the pooled budget ruling 2 reads for Toe To Toe: set to
# get_speed_max() at turn start (unit_action.gd:77), raised by Boost (event_unit_boost.gd:37),
# reduced only by spend_move steps (event_unit_move.gd:244-245). A Boosted Leoleth that stepped
# once still has 7; a knockback never touches it. The card's number is 4, literal, not speed max -
# which happens to be the same number on this frame today, and would not be on a Leoleth carrying a
# speed bonus.
#
# Fires beside Toe To Toe on the same trigger and timing; order does not matter, because a free
# Skirmish does not touch current.speed. spec/test_thermal_death_axe.gd runs both in one end_turn.
#
# THE CAP is get_max_charges (gear_core.gd:235-246) rather than kit.charges_max, so a Limited bonus
# (an Engineer pilot) or a max_charges_override is honoured.
#
# NOTHING IS SPENT HERE, so there is no spend_actions() call - which also means no automatic
# "reacted" line in the battle log (UnitAction.spend is the only caller of log_usage). The log_gear
# line below is therefore the sole player-facing trace of this reaction, which is why the spec reads
# it off the bus rather than only asserting that its row resolves.
extends ActionReactionSelf

const UNSPENT_SPACES_REQUIRED := 4
const LOG_KEY := 'gear.mw_thermal_death_axe.action_tda_recharge.log'

## Bookkeeping, not a rule the player reads twice: the Kit's own effect row says everything there is
## to say, and a reaction never reaches the gear bar anyway (gear_bar.gd drops every ActionReaction).
## show_in_tooltip is a FUNCTION on Action (action.gd:341), not an exported property, so this is the
## only way to set it - the same shape as ms_heaer's detonate reaction.
func show_in_tooltip(_kit:Kit) -> bool: return false

## WITHOUT THIS THE REACTION CAN NEVER FIRE, and it was measured rather than reasoned: the first
## GREEN run had every recharge case red with the gate and the activation both correct.
##
## ReactionBus.does_reaction_trigger asks UnitAction.can_activate_gear BEFORE triggers_on_event
## (reaction_bus.gd:119-124), and Action.consumes_charges defaults TRUE (action.gd:108), so
## unit_action.gd:153 answers REASON.NO_CHARGES for an empty Kit. On a LIMITED 1 weapon "empty" is
## the ONLY state in which this reaction has anything to do - so the default would refuse it in
## exactly the case it exists for, silently and with no log line.
##
## Nothing here is spent (there is no spend_actions call), so false is also simply the truth.
func consumes_charges(_specific:SpecificAction) -> bool: return false

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return false
	# "if you have at least 4 spaces of unspent movement" - ruling 2's pooled budget.
	if unit.core.current.speed < UNSPENT_SPACES_REQUIRED: return false
	# "gains 1 charge": nothing to gain when it is already full, and a reaction that fires to do
	# nothing would still write a log line.
	return gear.charges_current < gear.get_max_charges(unit.core)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	# Re-checked rather than trusted: recheck_trigger_before_execution is false on the .tres, so the
	# gate above ran when the reaction was COLLECTED and another END_TURN PRE reaction could have
	# run in between.
	if gear.charges_current >= gear.get_max_charges(unit.core): return
	gear.charges_current += 1
	battle_log.log_gear(LOG_KEY, unit, gear)
