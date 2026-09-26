# The shared Lovers Knot spec fixture (SP1). Every later sub-project extends it; signatures here are
# additions-only from SP2 on.
#
# DELEGATES TO fitzgerald_fixture.gd for the game and the dummies, the way every frame fixture in this
# mod does. NOT FrameIsolation'd for the Knot itself, for fitzgerald_fixture.create_fitzgerald()'s
# reason: a deep duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a
# lazily derived bare var (kit.gd:11-16) that does not survive duplicate(), so
# unit.get_gear(&'mt_precision_venting') would stop finding anything.
#
# "CHARACTER" IS Unit.is_actor() (the mod-wide author's call, rulings row 301; design ruling 3): a
# drone is not a character. create_hostile_drone is the negative control for every "hostile
# character" clause.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_lovers_knot'
const LICENSE_ID := &'li_deaths_head'

## The SP1 traits, in sheet order, then Fragile (vanilla, by path) and the core system (empty until SP2).
const PRECISION_VENTING_ID := &'mt_precision_venting'
const PRECISION_VENTING_BUFF := &'buff_precision_venting'
const PRECISION_VENTING_USAGE := &'precision_venting'
const FRACTURED_SILHOUETTE_ID := &'mt_fractured_silhouette'
const REPOSITION_ACTION := &'action_reposition'
const FRAGILE_ID := &'mt_fragile'
const CORE_ID := &'cp_integrated_redirection_aggregate'

## GMS main rifle, Range 10, 1d6 Kinetic, Reliable 2: the ranged vehicle, on both sides.
const RANGED := &'mw_assault_rifle'
## GMS auxiliary pistol: a SECOND ranged weapon, for a second attack in the same turn. The engine's
## per-turn soft limit silently refuses the same weapon twice in one turn (memory
## lancer-tactics-spec-harness-traps), and the Knot's own turn start resets its round, so a second
## crit in one ROUND has to come from another gun.
const RANGED_2 := &'mw_pistol'
## GMS main melee, 1d6+2 Kinetic, threat 1: the melee negative control.
const MELEE := &'mw_tactical_melee_weapon'

## A d20 every attack in these files misses with (the dummies have evasion 10 unless told otherwise).
const MISS_ROLL := 1

## SP2: Gemini Charge, the core system's passive half (design 2, rulings 7-16).
const GEMINI_BUFF := &'buff_gemini_charge'
const GEMINI_SHARED_ROLL := &'buff_gemini_shared_roll'
const GEMINI_IGNORE_COVER := &'buff_gemini_ignore_cover'
const GEMINI_LEG_TILES := &'buff_gemini_leg_tiles'
const GEMINI_USAGE := &'gemini_charge'
## SSC main Line 10, 1d6+1, no Reliable: the Line vehicle.
const LINE := &'mw_rail_rifle'
## GMS launcher, Blast 1, aim 10: the "no single contact" negative control.
const BLAST := &'mw_rocket_propelled_grenade'

## SP3: Form of the Myriad, the core system's active half (design 3, rulings 17-21).
const MYRIAD_ACTION := &'action_form_of_the_myriad'
const MYRIAD_CHIP := &'buff_form_of_the_myriad'
const EFFICIENT_REFUND := &'action_efficient_refund'

const DEFAULT_MAP_SIZE := Vector2i(16, 10)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder answers a SEQUENCE of prompts and records every one
## (testkit/mod_choice_responder.gd), and the responder itself: [game, responder]. add_responder =
## false stops two responders answering the same request (maidens_blush_fixture.gd's reasoning).
static func create_game_with_prompts(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Lovers Knot with its traits' passive buffs applied. PLAYER faction by default (SpecFactory's),
## which every hostile relation here depends on and which makes CommonActionUtil.confirm_use actually
## ask. The re-tracking line refreshes the cached footprint and effective floor.
static func create_knot(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile)
	return unit

## A FrameIsolation'd 200-HP, armor-0 punching bag with a caller-chosen evasion.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10,
		faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, evasion, faction)
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## A hostile CHARACTER holding the rifle, so it can be the shooter Reposition reacts to.
static func create_hostile(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := create_dummy(game, tile, 10, faction)
	equip(unit, RANGED)
	return unit

## A hostile DRONE with the rifle: a character that is not an ACTOR. Flipped on an already-isolated
## frame, so only the one flag differs from create_hostile.
static func create_hostile_drone(game:Gamemaster, tile:Vector2i) -> Unit:
	var drone := create_hostile(game, tile)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Put a Kit on a unit as a SYSTEM (which keeps a weapon out of loadout.basic - BuffWeaponType refuses
## basic gear) and hand back its GearCore. equip_system full_repairs, which CLEARS every gear's state
## and usage AND the unit's heat, so equip everything BEFORE a test spends or sets anything.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	UnitTile.update_tracking_and_statuses(unit.map)
	return unit.get_gear(kit_id)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## End the unit's turn if open, then start it: a fresh turn, and the unit's own 1/round tallies reset
## (unit_action.gd:74-76, :86-87 - design ruling 3).
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

static func heat(unit:Unit) -> int: return unit.core.current.heat
static func set_heat(unit:Unit, amount:int) -> void: unit.core.current.heat = amount

static func uses(unit:Unit, kit_id:StringName, usage:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	return gear.get_uses_this_round_alt(usage) if GearCore.is_valid(gear) else -1

static func precision_venting_uses(unit:Unit) -> int:
	return uses(unit, PRECISION_VENTING_ID, PRECISION_VENTING_USAGE)

## Gemini Charge's hand-rolled 1/round, on the core system's gear (ruling 7).
static func gemini_uses(unit:Unit) -> int:
	return uses(unit, CORE_ID, GEMINI_USAGE)

## The core system's GearCore: Gemini's round stamp and the Efficient stamp both live on it.
static func core_gear(unit:Unit) -> GearCore: return unit.get_gear(CORE_ID)

## Fire `kit_id`'s solo action from `attacker` at `target` with the d20s queued first and a tail of
## sixes behind them for every damage die (a crit doubles them). CLEARS THE QUEUE FIRST.
static func attack(game:Gamemaster, attacker:Unit, kit_id:StringName, target:Unit, d20s:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])
	await SpecFactory.use_solo(game, attacker, kit_id, [target])

## Raise `tiles` by `by` above where they stand now (SpecFactory.set_tiles_elevation re-tracks every
## unit, so the cached effective floors follow).
static func raise(game:Gamemaster, tiles:Array[Vector2i], by:int) -> void:
	var to:int = game.map.elevation(tiles[0]) + by
	SpecFactory.set_tiles_elevation(game.map, to, tiles)

## Every tile in a rectangle, both corners included.
static func rect(from:Vector2i, to:Vector2i) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for y:int in range(from.y, to.y + 1):
		for x:int in range(from.x, to.x + 1): tiles.append(Vector2i(x, y))
	return tiles
