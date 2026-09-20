# HUNT OF THE VAGRANT SOWCHE (O' Trickery's second invade, SP2 Task 8).
#
#   "Your target must succeed a Systems save or be teleported to a free space adjacent to the
#    closest character. If there are multiple characters tied for closest, you choose. This can only
#    be used 1/scene on each character."
#
# THE DICE ORDER IS THE WHOLE FIXTURE. A tech invade pops ONE entry - the d20 (attack_roll.gd:67);
# its damage_dice is the flat string '2' (action_attack_tech.gd:17) so roll_dice's loop body never
# runs, and no accuracy die is popped without an accuracy modifier (dice.gd:87-88). The forced save
# pops ONE more, immediately after. So every queue here is [invade d20, save d20], and
# SluaghFixture.queue tails with 1s - which means queue([19]) is a HIT AND A FAILED SAVE, and a PASS
# has to be queued explicitly.
#
# WITH ONE EXCEPTION, AND IT IS MEASURED RATHER THAN ASSUMED: AN AUTOHIT POPS NOTHING.
# EventUnitAttack.execute_attack_roll_sequence returns at its autohit branch (:148-154) BEFORE
# AttackRoll.roll_attack is ever called, so an ALLIED invade never touches the queue and the first
# entry goes to the SAVE. test_an_allied_target_auto_hits_saves_and_is_shoved therefore queues [1],
# not [19, 1] - a 19 there would be a PASSED save and the case would assert the wrong thing.
#
# THE STAMP GOES ON BEFORE THE SAVE (ruling 18): the HIT is the "use". A miss leaves the character
# available; a PASSED save does not. Both are pinned, because the two are the same absence of a move.
#
# THE TILE PICK IS A compcon_plan REQUEST, NOT reag_tile_set. Teleport.pick_tile goes through
# TargetActionUtil.ask_for_targets_alt (teleport.gd:315), whose player branch is
# choice_bus.choose_compcon_plan (target_action_util.gd:200) -> create_request(TYPE.compcon_plan)
# (choice_bus.gd:110-113). testkit/tile_set_answerer.gd filters on &'reag_tile_set' (:23) and is
# irrelevant here. Answered the way test_step_of_mist_and_thunder.gd answers one:
# responder.chosen_plan_queue.append(CompconPlan.create([tile], [], [])).
#
# AND THE ANSWER IS NOT CHECKED AGAINST WHAT WAS OFFERED, which decides how two of these cases are
# written. The responder regurgitates the queued plan whatever it contains (spec_factory.gd:454-455),
# and ask_for_targets_alt hands a player's plan straight back when it carries no movement
# (target_action_util.gd:227) - there is no "is this tile in the set" gate anywhere on that path. So
# a tile the engine never offered is still picked and still shoved to, and "the target did not land
# there" is green whatever destinations_beside returned. Every claim about WHICH TILES THE CARD
# OFFERS is therefore asserted against offered_tiles() below, read off the recorded prompt.
#
# AND THE TIE PROMPT IS A one_unit REQUEST, answered off testkit/mod_choice_responder.gd's
# unit_queue - which is also what RECORDS the prompts, so "a single closest character is auto-picked"
# can be asserted as "no prompt was raised" rather than as "the right unit was chosen anyway".
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hunt.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')

## Read by Task 9's card-text case, test_the_hunt_rows_resolve, the same way this file's sibling
## specs (test_rend_nexus.gd, test_grey_birds.gd) read their own rows.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const MAP_SIZE := Vector2i(30, 14)

const SLUAGH_TILE := Vector2i(4, 6)
## The victim, four east of the Sluagh.
const TARGET_TILE := Vector2i(8, 6)
## Two east of the victim: the closest character to it, and closer than the Sluagh.
const ANCHOR_TILE := Vector2i(10, 6)
## The tile the spec asks the picker for - adjacent to ANCHOR_TILE and free.
const LANDING := Vector2i(10, 7)
## Symmetrically two WEST of the victim, for the tie case.
const RIVAL_TILE := Vector2i(6, 6)

