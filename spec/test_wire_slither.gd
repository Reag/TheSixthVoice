# WIRE SLITHER (Naga trait, SP1 Task 2), ruling 6:
#   "1/round, when the Naga takes a Tech Action, it may immediately move two spaces. This movement
#    ignores engagement and doesn't provoke reactions."
#
# A unit_action POST reaction on the trait Kit, on the ActionReactionMovement archetype - the seam
# spec/test_spike_naga_sp1_seams.gd measured first. WHAT THIS FILE PROVES, in the design's own list
# (1.2): a Lock On offers the slither and the Naga moves 2; Scan offers; an invade offers; Boost does
# not; a weapon attack does not; the second tech action in a round does not offer; declining costs
# nothing and the next tech action that round still offers; the path ignores an engaging enemy and
# provokes no Overwatch; after the round refresh it offers again. Plus the wiring and the rows.
#
# HOW A SLITHER IS SEEN. The archetype opens the MOVEMENT PICKER (TargetActionUtil.ask_for_movement)
# and the stock responder answers it with chosen_move_tile, or the first tile it is offered. The
# prompt watcher (testkit/prompt_watcher.gd) reports every picker as KIND.move_tile with the
# SpecificAction that opened it in `using`, and THAT is how a slither is told apart from Boost's own
# picker: filter on using.gear.kit.compcon_id. A case asserting "no slither" reads zero such prompts,
# which only discriminates because the watcher records prompts the responder answered.
#
# GEOMETRY. The Naga is size 2, anchored at (4,4), occupying (4,4) (5,4) (4,5) (5,5). The hostile
# stands at (6,5): adjacent to (5,4) and (5,5), and with a rifle its threat 1 covers the Naga's
# first step whichever way it goes - the Overwatch case. The ENGAGEMENT case adds a size-2 engager
# west of the Naga (ENGAGER_TILE and its header), because three things defeated the obvious
# geometry: Chebyshev diagonals slip round a zone, a size-1 hostile does not stop a size-2 mover at
# all, and an engager outside the budget-2 scan ring marks nothing.
#
# SLOWED AND IMMOBILIZED: a Naga with either does not slither at all (author decision 7, 2026-09-23:
# correct Lancer - Slowed allows only the standard move). Pinned below, each with a liveness line.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_wire_slither.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Slither := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_naga/mt_wire_slither/action_wire_slither.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const NAGA_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(6, 5)
## Two south of the anchor: a legal slither destination (footprint (4,6)-(5,7), clear of the hostile).
const TWO_SOUTH := Vector2i(4, 6)
## Two west: the control walk's destination, away from the hostile and still inside its threat at
## the first step.
const TWO_WEST := Vector2i(2, 4)
## A second hostile, far enough to be nobody's neighbour, for the second-tech-action case.
const FAR_HOSTILE_TILE := Vector2i(10, 4)

## THE ENGAGEMENT GEOMETRY (rebuilt at the frame close, 2026-09-23). The Naga at (4,4) occupies
## (4,4)-(5,5); the ENGAGER is a SIZE-2 hostile at (1,4), footprint (1,4)-(2,5), two tiles from the
## Naga's (4,4), so the Naga starts UNENGAGED. Its zone (every tile adjacent to that footprint) is
## x 0-3, y 3-6, so a Naga anchor is ENGAGED when its own footprint touches it - x <= 3 and y 2-6.
## BEYOND_ZONE (2,2) is two steps from (4,4), and the ONLY tile adjacent to both is (3,3), an
## engaged anchor with no outward connections (pathfinder.gd:454). So a budget-2 pathfinder that
## honours engagement cannot offer (2,2), and the slither's - ignore_engagement - can.
##
## THE ENGAGER MUST BE INSIDE THE SCAN RING, which is what the first geometry got wrong (close
## review slice 1 #1): generate_for_movement_budget evaluates occupation only for tiles within the
## BUDGET of the anchor (pathfinder.gd:256, Tile.get_all_within), and the pathfinder only knows a
## tile engages its neighbours because it saw the engager standing on a scanned tile
## (pathfinder.gd:135-153). The old engager stood at x 7-8, three out from a budget-2 scan at x 4 - it
## marked nothing, and deleting ignore_engagement from the .tres stayed green. Here x 2 is scanned.
##
## SIZE 2 IS LOAD-BEARING: the pathfinder only marks a tile engaged when the engager WOULD STOP this
## mover - would_lose_movement_due_to_engagement_from (pathfinder.gd:147-150 ->
## unit_relation.gd:140-143), a SIZE compare - and a size-1 hostile does not stop a size-2 Naga.
const ENGAGER_TILE := Vector2i(1, 4)
const BEYOND_ZONE := Vector2i(2, 2)

