# DRAIN (a Mask of Many Faces mode, design 2.2, ruling 16):
#
#   "Your successful invades always apply Impaired and +1 heat."
#
# A hidden ActionReactionAttacked on ATTACK POST (the Koremasa's tech-hit watcher): the Rakshasa's own
# hit with an ActionAttackTech whose is_invade is true, on a HOSTILE target (the author's call: the
# engine zeroes an invade's own heat against a non-enemy), while the Drain chip is held. Impaired at
# its standard until, and 1 HEAT as a SEPARATE event: 3 in all with the invade's own 2.
#
# Shrike Code (ms_neurospike) is the vehicle: an invade that applies no condition of its own, so
# Drain's Impaired is the only one. Markerlight is the tech attack that is NOT an invade.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_drain.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(3, 4)
const HOSTILE_TILE := Vector2i(7, 4)
const HIT := 18
const MISS := 3

var game:Gamemaster
var responder
var rakshasa:Unit
var hostile:Unit

func before_each() -> void:
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self)
	game = built[0]
	responder = built[1]
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	# Equip BEFORE anything is spent: equip_system full_repairs every gear (fixture header).
	Fixture.equip(rakshasa, Fixture.SHRIKE)
	Fixture.equip(rakshasa, Fixture.MARKERLIGHT)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func shrike(target:Unit, d20s:Array[int]) -> void:
	await Fixture.attack_with(game, rakshasa, Fixture.SHRIKE, Fixture.SHRIKE_ACTION, target, d20s)

func _action() -> Action:
	var gear:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	return gear.get_action(Fixture.DRAIN_ACTION) if GearCore.is_valid(gear) else null

# ---------------------------------------------------------------- shape

func test_drain_is_a_quiet_tech_hit_watcher_on_the_core_system():
	var action = _action()
	assert_not_null(action, 'The core system carries Drain.')
	if action == null: return
	assert_true(action is ActionReactionAttacked, 'An attack watcher.')
	assert_eq(action.triggers_on, [&'attack'] as Array[StringName], 'On the per-target attack.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, 'At POST, where the roll exists.')
	assert_false(action.consumes_reaction(), 'No reaction point.')
	assert_false(action.allow_weapon, 'Not weapons.')
	assert_true(action.allow_tech and action.allow_basic, 'Tech, basic gear included.')
	assert_ne(action.usage_group, &'', 'On its own usage group.')

# ---------------------------------------------------------------- the effect

func test_a_successful_invade_under_drain_impairs_and_deals_one_more_heat():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var before := Fixture.heat(hostile)
	await shrike(hostile, [HIT])
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Impaired.')
	assert_eq(Fixture.heat(hostile) - before, 3, 'The invade\'s 2, and Drain\'s 1.')

func test_without_drain_the_same_invade_does_neither():
	# The control half: Shrike Code alone impairs nobody and deals its 2.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	var before := Fixture.heat(hostile)
	await shrike(hostile, [HIT])
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Not impaired.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'Only the invade\'s own 2.')

func test_the_basic_invade_counts_too():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var before := Fixture.heat(hostile)
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_eq(Fixture.heat(hostile) - before, 3, 'Fragment Signal is an invade: 2 and 1.')

func test_a_missed_invade_does_nothing():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var before := Fixture.heat(hostile)
	await shrike(hostile, [MISS])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the attack rolled.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Not impaired.')
	assert_eq(Fixture.heat(hostile), before, '"Successful" invades only.')

func test_a_tech_attack_that_is_not_an_invade_does_nothing_more():
	# Markerlight is an ActionAttackTech with is_invade = false. Its own heat, if any, is measured
	# without Drain on one turn and compared with Drain on the next.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	var before := Fixture.heat(hostile)
	await Fixture.attack_with(game, rakshasa, Fixture.MARKERLIGHT, Fixture.MARKERLIGHT_ACTION, hostile, [HIT])
	var without:int = Fixture.heat(hostile) - before
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'fixture: Markerlight does not impair.')

	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	before = Fixture.heat(hostile)
	await Fixture.attack_with(game, rakshasa, Fixture.MARKERLIGHT, Fixture.MARKERLIGHT_ACTION, hostile, [HIT])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the second attack rolled.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Not an invade: not impaired.')
	assert_eq(Fixture.heat(hostile) - before, without, 'Not an invade: no extra heat.')

func test_an_invaded_ally_takes_nothing_from_drain():
	# Ruling 16: hostile targets only. An invade auto-hits an ally and the engine zeroes its heat.
	var ally := Fixture.create_ally(game, Vector2i(5, 6))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var before := Fixture.heat(ally)
	await shrike(ally, [HIT])
	assert_true(UnitCondition.has_buff(ally, &'buff_shrike_code'), 'fixture: the invade hit the ally.')
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'Not impaired.')
	assert_eq(Fixture.heat(ally), before, 'No heat.')

func test_a_silver_tongue_reroll_that_hits_is_drained():
	# Ruling 16: the reroll is a new attack by the Rakshasa (ruling 11).
	var second := Fixture.create_hostile(game, Vector2i(7, 7))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	responder.unit_queue.append(second)
	var before := Fixture.heat(second)
	await shrike(hostile, [MISS, HIT])
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: Silver Tongue offered the reroll.')
	assert_true(second.has_status(Lancer.STATUS.IMPAIRED), 'The new target is impaired.')
	assert_eq(Fixture.heat(second) - before, 3, 'And takes 2 and 1.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'The missed target is not.')

func test_another_units_invade_is_not_drained():
	# Drain is the Rakshasa's own: an ally's invade on the same hostile does nothing more.
	var ally := Fixture.create_ally(game, Vector2i(5, 6))
	Fixture.equip(ally, Fixture.SHRIKE)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await Fixture.open_turn(game, ally)
	Fixture.queue([HIT])
	var before := Fixture.heat(hostile)
	await SpecFactory.use(game, ally, Fixture.SHRIKE, Fixture.SHRIKE_ACTION, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Not impaired.')
	assert_eq(Fixture.heat(hostile) - before, 2, 'Only the invade\'s own 2.')
