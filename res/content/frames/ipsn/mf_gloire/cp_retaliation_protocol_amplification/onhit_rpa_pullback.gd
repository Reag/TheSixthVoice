## RPA PULLBACK, the pull (design ruling 12, the author's): "targets hit are immediately pulled
## towards you by the most direct route possible".
##
## AT ON_RESOLUTION, NOT ON_HIT - AND THIS IS SP2'S MEASUREMENT, RECORDED (2026-09-24). The design
## queued the pull from on_hit, the Omni Harpoon's call, and ruled the weapon's own Knockback
## resolves first (the target ends adjacent). Those two do not compose: generate_pull_events plans
## its path from the target's tile AT THE CALL, and event_unit_move walks that plan as a fixed
## sequence of steps from the starting tile (event_unit_move.gd:150-152 generate_ddr_steps) and
## aborts outright when the unit is no longer where the plan began (:156-159, "if we got knocked
## off-course, abort"). A pull queued at ON_HIT beside a queued push is therefore planned from the
## pre-push tile and aborted after it - the push lands and the pull silently does nothing.
##
## So the pull runs once per attack at ON_RESOLUTION, which event_unit_attack_declared.gd:212-214
## reaches after every roll, every queued push (each per-target attack's children resolve with it,
## before the next roll) and the damage: every hit target that is still standing is pulled then,
## planned from where it actually is, executed inline, CLOSEST FIRST - sorted here, because the
## line does NOT roll closest first (measured 2026-09-24: the picked tile's occupant at (10,4)
## rolled before the one at (7,4)), and the order matters: a nearer target settles adjacent before
## a farther one is dragged into it and saves. Whether the pulls resolve between rolls or after them
## was the design's open question; the answer is AFTER, by construction. A target the attack killed
## is simply not in get_all_hit_units.
##
## THE PULL STOPS ONE SHORT OF THE GLOIRE (ruling 13's "arriving is not hitting", made geometric).
## Measured 2026-09-24: with max_pull_distance left at 99, generate_pull_events plans the full
## closest-pair distance, whose LAST step is one of the Gloire's own tiles. A grounded target is
## blocked there (a collision the reaction below refuses to act on), but a FLYING target is not -
## create_for_involuntary keeps its flying, and MovementType.moves_through_enemies lets it cross the
## footprint - so it flew onto (5,4), was landed there, and was bounced off the Gloire to (5,3). The
## cap is closest-pair distance minus one: a target at distance 1 is already adjacent and is not
## moved at all, everyone else ends on the near side of the footprint.
##
## THE FOUR FLAGS (memory lancer-tactics-movement-terrain-collisions): create_for_involuntary sets
## none of them. straight_line + must_move_max_possible are what is_next_step_blocked calls a
## knockback (event_unit_move.gd:410-414) and so what makes a body in the way a COLLISION rather
## than a silent stop; can_move_through_enemies is what lets the planner draw the line INTO that
## body's tile so the step is attempted at all (pathfinder.gd prices an occupied tile at
## INVALID_COST otherwise). The Kraken's action_drag_pull.gd carries the same three for the same
## reason. "The most direct route" IS the helper: calculate_step_path_for_line from the target to
## the closest pair of tiles (common_action_util.gd:159-176), stopped by whatever blocks it.
##
## KNOCKBACK IMMUNITY is this file's to check - the helper does none of its own
## (common_action_util.gd:148-195), unlike generate_knockback_events. Fortress Protocol and the rest
## read the same predicate. FLIERS are landed when the Gloire is not flying (force_to_land, the Omni
## Harpoon's reading). The Gloire's own tiles are the destination, and a pull that would end on one
## of them is what the collision reaction excludes (ruling 13).
##
## WHO IS THE PULLER: SpecificAction.from_context(activation.context) on the declared attack - the
## unit, the weapon and the COMPOSED action (event_gear_activate.gd:88-91 puts the composed context
## on the core), so the move event's `object` carries the variant key the collision reaction keys
## on (pathfinder.gd:912).
##
## THE PULL IS TAGGED (close review, 2026-09-25). That same composed action rides on EVERY forced move
## of the attack - the weapon's own Knockback is queued with it too (action_attack_weapon.gd:337) - so
## the variant key alone cannot tell the pull from the push. PULL_TAG on the pull's MovementType is
## what the collision reaction requires: "this movement" is the pull. And the pull CANNOT MOVE UPHILL,
## the fifth flag: an involuntary step costs 1 at any height (pathfinder.gd calculate_step_cost_alt),
## so without it a target was hauled straight up a ledge with no save; with it, is_next_step_blocked
## calls the step a collision (event_unit_move.gd:406-411), as every Knockback and Ferrous Lash do.
## BUT IT IS SET ON THE MOVE, NOT THE PLAN - measured: with the flag on at planning,
## calculate_step_path_for_line ends the path at the foot of the step, the move never attempts it,
## and nothing collides (the target just stops, unsaved). So the route is planned without it (the
## step is IN the path, as a body is thanks to can_move_through_enemies) and the flag goes onto the
## move events' MovementType before they run - the step is attempted, and refused as a collision.
extends OnHitEffect

