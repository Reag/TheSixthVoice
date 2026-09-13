## FULL SPEED AHEAD: the Fitzgerald flies its Speed in a straight line through whatever is in the
## way, and everything it touches has to hold on.
##
## THE MOVE ITSELF IS DATA, NOT CODE. The .tres beside this file carries an inline MovementType with
## flying, straight_line, can_move_through_enemies, ignore_engagement and ignore_rxns set;
## ActionSystemMovement merges that with the unit's own movement type and pathfinds it
## (action_system_movement.gd:38-45), and with movement_range_fixed 0 and spend_move false
## (movement_type.gd:5 - the default, which the .tres does not override) the budget is
## get_speed_max() - Speed, not what is left of this turn's movement (action_system_movement.gd:31-36).
## So this script overrides nothing about the movement and only walks the line AFTERWARDS.
##
## WHY THE LINE IS RECONSTRUCTED RATHER THAN OBSERVED. The Berserker's Avalanche Charge does exactly
## this (content/frames/npc/npcc_berserker/avalanche_charge/action_avalanche_charge.gd:
## activate_juggernaut) - it remembers the tile it started on, calls super, and then asks
## CommonActionUtil.get_all_occupied_tiles_in_line (common_action_util.gd:519) for the tiles between
## there and where it ended. That is exact for us because the movement type forces a straight line,
## so the path the pathfinder built and the line between the endpoints are the same tiles.
##
## AND THE START TILE IS NOT IN THAT LIST. get_all_occupied_tiles_in_line routes a LINE pattern into
## AoeCalculator.line (range_pattern.gd:59-60), which builds its rings starting ONE STEP from the
## origin (aoe_calculator.gd:143 calling Tile.get_rings, whose loop opens at 1 - tile.gd:349), so the
## returned tiles are exactly the tiles ENTERED. Ruling 7 - "adjacent to any tile entered after the
## start tile" - therefore costs no code: a hostile standing beside where the Fitzgerald was parked,
## and nowhere near the ray, is not caught, and a test pins that so a future engine change to the
## ring origin cannot pass silently.
##
## ADJACENCY IS EIGHT-WAY. Tile.distance is Chebyshev, max(dx, dy) (tile.gd:380-387), over the
## eight-neighbour Tile.DIRECTIONS (tile.gd:22). A hostile one tile diagonally off the ray is at
## distance 1 from a tile that was entered and IS caught - which is why "beside only the start tile"
## means the three tiles BEHIND the dash, not the one abeam of where it was parked.
##
## NO TELEGRAPH. The Berserker calls choice_bus.telegraph_ability before its saves because it is an
## NPC announcing an ability to the player. This is the player's own button; the movement picker has
## already shown them the ray.
extends ActionSystemMovement

## Dealt to every hostile that fails its Hull save. Flat, not a roll: the card says "3 AP Kinetic".
const HULL_BREAK_DAMAGE := 3
## Paid by the Fitzgerald for each occupied space it crossed.
const SELF_DAMAGE_PER_OCCUPIED_TILE := 1

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var start_tile := unit.tile()

	await super.activate(context, activation)
	if activation.abort_without_unit(unit): return
	# Cancelled at the picker, or refused: nothing was entered, so nothing is owed.
	if unit.tile() == start_tile: return

	var entered := entered_tiles(unit, start_tile)
	if entered.is_empty(): return

	# BOTH lists are built BEFORE the first save resolves. A hostile that dies to this dash would
	# otherwise stop counting towards the self-damage it already cost us, and every is_valid helper
	# in the engine is alive-gated.
	var caught := caught_hostiles(unit, entered)
	var occupied_crossed := count_occupied_crossed(unit, entered)

	var specific := SpecificAction.from_context(context)
	for victim:Unit in caught:
		if not Unit.is_valid(victim): continue
		var passed:bool = await UnitHasecheck.make_hull_save(activation, victim, specific, [Lancer.STATUS.PRONE])
		if not Unit.is_valid(victim): continue
		if passed: continue
		UnitCondition.apply_status(
			activation, victim, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, context.gear.persistent_id
		)
		activation.queue_event(&'event_unit_damage', {
			unit = victim,
			number = HULL_BREAK_DAMAGE,
			category = Lancer.DAMAGE_TYPE.KINETIC,
			target_unit = unit, # the damage event's target_unit is WHO DEALT it, not who takes it
			flags = [EventService.DAMAGE_FLAG.AP],
		})

	if occupied_crossed <= 0: return
	activation.queue_event(&'event_unit_damage', {
		unit = unit,
		number = occupied_crossed * SELF_DAMAGE_PER_OCCUPIED_TILE,
		category = Lancer.DAMAGE_TYPE.KINETIC,
		target_unit = unit,
		flags = [EventService.DAMAGE_FLAG.AP, EventService.DAMAGE_FLAG.SELF_INFLICTED],
	})

## The tiles the Fitzgerald entered, start tile excluded (see the header).
static func entered_tiles(unit:Unit, start_tile:Vector2i) -> Array[Vector2i]:
	return CommonActionUtil.get_all_occupied_tiles_in_line(unit, start_tile, unit.tile())

## Every hostile character passed through or become adjacent to, ONCE each.
##
## Distance 0 is "passed through" and distance 1 is "became adjacent"; the card's two clauses are one
## test, which is also how the Berserker writes it. get_enemy_units already filters to characters and
## through UnitRelation.can_affect (unit_relation.gd:367-377), and never returns the asker.
static func caught_hostiles(unit:Unit, entered:Array[Vector2i]) -> Array[Unit]:
	var caught:Array[Unit] = []
	for hostile:Unit in UnitRelation.get_enemy_units(unit, true):
		if not Unit.is_valid(hostile): continue
		if Tile.get_closest_pair_between(hostile.occupied_tiles(), entered).distance > 1: continue
		caught.append(hostile)
	return caught

## How many of the entered tiles had a character standing in them.
##
## ANY character, not only a hostile: the card says "each occupied space you pass through", and
## shouldering past an ally hurts just as much. The Fitzgerald itself is skipped - it is standing on
## the last entered tile by the time this runs - and a tile holding two characters still counts once,
## because the unit is charged per SPACE.
static func count_occupied_crossed(unit:Unit, entered:Array[Vector2i]) -> int:
	var count := 0
	for tile:Vector2i in entered:
		for other:Unit in unit.map.get_all_units_at_tile(tile):
			if other == unit: continue
			if not other.is_character(): continue
			count += 1
			break
	return count
