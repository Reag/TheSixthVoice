# SP2 PROBE: what an OWN-BUT-INVOLUNTARY teleport costs, and whether the reticle can be handed an
# explicit tile set. Vanilla frames only; nothing this file builds ships.
#
# THIS FILE IS DELETED IN SP2 TASK 4, once test_step_of_mist_and_thunder.gd covers the same ground
# against the real action. It exists because design §0.8 ("This teleportation cannot be prevented")
# rests on three facts nobody had measured, and the author approved a FALLBACK for each rather than
# leaving the build to guess:
#
#   1. Both Immobilized gates test movement_type.voluntary - Pathfinder.create (pathfinder.gd:333)
#      AND EventUnitMove.has_enough_move_to_reach_end (event_unit_move.gd:438-451, run at :156 after
#      the PRE reactions and at :288 per step). So bypassing the pathfinder beats BANS but not
#      Immobilized, and only an INVOLUNTARY type beats both. If that is wrong, Step keeps the
#      target-tile route with a voluntary type and the rulings record that Immobilized wins.
#   2. Pathfinder.create is also where every MOVEMENT_RESTRICTION ban lands (:345-352), bans winning
#      over adds, with no bypass parameter - so a move that never builds a pathfinder never reads
#      them at all.
#   3. An ActionSystem can offer an EXACT tile set through the reticle, which is what
#      Teleport.pick_tile needs. If it cannot, the fallback is the Thy Hubris reag_tile_set_picker
#      port (roadmap SP0, deferred to "the first frame that needs a free tile set").
#
# TWO CASES ARE OBSERVATIONS, NOT REQUIREMENTS - grapple and engagement (design §2.0's last two
# bullets). They are RECORDED in the rulings and designed around by nobody. They assert `true` and
# print, so a surprising measurement cannot fail the suite; the value is in the log and the ledger.
#
# THE VETO LISTENER AND run_move ARE COPIED FROM test_teleport.gd, NOT IMPORTED. This file is
# deleted in Task 4 and test_teleport.gd is not; an import would make the deletion a breaking change.
extends GutTest

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## Bigger than the fixture's 15x9 default: a 2d6 Step reaches 12, and the pull-rule and
## behind-a-wall cases need room on both sides of a wall.
const MAP_SIZE := Vector2i(20, 20)

const START := Vector2i(4, 4)
const DESTINATION := Vector2i(8, 4)

## CLOSE, and the closeness is the whole control. buff_interdiction_field.get_values has TWO
## branches (:29-34), and the geometry decides which one the mech meets:
##   - holder further than 3 from the mover: allowed = every tile EXCEPT the field's own radius.
##   - holder within 3 of the mover: allowed = the BLANK array, i.e. nothing at all.
## Combined with `boolean = false` ("ban every tile not in this array"), the second branch is a total
## lockdown and the first is a doughnut. MEASURED THIS SESSION, and it cost a red: with the hostile at
## (14, 4) the first branch ran, the doughnut's hole was nowhere near the mech's 6-tile reach, and the
## pathfinder happily found destinations - a control that proved nothing. At distance 2 the second
## branch runs, every tile is banned, and DESTINATION is inside the field as well.
const HOSTILE_TILE := Vector2i(6, 4)

var game:Gamemaster
var unit:Unit
var hostile:Unit

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self, MAP_SIZE)
	unit = SpecFactory.create_unit(game.map, START)
	unit.core.full_repair()
	hostile = FitzgeraldFixture.create_dummy(game, HOSTILE_TILE, 10, Faction.AI_ENEMY)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Run one event_unit_move and hand the core back, so a test can read `aborted`.
## game.execute_event does the same job and returns nothing.
func run_move(event_data:Dictionary) -> EventCore:
	var core := EventCore.create(&'event_unit_move', event_data)
	await game.execute_event_block(EventBlock.create_multiple([core]))
	return core

