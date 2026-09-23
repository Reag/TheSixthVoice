# BLESSED BOLT's +3 (ruling 4): a one-time BuffDamage to bonus_damage_specific, hung on the Thorn
# by action_blessed_bolt at ATTACK POST and read by roll_specific_bonus_damage a moment later
# (event_unit_attack_declared.gd:269-296) with the roll in context.object and its victim in
# context.target_unit.
#
# GATED ON THE ROLL IT WAS OFFERED ON. One Blast is one attack with several rolls, and the reaction
# is offered on the first hit alone (1/round); without this gate the buff would be read for EVERY
# roll's specific bonus damage and the +3 would land on every victim. The reaction stamps the
# victim's persistent id in this core's state; the gate compares it to the roll's target.
#
# THE GATE IS DEFENSIVE, AND NO SPEC CAN REACH IT FIRST - recorded rather than hidden (measured
# 2026-09-23, Task 3 mutation 2: `return true` here reddens NOTHING). roll_specific_bonus_damage
# consumes the buffs it read right after the FIRST roll they applied to
# (event_unit_attack_declared.gd:296, consume_buffs), and the reaction is offered on the first
# hit's roll, so by the time the Blast's second victim is rolled the onetime buff is already gone.
# The gate stays because the two facts are independent: a change to when specific bonus buffs are
# consumed, or an offer that lands on a later roll, would make it load-bearing again, and ruling 4
# is explicit that the +3 belongs to the hit that was offered.
#
# The rest is BuffDamage's own: damage_dice "3" (flat, rolls nothing), inherit_type_from_attack
# ("+3 bonus damage" is of the weapon's type - the Nexus's kinetic, a thermal pistol's energy),
# require_hit (which BuffDamage itself says works only with SPECIFIC - this is SPECIFIC), onetime
# (consumed by roll_specific_bonus_damage's consume_buffs), until FINISH_DAMAGE (cleared after the
# attack's damage either way, so nothing leaks to the next attack), hidden.
extends BuffDamage

## Buff core state: the persistent id of the target whose hit was offered the bonus.
const TARGET_KEY := 'blessed_bolt_target'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not (context.object is AttackRoll): return false
	var roll:AttackRoll = context.object
	if not Unit.is_valid(roll.target_unit): return false
	return String(roll.target_unit.core.persistent_id) == core.get_state(TARGET_KEY, '')
