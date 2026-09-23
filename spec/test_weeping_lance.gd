## WEEPING LANCE, the Naga's rank-III weapon (SP4 Task 1, design ruling 18).
##
## "Heavy Melee, SP 1. SMART, AP, THROWN 5. 1d6+3 Kinetic, Threat 2.
##  Effect: When you attack with this weapon and consume Lock On, you may choose to forgo the +1
##  Accuracy from Lock On. If you do, the weapon damage becomes 2d6 + 4."
##  (specs/sixth-voice/10-naga.md, Rank III)
##
## THE FORGO PROFILE IS A VARIANT SUB-MENU ENTRY (ruling 18, author). A spec picks it the way
## SpecFactory.use_solo's desired_variant does: context.string names the key, and
## event_gear_activate.enforce_required_variants (:135-141) filters the group down to it and makes it
## non-blankable, so the responder's default index 0 IS the forgo entry. The Thrown group is left
## alone and its blank is taken.
##
## DICE. A Smart weapon with no net accuracy pops the attack d20, then the damage dice TWICE - the
## hit set and the crit set are both rolled (attack_util.gd:251-252). 1d6+3 pops two d6, 2d6+4 pops
## four. A PLAIN consume adds +1 accuracy and so pops one accuracy d6 between the d20 and the damage;
## the FORGO profile nets 0 and pops none. Every hit rolls 12 against E-DEF 8: short of Advanced
## Targeting Calculations' 18, so never a crit. The dummy has armor 0 and 200 HP, so damage is the
## HP it loses.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const WeepingLance := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/weapons/mw_weeping_lance/action_weeping_lance.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'mw_weeping_lance'
const ACTION_ID := &'action_weeping_lance'
const FORGO := &'weeping_lance_forgo'
const GROUP := &'weeping_lance'

const NAGA_TILE := Vector2i(4, 4)    # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(7, 4)  # two from the Naga's east edge - Threat 2, not Threat 1
const OTHER_TILE := Vector2i(7, 7)   # a second hostile, for the targeting cases
const TARGET_EDEF := 8
const TARGET_EVASION := 15           # far above E-DEF, so a roll against the wrong one misses

const A_HIT := 12

var game:Gamemaster
var responder
var naga:Unit
var target:Unit
var lance:GearCore


func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE, TARGET_EVASION)
	NagaFixture.set_edef(target, TARGET_EDEF)
	lance = NagaFixture.equip(naga, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


## One swing through a real event_gear_activate; `variant` names the forgo key or leaves it plain.
## Returns the roll, or null when no attack was rolled.
func swing(rolls:Array[int], answers:Array[bool] = [], variant:StringName = &'', at:Unit = target) -> AttackRoll:
	await NagaFixture.cycle_turn(game, naga)
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array(answers)
	responder.yesno_prompts.clear()
	NagaFixture.queue(rolls)
	var core := EventCore.create(&'event_gear_activate', {
		action = lance.get_solo_action(), gear = lance, unit = naga, target_unit = at, string = variant,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	if summary == null or summary.attack_rolls.is_empty(): return null
	return summary.attack_rolls[0]

## The vanilla consume prompts the responder saw (titled battle.confirm.consume_lock).
func consume_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	var translated:String = X.tr('battle.confirm.consume_lock')
	for seen:Dictionary in responder.yesno_prompts:
		var title := String(seen.get('title', ''))
		if title.contains('consume_lock') or title.contains(translated): found.append(seen)
	return found

func forgo_entry() -> VariantAction:
	var specific := SpecificAction.create(naga, lance, lance.get_solo_action())
	for group:VariantActionGroup in lance.get_solo_action().get_alternate_actions(specific):
		if group.key == GROUP:
			for variant:VariantAction in group.list:
				if variant.key == FORGO: return variant
	return null

func forgo_specific() -> SpecificAction:
	var specific := SpecificAction.create(naga, lance, lance.get_solo_action())
	for variant:SpecificAction in VariantActionGroup.get_variant_specifics(specific):
		if WeepingLance.is_forgo(variant.action): return variant
	return null


# ---------------------------------------------------------------- wiring

func test_the_lance_is_a_heavy_melee_smart_ap_thrown_weapon() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes the Lance under its mw_ id.')
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.charges_max, 0, 'Not Limited.')
	var attack := kit.actions[0] as ActionAttackWeapon
	assert_not_null(attack, 'Its first action is the attack (get_solo_action).')
	if attack == null: return
	assert_eq(attack.get_id(), ACTION_ID)
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'Heavy.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.damage_dice, '1d6+3', '1d6+3...')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.KINETIC, '...Kinetic.')
	assert_eq(attack.threat, 2, 'Threat 2.')
	assert_eq(attack.thrown, 5, 'Thrown 5.')
	assert_eq(attack.tags, [&'smart', &'ap', &'thrown'] as Array[StringName], 'SMART, AP, THROWN in the card order.')
	assert_eq(kit.get_reactions().size(), 1, 'One hidden reaction: the forgo profile\'s forced consume.')

func test_the_licence_grants_the_lance_at_rank_3() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_3.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'li_naga rank 3 grants the Weeping Lance.')

func test_the_rows_resolve_through_the_mods_translation() -> void:
	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	assert_eq(String(translation.get_message('gear.mw_weeping_lance.name')), 'Weeping Lance')
	for key:String in ['gear.mw_weeping_lance.flavor', 'gear.mw_weeping_lance.effect']:
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)


