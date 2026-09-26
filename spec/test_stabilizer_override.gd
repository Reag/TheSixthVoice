# STABILIZER OVERRIDE (a Mask of Many Faces mode, design 2.3, ruling 17):
#
#   "1/round, when you hit a character with a tech attack, they must make a Systems save or be knocked
#    Prone."
#
# Drain's watcher shape plus a 1/round hard limit on its own usage group. Any own ActionAttackTech hit
# on a HOSTILE character (is_actor()) not already Prone and not immune to it; the round is spent before
# the save. A Systems save against [PRONE] forced with the full trifecta, so Worm Code sees the failure;
# Prone MANUAL.
#
# Dice: the attack d20, then the save d20. Fixture.queue's tail of 3s FAILS every save here, so a save
# that should never have been forced shows up as a Prone target rather than passing quietly.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_stabilizer_override.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(3, 4)
const HOSTILE_TILE := Vector2i(7, 4)
const HIT := 18
const MISS := 3
const SAVE_FAILS := 1
const SAVE_PASSES := 20
## What Shrike Code leaves on whatever it hits: the proof an auto-hit on an ally happened.
const SHRIKE_BUFF := &'buff_shrike_code'

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
	Fixture.equip(rakshasa, Fixture.MARKERLIGHT)
	Fixture.equip(rakshasa, Fixture.MELEE)
	Fixture.equip(rakshasa, Fixture.SHRIKE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	# Worm Code would otherwise ask on every failed save; its heat is not under test except where named.
	responder.chosen_yesnos = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func prone(unit:Unit) -> bool: return unit.has_status(Lancer.STATUS.PRONE)
func uses() -> int: return Fixture.uses(rakshasa, Fixture.CORE_ID, Fixture.STABILIZER_USAGE)

func _action() -> Action:
	var gear:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	return gear.get_action(Fixture.STABILIZER_ACTION) if GearCore.is_valid(gear) else null

# ---------------------------------------------------------------- shape

func test_stabilizer_override_is_a_quiet_one_per_round_tech_hit_watcher():
	var action = _action()
	assert_not_null(action, 'The core system carries Stabilizer Override.')
	if action == null: return
	var gear:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	assert_true(action is ActionReactionAttacked, 'An attack watcher.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, 'At POST.')
	assert_false(action.consumes_reaction(), 'No reaction point.')
	assert_eq(action.get_per_round_hard_limit(SpecificAction.create(rakshasa, gear, action)), 1, '1/round.')
	assert_eq(action.usage_group, Fixture.STABILIZER_USAGE, 'On its own usage group.')

# ---------------------------------------------------------------- the effect

func test_a_tech_hit_forces_a_save_and_a_failure_knocks_prone():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_FAILS])
	assert_true(prone(hostile), 'Knocked Prone.')
	assert_eq(uses(), 1, 'The round is spent.')

func test_prone_lasts_until_it_is_cleared():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_FAILS])
	assert_true(prone(hostile), 'fixture: knocked Prone.')
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.end_turn(game, hostile)
	assert_true(prone(hostile), 'MANUAL: a turn of the target\'s does not clear it.')

func test_a_passed_save_is_not_knocked_prone_and_still_spends_the_round():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_PASSES])
	assert_false(prone(hostile), 'Saved.')
	assert_eq(uses(), 1, 'The hit spent the round.')

func test_any_tech_attack_counts_not_only_an_invade():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.attack_with(game, rakshasa, Fixture.MARKERLIGHT, Fixture.MARKERLIGHT_ACTION, hostile, [HIT, SAVE_FAILS])
	assert_true(prone(hostile), 'Markerlight is a tech attack.')

func test_a_second_hit_the_same_round_forces_nothing():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_PASSES])
	assert_false(prone(hostile), 'fixture: the first save passed.')
	# Invades have no turn limit (action_attack_tech.gd:14); the tail's 3s would fail a second save.
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the second invade rolled.')
	assert_false(prone(hostile), '1/round.')
	assert_eq(uses(), 1, 'Still one.')

func test_the_next_round_it_works_again():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_PASSES])
	# The Mask forbids the same mode two turns running, so the round after next is the next chance.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_FAILS])
	assert_true(prone(hostile), 'A fresh round.')

func test_a_miss_forces_nothing():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [MISS])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade rolled.')
	assert_false(prone(hostile), 'A hit only.')
	assert_eq(uses(), 0, 'The round is untouched.')

