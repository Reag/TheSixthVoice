## UNCERTAINTY FIELD, the damage break.
##
##   "It immediately loses Invisible if it takes damage."
##
## A HIDDEN TRIGGERED BUFF, not a second reaction (design §0.2). Action.show_in_tooltip returns true
## for any trait reaction whose KIT carries a trigger row (action.gd:343-344), and a bookkeeping
## reaction on this Kit would also have to be given a usage group of its own to keep out of the
## field's 1/round. A buff subscribes to the same bus on the same terms (reaction_bus.gd:61-67) and
## advertises nothing.
##
## WHAT "TAKES DAMAGE" MEANS (ruling 6): the Halo definition, verbatim - any event_unit_damage of a
## type other than HEAT that reaches DAMAGE POST carrying a positive context.number.
##   - ARMOR. context.number is the POST-armor amount, and the engine does NOT abort a hit that armor
##     reduced to nothing: capped_damage is a BuffResistDamage cap defaulting to 9999
##     (damage_modifications.gd:11, :69), never the armor-reduced amount. Measured on the Myconid,
##     2026-09-16. So the `<= 0` clause below is a REAL gate.
##   - OVERSHIELD. The soak happens inside damage() against a local and never writes back to
##     context.number, so a hit absorbed entirely by Overshield still reads positive and still breaks
##     the fade. That is the ruling.
##   - BURN counts; a burn tick is an event_unit_damage of that category. HEAT does not: heat is not
##     damage in Lancer, and buff_suppress.gd:28 is vanilla's own exclusion of it.
##
## THE SOURCE QUALIFIER IS RULING 6'S REFINEMENT. It clears only the Invisible this trait's own gear
## applied; a Cloaking Field's or a Mirage's survives the hit. UnitCondition.has_status and
## clear_status both take that source (unit_condition.gd:310, :386-393), and the field's own
## activate() applies the status with the same gear.persistent_id - the reaction and this buff live on
## one Kit, so they resolve to one GearCore.
##
## get_required_triggering_context IS DELIBERATELY EMPTY - the HEAER's reasoning: a required prop is
## re-checked at execution time, not only at collection time, and everything read below is read
## defensively. Requiring one would abort in exactly the cases the trait exists for.
##
## activate() DOES NOT CALL super(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive the whole scene.
extends Buff

## The battle-log row, as a LITERAL KEY: battle_log.log_unit takes a translation key and calls tr()
## on it itself (battle_log_bus.gd:24-33), the way buff_symbiosis_exclusion.gd:118 passes one. A
## const rather than a lookup off the owner gear, so the row key stays stable even when the gear
## lookup fails.
const BROKEN_LOG := &'gear.mt_uncertainty_field.broken.log'

func get_required_triggering_context() -> Array[Context.PROP]:
	return []

## The persistent id of the gear that owns this buff - the same GearCore the field's own reaction
## passes as its status source, because both live on mt_uncertainty_field.
static func source_id(core:BuffCore, map:MapState) -> StringName:
	var gear:GearCore = core.get_owner_gear(map)
	if not GearCore.is_valid(gear): return &''
	return gear.persistent_id

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	# THE HOLDER took the damage. context.unit on a damage event is the victim, and the bus polls
	# every unit's buffs on every trigger with the SAME event - without this line the Blush would drop
	# its fade when anybody on the map was shot.
	if context.unit != unit: return false
	# Context.PROP.category is optional on a damage event and defaults to Kinetic, so category_int is
	# always present. The cast is buff_suppress.gd:27-28's.
	var damage_type:Lancer.DAMAGE_TYPE = context.category_int as Lancer.DAMAGE_TYPE
	if damage_type == Lancer.DAMAGE_TYPE.HEAT: return false
	if context.number <= 0: return false
	var source := source_id(core, context.map)
	if source.is_empty(): return false
	# And there is something of OURS to clear. Without this the buff fires on every hit the Blush ever
	# takes, writing a battle-log line about losing something it never had.
	return UnitCondition.has_status(unit, Lancer.STATUS.INVISIBLE, source)

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	var source := source_id(core, activation.context.map)
	if source.is_empty(): return
	UnitCondition.clear_status(activation, unit, Lancer.STATUS.INVISIBLE, source)
	battle_log.log_unit(BROKEN_LOG, unit)
