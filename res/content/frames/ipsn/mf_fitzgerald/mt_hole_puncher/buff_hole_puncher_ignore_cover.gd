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
##
## BUFF.TO.IGNORE_COVER IS A DUAL-PURPOSE CHANNEL, and this buff is attacker-only. buff.gd:35 spells
## the two purposes out - "(attacker) see-through seeker, kill with my heart; (defender) markerlight,
## wrecks" - and attack_roll.gd:160 runs the SECOND query against the unit being shot at:
##
##   get_buffs_to(attacked_unit, Buff.TO.IGNORE_COVER, Context.clone(context, {category = ...}))
##   ... if not empty: cover_result.total = Lancer.COVER.NONE
##
## In that query context.unit / .action / .gear still describe the ENEMY and the enemy's weapon, and
## context.target_unit is the Fitzgerald. Every clause below reads TRUE there whenever an enemy
## blind-fires a Cannon at us - stock mw_mortar and mw_howitzer are Arcing Cannons that do exactly
## that - so without the owner guard the trait would strip the FITZGERALD'S OWN cover: the precise
## inverse of its text. The guard is the whole of the fix; see test_hole_puncher.gd's
## test_an_enemy_blind_firing_a_cannon_does_not_strip_the_fitzgeralds_own_cover.
extends BuffWeaponType

const HolePuncher := preload('./buff_hole_puncher_arcing.gd')

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super.is_buff_context_valid_for_passive(core, context) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	# Attacker-only. `is_unit_owner` rather than `get_owner_unit() == context.target_unit` because it
	# answers the same question off the unit's own loadout (buff_core.gd:97-100) instead of going
	# through X.map(), which get_owner_unit falls back to when handed no map (buff_core.gd:102-105).
	if core.is_unit_owner(context.target_unit): return false
	if not super.check_if_passive_applies(core, context): return false
	if not HolePuncher.applies_to_weapon(context): return false
	# context.unit, not the resolved attacker: if a relay is in play it is the relay's sight that
	# the shot is taken along, which is the unit the engine hands us here.
	return not UnitRelation.can_see(context.unit, context.target_unit)
