# REND THAT WHICH IS CRUEL AND UNNATURAL (Purple Thorn, cp_lav_tactical_engine's active),
# rulings 6-7:
#
#   "You may immediately Skirmish as a free action. Until the end of your next turn, whenever you
#    deal damage to a hostile character, they must make a Systems save or be teleported to free
#    space you choose within range 3 of their original position."
#
# A QUICK ActionSystem that consumes the core power (both on the .tres). Its activate does three
# things in this order, and the order is the card's:
#
# 1. THE CONFIRM, then THE SPEND. CommonActionUtil.confirm_use for a player (a non-player unit
#    auto-confirms), then spend_actions - the archetype's own order (action_system_apply_buff.gd:
#    103, :122), so a declined confirm costs nothing and the core power is gone the moment the
#    player commits, whatever the free Skirmish then does.
# 2. THE CHIP. buff_cruel_and_unnatural on the Thorn, visible, until END_OF_NEXT_TURN - applied on the Thorn's own
#    turn, so it converts at the next turn start and clears at that turn's end
#    (unit_condition.gd:18-19, :34). Its DAMAGE POST trigger is the save-or-be-shoved; see
#    buff_cruel_and_unnatural.gd.
# 3. THE FREE SKIRMISH - PICK A WEAPON NOW (author's call, ruling 6): "immediately" is literal, so
#    CommonActionUtil.choose_and_use over every weapon this unit could Skirmish with right now,
#    with choose_and_use_no_spend (the shot costs the action economy nothing - choose_and_use adds
#    AS_FREEBIE itself, which waives action, boost and reaction costs and still spends LOADING,
#    charges and usage, unit_action.gd:236-277), no mandatory target (the player aims the shot),
#    CAN_FOLLOWUP (a Skirmish with an Aux/Aux pair fires both), and NOT counts_as_overwatch. The
#    Uncle-class Comp/Con's shape (action_uncle_class_comp_con.gd:40-45). Cancelling the weapon
#    pick, or its targeting, forfeits the shot; the chip stands and the core power is spent. A
#    Buff.TO.ACTION_FREE (Sekhmet's shape) was the alternative not taken: it would leave the shot for
#    later, and the card says now.
#
# "SKIRMISH": a weapon whose attack is a QUICK action (Main, Heavy, Aux - a Superheavy's is FULL,
# a Barrage, and is excluded), available to fire as a freebie right now (UnitAction.is_gear_available
# with as_freebie, so a weapon already fired this turn is still offered - AS_FREEBIE bypasses the
# per-turn soft limit, :114 - while LOADING, charges and destruction still refuse).
#
# THE DESIGN'S CALL PASSED `true` AS THE SEVENTH ARGUMENT, which is counts_as_overwatch, not
# can_voluntarily_cancel (that is the ninth, and defaults true). Passing it would have locked the
# Overwatch gear and stamped IS_OVERWATCH on a Skirmish - Uncle's shape passes nothing there, and
# neither does this. Corrected at build, 2026-09-23; recorded in the ledger.
extends ActionSystem

## The visible chip - buff_cruel_and_unnatural.tres.
@export var chip:Buff

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var specific:SpecificAction = SpecificAction.from_context(context)

	# 1. THE CONFIRM, THEN THE SPEND.
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(unit): return
	spend_actions(activation)

	# 2. THE CHIP.
	apply_buff(activation, unit, chip)

	# 3. THE FREE SKIRMISH, NOW.
	var weapons := skirmishable_weapons(unit)
	if weapons.is_empty(): return # nothing to Skirmish with; the chip stands
	await CommonActionUtil.choose_and_use(
		activation,
		specific,
		weapons,
		CommonActionUtil.choose_and_use_no_spend, # the shot costs the action economy nothing
		[], # no mandatory target: the player aims the shot
		[Action.FLAG.CAN_FOLLOWUP],
		false # NOT overwatch
	)

## Every weapon attack this unit could Skirmish with right now: QUICK (not a Superheavy's FULL),
## and available as a freebie. Static and side-effect free; the spec reads it too.
static func skirmishable_weapons(unit:Unit) -> Array[SpecificAction]:
	var weapons:Array[SpecificAction] = []
	for gear:GearCore in unit.core.loadout.get_all_weapons():
		for action:ActionAttackWeapon in gear.kit.get_weapon_actions():
			var candidate := SpecificAction.create(unit, gear, action)
			if action.get_action_type(candidate) != Lancer.ACTION.QUICK: continue
			if not UnitAction.is_gear_available(candidate, true): continue
			weapons.append(candidate)
	return weapons
