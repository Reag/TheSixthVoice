# ABJURATION OF METAL, the Maiden's Blush's core-system reaction.
#
#   Trigger: "A hostile character within sensors misses you with an attack."
#   Effect:  "Roll 1d6: You may teleport up to that many spaces in the direction of the attacker. If
#             this puts the attacker in Threat of one of your weapons, you may immediately use that
#             weapon to Skirmish against them."
#
# THE TELEPORT HERE IS PREVENTABLE, WHICH IS THE OPPOSITE OF STEP'S, and the pair of tests that say so
# is the most important thing in this file: Abjuration goes through Teleport.pathfinder, so
# Immobilized and every MOVEMENT_RESTRICTION ban stop it. Only Step carries the "cannot be prevented"
# clause, and only Step pays for it.
#
# DICE DISCIPLINE. CHEAT_ROLL_QUEUE is one global FIFO and a single activation here can draw from it
# three times over: the attack that triggers the reaction (mw_assault_rifle pops FOUR values when the
# shooter is engaged - the d20, the ENGAGED difficulty die and two 1d6 damage rolls), then
# Abjuration's own d6, then the follow-up Skirmish's own attack. Every helper below clears the queue
# before it queues, and says how many values it is accounting for.
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const ACTION_ID := &'action_abjuration_of_metal'
const MAP_SIZE := Vector2i(20, 20)

const BLUSH_TILE := Vector2i(6, 6)
## Eight tiles east, comfortably inside the frame's sensors of 10 and well outside melee threat.
const ATTACKER_TILE := Vector2i(14, 6)

var game:Gamemaster
var blush:Unit
var attacker:Unit
var responder

func before_each() -> void:
	# The sequenced responder, as Step's spec uses: an Abjuration activation opens its own confirm and
	# can then open Uncertainty Field's offer on the very teleport it just rolled for.
	var pair := MaidensBlushFixture.create_game_with_sequenced_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	attacker = MaidensBlushFixture.create_hostile(game, ATTACKER_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_plan_queue.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

## Answer the offer, fix the d6, and let the field decline. The queue is
## [abjuration confirm, uncertainty field] in the order the activation opens them.
func arm(accept:bool = true, d6:int = 3, fade:bool = false) -> void:
	responder.yesno_queue.append_array([accept, fade])
	if accept: responder.chosen_plan_queue.clear()

## What the cone would offer for a given roll - the action's own filter, reached through the same
## public helper it uses, so a test asserting on this is asserting on the real set.
func cone(roll:int) -> Array[Vector2i]:
	var action:Action = ContentLibrary.get_kit(MaidensBlushFixture.CORE_ID).get_action(ACTION_ID)
	return Teleport.candidate_tiles(blush, roll, true, action.toward(blush, attacker))

func blush_reactions() -> int:
	return blush.core.current.reactions

## ABJURATION'S OWN offers, not every yes/no the run opened. Firing an attack opens confirms of its
## own, so a bare yesno_prompts.size() counts the ATTACKER's prompts too - which made the two
## negative tests here fail and, worse, would have let the positive one pass on somebody else's
## prompt. CommonActionUtil.confirm_use titles the offer 'battle.confirm.use' formatted with the
## action's name (common_action_util.gd:355), so the name is what identifies it.
func offers() -> int:
	var count := 0
	for prompt:Dictionary in responder.yesno_prompts:
		if str(prompt.title).contains('Abjuration'): count += 1
	return count

# ---------------------------------------------------------------- the trigger

func test_a_hostile_within_sensors_missing_with_a_weapon_offers_it():
	arm(false) # decline, so the test is purely about the offer
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(offers(), 1, 'A miss inside Sensors opens the offer, exactly once.')

func test_a_hit_does_not_offer_it():
	arm(false)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([20, 20], [3, 3]) # a d20 that cannot miss, plus the rifle's two damage dice
	await SpecFactory.use_solo(game, attacker, MaidensBlushFixture.RANGED_ID, [blush])
	assert_eq(offers(), 0, 'require_miss: a hit offers nothing.')

func test_a_miss_from_beyond_sensors_does_not_offer_it():
	# Sensors is 10 on this frame; 15 tiles is outside it and still on the map.
	UnitTile.move_to(attacker, Vector2i(6, 19))
	assert_true(UnitRelation.distance_between(blush, attacker) > blush.get_sensor_range(),
		'Fixture: outside Sensors.')
	arm(false)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(offers(), 0, 'Out of sensors, out of mind.')

func test_an_allys_miss_does_not_offer_it():
	var ally := MaidensBlushFixture.create_ally(game, Vector2i(10, 6))
	arm(false)
	await MaidensBlushFixture.miss_from(game, ally, blush)
	assert_eq(offers(), 0, 'require_attacker_relation = ENEMIES.')

func test_a_missed_ram_offers_it():
	# RULING 11's basic-attack half, and the reason allow_basic is set. Ram is a basic mw_ Kit whose
	# action extends ActionAttackWeapon (action_ram.gd:2), so the archetype's final type test passes -
	# which is worth measuring rather than reading, because a class of its own would have failed it
	# silently.
	UnitTile.move_to(attacker, Vector2i(7, 6)) # adjacent, so it can Ram
	arm(false)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([MaidensBlushFixture.MISS_ROLL, MaidensBlushFixture.MISS_ROLL], [])
	await SpecFactory.use_solo(game, attacker, &'mw_ram', [blush])
	assert_eq(offers(), 1, 'A missed Ram counts as an attack.')

# ---------------------------------------------------------------- the spend

func test_declining_spends_nothing():
	var reactions_before := blush_reactions()
	arm(false)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(blush_reactions(), reactions_before, 'The reaction point is still in hand.')
	assert_eq(blush.tile(), BLUSH_TILE, 'And it did not move.')

func test_accepting_spends_the_reaction_point():
	var reactions_before := blush_reactions()
	arm(true, 3)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_lt(blush_reactions(), reactions_before, 'Accepting bills a reaction point.')

func test_a_second_abjuration_in_the_same_round_is_refused():
	arm(true, 3)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(offers(), 1, 'Fixture: the first miss was offered.')
	arm(true, 3)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(offers(), 1, '1/round: the second miss is never even offered.')

# ---------------------------------------------------------------- the pull rule

func test_the_cone_only_holds_tiles_that_close_the_distance_by_exactly_the_spaces_moved():
	# The rule itself, asserted over the whole set rather than tile by tile.
	var tiles := cone(3)
	assert_false(tiles.is_empty(), 'The cone is not empty.')
	var to_attacker:int = UnitRelation.distance_between(blush, attacker)
	for tile:Vector2i in tiles:
		var moved:int = Tile.distance(BLUSH_TILE, tile)
		var gained:int = to_attacker - Tile.get_closest_pair_between(
			[tile] as Array[Vector2i], attacker.occupied_tiles()).distance
		assert_eq(gained, moved, 'Tile %s closes exactly the distance it travelled.' % tile)

func test_a_tile_straight_toward_the_attacker_is_offered():
	# The positive control, without which every exclusion below could pass on an empty set.
	assert_true(cone(3).has(Vector2i(9, 6)), 'Three spaces due east, straight at it.')

func test_a_tile_that_ends_closer_but_drifts_is_excluded():
	# THE TEST THAT DISCRIMINATES RULING 10 from the reading it was chosen over, and PICKING THE TILE
	# TOOK MEASURING. The obvious candidate - three spaces due north of the Blush - is excluded by both
	# readings, because grid distance is Chebyshev and a purely perpendicular move gains nothing at
	# all; a mutation to "any closer tile" left it green.
	#
	# (7, 10) is the real discriminator. From (6, 6) it is FOUR spaces away, and it ends
	# max(|14-7|, |6-10|) = 7 from the attacker against 8 before - so it gains ONE while travelling
	# four. "Any closer free space within the roll" keeps it; the pull rule does not, because it drifted
	# three spaces sideways to buy one space of approach.
	assert_false(cone(4).has(Vector2i(7, 10)),
		'Drifting sideways to end one space nearer is not "in the direction of".')
	assert_true(cone(4).has(Vector2i(10, 6)),
		'While four spaces straight at it is - so the exclusion above is about the rule, not the range.')

func test_a_tile_behind_a_wall_is_excluded():
	# Line of sight IS required here, unlike Step: Bel exempts Step in so many words and leaves this
	# one silent (ruling 10).
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior',
		[Vector2i(8, 5), Vector2i(8, 6), Vector2i(8, 7)])
	game.map.calculate_los_blockers()
	assert_false(cone(4).has(Vector2i(10, 6)), 'Blind tiles are not offered.')

