# ADVANCED TARGETING CALCULATIONS (Naga, mt_advanced_targeting_calculations), rulings 2-5:
#
#   "The Naga's Smart weapons Critically Hit on an attack roll of 18 or higher rather than 20."
#
# THE SEAM IS turn_hit_to_crit, NOT THE DICE (Spike 6, specs/2026-09-22-crit-threshold-feasibility.md).
# attack_roll.gd:73 decides a crit unconditionally on a class_name RefCounted no extension can reach,
# and neither dice.gd nor unit_hasecheck.gd mentions a crit - but EventUnitAttack.prospective_hit
# (event_unit_attack.gd:196-210) re-asks every MODIFY_ATTACK_ROLL buff at
# SEQUENCE_STEP.turn_hit_to_crit with the AttackRoll in context.object and the weapon in
# context.action, and a confirmation re-routes the roll through prospective_crit. Markerlight's Weak
# Spot is the vanilla user of the step; the Gorgon's Metastatic Paralysis is the vanilla precedent
# for a FRAME TRAIT on this channel. A permanent attacker-side buff gated on the roll and the tag is
# the whole build. The spike's Crit18 stand-in IS this class; the spike's probe is retired by the
# spec that pins this file (test_advanced_targeting_calculations.gd), because both would otherwise
# apply.
#
# WHAT THE ENGINE DOES FOR US, all measured by the probe: never a crit out of a MISS (the step is a
# step of prospective_HIT, so a miss is never asked) or out of an AUTO-HIT (total_roll 0); crit
# immunity still demotes it AFTER our step (prospective_crit :222-223); a permanent buff is not
# consumed by its own use (consume_buffs keeps only is_onetime, unit_condition.gd:938); no prompt
# with needs_confirmation = false.
#
# "SMART WEAPONS" IS THE LIVE TAG SET (ruling 3): has_tag(SMART, context) reads
# get_weapon_tags(context), which merges Buff.TO.WEAPON_TAG grants and mod tags
# (action_attack_weapon.gd:160-172). A weapon made Smart by another effect - a mod, Smart Ammo, a
# Prototype Weapon, and the mod's own Hypnotize grant (SP2, ruling 12) - crits on 18 too.
#
# THE THRESHOLD IS AN @export (ruling 4), not a constant: BATS (SP4, ruling 19) shares the step and
# may reuse the class with a different gate, and the spike's mutation 1 shows the number is what a
# spec pins.
#
# VISIBLE (ruling 2): the chip is the frame's signature rule, and the Sixth Voice's rule since the
# Leoleth close is that a trait the player cannot see reads as "does nothing". Metastatic Paralysis
# hides its buff; this one does not. Its .tres therefore leaves hide_from_player false and carries
# an icon (SP5's).
#
# THE WEAK SPOT DOUBLE-PROMPT IS ACCEPTED (ruling 5): check_buffs_for_step asks every confirming
# buff before consuming any and ORs the answers (event_unit_attack.gd:372-381), so a Markerlight
# ally is still asked about an 18 this buff is about to crit anyway. Player-controlled, pre-existing.
extends BuffModifyAttackRoll

## The total roll (d20 + accuracy + flat bonus, attack_roll.gd:71) at or above which a Smart hit is
## a crit. 18 is the card.
@export var threshold:int = 18

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	# The base class gates on the step, on holder == attacker, and on the allow_* class flags
	# (buff_modify_attack_roll.gd:34-49); is_buff_context_valid_for_passive already required an
	# AttackRoll in `object` and an ActionAttack in `action`.
	if not super.check_if_passive_applies(core, context): return false
	# A WEAPON attack - allow_tech is false on the .tres too, but the class test is what "Smart
	# weapons" means and it costs nothing to say it here.
	if not (context.action is ActionAttackWeapon): return false
	# Smart, as the engine reads it for THIS shot (ruling 3).
	if not context.action.has_tag(Lancer.WEAPON_TAG.SMART, context): return false
	var roll:AttackRoll = context.object
	return roll.total_roll >= threshold
