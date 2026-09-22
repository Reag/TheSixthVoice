# The shared Leoleth spec fixture (SP1 Task 1). EVERY SIGNATURE HERE IS FROZEN for Tasks 2-13.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as sluagh_fixture.gd,
# primrose_fixture.gd, vauban_fixture.gd, maidens_blush_fixture.gd, myconid_fixture.gd,
# subutai_fixture.gd and mk2_fixture.gd do: everything except create_<frame>() and this frame's own
# helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'cp_hydraulic_excess') stops finding anything. No Leoleth spec writes to the frame's
# stats.
#
# THE GAMEMASTER IS THE SHARED ONE, and here that is load-bearing rather than only 2.65x faster: the
# re-use branch of SpecFactory.setup_gamemaster builds a CampaignCore and hangs it on the map
# (spec_factory.gd:47-48), and the fresh branch returns before reaching those two lines.
# EventService.remove_unit_from_game dereferences map.campaign_core with no guard
# (event_service.gd:80), so on a fresh gamemaster the first death in a test throws before
# unit.remove_from_game(), leaving a corpse that still answers is_valid(). DECIMATE'S CRATER DIES IN
# THREE OF ITS TESTS AND THE LEOLETH STRUCTURES IN FOUR MORE.
#
# NO SIZE RE-TRACKING. The Myconid's fixture ends create_myconid with UnitTile.move_to because that
# frame is size 2 and SpecFactory.create_unit adds every unit at size 1. The Leoleth IS size 1, so
# the line would be a no-op that reads as load-bearing. Deliberately absent.
#
# A BIGGER DEFAULT MAP THAN THE FITZGERALD'S 15x9, and it is the frame that decides it: Bulwark
# (ruling 13) is bounded by line of sight rather than by a radius, and its spec has to stand a
# hostile far enough out to be OUT of LOS behind a block while still on the map; Combust reaches
# Sensors 10. On the shared 15x9 landscape a unit placed beyond the map has NO occupied tiles and
# every distance to it reads as the 1000 sentinel, so an "out of range" test would pass for entirely
# the wrong reason (memory lancer-tactics-spec-harness-traps).
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_leoleth'
const LICENSE_ID := &'li_leoleth'

## The three sheet traits and the core system, in sheet order.
const TOE_TO_TOE_ID := &'mt_toe_to_toe'
## FORTY-THREE As, which is the card's name downcased (design 1.1). Counted against the LCP on
## 2026-09-21: len(trait name) == 43. If this constant and the .tres ever disagree, every Task 3
## assertion fails for the wrong reason - so count them, do not eyeball them:
##   grep -o "mt_a*" leoleth_fixture.gd | head -1 | sed 's/mt_//' | tr -d '\n' | wc -c   ->  43
const AAAA_ID := &'mt_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
const FLEET_ID := &'mt_fleet_of_foot'
const CORE_ID := &'cp_hydraulic_excess'

## The trait's one action, and the core system's four.
const TOE_TO_TOE_ACTION := &'action_toe_to_toe'
const ASR_ID := &'action_all_systems_red'
const RAGE_ID := &'action_rage'
const RAGE_ROLL_ID := &'action_rage_roll'
const COMBUST_ID := &'action_combust'

## Decimate's laid terrain: a MARKER frame carrying two trait Kits of its own (ruling 8).
const DECIMATE_FRAME_ID := &'dep_decimate'
const DECIMATE_ZONE_ID := &'mt_decimate_terrain'
const DECIMATE_EXPIRY_ID := &'mt_decimate_expiry'

## Every buff this frame ships in SP1. Named here so no spec re-types one and drifts.
const AAAA_BUFF := &'buff_aaaa_difficulty'
const FLEET_BUFF := &'buff_fleet_of_foot'
const ASR_COVER_CHIP := &'buff_all_systems_red_cover'
const RAGE_CHIP := &'buff_rage'
const DECIMATE_CHIP := &'buff_rage_decimate_crit'
const SWIFT_CHIP := &'buff_rage_swift'
const REACH_CHIP := &'buff_rage_reach'
const REACH_RELIABLE_BUFF := &'buff_rage_reach_reliable'
const BULWARK_CHIP := &'buff_rage_bulwark'
const BULWARK_PENALTY := &'buff_bulwark_penalty'
const HATRED_CHIP := &'buff_rage_hatred'

