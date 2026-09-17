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
# DICE DISCIPLINE. CHEAT_ROLL_QUEUE is one global FIFO and a single activation here draws from it in
# three bursts: the attack that triggers the reaction, then Abjuration's own d6
# (action_abjuration_of_metal.gd:86), then the follow-up Skirmish's own attack. ONE helper owns the
# whole sequence - arm() clears the queue and loads it - and miss() fires the triggering shot WITHOUT
# clearing again, which is the single thing it does differently from MaidensBlushFixture.miss_from and
# the whole reason it exists. arm()'s own comment says what every value is for, and why its tail is
# padded rather than counted.
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const ACTION_ID := &'action_abjuration_of_metal'
const MAP_SIZE := Vector2i(20, 20)

const BLUSH_TILE := Vector2i(6, 6)
## Eight tiles east, comfortably inside the frame's sensors of 10 and well outside melee threat.
const ATTACKER_TILE := Vector2i(14, 6)

## Six spaces due east of the mech and two short of the attacker. One tile does three jobs: a roll of
## 6 reaches it and the pull rule keeps it (it closes exactly the six it travels), it is INSIDE
## mw_variable_sword's threat of 2, and it is OUTSIDE mw_assault_rifle's threat of 1
## (action_attack_weapon.gd:16 - threat defaults to 1 and the rifle never overrides it, so a weapon
## with a ten-tile aim_range still threatens one tile). That last pair is what lets the positive
## Skirmish and its threat-not-range negative use the same geometry and differ only in the weapon.
const LANDING := Vector2i(12, 6)

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

## Answer the offer, FIX EVERY DIE THE ACTIVATION WILL DRAW, and let the field decline. The yes/no
## queue is [abjuration confirm, uncertainty field] in the order the activation opens them.
##
## THE d6 PARAMETER WAS DEAD until 2026-09-17, and the file header used to claim the opposite. Nothing
## here ever wrote to Dice.CHEAT_ROLL_QUEUE, and MaidensBlushFixture.miss_from CLEARS it
## (maidens_blush_fixture.gd:207) before queueing the attack's own pair - so Abjuration's roll was
## whatever that pair happened to leave behind, or randi() when it left nothing (dice.gd:25, :33: the
## queue is consulted only `elif not CHEAT_ROLL_QUEUE.is_empty()`). That is why every test below fires
## miss() instead of the fixture helper.
##
## THE TAIL IS PADDED RATHER THAN COUNTED, and that is the careful choice, not the lazy one. Where the
## d6 falls in the FIFO depends on two things a spec should not have to assume: an ENGAGED shooter adds
## a difficulty die (roll_d6_accuracy pops one value per point of it, dice.gd:86-88), and the rifle's
## two 1d6 damage rolls (attack_util.gd:250-251) are rolled by event_unit_attack_declared at :89, AFTER
## the per-target attack events at :67 - and this whole activation runs inside those, because a POST
## attack reaction is QUEUED onto the attack event's own block (event_unit_attack.gd:123) and drained
## before that block returns (event_block.gd:128-132). One MISS_ROLL for the triggering d20 and then
## `d6` for every die after it is right under either count, and stays right if that ordering ever
## moves. It is the shape test_uffish_gyre.gd and test_symbiosis.gd already use, for the same reason.
##
## SO THE FOLLOW-UP SKIRMISH ROLLS `d6` TOO. At 6 that is a d20 of 6 plus mw_variable_sword's accuracy
## die of 6 against the fixture dummy's evasion of 10, which hits; at the default 3 it does not reach
## it. The two tests that fire something other than the plain miss clear this queue again on their very
## next line, and both decline the offer, so no d6 is ever drawn in them.
func arm(accept:bool = true, d6:int = 3, fade:bool = false) -> void:
	responder.yesno_queue.append_array([accept, fade])
	if accept: responder.chosen_plan_queue.clear()
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append(MaidensBlushFixture.MISS_ROLL)
	for _die in 12: Dice.CHEAT_ROLL_QUEUE.append(d6)

## The triggering miss, fired WITHOUT clearing the queue arm() has just loaded - the same rifle, the
## same target and the same MISS_ROLL as MaidensBlushFixture.miss_from, minus its
## clear-and-requeue (maidens_blush_fixture.gd:205-209), which is what used to swallow the d6.
func miss(from:Unit = null) -> void:
	var shooter:Unit = from if Unit.is_valid(from) else attacker
	MaidensBlushFixture.equip_ranged(shooter)
	await SpecFactory.use_solo(game, shooter, MaidensBlushFixture.RANGED_ID, [blush])

