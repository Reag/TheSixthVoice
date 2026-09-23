# STALK THE HORIZON (Purple Thorn, cp_lav_tactical_engine's passive), ruling 5:
#
#   "2/round, when a hostile character in Line of Sight starts to move, you may make an attack
#    against them with an Auxiliary weapon as a reaction."
#
# OVERWATCH'S CHASSIS (action_overwatch.gd:13-40) on ENTIRE_MOVEMENT PRE - the trigger that fires
# ONCE, before the move begins (event_unit_move.gd:70-71), which is what "starts to move" means to
# Overwatch and means here. The gate, clause by clause: can_affect (exiled and intangible movers are
# out), are_enemies ("hostile"), is_actor ("character" - ruling 16 / row 301: a drone is not one),
# MovementType.is_contextual_move_reactable (a teleport or an involuntary move is not "starts to
# move", exactly as for Overwatch), UnitRelation.can_see ("in Line of Sight" - THE TRAIT'S OWN
# GATE, over and above each weapon's: get_weapons_that_can_react_against checks a weapon's LOS
# only when the weapon requires it, and a SEEKING Aux does not, so without this clause the Blink
# Bolt Launcher (SP2) would let the trait fire through a wall), and a non-empty weapon list -
# Gunslinger's Return Fire filter verbatim (action_return_fire.gd:32-35): every weapon that can
# react against the mover at NORMAL RANGE (not threat), filtered to weapon_size AUX. Overwatch's
# re-entrancy guard closes it: the shot below is itself a gear use on this unit.
#
# IT SPENDS THE REACTION POINT (author's call): consumes_rxn stays true on the .tres, so the bus's
# can_activate_gear refuses it without a point, one shot per hostile turn is the natural ceiling
# (the point is refreshed for every unit at ANY turn start, event_turn_start.gd:42-44), it competes
# with Overwatch and with Shimmer (SP4) for that point, and it is jammable, stunnable and dazable
# like any real reaction. 2/ROUND is the hard limit on its own usage_group (Covering Fire's shape);
# action_reaction.gd:69 would make a point-spending reaction's default 1.
#
# THE SHOT: CommonActionUtil.choose_and_use with the trigger's own spend
# (choose_and_use_spend_action spends THIS reaction when the chosen weapon commits), the mover as
# the mandatory target, CAN_FOLLOWUP (an Aux/Aux pair fires both, as an Overwatch does), and NOT
# counts_as_overwatch: that flag is what Impaler, Punisher Ammunition, Marker Shells and
# Lockbreaker key on, and Stalk the Horizon is not Overwatch. The card says the attack is "as a
# reaction", so the shot carries AS_RXN - choose_and_use adds it because this action
# requires_reaction_available (common_action_util.gd:684-690).
#
# THE PREDICATE IS PURE (the Naga probe's rule): no spend, no stamp, no prompt in triggers_on_event.
extends ActionReaction

const USES_PER_ROUND := 2

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return USES_PER_ROUND

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource] # the mover and its MovementType

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	var mover:Unit = context.unit
	if not Unit.is_valid(unit) or not Unit.is_valid(mover): return false
	if not UnitRelation.can_affect(unit, mover): return false
	if not UnitRelation.are_enemies(unit, mover): return false # "hostile"
	if not mover.is_actor(): return false # "character" (row 301: not a drone, not an object)
	if not MovementType.is_contextual_move_reactable(context): return false # "starts to move"
	if not UnitRelation.can_see(unit, mover): return false # "in Line of Sight" - the trait's own gate
	if get_possible_auxes(unit, mover).is_empty(): return false # "with an Auxiliary weapon"
	if CommonActionUtil.is_choose_and_use_with_gear_in_progress(gear): return false # re-entrancy
	return true

## Return Fire's filter, verbatim: every weapon that can react against the mover at NORMAL RANGE,
## kept only if AUX. Static and side-effect free; the spec reads it too.
static func get_possible_auxes(from_unit:Unit, target_unit:Unit) -> Array[SpecificAction]:
	var weapons:Array[SpecificAction] = UnitRelation.get_weapons_that_can_react_against(from_unit, target_unit, true)
	Util.filter(weapons, func(weapon:SpecificAction) -> bool:
		return weapon.action.is_weapon_size(Lancer.WEAPON_SIZE.AUX))
	return weapons

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var mover:Unit = context.event.context.unit
	if activation.abort_without_units([unit, mover]): return
	var specific:SpecificAction = SpecificAction.from_context(context)
	await CommonActionUtil.choose_and_use(
		activation,
		specific,
		get_possible_auxes(unit, mover),
		CommonActionUtil.choose_and_use_spend_action, # spends THIS reaction when the shot commits
		mover,
		[Action.FLAG.CAN_FOLLOWUP],
		false # NOT overwatch: no IS_OVERWATCH, no Overwatch gear lock
	)