## The RAGE table's six faces, by the number on the d6 (ruling 7). Named so a spec reads
## rage(game, leoleth, FACE_SWIFT) rather than a bare 2.
const FACE_DECIMATE := 1
const FACE_SWIFT := 2
const FACE_REACH := 3
const FACE_COMBUST := 4
const FACE_BULWARK := 5
const FACE_HATRED := 6

## The plain vanilla rifle every Fitzgerald spec uses: MAIN, weapon_type unset so it is the archetype
## default RIFLE (3, action_attack_weapon.gd:12), 1d6, RELIABLE 2, aim_range 10, threat 1. It carries
## NO accuracy modifier of its own, so a shot by a unit with no accuracy buffs pops a d20 and nothing
## else off Dice.CHEAT_ROLL_QUEUE.
##
## TWO TRAPS, BOTH MEASURED. (1) Its RELIABLE 2 is a floor on a HIT as well as a miss - AttackUtil
## tops the reduced rolls up whenever total < reliable (attack_util.gd:143-147) - so a cheated damage
## die of 1 or 2 makes a hit and a miss indistinguishable. Every rifle damage die in this
## sub-project is 3 or more. (2) Fired BY the Leoleth it pops a SECOND die, because the 43 As puts
## -2 accuracy on every non-melee weapon attack and Dice.roll_d6_accuracy rolls only when the bonus
## is non-zero (dice.gd:86-88).
const MAIN_RIFLE := &'mw_assault_rifle'

## The plain vanilla melee weapon: MAIN, MELEE (weapon_type 2), 1d6+2, threat 1 (the archetype
## default, action_attack_weapon.gd:16), aim_range 0, NO tags and therefore Reliable 0. The Reliable 0
## is what makes it Task 9's "a Reliable-0 weapon gains Reliable 2" case, and the missing tags are
## what make it the clean QUICK MELEE weapon Toe To Toe offers.
const MELEE_KIT := &'mw_tactical_melee_weapon'

## A HEAVY MELEE weapon that is ALREADY Reliable 3 (mw_nanocarbon_sword.tres:19), threat 2. Task 9's
## "the higher stands" case: the engine's own add_tag_to_collection ADDS for RELIABLE
## (action_attack_weapon.gd:134), so a naive +2 buff would make this Reliable 5.
const RELIABLE_SWORD := &'mw_nanocarbon_sword'

## A MAIN MELEE weapon that is already Reliable EXACTLY 2 (mw_chain_axe.tres:18). Task 9's boundary:
## the buff must add nothing at all rather than making it 4.
const RELIABLE_AXE := &'mw_chain_axe'

## A SUPERHEAVY MELEE weapon (mw_combat_drill's action sets weapon_size = 3). Toe To Toe's negative
## control: ActionAttackWeapon.get_action_type returns FULL for a SUPERHEAVY and QUICK for everything
## else (action_attack_weapon.gd:87-91), so this weapon can never be Skirmished and must never be
## offered.
const SUPERHEAVY_MELEE := &'mw_combat_drill'

## A vanilla TECH attack, and it needs no equipping: ms_fragment_signal is in every player mech's
## basic loadout (content/gear/basic/basic_loadout_mech_player.tres:5) and its single action is an
## ActionAttackTech. Two jobs here: it is the PURE miss (a tech miss deals nothing at all), and it is
## the case that proves the 43 As leaves tech attacks alone - BuffWeaponType.check_if_passive_applies
## refuses anything that is not an ActionAttackWeapon (buff_weapon_type.gd:35).
const TECH_ID := &'ms_fragment_signal'

