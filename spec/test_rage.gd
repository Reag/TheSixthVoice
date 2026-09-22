# RAGE - the active half of HYDRAULIC EXCESS (SP1 Task 6): the protocol, the chip, and the turn-start
# d6 that reads it.
#
#   "At the start of each of your turns for the rest of the scene roll a d6 then gain the
#    corresponding effect. The effects last until the start of your next turn:"
#
# THIS FILE IS ABOUT THE MACHINE, NOT THE FACES. Tasks 7-12 each build one face and each assert their
# own chip; here the FACE_CHIPS table names five buff ids that do not exist yet, and the reaction
# resolves each through ContentLibrary.get_buff and skips a null. So the claim under test is: the
# protocol holds a chip for the scene, a turn start with the chip rolls exactly one d6 and logs it,
# and a turn start without the chip rolls nothing at all.
#
# NEW_TURN **POST**, AND THE REASON IS AN ORDERING (ruling 7). event_turn_start awaits the PRE
# reactions at :14; handle_starting_unit runs at :39 and clears START_OF_TURN buffs at :76
# (new_turn_for_statuses); the POST queue is built at :56. Every face chip is until = START_OF_TURN,
# so one applied at PRE would die in the same event. THAT IS ASSERTED DECLARATIVELY HERE and
# BEHAVIOURALLY IN TASK 7, where a face chip exists to survive.
#
# EXACTLY ONE d6, MEASURED. handle_starting_unit also rolls a d6 per un-recharged non-basic gear
# (:89-91), but GearCore.is_recharged defaults true (gear_core.gd:13), full_repair resets it to true
# (:136) and no Kit this frame carries declares recharge_on - so that loop pops nothing and the RAGE
# roll is the first pop of the new turn. Every queue in this file and in LeolethFixture.rage depends
# on it, so it is asserted here rather than assumed.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rage.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(4, 6)

var game:Gamemaster
var leoleth:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear() -> GearCore:
	return leoleth.get_gear(LeolethFixture.CORE_ID)

func action_by_id(action_id:StringName) -> Action:
	var gear:GearCore = core_gear()
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == action_id: return action
	return null

# ---------------------------------------------------------------- the wiring

func test_the_core_kit_carries_the_protocol_and_the_roll():
	assert_true(GearCore.is_valid(core_gear()), 'fixture: the core Kit is on the unit.')
	assert_not_null(action_by_id(LeolethFixture.ASR_ID), 'It still carries ALL SYSTEMS RED (Task 5).')
	assert_not_null(action_by_id(LeolethFixture.RAGE_ID), 'And now the RAGE protocol.')
	assert_not_null(action_by_id(LeolethFixture.RAGE_ROLL_ID), 'And the hidden turn-start roll.')

func test_the_protocol_is_wired_as_ruling_7_says():
	var action := action_by_id(LeolethFixture.RAGE_ID)
	assert_not_null(action, 'fixture: the protocol is on the Kit.')
	if action == null: return
	assert_true(action is ActionSystemApplyBuff, 'It is an ActionSystemApplyBuff - the Fitzgerald shape.')
	if not (action is ActionSystemApplyBuff): return
	var specific := SpecificAction.create(leoleth, core_gear(), action)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.PROTOCOL,
		'A PROTOCOL - Lancer.ACTION index 4 (lancer.gd:27).')
	# consumes_core_power() is declared `-> int` while returning a bool export (action.gd:167,
	# action_system.gd:31), so GDScript refuses to compare it to a bool directly. This mod reads it
	# through int() in three other specs.
	assert_eq(int(action.consumes_core_power()), 1, 'It spends the core power.')
	assert_true(action.apply_only_to_self, 'Self only.')
	assert_true(action.can_apply_to_self, 'And self is a legal target.')
	assert_false(action.can_reapply, 'It cannot be pressed twice - the chip lasts the scene.')
	assert_eq(action.usage_group, &'rage',
		'Its own usage group: a groupless action falls back to the KIT id (gear_core.gd:166-168), '
		+ 'which would make this protocol share a tally with Combust and the roll.')
	assert_eq(action.buffs.size(), 1, 'It applies exactly one buff.')
	if action.buffs.is_empty(): return
	assert_eq(action.buffs[0].compcon_id, LeolethFixture.RAGE_CHIP, 'And that buff is buff_rage.')