func immobilize() -> void:
	UnitCondition.apply_status(SpecFactory.dummy_event(), unit,
		Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	assert_true(UnitCondition.is_immobilized(unit), 'Fixture: the unit is immobilized.')

## The Minotaur's Interdiction Field, hung straight on the hostile rather than equipped and woken.
## buff_interdiction_field.tres is `to = &"movement_restriction"` and its check_if_passive_applies
## asks only for a teleporting movement type and an enemy holder (buff_interdiction_field.gd:15-21),
## so nothing about the aura machinery is load-bearing for the BAN.
func field_the_hostile() -> void:
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), hostile, &'buff_interdiction_field')

## The prototype of SP2's Teleport.candidate_tiles, written here so the probe does not depend on a
## function Task 2 has not added yet.
func candidate_tiles(of:Unit, within:int, require_los:bool) -> Array[Vector2i]:
	var katamari := Katamari.create_solipsistic(of)
	var type := Teleport.movement_type(of)
	var tiles := UnitTile.get_tiles_within(of, within, require_los)
	Util.filter(tiles, func(tile:Vector2i) -> bool:
		if of.occupied_tiles().has(tile): return false
		return UnitTile.is_tile_standable(of, tile, katamari, type)
	)
	return tiles

## A hand-built single-step path, which is the ONE shape that never lets event_unit_move build a
## pathfinder of its own. The cost is nominal: nothing reads it once spend_move is false.
func one_step_path(to_tile:Vector2i) -> Array[Pathfinder.Step]:
	var path:Array[Pathfinder.Step] = [Pathfinder.Step.create(to_tile, 1)]
	return path

## ENTIRE_MOVEMENT / PRE on its holder's own moves. Copied from test_teleport.gd and given one extra
## field: whether Teleport.is_own could read the OWN tag AT PRE, which is what ruling 4 needs (the
## Uncertainty Field has to be able to take a Step).
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive to be asked about the next move too.
class VetoListener extends Buff:
	var heard:int = 0
	var saw_own_tag := false
	var veto := true

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		to = Buff.TO.NONE
		hide_from_player = true
		until = Lancer.UNTIL.MANUAL

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]

	func triggers_on_event(_core:BuffCore, holder:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.unit != holder: return false
		return Teleport.is_teleport(context)

	func activate(_core:BuffCore, activation:EventCore) -> void:
		heard += 1
		var triggering:EventCore = activation.context.event
		saw_own_tag = Teleport.is_own(triggering.context.resource)
		if veto: Teleport.veto(triggering)

func arm_listener(should_veto:bool = true) -> VetoListener:
	var listener := VetoListener.new()
	listener.veto = should_veto
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(listener))
	return listener

# ---------------------------------------------------------------- 1-3: the two Immobilized gates

func test_a_voluntary_target_tile_teleport_lands():
	await run_move({unit = unit, target_tiles = [DESTINATION], resource = Teleport.movement_type(unit)})
	assert_eq(unit.tile(), DESTINATION, 'Control: a voluntary target-tile teleport lands.')

func test_an_immobilized_units_voluntary_target_tile_teleport_does_not_land():
	# THE MEASUREMENT THE WHOLE OF RULING 8 HANGS ON. This move never touches a pathfinder, so if it
	# still refuses to land, the SECOND gate (event_unit_move.gd:451) is real and bypassing the
	# pathfinder is not enough on its own.
	immobilize()
	await run_move({unit = unit, target_tiles = [DESTINATION], resource = Teleport.movement_type(unit)})
	assert_eq(unit.tile(), START, 'The move event refuses it by itself: event_unit_move.gd:451.')

func test_an_own_involuntary_teleport_lands_while_immobilized():
	immobilize()
	var core := await run_move({unit = unit, target_tiles = [DESTINATION],
		resource = Teleport.movement_type(unit, true)})
	assert_false(core.aborted, 'Nothing aborted it.')
	assert_eq(unit.tile(), DESTINATION, 'Ruling 8: an involuntary type clears both gates.')

# ---------------------------------------------------------------- 4: the ban, and the bypass

func test_a_voluntary_pathfinder_teleport_finds_nothing_inside_a_hostile_interdiction_field():
	# The positive control. Without this, the next test proves only that the mech moved.
	field_the_hostile()
	var pf:Pathfinder = await Pathfinder.generate_for_given_tiles(
		unit, UnitTile.get_tiles_within(unit, 6, false), Teleport.movement_type(unit))
	assert_true(pf.valid_destinations.is_empty(),
		'The ban is live on the pathfinder route (pathfinder.gd:345-352).')

