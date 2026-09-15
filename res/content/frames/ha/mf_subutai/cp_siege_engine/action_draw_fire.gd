## DRAW FIRE, the Siege Engine's reaction.
##
##   "Reaction, 1/round. Trigger: A hostile character within Range of the Diversion Rail and line of
##    sight makes a ranged attack against an allied character within Sensors. Effect: The attack is
##    made against you instead. After the attack, you may make an attack against the hostile
##    character with the Diversion Rail."
##
## NOT ActionReactionAttacked. At attack_declared the context carries no target_units at all, so the
## archetype's defender-relation machinery has nothing to read; the NOAH's action_diluvian_ark_ward.gd
## is vanilla's worked example of this trigger on the bare ActionReaction.
##
## THE SEAM, AND WHY IT IS THIS ONE. event_unit_attack_declared.execute_preblock awaits the
## ATTACK_DECLARED PRE reactions (:21-23) BEFORE execute reads directly_attacked_tiles /
## all_attacked_tiles for the on-targeted-tile effects (:35-36), duplicates all_attacked_units for
## the per-target rolls (:54), and hands all_attacked_tiles to the ground-damage event (:193).
## Nothing in between copies the summary, so rewriting its arrays IN PLACE is seen by every one of
## them - which is what lets ruling 1 recentre a whole AoE rather than move one roll out of it.
## Proven end to end by spec/test_spike_recentre.gd (11/11, b6890a2) before this file existed.
##
## RULING 6: the muzzle and tracer FX have already played at the original target by the time this
## runs (ActionAttack.activate calls run_attack_effects at :265). Nothing in content precedes it. The
## confirm prompt's target line is the telegraph.
##
## THE USAGE GROUP IS ITS OWN, AND IT IS LOAD-BEARING. usage_group defaults to the KIT id, and this
## reaction shares cp_siege_engine with the GATHER ROUND protocol and the Diversion Rail - so
## without &'action_draw_fire' on the .tres, firing the Rail would spend the draw for the round
## (gear_core.gd:166-168). No get_per_round_hard_limit override is needed, unlike Juggernaut Drive's:
## ActionReaction returns 1 for a reaction that DOES consume a point (action_reaction.gd:69), which
## is the card's "1/round" already. Note that limit is stricter than the reaction point, which
## refreshes every turn - so one draw per round however many enemies shoot (ruling 3).
extends ActionReaction

## The Rail lives on the same Kit; both its reach (the trigger's range clause) and the follow-up shot
## are read off it, so the two can never disagree with the weapon the card names.
const RAIL_ACTION_ID := &'action_diversion_rail'

## GATHER ROUND's chip. The reaction does not exist until the protocol has been pressed.
const GATHER_ROUND_BUFF := &'buff_gather_round'

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return UnitCondition.has_buff(unit, GATHER_ROUND_BUFF)

## The declared-attack summary is in `resource`; without it the trigger cannot be evaluated at all.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

func rail_action(gear:GearCore) -> Action:
	return gear.get_action(RAIL_ACTION_ID) if GearCore.is_valid(gear) else null

## The Diversion Rail's targeting range, read off the weapon rather than hardcoded.
func rail_range(unit:Unit, gear:GearCore) -> int:
	var rail:Action = rail_action(gear)
	if rail == null: return 0
	return rail.get_target_range(SpecificAction.create(unit, gear, rail))

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var triggering_context:Context = triggering_event.context
	var summary:DeclaredAttackSummary = triggering_context.resource
	if not DeclaredAttackSummary.is_valid(summary): return false

	# "A hostile CHARACTER": a drone's or deployable's shot counts as its owner's (ruling 5).
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker) or not attacker.is_character(): return false
	if not UnitRelation.are_enemies(unit, attacker): return false

	# "makes a RANGED attack", and not one the engine already exempts from redirects (the Sniper's
	# AMR overrides is_immune_to_automisses_and_redirects; the NOAH honours it the same way).
	if not UnitAction.is_ranged_weapon(triggering_context.action, triggering_context.gear): return false
	if triggering_context.action.is_immune_to_automisses_and_redirects(triggering_context): return false

	# An attack already covering us needs no drawing. There is no target_unit on this context, so
	# the question is asked of the summary.
	if summary.all_attacked_units.has(unit): return false

	# "within Range of the Diversion Rail and line of sight" - OUR checks on the ATTACKER, never the
	# attacker's on us (ruling 4). The engine never re-checks the attacker's own range or sight
	# against the new target, and that is the card as written.
	if UnitRelation.distance_between(unit, attacker) > rail_range(unit, gear): return false
	if not UnitRelation.can_see(unit, attacker): return false

	# "against an allied character within Sensors".
	if allies_under_fire(unit, summary).is_empty(): return false

	# Ruling 2: an AoE that cannot be recentred is REFUSED - a Burst (always centred on the attacker)
	# and a Line or Cone whose rebuilt area would not contain us. One code path: the rebuild, dry.
	return rebuild(unit, triggering_context, false)

