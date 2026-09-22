# SWIFT - RAGE's face 2 (SP1 Task 8).
#
#   "2 Swift: You may immediately Boost as a free action and your Evasion increases by 2."
#
# AUTOMATIC, NOT OFFERED (ruling 10). "You may" is read as the engine reads every other free Boost:
# the reaction queues the activation with SKIP_PLAYER_DECISIONS so no yes/no interrupts the turn-start
# roll, and a Leoleth that cannot Boost simply does not. The alternative - a prompt - would put a
# question in front of the player six times a scene for an effect with no downside.
#
# TWO FLAGS DO ALL THE WORK, and neither says so on its own. AS_FREEBIE puts the whole
# action/boost/reaction spend inside `if not as_freebie` (unit_action.gd:242-265), which is where
# has_normal_boost = false lives (:264-265) - so the player keeps their own Boost.
# SKIP_PLAYER_DECISIONS is what makes CommonActionUtil.confirm_use return true without asking
# (:330), which action_boost.activate calls first (action_boost.gd:19-20).
#
# THE EVASION IS READ BEFORE ANY FURTHER UNIT IS CREATED. stat_bonus is rebuilt only by
# update_cached_values, and creating a unit on the map rebuilds every unit's cache - the Sluagh's
# Task 5 measured a missing refresh being hidden by exactly that. Every unit this file needs exists
# before the roll.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_swift.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)

const BASE_EVASION := 10
const EVASION_BONUS := 2

var game:Gamemaster
var leoleth:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- the wiring

func test_the_swift_chip_is_wired_as_ruling_10_says():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.SWIFT_CHIP)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.SWIFT_CHIP)
	if buff == null: return
	assert_eq(buff.to, Buff.TO.STATBLOCK,
		'to = statblock: UnitBattleState.update_cached_values walks that channel and folds each '
		+ 'buff\'s get_values().object into stat_bonus (unit_battle_state.gd:230-234).')
	assert_eq(buff.until, Lancer.UNTIL.START_OF_TURN, 'Until the start of the next turn.')
	assert_false(buff.hide_from_player, 'VISIBLE: one of the six face chips.')
	# THE BLOCK ITSELF, and only evasion in it. add_stats_from_block folds EVERY field, so a stray
	# speed or armor would be a second, silent grant.
	var block = buff.get_values(BuffCore.create(buff), Context.create({}))
	assert_not_null(block, 'get_values returns something.')
	if block == null: return
	assert_true(block.object is Statblock, 'And it is a Statblock in `object`.')
	if not (block.object is Statblock): return
	assert_eq(block.object.evasion, EVASION_BONUS, 'evasion +2.')
	for field:String in ['size', 'structure', 'stress', 'health', 'armor', 'edef', 'speed', 'heat',
			'save_target', 'sensor_range', 'tech_attack', 'repairs', 'systems_points', 'reactions',
			'activations']:
		assert_eq(block.object.get(field), 0, 'And %s is untouched.' % field)

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.buff_rage_swift.name', 'gear.buff_rage_swift.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.buff_rage_swift.name'), 'Swift', 'Named off the table.')
	assert_eq(X.tr('gear.buff_rage_swift.effect'),
		'You may immediately |Boost| as a |free action| and your |Evasion| increases by 2.',
		'And its effect row is that face\'s line, verbatim.')

# ---------------------------------------------------------------- the evasion

func test_the_chip_reads_plus_two_on_get_evasion():
	# THROUGH THE ACCESSOR, not off the buff: Unit.get_evasion is core.get_evasion() plus
	# state.stat_bonus.evasion, and stat_bonus is the thing the buff actually moves. Read FIRST,
	# before anything else in this test could refresh a cache.
	#
	# WHAT REFRESHES THAT CACHE IS THE ENGINE, NOT THE BUFF, and that was measured here: neutralising
	# buff_rage_swift.on_application reddens nothing, because UnitCondition.apply_buffs ends in
	# post_apply_buff_cache_update (unit_condition.gd:715 -> :770-777), which runs after
	# Buff.on_application (:758). The buff's own line is belt-and-braces for any future path that does
	# not go through apply_buffs; this test pins the OUTCOME, not which of the two did it.
	assert_eq(leoleth.get_evasion(), BASE_EVASION, 'fixture: the sheet evasion.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_eq(leoleth.get_evasion(), BASE_EVASION + EVASION_BONUS,
		'The chip raises evasion by 2, and get_evasion reads it without any further prompting.')