func test_the_roll_reaction_is_wired_as_ruling_7_says():
	var action := action_by_id(LeolethFixture.RAGE_ROLL_ID)
	assert_not_null(action, 'fixture: the roll is on the Kit.')
	if action == null: return
	assert_true(action is ActionReactionSelf, 'It is an ActionReactionSelf.')
	if not (action is ActionReactionSelf): return
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.NEW_TURN] as Array[StringName],
		'It triggers on new_turn and nothing else.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST,
		'POST, NOT PRE. handle_starting_unit clears START_OF_TURN buffs at event_turn_start.gd:76, '
		+ 'inside execute; the PRE await is at :14 and the POST queue at :56. A face chip applied at '
		+ 'PRE would die in the same event. Task 7 proves this behaviourally.')
	assert_false(action.consumes_rxn, 'Point-free: it is automatic, not a reaction the player takes.')
	assert_false(action.show_in_tooltip(ContentLibrary.get_kit(LeolethFixture.CORE_ID)),
		'Hidden: the protocol\'s own effect row is the whole table.')
	assert_eq(action.usage_group, &'rage_roll', 'And its own usage group.')

func test_the_chip_and_the_table_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_hydraulic_excess.action_rage.name',
			'gear.cp_hydraulic_excess.action_rage.effect',
			'gear.buff_rage.name', 'gear.buff_rage.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.cp_hydraulic_excess.action_rage.name'), 'RAGE', 'Named off the card.')
	assert_eq(X.tr('gear.buff_rage.name'), 'RAGE', 'And the chip wears the same name.')
	# THE WHOLE TABLE IS ONE ROW, with the LCP's <br> tags as real newlines - the shape
	# gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.effect already uses. All six faces are
	# asserted, because a truncation at a comma is exactly what CSV quoting gets wrong.
	var table:String = X.tr('gear.cp_hydraulic_excess.action_rage.effect')
	assert_true(table.begins_with('At the start of each of your turns for the rest of the scene'),
		'The table opens on the card\'s own first clause.')
	for face:String in ['1 Decimate:', '2 Swift:', '3 Reach:', '4 Combust:', '5 Bulwark:', '6 Hatred:']:
		assert_true(table.contains(face), 'And it carries the %s row.' % face)
	assert_true(table.ends_with('they take 3 |energy| damage.'),
		'And ends on Hatred, with nothing after it.')

# ---------------------------------------------------------------- the protocol

func test_pressing_the_protocol_holds_the_chip_for_the_scene():
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.RAGE_CHIP), 'fixture: no chip to start.')
	await LeolethFixture.press_rage(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.RAGE_CHIP), 'Pressing it holds the chip.')
	var chip:BuffCore = UnitCondition.get_buff(leoleth, LeolethFixture.RAGE_CHIP)
	assert_not_null(chip, 'fixture: the chip is readable.')
	if chip == null: return
	assert_eq(chip.base.until, Lancer.UNTIL.MANUAL,
		'until = MANUAL, which is "the rest of the scene" - Lancer.UNTIL\'s own zero.')
	# ACROSS A WHOLE TURN CYCLE, because "for the rest of the scene" is the clause most likely to be
	# lost to a stray lifetime.
	await SpecFactory.end_turn(game, leoleth)
	LeolethFixture.queue([LeolethFixture.FACE_REACH])
	await SpecFactory.start_turn(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.RAGE_CHIP), 'And it survives a turn cycle.')

