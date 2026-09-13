# SP1 Task 5: Hole Puncher (mt_hole_puncher), the Fitzgerald's blindfire trait.
#
#   The Fitzgerald may ignore line of sight when attacking with Cannon or Line weapons. Targets
#   attacked this way have soft cover.
#
# Replaces spec/test_spike_hole_puncher.gd, whose nine probe tests built the two candidate buffs in
# memory. They are rewritten here against the real .tres content, applied the way the game applies
# it - SpecFactory.apply_passive_buffs(unit) walking the frame's trait Kits - plus five tests for
# the design's four rulings (design doc §2.1, rulings 1-4).
#
# THE TRAIT IS THREE BUFFS, and each one is separately load-bearing:
#
#   buff_hole_puncher_arcing       WEAPON_TAG    grants ARCING to Cannons and Line weapons, which is
#                                                what makes requires_line_of_sight answer false
#   buff_hole_puncher_ignore_cover IGNORE_COVER  while blind to the target, erases cover geometry:
#                                                PreAttack.create skips CoverCalculator entirely
#                                                when the attacker holds any IGNORE_COVER buff
#                                                (attack_roll.gd:153-157)
#   buff_hole_puncher_soft_cover   ATTACK_ROLL   puts the trait's own soft cover back, as a labelled
#                                                constant -1
#
# A silently-dead buff looks exactly like "the engine just does not do that", so every behavioural
# test here pairs the claim with revoke_buffs() - clearing ONE of the three off the live unit and
# showing the behaviour goes away. That is the only evidence that a given buff fired rather than the
# engine doing it anyway.
#
# WHY THE COVER HALF IS ATTACKER-SIDE and not a Buff.TO.COVER buff (do not "simplify" this):
# CoverCalculator.determine_cover merges COVER buffs from both units with geometry and keeps the
# best (max-then-zero), and its buff context carries only {unit, target_unit} - no gear, no action.
# So that channel can express neither ruling 2 ("exactly soft", even behind a wall that would give
# HARD) nor ruling 3 (exact to Cannon and Line). The attack-roll context can: PreAttack.create takes
# context.target_unit, context.action and context.gear.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_fitzgerald'
const TRAIT_ID := &'mt_hole_puncher'
const KIT_ID := &'cp_broadside'
const ACTION_ID := &'action_bizarre_cannon'

const BUFF_ARCING := &'buff_hole_puncher_arcing'
const BUFF_IGNORE_COVER := &'buff_hole_puncher_ignore_cover'
const BUFF_SOFT_COVER := &'buff_hole_puncher_soft_cover'
const TRAIT_BUFFS:Array[StringName] = [BUFF_ARCING, BUFF_IGNORE_COVER, BUFF_SOFT_COVER]

## The row the roll breakdown shows for the trait's penalty. Asserted through tr() rather than
## hardcoded prose so the test pins the WIRING (buff -> localization row -> AccuracyMod.title)
## rather than the copy.
const SOFT_COVER_KEY := 'gear.buff_hole_puncher_soft_cover.name'

# ---------------------------------------------------------------- the map
#
# 15x9 rather than Landscape.create_default()'s 5x5 (Tile.MIN_MAP_DIMENSION), for two reasons: the
# Bizarre Cannon's 2-space recoil needs clear tiles behind the firer, and the ruling-1 test needs a
# SEEN target far enough away that its adjacent cover is not inside the "ignore terrain next to the
# attacker" grace (cover_calculator.gd:146-147).
const MAP_SIZE := Vector2i(15, 9)
const FIRE_FROM := Vector2i(2, 4)

## A column of forbidden interior spanning the map north to south: blocks sight at every layer and
## gives no cover of its own (the vanilla Seeking Payload spec uses it for exactly that). Everything
## east of x=5 is therefore unseen; everything west of it is in plain sight.
const WALL:Array[Vector2i] = [
	Vector2i(5,0), Vector2i(5,1), Vector2i(5,2), Vector2i(5,3), Vector2i(5,4),
	Vector2i(5,5), Vector2i(5,6), Vector2i(5,7), Vector2i(5,8),
]
const BEHIND_WALL := Vector2i(8, 4)   ## the unseen target
const IN_THE_OPEN := Vector2i(4, 4)   ## a target on our side of the wall, in plain sight

