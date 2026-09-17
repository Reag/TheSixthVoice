## ABJURATION OF METAL: the shot goes wide and the Maiden's Blush is suddenly closer.
##
##   Trigger: "A hostile character within sensors misses you with an attack."
##   Effect:  "Roll 1d6: You may teleport up to that many spaces in the direction of the attacker. If
##             this puts the attacker in Threat of one of your weapons, you may immediately use that
##             weapon to Skirmish against them."
##
## THIS TELEPORT IS PREVENTABLE, AND ON PURPOSE - it is the opposite of Step of Mist and Thunder's.
## It goes through Teleport.pathfinder, which builds a real Pathfinder, so Immobilized stops it
## (pathfinder.gd:333) and so does every MOVEMENT_RESTRICTION ban (:345-352). Only Step carries the
## card clause that beats those, and only Step pays for it.
##
## THE PULL RULE (ruling 10, the author's call). "In the direction of the attacker" is read as:
## the destination lies within the roll, and the attacker lies on the path - either between the
## mech and the destination, or the destination between the mech and it (reach design ruling A,
## 2026-09-17, widening the shipped approach-only cone). No sideways drift, and no requirement
## that the attacker was out of threat beforehand. Measured the way generate_pull_events measures
## (common_action_util.gd:159) - tile-to-footprint by closest pair, 2-D - so the two agree.
##
## LINE OF SIGHT IS REQUIRED here and not for Step, which looks inconsistent and is the card's own
## doing: Bel exempts Step in so many words ("without requiring line of sight") and leaves this one
## silent, so it takes Lancer's default (ruling 10).
##
## "UP TO THAT MANY SPACES" INCLUDES ZERO, and zero forfeits the Skirmish (ruling 5): the reaction is
## spent from step 2 onwards whatever happens, but the follow-up shot needs the mech to have actually
## moved. A field veto, a cancelled pick and a zero-space result all lose it.
##
## RULING 5'S QUALIFYING EXAMPLE - a ONE-SPACE SIDEWAYS teleport beside an already-adjacent attacker
## keeping the shot - still cannot arise, and that part of the 2026-09-17 amendment stands: a
## one-space step to either side satisfies neither clause of the filter at the foot of this file.
##
## WHAT CHANGED ON 2026-09-17 (reach design ruling A) IS THE TACTICAL SITUATION IT DESCRIBED. The
## shipped cone was empty beside an adjacent attacker at EVERY roll, so a point-blank miss earned the
## mech nothing at all; the overshoot clause now lets a TWO-space fold land it on the attacker's far
## side, which keeps the attacker inside a melee weapon's threat and so keeps the Skirmish. The cone
## is still empty at a roll of ONE, because the far side is two spaces away -
## spec/test_abjuration_of_metal.gd's test_no_valid_tile_leaves_the_reaction_spent_and_the_mech_unmoved
## presses exactly that, and test_an_adjacent_attacker_yields_the_far_side_at_a_roll_of_two is its
## other half.
##
## The gate below is still doing real work, which is why it asks whether the mech MOVED rather than
## whether the attacker is NEWLY in threat: a straight-line approach that ends inside threat is the
## ordinary way the Skirmish is earned, and a teleport that never happened must not earn it.
extends ActionReactionAttacked

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# The archetype does the heavy lifting: DEFENDER, ENEMIES, require_miss against the POST-timing
	# AttackRoll, and the weapon/tech/basic filters. Everything below is this card's own.
	if not super.triggers_on_event(unit, gear, triggering_event): return false

	var triggering_context:Context = triggering_event.context
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker): return false

	# "WITHIN SENSORS" IS A SUBCLASS CLAUSE because the archetype's require_attacker_within is a fixed
	# exported int (action_reaction_attacked.gd:19) and sensor range is a per-unit value. No line of
	# sight: the card says "within sensors", and sensors are not eyes (ruling 11).
	if UnitRelation.distance_between(unit, attacker) > unit.get_sensor_range(): return false

	# OVERWATCH'S RE-ENTRANCY GUARD (common_action_util.gd:578). The Skirmish below is itself a gear
	# use on this unit, and without this the reaction can be offered again from inside its own
	# follow-up.
	return not CommonActionUtil.is_choose_and_use_with_gear_in_progress(gear)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var triggering_context:Context = context.event.context
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if not Unit.is_valid(attacker): return
	var specific := SpecificAction.from_context(context)

	# 1. THE OFFER. Declining spends nothing - the reaction point and the 1/round are still in hand,
	# which is what lets a player hold the round's Abjuration for a shot they mind more.
	var confirmed:bool = await CommonActionUtil.confirm_use(context, [attacker])
	if activation.abort_when(not confirmed): return

	# 2. THE SPEND. From here the reaction is used however the rest goes (ruling 10) - no tile, a
	# cancelled pick, a vetoed teleport and a zero-space result all leave it spent.
	spend_actions(activation)

	# 3. THE ROLL.
	var roll:int = Dice.roll_d6()
	effect_bus.play_d6(roll, unit.tile())

	# 4. THE CONE. Line of sight ON, and the pull rule as the keep filter.
	var tiles := Teleport.candidate_tiles(unit, roll, true, toward(unit, attacker))
	if tiles.is_empty():
		battle_log.log_unit(&'gear.cp_caj_overhaul_modules.action_abjuration_of_metal.no_space.log', unit)
		return

	# 5. THE PICK, through a real pathfinder - so Immobilized and every ban apply, as they should.
	var pathfinder:Pathfinder = await Teleport.pathfinder(unit, tiles)
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return
	if activation.abort_without_unit(unit): return

	# 6. THE TELEPORT.
	var origin:Vector2i = unit.tile()
	var move:EventCore = await Teleport.move_along(activation, unit, pathfinder, plan)
	# RULING 5, three cases in one line: Uncertainty Field took it, the move failed, or the mech ended
	# where it started. "If THIS puts the attacker in threat" needs a this.
	#
	# THE ORIGIN COMPARISON IS DEFENSIVE AND NO SPEC CAN REACH IT FIRST, which is recorded rather than
	# hidden: the cone's own filter requires `moved > 0`, so the origin is never in the offered set and
	# no pick can produce a zero-space landing. Deleting it reddens nothing (measured 2026-09-17). It
	# stays because the two facts are independent - a future widening of the cone, or a
	# movement-restriction interaction that lands the mech back where it began, would make it
	# load-bearing again, and ruling 5 is explicit that zero forfeits the shot.
	#
	# IT IS NOT DEAD, THOUGH, AND THE WORD "UNREACHABLE" USED TO STAND HERE WRONGLY (corrected
	# 2026-09-17). A VETOED teleport lands on it too: Uncertainty Field aborts the move core one line
	# before undergo_move, so the mech is still standing on `origin` when this runs and both halves of
	# the test answer true at once. That is why deleting EITHER half alone leaves
	# spec/test_abjuration_of_metal.gd's test_a_vetoed_teleport_forfeits_the_skirmish green, and both
	# together turn it red.
	if move == null or move.aborted or unit.tile() == origin: return
	if activation.abort_without_unit(unit): return

	# 7. THE WEAPONS. Threat rather than range, Ordnance excluded, line of sight per weapon - which is
	# exactly what Overwatch asks for, and the reason this reads the same helper
	# (unit_relation.gd:220-225).
	var weapons:Array[SpecificAction] = UnitRelation.get_weapons_that_can_overwatch(unit, attacker)
	if weapons.is_empty(): return

	# 8. THE SKIRMISH, and it costs the mech NOTHING of its own. The shot is the WEAPON's own
	# SpecificAction, chosen from `weapons`; choose_and_use_no_spend is an empty body
	# (common_action_util.gd:775) and is what keeps the action economy untouched off-turn. Passing this
	# reaction's own already-spent specific as the follow-up's `using` is the Draw Fire and Uffish Gyre
	# mistake (memory lancer-tactics-attack-redirection-seam) - `using` is what gets spent, and it is
	# already gone.
	await CommonActionUtil.choose_and_use(
		activation, specific, weapons,
		CommonActionUtil.choose_and_use_no_spend,
		attacker, [Action.FLAG.CAN_FOLLOWUP]
	)