## How many times Uncertainty Field has fired this round. The veto test's discriminator: "it did not
## move" and "nobody was shot" are both true of a teleport that never found a tile, so without this
## the negative twin would pass for the wrong reason.
func field_uses_this_round() -> int:
	var gear:GearCore = blush.get_gear(MaidensBlushFixture.UNCERTAINTY_FIELD_ID)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round_alt(&'uncertainty_field')

## Land the mech on an EXACT tile instead of wherever the picker's first offer happens to sit.
##
## Abjuration's pick is a MOVE request, not a compcon plan: ask_for_movement_alt sends
## choose_move_tile_for for a player-controlled mover (target_action_util.gd:83), so chosen_plan_queue
## cannot steer it and chosen_move_tile can. Left unset, SpecFactory's responder answers with
## pathfinder.reachable_tiles[0] (spec_factory.gd:417-428) - fine for a test about the spend, useless
## for one about threat, where the destination IS the measurement.
func land_on(tile:Vector2i) -> void:
	responder.chosen_move_tile = tile

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

## UNCERTAINTY FIELD'S offers, however they were opened. Both doors put the trait's own name in the
## title - the interception through battle.confirm.use formatted with it, the consolation directly -
## so this counts the fade offers where offers() above counts Abjuration's.
func field_offers() -> int:
	var count := 0
	for prompt:Dictionary in responder.yesno_prompts:
		if str(prompt.title).contains('Uncertainty Field'): count += 1
	return count

## The description of the last yes/no prompt, which is how a CONSOLATION offer is told apart from the
## field's ordinary interception: CommonActionUtil.confirm_use passes no description at all
## (common_action_util.gd:362-371), and the consolation rows are the only prompt text this frame
## writes for the field.
func last_prompt_description() -> String:
	if responder.yesno_prompts.is_empty(): return ''
	return str(responder.yesno_prompts.back().desc)

# ---------------------------------------------------------------- the trigger

func test_a_hostile_within_sensors_missing_with_a_weapon_offers_it():
	arm(false) # decline, so the test is purely about the offer
	await miss()
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
	await miss()
	assert_eq(offers(), 0, 'Out of sensors, out of mind.')

func test_an_allys_miss_does_not_offer_it():
	var ally := MaidensBlushFixture.create_ally(game, Vector2i(10, 6))
	arm(false)
	await miss(ally)
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
	await miss()
	assert_eq(blush_reactions(), reactions_before, 'The reaction point is still in hand.')
	assert_eq(blush.tile(), BLUSH_TILE, 'And it did not move.')

func test_accepting_spends_the_reaction_point():
	var reactions_before := blush_reactions()
	arm(true, 3)
	await miss()
	assert_lt(blush_reactions(), reactions_before, 'Accepting bills a reaction point.')

func test_a_second_abjuration_in_the_same_round_is_refused():
	arm(true, 3)
	await miss()
	assert_eq(offers(), 1, 'Fixture: the first miss was offered.')
	arm(true, 3)
	await miss()
	assert_eq(offers(), 1, '1/round: the second miss is never even offered.')

# ---------------------------------------------------------------- the pull rule

func test_the_cone_only_holds_tiles_on_the_line_through_the_attacker():
	# THE RULE ITSELF, asserted over the whole set rather than tile by tile, and since 2026-09-17 it
	# is a DISJUNCTION: a kept tile is either between us and the attacker (approach) or has the
	# attacker between us and it (overshoot). Either way the attacker is on the path.
	#
	# The geometry here admits no overshoot tile at all - the attacker is eight spaces off and the
	# far side of it is ten, well past any d6 - so this set is still the approach cone exactly. That
	# is deliberate: it keeps the shipped assertion honest while stating the wider rule, and the two
	# tests below are where the overshoot clause is actually pinned.
	var tiles := cone(3)
	assert_false(tiles.is_empty(), 'The cone is not empty.')
	var to_attacker:int = UnitRelation.distance_between(blush, attacker)
	for tile:Vector2i in tiles:
		var moved:int = Tile.distance(BLUSH_TILE, tile)
		var away:int = Tile.get_closest_pair_between(
			[tile] as Array[Vector2i], attacker.occupied_tiles()).distance
		assert_true(moved + away == to_attacker or to_attacker + away == moved,
			'Tile %s lies on the line through the attacker.' % tile)

func test_a_tile_straight_toward_the_attacker_is_offered():
	# The positive control, without which every exclusion below could pass on an empty set.
	assert_true(cone(3).has(Vector2i(9, 6)), 'Three spaces due east, straight at it.')

