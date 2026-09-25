# ZWARTE HOOP's "Gain +1 range on the attack", once or twice (design ruling 10, the author's hybrid).
#
# THE ONE OPTION PICKED BEFORE TARGETING. Range is decided at targeting (action_attack.gd:134-144,
# :235), before ATTACK_DECLARED (:268), so no later point can widen a pick; the variant menu is the only
# pre-targeting choice (event_gear_activate.gd:72-94) and stays on screen through targeting. The other
# five options are the ATTACK_DECLARED PRE loop (action_zwarte_hoop_spend).
#
# OFFERED on a ranged ActionAttackWeapon only, while the round's first attack roll is still to come
# (the spend's round stamp) and there is a charge to pay: never on a melee weapon (threat, not range),
# never on a BURST (no range, action_attack_weapon.gd:183-184), never on a tech attack. One blankable
# group, +1 and +2; +2 is disabled below 2 charges.
#
# WHAT IT CHANGES, BY SHAPE. LINE and CONE targeting reads the pattern's value, not aim_range
# (action_attack_weapon.gd:202-203), and a variant duplicate is SHALLOW (action.gd:94-98) - the
# pattern sub-resource is the Kit's own, shared by every copy of the weapon - so those get a NEW
# RangePattern. Everything else (plain, BLAST) gets aim_range.
#
# THE CHARGES ARE PAID IN variant_spend, chained after whatever was there (Walking Armory,
# buff_armament.gd:143-167). spend_actions calls it AFTER targeting (unit_action.gd:222,
# action_attack.gd:262): a cancelled targeting spends nothing.
extends Buff

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

const GROUP_KEY := &'zwarte_hoop_range'
## Variant keys by the range they add.
const VARIANTS:Dictionary[int, StringName] = {1: &'zwarte_hoop_range_1', 2: &'zwarte_hoop_range_2'}
const KEY := 'gear.cp_inevitability_core.zwarte_hoop.range'

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) and Action.is_valid(context.action)

func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
	return offered(context.unit, context.action, context.gear)

static func offered(unit:Unit, action:Action, gear:GearCore) -> bool:
	if not action is ActionAttackWeapon: return false
	if UnitAction.is_melee_weapon(action, gear): return false
	if action.range_pattern and action.range_pattern.pattern == Lancer.AOE_TYPE.BURST: return false
	var core_gear := Core.core_gear(unit)
	if not GearCore.is_valid(core_gear): return false
	if core_gear.get_state(Core.SPENT_ROUND, -1) == Core.current_round(unit): return false
	return Core.charges(core_gear) >= 1

func get_values(core:BuffCore, context:Context) -> Context:
	var icon:Texture2D = core.base.icon if core.base.icon != null else Action.DEFAULT_ICON
	var group := VariantActionGroup.create(GROUP_KEY, tr('%s.name' % KEY), tr('%s.effect' % KEY), icon, true)
	var charges := Core.charges(Core.core_gear(context.unit)) if Unit.is_valid(context.unit) else 0
	for n:int in VARIANTS.keys():
		var variant := VariantAction.create(
			VARIANTS[n],
			tr('%s.option_%d' % [KEY, n]),
			tr('%s.effect' % KEY),
			icon,
			func(modified:ActionAttackWeapon) -> void:
				widen(modified, n)
				modified.variant_spend = spend.bind(modified.variant_spend, n),
		)
		variant.is_disabled = charges < n
		group.append(variant)
	return Context.create({object = group})

static func widen(modified:ActionAttackWeapon, n:int) -> void:
	var pattern := modified.range_pattern
	if pattern and [Lancer.AOE_TYPE.LINE, Lancer.AOE_TYPE.CONE].has(pattern.pattern):
		modified.range_pattern = RangePattern.create(pattern.pattern, pattern.value + n)
	else:
		modified.aim_range += n

static func spend(specific:SpecificAction, activation:EventCore, additional_spends:Callable, n:int) -> void:
	var core_gear := Core.core_gear(specific.unit)
	if GearCore.is_valid(core_gear):
		Core.set_charges(specific.unit, core_gear, Core.charges(core_gear) - n)
	additional_spends.call(specific, activation)
