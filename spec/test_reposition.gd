# FRACTURED SILHOUETTE / REPOSITION - "Reaction, 1/round. Trigger: A hostile character at a lower
# elevation misses you with a ranged attack. Effect: You may immediately move up to half your speed."
# Design 1.3, ruling 6.
#
# A real ActionReactionMovement (1/round by the engine, consumes_rxn), on ATTACK POST with the Knot as
# the target. The shooter is context.unit and must be a hostile is_actor() whose
# UnitTile.effective_floor is STRICTLY lower than the Knot's; a flier counts at +3. The move is
# Util.half(speed max), rounded up, as an ordinary voluntary move.
#
# THE MAP. A one-block plateau covers columns 0-7; the Knot stands on it at (4,4) and the shooter on
# the ground at (12,4), eight tiles away and inside the rifle's Range 10. Every "does not" test keeps
# that geometry and changes exactly one thing, and test_a_lower_hostiles_ranged_miss_offers_it is the
# control each one is read against.
#
# OFFERS ARE COUNTED BY TITLE. Firing an attack opens confirms of its own, so a bare yesno_prompts
# count would include the shooter's; CommonActionUtil.confirm_use titles the offer with the action's
# name (test_abjuration_of_metal.gd's offers()).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_reposition.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')

const KNOT_TILE := Vector2i(4, 4)
const SHOOTER_TILE := Vector2i(12, 4)
const PLATEAU_FROM := Vector2i(0, 0)
const PLATEAU_TO := Vector2i(7, 9)

## The rifle's Reliable 2: what a miss deals, and so the proof a miss actually went off.
const RELIABLE := 2
## What Fixture.attack queues: one d20 and twelve damage sixes.
const QUEUED := 13

var game:Gamemaster
var responder
var watcher
var knot:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game_with_prompts(self)
	game = made[0]
	responder = made[1]
	watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	knot = Fixture.create_knot(game, KNOT_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func raise_plateau() -> void:
	Fixture.raise(game, Fixture.rect(PLATEAU_FROM, PLATEAU_TO), 1)

## Reposition's own offers.
func offers() -> int:
	var count := 0
	for prompt:Dictionary in responder.yesno_prompts:
		if str(prompt.title).contains('Reposition'): count += 1
	return count

## Answer Reposition's offer `accept`; the attack's own confirms are answered yes by the base rule.
func arm(accept:bool) -> void:
	responder.chosen_yesnos = true
	responder.yesno_queue.clear()
	# The shooter is AI, so its own attack raises no yes/no; the first yes/no is Reposition's.
	responder.yesno_queue.append(accept)

func fire(shooter:Unit, kit_id:StringName, d20:int) -> void:
	await Fixture.open_turn(game, shooter)
	await Fixture.attack(game, shooter, kit_id, knot, [d20])

func miss_from(shooter:Unit, kit_id:StringName = Fixture.RANGED) -> void:
	await fire(shooter, kit_id, Fixture.MISS_ROLL)

## The furthest tile Reposition's move picker offered, measured from where the Knot stood.
func furthest_offered(from:Vector2i) -> int:
	var moves:Array[Dictionary] = watcher.kinds(&'move_tile')
	if moves.is_empty(): return -1
	var furthest := -1
	for tile:Vector2i in moves[0].pathfinder.reachable_tiles: furthest = maxi(furthest, Tile.distance(from, tile))
	return furthest

# ---------------------------------------------------------------- the shape

func test_the_trait_carries_the_reposition_reaction():
	var kit:Kit = ContentLibrary.get_kit(Fixture.FRACTURED_SILHOUETTE_ID)
	assert_true(Kit.is_valid(kit), 'mt_fractured_silhouette is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	var action:Action = kit.get_action(Fixture.REPOSITION_ACTION)
	assert_not_null(action, 'It carries action_reposition.')
	if action == null: return
	assert_true(action is ActionReactionMovement, 'An ActionReactionMovement.')
	var rxn = action # untyped: the exports live on the subclass
	assert_true(rxn.consumes_rxn, 'A real reaction: it spends the reaction, and so is 1/round.')
	assert_eq(rxn.triggers_on, [&'attack'] as Array[StringName], 'On an attack.')
	assert_eq(rxn.trigger_timing, ReactionBus.TIMING.POST, 'After it resolves.')
	assert_eq(rxn.triggering_unit_is, ActionReactionMovement.OWNER_IS.TARGET_UNIT, 'The Knot is the target.')
	assert_true(MovementType.is_valid(rxn.movement_type) and rxn.movement_type.voluntary, 'A voluntary move.')

# ---------------------------------------------------------------- the trigger

func test_a_lower_hostiles_ranged_miss_offers_it():
	raise_plateau()
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	assert_lt(UnitTile.effective_floor(shooter), UnitTile.effective_floor(knot), 'Fixture: the shooter stands lower.')
	arm(false)
	await miss_from(shooter)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 1, 'A lower hostile\'s ranged miss offers Reposition, exactly once.')

func test_an_equal_height_hostiles_miss_does_not_offer_it():
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	assert_eq(UnitTile.effective_floor(shooter), UnitTile.effective_floor(knot), 'Fixture: level ground.')
	arm(false)
	await miss_from(shooter)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 0, 'Strictly lower: an equal-height shooter offers nothing.')

