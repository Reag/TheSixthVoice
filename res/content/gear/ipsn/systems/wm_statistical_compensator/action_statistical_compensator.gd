# STATISTICAL COMPENSATOR's prompt (Hazard rank II weapon mod, SP3 Task 2, design ruling 11 as
# amended by the SP3 probe):
#
#   "When you make an attack roll with the weapon this mod is applied to, you may expend a charge to
#    gain +2 Reliable for that attack."
#
# ATTACK_DECLARED PRE: once per declared attack (a Blast asks once), before any roll. Point-free
# (consumes_rxn false) and unlimited per round - the charges are the only limit, and spend_actions
# spends one through the default consumes_charges (unit_action.gd:274), which also gates the offer
# when none are left (:153).
#
# THE MOD KIT'S REACTIONS FIRE WHETHER OR NOT IT IS FITTED - it sits in loadout.systems like any
# system (measured by spec/test_spike_hazard_sp3_seams.gd) - so the gate asks the FIRING weapon for
# its mod and compares it with our own gear.
#
# WHAT A YES DOES. The ruled carrier - a FINISH_DAMAGE tag buff hung here - is cleared at the end of
# the attack's execute(), BEFORE the ATTACK_DECLARED POST where reliable_topup.gd pays (measured by
# the probe). So a yes STAMPS this attack's DeclaredAttackSummary instead; the mod's permanent buff
# (buff_statistical_compensator.gd) reads +2 only on a stamped attack. The stamp dies with the
# summary, so nothing can leak to the next attack, even one that aborts before POST.
#
# "YOU MAY": CommonActionUtil.confirm_use - the player's yes/no; the AI declines (charges are a
# scene resource the AI does not weigh).
extends ActionReaction

const BuffCompensator := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ipsn/systems/wm_statistical_compensator/buff_statistical_compensator.gd')

func show_in_tooltip(_kit:Kit) -> bool: return false
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

## Our own attack, with the weapon this mod is fitted to, not already stamped. PURE.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	if BuffCompensator.is_armed(context): return false
	if not (context.action is ActionAttackWeapon): return false
	return context.gear.get_weapon_mod(unit.core.loadout) == gear

func ai_confirms_use(_context:Context, _target_units:Array[Unit] = []) -> bool:
	return false

func activate(context:Context, activation:EventCore) -> void:
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	spend_actions(activation) # a charge
	BuffCompensator.arm(context.event.context)
