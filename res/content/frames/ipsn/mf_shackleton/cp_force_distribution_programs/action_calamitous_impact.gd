## CALAMITOUS IMPACT, the Force Distribution Programs' active - Quick, one core point.
##
##   "You leap up into the air and crash down upon a free space within sensors. All characters within
##    a Burst 2 area are knocked back 3 spaces and must immediately make a Hull save. On a failure they
##    take 2d6+2 Kinetic damage and are knocked Prone. The Burst 2 area becomes Difficult Terrain for
##    the rest of the scene."
##
## THE LEAP IS A PREVENTABLE TELEPORT (design ruling 11, the author's), Abjuration of Metal's route:
## Teleport.candidate_tiles (the engine's own standability test over the whole 2x2, NO line of sight -
## the card names Sensors only), Teleport.pathfinder (Pathfinder.create is the Immobilized gate and
## where every MOVEMENT_RESTRICTION ban lands), the reticle, Teleport.move_along. The card has no
## "cannot be prevented" clause, unlike Step of Mist and Thunder's.
##
## THE ORDER OF activate() IS THE RULING. Nothing to leap to (boxed in, Immobilized, banned) and a
## cancelled pick both return BEFORE spend_actions and cost nothing. From the spend on, the Quick
## action and the core point are gone whatever happens: a VETOED leap (a listener aborting the move at
## ENTIRE_MOVEMENT PRE - Uncertainty Field on a mech that carries it) does nothing else - no crash, no
## burst, no crater. Step of Mist's veto ruling is the precedent. SP2 judgment task, kept: the
## Teleport helper's move_along un-spends nothing of its own, so there is nothing to refund.
##
## THE BURST (ruling 12) is measured from the NEW footprint, and "All characters" means all of them:
## allies and fliers included, only the Shackleton excepted. Each target is pushed 3 (the Shackleton's
## controller picks the direction per target - Spatial Rerouting, ruling 4; an AI Shackleton picks the
## best tile for an ally) and THEN saves, as the card orders it. Pushes run inline, farthest first
## (action_unfathomable_weight.gd's header gives the reason). Unfathomable Weight's collision reaction
## does NOT fire on these pushes - it is keyed to its own action - so this card's Prone comes only from
## this card's save. A knockback-immune target is not pushed and still saves.
##
## ONE DAMAGE ROLL FOR THE WHOLE BURST (ruling 13): Lancer's area convention. It is rolled once all the
## saves are known and dealt to every character that failed, the Shackleton credited as the source.
##
## THE CRATER LAST (ruling 14): Terrain.lay at the Shackleton's anchor, AFTER the damage has resolved.
## dep_shackleton_crater is a size-2 MARKER whose zone is BURST 2 from its own 2x2 footprint - the
## 6x6 that IS "the Burst 2 area" - and it sets is_deactivated_on_owner_death = false, so it outlives
## the Shackleton ("for the rest of the scene"). A null return (the spawn did not land) is not an
## error worth anything more than stopping: everything else the card does has happened.
##
## NO AI OPTION (ruling 15, SP2 judgment task): the mod's standing convention - none of its core
## actives ships get_ai_custom_action_option or an ai_behavior_override, so Action.get_ai_behavior
## returns null and an AI Shackleton never presses this. The mod's frames are player frames.
extends ActionSystem

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')
const UnfathomableWeight := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_shackleton/cp_force_distribution_programs/action_unfathomable_weight.gd')

const PUSH:int = 3
const BURST:int = 2
const DAMAGE_DICE:String = '2d6+2'

## The crater: dep_shackleton_crater.tres.
@export var crater:Frame

