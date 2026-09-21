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
## NO `until`, AND FINISH_DAMAGE IS THE ONE VALUE THAT MUST NOT BE SET. Task 2's review asked for
## `until = 9` and the measurement refused it; both halves are worth keeping, because the review's
## engine reading was correct and its conclusion still does not hold.
##
## THE PLAN'S ORIGINAL REASON WAS WRONG. It read "FINISH_DAMAGE would be cleared for the OWNER and
## the TARGET (:204, :209), neither of which is the attacker when an ally shot". `owner` there is
## `context.unit.get_attacker(context)` (event_unit_attack_declared.gd:29) - it IS the attacker,
## whoever fired - and that sweep runs AFTER the damage events at :199, so on its own it would have
## been harmless and would indeed have bounded the buff.
##
## WHAT REFUSES IT IS A DIFFERENT SWEEP. event_unit_damage.gd:76-77 clears every FINISH_DAMAGE buff
## ON THE DAMAGED UNIT whenever a damage instance consumes resist buffs. This reaction's own 2 ENERGY
## to the Sluagh is queued at POST, so it resolves BEFORE the attack's damage roll - and when the
## SLUAGH is the attacker, the buff is sitting on the Sluagh. Its own self-damage sweeps it, and
## roll_specific_bonus_damage (:268-296) then finds nothing.
## Measured: with until = 9 the Sluagh's own covered hit dealt 3 instead of 6, logging no bonus line
## at all, and the blast case fell the same way - while every ALLY-fired case stayed green, because
## there the buff is on the ally and the self-damage is on the Sluagh. 18/20, and the two reds are
## exactly the two cases where attacker and payer are the same unit.
##
## SO THE LIFETIME IS is_onetime ALONE, consumed at :296 by the roll that read it, and pinned by
## test_the_bonus_is_consumed_by_the_roll_that_read_it_and_does_not_ride_the_next_shot. The abort
## path the review was protecting against - :200's abort_if_level_exited returning between this
## reaction and the damage roll - is real and is NOT covered by anything here. It is recorded as an
## open question rather than papered over, because every lifetime that would close it also has to
## survive the Sluagh's own self-damage landing first.
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
