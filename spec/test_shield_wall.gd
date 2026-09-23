# SHIELD WALL (Hazard, mt_shield_wall) - SP1 Task 3, ruling 3:
#
#   "At the end of the Hazards turn, it may choose an adjacent allied character, they gain
#    OVERSHIELD equal to 1+GRIT."
#
# Prompts are answered and recorded by the queued responder (create_game_with_prompt_queues):
# unit_queue answers the picker (null declines), unit_prompts records every offer - including ones
# the base answered - so "no prompt" is a real assertion.
#
# The House Guard pin (the widening reaches the pick) lives in test_compat.gd.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_shield_wall.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const HAZARD_TILE := Vector2i(4, 6)
const ADJACENT := Vector2i(5, 6)
const OTHER_ADJACENT := Vector2i(3, 6)
const DIAGONAL := Vector2i(5, 7)
const TWO_OUT := Vector2i(6, 6)

const GRIT := 2

var game:Gamemaster
var responder
var hazard:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	hazard = Fixture.create_hazard(game, HAZARD_TILE, GRIT)

func end_hazards_turn() -> void:
	await Fixture.open_turn(game, hazard)
	await SpecFactory.end_turn(game, hazard)

func offered() -> Array:
	if responder.unit_prompts.is_empty(): return []
	return responder.unit_prompts[0].units

# ---------------------------------------------------------------- the offer

func test_the_picker_offers_exactly_the_adjacent_allied_characters():
	var ally := Fixture.create_ally(game, ADJACENT)
	var diagonal := Fixture.create_ally(game, DIAGONAL)
	var far := Fixture.create_ally(game, TWO_OUT)
	var drone := Fixture.create_drone(game, OTHER_ADJACENT)
	Fixture.create_hostile(game, HAZARD_TILE + Vector2i(0, -1))
	responder.unit_queue = [ally]
	await end_hazards_turn()
	assert_eq(responder.unit_prompts.size(), 1, 'One picker at the Hazard\'s turn end.')
	var units := offered()
	assert_has(units, ally, 'An adjacent ally is offered.')
	assert_has(units, diagonal, 'A diagonal ally is adjacent too.')
	assert_does_not_have(units, far, 'Two tiles out is not adjacent.')
	assert_does_not_have(units, drone, '"allied character": a drone is not offered.')
	assert_does_not_have(units, hazard, 'Not the Hazard itself.')
	assert_eq(units.size(), 2, 'Exactly the two adjacent allied characters (no hostile).')

func test_the_pick_gains_one_plus_grit_overshield():
	var ally := Fixture.create_ally(game, ADJACENT)
	responder.unit_queue = [ally]
	await end_hazards_turn()
	assert_eq(Overshield.current(ally), 1 + GRIT, 'The chosen ally gains 1 + Grit 2 = 3.')
	assert_eq(Overshield.current(hazard), 0, 'The Hazard gains none.')
	assert_eq(Fixture.uses_this_round(hazard, Fixture.SHIELD_WALL_ID, Fixture.SHIELD_WALL_ACTION_ID), 1, 'The use is recorded.')

func test_grit_zero_still_grants_one():
	Fixture.set_grit(hazard, 0)
	var ally := Fixture.create_ally(game, ADJACENT)
	responder.unit_queue = [ally]
	await end_hazards_turn()
	assert_eq(Overshield.current(ally), 1, '1 + Grit 0 = 1.')

func test_declining_grants_nothing_and_spends_nothing():
	var ally := Fixture.create_ally(game, ADJACENT)
	responder.unit_queue = [null]
	await end_hazards_turn()
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: the picker was raised.')
	assert_eq(Overshield.current(ally), 0, '"may": cancel grants nothing.')
	assert_eq(Fixture.uses_this_round(hazard, Fixture.SHIELD_WALL_ID, Fixture.SHIELD_WALL_ACTION_ID), 0, 'And spends nothing.')

func test_an_ally_holding_more_keeps_its_own():
	var ally := Fixture.create_ally(game, ADJACENT)
	ally.state.overshield = 5
	responder.unit_queue = [ally]
	await end_hazards_turn()
	assert_eq(Overshield.current(ally), 5, 'Overshield does not stack: 5 stays 5, not 3 and not 8.')

func test_no_adjacent_ally_means_no_prompt():
	Fixture.create_ally(game, TWO_OUT)
	await end_hazards_turn()
	assert_eq(responder.unit_prompts.size(), 0, 'Nobody adjacent: no picker at all.')

func test_an_allys_turn_end_does_not_offer():
	var ally := Fixture.create_ally(game, ADJACENT)
	await Fixture.open_turn(game, ally)
	await SpecFactory.end_turn(game, ally)
	assert_eq(responder.unit_prompts.size(), 0, 'Only the HAZARD\'s turn end.')
	assert_eq(Overshield.current(ally), 0, 'And nothing granted.')