## The Minotaur's Localized Maze buff: to = &"counts_as_size", number 99
## (content/frames/horus/mf_minotaur/mt_localized_maze/buff_localized_maze.tres). Task 4's hardest
## case: Fleet of Foot must walk out of an engagement with a unit that counts as size 99, because
## MovementType.ignores_engagement() is checked BEFORE the size compare
## (unit_relation.gd:135 then :140-143). Applied as the VANILLA buff itself, by id.
const MAZE_BUFF := &'buff_localized_maze'

const DEFAULT_MAP_SIZE := Vector2i(24, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A Leoleth with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own default
## gives us and which is load-bearing twice over: every hostile/ally relation in the ability specs
## depends on it, and CommonActionUtil.confirm_use returns true WITHOUT asking when the unit is not
## player-controlled (common_action_util.gd:304) - which would make every prompt in Tasks 2 and 10
## invisible to the watcher.
static func create_leoleth(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. Defaults to evasion 10 ("only hit when we say"), which
## is also the Leoleth's own evasion - so one cheated d20 decides a hit or a miss against either.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER: the shooter in almost every test here.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return create_dummy(game, tile, evasion)

## A friendly CHARACTER - the ally Bulwark shelters and the ally Hatred must not answer for.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## A DRONE: a character that is NOT an actor. The negative control for every "character" clause on
## this frame (ruling 22) - Combust's target filter, Bulwark's aura, Hatred's damager test.
##
## Built by flipping is_drone on an ALREADY-ISOLATED frame rather than by loading a vanilla drone
## frame, the Vauban and Sluagh fixtures' reasoning verbatim: create_dummy calls
## FrameIsolation.isolate_frame, which deep-duplicates the Frame AND its Statblock, so this write
## cannot reach the shared ContentLibrary copy. It also keeps the unit's stats identical to every
## other dummy, so the only thing that differs between the drone case and the character case is the
## one flag under test.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Give a drone an OWNER, so Unit.get_owner_unit_or_self() resolves it to that owner.
##
## THIS IS THE ENGINE'S OWN CALL, not a hand-written field: UnitBattleState.set_owner writes
## deployable_owner_id, get_owner_unit reads it back through map.get_unit_by_id (unit.gd:264-268),
## and get_owner_unit_or_self walks the chain (unit.gd:270-273) - which is what ruling 22 resolves
## through.
##
## AN UNOWNED DRONE IS THE CONTROL, and it is the default create_drone gives: with no owner id
## get_owner_unit_or_self returns the drone itself, which is not an actor, so nothing fires.
static func own_drone(drone:Unit, owner:Unit) -> Unit:
	drone.state.set_owner(owner)
	return drone

## A hostile OBJECT - a Jericho cover on the enemy side. THE POINT IS THAT IT IS NOT A CHARACTER:
## Frame.ENTITY.OBJECT makes Unit.is_character() false (unit.gd:116 -> frame.gd:100), so every
## "character" clause on this frame has to pass it by. Combust's blast is the case that needs it.
static func create_hostile_object(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 10, 0, 10, Faction.AI_ENEMY)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Put a Kit on a unit as a SYSTEM, and hand back its GearCore. IDEMPOTENT.
##
## THE IDEMPOTENCE IS LOAD-BEARING, not tidiness. UnitPrinter.equip_system calls full_repair
## (unit_printer.gd:180), which sets core.has_core_power = true (:76) and rebuilds the loadout, and
## SpecFactory.apply_passive_buffs calls full_repair again and re-applies every passive buff from
## scratch. So a spec that equipped a weapon AFTER pressing RAGE would silently refund the core power
## and re-arm the whole frame.
##
## THE RULE EVERY LEOLETH SPEC FOLLOWS: equip everything first, press RAGE LAST, and never equip
## again inside a test that has already pressed.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	return unit.get_gear(kit_id)

static func arm_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)
static func arm_melee(unit:Unit) -> GearCore: return equip(unit, MELEE_KIT)

## Fire the rifle at a target, CYCLING the attacker's turn first.
##
## THE CYCLE IS NOT DECORATION, and neither is its direction. Action.get_per_turn_soft_limit caps any
## non-free action at one use per turn (action.gd:161-163), and the second use_solo in one turn aborts
## at event_gear_activate's check_specific_context with NO "Gear not available" line - so the shot
## silently never happens and a "the second hit did nothing" assertion passes for the boring reason
## (memory lancer-tactics-spec-harness-traps). Ending and restarting the ATTACKER's turn clears it.
##
## AND IT DOES NOT DISTURB THE LEOLETH'S OWN 1/ROUND TALLIES. uses_this_round is cleared by
## UnitAction.new_turn_refresh -> reset_per_round_usage (unit_action.gd:78, :87-88), which runs only
## at the turn start of the unit whose turn it is.
##
## IT DOES, HOWEVER, HAND THE DEFENDER ITS REACTION POINT BACK: UnitAction.every_new_turn_refresh
## runs for EVERY unit on the map at ANY unit's turn start (event_turn_start.gd:42-44, :69). Use
## shoot_again() when that matters.
static func shoot(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	if attacker.state.is_taking_turn: await SpecFactory.end_turn(game, attacker)
	await SpecFactory.start_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target)

## A SECOND rifle shot from an attacker whose turn is ALREADY open, cycling nothing.
##
## Action.FLAG.AS_FREEBIE is what lets it happen inside one turn: it bypasses the attacker's per-turn
## soft limit and touches nothing on the defending side. Pair it with an assertion that the second
## shot really fired (memory lancer-tactics-spec-harness-traps).
static func shoot_again(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target, [Action.FLAG.AS_FREEBIE])

## Swing a MELEE weapon, cycling the attacker's turn first, exactly as shoot() does. The kit is a
## parameter because Task 9 needs three different melee weapons (Reliable 0, 2 and 3) through one
## helper.
static func swing(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName = MELEE_KIT) -> void:
	if attacker.state.is_taking_turn: await SpecFactory.end_turn(game, attacker)
	await SpecFactory.start_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, kit_id, target)

