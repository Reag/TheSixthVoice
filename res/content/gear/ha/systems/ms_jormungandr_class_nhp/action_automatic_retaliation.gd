# THE AUTOMATIC RETALIATION (Leoleth rank III, design ruling 17):
#
#   "Whenever you take damage from a hostile character for the first time each round, you
#    automatically retaliate, and must immediately attack the closest character -hostile or allied-
#    within Threat with a non-Superheavy melee attack as a reaction. If there are more than one
#    characters tied for closest, you attack one at random."
#
# THE BERSERKER'S AGGRESSION IS THE MODEL (content/frames/npc/npcc_berserker/aggression/
# action_aggression_berserker.gd): a DAMAGE reaction at Priority.DAMAGE.counterattack that excludes
# heat and queues a mandatory-target attack. It differs in the three ways the card names - THREAT
# rather than adjacency, CLOSEST rather than random, and a REAL reaction rather than a free one.
#
# THE 1/ROUND IS THE ENGINE'S AND IS NOT WRITTEN HERE. ActionReaction.get_per_round_hard_limit
# already returns 1 when consumes_rxn is set (action_reaction.gd:69), which is the card's "for the
# first time each round"; the Berserker overrides it only because ITS reaction is consumes_rxn
# false, where the limit would otherwise be 99. Overriding it here would be an inert line that reads
# as load-bearing (memory lancer-tactics-reactions-and-usage).
#
# THE USAGE GROUP ON THE .tres IS NOT COSMETIC. get_usage_group_for_action falls back to the KIT id
# when an action names none (gear_core.gd:166-168), and UnitAction.spend records under that group -
# so with the groups blank, pressing either PROTOCOL would silently spend this reaction's whole
# round with no log line.
#
# THE CHIP IS THE AVAILABILITY GATE, checked super-FIRST so the reaction economy still has the final
# word. is_available_to_activate is not UI-only: event_gear_activate.gd:51 calls can_activate_gear,
# so this is what makes "while the A.R.C systems are active" true of the mechanism and not only of
# the button.
#
# NO CONFIRM PROMPT. The card says "automatically" and "must", so unlike vanilla's Warp Shield there
# is no CommonActionUtil.confirm_use here and no way to decline: the only decision left to the
# player is WHICH melee weapon, and choose_and_use is called with can_voluntarily_cancel FALSE so
# the targeting screen cannot be backed out of either.
#
# THE DAMAGER IS READ OFF THE TRIGGERING EVENT, NOT OFF THE ACTIVATION. triggers_on_event is handed
# the triggering EventCore, but activate's own context is the gear-activation one; that is why the
# damager clause lives entirely in triggers_on_event and activate re-derives only the TARGET, from
# the board.
#
# WHY THE TARGET IS PICKED TWICE. triggers_on_event picks one to prove a candidate exists (no
# candidate, no offer, and the point is never at risk); activate picks again because the board may
# have moved between the trigger check and the queued execution. A tie therefore rolls twice and
# only the second roll decides - which costs nothing, because both draws are from the same tied set.
extends ActionReaction

const CHIP := &'buff_arc'

func get_priority() -> int: return Priority.DAMAGE.counterattack

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return UnitCondition.has_buff(unit, CHIP, gear.persistent_id)

# DAMAGE event, POST
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	# were WE the one damaged?
	if context.unit != unit: return false
	# heat is not damage for this card - the Berserker excludes it the same way (:20)
	if context.category_int == Lancer.DAMAGE_TYPE.HEAT: return false
	# "whenever you TAKE damage": a hit armor ate whole is not damage taken. The engine does NOT
	# give this one free - event_unit_damage.gd:86-87 aborts on capped_damage, which armor never
	# lowers, so a fully-absorbed hit still arrives at the POST queue with context.number == 0.
	# buff_rage_hatred.gd's header carries the measurement.
	if context.number <= 0: return false
	# "from a hostile character"
	if not Unit.is_valid(damager(context, unit)): return false
	# "the closest character ... within Threat" - with nobody in reach there is nothing to retaliate
	# with, and the reaction must not be offered at all, or a spent point would buy nothing.
	return Unit.is_valid(pick_target(unit))

