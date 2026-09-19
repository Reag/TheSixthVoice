## The Rend Axe's ordinary swing: a Quick attack that neither needs nor spends a charge.
##
## "You may attack with this weapon without expending or requiring charges" (ruling 14). Both halves
## of that sentence are ONE override, because the engine reads one answer for both purposes:
##   - unit_action.gd:153 -- `elif action.consumes_charges(specific) and not gear.has_charges_left():
##     reason = REASON.NO_CHARGES` -- the REQUIRING half.
##   - unit_action.gd:275 -- `if action.consumes_charges(specific): gear.spend_charge()`, the only
##     call to spend_charge in the engine -- the EXPENDING half.
## Answering false disables both, and nothing else changes: the Kit still shows 3/3 on the gear bar,
## and Task 2's free profile still spends them.
##
## EVERYTHING ELSE IS DATA. The dice, the AP and Thrown tags, the threat, the thrown range and the
## on-hit effect are all exports ActionAttackWeapon already has, and live in action_rend_axe.tres.
## This script exists for the one clause the resource format cannot express - the same reason
## action_rapier_carronade.gd exists on the Fitzgerald.
##
## CONTEXT IS IGNORED, AND THAT IS DELIBERATE. UnitAction asks this question at two different moments
## with two different SpecificActions (the availability scan and the spend), and an answer that
## varied by context could let the two disagree - the weapon reading as available and then eating a
## charge anyway.
extends ActionAttackWeapon

func consumes_charges(specific:SpecificAction) -> bool: return false
