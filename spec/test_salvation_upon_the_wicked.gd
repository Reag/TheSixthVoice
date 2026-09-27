# SALVATION UPON THE WICKED (Naga core active, SP1 Task 4), ruling 8:
#   "For the rest of the scene, whenever a hostile character would lose Lock On within sensors. They
#    must succeed a Systems save or take 1 AP Kinetic damage and become Locked On."
#
# A PROTOCOL (consumes_cp) hanging buff_salvation on the Naga, and a hidden statuses_changed POST
# reaction on the same Kit that lives while the chip does. "WOULD LOSE" IS "LOST, SAVE, RE-LOCKED":
# the engine has no PRE for a status clear (unit_condition.gd:216-218), so the reaction fires one
# event after the loss and re-locks on a failed save - the same board state one event later.
#
# WHAT THIS FILE PROVES (design 1.4): with the chip up, a hostile within Sensors losing Lock On to
# a consume rolls a Systems save; a FAIL deals 1 that ignores armor (a 3-armor dummy loses exactly
# 1) and re-locks it with the core Kit as the source; a PASS does neither; a Stabilize-style ability
# clear on a hostile within Sensors also triggers; a hostile outside Sensors does not; without the
# chip nothing triggers; twice in one round both trigger; an allied unit losing Lock On does not.
# Added at the frame close (2026-09-23): a DOUBLY-locked hostile cleared by Stabilize saves once
# (fail or pass); losing one of two stacked locks is no loss; a second Naga finds the target already
# re-locked; a hostile DRONE's loss triggers too (ruling 2026-09-27). Every clear here is Stabilize's real line
# (NagaFixture.clear_like_stabilize) except the one-of-two case, which needs a sourced clear.
# Plus the protocol itself (spends the core power, hangs the visible chip, needs a turn) and the rows.
#
# THE CONSUMER IS THE INVADE, NOT THE RIFLE, so the hostile's HP damage is the re-lock's 1 and
# nothing else: a tech attack deals heat, never HP, to a hostile. THE DICE ORDER IS THE TEST: the
# consume runs at ATTACK_DECLARED PRE, its statuses_changed POST is queued onto that same block, so
# the relock's SAVE d20 pops BEFORE the attack's own d20. queue([save, attack]) - and the numbers are
# chosen so a swapped order fails loudly: a save of 1 (fail) followed by an attack of 19 (hit) reads
# as a pass-and-miss the other way round.
#
# GEOMETRY. The Naga (size 2) at (4,4) occupies (4,4)-(5,5); Sensors 8 from its closest tile.
# HOSTILE (9,4) is 4 away; FAR_HOSTILE (14,4) is 9 - one past Sensors - and still inside the Naga's
# own Lock On range 8? No: Lock On's range IS Sensors, so the far hostile is locked BY HAND through
# the shared hook with the Naga's ms_lock_on gear as the source, exactly what a Lock On would write.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_salvation_upon_the_wicked.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const NAGA_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(9, 4)
const SECOND_HOSTILE_TILE := Vector2i(9, 7)
const FAR_HOSTILE_TILE := Vector2i(14, 4) # 9 from (5,4): one past Sensors
const ALLY_TILE := Vector2i(7, 4)

const SAVE_FAIL := 1
const SAVE_PASS := 20
const ATTACK_HIT := 19
const DUMMY_ARMOR := 3

var game:Gamemaster
var naga:Unit
var hostile:Unit

func before_each() -> void:
	game = NagaFixture.create_game(self)
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	hostile = NagaFixture.create_hostile(game, HOSTILE_TILE)
	NagaFixture.set_armor(hostile, DUMMY_ARMOR)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func core_gear() -> GearCore:
	return naga.get_gear(NagaFixture.CORE_ID)

func has_chip() -> bool:
	return UnitCondition.has_buff(naga, NagaFixture.SALVATION_CHIP)

## Lock the target by hand with the Naga's gear as the source, then consume with the invade:
## [save d20 (if any), attack d20].
func lock_then_consume_by_invade(target:Unit, save_d20:int) -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked by hand (no slither, no confirm prompt).')
	NagaFixture.queue([save_d20, ATTACK_HIT])
	await NagaFixture.invade(game, naga, target) # the stock responder consumes

