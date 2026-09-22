# ENGAGE (the ZIP Type Engine's on switch, design ruling 16). Otherwise the vanilla
# ActionSystemApplyBuff archetype unmodified - can_reapply/hide_if_disabled/action_type/the buff all
# stay declared on the .tres, exactly as before this file existed. This script exists for ONE thing:
# lifting the per-round cap (Fix 3, author's decision, 2026-09-22). See action_zip_disengage.gd's
# twin override for the other half of the toggle and the full reasoning; restated briefly here
# because each half needs its own override (get_per_round_hard_limit is per-Action, not per-Kit).
#
# THE PROBLEM: both halves of this card are action_type = 3, FREE (lancer.gd:27, action_zip_engage.
# tres:23 / action_zip_disengage.tres:14). Action.get_per_round_hard_limit
# (engine/character/gear_action/action.gd:156-158) returns 1 for ANY action whose natural cost is
# <= Lancer.ACTION_COST_FREE (0, lancer.gd:28-39), and UnitAction.is_under_per_round_limit
# (unit_action.gd:170-175) is what get_gear_unavailable_reason (:148) checks before refusing with
# REASON.PER_ROUND. So, unmodified, the engine caps EACH half to one flip per round - but the card
# caps nothing at all: it grants the choice per MOVEMENT, as many times as the pilot wants to move.
#
# WHY OVERRIDE RATHER THAN A Buff.TO.ACTION_PER_ROUND BUFF - the engine's own sanctioned channel for
# raising this exact cap (unit_action.gd:173-174, added to round_cap on top of
# get_per_round_hard_limit's return). Author's call: the cap should never apply to this gear AT ALL,
# not merely while some buff happens to be up. A buff is the right tool for a card that raises an
# existing limit conditionally; this card has no limit to raise a buff against, so the override goes
# straight at the source instead.
extends ActionSystemApplyBuff

func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 99
