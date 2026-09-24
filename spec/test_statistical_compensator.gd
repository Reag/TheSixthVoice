# STATISTICAL COMPENSATOR (Hazard rank II weapon mod, SP3 Task 2, design ruling 11 as amended by the
# SP3 probe - spec/test_spike_hazard_sp3_seams.gd).
#
#   Weapon mod, SP 2, UNIQUE, LIMITED 3. Fits Rifle, Cannon, Launcher, CQB, Nexus, Melee; Main,
#   Heavy, Superheavy. "When you make an attack roll with the weapon this mod is applied to, you may
#   expend a charge to gain +2 Reliable for that attack."
#
# THE SHAPE. A hidden ATTACK_DECLARED PRE reaction on the mod Kit asks (confirm_use; the AI
# declines), spends a charge and STAMPS the attack's DeclaredAttackSummary. The mod's permanent
# WEAPON_TAG buff reads +2 only on a stamped attack, and pays through the shared reliable_topup.gd at
# ATTACK_DECLARED POST - the same payout Weight of Fire uses, so the two add exactly.
#
# THE DICE: d20 first, then the damage columns. Hostile evasion 10, armor 0.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_statistical_compensator.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const MOD_ID := &'wm_statistical_compensator'
const ACTION_ID := &'action_statistical_compensator'
const BUFF_ID := &'buff_statistical_compensator'

const RIFLE := Fixture.MAIN_RIFLE                  # MAIN RIFLE, 1d6, RELIABLE 2
const PANIC_BREAKER := &'mw_panic_breaker'          # HEAVY CANNON, flat 6, RELIABLE 4
const WAVEMAKER := &'mw_wavemaker_grenade_launcher' # MAIN LAUNCHER, Blast 1, RELIABLE 2, INACCURATE
const AUX_NEXUS := Fixture.AUX_NEXUS

const HAZARD_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(6, 6)

