# ZWARTE HOOP's "+1 to the attack roll", once or twice (design ruling 13). A FLAT bonus, not
# accuracy - the card says "to the attack roll". PreAttack.create reads it through
# buff_core.get_values() with NO context (attack_roll.gd:182-189), so the count lives on the BuffCore
# (state 'n', written by action_zwarte_hoop_spend.apply_counted), not on the attack. FINISH_DAMAGE:
# it lives through every roll of the declared attack and is cleared at its end
# (event_unit_attack_declared.gd:203-205).
extends BuffBonus

func get_values(core:BuffCore, context:Context) -> Context:
	var values := super.get_values(core, context)
	values.number = core.get_state('n', 0) if core != null else 0
	return values
