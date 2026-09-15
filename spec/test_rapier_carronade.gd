# SP4 Task 1: the Rapier Class Carronade, the Fitzgerald's rank III weapon.
#
# Design §5.1, rules sheet "Rank III":
#   Main Cannon, Heat 2 (self), AP. 1d6+1 kinetic, Line 8. Ignores cover and deals 10 AP kinetic
#   damage to all objects or terrain within the line.
#
# BOTH CLAUSES ARE HERE. Task 1 wrote the first (cover, heat, reach, the Hole Puncher interaction
# and the weapon's own statistics); Task 2 appended the second (10 AP kinetic to every object,
# terrain block and interior wall in the fired line) to THIS file rather than starting a second one -
# the two clauses are one weapon and splitting them across files would hide the fact that both fire
# from the same activation. Task 2's section starts at "the line's 10 AP kinetic" below and brings
# its own constants and helpers with it.
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
# file's, and Task 2 grows the same subject. test_hole_puncher.gd's marker comment now points here
# instead of holding the coverage itself - the `ignores_cover` early return in
# buff_hole_puncher_soft_cover.gd's check_if_passive_applies is exercised only by this file's
# test_on_the_fitzgerald_it_blindfires_and_still_takes_no_penalty.
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
	# The cannon lives on mw_bizarre_cannon since 2026-09-15, not on cp_broadside - see
	# test_integrated_weapon_names.gd for why the weapon needed a Kit of its own.
	var cannon_gear := unit.get_gear(&'mw_bizarre_cannon')
	assert_true(GearCore.is_valid(cannon_gear), 'fixture: the frame carries mw_bizarre_cannon.')
	if not GearCore.is_valid(cannon_gear): return
	var bizarre := SpecificAction.create(unit, cannon_gear,
		cannon_gear.get_action(&'action_bizarre_cannon'))
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

