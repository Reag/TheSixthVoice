# TRAJECTORY ARC MAPPER's hidden, permanent accuracy buff (Purple Thorn SP2 Task 2, design ruling 10).
#
#   "When attacking a character whose distance from you is equal to the range of the weapon, you
#    gain +1 accuracy."
#
# Handshake Etiquette's shape (buff_handshake_etiquette.gd): a BuffWeaponTypeBonus on ATTACK_ROLL
# whose whole test lives in check_if_passive_applies, because that is the only hook handed the
# per-target context (attack_roll.gd:134 via unit_condition.gd:845-851) - get_values() gets none, and
# context.object is not yet the roll (event_unit_attack.gd:56), so nothing here may need one.
#
# "THE RANGE OF THE WEAPON" is ActionAttackWeapon.get_target_range, the LIVE number: aim_range plus
# every ACTION_RANGE buff (ranged_distance), or a Line/Cone's pattern value. A range mod moves the
# sweet spot with it. MELEE is forbidden on the .tres: a melee weapon has Threat, not Range, and
# get_target_range would hand back its threat - so an adjacent swing would otherwise always qualify.
# A THROWN attack is a melee weapon too, and is excluded by the same filter.
#
# "A CHARACTER" is is_actor(): the mod-wide row, design ruling 16 - a drone or an object is not one.
extends BuffWeaponTypeBonus

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	return Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	if not context.target_unit.is_actor(): return false
	var weapon:ActionAttackWeapon = context.action
	var distance:int = UnitRelation.distance_between(context.unit.get_attacker(context), context.target_unit)
	return distance == weapon.get_target_range(SpecificAction.from_context(context))