## Raised terrain ADJACENT to a target is what CoverCalculator scores as HARD cover
## (cover_calculator.gd:154-156: adjacent = HARD, further away = SOFT). One block east of the
## unseen target, one north of the seen one.
const HARD_COVER_FOR_UNSEEN := Vector2i(7, 4)
const SEEN_FAR := Vector2i(2, 8)
const HARD_COVER_FOR_SEEN := Vector2i(2, 7)

## Vanilla Launcher, natively Arcing, no range pattern - so it ignores sight on its own merits and
## the trait must NOT touch it (ruling 3).
const VANILLA_ARCING_LAUNCHER := &'mw_sharanga_missiles'

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self, true,
		SpecFactory.create_combat(Landscape.create_default(MAP_SIZE)))

	unit = SpecFactory.create_unit(game.map, FIRE_FROM)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	# NOT FrameIsolation'd, for the reason test_bizarre_cannon.gd:95 gives: a deep duplicate of the
	# frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily-derived bare var
	# that does not survive duplicate(), and unit.get_gear(&'cp_broadside') then finds nothing.
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs

	target = SpecFactory.create_unit(game.map, BEHIND_WALL, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(target) # we DO rewrite this one's stats
	target.core.frame.stat.health = 200 # never dies; a death mid-spec would end the scene
	target.core.frame.stat.armor = 0
	target.core.frame.stat.evasion = 10 # only hit when we say
	target.core.full_repair()

	# The flag is load-bearing and its absence is SILENT. landscape_node.gd:608 treats a forbidden
	# interior as a full-height sight blocker only when map.shape.forbidden_interiors_enabled is
	# true, and map_shape.gd:19 sets that from X.current_level() when the shape is built - which,
	# for the FIRST gamemaster a spec run creates, happens before the level is current, so it comes
	# out false and the interior is just a one-tall setpiece that two size-1 units look straight
	# over (sight runs along layer 2 here: floor 1 plus a body of 1). Every later test re-uses the
	# level, rebuilds the shape with the flag true, and blocks properly - so without this line the
	# first test in a run silently sees through the wall and the rest do not.
	game.map.shape.forbidden_interiors_enabled = true
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', WALL)
	game.map.calculate_los_blockers() # vanilla's test_map_sightlines.gd re-pushes the blockers the same way

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Raise one tile of terrain, so it can serve as cover. Kept out of before_each: most tests want the
## forbidden-interior wall's "blocks sight, gives no cover" shape, and only the ruling-1 and
## ruling-2 tests want geometry that would hand the target real cover.
func raise_cover_at(tile:Vector2i) -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 1, [tile])
	game.map.calculate_los_blockers()

## Equip a vanilla weapon Kit on the Fitzgerald and hand back something firable. Re-applies the
## passive buffs afterwards the way spawning would; the trait's buffs do not stack
## (multiple_copies_can_stack is false, so unit_condition.gd:740-747 clears the older copy).
func arm(kit_id:StringName) -> SpecificAction:
	var gear := unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	assert_true(GearCore.is_valid(gear), '%s equipped.' % kit_id)
	return SpecificAction.create(unit, gear, gear.get_solo_action())

## The Bizarre Cannon's base profile, off the frame's own cp_broadside trait Kit.
func cannon() -> SpecificAction:
	var gear := unit.get_gear(KIT_ID)
	assert_true(GearCore.is_valid(gear), 'The frame carries %s.' % KIT_ID)
	if not GearCore.is_valid(gear): return null
	return SpecificAction.create(unit, gear, gear.get_action(ACTION_ID))

## Clear named trait buffs off the live unit. This is the discriminator the whole file leans on:
## a behaviour that survives revoking the buff that supposedly causes it was never caused by it.
func revoke_buffs(buff_ids:Array[StringName]) -> void:
	var to_clear:Array[BuffCore] = []
	for buff_id:StringName in buff_ids: to_clear.append_array(UnitCondition.get_buffs(unit, buff_id))
	assert_eq(to_clear.size(), buff_ids.size(), 'fixture: revoking %s found them all applied.' % [buff_ids])
	UnitCondition.clear_buffs(SpecFactory.dummy_event(), unit, to_clear)

