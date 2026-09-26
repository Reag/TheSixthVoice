# The shared Rakshasa spec fixture (SP1). Every later sub-project extends it; signatures here are
# additions-only from SP2 on.
#
# DELEGATES TO fitzgerald_fixture.gd for the game and the dummies, and to vauban_fixture.gd for the
# forced-save plumbing (a real EventCore with a valid block, a full forcing trifecta), the way every
# frame fixture in this mod does. NOT FrameIsolation'd for the Rakshasa itself, for
# fitzgerald_fixture.create_fitzgerald()'s reason: a deep duplicate of the frame hands the unit COPIES
# of its trait Kits, whose compcon_id is a lazily derived bare var (kit.gd:11-16) that does not
# survive duplicate(), so unit.get_gear(&'mt_worm_code') would stop finding anything.
#
# THE HOSTILES HAVE A HEAT CAP OF 20. Worm Code and every invade deal 2 heat to the defender; a dummy
# on the default statblock would overheat part-way through a test and roll a stress check off the
# shared dice queue, which reads as a wrong number rather than a wrong setup. The Rakshasa's own cap
# is its sheet's 5, so no test here pays Silver Tongue more than twice without a turn boundary.
#
# "CHARACTER" IS Unit.is_actor() (the mod-wide author's call, rulings row 301, re-confirmed for this
# frame at SP1 on 2026-09-26 over design ruling 3's is_character()): a drone is not a character.
# create_hostile_drone is the negative control for every "hostile character" clause.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const FRAME_ID := &'mf_rakshasa'
const LICENSE_ID := &'li_goblin'

## The SP1 traits, in sheet order, then Fragile (vanilla, by path) and the core system (empty until SP2).
const WORM_CODE_ID := &'mt_worm_code'
const WORM_CODE_ACTION := &'action_worm_code'
const WORM_CODE_USAGE := &'worm_code'
const SILVER_TONGUE_ID := &'mt_silver_tongue'
const SILVER_TONGUE_BUFF := &'buff_silver_tongue'
const SILVER_TONGUE_PAY := &'action_silver_tongue_pay'
const SILVER_TONGUE_USAGE := &'silver_tongue'
const FRAGILE_ID := &'mt_fragile'
const CORE_ID := &'cp_short_wave_disruptors'

## Basic gear on every player mech, no equipping: the vanilla Invade (an ActionAttackTech, is_invade),
## Impaired and Slowed on a hit, and the invade's own 2 heat to a non-ally.
const TECH := &'ms_fragment_signal'
## GMS main melee, 1d6+2 Kinetic, threat 1, no tags - the weapon-miss negative control. NOT the
## assault rifle: that one is Reliable, and deals damage on a miss.
const MELEE := &'mw_tactical_melee_weapon'
## Vanilla Iskander system: a mine the Rakshasa can own, for "a save its deployable forced" (the
## Vauban's own vehicle for the same question, test_grav_amped_interference.gd).
const MINES := &'ms_grounding_charges'
const MINE_ACTION := &'action_grounding_mine'
const MINE_KIT := &'mt_grounding_mine'

const DEFAULT_MAP_SIZE := Vector2i(16, 10)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder answers a SEQUENCE of prompts and records every one
## (testkit/mod_choice_responder.gd), and the responder itself: [game, responder]. Worm Code's yes/no
## and Silver Tongue's unit pick are both answered and counted through it. add_responder = false stops
## two responders answering the same request (maidens_blush_fixture.gd's reasoning).
static func create_game_with_prompts(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Rakshasa with its traits' passive buffs applied. PLAYER faction by default (SpecFactory's), which
## every hostile relation here depends on and which makes CommonActionUtil.confirm_use actually ask.
## The re-tracking line refreshes the cached footprint and the map's tile index (the Myconid
## fixture's reasoning) - harmless for a size-1 frame, and the same line every frame fixture ends on.
static func create_rakshasa(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile)
	return unit