var game:Gamemaster
var naga:Unit
var hostile:Unit
var watcher:PromptWatcher
var responder:SpecFactory.ChoiceBusResponder

func before_each() -> void:
	game = NagaFixture.create_game(self)
	responder = SpecFactory.current_responder
	watcher = add_child_autoqfree(PromptWatcher.new())
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	hostile = NagaFixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

## Every movement picker the SLITHER opened so far - Boost's own picker is filtered out by the
## SpecificAction that opened it.
func slither_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for info:Dictionary in watcher.kinds(PromptWatcher.KIND.move_tile):
		var using = info.get('using')
		if using is SpecificAction and GearCore.is_valid(using.gear) \
				and using.gear.kit.compcon_id == NagaFixture.WIRE_SLITHER_ID:
			found.append(info)
	return found

func uses_this_round() -> int:
	return NagaFixture.uses_this_round(naga, NagaFixture.WIRE_SLITHER_ID, NagaFixture.SLITHER_ACTION_ID)

func slither_kit() -> Kit:
	return ContentLibrary.get_kit(NagaFixture.WIRE_SLITHER_ID)

func slither_action() -> ActionReactionMovement:
	var kit := slither_kit()
	if kit == null: return null
	return kit.get_action(NagaFixture.SLITHER_ACTION_ID) as ActionReactionMovement

## A vanilla budget-2 pathfinder for the Naga's own standard movement type: the CONTROL for the
## engagement claim. AWAITED - the graph is built on a worker thread (pathfinder.gd:234).
func standard_two_step() -> Pathfinder:
	return await Pathfinder.generate_for_movement_budget(
		naga, 2, MovementType.create_for_standard_move(naga))

# ---------------------------------------------------------------- the wiring

func test_the_trait_and_its_reaction_are_registered_and_shaped_by_the_card() -> void:
	var kit := slither_kit()
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % NagaFixture.WIRE_SLITHER_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	assert_true(GearCore.is_valid(naga.get_gear(NagaFixture.WIRE_SLITHER_ID)),
		'And the live Naga carries it as gear.')
	var action := slither_action()
	assert_not_null(action, 'Its one action is an ActionReactionMovement.')
	if action == null: return
	assert_eq(action.triggers_on, [&'unit_action'] as Array[StringName], 'Triggered by any gear activation...')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST,
		'...at POST, which event_gear_activate fires only once the use count rose (:100-111).')
	assert_false(action.consumes_rxn, 'A trait, not a reaction point.')
	assert_false(action.is_mandatory, '"May": the picker can be cancelled.')
	assert_eq(action.movement_range_fixed, 2, '"Two spaces".')
	assert_eq(action.get_per_round_hard_limit(SpecificAction.create(naga, naga.get_gear(NagaFixture.WIRE_SLITHER_ID), action)), 1,
		'"1/round" - the hard limit, not the archetype\'s 99 for a point-free reaction.')
	var type:MovementType = action.movement_type
	assert_not_null(type, 'The .tres carries a MovementType.')
	if type == null: return
	assert_true(type.voluntary, 'The Naga\'s own move: voluntary.')
	assert_true(type.ignore_engagement, '"Ignores engagement" - the explicit flag.')
	assert_true(type.ignore_rxns, '"Doesn\'t provoke reactions" - the explicit flag.')
	assert_false(type.teleport, 'Not a teleport: nothing else a teleport skips rides along.')
	assert_false(type.ignore_difficult, 'Difficult terrain still costs - the card says nothing about it.')

