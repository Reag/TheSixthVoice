# DISENGAGE (the ZIP Type Engine's off switch, design ruling 16). The clear-buff archetype has no
# availability gate of its own (action_system_clear_buff.gd overrides none; vanilla relies on
# is_situationally_activated to keep such buttons off the bar). This one is an ordinary FREE action
# with hide_if_disabled, so it needs the gate the archetype lacks: offered only while the chip from
# THIS gear is held. buff_needs_to_have_been_applied_by_this (the archetype default) already scopes
# the clear to our own persistent id; the same id is checked here.
extends ActionSystemClearBuff

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return unit_has_buff_to_clear(unit, gear)
