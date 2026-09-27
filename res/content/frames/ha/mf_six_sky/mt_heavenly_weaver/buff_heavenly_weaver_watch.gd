## HEAVENLY WEAVER, the arming half (design 1.3, rulings 7-8):
##
##   "1/round, when the Six Sky teleports itself, or another character, the next successful attack it
##    makes deals +1d6 Bonus damage."
##
## A hidden triggered buff on the Six Sky, listening at ENTIRE_MOVEMENT POST for every unit's move. It
## arms the visible chip (buff_heavenly_weaver) when:
##   - the move is a completed teleport the Six Sky caused (six_sky_agent.gd, ruling 5) - a hostile
##     shoving the Six Sky is the HOSTILE's teleport, so it does not arm;
##   - the mover is the Six Sky itself, or a CHARACTER (Unit.is_character(), a drone included -
##     rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 4; a deployable still is not
##     one), ally or hostile alike;
##   - the round is unspent;
##   - the chip is not already held.
##
## THE CHIP LASTS UNTIL USED (ruling 8, the author's call), so a re-arm while it is held is refused
## HERE, before the round is touched: it neither stacks nor spends the round.
##
## THE ROUND IS HAND-ROLLED on the trait gear, Precision Venting's shape: the engine enforces no round
## for a buff-triggered effect (reaction_bus.gd:116-124 consults it for ActionReactions only). The
## counter resets at the Six Sky's own turn start (unit_action.gd:86-87, ruling 4).
##
## BOTH GATES ARE RE-READ IN activate, because event_buff_activate has no
## recheck_trigger_before_execution (the Rend chip's reason): two POSTs queued before the first
## activation runs would otherwise both pass. (Not a katamari's passengers, as this said until the
## close: they move with create_for_involuntary, which carries no teleport flag, so they never pass.)
extends Buff

const Agent := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/six_sky_agent.gd')

const USAGE_KEY:StringName = &'heavenly_weaver'
const CHIP:StringName = &'buff_heavenly_weaver'
const Chip := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/mt_heavenly_weaver/buff_heavenly_weaver.gd')

## The mover and the MovementType that says whether it teleported.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if not Agent.is_teleport_by(unit, triggering_event): return false
	var mover:Unit = context.unit
	if not Unit.is_valid(mover): return false
	if mover != unit and not mover.is_character(): return false # "itself, or another CHARACTER"
	return can_arm(core, unit)

## The round is unspent and the chip is not held.
static func can_arm(core:BuffCore, six_sky:Unit) -> bool:
	if UnitCondition.has_buff(six_sky, CHIP): return false
	var trait_gear:GearCore = core.get_owner_gear(six_sky.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0

## Never calls super: Buff.activate would clear this watch from the Six Sky.
func activate(core:BuffCore, activation:EventCore) -> void:
	var six_sky:Unit = activation.context.unit
	if not Unit.is_valid(six_sky) or not can_arm(core, six_sky): return
	var trait_gear:GearCore = core.get_owner_gear(six_sky.map)
	trait_gear.increment_action_usage(USAGE_KEY, false)
	UnitCondition.apply_buff_id(activation, six_sky, CHIP, trait_gear)
	# ARMED INSIDE AN ATTACK (a Daykeeper crit): that attack may not spend it - the chip's header.
	var enclosing := enclosing_declared_attack(activation)
	if enclosing != null: enclosing.set_meta(Chip.ARMED_DURING_META, true)

## The DeclaredAttackSummary of the attack this activation runs inside, or null. The block-tree walk
## the Purple Thorn's attack_trace.gd uses: the move a crit makes is executed on the attack's own core,
## so its POST reactions run in blocks nested under the declared attack's.
static func enclosing_declared_attack(activation:EventCore) -> DeclaredAttackSummary:
	if activation == null: return null
	var node = activation.block
	while node is EventBlock:
		for core:EventCore in node.event_cores:
			if core.base.event_type == &'event_unit_attack_declared' and DeclaredAttackSummary.is_valid(core.context.resource):
				return core.context.resource
		node = node.get_parent()
	return null
