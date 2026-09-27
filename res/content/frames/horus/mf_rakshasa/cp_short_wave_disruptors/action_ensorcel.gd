## ENSORCEL, the replacement action (a Mask of Many Faces mode, design 3.2, rulings 20-22): "When you
## scan, you may take 2 heat to choose one of your Invade options and apply the effects instead of
## learning any information. This does not count as an attack and cannot apply any heat."
##
## NOT IN THE KIT. The Ensorcel chip (buff_mask_ensorcel.gd) offers this as a blankable VARIANT of
## vanilla Scan and swaps it in, so it activates on the Rakshasa's ms_scan gear and spends Scan's Quick
## action. The .tres carries Scan's own shape - Quick, tech, one target within Sensors and line of sight
## - plus self_heat_dice "2", which UnitAction.spend deals (unit_action.gd:292-296).
##
## THE TARGET: a hostile character (is_actor(), rulings row 301), as Scan targets enemies - but without
## Scan's "something unscanned" filter, because nothing is learned here.
##
## THE INVADE: every is_invade ActionAttackTech on the Rakshasa's equipped, undestroyed gear, systems,
## talents, traits and the core Kit included (loadout.get_all_gear(true); NOT get_all_tech_attacks,
## which is equipped attacks plus basics and misses the rest, loadout_core.gd:439-440, :527-531), each
## action once, and only those whose own can_target_unit accepts the chosen target (invade_options).
## Auto-picked when there is one (Fragment Signal alone); a mandatory menu for a player otherwise. Its
## on_hit and on-hit effects then run on the target, and nothing else of the attack flow does: no
## event_unit_attack, so no ATTACK reaction (Drain, Stabilizer Override, the Koremasa's mark), no
## apply_on_attacks, no summary-keyed effect, and no invade heat, which only the attack flow deals
## (event_unit_attack_declared.gd:148-199). The invade's own uses and charges are not spent.
##
## HEAT INSIDE THE EFFECT (vanilla Sear) is cancelled by buff_ensorcel_suppressor on the target, and the
## invade runs INSIDE that buff's own activation (event_buff_activate): an immediate block resolves its
## queued children before it returns (event_block.gd:175-183), so everything the invade queues lands
## while the suppressor holds. It is cleared the moment that block is done.
extends ActionSystem

const SUPPRESSOR := &'buff_ensorcel_suppressor'
## The menu reads the chip's own rows: the mode's name and its LCP text.
const CHIP_KEY := 'gear.buff_mask_ensorcel'

func get_target_range(specific:SpecificAction) -> int: return specific.unit.get_sensor_range()

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	if not potential_target.is_character(): return false
	return UnitRelation.are_enemies(specific.unit, potential_target)

## Every invade the unit can choose, in loadout order, each action once: [{gear, action}].
##
## UNDESTROYED: get_all_gear does no filtering of its own, so a destroyed system's invades are dropped
## here. AGAINST `target`, when there is one: an invade whose own can_target_unit refuses that target is
## not one of the options against them - the per-target limits (Smite's once-per-scene Stun list,
## action_smite.gd:4-10; Eject Power Cores; the Sowche's USED_ON_KEY) and eligibility gates (Beckon,
## action_beckon.gd:5-11) live there. The target is already chosen when the menu is built.
##
## NOT filtered: ACTION_FORBIDDEN (unit_action.gd:157). Vanilla's forbids name kinds of action (Siege
## Stabilizers' melee attacks, the Sekhmet's ranged ones), and Ensorcel "does not count as an attack" -
## an open question for the author, not a gate to guess at. Nor uses or charges, which Ensorcel does
## not spend (ruling 21).
static func invade_options(unit:Unit, target:Unit = null) -> Array:
	var options:Array = []
	if not Unit.is_valid(unit): return options
	var seen:Array[Action] = []
	for gear:GearCore in unit.core.loadout.get_all_gear(true):
		if not gear.is_intact(): continue
		for action:ActionAttackTech in gear.kit.get_tech_attack_actions():
			if not action.is_invade or seen.has(action): continue
			if Unit.is_valid(target) and not action.can_target_unit(target, SpecificAction.create(unit, gear, action)): continue
			seen.append(action)
			options.append({gear = gear, action = action})
	return options

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var plan := await TargetActionUtil.ask_for_targets(activation)
	if activation.abort_without_target_unit_plan(plan): return
	var target:Unit = plan.target_units.front()

	var chosen:Dictionary = await choose_invade(context, unit, target)
	if activation.abort_when(chosen.is_empty()): return
	if activation.abort_without_units([unit, target]): return

	spend_actions(activation)
	await run_system_fxgs(unit, [target])
	if activation.abort_without_units([unit, target]): return

	var suppressor:BuffCore = apply_buff_id(activation, target, SUPPRESSOR)
	if suppressor == null: return
	await activation.execute_event(&'event_buff_activate', {
		buff = suppressor,
		unit = target,
		event = activation,
		gear = chosen.gear,
		action = chosen.action,
	})
	if Unit.is_valid(target): UnitCondition.clear_buff(activation, target, suppressor)

func choose_invade(context:Context, unit:Unit, target:Unit) -> Dictionary:
	var options := invade_options(unit, target)
	if options.is_empty(): return {}
	if options.size() == 1 or not unit.is_player_controlled(): return options.front()
	var choices:Array = []
	for option:Dictionary in options:
		choices.append({text = option.action.name(SpecificAction.create(unit, option.gear, option.action))})
	var picked:int = await choice_bus.choose_from_multiple_choice_for({
		brochure = BrochureCore.create({
			title = X.tr('%s.name' % CHIP_KEY),
			description = X.tr('%s.effect' % CHIP_KEY),
			choices = choices,
		}),
		can_voluntarily_cancel = false,
	})
	if picked < 0 or picked >= options.size(): return options.front()
	return options[picked]