# ================================================== SP4 Task 2: the line's 10 AP kinetic
#
# Design §5.1, rules sheet "Rank III", second clause:
#   "...and deals 10 |AP| kinetic damage to all objects and terrain within the line."
#
# WHY THIS CANNOT BE AN OnHitEffect, and what pins that. The clause fires on EVERY firing - hit or
# miss, and whether or not there is anything to hit at all - so it hangs off activate(), exactly as
# the frame's own Bizarre Cannon recoil does. An implementation wired to an on-hit effect would pass
# nothing in this section: every terrain test here forces the shot to MISS, for the reason in the
# next paragraph, and both object tests fire at an object the shot cannot hit.
#
# ==== READ THIS BEFORE ADDING A TERRAIN ASSERTION: THE BASE ATTACK ALREADY WRECKS TERRAIN. ====
# An ActionAttack whose range pattern is not NONE returns true from apply_damage_to_ground
# (action_attack.gd:187-191), and event_unit_attack_declared.gd:180-196 then queues an
# event_map_damage of its own over the SAME swept tiles, carrying FLAG.AP because this weapon's
# damage is armour-piercing.
#
# HOW MUCH, AND WHY IT DOES NOT DEPEND ON WHETHER THE SHOT LANDED. The number is
# get_damage_to_terrain_and_objects(specific, base_damage) (event_unit_attack_declared.gd:183) =
# DamageRollSummary.get_non_heat_amount(damage_data.get_hits()) (action_attack.gd:57-69).
# get_hits() reads each roll's own `hit` value (attack_util.gd:127); it is never told whether the
# attack connected, and the per-attack-roll bonus damage that WOULD vary is rolled into a DUPLICATE
# summary (event_unit_attack_declared.gd:142, roll_specific_bonus_damage at :288) that never reaches
# base_damage. So for this weapon - 1d6+1, no reliable, no bonus damage - a hit and a miss put the
# SAME 7 into the ground, with the damage die cheated to a 6.
#
#   the base attack      -> event_map_damage number 7, flags [AP]  -> a standard block (health 15,
#                           armor 2) survives; two shots without the clause reach only 14
#   plus the clause      -> +10 -> 17, past the 15, in ONE firing. GamemasterCore.tile_damage
#                           accumulates across events (landscape_node.gd:813).
#
# CORRECTION, 2026-09-14. An earlier version of this banner said the base attack did 20 on a hit and
# 7 on a miss, and claimed a terrain assertion was therefore VACUOUS on a hit. That is false. The 20
# was a cheat-dice artefact: Dice.CHEAT_ROLL_QUEUE is a single FIFO (dice.gd:9, 33-35) and
# cheat_a_hit() loads [19, 6x8]; in the one RED test with nothing in the line to attack there was no
# attack roll to eat the 19, so the DAMAGE d6 popped it and 1d6+1 read 20 (sp4-t2-red.log:1252,
# which prints "if hit:20 ... if maximized:7" - 7 being the true maximum of 1d6+1, so 20 was
# impossible from a legitimate roll). Three Task 1 tests in that same log genuinely hit and read
# "if hit:7" (:701, :784, :867). The terrain tests below and their RED evidence are unaffected; only
# the reason given for them was wrong.
#
# WHAT ACTUALLY KEEPS THE TERRAIN TESTS HONEST - AND IT IS FRAGILE. See something_to_miss(). With
# the clause the margin is 7 + 10 = 17 against 15 (+2); without it, 7 against 15 (-8), so a SMALLER
# roll fails loudly, which is the safe direction. The one silent-pass direction is the base
# contribution rising to >= 15, and the cheat queue does exactly that - 7 jumps to 20 in one step -
# the moment no attack roll consumes the leading 19. So something_to_miss() standing IN the swept
# line, eating the 19, is load-bearing. Move it off the row, delete it, or aim a NEW terrain test at
# bare ground with nothing in the line, and the base damage silently becomes 20, the block dies
# without the clause, and the test passes for the engine's reason. The residual assertion in
# test_a_miss_still_cracks_the_terrain_in_its_line (TERRAIN_RESIDUAL) is the guard against that: it
# pins the exact arithmetic and moves the instant the base contribution changes.
#
# Neither of the other two halves of the clause is reachable by the base attack at all, so the
# object and interior tests need no such care: event_unit_attack_declared never sets
# ALSO_DAMAGE_OBJECTS, and it sets REMOVE_BREAKABLE_INTERIORS only when the attacker carries a
# Buff.TO.AUTODAMAGE_AGAINST_OBJECTS buff (:181, :191), which the Fitzgerald does not.
#
# EVERY SHOT IN THIS SECTION IS AIMED DOWN THE ROW y = 4, at AIM_DOWN_THE_ROW - a bare tile, not a
# unit. A Line weapon sweeps its full 8 tiles in the aimed direction regardless of what it was aimed
# at. Measured swept set, from the same RED log:
#
#   [(3,4), (4,4), (6,4), (7,4), (8,4), (9,4), (10,4)]
#
# - eight rings minus (5,4), which is a tile of before_each's forbidden-interior WALL and is dropped
# by AoeCalculator.line (see FORBIDDEN_CONTROL). THE LINE IS NOT TRUNCATED BY ANY OF IT, and that is
# not luck: the Hole Puncher trait hands this weapon ARCING
# (test_on_the_fitzgerald_it_blindfires_and_still_takes_no_penalty, above), so
# Action.get_aoe_tiles_with_targets' `if requires_line_of_sight(specific)` filter - the one that
# would drop every LINE tile behind a sight blocker - never runs.

## Exactly Line 8 east of FIRE_FROM. Aliased rather than re-typed so that "the tile the range test
## calls the last one in range" and "the tile every damage test fires at" cannot drift apart.
const AIM_DOWN_THE_ROW := IN_RANGE_AT_8

## The clause's number, and the SAME value the action script gives its constant. Asserted against
## that constant in test_the_rules_text_promises_the_damage_the_code_deals, so this is a restatement
## of the rules text rather than a second source of truth.
const LINE_DAMAGE := 10

