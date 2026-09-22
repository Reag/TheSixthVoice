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
## "CHARACTERS" IS is_actor() (ruling 21): the aura's applies_only_to_characters lets a DRONE through
## (Unit.is_character is true of one, unit.gd:116), so the holder gate is here.
##
## NO LEAK ONTO THE SHEET: with no target_unit in the context the context is not valid for this buff
## at all, so a weapon card read without a target never shows Smart.
extends BuffWeaponTypeTag

const HYPNOTIZED := &'buff_hypnotized'

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super(core, context) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	if not context.unit.is_actor(): return false
	var target:Unit = context.target_unit
	if not UnitCondition.has_buff(target, HYPNOTIZED): return false
	return target.get_edef() < target.get_evasion()
