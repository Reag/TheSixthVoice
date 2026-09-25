# The shared Koremasa spec fixture (SP1). Every later sub-project extends it; signatures here are
# additions-only from SP2 on.
#
# DELEGATES TO fitzgerald_fixture.gd for the game and the dummies, the way every frame fixture in this
# mod does. NOT FrameIsolation'd for the Koremasa itself, fitzgerald_fixture.create_fitzgerald()'s
# reason: a deep duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a
# lazily derived bare var (kit.gd:11-16) that does not survive duplicate(), so unit.get_gear(&'mt_entrap')
# would stop finding anything.
#
# SIZE HALF. The Koremasa is the second size-1/2 player frame (the Fitzgerald is the first), and
# SpecFactory.create_unit caches the footprint of whatever frame it was built with - so create_koremasa
# ends with UnitTile.move_to, which refreshes the cached size and the map's tile index (the Gloire
# fixture's reasoning).
#
# THE HOSTILE HAS A HEAT CAP OF 20, AND THAT IS THIS FRAME. Exploit Weakness deals up to 4 heat and
# Entrap 1, both to the defender; a dummy on the default statblock would overheat part-way through a
# test and roll a stress check off the shared dice queue, which reads as a wrong number rather than a
# wrong setup.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_koremasa'
const LICENSE_ID := &'li_koremasa'

## The three SP1 traits, in sheet order. The core system joins at SP2.
const SHIMMER_ID := &'mt_plasma_shimmer'
const SHIMMER_BUFF := &'buff_plasma_shimmer'
const EXPLOIT_ID := &'mt_exploit_weakness'
const EXPLOIT_ACTION := &'action_exploit_weakness'
const EXPLOIT_USAGE := &'exploit_weakness'
const ENTRAP_ID := &'mt_entrap'
const ENTRAP_ACTION := &'action_entrap_koremasa'
const ENTRAP_MARK_ACTION := &'action_entrap_mark_koremasa'
const ENTRAP_MARK := &'buff_entrap_mark'

## GMS main melee, 1d6+2 Kinetic, threat 1 - no tags that could add a line to anything here.
const MELEE := &'mw_tactical_melee_weapon'
## GMS aux melee, 1d3+1, threat 1, THROWN 3: the one weapon that is a melee WEAPON but, thrown, not a
## melee ATTACK (design ruling 14).
const KNIFE := &'mw_tactical_knife'
## GMS main rifle - the ranged negative control, and the hostile's gun for Plasma Shimmer.
const RIFLE := &'mw_assault_rifle'
## Basic gear on every mech, no equipping: the vanilla Invade (an ActionAttackTech).
const TECH := &'ms_fragment_signal'
## Basic gear: the Ram. A melee attack the card does not count (allow_basic = false, ruling 14).
const RAM := &'mw_ram'

const DEFAULT_MAP_SIZE := Vector2i(16, 12)

## The seven statuses the engine flags counts_as_condition (ruling 13).
const CONDITIONS:Array[StringName] = [
	Lancer.STATUS.IMMOBILIZED, Lancer.STATUS.IMPAIRED, Lancer.STATUS.JAMMED, Lancer.STATUS.LOCKON,
	Lancer.STATUS.SHREDDED, Lancer.STATUS.SLOWED, Lancer.STATUS.STUNNED,
]

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Koremasa with its traits' passive buffs applied. PLAYER faction (SpecFactory's default), which
## every hostile relation here depends on, and which makes CommonActionUtil.confirm_use actually ask.
static func create_koremasa(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached (size-1/2) footprint and the tile index
	return unit

## A FrameIsolation'd 200-HP, armor-0 hostile with heat cap 20 and a caller-chosen evasion and
## e-defense. 10/8 are the Koremasa's own, so one cheated d20 means the same against either.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10, edef:int = 8,
		faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, evasion, faction)
	unit.core.frame.stat.heat = 20
	unit.core.frame.stat.edef = edef
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return create_hostile(game, tile, 10, 8, Faction.PLAYER)

## A hostile DRONE: a character that is not an ACTOR (rulings row 301, mod-wide). Flipped on an
## already-isolated frame, the Leoleth fixture's reasoning, so only the one flag differs.
static func create_hostile_drone(game:Gamemaster, tile:Vector2i) -> Unit:
	var drone := create_hostile(game, tile)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Put a Kit on a unit and hand back its GearCore. IDEMPOTENT: equip_system full_repairs and
## apply_passive_buffs re-applies every passive, so equip everything BEFORE a test sets any state.
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
## (unit_action.gd:74-76, :86-87 - ruling 18).
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## A new ROUND: event_round_new raises round_count, then NEW_ROUND PRE and POST.
static func new_round(game:Gamemaster) -> void:
	await game.execute_event(&'event_round_new', {})

## Load the dice FIFO with exactly these numbers, then a long tail of 3s. CLEARS FIRST: Dice's cheat
## queue only appends, so a leftover would be handed to the next roll.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(3)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## Fire one weapon Kit (or a variant of it) from the attacker's ALREADY-OPEN turn.
static func attack(game:Gamemaster, attacker:Unit, kit_id:StringName, target:Unit, d20:int,
		flags:Array = [], variant:String = '') -> void:
	await open_turn(game, attacker)
	queue([d20])
	await SpecFactory.use_solo(game, attacker, kit_id, target, flags, variant)

## Put `count` of the seven conditions on a unit, MANUAL, in CONDITIONS order.
static func afflict(unit:Unit, count:int) -> void:
	for i:int in count:
		UnitCondition.apply_status(SpecFactory.dummy_event(), unit, CONDITIONS[i], Lancer.UNTIL.MANUAL)

## Set a unit's heat to exactly `heat`, then run the engine's own DANGER ZONE check - the call
## event_unit_set_stat, event_unit_damage and event_unit_cool each make after moving heat
## (event_unit_set_stat.gd:21). DZ is heat >= half the cap, rounded up: 4 of the Koremasa's 8.
static func set_heat(game:Gamemaster, unit:Unit, heat:int) -> void:
	unit.core.current.heat = heat
	UnitCondition.update_danger_zone_status(unit, SpecFactory.dummy_event())

static func heat(unit:Unit) -> int: return unit.core.current.heat

static func exploit_uses(unit:Unit) -> int:
	var gear:GearCore = unit.get_gear(EXPLOIT_ID)
	return gear.get_uses_this_round_alt(EXPLOIT_USAGE) if GearCore.is_valid(gear) else -1

static func is_marked(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, ENTRAP_MARK)
