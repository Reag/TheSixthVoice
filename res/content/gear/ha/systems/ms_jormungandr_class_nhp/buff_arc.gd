# THE A.R.C. CHIP (Leoleth rank III, design ruling 17). One visible chip carries the whole card:
#
#   "While the A.R.C systems are active, you gain the following effects: ...
#    - You gain 1 heat every time you make an attack.
#    You can begin to deactivate this system as a protocol. At the start of your next turn it
#    deactivates."
#
# THREE JOBS, TWO OF THEM HERE. The retaliation is a real reaction on the Kit
# (action_automatic_retaliation.gd) gated on holding this chip; the +1d6 is buff_arc_bonus, applied
# and cleared alongside. What lives HERE is the heat toll and the two-step deactivation.
#
# ONE BUFF, TWO TRIGGERS, ONE TIMING. Buff carries a single trigger_timing for the whole
# triggers_on array (buff.gd:138-139), and POST is right for both: an attack_declared POST fires
# once the attack has been declared and every target resolved, and a new_turn POST is queued at
# event_turn_start.gd:56, AFTER handle_starting_unit has cleared the START_OF_TURN buffs at :65. So
# activate dispatches on the triggering event's own type rather than on a second resource.
#
# THE HEAT IS PER ATTACK, NOT PER HIT OR PER TARGET. "every time you MAKE an attack" prices the
# swing: event_unit_attack_declared fires once for the declaration, whether the roll lands or misses
# and however many targets an AoE covers. Tech attacks are included, because the card does not
# exclude them.
#
# THE MOVER MUST BE THE HOLDER. The reaction bus offers every chip on the map every event
# (reaction_bus.gd:61-67), so `context.unit != unit` is a correctness clause here and not a
# performance guard: without it the Leoleth would take a point of heat for every attack anybody
# makes anywhere.
#
# "YOU CAN BEGIN TO DEACTIVATE" IS A STAMP, NOT A CLEAR. action_arc_deactivate writes DEACTIVATING
# into this core's state; nothing happens until the holder's own next turn start, which is the
# card's sentence exactly. Without the stamp a new_turn does nothing at all, which is what keeps
# `until` at MANUAL honest - an A.R.C. nobody switched off runs until the scene ends.
#
# THE CLEAR GOES THROUGH clear_buffs_owned_by, NOT clear_buff. Both this chip and buff_arc_bonus are
# applied by the same protocol from the same GearCore, so one call by persistent_id takes both and
# cannot leave the bonus hanging on a deactivated system (the Goblin's action_symbiosis_end.gd is
# the same shape). clear_buff on this core alone is the fallback for the case that cannot happen -
# a chip whose owner gear has gone - and it is there so a lost GearCore cannot make the A.R.C.
# permanent.
#
# activate DOES NOT CALL super ANYWHERE. Buff.activate's default body clears the buff
# (buff.gd:254-255); this chip answers many attacks and must survive all of them.
extends Buff

const HEAT := 1
const DEACTIVATING := 'deactivating'
const BONUS_CHIP := &'buff_arc_bonus'
## EventBase.event_type is the full event name, e.g. `event_unit_damage` (event_base.gd:5) - not the
## ReactionBus trigger alias in `triggers_on`. action_reaction_break_connection.gd:56 reads it the
## same way.
const EVENT_ATTACK_DECLARED := &'event_unit_attack_declared'
const EVENT_TURN_START := &'event_turn_start'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	var event_type:StringName = triggering_event.base.event_type
	if event_type == EVENT_ATTACK_DECLARED: return true
	# A deployable gets a VIRTUAL turn-start core alongside its owner (event_turn_start.gd:17-21,
	# :57-59); its context.unit is the deployable, so the identity check above has already refused
	# it and a Decimate crater cannot switch the A.R.C. off.
	if event_type == EVENT_TURN_START: return core.get_state(DEACTIVATING, false)
	return false

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	var triggering_event:EventCore = activation.context.event
	if triggering_event == null: return
	var event_type:StringName = triggering_event.base.event_type
	if event_type == EVENT_ATTACK_DECLARED: charge_the_heat(unit, activation)
	elif event_type == EVENT_TURN_START: switch_off(core, unit, activation)

func charge_the_heat(unit:Unit, activation:EventCore) -> void:
	CommonActionUtil.queue_damage_events(
		activation, unit, [unit] as Array[Unit], HEAT, Lancer.DAMAGE_TYPE.HEAT,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED]
	)

func switch_off(core:BuffCore, unit:Unit, activation:EventCore) -> void:
	var gear:GearCore = core.get_owner_gear(unit.map)
	if GearCore.is_valid(gear):
		UnitCondition.clear_buffs_owned_by(activation, unit, gear.persistent_id)
		return
	# Belt and braces: a chip whose owner gear has gone still has to be able to switch itself off.
	UnitCondition.clear_buff_id(activation, unit, BONUS_CHIP)
	UnitCondition.clear_buff(activation, unit, core)
