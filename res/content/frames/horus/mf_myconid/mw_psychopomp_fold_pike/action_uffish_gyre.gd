## UFFISH GYRE, the Psychopomp Fold Pike's reaction - and the only way the Pike ever attacks.
##
##   "Reaction, 1/round.
##    Trigger: An allied character within threat starts to move. This does not require line of sight
##             or a clear path between you and the target.
##    Effect:  Make a melee attack against evasion 8, on hit the allied character gains +2 armor
##             until the start of their next turn. This doesn't count against the maximum number of
##             reactions you can make in a turn."
##
## THE SEAM IS OVERWATCH'S, DELIBERATELY (design ruling 11). "Starts to move" is the tabletop wording
## of Overwatch's own trigger, so this file is content/gear/basic/ms_overwatch/action_overwatch.gd
## with the relation inverted and the weapon fixed: ENTIRE_MOVEMENT at PRE, the mover in
## context.unit, the MovementType in context.resource, and MovementType.is_contextual_move_reactable
## as the reactability test. event_unit_move.gd:71 fires that trigger before the move resolves and
## event_unit_move.gd:312-323 puts the mover's own MovementType on the event it hands us.
##
## WHAT "ANY REACTABLE MOVEMENT" TURNS OUT TO COVER - AND KNOCKBACK IS NOT IN IT.
## MovementType.ignores_reactions() (movement_type.gd:101-102) is
## `ignore_rxns or teleport or not voluntary`, so it excludes THREE things, not one:
##   - a move explicitly flagged to ignore reactions,
##   - a teleport, and
##   - ANY INVOLUNTARY MOVE, because `voluntary` is false on it.
## MovementType.create_for_involuntary (:63-71) sets ignore_rxns as well, and
## CommonActionUtil.generate_knockback_events (common_action_util.gd:117) builds its movement type
## from exactly that - so a knocked-back or pulled ally does NOT offer the Gyre. Design ruling 11's
## sentence "Boosts, standard moves, knockback and pulls all count" is wrong about the last two, and
## wrong about them in the same breath as it names the gate that excludes them; the GATE is the
## author's call and it stands. Measured, not reasoned: test_a_knocked_back_ally_does_not_offer sends
## a real knockback through and watches nothing happen, with a voluntary move beside it as the
## positive control. Rulings row 2026-09-16. Vanilla parity: Overwatch does not fire on forced
## movement either, which is the tabletop rule.
##
## NO LINE-OF-SIGHT TEST AND NO PATH TEST, and that is the card saying so outright rather than an
## omission. Draw Fire, the mod's other reaction of this shape, DOES ask UnitRelation.can_see
## (action_draw_fire.gd:155) because its card says "and line of sight"; this one says the opposite in
## as many words. The strike itself is off LOS too - see the .tres's
## requires_line_of_sight_baseline - because the card's sentence covers "you and the target", not
## just the trigger.
##
## THE THREAT IS READ OFF THE STRIKE, NEVER OFF A CONSTANT (strike_range() below). The card says
## "within threat", meaning this weapon's Threat, which is a number on the strike's .tres and which
## ActionAttackWeapon.threat_distance (action_attack_weapon.gd:187-191) lets a THREAT_RANGE buff
## widen. A literal 8 here would disagree with the weapon the moment either moved. Draw Fire's
## rail_range() (action_draw_fire.gd:102-106) is this mod's idiom and this is the same shape, minus
## its cross-Kit lookup: the Gyre and the strike are on ONE Kit, so the gear is our own.
##
## consumes_rxn = false IS THE CARD'S LAST SENTENCE, AND IT COSTS THE 1/ROUND. ActionReaction hands a
## non-consuming reaction a per-round hard limit of 99 (action_reaction.gd:69, keyed on
## requires_reaction_available()), so the override below is what puts the card's "1/round" back.
## SP1's probe recorded that the engine gate reads the ROUND counter and not the turn one
## (UnitAction.is_under_per_round_limit, unit_action.gd:170-175, reads gear.get_uses_this_round), so
## the spend_the_gyres_use() callable below is what feeds it - without that spend the limit is a
## limit on a counter nothing increments. Per design ruling 5 this "round" is really "since the Myconid's
## own last turn start", because UnitAction.reset_per_round_usage runs there; accepted for vanilla
## parity, as for Juggernaut Drive and Halo.
##
## AND IT ALSO OPENS THE can_be_used_while_* GATES, AND THE JAMMED ONE BESIDE THEM.
## action_reaction.gd:62-65 are the four can_be_used_while_* (dazed, stunned, uncharged, unloaded)
## and :66 is is_jammable(); all five derive from requires_reaction_available(), so a non-consuming
## reaction is usable while Stunned, Dazed, Jammed, unloaded and uncharged. That is not a loophole to
## be closed here: ruling 11 says a Stunned or Jammed Myconid cannot strike, and the refusal comes
## from the STRIKE's own re-validation inside choose_and_use - event_gear_activate.
## check_specific_context (content/events/event_gear_activate.gd:46-51) asks
## UnitAction.get_gear_unavailable_reason of the CHOSEN action and prints the reason in red.
##
## BOTH HALVES ARE TESTED RATHER THAN ASSERTED HERE, which is the brief's own instruction for a
## cross-seam claim. test_a_stunned_myconid_cannot_strike drives the Stunned one end to end;
## test_a_jammed_myconid_cannot_strike does the same for Jammed, where the asymmetry is two
## is_jammable() implementations - ActionAttack.is_jammable returns true (action_attack.gd:24) while
## this reaction's returns requires_reaction_available(), i.e. false (action_reaction.gd:66).
## UnitAction.is_action_jammable (unit_action.gd:573-576) asks each action for its own, and
## unit_action.gd:142 is the elif that turns "Jammed unit + jammable action" into REASON.JAMMED.
## Because nothing is spent unless the strike COMMITS (below), a Stunned or Jammed Myconid's Gyre
## costs it nothing either.
##
## SYMBIOSIS DOES NOT SEE THIS REACTION, WHICH IS THE POINT. buff_symbiosis's bookkeeping stamps the
## round's extra when a reaction POINT goes, and buff_symbiosis_exclusion's gate opens with
## action.consumes_reaction(). A non-consuming reaction spends no point and trips neither.
## test_symbiosis.test_a_non_consuming_reaction_is_neither_refused_nor_stamped proves the seam
## against a synthetic reaction; test_the_gyre_spends_no_reaction_point is its mirror against this
## one.
extends ActionReaction