## A block of ordinary terrain in the swept row, and the layer vanilla's own terrain test puts one
## at (test/gear/test_ms_bb_breach_blast_charges.gd:30).
const ROCK_TILE := Vector2i(7, 4)
const ROCK_LAYER := 2

## The same block, three tiles north of the row and therefore outside every sweep in this file. The
## clause has to reach the whole line and nothing else; a shot whose tile list could not be
## reconstructed and fell back to "everywhere" or to the firer's own tile would show up here.
const ROCK_OFF_THE_LINE := Vector2i(7, 1)

## Landscape.DEFAULT_BLOCK_NAME is block_grass_yellow, whose terraindata_standard_block has health 15
## and armor 2. The whole terrain arithmetic in the section header turns on these two numbers, so
## place_rocks() ASSERTS them against the TerrainBlockData the landscape actually hands back - a
## const on its own cannot fail, and GDScript does not warn on an unreferenced one, so naming them
## without checking them would have been decoration. With the check, a modkit release that retuned
## the default block fails at the fixture instead of quietly changing what every test below means.
const STANDARD_BLOCK_HEALTH := 15
const STANDARD_BLOCK_ARMOR := 2

## What the BASE ATTACK alone puts into every swept tile, hit or miss - see the section header for
## why it does not vary. Numerically the same as CARRONADE_DAMAGE (1d6+1 with the die cheated to a
## 6) but arrived at by a different route: this one is get_hits() read without an attack roll.
const BASE_GROUND_DAMAGE := 7

## What LandscapeNode leaves on the tile once the block has come down, and the assertion that keeps
## the terrain tests from going silently vacuous.
##
## damage_tile() subtracts the destroyed block's health from the running total and stashes the
## remainder back on the tile (landscape_node.gd:922-923), cascading whatever is left onto the block
## below - which is a standard block too, and survives. So the tile ends the shot holding exactly
## 7 + 10 - 15 = 2. Written as the arithmetic rather than as "2" because that is the point: if the
## base contribution ever changes - a retuned die, a bonus-damage buff, or the cheat-queue artefact
## in the section header putting 20 there - this number moves and the test says so, instead of the
## block dying for a reason that has nothing to do with the clause.
const TERRAIN_RESIDUAL := BASE_GROUND_DAMAGE + LINE_DAMAGE - STANDARD_BLOCK_HEALTH

## A hostile object in the swept row. FitzgeraldFixture.create_deployable spawns dep_jericho_cover,
## a real vanilla deployable (entity OBJECT, is_deployable true) - the same frame test_heaer.gd and
## test_reinforcement_blast.gd use, and for the same reason: it is a genuine object rather than the
## marker-ish dep_attack_ground_proxy the engine spawns for ground shots.
const OBJECT_TILE := Vector2i(8, 4)

## More than 10, so every object assertion is on the thing's HEALTH and not on whether it died -
## "it was destroyed" would be satisfied by 10 damage, by 12 damage, and by an attack roll that
## happened to land.
const OBJECT_HEALTH := 20
## 2, not 1, so the non-AP reading (8 damage) cannot be mistaken for a mis-rolled anything.
const OBJECT_ARMOR := 2

## Evasion no roll in this file can reach. cheat_a_hit() fixes the d20 at 19 and then feeds SIXES to
## every die behind it - the accuracy dice included - so the highest attack total available here is
## 19 + 6 + grit. 40 is out of reach of that by a clear margin, which is what makes "the attack
## missed" a property of the fixture rather than of the queue. (10, the evasion make_unseen_target()
## uses, is NOT enough: 19 already beats it.) Measured in the RED log as
## "rolled 19 against Enemy (40 Eva): miss."
const UNHITTABLE := 40

## The mech every terrain test aims through, so that the shot has something to miss. A CHARACTER,
## not an object, so it doubles as the assertion that the clause spares characters:
## event_map_damage's ALSO_DAMAGE_OBJECTS branch skips anything that is not is_object()
## (event_map_damage.gd:63), and this unit taking zero is what shows the 10 is not simply sprayed
## over everything in the line.
const MISSED_MECH_TILE := Vector2i(9, 4)

