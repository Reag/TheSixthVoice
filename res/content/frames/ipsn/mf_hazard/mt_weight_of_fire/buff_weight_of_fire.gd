# WEIGHT OF FIRE's buff (Hazard, mt_weight_of_fire), ruling 2:
#
#   "All non-Auxiliary weapons mounted on the Hazard and adjacent allied mechs increase their
#    Reliable equal to half Grit. If they do not have Reliable, they instead gain that much."
#
# A WEAPON_TAG buff (action_attack_weapon.gd:169-172 reads it with the attacker's context and folds
# it in with add_tag_to_collection, which ADDS for Reliable, :129-137). Both halves of the card are
# "+N", so this is ADDITIVE: a Reliable-2 weapon under Grit 4 reads Reliable 4. That is the OPPOSITE
# of the Leoleth's REACH (buff_rage_reach_reliable.gd tops up to a target value because its card
# says "Reliable 2") - do not copy that file's arithmetic.
#
# THE HAZARD'S GRIT, NOT THE HOLDER'S. The aura applies this with its own gear as the source
# (passive_aura.gd:80), so core.get_owner_unit(map) is the Hazard wherever the buff sits - measured
# by spec/test_spike_hazard_sp1_seams.gd (a Grit-1 ally under a Grit-4 Hazard reads +2, not +1).
# Half rounds UP (Util.half is ceili, util.gd:14-15; Lancer's own rule): Grit 1 gives +1.
#
# GRIT 0 ADDS NOTHING AND DRAWS NOTHING. add_tag_to_collection writes the key even for a value of 0,
# so a +0 on a weapon WITHOUT Reliable would draw a "Reliable 0" tag on its card; the buff refuses to
# apply instead. (Grit 0 is licence level 0 only - Grit is itself rounded up.)
#
# THE CARD IS NOT THE DAMAGE. This buff's WEAPON_TAG half reaches get_weapon_tags - the weapon card -
# and nothing else: the engine reads the Reliable floor from the action's printed export only
# (event_unit_attack_declared.gd:82). So the buff ALSO triggers at ATTACK_DECLARED PRE, on the
# holder's own attacks, and has the shared native_reliable.gd raise that export for the length of
# the attack - the engine then floors every roll itself (author's ruling 2026-09-24: EXACT). Until
# 2026-09-24 this paid a second damage event at POST through reliable_topup.gd; see
# native_reliable.gd's header for why that changed and how the shared export is kept safe.
#
# The size filter lives on the .tres: MAIN, HEAVY, SUPERHEAVY ("non-Auxiliary"), and allow_basic
# stays false, so a basic attack (size NONE) gets nothing.
extends BuffWeaponTypeTag

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const NativeReliable := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/native_reliable.gd')

## Half the Grit of the Hazard whose aura put this buff here; 0 if that Hazard is gone.
static func bonus_for(core:BuffCore, map:MapState) -> int:
	return Util.half(Overshield.grit(core.get_owner_unit(map)))

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	return bonus_for(core, context.map) > 0

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({
		category = added_tag,
		number = bonus_for(core, context.map),
	})

# ---------------------------------------------------------------- the raise (ATTACK_DECLARED PRE)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.action, Context.PROP.resource]

## The holder's own weapon attack that this buff actually raises. PURE: the bus may poll it more
## than once, and native_reliable.gd ignores a second raise from us on the same attack.
func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	return check_if_passive_applies(core, context)

func activate(core:BuffCore, activation:EventCore) -> void:
	var declared:EventCore = activation.context.event
	NativeReliable.raise(declared, bonus_for(core, declared.context.map), &'weight_of_fire')