func test_the_tech_predicate_is_the_engines_own_two_clauses() -> void:
	# Ruling 6, read straight off the static so a later edit to the predicate is a red here before
	# it is a wrong offer in play. The five basic actions the probe measured.
	var lock_on:Action = ContentLibrary.get_kit(NagaFixture.LOCK_ON).get_action(NagaFixture.LOCK_ON_ACTION)
	var scan:Action = ContentLibrary.get_kit(NagaFixture.SCAN).get_action(NagaFixture.SCAN_ACTION)
	var invade:Action = ContentLibrary.get_kit(NagaFixture.INVADE).actions[0]
	var boost:Action = ContentLibrary.get_kit(NagaFixture.BOOST).actions[0]
	var rifle:Action = ContentLibrary.get_kit(NagaFixture.MAIN_RIFLE).actions[0]
	assert_true(Slither.is_tech_action(lock_on), 'Lock On: an ActionSystem with is_tech.')
	assert_true(Slither.is_tech_action(scan), 'Scan: an ActionSystem with is_tech.')
	assert_true(Slither.is_tech_action(invade), 'An invade: an ActionAttackTech - the second clause.')
	assert_false(Slither.is_tech_action(boost), 'Boost is not tech.')
	assert_false(Slither.is_tech_action(rifle), 'A weapon attack is not tech.')
	assert_false(Slither.is_tech_action(slither_action()),
		'And the slither refuses ITSELF - its own activation is a unit_action too (the probe\'s third fact).')

func test_the_rows_resolve() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mt_wire_slither.name', 'gear.mt_wire_slither.effect',
			'gear.mt_wire_slither.action_wire_slither.name', 'gear.mt_wire_slither.action_wire_slither.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mt_wire_slither.name'), 'Wire Slither', 'Named off the card.')
	# AUTHOR DECISION 6 (frame close): the reaction's row is the card sentence VERBATIM, the Kit's own
	# text, so Action.show_in_tooltip hides it as a duplicate (action.gd:350-352) and the trait card
	# draws the card once.
	assert_eq(X.tr('gear.mt_wire_slither.action_wire_slither.effect'), X.tr('gear.mt_wire_slither.effect'),
		"The reaction's text is the card's, word for word.")
	var kit:Kit = ContentLibrary.get_kit(NagaFixture.WIRE_SLITHER_ID)
	assert_false(kit.get_action(NagaFixture.SLITHER_ACTION_ID).show_in_tooltip(kit), '...so it is not drawn twice.')

# ---------------------------------------------------------------- the offer

