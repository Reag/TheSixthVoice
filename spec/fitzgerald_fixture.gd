# SP2 Task 0: the shared Fitzgerald spec fixture, extracted from the ~60 duplicated before_each()
# lines in test_bizarre_cannon.gd, test_blasting_powder.gd, test_hole_puncher.gd and
# test_knock_em_down.gd (all SP1). SP1's whole-branch review flagged the duplication (a fourth
# Important finding): the rule of three was already met at four files, and every frame added first
# makes the extraction more expensive - so this exists before SP2 copies the same ~60 lines a fifth
# and sixth time.
#
# NOT testkit/. testkit/ is the harness shared across all four Reag-* mods; this file hardcodes
# mf_fitzgerald and cp_broadside, which is this MOD's content, not harness. It is preloaded the way
# testkit/frame_isolation.gd already is: static functions, no state, NOT extends GutTest, and NOT
# test_-prefixed, so GUT's directory scan never collects it as a test script.
#
# THIS IS A PURE REFACTOR. Every function below is a verbatim lift of code and comments out of one
# of the four before_each() bodies; where those bodies differed, the difference survives as a
# parameter, not as a silently-chosen default. See each function's own header for its source and,
# where relevant, exactly which before_each supplied which argument.
#
# OUT OF SCOPE, ON PURPOSE (per the SP2 Task 0 plan): the dice helpers (cheat_a_crit, cheat_a_hit,
# cheat_a_hit_no_crit, cheat_two_crits) and the save-forcing helpers stay in their own files. Their
# buffer sizes differ per file and their comments record measured evidence from real runs; they are
# a separate extraction, not this one.
extends RefCounted

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_fitzgerald'

## The map size every before_each passed to Landscape.create_default() - test_hole_puncher.gd named
## it MAP_SIZE for its own reasons (see that file), the other three wrote the literal
## Vector2i(15, 9). Exposed as the default here so a caller with no reason to override it does not
## have to name it.
const DEFAULT_MAP_SIZE := Vector2i(15, 9)

## The gamemaster + landscape every Fitzgerald spec builds.
##
## From SP1 test_hole_puncher.gd. THE FLAG IS LOAD-BEARING AND ITS ABSENCE IS SILENT.
## landscape_node.gd:608 treats a forbidden interior as a full-height sight blocker only when
## map.shape.forbidden_interiors_enabled is true, and map_shape.gd:19 sets that from
## X.current_level() when the shape is built - which, for the FIRST gamemaster a spec run creates,
## happens before the level is current, so it comes out false and the interior is just a one-tall
## setpiece that two size-1 units look straight over (sight runs along layer 2 here: floor 1 plus a
## body of 1). Every later test re-uses the level, rebuilds the shape with the flag true, and blocks
## properly - so without this line the first test in a run silently sees through the wall and the
## rest do not.
##
## THIS IS THE ONE LINE WHOSE REACH WIDENS BY THIS EXTRACTION: it becomes true in all four specs
## instead of only test_hole_puncher.gd, which is the only one of the four that ever places a
## forbidden interior. That is safe, and Task 0's identical-totals success criterion is exactly what
## proves it - if the totals move, this is the line to revert to a `blocks_sight:bool = true`
## parameter instead.
static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	var game := SpecFactory.setup_gamemaster(test, true,
		SpecFactory.create_combat(Landscape.create_default(map_size)))
	game.map.shape.forbidden_interiors_enabled = true
	return game

## A Fitzgerald. NOT FrameIsolation'd - see the comment this function inherits.
##
## From SP1 test_bizarre_cannon.gd, identically in test_blasting_powder.gd, test_hole_puncher.gd and
## test_knock_em_down.gd: NOT FrameIsolation'd on purpose - this spec never writes to the
## Fitzgerald's stats, and a deep duplicate of the frame would hand the unit COPIES of its trait
## Kits, whose compcon_id is a lazily-derived bare var (kit.gd:11-16) that does not survive
## duplicate() - at which point unit.get_gear(&'cp_broadside') stops finding anything.
static func create_fitzgerald(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion.
##
## From SP1 test_bizarre_cannon.gd / test_hole_puncher.gd / test_knock_em_down.gd (test_blasting_
## powder.gd built three of these through its own _make_target(), which also sets heat and stays
## local to that file since heat is not shared by the other three). The evasion argument is the real
## difference between the four before_each bodies, and it is preserved here rather than defaulted:
## test_hole_puncher.gd set 10 ("only hit when we say"), test_knock_em_down.gd set -10 ("every test
## here needs a guaranteed hit"), and test_bizarre_cannon.gd set NEITHER in before_each, leaving the
## frame's own statblock_default.tres value (8) in place until a test's own cheat_a_hit() /
## cheat_a_miss() overwrites it before ever reading it - so that file's call site passes 8
## explicitly, to land on the exact value the original before_each left the target holding, not on a
## newly chosen number.
static func create_dummy(
	game:Gamemaster, tile:Vector2i, evasion:int, faction:Faction.SIDE = Faction.AI_ENEMY
) -> Unit:
	var target := SpecFactory.create_unit(game.map, tile, faction)
	FrameIsolation.isolate_frame(target) # we DO rewrite this one's stats
	target.core.frame.stat.health = 200 # never dies; a death mid-spec would end the scene
	target.core.frame.stat.armor = 0 # so the damage numbers below are the weapon's, not armor's
	target.core.frame.stat.evasion = evasion
	target.core.full_repair()
	return target

## Open the unit's turn, once, if it is not already open.
##
## From SP1 test_bizarre_cannon.gd, identically in test_blasting_powder.gd and
## test_knock_em_down.gd (test_hole_puncher.gd called SpecFactory.start_turn directly, unguarded, in
## its one place that needs an open turn - routed through here too, for the same effect, since its
## turn is never already open at that point either).
##
## THE TURN START IS NOT DECORATION. unit_action.gd:119 refuses a PROTOCOL unless
## unit.state.is_using_protocols, which only event_turn_start opens - and More Black Powder is a
## protocol on this same Kit. The weapon profiles are QUICK actions and would activate without it;
## going through one helper means every test fires from the same state, and means a test that uses
## the protocol and then fires does not re-open a turn it is already in.
static func open_turn(game:Gamemaster, unit:Unit) -> void:
	if not unit.state.is_taking_turn: await SpecFactory.start_turn(game, unit)
