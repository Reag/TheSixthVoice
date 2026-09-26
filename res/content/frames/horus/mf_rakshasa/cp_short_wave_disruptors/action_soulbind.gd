## SOULBIND (a Mask of Many Faces mode, design 2.4, rulings 18-19): "Choose a character within Sensors.
## Whenever you gain heat from any other source, they immediately gain the same amount of heat. Whenever
## they gain heat from any other source, you immediately gain the same amount of heat."
##
## Vanilla Symbiosis' heat mirror (action_symbiosis_heat.gd) with the partner read from this core gear's
## state (short_wave_disruptors.gd; the menu writes it) instead of the fusion. ONE reaction mirrors both
## ways, as Symbiosis' does - design 2.4 named two, and one is the vanilla shape; nothing differs between
## the directions but which unit is the other one.
##
## NOT AN ActionReactionMirror, though it is one in all but name (close review). Vanilla's
## is_first_mirror_in_block (action_reaction_mirror.gd:50-67) aborts when ANY completed sibling block
## activated ANY ActionReactionMirror, so two mirrors reacting to one heat event cancel each other: a
## Rakshasa carrying vanilla Metahook linked to an ally, bound to a hostile, would give only one of them
## the heat - and as a mirror, Soulbind running first would switch off a vanilla player's Metahook. So
## this extends the archetype's own base and carries its guards itself.
##
## "FROM ANY OTHER SOURCE" IS VANILLA'S GUARD (ruling 19), replicated in is_echo: this action's own heat,
## an activation of it already above in the event tree (the archetype's static would_be_own_ancestor),
## and anything flagged MIRRORED - so heat Symbiosis or Metahook reflected onto either unit is not
## mirrored again, and they do not reflect ours. When one block carries several heat events only the
## first is mirrored (is_first_in_block): multi-target attack heat and each Overkill tick. Recorded, not
## fought - vanilla's own behaviour. It counts only THIS gear's Soulbind, so another mirror, or another
## Rakshasa bound to the same partner, never stops this one.
##
## THE SAME AMOUNT: heat to the PARTNER is flagged NO_REDUCE, which skips resistance and reduction
## (damage_modifications.gd:59), and MIRRORED, which stops the echo. NOT SELF_INFLICTED, as Symbiosis'
## is: that flag means "from their own systems", and a hostile Grunt's Weak (action_weak_grunt.gd:19-20)
## spares exactly that heat. Heat back to the RAKSHASA is its own system's, so it is SELF_INFLICTED (which
## is what keeps a resistance buff off it, buff_resist_damage.gd:44) and MIRRORED.
##
## HELD WHILE THE SOULBIND CHIP IS (until the Rakshasa's next turn start, ruling 15) and the partner
## lives. Sensors is checked only at the choice: the bond holds wherever the partner goes (ruling 18).
##
## NOT A REACTION POINT and not limited. HIDDEN by localization_key_override.
extends ActionReaction

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

# DAMAGE, POST
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var damage:Context = triggering_event.context
	if damage.category_int != Lancer.DAMAGE_TYPE.HEAT: return false
	if damage.number <= 0: return false
	if not Core.holds(unit, Core.MODE.SOULBIND): return false
	var partner:Unit = Core.partner(unit, gear)
	if partner == null: return false
	if damage.unit != unit and damage.unit != partner: return false
	return not is_echo(unit, gear, triggering_event)

func activate(context:Context, activation:EventCore) -> void:
	if activation.abort_when(not is_first_in_block(activation, context.gear)): return
	var unit:Unit = context.unit
	var partner:Unit = Core.partner(unit, context.gear)
	if activation.abort_without_units([unit, partner]): return
	var damage:Context = context.event.context
	var other:Unit = partner if damage.unit == unit else unit
	var flags:Array = [EventService.DAMAGE_FLAG.MIRRORED]
	flags.append(EventService.DAMAGE_FLAG.SELF_INFLICTED if other == unit else EventService.DAMAGE_FLAG.NO_REDUCE)
	spend_actions(activation)
	CommonActionUtil.queue_damage_events(
		activation, SpecificAction.from_context(context), [other],
		damage.number, Lancer.DAMAGE_TYPE.HEAT, flags
	)

## ActionReactionMirror.should_not_trigger_due_to_recursion_damage's three checks (:6-17), unchanged.
func is_echo(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var damage:Context = triggering_event.context
	if Action.is_valid(damage.action) and damage.action.get_id() == get_id(): return true
	if ActionReactionMirror.would_be_own_ancestor(unit.core.persistent_id, gear.persistent_id, get_id(), triggering_event.block): return true
	return damage.flags.has(EventService.DAMAGE_FLAG.MIRRORED)

## ActionReactionMirror.is_first_mirror_in_block (:50-67) narrowed to THIS gear's own Soulbind: false
## when a completed sibling block already activated it - several heat events in one block mirror once.
func is_first_in_block(core:EventCore, gear:GearCore) -> bool:
	if not EventBlock.is_valid(core.block) or not EventBlock.is_valid(core.block.get_parent()): return true
	if not GearCore.is_valid(gear): return true
	for sibling_block:EventBlock in core.block.get_parent().get_children():
		if sibling_block == core.block or not sibling_block.is_completed: continue
		for sibling:EventCore in sibling_block.event_cores:
			if (
				sibling.base.event_type == &'event_gear_activate' and
				GearCore.is_valid(sibling.context.gear) and
				sibling.context.gear.persistent_id == gear.persistent_id and
				Action.is_valid(sibling.context.action) and
				sibling.context.action.get_id() == get_id()
			): return false
	return true
