# ACTIVATE EMERGENCY ARMATURE (Hazard rank I system, SP2 Task 2, design ruling 9):
#
#   "Reaction, 1/round. Trigger: You take damage from a hostile character. Effect: Expend a charge,
#    you reduce the incoming damage by 1d6 and may move two spaces. This movement ignores
#    engagement and doesn't provoke reactions."
#
# DAMAGE PRE, a REAL reaction (consumes_rxn left at its default true): the point is the price and
# the 1/round, and a real reaction is also refused while uncharged, Stunned or Jammed
# (action_reaction.gd:57-58, :72-76). The charge goes through the default consumes_charges inside
# spend_actions (unit_action.gd:274).
#
# PRE, because at PRE event_unit_damage has written only its PRELIMINARY figure and builds the final
# one after the reactions (event_unit_damage.gd:47-61) - so a RESIST_DAMAGE buff hung here is counted.
#
# THE GATE. context.unit is the VICTIM on a damage event (Halo's header), and must be us.
# "From a hostile character": context.target_unit is the engine's "who did this"
# (event_unit_attack_declared.gd:166), walked up to its owner so a hostile drone's hit is its
# owner's - buff_rage_hatred.gd's damager(), the mod-wide rule. Not HEAT (heat is not damage), not
# SELF_INFLICTED. And context.number > 0: the preliminary post-armor figure, so a hit armor ate
# whole is not "take damage" (Halo's measurement). An end-of-turn burn tick names no dealer at all
# (event_turn_end.gd:101-106) and never offers.
#
# "YOU MAY": CommonActionUtil.confirm_use - the player's yes/no, the AI's ai_confirms_use (true: the
# reduction is free value). Nothing is spent on a no.
#
# THE 1d6 is rolled HERE, once, and loaded into buff_emergency_armature_reduce as a pool (author,
# 2026-09-24) - see that script.
#
# THE MOVE resolves inside the reaction, before the damage lands (the damage still lands on the
# Hazard wherever it stands): event_unit_pick_move with a budget of 2, voluntary, ignore_engagement
# and ignore_rxns - the two things the card names - and spend_move left false, so it costs none of
# the Hazard's own speed. Voluntary is what keeps DON'T GIVE UP THE MECH's knockback immunity from
# refusing it (buff_dgutm_knockback.gd). The reticle's cancel is "no move"; the reduction stays.
extends ActionReaction

const BuffReduce := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ipsn/systems/ms_emergency_armature/buff_emergency_armature_reduce.gd')

const MOVE_SPACES := 2
const REDUCTION_DICE := '1d6'

@export var reduce_buff:Buff

## Everything is read defensively below; a required prop would abort the activation in the cases
## the card exists for (Halo's reasoning).
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if context.category_int == Lancer.DAMAGE_TYPE.HEAT: return false
	if context.flags.has(EventService.DAMAGE_FLAG.SELF_INFLICTED): return false
	if context.number <= 0: return false
	return Unit.is_valid(damager(context, unit))

func activate(context:Context, activation:EventCore) -> void:
	var hazard:Unit = context.unit
	if not Unit.is_valid(hazard): return
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(hazard): return

	spend_actions(activation) # the point and a charge

	var reduce_core:BuffCore = apply_buff(activation, hazard, reduce_buff)
	BuffReduce.arm(reduce_core, Dice.roll_string(REDUCTION_DICE))

	var movement := MovementType.create(hazard, true)
	movement.ignore_engagement = true
	movement.ignore_rxns = true
	await activation.execute_event(&'event_unit_pick_move', {
		target_unit = hazard,
		resource = movement,
		number = MOVE_SPACES,
		unit = hazard,
		gear = context.gear,
		action = context.action,
	})

## The hostile CHARACTER responsible for a damage event, or null - buff_rage_hatred.gd's damager()
## verbatim (the Jormungandr's copy says why a copy): target_unit walked to its owner (an unowned
## drone resolves to itself), a character (is_character() - a drone included, ruling 2026-09-27), an
## enemy.
func damager(context:Context, holder:Unit) -> Unit:
	if not Unit.is_valid(context.target_unit): return null
	var them:Unit = context.target_unit.get_owner_unit_or_self()
	if not Unit.is_valid(them): return null
	if not them.is_character(): return null
	if not UnitRelation.are_enemies(holder, them): return null
	return them