func preattack(specific:SpecificAction, against:Unit) -> AttackRoll.PreAttack:
	return AttackRoll.PreAttack.create(specific.to_context({target_unit = against}))

## Every accuracy mod on a roll whose title is the trait's row, as a list of their values.
##
## attack_roll.gd:188 passes buff_core.name_text() as the mod's title_key - already TRANSLATED,
## unlike the vanilla cover and status lines beside it, which pass raw keys. So the comparison is
## against tr(SOFT_COVER_KEY), and it fails loudly if the buff's localization row goes missing
## (name_text would hand back the bare key, or an empty string if an override stopped resolving).
func trait_mods(pre:AttackRoll.PreAttack) -> Array:
	var wanted := tr(SOFT_COVER_KEY)
	var found:Array = []
	for accmod in pre.accuracy_mods:
		if accmod.title_key == wanted: found.append(accmod.mod)
	return found

func mod_titles(pre:AttackRoll.PreAttack) -> Array:
	return pre.accuracy_mods.map(func(accmod) -> String: return accmod.title_key)

## The icon the trait's breakdown line is drawn with, or null if the line is not there.
func trait_mod_icon(pre:AttackRoll.PreAttack) -> Texture2D:
	var wanted := tr(SOFT_COVER_KEY)
	for accmod in pre.accuracy_mods:
		if accmod.title_key == wanted: return accmod.icon
	return null

# ---------------------------------------------------------------- registration and the fixture

func test_the_trait_is_registered_and_applies_its_three_buffs():
	var kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(kit is Kit, '%s loads as a Kit through ContentLibrary.' % TRAIT_ID)
	if not (kit is Kit): return
	assert_true(kit.is_trait, '%s is a trait.' % TRAIT_ID)

	# On the live unit, not just in the resource: the PassiveBuffApplicator has to actually have run.
	# Exactly one copy of each - a second application would double the -1 without failing anything.
	for buff_id:StringName in TRAIT_BUFFS:
		assert_eq(UnitCondition.get_buffs(unit, buff_id).size(), 1,
			'%s is applied to the Fitzgerald exactly once.' % buff_id)

func test_the_fixture_blocks_sight_and_gives_no_cover():
	assert_false(UnitRelation.can_see(unit, target), 'The wall blocks sight to the target.')
	assert_eq(CoverCalculator.determine_cover(target, unit).total, Lancer.COVER.NONE,
		'Forbidden interior gives the target no cover of its own.')
	var seen := SpecFactory.create_unit(game.map, IN_THE_OPEN, Faction.AI_ENEMY)
	assert_true(UnitRelation.can_see(unit, seen), 'A target on our side of the wall is in plain sight.')

# ---------------------------------------------------------------- the line-of-sight half

func test_a_cannon_needs_sight_without_the_trait():
	var specific := cannon()
	if specific == null: return
	revoke_buffs([BUFF_ARCING])
	assert_true(specific.action.requires_line_of_sight(specific),
		'Without buff_hole_puncher_arcing the Bizarre Cannon requires line of sight.')
	assert_false(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL),
		'Without it the cannon cannot target through the wall.')

func test_the_trait_lets_the_bizarre_cannon_ignore_sight():
	var specific := cannon()
	if specific == null: return
	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific),
		'The trait hands the Bizarre Cannon ARCING.')
	assert_false(specific.action.has_tag(Lancer.WEAPON_TAG.SEEKING, specific),
		'ARCING and not SEEKING - SEEKING would make ignores_cover() true and skip the second clause.')
	assert_false(specific.action.requires_line_of_sight(specific),
		'The Bizarre Cannon no longer requires line of sight.')
	assert_true(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL),
		'It can target through the wall.')

func test_a_rifle_is_left_alone():
	var specific := arm(&'mw_assault_rifle')
	assert_false(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific),
		'A Rifle that fires no Line is left alone.')
	assert_true(specific.action.requires_line_of_sight(specific), 'A Rifle still requires line of sight.')
	assert_false(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL),
		'A Rifle still cannot target through the wall.')

	# Without this the test would pass just as well against a trait that was never applied at all -
	# the same unit's own Cannon is the control that says the buff is live right here.
	var control := cannon()
	if control == null: return
	assert_true(control.action.has_tag(Lancer.WEAPON_TAG.ARCING, control),
		'control: the trait IS applied in this fixture - the Bizarre Cannon has ARCING.')