# ---------------------------------------------------------------- the plain profile

func test_the_plain_profile_hits_for_1d6_plus_3_at_threat_2() -> void:
	var hp:int = target.core.current.health
	var roll := await swing([A_HIT, 4, 1])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit at Threat 2.')
	assert_false(roll.crit, 'LIVENESS: not a crit.')
	assert_eq(hp - target.core.current.health, 7, '1d6+3: a 4 deals 7.')

func test_the_plain_profile_still_offers_the_consume_and_a_no_keeps_the_lock() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked beforehand.')
	var roll := await swing([A_HIT, 4, 1], [false])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(consume_prompts().size(), 1, 'Vanilla\'s consume yes/no is raised for the plain profile.')
	assert_true(target.has_status(Lancer.STATUS.LOCKON), 'Declined: the lock stays.')
	assert_false(roll.consumed_lock, 'Nothing consumed.')


# ---------------------------------------------------------------- the forgo profile

func test_the_forgo_entry_is_greyed_out_with_no_locked_hostile() -> void:
	var entry := forgo_entry()
	assert_not_null(entry, 'The Lance offers a forgo entry in its own sub-menu.')
	if entry == null: return
	assert_true(entry.is_disabled, 'Nobody is Locked On: the entry is shown but cannot be picked.')

func test_a_locked_ally_does_not_enable_the_forgo_entry() -> void:
	var ally := NagaFixture.create_ally(game, Vector2i(7, 8))
	UnitCondition.apply_status(SpecFactory.dummy_event({unit = naga}), ally, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, &'')
	assert_true(ally.has_status(Lancer.STATUS.LOCKON), 'fixture: the ally is Locked On.')
	var entry := forgo_entry()
	if entry == null: return fail_test('fixture: no forgo entry.')
	assert_true(entry.is_disabled, 'Only a HOSTILE\'s lock can be consumed, so an ally\'s does not count.')

func test_a_locked_hostile_enables_the_forgo_entry() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var entry := forgo_entry()
	if entry == null: return fail_test('fixture: no forgo entry.')
	assert_false(entry.is_disabled, 'A hostile is Locked On: the entry can be picked.')

func test_the_forgo_profile_can_target_only_a_locked_hostile() -> void:
	var other := NagaFixture.create_hostile(game, OTHER_TILE)
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: one hostile locked.')
	var forgo := forgo_specific()
	assert_not_null(forgo, 'The sub-menu builds a forgo profile.')
	if forgo == null: return
	assert_eq((forgo.action as ActionAttackWeapon).damage_dice, '2d6+4', 'Its damage becomes 2d6 + 4.')
	assert_true(forgo.action.can_target_unit(target, forgo), 'A Locked On hostile is a target.')
	assert_false(forgo.action.can_target_unit(other, forgo), 'An unlocked hostile is not.')
	var plain := SpecificAction.create(naga, lance, lance.get_solo_action())
	assert_true(plain.action.can_target_unit(other, plain), 'The plain profile targets anybody.')

