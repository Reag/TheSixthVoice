# MASTICATION OF THE MAAR, the second pressable on EARTH SHAKER GRAV-GEN (design §2.3): "Choose a
# Blast 1 area within Sensors and line of sight that contains no hostile Characters. For the rest of
# the scene it becomes difficult terrain."
#
# THE CRATER IS A UNIT. There is no such thing as "terrain the map remembers" in this engine that a
# mod can write to: MapState.ground_surface_terrain is the level's own data, and everything a card
# adds is DYNAMIC terrain projected by a unit that is standing there (map_state.gd:423-434). So "for
# the rest of the scene it becomes difficult terrain" is a MARKER deployable, dep_maar, carrying a
# PassiveTerrainZone - the Apocalypse Rail's crater, which is the vanilla precedent, line for line.
#
# AND IT HAS TO OUTLIVE ITS MAKER. Frame.is_deactivated_on_owner_death defaults to TRUE (frame.gd:65)
# and EventService.remove_unit_from_game queues event_unit_die on every owned MARKER that has it
# (event_service.gd:56-63). Terrain.lay records an owner, so without dep_maar.tres setting that export
# false the crater dies with the Vauban and the card's "for the rest of the scene" is quietly not
# delivered. Measured at SP1 Task 2 mutation 4; test_the_crater_survives_the_vaubans_death and
# test_the_card_carries_the_persists_tag are the two pins, and both go red without that one line.
#
# WHY THE TARGETING CLAUSES ARE ASKED OF UnitTargeting AND NOT OF A PRESS. TargetActionUtil takes a
# SUPPLIED tile automatically and does NOT re-validate it against get_tiles_targetable
# (target_action_util.gd:230-242 - the only filter on the way in is Tile.is_valid at :171). So
# SpecFactory.use(..., a_forbidden_tile) lays a crater there quite happily, and a test written as
# "press it at a blocked tile and assert no crater" would assert nothing at all. The filter's real
# consumer is the player's targeting screen, which is get_tiles_targetable, so that is what the
# filter section below asks.
#
# WHICH OF THOSE TESTS ACTUALLY DISCRIMINATE OUR PREDICATE, stated plainly so nobody reads more into
# the section than it proves. Vanilla's TargetRequirements.standard_check_if_tile_is_free refuses a
# tile holding ANY non-marker, non-exiled unit (target_requirements.gd:74-84), and the caltrop
# launcher's predicate is the same shape (action_caltrop_launcher.gd:12-18). Measured against that:
#
#   - the two HOSTILE cases pin the card but would pass with either stock predicate too;
#   - the ALLY case can only pass with ours, and reddens when are_enemies is dropped;
#   - the hostile OBJECT case can only pass with ours, and reddens when is_character() is dropped -
#     the two clauses are independent, so they need a mutation each;
#   - the PREVIOUS-MAAR case cannot be reddened at all, because every predicate in the engine lets
#     markers through. It is a pin on the card, not evidence for the filter, and says so at its site.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mastication_of_the_maar.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const CORE_ID := &'cp_earth_shaker_grav_gen'
const MAAR_ACTION := &'action_mastication_of_the_maar'
const MAAR_FRAME := &'dep_maar'
const MAAR_TRAIT := &'mt_maar_terrain'

const MAP_SIZE := Vector2i(21, 13)
const VAUBAN_TILE := Vector2i(4, 6)
const NEAR_CENTRE := Vector2i(8, 6)   ## distance 4: inside Sensors 8
const FAR_CENTRE := Vector2i(18, 6)   ## distance 14: outside Sensors 8
const SECOND_CENTRE := Vector2i(10, 9) ## distance 6, and its Blast 1 does not touch NEAR_CENTRE's

var game:Gamemaster
var vauban:Unit

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	VaubanFixture.track(game)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func core() -> GearCore:
	return vauban.get_gear(CORE_ID)

func maar_action() -> Action:
	return core().get_action(MAAR_ACTION)

func specific() -> SpecificAction:
	return SpecificAction.create(vauban, core(), maar_action())

func is_difficult(tile:Vector2i) -> bool:
	return game.map.get_surface_terrain_at(tile).is_difficult()

func blast_1_around(centre:Vector2i) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for dx:int in [-1, 0, 1]:
		for dy:int in [-1, 0, 1]:
			tiles.append(centre + Vector2i(dx, dy))
	return tiles

