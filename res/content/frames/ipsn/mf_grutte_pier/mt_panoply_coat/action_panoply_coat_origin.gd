## PANOPLY COAT's "attacks that originate from beyond Range 10": WHERE THE ATTACK WAS MADE FROM
## (close review, 2026-09-25).
##
## The damage lands AFTER the attack's own on-hit effects have moved the Pier: a weapon's Knockback is
## queued on the per-target attack (action_attack_weapon.gd:337) and every damage event is built only
## after every roll (event_unit_attack_declared.gd:147-200). Measured at the damage, a hit from 10 that
## pushed the Pier to 11 was halved, and a pull from 11 to 10 was not. So this hidden reaction
## measures at ATTACK PRE - the moment the attack roll against the Pier is made - and records it on the
## trait's gear, keyed by the unit the damage context will name as its source: context.unit HERE (the
## relay, if any) is target_unit THERE (event_unit_attack_declared.gd:167), and ruling 3 measures from
## that same unit. buff_panoply_coat.gd reads the record, and measures live when there is none.
##
## Overwritten by every attack roll made at the Pier, so the record is always that attack's own; not
## a reaction point, and it fires through Stunned/Shut Down like any consumes_rxn = false reaction.
extends ActionReaction

const STATE_KEY := 'panoply_attack_from'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	var context := triggering_event.context
	return context.target_unit == unit and Unit.is_valid(context.unit) and context.unit != unit

func activate(context:Context, _activation:EventCore) -> void:
	var pier:Unit = context.unit
	var gear:GearCore = context.gear
	var source:Unit = context.event.context.unit
	if not Unit.is_valid(pier) or not GearCore.is_valid(gear) or not Unit.is_valid(source): return
	var record:Dictionary = gear.get_state(STATE_KEY, {})
	record[str(source.core.persistent_id)] = UnitRelation.distance_between(pier, source)
	gear.set_state(STATE_KEY, record)

## The distance recorded when `source` last made an attack roll at the Pier, or -1.
static func recorded_distance(gear:GearCore, source:Unit) -> int:
	if not GearCore.is_valid(gear) or not Unit.is_valid(source): return -1
	return gear.get_state(STATE_KEY, {}).get(str(source.core.persistent_id), -1)
