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
## RE-USES the gamemaster rather than building a fresh one per test (2026-09-15). The whole suite
## runs on this one line, so it is worth saying why both halves of it are deliberate:
##
## make_fresh_gamemaster = true built an entire Gamemaster - nodes, map, landscape - for every test
## and queue_free'd it again, because setup_gamemaster's fresh branch hands it to
## test.add_child_autoqfree (spec_factory.gd:30). The re-use branch keeps ONE at the tree root and
## resets it instead: cleanup(), a new core from the combat, map_node.clear(), map.clear(), then
## load_landscape (:40-46). That is vanilla's own default by a wide margin - 322 of the 340
## setup_gamemaster calls in res://test/ are the bare setup_gamemaster(self) - and passing a combat
## alongside `false`, which is what carries our per-spec MAP_SIZE through load_landscape, is an
## established vanilla form too (3 uses).
##
## IT ALSO FIXES SOMETHING. The fresh branch returns at spec_factory.gd:32, BEFORE the two lines
## that build a CampaignCore and hang it on the map (:47-48) - and EventService.remove_unit_from_game
## dereferences map.campaign_core with no guard (event_service.gd:80), one line above the
## unit.remove_from_game() at :85. That is why test_heaer.gd and test_blasting_powder.gd each
## hand-build a CampaignCore before anything is allowed to die. On this branch they get one for
## free; their hand-built ones are now redundant, and harmless, so they stay where they are.
static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	var game := SpecFactory.setup_gamemaster(test, false,
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
## THE TURN START IS NOT DECORATION. unit_action.gd:144 refuses a PROTOCOL unless
## unit.state.is_using_protocols, which only event_turn_start opens - and More Black Powder is a
## protocol on this same Kit. The weapon profiles are QUICK actions and would activate without it;
## going through one helper means every test fires from the same state, and means a test that uses
## the protocol and then fires does not re-open a turn it is already in.
static func open_turn(game:Gamemaster, unit:Unit) -> void:
	if not unit.state.is_taking_turn: await SpecFactory.start_turn(game, unit)

## The vanilla Jericho cover (entity OBJECT, is_deployable true, 10 HP by default): a real
## deployable rather than the MARKER-ish dep_attack_ground_proxy the engine spawns for a shot aimed
## at bare ground. FrameIsolation'd so rewriting its statblock cannot reach the shared
## ContentLibrary copy, then full_repair()'d so current.* picks the new numbers up.
##
## SP5 Task: hand-typed identically in test_heaer.gd, test_reinforcement_blast.gd and
## test_rapier_carronade.gd (each also carrying its own copy of DEPLOYABLE_FRAME_ID) - the rule of
## three was met, but the three bodies genuinely differ (health 5/40/OBJECT_HEALTH, evasion
## -10/the frame's own default 5/UNHITTABLE), so every difference survives here as a required
## argument rather than a chosen default. THIS IS A PURE REFACTOR: test_reinforcement_blast.gd's
## own `assert_false(dep.is_actor(), ...)` fixture self-check is NOT folded in here, since the
## other two callers never had it - it stays at that one call site.
const DEPLOYABLE_FRAME_ID := &'dep_jericho_cover'

## SP1 Task 4 review: `faction` is a new OPTIONAL trailing argument, defaulting to the AI_ENEMY every
## existing call site was getting implicitly, so none of them changes behaviour. The Subutai's
## Juggernaut Drive needs a FRIENDLY deployable - the card says "allied character", and the only
## honest test that a deployable does not anchor a line is one the unit would otherwise drive
## towards.
static func create_deployable(
	game:Gamemaster, tile:Vector2i, health:int, armor:int, evasion:int,
	faction:Faction.SIDE = Faction.AI_ENEMY,
) -> Unit:
	var dep := SpecFactory.create_unit(game.map, tile, faction)
	dep.core.frame = ContentLibrary.get_mech_frame(DEPLOYABLE_FRAME_ID)
	FrameIsolation.isolate_frame(dep)
	dep.core.frame.stat.health = health
	dep.core.frame.stat.armor = armor
	dep.core.frame.stat.evasion = evasion
	dep.core.full_repair()
	# THE FRAME SWAP ABOVE STEPS AROUND THE ENGINE'S OWN GROUND-LOCK AUTO-SETTER; THIS RE-RUNS IT.
	# Not tidying, and NOT a workaround for an engine bug - the engine has a purpose-built guard for
	# precisely this frame, and the order this fixture builds a unit in is what bypasses it.
	#
	# THE GUARD. UnitCondition.apply_lock_to_ground_height (unit_condition.gd:920-927) sets
	# state.lock_to_ground_height on any unit whose gear carries a PassiveTerrainZone with
	# terrain_data.obstruction, and its own comment at :922 names the case outright - "jericho cover
	# needs to ignore itself when determining its floor height". The engine runs it on every unit add
	# (map_node_3d.gd:125) and again from apply_buffs_from_passive_gear (unit_condition.gd:873).
	#
	# THE REAL DEPLOY PATH NEVER HAS THE GAP, which is why no player ever sees a cover climb:
	# ActionSystemDeploy.place_deployable builds the core WITH the deployable frame -
	# UnitCore.create(unit.get_faction(), frame), action_system_deploy.gd:117 - and only then queues
	# the spawn, so map_node_3d.gd:125 is looking at the Jericho and locks it from birth.
	#
	# THIS FIXTURE BUILDS IT THE OTHER WAY ROUND. SpecFactory.create_unit hands out a knockoff Everest
	# (spec_factory.gd:76-77) and adds it to the map (:95) - so the auto-setter runs against a frame
	# with no obstruction and lands the flag FALSE. The frame is swapped afterwards (:151 above), and
	# the full_repair() on the line above rebuilds the loadout from the NEW frame (unit_printer.gd:83
	# -> loadout_core.gd:139 and :154), so mt_obstruction_hard_cover genuinely IS on the loadout that
	# map_state.gd:427-433 reads when it writes the obstruction voxel. Only the flag is left stale,
	# and a cover that does not ignore its own obstruction reads its floor off its own raised surface
	# (map_state.gd:462 and :467 via unit_tile.gd:211-218) - climbing one layer on every
	# UnitTile.update_tracking_and_statuses pass, without bound.
	#
	# MEASURED 2026-09-16 with a throwaway probe on this fixture's own deployable: straight out of
	# create_deployable the flag is false while the loadout already reads [mt_obstruction_hard_cover];
	# this one call flips it to true, and effective_floor is then a stable 1 over seven bare tracking
	# passes instead of 1, 2, 3, 4, 5 ...
	#
	# ORDER IS LOAD-BEARING: this must come AFTER full_repair(), because the setter reads
	# unit.core.loadout.get_all_gear(false) (unit_condition.gd:921) and full_repair is what puts the
	# new frame's traits there.
	UnitCondition.apply_lock_to_ground_height(dep)
	return dep


# ---------------------------------------------------------------- shared by every later fixture
#
# CLOSE-OUT PASS D (2026-09-27): four helpers every later frame's fixture had re-typed, hosted here
# because every fixture already preloads this file. Each frame's fixture keeps its own function name
# and its own default arguments (a different default faction, its own DEFAULT_MAP_SIZE) as a one-line
# delegation, so no spec call site moved. Bodies are the copies' own, verbatim; the variants that
# differed in ORDER (Black Mountain, Six Sky and Hazard build a drone around their tracking
# create_dummy) were left where they are.

## A gamemaster plus a ModChoiceResponder the caller queues answers on. setup_gamemaster's trailing
## `{}, false` and the forbidden-interiors flag are create_game's reasons (above), unchanged. Was
## create_game_with_prompt_queues in five fixtures and create_game_with_sequenced_prompts in the
## Maiden's Blush's, one body under two names.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A drone: a dummy (evasion 10) with the frame's is_drone flag set. The flag is on the isolated
## frame copy create_dummy made, so no other unit is touched; full_repair rebuilds from it.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Put a Kit on a unit and hand back its GearCore. IDEMPOTENT, and that is load-bearing:
## UnitPrinter.equip_system calls full_repair (unit_printer.gd:180) and apply_passive_buffs re-applies
## every passive from scratch, so a second equip would refund a spent core power and re-arm the frame.
## Equip everything BEFORE a test sets any state. The tracking pass is the one the later fixtures
## added: a passive that reads positions (an aura) sees the new gear at once.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	UnitTile.update_tracking_and_statuses(unit.map)
	return unit.get_gear(kit_id)

## GRIT IS THE PILOT'S: PilotCore.get_grit() is half the licence level, rounded up, and a fixture unit
## starts at level 0 = Grit 0 (pilot_core.gd:26), which makes "Grit 0 grants nothing" the default.
## Takes the GRIT and derives the level, so no spec does the rounding in its head.
static func set_grit(unit:Unit, grit:int) -> void:
	if not Unit.is_valid(unit) or not PilotCore.is_valid(unit.core.pilot): return
	unit.core.pilot.license_level = grit * 2
