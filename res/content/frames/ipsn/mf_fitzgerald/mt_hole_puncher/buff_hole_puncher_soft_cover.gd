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
##
## WHERE THE LINE APPEARS IN THE UI, which is engine-forced and not a defect. attack_roll.gd:188
## passes `buff_core.base.to == Buff.TO.ATTACK_ROLL` as AccuracyMod's `_from_attacker` flag, while
## genuine cover passes false (attack_roll.gd:167), and attack_preview_column.gd:18 splits the
## breakdown on exactly that flag. So "Soft cover (Hole Puncher)" sits on the ATTACKER'S side of the
## attack preview rather than the target's, where a cover line normally reads. Every ATTACK_ROLL buff
## in the game lands there; there is no mod-side seam that moves it. Do not chase it.
extends BuffBonus

const HolePuncher := preload('./buff_hole_puncher_arcing.gd')

## BuffBonus extends Buff directly and Buff's defaults answer true for anything, so the two halves
## BuffWeaponType would have supplied - the validity check and the basic-gear guard - are taken from
## the shared statics on buff_hole_puncher_arcing.gd instead of being re-typed here. Re-typing them
## is what let this buff drift from its two siblings before: it had the validity check but not the
## guard, so a basic Cannon or Line weapon would have taken the -1 while getting neither the ARCING
## nor the cover erasure it is priced against.
func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return HolePuncher.is_weapon_context_valid(context) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if HolePuncher.is_gear_basic(context): return false
	if not HolePuncher.applies_to_weapon(context): return false
	# A weapon that already ignores cover in its own right (SP4's Carronade) is not made worse by
	# the trait: there is no cover for the trait to be "exactly" equal to.
	if context.action.ignores_cover(context): return false
	return not UnitRelation.can_see(context.unit, context.target_unit)
