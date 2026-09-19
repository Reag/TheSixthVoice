## The Rend Axe's free swing: "1/round, you may expend a charge to attack with this weapon as a free
## action during your turn."
##
## ONE OVERRIDE, AND THREE THINGS THAT DELIBERATELY ARE NOT OVERRIDES.
##
## get_action_type is the override. Lancer.ACTION.FREE is a real value (lancer.gd:27) with a cost of
## 0 (lancer.gd:31), and ActionAttackWeapon's own implementation derives the type from weapon_size
## (action_attack_weapon.gd:87-91), returning QUICK for anything that is not SUPERHEAVY - so a Main
## weapon has no way to be free except by saying so here.
##
## NOT OVERRIDDEN 1: consumes_charges. The default is true (action.gd:108), which is exactly what
## this profile wants and is the one difference from its sibling action_rend_axe.gd. It buys both
## halves at once: unit_action.gd:153 refuses the activation with REASON.NO_CHARGES on an empty axe,
## and unit_action.gd:275 spends the charge. Note that line sits OUTSIDE the freebie block, under the
## comment "but freebies still expend charges", so even an AS_FREEBIE activation pays.
##
## NOT OVERRIDDEN 2: get_per_round_hard_limit. action.gd:156-158 already returns 1 for a naturally
## free action, so the card's "1/round" is the engine's default and an override here would be an
## inert line that reads as load-bearing. test_rend_axe.gd asserts the engine's answer instead, so a
## change to that default goes red rather than quietly uncapping this weapon.
##
## NOT OVERRIDDEN 3: "during your turn". A free action is only offered inside the acting unit's own
## turn to begin with, and the card names no reaction window, so there is nothing to gate.
##
## THE usage_group IN THE .tres IS THE LOAD-BEARING PART OF THIS PROFILE, not this script.
## GearCore.get_usage_group_for_action falls back to kit.compcon_id when an action leaves it empty
## (gear_core.gd:166-168), so two actions on one Kit share BOTH counters by default. Sharing the
## per-round counter would be merely wrong; sharing the per-TURN counter is worse, because
## unit_action.gd:281 increments it for a player-pressed action and the ordinary attack's soft limit
## is 1 (action.gd:161-163) - so a shared group makes the free swing silently forbid the ORDINARY
## swing for the rest of the turn. The failure lands on the other button, which is why
## test_the_free_attack_does_not_use_up_the_ordinary_attack exists and why this task is flagged J.
extends ActionAttackWeapon

func get_action_type(specific:SpecificAction) -> Lancer.ACTION: return Lancer.ACTION.FREE
