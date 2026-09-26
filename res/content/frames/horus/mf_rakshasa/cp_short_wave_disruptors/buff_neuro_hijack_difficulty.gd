## NEURO-HIJACK's +1 Difficulty (ruling 29): "must choose a different target for that attack at +1
## Difficulty." On the attacker, from the Rakshasa's core gear: an ATTACK_ROLL BuffBonus of -1 accuracy,
## read by AttackRoll.PreAttack.create for every roll the attacker makes (attack_roll.gd:134, :182-189).
##
## SCOPED TO ONE DECLARED ATTACK by the summary id buff_neuro_hijack stamps into its state: the per-target
## context PreAttack hands over carries the DeclaredAttackSummary in `resource`, so every roll of THAT
## attack - the moved one, or an area's other caught characters - matches, and any later attack does not.
## Any other caller of get_buffs_to(ATTACK_ROLL) with no summary (an AI hit preview) sees nothing.
## until END_OF_THIS_TURN is only the backstop.
##
## HIDDEN, but the roll breakdown draws it anyway - attack_roll.gd:189 passes buff_core.base.icon RAW -
## so it is in test_content_integrity.gd's HIDDEN_BUFFS_NEEDING_ICONS. Its name is the protocol's.
extends BuffBonus

const SUMMARY_KEY := 'summary_id'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if context == null or not DeclaredAttackSummary.is_valid(context.resource): return false
	return String(context.resource.id) == String(core.get_state(SUMMARY_KEY, ''))
