# SP4 Task 1: the Rapier Class Carronade, the Fitzgerald's rank III weapon.
#
# Design §5.1, rules sheet "Rank III":
#   Main Cannon, Heat 2 (self), AP. 1d6+1 kinetic, Line 8. Ignores cover and deals 10 AP kinetic
#   damage to all objects or terrain within the line.
#
# THIS FILE COVERS THE FIRST CLAUSE ONLY: cover, heat, reach, the Hole Puncher interaction and the
# weapon's own statistics. The 10 AP kinetic against objects, terrain and interior walls is SP4
# Task 2, which appends its tests to THIS file rather than starting a second one - the two clauses
# are one weapon and splitting them across files would hide the fact that both fire from the same
# activation.
#
# WHY "IGNORES COVER" IS A METHOD OVERRIDE AND NOT A TAG, stated here because it is what the two
# cover tests below are shaped around. There is no "ignores cover" weapon tag in Lancer.WEAPON_TAG;
# attack_roll.gd:153-157 gates the WHOLE cover block on `not action.ignores_cover(context)`, an
# ordinary method on ActionAttackWeapon (action_attack_weapon.gd:206-212, natively true only for
# SEEKING and for a melee weapon with threat). So the only seam is the method, and the only
# observable consequence is that PreAttack.cover stays NONE and no cover line is added to the
# breakdown. That is a NEGATIVE claim, and a negative claim about cover passes just as well when the
# geometry never gave cover in the first place - hence the vanilla-Cannon control in
# test_a_target_behind_hard_cover_is_attacked_at_no_cover_penalty: the same target, the same tile,
# the same instant, through a Cannon that does NOT ignore cover.
#
# WHY THE HOLE PUNCHER TEST IS HERE AND NOT IN test_hole_puncher.gd. SP1 left a marker in that file
# saying the Carronade's test would be added there. The SP4 plan moved it: the claim is about THIS
# weapon (that it ignores cover, and so drops out of the trait's gate), the fixture it needs is this
# file's, and Task 2 grows the same subject. test_hole_puncher.gd keeps the trait-side half - the
# `ignores_cover` early return in buff_hole_puncher_soft_cover.gd's check_if_passive_applies - and
# its marker comment now points here.
#
# DICE. The all-sixes buffer trick is SP1's, and its reasoning is in test_bizarre_cannon.gd:155-164:
# Dice.cheat_attack APPENDS, so every helper clears the queue first, and the buffer is longer than
# any plausible number of accuracy/damage dice so that the damage die is a 6 whatever the attack ate
# ahead of it. The hit is guaranteed by the target's evasion, not by the dice.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rapier_carronade.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const KIT_ID := &'mw_rapier_class_carronade'
const ACTION_ID := &'action_rapier_carronade'
const LICENSE_ID := &'li_fitzgerald'

## Read THIS MOD'S OWN compiled artifact rather than the global tr(), so a display-text assertion is
## attributable to this mod and not to a sibling Reag-* mod loaded in the same testkit run. Same
## pattern as test_swivel_gun.gd:56 and test_content_integrity.gd:107.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The row the Hole Puncher penalty is labelled with, read through tr() rather than hardcoded prose
## so this file pins the WIRING (buff -> localization row -> AccuracyMod.title) the same way
## test_hole_puncher.gd:51 does.
const SOFT_COVER_KEY := 'gear.buff_hole_puncher_soft_cover.name'

## A VANILLA Cannon, used as the control for the cover claim. mw_mortar is already vetted by this
## mod's own test_hole_puncher.gd:391-405: it is weapon_type CANNON, it is ARCING but NOT SEEKING,
## and its ignores_cover() is therefore false - which is exactly the shape a control needs. Its
## Inaccurate tag puts an extra line in the breakdown and is harmless here: nothing below counts the
## mods, only which of them are cover lines.
const CONTROL_CANNON := &'mw_mortar'

# ---------------------------------------------------------------- the map
#
# 15x9 rather than Landscape.create_default()'s 5x5 (Tile.MIN_MAP_DIMENSION): the range test needs
# nine clear tiles east of the firer to tell "in range at 8" from "out of range at 9", and the
# blindfire test needs a sight-blocking wall with room on both sides of it.
const MAP_SIZE := Vector2i(15, 9)
const FIRE_FROM := Vector2i(2, 4)

