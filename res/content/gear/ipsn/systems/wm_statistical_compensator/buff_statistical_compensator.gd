# STATISTICAL COMPENSATOR's +2 Reliable (Hazard rank II weapon mod, SP3 Task 2, design ruling 11 as
# amended by the SP3 probe). Applied permanently by the mod's PassiveWeaponMod, so from_gear is the
# mod and from_weapon_mod limits it to the weapon the mod is fitted to (buff_weapon_type.gd).
#
# SILENT UNTIL ARMED. It adds +2 only to an attack whose DeclaredAttackSummary the prompt
# (action_statistical_compensator.gd) stamped; everywhere else - the weapon card, an unstamped
# attack - it does not apply at all, so no "+0" is drawn.
#
# CARD ONLY. The +2 the engine actually reads is raised by the prompt itself, through
# native_reliable.gd (see action_statistical_compensator.gd). This buff pays nothing: until
# 2026-09-24 it triggered at ATTACK_DECLARED POST and paid through reliable_topup.gd.
extends BuffWeaponTypeTag

## The per-attack stamp on the DeclaredAttackSummary.
const ARMED_META := &'reag_statistical_compensator_armed'

static func arm(declared_context:Context) -> void:
	if DeclaredAttackSummary.is_valid(declared_context.resource):
		declared_context.resource.set_meta(ARMED_META, true)

static func is_armed(context:Context) -> bool:
	return DeclaredAttackSummary.is_valid(context.resource) and context.resource.has_meta(ARMED_META)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not is_armed(context): return false
	return super(core, context)
