## WIDE GAZE NETWORKS, the Naga's rank-I tech system (SP2 Task 2, design rulings 10-13).
##
## "Ping (Invade): Your target becomes Locked on. Until the end of your next turn, if the target has
##  Lock On, they are also Impaired."
## "Hypnotize (Invade): You may immediately scan the target. Allied characters attacks against the
##  target may choose to target either Evasion or E-Defense regardless of if the weapon is smart.
##  This lasts until they succeed on a Systems check as a quick action."
##  (specs/sixth-voice/10-naga.md, Rank I)
##
## GEOMETRY, and why it tolerates the Naga moving. Every invade is a Tech Action, so WIRE SLITHER
## offers its 2-space move and the stock responder takes it (naga_fixture.lock_by_hand's header).
## So nothing here depends on where the Naga ends up: the target at distance 4 stays inside the
## invade's Sensors 8 after any slither, and the SHOOTER sits 14 out (12 after a slither), so after a slither it is still
## beyond Sensors and THE BLOOD OF THE CREATURE never offers on its consume.
##
## DICE: an invade on a hostile pops one d20 (no accuracy die, a flat +1 tech attack). The rifle pops
## its d20, one accuracy d6 when it consumes Lock On, then its damage.
##
## IMPAIRED IS MEASURED AS AN ACCURACY MOD, never read off the status array: PreAttack.create adds
## the -1 from the ATTACKER's has_status (attack_roll.gd:171-172), which is what the card's
## "Impaired" does in play.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'ms_wide_gaze_networks'
const PING := &'action_ping'
const HYPNOTIZE := &'action_hypnotize'
const CLEAR := &'action_hypnotize_clear'
const PING_CHIP := &'buff_ping'
const HYPNOTIZED := &'buff_hypnotized'
const TARGETING := &'buff_hypnotize_targeting'

const NAGA_TILE := Vector2i(4, 4)     # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(9, 4)   # 4 from the Naga's east edge
const SHOOTER_TILE := Vector2i(19, 4) # 10 from the target (Range 10), 12+ from the Naga after any slither
const ALLY_TILE := Vector2i(12, 4)    # 3 from the target, inside the rifle's Range 10

const CHECK_PASSES := 20
const CHECK_FAILS := 1

var game:Gamemaster
var naga:Unit
var target:Unit
var wgn:GearCore


func before_each() -> void:
	game = NagaFixture.create_game(self)
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE)
	wgn = NagaFixture.equip(naga, KIT_ID)
	# ARM EVERYONE UP FRONT: equip() is idempotent, but its FIRST call runs full_repair, which must
	# never run after an invade has hung the chips this spec is reading. Later arm_rifle calls in the
	# helpers are then pure lookups.
	NagaFixture.arm_rifle(naga)
	NagaFixture.arm_rifle(target)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	if is_instance_valid(SpecFactory.current_responder): SpecFactory.current_responder.chosen_yesnos = true


func ping(at:Unit = target) -> void:
	await NagaFixture.open_turn(game, naga)
	NagaFixture.queue([19])
	await SpecFactory.use(game, naga, KIT_ID, PING, at)

func hypnotize(at:Unit = target) -> void:
	await NagaFixture.open_turn(game, naga)
	NagaFixture.queue([19])
	await SpecFactory.use(game, naga, KIT_ID, HYPNOTIZE, at)

## The target's own rifle shot at the Naga, as a PreAttack - the per-target read of its accuracy.
func targets_accuracy() -> int:
	var rifle := NagaFixture.arm_rifle(target)
	var ctx := Context.create({unit = target, gear = rifle, action = rifle.get_solo_action(), target_unit = naga})
	return AttackRoll.PreAttack.create(ctx).accuracy_mods_total()

## `shooter`'s rifle against the target, as a PreAttack - what the roll would be made against.
func pre_attack(shooter:Unit) -> AttackRoll.PreAttack:
	var rifle := NagaFixture.arm_rifle(shooter)
	var ctx := Context.create({unit = shooter, gear = rifle, action = rifle.get_solo_action(), target_unit = target})
	return AttackRoll.PreAttack.create(ctx)