func test_a_higher_hostiles_miss_does_not_offer_it():
	# The plateau under the SHOOTER this time.
	Fixture.raise(game, Fixture.rect(Vector2i(10, 0), Vector2i(15, 9)), 1)
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	assert_gt(UnitTile.effective_floor(shooter), UnitTile.effective_floor(knot), 'Fixture: the shooter stands higher.')
	arm(false)
	await miss_from(shooter)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 0, 'A higher shooter offers nothing.')

func test_a_hit_does_not_offer_it():
	raise_plateau()
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	arm(false)
	await fire(shooter, Fixture.RANGED, 30)
	assert_gt(knot.current_damage(), 0, 'Fixture: the rifle hit.')
	assert_eq(offers(), 0, 'A hit offers nothing.')

func test_a_melee_miss_does_not_offer_it():
	raise_plateau()
	# Adjacent, one step down off the plateau's edge.
	UnitTile.move_to(knot, Vector2i(7, 4))
	var shooter:Unit = Fixture.create_dummy(game, Vector2i(8, 4))
	Fixture.equip(shooter, Fixture.MELEE)
	assert_lt(UnitTile.effective_floor(shooter), UnitTile.effective_floor(knot), 'Fixture: the swordsman stands lower.')
	arm(false)
	await miss_from(shooter, Fixture.MELEE)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), QUEUED, 'Fixture: the swing went off (its d20 was popped).')
	assert_eq(knot.current_damage(), 0, 'Fixture: and missed.')
	assert_eq(offers(), 0, 'A melee miss is not a ranged attack.')

func test_a_drones_miss_does_not_offer_it():
	raise_plateau()
	var drone:Unit = Fixture.create_hostile_drone(game, SHOOTER_TILE)
	assert_false(drone.is_actor(), 'Fixture: a drone is not a character (ruling 3).')
	arm(false)
	await miss_from(drone)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 0, 'A drone is not a hostile character.')

func test_an_allys_miss_does_not_offer_it():
	raise_plateau()
	var ally:Unit = Fixture.create_hostile(game, SHOOTER_TILE, Faction.PLAYER)
	# A PLAYER shooter raises confirms of its own, so nothing is queued: every yes/no is answered yes,
	# and a wrongly offered Reposition would still be counted by its title.
	responder.yesno_queue.clear()
	responder.chosen_yesnos = true
	await miss_from(ally)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 0, 'An ally is not hostile.')

func test_a_flying_knot_is_higher_than_a_grounded_shooter():
	# Level ground; the Knot flies, so it counts at +3 (unit_tile.gd:226-234).
	UnitCondition.apply_status(SpecFactory.dummy_event(), knot, Lancer.STATUS.FLYING, Lancer.UNTIL.MANUAL)
	UnitTile.update_tracking_and_statuses(game.map)
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	assert_lt(UnitTile.effective_floor(shooter), UnitTile.effective_floor(knot), 'Fixture: the flier stands higher.')
	arm(false)
	await miss_from(shooter)
	assert_eq(knot.current_damage(), RELIABLE, 'Fixture: the shot went off and missed.')
	assert_eq(offers(), 1, 'A grounded shooter is at a lower elevation than a flying Knot.')

# ---------------------------------------------------------------- the move

func test_the_move_reaches_exactly_half_speed_and_spends_the_reaction():
	raise_plateau()
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	var half:int = Util.half(knot.get_speed_max())
	assert_eq(half, 3, 'Fixture: speed 5, half rounded up is 3.')
	arm(true)
	var destination := KNOT_TILE + Vector2i(0, half)
	responder.chosen_move_tile = destination
	await miss_from(shooter)
	assert_eq(offers(), 1, 'Fixture: it was offered.')
	assert_eq(furthest_offered(KNOT_TILE), half, 'The picker reaches exactly half speed, no further.')
	assert_eq(knot.state.tile, destination, 'The Knot moved to the chosen tile.')
	assert_eq(knot.core.current.reactions, 0, 'And the reaction is spent.')

func test_declining_costs_nothing():
	raise_plateau()
	var shooter:Unit = Fixture.create_hostile(game, SHOOTER_TILE)
	arm(false)
	await miss_from(shooter)
	assert_eq(offers(), 1, 'Fixture: it was offered.')
	assert_eq(knot.state.tile, KNOT_TILE, 'A declined offer moves nothing.')
	assert_eq(knot.core.current.reactions, 1, 'And keeps the reaction.')