func test_a_line_weapon_of_another_type_gets_the_tag():
	var specific := arm(&'mw_rail_rifle') # a Rifle that fires a Line 10
	assert_true(specific.action.is_weapon_type(Lancer.WEAPON_TYPE.RIFLE, specific.gear),
		'fixture: the rail rifle is a Rifle, not a Cannon.')
	assert_eq(specific.action.range_pattern.pattern, Lancer.AOE_TYPE.LINE,
		'fixture: the rail rifle fires a Line.')
	var pattern:RangePattern = specific.action.range_pattern

	assert_false(specific.action.requires_line_of_sight(specific),
		'The trait covers it because it fires a Line, not because of its weapon type.')
	var after := specific.action.get_aoe_tiles_with_targets(pattern, [BEHIND_WALL], unit.tile(), specific)
	assert_true(after.has(Vector2i(6,4)) and after.has(BEHIND_WALL), 'The line continues past the wall.')
	assert_true(UnitTargeting.get_tiles_targetable(specific).has(BEHIND_WALL),
		'The line can be aimed past the wall.')

	revoke_buffs([BUFF_ARCING])
	assert_true(specific.action.requires_line_of_sight(specific),
		'Without the buff the Line weapon requires sight again.')
	var before := specific.action.get_aoe_tiles_with_targets(pattern, [BEHIND_WALL], unit.tile(), specific)
	assert_false(before.has(BEHIND_WALL), 'Without the buff the line is cut off at the wall.')

## The AI never recomputes sight per query: it precalculates the sweep once and threads it through
## get_tiles_in_range. That path has to honour the tag too, or the AI would refuse shots the player
## is offered (and, for an NPC Fitzgerald, never take them).
func test_the_precalculated_sight_path_honours_the_tag():
	var specific := cannon()
	if specific == null: return
	var sweep := UnitTile.get_tiles_in_los(unit)
	assert_false(Tile.in_bitwise_array(sweep, BEHIND_WALL),
		'fixture: the precalculated sweep does not reach the target.')
	assert_true(UnitTargeting.get_tiles_in_range(specific, [], Tile.INVALID, sweep).has(BEHIND_WALL),
		'With the tag the sweep is not consulted.')

	revoke_buffs([BUFF_ARCING])
	assert_false(UnitTargeting.get_tiles_in_range(specific, [], Tile.INVALID, sweep).has(BEHIND_WALL),
		'Without the tag the sweep governs.')

# ---------------------------------------------------------------- the cover half

## Ruling 1, forward direction: an unseen target is "attacked this way" and takes the trait's -1,
## labelled with the trait's own row so the breakdown reads like cover rather than like nothing.
func test_an_unseen_target_takes_exactly_minus_one_with_the_traits_label():
	var specific := cannon()
	if specific == null: return
	assert_false(UnitRelation.can_see(unit, target), 'fixture: the target is unseen.')

	var pre := preattack(specific, target)
	assert_ne(tr(SOFT_COVER_KEY), SOFT_COVER_KEY, 'The trait penalty has a localization row of its own.')
	assert_eq(trait_mods(pre), [-1], 'Exactly one accuracy mod, worth -1, titled %s.' % tr(SOFT_COVER_KEY))
	assert_eq(pre.cover, Lancer.COVER.NONE, 'The engine records no cover; the trait supplies it instead.')

	# The whole point of the labelled -1 is that the breakdown reads like cover rather than like an
	# unexplained penalty, and the line's icon is half of that. attack_roll.gd:188 passes
	# buff_core.base.icon straight through - the exported field, NOT BuffBonus.get_icon() - so an
	# unset icon silently gives the line no glyph at all.
	assert_eq(trait_mod_icon(pre), Icon.cover(Lancer.COVER.SOFT),
		'The breakdown line wears the vanilla soft-cover icon.')

	revoke_buffs([BUFF_SOFT_COVER])
	assert_eq(trait_mods(preattack(specific, target)), [],
		'Without buff_hole_puncher_soft_cover the blind shot takes no penalty at all.')