func test_a_target_tile_teleport_is_STILL_BANNED_however_involuntary_it_is():
	# THE PROBE'S HEADLINE FINDING, and it corrects design §0.8 and §4. "Moves by target tile through
	# event_unit_move WITHOUT a pathfinder" is FALSE: undergo_move builds one ITSELF when it is given a
	# target tile rather than a path (event_unit_move.gd:139-145,
	# `Pathfinder.generate_for_given_tiles(unit, given_tiles, movement_type)` then `path_to`). So the
	# target-tile route reads every MOVEMENT_RESTRICTION ban after all.
	#
	# It beats IMMOBILIZED (the test above) only because Pathfinder.create's immobilized gate is
	# voluntariness-checked at :333, while the ban read at :345-352 is not checked against anything.
	# Involuntariness buys the first and never the second.
	#
	# Vanilla's own event_unit_teleport takes this same route, so a scripted teleport is banned by an
	# Interdiction Field too. Recorded, not acted on: not our file.
	field_the_hostile()
	await run_move({unit = unit, target_tiles = [DESTINATION],
		resource = Teleport.movement_type(unit, true)})
	assert_eq(unit.tile(), START, 'The target-tile route builds its own pathfinder, so the ban bites.')

func test_an_own_involuntary_teleport_BY_PATH_lands_inside_a_hostile_interdiction_field():
	# THE SHAPE THAT ACTUALLY DELIVERS RULING 8. Handed an explicit path, undergo_move takes the
	# `if not context.array.is_empty()` branch (event_unit_move.gd:137-138) and never builds a
	# pathfinder at all - so nothing ever reads a MOVEMENT_RESTRICTION buff.
	#
	# ONE STEP OF ANY LENGTH IS LEGAL FOR A TELEPORT: is_next_step_possible waives the "adjacent to us"
	# rule when movement_type.teleport (:385). And has_enough_move_to_reach_end returns true at its
	# `not movement_type.spend_move` early exit (:454) - spend_move defaults false
	# (movement_type.gd:5) and Teleport.movement_type never sets it - after its own immobilized check,
	# which is voluntariness-gated and so passes.
	field_the_hostile()
	await run_move({unit = unit, array = one_step_path(DESTINATION),
		resource = Teleport.movement_type(unit, true)})
	assert_eq(unit.tile(), DESTINATION, 'Ruling 8, delivered: no pathfinder is ever built.')

func test_an_own_involuntary_teleport_BY_PATH_also_lands_while_immobilized():
	# The path route must not lose what the target-tile route already had.
	immobilize()
	await run_move({unit = unit, array = one_step_path(DESTINATION),
		resource = Teleport.movement_type(unit, true)})
	assert_eq(unit.tile(), DESTINATION, 'Immobilized is beaten by the path route too.')

func test_a_VOLUNTARY_path_teleport_still_loses_to_immobilized():
	# Which is the control that proves the flag is doing the work, not the path.
	immobilize()
	await run_move({unit = unit, array = one_step_path(DESTINATION),
		resource = Teleport.movement_type(unit)})
	assert_eq(unit.tile(), START, 'has_enough_move_to_reach_end:451 still refuses a voluntary move.')

# ---------------------------------------------------------------- 5: the seam still opens

func test_the_pre_trigger_fires_for_it_the_tag_is_readable_and_a_veto_holds():
	var listener := arm_listener()
	var core := await run_move({unit = unit, target_tiles = [DESTINATION],
		resource = Teleport.movement_type(unit, true)})
	assert_eq(listener.heard, 1, 'ENTIRE_MOVEMENT / PRE fires for an involuntary teleport too.')
	assert_true(listener.saw_own_tag, 'Teleport.is_own reads true at PRE - ruling 4.')
	assert_true(core.aborted, 'And the veto held.')
	assert_eq(unit.tile(), START, 'It did not move.')