func rifle_is_smart(shooter:Unit, against:Unit) -> bool:
	var rifle := NagaFixture.arm_rifle(shooter)
	var action:ActionAttackWeapon = rifle.get_solo_action()
	var fields := {unit = shooter, gear = rifle, action = action}
	if against != null: fields.target_unit = against
	return action.has_tag(Lancer.WEAPON_TAG.SMART, Context.create(fields))

func lockon_count(unit:Unit) -> int:
	var n := 0
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == Lancer.STATUS.LOCKON: n += 1
	return n

func defences(unit:Unit, edef:int, evasion:int) -> void:
	unit.core.frame.stat.edef = edef
	unit.core.frame.stat.evasion = evasion
	unit.core.full_repair()


# ---------------------------------------------------------------- wiring

func test_the_kit_is_a_unique_sp2_system_with_two_invades_in_card_order() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes Wide Gaze Networks.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE (Kit.SYSTEM_TAGS.UNIQUE).')
	var ids:Array[StringName] = []
	for action:Action in kit.actions: ids.append(action.get_id())
	assert_eq(ids, [PING, HYPNOTIZE, CLEAR] as Array[StringName], 'Ping, Hypnotize, then the clear.')
	for id:StringName in [PING, HYPNOTIZE]:
		var invade := kit.get_action(id) as ActionAttackTech
		assert_not_null(invade, '%s is an ActionAttackTech.' % id)
		if invade: assert_true(invade.is_invade, '%s is an invade.' % id)
	var groups := {}
	for action:Action in kit.actions: groups[action.usage_group] = true
	assert_eq(groups.size(), 3, 'Each action has its own usage group.')

func test_the_licence_grants_it_at_rank_1() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_1.granted_gear: ids.append(kit.compcon_id)
	assert_eq(ids, [&'mw_shimmering_blade', KIT_ID] as Array[StringName], 'Rank 1: the Blade, then Wide Gaze Networks.')

func test_the_rows_resolve_through_the_mods_translation() -> void:
	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	for key:String in [
		'gear.ms_wide_gaze_networks.name', 'gear.ms_wide_gaze_networks.flavor',
		'gear.ms_wide_gaze_networks.action_ping.name', 'gear.ms_wide_gaze_networks.action_ping.effect',
		'gear.ms_wide_gaze_networks.action_hypnotize.name', 'gear.ms_wide_gaze_networks.action_hypnotize.effect',
		'gear.ms_wide_gaze_networks.action_hypnotize_clear.name',
		'gear.buff_ping.name', 'gear.buff_ping.effect', 'gear.buff_hypnotized.name', 'gear.buff_hypnotized.effect',
	]:
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)


# ---------------------------------------------------------------- Ping

func test_a_ping_locks_the_target_and_hangs_the_chip() -> void:
	await ping()
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'Locked On.')
	assert_eq(NagaFixture.source_of_status(target, Lancer.STATUS.LOCKON), wgn.persistent_id,
		'The lock is Wide Gaze Networks\' own.')
	var chip := UnitCondition.get_buff(target, PING_CHIP)
	assert_not_null(chip, 'The Ping chip hangs on the target.')
	if chip: assert_false(chip.base.hide_from_player, 'And it is visible.')

func test_the_pinged_target_is_impaired() -> void:
	assert_eq(targets_accuracy(), 0, 'CONTROL: before the Ping, the target\'s shot carries no mod.')
	await ping()
	assert_eq(targets_accuracy(), -1, 'Impaired: its shot now carries -1 accuracy.')

func test_consuming_the_lock_ends_the_impaired_but_not_the_window() -> void:
	await ping()
	var shooter := NagaFixture.create_ally(game, SHOOTER_TILE)
	NagaFixture.arm_rifle(shooter) # after the Ping, but the SHOOTER holds nothing the spec reads
	assert_gt(UnitRelation.distance_between(naga, shooter), naga.get_sensor_range(),
		'fixture: the shooter is beyond the Naga\'s Sensors, so THE BLOOD stays quiet.')
	NagaFixture.queue([19])
	await NagaFixture.shoot(game, shooter, target)
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the shot consumed the lock.')
	assert_eq(targets_accuracy(), 0, 'The Impaired went with the lock...')
	assert_true(UnitCondition.has_buff(target, PING_CHIP), '...but the window stands (author decision 1).')