## A size-2 victim, far enough east that ANCHOR_TILE is still the closest character to it. A size-2
## unit at (x,y) occupies (x,y), (x+1,y), (x,y+1), (x+1,y+1) - UnitTile.get_occupied (:45-55) grows
## the footprint in +x and +y from the anchor corner - so this one holds (13,6) to (14,7).
const BIG_TILE := Vector2i(13, 6)
## In the anchor's ring and free of units, but a size-2 footprint planted here runs (10,6) - where
## the anchor stands - so the engine's own standability test refuses it and the design's size-blind
## filter would not. THE discriminator for departure 8.
const FOOTPRINT_BLOCKED := Vector2i(9, 5)
## Also in the anchor's ring, and its 2x2 footprint ((11,5) (12,5) (11,6) (12,6)) is clear.
const FOOTPRINT_FITS := Vector2i(11, 5)

## An ALLIED DRONE between the victim and the anchor. Two jobs in one case: it ENGAGES the victim (it
## is adjacent and hostile to it), and it is a character that is NOT an actor - so the closest-CHARACTER
## search must walk past it and take the anchor two tiles further out.
const DRONE_TILE := Vector2i(9, 6)
## Beside the ANCHOR and two tiles from the drone, so landing here really leaves the drone's
## engagement zone - and so it is absent from the offered set the moment "character" stops meaning
## is_actor() and the drone becomes the anchor.
const BEYOND_THE_DRONE := Vector2i(11, 6)

## A friendly victim, placed so the ANCHOR is its unique closest character (3) rather than tying with
## the hostile at TARGET_TILE (4).
const FRIEND_TILE := Vector2i(12, 8)
const BESIDE_THE_ANCHOR := Vector2i(10, 5)

## A Maiden's Blush victim, placed so the ANCHOR is again its unique closest character.
const BLUSH_TILE := Vector2i(12, 9)

## A hit. The dummy's e-def is 10 off the sheet, and 19 clears it - test_wicked_host.gd:167-169.
const D20_HITS := 19
## Beats a save target of 10 on its own.
const D20_PASSES_THE_SAVE := 20

var game:Gamemaster
var sluagh:Unit
var target:Unit
var anchor:Unit
## testkit/mod_choice_responder.gd - untyped, because its class is loaded at runtime and has no
## registrable class_name (res/content/gear/shared/README.md).
var responder

