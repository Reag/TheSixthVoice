# UNFATHOMABLE WEIGHT (Shackleton, SP2): "You create a shockwave in a Burst 1 area around you. Hostile
# characters are knocked back 2 spaces. If this would knock them into a wall, mech, or other
# obstruction that would stop them from moving, you may force the target to succeed on a Hull save or
# be knocked Prone." Design specs/2026-09-24-shackleton-design.md rulings 8-10.
#
# GEOMETRY. The Shackleton is size 2 at (5,5), so it covers (5..6, 5..6) and its Burst 1 is the 4x4
# x 4..7, y 4..7. TARGET_TILE (7,5) is inside it; (8,5) is not.
#
# WHERE THE PUSH GOES is steered with the fixture's move-tile queue, and it is checked twice: the
# target's landing tile, and the REACH of the pool the player was offered (a must-move-max straight
# push of N offers only tiles N away - test_mobilized_hydraulics.gd's measurement).
#
# THE PROMPTS are counted by title: CommonActionUtil.confirm_use titles its yes/no with the action's
# name, and the collision reaction's localization_key_override makes its name "Unfathomable Weight"
# too. So the first yes/no is the shockwave's confirm and any further one is a collision's offer.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_unfathomable_weight.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const SHACKLETON_TILE := Vector2i(5, 5)
const TARGET_TILE := Vector2i(7, 5)
## Two spaces east of TARGET_TILE: a straight push of 2.
const PUSHED_TILE := Vector2i(9, 5)
## One step east of TARGET_TILE, with a blocker on the step after it.
const SHORT_TILE := Vector2i(8, 5)
const BLOCKER_TILE := Vector2i(9, 5)
const FAIL := 1
const PASS := 20

