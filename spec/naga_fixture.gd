# The shared Naga spec fixture (SP1 Task 1). EVERY SIGNATURE HERE IS FROZEN for the rest of SP1.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as sluagh_fixture.gd,
# leoleth_fixture.gd, primrose_fixture.gd and the others do: everything except create_naga() and
# this frame's own helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'cp_shimmering_veil') stops finding anything. No Naga spec writes to the frame's
# stats.
#
# THE GAMEMASTER IS THE SHARED ONE (2.65x faster, and it is the branch that builds a CampaignCore,
# which EventService.remove_unit_from_game dereferences unguarded - fitzgerald_fixture.create_game).
#
# SIZE 2, SO THE RE-TRACKING LINE IS LOAD-BEARING - the Myconid's create_myconid verbatim:
# SpecFactory.create_unit adds every unit at SIZE 1 and only full_repair() grows it to the frame's
# size 2; MapState.unit_tiles is rebuilt only by map_bus.update_unit_tile_tracking, which nothing in
# that sequence fires, so without UnitTile.move_to the map indexes the Naga at its anchor tile
# ALONE and every range lookup through the tile index misses it on the other three. The Sluagh's
# fixture deliberately omits this line because that frame is size 1; this one needs it.
#
# THE MAP IS 30x12, the Sluagh's, and the frame decides it: Sensors 8 and the core passive's "within
# Sensors" clause stand allies at 8 and 9 from the mech, which on the 15x9 default is off the east
# edge, where a unit has NO occupied tiles and every distance to it reads as the 1000 sentinel - a
# "beyond Sensors" test would pass for the wrong reason (memory lancer-tactics-spec-harness-traps).
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_naga'
const LICENSE_ID := &'li_naga'

## The three sheet traits and the core system, in sheet order. Exposed Reactor is VANILLA
## (content/frames/shared/mt_exposed_reactor.tres), referenced by the frame, never authored here.
const WIRE_SLITHER_ID := &'mt_wire_slither'
const ATC_ID := &'mt_advanced_targeting_calculations'
const EXPOSED_REACTOR_ID := &'mt_exposed_reactor'
const CORE_ID := &'cp_shimmering_veil'

## Wire Slither's one action - the unit_action POST reaction that offers the 2-tile move.
const SLITHER_ACTION_ID := &'action_wire_slither'
## Advanced Targeting Calculations' one buff - the VISIBLE crit-threshold chip (ruling 2).
const ATC_CHIP := &'buff_advanced_targeting_calculations'

## The core system's three actions, each in its own usage group (design 1.4).
const SALVATION_ID := &'action_salvation_upon_the_wicked' # the protocol (ruling 8)
const RELOCK_ID := &'action_salvation_relock'             # its hidden statuses_changed reaction
const BLOOD_ID := &'action_blood_of_the_creature'         # the passive's attack POST reaction (ruling 7)
## SALVATION's chip on the Naga for the rest of the scene. Visible.
const SALVATION_CHIP := &'buff_salvation'

## Basic-loadout Kits every player mech carries (content/gear/basic/basic_loadout_mech_player.tres).
## Lock On and Scan are tech ActionSystems; Fragment Signal is an ActionAttackTech invade; Boost is
## the non-tech control; Stabilize is the other way to lose a Lock On.
const LOCK_ON := &'ms_lock_on'
const LOCK_ON_ACTION := &'action_lock_on'
const SCAN := &'ms_scan'
const SCAN_ACTION := &'action_scan'
const INVADE := &'ms_fragment_signal'
const BOOST := &'ms_boost'

## The plain vanilla rifle every Fitzgerald spec uses: MAIN, RIFLE, 1d6, RELIABLE 2, aim_range 10,
## threat 1, no accuracy modifier. ITS RELIABLE 2 IS A FLOOR ON A HIT TOO (attack_util.gd:144-147),
## so never cheat a rifle damage die below 3 in a test whose evidence is that number - the Sluagh
## fixture's header has the measurement.
const MAIN_RIFLE := &'mw_assault_rifle'