var game:Gamemaster
var responder
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Equip a weapon and fit the mod to it. EQUIP EVERYTHING FIRST (equip_system full-repairs).
func equip_modded(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = hazard.core.equip_system(weapon_id)
	hazard.core.loadout.equip_weapon_mod(MOD_ID, weapon)
	SpecFactory.apply_passive_buffs(hazard)
	UnitTile.update_tracking_and_statuses(game.map)
	return weapon

func equip_plain(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = hazard.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(hazard)
	return weapon

func mod_gear() -> GearCore: return hazard.get_gear(MOD_ID)

func fits(weapon_id:StringName) -> bool:
	var weapon:GearCore = hazard.core.equip_system(weapon_id)
	var passive:PassiveWeaponMod = ContentLibrary.get_kit(MOD_ID).get_passives(PassiveWeaponMod).front()
	return passive.is_applicable_to(weapon)

func offers() -> int: return responder.yesno_prompts.size()
func accept() -> void: responder.yesno_queue.assign([true])
func decline() -> void: responder.yesno_queue.assign([false])

## A MISS (d20 2 against evasion 10) with the named weapon, on a fresh turn.
func miss_with(weapon_id:StringName, target = hostile) -> void:
	Fixture.queue([2])
	await Fixture.shoot(game, hazard, target, weapon_id)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(MOD_ID)
	assert_not_null(kit, 'The mod loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE.')
	assert_eq(kit.charges_max, 3, 'LIMITED 3.')
	var passives:Array = kit.get_passives(PassiveWeaponMod)
	assert_eq(passives.size(), 1, 'One weapon-mod passive.')
	if passives.is_empty(): return
	var passive:PassiveWeaponMod = passives.front()
	assert_eq(passive.allowed_types, [Lancer.WEAPON_TYPE.RIFLE, Lancer.WEAPON_TYPE.CANNON, Lancer.WEAPON_TYPE.LAUNCHER,
		Lancer.WEAPON_TYPE.CQB, Lancer.WEAPON_TYPE.NEXUS, Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE], 'The six types, in the card\'s order.')
	assert_eq(passive.allowed_sizes, [Lancer.WEAPON_SIZE.MAIN, Lancer.WEAPON_SIZE.HEAVY, Lancer.WEAPON_SIZE.SUPERHEAVY] as Array[Lancer.WEAPON_SIZE], 'Main, Heavy, Superheavy.')
	assert_true(passive.added_tags.is_empty(), 'No unconditional tags: the +2 is optional and charged.')
	assert_eq(kit.get_reactions().size(), 1, 'One reaction: the prompt.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % MOD_ID), 'Statistical Compensator', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % MOD_ID).begins_with('The Statistical Compensator is the product'), 'The flavour row.')
	assert_eq(X.tr('gear.%s.effect' % MOD_ID), 'When you make an attack roll with the weapon this mod is applied to, you may expend a charge to gain +2 |Reliable| for that attack.', 'The effect row, verbatim.')

func test_it_fits_a_main_rifle_and_a_heavy_cannon_and_not_an_aux():
	assert_true(fits(RIFLE), 'A Main Rifle takes it.')
	assert_true(fits(PANIC_BREAKER), 'A Heavy Cannon takes it.')
	assert_false(fits(AUX_NEXUS), 'An Auxiliary does not.')

func test_the_weapon_card_reads_printed_reliable_outside_an_attack():
	var weapon := equip_modded(RIFLE)
	assert_eq(Fixture.reliable(hazard, RIFLE), 2, 'No attack, no charge spent: the card reads the printed RELIABLE 2.')
	assert_true(GearCore.is_valid(weapon.get_weapon_mod(hazard.core.loadout)), 'LIVENESS: the mod is fitted.')

# ---------------------------------------------------------------- the prompt

func test_an_attack_with_the_modded_weapon_offers_and_yes_spends_a_charge_and_adds_two_on_a_miss():
	equip_modded(RIFLE)
	accept()
	await miss_with(RIFLE)
	assert_eq(offers(), 1, 'One offer for one attack.')
	assert_eq(mod_gear().charges_current, 2, 'Yes spent one of three charges.')
	assert_eq(hostile.current_damage(), 4, 'A miss: printed RELIABLE 2 + 2.')

func test_no_spends_nothing_and_adds_nothing():
	equip_modded(RIFLE)
	decline()
	await miss_with(RIFLE)
	assert_eq(offers(), 1, 'It asked.')
	assert_eq(mod_gear().charges_current, 3, 'No spent nothing.')
	assert_eq(hostile.current_damage(), 2, 'A miss: printed RELIABLE 2 only.')

func test_a_low_hit_is_floored_at_the_raised_reliable():
	# d20 15 hits; the 1d6 rolls 1, below the printed floor 2 and the raised floor 4.
	equip_modded(RIFLE)
	accept()
	Fixture.queue([15, 1])
	await Fixture.shoot(game, hazard, hostile, RIFLE)
	assert_eq(hostile.current_damage(), 4, 'A hit for 1 is floored at RELIABLE 2 + 2.')

func test_the_unmodded_weapon_does_not_offer():
	equip_modded(RIFLE)
	equip_plain(PANIC_BREAKER)
	accept()
	await miss_with(PANIC_BREAKER)
	assert_eq(offers(), 0, 'The other weapon\'s attack does not ask.')
	assert_eq(mod_gear().charges_current, 3, 'Nothing spent.')
	assert_eq(hostile.current_damage(), 4, 'The Panic Breaker\'s own RELIABLE 4, no more.')

func test_the_plus_two_is_gone_on_the_next_attack():
	equip_modded(RIFLE)
	accept()
	await miss_with(RIFLE)
	decline()
	await miss_with(RIFLE)
	assert_eq(offers(), 2, 'Each attack asks.')
	assert_eq(hostile.current_damage(), 4 + 2, 'The first miss 4, the declined second only 2.')

func test_three_charges_then_it_stops_asking():
	equip_modded(RIFLE)
	for i:int in 3:
		accept()
		await miss_with(RIFLE)
	assert_eq(mod_gear().charges_current, 0, 'Three yeses, three charges.')
	accept()
	await miss_with(RIFLE)
	assert_eq(offers(), 3, 'A fourth attack does not ask - there is no fourth charge.')
	assert_eq(hostile.current_damage(), 4 * 3 + 2, 'Three raised misses, then a plain one.')

func test_under_weight_of_fire_the_three_add():
	# Grit 4: Weight of Fire +2. Panic Breaker RELIABLE 4 + 2 (Weight of Fire) + 2 (the mod) = 8.
	Fixture.set_grit(hazard, 4)
	equip_modded(PANIC_BREAKER)
	accept()
	await miss_with(PANIC_BREAKER)
	assert_eq(hostile.current_damage(), 8, 'A miss: 4 + 2 + 2.')

func test_weight_of_fire_alone_still_pays_when_the_mod_is_declined():
	Fixture.set_grit(hazard, 4)
	equip_modded(PANIC_BREAKER)
	decline()
	await miss_with(PANIC_BREAKER)
	assert_eq(hostile.current_damage(), 6, 'A miss: 4 + 2 (Weight of Fire), the mod declined.')

func test_a_blast_offers_once_and_raises_every_target():
	equip_modded(WAVEMAKER)
	var beside := Fixture.create_hostile(game, HOSTILE_TILE + Vector2i(0, 1))
	accept()
	# d20 2 for each of two rolls, the INACCURATE d6 after each: all misses.
	Fixture.queue([2, 1, 2, 1])
	await Fixture.cycle_turn(game, hazard)
	await SpecFactory.use_solo(game, hazard, WAVEMAKER, [HOSTILE_TILE])
	assert_eq(offers(), 1, 'One declared attack, one offer.')
	assert_eq(mod_gear().charges_current, 2, 'One charge.')
	assert_eq(hostile.current_damage(), 4, 'The aimed target: RELIABLE 2 + 2.')
	assert_eq(beside.current_damage(), 4, 'The one beside it too.')

func test_the_ai_declines():
	var action:Action = ContentLibrary.get_kit(MOD_ID).get_reactions().front()
	assert_false(action.ai_confirms_use(Context.create({})), 'An AI never spends the charge.')
