## BINDING FANGS, the Naga's rank-II weapon (SP3 Task 1, design ruling 14).
##
## "Auxiliary Melee, SP 1. THROWN 5, SMART, SEEKING, LIMITED 2. 1d3 Kinetic, Threat 1.
##  Effect: You may attack with this weapon without expending or requiring charges, and this weapon
##  can be destroyed (due to critical damage or other effects) even if it has no charges remaining.
##  On hit: You may expend a charge. If you do, you take 1 Heat, and the target becomes Locked On."
##  (specs/sixth-voice/10-naga.md, Rank II)
##
## DICE: a Smart melee weapon with no accuracy modifier pops the attack d20, then the one d3. THE
## NAGA'S SMART WEAPONS CRIT ON 18 (Advanced Targeting Calculations), so every "plain hit" here rolls
## 12 against E-DEF 8 - never the fixture's cheat_a_hit 19, which would be a crit on this frame.
##
## PROMPTS: the queue responder (NagaFixture.create_game_with_prompt_queues) records every yes/no and
## answers them front to back, so "was not offered" is an assertion on what it SAW, not on a default.
## The Fangs' own prompt is titled with the Kit's name (battle.confirm.use), which is the filter.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'mw_binding_fangs'
const ACTION_ID := &'action_binding_fangs'

const NAGA_TILE := Vector2i(4, 4)    # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(6, 4)  # adjacent to the Naga's east edge - inside Threat 1
const TARGET_EDEF := 8
const TARGET_EVASION := 15           # far above E-DEF, so a roll against the wrong one misses

const A_HIT := 12                    # beats E-DEF 8, short of the frame's crit threshold 18
const A_MISS := 2

var game:Gamemaster
var responder
var naga:Unit
var target:Unit
var fangs:GearCore


