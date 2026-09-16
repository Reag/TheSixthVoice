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
## the spend_actions() at the end of activate() is what feeds it - without that call the limit is a
## limit on a counter nothing increments. Per design ruling 5 this "round" is really "since the Myconid's
## own last turn start", because UnitAction.reset_per_round_usage runs there; accepted for vanilla
## parity, as for Juggernaut Drive and Halo.
##
## AND IT ALSO OPENS EVERY can_be_used_while_* GATE. action_reaction.gd:62-66 derive all four from
## requires_reaction_available(), so a non-consuming reaction is usable while Stunned, Dazed,
## Jammed, unloaded and uncharged. That is not a loophole to be closed here: ruling 11 says a Stunned
## or Jammed Myconid cannot strike, and the refusal comes from the STRIKE's own re-validation inside
## choose_and_use - event_gear_activate.check_specific_context (content/events/event_gear_activate.gd
## :46-51) asks UnitAction.get_gear_unavailable_reason of the CHOSEN action and prints the reason in
## red. test_a_stunned_myconid_cannot_strike drives that end to end and ALSO asks the engine for the
## reason directly, as a freebie, rather than asserting the claim in a comment. Because nothing is
## spent unless the strike lands (below), a Stunned Myconid's Gyre costs it nothing either.
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
## NOTHING OF THE MYCONID'S ACTION ECONOMY IS SPENT. choose_and_use_no_spend
## (common_action_util.gd:775-776) is the do-nothing spend callable; the Gyre fires off-turn, and a
## reaction that quietly ate the Myconid's next Quick would be a second cost the card never names.
##
## NOTHING IS SPENT UNTIL THE STRIKE IS KNOWN TO HAVE LANDED - Draw Fire's principle
## (action_draw_fire.gd:170-200), and here it is not theoretical. MEASURED 2026-09-16: the strike
## opens TWO prompts, a compcon targeting plan and, because the target is an ALLY,
## TargetActionUtil.confirm_friendly_fire's yes/no (action_attack.gd:247, target_action_util.gd
## :430-435). Declining the second aborts the child activation, so there IS a cancel path on this
## seam and an unconditional spend would charge the round's one use for a shot the player refused.
## The same guard also covers the Stunned and Jammed refusals of ruling 11: a Myconid that could not
## strike has not used its reaction.
##
## THE TEST IS THE STRIKE'S OWN USAGE COUNTER, NOT choose_and_use's RETURN VALUE. That returns
## SpecificAction.is_valid(chosen) (common_action_util.gd:763), which is TRUE even when the child
## aborted, so it cannot tell a landed strike from a refused one. The counter can, and it is the
## engine's own test for the same question - event_gear_activate.gd:76 and :103 bracket an activation
## with exactly this read to decide whether the gear was really used, with the comment "use ROUND and
## not TURN counts here bc freebies don't always get counted". The strike has its own usage_group, so
## nothing else on this Kit can move it.
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

	var strike_group:StringName = gear.get_usage_group_for_action(strike)
	var strike_uses_before:int = gear.get_uses_this_round_alt(strike_group)

	var shot := SpecificAction.create(context.unit, gear, strike)
	gear.wake_action(STRIKE_ID)
	await CommonActionUtil.choose_and_use(
		activation,
		shot,
		[shot],
		CommonActionUtil.choose_and_use_no_spend,
		mover,
		[Action.FLAG.CAN_FOLLOWUP],
	)
	gear.hibernate_action(STRIKE_ID)

	# The Gyre's OWN usage counter, which is what its per-round hard limit reads, and only if the
	# strike really happened. See the header.
	if gear.get_uses_this_round_alt(strike_group) == strike_uses_before: return
	spend_actions(activation)
