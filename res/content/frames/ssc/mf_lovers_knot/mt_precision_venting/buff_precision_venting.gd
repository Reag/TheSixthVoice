## PRECISION VENTING: supplies an ON_CRIT OnHitEffect to the Lovers Knot's RANGED attacks, once a round.
##
## The Maiden's Blush's Rend with the weapon filter inverted (design 1.2, ruling 4): MELEE is forbidden
## declaratively on the .tres, so every other ActionAttackWeapon - Blast, Burst, Cone, Line included -
## is "a Ranged weapon", exactly UnitAction.is_ranged_weapon's reading. Basic gear is excluded by
## BuffWeaponType.allow_basic's default.
##
## THE ROUND IS HAND-ROLLED because the engine never enforces one for a buff-triggered effect -
## ReactionBus consults per-round limits only for ActionReactions (reaction_bus.gd:116-124). The counter
## lives on the trait gear and resets at the Knot's own turn start (unit_action.gd:86-87, ruling 3). On a
## Line the gate holds across targets, because each per-target event re-collects its on-hit buffs
## (event_unit_attack.gd:47) and so re-reads the counter the previous target's crit just raised.
##
## AT 0 HEAT IT DOES NOT FIRE AND THE ROUND IS KEPT (ruling 5): the heat gate is checked here, before the
## effect is ever handed out, so the counter is never reached. event_unit_cool would refuse at 0 anyway
## (event_unit_cool.gd:17-22), but only after the increment had burnt the use.
##
## ONLY THE KNOT'S OWN ATTACKS (ruling 4): the buff sits on the Knot and is only ever collected for
## the Knot's attacks, but the holder check below says so rather than leaving it to where the engine
## happens to look.
##
## THE MYRIAD HOOK (ruling 20). While Form of the Myriad's chip is held, the round gate stands down and
## every qualifying crit clears. onhit_precision_venting.gd is the other half: under the chip it still
## clears heat, but skips the increment, so the round is never spent while the chip is up either.
extends BuffWeaponTypeOnHit

const USAGE_KEY:StringName = &'precision_venting'
const MYRIAD_CHIP:StringName = &'buff_form_of_the_myriad'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var holder:Unit = core.get_holder_unit(context.map)
	if not Unit.is_valid(holder) or context.unit != holder: return false
	if holder.core.current.heat <= 0: return false
	if UnitCondition.has_buff(holder, MYRIAD_CHIP): return true
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0