## A breakable interior in the swept row. It is in the swept set only because the weapon declares
## can_target_breakable_interiors (Task 1): AoeCalculator.line (:155-157) admits a tile that is
## `is_playable` OR, when that flag is on, `is_playable_or_breakable`, and map_shape.gd:41-47 lets a
## BREAKABLE interior through the second test while an ordinary forbidden one fails both.
const BREAKABLE_TILE := Vector2i(6, 4)

## The same breakable interior, three rows north of the firing row and therefore in no sweep in this
## file. THIS is what pins event_map_damage's scoping of REMOVE_BREAKABLE_INTERIORS: the flag is not
## "remove every breakable interior on the map", it filters the event's own tile list
## (event_map_damage.gd:47). Nothing else in the suite tests that - the forbidden-interior control
## below asserts a tile AoeCalculator dropped from the sweep before the event ever saw it, so it
## pins the targeting side rather than this one.
const BREAKABLE_OFF_THE_LINE := Vector2i(6, 1)

## The "left alone" half, and there is only one place it can stand. A plain forbidden interior can
## NEVER be inside a fired line - it fails both playability tests above, so AoeCalculator.line drops
## it from the sweep - which means the vanilla model's "a forbidden interior BESIDE the breakable one
## survives" is, for a LINE weapon, necessarily a tile the damage never saw. (4,4) is the strongest
## placement available: it is in the aimed row, between the firer and the breakable wall, and the RED
## log shows it in the swept set until it becomes forbidden, at which point the sweep steps over it.
## Demolishing its neighbour and skipping it is exactly the discrimination the assertion wants.
const FORBIDDEN_CONTROL := Vector2i(4, 4)

## One tile past the east edge of a 15-wide map, aimed straight down the firing row.
##
## OFF-MAP IS THE ABORT, AND THE DIRECTION IS THE POINT. Tile.is_valid bounds-checks it away inside
## TargetActionUtil.ask_for_targets_alt (target_action_util.gd:171), leaving a plan with no tiles,
## which ActionAttack.activate refuses at its abort_when(not CompconPlan.is_valid_with_targets(...))
## guard - the same branch a player cancelling the tile picker reaches, and the one
## test_swivel_gun.gd's OFF_MAP already uses. Unlike that constant this one is COLLINEAR with the
## rock: an implementation that reconstructed the line from context.target_tiles instead of from the
## declared attack would sweep straight through ROCK_TILE and be caught here.
const OFF_MAP_EAST := Vector2i(15, 4)

# ---------------------------------------------------------------- Task 2 helpers

func voxel_of(tile:Vector2i) -> Vector3i: return Tile.to_voxel(tile, ROCK_LAYER)

func index_of(tile:Vector2i) -> int:
	var voxel := voxel_of(tile)
	return Landscape.voxel_to_block_index(voxel.x, voxel.y, voxel.z)

## Put blocks of ordinary terrain down and assert they are really there. The fixture assertions are
## not decoration: every terrain test below is a claim that something WAS destroyed, and a claim like
## that reads identically when the thing was never placed.
func place_rocks(tiles:Array[Vector2i]) -> void:
	var voxels:Array[Vector3i] = []
	for tile:Vector2i in tiles: voxels.append(voxel_of(tile))
	SpecFactory.add_blocks_to_landscape(game.get_landscape_node(), Landscape.DEFAULT_BLOCK_NAME, voxels)
	assert_true(game.core.destroyed_blocks.is_empty(), 'fixture: nothing is destroyed yet.')
	for tile:Vector2i in tiles:
		var terrain:TerrainBlockData = game.get_landscape_node().get_terrain_for_voxel(voxel_of(tile))
		assert_true(terrain.is_obstruction(),
			'fixture: the rock at %s is standing.' % tile)
		assert_eq(game.core.get_current_damage_to_tile(tile), 0,
			'fixture: and it is undamaged.')
		# The two numbers the whole section's arithmetic is built on, read off the block the
		# landscape actually returns rather than trusted from terraindata_standard_block.tres. A
		# modkit release that retuned the default block fails HERE, saying so, instead of leaving
		# every "the rock came down" assertion below meaning something else.
		assert_eq(terrain.get_health(), STANDARD_BLOCK_HEALTH,
			'fixture: a standard block still has 15 health - the number the clause has to carry.')
		assert_eq(terrain.get_armor(), STANDARD_BLOCK_ARMOR,
			'fixture: and still 2 armor, which the AP flag is what waives.')