func activate(context:Context, activation:EventCore) -> void:
	var leoleth:Unit = context.unit
	if activation.abort_when(not Unit.is_valid(leoleth)): return
	var target:Unit = pick_target(leoleth)
	if activation.abort_when(not Unit.is_valid(target)): return
	var eligible:Array[SpecificAction] = eligible_attacks(leoleth, target)
	if activation.abort_when(eligible.is_empty()): return

	spend_actions(activation) # the reaction point is this card's whole price

	await CommonActionUtil.choose_and_use(
		activation,
		SpecificAction.from_context(context),
		eligible,
		# The point is already spent above; the chosen weapon must cost nothing of its own.
		CommonActionUtil.choose_and_use_no_spend,
		target, # mandatory - choose_and_use adds TARGETS_ARE_MANDATORY itself for a target unit
		[],
		false,
		&'',
		false, # "MUST immediately attack" - there is no backing out
	)

## The hostile CHARACTER responsible for a damage event, or null. buff_rage_hatred.gd's damager()
## verbatim, and deliberately so: the two cards ask the same question of the same event, and the
## mod-wide rule (design ruling 22) is that a drone's hit is its owner's.
func damager(context:Context, holder:Unit) -> Unit:
	if not Unit.is_valid(context.target_unit): return null
	var them:Unit = context.target_unit.get_owner_unit_or_self()
	if not Unit.is_valid(them): return null
	if not them.is_character(): return null
	if not UnitRelation.are_enemies(holder, them): return null
	return them

## Every character this Leoleth could answer right now: an ACTOR (ruling 22) other than itself, of
## ANY faction - "hostile or allied" - that at least one eligible weapon can reach.
##
## PUBLIC, so spec/test_automatic_retaliation.gd can read the candidate set at its source rather
## than inferring it from who bled.
func candidates(leoleth:Unit) -> Array[Unit]:
	var found:Array[Unit] = []
	if not Unit.is_valid(leoleth): return found
	for other:Unit in leoleth.map.get_all_units():
		if not Unit.is_valid(other) or other == leoleth: continue
		if not other.is_character(): continue
		if eligible_attacks(leoleth, other).is_empty(): continue
		found.append(other)
	return found

## The closest candidate, one of the tied at random. Null when there is none.
func pick_target(leoleth:Unit) -> Unit:
	var closest:Array[Unit] = []
	var best:int = -1
	for other:Unit in candidates(leoleth):
		var distance:int = UnitRelation.distance_between(leoleth, other)
		if best < 0 or distance < best:
			best = distance
			closest = [other]
		elif distance == best:
			closest.append(other)
	return closest.pick_random() if not closest.is_empty() else null

## Every non-Superheavy melee attack this Leoleth could make against `target` at Threat.
##
## UnitRelation.get_weapons_that_can_react_against IS the engine's own "can any of my weapons reach
## them as a reaction" (unit_relation.gd:227-252): it walks get_all_weapons (integrated plus mounts,
## no basics), asks each profile's own can_target_unit, measures against threat_distance rather than
## range, and checks line of sight where the profile needs it.
##
## AND IT ALREADY ANSWERS "NON-SUPERHEAVY". Its inner is_weapon_available_as_a_rxn (:293-299)
## refuses a SUPERHEAVY profile by name and calls UnitAction.is_gear_available(specific, true)
## itself - the same as_freebie form this offer would have used. MEASURED 2026-09-22: a hand-written
## Superheavy filter and a hand-written availability clause both stood here, and neutralising either
## reddened NOTHING, because the engine had already refused. Both were removed rather than left as
## inert lines that read as load-bearing; spec/test_automatic_retaliation.gd keeps the two Superheavy
## tests, which now pin that engine behaviour as the dependency it is.
##
## So the ONE word this card adds is MELEE.
##
## PUBLIC for the spec, exactly as action_toe_to_toe.gd's eligible_attacks is.
func eligible_attacks(leoleth:Unit, target:Unit) -> Array[SpecificAction]:
	var eligible:Array[SpecificAction] = []
	if not Unit.is_valid(leoleth) or not Unit.is_valid(target): return eligible
	for specific:SpecificAction in UnitRelation.get_weapons_that_can_react_against(leoleth, target):
		if not SpecificAction.is_valid(specific): continue
		if not GearCore.is_valid(specific.gear) or specific.gear.is_destroyed: continue
		var weapon := specific.action as ActionAttackWeapon
		if weapon == null: continue
		# MELEE, by the engine's own predicate (unit_action.gd:549-553). This is the ONLY clause
		# this card has to add.
		if not UnitAction.is_melee_weapon(weapon, specific.gear): continue
		eligible.append(specific)
	return eligible