func test_a_weapon_hit_forces_nothing():
	var adjacent := Fixture.create_hostile(game, Vector2i(4, 4))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.open_turn(game, rakshasa)
	Fixture.queue([HIT])
	await SpecFactory.use_solo(game, rakshasa, Fixture.MELEE, adjacent)
	assert_gt(adjacent.current_damage(), 0, 'fixture: the swing landed.')
	assert_false(prone(adjacent), 'A tech attack only.')
	assert_eq(uses(), 0, 'The round is untouched.')

func test_an_ally_hit_forces_nothing():
	# SHRIKE CODE, NOT FRAGMENT SIGNAL: the basic invade against an ally aborts before any attack
	# (found by mutation - with the hostile gate deleted this test stayed green), so it proved nothing.
	# Shrike Code auto-hits the ally and leaves its buff, which is the proof the hit happened.
	var ally := Fixture.create_ally(game, Vector2i(5, 6))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	responder.chosen_yesnos = true # the friendly-fire confirm; this file declines yes/nos by default
	await Fixture.attack_with(game, rakshasa, Fixture.SHRIKE, Fixture.SHRIKE_ACTION, ally, [HIT])
	assert_true(UnitCondition.has_buff(ally, SHRIKE_BUFF), 'fixture: the invade hit the ally.')
	assert_false(prone(ally), 'A hostile character only.')
	assert_eq(uses(), 0, 'The round is untouched.')

func test_a_hostile_drone_forces_nothing():
	var drone := Fixture.create_hostile_drone(game, Vector2i(7, 7))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, drone, [HIT])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade rolled.')
	assert_false(prone(drone), 'A drone is not a character.')
	assert_eq(uses(), 0, 'The round is untouched.')

func test_an_already_prone_target_keeps_the_round():
	SpecFactory.apply(hostile, Lancer.STATUS.PRONE)
	var second := Fixture.create_hostile(game, Vector2i(7, 7))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade rolled.')
	assert_eq(uses(), 0, 'Nothing to knock down: the round is kept.')
	await Fixture.invade(game, rakshasa, second, [HIT, SAVE_FAILS])
	assert_true(prone(second), 'And spent on a target it matters to.')

## Close review: a target that cannot be knocked Prone at all is excluded the way an already-Prone one
## is - the round is not spent on a save that cannot matter. The vehicle is a plain STATUS_IMMUNITY to
## Prone built in code: Flash Anchor's and the Fomorian Frame's shape. NOT the Heavy Frame's buff, which
## applies only against a SMALLER knocker (buff_heavy_frame_immunity.gd:27), so a size-1 Rakshasa on a
## size-1 dummy is not blocked by it - measured, the fixture guard below went red with it.
func test_a_target_immune_to_prone_keeps_the_round():
	var immunity := BuffStatusImmunity.new()
	immunity.to = Buff.TO.STATUS_IMMUNITY
	immunity.immune_to_statuses.assign([Lancer.STATUS.PRONE])
	immunity.hide_from_player = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), hostile, immunity)
	var second := Fixture.create_hostile(game, Vector2i(7, 7))
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	var core:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	assert_true(UnitCondition.is_immune_to_status(hostile, Lancer.STATUS.PRONE, core.persistent_id),
		'fixture: immune to Prone from the Rakshasa\'s core system.')
	assert_false(UnitCondition.is_immune_to_status(second, Lancer.STATUS.PRONE, core.persistent_id),
		'fixture: the second target is not.')
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_true(Fixture.d20_was_rolled(), 'fixture: the invade rolled.')
	assert_eq(uses(), 0, 'Nothing it can knock down: the round is kept.')
	await Fixture.invade(game, rakshasa, second, [HIT, SAVE_FAILS])
	assert_true(prone(second), 'And spent on a target it matters to.')

func test_without_the_chip_nothing_happens():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_false(prone(hostile), 'Only in Stabilizer Override.')
	assert_eq(uses(), 0, 'The round is untouched.')

func test_worm_code_fires_on_the_failure():
	# Ruling 6: every save the Rakshasa forces counts, its own core system's included.
	responder.chosen_yesnos = true
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	var before := Fixture.heat(hostile)
	await Fixture.invade(game, rakshasa, hostile, [HIT, SAVE_FAILS])
	assert_true(prone(hostile), 'fixture: knocked Prone.')
	assert_eq(responder.yesno_prompts.size(), 1, 'Worm Code asked.')
	assert_eq(Fixture.heat(hostile) - before, 4, 'The invade\'s 2 and Worm Code\'s 2.')
	assert_eq(Fixture.worm_code_uses(rakshasa), 1, 'Worm Code\'s round is spent.')
