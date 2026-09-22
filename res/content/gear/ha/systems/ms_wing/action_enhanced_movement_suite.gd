# ENHANCED MOVEMENT SUITE, W.I.N.G's one Protocol (Leoleth rank I, design ruling 20).
#
#   "You may spend a charge to clear the Prone, Slowed, and Immobilized conditions if they weren't
#    self inflicted. For the rest of the turn, you ignore difficult terrain and may move over cover
#    regardless of its size."
#
# ONE CHARGE BUYS BOTH HALVES (the author's ruling), so this is ONE action and not two: the movement
# chip is the archetype's own `buffs` array and the only code here is the three status clears.
#
# apply_additional_effect IS THE ARCHETYPE'S OWN OVERRIDE POINT (action_system_apply_buff.gd:167),
# called once per target from apply_buffs_to_targets (:158) - and with apply_only_to_self the one
# target is always the Leoleth. It runs AFTER the buff is applied, where the card words it the other
# way round; the two are independent (a MOVEMENT_TYPE buff reads no statuses, and clearing a status
# reads no buffs), so the order is not observable and no spec asserts one.
#
# "NOT SELF INFLICTED" IS NOT OURS TO DEFINE. UnitCondition.ability_can_clear
# (unit_condition.gd:472-477) carries the engine's own test: a status whose source gear sits in this
# unit's own loadout is self-applied, and the underwater Slowed is refused by name.
#
# BUT ability_can_clear ALSO GATES ON StatusType.get_counts_as_condition, AND PRONE FAILS THAT GATE -
# a DEPARTURE found by running spec/test_wing.gd, not proposed in the plan. Prone ships with no
# `counts_as_condition = true` line (content/statuses/status_prone.tres), unlike Slowed's and
# Immobilized's own (status_slowed.tres:9, status_immobilized.tres:9): in the engine's own taxonomy
# Prone is an AFFLICTION, not a "condition", and clear_status_via_ability (unit_condition.gd:479-483)
# refuses every affliction regardless of source. Every vanilla caller that clears Prone therefore
# goes around it and calls UnitCondition.clear_status / clear_specific_status directly - Stand Up
# (content/gear/basic/ms_stand_up/action_stand_up.gd:25) on self, Remote Reboot
# (content/frames/npc/npcc_support/remote_reboot/action_remote_reboot_support.gd:35) on a target.
# Measured: the naive `for status in CLEARED_STATUSES: UnitCondition.clear_status_via_ability(...)`
# cleared a hostile-applied Slowed and Immobilized but left Prone standing, in
# test_a_hostile_applied_prone_slow_and_immobilize_all_clear. The card names Prone explicitly, so
# _clear_if_not_self_inflicted keeps exactly the two tests the card's clause asks for - self-applied,
# underwater-Slowed - and drops only the condition/affliction distinction, which nothing on this
# card's text cares about.
extends ActionSystemApplyBuff

## The three the card names, and only these three.
const CLEARED_STATUSES:Array[StringName] = [
	Lancer.STATUS.PRONE, Lancer.STATUS.SLOWED, Lancer.STATUS.IMMOBILIZED,
]

func apply_additional_effect(specific:SpecificAction, target_unit:Unit, activation:EventCore) -> void:
	if not Unit.is_valid(target_unit): return
	for status:StringName in CLEARED_STATUSES:
		_clear_if_not_self_inflicted(activation, target_unit, status)

## UnitCondition.ability_can_clear's own self/underwater test (unit_condition.gd:472-477), WITHOUT
## its StatusType.get_counts_as_condition gate - see the header for why Prone needs that dropped -
## clearing directly with clear_specific_status rather than routing through clear_status_via_ability.
func _clear_if_not_self_inflicted(activation:EventCore, unit:Unit, status_type:StringName) -> void:
	for status_condition:StatusCondition in unit.state.statuses.duplicate():
		if status_condition.type != status_type: continue
		if status_condition.is_unit_owner(unit): continue
		if status_condition.source == StatusType.SOURCE_UNDERWATER_STATUS_KEY: continue
		UnitCondition.clear_specific_status(activation, unit, status_condition)
