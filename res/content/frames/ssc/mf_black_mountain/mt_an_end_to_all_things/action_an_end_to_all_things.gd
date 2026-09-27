## AN END TO ALL THINGS (Black Mountain SP1, design ruling 7):
##
##   "2/round, when an allied character with OVERSHIELD you granted makes a successful attack roll
##    against a hostile character within sensors and line of sight, you may take 1 heat to have them
##    deal +3 bonus damage."
##
## EYES OF NIGHT'S SHAPE (ms_bleakshadow_gate/action_eyes_of_night.gd) with a different gate and Blood
## of the Creature's heat payment. ATTACK / POST with require_hit; the archetype applies the hit, the
## defender relation (ENEMIES of the Black Mountain), the defender-is-a-character test and the
## weapon/tech branch (allow_tech and allow_basic set: "a successful attack roll", unqualified - an
## invade counts, though one that deals no damage gains nothing, since the +3 is read where damage is
## rolled). FOUR CLAUSES ARE THIS SCRIPT'S:
##  - the ATTACKER (get_attacker, so an owned drone's shot is its owner's) is an ALLIED CHARACTER
##    (is_actor, ruling 3) and NOT THE BLACK MOUNTAIN: are_allies is true of a unit and itself
##    (unit_relation.gd:364-365), and "allied character" excludes you on every card of this frame
##    (ruling 3, the author's call). The Black Mountain's own hits never open this.
##  - the attacker holds OVERSHIELD THE BLACK MOUNTAIN GRANTED: Overshield.is_granted_by(attacker, unit),
##    the shared helper's "granted by" mark (ruling 5) - hung by grant_by / increase_by, alive while any
##    Overshield remains, ended by the damage that zeroes it. Vanilla grants and other mods' grants
##    carry no mark and never qualify; SP2's Exalt and Fell the Mighty are the Black Mountain's granters.
##  - the DEFENDER is a hostile CHARACTER (is_actor: the card says "hostile character") within the Black
##    Mountain's live Sensors AND line of sight (ruling 4: on THIS card the clause modifies the hostile).
##  - "you MAY take 1 heat": CommonActionUtil.confirm_use for the Black Mountain's controller (an AI
##    takes ai_confirms_use, ruling 14); declining returns before spend_actions and costs nothing.
##
## "2/ROUND" AS A TRAIT: consumes_rxn = false, get_per_round_hard_limit 2, its own usage_group, and
## spend_actions inside activate AFTER the offer. The tally clears at the Black Mountain's own turn
## start (ruling 3).
##
## THE EFFECT: 1 HEAT to the Black Mountain through UnitAction.gain_self_heat_alt (vanilla's own
## self-heat shape: an event_unit_damage HEAT flagged SELF_INFLICTED and SKIP_CONSUMING_RESIST_BUFFS),
## then Eyes of Night's bonus on the ATTACKER: buff_an_end_to_all_things_bonus, a one-time BuffDamage on
## BONUS_DAMAGE_SPECIFIC, "3", scoped to THIS defender through DEFENDER_KEY, from_gear this trait. Every
## per-target attack event completes - ATTACK POST children included - before the declared attack rolls
## damage and reads BONUS_DAMAGE_SPECIFIC from the attacker per roll
## (event_unit_attack_declared.gd:53-67, :127-145, :269-315), so the +3 lands on this very attack. On a
## multi-target attack only the triggering defender takes it - which is the card. NEVER until =
## FINISH_DAMAGE on that buff: the payer's own heat event would sweep it (Eyes of Night's measured
## reason); its lifetime is is_onetime alone.
##
## THE TRIGGERING CONTEXT IS context.event.context, NOT this context (action_astral_guardian.gd).
extends ActionReactionAttacked

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const BONUS_BUFF := &'buff_an_end_to_all_things_bonus'
const DEFENDER_KEY := 'an_end_defender'   # buff_an_end_to_all_things_bonus.gd reads the same key
const HEAT_COST := 1
const USES_PER_ROUND := 2

## Bookkeeping: the trait Kit's own effect row IS this card. See action_dread_harbinger.gd.
func show_in_tooltip(_kit:Kit) -> bool: return false

## ActionReaction returns 99 for a reaction that consumes no reaction point. The card says 2/round.
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return USES_PER_ROUND

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit): return false
	var triggering:Context = triggering_event.context
	var attacker:Unit = triggering.unit.get_attacker(triggering)
	if not is_an_allied_character_shielded_by(unit, attacker): return false
	var defender:Unit = triggering.target_unit
	if not Unit.is_valid(defender) or not defender.is_actor(): return false
	if UnitRelation.distance_between(unit, defender) > unit.get_sensor_range(): return false
	return UnitRelation.can_see(unit, defender)

## "An allied character with OVERSHIELD you granted" - somebody ELSE (ruling 3), a character, marked.
static func is_an_allied_character_shielded_by(black_mountain:Unit, attacker:Unit) -> bool:
	if not Unit.is_valid(attacker) or attacker == black_mountain: return false
	if not UnitRelation.are_allies(black_mountain, attacker): return false
	if not attacker.is_actor(): return false
	return Overshield.is_granted_by(attacker, black_mountain)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var triggering:Context = context.event.context
	var attacker:Unit = triggering.unit.get_attacker(triggering)
	var defender:Unit = triggering.target_unit
	if activation.abort_without_units([unit, attacker, defender]): return

	# "You may take 1 heat" - the Black Mountain's controller decides, and the Black Mountain pays.
	var confirmed:bool = await CommonActionUtil.confirm_use(
		context, [defender], [], SpecificAction.from_context(triggering))
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([unit, attacker, defender]): return

	spend_actions(activation)
	UnitAction.gain_self_heat_alt(HEAT_COST, SpecificAction.from_context(context), activation)

	var bonus := BuffCore.create(ContentLibrary.get_buff(BONUS_BUFF), context.gear.persistent_id)
	bonus.set_state(DEFENDER_KEY, defender.core.persistent_id)
	UnitCondition.apply_buff_alt(activation, attacker, bonus)
