## PING'S CHIP (Naga SP2 Task 2, ruling 11): "Until the end of your next turn, if the target has Lock
## On, they are also Impaired."
##
## ONE SELF-CLEARING BUFF, not the Vlad's two reactions. The Impaired is applies_statuses, so it lives
## exactly as long as the chip; the chip dies on the first of two exits - its own clock
## (END_OF_OWNERS_NEXT_TURN, the Naga's next turn end) or the holder losing Lock On. There is no third
## exit and no way back in: Lock On can only be lost after the chip is hung, so "if the target has
## Lock On" is the same as "until it stops having it".
##
## THE TRIGGER is buff_markerlight_no_cover.gd's, verbatim in effect: statuses_changed at POST - which
## is a CLEAR (unit_condition.gd:216-218; the apply fires at PRE) - about the holder, category LOCKON.
## Every loss counts: a consume (source empty), Stabilize (the lock's own source), a cleanse. The
## default Buff.activate then clears this buff, and its Impaired with it.
##
## STABILIZE AIMED AT THE IMPAIRED DOES NOTHING, recorded: a buff-carried status is out of
## clear_status' reach (Myconid ruling 124). Clearing the Lock On is the way out, which is the card.
extends Buff

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context
	if triggering_context.unit != unit: return false
	return triggering_context.category_str == Lancer.STATUS.LOCKON