func test_pressing_the_protocol_spends_the_core_power():
	await LeolethFixture.open_turn(game, leoleth)
	assert_true(leoleth.core.has_core_power, 'fixture: the core power is available.')
	await SpecFactory.use(game, leoleth, LeolethFixture.CORE_ID, LeolethFixture.RAGE_ID)
	assert_false(leoleth.core.has_core_power, 'And pressing RAGE spends it.')

func test_the_protocol_is_refused_outside_the_protocol_window():
	# unit_action.gd:144 refuses a PROTOCOL unless unit.state.is_using_protocols, which only
	# event_turn_start opens (event_turn_start.gd:82). Asserted through is_available_to_activate
	# rather than by watching an activation fail, because a refused activation aborts quietly and
	# "the chip is absent" would be true for either reason (the Sluagh close's carry-forward).
	var action := action_by_id(LeolethFixture.RAGE_ID)
	assert_not_null(action, 'fixture: the protocol is on the Kit.')
	if action == null: return
	var specific := SpecificAction.create(leoleth, core_gear(), action)
	assert_false(leoleth.state.is_using_protocols, 'fixture: no turn is open.')
	assert_false(UnitAction.can_activate_gear(specific), 'So the protocol cannot be activated.')
	await LeolethFixture.open_turn(game, leoleth)
	assert_true(leoleth.state.is_using_protocols, 'fixture: the turn opened the window.')
	assert_true(UnitAction.can_activate_gear(specific), 'And now it can.')

# ---------------------------------------------------------------- the roll

func test_a_turn_start_with_the_chip_rolls_exactly_one_d6():
	# THE MEASUREMENT EVERY LATER TASK'S QUEUE DEPENDS ON. The tail after the face is asserted intact,
	# which is how "exactly one" is said: LeolethFixture.queue appends sixty 1s after the numbers it is
	# given, so a second pop would eat the first of them.
	await LeolethFixture.press_rage(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([LeolethFixture.FACE_BULWARK, 2, 3] as Array[int])
	await SpecFactory.start_turn(game, leoleth)
	assert_eq(Dice.CHEAT_ROLL_QUEUE, [2, 3] as Array[int],
		'Exactly one die was popped: the recharge loop rolls nothing for this frame.')

func test_a_turn_start_without_the_chip_rolls_nothing():
	# THE CONTROL, and the only thing that makes the test above about RAGE rather than about turn
	# starts. Without the protocol pressed, triggers_on_event refuses and the queue is untouched.
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([LeolethFixture.FACE_BULWARK, 2, 3] as Array[int])
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.RAGE_CHIP), 'fixture: no chip.')
	await SpecFactory.start_turn(game, leoleth)
	assert_eq(Dice.CHEAT_ROLL_QUEUE, [LeolethFixture.FACE_BULWARK, 2, 3] as Array[int],
		'Nothing was popped at all.')

func test_the_roll_repeats_at_every_turn_start_for_the_rest_of_the_scene():
	# "AT THE START OF EACH OF YOUR TURNS" - so the second turn rolls too, and a hostile's turn start
	# in between does not.
	await LeolethFixture.press_rage(game, leoleth)
	var hostile:Unit = LeolethFixture.create_hostile(game, Vector2i(10, 6))
	await SpecFactory.end_turn(game, leoleth)

	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([4, 4, 4] as Array[int])
	await SpecFactory.start_turn(game, hostile)
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 3,
		'A HOSTILE\'s turn start pops nothing - ActionReactionSelf refuses a triggering unit that is '
		+ 'not us (action_reaction_self.gd:11-15).')
	await SpecFactory.end_turn(game, hostile)

	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([LeolethFixture.FACE_HATRED, 2] as Array[int])
	await SpecFactory.start_turn(game, leoleth)
	assert_eq(Dice.CHEAT_ROLL_QUEUE, [2] as Array[int], 'And the Leoleth\'s second turn rolls again.')
