## UNCERTAINTY FIELD: the Maiden's Blush refuses a teleport and fades instead.
##
##   "1/round if the Maiden's Blush would teleport, it instead may become Invisible until the
##    beginning of its next turn."
##
## THE SEAM (design §0.1, spike 5). Every teleport in the engine is ONE event_unit_move whose
## context.resource is a MovementType with teleport = true, and ENTIRE_MOVEMENT / PRE fires at
## event_unit_move.gd:71 on the REAL core for the mover, before undergo_move at :113; :72 then returns
## on a listener's set_aborted(). Flash Anchor (action_flash_lock.gd) is vanilla's user of that exact
## veto; the Operator's Strike and Fade (action_strike_and_fade_operator.gd) is vanilla's
## ActionReactionSelf listening for its OWN teleport at the same trigger. This trait is both at once,
## which is why it is a reaction rather than the buff the spike probe used: the engine then supplies
## the 1/round counter, the confirm, the battle-log line and the tooltip handling for free.
##
## THE OFFER COMES AFTER THE DESTINATION IS CHOSEN (ruling 1), and the prompt does not name it: on
## every teleport the field offers on, the player either just picked the space or an enemy is forcing
## it. There is no earlier universal hook - nothing in the engine runs before the destination pick.
##
## WHICH TELEPORTS (ruling 3, the author's call, SUPERSEDING the spike's proposed "own voluntary
## only"):
##   - the mech's own VOLUNTARY teleports - Abjuration, a Fold Knife crit, a Prospector tunnel, any
##     teleport gear it carries;
##   - Step of Mist and Thunder's own-but-INVOLUNTARY teleport (design §0.8), recognised by
##     Teleport.is_own. SP2 builds Step; this clause is what lets the field still offer on it, and
##     ruling 4 says it may (a player who fades has already spent the core point and the quick
##     action, and no adjacent character saves);
##   - a HOSTILE FORCED teleport: involuntary, not NO_RXNS, with a forcer that is an enemy.
## Never a scripted placement - event_unit_teleport sets NO_RXNS unconditionally (:31) - and never an
## involuntary teleport with no readable forcer, which is Flash Anchor's own prompt-spam guard
## (action_flash_lock.gd:42).
##
## resource.ignore_rxns IS DELIBERATELY NOT CONSULTED, as Flash Anchor does not consult it:
## MovementType.create_for_involuntary sets it on EVERY forced move (movement_type.gd:65), so it says
## nothing about the source.
##
## EXTENDS ActionReactionSelf and CALLS SUPER in the gate. The archetype's whole body is
## `triggering_context.unit != unit` (action_reaction_self.gd:11-15); every other clause below is
## ours. The required props are widened to [unit, resource] exactly as Strike and Fade widens them
## for this trigger.
##
## THE 1/ROUND IS THE ENGINE'S. get_per_round_hard_limit is overridden because ActionReaction returns
## 99 for a reaction that consumes no reaction point (action_reaction.gd:69); the limit is consulted
## inside ReactionBus.does_reaction_trigger via can_activate_gear, so a second field in a round is
## never OFFERED rather than offered and refused. It clears at the Blush's OWN turn start - per turn
## in truth, accepted for vanilla parity (the Myconid's ruling 5).
extends ActionReactionSelf

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

## The mover and the MovementType that says what kind of move it is. Both are dereferenced below and
## both are present on every real event_unit_move; the same pair Strike and Fade requires
## (action_strike_and_fade_operator.gd:10-11).
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.resource]