func rock_is_gone(tile:Vector2i) -> bool:
	return (
		index_of(tile) in game.core.destroyed_blocks and
		not game.get_landscape_node().get_terrain_for_voxel(voxel_of(tile)).is_obstruction()
	)

## Something in the line for the shot to miss - and the thing that makes every terrain test in this
## section non-vacuous. DO NOT MOVE IT OFF THE ROW, AND DO NOT WRITE A TERRAIN TEST WITHOUT IT.
##
## It is not decoration and it is not only about missing. Dice.CHEAT_ROLL_QUEUE is a single FIFO
## (dice.gd:9, 33-35) and cheat_a_hit() loads [19, 6x8]. This mech, standing IN the swept line at
## UNHITTABLE evasion, is what forces an attack roll to be made at all - and that roll is what
## CONSUMES the leading 19, leaving a plain 6 for the damage die and so BASE_GROUND_DAMAGE = 7.
## Take it away (move it off y=4, delete it, or aim a new terrain test at bare ground with nothing
## in the line) and the 19 falls through to the damage roll instead: 1d6+1 reads 20, the base
## attack's own ground damage alone flattens a 15-health block, and the terrain test passes whether
## or not the clause exists. That is measured, not theoretical - it is exactly what happened in the
## RED run and what the section header's CORRECTION note is about.
##
## Being a CHARACTER rather than an object is a second, smaller job: it doubles as the assertion
## that the clause spares characters (event_map_damage.gd:63 skips anything not is_object()).
func something_to_miss() -> Unit:
	return FitzgeraldFixture.create_dummy(game, MISSED_MECH_TILE, UNHITTABLE)

## Fire down the row, at bare ground. Separate from fire_at() only in that it opens the turn's action
## budget wide enough for a second shot: unit_action.gd:358 counts state.actions + overcharge_actions
## and unit_action.gd:82 zeroes the latter at turn start, so this has to happen AFTER the turn opens.
## Vanilla's own two-shot terrain test does the same thing for the same reason
## (test_ms_bb_breach_blast_charges.gd:40). It is a budget, not a behaviour: nothing below asserts on
## actions, and granting it cannot make a shot that was refused for any OTHER reason appear to work.
func fire_down_the_row(at:Vector2i = AIM_DOWN_THE_ROW) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	unit.state.overcharge_actions = 2
	cheat_a_hit() # fixes the numbers only; whether the shot lands is decided by the target's evasion
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, at)

# ---------------------------------------------------------------- terrain

## THE TEST THAT DISTINGUISHES activate() FROM AN OnHitEffect. The shot is aimed through a mech it
## CANNOT hit, so an attack was declared, rolled and missed; the base attack put its 7 into the
## terrain, the block needs 15, and it comes down anyway.
##
## The mech is also what holds the arithmetic still - see something_to_miss(). The residual
## assertion at the bottom is what makes that failure loud rather than silent.
func test_a_miss_still_cracks_the_terrain_in_its_line() -> void:
	place_rocks([ROCK_TILE])
	var dodgy := something_to_miss()

	await fire_down_the_row()

	assert_eq(dodgy.current_damage(), 0,
		'fixture: the shot MISSED - so nothing here can be explained by a hit.'
		+ ' (It also shows the 10 spares characters: event_map_damage damages only is_object() units.)')
	assert_true(index_of(ROCK_TILE) in game.core.destroyed_blocks,
		'The map records the swept voxel as destroyed...')
	assert_false(game.get_landscape_node().get_terrain_for_voxel(voxel_of(ROCK_TILE)).is_obstruction(),
		'...and the terrain there stops being an obstruction. 7 from the attack plus 10 from the'
		+ ' clause is 17, past the block\'s 15; the attack alone stopped at 7, and a second missed'
		+ ' shot without the clause only reached 14 (RED log).')
	# AND EXACTLY HOW IT CAME DOWN, not merely that it did. "The rock is gone" is true of any
	# oversized number, including the 20 the cheat queue produces when nothing in the line eats the
	# leading 19 - which would destroy the block WITHOUT the clause and pass the two assertions
	# above. Pinning the leftover to 7 + 10 - 15 makes that case fail here instead. See
	# TERRAIN_RESIDUAL and something_to_miss().
	assert_eq(game.core.get_current_damage_to_tile(ROCK_TILE), TERRAIN_RESIDUAL,
		'And it came down by exactly the expected arithmetic: 7 from the attack plus the clause\'s'
		+ ' 10 is 17, 15 of which destroyed the block, leaving 2 on the tile.')

