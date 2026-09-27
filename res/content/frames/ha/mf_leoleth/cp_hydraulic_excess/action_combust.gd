# COMBUST (ruling 12), RAGE's face 4:
#
#   "Choose a blast 1 area within line of sight and SENSORS. All characters at least partially within
#    the area must succeed a Hull save or take 2d6 Kinetic damage and be knocked Prone."
#
# An ActionSystemApplyStatus with TWO overrides: the target filter ("character" is is_character(), a
# drone included - rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22) and the
# damage (apply_additional_effect, the archetype's own hook).
#
# THE FILTER IS NOT COSMETIC. A non-character AUTO-FAILS every forced save without rolling
# (unit_hasecheck.gd:52-53), so without it every deployable standing in the blast would be Proned and
# take 2d6 with no roll at all. A drone is NOT excluded by this filter - a drone is a character
# (2026-09-27) and rolls its save like any other target in the blast. can_target_unit is consulted by
# the AoE sweep at :65 as well as by targeting, which is why narrowing it there is enough.
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

## Set by action_rage_roll.offer_combust for the length of the offer and cleared straight after, so
## this action is activatable ONLY while face 4 is actually being resolved. It lives HERE, on the
## action it gates, and the roll preloads this script to read it - one source of truth rather than
## the Vauban's duplicated FIELD_STATE_KEY (action_grav_amped_interference.gd:73 and
## action_grav_amped_shock.gd:101), which is two strings that must be kept in step by hand.
##
## A String, NOT a StringName. GearCore.state is a plain Dictionary and get_state does no
## normalising, so a StringName key would never match a String one - the Vauban's own note at
## action_grav_amped_interference.gd:45-46 is about exactly that trap.
const OFFER_STATE_KEY := 'combust_offered'

func show_in_tooltip(_kit:Kit) -> bool: return false

## NOT A PLAYER-INITIATED ACTION, and before this override it was one. Combust is the only action on
## cp_hydraulic_excess that is neither an ActionReaction nor a protocol, so it is the only one that
## reaches gear_bar.collect_gear_actions' admission test (gear_bar.gd:143-150) - and with
## hide_if_disabled unset and is_available_to_activate defaulting to true (action.gd:175-176) it had
## a permanent hotbar button that ran the whole card with no RAGE anywhere. Reported from playtest
## 2026-09-22.
##
## PAIRED WITH hide_if_disabled = true IN THE .tres. Together they are what removes the button:
## gear_bar drops an action only when hide_if_disabled is set AND the gear is unavailable. Returning
## false here without that flag would leave the button on the bar, merely greyed out.
##
## WHY NOT A FLAT `return false`, which would read more simply: the legitimate offer would refuse
## too. event_gear_activate.gd:50 ends in UnitAction.can_activate_gear, which consults this very
## method (unit_action.gd:156 -> REASON.SPECIFIC), and choose_and_use reaches that same re-check. The
## window has to be open while the roll is resolving face 4 and shut the rest of the time.
##
## WHY NOT is_situationally_activated, which also hides it: that flag means "usable by a unit other
## than the one holding it" (action.gd:45-46) and it is read by the AI decider (ai_action_decider.gd:75)
## and the kit card (kit.gd:229). It would hide the button by telling the engine something untrue.
func is_available_to_activate(_unit:Unit, gear:GearCore) -> bool:
	if not GearCore.is_valid(gear): return false
	return bool(gear.get_state(OFFER_STATE_KEY, false))

## "All CHARACTERS at least partially within the area" - is_character(), a drone included
## (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22).
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	return potential_target.is_character()

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
