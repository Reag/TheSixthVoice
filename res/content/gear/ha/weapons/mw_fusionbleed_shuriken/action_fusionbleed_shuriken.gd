## FUSIONBLEED SHURIKEN (Koremasa rank III, design ruling 31): on a hit, "you may also make a secondary
## attack against a different character within range 5 of the target. Any further hits cannot repeat
## this effect. Attacks made this way do not cause you to take any additional heat".
##
## THE ARC PROJECTOR'S SHAPE (action_arc_projector.gd:18-53). The same weapon makes the secondary: the
## action duplicates itself for the variant, marks the copy (SECONDARY_MARK plus the first target's
## persistent id, in modified_by_variants - the only field create_duplicate_for_variant deep-copies,
## action.gd:94-99), asks for a target from a PROXY standing on the first target, and queues an
## event_unit_attack that reuses the declared summary at Priority.ATTACK.secondary_attack.
##
## WHAT THE MARK CHANGES (ruling 31):
## - range 5 FROM THE FIRST TARGET: get_target_range reads the proxy's specific, so a flat 5 there is
##   measured from where the proxy stands. The primary's own melee range would be 1.
## - never another secondary. Keyed on the mark, NOT on Action.FLAG.IS_FOLLOWUP: an auxiliary weapon
##   fired as a mount's follow-up already carries that flag (action_attack_weapon.gd:69-72) and must
##   still get its secondary.
## - no thrown-weapon spawn. The secondary is a THROW at a character up to 5 away, so its copy runs at
##   threat 0 - Lancer's thrown attack, which takes cover from the Koremasa's voxels (the summary's
##   source) and which Entrap does not count as a melee attack (ruling 14) - and on_attack skips
##   vanilla's spawn: one shuriken lands on the ground, from the throw that was actually thrown.
## - no heat: a directly queued event_unit_attack never pays self-heat (unit_action.gd:227-229).
##   Unlike the Arc Projector this queues no heat of its own.
## - "a different character": characters only, never the first target, never the Koremasa.
##
## Bonus damage is NOT suppressed (the card is silent; the Arc Projector's NO_BONUS_DAMAGE is its own).
## The secondary target is not added to all_attacked_units (vanilla). Cancelling the pick is clean.
extends ActionAttackWeapon

const SECONDARY_MARK := &'reag_fusionbleed_secondary'
## "within range 5 of the target"
const SECONDARY_RANGE := 5

static func is_secondary(action:Action) -> bool:
	return action != null and action.modified_by_variants.has(SECONDARY_MARK)

func get_target_range(specific:SpecificAction) -> int:
	if is_secondary(self): return SECONDARY_RANGE
	return super.get_target_range(specific)

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not is_secondary(self): return super.can_target_unit(potential_target, specific)
	# Fired from the proxy: judge the target as the Koremasa would, so it can never pick itself.
	var true_specific := SpecificAction.clone(specific)
	true_specific.unit = specific.unit.get_owner_unit_or_self()
	if not super.can_target_unit(potential_target, true_specific): return false
	if not potential_target.is_character(): return false
	if modified_by_variants.has(potential_target.core.persistent_id): return false # the first target
	return true

func on_attack(activation:EventCore, attacked_unit:Unit) -> void:
	if is_secondary(self): return # the throw already put a shuriken on the ground
	await super.on_attack(activation, attacked_unit)

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	await super.on_hit(activation, attacked_unit)
	if is_secondary(self): return # "Any further hits cannot repeat this effect"
	var context := activation.context
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not Unit.is_valid(attacked_unit) or not GearCore.is_valid(gear): return
	if not anyone_in_reach(unit, attacked_unit): return # nothing to ask

	var secondary:ActionAttackWeapon = context.action.create_duplicate_for_variant()
	secondary.modified_by_variants.append(SECONDARY_MARK)
	secondary.modified_by_variants.append(attacked_unit.core.persistent_id)
	secondary.threat = 0 # a throw (see the header)

	var plan := await TargetActionUtil.ask_for_targets_from_proxy(
		activation, unit, gear, secondary, attacked_unit.tile(), attacked_unit.core.get_size()
	)
	if plan.aborted or not Unit.is_valid(unit): return # "you MAY also make"
	if plan.target_units.is_empty() or not Unit.all_valid(plan.target_units): return

	var flags:Array = context.flags.duplicate()
	Util.append_nonduplicate(flags, Action.FLAG.IS_FOLLOWUP)
	activation.queue_event(&'event_unit_attack', {
		target_unit = plan.target_units.front(),
		unit = unit,
		gear = gear,
		action = secondary,
		resource = context.resource, # the declared attack
		event = context.event, # the declared-attack event
		flags = flags, # inherits e.g. AS_REACTION
	}, Priority.ATTACK.secondary_attack)

## A cheap pre-check so the player is never asked to pick from nobody: another valid character within
## range 5 of the first target. Line of sight is left to the proxy's own targeting.
static func anyone_in_reach(unit:Unit, attacked_unit:Unit) -> bool:
	for other:Unit in unit.map.get_all_units():
		if other == unit or other == attacked_unit: continue
		if not Unit.is_valid(other) or not other.is_character(): continue
		if UnitRelation.distance_between(attacked_unit, other) <= SECONDARY_RANGE: return true
	return false