## A column of forbidden interior spanning the map north to south: blocks sight at every layer and
## gives no cover of its own. Lifted from test_hole_puncher.gd:65-68, which is where the shape and
## the "gives no cover" property are established. Everything east of x=5 is unseen.
const WALL:Array[Vector2i] = [
	Vector2i(5,0), Vector2i(5,1), Vector2i(5,2), Vector2i(5,3), Vector2i(5,4),
	Vector2i(5,5), Vector2i(5,6), Vector2i(5,7), Vector2i(5,8),
]
const BEHIND_WALL := Vector2i(8, 4) ## the unseen target, 6 tiles away so it is inside Line 8

## The seen target, due south of the firer and 4 tiles away, with a raised block ADJACENT to it -
## which is what CoverCalculator scores as HARD cover (cover_calculator.gd:154-156: adjacent = HARD,
## further away = SOFT). The same geometry test_hole_puncher.gd:76-77 uses, and that file already
## proves both halves of it: the Fitzgerald can see over a 1-high block, and the block gives the
## target HARD cover.
const SEEN_SOUTH := Vector2i(2, 8)
const HARD_COVER_FOR_SEEN := Vector2i(2, 7)

## Line 8 exactly: (2,4) to (10,4) is 8 tiles, (2,4) to (11,4) is 9. Asserted as tiles rather than
## only as get_target_range() == 8 because the range number and the targetable set are computed by
## different code (action_attack_weapon.gd:202-203 versus UnitTargeting.get_tiles_in_range), and a
## range_pattern that landed on the action but not on its target_requirements_override would leave
## the first right and the second wrong.
const IN_RANGE_AT_8 := Vector2i(10, 4)
const OUT_OF_RANGE_AT_9 := Vector2i(11, 4)

## 1d6+1 with the damage die cheated to a 6. The exact number is the point: it is what proves the
## die size and the flat +1 are both wired, rather than merely that "some damage happened".
const CARRONADE_DAMAGE := 7

## Armor given to the target for the AP test only. 2 rather than 1 so the non-AP reading (5) cannot
## be confused with a mis-rolled die.
const AP_TEST_ARMOR := 2

const SELF_HEAT := 2

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	# forbidden_interiors_enabled is set true by FitzgeraldFixture.create_game() - see its header for
	# why the flag has to be true before the wall below is placed.
	game = FitzgeraldFixture.create_game(self, MAP_SIZE)
	unit = FitzgeraldFixture.create_fitzgerald(game, FIRE_FROM)
	# equip_system works for a weapon Kit as well as a system - it just appends to equipped_kits
	# (loadout_core.gd:337-339). The gun takes no mount this way, which is fine: the Fitzgerald's
	# single Main mount is not what is under test here. test_swivel_gun.gd:82-88 equips its weapon the
	# same way and records the same reasoning.
	unit.core.equip_system(KIT_ID)
	SpecFactory.apply_passive_buffs(unit)
	# Evasion -10: every test in this file that actually fires wants a guaranteed hit, and none of
	# them is about missing. (Task 2's miss test brings its own.)
	target = FitzgeraldFixture.create_dummy(game, SEEN_SOUTH, -10)

	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', WALL)
	game.map.calculate_los_blockers() # vanilla's test_map_sightlines.gd re-pushes the blockers the same way

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Kit.is_valid, NOT `kit is Kit`. ContentLibrary.get_kit (content_library.gd:231-236) logs an error
## and then hands back the PLACEHOLDER kit (Kit.UNKNOWN_ID = mt_missing_mechsystem) for an id it does
## not know - so `kit is Kit` is true for a weapon that does not exist and an assert_not_null on it
## passes vacuously. test_swivel_gun.gd:100-107 measured exactly that during its own RED run.
func _kit() -> Kit:
	var kit = ContentLibrary.get_kit(KIT_ID)
	return kit if Kit.is_valid(kit) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

func _gear() -> GearCore:
	var gear := unit.get_gear(KIT_ID)
	return gear if GearCore.is_valid(gear) else null

func _carronade() -> ActionAttackWeapon:
	var gear := _gear()
	if gear == null: return null
	var action := gear.get_action(ACTION_ID)
	return action if action is ActionAttackWeapon else null

