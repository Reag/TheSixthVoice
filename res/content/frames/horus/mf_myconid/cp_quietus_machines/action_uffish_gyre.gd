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
## SYMBIOSIS DOES NOT SEE THIS REACTION'S POINT COST, BECAUSE IT HAS NONE - AND THAT WAS A BUG UNTIL
## SP2.5 TASK 1. buff_symbiosis's bookkeeping stamps the round's extra when a reaction POINT goes, and
## buff_symbiosis_exclusion's gate opens with action.consumes_reaction(); a non-consuming reaction
## spends no point and trips neither, which is still true and still correct.
## test_symbiosis.test_a_non_consuming_reaction_is_neither_refused_nor_stamped proves that seam
## against a synthetic reaction; test_the_gyre_spends_no_reaction_point is its mirror against this one.
##
## WHAT WAS WRONG was concluding from that that Symbiosis had nothing to say here. The trait's card
## says "may use a reaction an additional time", and this IS a reaction - so the additional time has
## to come from somewhere, and for a non-consuming one the only thing standing in the way is the
## per-round limit below. The author hit it in play: an ally moved and the Gyre fired, a second ally
## moved in the same round and NOTHING happened, with no battle-log line and no refusal, because the
## limit is consulted inside ReactionBus.does_reaction_trigger and the reaction was never collected.
## buff_symbiosis_extra_use.gd now adds +1 to that cap through Buff.TO.ACTION_PER_ROUND while the
## round's extra is unspent, and taking the second Gyre is what spends it. Nothing in THIS file
## changed for it, and nothing should: the relief arrives through the engine's own channel, so the
## number below is still this reaction's own limit and still the thing a mutation reddens.
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
## after the targeting at :235 and the two confirms at :247 and :249 (the confirms this reaction
## skips; the targeting it now deliberately does not - see the flag block below), BEFORE
## run_attack_effects (:265) and the declared/attack events (:268). Two things follow, and both are
## the requirement:
##   - NOTHING IS SPENT UNLESS THE STRIKE COMMITS - Draw Fire's principle
##     (action_draw_fire.gd:170-200), and here it is not theoretical. It has guarded three paths,
##     then one, and now two, and the count is the history of this file rather than a moving target.
##     MEASURED 2026-09-16: the strike opened TWO prompts, a compcon targeting plan and, because the
##     target is an ALLY, TargetActionUtil.confirm_friendly_fire's yes/no (action_attack.gd:247,
##     target_action_util.gd:430-435); declining either returned before :262, so the callable never
##     ran. SP2.5 Task 2 suppressed BOTH, leaving the refusals as the callable's only job. The
##     TWO-STAGE FLAG (below) has since given the TARGETING SCREEN back - and that screen is not a
##     side effect, it is the back-out this reaction had no other way to offer. So the callable now
##     guards two live paths, and the second is the one the change depends on:
##       - THE REFUSALS. A Stunned or Jammed strike aborts in event_gear_activate.
##         check_specific_context (content/events/event_gear_activate.gd:46-51) before execute() is
##         reached at all, so it never gets near action_attack.gd:262 and a Myconid that could not
##         strike has not used its reaction.
##       - THE CANCEL. A cancelled targeting screen returns at action_attack.gd:144
##         (abort_without_targeting_plan), earlier still, so the round's use survives for whoever
##         moves next. WITHOUT the conditional spend this change would not work at all: an
##         unconditional spend would charge the Gyre for the shot the player just backed out of,
##         which is the exact cost the back-out exists to avoid.
##     The spend must therefore NOT be simplified back into an unconditional one - the reason is
##     stronger now than it was when the confirm was the thing being argued about.
##   - AND THE GYRE ANNOUNCES ITSELF BEFORE THE ROLL. spend_actions_gain_heat emits log_usage and
##     popcorn_usage at :233-234 of the same call that moved the counter at :225, with nothing
##     awaited in between - so the "Uffish Gyre triggered." battle-log line and the .tres's
##     emit_text_popcorn_on_use label both land before the attack roll instead of after it. That is
##     what the popcorn is FOR: this reaction fires on somebody else's turn, and a label arriving
##     after the roll would be announcing an attack the player had already watched.
## Pinned by test_the_gyre_announces_itself_before_the_roll (an ATTACK/PRE probe plus the ordered
## battle log) and by test_the_conditional_spend_guards_the_refusal,
## test_cancelling_the_targeting_screen_spends_nothing_and_saves_the_gyre,
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
## NO CONFIRM, BUT YES TARGET PICKER: Action.FLAG.SKIP_PLAYER_DECISIONS, IN TWO STAGES.
##
## SP2.5 TASK 2'S RULING STANDS, AND IT IS WHY THE CONFIRM IS STILL GONE. The author playtested
## SP2's head and reported the Gyre asking "you are about to attack an ally, are you sure?" on EVERY
## trigger - and a reaction fires on somebody else's turn, so the prompt interrupts a turn the
## player is only watching, to ask about an attack whose entire effect is to GIVE that ally armor.
## That reasoning has not changed and the warning has not come back.
##
## WHAT CHANGED IS THE CONCLUSION DRAWN FROM IT: "the card names no decision, so there is none to
## make" was true about the CARD and false about the ACTION ECONOMY. The Gyre is 1/round (2 with
## Symbiosis), it fires automatically on the first ally to move in threat, and until this change the
## player had no way to decline - so a Myconid watching its wounded line could spend the round's use
## on whoever happened to step first. THAT is the decision, and the author identified it in play.
## The targeting screen is the only place the engine offers to make it: vanilla Overwatch's back-out
## is the same screen, so this is Overwatch's seam again rather than a new mechanism (design ruling
## 11's shape throughout this file). Cancelling it costs nothing, because the spend is deferred into
## the strike's own commit - see the deferred-spend block above, which is what makes the back-out
## free rather than merely possible.
##
## THE FLAG IS NO LONGER PASSED FROM HERE. It gates both things, so one flag could not answer both
## questions from one place - but it is READ AT TWO DIFFERENT MOMENTS of one activation, and that is
## the seam this exploits. activate() below passes CAN_FOLLOWUP alone; the STRIKE's own
## get_attack_plan override (action_psychopomp_strike.gd, which carries the full account) appends
## SKIP_PLAYER_DECISIONS the instant the screen has returned, so the flag is ABSENT for
## target_action_util.gd:150 and PRESENT for :433 and :440. Pinned from the outside by
## test_the_flag_is_absent_for_the_screen_and_present_for_the_confirm.
##
## ONE MEASURED CONSEQUENCE OF PUTTING THE OVERRIDE ON THE STRIKE RATHER THAN HERE: the strike can
## no longer raise a friendly-fire warning by ANY route, a direct press from the gear bar included,
## because the override does not care who woke it. That is invisible in play - starts_hibernating
## means the Gyre is the only thing that ever wakes it (see the bracket block below) - but it did
## cost the spec its old control, which was exactly that direct press. The replacement control is a
## vanilla rifle; the test's header records the whole measurement.
##
## THE SEAM FOR THE CONFIRM IS A SINGLE EARLY RETURN. TargetActionUtil.confirm_friendly_fire tests
## the flag at target_action_util.gd:433, one line below the CONTROLLED_BY_OPPONENT test at :432,
## and returns true without ever reaching choice_bus.quick_yesno at :435. The flag reaches it on the
## CHILD's context, which is the same Context object the strike's override mutated: choose_and_use
## builds a fresh action_flags array (common_action_util.gd:693-710, copying
## additional_action_flags in at :697) and hangs it on the event_gear_activate it builds (:744),
## event_gear_activate hands that context to activate() (:80, or :89-91 composed), and
## ActionAttack.get_attack_plan reads it straight back out as `activation.context`
## (action_attack.gd:132) before passing it to the targeting (:141).
##
## THE SAME READ HAS A TWIN, ON THE SAME CALL SITE, AND THE EARLIER CUT OF THIS HEADER MISSED IT.
## TargetActionUtil.confirm_aoe_no_targets tests the flag identically at target_action_util.gd:440,
## and action_attack.gd:247/:249 is an if/elif chain, so confirm_aoe_no_targets always runs right
## after confirm_friendly_fire returns without aborting - which the re-appended flag guarantees it
## does, exactly as the passed-from-here flag used to. It is BEHAVIOURALLY INERT here regardless:
## :441 returns true the moment all_attacked_units is non-empty, and the Gyre always hands the
## strike a mandatory target_unit, so the twin would have returned true unflagged too. That is also
## why the two-stage arrangement did not have to think about it: whichever way the flag falls at
## :440, the answer is the same. Recorded because it IS on this path and a "checked rather than
## assumed" claim has to say so, not because it changes anything.
##
## THE COMPCON TARGET PICKER IS THE BACK-OUT, AND IT IS THE POINT OF THIS ARRANGEMENT. This
## paragraph said the opposite until now, and the sentence it turned on - "the Gyre has exactly ONE
## legal target... so the picker was a click with no alternative" - IS WITHDRAWN. The click does
## have an alternative: cancel. It is the same click either way, and what the player gets for it is
## the round's use back. Counting the legal targets was the wrong question; the question is what the
## player is choosing BETWEEN, and it is not which ally to pike, it is whether to pike at all.
##
## THE MECHANISM, unchanged, read the other way round. target_action_util.gd:150 reads the flag into
## skip_player_decision and :162 turns player_decides off, which routes the strike to the "use these
## supplied tiles/units automatically" branch at :230-242 instead of choice_bus.choose_compcon_plan
## at :200. With the flag absent at :150 the strike now takes :200, and :201 turns a null or aborted
## plan into CompconPlan.create_aborted() - which action_attack.gd:144 aborts the activation on,
## before the spend at :262. Action.FLAG.SKIP_PLAYER_DECISIONS' own declaration (action.gd:11:
## "auto-choose targets without player input") describes what we no longer want for the first read
## and still want for the two after it.
##
## AND THE ONE THING GIVEN UP WITH IT, recorded rather than quietly dropped: :233-234 of the
## supplied-target branch turned the Myconid to face its target, and that line no longer runs. The
## interactive picker has a set_facing of its own (ui/choice_controller/compcon/tilepicker_compcon.
## gd:161), so in real play the facing is likely still set from there - LIKELY, not measured: that
## is UI code no spec in this suite exercises, and it is stated here as the open question it is
## rather than as a replacement guarantee. Cosmetic either way; flagged for the author.
##
## DO NOT ADD Action.FLAG.CONTROLLED_BY_OPPONENT, which is the other half of the Enkidu's pair
## (.bk/gavstarb-ha_alts_1st_party .../mt_primal_fury/action_primal_fury_enter_threat.gd:37 - a
## read-only quarantine, read and never edited). The Enkidu's Primal Fury FORCES a mech to attack,
## so its shot is authored as the opponent's; the Gyre is the Myconid's own optional reaction and
## must stay attributed to the player. Two measured reasons, not one aesthetic one:
##   - THE ENGINE'S OWN RULE FOR ADDING IT DOES NOT HOLD HERE. choose_and_use appends the flag by
##     itself at common_action_util.gd:701, and only `if UnitRelation.are_enemies(acting_unit,
##     chosen.unit)`. Our acting unit and our target are ALLIES - that is the entire reason a
##     friendly-fire confirm was raised in the first place - so the engine would never add it, and
##     action.gd:12 calls it what it is: "Pred/prey concepts, pred logic".
##   - AND IT IS NOT A SECOND SPELLING OF THE SUPPRESSION - which now matters MORE THAN IT DID, and
##     this bullet is sharper for it rather than merely still true. Its three live readers are
##     target_action_util.gd:432, :439 and :152 -> :161. The first two would indeed skip the two
##     confirms, but :161 INVERTS player_decides where :162 CLEARS it. The earlier cut of this
##     bullet said the difference was invisible on a player Myconid because both landed in the same
##     supplied-target branch; that WAS true while this reaction passed SKIP_PLAYER_DECISIONS from
##     here, and it is now FALSE. A player Myconid no longer takes the supplied-target branch at
##     all - it takes the picker at :200, which is the whole back-out. Adding
##     CONTROLLED_BY_OPPONENT would invert player_decides to false and route it straight back into
##     :230-242, silently deleting the back-out this change exists to provide, while the two-stage
##     flag went to some trouble to keep it. On an NPC Myconid the inversion is worse still and in
##     the other direction - it would hand an AI-controlled Gyre's targeting to the human player.
##     SKIP_PLAYER_DECISIONS cannot do either, because :162 only ever turns the flag off.
##
## THE THIRD READER THIS FLAG REACHED, AND NO LONGER DOES FOR A PLAYER MYCONID - the one reader the
## two-stage arrangement cannot reach at all, because it fires BEFORE activate() is entered.
## event_gear_activate.gd:82-89 treats the flag exactly like "not player controlled" and composes
## the DEFAULT variant of any VariantActionGroup instead of opening the variant menu, via
## get_chosen_variant_for_group taking index 0 (variant_action_group.gd:192) against an empty
## override dictionary (:88). That read happens at :84-85, before the branch that calls activate()
## at :80/:91 - so the strike's get_attack_plan override, which runs INSIDE activate(), is far too
## late to influence it and could never have been used to. With the flag no longer passed from here,
## a player Myconid sees a variant MENU where it used to get the composed default; an NPC Myconid is
## unaffected, since :84 already answers "not player controlled" on its own. The mod ships no variant
## buffs, but eighteen vanilla .tres files declare variant_actions (Lunge, Sledgehammer, Throughbolt
## Rounds, Grapple Cable...) and a pilot could carry one.
##
## THE SURVEY BELOW IS WHAT MAKES THAT OF NO PRACTICAL CONSEQUENCE, and it is kept for exactly that
## reason rather than out of sentiment: its conclusion is that NOTHING IN THE TREE reaches
## action_psychopomp_strike with a VariantActionGroup at all. If that holds, variant_actions is
## empty for this action, event_gear_activate takes the `variant_actions.is_empty()` branch at :79-80
## and neither :82-89 nor the menu at :94 is reached whatever the flag says - so the paragraph above
## describes a door that is real, newly unlocked, and opens onto nothing. It is written out in full
## anyway because the day a mod-on-mod puts a group on this strike is the day the difference becomes
## visible, and the reader will want the reasoning rather than the verdict.
##
## "INDEX 0 IS THE CONSERVATIVE UNMODIFIED DEFAULT" IS NOT TRUE OF EVERY GROUP, AND AN EARLIER CUT
## OF THIS HEADER SAID IT WAS WITHOUT CHECKING. A blankable group inserts UNMODIFIED at index 0
## (variant_action_group.gd:76-83, is_blankable defaults true at :17) - but is_blankable is a
## per-group flag set by whoever builds the group, not a constant, and two of the four named
## examples above pass can_be_blank = false to VariantActionGroup.create (signature :26-33):
## buff_sledgehammer.gd:20 and buff_grapple_cable.gd:18. For a non-blankable group index 0 IS the
## variant, applied unasked, and merge (:43-54) keeps a merged group non-blankable if either half is
## (:49), so a second buff cannot blank one back.
##
## THE CONCLUSION SURVIVES ANYWAY, BUT FOR A DIFFERENT REASON, WHICH IS WHAT HAS TO BE WRITTEN HERE
## INSTEAD. Neither of those two groups can reach this strike: buff_sledgehammer.gd:12 filters to
## context.action.get_id() == &'action_improvised_attack' and buff_grapple_cable.gd:9 to
## &'action_grapple', and ours is action_psychopomp_strike. That leaves the other two named
## examples and the rest of the eighteen unaccounted for, so every VariantActionGroup.create call in
## the base game was surveyed for a broader hazard, not just the two reader-3 originally cited: 23
## call sites under content/, found by grepping for the call, plus engine's own single use for the
## THROWN tag (action_attack_weapon.gd:353-375). Every OTHER non-blankable group in the tree is
## gated exactly as narrowly: to one action id (buff_siege_ram.gd:17 -> action_ram) or one kit id
## (buff_tear_down_witch.gd:10-13 -> ms_stabilize / npcf_stabilize), or is a BuffWeaponType
## conversion additionally gated by a status (buff_limit_break_convert_damage.gd:6-9, EXPOSED;
## buff_fusion_hemorrhage_convert_damage.gd:7-12, DANGERZONE) that only rewrites KINETIC or
## EXPLOSIVE damage_type (:26 and :29 respectively) - and the Pike's strike declares no damage_dice
## at all (action_psychopomp_strike.tres:26), so even an unfiltered damage-type conversion would
## have nothing to convert. The Pike is also not THROWN, so the engine's own non-blankable-looking
## group (action_attack_weapon.gd:353-375) never builds for it at all - and that one is blankable
## regardless, the THROWN tag gate is what keeps it off, not is_blankable. No non-blankable group in
## the tree applies to an arbitrary melee weapon with no id filter, so a player Myconid gets the
## plain strike on THIS action specifically whatever the flag does - the same verdict as before,
## reached by the same survey, and the reason the flag's departure costs nothing here. (The sentence
## this replaced said the Myconid "still loses the variant menu"; that framing belonged to the
## suppression and is withdrawn with it. Nothing is lost now, because nothing was ever offered.)
## NOT WORTH A TEST: exercising the bad case would mean building a synthetic non-blankable,
## unfiltered VariantActionGroup from scratch, since nothing in the tree reaches it, and that
## fixture costs more than the consequence it would be guarding against. Flagged here for the
## author instead, same as before.
##
## AND THE FOURTH READER IS NOT ON THIS PATH AT ALL: CommonActionUtil.confirm_use_alt's test at
## common_action_util.gd:330 is reached from confirm_use (:312), from
## confirm_use_against_disambiguated_target (:388) and from ActionReactionMovement
## (action_reaction_movement.gd:91) - i.e. from the apply-buff / apply-status / clear-buff /
## reaction-movement archetypes, NEVER from ActionAttack, which has no confirm_use call at all.
## Recorded because the SP2.5 brief cited it as one of the "auto-choose targets" readers; it is a
## confirm, and an attack never asks it.
##
## WHAT THIS DOES NOT CHANGE: the spend stays conditional - and it is now LOAD-BEARING for this
## block rather than merely surviving it. See the deferred-spend block above: the Stunned and Jammed
## refusals were its only job while both prompts were suppressed; the cancel is the second job, and
## without the conditional spend the back-out described here would cost the player the very use they
## backed out to save.
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
		# SKIP_PLAYER_DECISIONS IS NO LONGER PASSED HERE, and the strike adds it back itself: see
		# the header, and action_psychopomp_strike.gd's get_attack_plan. Passing it here would take
		# the targeting screen with it, and that screen IS this reaction's back-out.
		# CONTROLLED_BY_OPPONENT is still deliberately NOT here, also per the header.
		[Action.FLAG.CAN_FOLLOWUP],
	)
	gear.hibernate_action(STRIKE_ID)