# ---------------------------------------------------------------- the protocol

func test_the_protocol_spends_the_core_power_and_hangs_the_visible_chip() -> void:
	assert_true(naga.core.has_core_power, 'fixture: core power up.')
	assert_false(has_chip(), 'fixture: no chip yet.')
	await NagaFixture.press_salvation(game, naga)
	assert_true(has_chip(), 'The chip is on the Naga.')
	assert_false(naga.core.has_core_power, 'The core power is spent.')
	var chip:Buff = ContentLibrary.get_buff(NagaFixture.SALVATION_CHIP)
	assert_not_null(chip, 'The chip is a registered buff.')
	if chip == null: return
	assert_false(chip.hide_from_player, 'And it is VISIBLE - the only on-token sign the protocol is running.')
	assert_eq(chip.until, Lancer.UNTIL.MANUAL, '"For the rest of the scene": no timer.')
	var protocol:Action = ContentLibrary.get_kit(NagaFixture.CORE_ID).get_action(NagaFixture.SALVATION_ID)
	assert_eq(protocol.get_action_type(SpecificAction.create(naga, core_gear(), protocol)), Lancer.ACTION.PROTOCOL, 'A protocol.')
	assert_true(bool(protocol.consumes_core_power()), 'That consumes the core power (an int on ActionSystem).')

func test_the_rows_resolve() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_shimmering_veil.action_salvation_upon_the_wicked.name',
			'gear.cp_shimmering_veil.action_salvation_upon_the_wicked.effect',
			'gear.buff_salvation.name', 'gear.buff_salvation.effect',
			'gear.cp_shimmering_veil.action_salvation_relock.name']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.buff_salvation.name'), 'SALVATION UPON THE WICKED', 'The chip names the protocol.')

# ---------------------------------------------------------------- the loss, the save, the re-lock

func test_a_failed_save_after_a_consume_deals_one_ap_and_relocks_before_the_attack_rolls() -> void:
	await NagaFixture.press_salvation(game, naga)
	var heat_before:int = hostile.core.current.heat
	await lock_then_consume_by_invade(hostile, SAVE_FAIL)
	assert_eq(hostile.current_damage(), 1,
		'THE CLAIM: exactly 1 HP lost through 3 armor - the AP flag - and nothing else, the invade deals heat.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'And it is Locked On again...')
	assert_eq(Lockon.source_of(hostile), core_gear().persistent_id,
		'...by the core Kit, which is the source the re-lock writes.')
	assert_gt(hostile.core.current.heat, heat_before,
		'ORDER: the attack rolled its 19 AFTER the save popped its 1 - the invade hit and dealt heat.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.size() < 60, 'fixture: dice were popped from the queue.')

func test_a_passed_save_does_neither() -> void:
	await NagaFixture.press_salvation(game, naga)
	await lock_then_consume_by_invade(hostile, SAVE_PASS)
	assert_eq(hostile.current_damage(), 0, 'No damage on a pass.')
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'And the lock stays consumed.')
	assert_gt(hostile.core.current.heat, 0, 'LIVENESS: the invade still hit (its 19 came after the save\'s 20).')

func test_an_ability_clear_within_sensors_also_triggers() -> void:
	# Stabilize's own line, driven for real (NagaFixture.clear_like_stabilize runs
	# clear_status_via_ability -> clear_specific_status): the loss carries the locker's source, and
	# the reaction does not care - "would lose", unqualified.
	await NagaFixture.press_salvation(game, naga)
	assert_true(NagaFixture.lock_by_hand(naga, hostile), 'fixture: locked.')
	NagaFixture.queue([SAVE_FAIL])
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_eq(hostile.current_damage(), 1, 'A failed save on an ability clear: 1 AP.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'And re-locked.')
	assert_eq(Lockon.source_of(hostile), core_gear().persistent_id, 'By the core Kit.')

func test_a_hostile_outside_sensors_does_not_trigger() -> void:
	await NagaFixture.press_salvation(game, naga)
	var far := NagaFixture.create_hostile(game, FAR_HOSTILE_TILE)
	NagaFixture.set_armor(far, DUMMY_ARMOR)
	assert_eq(UnitRelation.distance_between(naga, far), 9, 'fixture: one past Sensors 8.')
	assert_true(Lockon.apply(SpecFactory.dummy_event({unit = naga}), far, naga.get_gear(NagaFixture.LOCK_ON)),
		'fixture: locked by hand with the Naga\'s ms_lock_on as the source.')
	NagaFixture.queue([SAVE_FAIL])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, far, Lancer.STATUS.LOCKON)
	assert_false(far.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the lock was cleared.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'No save was rolled: nothing popped.')
	assert_eq(far.current_damage(), 0, 'No damage.')

func test_without_the_chip_nothing_triggers() -> void:
	assert_false(has_chip(), 'fixture: the protocol was never pressed.')
	assert_true(NagaFixture.lock_by_hand(naga, hostile), 'fixture: locked.')
	NagaFixture.queue([SAVE_FAIL])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the lock was cleared.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'No save was rolled.')
	assert_eq(hostile.current_damage(), 0, 'No damage, no re-lock: the reaction is unavailable without the chip.')

