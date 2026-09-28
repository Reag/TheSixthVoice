## UNFATHOMABLE WEIGHT, the Force Distribution Programs' passive half - a Quick action, unlimited.
##
##   "You create a shockwave in a Burst 1 area around you. Hostile characters are knocked back 2
##    spaces. If this would knock them into a wall, mech, or other obstruction that would stop them
##    from moving, you may force the target to succeed on a Hull save or be knocked Prone."
##
## THIS FILE IS THE PUSH; action_unfathomable_weight_collide.gd IS THE PRONE (design ruling 9). The
## collision is the ENGINE's - event_unit_move.gd fires event_unit_collide from is_next_step_blocked -
## so the "if this would knock them into..." half can only be a reaction to that event, keyed to the
## move this action caused. Ferrous Lash is the same split (action_ferrous_lash_collide.gd).
##
## BURST 1 FROM THE FOOTPRINT (ruling 8), AND FLAT. flat_burst is RangePattern.get_aoe_tiles(BURST, 1)
## - AoeCalculator.burst over the whole 2x2 (range_pattern.gd:45-46): the 4x4 ring around the
## Shackleton. It never asks UnitRelation.adjacent_characters, so House Guard's widening cannot reach
## it - spec/test_compat.gd pins that (the design's Contested seams line). It is NOT
## UnitTile.get_aoe_tiles, which then drops every tile whose occupant is out of the burst's vertical
## reach (unit_tile.gd:367-372, the radius doubling as height) and so left a Flying hostile beside the
## Shackleton out of the area. Pass E ruling, 2026-09-27 (the author): the burst is flat, height is
## ignored. Target lookup by tile (get_all_units_at_tiles) is 2-D already.
##
## "HOSTILE CHARACTERS", AND NO FLYING EXEMPTION. The Barricade's Seismic Repulsor skips fliers; that
## is its card's reading, and this card has no such clause, so a flier is pushed like anyone else.
## Knockback immunity is the helper's own business (common_action_util.gd:122) and produces nothing.
##
## ANY DIRECTION, BECAUSE OF THE TRAIT, NOT BECAUSE OF THIS FILE. The push goes through the QUALIFIED
## CommonActionUtil.generate_knockback_events, which the mod's common_action_util.gd_ext.gd overrides:
## a Shackleton carrying Spatial Rerouting gets every direction, the Shackleton's controller picks per
## target (ruling 4). Origin tiles are passed anyway, so a unit without the trait wearing this Kit
## gets vanilla's cone away from the footprint.
##
## MANDATORY, NOT AUTO_FURTHEST: "are knocked back" is not "may", so the reticle cannot be cancelled -
## but the direction IS the trait's choice, so the player is asked.
##
## ONE PUSH AT A TIME, FARTHEST FIRST (SP2 judgment task, 2026-09-24). Lancer has no initiative, so
## "turn order" had no engine meaning; each push is EXECUTED inline so its reticle resolves (and its
## collision reaction fires) before the next one opens, and the outer ring moves first so an inner
## target pushed outward is not blocked by a neighbour the same shockwave is about to move.
extends ActionSystem

const PUSH:int = 2
const BURST:int = 1

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var specific := SpecificAction.from_context(context)

	var tiles := flat_burst(unit, BURST)
	var targets := hostile_characters_in(unit, tiles)

	# The shockwave preview. Declining spends nothing.
	var confirmed:bool = await CommonActionUtil.confirm_use(context, targets, tiles)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(unit): return

	spend_actions(activation)
	await run_system_fxgs(unit, [], tiles)
	if activation.abort_without_unit(unit): return

	# The awaits above yield; drop anything freed meanwhile before the sort measures it.
	Util.filter(targets, Unit.is_valid)
	farthest_first(unit, targets)
	for target:Unit in targets:
		if not Unit.is_valid(target): continue
		var events := CommonActionUtil.generate_knockback_events(
			target, PUSH, specific, unit.occupied_tiles(), [EventUnitPickMove.FLAG.MANDATORY])
		if events.is_empty(): continue # immune
		await activation.execute_events(events)
		if activation.abort_without_unit(unit): return

## The FLAT Burst `radius` around the unit's footprint: RangePattern's 2-D pattern, with none of the
## elevation filter UnitTile.get_aoe_tiles applies after it (unit_tile.gd:367-372). Calamitous Impact
## measures its Burst 2 with this too.
static func flat_burst(unit:Unit, radius:int) -> Array[Vector2i]:
	return RangePattern.get_aoe_tiles(Lancer.AOE_TYPE.BURST, radius, unit.map.shape,
		unit.state.occupying_size, unit.occupied_tiles())

## Every hostile CHARACTER standing in `tiles`, the Shackleton excluded. Re-read per call: the burst
## is measured from wherever the unit stands now.
static func hostile_characters_in(unit:Unit, tiles:Array[Vector2i]) -> Array[Unit]:
	# whos_asking filters by UnitRelation.can_affect and does NOT drop the asker itself
	# (map_state.gd:319-320); are_enemies does that here.
	var found := unit.map.get_all_units_at_tiles(tiles, unit)
	Util.filter(found, func(other:Unit) -> bool:
		return Unit.is_valid(other) and other.is_character() and UnitRelation.are_enemies(unit, other)
	)
	return found

## Farthest from the unit's footprint first, ties in the map's own order (sort_custom is not stable,
## so the tie-break is the index).
static func farthest_first(unit:Unit, targets:Array[Unit]) -> void:
	var order := {}
	for i in targets.size(): order[targets[i]] = i
	targets.sort_custom(func(a:Unit, b:Unit) -> bool:
		var da := UnitRelation.distance_between(unit, a)
		var db := UnitRelation.distance_between(unit, b)
		if da != db: return da > db
		return order[a] < order[b]
	)
