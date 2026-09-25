## MAKIBISHI MAGNETS, ATTACHED (design 3.1, rulings 21-23, 25). One buff for both routes - Throw
## Magnets and the mine - applied from the MAKIBISHI KIT, so the victim's detach saves against the
## Koremasa and a second magnet from the same Koremasa replaces the first (ruling 22, the engine's
## own same-source replacement).
##
##   "Characters to whom they are attached are impaired and take 1 AP Kinetic damage for each space
##    they voluntarily move up to a maximum of 5. Characters can detach makibishi magnets from
##    themselves by passing an Agility save as a quick action on their turn. All magnets detach at
##    the end of the scene."
##
## IMPAIRED is the .tres's applies_statuses: it lives and dies with the buff. MANUAL: the scene's end
## clears it (believed, not traced - spec/test_makibishi_magnets.gd pins MANUAL and nothing more).
##
## PER STEP: the Barricade's Drag Down (buff_drag_down_barricade.gd) - a STEP trigger on the holder's
## own VOLUNTARY moves, 1 AP Kinetic each (ruling 23). A katamari passenger is handed an involuntary
## virtual move (event_unit_move.gd:316-322) and is never charged; a voluntary teleport is one step.
##
## THE CAP IS PER TURN OF THE VICTIM (ruling 21, the author's): a counter keyed on the round and the
## victim's activations, the Excommunicate key (buff_excommunicate.gd get_affect_key). NOT
## spaces_moved_this_turn, which resets at EVERY unit's turn start (unit_action.gd:67-72). Only the
## current key is kept, so the state never grows.
##
## THE DETACH is situational gear the buff carries (the Hornet's javelins,
## buff_lock_hold_javelins_hornet.gd): it reaches the victim whatever becomes of the Koremasa, since
## the magnets outlive it (ruling 25).
extends Buff

const DETACH_KIT := &'bt_makibishi_magnets'
const CAP := 5
const TURN_KEY := 'reag_makibishi_turn'
const STEPS_KEY := 'reag_makibishi_steps'

func is_cleared_on_owner_death() -> bool: return false

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	core.situational_gear = GearCore.create_from_id(DETACH_KIT)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context := triggering_event.context
	if context.unit != unit: return false
	if not MovementType.is_valid(context.resource): return false
	if not context.resource.voluntary: return false
	return steps_this_turn(core, unit) < CAP

func activate(core:BuffCore, activation:EventCore) -> void:
	var context := activation.context
	var victim:Unit = context.event.context.unit
	if not Unit.is_valid(victim): return
	var steps := steps_this_turn(core, victim) # read BEFORE the key moves, or a new turn inherits the old count
	core.set_state(TURN_KEY, turn_key(victim))
	core.set_state(STEPS_KEY, steps + 1)
	CommonActionUtil.queue_damage_events(
		activation, core.get_owner_unit(context.map), [victim],
		1, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP]
	)

## Spaces already charged on the victim's current turn.
func steps_this_turn(core:BuffCore, unit:Unit) -> int:
	if core.get_state(TURN_KEY, '') != turn_key(unit): return 0
	return int(core.get_state(STEPS_KEY, 0))

func turn_key(unit:Unit) -> String:
	return '%s-%s' % [unit.map.game_core.round_count, unit.core.current.activations]
