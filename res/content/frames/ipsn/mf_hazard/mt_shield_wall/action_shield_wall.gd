# SHIELD WALL (Hazard, mt_shield_wall), ruling 3:
#
#   "At the end of the Hazards turn, it may choose an adjacent allied character, they gain
#    OVERSHIELD equal to 1+GRIT."
#
# An END_TURN POST reaction on the trait Kit - the Balor's Regeneration shape. POST is queued after
# handle_ending_unit and every END_OF_THIS_TURN expiry (event_turn_end.gd:37, :46), so the shield is
# up for the coming enemy turns. consumes_rxn is false (the .tres): a trait, free of the reaction
# point, of Stunned and of Jammed (action_reaction.gd:57-58). The hard limit is 1 - the card fires
# once per end of turn anyway.
#
# "ADJACENT" TAKES HOUSE GUARD'S WIDENING (author's ruling; Contested seams): the candidates come
# from UnitRelation.adjacent_characters, the helper the talents mod overrides - so House Guard on the
# HAZARD widens who it can shield. spec/test_compat.gd pins it. "Allied character" is is_actor() (the
# mod-wide row): a drone or a deployable is not offered. can_affect as Halo's (EXILED, intangibility,
# INVULNERABLE, shards).
#
# "MAY": the unit picker's cancel grants nothing. THE AI PICKS WITHOUT A PROMPT: the adjacent ally
# with the least current Overshield, ties to the lowest HP.
#
# 1 + GRIT through the shared helper, ENGINE-MAX semantics (Overshield.grant): an ally already holding
# more keeps its own - Lancer's Overshield rule. A Grit-0 pilot still grants 1.
extends ActionReaction

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## The trait card's effect row says it all; the reaction never reaches the gear bar (Halo's shape).
func show_in_tooltip(_kit:Kit) -> bool: return false

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

## Adjacent allied characters the Hazard can reach, through the helper House Guard widens.
static func candidates(hazard:Unit) -> Array[Unit]:
	var allies:Array[Unit] = []
	if not Unit.is_valid(hazard): return allies
	for other:Unit in UnitRelation.adjacent_characters(hazard):
		if other == hazard or not Unit.is_valid(other): continue
		if not other.is_actor(): continue
		if not UnitRelation.are_allies(hazard, other): continue
		if not UnitRelation.can_affect(hazard, other): continue
		allies.append(other)
	return allies

## The AI's pick: least current Overshield, then lowest HP.
static func ai_pick(options:Array[Unit]) -> Unit:
	var best:Unit = null
	for other:Unit in options:
		if best == null:
			best = other
			continue
		var a:int = Overshield.current(other)
		var b:int = Overshield.current(best)
		if a < b or (a == b and other.core.current.health < best.core.current.health): best = other
	return best

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	if triggering_event.context.unit != unit: return false # the HAZARD's turn end
	return not candidates(unit).is_empty()

func activate(context:Context, activation:EventCore) -> void:
	var hazard:Unit = context.unit
	if not Unit.is_valid(hazard): return
	var options := candidates(hazard) # live, not the gate's snapshot
	if activation.abort_when(options.is_empty()): return

	var chosen:Unit
	if hazard.is_player_controlled():
		chosen = await choice_bus.choose_unit(options, true, SpecificAction.from_context(context))
	else:
		chosen = ai_pick(options)
	if not Unit.is_valid(chosen): return # declined: nothing spent
	if activation.abort_without_unit(hazard): return

	spend_actions(activation)
	await Overshield.grant(activation, chosen, 1 + Overshield.grit(hazard))