func test_a_listener_that_declines_leaves_the_involuntary_teleport_alone():
	# The other half of the pair: "the field was offered and said no" must not look like "the field
	# was never offered".
	var listener := arm_listener(false)
	var core := await run_move({unit = unit, target_tiles = [DESTINATION],
		resource = Teleport.movement_type(unit, true)})
	assert_eq(listener.heard, 1, 'Still offered.')
	assert_false(core.aborted, 'Nothing aborted it.')
	assert_eq(unit.tile(), DESTINATION, 'And it landed.')

# ---------------------------------------------------------------- 6: the reticle over an exact set

## A throwaway ActionSystem whose targetable set is whatever we hand it. MECHANISM A of the two the
## design left open (§2.4): UnitTargeting.get_tiles_targetable returns targetable_tiles_override's
## result VERBATIM and before any other filtering (unit_targeting.gd:68-74), which is the whole
## mechanism - no range pattern to fight, no line-of-sight pass to disable, no ACTION_TILE buffs.
##
## The real Step of Mist and Thunder cannot park its tiles on the Action resource the way this
## throwaway does, because one Action resource is shared by every unit carrying the gear. It reads
## the rolled range off per-unit GEAR STATE instead (gear_core.gd:256-269) and rebuilds the set in
## the callable. That difference is why this class is a probe and not a draft.
class TileSetPicker extends ActionSystem:
	var offered:Array[Vector2i] = []

	func _init() -> void:
		action_type = Lancer.ACTION.QUICK
		requires_line_of_sight_baseline = false

	func get_target_requirements(_specific:SpecificAction) -> TargetRequirements:
		var reqs := TargetRequirements.create(1, RangePattern.create(Lancer.AOE_TYPE.NONE, 0))
		reqs.can_target_empty_tiles = true
		reqs.can_target_units = false
		reqs.requires_free_space = true
		reqs.targetable_tiles_override = func(
			_s:SpecificAction,
			_picks:Array = [],
			_from_tile := Tile.INVALID,
			_los:PackedInt64Array = []
		) -> Array[Vector2i]: return offered
		return reqs

## Hang the throwaway picker on a real piece of the mech's gear, so the SpecificAction is valid.
## mw_improvised_attack is in every unit's basic loadout, so nothing needs equipping.
func picker_for(tiles:Array[Vector2i]) -> Array:
	var picker := TileSetPicker.new()
	picker.offered = tiles
	return [picker, SpecificAction.create(unit, unit.get_gear(&'mw_improvised_attack'), picker)]

## A sight-blocking wall WEST of the mech, clear of the hostile in the east. test_hole_puncher.gd's
## recipe: forbidden_interiors_enabled is already true (FitzgeraldFixture.create_game sets it before
## the setpieces land, which is the order that matters), then re-push the blockers by hand the way
## vanilla's own test_map_sightlines.gd does.
func build_west_wall() -> void:
	var wall:Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', wall)
	game.map.calculate_los_blockers()

func test_the_reticle_offers_exactly_the_tile_set_it_is_handed():
	var tiles := candidate_tiles(unit, 3, false)
	assert_false(tiles.is_empty(), 'Fixture: there is something to offer.')
	var picker_and_specific := picker_for(tiles)
	assert_eq(UnitTargeting.get_tiles_targetable(picker_and_specific[1]), tiles,
		'targetable_tiles_override is returned verbatim - mechanism A works.')

func test_the_set_can_include_a_standable_tile_behind_a_wall():
	# The clause the card actually cares about: "without requiring line of sight".
	build_west_wall()
	var blind := candidate_tiles(unit, 3, false)
	var sighted := candidate_tiles(unit, 3, true)
	var behind:Vector2i = Vector2i(1, 4)
	assert_true(blind.has(behind), 'Without line of sight, the tile behind the wall is offered.')
	assert_false(sighted.has(behind), 'With it, the same tile is not - so the wall really blocks.')
	assert_eq(UnitTargeting.get_tiles_targetable(picker_for(blind)[1]), blind,
		'And the reticle offers the blind set unchanged.')