func _specific() -> SpecificAction:
	var gear := _gear()
	if gear == null: return null
	return SpecificAction.create(unit, gear, gear.get_action(ACTION_ID))

## Equip a vanilla weapon Kit on the Fitzgerald and hand back something firable. Re-applies the
## passive buffs afterwards the way spawning would; the Hole Puncher buffs do not stack
## (multiple_copies_can_stack is false, so unit_condition.gd:740-747 clears the older copy).
## test_hole_puncher.gd:123-127 is the same helper.
func arm(kit_id:StringName) -> SpecificAction:
	var gear := unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	assert_true(GearCore.is_valid(gear), '%s equipped.' % kit_id)
	return SpecificAction.create(unit, gear, gear.get_solo_action())

func preattack(specific:SpecificAction, against:Unit) -> AttackRoll.PreAttack:
	return AttackRoll.PreAttack.create(specific.to_context({target_unit = against}))

func mod_titles(pre:AttackRoll.PreAttack) -> Array:
	return pre.accuracy_mods.map(func(accmod) -> String: return accmod.title_key)

## Every accuracy mod on a roll whose title is the Hole Puncher row, as a list of their values.
## attack_roll.gd:188 passes buff_core.name_text() - already TRANSLATED - as the mod's title_key, so
## the comparison is against tr(SOFT_COVER_KEY). test_hole_puncher.gd:153-158 is the same helper.
func trait_mods(pre:AttackRoll.PreAttack) -> Array:
	var wanted := tr(SOFT_COVER_KEY)
	var found:Array = []
	for accmod in pre.accuracy_mods:
		if accmod.title_key == wanted: found.append(accmod.mod)
	return found

## An enemy behind the wall: unseen from FIRE_FROM, and inside Line 8. Built per-test rather than in
## before_each because only the blindfire tests want a second body on the map.
func make_unseen_target() -> Unit:
	return FitzgeraldFixture.create_dummy(game, BEHIND_WALL, 10) # only hit when we say

## Raise one tile of terrain, so it can serve as cover. test_hole_puncher.gd:116-118.
func raise_cover_at(tile:Vector2i) -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 1, [tile])
	game.map.calculate_los_blockers()

func fire_at(tile:Vector2i) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, tile)

## A guaranteed hit whose damage die is a 6. The target's evasion (-10, from before_each) is what
## guarantees the hit; the queue only fixes the numbers. Clears first - Dice.cheat_attack appends.
func cheat_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6, 6, 6])

# ---------------------------------------------------------------- the Kit and the licence

func test_the_carronade_is_registered_and_granted_at_licence_rank_3() -> void:
	var kit := _kit()
	assert_not_null(kit, '%s loads as a valid Kit through ContentLibrary.' % KIT_ID)
	if kit == null: return
	# Registration, not merely parsing: ContentLibrary files by FILENAME PREFIX, and mw_ is what puts
	# this in the kits index at all.
	assert_eq(kit.compcon_id, KIT_ID, 'And it is filed under its own id, not the missing-gear stub.')
	assert_false(kit.is_trait,
		'It is equippable gear, not a frame trait - so it is destructible and takes a weapon slot.')
	assert_eq(kit.sp_cost, 0, 'The Carronade costs SP 0.')
	assert_eq(kit.actions.size(), 1, 'One action: the shot itself.')

	var license := _license()
	assert_not_null(license, 'fixture: %s loads.' % LICENSE_ID)
	if license == null: return
	assert_not_null(license.rank_3, 'fixture: the licence has a rank_3.')
	if license.rank_3 == null: return
	var granted:Array = license.rank_3.granted_gear.map(func(g:Kit) -> StringName: return g.compcon_id)
	assert_has(granted, KIT_ID, 'Licence rank 3 grants the Carronade.')
	# Ranks 1 and 2 must not have been disturbed by the edit that filled rank 3 - the rank_3 block had
	# no granted_gear line at all before this task, so the edit had to add one.
	assert_true(license.rank_1 != null and license.rank_1.granted_gear.size() == 2,
		'Rank 1 still grants its two kits.')
	assert_true(license.rank_2 != null and not license.rank_2.granted_frames.is_empty(),
		'Rank 2 still grants the frame.')

	# And it survives the trip onto a live unit, which is what makes it fireable at all.
	assert_not_null(_gear(), 'A Fitzgerald that equipped it carries it as gear.')
	assert_not_null(_carronade(), '%s carries %s as an ActionAttackWeapon.' % [KIT_ID, ACTION_ID])

