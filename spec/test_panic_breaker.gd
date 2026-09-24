# PANIC BREAKER (Hazard rank II weapon, SP3 Task 1, design ruling 10).
#
#   Heavy Cannon, SP 0. RELIABLE 4, KNOCKBACK 2. 6 Kinetic, Range 3.
#
# PURE .tres - every behaviour below is ActionAttackWeapon's own, read off the fields: RELIABLE's
# value is reliable_damage, KNOCKBACK's is `knockback` (the Siege Cannon's pairing), the flat 6 is
# damage_dice "6". The FX is vanilla's default heavy cannon (default_weapon_fxg.tres), so no override.
#
# FIRED BY THE HAZARD at the fixture's Grit 0, so Weight of Fire adds +0 and the exact top-up pays
# nothing: the RELIABLE 4 below is the weapon's own.
#
# THE DICE: d20 first, then the damage columns (a flat 6 rolls none).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_panic_breaker.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const KIT_ID := &'mw_panic_breaker'
const ACTION_ID := &'action_panic_breaker'

const HAZARD_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(6, 6)
## Exactly Range 3 east of the Hazard, and one tile past it.
const AT_RANGE := Vector2i(7, 6)
const PAST_RANGE := Vector2i(8, 6)

var game:Gamemaster
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func arm() -> GearCore:
	return Fixture.equip(hazard, KIT_ID)

func specific(gear:GearCore) -> SpecificAction:
	return SpecificAction.create(hazard, gear, gear.get_solo_action())

## A d20 of 15 hits evasion 10 without critting.
func shoot_hit() -> void:
	Fixture.queue([15])
	await Fixture.shoot(game, hazard, hostile, KIT_ID)

## A d20 of 2 misses evasion 10.
func shoot_miss() -> void:
	Fixture.queue([2])
	await Fixture.shoot(game, hazard, hostile, KIT_ID)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The weapon loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.charges_max, 0, 'Not LIMITED.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var weapon := kit.actions[0] as ActionAttackWeapon
	assert_not_null(weapon, 'The profile is an ActionAttackWeapon.')
	if weapon == null: return
	assert_eq(weapon.get_id(), ACTION_ID, 'Its id.')
	assert_eq(weapon.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'Heavy.')
	assert_eq(weapon.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'Cannon.')
	assert_eq(weapon.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(weapon.damage_dice, '6', 'A flat 6.')
	assert_eq(weapon.aim_range, 3, 'Range 3.')
	assert_null(weapon.range_pattern, 'A single target, no area.')
	assert_eq(weapon.tags, [&'reliable', &'knockback'] as Array[StringName], 'RELIABLE, KNOCKBACK - the card\'s order.')
	assert_eq(weapon.get_base_value_for_tag(Lancer.WEAPON_TAG.RELIABLE), 4, 'RELIABLE 4.')
	assert_eq(weapon.get_base_value_for_tag(Lancer.WEAPON_TAG.KNOCKBACK), 2, 'KNOCKBACK 2.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Panic Breaker', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('The Panic Breaker is the most popular item'), 'The flavour row.')

# ---------------------------------------------------------------- the engine acts on it

func test_a_hit_deals_six():
	arm()
	await shoot_hit()
	assert_eq(hostile.current_damage(), 6, 'A hit: the flat 6.')

func test_a_miss_still_deals_reliable_four():
	arm()
	await shoot_miss()
	assert_eq(hostile.current_damage(), 4, 'A miss: RELIABLE 4 lands anyway.')

func test_a_hit_knocks_the_target_back_up_to_two():
	arm()
	var before:Vector2i = hostile.tile()
	await shoot_hit()
	assert_ne(hostile.tile(), before, 'KNOCKBACK 2 moved the target.')
	assert_lte(Tile.distance(before, hostile.tile()), 2, 'No further than 2.')
	assert_gt(Tile.distance(HAZARD_TILE, hostile.tile()), Tile.distance(HAZARD_TILE, before),
		'Away from the Hazard.')

func test_a_miss_does_not_knock_back():
	arm()
	var before:Vector2i = hostile.tile()
	await shoot_miss()
	assert_eq(hostile.tile(), before, 'No hit, no knockback.')

func test_a_target_immune_to_knockback_is_not_moved():
	# DON'T GIVE UP THE MECH's knockback buff (ruling 7) on the target: the engine's own gate refuses.
	arm()
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), hostile, Fixture.DGUTM_KNOCKBACK)
	var before:Vector2i = hostile.tile()
	await shoot_hit()
	assert_eq(hostile.current_damage(), 6, 'LIVENESS: the hit landed.')
	assert_eq(hostile.tile(), before, 'The immune target stays put.')

func test_range_three_is_the_edge():
	var gear := arm()
	var tiles := UnitTargeting.get_tiles_in_range(specific(gear))
	assert_has(tiles, AT_RANGE, 'Three tiles away is in range.')
	assert_does_not_have(tiles, PAST_RANGE, 'Four is not.')

