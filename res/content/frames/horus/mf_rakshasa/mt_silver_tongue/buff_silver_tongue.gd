## SILVER TONGUE, the offer: "1/round, when the Rakshasa misses with a tech attack, it may take 2 heat
## to reroll the attack against a different target within Sensors and line of sight." Design 1.3,
## rulings 7-11.
##
## THE ENGINE'S OWN SEAM: Buff.TO.REROLL_MISS_AGAINST_NEW_TARGET, which event_unit_attack.gd:308-339
## reads after every per-target roll, the Executioner's No Escape and the Tlaloc's protocol being the
## vanilla users. It offers get_values().array in one choose_unit and, on a pick, runs a NEW
## event_unit_attack on the same declared summary flagged WAS_REROLLED_AGAINST_NEW_TARGET - so ATTACK
## PRE and POST fire again and a hit lands the invade on the new target (ruling 11).
##
## EXTENDS Buff, NOT BuffRerollMissAgainstNewTarget: that archetype is a BuffWeaponType, whose
## is_buff_context_valid_for_passive and check_if_passive_applies both demand an ActionAttackWeapon
## (buff_weapon_type.gd:26-35) and whose get_valid_reroll_targets returns [] for anything else. Its
## body is re-implemented here for a TECH attack.
##
## NOT ONETIME, AND THAT IS THE WHOLE POINT (ruling 9). A onetime reroll buff is consumed BEFORE its
## target prompt (event_unit_attack.gd:317-320: consume_buffs filters to is_onetime,
## unit_condition.gd:936-938), so a cancelled pick would spend the 1/round, and an on_consumption
## heat charge would land before the player chose anything. So nothing here costs anything: the 2 heat
## and the round are paid by action_silver_tongue_pay, an ATTACK PRE reaction on the rerolled attack
## itself, and a cancel never reaches it. This gate reads that reaction's round off its usage group.
##
## Because it is not onetime, vanilla's own guard applies (buff_weapon_type_reroll_miss.gd:17-20): a
## rerolled attack is never rerolled again, or it would keep rolling forever.
##
## AI-CONTROLLED: NEVER (ruling 10). choice_bus.choose_unit has no AI answerer
## (choice_request_receiver.gd:29), so an AI Rakshasa's reroll would prompt the human.
extends Buff

## The Kit this buff comes from and the pay reaction on it, whose usage group carries the 1/round.
const PAY_ACTION := &'action_silver_tongue_pay'

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return (
		Unit.is_valid(context.unit) and
		GearCore.is_valid(context.gear) and
		Action.is_valid(context.action) and
		context.action is ActionAttackTech and
		DeclaredAttackSummary.is_valid(context.resource) and
		AttackRoll.is_valid(context.object)
	)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	# a rerolled attack is never rerolled again (vanilla's guard for a non-onetime reroll buff)
	if context.flags.has(Action.FLAG.WAS_REROLLED_AGAINST_NEW_TARGET): return false
	# only a MISS
	if AttackRoll.check(context.object, &'hit') != false: return false
	# the Rakshasa's OWN tech attack (a drone's buffs are its own; this one is on the Rakshasa)
	var holder:Unit = core.get_holder_unit(context.map)
	if holder != context.unit: return false
	if not holder.is_player_controlled(): return false
	# 1/round, spent only when a reroll actually runs (the pay reaction's usage group)
	if is_round_spent(core, context.map): return false
	# somebody else to reroll against
	if get_valid_reroll_targets(core, context).is_empty(): return false
	return true

func get_values(core:BuffCore, context:Context) -> Context:
	var owner_gear := core.get_owner_gear(context.map)
	return Context.create({
		array = get_valid_reroll_targets(core, context), # alternative targets
		unit = core.get_owner_unit(context.map),
		gear = owner_gear,
		action = owner_gear.get_action(PAY_ACTION) if GearCore.is_valid(owner_gear) else null,
	})

func is_round_spent(core:BuffCore, map:MapState) -> bool:
	var gear:GearCore = core.get_owner_gear(map)
	if not GearCore.is_valid(gear): return true
	var pay:Action = gear.get_action(PAY_ACTION)
	if not Action.is_valid(pay): return true
	return gear.get_uses_this_round(pay) >= 1

## Ruling 8: the tech action's own targetable set - Sensors, line of sight and can_target_unit, which
## is what UnitTargeting.get_tiles_targetable computes for the player's picker and the AI alike - of
## CHARACTERS (is_actor(), rulings row 301), allies included, minus the original target and the
## Rakshasa itself. vanilla's weapon version, buff_weapon_type_reroll_miss.gd:45-65, less its AoE
## branch: a tech attack has no area to re-use.
func get_valid_reroll_targets(_core:BuffCore, context:Context) -> Array[Unit]:
	var specific:SpecificAction = SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific) or specific.action is not ActionAttackTech: return []
	var targets:Array[Unit] = []
	targets.assign(context.map.get_all_units_at_tiles(UnitTargeting.get_tiles_targetable(specific)))
	Util.filter(targets, func(target:Unit) -> bool:
		return (
			Unit.is_valid(target) and
			target != context.target_unit and
			target != context.unit and
			target.is_actor()
		)
	)
	return targets
