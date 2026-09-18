## SAP: the shattered ground drags at anything hostile that walks into it.
##
##   "When a hostile character within sensors and line of sight enters, or starts their turn, in an
##    area of difficult terrain, they must make a Hull save or become Slowed until the end of their
##    next turn. A character that succeeds this save is unaffected by Sap until the end of their next
##    turn."
##
## ONE REACTION ON TWO TRIGGERS, because the card is one sentence with two clauses and splitting it
## would need two usage groups, two localisation blocks and two things to keep in step.
##
##  - `step` at PRE (event_unit_move.gd:198) is the ONLY timing at which the tile about to be entered
##    is readable: :325-327 sets context.target_tiles to it for the mover and for every virtual
##    involuntary move in the katamari, and clears it again afterwards.
##  - `new_turn` at PRE (event_turn_start.gd:14) is the other clause. Note event_turn_start ALSO fires
##    a virtual core for every DEPLOYABLE the turn-taker owns (:17-21), with the deployable as
##    context.unit - which is why is_character() below is load-bearing rather than defensive. Without
##    it a piece of cover in the field would be asked to save, and UnitHasecheck.make_hull_save returns
##    false for a non-character without rolling anything (unit_hasecheck.gd:53), which this action
##    would read as a failure.
##
## NOT A REAL REACTION. consumes_rxn = false and the per-round hard limit is overridden to 99, because
## ActionReaction only returns 99 for a non-consuming reaction and returns 1 otherwise
## (action_reaction.gd:66) - the card gives Sap no cadence at all, and ruling 3 took "a save on every
## entry" over a cap. A Vauban that has already spent its reaction on Solfataric Breach still Saps.
##
## show_in_tooltip IS OVERRIDDEN TO FALSE (design §1.4, the Poisoned Soil lesson): the Kit's own rows
## describe the whole trait, and a second copy of the same paragraph under a "Trigger:" heading is
## noise on the trait card. show_in_tooltip is a FUNCTION on Action (action.gd:341), not an exported
## property, so this is the only way to set it.
##
## WHERE IT MEASURES (ruling 3): TO THE ENTERED TILE, not to the mover. At the step-PRE gate the mover
## has not moved, so UnitRelation.distance_between would measure to the tile it is LEAVING. The
## distance below is a minimum Chebyshev over the Vauban's own occupied tiles (Tile.distance,
## tile.gd:380-387) - the horizontal term UnitRelation.closest_tiles_between itself uses
## (unit_relation.gd:13-25), without the vertical one, which has no meaning against a bare tile. Sight
## is UnitTile.is_tile_in_los, the per-tile call UnitRelation.can_see makes (:206-215).
## UnitTile.get_tiles_within was the other candidate and is the wrong shape here: it allocates an
## O(range^2) array and runs a sight pass by default, and this gate is asked for every step of every
## move of every unit on the map.
##
## THE SLOWED IT APPLIES IS AN ORDINARY STATUS sourced to this gear (ruling 4) - clearable by
## Stabilize, visible to get_status, and exactly what Solfataric Breach's gate then sees. The reprieve
## is a hidden buff this gate refuses. Neither is exempt from anything: the card names no exemption,
## unlike Caustic Earth's, so a flier or a terrain-ignoring mech still saves.
extends ActionReaction

const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

const REPRIEVE_BUFF := &'buff_sap_reprieve'

## Both triggering events carry the unit this is about: the mover for `step`, the turn-taker (or the
## deployable, see the header) for `new_turn`.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

## ActionReaction returns 1 for a consuming reaction and 99 otherwise (action_reaction.gd:66); this
## one consumes nothing, so 99 is already what it would return. Written out anyway, because the
## card's "no cadence" is a RULING (ruling 3, the author's call over a once-per-round cap) and a
## future edit that flipped consumes_rxn would otherwise silently acquire a cap.
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 99

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	var target:Unit = context.unit
	if not Unit.is_valid(target): return false
	if target == unit: return false
	if not target.is_character(): return false
	if not UnitRelation.are_enemies(unit, target): return false
	if UnitCondition.has_buff(target, REPRIEVE_BUFF): return false

	var entered:Vector2i = Tile.INVALID
	if triggering_event.base.event_type == &'event_unit_move':
		# The tile about to be entered, readable at PRE only. A move context without one is not a step
		# this action can measure.
		if context.target_tiles.is_empty(): return false
		entered = context.target_tiles.front()
		if not Terrain.is_entering_difficult(target, entered): return false
	else:
		if not Terrain.is_unit_in_difficult(target): return false
		entered = target.tile()

	return watches_tile(unit, entered)

## Is `tile` within the Vauban's Sensors and in its line of sight? See the header for why it is
## measured to the TILE rather than to the unit standing on it.
func watches_tile(unit:Unit, tile:Vector2i) -> bool:
	if tile == Tile.INVALID: return false
	var map:MapState = unit.map
	if map == null: return false
	if distance_to_tile(unit, tile) > unit.get_sensor_range(): return false
	return UnitTile.is_tile_in_los(
		map, unit.occupied_tiles(), UnitTile.effective_height(unit, true),
		tile, unit.core.persistent_id
	)

## Chebyshev distance from the CLOSEST of the unit's own tiles to `tile`.
func distance_to_tile(unit:Unit, tile:Vector2i) -> int:
	var closest := 9999
	for own_tile:Vector2i in unit.occupied_tiles():
		closest = mini(closest, Tile.distance(own_tile, tile))
	return closest

func activate(context:Context, activation:EventCore) -> void:
	var gear:GearCore = context.gear
	var triggering:Context = context.event.context
	var target:Unit = triggering.unit
	if not Unit.is_valid(target) or not GearCore.is_valid(gear): return

	# SpecificAction.from_context(context) is (the Vauban, the Sap gear, the Sap action) - the forcer
	# triple SP2's core power keys "saves you force" on (ruling 9). The save target is the FORCER's
	# (event_unit_save.gd:41-43), i.e. the Vauban's 12; the flat bonus is the SAVER's Hull.
	var passed:bool = await UnitHasecheck.make_hull_save(activation, target, SpecificAction.from_context(context))

	# The save resolves inside its own event, and SP2's 3 AP reaction fires at forced_save POST from
	# inside it - so the target can be dead by the time we get here, and a hostile the 3 AP kills is
	# never Slowed and never feeds Breach (ruling 10).
	if activation.abort_without_unit(target): return

	if passed:
		UnitCondition.apply_buff_id(activation, target, REPRIEVE_BUFF, gear)
		return
	UnitCondition.apply_status(
		activation, target,
		Lancer.STATUS.SLOWED, Lancer.UNTIL.END_OF_NEXT_TURN,
		gear.persistent_id
	)
