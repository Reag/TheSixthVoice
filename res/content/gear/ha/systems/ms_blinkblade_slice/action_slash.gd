## SLASH (Blinkblade Slice, Koremasa rank II, design ruling 29): move up to five spaces in a straight
## line through characters, ignoring terrain penalties, reactions and engagement; every hostile
## character moved THROUGH makes a Hull save or takes 3 Kinetic and becomes Locked On.
##
## FULL SPEED AHEAD'S SHAPE (ms_hull_break_thrusters/action_full_speed_ahead.gd) WITH THREE CHANGES:
## - caught at DISTANCE 0 only. "Any hostile character you moved through": a hostile merely beside the
##   line is not caught, where Full Speed Ahead also takes those it became adjacent to.
## - no flying (the .tres), so a hostile whose flying state differs from the Koremasa's is not moved
##   through - the Cataphract's Trample filter (action_trample_cataphract.gd).
## - no AP on the damage, and no self-damage.
##
## THE MOVE IS DATA. The .tres's MovementType carries every clause; ActionSystemMovement merges it with
## the unit's own and pathfinds it. Refusals are vanilla: a stackup rider (can_be_used_while_stackup_rider,
## action_system_movement.gd:20), Slowed and Immobilized (:22-28). A cancelled pick spends nothing
## (:105-106).
##
## THE LINE IS RECONSTRUCTED AFTERWARDS, exactly as Full Speed Ahead does: the move is a straight
## line, so CommonActionUtil.get_all_occupied_tiles_in_line between where it started and where it
## ended is the path, start tile excluded (AoeCalculator.line's rings open one step out). The tiles the
## Koremasa now stands on are dropped too - the last tile is always free (pathfinder.gd:133-134).
extends ActionSystemMovement

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

## "take 3 Kinetic damage" - flat, and not AP.
const SLASH_DAMAGE := 3

## MovementType.merge_in has no ignore_fall_damage limb (movement_type.gd:78-94), so the merge with the
## unit's own type silently drops the .tres's flag and a dip mid-line would deal fall damage per step
## (katamari.gd:104-115). Re-assert it after the merge.
func get_movement_type(unit:Unit) -> MovementType:
	var type := super.get_movement_type(unit)
	type.ignore_fall_damage = type.ignore_fall_damage or movement_type.ignore_fall_damage
	return type

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var start_tile := unit.tile()

	await super.activate(context, activation)
	if activation.abort_without_unit(unit): return
	# Cancelled at the picker, or refused: nothing was moved through.
	if unit.tile() == start_tile: return
	if not GearCore.is_valid(context.gear): return

	# Collected BEFORE any save resolves: a victim killed by an earlier one's queued damage cannot
	# shorten the list, and each hostile is listed once however many of its tiles the line crossed.
	var victims := moved_through(unit, passed_tiles(unit, start_tile))

	var specific := SpecificAction.from_context(context)
	for victim:Unit in victims:
		if not Unit.is_valid(victim): continue
		var passed:bool = await UnitHasecheck.make_hull_save(activation, victim, specific, [Lancer.STATUS.LOCKON])
		if not Unit.is_valid(victim): continue
		if passed: continue
		Lockon.apply(activation, victim, context.gear) # a no-op on a target already Locked On
		activation.queue_event(&'event_unit_damage', {
			unit = victim,
			number = SLASH_DAMAGE,
			category = Lancer.DAMAGE_TYPE.KINETIC,
			target_unit = unit, # the damage event's target_unit is WHO DEALT it
		})

## The tiles moved THROUGH: entered after the start tile, minus the ones the Koremasa ended on.
static func passed_tiles(unit:Unit, start_tile:Vector2i) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	var standing := unit.occupied_tiles()
	for tile:Vector2i in CommonActionUtil.get_all_occupied_tiles_in_line(unit, start_tile, unit.tile()):
		if tile in standing: continue
		tiles.append(tile)
	return tiles

## Every hostile character standing on a passed tile, ONCE each.
static func moved_through(unit:Unit, tiles:Array[Vector2i]) -> Array[Unit]:
	var caught:Array[Unit] = []
	if tiles.is_empty(): return caught
	for hostile:Unit in UnitRelation.get_enemy_units(unit, true):
		if not Unit.is_valid(hostile): continue
		if not hostile.is_character(): continue
		if hostile.state.is_flying() != unit.state.is_flying(): continue
		if Katamari.are_attached(hostile, unit): continue
		if not hostile.occupied_tiles().any(func(tile:Vector2i) -> bool: return tile in tiles): continue
		caught.append(hostile)
	return caught
