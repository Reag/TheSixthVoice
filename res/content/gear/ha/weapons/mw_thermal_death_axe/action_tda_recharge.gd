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
# FIRES BESIDE TOE TO TOE ON THE SAME TRIGGER AND TIMING - AND IN PRODUCTION THE TRAIT SWINGS FIRST.
# END_TURN PRE reactions are COLLECTED in one pass and only then executed: EventCore's
# execute_reaction_events takes the whole block list back from reaction_bus.trigger_occurred and
# awaits it afterwards (event_core.gd:52-55), so every gate below is evaluated BEFORE any reaction in
# the batch has run. The collection order is loadout.reactions_by_trigger, built by walking
# get_reactions() (loadout_core.gd:291-296), which filters get_all_gear() - attacks, systems, TRAITS,
# then MOUNTS (:511-518). A Heavy Melee weapon is MOUNTED in play and Toe To Toe is a frame TRAIT, so
# the free Skirmish is collected and swung before this reaction is executed.
#
# THE GATE IS THEREFORE THE SPEED CLAUSE AND NOTHING ELSE. A charge check here would be read against
# the axe as it stood BEFORE the Skirmish: a FULL axe would never be collected at all, Toe To Toe
# would then swing Thunderous and spend the charge, and the turn would end empty - while the card
# says the weapon gains one. Simultaneous end-of-turn effects resolve in the player's order, and
# Skirmish-then-recharge is the faithful reading of that.
#
# THE CAP MOVES TO activate(), where it is read AFTER the swing. Returning early there costs nothing:
# event_gear_activate's execute just calls activate (:79-80), its post-activation block is gated on
# the usage tally actually MOVING (:100-104), and log_usage is reached only from UnitAction.spend
# (unit_action.gd:233) - which this action never reaches, because it has no spend_actions() call. So
# a recharge that fires on a full axe spends nothing and writes no battle-log line.
#
# spec/test_thermal_death_axe.gd runs both reactions in one end_turn, in both collection orders.
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

## get_required_triggering_context is NOT overridden here: ActionReactionSelf's own returns
## [Context.PROP.unit] already (action_reaction_self.gd:8-9), and a byte-identical copy only invites
## the two to drift apart.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return false
	# "if you have at least 4 spaces of unspent movement" - ruling 2's pooled budget, and the ONLY
	# clause here. The cap is deliberately NOT read at collection time; see the header.
	return unit.core.current.speed >= UNSPENT_SPACES_REQUIRED

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	# THE CAP, READ HERE AND NOWHERE ELSE - see the header. The gate above ran when the whole END_TURN
	# PRE batch was COLLECTED, before Toe To Toe's free Skirmish had a chance to empty this weapon, so
	# a full axe at collection time can be an empty one by now. "Gains 1 charge" has nothing to add
	# only when the axe is still full at THIS moment.
	if gear.charges_current >= gear.get_max_charges(unit.core): return
	gear.charges_current += 1
	battle_log.log_gear(LOG_KEY, unit, gear)
