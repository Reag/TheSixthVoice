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
## THE PULL RULE (ruling 10, the author's call). "In the direction of the attacker" is read as: the
## destination lies within the roll, and the distance to the attacker shrinks by EXACTLY the spaces
## moved. A cone toward the attacker, with no sideways drift, and no requirement that the attacker was
## out of threat beforehand. Measured the way generate_pull_events measures
## (common_action_util.gd:159) - tile-to-footprint by closest pair, 2-D - so the two agree.
##
## LINE OF SIGHT IS REQUIRED here and not for Step, which looks inconsistent and is the card's own
## doing: Bel exempts Step in so many words ("without requiring line of sight") and leaves this one
## silent, so it takes Lancer's default (ruling 10).
##
## "UP TO THAT MANY SPACES" INCLUDES ZERO, and zero forfeits the Skirmish (ruling 5): the reaction is
## spent from step 2 onwards whatever happens, but the follow-up shot needs the mech to have actually
## moved. A field veto, a cancelled pick and a zero-space result all lose it; a one-space sideways
## teleport beside an already-adjacent attacker keeps it.
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
	# THE ORIGIN COMPARISON IS DEFENSIVE AND CURRENTLY UNREACHABLE, which is recorded rather than
	# hidden: the cone's own filter requires `moved > 0`, so the origin is never in the offered set and
	# no spec can produce a zero-space landing through the picker. Deleting it reddens nothing
	# (measured 2026-09-17). It stays because the two facts are independent - a future widening of the
	# cone, or a movement-restriction interaction that lands the mech back where it began, would make
	# it load-bearing again, and ruling 5 is explicit that zero forfeits the shot.
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

## The pull-rule filter: keep a tile only when moving there shrinks the distance to the attacker by
## EXACTLY the spaces moved.
##
##   d(origin, attacker) - d(destination, attacker) == d(origin, destination)
##
## Distances are tile-to-footprint by closest pair, the way generate_pull_events measures
## (common_action_util.gd:159, Tile.get_closest_pair_between(...).distance), so a large attacker is
## measured to its nearest tile rather than to its anchor. That equality is what makes this a cone
## rather than "any closer tile": a sideways step that happens to end one space nearer fails it,
## because it moved further than it gained.
func toward(unit:Unit, attacker:Unit) -> Callable:
	var attacker_tiles:Array[Vector2i] = attacker.occupied_tiles()
	var origin_tiles:Array[Vector2i] = unit.occupied_tiles()
	var from_attacker:int = Tile.get_closest_pair_between(origin_tiles, attacker_tiles).distance
	return func(tile:Vector2i) -> bool:
		var destination:Array[Vector2i] = [tile]
		var moved:int = Tile.get_closest_pair_between(origin_tiles, destination).distance
		var gained:int = from_attacker - Tile.get_closest_pair_between(destination, attacker_tiles).distance
		return moved > 0 and gained == moved
