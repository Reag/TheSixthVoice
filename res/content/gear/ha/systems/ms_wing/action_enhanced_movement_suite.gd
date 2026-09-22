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
#
# FIX (frame-close review, author's decision): THE LOOP ABOVE ONLY EVER SAW unit.state.statuses, AND
# A STATUS A BUFF APPLIES NEVER BECOMES A StatusCondition IN THAT ARRAY. UnitCondition
# .get_current_statuses (unit_condition.gd:372-384) is the engine's own proof this is a second,
# separate set: it walks unit.state.statuses AND, independently at :379-382, every buff's
# applies_statuses via get_buffs_that_apply_status (:809-817). Twenty-one vanilla resources apply
# Immobilized this way and twelve apply Slowed - the Goliath's Pin
# (content/frames/npc/npcc_goliath/pin/buff_pin_goliath_immobilized.tres: applies_statuses =
# [&"immobilized"]), the Barricade's Titan Snare, the Aegis Defense Net, the Assassin's Transfix, the
# Minotaur's Maze, and more - so a Leoleth pinned by any of them was spending the charge, getting the
# movement half, and staying Immobilized: the naive loop's Measured note above never exercised this
# path at all, because SpecFactory.apply always writes a StatusCondition.
#
# MODELED ON THE ONE PLACE IN THE ENGINE THAT ALREADY CHECKS BOTH SETS BEFORE DECIDING A STATUS IS
# GONE: content/frames/ipsn/mf_vlad/mt_dismemberment/action_dismemberment_unshred.gd:21-34 walks
# shredded_unit.state.statuses, then separately shredded_unit.state.buffs, asking of each buff
# whether buff.base.applies_statuses contains the status in question.
#
# SELF-INFLICTED IS DISTINGUISHABLE ON THE BUFF PATH TOO, BY THE IDENTICAL TEST. BuffCore
# .is_unit_owner (buff_core.gd:97-100) is StatusCondition.is_unit_owner (status_condition.gd:41-44)
# verbatim, just read off from_gear instead of source - is the buff's applying gear a piece of THIS
# unit's own loadout. So "if they weren't self inflicted" costs no guesswork on the buff side either;
# there is no underwater-key equivalent to check because no buff in the corpus applies a status with
# StatusType.SOURCE_UNDERWATER_STATUS_KEY as its from_gear (that key only ever appears as a
# StatusCondition.source, written directly by UnitCondition.update_water_statuses, unit_condition.gd
# :583-584).
#
# A BUFF CLEARS WHOLE, NOT PER-STATUS - THIS IS A DELIBERATE COST, NOT AN OVERSIGHT. Buff has no
# "drop just this one applies_statuses entry"; UnitCondition.clear_buff (unit_condition.gd:967-982)
# always removes the entire buff and everything else about it. Every vanilla Slowed/Immobilized-
# applying buff found above (Pin, Titan Snare, Defense Net, Transfix, Maze) applies ONLY that one
# status and nothing else mechanical, so nothing is observed to be lost beyond the condition the
# card promises to clear - but a future buff that bundled Immobilized with, say, an unrelated stat
# penalty would lose that too. Flagged here rather than guarded against, because no vanilla case
# exists to design the guard against and the card's own text has no opinion on it.
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
## Then the buff-carried half of the same status (see the header's FIX note) - the two sets are
## independent (a StatusCondition and a Buff.applies_statuses entry for the same status can coexist),
## so both are always checked rather than one short-circuiting the other.
func _clear_if_not_self_inflicted(activation:EventCore, unit:Unit, status_type:StringName) -> void:
	for status_condition:StatusCondition in unit.state.statuses.duplicate():
		if status_condition.type != status_type: continue
		if status_condition.is_unit_owner(unit): continue
		if status_condition.source == StatusType.SOURCE_UNDERWATER_STATUS_KEY: continue
		UnitCondition.clear_specific_status(activation, unit, status_condition)
	_clear_buff_carried_if_not_self_inflicted(activation, unit, status_type)

## The buff-applied half: UnitCondition.get_buffs_that_apply_status (unit_condition.gd:809-817) is
## the accessor get_current_statuses itself uses for this set. Collected first and cleared in one
## UnitCondition.clear_buffs call rather than one clear_buff per hit, matching
## UnitCondition.apply_buffs's own reasoning for batching (unit_condition.gd:702-703) - and because a
## single buff whose applies_statuses names more than one of this card's three (e.g. the Minotaur's
## Maze pairs immobilized with a separate slowed buff, but nothing rules out one buff naming both)
## would otherwise have clear_buff called on it twice over the two outer-loop passes; clear_buff
## already no-ops on a buff no longer in unit.state.buffs (unit_condition.gd:968), so that repeat call
## is harmless, but collecting once per status and clearing once keeps the shape parallel to the
## StatusCondition half above.
func _clear_buff_carried_if_not_self_inflicted(activation:EventCore, unit:Unit, status_type:StringName) -> void:
	var buffs_to_clear:Array[BuffCore] = []
	for buff:BuffCore in UnitCondition.get_buffs_that_apply_status(unit, status_type):
		if buff.is_unit_owner(unit): continue
		buffs_to_clear.append(buff)
	UnitCondition.clear_buffs(activation, unit, buffs_to_clear)
