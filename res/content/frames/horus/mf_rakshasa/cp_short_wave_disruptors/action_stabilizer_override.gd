## STABILIZER OVERRIDE (a Mask of Many Faces mode, design 2.3, ruling 17): "1/round, when you hit a
## character with a tech attack, they must make a Systems save or be knocked Prone."
##
## Drain's watcher shape (action_drain.gd) - ATTACKER, ENEMIES, require_hit, tech and basic only - with
## a 1/round hard limit on its own usage group. ANY tech attack, invade or not. A HOSTILE CHARACTER:
## hostile for Drain's reason (every tech hit on an ally is an auto-hit), and "character" is is_actor()
## (rulings row 301), tested here because the archetype's is_character() admits drones.
##
## A TARGET IT CANNOT KNOCK PRONE IS EXCLUDED - already Prone, or immune (close review): a STATUS_IMMUNITY
## buff (Armor-Lock Plating, Flash Anchor, a Heavy Frame against a smaller knocker), Invulnerable, or
## Flying. UnitCondition.is_immune_to_status is the predicate apply_status itself refuses on
## (unit_condition.gd:93), asked with the same source - the core gear's id - so the answer is the one the
## save's failure would get. The 1/round is kept for a target it can matter to.
##
## The round is spent on the HIT, before the save: a passed save has still used it. The save is a
## Systems save against [PRONE] forced with the full trifecta (this unit, the core gear, this action),
## so Worm Code sees the failure (ruling 6). Prone at its standard until, MANUAL - Action.apply_status
## would default to END_OF_NEXT_TURN (action.gd:378-379). The Gut Reactor is the same four lines.
##
## NOT A REACTION POINT ("1/round", not "Reaction"). HIDDEN by localization_key_override; the save
## prompt and the log read "Stabilizer Override" off the chip's name row.
extends ActionReactionAttacked

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not Core.holds(unit, Core.MODE.STABILIZER_OVERRIDE): return false
	var defender:Unit = triggering_event.context.target_unit
	if not Unit.is_valid(defender) or not defender.is_character(): return false
	if defender.has_status(Lancer.STATUS.PRONE): return false
	return not UnitCondition.is_immune_to_status(defender, Lancer.STATUS.PRONE, gear.persistent_id)

func activate(context:Context, activation:EventCore) -> void:
	var defender:Unit = context.event.context.target_unit
	if activation.abort_without_unit(defender): return
	spend_actions(activation)

	var saved:bool = await UnitHasecheck.make_systems_save(
		activation, defender, SpecificAction.from_context(context), [Lancer.STATUS.PRONE])
	if saved or not Unit.is_valid(defender): return
	UnitCondition.apply_status(activation, defender, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, context.gear.persistent_id)
