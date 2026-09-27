## HYPNOTIZE'S TARGETING RULE (Naga SP2 Task 2, ruling 12): "Allied characters attacks against the
## target may choose to target either Evasion or E-Defense regardless of if the weapon is smart."
##
## BUILT AS AN AUTOMATIC LOWER DEFENCE (the author's pick), because no buff channel reaches the
## defence an attack targets: calculate_target_defense is chosen by the per-ACTION virtual
## get_against_attack_type (attack_roll.gd:128), and the only lever on it is the SMART tag
## (action_attack_weapon.gd:250-252), which WEAPON_TAG buffs can ADD and nothing can remove. So:
## grant Smart exactly when the target is Hypnotized AND its E-DEF is the LOWER number. A tie changes
## nothing either way, so it is left alone.
##
## DIVERGENCE, recorded: a weapon that is ALREADY Smart cannot switch to Evasion when Evasion is the
## lower number - only the E-Defense half of "either" is reachable. Hypnotize scans first, so the
## numbers are known and a prompt could never beat the lower one.
##
## "ALLIED CHARACTERS" - A DRONE ATTACKS AS ITS OWNER (author decision 2 at the frame close,
## 2026-09-23; mod-wide rulings row 301, Draw Fire's rule, over design section 2.2). The attacker is
## resolved through Unit.get_attacker (unit.gd:276-282: the owner, unless the unit holds a
## SET_ATTACK_ROOT buff), and it must then be a character by ruling 21 (is_actor(), unit.gd:117) and an
## ally of the Naga who owns this buff. The aura reaches a drone itself (is_character is true of one,
## unit.gd:116), which is how its weapon gets the tag at all; an UNOWNED drone resolves to itself and
## is refused, and so is a drone on our side whose owner is not.
##
## NO LEAK ONTO THE SHEET: with no target_unit in the context the context is not valid for this buff
## at all, so a weapon card read without a target never shows Smart.
extends BuffWeaponTypeTag

const HYPNOTIZED := &'buff_hypnotized'

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super(core, context) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(attacker) or not attacker.is_character(): return false
	var naga := core.get_owner_unit(context.map)
	if not Unit.is_valid(naga) or not UnitRelation.are_allies(attacker, naga): return false
	var target:Unit = context.target_unit
	if not UnitCondition.has_buff(target, HYPNOTIZED): return false
	return target.get_edef() < target.get_evasion()