func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE, TARGET_EVASION)
	NagaFixture.set_edef(target, TARGET_EDEF)
	fangs = NagaFixture.equip(naga, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


## One swing through a real event_gear_activate, the Blade spec's `swing`, answering the yes/no
## prompts it raises from `answers` in order. Returns the roll, or null when no attack was rolled.
func swing(rolls:Array[int], answers:Array[bool] = [], at:Unit = target) -> AttackRoll:
	await NagaFixture.cycle_turn(game, naga)
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array(answers)
	responder.yesno_prompts.clear()
	NagaFixture.queue(rolls)
	var core := EventCore.create(&'event_gear_activate', {
		action = fangs.get_solo_action(), gear = fangs, unit = naga, target_unit = at,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	if summary == null or summary.attack_rolls.is_empty(): return null
	return summary.attack_rolls[0]

## The yes/no prompts the FANGS raised (titled with the Kit's name) - any other one is a consume.
func fangs_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	var fangs_name:String = X.tr('gear.mw_binding_fangs.name')
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(fangs_name): found.append(seen)
	return found


# ---------------------------------------------------------------- wiring

func test_the_fangs_are_an_auxiliary_melee_smart_seeking_thrown_weapon() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes the Fangs under their mw_ id.')
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.charges_max, 2, 'LIMITED 2.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var attack := kit.actions[0] as ActionAttackWeapon
	assert_not_null(attack, 'Its one action is an ActionAttackWeapon.')
	if attack == null: return
	assert_eq(attack.get_id(), ACTION_ID)
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.AUX, 'Auxiliary.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.damage_dice, '1d3', '1d3...')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.KINETIC, '...Kinetic.')
	assert_eq(attack.threat, 1, 'Threat 1.')
	assert_eq(attack.thrown, 5, 'Thrown 5.')
	assert_eq(attack.tags, [&'thrown', &'smart', &'seeking'] as Array[StringName],
		'THROWN, SMART and SEEKING in the card order (LIMITED is the Kit\'s charges_max, not a tag).')

func test_the_licence_grants_the_fangs_at_rank_2() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_2.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'li_naga rank 2 grants the Binding Fangs.')

func test_the_rows_resolve_through_the_mods_translation() -> void:
	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	assert_eq(String(translation.get_message('gear.mw_binding_fangs.name')), 'Binding Fangs')
	for key:String in ['gear.mw_binding_fangs.flavor', 'gear.mw_binding_fangs.effect', 'gear.mw_binding_fangs.on_hit']:
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)


# ---------------------------------------------------------------- charges are optional

func test_the_fangs_attack_with_no_charges_left() -> void:
	fangs.charges_current = 0
	var roll := await swing([A_HIT])
	assert_not_null(roll, '"without ... requiring charges" - an empty Fangs still swings.')
	if roll == null: return
	assert_true(roll.hit, 'LIVENESS: and it hits.')
	assert_eq(fangs.charges_current, 0, 'Nothing to spend, nothing spent.')

func test_a_swing_does_not_expend_a_charge_by_itself() -> void:
	var roll := await swing([A_MISS])
	assert_not_null(roll, 'LIVENESS: the swing rolled.')
	assert_eq(fangs.charges_current, 2, '"without expending ... charges" - a miss leaves both.')


# ---------------------------------------------------------------- the on-hit lock

func test_a_hit_with_a_charge_offers_and_a_yes_locks_for_a_charge_and_a_heat() -> void:
	var heat := naga.core.current.heat
	var roll := await swing([A_HIT], [true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_false(roll.crit, 'LIVENESS: not a crit (12 is short of ATC\'s 18).')
	assert_eq(fangs_prompts().size(), 1, 'The Fangs offered their charge once.')
	assert_eq(fangs.charges_current, 1, 'A yes expends one charge.')
	assert_eq(naga.core.current.heat, heat + 1, 'You take 1 Heat.')
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'And the target becomes Locked On.')
	assert_eq(Lockon.source_of(target), fangs.persistent_id, 'The lock is the Fangs\' own.')

func test_a_no_spends_nothing() -> void:
	var heat := naga.core.current.heat
	var roll := await swing([A_HIT], [false])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(fangs_prompts().size(), 1, 'LIVENESS: the Fangs offered.')
	assert_eq(fangs.charges_current, 2, 'A no keeps both charges.')
	assert_eq(naga.core.current.heat, heat, 'No heat.')
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'No lock.')

func test_a_miss_does_not_offer() -> void:
	await swing([A_MISS], [true])
	assert_eq(fangs_prompts().size(), 0, 'On hit only.')
	assert_eq(fangs.charges_current, 2, 'Nothing spent.')

func test_an_empty_fangs_does_not_offer() -> void:
	fangs.charges_current = 0
	var heat := naga.core.current.heat
	var roll := await swing([A_HIT], [true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_eq(fangs_prompts().size(), 0, '"You may expend a charge" - there is none to expend.')
	assert_eq(naga.core.current.heat, heat, 'No heat.')
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'No lock.')

## Ruling 14: the card would let you pay for a lock that changes nothing, so the prompt is a trap.
## The existing lock is declined for consumption (the consume prompt is the FIRST yes/no), so it is
## still there when the hit lands.
func test_an_already_locked_target_is_not_offered() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked beforehand.')
	var roll := await swing([A_HIT], [false, true]) # decline the consume; a stray yes would pay
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the old lock was kept.')
	assert_eq(fangs_prompts().size(), 0, 'Not offered against a target already Locked On.')
	assert_eq(fangs.charges_current, 2, 'Nothing spent.')
	assert_eq(Lockon.source_of(target), naga.get_gear(NagaFixture.LOCK_ON).persistent_id,
		'The lock is still the original one.')

## Consumed by this very swing (the consume runs at ATTACK_DECLARED PRE), the target is unlocked
## again by the time the hit lands, so the Fangs lock it anew - the loop the card is built for.
func test_a_consumed_lock_is_relocked_by_the_same_swing() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked beforehand.')
	# the consume's +1 accuracy pops one d6 after the d20
	var roll := await swing([A_HIT, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_true(AttackRoll.check(roll, &'consumed_lock'), 'LIVENESS: the swing consumed the lock.')
	assert_eq(fangs_prompts().size(), 1, 'The Fangs offer on the now-unlocked target.')
	assert_eq(Lockon.source_of(target), fangs.persistent_id, 'Relocked as the Fangs\' own.')


# ---------------------------------------------------------------- seeking

func test_seeking_needs_no_line_of_sight_and_ignores_cover() -> void:
	var action := fangs.get_solo_action() as ActionAttackWeapon
	var specific := SpecificAction.create(naga, fangs, action)
	assert_false(action.requires_line_of_sight(specific), 'SEEKING: no line of sight needed.')
	assert_true(action.ignores_cover(specific.to_context({target_unit = target})), 'SEEKING: cover ignored.')


# ---------------------------------------------------------------- destructible at zero

func test_the_fangs_are_destructible_with_a_charge() -> void:
	assert_true(UnitPrinter.get_destructable_gear([fangs]).has(fangs), 'A licensed weapon can be shot off.')

func test_the_fangs_are_destructible_at_zero_charges() -> void:
	fangs.charges_current = 0
	assert_false(fangs.has_charges_left(), 'fixture: empty.')
	assert_true(UnitPrinter.get_destructable_gear([fangs]).has(fangs),
		'"can be destroyed ... even if it has no charges remaining" - the whitelist says so.')
	assert_true(LoadoutCore.get_destructable_gear([fangs]).has(fangs),
		'And through LoadoutCore\'s delegation (loadout_core.gd:575-576).')
