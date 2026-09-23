## PING'S WINDOW (Naga SP2 Task 2, ruling 11; REBUILT at the frame close, author decision 1,
## 2026-09-23): "Until the end of your next turn, if the target has Lock On, they are also Impaired."
##
## READ LITERALLY: A WINDOW, AND A TEST MADE THROUGHOUT IT. This chip is the window - visible, and
## carrying no status of its own. The Impaired rides a second, hidden buff (buff_ping_impaired) that
## this chip hangs whenever the holder is Locked On inside the window, and that drops itself when the
## holder stops being Locked On. So a lock lost and regained inside the window - SALVATION's relock
## through the shared Lockon hook, Binding Fangs, a vanilla Lock On - brings the Impaired back; a lost
## lock drops it; and once the window is over a relock does nothing. (The first build ended the chip
## on the first lock loss, which gave "no way back in" - against the card, close review slice 3 #2.)
##
## TWO WAYS IN, ONE HELPER. on_application covers the Ping's own lock (onhit_ping locks FIRST, so its
## statuses_changed PRE was queued before this chip existed - reaction_bus.gd:61 evaluates triggers at
## QUEUE time, event_core.gd:59-61). The trigger covers every later lock: statuses_changed at PRE is
## an APPLY (unit_condition.gd:165-167; the clear is POST, :216-218), about the holder, category
## LOCKON. activate is overridden so the window does NOT consume itself on a trigger (buff.gd:254-255).
##
## THE CLOCK IS THE NAGA'S, NOT THIS CHIP'S (the Sluagh's shape, rulings row 285). until = 7
## (END_OF_OWNERS_NEXT_TURN) clears only once the HOLDER's turn_count has ticked (unit_condition.gd:62,
## ticked at the holder's own turn start, :24) - so a target that never starts a turn between the Ping
## and the Naga's next turn would stay Impaired a whole Naga turn too long. buff_ping_clock, hung on
## the NAGA by onhit_ping, ticks on the Naga's own turn and clears this chip, by its persistent id, at
## the end of the Naga's next turn whatever the turn order. The chip keeps until = 7 as well: it names
## the lifetime in the tooltip's glossary (buff.gd:206-210), and whenever it fires it fires at that
## same Naga turn end, never earlier.
##
## on_clear TAKES THE IMPAIRED WITH IT, so every way the window ends - the clock, a second Ping
## replacing it (apply_buff_alt's same-source clear, unit_condition.gd:741-747), the Naga's death
## (clear_outgoing_buffs_from_unit, event_service.gd:71) - ends the Impaired too.
##
## STABILIZE AIMED AT THE IMPAIRED DOES NOTHING, recorded: a buff-carried status is out of
## clear_status_via_ability's reach (it walks unit.state.statuses only, unit_condition.gd:479-483;
## Myconid ruling 124). Clearing the Lock On is the way out, which is the card.
extends Buff

const IMPAIRED := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping_impaired.tres')
const IMPAIRED_ID := &'buff_ping_impaired'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context
	if triggering_context.unit != unit: return false
	return triggering_context.category_str == Lancer.STATUS.LOCKON

## The window stays; a (re)lock inside it hangs the Impaired.
func activate(core:BuffCore, activation:EventCore) -> void:
	hang_impaired_if_locked(activation, core, activation.context.unit)

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	hang_impaired_if_locked(event, core, unit)

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if not Unit.is_valid(unit): return
	UnitCondition.clear_buff_id(event, unit, IMPAIRED_ID, core.from_gear)

## Idempotent: one Impaired per window, however many locks land.
static func hang_impaired_if_locked(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if not Unit.is_valid(unit) or unit.map == null: return
	if not unit.has_status(Lancer.STATUS.LOCKON): return
	if UnitCondition.has_buff(unit, IMPAIRED_ID, core.from_gear): return
	UnitCondition.apply_buff(event, unit, IMPAIRED, core.get_owner_gear(unit.map))
