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
# WHAT A YES DOES. It has the shared native_reliable.gd raise the weapon's Reliable by 2 for the
# length of this attack - we are already at ATTACK_DECLARED PRE, before the engine reads it (:82),
# so the engine floors every roll itself and Weight of Fire's raise simply adds. It also STAMPS the
# DeclaredAttackSummary, which is what stops a second offer and what lets the mod's WEAPON_TAG buff
# (buff_statistical_compensator.gd) draw the +2 during the attack. Until 2026-09-24 the +2 was paid
# as a second damage event at POST (reliable_topup.gd); the stamp dates from then, when a
# FINISH_DAMAGE buff could not carry the +2 that far.
#
# "YOU MAY": CommonActionUtil.confirm_use - the player's yes/no; the AI declines (charges are a
# scene resource the AI does not weigh).
extends ActionReaction

const BuffCompensator := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ipsn/systems/wm_statistical_compensator/buff_statistical_compensator.gd')
const NativeReliable := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/native_reliable.gd')

## The card's "+2 Reliable".
const RELIABLE_BONUS := 2

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
	NativeReliable.raise(context.event, RELIABLE_BONUS, &'statistical_compensator')
