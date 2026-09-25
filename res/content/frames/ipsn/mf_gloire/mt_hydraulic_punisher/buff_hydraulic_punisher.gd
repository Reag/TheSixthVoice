## HYDRAULIC PUNISHER'S IMPAIRED: "they become Impaired until they clear Prone." Design ruling 4.
##
## A buff with applies_statuses IS the status for as long as it lives: unit_condition.gd:380 counts
## it among the unit's statuses, :760 acts as applied when the buff lands and :981 acts as cleared
## when the buff goes. So this one resource is both the Impaired and the listener for "until they
## clear Prone" - the Ping's Impaired shape (buff_ping_impaired.gd), with Prone for Lock On.
##
## IT DROPS ITSELF WHEN THE HOLDER CLEARS PRONE. statuses_changed at POST is a CLEAR
## (unit_condition.gd:217-219), about the holder, category PRONE: Stand Up (action_stand_up.gd:25)
## and every other Prone clear go through on_status_clear. A POST fires for every copy cleared and a
## unit can hold Prone from two sources, so the gate is whether the holder STILL has Prone - asked in
## activate, when this runs, not when it is queued (buff_ping_impaired's reasoning: something queued
## on the same POST may put it back first).
##
## VISIBLE (the trait's glyph at SP3): the chip on the target is how a player reads "Impaired because
## the Gloire floored me", and it names itself off the Kit's own rows (BUFFS_THAT_BORROW_A_CARD).
## Lifts if the Gloire is destroyed (the default is_cleared_on_owner_death) - recorded, not fought.
extends Buff

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.category]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context
	if triggering_context.unit != unit: return false
	return triggering_context.category_str == Lancer.STATUS.PRONE

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	if unit.has_status(Lancer.STATUS.PRONE): return # still down from another source
	UnitCondition.clear_buff(activation, unit, core)
