## Hole Puncher, cover half (1 of 2): while the Fitzgerald cannot see its target, a Cannon or Line
## shot ignores cover geometry outright. PreAttack.create skips the cover calculation entirely when
## the attacker holds ANY IGNORE_COVER buff (attack_roll.gd:153-157), so geometry can never
## contribute hard cover.
##
## Paired with buff_hole_puncher_soft_cover, which puts the trait's own soft cover back as a
## labelled -1; together they make the cover "exactly soft" (ruling 2), which the engine's
## max-then-zero cover channel cannot express.
##
## "Attacked this way" (ruling 1) is read as "the target was not in the attacker's line of sight
## when the attack was rolled" - so a Cannon shot at a SEEN target keeps ordinary cover rules and
## this buff stays out of it.
extends BuffWeaponType

const HolePuncher := preload('./buff_hole_puncher_arcing.gd')

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super.is_buff_context_valid_for_passive(core, context) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not HolePuncher.applies_to_weapon(context): return false
	# context.unit, not the resolved attacker: if a relay is in play it is the relay's sight that
	# the shot is taken along, which is the unit the engine hands us here.
	return not UnitRelation.can_see(context.unit, context.target_unit)
