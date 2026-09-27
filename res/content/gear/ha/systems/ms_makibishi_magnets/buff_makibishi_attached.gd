## MAKIBISHI MAGNETS, ATTACHED (design 3.1, rulings 21-23, 25). One buff for both routes - Throw
## Magnets and the mine - applied from the MAKIBISHI KIT, so the victim's detach saves against the
## Koremasa whose magnet it is. A second magnet REPLACES the first, from any Koremasa (ruling 22; Pass E,
## rulings.md 2026-09-27): from the same one through the engine's own same-source replacement, from
## another one through on_application below.
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
## THE CAP SURVIVES A REPLACEMENT (frame-close finding I-2): a same-source magnet landing mid-turn -
## the mine's after a throw - clears the old core (unit_condition.gd:741-747) before appending the
## new one (:757), which would restart the count and let one turn cost 10. The two calls share one
## EventCore, so on_clear leaves the outgoing core on it as meta and on_application picks it up: the
## key and count carry over, and so does the detach's GearCore with its usage (one quick action a
## turn). The meta only bridges that gap; the state itself stays in the serialized BuffCore.
##
## ANOTHER KOREMASA'S MAGNET (Pass E, settling row 567): two Koremasas' Kits have different persistent
## ids, so the engine's replacement - keyed on from_gear - never fires between them, and the victim
## used to carry both (two detach buttons, 10 a turn). on_application therefore clears every OTHER
## copy itself, through the same I-2 bridge: the new core is already in state.buffs (:757-758), so the
## victim stays Impaired throughout, and each cleared core's on_clear sets the meta. The busiest one
## (most steps this turn) is cleared LAST, so its count is the one carried over. A sourceless magnet -
## a mine that outlived its Koremasa (row 568) - is replaced the same way. The detach then saves
## against the NEWEST Koremasa, the owner of the core that stays.
##
## THE DETACH is situational gear the buff carries (the Hornet's javelins,
## buff_lock_hold_javelins_hornet.gd): it reaches the victim whatever becomes of the Koremasa, since
## the magnets outlive it (ruling 25). The engine resets per-turn usage only on a unit's LOADOUT
## (unit_action.gd:85-88), never on a buff's situational gear, and the archetype spends before its
## save (action_system_clear_buff.gd:72) - so a failed detach would lock it for the scene (frame-close
## finding I-1). The buff also triggers on NEW_TURN and clears the detach's usage at the start of
## the victim's own turn (the Swarm Body's two-trigger shape, buff_swarm_body.gd).
extends Buff

const DETACH_KIT := &'bt_makibishi_magnets'
const CAP := 5
const TURN_KEY := 'reag_makibishi_turn'
const STEPS_KEY := 'reag_makibishi_steps'
const OUTGOING_META := &'reag_makibishi_outgoing'

func is_cleared_on_owner_death() -> bool: return false

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if event != null and not is_same_source_replacement(event, unit):
		clear_other_magnets(event, core, unit)
	var outgoing:BuffCore = null
	if event != null and event.has_meta(OUTGOING_META):
		var left:Dictionary = event.get_meta(OUTGOING_META)
		event.remove_meta(OUTGOING_META)
		if left.unit == unit and left.core != core: outgoing = left.core
	if outgoing == null or not GearCore.is_valid(outgoing.situational_gear):
		core.situational_gear = GearCore.create_from_id(DETACH_KIT)
		return
	core.situational_gear = outgoing.situational_gear
	core.set_state(TURN_KEY, outgoing.get_state(TURN_KEY, ''))
	core.set_state(STEPS_KEY, outgoing.get_state(STEPS_KEY, 0))

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if event != null: event.set_meta(OUTGOING_META, {unit = unit, core = core})

## The engine has just cleared a same-source magnet on THIS unit and left it as meta (I-2).
func is_same_source_replacement(event:EventCore, unit:Unit) -> bool:
	return event.has_meta(OUTGOING_META) and event.get_meta(OUTGOING_META).unit == unit

## Clear every other magnet on the unit, whatever its source, the busiest LAST: its on_clear leaves the
## meta on_application then reads, so that turn's count survives.
func clear_other_magnets(event:EventCore, core:BuffCore, unit:Unit) -> void:
	var others:Array[BuffCore] = []
	for other:BuffCore in UnitCondition.get_buffs(unit, core.base.compcon_id):
		if other != core: others.append(other)
	if others.is_empty(): return
	others.sort_custom(func(a:BuffCore, b:BuffCore) -> bool:
		return steps_this_turn(a, unit) < steps_this_turn(b, unit)
	)
	UnitCondition.clear_buffs(event, unit, others)

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context := triggering_event.context
	if context.unit != unit: return false
	if triggering_event.base.event_type == &'event_turn_start': return true
	if not MovementType.is_valid(context.resource): return false
	if not context.resource.voluntary: return false
	return steps_this_turn(core, unit) < CAP

func activate(core:BuffCore, activation:EventCore) -> void:
	var context := activation.context
	if context.event.base.event_type == &'event_turn_start':
		if GearCore.is_valid(core.situational_gear):
			core.situational_gear.uses_this_turn.clear()
			core.situational_gear.uses_this_round.clear()
		return
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
