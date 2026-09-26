## SOULBIND (a Mask of Many Faces mode, design 2.4, rulings 18-19): "Choose a character within Sensors.
## Whenever you gain heat from any other source, they immediately gain the same amount of heat. Whenever
## they gain heat from any other source, you immediately gain the same amount of heat."
##
## Vanilla Symbiosis' heat mirror (action_symbiosis_heat.gd) with the partner read from this core gear's
## state (short_wave_disruptors.gd; the menu writes it) instead of the fusion. ONE reaction mirrors both
## ways, as Symbiosis' does - design 2.4 named two, and one is the vanilla shape; nothing differs between
## the directions but which unit is the other one.
##
## "FROM ANY OTHER SOURCE" IS VANILLA'S GUARD (ruling 19): should_not_trigger_due_to_recursion_damage
## refuses this action's own heat, an activation of it already above in the event tree, and anything
## flagged MIRRORED - so heat Symbiosis or Metahook reflected onto either unit is not mirrored again.
## When one block carries several heat events only the first is mirrored (is_first_mirror_in_block):
## multi-target attack heat and each Overkill tick. Recorded, not fought - vanilla's own behaviour.
##
## THE SAME AMOUNT: the mirrored heat is flagged SELF_INFLICTED as Symbiosis' is, which is what keeps a
## resistance buff from shrinking it (buff_resist_damage.gd:44), and MIRRORED, which stops the echo.
##
## HELD WHILE THE SOULBIND CHIP IS (until the Rakshasa's next turn start, ruling 15) and the partner
## lives. Sensors is checked only at the choice: the bond holds wherever the partner goes (ruling 18).
##
## NOT A REACTION POINT and not limited. HIDDEN by localization_key_override.
extends ActionReactionMirror

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
	return not should_not_trigger_due_to_recursion_damage(unit, gear, triggering_event)

func activate(context:Context, activation:EventCore) -> void:
	if activation.abort_when(not is_first_mirror_in_block(activation)): return
	var unit:Unit = context.unit
	var partner:Unit = Core.partner(unit, context.gear)
	if activation.abort_without_units([unit, partner]): return
	var damage:Context = context.event.context
	var other:Unit = partner if damage.unit == unit else unit
	spend_actions(activation)
	CommonActionUtil.queue_damage_events(
		activation, SpecificAction.from_context(context), [other],
		damage.number, Lancer.DAMAGE_TYPE.HEAT,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED, EventService.DAMAGE_FLAG.MIRRORED]
	)
