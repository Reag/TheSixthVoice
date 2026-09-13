# Spike 1 (2026-09-13): can a mod make a weapon attack ignore line of sight, conditioned on the
# weapon being a Cannon or a Line weapon, and then hand the target soft cover? That is Hole Puncher
# (Fitzgerald, IPS-N): "The Fitzgerald may ignore line of sight when attacking with Cannon or Line
# weapons. Targets attacked this way have soft cover."
#
# This is a PROBE, not a spec for content. It builds the two candidate buffs in memory, applies them
# to a vanilla unit carrying vanilla weapons, and asserts what the engine does with them. The verdict
# is written up in D:\DEV\lancer-tactics-claude\specs\2026-09-13-ignore-los-weapon-type-feasibility.md;
# the trait's real specs replace this file when SP1 builds it.
#
# WHY NO SCRIPT EXTENSION. The roadmap's lead was the Banshee's unit_tile.gd_ext.gd, which widens the
# LOS sweep. That turned out to be the wrong layer: every consumer of line of sight for an attack -
# the tile picker (unit_targeting.gd:33), the AI's precalculated path (same call, via
# consider_line_of_sight), the AoE filter for lines and cones (action.gd:258) and the reaction check
# (unit_relation.gd:250, :267) - first asks the ACTION `requires_line_of_sight(specific)`, and
# ActionAttackWeapon answers false when the weapon carries the ARCING or SEEKING tag
# (action_attack_weapon.gd:242-244). Tags are read through Buff.TO.WEAPON_TAG buffs on the attacker
# (action_attack_weapon.gd:166-171), whose context carries the gear AND the action - so a buff can
# say "this weapon is a Cannon" or "this weapon fires a Line" with no engine code at all.
# BuffWeaponType (engine/character/buff/archtypes/buff_weapon_type.gd) already filters by weapon
# type; the Line condition is the one thing it lacks.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

## Candidate for the LOS half: a WEAPON_TAG buff granting ARCING to Cannons and to Line weapons.
## ARCING, not SEEKING: SEEKING also makes ignores_cover() true (action_attack_weapon.gd:207), which
## would skip the cover calculation the second clause depends on.
class ProbeArcingTag extends BuffWeaponType:
	func _init() -> void:
		to = Buff.TO.WEAPON_TAG
		hide_from_player = true

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if not super.check_if_passive_applies(core, context): return false
		var weapon:ActionAttackWeapon = context.action
		if weapon.is_weapon_type(Lancer.WEAPON_TYPE.CANNON, context.gear): return true
		return weapon.range_pattern != null and weapon.range_pattern.pattern == Lancer.AOE_TYPE.LINE

	func get_values(core:BuffCore, context:Context) -> Context:
		return Context.create({category = Lancer.WEAPON_TAG.ARCING, number = 0})

## Candidate for the cover half: a COVER buff on the ATTACKER. CoverCalculator.determine_cover reads
## COVER buffs off both parties with a context of {unit = attacker, target_unit = target} and nothing
## else - no gear, no action (cover_calculator.gd:55-61) - so the weapon is NOT knowable here. The
## gate is instead the trait's own words: a target is attacked "this way" exactly when the attacker
## has no line of sight to it.
class ProbeBlindSoftCover extends Buff:
	func _init() -> void:
		to = Buff.TO.COVER
		hide_from_player = true

	func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
		return Unit.is_valid(context.unit) and Unit.is_valid(context.target_unit)

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if context.unit == context.target_unit: return false # the hide check asks about ourselves
		return not UnitRelation.can_see(context.unit, context.target_unit)

	func get_values(core:BuffCore, context:Context) -> Context:
		return Context.create({category = Lancer.COVER.SOFT, boolean = false}) # false: not enough to hide behind

const WALL:Array[Vector2i] = [Vector2i(2,0), Vector2i(2,1), Vector2i(2,2), Vector2i(2,3), Vector2i(2,4)]
const BEHIND_WALL := Vector2i(4,2)
const IN_THE_OPEN := Vector2i(1,2)

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)
	unit = SpecFactory.create_unit(game.map, Vector2i(0,2))

	target = SpecFactory.create_unit(game.map, BEHIND_WALL, Faction.SIDE.AI_ENEMY)
	FrameIsolation.isolate_frame(target)
	target.core.frame.stat.health = 40 # don't die
	target.core.frame.stat.evasion = 10 # only hit when we say
	target.core.full_repair()

	# A column of forbidden interior: blocks sight at every layer, gives no cover (the vanilla Seeking
	# Payload spec uses it for exactly that). A raised wall would hand the target cover of its own and
	# hide what the cover buff does.
	#
	# The flag is load-bearing. landscape_node.gd:608 treats a forbidden interior as a full-height
	# sight blocker only when map.shape.forbidden_interiors_enabled is true, and map_shape.gd:19 sets
	# that from X.current_level() when the shape is built - which, for the FIRST gamemaster a spec run
	# creates, happens before the level is current, so it comes out false and the interior is just a
	# one-tall setpiece that two size-1 units look straight over (sight runs along layer 2 here: floor
	# 1 plus a body of 1). Every later test re-uses the level, rebuilds the shape with the flag true,
	# and blocks properly - so without this line the first test in a run silently sees through the
	# wall and the rest do not.
	game.map.shape.forbidden_interiors_enabled = true
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', WALL)
	game.map.calculate_los_blockers() # vanilla's test_map_sightlines.gd re-pushes the blockers the same way

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func arm(kit_id:StringName) -> SpecificAction:
	var gear := unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	assert_true(GearCore.is_valid(gear), '%s equipped.' % kit_id)
	return SpecificAction.create(unit, gear, gear.get_solo_action())

