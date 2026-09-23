## BOUNDED AUTOMATIC TARGETING SYSTEMS, the Naga's rank-III weapon mod (SP4 Task 2).
##
## "SP 2, LIMITED 2. Melee, Rifle or Nexus; Auxiliary, Main or Heavy - not Superheavy.
##  1/round, when you hit with an attack that consumed Lock On you may expend a charge, if you do, the
##  hit is treated as a Critical Hit. Resulting damage is not rolled twice. If the hit was already
##  Critical, you deal the maximum possible damage."  (specs/sixth-voice/10-naga.md, Rank III)
##
## THE SHAPE (author, 2026-09-23, superseding ruling 19's arm-at-declaration): one OnHitEffect on the
## mod at the ON_ATTACK stage, which asks AFTER the roll, on a hit only. "Not rolled twice" is a
## recorded divergence: a BATS crit takes the higher damage set like any crit.
##
## DICE. The rifle (MAIN RIFLE 1d6, RELIABLE 2) pops the attack d20, then - when a Lock On is
## consumed - one accuracy d6 for buff_lock_consumed's +1, then the damage d6 TWICE (the hit set and
## the crit set, attack_util.gd:251-252). The target's EVASION is 10; a 12 plus the accuracy die's 1
## is a plain 13 hit, a natural 20 a crit. The fixture's tail of 1s keeps every unplanned die harmless.
##
## PROMPTS: the queue responder. A player's consume yes/no comes FIRST (answer true to consume), then
## the BATS yes/no, titled with the Kit's name - which is the filter.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const OnHitBats := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/wm_bounded_automatic_targeting_systems/onhit_bounded_automatic_targeting_systems.gd')

const TRANSLATION_PATH := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'wm_bounded_automatic_targeting_systems'
const RIFLE := &'mw_assault_rifle'      # MAIN RIFLE
const NEXUS := &'mw_nexus_light'        # AUX NEXUS, Smart
const LANCE := &'mw_weeping_lance'      # HEAVY MELEE, Smart
const PISTOL := &'mw_pistol'            # AUX CQB - the wrong type
const DRILL := &'mw_combat_drill'       # SUPERHEAVY MELEE - the wrong size
const ANNIHILATION := &'mw_annihilation_nexus' # SUPERHEAVY NEXUS

const NAGA_TILE := Vector2i(4, 4)    # size 2: (4,4)-(5,5)
const TARGET_TILE := Vector2i(9, 4)  # four from the Naga's east edge: inside the rifle's range, not engaged
const TARGET_EVASION := 10
const TARGET_EDEF := 8

const A_HIT := 12
const A_CRIT := 20
const A_MISS := 2

var game:Gamemaster
var responder
var naga:Unit
var target:Unit


func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	target = NagaFixture.create_hostile(game, TARGET_TILE, TARGET_EVASION)
	NagaFixture.set_edef(target, TARGET_EDEF)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


## Equip a weapon, put BATS on it, and repair so the mod has its charges. Returns [weapon, mod] as
## they are AFTER the repair, found again by persistent id (full_repair keeps both ids -
## test/unit/test_loadout.gd's preserve-mods case). null mod = the engine refused to fit it.
func mount(weapon_id:StringName) -> Array:
	var weapon := NagaFixture.equip(naga, weapon_id)
	var mod := naga.core.loadout.equip_weapon_mod(KIT_ID, weapon)
	if not GearCore.is_valid(mod): return [weapon, null]
	var weapon_id_p := weapon.persistent_id
	var mod_id_p := mod.persistent_id
	SpecFactory.apply_passive_buffs(naga)
	return [naga.core.loadout.get_by_persistent_id(weapon_id_p), naga.core.loadout.get_by_persistent_id(mod_id_p)]

## One attack with `weapon` in a freshly opened turn (or, with again = true, a freebie in the SAME
## turn - the only way to test a 1/round without cycling the tallies away). Answers yes/no prompts
## from `answers` in order. Returns the roll, or null when none was rolled.
func attack(weapon:GearCore, rolls:Array[int], answers:Array[bool], again:bool = false) -> AttackRoll:
	if not again: await NagaFixture.cycle_turn(game, naga)
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array(answers)
	responder.yesno_prompts.clear()
	NagaFixture.queue(rolls)
	var flags:Array = [Action.FLAG.AS_FREEBIE] if again else []
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = naga, target_unit = target, flags = flags,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	if summary == null or summary.attack_rolls.is_empty(): return null
	return summary.attack_rolls[0]

func bats_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	var bats_name:String = X.tr('gear.%s.name' % KIT_ID)
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(bats_name): found.append(seen)
	return found