func before_each() -> void:
	var pair := SluaghFixture.create_game_with_prompt_queues(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_trickery(sluagh)
	target = SluaghFixture.create_hostile(game, TARGET_TILE)
	anchor = SluaghFixture.create_hostile(game, ANCHOR_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_plan_queue.clear()
	responder.unit_queue.clear()
	responder.abort_all = false

## Queue the tile the picker should answer with, then run the invade.
func run_hunt(landing:Vector2i = LANDING, rolls:Array[int] = [D20_HITS], at:Unit = null) -> void:
	if landing != Tile.INVALID:
		responder.chosen_plan_queue.append(CompconPlan.create([landing], [], []))
	SluaghFixture.queue(rolls)
	await SluaghFixture.hunt(game, sluagh, at if at != null else target)

func stamped(who:Unit) -> bool:
	var gear:GearCore = sluagh.get_gear(SluaghFixture.TRICKERY)
	return gear.state_has_id_in('used_on', who.core.persistent_id)

func hunt_specific() -> SpecificAction:
	return SpecificAction.from_id(sluagh, SluaghFixture.TRICKERY, SluaghFixture.HUNT_ID)

## The tile set the picker was actually OFFERED - see this file's header for why the landing cannot
## stand in for it. UnitTargeting.get_tiles_targetable returns a targetable_tiles_override VERBATIM
## before any other filtering (unit_targeting.gd:68-74), and Teleport.pick_tile installs exactly such
## an override carrying the caller's tiles (teleport.gd:302-307), so this reads back the array
## destinations_beside built.
func offered_tiles() -> Array[Vector2i]:
	if responder.plan_prompts.is_empty(): return []
	var using:SpecificAction = responder.plan_prompts.back().using
	if not SpecificAction.is_valid(using): return []
	return UnitTargeting.get_tiles_targetable(using)

# ---------------------------------------------------------------- the wiring

func test_the_system_carries_both_invades_in_the_cards_order():
	# THE PAIR, pinned HERE rather than in test_grey_birds.gd, so that file did not have to change
	# when this task landed. The order is the sheet's (specs/sixth-voice/08-sluagh.md:60-63) and it
	# is what the gear bar draws.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.TRICKERY)
	assert_not_null(kit, 'ms_o_trickery loads.')
	if kit == null: return
	var ids:Array[StringName] = []
	for action:Action in kit.actions: ids.append(action.get_id())
	assert_eq(ids, [SluaghFixture.GREY_BIRDS_ID, SluaghFixture.HUNT_ID] as Array[StringName],
		'Grey Birds then Hunt, the card\'s own order.')
	var specific := hunt_specific()
	assert_true(SpecificAction.is_valid(specific), 'And Hunt is reachable as gear on a live Sluagh.')
	if not SpecificAction.is_valid(specific): return
	assert_true(specific.action.is_invade, 'It is an INVADE.')

# ---------------------------------------------------------------- the save and the move

func test_a_failed_save_shoves_the_target_beside_the_closest_character():
	await run_hunt()
	assert_eq(target.tile(), LANDING,
		'THE CARD: a failed Systems save teleports the target beside the closest character.')
	assert_true(stamped(target), 'And the character is stamped as used.')

func test_a_passed_save_moves_nothing_and_still_stamps():
	# RULING 18: the HIT is the "use", not the failure. A passed save costs the character its slot.
	await run_hunt(LANDING, [D20_HITS, D20_PASSES_THE_SAVE])
	assert_eq(target.tile(), TARGET_TILE, 'A passed save moves nothing...')
	assert_true(stamped(target), '...and the character is still stamped: the hit was the use.')

func test_a_miss_leaves_the_character_available():
	# THE OTHER SIDE OF THE SAME RULING, and the discriminating one: a miss and a passed save leave
	# the same absence of a move, so only the stamp tells them apart.
	await run_hunt(Tile.INVALID, [1])
	assert_eq(target.tile(), TARGET_TILE, 'Nothing moved.')
	assert_false(stamped(target), 'And a MISS leaves the character available.')

func test_a_second_hunt_on_the_same_character_is_refused_at_targeting():
	await run_hunt()
	assert_true(stamped(target), 'fixture: stamped.')
	assert_false(hunt_specific().action.can_target_unit(target, hunt_specific()),
		'1/scene: the same character cannot be hunted twice.')
	assert_true(hunt_specific().action.can_target_unit(anchor, hunt_specific()),
		'But another character still can - the stamp is per TARGET, not per gear.')

# ---------------------------------------------------------------- the closest character

func test_the_closest_character_can_be_the_sluagh_itself():
	# "the closest character" - ANY faction, the Sluagh included (ruling 18). Moving the anchor out
	# of the way leaves the Sluagh as the nearest thing to the target.
	SluaghFixture.step(anchor, Vector2i(25, 6))
	SluaghFixture.track(game)
	var beside_the_sluagh := Vector2i(SLUAGH_TILE.x, SLUAGH_TILE.y + 1)
	await run_hunt(beside_the_sluagh)
	assert_eq(target.tile(), beside_the_sluagh, 'The target is dragged to the Sluagh\'s own side.')

func test_a_single_closest_character_is_auto_picked_with_no_prompt():
	# The negative half of the tie case, and it needs the RECORDER rather than the outcome: with one
	# clear winner the outcome is the same whether a prompt was raised and auto-answered or never
	# raised at all.
	await run_hunt()
	assert_true(responder.unit_prompts.is_empty(),
		'No unit choice was raised: one closest character is picked outright.')

func test_two_characters_tied_for_closest_prompt_a_unit_choice():
	# RULING 5: "If there are multiple characters tied for closest, you choose" - and "you" is the
	# SLUAGH'S player. A rival placed symmetrically opposite the anchor makes the tie.
	var rival:Unit = SluaghFixture.create_hostile(game, RIVAL_TILE)
	responder.unit_queue.append(rival)
	var beside_the_rival := Vector2i(RIVAL_TILE.x, RIVAL_TILE.y + 1)
	await run_hunt(beside_the_rival)
	assert_false(responder.unit_prompts.is_empty(), 'A unit choice WAS raised.')
	if responder.unit_prompts.is_empty(): return
	var offered:Array = responder.unit_prompts.back().units
	assert_eq(offered.size(), 2, 'Both tied characters were offered...')
	assert_true(offered.has(rival) and offered.has(anchor), '...and they are the two tied ones.')
	assert_eq(target.tile(), beside_the_rival, 'And the chosen one is where the target landed.')

# ---------------------------------------------------------------- the space

func test_a_size_two_target_is_only_offered_tiles_its_footprint_fits():
	# DEPARTURE 8, pinned. UnitTile.filter_to_free_tiles - what the design named - takes no unit and
	# no size (unit_tile.gd:605-610), so it would offer a size-2 target a tile its footprint cannot
	# occupy. Teleport.candidate_tiles uses UnitTile.is_tile_standable with a solipsistic Katamari of
	# the MOVER (teleport.gd:249-255), which reaches Occupation's bigunit_invalid_endpoint
	# (pathfinder.gd:805-812) and is therefore size-aware.
	#
	# ASSERTED ON THE OFFERED SET, NOT ON THE LANDING - see this file's header. Nothing validates the
	# answered plan, so a size-2 unit asked to stand on a tile it does not fit simply fails to move,
	# and it fails to move under the size-BLIND filter too: the landing discriminates nothing.
	var big:Unit = SluaghFixture.create_hostile(game, BIG_TILE)
	SpecFactory.change_size(big, 2)
	SluaghFixture.track(game)
	assert_eq(big.occupied_tiles().size(), 4, 'fixture: it really occupies a 2x2 footprint.')
	if big.occupied_tiles().size() != 4: return

	await run_hunt(FOOTPRINT_FITS, [D20_HITS], big)
	var tiles := offered_tiles()
	assert_false(tiles.is_empty(), 'fixture: the picker was offered something.')
	assert_false(tiles.has(FOOTPRINT_BLOCKED),
		'A tile whose 2x2 footprint would run into the anchor is never offered.')
	assert_true(tiles.has(FOOTPRINT_FITS), 'But one beside it, whose footprint is clear, is.')
	assert_eq(big.tile(), FOOTPRINT_FITS, 'And that is where the size-2 target landed.')

func test_no_free_tile_means_no_move_and_the_stamp_still_lands():
	# "No free tile: the save was still forced, the stamp stands, nothing moves, one log line."
	# Walled in on every side, the candidate set is empty and there is nothing to pick.
	var box:Array[Vector2i] = []
	for dx:int in [-1, 0, 1]:
		for dy:int in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			box.append(Vector2i(ANCHOR_TILE.x + dx, ANCHOR_TILE.y + dy))
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', box)
	game.map.calculate_los_blockers()
	SluaghFixture.track(game)

	await run_hunt(Tile.INVALID)
	assert_eq(target.tile(), TARGET_TILE, 'Nothing moved.')
	assert_true(responder.plan_prompts.is_empty(), 'And no reticle was even raised: the set was empty.')
	assert_true(stamped(target), 'But the save was forced and the stamp stands.')

func test_cancelling_the_tile_pick_moves_nothing_and_the_stamp_stands():
	# Teleport.pick_tile returns Tile.INVALID when the player cancels (teleport.gd:316-317), and a
	# cancel is NOT a refund: the invade hit, so the character is spent. Recorded as the reading
	# rather than left to chance.
	responder.abort_all = true
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.hunt(game, sluagh, target)
	assert_false(responder.plan_prompts.is_empty(), 'fixture: the reticle really was raised...')
	assert_eq(target.tile(), TARGET_TILE, '...and a cancelled pick moves nobody.')
	assert_true(stamped(target), 'And the character is still spent.')

# ---------------------------------------------------------------- the shove itself

func test_the_shove_drags_an_engaged_target_out_past_the_drone_that_engaged_it():
	# TWO CLAUSES IN ONE BOARD, because they need the same piece and neither can be asked without it.
	#
	# (1) ENGAGEMENT. forced_movement_type sets ignore_engagement (Task 1), and a teleport ignores it
	# anyway - so a target standing next to an enemy is dragged clear. The fixture pre-condition is
	# asserted rather than assumed: the plan's own version of this case put a HOSTILE beside the
	# target, and two units on the same side never engage each other, so it would have been a
	# tautology. An allied DRONE is hostile to the target and does engage it.
	#
	# (2) "CHARACTER" MEANS is_actor(). Unit.is_character() is TRUE for a drone (unit.gd:116-117), so
	# a drone at distance 1 would beat the anchor at distance 2 the moment the search asks the wrong
	# question - and BEYOND_THE_DRONE is beside the ANCHOR and two tiles from the drone, so it leaves
	# the offered set entirely if that happens. Without this clause nothing in the suite places a
	# drone at all and the mutation is invisible.
	var drone:Unit = SluaghFixture.create_drone(game, DRONE_TILE)
	SluaghFixture.track(game)
	assert_true(UnitCondition.is_engaged(target), 'fixture: the drone really engages the target.')

	await run_hunt(BEYOND_THE_DRONE)
	assert_true(offered_tiles().has(BEYOND_THE_DRONE),
		'The ANCHOR is the closest character: a drone is not one, whatever is_character() says.')
	assert_eq(target.tile(), BEYOND_THE_DRONE, 'And the shove lands regardless of engagement.')
	assert_false(UnitCondition.is_engaged(target), 'Two tiles out, the engagement is gone.')
	assert_true(Unit.is_valid(drone), 'fixture: the drone is still standing where it was.')

func test_an_interdiction_field_stops_the_shove_and_the_stamp_still_stands():
	# THE CONTROLLER'S ROUTE RULING (2026-09-20, reversing the plan's departure 7), asked of the CARD
	# rather than of the helper: a shove is somebody else's move, so the fence a unit's own effects put
	# round it is the engine's ban channel and a Hunt does not break it. Teleport.shove sends
	# target_tiles, so EventUnitMove.undergo_move builds a pathfinder of its own
	# (event_unit_move.gd:139-145) and Pathfinder.create reads every MOVEMENT_RESTRICTION there
	# (:345-352); Teleport.move's hand-built single step bypasses all of it.
	#
	# THIS CASE EXISTS BECAUSE THE PLAN'S OWN MUTATION 4 DOES NOT DISCRIMINATE. Swapping shove for
	# move was predicted to redden the Uncertainty Field case; measured, it reddens nothing, and the
	# trait says why in its own header - reach design ruling C (2026-09-17) deleted the
	# own-involuntary exemption, so the field now reads Teleport.forcer, and BOTH routes hang the same
	# SLUAGH SpecificAction on the move. A ban is the only observable that separates them, and without
	# one on the board this file could not tell if Hunt had quietly become unpreventable.
	#
	# The Minotaur's Interdiction Field hung straight on the Sluagh, no system and no aura: its
	# check_if_passive_applies asks only for a teleporting movement type and an ENEMY holder
	# (buff_interdiction_field.gd:16-21). The holder must be WITHIN 3 of the mover or get_values
	# returns the doughnut instead of the lockdown (:29-33) - so the Sluagh steps to 3 away, which
	# still leaves the anchor at 2 the unique closest character.
	SluaghFixture.step(sluagh, Vector2i(5, 6))
	SluaghFixture.track(game)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), sluagh, &'buff_interdiction_field')

	await run_hunt(LANDING)
	assert_true(offered_tiles().has(LANDING),
		'fixture: the reticle was raised and offered the landing, so only the MOVE was refused.')
	assert_eq(target.tile(), TARGET_TILE, 'A MOVEMENT_RESTRICTION ban stops a Hunt.')
	assert_true(stamped(target), 'And the character is still spent: the save was forced either way.')