func test_the_carronade_has_display_text() -> void:
	# Asserted against the compiled ARTIFACT rather than the csv, because Translate loads
	# localizations.en.translation and never reads the csv beside it: an edited csv that was never
	# re-scanned leaves a correct-looking source file next to an artifact that has never heard of
	# these keys. (filesystem_manage(op="reimport") does NOT regenerate it; only op="scan" and the
	# headless --import do.)
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in [
		'gear.%s.name' % KIT_ID,
		'gear.%s.effect' % KIT_ID,
		'gear.%s.%s.name' % [KIT_ID, ACTION_ID],
		'gear.%s.%s.effect' % [KIT_ID, ACTION_ID],
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

# ---------------------------------------------------------------- the weapon's statistics

func test_it_is_a_main_cannon_firing_a_line_8() -> void:
	var action := _carronade()
	assert_not_null(action, 'fixture: the profile loads.')
	if action == null: return

	assert_eq(action.get_id(), ACTION_ID, 'The action ids itself off its own filename.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'weapon_type is CANNON.')
	# MAIN, not HEAVY. ActionAttackWeapon has no action_type export at all - get_action_type
	# (action_attack_weapon.gd:87-91) derives it from weapon_size, returning FULL only for
	# SUPERHEAVY - so "Main Cannon" and "a QUICK action" are the same fact, and weapon_size is the
	# only place it is written down.
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'weapon_size is MAIN.')
	assert_eq(action.damage_dice, '1d6+1', 'damage_dice is 1d6+1.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'damage_type is KINETIC.')
	assert_eq(action.self_heat_dice, '2', 'Heat 2 (self).')

	assert_not_null(action.range_pattern, 'The profile has a range pattern.')
	if action.range_pattern == null: return
	assert_eq(action.range_pattern.pattern, Lancer.AOE_TYPE.LINE, 'The pattern is a LINE.')
	assert_eq(action.range_pattern.value, 8, 'The line is 8 long.')

	var specific := _specific()
	if specific == null: return
	assert_eq(action.get_action_type(specific), Lancer.ACTION.QUICK,
		'A Main weapon is a QUICK action.')
	# Asked through a SpecificAction rather than the raw `tags` array: has_tag reads get_weapon_tags,
	# which is also where weapon mods and WEAPON_TAG buffs would add or remove one, so this is the
	# value the attack pipeline will actually see.
	assert_true(action.has_tag(Lancer.WEAPON_TAG.AP, specific), 'AP.')
	assert_false(action.has_tag(Lancer.WEAPON_TAG.SEEKING, specific),
		'NOT Seeking - which would make ignores_cover() true for a reason that is not ours, and would'
		+ ' make the cover tests below pass without the override existing.')

func test_its_targeting_reaches_through_setpieces_and_interior_walls() -> void:
	# Ruling: the line reaches through interior walls, which is the targeting half of Task 2's
	# demolition clause. The flags are asserted in Task 1 even though nothing exercises them until
	# Task 2, because they are part of the weapon's declaration and a .tres edit that dropped them
	# would otherwise go unnoticed until the Task 2 tests were written.
	#
	# A target_requirements_override REPLACES the whole generated block (action_attack_weapon.gd:
	# 216-223), it does not merge into it - so the two flags a weapon gets by default,
	# can_target_setpieces and can_target_empty_tiles, have to be re-declared here or the override
	# silently takes them away. That is what the last two assertions are for.
	var action := _carronade()
	var specific := _specific()
	if action == null or specific == null: return

	var reqs := action.get_target_requirements(specific)
	assert_not_null(action.target_requirements_override,
		'The Carronade declares its own TargetRequirements rather than taking the generated one.')
	assert_true(reqs.can_target_breakable_interiors,
		'It can target a breakable interior: the line is not truncated at the first interior wall.')
	assert_true(reqs.can_target_setpieces, 'It can target a setpiece, as every weapon can by default.')
	assert_true(reqs.can_target_empty_tiles,
		'And an empty tile - which an AOE weapon gets by default, and which the override must not'
		+ ' silently revoke.')
	# The override carries the range pattern too, and it must be the SAME line: ranged_distance
	# (action_attack_weapon.gd:182-184) reads reqs.range_pattern while get_target_range (:202-203)
	# reads the action's own range_pattern, so two different patterns would make the weapon's reach
	# depend on which function asked.
	assert_not_null(reqs.range_pattern, 'The override carries a range pattern.')
	if reqs.range_pattern == null: return
	assert_eq(reqs.range_pattern.pattern, Lancer.AOE_TYPE.LINE, 'It is a LINE...')
	assert_eq(reqs.range_pattern.value, 8, '...and it is 8 long, the same as the action\'s own.')

func test_the_line_reaches_eight_tiles_and_not_nine() -> void:
	var action := _carronade()
	var specific := _specific()
	if action == null or specific == null: return

	assert_eq(action.get_target_range(specific), 8, 'The Carronade reaches 8.')
	var in_range := UnitTargeting.get_tiles_in_range(specific)
	assert_true(in_range.has(IN_RANGE_AT_8), 'A tile 8 tiles away is in range.')
	assert_false(in_range.has(OUT_OF_RANGE_AT_9), 'A tile 9 tiles away is not.')

# ---------------------------------------------------------------- ignores cover

## THE TEST THE WHOLE OVERRIDE EXISTS FOR, and the control is half of it. "No cover penalty" is a
## negative claim, and a negative claim about cover reads exactly the same when the geometry never
## gave any cover at all - a raised block placed one tile off, a sight calculation that was never
## re-pushed, a target that moved. The vanilla Cannon fired at the SAME target from the SAME tile in
## the SAME instant is what makes the geometry's own contribution visible, so this test fails if the
## cover is zero for any reason other than the Carronade's own ignores_cover().
func test_a_target_behind_hard_cover_is_attacked_at_no_cover_penalty() -> void:
	raise_cover_at(HARD_COVER_FOR_SEEN)
	var specific := _specific()
	if specific == null: return

	# Fixture, stated three ways, because all three have to hold for the control to mean anything.
	assert_true(UnitRelation.can_see(unit, target),
		'fixture: the target is SEEN - so Hole Puncher stays out of this entirely and the only thing'
		+ ' erasing cover can be the weapon.')
	assert_eq(CoverCalculator.determine_cover(target, unit).total, Lancer.COVER.HARD,
		'fixture: this geometry really does give the target HARD cover.')

	var control := arm(CONTROL_CANNON)
	assert_true(control.action.is_weapon_type(Lancer.WEAPON_TYPE.CANNON, control.gear),
		'fixture: %s is a vanilla Cannon.' % CONTROL_CANNON)
	assert_false(control.action.ignores_cover(control.to_context({target_unit = target})),
		'fixture: and it does NOT ignore cover, so the cover query really runs for it.')
	var control_pre := preattack(control, target)
	assert_eq(control_pre.cover, Lancer.COVER.HARD,
		'control: the vanilla Cannon faces HARD cover against this target from this tile.')
	assert_true(mod_titles(control_pre).has(Lancer.cover_name(Lancer.COVER.HARD)),
		'control: and a hard-cover line appears in its accuracy breakdown.')

	# And the Carronade, against the same target, from the same tile, at the same instant.
	var pre := preattack(specific, target)
	assert_eq(pre.cover, Lancer.COVER.NONE, 'The Carronade faces no cover at all.')
	assert_true(pre.cover_sources.is_empty(), 'It records no cover sources either.')
	assert_false(mod_titles(pre).has(Lancer.cover_name(Lancer.COVER.HARD)),
		'No hard cover line in its breakdown...')
	assert_false(mod_titles(pre).has(Lancer.cover_name(Lancer.COVER.SOFT)),
		'...and no soft cover line either.')

func test_the_weapon_reports_that_it_ignores_cover() -> void:
	# The seam itself, asked directly. The test above observes the CONSEQUENCE through the whole
	# attack-roll path; this one pins the function, because buff_hole_puncher_soft_cover.gd calls it
	# by name (`if context.action.ignores_cover(context): return false`) and would keep compiling
	# against an ActionAttackWeapon that had quietly lost the override.
	var specific := _specific()
	if specific == null: return
	assert_true(specific.action.ignores_cover(specific.to_context({target_unit = target})),
		'ignores_cover() answers true.')
	# Against a target it cannot see, too: the override takes no context into account and must not
	# start doing so, or the Hole Puncher gate below would read differently from this one.
	var unseen := make_unseen_target()
	assert_true(specific.action.ignores_cover(specific.to_context({target_unit = unseen})),
		'Unconditionally - the same answer against an unseen target.')

# ---------------------------------------------------------------- the Hole Puncher interaction

## Design §5.1's last paragraph, and the assertion that pins buff_hole_puncher_soft_cover.gd's
## `if context.action.ignores_cover(context): return false` early return. On the Fitzgerald the
## Carronade is a Cannon AND a Line weapon, so the trait hands it ARCING and it can be aimed at a
## target nobody can see - but the trait's -1 is the price of "attacked this way", and a weapon that
## ignores cover in its own right is not made worse by it: there is no cover for the trait's soft
## cover to be "exactly" equal to.
func test_on_the_fitzgerald_it_blindfires_and_still_takes_no_penalty() -> void:
	var specific := _specific()
	if specific == null: return
	var unseen := make_unseen_target()
	assert_false(UnitRelation.can_see(unit, unseen), 'fixture: the target is behind the wall, unseen.')

	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific),
		'Hole Puncher hands the Carronade ARCING, because it is a Cannon and fires a Line.')
	assert_false(specific.action.requires_line_of_sight(specific),
		'So it no longer requires line of sight...')
	assert_true(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL),
		'...and the unseen target can be aimed at.')

	var pre := preattack(specific, unseen)
	assert_eq(trait_mods(pre), [],
		'And NO "Soft cover (Hole Puncher)" -1 appears: the trait steps aside for a weapon that'
		+ ' already ignores cover.')
	assert_eq(pre.cover, Lancer.COVER.NONE, 'Nor any cover of its own.')

	# The control, and it is what stops this passing against a trait that was never applied: the
	# Fitzgerald's OWN Bizarre Cannon, same unit, same target, same instant, DOES take the -1.
	var broadside := unit.get_gear(&'cp_broadside')
	assert_true(GearCore.is_valid(broadside), 'fixture: the frame carries cp_broadside.')
	if not GearCore.is_valid(broadside): return
	var bizarre := SpecificAction.create(unit, broadside, broadside.get_action(&'action_bizarre_cannon'))
	assert_eq(trait_mods(preattack(bizarre, unseen)), [-1],
		'control: the trait IS live here - the Bizarre Cannon takes its -1 against the same target.')

