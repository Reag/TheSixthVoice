## ENTRAP'S WATCHER (design 1.4, ruling 16): when the Koremasa successfully hits a hostile character
## with a TECH attack, hang buff_entrap_mark on them, stamped with the round.
##
## An ActionReactionAttacked on ATTACK POST with the .tres doing the filtering: ATTACKER, ENEMIES,
## require_hit, allow_weapon = false, allow_tech = true, and allow_basic = TRUE - the vanilla Invade
## (ms_fragment_signal) is basic gear and is the tech attack every mech carries. An auto-hit counts
## (roll.hit). Lock On is not a tech attack (action_lock_on.gd:2), so it never gets here.
##
## "HOSTILE CHARACTER" is is_actor() (rulings row 301): the archetype's is_character() check is off
## in the .tres and this file tests is_actor().
##
## NOT A REACTION POINT and not limited: every tech hit re-marks, and a re-mark replaces the old one
## from the same gear (unit_condition.gd:741-747) with a fresh stamp. Spent anyway, so the tally is
## honest - it has no limit to bite. NO PROMPT. HIDDEN from the card by localization_key_override.
extends ActionReactionAttacked

const MARK_ID := &'buff_entrap_mark'

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var defender:Unit = triggering_event.context.target_unit
	return Unit.is_valid(defender) and defender.is_actor()

func activate(context:Context, activation:EventCore) -> void:
	var defender:Unit = context.event.context.target_unit
	if activation.abort_without_unit(defender): return
	spend_actions(activation)
	apply_buff_id(activation, defender, MARK_ID) # from_gear = mt_entrap on this Koremasa (action.gd:375)