func test_stabilize_on_the_lock_ends_the_impaired_but_not_the_window() -> void:
	await ping()
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the lock is cleared.')
	assert_eq(targets_accuracy(), 0, 'The Impaired is gone with the lock...')
	assert_true(UnitCondition.has_buff(target, PING_CHIP),
		'...but the chip - the WINDOW - stands until the end of the Naga\'s next turn (author decision 1).')

func test_stabilize_aimed_at_the_impaired_changes_nothing() -> void:
	await ping()
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.IMPAIRED)
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'The lock stands...')
	assert_true(UnitCondition.has_buff(target, PING_CHIP), '...the chip stands...')
	assert_eq(targets_accuracy(), -1,
		'...and the Impaired stands: a buff-carried status is out of clear_status_via_ability\'s reach '
		+ '(Myconid ruling 124). The way out is the lock, which is the card.')

## ORDER ONE: the target takes a turn between the Ping and the Naga's next turn.
func test_the_chip_expires_at_the_end_of_the_nagas_next_turn() -> void:
	await ping()
	await SpecFactory.end_turn(game, naga)
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'Still up after the Naga\'s Ping turn.')
	await SpecFactory.start_turn(game, target)
	await SpecFactory.end_turn(game, target)
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'Still up after the target\'s turn.')
	await SpecFactory.start_turn(game, naga)
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'Still up through the Naga\'s next turn...')
	assert_eq(targets_accuracy(), -1, '...and still Impaired.')
	await SpecFactory.end_turn(game, naga)
	assert_false(UnitCondition.has_buff(target, PING_CHIP), '...and gone when it ends ("your next turn").')
	assert_eq(targets_accuracy(), 0, 'The Impaired went with it.')
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'The Lock On itself is MANUAL and stays.')

## ORDER TWO: the target never starts a turn in between (the Naga acts last in one round and first
## in the next). A target-side END_OF_OWNERS_NEXT_TURN never ticks here (unit_condition.gd:24, :62),
## so only the Naga-side clock ends the window where the card does.
func test_the_window_ends_on_the_nagas_next_turn_even_if_the_target_never_acted() -> void:
	await ping()
	await SpecFactory.end_turn(game, naga)
	await SpecFactory.start_turn(game, naga)
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'Up through the Naga\'s next turn...')
	assert_eq(targets_accuracy(), -1, '...Impaired...')
	await SpecFactory.end_turn(game, naga)
	assert_false(UnitCondition.has_buff(target, PING_CHIP), '...and gone at its end, though the target never started a turn.')
	assert_eq(targets_accuracy(), 0, 'The Impaired went with it.')
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: still Locked On - it is the window that ended.')

## A second Ping restarts the window: the first Ping's clock must not take the second chip with it.
func test_a_second_ping_next_turn_restarts_the_window() -> void:
	await ping()
	await SpecFactory.end_turn(game, naga)
	await ping() # opens the Naga's next turn; the stock yes consumes the old lock, the hit relocks
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'LIVENESS: the second chip hangs.')
	await SpecFactory.end_turn(game, naga)
	assert_true(UnitCondition.has_buff(target, PING_CHIP),
		'The FIRST Ping\'s window ended here, but the second chip is its own and stands...')
	assert_eq(targets_accuracy(), -1, '...Impaired.')
	await SpecFactory.start_turn(game, naga)
	await SpecFactory.end_turn(game, naga)
	assert_false(UnitCondition.has_buff(target, PING_CHIP), 'The second window ends a turn later.')

## Two targets, two windows: the second Ping's clock must not replace the first's (the clocks stack).
func test_pinging_a_second_target_leaves_the_first_window_running() -> void:
	var second := NagaFixture.create_hostile(game, Vector2i(9, 8))
	await ping()
	await SpecFactory.end_turn(game, naga)
	await ping(second)
	assert_true(UnitCondition.has_buff(second, PING_CHIP), 'LIVENESS: the second target has its window.')
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'The first target\'s window is still running...')
	assert_eq(targets_accuracy(), -1, '...Impaired.')
	await SpecFactory.end_turn(game, naga)
	assert_false(UnitCondition.has_buff(target, PING_CHIP), 'The first window ends at the end of this turn...')
	assert_true(UnitCondition.has_buff(second, PING_CHIP), '...the second a turn later.')