func test_it_fires_again_at_the_next_turn_end():
	var ally := Fixture.create_ally(game, ADJACENT)
	responder.unit_queue = [ally, ally]
	await end_hazards_turn()
	ally.state.overshield = 0
	await end_hazards_turn()
	assert_eq(responder.unit_prompts.size(), 2, 'Every turn end of the Hazard offers.')
	assert_eq(Overshield.current(ally), 1 + GRIT, 'And grants again.')

# ---------------------------------------------------------------- the AI
#
# EACH CASE RUNS IN BOTH CREATION ORDERS: the candidates come back in the map's unit order, which is
# creation order, so a pick of "the first" or "the last" would pass one ordering by luck (measured: a
# back() mutation stayed green while the expected unit was always created last).

func ai_setup(grit:int) -> Array:
	var ai_game := Fixture.create_game(self)
	var ai_hazard := SpecFactory.create_unit(ai_game.map, HAZARD_TILE, Faction.AI_ENEMY)
	ai_hazard.core.frame = ContentLibrary.get_mech_frame(Fixture.FRAME_ID)
	Fixture.set_grit(ai_hazard, grit)
	SpecFactory.apply_passive_buffs(ai_hazard)
	return [ai_game, ai_hazard]

## [expected, other], created in the order asked for.
func make_two(ai_game:Gamemaster, expected_tile:Vector2i, other_tile:Vector2i, expected_first:bool) -> Array[Unit]:
	var expected:Unit
	var other:Unit
	if expected_first:
		expected = Fixture.FitzgeraldFixture.create_dummy(ai_game, expected_tile, 10, Faction.AI_ENEMY)
		other = Fixture.FitzgeraldFixture.create_dummy(ai_game, other_tile, 10, Faction.AI_ENEMY)
	else:
		other = Fixture.FitzgeraldFixture.create_dummy(ai_game, other_tile, 10, Faction.AI_ENEMY)
		expected = Fixture.FitzgeraldFixture.create_dummy(ai_game, expected_tile, 10, Faction.AI_ENEMY)
	return [expected, other]

func ai_least_shielded_case(bare_tile:Vector2i, shielded_tile:Vector2i, bare_first:bool) -> void:
	var pair := ai_setup(GRIT)
	var ai_game:Gamemaster = pair[0]
	var ai_hazard:Unit = pair[1]
	var made := make_two(ai_game, bare_tile, shielded_tile, bare_first)
	var bare:Unit = made[0]
	var shielded:Unit = made[1]
	shielded.state.overshield = 2
	UnitTile.update_tracking_and_statuses(ai_game.map)
	assert_false(ai_hazard.is_player_controlled(), 'fixture: an AI Hazard.')
	await Fixture.open_turn(ai_game, ai_hazard)
	await SpecFactory.end_turn(ai_game, ai_hazard)
	assert_eq(Overshield.current(bare), 1 + GRIT, 'The ally with no Overshield is shielded (bare at %s).' % bare_tile)
	assert_eq(Overshield.current(shielded), 2, 'The shielded one is left alone.')

func ai_tie_case(hurt_tile:Vector2i, healthy_tile:Vector2i, hurt_first:bool) -> void:
	var pair := ai_setup(0)
	var ai_game:Gamemaster = pair[0]
	var ai_hazard:Unit = pair[1]
	var made := make_two(ai_game, hurt_tile, healthy_tile, hurt_first)
	var hurt:Unit = made[0]
	var healthy:Unit = made[1]
	hurt.core.current.health = 50
	UnitTile.update_tracking_and_statuses(ai_game.map)
	await Fixture.open_turn(ai_game, ai_hazard)
	await SpecFactory.end_turn(ai_game, ai_hazard)
	assert_eq(Overshield.current(hurt), 1, 'Equal Overshield: the lower-HP ally is shielded (hurt at %s).' % hurt_tile)
	assert_eq(Overshield.current(healthy), 0, 'The healthier one is not.')

func test_an_ai_hazard_picks_the_least_shielded_adjacent_ally_without_a_prompt():
	await ai_least_shielded_case(ADJACENT, OTHER_ADJACENT, false)

func test_the_least_shielded_pick_holds_in_the_other_order():
	await ai_least_shielded_case(OTHER_ADJACENT, ADJACENT, true)

func test_the_ai_breaks_a_tie_by_lowest_hp():
	await ai_tie_case(OTHER_ADJACENT, ADJACENT, false)

func test_the_tie_break_holds_in_the_other_order():
	await ai_tie_case(ADJACENT, OTHER_ADJACENT, true)
