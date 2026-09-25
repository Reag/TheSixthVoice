# The INEVITABILITY CORE's shared vocabulary (Grutte Pier SP2, design rulings 6-17).
#
# Static helpers only, no state, never instantiated: every action and buff on the Kit reads and
# writes the same few keys in the core GearCore's state dictionary, and one file naming them is what
# keeps seven scripts from each spelling them. Preloaded by path, never by class_name (the mod names
# no class_name of its own - a class_name script cannot be extended reliably, Godot #83542).
#
# THE CHARGES ARE A PassiveDieCounter (ruling 6), passives[0] of cp_inevitability_core, so the gear
# bar draws its badge (linked_gear_bar_button.gd:49-56). Everything goes through the counter's own
# update_value, which logs the change and popcorns it; nothing writes gear.state[CHARGES] by hand.
extends RefCounted

const CORE_ID := &'cp_inevitability_core'

## The PassiveDieCounter's key, and so the gear.state key the charges live under.
const CHARGES := &'charges'

## The visible chip Patience in All Things hangs on the Pier for the rest of the scene.
const PATIENCE_BUFF := &'buff_patience_in_all_things'

## The 1/round reduction's usage key (gear_core.gd:170-195): increment_action_usage and
## get_uses_this_round_alt both take a free-form StringName, reset at the owner's turn start.
const PATIENCE_REDUCE_USAGE := &'patience_reduce'

## Hostile activations seen so far this round (ruling 7), and the round they were counted in: a
## tally stamped with an older round is read as 0, which is the new_round reset without a second
## reaction.
const TALLY := &'zh_tally'
const TALLY_ROUND := &'zh_tally_round'

## The round the Pier last made an attack roll in (ruling 9). Zwarte Hoop's spend is offered only
## while this is not the current round.
const SPENT_ROUND := &'zh_round'

## "to a maximum of 5" - the cap on the charges GAINED from hostile activations only (ruling 11).
const GAIN_CAP := 5
## "Zwarte Hoop gains 3 additional charges" (ruling 15).
const PATIENCE_GAIN := 3

static func core_gear(unit:Unit) -> GearCore:
	if not Unit.is_valid(unit): return null
	return unit.get_gear(CORE_ID)

static func counter(gear:GearCore) -> PassiveDieCounter:
	if not GearCore.is_valid(gear): return null
	return gear.get_die_counter_passive()

static func charges(gear:GearCore) -> int:
	var die := counter(gear)
	return die.get_current(gear) if die != null else 0

static func set_charges(unit:Unit, gear:GearCore, value:int) -> void:
	var die := counter(gear)
	if die != null: die.update_value(unit, gear, value)

static func has_patience(unit:Unit) -> bool:
	return Unit.is_valid(unit) and UnitCondition.has_buff(unit, PATIENCE_BUFF)

## map.game_core "may or may not exist, depending on the mode" (map_state.gd:58).
static func current_round(unit:Unit) -> int:
	if unit.map == null or unit.map.game_core == null: return 0
	return unit.map.game_core.round_count

static func tally(unit:Unit, gear:GearCore) -> int:
	if gear.get_state(TALLY_ROUND, -1) != current_round(unit): return 0
	return gear.get_state(TALLY, 0)

static func add_to_tally(unit:Unit, gear:GearCore) -> void:
	var count := tally(unit, gear) + 1
	gear.set_state(TALLY_ROUND, current_round(unit))
	gear.set_state(TALLY, count)