## The clause damages the LINE, not the map. Without this, an implementation that lost its tile list
## and fell back to something wider - the whole aoe, the firer's own tiles, every tile it could find -
## would pass every other test in this section.
func test_the_line_damage_stops_at_the_edge_of_the_line() -> void:
	place_rocks([ROCK_TILE, ROCK_OFF_THE_LINE])
	var _dodgy := something_to_miss()

	await fire_down_the_row()

	assert_true(rock_is_gone(ROCK_TILE), 'control: the rock IN the line came down.')
	assert_false(rock_is_gone(ROCK_OFF_THE_LINE), 'The rock three tiles off the line did not...')
	assert_eq(game.core.get_current_damage_to_tile(ROCK_OFF_THE_LINE), 0,
		'...and took no damage at all: not a scratch, not a partial.')

# ---------------------------------------------------------------- objects

func test_an_object_in_the_line_takes_ten_with_no_attack_roll_of_its_own() -> void:
	var dep := FitzgeraldFixture.create_deployable(game, OBJECT_TILE, OBJECT_HEALTH, 0, UNHITTABLE)
	assert_true(dep.is_object(), 'fixture: a deployable is an OBJECT, which is what the clause names.')
	assert_eq(dep.core.current.health, OBJECT_HEALTH, 'fixture: and it starts at 20 health.')

	await fire_down_the_row()

	# 10, from 20, in one shot. The object is UNHITTABLE, so the attack roll made against it missed -
	# which is precisely how this shows the 10 is not the attack's damage wearing a hat: a hit would
	# have added 1d6+1 on top, and an implementation that dealt the 10 through an attack roll of its
	# own would have dealt nothing at all. The base attack's own ground damage cannot explain it
	# either: event_unit_attack_declared never sets ALSO_DAMAGE_OBJECTS (see the section header), and
	# the RED run measured this object at a full 20 health after the same shot.
	assert_eq(dep.core.current.health, OBJECT_HEALTH - LINE_DAMAGE,
		'The object took exactly 10, from a shot that could not hit it: no attack roll of its own.')

func test_the_object_damage_is_ap() -> void:
	var dep := FitzgeraldFixture.create_deployable(game, OBJECT_TILE, OBJECT_HEALTH, OBJECT_ARMOR, UNHITTABLE)
	assert_eq(dep.core.current.armor, OBJECT_ARMOR,
		'fixture: the object really has 2 armor - without this the AP claim is unfalsifiable.')

	await fire_down_the_row()

	assert_eq(dep.core.current.health, OBJECT_HEALTH - LINE_DAMAGE,
		'The full 10 landed through 2 armor: the object damage is AP. (Without AP it would be 8.)')

# ---------------------------------------------------------------- interior walls

