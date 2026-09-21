## CROWN OF RESTLESS DEAD, the second half of TWILIGHT SWARM (SP3 Task 4, design rulings 7 and 21).
##
##   "Free: An allied character within sensors gains OVERSHIELD equal to your OVERSHIELD, then you
##    take that much Energy damage. This damage cannot be prevented in any way. You may only take
##    this action 1/round."
##
## THE TRANSFER IS THE FICTION AND THE SOAK IS WHAT MAKES IT ONE. The self-damage carries
## [SELF_INFLICTED, NO_REDUCE] - Mathur Stop's own pair (action_mathur_stop.gd:19-24) - so armor,
## resistance and damage caps are all skipped: damage_modifications.gd:59 returns before any of them
## on that flag. But the Sluagh's OWN Overshield still absorbs it, because the soak lives inside
## damage() (event_unit_damage.gd:215-218) and is unconditional - it sees every flag alike. So the
## mech ends at 0 shield and FULL HEALTH, having handed the shield over rather than having bled for
## it. Ruling 7. Immunity, halving and Exposed still apply, which is narrow and recorded.
##
## THE ORDER IS THE CARD'S "then", AND IT IS ONE LINE OF CARE: `amount` is read ONCE, before anything
## moves. Read it after the grant and it would still be the Sluagh's own value (the grant goes to the
## TARGET), but read it off the target - the obvious "give them what they now have" slip - and an ally
## already above the amount would cost the Sluagh the ALLY'S total instead of its own.
## test_crown_grants_nothing_extra_to_an_ally_already_above_it_and_still_costs_the_sluagh is the pin,
## and it is arranged so the two readings differ.
##
## ActionSystemTargetUnit.activate already asks for targets, aborts without a plan, spends the
## action, runs the FXGs, re-checks the units and then calls activate_for_target once per target.
## Its can_target_unit enforces requires_target_character, can_target_allies and can_target_enemies,
## and can_target_unit_self returns can_target_self - all four of which this card sets in its .tres
## rather than in code.
##
## AN ALLIED DRONE IS NOT A LEGAL TARGET, AND THAT TAKES ONE OVERRIDE - REVERSING THIS CARD'S OWN
## SP3 RULING (author, 2026-09-21, at the frame close). requires_target_character is
## `potential_target.is_character()` (action_system_target_unit.gd:16) and Unit.is_character() is
## TRUE of a drone ("active mech/pilot/drone", unit.gd:116), so the flag admits one. "Character" on
## this frame, and across this mod, is `is_actor()` (:117): ruling 194 (the Vauban's Gravity Well
## shelters allied MECHS), rulings 64 and 70 (a drone's shot counts as its OWNER'S) and ruling 269
## (the Stealing). The canonical paragraph is in
## res/content/frames/horus/mf_sluagh/mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd.
## The SP3 ruling reasoned from the archetype's default and from vanilla's habit; the author has
## chosen the mod's own consistency over both, knowing it reverses them.
##
## can_target_unit IS THE RIGHT SEAM AND THE ONLY ONE. It is UnitTargeting's additional filter when
## the player picks (action.gd:214), AND it is what filters a target supplied straight to the plan
## (target_action_util.gd:172) - so a spec or an AI handing the action a drone by hand is refused
## too. The .tres flag stays on as the cheap first gate: it refuses objects and markers for free.
##
## THE 1/ROUND IS THE ENGINE'S AND THE USAGE GROUP IS OURS. Action.get_per_round_hard_limit returns 1
## for any FREE action (action.gd:156-158), so the card's limit costs no code. But the tally is kept
## per USAGE GROUP, and GearCore.get_usage_group_for_action falls back to the KIT ID when an action
## names none (gear_core.gd:166-168) - so without the usage_group on this action's .tres, ONE
## Damnation of the Host would fill this action's single slot for the round and the Crown would be
## refused. The design says "own usage group" without saying why; that is why.
## test_a_damnation_does_not_consume_crowns_one_per_round is the pin.
##
## RULING 3, AND IT IS PROVISIONAL: THIS ACTION SPENDS NO CHARGE. The card does not say which of the
## two actions the LIMITED 3 covers and the author has asked //Bela//. `consumes_charges` is a
## FUNCTION on Action (action.gd:108), not an export, so the exemption cannot live in the .tres -
## it is the one-line override below, which is exactly the "one line to flip" ruling 3 promises.
extends ActionSystemTargetUnit

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')


## RULING 3. See the header - if the ruling reverses, delete this function.
func consumes_charges(specific:SpecificAction) -> bool: return false


## "an allied CHARACTER", narrowed from the archetype's is_character() to the mod's is_actor(). See
## the header; test_crown_cannot_crown_an_allied_drone is the pin.
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super(potential_target, specific): return false
	return potential_target.is_actor()


## "gains OVERSHIELD equal to YOUR OVERSHIELD" - with none, there is nothing to hand over and no
## action to offer. UnitAction.can_activate_gear calls this (action.gd:175), so the button is dead
## rather than merely wasteful.
func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return Overshield.has(unit)


func activate_for_target(context:Context, activation:EventCore, target_unit:Unit) -> void:
	var unit:Unit = context.unit
	var specific := SpecificAction.from_context(context)

	# READ ONCE, BEFORE ANYTHING MOVES. See the header.
	var amount:int = Overshield.current(unit)
	if amount <= 0: return

	await Overshield.grant(activation, target_unit, amount)

	# Mathur Stop's flags and Mathur Stop's helper. queue_damage_events adds SELF_INFLICTED itself
	# when the target is the actor (common_action_util.gd:91); it is passed explicitly anyway, as that
	# card does, so the intent is on the page rather than inferred from a coincidence.
	CommonActionUtil.queue_damage_events(
		activation, specific, [unit], amount, Lancer.DAMAGE_TYPE.ENERGY,
		[EventService.DAMAGE_FLAG.SELF_INFLICTED, EventService.DAMAGE_FLAG.NO_REDUCE]
	)
