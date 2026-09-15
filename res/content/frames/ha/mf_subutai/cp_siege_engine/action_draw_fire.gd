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
## ONE SHOT THIS REACTION CANNOT DRAW, AND IT IS CORRECT: an ORDNANCE attack made by a unit the
## Subutai is ENGAGED with. The rebuild's unit filter is the attacker's own can_target_unit, and
## action_attack_weapon.gd:231-236 refuses an ordnance target that is engaged with the firer - so the
## Subutai drops out of new_units, `new_units.has(unit)` is false and the draw is refused exactly as a
## Line that cannot reach is. That is vanilla's ordnance rule applied to the new target, not a defect;
## it is written down here because "the draw is silently not offered" is the same symptom as ruling 2's
## refusals and a playtest would otherwise have to guess which one it was watching.
##
## THE USAGE GROUP IS ITS OWN, AND TODAY THAT IS DEFENCE IN DEPTH, NOT LOAD-BEARING. usage_group
## defaults to the KIT id, which this reaction would otherwise share with the GATHER ROUND protocol
## and the Diversion Rail. But cf56dfc gave both of those their OWN usage_groups too (vanilla's
## per-action convention), so as of that commit NOTHING on this Kit still uses the default
## cp_siege_engine group - Draw Fire's explicit group collides with nothing today. Re-measured at
## head (2026-09-15): deleting &'action_draw_fire' from the .tres reddens only the value pin in
## test_the_reaction_is_on_the_core_kit; it does not touch what firing the Rail spends. The line
## stays because it is what stops a FUTURE action added to this Kit without its own group from
## silently spending the draw - the field's VALUE is what test_the_reaction_is_on_the_core_kit pins,
## and that pin is the only thing currently guarding it. No get_per_round_hard_limit override is
## needed, unlike Juggernaut Drive's: ActionReaction returns 1 for a reaction that DOES consume a
## point (action_reaction.gd:69), which is the card's "1/round" as the engine spells it.
##
## RULING 3, AND WHAT "1/ROUND" ACTUALLY MEANS OFF-TURN. The engine's per-round counter is NOT a game
## round: uses_this_round is cleared by UnitAction.new_turn_refresh -> reset_per_round_usage
## (unit_action.gd:75-78 and :87-88), which runs only at the SUBUTAI'S OWN turn start, while the
## reaction POINT refreshes at every unit's turn start (every_new_turn_refresh, :67-70). So the real
## limit is "one draw since the Subutai's last turn start" - enemy A shoots and is drawn, the Subutai
## takes its turn, enemy B shoots and is drawn again: two draws inside one game round, one on each
## side of the Subutai's turn. Every vanilla 1/round reaction shares the property; it is recorded as a
## ruling rather than fought, and pinned by test_draw_fire.test_a_draw_is_available_again_after_the_
## subutais_own_turn. Within a single enemy phase the counter does bind, however many enemies shoot.
extends ActionReaction

## THE RAIL IS ITS OWN KIT, not an action on this one (changed 2026-09-15, author-ruled).
##
## The character sheet titles an integrated-weapon box from the KIT that holds the weapon -
## `Translate.gear(core.kit.compcon_id, 'name')`, `weapon_mount_item.gd:101` - so while the Rail sat
## on `cp_siege_engine` the game called the Subutai's gun "Siege Engine". One Kit cannot carry two
## names, and that UI file is base-game. Splitting the weapon onto `mw_diversion_rail` is vanilla's
## own shape for a standalone integrated weapon (`mw_fuel_rod_gun.tres`, Nuclear Cavalier rank 3).
##
## Both the trigger's range clause and the follow-up shot are still read off the weapon itself, so
## neither can disagree with the gun the card names - they are just read off the OTHER gear now, via
## `rail_gear()`. Everything here takes the UNIT rather than this reaction's own gear.
const RAIL_KIT_ID := &'mw_diversion_rail'
const RAIL_ACTION_ID := &'action_diversion_rail'

## GATHER ROUND's chip. The reaction does not exist until the protocol has been pressed.
const GATHER_ROUND_BUFF := &'buff_gather_round'

## A DECLARED ATTACK MAY BE DRAWN ONCE. The stamp goes on the DeclaredAttackSummary itself, which is
## the one object every reader of this attack shares by reference - so a second Subutai asking about
## the same attack sees it. DeclaredAttackSummary is a Resource, so set_meta/has_meta are free and the
## stamp dies with the summary at the end of the attack.
const DRAWN_META := &'reag_draw_fire_drawn'

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	return UnitCondition.has_buff(unit, GATHER_ROUND_BUFF)

## The declared-attack summary is in `resource`; without it the trigger cannot be evaluated at all.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

