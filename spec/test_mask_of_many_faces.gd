# MASK OF MANY FACES (Rakshasa core passive, design 2.1 and 2.5, rulings 12-15):
#
#   "At the start of each of your turns choose one of the following effects. These effects last until
#    the start of your next turn and you cannot choose the same option two turns in a row"
#
# A hidden, point-free ActionReactionSelf on new_turn POST (the Leoleth's Rage roll timing: after
# new_turn_for_statuses has cleared last turn's chip). A player-controlled Rakshasa gets a mandatory
# five-button brochure, last turn's option disabled - and re-checked after the pick, because a disabled
# button still resolves. Soulbind is also disabled when no other character is within Sensors. An
# AI-controlled one takes the next option in card order (ruling 14). The choice is remembered in the
# core gear's state, which repair clears: the first turn of a scene may choose anything (ruling 13).
#
# The menu's answers go through the mod responder's multiple_choice_queue; its button index IS the
# mode (Fixture.MODE, card order).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mask_of_many_faces.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(1, 2)
const HOSTILE_TILE := Vector2i(5, 2)
## 24 tiles from the Rakshasa: outside its Sensors 20 on Fixture.WIDE_MAP_SIZE.
const FAR_TILE := Vector2i(25, 2)

var game:Gamemaster
var responder
var rakshasa:Unit

func before_each() -> void:
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self, Fixture.WIDE_MAP_SIZE)
	game = built[0]
	responder = built[1]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The default arrangement: a player Rakshasa with one hostile inside its Sensors.
func with_a_hostile_in_sensors(faction:Faction.SIDE = Faction.PLAYER) -> void:
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, faction)
	Fixture.create_hostile(game, HOSTILE_TILE)

func last_prompt() -> Dictionary:
	return responder.multiple_choice_prompts.back() if not responder.multiple_choice_prompts.is_empty() else {}

func _action() -> Action:
	var gear:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	return gear.get_action(Fixture.MASK_ACTION) if GearCore.is_valid(gear) else null

# ---------------------------------------------------------------- shape

func test_the_core_system_carries_a_quiet_turn_start_reaction():
	with_a_hostile_in_sensors()
	var action = _action()
	assert_not_null(action, 'The core system carries the Mask.')
	if action == null: return
	assert_true(action is ActionReactionSelf, 'A reaction to the Rakshasa itself.')
	assert_eq(action.triggers_on, [&'new_turn'] as Array[StringName], 'At turn start.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, 'At POST, after last turn\'s chip is cleared.')
	assert_false(action.consumes_reaction(), 'It spends no reaction point.')
	assert_eq(action.usage_group, Fixture.MASK_USAGE, 'On its own usage group.')

# ---------------------------------------------------------------- the menu

func test_the_turn_start_offers_the_five_modes_in_card_order():
	with_a_hostile_in_sensors()
	await Fixture.cycle_turn(game, rakshasa)
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'One menu at the turn start.')
	var prompt := last_prompt()
	if prompt.is_empty(): return
	assert_eq(Array(prompt.labels), Array(Fixture.MODE_NAMES),'Drain, Entrap, Stabilizer Override, Soulbind, Ensorcel.')
	for reason:String in prompt.disabled_reasons:
		assert_eq(reason, '', 'The first turn of a scene may choose anything.')

func test_the_chosen_mode_is_held_and_nothing_else():
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.STABILIZER_OVERRIDE)
	assert_eq(Fixture.held_modes(rakshasa), [MODE.STABILIZER_OVERRIDE] as Array[int], 'Exactly the chosen chip.')

func test_every_mode_can_be_chosen():
	with_a_hostile_in_sensors()
	for mode:int in Fixture.MODE_CHIPS.size():
		await Fixture.choose_mode(game, rakshasa, responder, mode)
		assert_eq(Fixture.held_modes(rakshasa), [mode] as Array[int], 'Mode %s is held.' % Fixture.MODE_NAMES[mode])

func test_last_turns_mode_is_disabled_and_the_rest_are_not():
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	assert_eq(responder.multiple_choice_prompts.size(), 2, 'One menu per turn.')
	var prompt := last_prompt()
	if prompt.is_empty(): return
	assert_ne(prompt.disabled_reasons[MODE.DRAIN], '', 'Last turn\'s Drain is disabled.')
	for mode:int in [MODE.ENTRAP, MODE.STABILIZER_OVERRIDE, MODE.SOULBIND, MODE.ENSORCEL]:
		assert_eq(prompt.disabled_reasons[mode], '', '%s is not.' % Fixture.MODE_NAMES[mode])

func test_a_forced_pick_of_last_turns_mode_is_refused_and_asked_again():
	# A disabled brochure button still resolves (informational_brochure.gd:76-84), so the pick is
	# re-checked: the refused pick asks again, and the second answer is the one held.
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	responder.multiple_choice_queue.append(MODE.DRAIN)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	assert_eq(responder.multiple_choice_prompts.size(), 3, 'The refused pick asked a second time.')
	assert_eq(Fixture.held_modes(rakshasa), [MODE.ENTRAP] as Array[int], 'Drain two turns running is refused.')

func test_a_pick_refused_every_time_falls_back_to_the_rotation():
	# The refused pick is asked again at most MAX_ASKS (3) times in all, then the AI's rotation decides,
	# so no answer can hang the turn start. After Drain, the rotation's next is Entrap.
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	responder.multiple_choice_queue.append_array([MODE.DRAIN, MODE.DRAIN, MODE.DRAIN])
	await Fixture.cycle_turn(game, rakshasa)
	assert_eq(responder.multiple_choice_prompts.size(), 4, 'Three asks this turn, then no more.')
	assert_eq(Fixture.held_modes(rakshasa), [MODE.ENTRAP] as Array[int], 'Never Drain; the rotation picked Entrap.')