func damage_taken() -> int: return target.core.get_health_max() - target.core.current.health


# ---------------------------------------------------------------- wiring

func test_bats_is_an_sp2_limited_2_weapon_mod_for_melee_rifle_and_nexus() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes BATS under its wm_ id.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 2, 'LIMITED 2.')
	assert_true(kit.actions.is_empty(), 'No action of its own - a weapon mod.')
	var mods := kit.get_passives(PassiveWeaponMod)
	assert_eq(mods.size(), 1, 'One PassiveWeaponMod.')
	if mods.is_empty(): return
	var mod := mods[0] as PassiveWeaponMod
	assert_eq(mod.allowed_types, [Lancer.WEAPON_TYPE.MELEE, Lancer.WEAPON_TYPE.RIFLE, Lancer.WEAPON_TYPE.NEXUS] as Array[Lancer.WEAPON_TYPE])
	assert_eq(mod.allowed_sizes, [Lancer.WEAPON_SIZE.AUX, Lancer.WEAPON_SIZE.MAIN, Lancer.WEAPON_SIZE.HEAVY] as Array[Lancer.WEAPON_SIZE])
	assert_eq(mod.on_hit_effects.size(), 1, 'One on-hit effect.')
	if mod.on_hit_effects.is_empty(): return
	assert_eq(mod.on_hit_effects[0].apply_on, OnHitEffect.STAGE.ON_ATTACK, 'At ON_ATTACK: after the roll, before MAXIMIZE.')
	assert_true(mod.on_hit_effects[0].require_consume_lock, 'Only an attack that consumed Lock On.')

func test_the_licence_grants_bats_at_rank_3() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_3.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'li_naga rank 3 grants BATS.')

func test_the_rows_resolve_through_the_mods_translation() -> void:
	var translation := load(TRANSLATION_PATH) as Translation
	assert_not_null(translation, 'The mod ships a compiled translation.')
	if translation == null: return
	assert_eq(String(translation.get_message('gear.%s.name' % KIT_ID)), 'Bounded Automatic Targeting Systems')
	for field:String in ['flavor', 'effect']:
		var key := 'gear.%s.%s' % [KIT_ID, field]
		assert_ne(String(translation.get_message(key)), '', 'The compiled translation carries %s.' % key)


# ---------------------------------------------------------------- what it fits

func test_it_fits_a_rifle_a_nexus_and_a_heavy_melee() -> void:
	for weapon_id:StringName in [RIFLE, NEXUS, LANCE]:
		var pair := mount(weapon_id)
		assert_not_null(pair[1], 'BATS fits %s.' % weapon_id)

func test_it_refuses_a_superheavy_and_a_cqb() -> void:
	for weapon_id:StringName in [DRILL, ANNIHILATION, PISTOL]:
		var weapon := NagaFixture.equip(naga, weapon_id)
		assert_true(GearCore.is_valid(weapon), 'fixture: %s equipped.' % weapon_id)
		if not GearCore.is_valid(weapon): continue
		var mod := naga.core.loadout.equip_weapon_mod(KIT_ID, weapon)
		assert_null(mod, 'BATS refuses %s.' % weapon_id)


# ---------------------------------------------------------------- a hit becomes a crit

func test_a_consumed_hit_is_offered_and_a_yes_turns_it_into_a_crit_for_a_charge() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	var charges := mod.charges_current
	assert_eq(charges, 2, 'fixture: two charges.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_HIT, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.consumed_lock, 'LIVENESS: the lock was consumed.')
	assert_eq(bats_prompts().size(), 1, 'Offered once, after the hit.')
	assert_true(roll.hit, 'Still a hit...')
	assert_true(roll.crit, '...now treated as a Critical Hit.')
	assert_false(roll.maximized, 'Not maximised - it was not a crit already.')
	assert_eq(mod.charges_current, charges - 1, 'One charge expended.')
	assert_eq(mod.get_uses_this_round_alt(OnHitBats.USAGE_KEY), 1, 'The 1/round is spent.')

func test_a_no_leaves_the_hit_and_the_charge() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_HIT, 1], [true, false])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(bats_prompts().size(), 1, 'LIVENESS: offered.')
	assert_false(roll.crit, 'Declined: a plain hit.')
	assert_eq(mod.charges_current, 2, 'Nothing expended.')
	assert_eq(mod.get_uses_this_round_alt(OnHitBats.USAGE_KEY), 0, 'And the 1/round is not spent.')


# ---------------------------------------------------------------- a crit is maximised

