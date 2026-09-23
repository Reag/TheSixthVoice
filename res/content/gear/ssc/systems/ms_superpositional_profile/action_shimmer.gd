# SHIMMER (Purple Thorn rank III, Superpositional Profile; SP4 Task 2, design ruling 15):
#
#   "Reaction, 1/round. Trigger: You are targeted by a ranged attack.
#    Effect: Expend a charge, the attack gains +2 DIFFICULTY, if the attack misses you may
#    immediately teleport to a space within range 3."
#
# TWO REACTIONS, ONE CARD. This is the first: an ATTACK PRE ActionReactionAttacked on the DEFENDER
# (the .tres: require_unit_to_be DEFENDER, allow_tech false, weapon_types_forbidden [MELEE] - the
# engine's own "ranged", the Leoleth's 43-A ruling - allow_basic true). It is a real reaction
# (consumes_rxn, the archetype's default), so the point makes it 1/round and a charge is spent by
# the default consumes_charges; an empty system is refused by can_be_used_while_uncharged.
#
# ON A YES: the Saladin's Warp Shield verbatim (action_warp_shield.gd) - confirm_use, spend, and a
# onetime FINISH_ATTACK_ROLL buff on attack_roll_incoming, here -2 accuracy (= +2 Difficulty). PRE
# runs before the roll is built (event_unit_attack.gd:31-32, :50), so the roll collects it.
#
# THEN THE STAMP: the triggering attack event's id in gear state, which is the ONLY thing that arms
# the companion action_shimmer_blink at ATTACK POST. Gear state, not a buff: the attack consumes
# incoming onetime buffs and clears FINISH_ATTACK_ROLL (:114-120) BEFORE it queues POST (:123), so
# a marker buff would already be gone when the blink asks.
extends ActionReactionAttacked

## Gear state: the id of the attack event Shimmer was taken on. Read and cleared by the blink.
const STAMP_KEY := 'shimmer_attack'
const DIFFICULTY_BUFF := &'buff_shimmer_difficulty'

func activate(context:Context, activation:EventCore) -> void:
	var triggering_context:Context = context.event.context
	var defender:Unit = triggering_context.target_unit
	var declared_attack_summary:DeclaredAttackSummary = triggering_context.resource

	var confirmed := await CommonActionUtil.confirm_use(
		context,
		[defender],
		declared_attack_summary.all_attacked_tiles,
		SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(defender): return
	spend_actions(activation)

	apply_buff_id(activation, defender, DIFFICULTY_BUFF)
	context.gear.set_state(STAMP_KEY, String(context.event.id))
