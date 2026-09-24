# CALAMITOUS IMPACT (Shackleton, SP2): "You leap up into the air and crash down upon a free space within
# sensors. All characters within a Burst 2 area are knocked back 3 spaces and must immediately make a
# Hull save. On a failure they take 2d6+2 Kinetic damage and are knocked Prone. The Burst 2 area
# becomes Difficult Terrain for the rest of the scene." Design specs/2026-09-24-shackleton-design.md
# rulings 11-15.
#
# GEOMETRY. The Shackleton (size 2, Sensors 8) starts at (2,5), covering (2..3, 5..6), and leaps to
# LANDING (10,5), covering (10..11, 5..6) - seven spaces, inside Sensors. Its Burst 2 from there is the
# 6x6 x 8..13, y 3..8. FAR_TILE (8,8) is two out from the landing footprint and NEAR_TILE (12,5) one, so
# farthest-first pushes the far one first and the move-tile queue is [landing, far push, near push].
#
# DICE. CHEAT_ROLL_QUEUE is consumed in order: one Hull save d20 per target in push order, then the
# shared 2d6 (+2). A FrameIsolation'd dummy is armor 0, so damage taken == the roll.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_calamitous_impact.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

const MAP_SIZE := Vector2i(20, 16)
const START_TILE := Vector2i(2, 5)
const LANDING := Vector2i(10, 5)
const FAR_TILE := Vector2i(8, 8)
const FAR_PUSHED := Vector2i(5, 8)   # three west
const NEAR_TILE := Vector2i(12, 5)
const NEAR_PUSHED := Vector2i(15, 5) # three east
const FAIL := 1
const PASS := 20
const D6_A := 3
const D6_B := 4
const DAMAGE := D6_A + D6_B + 2

var game:Gamemaster
var responder
var watcher
var shackleton:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self, MAP_SIZE)
	game = made[0]; responder = made[1]; watcher = made[2]
	shackleton = Fixture.create_shackleton(game, START_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.move_tile_queue.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false

func impact(moves:Array[Vector2i], rolls:Array = [], answers:Array[bool] = []) -> int:
	await Fixture.open_turn(game, shackleton)
	responder.move_tile_queue.assign(moves)
	responder.yesno_queue.assign(answers)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)
	var before:int = watcher.prompts.size()
	await SpecFactory.use(game, shackleton, Fixture.CORE_ID, Fixture.IMPACT_ID)
	return before

func hp(unit:Unit) -> int: return unit.core.current.health

func craters() -> Array:
	return UnitAction.get_deployables_from(shackleton, shackleton.get_gear(Fixture.CORE_ID), Fixture.CRATER_ID)

func named_prompts(key:String, from:int) -> int:
	var n := 0
	var name:String = X.tr(key)
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind == PromptWatcher.KIND.yesno and String(seen.info.title).contains(name): n += 1
	return n

# ---------------------------------------------------------------- the leap

func test_the_leap_lands_on_the_chosen_space_and_spends_the_core() -> void:
	await impact([LANDING])
	assert_eq(shackleton.tile(), LANDING, 'it leapt.')
	assert_false(shackleton.core.has_core_power, 'the core point is spent.')
	assert_eq(shackleton.state.actions, 1, 'and a Quick action.')

func test_the_leap_is_offered_anywhere_free_within_sensors() -> void:
	var from := await impact([LANDING])
	var pools := Fixture.offered_pools(watcher, from)
	assert_true(pools.size() >= 1, 'the leap raised a reticle.')
	if pools.is_empty(): return
	assert_true(pools[0].has(LANDING), 'seven spaces out is offered.')
	assert_false(pools[0].has(Vector2i(13, 5)), 'ten spaces out is beyond Sensors 8.')

func test_cancelling_the_pick_spends_nothing() -> void:
	responder.abort_all = true
	await impact([])
	assert_eq(shackleton.tile(), START_TILE)
	assert_true(shackleton.core.has_core_power, 'nothing spent.')
	assert_eq(shackleton.state.actions, 2)

func test_immobilized_refuses_before_the_spend() -> void:
	await game.execute_event(&'event_unit_apply_status',
		{unit = shackleton, category = Lancer.STATUS.IMMOBILIZED, flags = [Lancer.UNTIL.MANUAL]})
	var near := Fixture.create_dummy(game, NEAR_TILE)
	await impact([LANDING])
	assert_eq(shackleton.tile(), START_TILE, 'a preventable teleport: Immobilized stops it.')
	assert_true(shackleton.core.has_core_power, 'and nothing was spent.')
	assert_eq(shackleton.state.actions, 2)
	assert_eq(near.tile(), NEAR_TILE)

func test_a_vetoed_leap_is_spent_and_does_nothing_else() -> void:
	# Uncertainty Field on the Shackleton itself: an ENTIRE_MOVEMENT PRE veto of its own voluntary
	# teleport (action_uncertainty_field.gd), accepted.
	Fixture.equip(shackleton, &'mt_uncertainty_field')
	var near := Fixture.create_dummy(game, LANDING + Vector2i(-1, 0))
	var from := await impact([LANDING], [FAIL, FAIL, D6_A, D6_B], [true])
	assert_eq(named_prompts('gear.mt_uncertainty_field.name', from), 1, 'fixture: the field offered the veto.')
	assert_eq(shackleton.tile(), START_TILE, 'the leap was vetoed.')
	assert_false(shackleton.core.has_core_power, 'the core point is spent anyway (ruling 11).')
	assert_eq(near.tile(), LANDING + Vector2i(-1, 0), 'no burst.')
	assert_eq(hp(near), 200, 'no damage.')
	assert_eq(craters().size(), 0, 'no crater.')

