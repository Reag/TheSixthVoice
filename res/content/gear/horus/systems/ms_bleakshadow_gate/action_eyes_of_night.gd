## EYES OF NIGHT: the Gate's reaction. Design ruling 22.
##
##   "Reaction, 1/Turn. Trigger: You or an allied character within Sensors hit an enemy benefiting
##    from soft or hard cover for the first time this turn. Effect: The attack deals an additional
##    +3 bonus damage and you take 2 Energy damage. This damage cannot be reduced in any way."
##
## ATTACK / POST, require_hit. The archetype applies the hit, the defender relation (ENEMIES of the
## Sluagh), the character test and the weapon/tech branch (action_reaction_attacked.gd:64-128).
## THREE CLAUSES ARE THIS SCRIPT'S, because the archetype cannot express them:
##  - the ATTACKER is the Sluagh itself, OR an allied CHARACTER (is_actor: a mech or a pilot, never
##    a drone - unit.gd:117) within the Sluagh's LIVE Sensors (unit.get_sensor_range(): frame +
##    stat_bonus, so Inexorable Formation counts).
##    "CHARACTER" IS is_actor() ACROSS THE WHOLE FRAME, which is THE MOD'S settled reading and not
##    this frame's local taste: ruling 194 (the Vauban's Gravity Well), rulings 64 and 70 (a drone's
##    shot counts as its OWNER'S) and ruling 269 (the Stealing) all spell it that way. The canonical
##    paragraph is in
##    res/content/frames/horus/mf_sluagh/mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd.
##    An allied DRONE's covered hit therefore does NOT open the Eyes; the archetype's
##    require_defender_to_be_character could never have delivered that anyway, since it is about the
##    DEFENDER (action_reaction_attacked.gd:95) and says nothing about who fired.
##    require_attacker_within would measure from the holder too, but it cannot say "or me"
##    and it cannot read a live stat. require_attacker_relation is ANY on the .tres for the same
##    reason: are_allies is true of a unit and itself, but the Sensors clause must not apply to the
##    Sluagh's own shots.
##  - the defender BENEFITED FROM COVER AS THAT ROLL COMPUTED IT: roll.pre.cover != NONE
##    (attack_roll.gd:99). A defender-side IGNORE_COVER (Markerlight) zeroes it at :161-163, so no
##    cover, so no trigger - the roll's own answer, not a second computation.
##    **AND THAT MAKES THE CARD WEAPON-ONLY IN PRACTICE, MEASURED IN TASK 2.** PreAttack.create
##    computes cover only inside `if action is ActionAttackWeapon` (the condition is
##    attack_roll.gd:153-157, the clause itself :154), and ActionAttackTech is a SIBLING of
##    ActionAttackWeapon under ActionAttack, not a subclass - so a
##    tech attack's pre.cover is the initialiser NONE, always, and an invade can never satisfy this
##    clause however covered the defender is. allow_tech stays true on the .tres (the card says "hit
##    an enemy", unqualified, and the day a tech attack carries cover this must not refuse it), and
##    the spec pins the current behaviour rather than asserting a bonus the engine cannot deliver.
##    Lancer's own rules agree - a tech attack is against E-Defense and cover does not apply - but
##    that is a ruling for the author, not a thing this file decides. Task 2 departure 3.
##  - the Gate is OPEN: is_available_to_activate requires buff_bleakshadow_gate (Draw Fire's
##    pattern, action_mark_retort.gd's twin). "You gain the reaction until..." is the chip's clock.
##
## "1/TURN" AND "FOR THE FIRST TIME THIS TURN" ARE BOTH THE REACTION POINT. consumes_rxn (the
## default) makes get_per_round_hard_limit return 1 (action_reaction.gd:69); the point is restored at
## every unit's turn start (event_turn_start.gd:42-44), so within one enemy turn the second
## qualifying hit is refused by the spent point, and the tally stops one more after the Sluagh's
## own turn comes round. Draw Fire ruling 3, recorded again.
##
## IT PROMPTS (plan departure 1): CommonActionUtil.confirm_use raises a yes/no for a player and
## answers itself for the AI (common_action_util.gd:304, :329). Declining returns BEFORE
## spend_actions, so it costs neither the point nor the round - the player may keep the Eyes for a
## better hit. The reaction costs the Sluagh 2 HP; a reaction the player cannot decline is not one.
##
## THE EFFECT, in order: (1) a one-time BuffDamage on BONUS_DAMAGE_SPECIFIC, "3", applied to the
## ATTACKER with from_gear the Gate and the defender's id in state - read and consumed by THIS
## attack's roll_specific_bonus_damage (event_unit_attack_declared.gd:268-296; Task 0's probe);
## (2) 2 ENERGY to the Sluagh, [SELF_INFLICTED, NO_REDUCE] - Mathur Stop's pair, the Crown's call.
## NO_REDUCE returns before armor and resistance (damage_modifications.gd:59); the Overshield soak is
## inside damage() (event_unit_damage.gd:215-218) and takes it first (ruling 7's parity).
##
## IT IS DRAWN ON THE SYSTEM CARD (author's ordered change, 2026-09-21), and it used to be drawn
## NOWHERE. This action carried `show_in_tooltip() -> bool: return false`, whose comment claimed
## "the Kit's own effect row IS this card" - THE KIT HAS NO EFFECT ROW. Every
## gear.ms_bleakshadow_gate.* key in the CSV was enumerated at the close: .name, .flavor, the
## activate's .name/.effect and this reaction's .name/.trigger/.effect, and no .effect on the Kit.
## So the card was built from the activate's row alone and the player had no way to read this
## reaction's trigger, its +3 or its 2 self-damage anywhere in the game. With the override gone the
## base runs (action.gd:341-353) and returns true at clause 5: this action's own effect row is
## non-empty and differs from the Kit's, which is empty. tooltip_organ_kit.gd:71 is
## show_in_tooltip's ONLY caller in the tree - it governs the kit/trait CARD, not the gear bar,
## which drops every ActionReaction unconditionally at gear_bar.gd:145 and never asks this
## function. The trigger line renders with it: ActionReaction.trigger_text (action_reaction.gd:21-24)
## reads the ACTION-keyed row and prepends "Trigger:". The interlock is
## test_content_integrity.gd's ICON_TARGETS, which now carries a KIT row for this action -
## _action_reaches_a_player_facing_surface returns show_in_tooltip for a reaction, so the pairing
## assertion goes red if either half is changed alone.
##
## TECH IMMUNITY KILLS THIS REACTION OUTRIGHT - not just its +3, and earlier than the branch used to
## record (close review, slice 6 I-2). ActionReaction.check_if_prohibited (action_reaction.gd:99-111)
## refuses any TECH reaction whose triggering context.unit or context.target_unit is tech-immune, and
## reaction_bus.gd:120 calls it inside does_reaction_trigger BEFORE triggers_on_event (:123) is
## reached. The Gate is tech gear (UnitAction.is_tech, unit_action.gd:567-571, is true of a Kit whose
## activate sets is_tech), so against a tech-immune attacker or defender there is no prompt, no +3
## AND no 2 self-damage. The Buff.check_if_prohibited path some of our comments used to name
## (buff.gd:228-239) is unreachable here, because the buff is never applied. Note also that
## triggering_context.unit is the DECLARED attacker - "may be a throughbolt round"
## (event_unit_attack_declared.gd:28-29) - not get_attacker(context), so on a relayed shot the
## immunity test reads the relay, where the Sensors clause below reads the real attacker.
##
## THE TRIGGERING CONTEXT IS context.event.context, NOT this context - measured in SP1 Task 6 and
## used by action_astral_guardian.gd and action_mark_retort.gd. ReactionBus builds the block as
## {action, unit, gear, event} (reaction_bus.gd:53-60).
extends ActionReactionAttacked