## A vanilla SMART weapon: GMS Nexus (Light), Aux, 1d3, Range 10, tags [smart]. The spike's choice;
## what Advanced Targeting Calculations reads. One d20 and one damage die per shot, no accuracy die.
const SMART_WEAPON := &'mw_nexus_light'

const DEFAULT_MAP_SIZE := Vector2i(30, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder can answer a SEQUENCE of yes/no and unit prompts and hand back the one it
## installed - sluagh_fixture.create_game_with_prompt_queues verbatim. Needed wherever a spec must
## assert that a "may" prompt was or was NOT raised: the stock responder answers and records nothing.
## add_responder = false is what stops TWO responders answering the same request.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Naga with its traits' passive buffs applied, and the map's tile index told it is size 2.
## PLAYER faction, which SpecFactory's own default gives us and which is load-bearing twice over:
## every hostile/ally relation in the ability specs depends on it, and CommonActionUtil.confirm_use
## returns true WITHOUT asking when the unit is not player-controlled (common_action_util.gd:304).
static func create_naga(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached footprint, THEN rebuild the map's tile index
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. E-DEF stays statblock_default.tres's 8 - a SMART
## weapon rolls against THAT (action_attack_weapon.gd:250-252), so the evasion argument is inert
## for the Nexus; set_edef() below is what moves it.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return create_dummy(game, tile, evasion)

## A friendly CHARACTER - the ally the core passive moves and shields.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## An allied DRONE: a character that is NOT an actor. The NEGATIVE control for ruling 21's
## "character" clauses (the core passive's consumer, the core active's loser). Unit.is_character()
## IS true of a drone (unit.gd:116), which is exactly why every clause says is_actor() (:117) for
## itself - the Sluagh fixture's header carries the full argument and the mod-wide precedent.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Give a drone an OWNER, so Unit.get_attacker() resolves its shots to that owner (the engine's own
## UnitBattleState.set_owner, unit_battle_state.gd:255-261). An unowned drone is the control.
static func own_drone(drone:Unit, owner:Unit) -> Unit:
	drone.state.set_owner(owner)
	return drone

## Isolated frames rewrite E-DEF directly; full_repair picks it up. The spike's set_edef.
static func set_edef(unit:Unit, edef:int) -> void:
	unit.core.frame.stat.edef = edef
	unit.core.full_repair()

## Isolated frames rewrite armor directly; the core active's "1 AP" case wants a 3-armor dummy.
static func set_armor(unit:Unit, armor:int) -> void:
	unit.core.frame.stat.armor = armor
	unit.core.full_repair()

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Cycle the unit's turn: end it if open, then start it. Clears the per-TURN soft limit so a second
## non-free action can be taken, and (event_turn_start.gd:79) resets THIS unit's per-round tallies -
## so a spec measuring a 1/round must not cycle the holder's turn between its two attempts.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## Put a Kit on a unit as a SYSTEM, and hand back its GearCore. IDEMPOTENT, and the idempotence is
## load-bearing: UnitPrinter.equip_system calls full_repair, which sets core.has_core_power = true
## and rebuilds the loadout, and SpecFactory.apply_passive_buffs re-applies every passive buff from
## scratch. So: equip everything first, press the protocol LAST, never equip again after pressing.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	return unit.get_gear(kit_id)

static func arm_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)
static func arm_nexus(unit:Unit) -> GearCore: return equip(unit, SMART_WEAPON)

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s.
##
## THE TAIL IS 1s: the Naga has 10 HP and 1 armor and the dummies have 200, so a stray cheated six
## would never end a test - but a tail of 1s also keeps every unplanned d6 (a structure check, a
## recharge roll at a turn start) as harmless as it can be. CLEARS FIRST: Dice.cheat_attack only
## APPENDS (dice.gd:13-17), and a leftover from an earlier shot would be handed to the next roll in
## place of its own first value.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## A guaranteed HIT that is never a crit against any defence this fixture hands out (10 or less):
## base_roll 19 minus the worst-case -6 accuracy die is 13, always short of the crit threshold 20 -
## and short of Advanced Targeting Calculations' 18 too, which is the number that frame reads.
static func cheat_a_hit() -> void: queue([19])

## A guaranteed MISS: base_roll 1 cannot beat any defence this fixture hands out.
static func cheat_a_miss() -> void: queue([1])

## Lock On: a QUICK tech action, so the turn is opened first. Pops NOTHING off the dice queue.
static func lock_on(game:Gamemaster, unit:Unit, target:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use(game, unit, LOCK_ON, LOCK_ON_ACTION, target)

## Scan: a QUICK tech action; needs a target with something unscanned (action_scan.gd:9-16).
static func scan(game:Gamemaster, unit:Unit, target:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use(game, unit, SCAN, SCAN_ACTION, target)

## Fragment Signal, the basic invade: an ActionAttackTech. POPS ONE ENTRY - the d20 (no accuracy
## die without a modifier; a tech attack's flat '2' rolls nothing). Auto-hits an ALLY and pops
## nothing at all in that case (the autohit branch returns before AttackRoll.roll_attack).
static func invade(game:Gamemaster, unit:Unit, target:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, INVADE, target)

## Boost: a QUICK non-tech action; the stock responder answers the picker it opens.
static func boost(game:Gamemaster, unit:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, BOOST)

## Fire the rifle at a target, CYCLING the attacker's turn first (the per-turn soft limit swallows a
## second shot in one turn silently - sluagh_fixture.shoot's header). POPS the d20, then - ONLY when
## a Lock On is consumed - one accuracy d6 for buff_lock_consumed's +1, then the damage d6.
static func shoot(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await cycle_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target)

## A SECOND rifle shot from an attacker whose turn is ALREADY open, cycling nothing - AS_FREEBIE
## bypasses the per-turn soft limit (unit_action.gd:114). The only way to fire twice in one turn
## without handing every unit on the map its reaction point back (every_new_turn_refresh runs for
## ALL units at ANY turn start).
static func shoot_again(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target, [Action.FLAG.AS_FREEBIE])

## Fire the Nexus (Light) at a target, cycling the shooter's turn first. POPS the d20 and one
## damage die (1d3 rolls one d3 through the same FIFO); no accuracy die.
static func nexus_shot(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await cycle_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, SMART_WEAPON, target)

## Put Overshield on a unit through the shared helper, the way production does (a dummy event, so
## the helper's level path - the one every spec takes).
static func grant_overshield(unit:Unit, amount:int) -> void:
	await Overshield.grant(SpecFactory.dummy_event({unit = unit}), unit, amount)

## Press SALVATION UPON THE WICKED, turn and all. CALL THIS LAST - see equip()'s header. A PROTOCOL
## needs unit.state.is_using_protocols, which only the turn start opens (unit_action.gd:144).
## SpecFactory.use rather than use_solo: the Kit carries THREE actions.
static func press_salvation(game:Gamemaster, naga:Unit) -> void:
	if not naga.state.is_taking_turn: await open_turn(game, naga)
	await SpecFactory.use(game, naga, CORE_ID, SALVATION_ID)

## Clear a status the way Stabilize's "clear condition" does: clear_status_via_ability ->
## clear_specific_status, which hands the status's OWN source on to the reaction bus
## (unit_condition.gd:479-483, :326-329). Driven inside a real event so the statuses_changed POST
## it queues is actually run - a dummy event has no block to run it on.
static func clear_by_ability(game:Gamemaster, unit:Unit, status:StringName) -> void:
	await game.execute_event(&'event_unit_clear_status', {
		unit = unit, category = status, string = source_of_status(unit, status),
	})

## The source recorded on a unit's live status of this type, or empty.
static func source_of_status(unit:Unit, status:StringName) -> StringName:
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == status: return condition.source
	return &''

## The per-round tally of one action on one Kit, read the way the engine reads it.
static func uses_this_round(unit:Unit, kit_id:StringName, action_id:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round(gear.kit.get_action(action_id))