# ---------------------------------------------------------------- firing it

func test_firing_heats_the_fitzgerald_by_two() -> void:
	assert_eq(unit.core.current.heat, 0, 'fixture: the firer starts cold.')
	cheat_a_hit()
	await fire_at(SEEN_SOUTH)
	assert_eq(unit.core.current.heat, SELF_HEAT,
		'The Carronade heats its own user by exactly 2.')

func test_it_deals_one_d6_plus_one_kinetic() -> void:
	cheat_a_hit()
	await fire_at(SEEN_SOUTH)
	# Exactly 7 - a cheated 6 plus the flat 1, through the fixture's armor 0. "More than zero" would
	# be satisfied by any damage at all, including a die of the wrong size.
	assert_eq(target.current_damage(), CARRONADE_DAMAGE,
		'The Carronade dealt 1d6+1: a cheated 6 and the flat +1.')

func test_the_shot_is_ap() -> void:
	# The behavioural half of the AP tag. The statistics test above asks has_tag; this one asks the
	# damage pipeline, which is the only place the tag has to mean anything.
	target.core.frame.stat.armor = AP_TEST_ARMOR
	target.core.full_repair()
	assert_eq(target.core.current.armor, AP_TEST_ARMOR, 'fixture: the target really has 2 armor.')

	cheat_a_hit()
	await fire_at(SEEN_SOUTH)
	assert_eq(target.current_damage(), CARRONADE_DAMAGE,
		'The full 1d6+1 landed through 2 armor: the shot is AP. (Without AP it would be 5.)')