const GATE_CHIP := &'buff_bleakshadow_gate'
const BONUS_BUFF := &'buff_eyes_of_night_bonus'
const DEFENDER_KEY := 'eyes_defender'   # buff_eyes_of_night_bonus.gd reads the same key
const SELF_DAMAGE := 2

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return UnitCondition.has_buff(unit, GATE_CHIP)

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit): return false
	var triggering_context:Context = triggering_event.context
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker): return false
	# "You or an allied character within Sensors".
	if attacker != unit:
		if not UnitRelation.are_allies(unit, attacker): return false
		if not attacker.is_character(): return false
		if UnitRelation.distance_between(unit, attacker) > unit.get_sensor_range(): return false
	# "benefiting from soft or hard cover" - as the roll computed it.
	var roll:AttackRoll = triggering_context.object
	if not AttackRoll.is_valid(roll): return false
	return roll.pre.cover != Lancer.COVER.NONE

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	var triggering_context:Context = context.event.context
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	var defender:Unit = triggering_context.target_unit
	if activation.abort_without_units([attacker, defender]): return

	# "You may" - declining is free.
	var confirmed:bool = await CommonActionUtil.confirm_use(
		context, [defender], [], SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([unit, attacker, defender]): return

	spend_actions(activation)

	var bonus := BuffCore.create(ContentLibrary.get_buff(BONUS_BUFF), context.gear.persistent_id)
	bonus.set_state(DEFENDER_KEY, defender.core.persistent_id)
	UnitCondition.apply_buff_alt(activation, attacker, bonus)

	CommonActionUtil.queue_damage_events(
		activation, SpecificAction.from_context(context), [unit], SELF_DAMAGE, Lancer.DAMAGE_TYPE.ENERGY,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED, EventService.DAMAGE_FLAG.NO_REDUCE]
	)