var game:Gamemaster
var responder
var watcher
var shackleton:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	shackleton = Fixture.create_shackleton(game, SHACKLETON_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.move_tile_queue.clear()
	responder.yesno_queue.clear()

func weight_prompts(from:int = 0) -> int:
	var n := 0
	var name:String = X.tr('gear.cp_force_distribution_programs.action_unfathomable_weight.name')
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind == PromptWatcher.KIND.yesno and String(seen.info.title).contains(name): n += 1
	return n

## Press Unfathomable Weight. `answers` is the yes/no queue: [confirm, collision offers...].
func press(answers:Array[bool] = [true], moves:Array[Vector2i] = []) -> int:
	await Fixture.open_turn(game, shackleton)
	responder.yesno_queue.assign(answers)
	responder.move_tile_queue.assign(moves)
	var before:int = watcher.prompts.size()
	await SpecFactory.use(game, shackleton, Fixture.CORE_ID, Fixture.WEIGHT_ID)
	return before

func make_flying(unit:Unit) -> void:
	await game.execute_event(&'event_unit_apply_status',
		{unit = unit, category = Lancer.STATUS.FLYING, flags = [Lancer.UNTIL.MANUAL]})

# ---------------------------------------------------------------- the push

func test_a_hostile_in_the_burst_is_pushed_two() -> void:
	var target := Fixture.create_dummy(game, TARGET_TILE)
	var from := await press([true], [PUSHED_TILE])
	var pools := Fixture.offered_pools(watcher, from)
	assert_eq(pools.size(), 1, 'one push offered.')
	if pools.size() == 1: assert_eq(Fixture.reach_of(pools[0], TARGET_TILE), 2, 'Knockback 2.')
	assert_eq(target.tile(), PUSHED_TILE, 'the hostile was pushed two spaces.')

func test_the_push_can_go_toward_the_shackleton_with_spatial_rerouting() -> void:
	# The core calls the QUALIFIED helper, so the trait's extension reaches it.
	# (7,7) is the Shackleton's south-east corner neighbour; west along row 7 runs under its footprint
	# toward (5,7), which vanilla's cone (angled away, south-east) never offers.
	var target := Fixture.create_dummy(game, Vector2i(7, 7))
	var from := await press([true], [Vector2i(5, 7)])
	var pools := Fixture.offered_pools(watcher, from)
	assert_eq(pools.size(), 1)
	if pools.size() == 1: assert_true(pools[0].has(Vector2i(5, 7)), 'back past the Shackleton is offered.')
	assert_eq(target.tile(), Vector2i(5, 7), 'and taken.')

func test_an_ally_in_the_burst_is_untouched() -> void:
	var ally := Fixture.create_dummy(game, TARGET_TILE, -10, Faction.PLAYER)
	var from := await press()
	assert_eq(Fixture.offered_pools(watcher, from).size(), 0, 'no push offered for an ally.')
	assert_eq(ally.tile(), TARGET_TILE, '"Hostile characters" only.')

func test_a_hostile_outside_the_burst_is_untouched() -> void:
	var far := Fixture.create_dummy(game, Vector2i(8, 5))
	await press()
	assert_eq(far.tile(), Vector2i(8, 5), 'Burst 1 from the footprint stops at x = 7.')

## A FLIER IS NOT EXEMPTED - IT IS OUT OF THE AREA. SP2 ruling, 2026-09-24, departing from the design's
## test list ("a flying hostile pushed"): the engine's BURST is three-dimensional. UnitTile.get_aoe_tiles
## drops every tile whose occupant the origin cannot touch elevationwise within the burst's value
## (unit_tile.gd:368-372 -> can_unit_touch_tile_elevationwise, which reads the TARGET UNIT's floor and
## height at :281-284), and a Flying unit hovers above a Burst 1's reach. Every vanilla burst measures
## the same way, so the card's "Burst 1 area" is the engine's. The code carries no flying clause either
## way; this pins what the geometry does, and the tile test is the discriminator - the flier is
## untouched BECAUSE its tile is not in the area, not because anything skipped it.
func test_a_flier_above_the_bursts_reach_is_not_in_the_area() -> void:
	var flier := Fixture.create_dummy(game, TARGET_TILE)
	await make_flying(flier)
	assert_true(flier.has_status(Lancer.STATUS.FLYING), 'precondition: it flies.')
	var tiles := UnitTile.get_aoe_tiles(shackleton, Lancer.AOE_TYPE.BURST, 1)
	assert_false(tiles.has(TARGET_TILE), "the engine's Burst 1 does not reach it.")
	var from := await press([true], [PUSHED_TILE])
	assert_eq(Fixture.offered_pools(watcher, from).size(), 0, 'so no push is offered.')
	assert_eq(flier.tile(), TARGET_TILE)

func test_a_knockback_immune_hostile_is_untouched() -> void:
	var target := Fixture.create_dummy(game, TARGET_TILE)
	SpecFactory.apply_buff(target, &'buff_fortress_knockback')
	var from := await press([true], [PUSHED_TILE])
	assert_eq(Fixture.offered_pools(watcher, from).size(), 0, 'no push offered.')
	assert_eq(target.tile(), TARGET_TILE, 'immune.')

func test_declining_the_confirm_spends_nothing_and_moves_nobody() -> void:
	var target := Fixture.create_dummy(game, TARGET_TILE)
	var from := await press([false], [PUSHED_TILE])
	assert_eq(weight_prompts(from), 1, 'the confirm was raised.')
	assert_eq(target.tile(), TARGET_TILE, 'nothing happened.')
	assert_eq(shackleton.state.actions, 2, 'no action spent.')

func test_it_costs_a_quick_action_and_no_core_power() -> void:
	Fixture.create_dummy(game, TARGET_TILE)
	await press([true], [PUSHED_TILE])
	assert_eq(shackleton.state.actions, 1, 'one Quick action spent.')
	assert_true(shackleton.core.has_core_power, 'the passive half costs no core point.')

# ---------------------------------------------------------------- the collision

func collide(answers:Array[bool], roll:int) -> Dictionary:
	var target := Fixture.create_dummy(game, TARGET_TILE)
	var blocker := Fixture.create_dummy(game, BLOCKER_TILE)
	Dice.CHEAT_ROLL_QUEUE.assign([roll])
	var from := await press(answers, [SHORT_TILE])
	return {target = target, blocker = blocker, offers = weight_prompts(from) - 1}

func test_a_collision_offers_the_save_and_a_failure_is_prone() -> void:
	var run := await collide([true, true], FAIL)
	assert_eq(run.target.tile(), SHORT_TILE, 'stopped short against the blocker.')
	assert_eq(run.offers, 1, 'the collision offered the save.')
	assert_true(run.target.has_status(Lancer.STATUS.PRONE), 'a failed Hull save is Prone.')
	assert_false(run.blocker.has_status(Lancer.STATUS.PRONE), 'the unit it hit is not.')

func test_a_passed_save_is_not_prone() -> void:
	var run := await collide([true, true], PASS)
	assert_eq(run.offers, 1)
	assert_false(run.target.has_status(Lancer.STATUS.PRONE), 'passed.')

func test_declining_the_offer_forces_no_save() -> void:
	var run := await collide([true, false], FAIL)
	assert_eq(run.offers, 1)
	assert_false(run.target.has_status(Lancer.STATUS.PRONE), '"you may" - declined.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 1, 'and no save was rolled.')

func test_no_collision_no_offer() -> void:
	var target := Fixture.create_dummy(game, TARGET_TILE)
	Dice.CHEAT_ROLL_QUEUE.assign([FAIL])
	var from := await press([true, true], [PUSHED_TILE])
	assert_eq(target.tile(), PUSHED_TILE)
	assert_eq(weight_prompts(from), 1, 'only the confirm.')
	assert_false(target.has_status(Lancer.STATUS.PRONE))

func test_the_map_edge_is_not_a_collision() -> void:
	# Ruling 10's recorded divergence. Size 2 at (3,1) covers (3..4, 1..2); (5,1) is in its burst.
	# Pushed north-east it reaches (6,0) and the next step is off the board: the walk ends silently.
	UnitTile.move_to(shackleton, Vector2i(3, 1))
	UnitTile.update_tracking_and_statuses(game.map)
	var target := Fixture.create_dummy(game, Vector2i(5, 1))
	Dice.CHEAT_ROLL_QUEUE.assign([FAIL])
	var from := await press([true, true], [Vector2i(6, 0)])
	assert_eq(target.tile(), Vector2i(6, 0), 'the push ran out of board.')
	assert_eq(weight_prompts(from), 1, 'and no collision was offered.')
	assert_false(target.has_status(Lancer.STATUS.PRONE))
