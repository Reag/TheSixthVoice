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
## SINCE 2026-09-17 THE FADE HAS A SECOND DOOR (reach design ruling B). Abjuration of Metal calls
## fade() directly when its own cone came back empty or the player cancelled the pick - a teleport the
## mech was entitled to and could not take. The card's "if the Maiden's Blush would teleport, it
## INSTEAD may become Invisible" is what licenses it, both doors share this trait's one round, and the
## rules live here rather than in the caller.
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
	await fade(activation, unit, context.gear, triggering)

## THE FADE ITSELF, AND THE ONLY IMPLEMENTATION OF IT (reach design ruling B, 2026-09-17). Confirm,
## spend the round, veto the move when there is one, apply Invisible, log. Returns true when the mech
## faded.
##
## `triggering` IS OPTIONAL BECAUSE THE SECOND CALLER HAS NO MOVE TO VETO. Abjuration of Metal offers
## the fade as a CONSOLATION when its cone came back empty or the player cancelled the pick - there is
## no event_unit_move in either case and nothing to abort. Everything else about the fade is the same,
## which is the whole reason this is one function: the rules belong to the trait whose card they are
## on, not to the trait that happens to be asking. The rejected alternative was to have Abjuration
## raise a synthetic event for this reaction to intercept - it preserves the trigger shape and the
## engine's accounting for free, but needs a new event type or a degenerate zero-step move, leaves the
## veto path with nothing to abort, and lies to the engine about a move having happened.
##
## `consolation` NAMES THE EXIT for that caller (&'no_space' or &'cancelled') and is EMPTY for the
## trait's own interception. It selects the prompt and the log row and nothing else: ruling 154
## settled that the interception prompt does not name its destination, because the player had just
## picked one, and the consolation fires precisely when there is no destination to name. Two strings,
## one decision each.
##
## THE ROUND IS THE ENGINE'S, AND IT IS ASKED THE ENGINE'S WAY IN BOTH DIRECTIONS. This is the one
## thing here that could ship looking correct and be wrong. On the trait's own path the engine already
## refuses a second offer inside ReactionBus.does_reaction_trigger (via UnitAction.can_activate_gear),
## so re-asking below changes nothing. A DIRECT call from another action gets no such gate, and a
## plain spend_actions(activation) would bill ABJURATION's gear and usage group rather than this one -
## so the round would be free every second time, and a player could fade twice. Hence both lines name
## THIS trait's own SpecificAction: can_activate_gear reads the per-round hard limit
## (unit_action.gd:171, get_gear_unavailable_reason's PER_ROUND arm), and spend_actions_gain_heat
## increments uses_this_round under this action's own usage_group (&'uncertainty_field',
## gear_core.gd:170-177). spec/test_uncertainty_field.gd's
## test_a_consolation_fade_spends_the_round_the_interception_would_have_used and
## test_a_spent_round_refuses_the_consolation_too press both directions, and are the mutations that
## prove it.
##
## THE FLAGS COME OFF THE ACTIVATION, which keeps the trait's own path byte for byte what it was:
## Action.spend_actions(activation) is exactly UnitAction.spend_actions_gain_heat(
## SpecificAction.from_context(activation.context), activation, activation.context.flags), and on that
## path the context's specific IS this one.
func fade(activation:EventCore, unit:Unit, gear:GearCore, triggering:EventCore, consolation:StringName = &'') -> bool:
	if not Unit.is_valid(unit): return false
	if not GearCore.is_valid(gear): return false
	var specific := SpecificAction.create(unit, gear, self)
	if not UnitAction.can_activate_gear(specific): return false

	# THE OFFER. There is no engine-level reaction prompt - ReactionBus queues the activation and asks
	# nobody (reaction_bus.gd:52-58) - so this call IS the offer, exactly as it is for Flash Anchor
	# (action_flash_lock.gd:56).
	#
	# DECLINING RETURNS BEFORE THE SPEND, which is what leaves the round unspent and the teleport
	# untouched, and is what lets a player hold the round's fade for a teleport they mind losing.
	var confirmed:bool = await ask_to_fade(specific, gear, consolation, activation)
	if not confirmed: return false
	if activation.abort_without_unit(unit): return false

	# A MECH THAT CANNOT BECOME INVISIBLE STILL PAYS FOR THE FADE AND STILL GETS NOTHING, AND THAT IS
	# THE AUTHOR'S RULING (2026-09-17) RATHER THAN AN OVERSIGHT. The order below is spend, veto, apply,
	# and UnitCondition.apply_status returns before it applies anything when the unit is immune to the
	# status (unit_condition.gd:93-99) - so on an immune Blush the round is spent, the teleport is
	# cancelled, and no Invisible lands. The engine is loud about it and self-contradictory:
	# apply_status floats its own "immune to Invisible" popcorn and logs it, and the lines below then
	# log that the mech faded. Accepting is strictly worse than declining, and the player is not
	# warned.
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
	UnitAction.spend_actions_gain_heat(specific, activation, activation.context.flags)

	# NOTHING TO ABORT ON THE CONSOLATION PATH, and that is the whole of what `triggering == null` means
	# here. Teleport.veto takes the TRIGGERING core, never the activation: vetoing the activation would
	# abort our own reaction and leave the teleport untouched.
	if triggering != null: Teleport.veto(triggering)

	UnitCondition.apply_status(
		activation, unit,
		Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN,
		gear.persistent_id
	)

	# THE LITERAL KEY, not Translate.action(): battle_log.log_unit takes a translation KEY and calls
	# tr() on it itself (battle_log_bus.gd:24-33), which is how buff_symbiosis_exclusion.gd:118 passes
	# one. Handing it translated text only works because a missed lookup returns its input unchanged.
	# The popcorn below is different: effect_bus.play_text takes TEXT, so Translate.action is right
	# there - and it is the SAME popcorn on both paths, because a fade is a fade whichever door it came
	# through.
	if consolation.is_empty():
		battle_log.log_unit(
			&'gear.mt_uncertainty_field.action_uncertainty_field.replaced.log', unit,
			{source = replaced_name(triggering)}
		)
	else:
		battle_log.log_unit(
			StringName('gear.mt_uncertainty_field.action_uncertainty_field.consolation.%s.log' % consolation),
			unit
		)
	effect_bus.play_text(Translate.action(gear.kit, self, 'replaced.pop'), unit.tile())
	return true

