# BLESSED BOLT SYSTEM (Purple Thorn, mt_blessed_bolt_system), ruling 4:
#
#   "1/round, when the Purple Thorn hits with an Auxiliary weapon, it may deal + 3 bonus damage."
#
# An ATTACK POST reaction on the trait Kit - Leader's Follow Order shape
# (action_follow_order_damage.gd): a yes/no, then a one-time BuffDamage that the damage roll a
# moment later reads. ATTACK POST reactions finish inside execute_events(unit_attacked_events)
# (event_unit_attack_declared.gd:67), BEFORE damage is rolled at :74, so a buff hung here is
# counted. Bonus-damage buffs have no confirmation hook of their own, hence the reaction.
#
# ON ActionReactionAttacked, which does most of the gate for free from the .tres:
# require_unit_to_be ATTACKER (the Thorn is the one shooting), require_hit (POST, off the roll in
# context.object), weapon_sizes [AUX], allow_weapon only. require_defender_to_be_character is
# OFF: the card says "hits with an Auxiliary weapon", not "hits a character", so an object counts.
# Two clauses are this file's own: the attack must not carry NO_BONUS_DAMAGE - the engine's own
# flag for the second Aux of an Aux/Aux pair (action_attack_weapon.gd:72, read at
# event_unit_attack_declared.gd:94), which the AUTHOR ruled Blessed Bolt is not offered on either -
# and the re-entrancy guard is not needed (no follow-up shot is fired from here).
#
# THE BUFF IS PLAIN BONUS DAMAGE (rulings.md Pass E, close-out Pass F Task 13): to = bonus_damage is
# read once for the whole declared attack (:95), halved when more than one character is attacked, and
# added to every victim's damage - so on a Blast every victim takes the halved +3, as Lancer does.
# (Until Pass F it was bonus_damage_specific, gated on the one victim whose hit was offered.) It is
# onetime and until FINISH_DAMAGE, so it cannot leak into the next attack.
#
# 1/ROUND: consumes_rxn is false (a trait, not the reaction point), so the archetype's default
# limit would be 99; get_per_round_hard_limit returns 1 and counts gear.uses_this_round, whose only
# writer is spend_actions - called on a YES only. A "no" spends nothing (the card's "may") and the
# next Aux hit that round offers again. Own usage_group.
#
# THE PREDICATE IS PURE (the Naga probe's rule): no spend, no stamp, no prompt in triggers_on_event.
extends ActionReactionAttacked

const USES_PER_ROUND := 1

## The one-time BuffDamage hung on the Thorn on a yes - buff_blessed_bolt.tres.
@export var damage_buff:Buff

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return USES_PER_ROUND

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# The archetype: ATTACKER is the holder, a HIT, an AUX weapon attack, the defender still valid.
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# The second Aux of an Aux/Aux pair: the engine's own no-bonus-damage shot (author's call).
	if triggering_event.context.flags.has(Action.FLAG.NO_BONUS_DAMAGE): return false
	return true

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var triggering:Context = context.event.context
	var defender:Unit = triggering.target_unit
	if activation.abort_without_units([unit, defender]): return

	# 1. THE OFFER. A "no" spends nothing; the next Aux hit this round offers again.
	var confirmed:bool = await CommonActionUtil.confirm_use(context, [defender])
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([unit, defender]): return

	# 2. THE SPEND, then the buff - read by this attack's general bonus-damage roll.
	spend_actions(activation)
	apply_buff(activation, unit, damage_buff)
