## RITUAL OF THE FIRST GOD (the Six Sky's core power; design 2.2, rulings 15-20):
##
##   "You may immediately teleport to a free space within Range 50 and make attacks against all Hostile
##    characters within Range 5 with your DAYKEEPER CYCLER BOW. All characters successfully hit this way
##    must succeed on a Systems save or become Slowed until the end of their next turn. Attacks made this
##    way do not generate Heat."
##
## THE ORDER: spend (the Full action and the core power, whatever follows - with no hostile in range it
## is still a legal use, ruling 20); the optional teleport; the scope buff; the target list; one bow
## attack per target; the scope off; then the recorded crits.
##
## THE TELEPORT (ruling 15) is the Koremasa's Vanish shape: the helper's PREVENTABLE route over every
## free space within 50, NO line of sight (the mod's standing teleport reading), and "may" is the
## picker's cancel. Immobilized or a ban leaves no space, and the Six Sky attacks from where it stands.
##
## THE TARGETS (ruling 16, the author's) are ONE list, taken once after the teleport: every hostile
## CHARACTER (Unit.is_actor - no drone, no deployable) within 5, closest first, ties by persistent id.
## Before each shot a target is skipped if it is dead, or if the bow cannot attack it (the engine's own
## targeting: range, line of sight). Nobody is added mid-sequence.
##
## EACH SHOT IS ITS OWN DECLARED ATTACK, fired as a freebie at a mandatory target with the player's
## decisions skipped - Rage Roll's awaited event_gear_activate - plus NO_SELF_HEAT, which is both "no
## heat" for the bow (action_daykeeper_cycler_bow.gd) and the mark the scope buff gates on. Being
## separate attacks, nothing is halved, and Heavenly Weaver's 1d6 goes to the first hit alone.
##
## THE CRITS RESOLVE AFTER THE RITUAL (ruling 17, the author's): the bow records each on the scope, and
## the records are resolved here one by one, in attack order, after the scope is gone - so every Ritual
## attack is fired from the Ritual's space, and a self-teleport from one crit moves the origin of the
## next. A recorded target that has since died is offered as "yourself" only.
##
## THE SCOPE COMES OFF ON EVERY EXIT. GDScript has no finally, so the shots run in their own function
## and the single clear follows it whether that function finished the list or left early because the
## Six Sky died.
extends ActionSystem

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Bow := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/cp_ors_daykeeper_cycler_bow/action_daykeeper_cycler_bow.gd')
const Scope := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/cp_ors_daykeeper_cycler_bow/buff_ritual_of_the_first_god.gd')

const TELEPORT_RANGE := 50
const ATTACK_RANGE := 5

## buff_ritual_of_the_first_god.tres.
@export var scope:Buff

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_without_unit(unit): return

	# 1. THE PRICE.
	spend_actions(activation)

	# 2. THE TELEPORT, optional.
	await teleport(context, activation, unit)
	if not Unit.is_valid(unit): return

	var bow := Bow.bow_of(unit)
	if not SpecificAction.is_valid(bow): return

	# 3-6. THE SCOPE, THE LIST, THE SHOTS, THE SCOPE OFF.
	var scope_core:BuffCore = UnitCondition.apply_buff(activation, unit, scope, context.gear)
	await fire_at_every_target(activation, unit, bow, targets_of(unit))
	var crits := Scope.recorded_crits(scope_core)
	if scope_core != null and unit.state.buffs.has(scope_core):
		UnitCondition.clear_buff(activation, unit, scope_core)
	if not Unit.is_valid(unit): return

	# 7. THE RECORDED CRITS, in attack order.
	for id:String in crits:
		if not Unit.is_valid(unit): return
		await Bow.resolve_crit_teleport(activation, unit, unit.map.get_unit_by_id(StringName(id)))

func teleport(context:Context, activation:EventCore, unit:Unit) -> void:
	var tiles := Teleport.candidate_tiles(unit, TELEPORT_RANGE, false)
	if tiles.is_empty(): return
	var pathfinder:Pathfinder = await Teleport.pathfinder(unit, tiles)
	if not Unit.is_valid(unit): return
	if pathfinder == null or pathfinder.valid_destinations.is_empty(): return # Immobilized, or banned
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return # "may": declined
	if not Unit.is_valid(unit): return
	await Teleport.move_along(activation, unit, pathfinder, plan)

## Every hostile character within 5, closest first, ties by persistent id.
static func targets_of(unit:Unit) -> Array[Unit]:
	var found:Array[Unit] = []
	for other:Unit in unit.map.get_all_units(true):
		if other == unit or not Unit.is_valid(other): continue
		if not other.is_actor(): continue
		if not UnitRelation.are_enemies(unit, other): continue
		if UnitRelation.distance_between(unit, other) > ATTACK_RANGE: continue
		found.append(other)
	found.sort_custom(func(a:Unit, b:Unit) -> bool:
		var from_a := UnitRelation.distance_between(unit, a)
		var from_b := UnitRelation.distance_between(unit, b)
		if from_a != from_b: return from_a < from_b
		return str(a.core.persistent_id) < str(b.core.persistent_id)
	)
	return found

## Can the bow attack this unit right now? The engine's own targeting, which the player's picker and
## the AI use too.
static func can_attack(bow:SpecificAction, target:Unit) -> bool:
	if not bow.action.can_target_unit(target, bow): return false
	var targetable := UnitTargeting.get_tiles_targetable(bow)
	return target.occupied_tiles().any(func(tile:Vector2i) -> bool: return targetable.has(tile))

func fire_at_every_target(activation:EventCore, unit:Unit, bow:SpecificAction, targets:Array[Unit]) -> void:
	for target:Unit in targets:
		if not Unit.is_valid(unit): return
		# OVER-DETERMINED, AND KEPT (measured by mutation, SP2): can_attack refuses a corpse on its own -
		# a dead unit occupies no tiles - so deleting this line reddens nothing. It stays so can_attack
		# is never handed one.
		if not Unit.is_valid(target): continue
		if not can_attack(bow, target): continue
		await activation.execute_event(&'event_gear_activate', {
			unit = unit,
			gear = bow.gear,
			action = bow.action,
			target_unit = target,
			flags = [
				Action.FLAG.AS_FREEBIE,
				Action.FLAG.TARGETS_ARE_MANDATORY,
				Action.FLAG.SKIP_PLAYER_DECISIONS,
				Action.FLAG.NO_SELF_HEAT,
			],
			event = activation,
		})