## Ruling 1, the other direction: a Cannon shot at a target the Fitzgerald CAN see is not "attacked
## this way", so the trait stays out of it entirely.
func test_a_seen_target_takes_no_trait_penalty():
	var specific := cannon()
	if specific == null: return
	var seen := SpecFactory.create_unit(game.map, IN_THE_OPEN, Faction.AI_ENEMY)
	assert_true(UnitRelation.can_see(unit, seen), 'fixture: the near target is in plain sight.')

	var pre := preattack(specific, seen)
	assert_eq(trait_mods(pre), [], 'A target the attacker can see is not "attacked this way".')
	assert_eq(pre.cover, Lancer.COVER.NONE, 'fixture: there is nothing between them to give cover.')

	# The control that stops this passing vacuously: the SAME weapon on the SAME turn does take the
	# penalty against the unseen target, so the empty list above is the gate working, not the trait
	# being absent.
	assert_eq(trait_mods(preattack(specific, target)), [-1],
		'control: the same cannon does take the -1 against the unseen target.')

## RULING 2, and the test the whole attacker-side design exists for. The target is behind geometry
## that really would hand it HARD cover - proved twice over here, by CoverCalculator directly and by
## the same PreAttack path with the IGNORE_COVER buff revoked - and the trait still reduces that to
## exactly its own soft cover: no cover recorded, one -1.
func test_an_unseen_target_behind_hard_cover_still_takes_exactly_minus_one():
	raise_cover_at(HARD_COVER_FOR_UNSEEN)
	var specific := cannon()
	if specific == null: return
	assert_false(UnitRelation.can_see(unit, target), 'fixture: the target is still unseen.')
	assert_eq(CoverCalculator.determine_cover(target, unit).total, Lancer.COVER.HARD,
		'fixture: this geometry really does give the target HARD cover.')

	var pre := preattack(specific, target)
	assert_eq(pre.cover, Lancer.COVER.NONE, 'The blind shot never faces hard cover.')
	assert_eq(trait_mods(pre), [-1], 'It takes exactly the trait\'s -1.')
	assert_false(mod_titles(pre).has(Lancer.cover_name(Lancer.COVER.HARD)),
		'No hard cover line in the breakdown.')

	# And the discriminator: the geometry is unchanged, only the buff is gone.
	revoke_buffs([BUFF_IGNORE_COVER])
	assert_eq(preattack(specific, target).cover, Lancer.COVER.HARD,
		'Without buff_hole_puncher_ignore_cover the same shot faces HARD cover.')

## Ruling 1 again, with cover in play: a SEEN target keeps whatever geometry gives it, and the trait
## adds no line of its own. The trait must not become a general-purpose cover eraser.
func test_a_seen_target_behind_hard_cover_keeps_hard_cover_and_gets_no_trait_line():
	raise_cover_at(HARD_COVER_FOR_SEEN)
	var seen := SpecFactory.create_unit(game.map, SEEN_FAR, Faction.AI_ENEMY)
	var specific := cannon()
	if specific == null: return
	assert_true(UnitRelation.can_see(unit, seen), 'fixture: the far target is visible over the low block.')
	assert_eq(CoverCalculator.determine_cover(seen, unit).total, Lancer.COVER.HARD,
		'fixture: the block adjacent to it gives HARD cover.')

	var pre := preattack(specific, seen)
	assert_eq(pre.cover, Lancer.COVER.HARD, 'A seen target keeps its hard cover.')
	assert_eq(trait_mods(pre), [], 'And the trait adds no line of its own.')

	# Control, so this cannot pass against a trait that never installed: the same cannon against the
	# unseen target on the far side of the wall does erase cover and does take the -1.
	var blind := preattack(specific, target)
	assert_eq(blind.cover, Lancer.COVER.NONE, 'control: the trait IS live - a blind shot faces no cover.')
	assert_eq(trait_mods(blind), [-1], 'control: and takes the -1.')