func test_a_tile_on_the_far_side_of_the_attacker_is_offered():
	# THE OVERSHOOT CLAUSE (reach design ruling A, 2026-09-17), which the shipped rule refused: the
	# mech folds THROUGH the attacker and comes out behind it. With the attacker two spaces east,
	# (10, 6) is four away and two past it - 2 + 2 == 4 - so the overshoot clause keeps it while the
	# approach clause (4 + 2 == 2) does not.
	UnitTile.move_to(attacker, Vector2i(8, 6))
	assert_true(cone(4).has(Vector2i(10, 6)),
		'Two spaces past an attacker two spaces away, on a roll of four.')
	assert_true(cone(4).has(Vector2i(7, 6)),
		'And the approach clause still holds in the same cone, so this is a widening and not a swap.')

func test_an_adjacent_attacker_yields_the_far_side_at_a_roll_of_two():
	# THE CASE THE FRAME CLOSE FOUND, and the reason ruling A was taken: with the attacker already
	# adjacent the shipped cone was EMPTY at every roll, so a point-blank miss earned the mech
	# nothing. A two-space fold now lands it on the far side - 1 + 1 == 2 - which keeps the attacker
	# inside a melee weapon's threat and so keeps the Skirmish alive (ruling 5 needs no change).
	UnitTile.move_to(attacker, Vector2i(7, 6))
	assert_true(cone(2).has(Vector2i(8, 6)), 'Straight through it and out the other side.')
	assert_false(cone(1).has(Vector2i(8, 6)),
		'But not on a roll of one: the far side is two spaces away, which is what leaves the cone'
		+ ' empty at a roll of one and keeps the no-tile test below meaningful.')

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
	# Boxed in by geometry: with the attacker ADJACENT and a roll of ONE, no tile closes as much as it
	# costs to reach and none is far enough to reach the attacker's far side, so the cone is empty and
	# the reaction is spent on nothing. THE ROLL IS NOW LOAD-BEARING and was not before 2026-09-17:
	# the overshoot clause yields (8, 6) from a roll of two upwards, so "empty at every roll" - which
	# this comment used to claim, and the action's header with it - is no longer true. A roll of one is
	# the surviving case, and it is still a real one: an adjacent miss with a low roll earns nothing.
	UnitTile.move_to(attacker, Vector2i(7, 6))
	var reactions_before := blush_reactions()
	arm(true, 1) # the attacker is ENGAGED from here, so the rifle draws a difficulty die too
	await miss()
	assert_lt(blush_reactions(), reactions_before, 'Spent anyway (ruling 10).')
	assert_eq(blush.tile(), BLUSH_TILE, 'And nowhere to spend it on.')

# ---------------------------------------------------------------- the teleport itself

func test_the_blush_teleports_toward_the_attacker():
	# THE CARD'S FIRST HALF, END TO END, and until 2026-09-17 nothing in this file asserted that the
	# mech moves AT ALL - every test above stops at the spend or reads the cone through the helper. Six
	# spaces on a roll of 6, straight at the shot that missed.
	land_on(LANDING)
	arm(true, 6)
	await miss()
	assert_eq(blush.tile(), LANDING, 'It teleported the whole six spaces it rolled.')
	assert_eq(UnitRelation.distance_between(blush, attacker), 2,
		'And "in the direction of the attacker" means eight tiles away became two.')

# ---------------------------------------------------------------- the Skirmish

func test_a_teleport_that_ends_out_of_threat_offers_no_skirmish():
	# The Blush carries no weapon here at all, so nothing can reach - the cleanest form of "out of
	# threat", and the negative control for the case below.
	arm(true, 2)
	await miss()
	assert_eq(attacker.current_damage(), 0, 'No follow-up shot landed.')

func test_a_weapon_whose_threat_does_not_reach_the_attacker_fires_nothing():
	# THREAT, NOT RANGE, which is the whole reason the action reads
	# UnitRelation.get_weapons_that_can_overwatch (unit_relation.gd:220-226) rather than
	# get_weapons_that_can_react_against with its normal-range flag. mw_assault_rifle is the case that
	# tells them apart: aim_range 10 against a threat of 1, so at the two tiles LANDING leaves between
	# them it is well in range and nowhere near threat.
	#
	# The rifle is Reliable 2, so if it ever did fire the attacker would take damage whether the shot
	# hit or missed (maidens_blush_fixture.gd:73-76) - there is no roll this test can pass on.
	MaidensBlushFixture.equip_ranged(blush)
	land_on(LANDING)
	arm(true, 6)
	await miss()
	assert_eq(blush.tile(), LANDING, 'Fixture: it teleported, so a weapon was looked for at all.')
	assert_eq(attacker.current_damage(), 0, 'In range is not in threat: nothing fired.')

