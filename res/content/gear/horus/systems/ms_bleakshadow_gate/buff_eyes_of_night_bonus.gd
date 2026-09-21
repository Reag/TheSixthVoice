## THE +3, scoped to one defender of one attack.
##
## A BuffDamage on Buff.TO.BONUS_DAMAGE_SPECIFIC: "applied to specific units; not halved like
## normal bonus damage" (buff.gd:31). It is read per attack roll by roll_specific_bonus_damage
## (event_unit_attack_declared.gd:268-296) with `target_unit = attack_roll.target_unit` in the
## context - and consumed there (:296), because is_onetime. SP4 Task 0 measured that a buff applied
## at ATTACK / POST is read by that same roll.
##
## WHY IT IS SCOPED AT ALL: a Blast lands one per-target attack event per unit hit, and Eyes of
## Night fires on the FIRST of them. Without this clause the buff would sit on the attacker while
## the second roll asks the channel - and be rolled into it too, before consumption at :296 had a
## chance to run for the first. The stamped id is the defender of the roll the reaction answered.
##
## NO `until`. Applied at POST and consumed by the same attack's damage roll, it never survives to
## a turn end; FINISH_DAMAGE would be cleared for the OWNER and the TARGET (:204, :209), neither of
## which is the attacker when an ally shot. Plan departure 3.
##
## can_apply_to_tech_attacks IS SET on the .tres: the card says "hit an enemy", and an invade's +3
## inherits the attack's type - HEAT (INHERIT_TYPE, buff_damage.gd:36-37; action_attack_tech.gd:18).
## NOTE (Task 2, measured): no tech attack can currently REACH this buff, because the reaction that
## applies it needs roll.pre.cover and PreAttack.create computes cover only for an ActionAttackWeapon
## (attack_roll.gd:152-156). The flag is kept because it is the card's wording, and because the day
## a tech attack does carry cover this buff must not silently refuse it. See the spec's
## test_an_invade_on_a_covered_enemy_offers_nothing_because_a_tech_attack_computes_no_cover.
extends BuffDamage

const DEFENDER_KEY := 'eyes_defender'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not Unit.is_valid(context.target_unit): return false
	return context.target_unit.core.persistent_id == core.get_state(DEFENDER_KEY, '')
