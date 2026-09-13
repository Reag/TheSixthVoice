## Hole Puncher, cover half (2 of 2): the soft cover the trait hands an unseen target, expressed as
## a labelled -1 on the attack roll rather than through Buff.TO.COVER.
##
## WHY IT EXTENDS BuffBonus AND NOT Buff. attack_roll.gd:182-189 reads an ATTACK_ROLL buff's value
## with `buff_core.get_values()` and NO CONTEXT AT ALL, so the -1 has to be a constant that
## BuffBonus renders from bonus_subtype + bonus_value. A get_values() that tried to compute anything
## from the context would see an empty one and silently contribute nothing. The weapon-and-blindness
## gate runs earlier and separately, in UnitCondition.get_buffs_to(unit, Buff.TO.ATTACK_ROLL,
## context), which DOES receive the full context - which is why the gate lives in
## check_if_passive_applies below and the value does not.
##
## WHY NOT Buff.TO.COVER. CoverCalculator.determine_cover merges COVER buffs from both units with
## the geometry and keeps the BEST of them, and its buff context carries only {unit, target_unit} -
## no gear, no action (cover_calculator.gd:56-62). So that channel can express neither ruling 2
## (behind a wall that would give HARD, max-then-zero keeps the HARD) nor ruling 3 (it cannot see
## which weapon is firing). Paired with buff_hole_puncher_ignore_cover, which erases the geometry,
## this gives the "exactly soft" the rules text asks for.
extends BuffBonus

const HolePuncher := preload('./buff_hole_puncher_arcing.gd')

## Mirrors BuffWeaponType's own validity check (buff_weapon_type.gd:26-32) plus the target, because
## BuffBonus extends Buff directly and Buff's default answers true for anything.
func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return (
		Unit.is_valid(context.unit) and
		Unit.is_valid(context.target_unit) and
		GearCore.is_valid(context.gear) and
		Action.is_valid(context.action) and
		context.action is ActionAttackWeapon
	)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not HolePuncher.applies_to_weapon(context): return false
	# A weapon that already ignores cover in its own right (SP4's Carronade) is not made worse by
	# the trait: there is no cover for the trait to be "exactly" equal to.
	if context.action.ignores_cover(context): return false
	return not UnitRelation.can_see(context.unit, context.target_unit)
