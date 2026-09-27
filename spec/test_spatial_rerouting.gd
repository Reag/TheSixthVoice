# SPATIAL REROUTING (Shackleton, SP1): "Knockback the Shackleton inflicts can be in any direction
# other than up." Design specs/2026-09-24-shackleton-design.md rulings 3-4.
#
# The rule is the mod's common_action_util.gd_ext.gd (the seam is proven by
# test_spike_shackleton_sp1_seam.gd). What is asserted here is the OFFER - the move_tile prompt's
# pathfinder.movable_tiles - never where the target lands: ask_for_movement_alt accepts whatever
# tile comes back without checking it against the offer (test_bizarre_cannon.gd's RECOIL_ANY note).
#
# THE GEOMETRY. A size-2 Shackleton at anchor (5,5) occupies (5..6, 5..6). The target stands at
# (7,4), diagonally off its north-east corner, inside the War Pike's reach. TOWARD (6,4) is on the
# Shackleton's side of the target: vanilla's cone is angled AWAY from the knocker's closest tile
# (event_unit_pick_move.gd:91-96) and never offers it; Spatial Rerouting's every-direction pool does.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spatial_rerouting.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')

const SHACKLETON_TILE := Vector2i(5, 5)
const TARGET_TILE := Vector2i(7, 4)
## West of the target, on the Shackleton's side: only an every-direction pool offers it.
const TOWARD := Vector2i(6, 4)
## North of the target, level ground: offered either way the rule reads, the uphill control.
const LEVEL := Vector2i(7, 3)

var game:Gamemaster
var responder
var watcher
var target:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## One pike swing from `attacker` at a dummy on TARGET_TILE; the single pool it was offered.
func pike_pool(attacker:Unit) -> Array:
	target = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(attacker, Fixture.PIKE)
	await Fixture.open_turn(game, attacker)
	# Mobilized Hydraulics would make this Knockback 3, and a must-move-max push of 3 never ENDS one
	# tile away - so its round is spent first and the pike's own Knockback 1 is what is measured.
	Fixture.spend_hydraulics(attacker)
	var before:int = watcher.prompts.size()
	await Fixture.swing(game, attacker, target)
	var pools:Array = Fixture.offered_pools(watcher, before)
	assert_eq(pools.size(), 1, 'one knockback reticle was offered.')
	return pools[0] if pools.size() == 1 else []

func test_the_trait_is_a_kit_the_extension_can_find() -> void:
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	assert_true(GearCore.is_valid(shackleton.get_gear(Fixture.REROUTING_ID)),
		'the Shackleton carries mt_spatial_rerouting by id - the extension asks for exactly that.')

func test_the_shackletons_knockback_is_offered_toward_itself() -> void:
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	var pool:Array = await pike_pool(shackleton)
	assert_has(pool, TOWARD, 'a push back toward the Shackleton is offered.')
	assert_has(pool, LEVEL, 'and a push to the side.')

func test_an_ordinary_knocker_gets_the_vanilla_cone() -> void:
	# THE NEGATIVE CONTROL: the same swing, the same target, from a plain unit standing on the
	# Shackleton's north-east tile. Vanilla angles the cone away from (6,5), so TOWARD is not offered.
	var plain := SpecFactory.create_unit(game.map, Vector2i(6, 5))
	var pool:Array = await pike_pool(plain)
	assert_false(pool.is_empty(), 'the cone offered something.')
	assert_does_not_have(pool, TOWARD, 'but not a push back toward the knocker.')

func test_never_uphill() -> void:
	# "other than up": vanilla's knockback movement type sets cannot_move_uphill
	# (common_action_util.gd:118), and the extension leaves the movement type alone.
	SpecFactory.set_tiles_elevation(game.map, 2, [TOWARD])
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	var pool:Array = await pike_pool(shackleton)
	assert_does_not_have(pool, TOWARD, 'a raised tile is never offered.')
	assert_has(pool, LEVEL, 'while level ground still is.')