func get_glossary_tags(specific:SpecificAction = null) -> Array[GlossaryItem]:
	var display_tags:Array[GlossaryItem] = super.get_glossary_tags(specific)
	# ActionSystemDeploy's heads-up (action_system_deploy.gd:52-59), said here because this is not a
	# deploy action: the crater outlives the Shackleton.
	if crater != null and not crater.is_deactivated_on_owner_death:
		display_tags.append(GlossaryItem.create('lancer.term.persists'))
	return display_tags

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var specific := SpecificAction.from_context(context)

	# 1. WHERE TO. Nothing standable within Sensors, or a pathfinder that refuses to move us
	# (Immobilized, an Interdiction Field): refuse before anything is spent.
	var tiles := Teleport.candidate_tiles(unit, unit.get_sensor_range(), false)
	if activation.abort_when(tiles.is_empty()): return
	var pathfinder:Pathfinder = await Teleport.pathfinder(unit, tiles)
	# DEFENSIVE, measured 2026-09-24: with this empty-set clause removed an Immobilized Shackleton still
	# spends nothing, because the pick below comes back empty and returns before the spend too. It stays
	# so that "nothing to leap to" never depends on how the reticle answers an empty pathfinder.
	if activation.abort_when(pathfinder == null or pathfinder.movable_tiles.is_empty()): return

	# 2. THE PICK. A cancel costs nothing.
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if activation.abort_when(plan == null or plan.aborted or plan.move_path.is_empty()): return
	if activation.abort_without_unit(unit): return

	# 3. THE SPEND. From here on it is paid for.
	spend_actions(activation)

	# 4. THE LEAP. A veto, a failed move or a landing where we started: spent, nothing else.
	var origin:Vector2i = unit.tile()
	var move:EventCore = await Teleport.move_along(activation, unit, pathfinder, plan)
	if move == null or move.aborted or unit.tile() == origin: return
	if activation.abort_without_unit(unit): return

	# 5. THE BURST, from where we landed.
	var area := UnitTile.get_aoe_tiles(unit, Lancer.AOE_TYPE.BURST, BURST)
	await run_system_fxgs(unit, [], area)
	if activation.abort_without_unit(unit): return

	var targets := characters_in(unit, area)
	UnfathomableWeight.farthest_first(unit, targets)
	var failed:Array[Unit] = []
	for target:Unit in targets:
		if not Unit.is_valid(target): continue
		var events := CommonActionUtil.generate_knockback_events(
			target, PUSH, specific, unit.occupied_tiles(), [EventUnitPickMove.FLAG.MANDATORY])
		if not events.is_empty():
			await activation.execute_events(events)
			if activation.abort_without_unit(unit): return
		if not Unit.is_valid(target): continue
		var passed := await UnitHasecheck.make_hull_save(activation, target, specific,
			[EventService.SAVE_FLAG.KNOCKBACK, Lancer.STATUS.PRONE])
		if activation.abort_without_unit(unit): return
		if not passed and Unit.is_valid(target): failed.append(target)

	# 6. ONE ROLL, every failure takes it, and is knocked Prone.
	if not failed.is_empty():
		var damage := Action.roll_damage(DAMAGE_DICE, unit)
		battle_log.log_tr('battle.generic_roll.log', {dice = DAMAGE_DICE, result = damage})
		Util.filter(failed, Unit.is_valid)
		await activation.execute_events(CommonActionUtil.generate_damage_events(
			specific, failed, damage, Lancer.DAMAGE_TYPE.KINETIC))
		for target:Unit in failed:
			if Unit.is_valid(target):
				apply_status(activation, target, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL)
		if activation.abort_without_unit(unit): return

	# 7. THE CRATER, last.
	if crater == null: return
	await Terrain.lay(activation, specific, unit.state.tile, crater)

## Every CHARACTER standing in `tiles`, of any faction, the Shackleton excluded.
static func characters_in(unit:Unit, tiles:Array[Vector2i]) -> Array[Unit]:
	# whos_asking filters by UnitRelation.can_affect and does NOT drop the asker itself
	# (map_state.gd:319-320), so the Shackleton is excluded by hand.
	var found := unit.map.get_all_units_at_tiles(tiles, unit)
	Util.filter(found, func(other:Unit) -> bool:
		return Unit.is_valid(other) and other != unit and other.is_character())
	return found