## A FrameIsolation'd 200-HP, armor-0 hostile with heat cap 20 and a caller-chosen e-defense.
static func create_hostile(game:Gamemaster, tile:Vector2i, edef:int = 8,
		faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	unit.core.frame.stat.heat = 20
	unit.core.frame.stat.edef = edef
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## An ally of a PLAYER Rakshasa, otherwise the hostile's statblock.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return create_hostile(game, tile, 8, Faction.PLAYER)

## A hostile DRONE: a character that is not an ACTOR. Flipped on an already-isolated frame, so only
## the one flag differs from create_hostile.
static func create_hostile_drone(game:Gamemaster, tile:Vector2i) -> Unit:
	var drone := create_hostile(game, tile)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## A three-tile forbidden-interior wall: blocks sight at every layer and gives nothing behind it cover
## (test_bulwark.gd's reasoning). create_game sets forbidden_interiors_enabled first, which is what
## makes the interior a full-height blocker (landscape_node.gd:608).
static func raise_wall(game:Gamemaster, tiles:Array[Vector2i]) -> void:
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', tiles)
	game.map.calculate_los_blockers()

## Put a Kit on a unit and hand back its GearCore. equip_system full_repairs, which CLEARS every gear's
## state and usage, so equip everything BEFORE a test spends anything.
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

## How many numbers a queue() leaves behind it, so a test can tell whether a d20 was popped.
const TAIL := 60

## Load the dice FIFO with exactly these numbers, then a long tail of 3s. CLEARS FIRST: Dice's cheat
## queue only appends, so a leftover would be handed to the next roll. A 3 misses every e-defense in
## this file, so a roll nobody queued for is a miss, never a surprise hit.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in TAIL: all.append(3)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## Invade `target` with the basic Fragment Signal from the Rakshasa's (opened if need be) turn, the
## attack d20s queued in order: [first roll, reroll].
static func invade(game:Gamemaster, rakshasa:Unit, target:Unit, d20s:Array[int], flags:Array = []) -> void:
	await open_turn(game, rakshasa)
	queue(d20s)
	await SpecFactory.use_solo(game, rakshasa, TECH, target, flags)

## Whether the first queued number has been popped: the vacuity guard for "nothing was offered", so an
## attack that was silently refused (the per-turn soft limit logs nothing) cannot pass as a clean miss.
## <= rather than ==, because a weapon rolls its damage columns even on a miss.
static func d20_was_rolled() -> bool: return Dice.CHEAT_ROLL_QUEUE.size() <= TAIL

static func heat(unit:Unit) -> int: return unit.core.current.heat

static func uses(unit:Unit, kit_id:StringName, usage:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	return gear.get_uses_this_round_alt(usage) if GearCore.is_valid(gear) else -1

static func worm_code_uses(unit:Unit) -> int: return uses(unit, WORM_CODE_ID, WORM_CODE_USAGE)
static func silver_tongue_uses(unit:Unit) -> int: return uses(unit, SILVER_TONGUE_ID, SILVER_TONGUE_USAGE)

# ---------------------------------------------------------------- forced saves

## A forcer named the way every vanilla save-forcing action names one: unit AND gear AND action
## (vauban_fixture.forcer's header: roll_check copies the forcer only when all three are valid).
static func forcer(unit:Unit, gear_id:StringName = TECH, action_id:StringName = &'') -> SpecificAction:
	return VaubanFixture.forcer(unit, gear_id, action_id)

static func force_hull_save(test:GutTest, saver:Unit, forcing:SpecificAction) -> bool:
	return await VaubanFixture.force_hull_save(test, saver, forcing)

static func force_systems_save(test:GutTest, saver:Unit, forcing:SpecificAction) -> bool:
	return await UnitHasecheck.make_systems_save(VaubanFixture.save_event(test), saver, forcing)

## A d20 that fails every save in this file, then a tail.
static func queue_a_failure() -> void: VaubanFixture.queue_save_dice(1)
## A d20 that makes every save in this file, then a tail.
static func queue_a_pass() -> void: VaubanFixture.queue_save_dice(20)