func test_the_rule_keys_on_the_knocker_not_the_knocked() -> void:
	# At the helper itself (depth 0, a qualified call through the autoload node): the Shackleton as
	# the TARGET of someone else's knockback keeps its origin tiles; as the knocker it has none.
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	var plain := SpecFactory.create_unit(game.map, Vector2i(8, 5))
	var pike := Fixture.equip(plain, Fixture.PIKE)
	var knocked:Array[EventCore] = CommonActionUtil.generate_knockback_events(
		shackleton, 1, SpecificAction.create(plain, pike, pike.get_solo_action()))
	assert_eq(knocked.size(), 1, 'one pick-move event for the Shackleton as target.')
	if knocked.size() == 1:
		assert_eq(Array(knocked[0].context.array), [Vector2i(8, 5)], 'a plain knocker keeps its origin.')

	var own_pike := Fixture.equip(shackleton, Fixture.PIKE)
	target = Fixture.create_dummy(game, TARGET_TILE)
	var knocking:Array[EventCore] = CommonActionUtil.generate_knockback_events(
		target, 1, SpecificAction.create(shackleton, own_pike, own_pike.get_solo_action()))
	assert_eq(knocking.size(), 1, 'one pick-move event for the Shackleton as knocker.')
	if knocking.size() != 1: return
	var context:Context = knocking[0].context
	assert_true(Array(context.array).is_empty(), 'the Shackleton\'s knockback carries no origin tiles.')
	assert_has(context.flags, EventUnitPickMove.FLAG.KNOCKBACK, 'it is still a knockback.')
	var movement:MovementType = context.resource
	assert_true(movement.straight_line and movement.must_move_max_possible and movement.cannot_move_uphill,
		'and the movement type is vanilla\'s: straight, the full distance, never uphill.')

func automatic_push(shackleton:Unit) -> Array[EventCore]:
	var own_pike := Fixture.equip(shackleton, Fixture.PIKE)
	target = Fixture.create_dummy(game, TARGET_TILE, -10,
		Faction.AI_ENEMY if shackleton.is_player_controlled() else Faction.PLAYER)
	return CommonActionUtil.generate_knockback_events(
		target, 1, SpecificAction.create(shackleton, own_pike, own_pike.get_solo_action()),
		[], [EventUnitPickMove.FLAG.AUTO_FURTHEST])

func test_a_players_automatic_push_is_picked_too() -> void:
	# Pass E ruling, 2026-09-27 (the author, settling the frame-close row's alternative): "Knockback the
	# Shackleton inflicts can be in any direction" covers the pushes vanilla resolves with no picker
	# (Repulser Field, Agni, Siege Specialist, Stormbending). The extension strips AUTO_FURTHEST, makes
	# the push MANDATORY (it was never cancellable) and empties the origin, so the reticle opens over the
	# every-direction pool - one prompt per target, a cost the author accepted.
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	var events:Array[EventCore] = automatic_push(shackleton)
	assert_eq(events.size(), 1, 'one pick-move event.')
	if events.size() != 1: return
	var flags:Array = events[0].context.flags
	assert_does_not_have(flags, EventUnitPickMove.FLAG.AUTO_FURTHEST, 'no longer resolved without a picker.')
	assert_has(flags, EventUnitPickMove.FLAG.MANDATORY, 'and not cancellable, as the automatic push was not.')
	assert_has(flags, EventUnitPickMove.FLAG.KNOCKBACK, 'still a knockback.')
	assert_true(Array(events[0].context.array).is_empty(), 'every direction: no origin tiles.')

func test_an_ai_shackletons_automatic_push_keeps_its_origin() -> void:
	# The AI keeps vanilla's deterministic "away": with the origin emptied an AUTO_FURTHEST push has
	# every tile tie and Tile.get_furthest_pair_between shuffles them (tile.gd:449-453).
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE, Faction.AI_ENEMY)
	var events:Array[EventCore] = automatic_push(shackleton)
	assert_eq(events.size(), 1, 'one pick-move event.')
	if events.size() != 1: return
	assert_has(events[0].context.flags, EventUnitPickMove.FLAG.AUTO_FURTHEST, 'resolved without a picker.')
	assert_false(Array(events[0].context.array).is_empty(), 'away from its origin tiles.')

