# LOCK ON: the mod's shared "Lock On consumed / lost / applied" hook. Born with the Naga (SP1
# Task 5). Consumers: the Naga (the core passive, the core active, Ping, Binding Fangs), the Black
# Mountain (Dread Harbinger) and the Koremasa (Blinkblade Slice, action_slash.gd).
#
# FROZEN INTERFACE (design ruling 20 of the Naga, roadmap 4). Five functions, exactly these names,
# argument names and types: was_consumed consumer is_lost apply source_of. A later frame that needs
# MORE extends this file in its own sub-project, with every earlier spec still green; a reshape is
# not allowed. spec/test_lockon.gd pins every signature off Script.get_script_method_list().
#
# No class_name (res/content/gear/shared/README.md): a class_name declared in a script a mod loads
# at runtime is never registered. Callers preload this file. Same shape as overshield.gd.
#
# WHERE THE ENGINE SAYS "A LOCK WAS CONSUMED". Vanilla has no consume event. The consume is
# action_consume_lock_on, an attack_declared PRE reaction on ms_lock_on, which clears LOCKON and
# applies buff_lock_consumed to the target (action_consume_lock_on.gd:42-43). Then, per target,
# event_unit_attack sets roll.consumed_lock = has_buff(target, buff_lock_consumed) (:54) on the
# AttackRoll it hangs on context.object, and queues ATTACK POST with that context (:123). So there
# are TWO readable moments, and was_consumed() answers for both:
#   - an `attack` trigger context: context.object is the AttackRoll; read consumed_lock through
#     AttackRoll.check, which is exactly the vanilla reader (action_autonomous_assault.gd, the
#     Autopod).
#   - an `attack_declared` context (after the consume reaction ran): the target still carries
#     buff_lock_consumed, which is only cleared when the attack roll consumes its applied buffs.
#
# MEASURED BY THE PROBE (spec/test_spike_naga_sp1_seams.gd, 2026-09-22) - THE FACT THE BLACK
# MOUNTAIN MUST DESIGN AROUND: A CONSUME CLEARS THE STATUS WITH NO SOURCE.
# action_consume_lock_on.gd:42 calls UnitCondition.clear_status with the default empty source, so
# the statuses_changed POST virtual event's `string` is EMPTY after a consume, and "when THIS lock is
# consumed" (whose lock it was) CANNOT be read after the fact. A consumer that needs it must read
# source_of(target) at ATTACK_DECLARED PRE - ahead of the consume reaction, which is itself an
# attack_declared PRE reaction, so order within PRE matters - and stash it. An ABILITY clear
# (Stabilize: clear_status_via_ability -> clear_specific_status, unit_condition.gd:326-329) DOES
# carry the status's own source.
#
# is_lost() AND TIMING. UnitCondition queues ONE virtual event name, event_unit_apply_status, for both
# directions: at PRE when a status is APPLIED (unit_condition.gd:165-167) and at POST when it is
# CLEARED (:216-218). is_lost() looks only at the event, so it answers true for either; the CALLER'S
# reaction must be a statuses_changed POST reaction for "true" to mean "lost". (The two virtual
# events do differ in one field - the apply carries flags = [until], the clear flags = [] - but this
# helper deliberately does not lean on that: it is an undocumented detail of the engine's
# construction, not a contract.)
extends RefCounted

const CONSUMED_BUFF := &'buff_lock_consumed'

## True when a lock was consumed for this attack. Two shapes (see header):
## an `attack` context whose object is an AttackRoll with consumed_lock, or an `attack_declared`
## context whose target_unit holds buff_lock_consumed. False for null, or for neither.
##
## `object` is untyped on Context (context.gd:33) and some events put a String there, so it is
## class-checked before AttackRoll.check - whose parameter is typed Object - ever sees it.
static func was_consumed(context:Context) -> bool:
	if context == null: return false
	if context.object is AttackRoll and AttackRoll.check(context.object, &'consumed_lock') == true:
		return true
	if Unit.is_valid(context.target_unit) and UnitCondition.has_buff(context.target_unit, CONSUMED_BUFF):
		return true
	return false

## Who consumed it: the ATTACKER, resolved the way the consume reaction itself resolves it
## (action_consume_lock_on.gd:15) - so a drone's shot is its owner's. Null when the context carries
## no valid unit.
static func consumer(context:Context) -> Unit:
	if context == null or not Unit.is_valid(context.unit): return null
	return context.unit.get_attacker(context)

## True when this statuses_changed virtual event is about LOCKON. CALL IT FROM A POST REACTION ONLY -
## the same virtual event at PRE is the APPLY, and this cannot tell the two apart (see header).
static func is_lost(triggering:EventCore) -> bool:
	if triggering == null or triggering.context == null: return false
	return triggering.context.category_str == Lancer.STATUS.LOCKON

## Lock the target on, the way vanilla Lock On does through ActionSystemApplyStatus: LOCKON,
## UNTIL.MANUAL, source = the locking gear's persistent_id (which is what makes source_of useful).
##
## Returns false and does nothing for an invalid target or gear, and for a target ALREADY locked -
## vanilla's own targeting refuses that (action_lock_on.gd:5-11), and a second stacked StatusCondition
## would leave a stale source behind the first clear. Returns false when the target is immune, which
## apply_status reports by returning null.
##
## A NULL EVENT FALLS BACK TO THE LEVEL, like its siblings (Overshield._fire, Teleport._run,
## Terrain.lay; close-out Pass F Task 21): false when there is no level, otherwise the lock lands on
## the stand-in a spec's dummy event is (SpecFactory.dummy_event, EventCore.create(&'event_delay', ...)).
## apply_status dereferences the event unguarded (on_status_application queues the statuses_changed
## virtual event on it), so without this a null event threw. This stays synchronous - the frozen
## signature returns bool - so the stand-in has no block and the apply's statuses_changed PRE
## reactions are not queued; a caller that needs them passes its live activation.
static func apply(event:EventCore, target:Unit, source_gear:GearCore) -> bool:
	if not Unit.is_valid(target): return false
	if not GearCore.is_valid(source_gear): return false
	if UnitCondition.has_status(target, Lancer.STATUS.LOCKON): return false
	var carrier := event
	if carrier == null or carrier.context == null:
		if X.current_level() == null: return false
		carrier = EventCore.create(&'event_delay', {unit = target})
	var applied := UnitCondition.apply_status(carrier, target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL,
		source_gear.persistent_id)
	return applied != null

## The source (the locking gear's persistent_id) of the unit's live LOCKON, or &'' when the unit is
## invalid or not locked. Read it at ATTACK_DECLARED PRE if a consume is coming - see header.
static func source_of(unit:Unit) -> StringName:
	if not Unit.is_valid(unit): return &''
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == Lancer.STATUS.LOCKON: return condition.source
	return &''
