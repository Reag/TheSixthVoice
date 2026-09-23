# WEIGHT OF FIRE (Hazard, mt_weight_of_fire) - SP1 Task 2, ruling 2:
#
#   "All non-Auxiliary weapons mounted on the Hazard and adjacent allied mechs increase their
#    Reliable equal to half Grit. If they do not have Reliable, they instead gain that much."
#
# Two halves, tested separately: the CARD (the engine's own tag fold, ActionAttackWeapon.get_weapon_tags)
# and the DAMAGE (real shots, paid by reliable_topup.gd at ATTACK_DECLARED POST - the engine reads the
# Reliable floor from the printed export only, so the tag alone never reaches a roll).
#
# THE HAZARD'S GRIT IS 4 AND EVERY ALLY'S IS 1 unless a case says otherwise: half(4) = 2 and
# half(1) = 1, so a buff reading the holder's Grit instead of the Hazard's is caught everywhere.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_weight_of_fire.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const HEAVY_HMG := &'mw_heavy_machine_gun' # GMS HEAVY, 2d6+4, INACCURATE, no Reliable
const BASIC_MELEE := &'mw_improvised_attack' # size NONE, in every unit's basic loadout

const HAZARD_TILE := Vector2i(4, 6)
const ADJACENT := Vector2i(5, 6)
const TWO_OUT := Vector2i(6, 6)
const DIAGONAL := Vector2i(5, 7)
const TARGET_TILE := Vector2i(9, 6)

var game:Gamemaster
var hazard:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE, 4)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func has_wof(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, Fixture.WOF_BUFF)

# ---------------------------------------------------------------- the Hazard itself

func test_the_hazards_main_rifle_adds_half_grit_to_its_reliable():
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	assert_true(has_wof(hazard), 'LIVENESS: the aura put the buff on the Hazard itself.')
	assert_eq(Fixture.reliable(hazard, Fixture.MAIN_RIFLE), 4, 'Reliable 2 + half Grit 4 = 4 (additive, not a top-up to 2).')

func test_a_miss_deals_the_raised_reliable():
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([1, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'A miss deals Reliable 4 - the buff reaches the damage roll.')

func test_the_hazards_aux_weapon_gets_nothing():
	Fixture.equip(hazard, Fixture.AUX_NEXUS)
	assert_eq(Fixture.reliable(hazard, Fixture.AUX_NEXUS), 0, '"non-Auxiliary": the Nexus gains no Reliable.')

func test_a_basic_attack_gets_nothing():
	assert_true(has_wof(hazard), 'fixture: the buff is on.')
	assert_eq(Fixture.reliable(hazard, BASIC_MELEE), 0, 'The improvised attack (size NONE, basic) gains no Reliable.')

func test_grit_one_rounds_up_to_one():
	Fixture.set_grit(hazard, 1)
	Fixture.equip(hazard, HEAVY_HMG)
	assert_eq(Fixture.reliable(hazard, HEAVY_HMG), 1, 'Half of Grit 1 rounds UP: a weapon without Reliable gains 1.')

func test_grit_zero_adds_nothing_and_draws_no_tag():
	Fixture.set_grit(hazard, 0)
	Fixture.equip(hazard, HEAVY_HMG)
	var gear:GearCore = hazard.get_gear(HEAVY_HMG)
	var specific := SpecificAction.create(hazard, gear, gear.get_solo_action())
	assert_false(specific.action.get_weapon_tags(specific).has(Lancer.WEAPON_TAG.RELIABLE),
		'Grit 0: no "Reliable 0" tag appears on a weapon that had none.')

# ---------------------------------------------------------------- adjacent allies

func test_an_adjacent_allied_mechs_heavy_reads_the_hazards_half_grit():
	var ally := Fixture.create_ally(game, ADJACENT, 1)
	Fixture.equip(ally, HEAVY_HMG)
	assert_true(has_wof(ally), 'LIVENESS: the adjacent ally carries the buff.')
	assert_eq(Fixture.reliable(ally, HEAVY_HMG), 2, 'Half the HAZARD\'s Grit 4 = 2 (its own Grit 1 would give 1).')

func test_a_diagonal_ally_is_adjacent():
	var ally := Fixture.create_ally(game, DIAGONAL, 1)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 4, 'Diagonal is adjacent: Reliable 2 + 2.')