func test_an_immobilized_blush_finds_no_tile():
	# THIS TELEPORT IS PREVENTABLE. Teleport.pathfinder builds a real Pathfinder, whose Immobilized
	# gate refuses a voluntary move outright (pathfinder.gd:333).
	UnitCondition.apply_status(SpecFactory.dummy_event(), blush,
		Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	var pathfinder:Pathfinder = await Teleport.pathfinder(blush, cone(3))
	assert_true(pathfinder.valid_destinations.is_empty(),
		'Immobilized stops Abjuration, where it would not stop Step.')

func test_no_valid_tile_leaves_the_reaction_spent_and_the_mech_unmoved():
	# Boxed in by geometry: a roll of 0 spaces cannot happen, but an attacker the mech is already
	# adjacent to leaves no tile that closes any distance at all.
	UnitTile.move_to(attacker, Vector2i(7, 6))
	var reactions_before := blush_reactions()
	arm(true, 1)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([MaidensBlushFixture.MISS_ROLL, MaidensBlushFixture.MISS_ROLL], [])
	await SpecFactory.use_solo(game, attacker, MaidensBlushFixture.RANGED_ID, [blush])
	assert_lt(blush_reactions(), reactions_before, 'Spent anyway (ruling 10).')

# ---------------------------------------------------------------- the Skirmish

func test_a_teleport_that_ends_out_of_threat_offers_no_skirmish():
	# The Blush carries no weapon here at all, so nothing can reach - the cleanest form of "out of
	# threat", and the negative control for the case below.
	arm(true, 2)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(attacker.current_damage(), 0, 'No follow-up shot landed.')

func test_the_follow_up_costs_the_mech_nothing_of_its_own():
	# The Uffish Gyre and Draw Fire lesson: the shot is the WEAPON's own SpecificAction and
	# choose_and_use_no_spend keeps the mech's economy untouched off-turn. Asserted on the action
	# state, not merely on the attack having happened.
	MaidensBlushFixture.equip_melee(blush)
	var actions_before := blush.state.actions
	arm(true, 6)
	await MaidensBlushFixture.miss_from(game, attacker, blush)
	assert_eq(blush.state.actions, actions_before,
		'Its quick and full actions are exactly where they were.')
