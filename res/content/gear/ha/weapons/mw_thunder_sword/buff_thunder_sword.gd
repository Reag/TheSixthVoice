# THE THUNDER SWORD'S CHIP (Leoleth rank I, design ruling 19).
#
#   "Until the end of your next turn, if the damaged character voluntarily moves, they take 1 AP
#    Energy damage per space, up to a maximum of 5."
#
# VANILLA'S BARRICADE IS THE EXACT PER-SPACE PRECEDENT (buff_drag_down_barricade.gd), and this is
# that file with three differences the card dictates: 1 point rather than 2, a running cap, and
# ENERGY rather than the Barricade's ENERGY at a different flag set (both are AP).
#
# THE CAP IS STATE ON THE CORE, NOT ON THE RESOURCE. BuffCore.state is a per-application dictionary
# (buff_core.gd:6); the Buff itself is the shared ContentLibrary singleton and MUST never be written
# to, or every future chip from this weapon would start pre-spent.
#
# THE RESET COMES FREE FROM multiple_copies_can_stack = false (the Buff default, buff.gd:131):
# UnitCondition.apply_buff_alt clears the matching old core (unit_condition.gd:741-747) and
# apply_buffs then creates a FRESH BuffCore with an empty state (:709). Nothing here resets anything.
#
# WE DO NOT OVERRIDE is_cleared_on_owner_death. The Barricade does (its crater outlives it); this
# chip's whole clock is "your next turn", so a dead Leoleth has no next turn - and
# EventService.remove_unit_from_game force-clears every END_OF_OWNERS_NEXT_TURN buff it owns anyway
# (event_service.gd:74, force_now = true).
extends Buff

## How much this application has already dealt. Capped at MAX_DAMAGE.
const DAMAGE_DEALT_KEY := 'damage_dealt'
const MAX_DAMAGE := 5
const DAMAGE_PER_SPACE := 1

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context

	# are we the unit who moved? (a step event is broadcast; every chip on the map sees it)
	if triggering_context.unit != unit: return false

	# "voluntarily moves". MovementType.voluntary is false for a knockback, a pull or any other
	# forced move - and create_for_involuntary does not merge buffs at all (movement_type.gd:64-72).
	if not MovementType.is_valid(triggering_context.resource): return false
	var movement_type:MovementType = triggering_context.resource
	if not movement_type.voluntary: return false

	# "up to a maximum of 5" - once spent out, this chip is GONE (author ruling, 2026-09-22), so this
	# guard should never actually fire. It stays as a belt-and-braces floor: if anything ever reaches
	# a spent core, it pays nothing rather than paying again.
	if core.get_state(DAMAGE_DEALT_KEY, 0) >= MAX_DAMAGE: return false

	return true

func activate(core:BuffCore, activation:EventCore) -> void:
	var context := activation.context
	var triggering_unit:Unit = context.event.context.unit
	if not Unit.is_valid(triggering_unit): return

	var already:int = core.get_state(DAMAGE_DEALT_KEY, 0)
	var amount:int = mini(DAMAGE_PER_SPACE, MAX_DAMAGE - already)
	if amount <= 0: return
	var total:int = already + amount
	core.set_state(DAMAGE_DEALT_KEY, total)

	# The damage is dealt BY THE LEOLETH - core.get_owner_unit resolves from_gear (the sword's
	# GearCore) back through map.get_unit_from_source_id (buff_core.gd:102-105).
	CommonActionUtil.queue_damage_events(
		activation, core.get_owner_unit(context.map), [triggering_unit],
		amount, Lancer.DAMAGE_TYPE.ENERGY, [EventService.DAMAGE_FLAG.AP]
	)

	# SPENT OUT: the chip removes itself, so what is on screen is always a live threat (AUTHOR
	# RULING, 2026-09-22 - design ruling 19 said "a stop at 5" and was silent on the chip). This is
	# the Buff base class's own default activate() line (buff.gd:255), used deliberately rather than
	# by falling through to it: context.unit on an event_buff_activate is the buff's HOLDER
	# (event_buff_activate.gd:6-11, measured in SP1 Task 12), which is the unit we want.
	if total >= MAX_DAMAGE:
		UnitCondition.clear_buff(activation, activation.context.unit, core)