func test_twice_in_one_round_both_trigger() -> void:
	# Unlimited per round: two losses, two saves, two re-locks, with the Naga's turn never cycled.
	await NagaFixture.press_salvation(game, naga)
	assert_true(NagaFixture.lock_by_hand(naga, hostile), 'fixture: locked.')
	NagaFixture.queue([SAVE_FAIL])
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_eq(hostile.current_damage(), 1, 'fixture: the first loss cost 1.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'fixture: and re-locked.')
	NagaFixture.queue([SAVE_FAIL])
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON) # loses the RE-lock
	assert_eq(hostile.current_damage(), 2, 'The second loss in the same round cost another 1.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'And re-locked again.')

func test_a_doubly_locked_hostile_cleared_by_stabilize_saves_once() -> void:
	# THE DOUBLE-FIRE (close review slice 2 #1). apply_status APPENDS (unit_condition.gd:103-105), so
	# a Markerlight on a target already Locked On leaves TWO Lock On copies with two sources; Lockon.apply
	# refuses a second lock, so they are written raw here. Stabilize's clear_status_via_ability clears
	# BOTH and fires one statuses_changed POST PER COPY (:479-483 -> :326-329). The hostile loses Lock
	# On ONCE, so it saves once and takes at most 1.
	await NagaFixture.press_salvation(game, naga)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.LOCK_ON).persistent_id)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.SCAN).persistent_id)
	var copies := hostile.state.statuses.filter(func(s:StatusCondition) -> bool: return s.type == Lancer.STATUS.LOCKON)
	assert_eq(copies.size(), 2, 'fixture: two stacked Lock On copies.')
	NagaFixture.queue([SAVE_FAIL]) # and the tail is 1s: a second save would ALSO fail, and show
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_eq(queued - Dice.CHEAT_ROLL_QUEUE.size(), 1, 'THE CLAIM: exactly one save d20 popped.')
	assert_eq(hostile.current_damage(), 1, 'And 1 AP, not 2.')
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the one failed save re-locked it.')
	assert_eq(Lockon.source_of(hostile), core_gear().persistent_id, 'By the core Kit.')

func test_a_doubly_locked_hostile_that_passes_is_not_asked_again() -> void:
	# The same stack, a PASS: nothing re-locks, so the second copy's POST must not roll a second save.
	await NagaFixture.press_salvation(game, naga)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.LOCK_ON).persistent_id)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.SCAN).persistent_id)
	NagaFixture.queue([SAVE_PASS])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: both copies cleared, no re-lock.')
	assert_eq(queued - Dice.CHEAT_ROLL_QUEUE.size(), 1, 'THE CLAIM: one save, not a second on a tail 1.')
	assert_eq(hostile.current_damage(), 0, 'And no damage.')