## The offer, and there are two of them (reach design ruling B, 2026-09-17).
##
## THE INTERCEPTION KEEPS CommonActionUtil.confirm_use(activation.context) BYTE FOR BYTE, because on
## that path the activation's context IS this trait's own - so the AI branch, the telegraph timing and
## the context flags all still reach the engine exactly as they did before the extraction.
##
## THE CONSOLATION CANNOT USE IT, and that is ruling B's own condition rather than a convenience.
## confirm_use titles its prompt with battle.confirm.use and the action name and carries no
## description at all (common_action_util.gd:362-371), which on an empty cone reads as "use the
## Uncertainty Field?" about a teleport the player just watched fail to exist. Ruling 154's premise -
## that the player has just chosen a destination - is exactly what is false here, so this branch opens
## its own prompt with its own row saying which dead end it was.
##
## A NON-PLAYER MECH GOES THROUGH CommonActionUtil.confirm_use ITSELF, not a bare ai_confirms_use
## call, because confirm_use's own AI branch does one more thing than return the verdict: when
## specific.action.ai_telegraphs_action(specific) is TARGET it also awaits
## choice_bus.telegraph_ability(...) (common_action_util.gd:296-310, the confirm_use body). This
## trait's .tres sets no ai_telegraph_timing, so ai_telegraphs_action defaults to TARGET
## (action_reaction.gd:116-119) - the interception telegraphs, and a hand-rolled ai_confirms_use call
## here would silently not. Routing through confirm_use keeps that telegraph, as well as the verdict
## (the base ai_confirms_use already returns true unconditionally), identical on both paths. The
## context passed is specific.to_context(), this trait's own, rather than activation.context: on the
## consolation path activation belongs to Abjuration, and a reaction activation carries no flags for
## it to lose regardless (reaction_bus.gd queues one with no flags key). Diverging here would make the
## consolation the one offer an AI never accepts, for no reason on the card.
func ask_to_fade(specific:SpecificAction, gear:GearCore, consolation:StringName, activation:EventCore) -> bool:
	if consolation.is_empty(): return await CommonActionUtil.confirm_use(activation.context)
	if not specific.unit.is_player_controlled(): return await CommonActionUtil.confirm_use(specific.to_context())
	return await choice_bus.quick_yesno_for({
		tile = specific.unit.tile(),
		title = name(specific),
		description = Translate.action(gear.kit, self, 'consolation.%s.confirm' % consolation),
		whois = specific.unit,
	})

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
