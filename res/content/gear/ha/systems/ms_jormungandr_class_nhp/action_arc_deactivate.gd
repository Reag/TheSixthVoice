# BEGIN DEACTIVATING THE A.R.C. (Leoleth rank III, design ruling 17):
#
#   "You can begin to deactivate this system as a protocol. At the start of your next turn it
#    deactivates."
#
# TWO SENTENCES, TWO MECHANISMS, AND THIS IS THE FIRST ONE. All this protocol does is STAMP the
# chip; buff_arc's own new_turn POST trigger reads the stamp and switches the system off at the
# holder's next turn start. A protocol that cleared the chip outright would read the card's first
# sentence and lose its second - the A.R.C. is still live for the rest of the turn you begin on,
# which is the whole cost of switching it off.
#
# NOT ActionSystemClearBuff, WHICH IS WHAT THE ZIP'S OFF SWITCH USES. That archetype clears
# immediately and has no way to defer; this one is a plain ActionSystem whose activate writes one
# key, the Goblin's action_symbiosis_end.gd shape (a self-targeted ActionSystem overriding
# is_available_to_activate and activate, and nothing else).
#
# AVAILABLE WHILE THE CHIP IS HELD, FULL STOP. Pressing it a second time re-stamps the same value
# and changes nothing, which is preferable to a second availability rule the card does not have.
# ActionSystem's default get_target_requirements is already count = 0, self-targeting
# (action_system.gd:55-60), so no targeting override is needed.
extends ActionSystem

## The stamp's key is buff_arc.gd's own constant, preloaded rather than retyped so the two cannot
## drift apart silently. Preloading a sibling mod script is this mod's established shape (the frozen
## Teleport and Terrain helpers are reached the same way).
const BuffArc := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ha/systems/ms_jormungandr_class_nhp/buff_arc.gd')

const CHIP := &'buff_arc'

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return UnitCondition.has_buff(unit, CHIP, gear.persistent_id)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_when(not Unit.is_valid(unit)): return
	# Scoped to OUR gear's own chip, the way the ZIP's disengage scopes its clear: a second copy of
	# this Kit is impossible (UNIQUE), but the id is free and states the intent.
	var chip:BuffCore = UnitCondition.get_buff(unit, CHIP, context.gear.persistent_id)
	if activation.abort_when(not is_instance_valid(chip)): return
	chip.set_state(BuffArc.DEACTIVATING, true)
