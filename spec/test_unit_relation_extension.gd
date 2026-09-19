# THE PROBE for the mod's first autoload extension - design §1.0, the task that decides whether the
# rest of Wormhole Grasp is built as designed.
#
# res/engine/character/unit/service/unit_relation.gd_ext.gd waives the SUPERHEAVY refusal in
# is_weapon_available_as_a_rxn while buff_wormhole_grasp is held. ModLoader logs the install for a
# dead seam exactly as for a live one (memory lancer-tactics-extension-seams), so only behaviour
# that solely the override can produce is evidence - and the waiver has to be reached from every
# DEPTH the engine calls it at:
#
#   level 0  UnitRelation.is_weapon_available_as_a_rxn(specific)        - a direct call through the
#            autoload node, which is how Integrated Weapon and the Ghast ask (proves the reload).
#   level 2  UnitRelation.get_weapons_that_can_react_against(a, b)      - vanilla's body reaches the
#            waiver through TWO unqualified internal static calls (can_weapon_hit_target_as_rxn,
#            then is_weapon_available_as_a_rxn). Monitor Module and Scylla ask here.
#   level 3  UnitRelation.get_weapons_that_can_overwatch(a, b)          - one more, and through Thy
#            Hubris' own override of this function when that mod is loaded. ms_overwatch asks here
#            (action_overwatch.gd:21, :31).
#   the move a real hostile walking out of threat, with the stock responder accepting the Overwatch.
#
# MEASURED 2026-09-19, and it changed the extension's shape. With ONLY is_weapon_available_as_a_rxn
# overridden (the design's shape) the first run went 4/7: level 0 green, levels 2 and 3 and the
# real move RED. A call through the autoload node dispatches to the most-derived override, and so
# does one unqualified static call made from inside that function - but a function reached that way
# runs with no instance, so the unqualified calls in ITS body bind to vanilla. Dispatch is virtual
# exactly one level below an instance call and no deeper (the one-level case was already known:
# House Guard's adjacent_characters override is seen by vanilla's is_adjacent, memory
# third-party-adjacency-widening). The extension now overrides all three functions the chain
# crosses, each calling super and re-running the gates below it; the second run went 7/7. The
# level-3 green also shows a `super.` call keeps the instance for its own one level down, since the
# path runs through Thy Hubris' override of get_weapons_that_can_overwatch.
#
# Modelled on vanilla's test/gear/test_ms_overwatch.gd and Thy Hubris' test_earthstep.gd: spec units
# carry ms_overwatch from the basic loadout, the watcher only needs a weapon, and "did overwatch
# fire" reads off mover.current_damage().
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const MARKER := &'buff_wormhole_grasp'
## Vanilla IPS-N Combat Drill: SUPERHEAVY MELEE, threat 1, 3d6 - the one vanilla Superheavy melee
## weapon (content/gear/ipsn/weapons/mw_combat_drill/action_combat_drill.tres:18-19).
const SUPERHEAVY_MELEE := &'mw_combat_drill'
## Vanilla GMS Heavy Melee Weapon: HEAVY MELEE, threat 1 - the control the waiver must not touch.
const HEAVY_MELEE := &'mw_heavy_melee_weapon'

## Geometry copied from vanilla's test_ms_overwatch.gd, known to produce an overwatch: the watcher
## sits at the origin and the mover starts ADJACENT to it before walking away. All inside the 5x5.
const WATCHER_TILE := Vector2i(0, 0)
const START := Vector2i(1, 1)
const FINISH := Vector2i(3, 3)

var game:Gamemaster
var watcher:Unit
var mover:Unit