## Ruling, 2026-09-14: the Carronade breaches interior walls. Both halves of vanilla's
## test_breaching_charge_breakable_interior are here - the breakable one goes, the forbidden one
## stays - with the placement caveat recorded on FORBIDDEN_CONTROL. A breakable interior has health 0
## and so is not destructable at all (terraindata_breakable_interior.tres); the only thing that can
## remove it is the REMOVE_BREAKABLE_INTERIORS flag, which is unconditional demolition rather than
## the 10 doing any work - the author ruled it in knowing that.
func test_a_breakable_interior_in_the_line_is_removed_and_a_forbidden_one_is_not() -> void:
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), CommonActionUtil.BREAKABLE_INTERIOR_SETPIECE, [BREAKABLE_TILE])
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), &'setpiece_forbidden_interior', [FORBIDDEN_CONTROL])
	game.map.calculate_los_blockers()

	# A breakable interior is in forbidden_interiors TOO (map_shape.gd:41-47 is what separates them),
	# so both fixture assertions read the same array and the test's whole claim is which of the two
	# is still in it afterwards.
	assert_true(Tile.in_bitwise_array(game.map.shape.breakable_interiors, BREAKABLE_TILE),
		'fixture: there is a breakable interior in the row...')
	assert_true(Tile.in_bitwise_array(game.map.shape.forbidden_interiors, FORBIDDEN_CONTROL),
		'fixture: ...and an ordinary forbidden one beside it.')

	await fire_down_the_row()

	assert_false(Tile.in_bitwise_array(game.map.shape.forbidden_interiors, BREAKABLE_TILE),
		'The Carronade breached the breakable interior.')
	assert_true(Tile.in_bitwise_array(game.map.shape.forbidden_interiors, FORBIDDEN_CONTROL),
		'And left the forbidden one exactly where it was.')

## The demolition is SCOPED TO THE FIRED LINE, and this is the only test that says so about interior
## walls. REMOVE_BREAKABLE_INTERIORS filters the event's own tile list
## (event_map_damage.gd:46-48) - it is not a map-wide "knock down every breakable wall" - and an
## implementation that handed the event a wider list, or that reached for
## map.shape.breakable_interiors directly instead of the swept tiles, would pass the test above and
## fail here. The control at the top is what stops it passing vacuously: the wall IN the line, in
## the same shot, does come down.
func test_a_breakable_interior_off_the_line_is_left_standing() -> void:
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), CommonActionUtil.BREAKABLE_INTERIOR_SETPIECE,
		[BREAKABLE_TILE, BREAKABLE_OFF_THE_LINE])
	game.map.calculate_los_blockers()

	assert_true(Tile.in_bitwise_array(game.map.shape.breakable_interiors, BREAKABLE_TILE),
		'fixture: a breakable interior in the firing row...')
	assert_true(Tile.in_bitwise_array(game.map.shape.breakable_interiors, BREAKABLE_OFF_THE_LINE),
		'fixture: ...and an identical one three rows north of it.')

	await fire_down_the_row()

	# The breached half is asserted through forbidden_interiors, exactly as the test above does it:
	# a breakable interior sits in BOTH arrays, and leaving forbidden_interiors is what "the wall is
	# gone" means for movement and sight.
	assert_false(Tile.in_bitwise_array(game.map.shape.forbidden_interiors, BREAKABLE_TILE),
		'control: the wall IN the line was breached by this very shot...')
	assert_true(Tile.in_bitwise_array(game.map.shape.breakable_interiors, BREAKABLE_OFF_THE_LINE),
		'...and the one off the line is untouched: the flag reaches the fired tiles, not the map.')
	assert_true(Tile.in_bitwise_array(game.map.shape.forbidden_interiors, BREAKABLE_OFF_THE_LINE),
		'And it still blocks movement and sight - it was not quietly half-removed.')

# ---------------------------------------------------------------- the shot that was never fired