func test_an_already_critical_hit_deals_maximum_damage() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_CRIT, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.crit, 'LIVENESS: a natural 20.')
	assert_eq(bats_prompts().size(), 1, 'Offered on the crit too.')
	assert_true(roll.maximized, 'The crit is maximised.')
	assert_eq(damage_taken(), 6, 'Maximum possible damage: the rifle\'s 1d6 deals 6 (every die rolled 1).')
	assert_eq(mod.charges_current, 1, 'One charge expended.')

## Ruling 3 meets BATS: under Advanced Targeting Calculations a SMART 18 is already a crit by the
## time BATS is asked, so a yes buys maximum damage - measured, the design's last clause for ruling 19.
func test_under_atc_a_smart_18_is_already_a_crit_and_a_yes_maximises_it() -> void:
	var pair := mount(NEXUS)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	# d20 17, accuracy d6 1 -> 18 against E-DEF 8: a crit only because of ATC
	var roll := await attack(pair[0], [17, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(roll.total_roll, 18, 'LIVENESS: an 18.')
	assert_true(roll.crit, 'ATC made it a crit before BATS was asked.')
	assert_true(roll.maximized, 'So BATS maximises it.')
	assert_eq(damage_taken(), 3, 'The Nexus (Light)\'s 1d3 at its maximum.')
	assert_eq(mod.charges_current, 1, 'One charge expended.')


# ---------------------------------------------------------------- not offered

func test_a_miss_is_not_offered() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_MISS, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_false(roll.hit, 'LIVENESS: a miss.')
	assert_true(roll.consumed_lock, 'LIVENESS: the lock was consumed anyway.')
	assert_eq(bats_prompts().size(), 0, '"when you hit" - a miss is never offered.')
	assert_eq(mod.charges_current, 2, 'Nothing expended.')

func test_a_hit_that_consumed_nothing_is_not_offered() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	var roll := await attack(pair[0], [A_HIT], [true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_true(roll.hit, 'LIVENESS: a hit.')
	assert_eq(bats_prompts().size(), 0, 'No Lock On consumed: not offered.')
	assert_false(roll.crit, 'A plain hit.')

func test_a_declined_consume_is_not_offered() -> void:
	var pair := mount(RIFLE)
	if pair[1] == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_HIT], [false, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_false(roll.consumed_lock, 'LIVENESS: the consume was declined.')
	assert_eq(bats_prompts().size(), 0, 'The attack did not consume Lock On: not offered.')

func test_an_empty_mod_is_not_offered() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	mod.charges_current = 0
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_HIT, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(bats_prompts().size(), 0, 'No charge to expend: not offered.')
	assert_false(roll.crit, 'A plain hit.')

func test_a_crit_immune_target_is_not_offered_the_conversion() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	var immune := Buff.new()
	immune.to = Buff.TO.CRIT_IMMUNITY
	UnitCondition.apply_buffs(SpecFactory.dummy_event({unit = target}), target, [immune], null)
	assert_true(UnitCondition.has_buff_to(target, Buff.TO.CRIT_IMMUNITY, Context.create({unit = naga, target_unit = target})),
		'fixture: the target is crit-immune.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var roll := await attack(pair[0], [A_HIT, 1], [true, true])
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(bats_prompts().size(), 0, 'A crit it cannot take would waste the charge: not offered.')
	assert_eq(mod.charges_current, 2, 'Nothing expended.')


# ---------------------------------------------------------------- 1/round

func test_a_second_consumed_hit_in_the_same_round_is_not_offered() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	var first := await attack(pair[0], [A_HIT, 1], [true, true])
	if first == null or not first.crit: return fail_test('fixture: the first hit was not converted.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked again.')
	var second := await attack(pair[0], [A_HIT, 1], [true, true], true)
	if second == null: return fail_test('fixture: no second roll.')
	assert_true(second.consumed_lock, 'LIVENESS: the second hit consumed too.')
	assert_eq(bats_prompts().size(), 0, '1/round: not offered again.')
	assert_false(second.crit, 'A plain hit.')
	assert_eq(mod.charges_current, 1, 'Only the first charge was expended.')

func test_it_is_offered_again_after_the_naga_starts_a_new_turn() -> void:
	var pair := mount(RIFLE)
	var mod:GearCore = pair[1]
	if mod == null: return fail_test('fixture: no mod.')
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked.')
	await attack(pair[0], [A_HIT, 1], [true, true])
	assert_true(NagaFixture.lock_by_hand(naga, target), 'fixture: locked again.')
	var roll := await attack(pair[0], [A_HIT, 1], [true, true]) # cycles the Naga's turn
	if roll == null: return fail_test('fixture: no roll.')
	assert_eq(bats_prompts().size(), 1, 'A new round of the Naga\'s: offered again.')
	assert_eq(mod.charges_current, 0, 'Both charges expended.')