func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)

	watcher = SpecFactory.create_unit(game.map, WATCHER_TILE)

	mover = SpecFactory.create_unit(game.map, START, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(mover)
	mover.core.frame.stat.health = 100 # survives a 3d6 drill so the damage is readable, not fatal
	mover.core.frame.stat.evasion = -10 # every roll hits, so "no damage" can only mean "no shot"
	mover.core.full_repair()
	SpecFactory.apply_passive_buffs(mover)


## Equip one weapon on the watcher and hand back its SpecificAction. apply_passive_buffs runs
## full_repair, so the MARKER has to be applied AFTER this, never before.
func arm(weapon_id:StringName) -> SpecificAction:
	var gear:GearCore = watcher.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(watcher)
	return SpecificAction.create(watcher, gear, gear.get_solo_action())

func mark() -> void:
	SpecFactory.apply_buff(watcher, MARKER)
	assert_true(UnitCondition.has_buff(watcher, MARKER), 'Fixture: the marker landed.')

func offers(weapons:Array[SpecificAction], weapon_id:StringName) -> bool:
	for specific:SpecificAction in weapons:
		if specific.gear.kit.compcon_id == weapon_id: return true
	return false


# ============================== the reload entry is OURS ==============================

## Path to this mod's own mod_main.gd, read for its declared constants rather than for what the
## process ended up doing - because what the process does is NOT attributable to this mod.
const OUR_MOD_MAIN := 'res://unpacked/Reag-TheSixthVoice/mod_main.gd'

## MEASURED 2026-09-19: deleting our EXTENDED_AUTOLOADS entry left every behavioural test in this
## file GREEN, because Reag-ThyHubris' mod_main.gd reloads the same UnitRelation node with the same
## chain-end script, and our extension is in that chain. A player with only this mod installed has
## no such sibling, and for them a missing entry is the whole seam silently dead (upstream bug 5:
## a .gd_ext.gd never reaches the live autoload node without the deferred reload). A guard on global
## state cannot tell which mod satisfied it (memory lancer-tactics-spec-harness-traps), so this one
## reads the constant off OUR file.
func test_this_mods_own_mod_main_reloads_unit_relation() -> void:
	var mod_main:Script = load(OUR_MOD_MAIN)
	assert_not_null(mod_main, 'Fixture: our mod_main.gd loads.')
	var extended:Dictionary = mod_main.get_script_constant_map().get('EXTENDED_AUTOLOADS', {})
	assert_true(extended.has(&'UnitRelation'),
		'EXTENDED_AUTOLOADS names UnitRelation - without it the extension is dead for a player without Thy Hubris.')
	assert_eq(extended.get(&'UnitRelation', ''), 'res://engine/character/unit/service/unit_relation.gd',
		'And it points at the vanilla script the deferred reload loads.')


# ============================== the fixture can overwatch at all ==============================

## THE VACUITY GUARD. Without this, every "no damage" assertion below would pass against a fixture
## that simply never overwatches.
func test_an_ordinary_heavy_weapon_overwatches_from_this_fixture() -> void:
	arm(HEAVY_MELEE)
	await SpecFactory.move(game, mover, FINISH)
	assert_eq(mover.tile(), FINISH, 'It actually moved.')
	assert_gt(mover.current_damage(), 0, 'The watcher caught it with a Heavy weapon - the fixture works.')


# ============================== level 0: the override itself ==============================

func test_level_0_the_override_admits_a_superheavy_weapon_only_under_the_marker() -> void:
	var drill := arm(SUPERHEAVY_MELEE)
	assert_false(UnitRelation.is_weapon_available_as_a_rxn(drill),
		'Vanilla refuses SUPERHEAVY, and so does the override without the marker.')
	mark()
	assert_true(UnitRelation.is_weapon_available_as_a_rxn(drill),
		'THE SEAM: the override runs on the live autoload and waives the size test.')

func test_level_0_a_heavy_weapon_is_unchanged_with_or_without_the_marker() -> void:
	var blade := arm(HEAVY_MELEE)
	assert_true(UnitRelation.is_weapon_available_as_a_rxn(blade), 'Heavy was always allowed.')
	mark()
	assert_true(UnitRelation.is_weapon_available_as_a_rxn(blade), 'And still is.')


# ============================== level 2: the reaction list ==============================

func test_level_2_the_reaction_list_offers_the_superheavy_weapon_only_under_the_marker() -> void:
	arm(SUPERHEAVY_MELEE)
	assert_false(offers(UnitRelation.get_weapons_that_can_react_against(watcher, mover), SUPERHEAVY_MELEE),
		'Without the marker the list is vanilla: no Superheavy.')
	mark()
	assert_true(offers(UnitRelation.get_weapons_that_can_react_against(watcher, mover), SUPERHEAVY_MELEE),
		'With the marker, the list built two unqualified static calls above the override offers it.')


# ============================== level 3: what ms_overwatch asks ==============================

func test_level_3_the_overwatch_list_offers_the_superheavy_weapon_only_under_the_marker() -> void:
	arm(SUPERHEAVY_MELEE)
	assert_false(offers(UnitRelation.get_weapons_that_can_overwatch(watcher, mover), SUPERHEAVY_MELEE),
		'Without the marker, Overwatch has no Superheavy to offer.')
	mark()
	assert_true(offers(UnitRelation.get_weapons_that_can_overwatch(watcher, mover), SUPERHEAVY_MELEE),
		'With the marker, the exact call action_overwatch.gd:21 makes offers it.')


# ============================== the real thing ==============================

func test_a_marked_watcher_overwatches_with_the_superheavy_weapon() -> void:
	arm(SUPERHEAVY_MELEE)
	mark()
	await SpecFactory.move(game, mover, FINISH)
	assert_eq(mover.tile(), FINISH, 'It actually moved.')
	assert_gt(mover.current_damage(), 0, 'The drill fired as an Overwatch.')

func test_an_unmarked_watcher_cannot_overwatch_with_it() -> void:
	arm(SUPERHEAVY_MELEE)
	await SpecFactory.move(game, mover, FINISH)
	assert_eq(mover.tile(), FINISH, 'It actually moved.')
	assert_eq(mover.current_damage(), 0, 'Vanilla behaviour is intact without the marker.')