func test_repulser_field_offers_each_pushed_target_every_direction() -> void:
	# End to end through vanilla's own AUTO_FURTHEST caller (action_repulser_field.gd:25-31). Both
	# dummies stand beside the Shackleton and fail their Hull saves; each gets its own reticle, and
	# each reticle offers the push of 2 back past the Shackleton's side, which vanilla's cone never does.
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	Fixture.equip(shackleton, &'ms_repulser_field')
	Fixture.create_dummy(game, TARGET_TILE)       # (7,4): toward is (5,4)
	Fixture.create_dummy(game, Vector2i(7, 7))    # (7,7): toward is (5,7)
	await Fixture.open_turn(game, shackleton)
	Dice.CHEAT_ROLL_QUEUE.assign([1, 1])
	var before:int = watcher.prompts.size()
	await SpecFactory.use_solo(game, shackleton, &'ms_repulser_field')
	var pools:Array = Fixture.offered_pools(watcher, before)
	assert_eq(pools.size(), 2, 'one reticle per pushed target.')
	assert_true(pools.any(func(pool:Array) -> bool: return pool.has(Vector2i(5, 4))),
		'the north target may be pushed back past the Shackleton.')
	assert_true(pools.any(func(pool:Array) -> bool: return pool.has(Vector2i(5, 7))),
		'and so may the south one.')

func test_an_ai_shackleton_pushes_without_asking() -> void:
	# The deciding party is vanilla's (target_action_util.gd:38-39, :60-66): an AI knocker picks the
	# worst tile for its enemy itself.
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE, Faction.AI_ENEMY)
	target = Fixture.create_dummy(game, TARGET_TILE, -10, Faction.PLAYER)
	Fixture.equip(shackleton, Fixture.PIKE)
	var before:int = watcher.prompts.size()
	await Fixture.swing(game, shackleton, target)
	assert_eq(Fixture.offered_pools(watcher, before).size(), 0, 'no reticle was raised.')
	assert_ne(target.tile(), TARGET_TILE, 'and the target was pushed.')

## THE PROBE, Pass F task 10 (before stripping AUTO_FURTHEST): a MANDATORY every-direction push on a
## target boxed in on every side. With no AUTO_FURTHEST the event never takes its :119 "nothing
## reachable -> abort" branch, so the reticle opens over an empty pathfinder and cannot be cancelled.
## The question was whether that soft-locks. Run with the move-tile queue EMPTY under a 10 s timeout,
## so a hang fails here instead of freezing the run.
const BOX:Array[Vector2i] = [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(6, 4),
	Vector2i(8, 4), Vector2i(7, 5), Vector2i(8, 5)] # (6,5) is the Shackleton's own corner

func test_a_boxed_in_target_of_a_mandatory_every_direction_push_does_not_hang() -> void:
	var shackleton := Fixture.create_shackleton(game, SHACKLETON_TILE)
	var own_pike := Fixture.equip(shackleton, Fixture.PIKE)
	target = Fixture.create_dummy(game, TARGET_TILE)
	# The box is the TARGET's enemies: a mover passes through its allies, so a box of fellow AI dummies
	# left 13 tiles reachable (measured).
	for tile:Vector2i in BOX: Fixture.create_dummy(game, tile, -10, Faction.PLAYER)
	var events:Array[EventCore] = CommonActionUtil.generate_knockback_events(
		target, 2, SpecificAction.create(shackleton, own_pike, own_pike.get_solo_action()),
		[], [EventUnitPickMove.FLAG.MANDATORY])
	assert_eq(events.size(), 1, 'one pick-move event.')
	if events.size() != 1: return
	assert_does_not_have(events[0].context.flags, EventUnitPickMove.FLAG.AUTO_FURTHEST, 'fixture: no AUTO_FURTHEST.')
	assert_true(responder.move_tile_queue.is_empty(), 'fixture: nothing queued.')
	var before:int = watcher.prompts.size()
	var state := {done = false}
	var run := func() -> void:
		await game.execute_event_block(EventBlock.create_multiple(events))
		state.done = true
	run.call()
	var resolved:bool = await wait_until(func() -> bool: return state.done, 10, 'the boxed-in push')
	assert_true(resolved, 'the push resolved - no soft-lock.')
	var moves:Array = watcher.prompts.slice(before).filter(
		func(seen:Dictionary) -> bool: return seen.kind == &'move_tile')
	assert_eq(moves.size(), 1, 'the reticle opened.')
	if moves.size() != 1: return
	var info:Dictionary = moves[0].info
	assert_true(info.pathfinder.reachable_tiles.is_empty(), 'over an empty pathfinder.')
	assert_false(info.can_cancel, 'uncancellable.')
	assert_false(info.tiles.is_empty(), 'but a knockback reticle still carries its aiming tiles.')
	assert_eq(target.tile(), TARGET_TILE, 'boxed in, it collided where it stood.')
