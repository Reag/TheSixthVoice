## DAMNATION OF THE HOST, the first half of TWILIGHT SWARM (SP3 Task 3, design ruling 20).
##
##   "Quick Tech: You gain OVERSHIELD equal to 1d6+GRIT"
##
## SELF-TARGETING, AND THAT IS THE ARCHETYPE'S DEFAULT RATHER THAN SOMETHING THIS FILE ARRANGES.
## ActionSystem.get_target_requirements returns reqs.count = 0 when no override is set, which is the
## engine's "applies to self" - so there is no targeting code here at all, and no CompconPlan. The
## body is vanilla's action_scan.gd minus its target: spend, run the FXGs, re-check the unit, act.
##
## THE abort_without_units RE-CHECK IS NOT CEREMONY. run_system_fxgs awaits real FX, and an await
## inside an activation is a window in which a reaction can kill the actor. Every vanilla ActionSystem
## that awaits its FXGs makes this check afterwards; the helper would answer 0 for a dead unit rather
## than throw, but the log line and the popcorn would still be wrong.
##
## THE HELPER IS PRELOADED, NOT NAMED. overshield.gd declares no class_name on purpose - a global
## class name is registered from project.godot's class list, built at startup, so one declared in a
## script a mod loads at runtime is never registered. Every consumer preloads it; see its header.
##
## roll_d6() + grit() IS ONE EXPRESSION AND THE ORDER MATTERS FOR SPECS, not for play: the d6 pops
## from the same global FIFO as an attack roll (dice.gd:33-35, :90), so a spec's queue for this
## action is exactly one entry long.
##
## RULING 25: A GRIT-0 PILOT STILL GAINS THE D6. Overshield.grant is a no-op at amount <= 0 and a
## Grit-sized grant elsewhere on this frame really does hit that path, but it cannot here - a d6 is
## never less than 1. test_damnation_at_grit_zero_still_grants_the_d6 is the pin, and it is the
## discriminating half of the Grit assertion: without it, deleting `+ Overshield.grit(unit)` would
## redden only one test and might read as a fixture problem.
##
## RULING 3, AND IT IS PROVISIONAL: THIS ACTION SPENDS A CHARGE and the Crown does not. That is the
## archetype default (Action.consumes_charges returns true, action.gd:108), so it is the ABSENCE of
## an override here and the PRESENCE of one on action_crown_of_restless_dead.gd. The card does not
## say which actions the LIMITED covers; the author has asked //Bela//. If the answer reverses it,
## the change is to move the override, not to touch this file's logic.
extends ActionSystem

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')


func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit

	spend_actions(activation)
	await run_system_fxgs(unit)
	if activation.abort_without_units([unit]): return

	await Overshield.grant(activation, unit, Dice.roll_d6() + Overshield.grit(unit))
