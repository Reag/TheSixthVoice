## DREAD HARBINGER's mark, the payoff (Black Mountain SP1, design ruling 9; VISIBLE by the author's call):
##
##   "Additionally, when this Lock On is consumed, the Black Mountain gains 1d6 Overshield."
##
## PING'S SHAPE (buff_ping.gd): a chip on the LOCKED TARGET with a statuses_changed POST trigger, gated
## on the holder and on the LOCKON category through the shared hook's is_lost - the same virtual event
## carries the APPLY at PRE (unit_condition.gd:165-167) and the CLEAR at POST (:216-218), so POST is
## what makes "true" mean "lost".
##
## THE CONSUMED TEST LIVES IN activate, NOT THE GATE, AND THE ORDER IS MEASURED (probe P1, 2026-09-27,
## spec/test_spike_black_mountain_sp1_probes.gd). action_consume_lock_on.gd:42-43 clears the status
## FIRST - which queues this trigger's POST virtual event - and applies buff_lock_consumed SECOND; the
## trigger gate is evaluated at QUEUE time (reaction_bus.gd:61), when the chip is not on the target yet,
## but by the time the queued block runs it is, and it is stripped only at event_unit_attack.gd:114,
## after the roll. So: gate on the loss, and read the chip in activate. If the holder carries
## buff_lock_consumed the lock was CONSUMED and the Black Mountain gains 1d6 Overshield through
## Overshield.grant (engine max semantics: a low roll on a Black Mountain already shielded may change
## nothing - Astral Guardian's reading). A lock lost any other way - Stabilize, the talents mod's Black
## Thumb, an NPC cleanse - pays nothing. Either way the mark then clears itself: the lock it was about
## is gone.
##
## THE NAGA'S STASH-THE-SOURCE-AT-PRE WORKAROUND IS NOT NEEDED, and Lockon.source_of is never read:
## the mark itself is the memory of whose lock this was (from_gear = the Harbinger trait's gear, so
## get_owner_unit() is the Black Mountain the shield goes to). The mark also ends with the holder's
## death and, by the engine default (is_cleared_on_owner_death), with the Black Mountain's.
##
## THE 1d6 IS ROLLED THROUGH Dice, so a spec pins it with CHEAT_ROLL_QUEUE; the reaction that applies
## this mark rolls nothing. The grant runs INSIDE this activation (a live block), so it is ordered
## inside the consume, before the attack roll that consumed the lock.
extends Buff

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if triggering_event.context.unit != unit: return false
	return Lockon.is_lost(triggering_event)

func activate(core:BuffCore, activation:EventCore) -> void:
	var holder:Unit = activation.context.unit
	if not Unit.is_valid(holder): return
	if UnitCondition.has_buff(holder, Lockon.CONSUMED_BUFF):
		var black_mountain:Unit = core.get_owner_unit(holder.map)
		if Unit.is_valid(black_mountain):
			await Overshield.grant(activation, black_mountain, Dice.roll_d6())
	# Whatever happened, the lock this mark was about is gone.
	if Unit.is_valid(holder): UnitCondition.clear_buff(activation, holder, core)
