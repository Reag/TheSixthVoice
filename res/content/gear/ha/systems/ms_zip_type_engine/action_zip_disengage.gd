# DISENGAGE (the ZIP Type Engine's off switch, design ruling 16). The clear-buff archetype has no
# availability gate of its own (action_system_clear_buff.gd overrides none; vanilla relies on
# is_situationally_activated to keep such buttons off the bar). This one is an ordinary FREE action
# with hide_if_disabled, so it needs the gate the archetype lacks: offered only while the chip from
# THIS gear is held. buff_needs_to_have_been_applied_by_this (the archetype default) already scopes
# the clear to our own persistent id; the same id is checked here.
#
# get_per_round_hard_limit ALSO LIVES HERE NOW (Fix 3, author's decision, 2026-09-22) - lifting the
# per-round cap. Its twin override, action_zip_engage.gd, carries the full reasoning: both halves
# are naturally FREE (action_type = 3), so Action.get_per_round_hard_limit
# (action.gd:156-158) defaults each to 1/round on its own, though the card caps nothing - it grants
# the choice per MOVEMENT. Overridden straight at the source rather than through a
# Buff.TO.ACTION_PER_ROUND buff (unit_action.gd:173-174, the engine's sanctioned channel for RAISING
# this cap) because the cap should never apply to this gear at all, not merely while some buff is up.
extends ActionSystemClearBuff

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return unit_has_buff_to_clear(unit, gear)

func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 99
