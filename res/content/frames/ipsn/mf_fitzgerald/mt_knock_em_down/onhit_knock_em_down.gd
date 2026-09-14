## The knockdown itself. The statuses/save wiring is declarative on the .tres; the only reason this
## script exists is to spend the trait's 1/round.
##
## RULING 15 (2026-09-13): the round is spent by FORCING the save, pass or fail - the trigger is the
## crit, not the knockdown. So the increment happens here, before super() rolls the save, exactly as
## Crack Shot III increments before it calls UnitHasecheck.make_save. Incrementing in on_crit()
## instead would spend the round only on a FAILED save, because a passed save makes should_abort
## return true and on_crit is never reached.
##
## THE CHARACTER GATE (review finding 1, 2026-09-13): "critically hits A CHARACTER" per the design
## doc and the shipped localization row, but event_unit_attack.gd never filters on is_character()
## before apply_on_crits runs - it only checks it two lines later, for the crit bark
## (`if target_unit.is_character(): await UnitBark.play_for(...)`). apply_on_crits is reached for
## ANY valid target unit, so without the explicit attacked_unit.is_character() check below, a Cannon
## crit on a destructible object or other non-character unit would still spend the 1/round and force
## a Hull save that can do nothing (Prone has no effect on a non-character).
##
## THE BOOKKEEPING FLAG (whole-branch review, 2026-09-13). increment_action_usage's second argument,
## increment_per_turn_counter, is passed false here to match the Fitzgerald's other 1/round trait,
## Blasting Powder. The full reasoning is stated ONCE, above activate() in
## mt_blasting_powder/action_blasting_powder_spend.gd, and in short: the flag gates only the
## uses_this_turn tally (gear_core.gd:173-177 - uses_this_round and uses_this_scene are written
## either way), this trait's limit is the per-ROUND counter read by buff_knock_em_down, and nothing
## consults a per-turn count under &'knock_em_down'. It was true before this change too: the per-turn
## soft limit at unit_action.gd:168 asks per-ACTION, against the usage group of the action being
## taken (the Cannon's), never this trait's key - so the tally that used to be written here was a
## third counter nobody read. Inert either way; two sibling traits on one frame doing identical
## bookkeeping two different ways is the thing being fixed, since whichever shape this frame ships is
## the one nineteen more frames copy.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_knock_em_down'
const USAGE_KEY:StringName = &'knock_em_down'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if (
		stage == apply_on and Unit.is_valid(attacked_unit) and attacked_unit.is_character() and
		Unit.is_valid(activation.context.unit)
	):
		var trait_gear:GearCore = activation.context.unit.get_gear(TRAIT_ID)
		if GearCore.is_valid(trait_gear): trait_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)
