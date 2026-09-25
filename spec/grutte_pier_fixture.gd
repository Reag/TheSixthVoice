# The shared Grutte Pier spec fixture (SP1). gloire_fixture.gd's shape, re-pointed.
#
# DELEGATES TO fitzgerald_fixture.gd / shackleton_fixture.gd rather than copying them, as every frame
# fixture since the Naga does: everything except create_pier() and this frame's own helpers is
# frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var that does not survive duplicate() - at which point unit.get_gear(&'mt_...') stops
# finding anything. No Grutte Pier spec writes to the frame's stats; the ones that need armour out
# of the arithmetic zero core.current.armor, which the next full_repair() restores.
#
# SIZE 1, the size create_unit already adds every unit at, so no re-tracking line is needed - it is
# kept anyway (the Gloire's create_gloire) so a future size change cannot silently mis-index it.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const ShackletonFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')

const FRAME_ID := &'mf_grutte_pier'
const LICENSE_ID := &'li_drake'

## The two sheet traits, in sheet order, then the core system (SP2).
const PANOPLY_ID := &'mt_panoply_coat'
const PANOPLY_BUFF := &'buff_panoply_coat'
const BULWARK_ID := &'mt_bulwark'
const BULWARK_GATE := &'buff_bulwark_gate'
const BULWARK_COVER := &'buff_bulwark_cover'
const CORE_ID := &'cp_inevitability_core'

## The plain vanilla rifle: MAIN RIFLE, Range 10, 1d6 kinetic, Reliable 2.
const RIFLE := &'mw_assault_rifle'
## An ActionAttackTech with is_invade: 2 heat on a hit (action_attack_tech.gd:15-17).
const INVADE := &'ms_fragment_signal'

## Wide enough for a shot from 11 tiles out along one row.
const DEFAULT_MAP_SIZE := Vector2i(16, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Grutte Pier with its traits' passive buffs applied (Panoply Coat's). PLAYER faction unless told
## otherwise.
static func create_pier(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached footprint, THEN rebuild the map's tile index
	return unit

## A FrameIsolation'd 200-HP, armor-0 punching bag (fitzgerald_fixture.create_dummy).
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = -10, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	return ShackletonFixture.create_dummy(game, tile, evasion, faction)

## Put a Kit on a unit as an INTEGRATED system/weapon and hand back its GearCore. IDEMPOTENT.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	return ShackletonFixture.equip(unit, kit_id)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Fire one weapon or tech Kit at `target` from an already-open turn, with `dice` queued first (the
## d20, then the damage dice). The target is handed straight to the attack, so reach is NOT checked -
## which is what lets a Range 10 rifle fire from 11 tiles out.
static func attack(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName, dice:Array[int]) -> void:
	equip(attacker, kit_id)
	await open_turn(game, attacker)
	Dice.CHEAT_ROLL_QUEUE.append_array(dice)
	await SpecFactory.use_solo(game, attacker, kit_id, target)

## A new round: NEW_ROUND PRE, the activation reset, NEW_ROUND POST (event_round_new.gd:40-84).
static func new_round(game:Gamemaster) -> void:
	await game.execute_event(&'event_round_new', {})

static func has(unit:Unit, buff_id:StringName) -> bool:
	return UnitCondition.has_buff(unit, buff_id)
