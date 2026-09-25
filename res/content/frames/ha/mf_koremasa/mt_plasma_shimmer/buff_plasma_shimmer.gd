## PLASMA SHIMMER's chip: +1 Difficulty on every attack against the Koremasa while it is in the
## DANGER ZONE (design 1.2, ruling 17).
##
##   "While it's in the DANGER ZONE, attacks against the Koremasa have +1 Difficulty."
##
## THE VALUE IS CONSTANT AND THE GATE DOES ALL THE WORK - the Gravity Well's split, forced by the
## engine: AttackRoll.PreAttack.create gathers ATTACK_ROLL_INCOMING buffs from the ATTACKED unit with
## the roll's context (attack_roll.gd:135) but calls get_values() bare (:184), so only this hook sees
## which roll it is on. bonus_value = -1 lives on the .tres.
##
## EVERY ATTACK, TECH INCLUDED (ruling 17): both kinds build their PreAttack through the same create
## (event_unit_attack.gd:53), so there is no type test here at all. The Gravity Well's
## `is ActionAttackWeapon` test is absent on purpose - its card said "ranged and melee", this one says
## "attacks".
##
## THE HOLDER IS context.target_unit, the attacked unit whose buffs were gathered (attack_roll.gd:116,
## :135) - always this chip's own Koremasa, because the chip is applied to its holder alone
## (PassiveBuffApplicator, not an aura). DANGERZONE is the engine's own status, heat >= half the cap
## rounded up (unit_condition.gd:591-597): 4 of 8. It is the Tokugawa's Plasma Sheath's gate, read on
## the defender instead of the attacker.
##
## A LOST TARGET REFUSES rather than guessing: a gate that runs on every roll must answer, not throw.
extends BuffBonus

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var koremasa:Unit = context.target_unit
	if not Unit.is_valid(koremasa): return false
	return koremasa.has_status(Lancer.STATUS.DANGERZONE)