func test_cancelling_the_pick_returns_an_aborted_plan():
	# The half a synchronous assertion cannot reach. SpecFactory's responder aborts a compcon-plan
	# request when abort_all is set (spec_factory.gd:504), and ask_for_targets_alt turns a null or
	# aborted plan into CompconPlan.create_aborted() (target_action_util.gd:203) - which is what
	# Teleport.pick_tile reads as Tile.INVALID.
	var responder:SpecFactory.ChoiceBusResponder = SpecFactory.current_responder
	responder.abort_all = true
	var specific:SpecificAction = picker_for(candidate_tiles(unit, 3, false))[1]
	var plan:CompconPlan = await TargetActionUtil.ask_for_targets_alt(SpecFactory.dummy_event(), specific)
	responder.abort_all = false
	assert_true(plan == null or plan.aborted, 'A cancelled pick comes back aborted.')
	assert_eq(unit.tile(), START, 'And nothing moved.')

func test_an_uncancelled_pick_returns_the_first_offered_tile():
	# The positive control for the test above, and the behaviour MaidensBlushFixture.step will lean on:
	# with can_target_empty_tiles and no unit targets, the responder takes targetable_tiles.slice(0,
	# count) - the FIRST offered tile (spec_factory.gd:481-482).
	var tiles := candidate_tiles(unit, 3, false)
	var specific:SpecificAction = picker_for(tiles)[1]
	var plan:CompconPlan = await TargetActionUtil.ask_for_targets_alt(SpecFactory.dummy_event(), specific)
	assert_false(plan == null or plan.aborted, 'It answered.')
	assert_eq(plan.target_tiles, [tiles.front()] as Array[Vector2i], 'With the first offered tile.')

# ---------------------------------------------------------------- 7-8: recorded, not designed

func test_what_an_own_involuntary_teleport_does_to_a_grapple():
	# GRAPPLED-and-not-larger is one of is_immobilized's three causes (unit_condition.gd:416), so an
	# unpreventable Step escaping a grapple is a CONSEQUENCE of ruling 8, not a choice anyone made.
	# RECORDED for the rulings; the author decides at the frame close whether it should stand.
	#
	# The grapple is built the way onhit_grapple.on_hit builds one, rather than by landing a real
	# mw_grapple attack: attach, recalculate who is larger, then status both ways.
	var event := SpecFactory.dummy_event()
	Katamari.attach_units(event, hostile, unit, &'spec_grapple')
	Katamari.create(hostile).recalculate_largest_unit(hostile, event, false)
	UnitCondition.apply_status(event, hostile, Lancer.STATUS.GRAPPLED, Lancer.UNTIL.MANUAL, unit.core.persistent_id)
	UnitCondition.apply_status(event, unit, Lancer.STATUS.GRAPPLED, Lancer.UNTIL.MANUAL, hostile.core.persistent_id)
	assert_true(UnitCondition.is_immobilized(unit), 'Fixture: grappled and not the larger one.')

	var grappler_before := hostile.tile()
	await run_move({unit = unit, array = one_step_path(DESTINATION),
		resource = Teleport.movement_type(unit, true)})

	gut.p('GRAPPLE OBSERVATION: blush %s -> %s | still GRAPPLED: %s | grappler %s -> %s' % [
		START, unit.tile(), unit.has_status(Lancer.STATUS.GRAPPLED), grappler_before, hostile.tile()])
	assert_true(true, 'Observation only - see the printed line and the ledger.')

func test_what_an_own_involuntary_teleport_does_to_engagement_and_spaces_moved():
	# spaces_moved_this_turn is unit_battle_state.gd:38, an exported int that resets every turn.
	await SpecFactory.start_turn(game, unit)
	var moved_before:int = unit.state.spaces_moved_this_turn
	await run_move({unit = unit, array = one_step_path(DESTINATION),
		resource = Teleport.movement_type(unit, true)})

	gut.p('MOVEMENT OBSERVATION: spaces_moved_this_turn %s -> %s | landed %s | engaged after: %s' % [
		moved_before, unit.state.spaces_moved_this_turn, unit.tile(),
		UnitRelation.is_close_enough_to_engage(unit, hostile)])
	assert_true(true, 'Observation only - see the printed line and the ledger.')