func grant_hole_puncher() -> void:
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, ProbeArcingTag.new())
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, ProbeBlindSoftCover.new())

func preattack(specific:SpecificAction, against:Unit) -> AttackRoll.PreAttack:
	return AttackRoll.PreAttack.create(specific.to_context({target_unit = against}))

# ---------------------------------------------------------------- the fixture itself

func test_fixture_blocks_sight_and_gives_no_cover() -> void:
	assert_false(UnitRelation.can_see(unit, target), 'The wall blocks sight to the target.')
	assert_eq(CoverCalculator.determine_cover(target, unit).total, Lancer.COVER.NONE, 'Forbidden interior gives the target no cover of its own.')

# ---------------------------------------------------------------- the LOS half

func test_cannon_needs_sight_without_the_tag() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	assert_true(specific.action.requires_line_of_sight(specific), 'A plain Cannon requires line of sight.')
	assert_false(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL), 'Cannot target through the wall.')

func test_cannon_ignores_sight_with_the_tag() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	grant_hole_puncher()
	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific), 'The buff hands the Cannon ARCING.')
	assert_false(specific.action.requires_line_of_sight(specific), 'The Cannon no longer requires line of sight.')
	assert_true(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL), 'Can target through the wall.')

func test_rifle_still_needs_sight_with_the_tag() -> void:
	var specific := arm(&'mw_assault_rifle')
	grant_hole_puncher()
	assert_false(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific), 'A Rifle is left alone.')
	assert_true(specific.action.requires_line_of_sight(specific), 'A Rifle still requires line of sight.')
	assert_false(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL), 'A Rifle still cannot target through the wall.')

func test_line_weapon_of_another_type_gets_the_tag() -> void:
	var specific := arm(&'mw_rail_rifle') # a Rifle that fires a Line 10
	assert_true(specific.action.is_weapon_type(Lancer.WEAPON_TYPE.RIFLE, specific.gear), 'Fixture: the rail rifle is a Rifle, not a Cannon.')
	assert_eq(specific.action.range_pattern.pattern, Lancer.AOE_TYPE.LINE, 'Fixture: the rail rifle fires a Line.')
	var pattern:RangePattern = specific.action.range_pattern

	var before := specific.action.get_aoe_tiles_with_targets(pattern, [BEHIND_WALL], unit.tile(), specific)
	assert_false(before.has(BEHIND_WALL), 'Without the tag the line is cut off at the wall.')
	assert_false(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL), 'Without the tag the line cannot be aimed past the wall.')

	grant_hole_puncher()
	assert_false(specific.action.requires_line_of_sight(specific), 'The Line weapon no longer requires line of sight.')
	var after := specific.action.get_aoe_tiles_with_targets(pattern, [BEHIND_WALL], unit.tile(), specific)
	assert_true(after.has(Vector2i(3,2)) and after.has(BEHIND_WALL), 'With the tag the line continues past the wall.')
	assert_true(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL), 'With the tag the line can be aimed past the wall.')

## The AI never recomputes sight per query: it precalculates the sweep once and threads it through
## get_tiles_in_range. That path has to honour the tag too, or the AI would refuse shots the player
## is offered (and, for an NPC Fitzgerald, never take them).
func test_precalculated_sight_path_honours_the_tag() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	var sweep := UnitTile.get_tiles_in_los(unit)
	assert_false(Tile.in_bitwise_array(sweep, BEHIND_WALL), 'Fixture: the precalculated sweep does not reach the target.')
	assert_false(UnitTargeting.get_tiles_in_range(specific, [], Tile.INVALID, sweep).has(BEHIND_WALL), 'Without the tag the sweep governs.')

	grant_hole_puncher()
	assert_true(UnitTargeting.get_tiles_in_range(specific, [], Tile.INVALID, sweep).has(BEHIND_WALL), 'With the tag the sweep is not consulted.')

# ---------------------------------------------------------------- the cover half

func test_blind_target_gets_soft_cover() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	assert_eq(preattack(specific, target).cover, Lancer.COVER.NONE, 'Without the buff a blind shot has no cover to speak of.')

	grant_hole_puncher()
	assert_eq(preattack(specific, target).cover, Lancer.COVER.SOFT, 'With the buff the unseen target has soft cover.')

func test_seen_target_gets_no_cover_from_the_buff() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	var seen := SpecFactory.create_unit(game.map, IN_THE_OPEN, Faction.SIDE.AI_ENEMY)
	assert_true(UnitRelation.can_see(unit, seen), 'Fixture: the near target is in plain sight.')

	grant_hole_puncher()
	assert_eq(preattack(specific, seen).cover, Lancer.COVER.NONE, 'A target the attacker can see is not "attacked this way".')

# ---------------------------------------------------------------- end to end

func test_blind_cannon_shot_resolves() -> void:
	var specific := arm(&'mw_heavy_machine_gun')
	grant_hole_puncher()
	# d20 19, then ONE d6 per difficulty die. Two are queued because two are owed - Inaccurate and the
	# soft cover the buff hands out - and the run log shows exactly three pops before the damage roll.
	# The battle-log line prints the accuracy RESULT ("19-1"), not the mod count; the pop count is
	# the evidence that both applied. 19-1 still beats evasion 10.
	Dice.cheat_attack([19, 1, 1], [6, 6, 6, 6])
	await SpecFactory.use_solo(game, unit, &'mw_heavy_machine_gun', target)
	assert_gt(target.current_damage(), 0, 'The Cannon hit a target it cannot see.')
	assert_false(UnitRelation.can_see(unit, target), 'Fixture held: the target was never in sight.')
	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific), 'The tag is still granted after the attack (not consumed).')
