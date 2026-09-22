# SALVATION UPON THE WICKED, the reaction half (Naga, cp_shimmering_veil's active), ruling 8:
#
#   "For the rest of the scene, whenever a hostile character would lose Lock On within sensors. They
#    must succeed a Systems save or take 1 AP Kinetic damage and become Locked On."
#
# THE PROTOCOL (action_salvation_upon_the_wicked.tres, consumes_cp) hangs buff_salvation on the Naga
# for the rest of the scene; THIS is the hidden reaction that lives while the chip does - Draw Fire's
# pattern: is_available_to_activate requires the chip, and show_in_tooltip is false because a
# bookkeeping reaction on a Kit with a trigger row advertises itself (memory
# lancer-tactics-reactions-and-usage).
#
# "WOULD LOSE" IS BUILT AS "LOST, SAVE, RE-LOCKED". There is no PRE for a status clear -
# unit_condition.gd:216-218 fires statuses_changed POST only, with the cleared status in
# `category` and the source (EMPTY on a consume, action_consume_lock_on.gd:42) in `string` - so the
# reaction fires one event after the loss and re-applies the lock on a failed save, which is the
# same board state one event later. Inside a consume the loss happens at ATTACK_DECLARED PRE, so the
# re-lock lands BEFORE that attack rolls; the attack still has its +1 (buff_lock_consumed is
# separate) and the next attack may consume again - the card's loop, as written. EVERY LOSS COUNTS:
# a consume, Stabilize, Black Thumb, an NPC's cleanse - the card says "would lose", unqualified.
# The SP1 probe measured both the consume and the ability-clear paths.
#
# THE GATE: Lockon.is_lost (a statuses_changed event for LOCKON - the same virtual event carries the
# APPLY at PRE, which is why the .tres says POST); the loser is a live hostile CHARACTER of the Naga
# (is_actor, ruling 21) within the Naga's Sensors (no line of sight). Unlimited per round:
# consumes_rxn false, no hard limit, its own usage group.
#
# THE SAVE: UnitHasecheck.make_save with THIS SpecificAction as the forcer (the Vauban's rulings
# 196-197: the forcer is the Naga, and a full unit/gear/action trifecta is what lets the saver's
# buffs see it). On a fail: 1 KINETIC with the AP flag through CommonActionUtil.queue_damage_events,
# then Lockon.apply (MANUAL, source = this core Kit's gear id) - which refuses a target somehow
# already re-locked, and which fires statuses_changed at PRE, not POST, so it cannot re-trigger
# this reaction.
extends ActionReaction

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const SALVATION_CHIP := &'buff_salvation'
const DAMAGE := 1

func show_in_tooltip(_kit:Kit) -> bool: return false
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return UnitCondition.has_buff(unit, SALVATION_CHIP)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	if not Lockon.is_lost(triggering_event): return false
	return is_a_hostile_character_within_sensors(unit, triggering_event.context.unit)

## "A hostile character ... within sensors", read from the Naga's side.
static func is_a_hostile_character_within_sensors(naga:Unit, loser:Unit) -> bool:
	if not Unit.is_valid(loser) or loser == naga: return false
	if not UnitRelation.are_enemies(naga, loser): return false
	if not loser.is_actor(): return false
	return UnitRelation.distance_between(naga, loser) <= naga.get_sensor_range()

func activate(context:Context, activation:EventCore) -> void:
	var naga:Unit = context.unit
	var loser:Unit = context.event.context.unit
	if activation.abort_without_units([naga, loser]): return
	var forcer := SpecificAction.from_context(context)

	var passed:bool = await UnitHasecheck.make_save(activation, loser, forcer, Lancer.HASE.SYS)
	if activation.abort_without_units([naga, loser]): return
	if passed: return

	CommonActionUtil.queue_damage_events(
		activation, forcer, [loser], DAMAGE, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP])
	Lockon.apply(activation, loser, context.gear)
