# STATISTICAL COMPENSATOR's +2 Reliable (Hazard rank II weapon mod, SP3 Task 2, design ruling 11 as
# amended by the SP3 probe). Applied permanently by the mod's PassiveWeaponMod, so from_gear is the
# mod and from_weapon_mod limits it to the weapon the mod is fitted to (buff_weapon_type.gd).
#
# SILENT UNTIL ARMED. It adds +2 only to an attack whose DeclaredAttackSummary the prompt
# (action_statistical_compensator.gd) stamped; everywhere else - the weapon card, an unstamped
# attack - it does not apply at all, so no "+0" is drawn.
#
# THE PAYOUT is Weight of Fire's (buff_weight_of_fire.gd): this buff is in reliable_topup.gd's
# OPTED_IN, and it too triggers at ATTACK_DECLARED POST and hands off to the helper. Whichever of the
# two runs first pays for both together (their floors do not add linearly); the other sees the stamp
# the helper leaves and passes.
extends BuffWeaponTypeTag

const ReliableTopup := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/reliable_topup.gd')

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

# ---------------------------------------------------------------- the payout (ATTACK_DECLARED POST)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.action, Context.PROP.resource]

## The holder's own armed attack, not already paid. PURE: the bus may poll it more than once.
func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if ReliableTopup.is_paid(context): return false
	if not check_if_passive_applies(core, context): return false
	return ReliableTopup.extra_for(unit, context) > 0

func activate(_core:BuffCore, activation:EventCore) -> void:
	await ReliableTopup.pay(activation, activation.context.event.context)