const PULL_TAG := &'reag_rpa_pullback_pull'

func on_resolution(activation:EventCore) -> void:
	var context:Context = activation.context
	var gloire:Unit = context.unit
	if not Unit.is_valid(gloire): return
	var summary = context.resource
	if not (summary is DeclaredAttackSummary): return
	var specific := SpecificAction.from_context(context)

	var targets:Array[Unit] = summary.get_all_hit_units()
	closest_first(gloire, targets)
	for target:Unit in targets:
		if not Unit.is_valid(target) or target == gloire: continue
		var movement_type := movement_type_for(target)
		if UnitCondition.is_immune_to_knockback_from(target, specific, movement_type, true): continue
		# Re-measured per target: an earlier pull may have moved a body into the way, and the target
		# itself may have been pushed since it was hit.
		var distance:int = Tile.get_closest_pair_between(target.occupied_tiles(), gloire.occupied_tiles()).distance
		if distance <= 1: continue # already adjacent: nothing to pull
		var events := await CommonActionUtil.generate_pull_events(
			target,
			gloire.occupied_tiles(),
			specific,
			movement_type,
			not gloire.has_status(Lancer.STATUS.FLYING),
			distance - 1,
			[EventUnitMove.FLAG.SKIP_CAMERA_FOCUS],
		)
		if activation.abort_without_unit(gloire): return
		if events.is_empty(): continue
		for event:EventCore in events: # see the header: planned over the step, refused at it
			if event.context.resource is MovementType: event.context.resource.cannot_move_uphill = true
		await activation.execute_events(events)
		if activation.abort_without_unit(gloire): return

## Closest to the Gloire's footprint first, ties in the roll's own order (sort_custom is not stable,
## so the tie-break is the index). The Shackleton's farthest_first, inverted.
static func closest_first(unit:Unit, targets:Array[Unit]) -> void:
	var order := {}
	for i in targets.size(): order[targets[i]] = i
	targets.sort_custom(func(a:Unit, b:Unit) -> bool:
		var da := UnitRelation.distance_between(unit, a, true) # flat, as the pull measures
		var db := UnitRelation.distance_between(unit, b, true)
		if da != db: return da < db
		return order[a] < order[b]
	)

## Involuntary, straight, must-move-max, through enemies: the four flags a pull needs to collide -
## plus the tag that marks it as the pull. No climbing is added to the MOVE, after planning (header).
static func movement_type_for(target:Unit) -> MovementType:
	var movement_type := MovementType.create_for_involuntary(target)
	movement_type.straight_line = true
	movement_type.must_move_max_possible = true
	movement_type.can_move_through_enemies = true
	movement_type.other_tags.append(PULL_TAG)
	return movement_type