## An activation that aborts before the attack is declared must queue NO map damage. The control at
## the bottom is what stops this passing vacuously: the rock is not merely "not destroyed", it is in
## a spot the very next shot of the very same test demolishes. (The control proves REACHABILITY only
## - on a shot that connects, the base attack would have flattened that rock by itself.)
##
## MUTATION-TESTED 2026-09-14, AND THE RESULT IS WORTH KNOWING. Moving activate()'s
## `if activation.aborted: return` to BELOW the queue_event left this test GREEN
## (.superpowers/sdd/sp4-t2-mutation-b-abort-guard-below-queue.log, 18/18) - not because the test is
## weak but because that guard is unreachable by the abort THIS test reaches: the off-map plan is
## refused at action_attack.gd:236, before context.resource is assigned at :259, so swept_tiles()
## comes back empty and the OTHER guard refuses first. (It is NOT true that every abort in
## ActionAttack.activate precedes that assignment - :266, :201 and :227 all follow it, and the
## aborted guard is the only thing covering those. The action script's header has the detail.)
## What this test actually pins is the pair of them
## together, against the realistic wrong implementation - reconstructing the line from
## context.target_tiles when the declared attack is missing, which is the fallback
## action_bizarre_cannon.gd's header warns about. With both guards dropped and that fallback in
## place, this test and only this test went red, at exactly the right assertion
## ("[10] expected to equal [0]": sp4-t2-mutation-b2-line-from-the-hint.log, 17/18). OFF_MAP_EAST is
## collinear with the rock precisely so that mutation could be caught.
func test_an_aborted_shot_wrecks_nothing() -> void:
	place_rocks([ROCK_TILE])
	var _dodgy := something_to_miss()

	await fire_down_the_row(OFF_MAP_EAST)

	assert_eq(game.core.get_current_damage_to_tile(ROCK_TILE), 0,
		'A shot that was never fired put no damage into the terrain...')
	assert_false(rock_is_gone(ROCK_TILE), '...and destroyed nothing.')

	await fire_down_the_row()
	assert_true(rock_is_gone(ROCK_TILE),
		'control: a real shot down the same row, in the same turn, wrecks that same rock.')

# ---------------------------------------------------------------- the rules text

## TASK 1 PROMISED THIS CLAUSE IN PROSE BEFORE ANY CODE KEPT IT. The localization row was written
## whole in Task 1 (the rules text had to land as one sentence or not at all), and
## test_the_carronade_has_display_text only asks that the row is non-empty - so the shipped weapon
## could have advertised 10 AP kinetic against objects and terrain while doing nothing of the sort,
## and nothing in the suite would have gone red. This test ties the promise to the code that keeps
## it: the number in the player-facing sentence is read back out of the ACTION SCRIPT'S OWN constant,
## so changing one without the other fails here.
func test_the_rules_text_promises_the_damage_the_code_deals() -> void:
	var action := _carronade()
	assert_not_null(action, 'fixture: the profile loads.')
	if action == null: return

	# Read through get_script_constant_map() rather than naming the constant on the instance:
	# GDScript resolves a `const` against the script the reference is WRITTEN in, and this spec is
	# not that script.
	var constants:Dictionary = action.get_script().get_script_constant_map()
	assert_true(constants.has('LINE_TERRAIN_DAMAGE'),
		'The action script declares its damage as a named constant.')
	if not constants.has('LINE_TERRAIN_DAMAGE'): return
	assert_eq(constants['LINE_TERRAIN_DAMAGE'], LINE_DAMAGE,
		'And it is the 10 every test in this section fires at.')

	# Against this mod's OWN compiled artifact, for the reason test_the_carronade_has_display_text
	# records: tr() would answer out of whatever translation any sibling Reag-* mod loaded.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'fixture: this mod has a compiled translation.')
	if translation == null: return
	var effect := str(translation.get_message('gear.%s.%s.effect' % [KIT_ID, ACTION_ID]))
	# "objects OR terrain", which is the LCP's own conjunction. This read "and terrain" until
	# 2026-09-14, when the card was swept back to the LCP's wording under the author's localization
	# directive and this assertion went red - correctly, and for the wrong reason: the conjunction
	# was never what it is here to pin. What it pins is the NUMBER, which is why LINE_DAMAGE is
	# interpolated rather than written out. Match the source's phrasing, keep the number binding.
	assert_string_contains(effect, '%d |AP| kinetic damage to all objects or terrain' % LINE_DAMAGE,
		'The rules text promises exactly the number the code deals.')
