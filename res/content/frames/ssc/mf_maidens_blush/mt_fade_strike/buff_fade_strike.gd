## FADE STRIKE, the chip: reroll the first melee attack roll and keep the second result.
##
## EXTENDS BuffModifyAttackRoll because that archetype is the whole mechanism and has exactly one
## thing missing: it has no weapon-type filter (buff_modify_attack_roll.gd). Everything else -
## reroll_take_second, the confirmation, the consume-regardless-of-use rule - is declared on the
## .tres and executed by EventUnitAttack.handle_reroll_take_second.
##
## NOT BuffRerollMissAgainstNewTarget, despite living in buff_weapon_type_reroll_miss.gd and having a
## weapon-type filter: it serves Buff.TO.REROLL_MISS_AGAINST_NEW_TARGET and RE-TARGETS a miss (No
## Escape, Tlaloc). Different card entirely.
##
## "MELEE ATTACK ROLL" IS MOUNTED MELEE ONLY (ruling 12). The type test below is the added clause; the
## basic-gear exclusion comes free from BuffModifyAttackRoll.allow_basic being false on the .tres, so
## Ram, Grapple and the Improvised Attack - all weapon_type MELEE, all basic mw_ Kits - never consume
## the reroll before the real strike.
##
## super() FIRST, and it is doing real work: BuffModifyAttackRoll.check_if_passive_applies is what
## tests context.category_int == step (so the chip is only consulted at reroll_take_second),
## applies_when_holder_is, and the allow_weapon / allow_tech / allow_basic trio.
extends BuffModifyAttackRoll

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if context.action is not ActionAttackWeapon: return false
	return context.action.is_weapon_type(Lancer.WEAPON_TYPE.MELEE, context.gear)
