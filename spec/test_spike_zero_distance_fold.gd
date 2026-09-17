# PROBE: does a ZERO-DISTANCE fold arrive? (reach design §4, the gate on ruling D.)
#
# Teleport.move hand-builds a single-step path (teleport.gd:307-316), and it is not settleable from
# event_unit_move.gd whether a step onto the tile the unit already occupies is a real arrival or a
# no-op. It matters because Step's adjacent-characters Systems saves sit in SECTION 7 of its own
# action, after the move and behind `if move == null or move.aborted: return` - so if the engine
# aborts the move, the feature would silently do nothing while reading as correct.
#
# NO PRODUCTION CHANGE IS NEEDED TO ASK. Teleport.pick_tile returns plan.target_tiles.front() without
# checking it against the offered set (teleport.gd:286-289), and the spec responder regurgitates
# chosen_plan_queue verbatim (spec_factory.gd:454-455) - which MaidensBlushFixture.step fills from its
# `tile` argument. So the real action can be handed its own tile today.
#
# THIS FILE IS TEMPORARY. It is deleted when the verdict is taken: absorbed into
# test_step_of_mist_and_thunder.gd if D ships, deleted outright with the finding recorded in
# rulings.md if it does not. The SP2 probe (test_spike_own_involuntary_teleport.gd) was handled the
# same way.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_zero_distance_fold.gd
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const ACTION_ID := &'action_step_of_mist_and_thunder'
const CHIP_ID := &'buff_mist_and_thunder_invisible'
const MAP_SIZE := Vector2i(20, 20)
const BLUSH_TILE := Vector2i(4, 4)
## One space east of the Blush: adjacent to the tile it already stands on, so it saves on a
## zero-distance fold and on no other.
const NEIGHBOUR_TILE := Vector2i(5, 4)

var game:Gamemaster
var blush:Unit
var responder

func before_each() -> void:
	var pair := MaidensBlushFixture.create_game_with_sequenced_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_plan_queue.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false

func chip_on(character:Unit) -> BuffCore:
	for buff_core:BuffCore in character.state.buffs:
		if buff_core.base.compcon_id == CHIP_ID: return buff_core
	return null

func test_the_helper_does_not_offer_the_units_own_tile():
	# THE PREMISE, pinned so the probe cannot be misread. Teleport.candidate_tiles drops the caller's
	# occupied tiles at teleport.gd:225, which is why D has to re-add the tile in Step rather than
	# loosen the FROZEN helper.
	await MaidensBlushFixture.open_turn(game, blush)
	assert_false(Teleport.candidate_tiles(blush, 7, false).has(BLUSH_TILE),
		'The helper excludes the tile the unit already occupies.')

func test_a_zero_distance_fold_makes_an_adjacent_character_save():
	# THE QUESTION. Three values: the 2d6, then one Systems save low enough to fail. If the engine
	# treats the step as a real arrival, section 7 runs and the neighbour wears the chip; if it
	# no-ops or aborts the move core, no save is ever rolled.
	await MaidensBlushFixture.open_turn(game, blush)
	var neighbour := MaidensBlushFixture.create_hostile(game, NEIGHBOUR_TILE)
	await MaidensBlushFixture.step(game, blush, responder, [3, 4, 1], BLUSH_TILE)

	assert_eq(blush.tile(), BLUSH_TILE, 'Fixture: it is where it started, which is where it aimed.')
	assert_not_null(chip_on(neighbour),
		'A zero-distance fold IS an arrival: the adjacent character rolled, and failed.')

func test_a_zero_distance_fold_costs_the_quick_action_and_the_core_point():
	# The spend is above the move, so this is true whatever the engine does with the step - asserted
	# so a RED on the test above cannot be read as "the action never ran at all".
	await MaidensBlushFixture.open_turn(game, blush)
	await MaidensBlushFixture.step(game, blush, responder, [3, 4], BLUSH_TILE)
	assert_false(blush.core.has_core_power, 'The core point is spent.')
	assert_ne(blush.state.actions, Lancer.ACTION_COST_FULL, 'And the quick action with it.')

func test_a_zero_distance_fold_counts_as_one_space_moved():
	# Free to ask while the probe is running (design §4). SP2 recorded that a teleport of ANY distance
	# counts as one spaces_moved_this_turn; this is whether zero is also one.
	await MaidensBlushFixture.open_turn(game, blush)
	var before:int = blush.state.spaces_moved_this_turn
	await MaidensBlushFixture.step(game, blush, responder, [3, 4], BLUSH_TILE)
	assert_eq(blush.state.spaces_moved_this_turn, before + 1,
		'RECORDED, not required: a zero-distance fold counts as one space moved.')

func test_a_grappled_blush_cannot_fold_in_place_to_shed_the_grip():
	# The other free question, and the one with a wrong answer available. Step strips a GRAPPLED
	# status through Katamari.validate_attachments when it was grappled and moved
	# (action_step_of_mist_and_thunder.gd:134) - the engine's own reconciler, which keeps the status
	# while a grappling attachment still backs it. A REAL grapple is built here, not the orphan status
	# the shipped test uses: the grappler stays adjacent to a mech that folded nowhere, so the
	# attachment is genuinely intact and the grip must survive.
	await MaidensBlushFixture.open_turn(game, blush)
	var grappler := MaidensBlushFixture.create_hostile(game, NEIGHBOUR_TILE)
	var grapple_gear:GearCore = grappler.get_gear(&'mw_grapple')
	assert_true(GearCore.is_valid(grapple_gear),
		'Fixture: mw_grapple is in every unit-s basic loadout, and is the gear whose PassiveAttachment'
		+ ' is_grapple makes an attachment a grapple.')
	Katamari.attach_units(SpecFactory.dummy_event(), blush, grappler, grapple_gear.persistent_id)
	assert_true(blush.has_status(Lancer.STATUS.GRAPPLED), 'Fixture: really grappled.')

	await MaidensBlushFixture.step(game, blush, responder, [3, 4], BLUSH_TILE)

	assert_true(blush.has_status(Lancer.STATUS.GRAPPLED),
		'Folding in place sheds nothing: the grappler is still adjacent and the attachment is intact.')