func test_an_ally_two_tiles_out_gets_nothing():
	var ally := Fixture.create_ally(game, TWO_OUT, 1)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	assert_false(has_wof(ally), 'No buff two tiles out.')
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 2, 'Printed Reliable only.')

func test_an_ally_that_steps_away_loses_it_and_one_that_steps_in_gains_it():
	var ally := Fixture.create_ally(game, ADJACENT, 1)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 4, 'fixture: adjacent, raised.')
	Fixture.step(ally, TWO_OUT)
	assert_false(has_wof(ally), 'Stepping away strips the buff.')
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 2, 'And the tag returns to printed.')
	Fixture.step(ally, DIAGONAL)
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 4, 'Stepping back in raises it again.')

func test_an_adjacent_allied_drone_gets_nothing():
	var drone := Fixture.create_drone(game, ADJACENT)
	assert_true(drone.is_character(), 'fixture: a drone IS a character - the reason for the mech gate.')
	assert_false(has_wof(drone), '"allied mechs": a drone is not a mech.')

func test_an_adjacent_hostile_gets_nothing():
	var hostile := Fixture.create_hostile(game, ADJACENT)
	Fixture.equip(hostile, Fixture.MAIN_RIFLE)
	assert_false(has_wof(hostile), 'Hostiles are not in the aura.')
	assert_eq(Fixture.reliable(hostile, Fixture.MAIN_RIFLE), 2, 'Printed Reliable only.')

func test_the_ally_loses_it_when_the_hazard_dies():
	var ally := Fixture.create_ally(game, ADJACENT, 1)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	assert_true(has_wof(ally), 'fixture: on.')
	await EventService.remove_unit_from_game(SpecFactory.dummy_event(), hazard)
	UnitTile.update_tracking_and_statuses(game.map)
	assert_eq(Fixture.reliable(ally, Fixture.MAIN_RIFLE), 2, 'With no Hazard the ally is back to printed Reliable.')

# ---------------------------------------------------------------- the payout (reliable_topup.gd)
#
# The WEAPON_TAG half only reaches the card; these prove the damage. Author's ruling 2026-09-24:
# EXACT - (dealt + top-up) must equal what ONE event of the raised floor would have dealt.

func armored_hostile(armor:int) -> Unit:
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	hostile.core.frame.stat.armor = armor
	hostile.core.full_repair()
	return hostile

func test_a_low_hit_is_floored_to_the_raised_reliable():
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([19, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'A hit rolling 1 is floored to Reliable 4, not the printed 2.')

func test_a_high_hit_is_not_topped_up():
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([19, 6])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 6, 'A hit above the floor deals its roll and nothing more.')

func test_armor_is_counted_once_on_a_miss():
	var hostile := armored_hostile(1)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([1, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 3, 'Reliable 4 against armor 1 is 3 - armor once, not twice (2).')

func test_armor_that_ate_the_printed_floor_is_not_spent_twice():
	var hostile := armored_hostile(3)
	Fixture.equip(hazard, Fixture.MAIN_RIFLE)
	Fixture.queue([1, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 1, 'Reliable 4 against armor 3 is 1 (the printed 2 was absorbed; the record is lowered to what it used).')

func test_a_weapon_without_printed_reliable_misses_for_the_granted_amount():
	var hostile := armored_hostile(1)
	Fixture.equip(hazard, HEAVY_HMG)
	Fixture.queue([1, 1, 1, 1])
	await Fixture.shoot(game, hazard, hostile, HEAVY_HMG)
	assert_eq(hostile.current_damage(), 1, 'Gained Reliable 2 against armor 1 is 1.')

func test_an_adjacent_allys_miss_pays_the_hazards_half_grit():
	var ally := Fixture.create_ally(game, ADJACENT, 1)
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(ally, Fixture.MAIN_RIFLE)
	Fixture.queue([1, 1])
	await Fixture.shoot(game, ally, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'The ally misses for 2 + half the Hazard\'s Grit 4.')

func test_an_aux_miss_pays_nothing_extra():
	var hostile := Fixture.create_hostile(game, TARGET_TILE)
	Fixture.equip(hazard, Fixture.AUX_NEXUS)
	Fixture.queue([1, 1])
	await Fixture.shoot(game, hazard, hostile, Fixture.AUX_NEXUS)
	assert_eq(hostile.current_damage(), 0, 'The Nexus has no Reliable and gains none: a miss deals 0.')