## "if the target has Lock On" is read throughout the window: a lock regained inside it brings the
## Impaired back. The relock is a vanilla Lock On by an ally - a real apply, so its statuses_changed
## PRE fires (lock_by_hand's dummy event has no block and would drop it).
func test_a_relock_inside_the_window_brings_the_impaired_back() -> void:
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	await ping()
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	assert_eq(targets_accuracy(), 0, 'CONTROL: the lock is gone and so is the Impaired.')
	await NagaFixture.lock_on(game, ally, target)
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally\'s Lock On landed.')
	assert_eq(targets_accuracy(), -1, 'Locked On again inside the window: Impaired again.')
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	assert_eq(targets_accuracy(), 0, 'And it goes again with the second lock.')

func test_after_the_window_a_relock_does_not_impair() -> void:
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	await ping()
	await SpecFactory.end_turn(game, naga)
	await SpecFactory.start_turn(game, naga)
	await SpecFactory.end_turn(game, naga)
	assert_false(UnitCondition.has_buff(target, PING_CHIP), 'LIVENESS: the window is over.')
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	await NagaFixture.lock_on(game, ally, target)
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally\'s Lock On landed.')
	assert_eq(targets_accuracy(), 0, 'Locked On after the window: not Impaired.')

## Two stacked LOCKON conditions (apply_status APPENDS, unit_condition.gd:104-105): a SOURCE-SPECIFIC
## clear takes one (clear_status with a source, :310-324) and fires a POST while the other remains.
## The target still has Lock On, so it is still Impaired.
func test_a_stacked_lock_losing_one_copy_stays_impaired() -> void:
	await ping()
	SpecFactory.apply(target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, 'second')
	assert_eq(lockon_count(target), 2, 'fixture: two LOCKON conditions.')
	await NagaFixture.clear_by_ability(game, target, Lancer.STATUS.LOCKON) # the Ping's own, first
	assert_eq(lockon_count(target), 1, 'LIVENESS: one copy went.')
	assert_eq(targets_accuracy(), -1, 'Still Locked On, so still Impaired.')
	await NagaFixture.clear_by_ability(game, target, Lancer.STATUS.LOCKON)
	assert_eq(lockon_count(target), 0, 'LIVENESS: the other went too.')
	assert_eq(targets_accuracy(), 0, 'No Lock On: no Impaired.')

## THE MEASUREMENT behind the Ping's relock refusal. A plain apply_status STACKS a second LOCKON
## (unit_condition.gd:104-105 appends unconditionally). A SOURCE-SPECIFIC clear removes only the
## copies with that source, so one survives it. Stabilize itself (clear_status_via_ability,
## :479-483) walks EVERY copy and takes both - measured here too, so neither claim rests on the
## wrong clear.
func test_measured_a_raw_second_lockon_stacks_and_survives_one_sourced_clear() -> void:
	SpecFactory.apply(target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, 'first')
	SpecFactory.apply(target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, 'second')
	assert_eq(lockon_count(target), 2, 'MEASURED: two LOCKON conditions.')
	await NagaFixture.clear_by_ability(game, target, Lancer.STATUS.LOCKON)
	assert_eq(lockon_count(target), 1, 'MEASURED: one source-specific clear leaves the other standing.')
	SpecFactory.apply(target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, 'third')
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	assert_eq(lockon_count(target), 0, 'MEASURED: a Stabilize-shaped clear takes every copy.')