## RULING 3: exact to Cannon and Line. A natively Arcing Launcher reaches the same unseen target on
## its own merits, and gets ORDINARY cover rules - which is also independent proof that the geometry
## in the ruling-2 test above produces HARD cover through the real PreAttack path.
func test_a_vanilla_arcing_launcher_at_an_unseen_target_gets_geometry_cover_and_no_trait_line():
	raise_cover_at(HARD_COVER_FOR_UNSEEN)
	var specific := arm(VANILLA_ARCING_LAUNCHER)
	assert_true(specific.action.is_weapon_type(Lancer.WEAPON_TYPE.LAUNCHER, specific.gear),
		'fixture: %s is a Launcher.' % VANILLA_ARCING_LAUNCHER)
	assert_null(specific.action.range_pattern, 'fixture: it fires no Line.')
	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific),
		'fixture: it is natively Arcing, so it reaches the unseen target without the trait.')
	assert_false(UnitRelation.can_see(unit, target), 'fixture: the target is unseen.')

	var pre := preattack(specific, target)
	assert_eq(pre.cover, Lancer.COVER.HARD, 'Ordinary cover rules apply: the geometry gives HARD cover.')
	assert_eq(trait_mods(pre), [], 'And Hole Puncher contributes nothing to a Launcher.')

	# Control: the Fitzgerald's own Cannon, same unit, same target, same geometry, same instant.
	# Without this the test would read the same against a trait that had never installed.
	var control := cannon()
	if control == null: return
	var by_cannon := preattack(control, target)
	assert_eq(by_cannon.cover, Lancer.COVER.NONE, 'control: the trait IS live for the Cannon.')
	assert_eq(trait_mods(by_cannon), [-1], 'control: and the Cannon takes its -1.')

# SP4: the Carronade goes here. It is a Cannon that ignores cover in its own right, so
# buff_hole_puncher_soft_cover's `not context.action.ignores_cover(context)` clause must leave it at
# no penalty against an unseen target. The weapon does not exist yet - add the test to THIS file
# rather than starting a second one.

# ---------------------------------------------------------------- blindness

## RULING 4. UnitTile.get_tiles_within caps a BLINDED unit at range 1, but only when it is asked to
## consider sight (unit_tile.gd:579) - and UnitTargeting.get_tiles_in_range passes
## action.requires_line_of_sight(specific) as that flag. So ARCING keeps the cannon's full reach
## with no code of our own; this test is what proves it on this engine.
func test_a_blinded_fitzgerald_keeps_full_cannon_range():
	var specific := cannon()
	if specific == null: return
	SpecFactory.apply(unit, Lancer.STATUS.BLINDED)
	assert_true(unit.has_status(Lancer.STATUS.BLINDED), 'fixture: the Fitzgerald is Blinded.')

	assert_eq(specific.action.get_target_range(specific), 15, 'The Bizarre Cannon still reaches 15.')
	var in_range := UnitTargeting.get_tiles_in_range(specific)
	assert_true(in_range.has(BEHIND_WALL),
		'A tile %d spaces away is still in range while Blinded.' % UnitTile.distance_to(unit, BEHIND_WALL))

	revoke_buffs([BUFF_ARCING])
	assert_false(UnitTargeting.get_tiles_in_range(specific).has(BEHIND_WALL),
		'Without the trait, Blinded clamps the same cannon to range 1.')

# ---------------------------------------------------------------- end to end

func test_a_blind_cannon_shot_resolves():
	var specific := cannon()
	if specific == null: return
	# Enough sixes that the roll queue can never drain into real randomness, whatever the exact
	# number of difficulty dice the attack pops (the Bizarre Cannon's own Inaccurate, plus the
	# trait's soft cover). The hit is guaranteed by the target's evasion, not by the dice - the same
	# trick test_bizarre_cannon.gd:173-178 uses, and for the same reason: predicting the die count
	# would make this test fail for arithmetic rather than for behaviour.
	target.core.frame.stat.evasion = -10
	target.core.full_repair()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6])
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, BEHIND_WALL)
	assert_gt(target.current_damage(), 0, 'The Bizarre Cannon hit a target it cannot see.')
	assert_false(UnitRelation.can_see(unit, target), 'fixture held: the target was never in sight.')
	assert_true(specific.action.has_tag(Lancer.WEAPON_TAG.ARCING, specific),
		'The tag is still granted after the attack (nothing consumed it).')
