# WAVEMAKER GRENADE LAUNCHER (Hazard rank I weapon, SP2 Task 1, design ruling 8).
#
#   Main Launcher, SP 0. ARCING, RELIABLE 2, LIMITED 4, INACCURATE. 1d6 Explosive, Range 10, Blast 1.
#
# PURE .tres - every behaviour below is ActionAttackWeapon's own, read off the fields: ARCING waives
# LOS in targeting, RELIABLE's value is reliable_damage, INACCURATE's d6 comes from attack_accuracy
# (attack_roll.gd:145-151; the tag in `tags` only draws it), LIMITED is the Kit's charges_max and each
# shot spends one through the default consumes_charges.
#
# FIRED BY THE HAZARD, so Weight of Fire is live on it: at the fixture's Grit 0 it adds +0 Reliable
# and the exact top-up pays nothing, which is what lets the RELIABLE 2 below read as the weapon's own.
#
# THE DICE: d20 first, then the INACCURATE d6 (attack_roll.gd:67-70), then the damage columns.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_wavemaker_grenade_launcher.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const KIT_ID := &'mw_wavemaker_grenade_launcher'
const ACTION_ID := &'action_wavemaker_grenade_launcher'

const HAZARD_TILE := Vector2i(4, 6)
## Exactly Range 10 east of the Hazard, and one tile past it.
const AT_RANGE := Vector2i(14, 6)
const PAST_RANGE := Vector2i(15, 6)
## Four east, with a full-height wall between.
const BEHIND_WALL := Vector2i(8, 6)
const WALL_X := 6

var game:Gamemaster
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, BEHIND_WALL)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func arm() -> GearCore:
	return Fixture.equip(hazard, KIT_ID)

func specific(gear:GearCore) -> SpecificAction:
	return SpecificAction.create(hazard, gear, gear.get_solo_action())

## Fire at a TILE (a Blast weapon's aim point), cycling the Hazard's turn first.
func fire_at(tile:Vector2i) -> void:
	await Fixture.cycle_turn(game, hazard)
	await SpecFactory.use_solo(game, hazard, KIT_ID, [tile])

## The Green Tide spec's full-height wall down column x: blocks LOS at every layer.
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(HAZARD_TILE) + 6, wall)
	UnitTile.update_tracking_and_statuses(game.map)

