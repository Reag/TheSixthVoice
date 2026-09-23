# BLINK BOLT LAUNCHER (Purple Thorn rank I weapon, SP2 Task 1, design ruling 9).
#
#   Auxiliary Launcher, SP 1. SEEKING, RELIABLE 1. 2 Kinetic, Range 10.
#
# PURE .tres - every behaviour below is ActionAttackWeapon's own, read off the tags. The spec pins
# that the tags and numbers are the card's AND that the engine acts on them: a miss still lands the
# RELIABLE 1, a target behind a full-height wall is still in the targeting set (SEEKING), and the
# range edge is 10. (A "fire through the wall" case was tried and dropped: SpecFactory.use_solo
# bypasses targeting, so it stayed green with SEEKING removed and proved nothing.)
#
# ON THE THORN, so the frame's two traits fire on every hit: Blessed Bolt offers a yes/no (declined
# by default below, or every hit reads +3) and Vigil opens a reticle (cancelled by an unreachable
# answer, or the Thorn walks about the board) - test_stalk_the_horizon.gd's idiom.
#
# THE DICE: flat 2 rolls no damage die, so a shot pops only the d20.
#
# Stalk the Horizon's own Line of Sight gate, which this weapon is the first to make bind (SP1 J-5),
# is pinned in test_stalk_the_horizon.gd beside the gate's other cases.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_blink_bolt_launcher.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const KIT_ID := &'mw_blink_bolt_launcher'
const ACTION_ID := &'action_blink_bolt_launcher'

const THORN_TILE := Vector2i(4, 6)
## Exactly Range 10 east of the Thorn, and one tile past it.
const AT_RANGE := Vector2i(14, 6)
const PAST_RANGE := Vector2i(15, 6)
## Four east, with a full-height wall between.
const BEHIND_WALL := Vector2i(8, 6)
const WALL_X := 6

const D20_HITS := 19
const D20_MISSES := 1
## On the map, far outside range 3 of anywhere the Thorn stands: cancels Vigil's reticle.
const CANCEL_VIGIL := Vector2i(25, 11)

var game:Gamemaster
var thorn:Unit
var hostile:Unit
var responder

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	hostile = Fixture.create_hostile(game, BEHIND_WALL)
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func arm_bolt() -> GearCore:
	Fixture.mount_pair(thorn, 0, KIT_ID)
	return thorn.get_gear(KIT_ID)

func targetable(gear:GearCore) -> Array[Vector2i]:
	return UnitTargeting.get_tiles_targetable(SpecificAction.create(thorn, gear, gear.get_solo_action()))

## The Green Tide spec's full-height wall down column x: blocks LOS at every layer.
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(THORN_TILE) + 6, wall)
	UnitTile.update_tracking_and_statuses(game.map)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The weapon loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var weapon := kit.actions[0] as ActionAttackWeapon
	assert_not_null(weapon, 'The profile is an ActionAttackWeapon.')
	if weapon == null: return
	assert_eq(weapon.get_id(), ACTION_ID, 'Its id.')
	assert_eq(weapon.weapon_size, Lancer.WEAPON_SIZE.AUX, 'Auxiliary.')
	assert_eq(weapon.weapon_type, Lancer.WEAPON_TYPE.LAUNCHER, 'Launcher.')
	assert_eq(weapon.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(weapon.damage_dice, '2', '2 damage, flat.')
	assert_eq(weapon.aim_range, 10, 'Range 10.')
	assert_eq(weapon.tags, [&'seeking', &'reliable'] as Array[StringName], 'SEEKING, RELIABLE - the card\'s order.')
	assert_eq(weapon.get_base_value_for_tag(Lancer.WEAPON_TAG.RELIABLE), 1, 'RELIABLE 1.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Blink Bolt Launcher', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('While resembling a simple bolt launcher'), 'The flavour row.')

# ---------------------------------------------------------------- the engine acts on it

func test_a_hit_deals_two_kinetic():
	arm_bolt()
	Fixture.step(hostile, AT_RANGE)
	Fixture.queue([D20_HITS])
	await Fixture.shoot(game, thorn, hostile, KIT_ID)
	assert_eq(hostile.current_damage(), 2, 'A hit: 2.')

func test_a_miss_still_deals_reliable_one():
	arm_bolt()
	Fixture.step(hostile, AT_RANGE)
	Fixture.queue([D20_MISSES])
	await Fixture.shoot(game, thorn, hostile, KIT_ID)
	assert_eq(hostile.current_damage(), 1, 'A miss: RELIABLE 1 lands anyway.')

func test_range_ten_is_the_edge():
	var gear := arm_bolt()
	var tiles := UnitTargeting.get_tiles_in_range(SpecificAction.create(thorn, gear, gear.get_solo_action()))
	assert_has(tiles, AT_RANGE, 'Ten tiles away is in range.')
	assert_does_not_have(tiles, PAST_RANGE, 'Eleven is not.')

func test_a_target_behind_a_wall_is_targetable_because_it_is_seeking():
	var gear := arm_bolt()
	Fixture.mount_pair(thorn, 1, Fixture.AUX_NEXUS)
	build_wall_at(WALL_X)
	assert_false(UnitRelation.can_see(thorn, hostile), 'fixture: the wall blocks LOS.')
	assert_has(targetable(gear), BEHIND_WALL, 'SEEKING: the target behind the wall is in the targeting set.')
	assert_does_not_have(targetable(thorn.get_gear(Fixture.AUX_NEXUS)), BEHIND_WALL,
		'Control: the Nexus, not SEEKING, cannot pick it.')
