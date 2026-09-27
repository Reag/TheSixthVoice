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
## copy itself, whatever its source - a sourceless magnet, a mine that outlived its Koremasa (row 568),
## included - and even on the same-source path, in case a save from before Pass F holds two. The new
## core is already in state.buffs (:757-758), so the victim stays Impaired throughout. Of every core
## replaced - the engine's outgoing one (the meta) and the ones cleared here - the BUSIEST (most steps
## this turn) is the one whose count and detach carry over. The detach then saves against the NEWEST
## Koremasa, the owner of the core that stays.
##
## THE OWNER IS RESOLVED ONCE AND STORED (Pass F 7b, the author's ruling on a VANILLA BUG). The engine
## finds a buff's owner through MapState.get_unit_from_source_id, which returns - and CACHES - the first
## unit in the list carrying a buff with ANY situational gear, whatever id it was asked about
## (map_state.gd:290-293); get_gear_by_id gives up with null at the same point (:261-264). A magnet IS
## such a buff, so once one is on a victim listed ahead of its Koremasa, every uncached lookup of the
## Kit answers "the victim": the step damage became self-inflicted and the detach fell back to the
## DC 10 check. The cache starts empty after every load (map_state.gd:102), so a lone Koremasa was
## exposed too. So on_application stores the Kit holder's unit id (OWNER_KEY), found by a direct
## loadout scan; this file reads it directly (owner_of), and the detach does too
## (action_makibishi_detach.gd). For the engine's OWN reads - apply_buff_alt's aura check, the
## clear's token refresh - seed_owner_cache writes that one cache key from the stored id before each
## point this buff controls. A magnet from before 7b has no OWNER_KEY and falls back to the engine.
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
## The persistent id of the unit whose Kit applied this magnet; '' when there was none.
const OWNER_KEY := 'reag_makibishi_owner'

func is_cleared_on_owner_death() -> bool: return false

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	record_owner(core, unit.map)
	var replaced:Array[BuffCore] = []
	var engine_outgoing := take_outgoing(event, core, unit) # the engine's same-source clear, if any
	if BuffCore.is_valid(engine_outgoing): replaced.append(engine_outgoing)
	if event != null:
		var others := other_magnets(core, unit)
		UnitCondition.clear_buffs(event, unit, others)
		take_outgoing(event, core, unit) # our own clears left their meta too; drop it
		replaced.append_array(others)
	var outgoing := busiest(replaced, unit)
	if outgoing == null or not GearCore.is_valid(outgoing.situational_gear):
		core.situational_gear = GearCore.create_from_id(DETACH_KIT)
		return
	core.situational_gear = outgoing.situational_gear
	core.set_state(TURN_KEY, outgoing.get_state(TURN_KEY, ''))
	core.set_state(STEPS_KEY, outgoing.get_state(STEPS_KEY, 0))

func on_clear(event:EventCore, core:BuffCore, unit:Unit) -> void:
	if event != null:
		seed_owner_cache(core, event.context.map if event.context.map != null else unit.map) # the clear's token refresh reads it
		event.set_meta(OUTGOING_META, {unit = unit, core = core})

## Read and remove the outgoing-core meta: the core cleared on THIS unit just before, or null.
func take_outgoing(event:EventCore, core:BuffCore, unit:Unit) -> BuffCore:
	if event == null or not event.has_meta(OUTGOING_META): return null
	var left:Dictionary = event.get_meta(OUTGOING_META)
	event.remove_meta(OUTGOING_META)
	if left.unit == unit and left.core != core: return left.core
	return null

## Every other magnet on the unit, whatever its source.
func other_magnets(core:BuffCore, unit:Unit) -> Array[BuffCore]:
	var others:Array[BuffCore] = []
	for other:BuffCore in UnitCondition.get_buffs(unit, core.base.compcon_id):
		if other != core: others.append(other)
	return others

## The core with the most steps charged this turn; the first of equals. null for none.
func busiest(cores:Array[BuffCore], unit:Unit) -> BuffCore:
	var best:BuffCore = null
	for candidate:BuffCore in cores:
		if best == null or steps_this_turn(candidate, unit) > steps_this_turn(best, unit): best = candidate
	return best

# ---------------------------------------------------------------- the owner (Pass F 7b)

## Store the Kit holder's unit id, and put right the tier and faction apply_buff_alt stamped
## (unit_condition.gd:750-754) from the engine's lookup - possibly from the victim.
func record_owner(core:BuffCore, map:MapState) -> void:
	var owner := find_kit_holder(core.from_gear, map)
	core.set_state(OWNER_KEY, String(owner.core.persistent_id) if Unit.is_valid(owner) else '')
	if Unit.is_valid(owner):
		core.set_state(Buff.TIER_KEY, owner.core.tier)
		core.set_state(Buff.FACTION_KEY, owner.core.faction)
	seed_owner_cache(core, map)

## The unit whose LOADOUT holds this gear id - the half of the vanilla search that is right
## (map_state.gd:287-289), without the buff half that is not.
static func find_kit_holder(gear_id:StringName, map:MapState) -> Unit:
	if gear_id.is_empty() or map == null: return null
	for candidate:Unit in map.get_all_units():
		if candidate.core.loadout.has_persistent_id(gear_id): return candidate
	return null

## The magnet's owner, from the stored id: null when it had none or is gone from the map. A magnet
## applied before Pass F 7b has no stored id and asks the engine.
func owner_of(core:BuffCore, map:MapState) -> Unit:
	if map == null: return null
	if not core.state.has(OWNER_KEY): return core.get_owner_unit(map)
	var owner_id:String = core.get_state(OWNER_KEY, '')
	return map.get_unit_by_id(StringName(owner_id)) if not owner_id.is_empty() else null

## PAPERS OVER A VANILLA BUG (map_state.gd:290-293 and :261-264, see the header): point the source
## cache's entry for THIS magnet's Kit at the stored owner, so the engine's own lookups of it resolve
## right. Writes that one key and nothing else, and only from a stored id.
func seed_owner_cache(core:BuffCore, map:MapState) -> void:
	if map == null or core.from_gear.is_empty(): return
	var owner_id:String = core.get_state(OWNER_KEY, '')
	if owner_id.is_empty(): return
	map.cached_source_to_unit[core.from_gear] = StringName(owner_id)

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
	seed_owner_cache(core, context.map)
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
		activation, owner_of(core, context.map), [victim],
		1, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP]
	)

## Spaces already charged on the victim's current turn.
func steps_this_turn(core:BuffCore, unit:Unit) -> int:
	if core.get_state(TURN_KEY, '') != turn_key(unit): return 0
	return int(core.get_state(STEPS_KEY, 0))

func turn_key(unit:Unit) -> String:
	return '%s-%s' % [unit.map.game_core.round_count, unit.core.current.activations]
