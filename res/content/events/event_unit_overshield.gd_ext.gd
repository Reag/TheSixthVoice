# OVERSHIELD "GRANTED BY", FROM ANY SOURCE (playtest finding 2026-09-29; widens Black Mountain ruling 5).
#
# An End to All Things asks for "OVERSHIELD you granted". Until this file the "granted by" mark was hung
# only by the shared helper's grant_by / increase_by, so every OTHER grant the Black Mountain made - a
# vanilla Aceso Stabilizer, another mod's Micro-Maintenance Suite, this mod's own plain Overshield.grant
# callers - left the ally unmarked and the trait silent. The card does not restrict the source.
#
# THE RULE: every Overshield event credits the gear whose ACTIVATION it runs inside - the nearest
# ancestor EventBlock holding an event_gear_activate (execute_event and queue_event both nest the new
# block under the activation's own, event_core.gd:71-89). A reaction is its own activation, so it is
# nearer than whatever it reacted to. The walk STOPS, crediting nobody, at:
#   - an event_buff_activate: the grant is the buff's owner's, and our buffs that grant name that
#     owner explicitly (DOOMED through increase_by; ruling 13 wants no mark once its Black Mountain is
#     dead, which is what increase_by's invalid-gear path gives);
#   - a block with two DIFFERENT activating gears (breadth-first): ambiguous, so no guess;
#   - the root: a grant with no activation above it (a spec's level path, a spawn trigger).
# grant_by / increase_by still mark explicitly after this runs. Same gear -> same-source refresh
# (unit_condition.gd:741-747), never a second copy.
#
# THE MARK is the helper's, with the helper's "took" rule (overshield.gd _mark_if_took): after the
# event the target holds Overshield, and it rose or the number asked was at least what it held.
# `number` is what was asked: increase() already hands the event current + amount.
#
# THE STALE-MARK CLEAR MOVES HERE TOO for every grant, not only the helper's (overshield.gd _fire,
# close-out Pass F Task 21): a grant onto an EMPTY shield first clears every mark, because two vanilla
# paths zero the shield without LOSE_OVERSHIELD and a mark on an empty shield is stale by definition.
# Left in _fire as well; the second clear finds nothing.
#
# COMPOSES WITH the resident gavstarb-ssc_emperor's extension of this same script (Imperial Vestment
# rewrites `number` in its PRE, before execute; it overrides execute only to queue its POST after
# super). Whichever order ModLoader chains the two in, `before` is read before either execute body and
# `number` is the final value. spec/test_compat.gd covers the Emperor side.
extends "res://content/events/event_unit_overshield.gd"

const GRANTED_BY_MARK := &'buff_overshield_granted_by'
const GEAR_ACTIVATE := &'event_gear_activate'
const BUFF_ACTIVATE := &'event_buff_activate'

func execute(core:EventCore) -> void:
	var target:Unit = core.context.unit
	var before:int = target.state.overshield if Unit.is_valid(target) else 0
	if before == 0 and Unit.is_valid(target) and not UnitCondition.get_buffs(target, GRANTED_BY_MARK).is_empty():
		UnitCondition.clear_buff_id(core, target, GRANTED_BY_MARK)
	await super(core)
	if not Unit.is_valid(target): return
	var now:int = target.state.overshield
	if now <= 0: return
	if not (now > before or int(core.context.number) >= before): return
	var granter_gear := granting_gear(core)
	if not GearCore.is_valid(granter_gear): return
	# The lookup is_granted_by makes through BuffCore.get_owner_unit: a gear that names no live unit
	# marks nothing.
	if not Unit.is_valid(core.context.map.get_unit_from_source_id(granter_gear.persistent_id)): return
	var mark_base:Buff = ContentLibrary.get_buff(GRANTED_BY_MARK)
	if mark_base == null: return
	UnitCondition.apply_buff_alt(core, target, BuffCore.create(mark_base, granter_gear.persistent_id))

## The gear of the nearest activation this event runs inside, or null (see the header for the stops).
static func granting_gear(core:EventCore) -> GearCore:
	var node:Node = core.block
	while is_instance_valid(node) and node is EventBlock:
		var found:GearCore = null
		for ancestor:EventCore in node.event_cores:
			if ancestor == core: continue
			var type:StringName = ancestor.base.event_type if ancestor.base != null else &''
			if type == BUFF_ACTIVATE: return null
			if type != GEAR_ACTIVATE: continue
			var gear = ancestor.context.gear
			if not GearCore.is_valid(gear): continue
			if found != null and found != gear: return null
			found = gear
		if found != null: return found
		node = node.get_parent()
	return null
