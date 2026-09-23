# TRAJECTORY ARC MAPPER (Purple Thorn rank I system, SP2 Task 2, design ruling 10).
#
#   "When attacking a character whose distance from you is equal to the range of the weapon, you
#    gain +1 accuracy."
#
# READ THROUGH AttackRoll.PreAttack, NOT through the buff list - test_aaaa_difficulty.gd's idiom:
# accuracy_mods_total() is the number roll_attack feeds to the accuracy dice, so a wrong `to`,
# subtype or sign goes red here where "the buff is on the unit" would stay green.
#
# EVERY TARGET STANDS IN THE OPEN and, for the ranged cases, far from the Thorn: PreAttack folds
# cover and the ENGAGED penalty into the same list (test_aaaa_difficulty.gd's measurement).
#
# THE RIFLE is the fixture's plain Assault Rifle, Range 10, equipped INTEGRATED (a preview needs no
# mount). The melee control is the GMS Tactical Melee Weapon, Threat 1: its get_target_range is its
# THREAT, so an adjacent swing would match "distance == range" if MELEE were not forbidden.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_trajectory_arc_mapper.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const KIT_ID := &'ms_trajectory_arc_mapper'
const BUFF_ID := &'buff_trajectory_arc_mapper'
const MELEE := &'mw_tactical_melee_weapon'
const BLINK_BOLT := &'mw_blink_bolt_launcher'

const THORN_TILE := Vector2i(4, 6)
const AT_RANGE := Vector2i(14, 6)     # 10 east: the rifle's range exactly
const ONE_CLOSER := Vector2i(13, 6)   # 9
const ONE_FURTHER := Vector2i(15, 6)  # 11
const AT_BUFFED_RANGE := Vector2i(16, 6) # 12: the rifle's range with +2
const ADJACENT := Vector2i(5, 6)      # 1: the melee weapon's threat

var game:Gamemaster
var thorn:Unit
var target:Unit

## A runtime +2 aim-range bonus on every weapon - the shape of a range mod, standing in for one.
class PlusTwoRange extends BuffWeaponTypeBonus:
	func _init() -> void:
		to = Buff.TO.ACTION_RANGE
		bonus_subtype = Buff.BONUS_SUBTYPE.AIM_RANGE
		bonus_value = 2
		hide_from_player = true

func before_each() -> void:
	game = Fixture.create_game(self)
	thorn = Fixture.create_thorn(game, THORN_TILE)
	target = Fixture.create_hostile(game, AT_RANGE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func with_mapper() -> void:
	Fixture.equip(thorn, KIT_ID)

## What a roll by the Thorn at `against` with `kit_id` would compute right now, without firing.
func accuracy(kit_id:StringName, against:Unit) -> int:
	var weapon:GearCore = Fixture.equip(thorn, kit_id)
	var specific := SpecificAction.create(thorn, weapon, weapon.get_solo_action())
	return AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = against})).accuracy_mods_total()

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_system():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_true(kit.is_unique(), 'UNIQUE.')
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_true(kit.actions.is_empty(), 'No action: the effect is passive.')
	assert_false(kit.is_trait, 'Equippable gear, not a trait.')

func test_the_buff_is_hung_on_the_thorn_and_hidden():
	with_mapper()
	assert_true(UnitCondition.has_buff(thorn, BUFF_ID), 'Equipping the system hangs its buff on the Thorn.')
	var buff:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(buff, 'fixture: the buff loads.')
	if buff == null: return
	assert_true(buff.hide_from_player, 'Hidden: the system card says it.')

func test_the_rows_resolve():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Trajectory Arc Mapper', 'The name row.')
	assert_true(X.tr('gear.%s.effect' % KIT_ID).begins_with('When attacking a'), 'The effect row.')

# ---------------------------------------------------------------- the sweet spot

func test_at_exactly_the_weapons_range_the_roll_gains_one_accuracy():
	with_mapper()
	assert_eq(accuracy(Fixture.MAIN_RIFLE, target), 1, 'Distance 10, Range 10: +1 accuracy.')

func test_without_the_system_the_same_shot_gains_nothing():
	assert_eq(accuracy(Fixture.MAIN_RIFLE, target), 0, 'Control: the +1 is the system\'s.')

func test_one_tile_closer_gains_nothing():
	with_mapper()
	Fixture.step(target, ONE_CLOSER)
	assert_eq(accuracy(Fixture.MAIN_RIFLE, target), 0, 'Distance 9: nothing.')

func test_one_tile_further_is_not_targetable():
	with_mapper()
	Fixture.step(target, ONE_FURTHER)
	var rifle:GearCore = Fixture.equip(thorn, Fixture.MAIN_RIFLE)
	assert_does_not_have(UnitTargeting.get_tiles_targetable(SpecificAction.create(thorn, rifle, rifle.get_solo_action())), ONE_FURTHER,
		'Distance 11: out of range, so no attack to gain on.')

func test_a_range_buff_moves_the_sweet_spot():
	with_mapper()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), thorn, PlusTwoRange.new())
	assert_eq(accuracy(Fixture.MAIN_RIFLE, target), 0, 'Range 12 now: distance 10 is no longer the sweet spot.')
	Fixture.step(target, AT_BUFFED_RANGE)
	assert_eq(accuracy(Fixture.MAIN_RIFLE, target), 1, 'Distance 12: +1.')

func test_the_blink_bolt_launcher_at_ten_gains_it_too():
	with_mapper()
	assert_eq(accuracy(BLINK_BOLT, target), 1, 'The frame\'s own Range 10 Aux: +1 at 10.')

# ---------------------------------------------------------------- what gains nothing

func test_a_melee_weapon_at_its_threat_gains_nothing():
	with_mapper()
	Fixture.step(target, ADJACENT)
	assert_eq(accuracy(MELEE, target), 0, 'Threat 1, distance 1: a melee weapon has no Range.')

func test_a_drone_at_range_gains_nothing():
	with_mapper()
	var drone := Fixture.create_drone(game, Vector2i(14, 3))
	assert_eq(UnitRelation.distance_between(thorn, drone), 10, 'fixture: the drone stands at 10.')
	assert_eq(accuracy(Fixture.MAIN_RIFLE, drone), 0, '"A character": a drone is not one.')
