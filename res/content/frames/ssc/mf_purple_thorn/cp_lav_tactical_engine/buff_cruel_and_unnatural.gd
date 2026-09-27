# REND's chip (Purple Thorn, cp_lav_tactical_engine), ruling 7:
#
#   "Until the end of your next turn, whenever you deal damage to a hostile character, they must
#    make a Systems save or be teleported to free space you choose within range 3 of their original
#    position."
#
# A VISIBLE buff on the Thorn with a DAMAGE POST trigger - the Hunt of the Vagrant Sowche
# (action_hunt_of_the_vagrant_sowche.gd:95-116) copied step for step, from a buff instead of an
# invade: the save forced with the FULL SpecificAction (the Hunt's trifecta rule), then on a fail
# the free spaces within 3 of the VICTIM measured from where it stands ("their original position" -
# it has not moved yet), the THORN's own reticle over them ("you choose"), then Teleport.shove.
#
# THE GATE is Vigil's reading of "deals damage" (action_vigil.is_damage_dealt_by: the dealer read off
# target_unit.get_attacker, number > 0, not HEAT, not SELF_INFLICTED) plus the card's two extra
# words: the victim is a HOSTILE (are_enemies) CHARACTER (is_character() - a drone included, ruling
# 2026-09-27; still not an object). ONCE PER VICTIM PER ATTACK: a two-type hit, or Hyper Engineered Munitions' extra point
# (SP4), is one attack and forces ONE save; the stamp is the enclosing declared attack's id
# (attack_trace.gd) joined to the victim's persistent id, in this core's state, and the predicate
# refuses a repeat. A Blast on two hostiles forces two saves, one each - that is two victims.
#
# THE STAMP IS ALSO RE-CHECKED AT THE TOP OF activate, because event_buff_activate has no
# recheck_trigger_before_execution: a two-type hit queues BOTH damage POSTs before either runs, both
# pass the predicate at queue time (nothing stamped yet), and only the in-activate check stops the
# second from forcing a second save.
#
# THE SHOVE TAKES THE TARGET-TILE ROUTE (Teleport.shove, design ruling 18 of the Sluagh): a
# MOVEMENT_RESTRICTION ban still stops it and Immobilized does not. The event's `object` is derived
# from this activation's context - a buff activation carries the Thorn as `unit` and no gear or
# action - so Teleport.forcer reads the THORN, are_enemies(victim, thorn) is true, and a Maiden's
# Blush's Uncertainty Field correctly offers on it. A passed save, an empty set, or a cancelled
# pick: no move.
#
# ORDER ON ONE HIT WITH VIGIL (ruling 8, MEASURED by spec/test_spike_purple_thorn_sp1_seams.gd,
# 2026-09-23): ReactionBus.trigger_occurred appends a unit's GEAR reactions before its buffs, at
# equal priority, and EventBlock's tiebreak is first-created-first-run - so VIGIL'S TELEPORT
# RESOLVES FIRST, then this shove. The design expected the opposite; the card's numbers are
# unaffected either way (the victim's set is measured from where it stands, the Thorn's from where
# it stands after its own move). test_rend.gd pins the measured order.
#
# UNTIL END_OF_NEXT_TURN, on the .tres: applied on the Thorn's own turn, it converts at the Thorn's
# next turn start and clears at that turn's end (unit_condition.gd:18-19, :34) - "until the end of
# your next turn".
extends Buff

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const AttackTrace := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/attack_trace.gd')
const VigilAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/mt_vigil/action_vigil.gd')

const TELEPORT_RANGE := 3
const REND_ID := &'action_rend'
## Buff core state: every "<attack id>:<victim id>" this chip has already forced a save for.
const FORCED_KEY := 'rend_forced'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.number]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if not VigilAction.is_damage_dealt_by(unit, context): return false
	var victim:Unit = context.unit
	if not Unit.is_valid(victim) or not victim.is_character(): return false # "a hostile CHARACTER"
	if not UnitRelation.are_enemies(unit, victim): return false # "a HOSTILE character"
	return not core.state_has_id_in(FORCED_KEY, stamp_for(triggering_event, victim))

## One save per victim per attack.
static func stamp_for(damage:EventCore, victim:Unit) -> StringName:
	return StringName('%s:%s' % [AttackTrace.enclosing_attack_id(damage), victim.core.persistent_id])

func activate(core:BuffCore, activation:EventCore) -> void:
	var thorn:Unit = activation.context.unit
	var damage:EventCore = activation.context.event
	if damage == null or damage.context == null: return
	var victim:Unit = damage.context.unit
	if not Unit.all_valid([thorn, victim]): return

	# 1. THE STAMP, FIRST - and the re-check event_buff_activate does not do for us.
	var stamp := stamp_for(damage, victim)
	if core.state_has_id_in(FORCED_KEY, stamp): return
	core.append_to_array_state(FORCED_KEY, String(stamp))

	# The FULL SpecificAction: the Thorn, the core Kit, Rend - what the save names as its forcer.
	var specific:SpecificAction = core.get_owner_specific(thorn.map, REND_ID)
	if not SpecificAction.is_valid(specific): return

	# 2. THE SAVE. Saver = victim, forcer = the Thorn (unit_hasecheck.gd:42-45, :79-84).
	var passed:bool = await UnitHasecheck.make_systems_save(activation, victim, specific)
	if activation.abort_without_units([thorn, victim]): return
	if passed: return

	# 3. THE FREE SPACES within 3 of where the victim stands, no line of sight required.
	var tiles := Teleport.candidate_tiles(victim, TELEPORT_RANGE, false)
	if tiles.is_empty(): return # nowhere to put them; the save was still forced

	# 4. THE PICK - the THORN's player, through the helper's own reticle, in Rend's name.
	var tile:Vector2i = await Teleport.pick_tile(specific.to_context(), activation, tiles)
	if tile == Tile.INVALID: return # cancelled; the save was forced
	if activation.abort_without_units([thorn, victim]): return

	# 5. THE SHOVE.
	await Teleport.shove(activation, victim, tile)
