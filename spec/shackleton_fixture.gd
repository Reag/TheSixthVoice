# The shared Shackleton spec fixture (SP1).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, as every frame fixture since the Naga
# does: everything except create_shackleton() and this frame's own helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var that does not survive duplicate() - at which point
# unit.get_gear(&'mt_spatial_rerouting') stops finding anything, and Spatial Rerouting's extension
# asks for exactly that. No Shackleton spec writes to the frame's stats.
#
# SIZE 2, SO THE RE-TRACKING LINE IS LOAD-BEARING - the Naga's create_naga verbatim: create_unit
# adds every unit at size 1 and only full_repair() grows it, and without UnitTile.move_to the map
# indexes the Shackleton at its anchor tile alone. A size-2 unit at anchor (x, y) occupies
# (x..x+1, y..y+1).
#
# THE GAME CARRIES ITS OWN RESPONDER (hazard_fixture.create_game_with_prompt_queues' shape) and a
# PromptWatcher, because every trait spec here reads what the player was OFFERED: the stock
# responder answers a move_tile prompt with params.tiles[0] and ask_for_movement_alt never checks the
# answer against the offer (test_bizarre_cannon.gd's RECOIL_ANY note), so only the offer is evidence.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const FRAME_ID := &'mf_shackleton'
const LICENSE_ID := &'li_nelson'

## The three sheet traits, in sheet order, then the core system (SP2).
const REROUTING_ID := &'mt_spatial_rerouting'
const HYDRAULICS_ID := &'mt_mobilized_hydraulics'
const WEAK_COMPUTER_ID := &'mt_shackleton_weak_computer'
const HYDRAULICS_USAGE := &'mobilized_hydraulics'
const CORE_ID := &'cp_force_distribution_programs'
const WEIGHT_ID := &'action_unfathomable_weight'
const IMPACT_ID := &'action_calamitous_impact'
const CRATER_ID := &'dep_shackleton_crater'

## IPS-N War Pike: MAIN MELEE, 1d6, Knockback 1, reach 1. The Nelson's own rank-1 weapon.
const PIKE := &'mw_war_pike'
## The basic Ram: weapon_type MELEE, size NONE, Knockback 1 through the ordinary on_hit.
const RAM := &'mw_ram'
## The plain vanilla rifle: MAIN RIFLE, no knockback - the ranged negative control.
const RIFLE := &'mw_assault_rifle'

const DEFAULT_MAP_SIZE := Vector2i(16, 12)

## [game, responder, watcher]. add_responder = false is what stops TWO responders answering the same
## request.
static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(MoveQueueResponder.new())
	var watcher = test.add_child_autoqfree(PromptWatcher.new())
	return [game, responder, watcher]

## A Shackleton with its traits' passive buffs applied. PLAYER faction unless told otherwise.
static func create_shackleton(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached footprint, THEN rebuild the map's tile index
	return unit

## A FrameIsolation'd 200-HP, armor-0 punching bag (fitzgerald_fixture.create_dummy).
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = -10, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, evasion, faction)
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## Put a Kit on a unit as an INTEGRATED system/weapon and hand back its GearCore. IDEMPOTENT.
## equip_system full_repairs and apply_passive_buffs re-applies every passive buff, so equip first.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	UnitTile.update_tracking_and_statuses(unit.map)
	return unit.get_gear(kit_id)

## End the unit's turn if open, then start it - a new round's worth of per-round tallies.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Swing one weapon Kit at a target from an already-open turn.
static func swing(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName = PIKE) -> void:
	await open_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, kit_id, target)

## The knockback pools the player was offered since `from` (a watcher.prompts index), as the
## pathfinders' MOVABLE tiles - the tiles the reticle actually lets a player click.
static func offered_pools(watcher, from:int = 0) -> Array:
	var pools := []
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind != PromptWatcher.KIND.move_tile: continue
		var pathfinder:Pathfinder = seen.info.pathfinder
		pools.append(pathfinder.movable_tiles.duplicate() if pathfinder != null else [])
	return pools

static func yesno_count(watcher, from:int = 0) -> int:
	var n := 0
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind == PromptWatcher.KIND.yesno: n += 1
	return n

## The furthest Chebyshev distance (the engine's Tile.distance) of any tile in `pool` from `origin`.
static func reach_of(pool:Array, origin:Vector2i) -> int:
	var best := 0
	for tile:Vector2i in pool: best = maxi(best, Tile.distance(origin, tile))
	return best

## Spend Mobilized Hydraulics' round, so a swing measures the weapon's own knockback. Call it AFTER
## the turn is open: the turn start resets the per-round tally.
static func spend_hydraulics(unit:Unit) -> void:
	var gear:GearCore = unit.get_gear(HYDRAULICS_ID)
	if GearCore.is_valid(gear): gear.increment_action_usage(HYDRAULICS_USAGE, false)

static func hydraulics_uses(unit:Unit) -> int:
	var gear:GearCore = unit.get_gear(HYDRAULICS_ID)
	return gear.get_uses_this_round_alt(HYDRAULICS_USAGE) if GearCore.is_valid(gear) else -1

## The testkit responder plus a QUEUE of move-tile answers (SP2). SpecFactory's responder has ONE
## chosen_move_tile that answers every later move request, and Calamitous Impact opens several in a
## row - the leap, then one knockback per target - that want different answers. Each move request
## takes the next queued tile; once a queue has been used and runs dry, chosen_move_tile goes back to
## INVALID so later requests take the stock default instead of the last queued tile. A spec that never
## touches move_tile_queue sees the stock responder exactly.
class MoveQueueResponder extends "res://testkit/mod_choice_responder.gd":
	var move_tile_queue:Array[Vector2i] = []
	var _queued := false

	func choose_move_tile(request:ChoiceRequest):
		if not move_tile_queue.is_empty():
			chosen_move_tile = move_tile_queue.pop_front()
			_queued = true
		elif _queued:
			chosen_move_tile = Tile.INVALID
			_queued = false
		await super(request)