## Open a FRESH turn for the Vauban, ending the current one first if it is in one.
##
## VaubanFixture.open_turn is a no-op when the unit is already taking its turn
## (fitzgerald_fixture.gd:124-125). That is right for every other spec in this frame and wrong for
## this one, because THE SAME QUICK ACTION CANNOT BE PRESSED TWICE IN ONE TURN: Lancer's no-repeat
## rule lives in Action.get_per_turn_soft_limit, which returns 1 for anything that is not free
## (action.gd:161-163), and UnitAction.can_activate_gear consults it (unit_action.gd:116).
##
## MEASURED 2026-09-18, and worth writing down because the failure is silent in the useful sense:
## the second press aborts with "[ ABORT event_gear_activate ] ... specific: invalid" and NO
## "[ Gear not available ]" line at all, because get_gear_unavailable_reason answers NONE and the
## per-turn limit is asked afterwards by can_activate_gear. Without this helper the three
## two-crater tests each laid exactly one crater and read as "the deployable is being removed".
func new_turn() -> void:
	if vauban.state.is_taking_turn: await SpecFactory.end_turn(game, vauban)
	await VaubanFixture.open_turn(game, vauban)

## Lay a Maar centred on `centre`, through the real action, on a turn of its own.
##
## THE TURN IS NOT DECORATION: a QUICK action has to be affordable, and CompconPlan.is_valid_with_targets
## refuses the plan outright when it is not (compcon_plan.gd:53-55, via UnitAction.is_gear_affordable).
## Only event_turn_start hands the unit its actions back.
func lay_maar(centre:Vector2i) -> void:
	await new_turn()
	await SpecFactory.use(game, vauban, CORE_ID, MAAR_ACTION, centre)
	VaubanFixture.track(game)

func maars() -> Array:
	return UnitAction.get_deployables_from(vauban, core(), MAAR_FRAME)

## The set of tiles the engine would let the Vauban pick right now - i.e. what the targeting screen
## would light up.
func targetable() -> Array[Vector2i]:
	return UnitTargeting.get_tiles_targetable(specific())

# ---------------------------------------------------------------- wiring and text

func test_the_action_is_a_quick_tile_pick_within_sensors() -> void:
	var action := maar_action()
	assert_not_null(action, 'the action is on the core Kit')
	if action == null: return
	assert_eq(action.get_action_type(specific()), Lancer.ACTION.QUICK, 'QUICK')
	assert_eq(action.get_target_range(specific()), vauban.get_sensor_range(), 'range is Sensors')
	assert_true(action.requires_line_of_sight(specific()), 'and it needs line of sight')
	# consumes_core_power() is declared `-> int` while returning a bool export (action_system.gd:31,
	# action.gd:167), so GUT's assert_false throws "Cannot convert 0 to boolean" on it. Asked through
	# the call the engine's own refusal chain makes (unit_action.gd:146), not through the export.
	assert_eq(int(action.consumes_core_power()), 0, 'it does NOT spend the core point: the protocol does')

func test_the_cards_text_resolves() -> void:
	var key := 'gear.%s.%s.effect' % [CORE_ID, MAAR_ACTION]
	assert_ne(X.tr(key), key, 'the action has an effect row')
	var name_key := 'gear.%s.%s.name' % [CORE_ID, MAAR_ACTION]
	assert_ne(X.tr(name_key), name_key, 'and a name row')
	assert_ne(X.tr('frame.%s.name' % MAAR_FRAME), 'frame.%s.name' % MAAR_FRAME, 'and the crater has a name')

func test_the_card_carries_the_persists_tag() -> void:
	# A PLAYER-FACING AFFORDANCE THAT COMES FREE WITH THE ARCHETYPE, and the second pin on the one
	# line the card depends on: ActionSystemDeploy.get_glossary_tags appends lancer.term.persists
	# exactly when the deployable frame sets is_deactivated_on_owner_death = false
	# (action_system_deploy.gd:53-60). A hand-rolled ActionSystem would simply not have it, and
	# deleting that line from dep_maar.tres takes the tag off the card as well as killing the crater.
	# GlossaryItem.name holds the localisation key it was created from (glossary_item.gd:50).
	var action := maar_action()
	assert_not_null(action, 'the action is on the core Kit')
	if action == null: return
	var tag_keys:Array = action.get_glossary_tags(specific()).map(func(item:GlossaryItem) -> String: return item.name)
	assert_has(tag_keys, 'lancer.term.persists', 'the card tells the player the crater persists')

# ---------------------------------------------------------------- the crater

func test_a_maar_spawns_at_the_chosen_tile() -> void:
	await lay_maar(NEAR_CENTRE)

	var laid:Array = maars()
	assert_eq(laid.size(), 1, 'one crater')
	if laid.size() != 1: return
	assert_eq(laid.front().tile(), NEAR_CENTRE, 'at the tile that was picked')