## The strike lives on this same Kit, so both halves are reached off context.gear.
const STRIKE_ID := &'action_psychopomp_strike'

## Overwatch's pair (action_overwatch.gd:6-11): the MOVER in `unit`, its MovementType in `resource`.
## Without the MovementType the reactability test cannot be asked at all, so it is REQUIRED rather
## than defaulted - ActionReaction.check_required_triggering_context refuses the trigger outright
## when a listed property is missing (action_reaction.gd:83-87).
func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit,
		Context.PROP.resource, # MovementType
	]

## "1/round". Not inherited: ActionReaction gives a non-consuming reaction 99
## (action_reaction.gd:69). See the header.
func get_per_round_hard_limit(specific:SpecificAction) -> int: return 1

## The Pike's own strike action, or null if the Kit has been taken apart.
func strike_action(gear:GearCore) -> Action:
	return gear.get_action(STRIKE_ID) if GearCore.is_valid(gear) else null

## "within threat" - the STRIKE's Threat, buffs included, never a constant. See the header.
## Returns 0 when the strike is missing, which reads as "no reach, so no trigger".
func strike_range(unit:Unit, gear:GearCore) -> int:
	var strike:Action = strike_action(gear)
	if strike == null: return 0
	return strike.get_target_range(SpecificAction.create(unit, gear, strike))

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var triggering_context:Context = triggering_event.context
	var mover:Unit = triggering_context.unit
	if not Unit.is_valid(mover): return false

	# Invulnerable, intangible, exiled, off-map: the engine's own "can this unit reach that one at
	# all" test, and Overwatch's first line (action_overwatch.gd:15).
	if not UnitRelation.can_affect(unit, mover): return false

	# "An allied CHARACTER" - and never ourselves. Overwatch's are_allies test with the sense
	# inverted; the self clause is separate because are_allies(unit, unit) is TRUE
	# (Faction.is_ally of a faction against itself, faction.gd:30), so a Myconid taking its own
	# standard move would otherwise pike itself every turn.
	if mover == unit: return false
	if not UnitRelation.are_allies(unit, mover): return false
	if not mover.is_character(): return false

	# "starts to move" - reactable movement only, Overwatch's own test
	# (action_overwatch.gd:19). This is what excludes a teleport, a flagged no-reaction move and
	# every involuntary move including knockback; see the header.
	if not MovementType.is_contextual_move_reactable(triggering_context): return false

	# "within threat", read off the strike.
	if UnitRelation.distance_between(unit, mover) > strike_range(unit, gear): return false

	# Re-entrancy: the strike below is activated through choose_and_use, which locks THIS gear for
	# the duration (common_action_util.gd:750-752). Without this line a move the strike itself
	# provoked would offer the Gyre again from inside its own activation. Overwatch's last line
	# (action_overwatch.gd:23).
	return not CommonActionUtil.is_choose_and_use_with_gear_in_progress(gear)