# ---------------------------------------------------------------- the burst

func test_every_character_but_the_shackleton_is_pushed_three_then_saves() -> void:
	var far := Fixture.create_dummy(game, FAR_TILE, -10, Faction.PLAYER) # an ally
	var near := Fixture.create_dummy(game, NEAR_TILE)
	var from := await impact([LANDING, FAR_PUSHED, NEAR_PUSHED], [FAIL, PASS, D6_A, D6_B])
	var pools := Fixture.offered_pools(watcher, from)
	assert_eq(pools.size(), 3, 'the leap, then one push per character.')
	if pools.size() == 3:
		assert_eq(Fixture.reach_of(pools[1], FAR_TILE), 3, 'Knockback 3.')
		assert_eq(Fixture.reach_of(pools[2], NEAR_TILE), 3, 'Knockback 3.')
	assert_eq(far.tile(), FAR_PUSHED, '"All characters": the ally too.')
	assert_eq(near.tile(), NEAR_PUSHED)
	assert_eq(shackleton.tile(), LANDING, 'the Shackleton itself does not move.')

func test_a_failed_save_takes_the_damage_and_is_prone_a_passed_one_neither() -> void:
	var far := Fixture.create_dummy(game, FAR_TILE)
	var near := Fixture.create_dummy(game, NEAR_TILE)
	await impact([LANDING, FAR_PUSHED, NEAR_PUSHED], [FAIL, PASS, D6_A, D6_B])
	assert_eq(hp(far), 200 - DAMAGE, 'failed: 2d6+2 Kinetic.')
	assert_true(far.has_status(Lancer.STATUS.PRONE), 'failed: Prone.')
	assert_eq(hp(near), 200, 'passed: no damage.')
	assert_false(near.has_status(Lancer.STATUS.PRONE), 'passed: not Prone.')

func test_one_damage_roll_is_shared_by_every_failure() -> void:
	var far := Fixture.create_dummy(game, FAR_TILE)
	var near := Fixture.create_dummy(game, NEAR_TILE)
	# A second 2d6 would draw 6 and 6 and deal 14.
	await impact([LANDING, FAR_PUSHED, NEAR_PUSHED], [FAIL, FAIL, D6_A, D6_B, 6, 6])
	assert_eq(hp(far), 200 - DAMAGE)
	assert_eq(hp(near), 200 - DAMAGE, 'the same roll, not a second one.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 2, 'exactly one 2d6 was drawn.')

func test_a_knockback_immune_character_still_saves() -> void:
	var near := Fixture.create_dummy(game, NEAR_TILE)
	SpecFactory.apply_buff(near, &'buff_fortress_knockback')
	await impact([LANDING], [FAIL, D6_A, D6_B])
	assert_eq(near.tile(), NEAR_TILE, 'immune to the push.')
	assert_true(near.has_status(Lancer.STATUS.PRONE), 'but not to the save.')
	assert_eq(hp(near), 200 - DAMAGE)

func test_a_collision_here_does_not_raise_unfathomable_weights_offer() -> void:
	# Ruling 12: the collision reaction is keyed to Unfathomable Weight's own action.
	var near := Fixture.create_dummy(game, NEAR_TILE)
	Fixture.create_dummy(game, Vector2i(14, 5)) # outside the burst, in the push's way
	var from := await impact([LANDING, Vector2i(13, 5)], [PASS, PASS, PASS], [true, true])
	assert_eq(near.tile(), Vector2i(13, 5), 'fixture: stopped short against the blocker.')
	assert_eq(named_prompts('gear.cp_force_distribution_programs.action_unfathomable_weight.name', from), 0,
		'no Unfathomable Weight offer.')

# ---------------------------------------------------------------- the crater

func test_the_burst_2_area_becomes_difficult_terrain() -> void:
	await impact([LANDING])
	assert_eq(craters().size(), 1, 'one crater laid.')
	for tile:Vector2i in [Vector2i(8, 3), Vector2i(13, 3), Vector2i(8, 8), Vector2i(13, 8), LANDING]:
		assert_true(Terrain.is_difficult(game.map, tile), '%s is in the 6x6.' % tile)
	for tile:Vector2i in [Vector2i(7, 5), Vector2i(14, 5), Vector2i(10, 2), Vector2i(10, 9)]:
		assert_false(Terrain.is_difficult(game.map, tile), '%s is outside it.' % tile)

func test_the_crater_survives_the_shackletons_death() -> void:
	await impact([LANDING])
	var laid:Array = craters()
	assert_eq(laid.size(), 1, 'fixture: the crater is there.')
	if laid.size() != 1: return
	var crater:Unit = laid.front()
	await game.execute_event(&'event_unit_die', {unit = shackleton})
	UnitTile.update_tracking_and_statuses(game.map)
	assert_false(Unit.is_valid(shackleton), 'fixture: the Shackleton really died.')
	assert_true(Unit.is_valid(crater) and crater.is_on_map(), 'the crater is still on the map.')
	assert_true(Terrain.is_difficult(game.map, LANDING), '"for the rest of the scene".')

func test_the_card_carries_the_persists_tag() -> void:
	var gear:GearCore = shackleton.get_gear(Fixture.CORE_ID)
	var action:Action = gear.get_action(Fixture.IMPACT_ID)
	var specific := SpecificAction.create(shackleton, gear, action)
	var keys:Array = action.get_glossary_tags(specific).map(func(item:GlossaryItem) -> String: return item.name)
	assert_has(keys, 'lancer.term.persists')