func test_the_crater_makes_its_blast_1_difficult() -> void:
	await lay_maar(NEAR_CENTRE)

	for tile:Vector2i in blast_1_around(NEAR_CENTRE):
		assert_true(is_difficult(tile), '%s is difficult ground' % tile)
	assert_false(is_difficult(NEAR_CENTRE + Vector2i(2, 0)), 'and the tile beyond it is not')

func test_the_crater_is_a_factionless_non_obstructing_marker() -> void:
	await lay_maar(NEAR_CENTRE)
	var laid:Array = maars()
	assert_eq(laid.size(), 1, 'fixture: one crater')
	if laid.size() != 1: return
	var maar:Unit = laid.front()

	assert_true(maar.is_marker(), 'a MARKER, so it does not block movement or take attacks')
	assert_false(maar.core.frame.is_obstruction, 'and it obstructs nothing')
	assert_eq(maar.get_faction(), Faction.NONE, 'factionless: it is ground, not a combatant')
	assert_true(GearCore.is_valid(maar.get_gear(MAAR_TRAIT)), 'and it carries its own terrain trait')

func test_the_crater_knows_who_made_it() -> void:
	await lay_maar(NEAR_CENTRE)
	var laid:Array = maars()
	assert_eq(laid.size(), 1, 'fixture: one crater')
	if laid.size() != 1: return
	assert_eq(laid.front().get_owner_unit(), vauban,
		'Terrain.lay records the owner through UnitAction.set_deployable_owner')

func test_the_crater_survives_the_vaubans_death() -> void:
	# THE ONE THAT MATTERS. Frame.is_deactivated_on_owner_death defaults TRUE and would kill this
	# crater the moment the Vauban died (event_service.gd:56-63). dep_maar.tres sets it false.
	#
	# THE UNIT IS CAPTURED BEFORE THE KILL, rather than asked for afterwards: maars() reaches the
	# crater through UnitAction.get_deployables_from(vauban, core(), ...), which walks the VAUBAN's map
	# and reads the VAUBAN's gear state - neither of which is a sound thing to dereference through a
	# unit that has just been removed from the game. test_terrain.gd's own
	# test_the_laid_terrain_survives_the_layers_death holds the unit the same way.
	await lay_maar(NEAR_CENTRE)
	var laid:Array = maars()
	assert_eq(laid.size(), 1, 'fixture: the crater is there')
	if laid.size() != 1: return
	var maar:Unit = laid.front()
	assert_true(is_difficult(NEAR_CENTRE), 'fixture: and it is difficult ground')

	await game.execute_event(&'event_unit_die', {unit = vauban})
	VaubanFixture.track(game)

	assert_false(Unit.is_valid(vauban), 'fixture: the Vauban really died')
	assert_true(Unit.is_valid(maar) and maar.is_on_map(), 'the crater is still on the map')
	assert_true(is_difficult(NEAR_CENTRE), 'and still difficult ground - for the rest of the scene')

func test_two_maars_stack() -> void:
	await lay_maar(NEAR_CENTRE)
	await lay_maar(SECOND_CENTRE)

	assert_eq(maars().size(), 2, 'nothing removes the previous one')
	assert_true(is_difficult(NEAR_CENTRE), 'the first is still there')
	assert_true(is_difficult(SECOND_CENTRE), 'and so is the second')

func test_overlapping_maars_are_simply_difficult_ground() -> void:
	# TerrainData merges by OR (terrain_data.gd:64), so two craters over one tile is not two
	# difficulties, and nothing here needs to de-duplicate.
	await lay_maar(NEAR_CENTRE)
	await lay_maar(NEAR_CENTRE + Vector2i(1, 0))

	assert_eq(maars().size(), 2, 'both craters exist')
	assert_true(is_difficult(NEAR_CENTRE), 'still difficult, once')

func test_the_action_is_usable_again_next_turn_but_not_twice_in_one() -> void:
	# ONCE A TURN, EVERY TURN. There are no charges, no core point and no hibernation on this action,
	# so the only cadence is Lancer's own no-repeat-action rule
	# (Action.get_per_turn_soft_limit returns 1, action.gd:161-163). Both halves are asserted, because
	# the second is what the fixture's new_turn() helper exists for and a reader should not have to
	# take that on trust.
	await lay_maar(NEAR_CENTRE)

	await SpecFactory.use(game, vauban, CORE_ID, MAAR_ACTION, SECOND_CENTRE) # same turn, no new_turn()
	VaubanFixture.track(game)
	assert_eq(maars().size(), 1, 'a second press in the SAME turn is refused: no repeat actions')

	await lay_maar(SECOND_CENTRE)
	assert_eq(maars().size(), 2, 'and next turn it is available again')