func test_an_allied_target_auto_hits_saves_and_is_shoved():
	# CONTROLLER DECISION, a PROPOSED ruling for the author: vanilla Puppet System parity. An allied
	# invade auto-hits (action_attack_tech.gd:71-73), and Hunt's card says only "your target" where
	# Grey Birds says "must target YOU" - which is meaningless for a friend. So an ally is hunted.
	#
	# ONE DIE, NOT TWO: the autohit branch returns before the d20 is rolled, so [1] is the SAVE.
	var friend:Unit = SluaghFixture.create_ally(game, FRIEND_TILE)
	await run_hunt(BESIDE_THE_ANCHOR, [1], friend)
	assert_true(stamped(friend), 'An allied target is stamped...')
	assert_eq(friend.tile(), BESIDE_THE_ANCHOR, '...and shoved, exactly as a hostile one is.')

func test_a_maidens_blush_uncertainty_field_vetoes_the_shove():
	# THE REAL VETO CASE ruling 18 names, with a real frame holding it - test_teleport.gd's own veto
	# test uses a hand-built listener, which proves the seam but not the card.
	#
	# WHY THE FIELD SEES THIS AT ALL: Teleport.shove hangs the SLUAGH's SpecificAction on the move as
	# its `object`, so Teleport.forcer returns the Sluagh, are_enemies(blush, sluagh) is true, and the
	# trait's own exemption - which is written as "the forcer is me" - does not fire. A shove built
	# without that object would be invisible to it.
	#
	# THE BLUSH IS SET HOSTILE, and that is forced by the trait rather than chosen: its whole
	# involuntary branch ends on UnitRelation.are_enemies(unit, forcer)
	# (action_uncertainty_field.gd:88), so a PLAYER-faction Blush shoved by a PLAYER-faction Sluagh is
	# never offered the fade at all. set_faction is vanilla's own spec idiom for this
	# (test/gear/test_ms_blinkshield.gd:43). A non-player Blush then auto-accepts:
	# CommonActionUtil.confirm_use returns true without asking off the map's AI branch, so NO yes/no
	# is queued - the INVISIBLE below is what says the fade really ran rather than the shove quietly
	# failing.
	var blush:Unit = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	blush.set_faction(Faction.AI_ENEMY)
	SluaghFixture.track(game)
	await run_hunt(LANDING, [D20_HITS], blush)
	assert_ne(blush.tile(), LANDING,
		'The field took the teleport: the Blush is not where the Sluagh sent it.')
	assert_true(blush.has_status(Lancer.STATUS.INVISIBLE),
		'And it faded instead, which is what says the trait fired rather than the shove failing.')
	assert_true(stamped(blush), 'And the character is still spent - the invade hit.')

func test_the_hunt_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in [
		'gear.ms_o_trickery.action_hunt_of_the_vagrant_sowche.name',
		'gear.ms_o_trickery.action_hunt_of_the_vagrant_sowche.effect',
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.ms_o_trickery.action_hunt_of_the_vagrant_sowche.name'),
		'Hunt of the Vagrant Sowche', 'The card\'s own name, without the LCP\'s trailing space.')
	# X.tr keeps the glossary pipes, so this pins the one pipe on the row too.
	assert_true(X.tr('gear.ms_o_trickery.action_hunt_of_the_vagrant_sowche.effect')
		.begins_with('Your target must succeed a |Systems save| or be teleported'),
		'And the effect row is the LCP\'s sentence, with |Systems save| piped and "teleported" bare.')
	assert_true(X.tr('gear.ms_o_trickery.action_hunt_of_the_vagrant_sowche.effect')
		.ends_with('1/scene on each character.'), 'Entire, to the last clause.')