func activate(context:Context, activation:EventCore) -> void:
	var triggering_context:Context = context.event.context
	var summary:DeclaredAttackSummary = triggering_context.resource
	# RE-ASKED HERE, not just in the trigger. A second Subutai's Draw Fire queued on the same attack
	# may already have moved every ally out of the summary, at which point there is nothing left to
	# draw - abort WITHOUT spending rather than confirm a prompt about nobody.
	var allies := allies_under_fire(context.unit, summary)
	if activation.abort_when(allies.is_empty()): return

	var confirmed := await CommonActionUtil.confirm_use(
		context, allies, [], SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	spend_actions(activation)

	rebuild(context.unit, triggering_context, true)
	queue_rail_follow_up(context, activation, triggering_context)

## "After the attack, you may make an attack against the hostile character with the Diversion Rail."
##
## THE `using` ACTION IS THE SHOT, NEVER THIS REACTION. event_gear_choose_and_use re-validates
## `using` with can_activate_gear at execute time, and AS_FREEBIE skips only the per-turn and
## affordability checks - a real reaction's 1/round hard limit still applies, and by then this
## reaction HAS been used this round. Measured in Spike 3: with the reaction as `using`, the queued
## event aborted with "specific: invalid" and no shot was fired.
##
## If the Rail cannot reach the attacker by then - the drawn shot's knockback moved us out of range
## or sight - the queued event finds no target and does nothing. Accepted.
func queue_rail_follow_up(context:Context, activation:EventCore, triggering_context:Context) -> void:
	var rail:Action = rail_action(context.gear)
	if rail == null: return
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker): return
	var shot := SpecificAction.create(context.unit, context.gear, rail)
	CommonActionUtil.choose_and_use_after_triggering_event(
		activation, shot, [shot],
		CommonActionUtil.choose_and_use_no_spend, attacker, [Action.FLAG.AS_FREEBIE]
	)

## Allied CHARACTERS caught by the declared attack and within our Sensors, excluding ourselves.
##
## THE SENSOR FILTER LIVES HERE RATHER THAN IN triggers_on_event because rebuild() reads the same
## list to decide whose tiles move: an ally the trigger would not fire for must not have its tile
## dragged onto us either, or the two halves would disagree about what the card covers.
static func allies_under_fire(unit:Unit, summary:DeclaredAttackSummary) -> Array[Unit]:
	var allies:Array[Unit] = []
	for attacked:Unit in summary.all_attacked_units:
		if attacked == unit: continue
		if not Unit.is_valid(attacked) or not attacked.is_character(): continue
		if not UnitRelation.are_allies(unit, attacked): continue
		if UnitRelation.distance_between(unit, attacked) > unit.get_sensor_range(): continue
		allies.append(attacked)
	return allies