## The vanilla tech attack. Needs no equipping (it is basic gear) and deals NO damage of its own,
## which is the only way to land a genuinely empty miss on an 8 HP frame.
static func invade(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	if attacker.state.is_taking_turn: await SpecFactory.end_turn(game, attacker)
	await SpecFactory.start_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, TECH_ID, target)

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s.
##
## THE WHOLE QUEUE, EXPLICITLY, because on this frame the order is the test. Dice.roll_d6() pops from
## the same global FIFO as an attack roll (dice.gd:33-35), and the RAGE roll happens at NEW_TURN POST
## - so a test that starts a turn and then attacks reads [the RAGE d6, the d20, ...].
##
## THE TAIL IS 1s, NOT 6s, AND THAT IS THIS FRAME: the Leoleth has 8 HP, so a stray cheated six is
## most of a structure. Every other fixture in this mod tails with sixes because its subject is a
## 200 HP dummy.
##
## CLEARS FIRST. Dice.cheat_attack only APPENDS (dice.gd:13-17), so a leftover from an earlier roll
## would be handed to the next one in place of its own first value.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## A guaranteed HIT that is never a crit, against any evasion this fixture hands out (10 or less):
## base_roll 19 minus the worst-case accuracy die still clears 10, and total_roll >= 20 is the crit
## threshold (attack_roll.gd:71-73).
static func cheat_a_hit() -> void: queue([19])

## A guaranteed MISS: base_roll 1 cannot beat any evasion this fixture hands out.
static func cheat_a_miss() -> void: queue([1])

## Press the RAGE protocol, turn and all. CALL THIS BEFORE any other turn manipulation - see equip()'s
## header for why it must come after every equip.
##
## SpecFactory.use(game, unit, kit_id, action_id) rather than use_solo(): the core Kit carries FOUR
## actions by the end of SP1 and use_solo fires the FIRST one, whichever that is.
##
## THE TURN IS LOAD-BEARING, not decoration: unit_action.gd:144 refuses a PROTOCOL unless
## unit.state.is_using_protocols, which only event_turn_start opens (event_turn_start.gd:82). The
## stock ChoiceBusResponder answers the confirm prompt ActionSystemApplyBuff raises
## (spec_factory.gd:376, chosen_yesnos defaults true).
static func press_rage(game:Gamemaster, leoleth:Unit) -> void:
	await open_turn(game, leoleth)
	await SpecFactory.use(game, leoleth, CORE_ID, RAGE_ID)