func test_losing_one_of_two_stacked_locks_does_not_trigger() -> void:
	# A source-specific clear of ONE copy (event_unit_clear_status with a source) leaves the other:
	# the hostile never loses Lock On, so there is nothing to save against.
	await NagaFixture.press_salvation(game, naga)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.LOCK_ON).persistent_id)
	SpecFactory.apply(hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, naga.get_gear(NagaFixture.SCAN).persistent_id)
	NagaFixture.queue([SAVE_FAIL])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_by_ability(game, hostile, Lancer.STATUS.LOCKON)
	var copies := hostile.state.statuses.filter(func(s:StatusCondition) -> bool: return s.type == Lancer.STATUS.LOCKON)
	assert_eq(copies.size(), 1, 'LIVENESS: one copy was cleared, one remains.')
	assert_eq(queued - Dice.CHEAT_ROLL_QUEUE.size(), 0, 'No save: it is still Locked On.')
	assert_eq(hostile.current_damage(), 0, 'No damage.')

func test_two_nagas_the_second_finds_the_target_already_relocked() -> void:
	# The activate() half of still_locked: both Nagas' reactions are QUEUED on the one loss (the target
	# holds no lock at queue time), the first fails the save and re-locks, and by the time the second
	# RUNS there is nothing left to lose - so it neither saves nor deals a second 1 AP.
	var naga2 := NagaFixture.create_naga(game, Vector2i(4, 8))
	await NagaFixture.press_salvation(game, naga)
	await NagaFixture.press_salvation(game, naga2)
	assert_true(UnitCondition.has_buff(naga2, NagaFixture.SALVATION_CHIP), 'fixture: the second Naga\'s chip is up.')
	assert_true(has_chip(), 'fixture: the first Naga\'s chip is up.')
	assert_lte(UnitRelation.distance_between(naga2, hostile), naga2.get_sensor_range(), 'fixture: within its Sensors.')
	assert_true(NagaFixture.lock_by_hand(naga, hostile), 'fixture: locked.')
	NagaFixture.queue([SAVE_FAIL]) # the tail is 1s: a second save would fail too
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: one Naga re-locked it.')
	assert_eq(queued - Dice.CHEAT_ROLL_QUEUE.size(), 1, 'THE CLAIM: one save across both Nagas.')
	assert_eq(hostile.current_damage(), 1, 'And 1 AP, not 2.')

func test_a_hostile_drone_losing_lock_on_now_triggers() -> void:
	# "A hostile CHARACTER" is is_character() (ruling 2026-09-27, reversing the old is_actor() reading):
	# a drone is_character() (unit.gd:116), so within Sensors and hostile it now fails no gate at all.
	await NagaFixture.press_salvation(game, naga)
	var drone := NagaFixture.create_drone(game, SECOND_HOSTILE_TILE, Faction.AI_ENEMY)
	assert_true(drone.is_character(), 'fixture: a drone is a character.')
	assert_true(UnitRelation.are_enemies(naga, drone), 'fixture: hostile.')
	assert_lte(UnitRelation.distance_between(naga, drone), naga.get_sensor_range(), 'fixture: within Sensors.')
	assert_true(NagaFixture.lock_by_hand(naga, drone), 'fixture: locked.')
	NagaFixture.queue([SAVE_FAIL])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, drone, Lancer.STATUS.LOCKON)
	assert_eq(queued - Dice.CHEAT_ROLL_QUEUE.size(), 1, 'A save WAS rolled: a drone is "a hostile character" now.')
	assert_eq(drone.current_damage(), 1, 'And a failed save dealt 1 AP.')
	assert_true(drone.has_status(Lancer.STATUS.LOCKON), 'And re-locked, same as any other character.')

func test_an_allied_unit_losing_lock_on_does_not_trigger() -> void:
	await NagaFixture.press_salvation(game, naga)
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	NagaFixture.arm_rifle(hostile)
	assert_true(Lockon.apply(SpecFactory.dummy_event({unit = hostile}), ally, hostile.get_gear(NagaFixture.LOCK_ON)),
		'fixture: the hostile\'s lock on our ally.')
	NagaFixture.queue([SAVE_FAIL])
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await NagaFixture.clear_like_stabilize(game, ally, Lancer.STATUS.LOCKON)
	assert_false(ally.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally lost the lock.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'No save: an ally is not "a hostile character".')
	assert_eq(ally.current_damage(), 0, 'No damage.')