## THE REBUILD. DRY (live = false) answers "would the rebuilt area contain us?"; LIVE writes the four
## summary arrays in place. Copies ActionAttack.get_attacked_tiles_and_units_from_plan
## (action_attack.gd:156-173) step for step, so the rebuilt area is exactly what the attacker would
## have got by aiming there.
##
## THE AIM TILE IS OUR OCCUPIED TILE CLOSEST TO THE ATTACKER, NOT OUR ANCHOR. A Line 5 from (14,6)
## reaches a Subutai anchored at (8,6) by its near column at distance 5; the anchor is at 6. The
## nearest tile is the generous reading of "within Range" and the one a player aiming by hand picks.
##
## WHAT IT ACTUALLY CHANGES, measured (task 3 mutation 7, 2026-09-15), because the SP2 design claimed
## more than this: aiming at the anchor instead does NOT refuse that draw. The rebuilt Line still
## sweeps (13,6)…(9,6) on its way to the anchor and so still catches the near column, and the shot
## resolves against us either way. What moves is where the attack is CENTRED -
## directly_attacked_tiles, and with it a Blast's centre, its cover origin and the tiles the ground
## damage lands on. For a 2x2 footprint a Blast 1 covers the whole of it from any of the four, so the
## difference shows up on bigger footprints and bigger blasts rather than on the case that motivated
## the ruling. The choice is still the right one; the reason is "aim where a player would", not
## "otherwise the draw is refused".
##
## RECORDED CONSEQUENCE, not a bug: an ally standing ON the re-aimed ray is still caught. The shot is
## made against us, and whatever lies between the attacker and us is in the rebuilt area.
static func rebuild(unit:Unit, triggering_context:Context, live:bool) -> bool:
	var specific := SpecificAction.from_context(triggering_context)
	var summary:DeclaredAttackSummary = triggering_context.resource
	var map:MapState = specific.unit.map
	var aim:Vector2i = Tile.closest_possible_to(unit.occupied_tiles(), specific.unit.tile())

	# 1. the direct targets: every tile an allied character stands on becomes the aim tile
	var allies := allies_under_fire(unit, summary)
	var new_targets:Array[Vector2i] = []
	for tile:Vector2i in summary.directly_attacked_tiles:
		var moved := tile
		for allied:Unit in allies:
			if allied.occupied_tiles().has(tile):
				moved = aim
				break
		Util.append_nonduplicate(new_targets, moved)

	# 2. the area and the units in it
	var reqs := specific.action.get_target_requirements(specific)
	var pattern := specific.action.get_range_pattern_for_targets(specific, specific.unit.tile(), new_targets)
	var new_tiles:Array[Vector2i] = []
	var new_units:Array[Unit] = []
	if pattern and not reqs.aoe_is_just_for_show:
		# A Burst is centred on the ACTOR (range_pattern.gd:45-46): there is nothing to re-aim, so
		# the draw is refused outright rather than half-applied (ruling 2).
		#
		# MEASURED REDUNDANT, AND KEPT ANYWAY (mutation 6, 2026-09-15: deleting this line reddened
		# NOTHING). A Burst that does not already cover us rebuilds to an area centred on the
		# attacker, which cannot contain us either, so the `not new_units.has(unit)` check below
		# refuses it one step later; a Burst that DOES cover us was already refused by the
		# all_attacked_units check in triggers_on_event, before the rebuild ever ran. No geometry can
		# tell the two paths apart. The line stays because it says WHY a Burst can never be drawn,
		# which the generic reach check does not, and because it stops a future AoE-shape change
		# from half-applying one.
		if pattern.pattern == Lancer.AOE_TYPE.BURST: return false
		new_tiles = specific.action.get_aoe_tiles_with_targets(pattern, new_targets, specific.unit.tile(), specific)
		for aoe_unit:Unit in map.get_all_units_at_tiles(new_tiles, specific.unit):
			Util.append_nonduplicate(new_units, aoe_unit)
	else:
		new_tiles = new_targets
		for attacked:Unit in summary.all_attacked_units:
			Util.append_nonduplicate(new_units, unit if allies.has(attacked) else attacked)
	Util.filter(new_units, specific.action.can_target_unit.bind(specific))
	CommonActionUtil.sort_deployables_and_grunts_to_back(new_units)

	# A Line or Cone that cannot reach us (ruling 2), or a Hidden reactor that fails can_target_unit
	# for a non-AoE shot (accepted: drawing fire while hidden is not a thing).
	if not new_units.has(unit): return false
	if not live: return true

	# 3. IN PLACE. The summary is shared by reference with the declared-attack event and with the
	# attack action's own context, so the arrays are ASSIGNED, never replaced.
	#
	# THE IN-PLACE REQUIREMENT IS UNGUARDED, AND WEAKER THAN THE DESIGN CLAIMED (mutation 8,
	# 2026-09-15: swapping the .assign below for a plain reassignment reddened NOTHING). What is
	# actually shared is the SUMMARY OBJECT, and every reader goes through it - execute() duplicates
	# all_attacked_units at :54 and re-reads the tile arrays at :35-36, both AFTER the preblock, so
	# a replaced array is seen just as well as a rewritten one. .assign is kept because it is the
	# strictly safer of the two: it preserves the summary's declared element types and it survives
	# any future reader that caches one of these arrays before the PRE reactions run.
	summary.directly_attacked_tiles.assign(new_targets)
	summary.all_attacked_tiles.assign(new_tiles)
	summary.all_attacked_units.assign(new_units)
	# A Blast's cover origin is its centre, not the firer (action_attack.gd:177-182), and
	# PreAttack.create takes cover from source_voxels - so recomputing this is what gives the
	# recentred blast the right cover.
	summary.source_voxels.assign(specific.action.get_origin_voxels(specific, new_targets, specific.unit.tile()))
	return true
