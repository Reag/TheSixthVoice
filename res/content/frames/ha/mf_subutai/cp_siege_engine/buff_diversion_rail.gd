## The DIVERSION RAIL's on-hit chip: +2 difficulty on every attack the target makes that is NOT
## aimed at the Subutai, until the end of their next turn.
##
## THE VALUE IS CONSTANT AND THE GATE DOES ALL THE WORK, and that split is forced by the engine
## rather than chosen. AttackRoll.PreAttack.create gathers ATTACK_ROLL buffs from the attacker with
## the PER-TARGET roll's context (attack_roll.gd:134) but calls buff_core.get_values() BARE, with no
## context at all (:184) - so get_values cannot see which roll it is modifying. Only
## check_if_passive_applies is handed the context, and that context's target_unit is THAT roll's
## target. So: bonus_value = -2 on the .tres, and one question here.
##
## The consequence is the behaviour the card wants, for free: a Blast catching the Subutai and two
## others is at -2 on the two rolls and +0 on the Subutai's, from a single buff. Same shape as the
## M/K2's Hybridized Shot, whose header records the same reasoning at length.
##
## "ALL ATTACKS" IS LITERAL AND NEEDS NO HELP. Tech attacks, Ram and Grapple all resolve through
## PreAttack.create, so naming none of them is what covers all of them.
##
## THE OWNER COMES FROM from_gear. OnHitEffect.apply_statuses_and_buffs applies this buff to the
## attacked unit with context.gear as from_gear, so BuffCore.get_owner_unit(map) resolves to the
## Subutai that fired. A lost owner would compare against null, every comparison would be true, and
## the -2 would silently apply to attacks on the Subutai as well - the one case the card exempts.
extends BuffBonus

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	# A roll with no target (a tile-only effect that still gathers ATTACK_ROLL buffs) is not "an
	# attack that does not target the Subutai" in any useful sense; refuse rather than guess.
	if not Unit.is_valid(context.target_unit): return false
	return context.target_unit != core.get_owner_unit(context.map)
