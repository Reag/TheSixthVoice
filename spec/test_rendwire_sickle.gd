# RENDWIRE SICKLE (Koremasa rank II, design section 4, ruling 32):
#
#   Main Melee, OVERKILL, AP, 1d3+1 Energy, Threat 3.
#   "On hit: Targets must succeed on a Hull save or become Impaired until the end of their next turn."
#
# PURE .tres: an inline OnHitEffect with save_to_avoid and save_type HULL, the Concussion Missiles'
# shape (mw_concussion_missiles.tres:15-16). The status's standard lifetime is END_OF_NEXT_TURN
# (on_hit_effect.gd get_applied_duration_for_statuses -> StatusType.get_standard_until), so nothing
# in the resource names the duration and the spec pins it from the target's side.
#
# THE DICE. One swing pops, in order: the attack d20, the target's Hull save d20 (the on-hit effect
# runs inside event_unit_attack, event_unit_attack.gd:85-87), then the damage d3 when the declared
# attack rolls base damage (event_unit_attack_declared.gd:89). The fixture's queue pads with 3s, so a
# swing that names only [attack, save] deals 3 + 1 = 4. The save is d20 + the dummy's Hull 0 against
# the Koremasa's save target 10.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rendwire_sickle.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 5)
## Threat 3: three tiles east, the far edge of the reach.
const HOSTILE_TILE := Vector2i(6, 5)

const HIT := 15
const CRIT := 20
const FAIL := 5
const PASS := 15

var game:Gamemaster
var koremasa:Unit
var hostile:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.SICKLE_ID)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func weapon() -> ActionAttackWeapon:
	var kit:Kit = ContentLibrary.get_kit(Fixture.SICKLE_ID)
	if not Kit.is_valid(kit): return null
	return kit.get_action(Fixture.SICKLE_ACTION) as ActionAttackWeapon

## Swing at the hostile with [attack d20, save d20] + `rest`, then the fixture's tail of 3s.
func swing(d20:int, save:int, rest:Array[int] = []) -> void:
	await Fixture.open_turn(game, koremasa)
	var rolls:Array[int] = [d20, save]
	rolls.append_array(rest)
	Fixture.queue(rolls)
	await SpecFactory.use_solo(game, koremasa, Fixture.SICKLE_ID, hostile)

func status_until(unit:Unit, status:StringName) -> int:
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == status: return condition.until
	return -1

func lost(unit:Unit, before:int) -> int: return before - unit.core.current.health

# ---------------------------------------------------------------- the profile

func test_the_sickle_is_a_main_melee_energy_weapon_at_threat_three():
	var kit:Kit = ContentLibrary.get_kit(Fixture.SICKLE_ID)
	assert_true(Kit.is_valid(kit), 'mw_rendwire_sickle is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var attack := weapon()
	assert_not_null(attack, 'The action is action_rendwire_sickle, an ActionAttackWeapon.')
	if attack == null: return
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.ENERGY, 'Energy.')
	assert_eq(attack.damage_dice, '1d3+1', '1d3+1.')
	assert_eq(attack.threat, 3, 'Threat 3.')
	assert_eq(attack.thrown, 0, 'Not thrown.')

func test_the_sickle_is_overkill_and_ap():
	var attack := weapon()
	assert_not_null(attack, 'fixture: the action loads.')
	if attack == null: return
	assert_true(attack.tags.has(Lancer.WEAPON_TAG.OVERKILL), 'OVERKILL.')
	assert_true(attack.tags.has(Lancer.WEAPON_TAG.AP), 'AP.')
	assert_eq(attack.tags.size(), 2, 'And nothing else.')

func test_the_on_hit_is_a_hull_save_against_impaired():
	var attack := weapon()
	assert_not_null(attack, 'fixture: the action loads.')
	if attack == null: return
	assert_eq(attack.on_hit_effects.size(), 1, 'One on-hit effect.')
	if attack.on_hit_effects.is_empty(): return
	var effect:OnHitEffect = attack.on_hit_effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_HIT, 'On hit.')
	assert_eq(effect.statuses, [Lancer.STATUS.IMPAIRED] as Array[StringName], 'Impaired.')
	assert_true(effect.save_to_avoid, 'Avoided by a save...')
	assert_eq(effect.save_type, Lancer.HASE.HULL, '...a Hull save.')

# ---------------------------------------------------------------- behaviour

## use_solo fires at the named target WHATEVER the range, so landing a hit proves nothing about reach
## (measured: this test's first form stayed green at threat 1). The targeting set is the check.
func test_a_hostile_three_tiles_away_is_in_reach_and_four_is_not():
	var gear := koremasa.get_gear(Fixture.SICKLE_ID)
	var tiles := UnitTargeting.get_tiles_targetable(SpecificAction.create(koremasa, gear, gear.get_solo_action()))
	assert_has(tiles, HOSTILE_TILE, 'Threat 3 reaches three tiles out.')
	assert_does_not_have(tiles, HOSTILE_TILE + Vector2i(1, 0), 'But not four.')
	var before := hostile.core.current.health
	await swing(HIT, PASS)
	assert_eq(lost(hostile, before), 4, 'And the swing lands: 1d3+1 with the d3 at 3.')

func test_a_failed_hull_save_impairs_to_the_end_of_their_next_turn():
	await swing(HIT, FAIL)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'A failed Hull save: Impaired.')
	assert_eq(status_until(hostile, Lancer.STATUS.IMPAIRED), Lancer.UNTIL.END_OF_NEXT_TURN,
		'"until the end of their next turn".')

func test_a_passed_hull_save_does_not_impair():
	var before := hostile.core.current.health
	await swing(HIT, PASS)
	assert_eq(lost(hostile, before), 4, 'LIVENESS: the hit landed.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'A passed save: not Impaired.')

func test_a_miss_forces_no_save():
	await swing(1, FAIL)
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'A miss: no save, no Impaired.')

func test_a_crit_impairs_as_a_hit_does():
	await swing(CRIT, FAIL)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'A crit is a hit: Impaired on a failed save.')

func test_armor_does_not_reduce_it():
	hostile.core.frame.stat.armor = 2
	hostile.core.full_repair()
	var before := hostile.core.current.health
	await swing(HIT, PASS)
	assert_eq(lost(hostile, before), 4, 'AP: all 4 through 2 armor.')

func test_overkill_rerolls_a_one_and_heats_the_koremasa():
	var heat_before := Fixture.heat(koremasa)
	var before := hostile.core.current.health
	await swing(HIT, PASS, [1, 3])
	assert_eq(lost(hostile, before), 4, 'The 1 was rerolled into a 3: 3 + 1.')
	assert_eq(Fixture.heat(koremasa) - heat_before, 1, 'OVERKILL: 1 Heat for the 1.')

# ---------------------------------------------------------------- the card

func test_the_card_rows_resolve():
	for key:String in ['gear.mw_rendwire_sickle.name', 'gear.mw_rendwire_sickle.flavor',
			'gear.mw_rendwire_sickle.on_hit']:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.mw_rendwire_sickle.name'), 'Rendwire Sickle', 'The name.')