## The Rail's own GearCore on this unit, or null. Null is a real possibility rather than paranoia:
## the Rail is a frame trait and a player may CLEAR a frame trait from the character sheet
## (mech_section.gd:256, set_trait_removed), which removes the gear while GATHER ROUND and this
## reaction stay. Every caller below treats null as "no Rail, so no draw", which is the card's own
## reading - the trigger is measured in the Rail's range, and a Subutai with no Rail has none.
func rail_gear(unit:Unit) -> GearCore:
	if not Unit.is_valid(unit): return null
	var gear:GearCore = unit.get_gear(RAIL_KIT_ID)
	return gear if GearCore.is_valid(gear) else null

func rail_action(unit:Unit) -> Action:
	var gear:GearCore = rail_gear(unit)
	return gear.get_action(RAIL_ACTION_ID) if GearCore.is_valid(gear) else null

## The Diversion Rail's targeting range, read off the weapon rather than hardcoded.
func rail_range(unit:Unit, _gear:GearCore) -> int:
	var gear:GearCore = rail_gear(unit)
	var rail:Action = rail_action(unit)
	if rail == null: return 0
	return rail.get_target_range(SpecificAction.create(unit, gear, rail))

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var triggering_context:Context = triggering_event.context
	var summary:DeclaredAttackSummary = triggering_context.resource
	if not DeclaredAttackSummary.is_valid(summary): return false

	# ONCE PER DECLARED ATTACK - and MEASURED REDUNDANT ON THIS SEAM, KEPT ANYWAY, in the same sense as
	# the Burst guard and the dedupe loop in rebuild(). The old comment here justified the line with "a
	# later re-evaluation of the same event", and on this seam there is no such re-evaluation. Three
	# facts, read off the 1.4.3 source at the frame close (2026-09-15):
	#  - the ONLY path that re-runs triggers_on_event at execute time is
	#    event_gear_activate.check_specific_context (:38-41), behind the action's own
	#    recheck_trigger_before_execution flag - which defaults to false (action_reaction.gd:10) and
	#    which action_draw_fire.tres does not set;
	#  - execute_reaction_events(ATTACK_DECLARED, PRE) runs exactly once per declared attack
	#    (event_unit_attack_declared.gd:21-23), so the gate is asked once;
	#  - the engine evaluates every reaction's gate before any body runs, so a second Subutai's gate is
	#    asked BEFORE the first has drawn, never after. The stamp in activate() is what refuses it, and
	#    test_a_second_subutai_cannot_redraw_an_attack_already_drawn pins that.
	# So this branch cannot currently be reached by anything. It stays because it is the correct defence
	# the day recheck_trigger_before_execution IS set on this action, and because it costs a meta lookup.
	if summary.has_meta(DRAWN_META): return false

	# "A hostile CHARACTER": a drone's or deployable's shot counts as its owner's (ruling 5).
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker) or not attacker.is_character(): return false
	if not UnitRelation.are_enemies(unit, attacker): return false

	# "makes a RANGED attack".
	if not UnitAction.is_ranged_weapon(triggering_context.action, triggering_context.gear): return false
	# THE AMR EXEMPTION IS UNREACHABLE ON THIS SEAM, and kept for parity with the NOAH's ward rather
	# than because it is honoured here. The only vanilla override of
	# is_immune_to_automisses_and_redirects is the Sniper's AMR, and it reads
	# AttackRoll.is_valid(context.object) and Unit.is_valid(context.target_unit) - an attack_declared
	# context carries neither, so that override can only ever return false here. Vanilla's base
	# ActionAttack returns false too (action_attack.gd:43), so on this seam the line never refuses
	# anything. It stays so that a future override keyed
	# off something this context DOES carry is honoured without anyone having to remember to add it.
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
	# A player who confirms the draw can still see nothing happen if the live rebuild below then
	# refuses it - deliberate, and strictly better than spending the point on nothing.
	#
	# NOTHING IS SPENT UNTIL THE DRAW IS KNOWN TO HAVE LANDED. Three guards, all re-asking at LIVE time
	# what triggers_on_event only answered when the event was queued:
	#
	#  1. the stamp, and it is THE guard that stops a second Subutai redrawing the same attack. Every
	#     reaction's gate is evaluated before any body runs, so when two Subutais both see the shot
	#     both are queued; the first to activate stamps the summary and the second aborts here,
	#     WITHOUT spending. The allies check below cannot do this job - after the first draw
	#     all_attacked_units is [Subutai A], and A is an allied character inside B's sensors, so B's
	#     allies_under_fire is NOT empty and B would happily redraw the attack onto itself. (The old
	#     comment here claimed the opposite; it was wrong, and this stamp is the fix.)
	#  2. the allies - and this one is UNREACHABLE, MEASURED, KEPT ANYWAY (frame close, 2026-09-15; the
	#     design's §2.2 "Guards" paragraph believed it was the guard against a second Subutai, and
	#     guard 1 above already records that it is not). Nothing between the trigger's own ally check
	#     and this line can empty the list: the only writer of all_attacked_units at this timing is
	#     another Draw Fire's rebuild, and after one of those has run the summary names the drawing
	#     Subutai - an allied character inside this one's sensors - so the list is non-empty, not
	#     empty, which is precisely why guard 1 had to exist. It stays as a cheap liveness check on a
	#     list this function is about to put in a player-facing prompt: a prompt about nobody is worse
	#     than a silent abort.
	#  3. the rebuild itself, run LIVE. rebuild() returns false without writing anything when the
	#     rebuilt area would not contain us, and the geometry it reads can have changed since the DRY
	#     check in triggers_on_event - another attack_declared PRE reaction may have displaced the
	#     Subutai or the ally while confirm_use was awaited. Checking its return before spend_actions
	#     is what stops that costing the point, leaving the attack undrawn, and still queueing a free
	#     Rail shot.
	#
	# ORDERING CONSEQUENCE, and it is safe: guard 3 rewrites the summary BEFORE the point is spent.
	# spend_actions does not read the summary - it only touches the activation's own gear and reaction
	# bookkeeping - so the earlier write changes nothing about what it does. The stamp goes on at the
	# same moment, for the same reason: it must be set only once the draw has actually landed, or a
	# refused rebuild would lock every other Subutai out of an attack nobody drew.
	if activation.abort_when(summary.has_meta(DRAWN_META)): return
	var allies := allies_under_fire(context.unit, summary)
	if activation.abort_when(allies.is_empty()): return

	var confirmed := await CommonActionUtil.confirm_use(
		context, allies, [], SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	if activation.abort_when(not rebuild(context.unit, triggering_context, true)): return
	summary.set_meta(DRAWN_META, true)

	spend_actions(activation)
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
	# The shot is built on the RAIL's gear, not this reaction's - they are different Kits since the
	# frame close. Getting this wrong would not crash: SpecificAction.create would pair the Rail
	# action with cp_siege_engine, and can_activate_gear would then check the wrong Kit's usage,
	# charges and destruction state.
	var rail_holder:GearCore = rail_gear(context.unit)
	var rail:Action = rail_action(context.unit)
	if rail == null: return
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker): return
	var shot := SpecificAction.create(context.unit, rail_holder, rail)
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