## Every die a 6 from here on: a d20 of 6 misses evasion 10, so only RELIABLE lands.
func all_sixes() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = []
	for i:int in 60: rolls.append(6)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The weapon loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.charges_max, 4, 'LIMITED 4.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var weapon := kit.actions[0] as ActionAttackWeapon
	assert_not_null(weapon, 'The profile is an ActionAttackWeapon.')
	if weapon == null: return
	assert_eq(weapon.get_id(), ACTION_ID, 'Its id.')
	assert_eq(weapon.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(weapon.weapon_type, Lancer.WEAPON_TYPE.LAUNCHER, 'Launcher.')
	assert_eq(weapon.damage_type, Lancer.DAMAGE_TYPE.EXPLOSIVE, 'Explosive.')
	assert_eq(weapon.damage_dice, '1d6', '1d6.')
	assert_eq(weapon.aim_range, 10, 'Range 10.')
	assert_not_null(weapon.range_pattern, 'An area.')
	if weapon.range_pattern != null:
		assert_eq(weapon.range_pattern.pattern, 1, 'A Blast (the RPG\'s and the Mortar\'s pattern).')
		assert_eq(weapon.range_pattern.value, 1, 'Blast 1.')
	assert_eq(weapon.tags, [&'arcing', &'reliable', &'inaccurate'] as Array[StringName], 'ARCING, RELIABLE, INACCURATE - the card\'s order, LIMITED being the Kit\'s charges.')
	assert_eq(weapon.get_base_value_for_tag(Lancer.WEAPON_TAG.RELIABLE), 2, 'RELIABLE 2.')
	assert_eq(weapon.attack_accuracy, '-1', 'INACCURATE: one Difficulty, from the field.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Wavemaker Grenade Launcher', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('As the current lead in IPS-N'), 'The flavour row.')

func test_the_live_tags_on_the_hazard_read_reliable_two():
	var gear := arm()
	var live:Dictionary = specific(gear).action.get_weapon_tags(specific(gear))
	assert_eq(live.get(Lancer.WEAPON_TAG.RELIABLE, -1), 2, 'Grit 0: Weight of Fire adds nothing, RELIABLE 2 is the weapon\'s.')
	assert_true(live.has(Lancer.WEAPON_TAG.ARCING), 'ARCING is live.')
	assert_true(live.has(Lancer.WEAPON_TAG.INACCURATE), 'INACCURATE is live.')

# ---------------------------------------------------------------- the engine acts on it

func test_a_miss_still_deals_reliable_two():
	arm()
	all_sixes()
	await fire_at(BEHIND_WALL)
	assert_eq(hostile.current_damage(), 2, 'A miss (d20 6 against evasion 10): RELIABLE 2 lands anyway.')

func test_inaccurate_is_one_difficulty_die_in_the_roll():
	# d20 11 hits evasion 10 on its own; the Difficulty d6 of 6 takes it to 5, a miss, so only the
	# RELIABLE 2 lands. Without the Difficulty the 11 would hit and the damage die (6) would land 6.
	arm()
	Fixture.queue([11, 6, 6, 6, 6, 6])
	await fire_at(BEHIND_WALL)
	assert_eq(hostile.current_damage(), 2, 'The Difficulty d6 turned an 11 into a miss.')

func test_blast_one_hits_both_adjacent_targets_and_not_a_third_two_out():
	arm()
	var beside := Fixture.create_hostile(game, BEHIND_WALL + Vector2i(0, 1))
	var two_out := Fixture.create_hostile(game, BEHIND_WALL + Vector2i(0, 2))
	all_sixes()
	await fire_at(BEHIND_WALL)
	assert_eq(hostile.current_damage(), 2, 'The aimed tile\'s unit is in the Blast.')
	assert_eq(beside.current_damage(), 2, 'The adjacent one is in Blast 1 too.')
	assert_eq(two_out.current_damage(), 0, 'Two out is not.')

func test_range_ten_is_the_edge():
	var gear := arm()
	var tiles := UnitTargeting.get_tiles_in_range(specific(gear))
	assert_has(tiles, AT_RANGE, 'Ten tiles away is in range.')
	assert_does_not_have(tiles, PAST_RANGE, 'Eleven is not.')

func test_a_target_behind_a_wall_is_targetable_because_it_is_arcing():
	var gear := arm()
	var nexus := Fixture.equip(hazard, Fixture.AUX_NEXUS)
	gear = hazard.get_gear(KIT_ID) # equip() full-repairs; re-read
	build_wall_at(WALL_X)
	assert_false(UnitRelation.can_see(hazard, hostile), 'fixture: the wall blocks LOS.')
	assert_has(UnitTargeting.get_tiles_targetable(specific(gear)), BEHIND_WALL,
		'ARCING: the tile behind the wall is in the targeting set.')
	assert_does_not_have(UnitTargeting.get_tiles_targetable(specific(nexus)), BEHIND_WALL,
		'Control: the Nexus, not ARCING, cannot pick it.')

func test_each_shot_spends_a_charge_and_a_fifth_is_refused():
	var gear := arm()
	assert_eq(gear.charges_current, 4, 'Starts at LIMITED 4.')
	all_sixes()
	await fire_at(BEHIND_WALL)
	assert_eq(gear.charges_current, 3, 'One shot spent one charge.')
	for i:int in 3:
		all_sixes()
		await fire_at(BEHIND_WALL)
	assert_eq(gear.charges_current, 0, 'Four shots, four charges.')
	await Fixture.cycle_turn(game, hazard)
	assert_false(UnitAction.can_activate_gear(specific(gear)), 'A fifth shot is refused.')
	assert_eq(hostile.current_damage(), 8, 'Exactly four shots landed (RELIABLE 2 each).')
