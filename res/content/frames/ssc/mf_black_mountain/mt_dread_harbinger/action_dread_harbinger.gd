## DREAD HARBINGER, the lock (Black Mountain SP1, design ruling 8):
##
##   "1/round, whenever the Black Mountain or an allied character within Sensors and line of sight
##    critically hits, the target receives Lock On. Additionally, when this Lock On is consumed, the
##    Black Mountain gains 1d6 Overshield."
##
## ATTACK / POST with require_crit: `roll.crit` exists only on the POST AttackRoll
## (action_reaction_attacked.gd:101-107). The archetype applies the crit, the defender relation
## (ENEMIES of the Black Mountain), the defender-is-a-character test and the weapon/tech branch.
## THREE CLAUSES ARE THIS SCRIPT'S:
##  - the ATTACKER is the Black Mountain itself, OR an allied CHARACTER (is_actor - the mod's settled
##    reading, ruling 3; a drone's crit counts as its OWNER's through get_attacker) within the Black
##    Mountain's live Sensors AND line of sight (ruling 4: distance_between <= get_sensor_range(), and
##    UnitRelation.can_see, which carries the Blinded rule the per-tile primitive drops). Eyes of Night's
##    "you or an allied character within Sensors" clause, plus the sight test. require_attacker_relation
##    is ANY on the .tres because are_allies is true of a unit and itself and the Sensors clause must
##    not apply to the Black Mountain's own crits.
##  - the TARGET can take the lock: not already Locked On, not immune. Lockon.apply refuses both anyway
##    (and returns false); gating here means the reaction is never OFFERED for a target it cannot lock,
##    and never spends its round on one (Naga ruling 6: spend_actions is the only writer of
##    uses_this_round). The card says "the target", not "character", so a hostile DRONE may be locked,
##    as vanilla Lock On allows; the archetype's require_defender_to_be_character still refuses objects.
##  - nothing else: AUTOMATIC, no prompt (the card has no "may"; Astral Guardian's reading).
##
## WEAPON-ONLY IN PRACTICE, MEASURED (SP1, 2026-09-27): a TECH attack never crits in this engine.
## event_unit_attack.gd:241 rolls with context.action.can_crit(context); ActionAttack.can_crit is
## `return false` (action_attack.gd:48) and only ActionAttackWeapon overrides it to true (:246), so
## attack_roll.gd:73 leaves crit false on every invade however high the d20. Lancer's own rules agree.
## allow_tech stays true on the .tres because the card says "critically hits", unqualified - Eyes of
## Night's reasoning for its weapon-only cover clause - and the spec pins the current behaviour.
##
## "1/ROUND" AS A TRAIT: consumes_rxn = false on the .tres (no reaction point), so
## get_per_round_hard_limit is overridden to 1 - ActionReaction returns 99 for a point-free reaction
## (action_reaction.gd:69). The limit is consulted inside ReactionBus.does_reaction_trigger via
## can_activate_gear, so a second crit in the round is never offered. It clears at the BLACK MOUNTAIN's
## own turn start (reset_per_round_usage in UnitAction.new_turn_refresh), ruling 3.
##
## THE EFFECT, in order: Lockon.apply(activation, target, this trait's gear) - LOCKON, UNTIL.MANUAL,
## source = the gear's persistent id, exactly the status a vanilla Lock On writes, so every vanilla
## consumer (buff_lock_consumed's +1, the consume reaction, Stabilize) treats it as one - and ONLY IF
## THAT RETURNED TRUE: spend_actions, then the visible mark buff_dread_harbinger_mark on the target
## (ruling 9), from_gear = this gear so its get_owner_unit() is the Black Mountain the 1d6 goes to. A
## Blast that crits two hostiles locks the first target the engine resolves; the second is refused by
## the round.
##
## THE TRIGGERING CONTEXT IS context.event.context, NOT this context (action_astral_guardian.gd's
## measured note): ReactionBus builds the block as {action, unit, gear, event} (reaction_bus.gd:53-60),
## so THIS context carries the holder in `unit` and the per-target attack event in `event`.
extends ActionReactionAttacked

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const MARK := &'buff_dread_harbinger_mark'

## Bookkeeping: the trait Kit's own effect row IS this card, and a reaction never reaches the gear bar
## (gear_bar.gd:145). With no effect row of its own the base would return false anyway (action.gd:
## 341-353); written out so the ICON_TARGETS row ({}) has one line to point at.
func show_in_tooltip(_kit:Kit) -> bool: return false

## ActionReaction returns 99 for a reaction that consumes no reaction point. The card says 1/round.
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit): return false
	var triggering:Context = triggering_event.context
	var attacker:Unit = triggering.unit.get_attacker(triggering)
	if not is_you_or_an_allied_character_within_sensors_and_sight(unit, attacker): return false
	var target:Unit = triggering.target_unit
	if not Unit.is_valid(target): return false
	if UnitCondition.has_status(target, Lancer.STATUS.LOCKON): return false
	if UnitCondition.is_immune_to_status(target, Lancer.STATUS.LOCKON): return false
	return true

## "The Black Mountain or an allied character within Sensors and line of sight", read from the Black
## Mountain's side (ruling 4: the `x` is the ALLY on this card).
static func is_you_or_an_allied_character_within_sensors_and_sight(black_mountain:Unit, attacker:Unit) -> bool:
	if not Unit.is_valid(attacker): return false
	if attacker == black_mountain: return true
	if not UnitRelation.are_allies(black_mountain, attacker): return false
	if not attacker.is_character(): return false
	if UnitRelation.distance_between(black_mountain, attacker) > black_mountain.get_sensor_range(): return false
	return UnitRelation.can_see(black_mountain, attacker)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var target:Unit = context.event.context.target_unit
	# Re-derived LIVE: the gate ran when the reaction was queued, and another reaction to the same roll
	# may have displaced, locked or destroyed either of them.
	if activation.abort_without_units([unit, target]): return
	# THE LOCK FIRST, AND THE ROUND ONLY IF IT TOOK: a target somebody else locked between the gate and
	# now costs nothing.
	if not Lockon.apply(activation, target, context.gear): return
	spend_actions(activation)
	var mark := BuffCore.create(ContentLibrary.get_buff(MARK), context.gear.persistent_id)
	UnitCondition.apply_buff_alt(activation, target, mark)
