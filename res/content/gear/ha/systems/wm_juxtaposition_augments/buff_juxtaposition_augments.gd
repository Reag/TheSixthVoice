## JUXTAPOSITION AUGMENTS' chip (Koremasa rank III weapon mod, design ruling 30): "While you are in the
## Danger Zone, you may reroll the first attack made with this weapon each round, but must keep the
## second result."
##
## THE DEATH'S HEAD'S NEUROLINK (buff_neurolink.tres), aimed at one weapon: a one-time
## BuffModifyAttackRoll at reroll_take_second with needs_confirmation, which the engine asks for itself
## and never on a crit (event_unit_attack.gd:264-305). Without CAN_BANK the engine consumes it whether
## the player rerolls or not (:271, :303) - "the FIRST attack", however it was answered.
##
## TWO GATES, both on top of BuffModifyAttackRoll's own (attacker-side, weapon attacks only):
## - THIS weapon: the chip is applied from the mod's GearCore (PassiveWeaponMod.applied_buffs,
##   unit_condition.gd:884-891), so from_gear is the mod's persistent id and the weapon names its mods
##   by that id - BuffWeaponType's from_weapon_mod test (buff_weapon_type.gd:53).
## - the DANGER ZONE, read at the roll: heat >= half the cap, rounded up (unit_condition.gd:591-597).
##
## A chip that did not apply is not consumed by the engine, so an out-of-zone first attack would leave
## it for a later one. onhit_juxtaposition_augments.gd spends it after ANY attack with the weapon
## (ruling 30). Re-armed at every turn start (reapply_at_the_start_of_each_turn): per turn, ruling 18.
extends BuffModifyAttackRoll

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not GearCore.is_valid(context.gear) or not context.gear.is_weapon_mod_attached(core.from_gear): return false
	var holder := core.get_holder_unit(context.map)
	return Unit.is_valid(holder) and holder.has_status(Lancer.STATUS.DANGERZONE)