func test_the_follow_up_lands_and_costs_the_mech_nothing_of_its_own():
	# THE SECOND SENTENCE OF THE CARD, asserted on a shot that provably happened. This test used to
	# claim only that the economy was untouched, which an unfixed d6 made vacuous: the mech never
	# reached threat, no shot was ever fired, and "nothing was spent" was true of nothing.
	#
	# The Uffish Gyre and Draw Fire lesson is the other half: the shot is the WEAPON's own
	# SpecificAction and choose_and_use_no_spend keeps the mech's action economy untouched off-turn.
	# Both claims belong in one test so the economy one is made about a real Skirmish.
	#
	# mw_variable_sword threatens 2, and the follow-up rolls 6 on the d20 plus 6 on the sword's own
	# accuracy die against the dummy's evasion of 10 - see arm() for why every die after the first is
	# the roll passed in.
	MaidensBlushFixture.equip_melee(blush)
	land_on(LANDING)
	var actions_before := blush.state.actions
	arm(true, 6)
	await miss()
	assert_eq(blush.tile(), LANDING, 'Fixture: the teleport put the attacker inside threat.')
	assert_gt(attacker.current_damage(), 0, 'And the Skirmish went off.')
	assert_eq(blush.state.actions, actions_before,
		'Its quick and full actions are exactly where they were.')

func test_a_vetoed_teleport_forfeits_the_skirmish():
	# RULING 5's teeth: the follow-up needs a teleport that actually happened, and Uncertainty Field's
	# veto means it did not. The negative twin of the test above - same weapon, same landing, same roll,
	# one different answer - so the absence of the shot is the fade's doing and nothing else's.
	#
	# The field aborts the move core at ENTIRE_MOVEMENT / PRE (teleport.gd:180-192), which is what
	# action_abjuration_of_metal.gd:123's `move.aborted` reads.
	#
	# AND THAT GUARD IS OVER-DETERMINED, WHICH IS WORTH KNOWING RATHER THAN DISCOVERING TWICE: a veto
	# returns one line before undergo_move, so the mech is still standing on `origin` and the SAME line's
	# `unit.tile() == origin` catches the identical case. Deleting either half alone leaves this test
	# green; deleting both turns it red. The neighbouring note calling the origin comparison unreachable
	# is about the CONE - no roll offers the tile the mech is already on - and says nothing about this
	# path, where it is reached every time.
	# AND THE FADE DOES NOT SURVIVE THIS PARTICULAR TRIGGER, which is content behaving correctly and
	# not a gap. Abjuration triggers on a MISS, mw_assault_rifle is Reliable 2, and a Reliable miss
	# still deals its damage - rolled by event_unit_attack_declared at :89, AFTER the per-target attack
	# events at :67 that this whole reaction runs inside. So the order really is: fade granted, veto
	# taken, then two points of Reliable damage land, and buff_uncertainty_field_break clears the
	# Invisible it just granted, exactly as the card says it must. Fading away from a Reliable attacker
	# buys the veto and nothing else. Recorded at the frame close as a ruling; measured, not reasoned.
	MaidensBlushFixture.equip_melee(blush)
	land_on(LANDING)
	arm(true, 6, true) # this time the player TAKES the fade
	await miss()
	assert_eq(blush.tile(), BLUSH_TILE, 'The field replaced the teleport, so it never moved.')
	assert_eq(field_uses_this_round(), 1, 'The field really did fire - and without this assertion the'
		+ ' two either side of it would hold just as well for a teleport that never found a tile.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE),
		'And the fade is already gone, broken by the Reliable 2 that the triggering miss still dealt.')
	assert_eq(attacker.current_damage(), 0, 'And a teleport that never happened earns no Skirmish.')

# ---------------------------------------------------------------- the consolation fade