func test_a_lock_on_offers_the_slither_and_the_naga_moves_two() -> void:
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.lock_on(game, naga, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the Lock On landed.')
	assert_eq(slither_prompts().size(), 1, 'One slither picker opened.')
	assert_eq(naga.tile(), TWO_SOUTH, 'THE CLAIM: the Naga moved two spaces to where the responder chose.')
	assert_eq(uses_this_round(), 1, 'And the slither is spent for the round.')

func test_a_scan_offers_the_slither() -> void:
	assert_true(Scanpedia.is_anything_unscanned(hostile), 'fixture: Scan is available at all.')
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.scan(game, naga, hostile)
	assert_eq(slither_prompts().size(), 1, 'Scan is a Tech Action: one slither picker opened.')
	assert_eq(naga.tile(), TWO_SOUTH, 'And the Naga moved.')

func test_an_invade_offers_the_slither() -> void:
	responder.chosen_move_tile = TWO_SOUTH
	NagaFixture.queue([19])
	await NagaFixture.invade(game, naga, hostile)
	assert_eq(slither_prompts().size(), 1,
		'An invade is a Tech Action through the ActionAttackTech clause: one slither picker opened.')
	assert_eq(naga.tile(), TWO_SOUTH, 'And the Naga moved.')

func test_a_boost_does_not_offer_it() -> void:
	await NagaFixture.boost(game, naga)
	var boost:GearCore = naga.get_gear(NagaFixture.BOOST)
	assert_gt(boost.get_uses_this_turn(boost.kit.actions[0]), 0, 'LIVENESS: the Boost activated.')
	assert_true(slither_prompts().is_empty(), 'CONTROL: Boost is not tech - no slither picker.')
	assert_eq(uses_this_round(), 0, 'Nothing spent.')

func test_a_weapon_attack_does_not_offer_it() -> void:
	NagaFixture.arm_rifle(naga)
	NagaFixture.queue([19, 3])
	await NagaFixture.shoot(game, naga, hostile)
	assert_gt(hostile.current_damage(), 0, 'LIVENESS: the shot landed.')
	assert_true(slither_prompts().is_empty(), 'CONTROL: a weapon attack is not a Tech Action.')
	assert_eq(naga.tile(), NAGA_TILE, 'The Naga stayed put.')

# ---------------------------------------------------------------- 1/round and "may"

func test_the_second_tech_action_in_a_round_does_not_offer_it() -> void:
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(slither_prompts().size(), 1, 'fixture: the first tech action offered and was taken.')
	assert_eq(uses_this_round(), 1, 'fixture: spent.')
	responder.chosen_move_tile = Tile.INVALID
	var far := NagaFixture.create_hostile(game, FAR_HOSTILE_TILE)
	await NagaFixture.lock_on(game, naga, far) # same turn: quick tech has no per-turn limit
	assert_true(far.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the second Lock On landed.')
	assert_eq(slither_prompts().size(), 1, '1/ROUND: the second tech action opened no second picker.')
	assert_eq(naga.tile(), TWO_SOUTH, 'The Naga is where the first slither left it.')

func test_declining_costs_nothing_and_the_next_tech_action_still_offers() -> void:
	responder.abort_all = true # cancels the picker it is about to be offered
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(slither_prompts().size(), 1, 'The picker did open - there was something to decline.')
	assert_eq(naga.tile(), NAGA_TILE, 'It stayed put.')
	assert_eq(uses_this_round(), 0, '"MAY": declining costs nothing - spend_actions runs only after a confirmed plan.')
	responder.abort_all = false
	responder.chosen_move_tile = TWO_SOUTH
	var far := NagaFixture.create_hostile(game, FAR_HOSTILE_TILE)
	await NagaFixture.lock_on(game, naga, far)
	assert_eq(slither_prompts().size(), 2, 'The next tech action that round offered again...')
	assert_eq(naga.tile(), TWO_SOUTH, '...and this time it moved.')
	assert_eq(uses_this_round(), 1, 'Now it is spent.')

# ---------------------------------------------------------------- Slowed and Immobilized

func test_a_slowed_naga_does_not_slither() -> void:
	# AUTHOR DECISION 7 (2026-09-23): correct Lancer - Slowed allows only the standard move, so no
	# system move at all. The archetype refuses a VOLUNTARY move to a Slowed holder
	# (action_reaction_movement.gd:46).
	SpecFactory.apply(naga, Lancer.STATUS.SLOWED)
	assert_true(UnitCondition.is_slowed(naga), 'LIVENESS: the Naga IS Slowed.')
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.lock_on(game, naga, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the Lock On - a Tech Action - landed.')
	assert_true(slither_prompts().is_empty(), 'THE CLAIM: no slither picker for a Slowed Naga.')
	assert_eq(naga.tile(), NAGA_TILE, 'It stayed put.')
	assert_eq(uses_this_round(), 0, 'Nothing spent.')

func test_an_immobilized_naga_does_not_slither() -> void:
	SpecFactory.apply(naga, Lancer.STATUS.IMMOBILIZED)
	assert_true(UnitCondition.is_immobilized(naga), 'LIVENESS: the Naga IS Immobilized.')
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.lock_on(game, naga, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the Lock On - a Tech Action - landed.')
	assert_true(slither_prompts().is_empty(), 'THE CLAIM: no slither picker for an Immobilized Naga.')
	assert_eq(naga.tile(), NAGA_TILE, 'It stayed put.')
	assert_eq(uses_this_round(), 0, 'Nothing spent.')

func test_after_the_round_refresh_it_offers_again() -> void:
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(uses_this_round(), 1, 'fixture: spent this round.')
	await NagaFixture.cycle_turn(game, naga) # the Naga's OWN turn start resets its per-round tallies
	assert_eq(uses_this_round(), 0, 'LIVENESS: the refresh cleared the tally.')
	responder.chosen_move_tile = NAGA_TILE
	var far := NagaFixture.create_hostile(game, FAR_HOSTILE_TILE)
	await NagaFixture.lock_on(game, naga, far)
	assert_eq(slither_prompts().size(), 2, 'A new round: a second picker.')
	assert_eq(naga.tile(), NAGA_TILE, 'And it slithered back.')

func test_the_reaction_point_is_untouched() -> void:
	responder.chosen_move_tile = TWO_SOUTH
	await NagaFixture.open_turn(game, naga)
	var points_before:int = naga.core.current.reactions
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(naga.tile(), TWO_SOUTH, 'fixture: it did slither, so there was something to spend.')
	assert_eq(naga.core.current.reactions, points_before, 'A trait spends no reaction point.')

# ---------------------------------------------------------------- engagement and reactions

func test_the_slither_reaches_past_an_engagement_zone_a_vanilla_move_cannot_cross() -> void:
	var engager := NagaFixture.create_hostile(game, ENGAGER_TILE)
	SpecFactory.change_size(engager, 2)
	UnitTile.move_to(engager, ENGAGER_TILE) # re-track the grown footprint
	assert_eq(engager.get_size(), 2, 'fixture: the engager is size 2, big enough to stop a size-2 Naga.')
	assert_eq(UnitRelation.distance_between(naga, engager), 2, 'fixture: two tiles out - not yet engaging.')
	await NagaFixture.open_turn(game, naga)
	# The Naga IS Engaged here, by the file's default size-1 hostile at (6,5) - irrelevant: a unit
	# already within 1 never engages again for this move (pathfinder.gd:147), and the distance-2 line
	# above is what keeps the ENGAGER a new engagement the pathfinder must honour.
	var control := await standard_two_step()
	assert_false(control.is_movable(BEYOND_ZONE),
		'CONTROL: a budget-2 standard move cannot reach BEYOND_ZONE - its only route is the engaged (3,3).')
	assert_true(control.is_movable(Vector2i(3, 3)),
		'CONTROL LIVENESS: the engaged anchor itself IS reachable, as an endpoint - the zone stops, it does not wall.')
	responder.abort_all = true # open the picker, read what it offers, take nothing
	await NagaFixture.lock_on(game, naga, engager)
	assert_true(engager.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the Lock On landed.')
	var prompts := slither_prompts()
	assert_eq(prompts.size(), 1, 'The slither picker opened.')
	if prompts.is_empty(): return
	var offered:Pathfinder = prompts[0].get('pathfinder')
	assert_not_null(offered, 'The watcher reported the slither pathfinder.')
	if offered == null: return
	assert_true(offered.is_movable(BEYOND_ZONE),
		'THE CLAIM: the slither ignores engagement and offers the anchor behind the zone, two steps away.')

func test_the_slither_provokes_no_overwatch_and_a_plain_move_does() -> void:
	NagaFixture.arm_rifle(hostile) # threat 1 covers every first step the Naga can take
	responder.chosen_move_tile = TWO_SOUTH
	NagaFixture.queue([19, 3, 3]) # for any Overwatch that DOES fire: a hit
	await NagaFixture.lock_on(game, naga, hostile)
	assert_eq(naga.tile(), TWO_SOUTH, 'fixture: it slithered out through the threat.')
	assert_eq(naga.current_damage(), 0, 'THE CLAIM: no Overwatch - the move ignores reactions.')

	# CONTROL: the same Naga, back in threat, walking a standard move draws the shot. Cycle the
	# turn so the standard move budget is fresh, and walk back adjacent first.
	UnitTile.move_to(naga, NAGA_TILE)
	await NagaFixture.cycle_turn(game, naga)
	NagaFixture.queue([19, 3, 3])
	await SpecFactory.move(game, naga, TWO_WEST, MovementType.create_for_standard_move(naga))
	assert_eq(naga.tile(), TWO_WEST, 'fixture: the control walk happened.')
	assert_gt(naga.current_damage(), 0,
		'CONTROL: a plain move from inside the rifle\'s threat draws the Overwatch (Reliable 2 lands even on a miss).')