## "Consume Lock On" means a HOSTILE's lock: vanilla's consume refuses a non-enemy
## (action_consume_lock_on.gd:62-67), so forgoing against a Locked On ally would consume nothing and
## still take the -1 and the 2d6+4.
func test_a_locked_ally_is_not_a_forgo_target() -> void:
	var ally := NagaFixture.create_ally(game, OTHER_TILE)
	UnitCondition.apply_status(SpecFactory.dummy_event({unit = naga}), ally, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, &'')
	assert_true(ally.has_status(Lancer.STATUS.LOCKON), 'fixture: the ally is Locked On.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: a hostile is locked too, so the entry is live.')
	var forgo := forgo_specific()
	if forgo == null: return fail_test('fixture: no forgo profile.')
	var plain := SpecificAction.create(naga, lance, lance.get_solo_action())
	assert_true(plain.action.can_target_unit(ally, plain), 'LIVENESS: the plain profile can target the ally.')
	assert_true(forgo.action.can_target_unit(target, forgo), 'LIVENESS: the locked hostile is a forgo target.')
	assert_false(forgo.action.can_target_unit(ally, forgo), 'A Locked On ALLY is not a forgo target.')

## The attack preview (attack_preview.gd:46-48) builds PreAttack from the forgo action BEFORE the
## consume, when the target carries no buff_lock_consumed yet: the +1 is not there to cancel, so the
## -1 must not be either, or the preview shows the swing a point worse than it will roll.
func test_the_attack_preview_shows_the_forgo_swing_at_net_zero() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked, not yet consumed.')
	var forgo := forgo_specific()
	if forgo == null: return fail_test('fixture: no forgo profile.')
	var tiles:Array[Vector2i] = [target.tile()]
	var virtual_declared := DeclaredAttackSummary.create(
		[target], target.occupied_tiles(), target.occupied_tiles(),
		forgo.action.get_origin_voxels(forgo, tiles, naga.tile()))
	# attack_preview.gd:114-122, verbatim in shape
	var preattack := AttackRoll.PreAttack.create(Context.create({
		unit = forgo.unit.get_attacker(forgo), target_unit = target, gear = forgo.gear,
		action = forgo.action, resource = virtual_declared, flags = [],
	}))
	assert_true(preattack.target_is_locked_on, 'LIVENESS: the preview sees the lock.')
	assert_false(UnitCondition.has_buff(target, &'buff_lock_consumed'), 'LIVENESS: nothing consumed yet.')
	assert_eq(preattack.accuracy_mods_total(), 0, 'The preview nets 0, as the real forgo roll does.')

func test_the_forgo_profile_consumes_without_asking_and_trades_the_accuracy_for_2d6_plus_4() -> void:
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked beforehand.')
	var hp:int = target.core.current.health
	# d20, then 2d6 hit set (3, 5), then 2d6 crit set - no accuracy die: the +1 and the -1 cancel
	var roll := await swing([A_HIT, 3, 5, 1, 1], [false, false], FORGO)
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_false(roll.crit, 'LIVENESS: not a crit.')
	assert_eq(consume_prompts().size(), 0, 'The forgo profile never asks: declining is impossible.')
	assert_false(target.has_status(Lancer.STATUS.LOCKON), 'The lock was consumed.')
	assert_true(roll.consumed_lock, 'consumed_lock is on the roll - BATS and the core passive see it.')
	assert_eq(roll.pre.accuracy_mods_total(), 0, 'The +1 from Lock On is forgone (a +1 and a -1).')
	assert_eq(hp - target.core.current.health, 12, '2d6 + 4: a 3 and a 5 deal 12.')
	assert_true(roll.pre.accuracy_mods.any(func(mod) -> bool: return mod.mod == 1),
		'The consumed lock\'s +1 is still there, cancelled rather than removed.')