## The pull-rule filter: keep a tile only when the ATTACKER IS ON THE PATH - either between us and
## the tile, or the tile between us and it. Two clauses, one line of geometry each:
##
##   approach:   d(origin, destination) + d(destination, attacker) == d(origin, attacker)
##   overshoot:  d(origin, attacker)    + d(attacker, destination) == d(origin, destination)
##
## THE APPROACH CLAUSE IS THE SHIPPED RULE, RESTATED. `gained == moved`, with
## `gained = d(origin, attacker) - d(destination, attacker)`, is the same statement; nothing it kept
## is dropped, and the filter is a strict superset of what shipped. The overshoot clause is the
## 2026-09-17 widening (reach design ruling A): the mech folds THROUGH the attacker and comes out
## behind it, which is what an adjacent attacker needs before it yields any destination at all.
##
## SIDEWAYS DRIFT IS STILL REFUSED, which is the whole reason this is not "any closer free space
## within the roll": a tile that ends one space nearer while travelling four satisfies neither
## clause. That was the author's design-time rejection and it is preserved exactly.
##
## Distances are tile-to-footprint by closest pair, the way generate_pull_events measures
## (common_action_util.gd:159, Tile.get_closest_pair_between(...).distance), so a large attacker is
## measured to its nearest tile rather than to its anchor.
func toward(unit:Unit, attacker:Unit) -> Callable:
	var attacker_tiles:Array[Vector2i] = attacker.occupied_tiles()
	var origin_tiles:Array[Vector2i] = unit.occupied_tiles()
	var from_attacker:int = Tile.get_closest_pair_between(origin_tiles, attacker_tiles).distance
	return func(tile:Vector2i) -> bool:
		var destination:Array[Vector2i] = [tile]
		var moved:int = Tile.get_closest_pair_between(origin_tiles, destination).distance
		if moved <= 0: return false
		var to_attacker:int = Tile.get_closest_pair_between(destination, attacker_tiles).distance
		# APPROACH: the destination lies between us and the attacker. This is the shipped rule
		# restated - `gained == moved` is the same statement as `moved + to == from` - and it is
		# unchanged in effect.
		if moved + to_attacker == from_attacker: return true
		# OVERSHOOT: the ATTACKER lies between us and the destination. New 2026-09-17.
		return from_attacker + to_attacker == moved