## AN INVADE ON A LOCKED TARGET RAISES VANILLA'S CONSUME PROMPT - tech attacks consume through the
## same attack_declared reaction as weapons (Snow Crash; design section 7). Two cases, then:
##
## DECLINED (chosen_yesnos = false - vanilla's own knob, spec_factory.gd:376; it also declines Wire
## Slither's offer, which nothing here reads): the first lock stays, and the Ping's relock is REFUSED
## by Lockon.apply - one condition, the first source. This is the case the ruling exists for.
func test_a_ping_on_a_locked_target_that_keeps_its_lock_does_not_stack_a_second() -> void:
	NagaFixture.lock_by_hand(naga, target)
	var first_source := NagaFixture.source_of_status(target, Lancer.STATUS.LOCKON)
	SpecFactory.current_responder.chosen_yesnos = false
	await ping()
	assert_eq(lockon_count(target), 1, 'ONE condition: the Ping locks through Lockon.apply, which refuses a relock.')
	assert_eq(NagaFixture.source_of_status(target, Lancer.STATUS.LOCKON), first_source, 'The first lock\'s source is kept.')
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'The chip still hangs - "if the target has Lock On".')
	assert_eq(targets_accuracy(), -1, 'Impaired.')
	await NagaFixture.clear_like_stabilize(game, target, Lancer.STATUS.LOCKON)
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'And ONE Stabilize clears it all.')
	assert_eq(targets_accuracy(), 0, 'Impaired gone with it.')

## CONSUMED (the stock yes): the invade spends the old lock for its +1, and the Ping's hit locks the
## target afresh, as Wide Gaze Networks' own. Still one condition.
func test_a_ping_that_consumes_an_existing_lock_relocks_it_as_its_own() -> void:
	NagaFixture.lock_by_hand(naga, target)
	await ping()
	assert_eq(lockon_count(target), 1, 'One condition.')
	assert_eq(NagaFixture.source_of_status(target, Lancer.STATUS.LOCKON), wgn.persistent_id,
		'The old lock was consumed by the invade and the hit relocked as Wide Gaze Networks\'.')
	assert_true(UnitCondition.has_buff(target, PING_CHIP), 'The chip hangs.')


# ---------------------------------------------------------------- Hypnotize

func test_a_hypnotize_scans_and_hangs_the_chip() -> void:
	assert_true(Scanpedia.is_anything_unscanned(target), 'CONTROL: the target starts unscanned.')
	await hypnotize()
	assert_false(Scanpedia.is_anything_unscanned(target), 'The hit scanned it.')
	var chip := UnitCondition.get_buff(target, HYPNOTIZED)
	assert_not_null(chip, 'buff_hypnotized hangs on the target.')
	if chip: assert_false(chip.base.hide_from_player, 'Visibly.')

func test_an_allys_rifle_rolls_against_the_lower_e_defense() -> void:
	defences(target, 8, 10)
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	NagaFixture.arm_rifle(ally)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	var pre := pre_attack(ally)
	assert_eq(pre.against, AttackRoll.ATTACK_TYPE.TECH, 'The ally\'s rifle is Smart for this target...')
	assert_eq(pre.target_defense, 8, '...and rolls against E-DEF 8, the lower one.')

func test_against_a_lower_evasion_nothing_changes() -> void:
	defences(target, 10, 8)
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	NagaFixture.arm_rifle(ally)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	var pre := pre_attack(ally)
	assert_eq(pre.against, AttackRoll.ATTACK_TYPE.WEAPON, 'Evasion is already the lower: the rifle stays a rifle...')
	assert_eq(pre.target_defense, 8, '...against Evasion 8.')

func test_the_nagas_own_rifle_is_smart_against_the_target() -> void:
	defences(target, 8, 10)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	var pre := pre_attack(naga)
	assert_eq(pre.against, AttackRoll.ATTACK_TYPE.TECH, 'The Naga benefits too ("allied characters", self included).')
	assert_eq(pre.target_defense, 8, 'Against E-DEF 8.')

## AUTHOR DECISION 2 (2026-09-23): a drone is not a character, but where it attacks it attacks as
## its OWNER (mod-wide row 301, Draw Fire's rule) - Unit.get_attacker, unit.gd:276-282.
func test_an_allied_drone_attacks_as_its_owner() -> void:
	defences(target, 8, 10)
	var ally := NagaFixture.create_ally(game, Vector2i(12, 8))
	var drone := NagaFixture.own_drone(NagaFixture.create_drone(game, ALLY_TILE), ally)
	NagaFixture.arm_rifle(drone)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_true(UnitCondition.has_buff(drone, TARGETING), 'LIVENESS: the aura reaches the drone.')
	assert_true(rifle_is_smart(drone, target), 'Its owner is an allied character, so its rifle is Smart here.')
	var pre := pre_attack(drone)
	assert_eq(pre.target_defense, 8, 'And it rolls against E-DEF 8, the lower one.')