# ---------------------------------------------------------------- the target filter

func test_a_tile_whose_blast_holds_a_hostile_is_not_targetable() -> void:
	VaubanFixture.create_hostile(game, NEAR_CENTRE + Vector2i(1, 0))
	VaubanFixture.track(game)

	assert_false(targetable().has(NEAR_CENTRE),
		'the card says an area that contains no hostile Characters')

func test_the_hostiles_own_tile_is_not_targetable_either() -> void:
	VaubanFixture.create_hostile(game, NEAR_CENTRE)
	VaubanFixture.track(game)

	assert_false(targetable().has(NEAR_CENTRE), 'the centre is in its own blast')

func test_a_tile_whose_blast_holds_an_ALLY_is_targetable() -> void:
	VaubanFixture.create_ally(game, NEAR_CENTRE + Vector2i(1, 0))
	VaubanFixture.track(game)

	assert_true(targetable().has(NEAR_CENTRE), 'ruling 8: allies do not block it')

func test_a_tile_whose_blast_holds_a_hostile_OBJECT_is_targetable() -> void:
	# THE CLAUSE THAT SEPARATES OUR PREDICATE FROM EVERY VANILLA ONE. A Jericho cover on the enemy
	# side is hostile and is NOT a Character (Frame.ENTITY.OBJECT), so ruling 8 lets it through -
	# while TargetRequirements.standard_check_if_tile_is_free and the caltrop launcher's own predicate
	# would both refuse the tile, since each blocks on any non-marker unit whatever its side
	# (target_requirements.gd:74-84, action_caltrop_launcher.gd:12-18). Deleting the is_character()
	# line from the predicate is the mutation that reddens this and nothing else.
	VaubanFixture.create_hostile_object(game, NEAR_CENTRE + Vector2i(1, 0))
	VaubanFixture.track(game)

	assert_true(targetable().has(NEAR_CENTRE), 'ruling 8: objects do not block it, hostile or not')

func test_a_tile_whose_blast_holds_a_previous_MAAR_is_targetable() -> void:
	# HONESTY ABOUT WHAT THIS PROVES: no predicate in the engine blocks on a MARKER - vanilla's
	# standard check skips them (target_requirements.gd:80), the caltrop launcher's skips them
	# (action_caltrop_launcher.gd:16), and ours skips them twice over (not a character, and
	# Faction.NONE is nobody's enemy - faction.gd:24). So this test cannot be reddened by mutating our
	# filter, and it is a pin on the CARD CLAUSE rather than evidence for the predicate. What it does
	# buy: it is the only test that shows overlapping craters can actually be TARGETED, where
	# test_overlapping_maars_are_simply_difficult_ground reaches its second crater through
	# SpecFactory.use and so never asks the targeting screen anything.
	await lay_maar(NEAR_CENTRE)

	assert_true(targetable().has(NEAR_CENTRE + Vector2i(1, 1)),
		'ruling 8: markers do not block it, which is what lets two craters overlap')

func test_a_hostile_two_tiles_out_does_not_block_it() -> void:
	VaubanFixture.create_hostile(game, NEAR_CENTRE + Vector2i(2, 0))
	VaubanFixture.track(game)

	assert_true(targetable().has(NEAR_CENTRE), 'it is outside the Blast 1')

func test_the_vaubans_own_tile_is_not_a_valid_centre() -> void:
	# A MEASURED DIVERGENCE FROM RULING 8, not a decision: UnitTargeting.filter_for_free_spaces drops
	# the acting unit's own tiles before check_if_tile_is_free is ever asked
	# (unit_targeting.gd:252-256). The Vauban can still centre a crater one tile away and stand in the
	# result - which is what the second assertion says. Recorded as an author note for the close;
	# pinned here so it cannot change in silence.
	assert_false(targetable().has(VAUBAN_TILE), 'the engine will not let a unit target the space it occupies')
	assert_true(targetable().has(VAUBAN_TILE + Vector2i(1, 0)), 'but the tile beside it is fine')

func test_a_tile_beyond_sensors_is_not_targetable() -> void:
	assert_eq(vauban.get_sensor_range(), 8, 'fixture: the Vauban sheet says Sensors 8')
	assert_false(targetable().has(FAR_CENTRE), 'and that is 14 away')
	assert_true(targetable().has(NEAR_CENTRE), 'fixture: the near one is in range')
