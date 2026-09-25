# EXTENDED ZONE CONTROL (Gloire SP1, design rulings 5-6): "The Gloire can Ram targets within Range 3
# and line of sight. Additionally, it has +2 Range with CQB weapons."
#
# The reach is read off UnitTargeting.get_tiles_targetable for the Gloire's own Ram - the tiles the
# picker would actually offer - never off a direct-target SpecFactory.use, which bypasses the reach
# rule entirely. The push direction is read off the knockback reticle the fixture's watcher saw.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_extended_zone_control.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')

## Size 2 at (4,4) covers (4..5, 4..5): a target at x = 8 is 3 from the east edge, x = 9 is 4.
const GLOIRE_TILE := Vector2i(4, 4)
const AT_THREE := Vector2i(8, 4)
const AT_FOUR := Vector2i(9, 4)
const ADJACENT := Vector2i(6, 4)
## The column a full-height wall stands in, between the Gloire and AT_THREE.
const WALL_X := 7
## A plain size-1 control at (10,8): its Ram reaches 1, so (11,8) is in and (12,8) is out.
const PLAIN_TILE := Vector2i(10, 8)
const PLAIN_ADJACENT := Vector2i(11, 8)
const PLAIN_AT_TWO := Vector2i(12, 8)

var game:Gamemaster
var responder
var watcher
var gloire:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	gloire = Fixture.create_gloire(game, GLOIRE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func ram_targets() -> Array[Vector2i]:
	return UnitTargeting.get_tiles_targetable(Fixture.ram_specific(gloire))

# ---------------------------------------------------------------- the Ram's reach

func test_the_two_buffs_are_live_on_a_gloire() -> void:
	assert_true(UnitCondition.has_buff(gloire, Fixture.ZONE_CONTROL_RAM_BUFF), 'the Ram buff is on.')
	assert_true(UnitCondition.has_buff(gloire, Fixture.ZONE_CONTROL_CQB_BUFF), 'the CQB buff is on.')

func test_the_ram_reaches_three_and_not_four() -> void:
	var near := Fixture.create_dummy(game, AT_THREE)
	var far := Fixture.create_dummy(game, AT_FOUR)
	assert_eq(Fixture.ram_specific(gloire).action.get_target_range(Fixture.ram_specific(gloire)), 3, 'threat 1 + 2 = 3.')
	var tiles := ram_targets()
	assert_has(tiles, AT_THREE, 'RULED: a hostile three tiles out can be Rammed.')
	assert_does_not_have(tiles, AT_FOUR, 'four is not.')
	assert_true(UnitRelation.distance_between(gloire, near) == 3 and UnitRelation.distance_between(gloire, far) == 4, 'fixture: the distances are 3 and 4.')

func test_a_plain_units_ram_still_reaches_one() -> void:
	var plain := SpecFactory.create_unit(game.map, PLAIN_TILE)
	Fixture.create_dummy(game, PLAIN_ADJACENT)
	Fixture.create_dummy(game, PLAIN_AT_TWO)
	var tiles := UnitTargeting.get_tiles_targetable(Fixture.ram_specific(plain))
	assert_has(tiles, PLAIN_ADJACENT, 'CONTROL: adjacent is in.')
	assert_does_not_have(tiles, PLAIN_AT_TWO, 'CONTROL: two out is not - the reach is the Gloire\'s, not everyone\'s.')

func test_the_ram_does_not_reach_through_a_wall() -> void:
	var hostile := Fixture.create_dummy(game, AT_THREE)
	Fixture.build_wall_at(game, WALL_X, GLOIRE_TILE)
	assert_false(UnitRelation.can_see(gloire, hostile), 'fixture: the wall blocks LOS.')
	assert_does_not_have(ram_targets(), AT_THREE, 'RULED: "and line of sight" - not through a wall.')

func test_the_ram_still_refuses_a_bigger_target() -> void:
	var big := Fixture.create_dummy(game, AT_THREE)
	SpecFactory.change_size(big, 3)
	UnitTile.update_tracking_and_statuses(game.map)
	assert_does_not_have(ram_targets(), big.tile(), 'the size rule stays: a size-3 target cannot be Rammed from any distance.')
	assert_false(Fixture.ram_specific(gloire).action.can_target_unit(big, Fixture.ram_specific(gloire)), 'action_ram.can_target_unit refuses it.')

func test_a_ram_from_three_away_pushes_directly_away_from_the_gloire() -> void:
	var hostile := Fixture.create_dummy(game, AT_THREE)
	var before:int = watcher.prompts.size()
	await Fixture.ram(game, gloire, hostile)
	var pools:Array = Fixture.offered_pools(watcher, before)
	assert_eq(pools.size(), 1, 'the Ram hit: one knockback reticle was offered.')
	if pools.size() != 1: return
	var pool:Array = pools[0]
	assert_has(pool, Vector2i(9, 4), 'the push goes east, away from the Gloire.')
	assert_does_not_have(pool, Vector2i(7, 4), 'never back toward it.')
	for tile:Vector2i in pool:
		assert_true(tile.x > AT_THREE.x, 'every offered tile is further from the Gloire: %s' % tile)

func test_the_ram_never_overwatches() -> void:
	# The War Pike is the positive control: with nothing equipped the pool is empty and the check
	# below proves nothing (close review, 2026-09-25).
	Fixture.equip(gloire, Fixture.PIKE)
	var hostile := Fixture.create_dummy(game, ADJACENT)
	var offered:Array[SpecificAction] = UnitRelation.get_weapons_that_can_overwatch(gloire, hostile)
	var ids:Array = offered.map(func(specific:SpecificAction) -> StringName: return specific.gear.kit.compcon_id)
	assert_has(ids, Fixture.PIKE, 'CONTROL: the pool is live - the pike overwatches.')
	for specific:SpecificAction in offered:
		assert_ne(specific.action.get_id(), Fixture.RAM_ACTION, 'the Ram is basic gear and never in the overwatch pool.')

## The Ram bonus is the Ram's alone: another melee weapon on the Gloire keeps its printed threat.
func test_the_gloires_other_melee_weapons_keep_their_threat() -> void:
	Fixture.equip(gloire, Fixture.PIKE)
	var specific := Fixture.weapon_specific(gloire, Fixture.PIKE)
	var weapon:ActionAttackWeapon = specific.action
	assert_true(UnitAction.is_melee_weapon(weapon, specific.gear), 'fixture: the War Pike is melee.')
	assert_eq(weapon.threat_distance(specific), weapon.threat, '"Ram targets within Range 3" - not every melee weapon.')

# ---------------------------------------------------------------- the CQB range

func test_a_cqb_weapon_reads_two_more_range_and_its_threat_is_untouched() -> void:
	Fixture.equip(gloire, Fixture.SHOTGUN)
	var specific := Fixture.weapon_specific(gloire, Fixture.SHOTGUN)
	var weapon:ActionAttackWeapon = specific.action
	assert_true(weapon.is_weapon_type(Lancer.WEAPON_TYPE.CQB, specific.gear), 'fixture: the Shotgun is CQB.')
	assert_eq(weapon.ranged_distance(specific), weapon.aim_range + 2, 'RULED: +2 Range on a CQB weapon.')
	assert_eq(weapon.threat_distance(specific), weapon.threat, 'Range, not threat: its threat 3 is untouched.')

func test_a_rifle_reads_its_own_range() -> void:
	Fixture.equip(gloire, Fixture.RIFLE)
	var specific := Fixture.weapon_specific(gloire, Fixture.RIFLE)
	var weapon:ActionAttackWeapon = specific.action
	assert_false(weapon.is_weapon_type(Lancer.WEAPON_TYPE.CQB, specific.gear), 'fixture: the rifle is not CQB.')
	assert_eq(weapon.ranged_distance(specific), weapon.aim_range, 'CONTROL: a rifle gets nothing.')

func test_a_plain_units_shotgun_reads_its_own_range() -> void:
	var plain := SpecFactory.create_unit(game.map, PLAIN_TILE)
	Fixture.equip(plain, Fixture.SHOTGUN)
	var specific := Fixture.weapon_specific(plain, Fixture.SHOTGUN)
	var weapon:ActionAttackWeapon = specific.action
	assert_eq(weapon.ranged_distance(specific), weapon.aim_range, 'CONTROL: the bonus is the Gloire\'s alone.')

# ---------------------------------------------------------------- the card

func test_the_kit_is_a_trait_with_two_hidden_buffs_and_its_rows() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.ZONE_CONTROL_ID)
	assert_true(Kit.is_valid(kit), 'mt_extended_zone_control is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'a trait.')
	assert_true(kit.actions.is_empty(), 'no action of its own.')
	for buff_id:StringName in [Fixture.ZONE_CONTROL_RAM_BUFF, Fixture.ZONE_CONTROL_CQB_BUFF]:
		var buff:Buff = ContentLibrary.get_buff(buff_id)
		assert_not_null(buff, '%s is in the buffs index.' % buff_id)
		if buff == null: continue
		assert_true(buff.hide_from_player, '%s is plumbing, not a chip.' % buff_id)
	assert_eq(X.tr('gear.mt_extended_zone_control.effect'),
		'The Gloire can |Ram| targets within Range 3 and line of sight. Additionally, it has +2 Range with CQB weapons.',
		'the card is the LCP verbatim.')
