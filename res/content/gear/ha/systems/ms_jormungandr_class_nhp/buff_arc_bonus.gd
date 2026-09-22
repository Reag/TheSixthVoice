# THE A.R.C.'s BONUS DAMAGE (Leoleth rank III, design ruling 17):
#
#   "You deal +1d6 bonus damage on a successful melee attack against Slowed or Impaired targets."
#
# HIDDEN, AND APPLIED BESIDE buff_arc BY THE SAME PROTOCOL from the same GearCore - which is what
# lets buff_arc's own deactivation clear both with one clear_buffs_owned_by call. It is a second
# resource rather than a second job on the chip because a Buff carries ONE `to` channel, and the
# chip's channel is "none": it is a pure trigger.
#
# BONUS_DAMAGE_SPECIFIC, NOT PLAIN BONUS DAMAGE, and require_hit is why: require_hit is honoured
# only against an AttackRoll in context.object (buff_damage.gd:20, :25), which the SPECIFIC channel
# supplies per target (event_unit_attack_declared.gd:269-273) and plain bonus damage has no roll to
# ask. The specific channel is also never halved on an AoE, which is the right reading of a flat
# +1d6 against one target's condition.
#
# THE MELEE CLAUSE HAS TO BE WRITTEN BY HAND. BuffDamage carries no weapon filters at all - those
# live on BuffWeaponType, whose get_values returns a number rather than dice - so "on a successful
# melee attack" is this override, using the engine's own predicate (UnitAction.is_melee_weapon,
# unit_action.gd:549-553), the same one Toe To Toe's offer filter uses.
#
# THE CONDITION IS READ OFF context.target_unit, which roll_specific_bonus_damage clones onto the
# context per attack roll (event_unit_attack_declared.gd:270-273). A tech attack never reaches here
# at all: BuffDamage.check_if_passive_applies refuses one while can_apply_to_tech_attacks is false
# (buff_damage.gd:24), and the melee clause below would refuse it a second time.
extends BuffDamage

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if context.action is not ActionAttackWeapon: return false
	var weapon:ActionAttackWeapon = context.action
	if not UnitAction.is_melee_weapon(weapon, context.gear): return false
	if not Unit.is_valid(context.target_unit): return false
	return (
		UnitCondition.has_status(context.target_unit, Lancer.STATUS.SLOWED) or
		UnitCondition.has_status(context.target_unit, Lancer.STATUS.IMPAIRED)
	)