## THE SPEND CALLABLE handed to choose_and_use, which runs it - through `deferred_spend` - at the
## moment the strike commits, and not at all if it never does. See activate()'s header.
##
## The three-argument signature is choose_and_use's own (common_action_util.gd:721-724); `using` is
## the shot and `chosen` is the shot again, so neither is needed. What matters is the FIRST argument:
## it is the GYRE's activation event, which is where Action.spend_actions reads its SpecificAction
## from (action.gd:144-147) - so this spends the reaction, never the weapon underneath it.
func spend_the_gyres_use(activation:EventCore, _using:SpecificAction, _chosen:SpecificAction) -> void:
	spend_actions(activation)

## "Make a melee attack against evasion 8."
##
## THE AWAITED choose_and_use, NOT choose_and_use_after_triggering_event, and the difference is not
## stylistic. The queued form walks UP the event chain looking for an ancestor of a given type -
## event_unit_attack_declared by default - and asserts when it finds none
## (common_action_util.gd:603-608). A movement event has no such ancestor, so Draw Fire's queued form
## would abort here. The awaited form also lets the wake/hibernate pair BRACKET the call, which the
## queued form structurally cannot: it returns immediately and the shot runs later.
##
## THE FOLLOW-UP IS BUILT ON THIS KIT'S OWN GEAR AND THE SHOT IS THE `using`. Draw Fire's header
## (action_draw_fire.gd:215-224) records what the alternative costs: passing the REACTION as `using`
## has it re-validated by can_activate_gear at execute time, where AS_FREEBIE skips only the
## per-turn and affordability checks and a spent 1/round hard limit still refuses - measured there as
## "specific: invalid" and no shot. This reaction is non-consuming, but its per-round limit is real
## (see the header) and would refuse the second half of its own activation once spend_actions has
## run. `using` is the shot.
##
## ONE MEASURED COST OF THAT CHOICE, RECORDED RATHER THAN CORRECTED: the strike is NOT flagged
## AS_RXN. common_action_util.gd:699 appends Action.FLAG.AS_RXN only when
## `using.action.requires_reaction_available()`, and our `using` is the SHOT - an ActionAttackWeapon,
## for which that is false. Overwatch passes its REACTION as `using` (action_overwatch.gd:34), so its
## shot does carry the flag. Four vanilla readers key on it: buff_sentinel.gd:11 and
## buff_superior_sentinel_archer.gd:11 give the ATTACKER +1 accuracy on a reaction shot, and
## buff_weave.gd:8 / buff_weave_hornet.gd:8 auto-miss one for the DEFENDER (both .tres carry
## applies_when_holder_is = 1, i.e. target). None can hurt us and the last two would HELP if they
## fired: the Pike deals no damage and its target is an ally, so an ally Weaving away this strike
## would only deny itself the armor. Not corrected, because the correction is to pass the reaction as
## `using` and buy back the re-validation above. (attack_preview.gd:121 and :141 set the same flag by
## hand for the UI's reaction preview and are unaffected.)
##
## NOTHING OF THE MYCONID'S ACTION ECONOMY IS SPENT BY THE STRIKE. The spend callable below spends
## the GYRE and only the Gyre; the Gyre fires off-turn, and a reaction that quietly ate the Myconid's
## next Quick would be a second cost the card never names. The Gyre's own spend costs nothing either:
## ActionReaction.get_action_type returns Lancer.ACTION.RXN, which prices it FREE, and
## consumes_rxn = false keeps UnitAction.spend away from spend_reaction (unit_action.gd:257). What it
## DOES do is increment the per-round counter (:279), which is the entire point.
##
## THE SPEND IS DEFERRED INTO THE STRIKE'S OWN COMMIT - the engine's own mechanism for exactly this
## question, and also what fixes the order the player sees. choose_and_use's 4th argument is wrapped
## in a `deferred_spend` and hung on the CHILD's event_gear_activate (common_action_util.gd:721-724,
## :746); event_gear_activate.gd:29 says what it is for in one line - "run a parent event's
## spend_actions() only when the child actually does". UnitAction.spend_actions_gain_heat runs it
## first thing (unit_action.gd:219), and ActionAttack calls spend_actions at action_attack.gd:262 -
## after the targeting plan and the friendly-fire confirm, BEFORE run_attack_effects (:265) and the
## declared/attack events (:268). Two things follow, and both are the requirement:
##   - NOTHING IS SPENT UNLESS THE STRIKE COMMITS - Draw Fire's principle
##     (action_draw_fire.gd:170-200), and here it is not theoretical. MEASURED 2026-09-16: the strike
##     opens TWO prompts, a compcon targeting plan and, because the target is an ALLY,
##     TargetActionUtil.confirm_friendly_fire's yes/no (action_attack.gd:247,
##     target_action_util.gd:430-435). Declining the second returns at :247, before :262, so the
##     callable never runs; nor does it on a Stunned or Jammed refusal, where the child aborts in
##     check_specific_context before execute() is reached at all.
##   - AND THE GYRE ANNOUNCES ITSELF BEFORE THE ROLL. spend_actions_gain_heat emits log_usage and
##     popcorn_usage at :233-234 of the same call that moved the counter at :225, with nothing
##     awaited in between - so the "Uffish Gyre triggered." battle-log line and the .tres's
##     emit_text_popcorn_on_use label both land before the attack roll instead of after it. That is
##     what the popcorn is FOR: this reaction fires on somebody else's turn, and a label arriving
##     after the roll would be announcing an attack the player had already watched.
## Pinned by test_the_gyre_announces_itself_before_the_roll (an ATTACK/PRE probe plus the ordered
## battle log) and by test_a_declined_friendly_fire_confirm_costs_nothing,
## test_a_stunned_myconid_cannot_strike and test_a_jammed_myconid_cannot_strike.
##
## REJECTED (this file's first shape, replaced at the SP2 Task 4 review, 2026-09-16): await
## choose_and_use, then spend if the strike's own usage counter moved. That gets the CONDITIONALITY
## right - it is the same read event_gear_activate.gd:76 and :103 use to decide whether gear was
## really used, and it is strictly better than choose_and_use's return value, which is
## SpecificAction.is_valid(chosen) (common_action_util.gd:763) and stays TRUE when the child aborted.
## But it is unconditionally LATE: the await does not return until the whole attack has resolved, so
## the popcorn and the battle-log line both arrived after the roll they were supposed to introduce,
## and the .tres's justification for the flag described an ordering the code did not produce. The
## deferred callable is conditional AND early, so nothing was traded away for it.
##
## THE WAKE/HIBERNATE BRACKET, AND WHY IT SURVIVES AN ABORT. The strike ships starts_hibernating, so
## it is refused everywhere - including here, because UnitAction.can_activate_gear checks
## is_gear_available BEFORE its `if as_freebie: return true` early-out (unit_action.gd:112-114) and
## the hibernation branch sits inside get_gear_unavailable_reason at :154. Waking it around the call
## is therefore mandatory, not decoration. The re-hibernate is UNCONDITIONAL and there is no `return`
## between the two lines: a cancelled prompt, an aborted activation or a refused re-validation all
## fall through to it, so the weapon can never be left awake on the gear bar. The one path that skips
## both is the early return above them, which happens before the wake.
func activate(context:Context, activation:EventCore) -> void:
	var gear:GearCore = context.gear
	var mover:Unit = context.event.context.unit
	var strike:Action = strike_action(gear)
	if strike == null or not Unit.is_valid(mover): return

	var shot := SpecificAction.create(context.unit, gear, strike)
	gear.wake_action(STRIKE_ID)
	await CommonActionUtil.choose_and_use(
		activation,
		shot,
		[shot],
		spend_the_gyres_use,
		mover,
		[Action.FLAG.CAN_FOLLOWUP],
	)
	gear.hibernate_action(STRIKE_ID)
