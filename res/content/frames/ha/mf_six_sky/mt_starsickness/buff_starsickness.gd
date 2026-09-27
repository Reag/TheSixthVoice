## STARSICKNESS (design 1.4, ruling 11):
##
##   "When the Six Sky teleports a hostile character, it may take 1 Heat. If it does, that character
##    must succeed on a Systems save or become Impaired until the end of their next turn."
##
## A hidden triggered buff on the Six Sky at ENTIRE_MOVEMENT POST, Heavenly Weaver's watch with a
## different victim filter: a completed teleport the Six Sky caused (six_sky_agent.gd, ruling 5) of a
## HOSTILE (are_enemies) CHARACTER (is_character(), a drone included - rulings.md, mod-wide row of
## 2026-09-27, reversing row 301/ruling 4). The offer comes AFTER the move, from where the victim
## landed.
##
## NO PER-ROUND LIMIT. A hostile teleported by one area effect alongside others is its own move event
## and its own offer; the stamp below only stops the SAME move being offered twice.
##
## THE ORDER in activate: the stamp (event_buff_activate has no recheck_trigger_before_execution - the
## Rend chip's reason), the yes/no, 1 heat to the Six Sky, the save, then Impaired on a fail.
##
## THE YES/NO IS CommonActionUtil.confirm_use, in action_starsickness's name. For an AI-controlled Six
## Sky it asks action_starsickness.ai_confirms_use, which declines (ruling 11).
##
## THE HEAT IS PAID BEFORE THE SAVE, INLINE: UnitAction.gain_self_heat_alt's event (SELF_INFLICTED,
## SKIP_CONSUMING_RESIST_BUFFS, unit_action.gd:296-306) executed here rather than queued, because the
## card makes the save conditional on the heat already taken ("If it does").
##
## THE SAVE IS FORCED WITH A FULL SpecificAction - the Six Sky, this trait's gear and its hidden
## action_starsickness - because unit_hasecheck.gd:141-146 and :180-184 read the forcer only through a
## VALID specific: without an action the log names the source "?" and no Buff.TO.SAVE sees who forced
## it. Impaired is Stuncrown's own call (action_stuncrown.gd:28-31), sourced from this trait's gear.
extends Buff

const Agent := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/six_sky_agent.gd')

const ACTION_ID:StringName = &'action_starsickness'
const HEAT := 1
## Buff core state: every "<move event id>:<victim id>" this trait has already offered on.
const OFFERED_KEY := 'starsickness_offered'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if not Agent.is_teleport_by(unit, triggering_event): return false
	var victim:Unit = context.unit
	if not Unit.is_valid(victim) or not victim.is_character(): return false # "a hostile CHARACTER"
	if not UnitRelation.are_enemies(unit, victim): return false # "a HOSTILE character"
	return not core.state_has_id_in(OFFERED_KEY, stamp_for(triggering_event, victim))

static func stamp_for(move:EventCore, victim:Unit) -> StringName:
	return StringName('%s:%s' % [move.id, victim.core.persistent_id])

## Never calls super: Buff.activate would clear this trigger from the Six Sky.
func activate(core:BuffCore, activation:EventCore) -> void:
	var six_sky:Unit = activation.context.unit
	var move:EventCore = activation.context.event
	if move == null or move.context == null: return
	var victim:Unit = move.context.unit
	if not Unit.all_valid([six_sky, victim]): return

	var stamp := stamp_for(move, victim)
	if core.state_has_id_in(OFFERED_KEY, stamp): return
	core.append_to_array_state(OFFERED_KEY, String(stamp))

	var specific:SpecificAction = core.get_owner_specific(six_sky.map, ACTION_ID)
	if not SpecificAction.is_valid(specific): return

	# "It MAY take 1 Heat."
	var confirm_context := specific.to_context()
	confirm_context.event = activation
	if not await CommonActionUtil.confirm_use(confirm_context, [victim]): return
	if activation.abort_without_units([six_sky, victim]): return

	# "If it does" - the heat first, inline.
	await activation.execute_events([EventCore.create(&'event_unit_damage', {
		unit = six_sky,
		number = HEAT,
		category = Lancer.DAMAGE_TYPE.HEAT,
		flags = [EventService.DAMAGE_FLAG.SELF_INFLICTED, EventService.DAMAGE_FLAG.SKIP_CONSUMING_RESIST_BUFFS],
		target_unit = six_sky,
		gear = specific.gear,
		action = specific.action,
	})])
	if activation.abort_without_units([six_sky, victim]): return

	# "That character must succeed on a Systems save or become Impaired until the end of their next turn."
	var passed:bool = await UnitHasecheck.make_systems_save(activation, victim, specific, [Lancer.STATUS.IMPAIRED])
	if not Unit.is_valid(victim) or passed: return
	UnitCondition.apply_status(activation, victim, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.END_OF_NEXT_TURN, specific.gear.persistent_id)