## ActionReaction returns 99 for a reaction that consumes no reaction point. The card says 1/round.
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var context:Context = triggering_event.context
	if not Teleport.is_teleport(context): return false
	# A scripted placement asks not to be reacted to. Honouring that is the whole difference between
	# "an enemy is moving me" and "the mission is moving me" (ruling 3).
	if context.flags.has(EventUnitMove.FLAG.NO_RXNS): return false
	# Ours, either way round.
	if context.resource.voluntary: return true
	if Teleport.is_own(context.resource): return true
	# Or somebody else's, with a readable and hostile forcer.
	var forcer:Unit = Teleport.forcer(context)
	if not Unit.is_valid(forcer): return false
	return UnitRelation.are_enemies(unit, forcer)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	var triggering:EventCore = context.event
	if not is_instance_valid(triggering): return

	# THE OFFER. There is no engine-level reaction prompt - ReactionBus queues the activation and asks
	# nobody (reaction_bus.gd:52-58) - so this call IS the offer, exactly as it is for Flash Anchor
	# (action_flash_lock.gd:56). It opens one quick_yesno_for and nothing else.
	#
	# DECLINING RETURNS BEFORE spend_actions, which is what leaves the round unspent and the teleport
	# untouched, and is what lets a player hold the round's fade for a teleport they mind losing.
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if not confirmed: return
	if activation.abort_without_unit(unit): return

	# A MECH THAT CANNOT BECOME INVISIBLE STILL PAYS FOR THE FADE AND STILL GETS NOTHING, AND THAT IS
	# THE AUTHOR'S RULING (2026-09-17) RATHER THAN AN OVERSIGHT. The order below is spend, veto, apply,
	# and UnitCondition.apply_status returns before it applies anything when the unit is immune to the
	# status (unit_condition.gd:93-99) - so on an immune Blush the round is spent, the teleport is
	# cancelled, and no Invisible lands. The engine is loud about it and self-contradictory: apply_status
	# floats its own "immune to Invisible" popcorn and logs it, and the lines below then log that the
	# mech faded. Accepting is strictly worse than declining, and the player is not warned.
	#
	# The rule the trait implements is that the fade is offered on a qualifying teleport and costs the
	# round once accepted - with no condition on whether the mech can hold the status. So there is no
	# immunity clause in triggers_on_event, no re-ordering here, and a future session that adds either
	# is changing the trait, not fixing it.
	#
	# THIS IS REACHABLE, NOT THEORETICAL, which is why it is written down rather than left as an
	# accident of the ordering. Two ordinary vanilla NPC features hand a player mech immunity to
	# Invisible: the Scout's Rebound Scan (buff_rebound_scan.tres, a BuffStatusImmunity over
	# [hidden, invisible], applied on hit to every enemy within 3 of its target, and whose AI scorer
	# hunts Invisible units on purpose) and the Bombard's Flare Drone aura
	# (buff_flare_drone_bombard.tres, hung by the PassiveAura on mt_flare_drone_bombard.tres at range 2
	# in LOS, applies_to_enemies). The SSC Athena-class NHP's simulacrum is a third.
	# spec/test_uncertainty_field.gd's test_an_immune_blush_still_pays_for_a_fade_that_grants_nothing
	# pins the behaviour, so the guard cannot be added back in silence.
	spend_actions(activation) # the per-round counter; consumes_rxn = false, so no reaction point

	Teleport.veto(triggering)
	UnitCondition.apply_status(
		activation, unit,
		Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN,
		context.gear.persistent_id
	)

	# THE LITERAL KEY, not Translate.action(): battle_log.log_unit takes a translation KEY and calls
	# tr() on it itself (battle_log_bus.gd:24-33), which is how buff_symbiosis_exclusion.gd:118 passes
	# one. Handing it translated text only works because a missed lookup returns its input unchanged.
	# The popcorn below is different: effect_bus.play_text takes TEXT, so Translate.action is right there.
	battle_log.log_unit(
		&'gear.mt_uncertainty_field.action_uncertainty_field.replaced.log', unit,
		{source = replaced_name(triggering)}
	)
	effect_bus.play_text(Translate.action(context.gear.kit, self, 'replaced.pop'), unit.tile())

## What the fade replaced, for the log line: the name of the action that forced the teleport when one
## is readable, and the glossary's own word for a teleport when it is not.
##
## SpecificAction.is_valid here, NOT has_valid_unit as Teleport.forcer uses - this needs the ACTION,
## and a mover specific built with null gear and null action has none.
##
## THE FALL-BACK IS THE COMMON CASE IN SP1. Blinkspace Jump passes no SpecificAction to
## Pathfinder.generate_events (action_blinkspace_jump.gd:64) and event_unit_teleport sets no `object`
## at all, so the mech's own teleports name nothing today. SP2's Step of Mist and Thunder passes its
## own specific through Teleport.move, which is what makes "Step by name when it was Step" true.
func replaced_name(triggering:EventCore) -> String:
	var source = triggering.context.object
	if SpecificAction.is_valid(source): return source.action.name(source)
	return X.tr('lancer.term.teleport')