## Hold RAGE if it is not already held, then open a FRESH turn with the d6 landing on `face`.
##
## THE QUEUE IS EXACTLY [face] PLUS WHATEVER THE FACE ITSELF ROLLS, and that is measured rather than
## hoped: handle_starting_unit rolls one d6 per UN-RECHARGED non-basic gear (event_turn_start.gd:89-91),
## GearCore.is_recharged defaults TRUE (gear_core.gd:13) and full_repair resets it to true (:136), and
## no Kit this frame carries declares recharge_on - so the recharge loop pops nothing at all. The RAGE
## roll at NEW_TURN POST (event_turn_start.gd:56) is therefore the FIRST pop of the new turn.
##
## `tail` is whatever the face's own effect will roll afterwards, in order: Combust's save d20 and its
## 2d6, an attack's d20 and damage die. Pass it here rather than re-queueing, because re-queueing
## between the turn start and the attack would discard the tail the roll already consumed.
##
## THE PROTOCOL IS PRESSED IN A DIFFERENT TURN FROM THE ONE THAT ROLLS, on purpose: RAGE applies its
## chip at NEW_TURN POST of every turn AFTER the press, and pressing inside the turn under test would
## make "the previous face's chip is gone" untestable.
static func rage(game:Gamemaster, leoleth:Unit, face:int, tail:Array[int] = []) -> void:
	if not UnitCondition.has_buff(leoleth, RAGE_CHIP): await press_rage(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	var rolls:Array[int] = [face]
	rolls.append_array(tail)
	queue(rolls)
	await SpecFactory.start_turn(game, leoleth)

## Drive a unit past zero HP with ONE damage event, so event_unit_damage queues the structure event
## itself.
##
## THE STRUCTURE CHECK'S ONE d6 IS CHEATED TO 6, WHICH IS IMPAIRED. make_structure_check rolls
## structure_max - structure_current dice, i.e. ONE at the first structure; 2-4 rolls a SECOND d6 and
## raises a gear-destroy prompt, and a 1 stuns. Task 0's probe measured all of this
## (spec/test_spike_structured_pre_under_talents.gd's header).
##
## THE DEFAULT 13 IS THE LEOLETH'S OWN NUMBER: 8 HP and armor 1 means 13 lands 12 and leaves -4 on the
## bar, comfortably past zero with the overflow big enough to see.
static func structure(game:Gamemaster, unit:Unit, damage:int = 13) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append(6)
	await game.execute_event(&'event_unit_damage', {
		unit = unit, number = damage, category = Lancer.DAMAGE_TYPE.KINETIC,
	})

## Run the tracking pass: re-evaluate every aura on the map.
##
## THIS IS WHAT HANGS AN AURA BUFF. PassiveAura.update_unit is called from
## UnitTile.update_tracking_and_statuses (unit_tile.gd:24) and from nowhere else a spec reaches;
## SpecFactory.apply_passive_buffs only marks the gear's aura ACTIVE, it does not place anything.
## Bulwark's aura needs this after anything moves.
static func track(game:Gamemaster) -> void:
	UnitTile.update_tracking_and_statuses(game.map)

## Teleport a unit to a tile and re-run the tracking pass, which move_to does for us
## (unit_tile.gd:10-13). NOT a movement EVENT: nothing is spent, no engagement is evaluated, no
## reaction fires. Use it to place units; use walk() when the movement itself is the subject.
static func step(unit:Unit, tile:Vector2i) -> void:
	UnitTile.move_to(unit, tile)

## A real STANDARD move event to a tile, which is what spends speed and triggers engagement.
##
## MovementType.create_for_standard_move, NOT SpecFactory.move()'s default: the default is
## MovementType.create(unit, true), which is voluntary but NOT spend_move, and event_unit_move
## subtracts from current.speed only when spend_move is set (event_unit_move.gd:244-245). Toe To Toe
## (ruling 2) is entirely about that number, so the distinction is the test.
static func walk(game:Gamemaster, unit:Unit, tile:Vector2i) -> void:
	await SpecFactory.move(game, unit, tile, MovementType.create_for_standard_move(unit))

## Destroy a unit outright, without an attack. A DIRECT event_unit_die, deliberately: every damage
## kill fires `structured` before `death` and rolls an unseeded structure-table d6 (memory
## lancer-tactics-spec-harness-traps), which is four moving parts for a test that only cares that a
## death happened.
static func kill(game:Gamemaster, unit:Unit) -> void:
	await game.execute_event(&'event_unit_die', {unit = unit})

## The ONE Decimate crater on the map, or null.
##
## PLAIN get_all_units(), WITH NO ARGUMENTS, AND THE ARGUMENTS ARE WHY. The signature is
## `get_all_units(skip_markers := false, skip_deployables := false)` (map_state.gd:222-229) - two
## SKIP flags, not two INCLUDE flags, and markers are in by DEFAULT. Task 1 wrote `(true, true)` here
## reading it as map_state.gd:314's `include_markers` shape, which belongs to get_all_units_AT_TILE;
## that asked the map to skip every marker and therefore could never return a crater at all.
## Corrected at Task 7, measured: test_the_burst_one_around_it_becomes_difficult_terrain passed (the
## ground really was difficult) in the same run where every marker() assertion read null.
static func marker(game:Gamemaster) -> Unit:
	for unit:Unit in game.map.get_all_units():
		if Unit.is_valid(unit) and unit.core.frame.compcon_id == DECIMATE_FRAME_ID: return unit
	return null

## Shorthand every ability spec uses: does this unit hold this chip, from any source?
static func has(unit:Unit, buff_id:StringName) -> bool:
	return UnitCondition.has_buff(unit, buff_id)

## ------------------------------------------------------------------ SP2: rank I
## The Thunder Sword (design ruling 19). A MAIN MELEE weapon, Threat 1, whose whole ability is the
## on-hit chip.
const THUNDER_SWORD_ID := &'mw_thunder_sword'
const THUNDER_SWORD_ACTION := &'action_thunder_sword'
const THUNDER_SWORD_CHIP := &'buff_thunder_sword'

static func arm_thunder_sword(unit:Unit) -> GearCore: return equip(unit, THUNDER_SWORD_ID)

## Swing the Thunder Sword, cycling the attacker's turn first, exactly as swing() does - and it IS
## swing(), which takes a kit id for precisely this reason. Named separately so a reader of
## test_thunder_sword.gd never has to ask which weapon is in hand.
static func swing_sword(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await swing(game, attacker, target, THUNDER_SWORD_ID)

## W.I.N.G (design ruling 20). UNIQUE, LIMITED 2, one Protocol.
const WING_ID := &'ms_wing'
const WING_ACTION := &'action_enhanced_movement_suite'
const WING_CHIP := &'buff_wing'

static func arm_wing(unit:Unit) -> GearCore: return equip(unit, WING_ID)

## Press the Enhanced Movement Suite protocol, opening the turn if it is not already open.
##
## THE TURN IS LOAD-BEARING, exactly as it is for press_rage: unit_action.gd:144 refuses a PROTOCOL
## unless unit.state.is_using_protocols, which only event_turn_start opens (event_turn_start.gd:82).
## SpecFactory.use() rather than use_solo() so the action is named rather than "whichever is first",
## which costs nothing today and survives a second action being added to the Kit.
static func press_wing(game:Gamemaster, leoleth:Unit) -> void:
	if not leoleth.state.is_taking_turn: await open_turn(game, leoleth)
	await SpecFactory.use(game, leoleth, WING_ID, WING_ACTION)