func test_an_empty_cone_offers_the_fade_instead():
	# RULING B'S FIRST EXIT. With the attacker adjacent and a roll of one the cone is empty, so the
	# action logs no_space.log and - since 2026-09-17 - hands the player the round's Uncertainty Field
	# rather than returning with nothing.
	#
	# A MISSED RAM RATHER THAN THE RIFLE, and that is the whole reason this test does its own setup:
	# mw_assault_rifle is Reliable 2, so its miss still lands two damage AFTER the reaction resolves,
	# and buff_uncertainty_field_break then clears the Invisible the fade just granted (the frame
	# close's Reliable ruling). A Ram that misses deals nothing, so the status is still there to
	# assert - which is the strongest form of "the fade really happened".
	UnitTile.move_to(attacker, Vector2i(7, 6))
	assert_true(cone(1).is_empty(), 'Fixture: an adjacent attacker leaves no tile at a roll of one.')
	arm(true, 1, true) # accept Abjuration, roll 1, TAKE the fade
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([MaidensBlushFixture.MISS_ROLL, MaidensBlushFixture.MISS_ROLL], [])
	for _die in 12: Dice.CHEAT_ROLL_QUEUE.append(1)
	await SpecFactory.use_solo(game, attacker, &'mw_ram', [blush])

	assert_eq(field_uses_this_round(), 1, 'The round of Uncertainty Field was spent on the consolation.')
	assert_true(blush.has_status(Lancer.STATUS.INVISIBLE), 'And the mech faded.')
	assert_eq(blush.tile(), BLUSH_TILE, 'It never moved - there was nowhere to move to.')
	assert_eq(last_prompt_description(),
		X.tr('gear.mt_uncertainty_field.action_uncertainty_field.consolation.no_space.confirm'),
		"And it was asked with the consolation's own words, not the interception's (ruling 154).")

func test_a_cancelled_pick_offers_the_fade_instead():
	# RULING B'S SECOND EXIT. Abjuration picks through TargetActionUtil.ask_for_movement, so the cancel
	# is driven by answering the move request with a tile the pathfinder cannot reach: ask_for_movement_alt
	# hands back a plan whose move_path is empty (target_action_util.gd:106), which is the third arm of
	# the action's own `plan == null or plan.aborted or plan.move_path.is_empty()` guard. NOT
	# responder.abort_all, which aborts every request including the consolation prompt this test is
	# about.
	#
	# THE PATH REALLY IS EMPTY AND NOT A ONE-STEP LUNGE TOWARD THE CORNER:
	# is_tile_within_max_distance_of_straight_movement opens with `not using_movement_type.teleport`
	# (pathfinder.gd:711-717), so a teleport never takes the straight_path_to branch, and
	# pathfinder.path_to of an unreachable tile is empty.
	#
	# THE INVISIBLE IS NOT ASSERTED HERE, and that is the Reliable ruling rather than an omission: the
	# rifle's miss lands two damage after the reaction and the break buff clears the status. The use
	# count and the prompt are what discriminate.
	land_on(Vector2i(19, 19)) # on the map, far outside a roll of one
	arm(true, 1, true)
	await miss()

	assert_eq(blush.tile(), BLUSH_TILE, 'Fixture: the pick was cancelled, so nothing moved.')
	assert_eq(field_uses_this_round(), 1, 'And the fade was offered and taken instead.')
	assert_eq(last_prompt_description(),
		X.tr('gear.mt_uncertainty_field.action_uncertainty_field.consolation.cancelled.confirm'),
		'With the cancelled row, which is the other string ruling B asks for.')

func test_declining_the_consolation_leaves_the_round_and_the_reaction_as_they_were():
	# THE NEGATIVE CONTROL FOR BOTH EXITS, and the promise that ruling B adds an OFFER and changes
	# nothing else: declining spends no round, grants no Invisible, and leaves Abjuration itself spent,
	# which is exactly what this file asserted before the consolation existed.
	UnitTile.move_to(attacker, Vector2i(7, 6))
	var reactions_before := blush_reactions()
	arm(true, 1, false) # accept Abjuration, DECLINE the fade
	await miss()

	assert_lt(blush_reactions(), reactions_before, 'Abjuration itself is still spent (ruling 10).')
	assert_eq(field_uses_this_round(), 0, 'The fade was declined, so the round is still in hand.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'And nothing faded.')
	assert_eq(blush.tile(), BLUSH_TILE, 'And nothing moved.')

func test_a_teleport_that_lands_is_not_offered_the_consolation_as_well():
	# THE CONSOLATION IS ADDITIONAL, NOT A REPLACEMENT, and this is the test that keeps it from
	# double-asking. A picked tile produces a real event_unit_move, and the field's own
	# ENTIRE_MOVEMENT / PRE reaction offers the fade THERE - after the destination is chosen, before
	# the move resolves - so a player who picks a spot and then decides to fade still gets exactly
	# that. Exactly one offer per teleport, whichever door it came through.
	MaidensBlushFixture.equip_melee(blush)
	land_on(LANDING)
	arm(true, 6, false) # accept Abjuration, roll 6, DECLINE the field at the move
	await miss()

	assert_eq(blush.tile(), LANDING, 'Fixture: it teleported, so the field had a move to offer on.')
	assert_eq(field_offers(), 1, 'One teleport, one fade offer.')
	assert_eq(field_uses_this_round(), 0, 'Declined at the move, and never asked a second time.')
