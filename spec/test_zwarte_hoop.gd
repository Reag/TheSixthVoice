# ZWARTE HOOP, the Inevitability Core's passive (Grutte Pier SP2). Design rulings 6-13.
#
#   "At the start of your turn, this system gains charges equal to the number of hostile activations
#    that have already happened that round, to a maximum of 5. On your first attack roll each round,
#    you may expend any number of charges. [...] You may choose the same option up to twice, and you
#    lose all charges at the end of your turn."
#
# The gain and the lapse. A "hostile activation" is a hostile ACTOR's turn start, counted as it
# happens by a hidden NEW_TURN reaction on the Pier (ruling 7), so each test drives turn starts
# rather than editing core.current.activations.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_zwarte_hoop.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const PIER_TILE := Vector2i(2, 5)

var game:Gamemaster
var responder
var pier:Unit
var hostiles:Array[Unit] = []

func before_each() -> void:
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	pier = Fixture.create_pier(game, PIER_TILE)
	hostiles.clear()
	for i in 6: hostiles.append(Fixture.create_dummy(game, Vector2i(10, i * 2)))
	await Fixture.new_round(game)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## One activation: the unit's turn starts and ends.
func activation(unit:Unit) -> void:
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.end_turn(game, unit)

func pier_turn_starts() -> void:
	await SpecFactory.start_turn(game, pier)

# ---------------------------------------------------------------- wiring

func test_the_counter_is_passives_0_and_starts_at_0():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_not_null(kit, 'The core Kit is in the kits index.')
	if kit == null: return
	assert_true(kit.passives[0] is PassiveDieCounter, 'The counter is passives[0], which the gear-bar badge reads.')
	assert_eq(Fixture.charges(pier), 0, 'A fresh Pier has no charges.')

# ---------------------------------------------------------------- the gain (rulings 7, 8, 11)

func test_the_pier_going_first_gains_nothing():
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 0, 'No hostile has activated yet this round.')

func test_two_hostile_turns_give_two():
	await activation(hostiles[0])
	await activation(hostiles[1])
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 2)

func test_an_elites_two_activations_count_two():
	await activation(hostiles[0])
	await activation(hostiles[0])
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 2, 'Each turn start is an activation.')

func test_a_hostile_that_acted_then_died_still_counts():
	await activation(hostiles[0])
	hostiles[0].remove_from_game(true)
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 1, 'Its activation already happened.')

func test_a_hostile_deployables_turn_start_does_not_count():
	var dep := FitzgeraldFixture.create_deployable(game, Vector2i(12, 11), 10, 0, 5)
	await SpecFactory.start_turn(game, dep)
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 0, 'A deployable is not an actor (unit.gd:117).')

func test_an_allys_turn_gives_nothing():
	var ally := Fixture.create_dummy(game, Vector2i(4, 9), 8, Faction.PLAYER)
	await activation(ally)
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 0)

func test_six_hostile_activations_give_five():
	for hostile:Unit in hostiles: await activation(hostile)
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 5, '"to a maximum of 5".')

func test_the_tally_starts_over_each_round():
	await activation(hostiles[0])
	await activation(hostiles[1])
	await Fixture.new_round(game)
	await activation(hostiles[2])
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 1, 'Only this round\'s hostile activation counts.')

# ---------------------------------------------------------------- the lapse (ruling 8)

func test_the_charges_lapse_when_the_pier_ends_its_turn():
	await activation(hostiles[0])
	await activation(hostiles[1])
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 2, 'fixture: two charges gained.')
	await SpecFactory.end_turn(game, pier)
	assert_eq(Fixture.charges(pier), 0, '"you lose all charges at the end of your turn".')

func test_a_leftover_bank_is_replaced_not_added_to():
	Fixture.set_charges(pier, 4) # e.g. a turn that ended through death never lapsed
	await activation(hostiles[0])
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 1, 'Without Patience the gain replaces whatever was left.')

# ---------------------------------------------------------------- under Patience (rulings 11, 15)

func test_under_patience_the_charges_persist_past_turn_end():
	Fixture.give_patience(pier)
	Fixture.set_charges(pier, 4)
	await SpecFactory.start_turn(game, pier)
	await SpecFactory.end_turn(game, pier)
	assert_eq(Fixture.charges(pier), 7, '4 banked + 3 from Patience, and the turn end takes none.')

func test_under_patience_the_gain_adds_three_on_top_and_the_bank_passes_five():
	Fixture.give_patience(pier)
	Fixture.set_charges(pier, 4)
	for hostile:Unit in hostiles: await activation(hostile)
	await pier_turn_starts()
	assert_eq(Fixture.charges(pier), 12, '4 banked + min(5, 6) + 3: only the gain is capped (ruling 11).')