func test_the_mode_two_turns_ago_may_be_chosen_again():
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	assert_eq(Fixture.held_modes(rakshasa), [MODE.DRAIN] as Array[int], '"Two turns in a row" only.')
	assert_eq(last_prompt().disabled_reasons[MODE.DRAIN], '', 'Drain was offered.')

func test_a_new_scene_forgets_last_turns_mode():
	# Ruling 13: the memory is core gear state, which repair clears (gear_core.gd:130-155).
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await SpecFactory.end_turn(game, rakshasa)
	rakshasa.core.full_repair()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	assert_eq(last_prompt().disabled_reasons[MODE.DRAIN], '', 'Nothing is disabled after a repair.')
	assert_eq(Fixture.held_modes(rakshasa), [MODE.DRAIN] as Array[int], 'Drain again.')

# ---------------------------------------------------------------- lifetime

func test_the_chip_lasts_through_the_turn_and_clears_at_the_next_turn_start():
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	await SpecFactory.end_turn(game, rakshasa)
	assert_true(Fixture.holds_mode(rakshasa, MODE.DRAIN), 'Still held after the Rakshasa\'s turn ends.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	assert_eq(Fixture.held_modes(rakshasa), [MODE.ENTRAP] as Array[int], 'Drain is gone; only the new mode.')

# ---------------------------------------------------------------- Soulbind needs somebody

func test_soulbind_is_disabled_with_nobody_in_sensors():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	Fixture.create_hostile(game, FAR_TILE)
	await Fixture.cycle_turn(game, rakshasa)
	var prompt := last_prompt()
	if prompt.is_empty():
		fail_test('No menu was raised.')
		return
	assert_ne(prompt.disabled_reasons[MODE.SOULBIND], '', 'Nobody within Sensors: Soulbind is disabled.')
	assert_eq(prompt.disabled_reasons[MODE.DRAIN], '', 'Control: the others are not.')

func test_a_drone_alone_in_sensors_does_not_enable_soulbind():
	# "Character" is is_actor() (rulings row 301): a drone is not one.
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	Fixture.create_hostile_drone(game, HOSTILE_TILE)
	await Fixture.cycle_turn(game, rakshasa)
	assert_ne(last_prompt().get('disabled_reasons', ['', '', '', ''])[MODE.SOULBIND], '', 'A drone is not a character.')

func test_a_forced_soulbind_pick_with_nobody_in_sensors_is_refused():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	Fixture.create_hostile(game, FAR_TILE)
	responder.multiple_choice_queue.append(MODE.SOULBIND)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	assert_eq(Fixture.held_modes(rakshasa), [MODE.DRAIN] as Array[int], 'The Soulbind pick was refused.')

# ---------------------------------------------------------------- nobody answers

func test_an_ai_rakshasa_chooses_without_asking_and_rotates_in_card_order():
	# Ruling 14: the next option in card order after the last one; the first turn starts at Drain.
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, Faction.AI_ENEMY)
	Fixture.create_ally(game, HOSTILE_TILE) # a PLAYER unit: somebody in Sensors for Soulbind
	var seen:Array[int] = []
	for i:int in 6:
		await Fixture.cycle_turn(game, rakshasa)
		var held := Fixture.held_modes(rakshasa)
		assert_eq(held.size(), 1, 'Turn %s: exactly one mode.' % i)
		if held.size() == 1: seen.append(held[0])
	assert_eq(seen, [MODE.DRAIN, MODE.ENTRAP, MODE.STABILIZER_OVERRIDE, MODE.SOULBIND, MODE.ENSORCEL, MODE.DRAIN] as Array[int],
		'Card order, round and round, never the same twice.')
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'Nobody was asked.')

func test_an_ai_rakshasa_skips_soulbind_with_nobody_in_sensors():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, Faction.AI_ENEMY)
	Fixture.create_ally(game, FAR_TILE)
	for i:int in 3: await Fixture.cycle_turn(game, rakshasa) # Drain, Entrap, Stabilizer Override
	assert_eq(Fixture.held_modes(rakshasa), [MODE.STABILIZER_OVERRIDE] as Array[int], 'fixture: three turns in.')
	await Fixture.cycle_turn(game, rakshasa)
	assert_eq(Fixture.held_modes(rakshasa), [MODE.ENSORCEL] as Array[int], 'Soulbind is skipped.')

func test_a_stunned_rakshasa_still_chooses():
	# Ruling 14: "at the start of each of your turns" is not an action; a non-consuming reaction passes
	# the stun gate (action_reaction.gd:62-66).
	with_a_hostile_in_sensors()
	SpecFactory.apply(rakshasa, Lancer.STATUS.STUNNED)
	assert_true(rakshasa.has_status(Lancer.STATUS.STUNNED), 'fixture: stunned.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'The menu was raised.')
	assert_eq(Fixture.held_modes(rakshasa), [MODE.ENTRAP] as Array[int], 'And its choice held.')

func test_the_chips_come_from_the_core_system():
	with_a_hostile_in_sensors()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var chip:BuffCore = UnitCondition.get_buff(rakshasa, Fixture.MODE_CHIPS[MODE.DRAIN])
	assert_not_null(chip, 'fixture: Drain is held.')
	if chip == null: return
	assert_eq(chip.from_gear, rakshasa.get_gear(Fixture.CORE_ID).persistent_id, 'from_gear is the core system.')
	assert_eq(chip.base.until, Lancer.UNTIL.START_OF_TURN, 'Until the start of the next turn.')
	assert_false(chip.base.hide_from_player, 'A visible chip.')