func test_the_chip_is_gone_at_the_next_turn_start():
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.SWIFT_CHIP), 'fixture: the chip is held.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.SWIFT_CHIP), 'And gone the next turn.')
	assert_eq(leoleth.get_evasion(), BASE_EVASION, 'With the evasion back to the sheet\'s.')

# ---------------------------------------------------------------- the Boost

func test_a_two_boosts_immediately():
	# get_boost_speed is get_speed_max plus any BOOST_DISTANCE buffs (unit_action.gd:474-478), so on
	# this frame it is 4 - and event_unit_boost ADDS it to current.speed (:37). A turn start has
	# already refreshed the pool to 4, so 8 is the whole claim.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() * 2,
		'The pool is doubled: the turn start set it to 4 and the free Boost added another 4.')

func test_the_free_boost_costs_no_action_and_leaves_the_players_own_boost_intact():
	# AS_FREEBIE puts the entire spend block behind `if not as_freebie` (unit_action.gd:242-265), and
	# has_normal_boost = false is INSIDE it at :264-265. So the player can still Boost for themselves
	# this turn, which is what "as a free action" means.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_true(leoleth.state.has_normal_boost,
		'The player still has their own Boost - the freebie did not consume it.')
	assert_eq(leoleth.state.actions, Lancer.ACTION_COST_FULL,
		'And a full turn\'s actions: new_turn_refresh set them and nothing spent any.')

func test_a_slowed_leoleth_simply_does_not_boost_and_still_gets_the_chip():
	# RULING 10, recorded: is_available_to_activate on ms_boost is UnitAction.can_boost
	# (action_boost.gd:15-16), which is_boost_prohibited refuses for a Slowed unit - and
	# UnitAction.can_activate_gear asks is_gear_available BEFORE the freebie short-circuit
	# (unit_action.gd:112 then :114), so AS_FREEBIE does not get around it. The Boost does not happen;
	# the evasion does.
	SpecFactory.apply(leoleth, Lancer.STATUS.SLOWED)
	assert_true(leoleth.has_status(Lancer.STATUS.SLOWED), 'fixture: Slowed.')
	assert_false(UnitAction.can_boost(leoleth), 'fixture: and therefore unable to Boost.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.SWIFT_CHIP), 'The chip landed anyway.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(),
		'But the pool is only the turn start\'s - no Boost was added.')

func test_a_hidden_leoleth_loses_hidden_to_the_free_boost():
	# THE RECORDED EDGE (ruling 10). event_unit_boost queues event_unit_lose_hidden after its own POST
	# reactions, unconditionally (:42-45) - it does not care that the Boost was free. A Hidden Leoleth
	# that rolls a 2 is revealed, and there is nothing in the card to stop it.
	SpecFactory.apply(leoleth, Lancer.STATUS.HIDDEN)
	assert_true(leoleth.has_status(Lancer.STATUS.HIDDEN), 'fixture: Hidden.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_SWIFT)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() * 2, 'LIVENESS: it did Boost.')
	assert_false(leoleth.has_status(Lancer.STATUS.HIDDEN), 'And lost Hidden doing it.')

func test_another_face_boosts_nothing():
	# THE CONTROL. Without it, "a 2 doubles the pool" says nothing about face 2 - a turn start alone
	# could have done it.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.SWIFT_CHIP), 'No Swift chip on a 3.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'And no Boost.')
	assert_eq(leoleth.get_evasion(), BASE_EVASION, 'And the sheet evasion.')