## The direct target tile CLOSEST to any ally we are answering for - step 1a's pick. Tile.INVALID when
## either array is empty, which the caller reads as "nothing to re-aim" and refuses.
##
## Tile.get_closest_pair_between measures every from/to pair (tile.gd:408-436) and breaks ties by
## Chebyshev, then by a tiebreaker distance, then by Manhattan - the engine's own ordering, the same
## one Tile.closest_possible_to picks the aim tile with two lines above. Allies are compared by their
## WHOLE footprint, so a size-2 ally is measured from the corner the attack actually reached.
static func nearest_target_to_allies(targets:Array[Vector2i], allies:Array[Unit]) -> Vector2i:
	var ally_tiles:Array[Vector2i] = []
	for allied:Unit in allies: ally_tiles.append_array(allied.occupied_tiles())
	var closest:Vector2i = Tile.get_closest_pair_between(targets, ally_tiles).from
	return closest

## THE REBUILD. DRY (live = false) answers "would the rebuilt area contain us?"; LIVE writes the four
## summary arrays in place. Copies ActionAttack.get_attacked_tiles_and_units_from_plan
## (action_attack.gd:156-173) step for step, so the rebuilt area is exactly what the attacker would
## have got by aiming there - with ONE deliberate departure. Everything else vanilla does is kept,
## including its NON-DUPLICATE append of both the AoE tiles and the units in them - though for the
## TILES that turns out to be parity rather than protection, since get_aoe_tiles already returns a
## unique array (measured; see the comment at the append itself).
##
## THE DEPARTURE: vanilla seeds attacked_units from the plan's DIRECT targets before the AoE branch
## runs (`attacked_units.assign(plan.target_units)`, action_attack.gd:160); the AoE branch here starts
## new_units EMPTY and takes only what get_all_units_at_tiles finds in the rebuilt area. There is no
## plan to read from at this seam - the summary is all we have, and its all_attacked_units is the
## POST-AoE list, so seeding from it would re-admit units the rebuild has just moved the area off.
## Harmless here for the one thing this function decides: the reactor is inside the rebuilt area by
## construction (every allied tile became our aim tile), so the `new_units.has(unit)` verdict cannot
## turn on the seed. The seed would only matter for a unit the MAP does not index inside the area it
## occupies - and the size-2 footprint case that could produce is pinned the other way, by
## assert_map_indexes_the_whole_footprint in spec/test_draw_fire.gd. The non-AoE branch does the
## equivalent of the seed explicitly, mapping each attacked unit to us.
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
## RECORDED, UNMEASURED, AND DELIBERATELY NOT CHANGED: the aim tile is measured to the attacker's
## ANCHOR (specific.unit.tile()), where the engine's own start-tile pick for an AoE is symmetric -
## RangePattern.get_aoe_tiles takes Tile.closest_possible_to(occupied_tiles, target_tile) over the
## ATTACKER's footprint (range_pattern.gd:51,55). For a size-2 attacker the two can disagree about
## which of our four tiles is "nearest", by one tile. Every case in the suite has a size-1 attacker,
## so nothing measures it; it is a candidate for the next frame that fields a big shooter.
##
## THE SPLASH CASE, and why step 1a exists. The trigger's ally gate reads all_attacked_units, which
## includes SPLASHED units; step 1 only moves a direct target tile an allied character is STANDING on.
## Without 1a the two disagree, and an AoE merely splashing an ally rebuilds to the area it already
## had - `new_units.has(unit)` is false, the dry rebuild returns false, and the reaction is silently
## never offered. Three routine ways in, all reachable on 1.4.3: an AoE aimed at a friendly DEPLOYABLE
## (NPC behaviours weight those positively - npcc_demolisher's action_seismic_destroyer_demolisher.tres
## sets weight_deployables = 1.25) whose splash catches an allied mech; an AoE aimed at an allied
## character OUTSIDE our Sensors whose splash catches one inside them; and, from a player-side
## attacker, an AoE aimed at empty ground beside an ally. Found at the frame close, 2026-09-15.
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
	var moved_targets:Array[Vector2i] = []
	var moved_an_allys_tile := false
	for tile:Vector2i in summary.directly_attacked_tiles:
		var moved := tile
		for allied:Unit in allies:
			if allied.occupied_tiles().has(tile):
				moved = aim
				moved_an_allys_tile = true
				break
		moved_targets.append(moved)

	# 1a. THE SPLASH CASE: the ally is CAUGHT but nothing is AIMED at it, so step 1 moved nothing and
	# the rebuild would hand back the area the attack already had. Re-aim the single direct target
	# CLOSEST to an ally we are answering for - the one whose area the splash came out of - and leave
	# every other direct target where the attacker put it, exactly as step 1 does.
	#
	# NEAREST RATHER THAN "whichever target's rebuilt area would contain us": one derivation, no
	# geometry loop, and the same answer on every case reachable today, since an ally is splashed by
	# the area it is nearest to. Nothing downstream is relaxed to make this work - the area is rebuilt
	# the same way, the unit refilter is the same, a Burst is still refused before either, and a Line
	# or Cone that still cannot reach us is still refused by `new_units.has(unit)` (ruling 2).
	if not moved_an_allys_tile:
		var splashed_from := nearest_target_to_allies(moved_targets, allies)
		var index := moved_targets.find(splashed_from)
		if index < 0: return false # no direct target to move: nothing this reaction can draw
		moved_targets[index] = aim

	# DEDUPED HERE rather than as they are appended, because 1a substitutes by index: two ally tiles
	# collapsing onto our one aim tile must still leave one direct target, as before.
	var new_targets:Array[Vector2i] = []
	for tile:Vector2i in moved_targets:
		Util.append_nonduplicate(new_targets, tile)

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
		# NON-DUPLICATE, as vanilla appends them (action_attack.gd:165-166) - and MEASURED REDUNDANT,
		# KEPT ANYWAY. The SP2 review expected duplicates here, because the rebuild is the one thing in
		# the game that routinely makes two direct targets' areas overlap (it drags one onto our aim
		# tile and leaves the others where they were) and RangePattern.get_aoe_tiles append_arrays each
		# target's area (range_pattern.gd:54-65). They do not appear: get_aoe_tiles ends by calling
		# filter_valid_aoe_tiles, which filters through Util.filter_and_remove_duplicates
		# (range_pattern.gd:79-80), so the array comes back unique already. Measured 2026-09-15:
		# assigning the result straight to new_tiles reddened nothing, test_two_overlapping_blasts_do_
		# not_double_up_the_attacked_tiles included. The loop stays because it is what VANILLA does at
		# this exact step, so the rebuild keeps matching it line for line if that filter ever moves.
		for tile:Vector2i in specific.action.get_aoe_tiles_with_targets(pattern, new_targets, specific.unit.tile(), specific):
			Util.append_nonduplicate(new_tiles, tile)
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
