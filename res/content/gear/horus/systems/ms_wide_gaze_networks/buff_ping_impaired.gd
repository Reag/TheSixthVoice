## PING'S IMPAIRED (frame close, author decision 1, 2026-09-23): the half of "if the target has Lock
## On, they are also Impaired" that is the Impaired. Hidden plumbing - buff_ping, the window, is the
## chip the player reads; this carries the status through applies_statuses, so Stabilize cannot clear
## it directly (buff_ping's header).
##
## IT DROPS ITSELF WHEN THE HOLDER STOPS BEING LOCKED ON. statuses_changed at POST is a CLEAR
## (unit_condition.gd:216-218), about the holder, category LOCKON - the trigger buff_markerlight_no_cover
## uses. But a POST fires for EVERY condition cleared (clear_specific_status, :326-329, once per copy)
## and apply_status appends a second LOCKON unconditionally (:104-105), so the gate is whether the
## holder STILL has Lock On: a stacked lock losing one copy stays Impaired. The gate is asked in
## activate, when the reaction RUNS, not when it is queued: a relock can land in between - a relock
## reaction on the same POST (SALVATION's) that runs first re-locks the holder, its PRE finds this
## buff still hung and adds nothing, and an Impaired cleared after that would be gone while Locked On.
##
## Every loss counts: a consume (source empty), Stabilize (each copy, with its source), a cleanse.
## buff_ping re-hangs this on a relock inside the window.
extends Buff

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context
	if triggering_context.unit != unit: return false
	return triggering_context.category_str == Lancer.STATUS.LOCKON

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if Unit.is_valid(unit) and unit.has_status(Lancer.STATUS.LOCKON): return
	UnitCondition.clear_buff(activation, unit, core)
