# TOE TO TOE (ruling 3): at the end of its turn, with its standard movement unspent, the Leoleth may
# Skirmish for free with a melee weapon it has not used this turn.
#
# THE RALEIGH'S FULL METAL JACKET SHAPE (content/frames/ipsn/mf_raleigh/mt_full_metal_jacket/): an
# ActionReactionSelf on end_turn at PRE, consumes_rxn false, counts_as_free_action true. The .tres
# carries all four; this script carries the two things a .tres cannot express - the movement gate and
# the weapon filter.
#
# WHY PRE. event_turn_end awaits its PRE reactions in execute_preblock (:15-17); handle_ending_unit
# zeroes current.speed and state.actions at :69-70, inside execute; the POST queue is at :46. The gate
# below reads current.speed, so PRE is the only timing at which it is anything but zero.
#
# WHY THE GATE IS A NUMBER AND NOT A FLAG (ruling 2). The engine pools standard movement and Boost
# into one budget: new_turn_refresh sets current.speed = get_speed_max() (unit_action.gd:77),
# event_unit_boost adds get_boost_speed - itself get_speed_max (unit_action.gd:474-478) - at :37, and
# only a spend_move step subtracts (event_unit_move.gd:244-245). So "has not spent any of its STANDARD
# movement" is exactly "the budget is still at least full": a Boost plus a Boost's worth of steps
# qualifies, one unboosted step does not, and a knockback never touches it at all
# (MovementType.create_for_involuntary leaves spend_move false, movement_type.gd:63-71).
# state.spaces_moved_this_turn cannot say this: it counts every katamari step, involuntary included
# (event_unit_move.gd:239).
#
# counts_as_free_action MAKES ActionReaction.is_available_to_activate REQUIRE is_taking_turn
# (action_reaction.gd:48) - which END_TURN PRE still satisfies, because handle_ending_unit does not
# clear is_taking_turn until :64, inside execute.
#
# THE OFFER GOES THROUGH CommonActionUtil.choose_and_use, which supplies AS_FREEBIE and
# TARGETS_ARE_MANDATORY itself (common_action_util.gd:693-696) and, for a player-controlled unit with
# exactly one option, picks it without raising a menu (:658-659). The "may" is then the chosen
# weapon's own targeting screen, which the player can back out of. The spend callable is
# choose_and_use_no_spend (design 1.2): this reaction costs nothing, so there is nothing to defer.
#
# NO VARIANT ACTIONS. action_predator_prey_concepts.gd expands each weapon through
# VariantActionGroup.get_variant_specifics (:29) so a thrown profile can be picked; ruling 3 names
# only "an ActionAttackWeapon that is MELEE and QUICK", and a thrown variant of a melee weapon has
# threat 0 and is a ranged attack the 43 As would penalise. Deliberately out.
extends ActionReactionSelf

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# "has not spent any of its standard movement" - ruling 2.
	if unit.core.current.speed < unit.get_speed_max(): return false
	# "with a melee weapon that has not been used this turn" - and one has to exist.
	return not eligible_attacks(unit).is_empty()

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var eligible:Array[SpecificAction] = eligible_attacks(unit)
	if activation.abort_when(eligible.is_empty()): return
	await CommonActionUtil.choose_and_use(
		activation,
		SpecificAction.from_context(context),
		eligible,
		CommonActionUtil.choose_and_use_no_spend,
	)

## Every Skirmish this unit could make right now, by the card's five clauses. PUBLIC so
## spec/test_toe_to_toe.gd can read the offer at its source: the pick menu is a ChoiceBus.TYPE.gear
## request that testkit/prompt_watcher.gd does not report, and with one eligible weapon no menu is
## raised at all.
func eligible_attacks(unit:Unit) -> Array[SpecificAction]:
	var eligible:Array[SpecificAction] = []
	if not Unit.is_valid(unit): return eligible
	# get_all_weapons is integrated weapons plus mounts and NO basics (loadout_core.gd:521-525), which
	# is the card's "a melee weapon" - the basic improvised attack is not one.
	for weapon:GearCore in unit.core.loadout.get_all_weapons():
		if not GearCore.is_valid(weapon): continue
		if weapon.is_destroyed: continue
		for action:ActionAttackWeapon in weapon.kit.get_weapon_actions():
			var specific := SpecificAction.create(unit, weapon, action)
			# MELEE, by the engine's own predicate (unit_action.gd:549-553).
			if not UnitAction.is_melee_weapon(action, weapon): continue
			# QUICK: a SUPERHEAVY reports FULL and needs Barrage, which is not a Skirmish
			# (action_attack_weapon.gd:87-91).
			if action.get_action_type(specific) != Lancer.ACTION.QUICK: continue
			# "has not been used this turn", per USAGE GROUP (gear_core.gd:183-188).
			if weapon.get_uses_this_turn(action) > 0: continue
			# AND THE ENGINE HAS TO AGREE THIS PROFILE CAN SWING, or the menu offers an entry that
			# event_gear_activate.gd:46-50 then refuses with "[ Gear not available ]" and the free
			# Skirmish is simply lost. as_freebie = true is the form choose_and_use will use
			# (common_action_util.gd:693-696): it skips the per-turn limit at unit_action.gd:114, which
			# the usage-group clause above already covers, while every blanket refusal in
			# get_gear_unavailable_reason (:131-160) still applies - including REASON.NO_CHARGES at :153,
			# which is what an empty Thermal Death Axe's Thunderous profile answers.
			if not UnitAction.is_gear_available(specific, true): continue
			# And it has to be able to reach something, or this is an empty targeting screen at the
			# end of every turn (action_predator_prey_concepts.gd:36's filter).
			if UnitTargeting.get_tiles_targetable(specific).is_empty(): continue
			eligible.append(specific)
	return eligible
