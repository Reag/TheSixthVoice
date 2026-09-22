# COMBUST (ruling 12), RAGE's face 4:
#
#   "Choose a blast 1 area within line of sight and SENSORS. All characters at least partially within
#    the area must succeed a Hull save or take 2d6 Kinetic damage and be knocked Prone."
#
# An ActionSystemApplyStatus with TWO overrides: the target filter (every "character" on this frame
# is is_actor(), ruling 22) and the damage (apply_additional_effect, the archetype's own hook).
#
# THE FILTER IS NOT COSMETIC. A non-character AUTO-FAILS every forced save without rolling
# (unit_hasecheck.gd:52-53), so without it every deployable and every drone standing in the blast
# would be Proned and take 2d6. can_target_unit is consulted by the AoE sweep at :65 as well as by
# targeting, which is why narrowing it there is enough.
#
# THE DAMAGE GOES THROUGH apply_additional_effect, which the archetype calls ONLY for a failed save
# and BEFORE the statuses land (:96-101, and its own comment says so). 2d6 is rolled fresh per
# target, which is the card.
#
# THE SAVE'S FORCER IS THE LEOLETH, and that comes for free: does_target_make_save hands
# UnitHasecheck.make_save the SPECIFIC (:82), whose unit is the Leoleth.
#
# THE BLAST IS ON target_requirements_override IN THE .tres, NOT on this archetype's own
# range_pattern export - that export is read by nothing. activate calls
# get_range_pattern_for_targets (:59), which is Action's and returns
# get_target_requirements(specific).range_pattern (action.gd:204-206), and this archetype's
# get_target_requirements (:22-27) never copies its export in.
#
# apply_to_self IS FALSE in the .tres, against ruling 12's letter, because TRUE makes the whole
# action self-only with no tile pick (:35, :26, :47-50). The Leoleth is caught by its own blast
# regardless: the AoE sweep filters with UnitRelation.can_affect (map_state.gd:319-320), which has no
# self clause.
extends ActionSystemApplyStatus

const BLAST_DAMAGE := '2d6'

func show_in_tooltip(_kit:Kit) -> bool: return false

## "All CHARACTERS at least partially within the area" - is_actor(), the mod-wide rule (ruling 22).
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	return potential_target.is_actor()

## "...or take 2d6 Kinetic damage". Runs only for a FAILED save (:96-101).
##
## THE UNIT, NOT THE SPECIFIC, is handed to queue_damage_events: passing the specific would copy
## `gear` and `action` onto the damage event (common_action_util.gd:97-99), and the card names no
## weapon. generate_damage_events builds an empty SpecificAction with only `unit` set when it is
## handed a Unit (:81-82), so `target_unit` still records who did it.
func apply_additional_effect(specific:SpecificAction, target_unit:Unit, activation:EventCore) -> void:
	if not Unit.is_valid(target_unit): return
	CommonActionUtil.queue_damage_events(
		activation, specific.unit, [target_unit] as Array[Unit],
		Dice.roll_string(BLAST_DAMAGE),
		Lancer.DAMAGE_TYPE.KINETIC
	)