func test_an_unowned_drone_does_not_benefit() -> void:
	defences(target, 8, 10)
	var drone := NagaFixture.create_drone(game, ALLY_TILE)
	NagaFixture.arm_rifle(drone)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_true(UnitCondition.has_buff(drone, TARGETING), 'LIVENESS: the aura reaches the drone.')
	assert_false(rifle_is_smart(drone, target), 'No owner: get_attacker is the drone itself, not a character.')

func test_a_drone_whose_owner_is_hostile_does_not_benefit() -> void:
	defences(target, 8, 10)
	var hostile_owner := NagaFixture.create_hostile(game, Vector2i(20, 8))
	var drone := NagaFixture.own_drone(NagaFixture.create_drone(game, ALLY_TILE), hostile_owner)
	NagaFixture.arm_rifle(drone)
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_true(UnitCondition.has_buff(drone, TARGETING), 'LIVENESS: the drone is on our side, so the aura reaches it.')
	assert_false(rifle_is_smart(drone, target), 'Its attack is its hostile owner\'s - not an ALLIED character\'s.')

## Slice 3 #7: the hit pops vanilla Scan's own text (action_scan.gd:32).
func test_the_hypnotize_scan_pops_the_vanilla_scan_text() -> void:
	var bus:EffectsControllerBus = load('res://engine/gamemaster/effects_controller/effects_controller_bus.tres')
	var popped:Array[String] = []
	var record := func(text:String, _tile:Vector2i, _large:bool) -> void: popped.append(text)
	bus.on_play_text.connect(record)
	await hypnotize()
	bus.on_play_text.disconnect(record)
	assert_true(popped.has(tr('gear.ms_scan.action_scan.pop')), 'The scan pops "%s".' % tr('gear.ms_scan.action_scan.pop'))

func test_no_chip_no_smart_and_no_leak_onto_the_sheet() -> void:
	defences(target, 8, 10)
	var ally := NagaFixture.create_ally(game, ALLY_TILE)
	NagaFixture.arm_rifle(ally)
	UnitTile.update_tracking_and_statuses(game.map)
	assert_false(rifle_is_smart(ally, target), 'CONTROL: without the chip the ally\'s rifle is not Smart.')
	await hypnotize()
	UnitTile.update_tracking_and_statuses(game.map)
	assert_true(rifle_is_smart(ally, target), 'LIVENESS: against the Hypnotized target it is.')
	assert_false(rifle_is_smart(ally, null), 'With no target in context (the sheet) it is not.')
	var other := NagaFixture.create_hostile(game, Vector2i(9, 8))
	NagaFixture.set_edef(other, 8) # full_repair on OTHER only; the Hypnotized target is untouched
	assert_false(rifle_is_smart(ally, other), 'Against a different, un-Hypnotized hostile it is not.')

func test_the_targets_quick_check_clears_on_a_success() -> void:
	await hypnotize()
	await SpecFactory.end_turn(game, naga)
	await SpecFactory.start_turn(game, target)
	var offered := UnitAction.get_situational_actions(target).any(
		func(s) -> bool: return s.action.get_id() == CLEAR)
	assert_true(offered, 'The Hypnotized target is offered the clear.')
	NagaFixture.queue([CHECK_PASSES])
	await SpecFactory.use(game, target, KIT_ID, CLEAR)
	assert_false(UnitCondition.has_buff(target, HYPNOTIZED), 'A passed Systems check clears it.')

func test_the_targets_quick_check_keeps_it_on_a_fail() -> void:
	await hypnotize()
	await SpecFactory.end_turn(game, naga)
	await SpecFactory.start_turn(game, target)
	NagaFixture.queue([CHECK_FAILS])
	await SpecFactory.use(game, target, KIT_ID, CLEAR)
	assert_true(UnitCondition.has_buff(target, HYPNOTIZED), 'A failed check leaves it.')
