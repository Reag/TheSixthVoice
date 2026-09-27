# The shared Purple Thorn spec fixture (SP1 Task 1). EVERY SIGNATURE HERE IS FROZEN for the rest
# of SP1.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as naga_fixture.gd,
# sluagh_fixture.gd and the others do: everything except create_thorn() and this frame's own
# helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'cp_lav_tactical_engine') stops finding anything. No Thorn spec writes to the
# frame's stats.
#
# THE GAMEMASTER IS THE SHARED ONE (2.65x faster, and it is the branch that builds a CampaignCore,
# which EventService.remove_unit_from_game dereferences unguarded - fitzgerald_fixture.create_game).
#
# SIZE 1, so there is no re-tracking line: SpecFactory.create_unit indexes a size-1 unit on its one
# tile (the Sluagh's fixture omits the line for the same reason; the Naga's needs it).
#
# THE MAP IS 30x12, the Sluagh's. Sensors 15 does not bind anything in SP1 - the core passive's gate
# is Line of Sight, not Sensors - but Stalk the Horizon's "out of LOS" cases stand a wall between a
# mover and the Thorn, and the Nexus's Range 10 wants room to be exceeded on the east side.
#
# "MOUNTED" IS NOT "EQUIPPED" (test_spin.gd's header): UnitPrinter.equip_system files a weapon Kit
# in the loadout's `attacks` list as an INTEGRATED weapon, never on a mount. The Aux/Aux follow-up
# that Blessed Bolt must refuse (the engine's own NO_BONUS_DAMAGE flag, action_attack_weapon.gd:72)
# exists only for a weapon ON A MOUNT with an opposite Aux beside it - so mount_pair() below goes
# through MountCore.equip_primary/equip_secondary (vanilla's own test_mw_combat_drill.gd:17 idiom),
# and equip() stays for the integrated case.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_purple_thorn'
const LICENSE_ID := &'li_purple_thorn'

## The two sheet traits and the core system, in sheet order.
const VIGIL_ID := &'mt_vigil'
const BOLT_ID := &'mt_blessed_bolt_system'
const CORE_ID := &'cp_lav_tactical_engine'

## Vigil's one action - the DAMAGE POST reaction that offers the teleport reticle (ruling 2-3).
const VIGIL_ACTION_ID := &'action_vigil'
## Blessed Bolt System's one action - the ATTACK POST reaction that offers the +3 (ruling 4), and
## the hidden one-time BuffDamage it hangs on a yes.
const BOLT_ACTION_ID := &'action_blessed_bolt'
const BOLT_BUFF := &'buff_blessed_bolt'

## The core system's two actions, each in its own usage group (design 1.4).
const STALK_ID := &'action_stalk_the_horizon' # the passive: an entire_movement PRE reaction (ruling 5)
const REND_ID := &'action_rend'               # the active: QUICK, consumes the core power (rulings 6-7)
## Rend's VISIBLE chip on the Thorn until the end of its next turn; its DAMAGE POST trigger is the
## save-or-be-shoved.
const REND_CHIP := &'buff_cruel_and_unnatural'

## A vanilla AUX weapon that reaches: GMS Nexus (Light), 1d3, Range 10, tags [smart]. SMART rolls
## against E-DEF (action_attack_weapon.gd:250-252), which is statblock_default.tres's 8 on every
## dummy this fixture hands out, so a 19 hits and a 1 misses whatever evasion a dummy carries. One
## d20 and one damage die per shot, no accuracy die.
const AUX_NEXUS := &'mw_nexus_light'
## A vanilla AUX weapon that does NOT reach at range: GMS Pistol, 1d3, threat 3, no aim_range, tags
## [reliable]. The Aux/Aux pair's second half, and the "only Aux in threat" negative control.
const AUX_PISTOL := &'mw_pistol'
## The plain vanilla rifle every Fitzgerald spec uses: MAIN, RIFLE, 1d6, RELIABLE 2, aim_range 10,
## threat 1. Blessed Bolt's "a Main hit does not offer" control, and the Thorn's Rend/Vigil shooter
## where the size of the weapon does not matter. ITS RELIABLE 2 IS A FLOOR ON A HIT TOO
## (attack_util.gd:144-147), so never cheat its damage die below 3 in a test whose evidence is that
## number.
const MAIN_RIFLE := &'mw_assault_rifle'

const DEFAULT_MAP_SIZE := Vector2i(30, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder can answer a SEQUENCE of yes/no, unit and plan prompts and hand back the
## one it installed - sluagh_fixture.create_game_with_prompt_queues verbatim. Needed wherever a spec
## must assert that a "may" prompt was or was NOT raised: the stock responder answers and records
## nothing. add_responder = false is what stops TWO responders answering the same request.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Purple Thorn with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own
## default gives us and which is load-bearing twice over: every hostile/ally relation in the ability
## specs depends on it, and CommonActionUtil.confirm_use returns true WITHOUT asking when the unit
## is not player-controlled (common_action_util.gd:304).
static func create_thorn(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. E-DEF stays statblock_default.tres's 8 - a SMART
## weapon rolls against THAT, so the evasion argument is inert for the Nexus; set_edef() moves it.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return create_dummy(game, tile, evasion)

## A friendly CHARACTER.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

## A DRONE: a character that is NOT an actor (unit.gd:116-117). Since the mod-wide ruling of
## 2026-09-27 (reversing row 301) every membership clause reads "character" as is_character(), so a
## drone now PASSES every "character" clause too - it is no longer a membership negative control, only
## an is_actor()/is_mech() one, and the fixture for ATTRIBUTION (own_drone) cases.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var drone := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## A hostile OBJECT (a Jericho cover deployable), the Sluagh fixture's create_hostile_object shape:
## Vigil's "the victim any unit - an object counts" case and Rend's "a hit on an object forces
## nothing" case both need something that takes damage and is not a character.
static func create_object(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	return FitzgeraldFixture.create_deployable(game, tile, 200, 0, 10, faction)

## Isolated frames rewrite E-DEF directly; full_repair picks it up.
static func set_edef(unit:Unit, edef:int) -> void:
	unit.core.frame.stat.edef = edef
	unit.core.full_repair()

## Isolated frames rewrite armor directly; Vigil's "armor-zeroed hit does not offer" case.
static func set_armor(unit:Unit, armor:int) -> void:
	unit.core.frame.stat.armor = armor
	unit.core.full_repair()

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Cycle the unit's turn: end it if open, then start it. Clears the per-TURN soft limit so a second
## non-free action can be taken, and (event_turn_start.gd:79) resets THIS unit's per-round tallies -
## so a spec measuring a 2/round must not cycle the THORN's turn between its attempts. It DOES hand
## every unit on the map its reaction point back (every_new_turn_refresh runs for ALL units at ANY
## turn start, event_turn_start.gd:42-44) - which is what a Stalk the Horizon spec relies on to
## re-arm the point, and what a "no point left" case must avoid.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## Put a Kit on a unit as an INTEGRATED system/weapon, and hand back its GearCore. IDEMPOTENT, and
## the idempotence is load-bearing: UnitPrinter.equip_system calls full_repair, which sets
## core.has_core_power = true and rebuilds the loadout, and SpecFactory.apply_passive_buffs
## re-applies every passive buff from scratch. So: equip everything first, press Rend LAST, never
## equip again after pressing.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	return unit.get_gear(kit_id)

static func arm_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)
static func arm_nexus(unit:Unit) -> GearCore: return equip(unit, AUX_NEXUS)

## Put `primary` (and `secondary`, when given) ON A MOUNT - mount `index` of the unit's frame - and
## hand the mount back. The Thorn's mounts are [Aux/Aux, Aux/Aux, Flex] in that order (ruling 16),
## so index 0 or 1 with two Auxes is the pair Blessed Bolt's follow-up rule is about. Repairs and
## re-applies passive buffs afterwards, so the same equip-first-press-last rule as equip() applies.
static func mount_pair(unit:Unit, index:int, primary:StringName, secondary:StringName = &'') -> MountCore:
	var mount:MountCore = unit.core.loadout.mounts[index]
	mount.equip_primary(primary)
	if not secondary.is_empty(): mount.equip_secondary(secondary)
	SpecFactory.apply_passive_buffs(unit)
	return unit.core.loadout.mounts[index]

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s. CLEARS FIRST: Dice.cheat_attack
## only APPENDS (dice.gd:13-17), and a leftover from an earlier shot would be handed to the next
## roll in place of its own first value. The tail is 1s so every unplanned d6 (a structure check,
## a recharge roll at a turn start) stays as harmless as it can be.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## A guaranteed HIT against any defence this fixture hands out (10 or less): base_roll 19 minus the
## worst-case -6 accuracy die is 13. Not a crit (threshold 20).
static func cheat_a_hit() -> void: queue([19])

## A guaranteed MISS: base_roll 1 cannot beat any defence this fixture hands out.
static func cheat_a_miss() -> void: queue([1])

## Fire ONE weapon Kit at a target, CYCLING the attacker's turn first (the per-turn soft limit
## swallows a second shot in one turn silently - sluagh_fixture.shoot's header). The Nexus pops the
## d20 then one d3 damage die; the rifle the d20 then one d6; neither pops an accuracy die.
## `flags` is for CAN_FOLLOWUP: an Aux ON A MOUNT with an opposite Aux beside it fires that second
## Aux afterwards, AS_FREEBIE + IS_FOLLOWUP + NO_BONUS_DAMAGE (action_attack_weapon.gd:59-82).
static func shoot(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName = AUX_NEXUS, flags:Array = []) -> void:
	await cycle_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, kit_id, target, flags)

## A SECOND shot from an attacker whose turn is ALREADY open, cycling nothing - AS_FREEBIE bypasses
## the per-turn soft limit (unit_action.gd:114). The only way to fire twice in one ROUND without
## handing every unit on the map its reaction point back, and without resetting the Thorn's own
## per-round tallies (the 2/round cases live on this).
static func shoot_again(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName = AUX_NEXUS) -> void:
	await SpecFactory.use_solo(game, attacker, kit_id, target, [Action.FLAG.AS_FREEBIE])

## A hostile's STANDARD move to a tile: event_unit_move with MovementType.create(unit, true) - a
## voluntary, non-teleport, reaction-provoking move, which is what "starts to move" means to
## Overwatch and to Stalk the Horizon. Opens the mover's turn first, the way a real move happens.
static func standard_move(game:Gamemaster, mover:Unit, tile:Vector2i) -> void:
	if not mover.state.is_taking_turn: await open_turn(game, mover)
	await SpecFactory.move(game, mover, tile)

## Press REND THAT WHICH IS CRUEL AND UNNATURAL, turn and all. CALL THIS LAST - see equip()'s header.
## SpecFactory.use rather than use_solo: the Kit carries TWO actions.
static func press_rend(game:Gamemaster, thorn:Unit) -> void:
	if not thorn.state.is_taking_turn: await open_turn(game, thorn)
	await SpecFactory.use(game, thorn, CORE_ID, REND_ID)

## The per-round tally of one action on one Kit, read the way the engine reads it.
static func uses_this_round(unit:Unit, kit_id:StringName, action_id:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round(gear.kit.get_action(action_id))

## Move a unit to a tile by hand and re-run the tracking pass (unit_tile.gd:10-13). For placing a
## piece before a case, never for the move under test.
static func step(unit:Unit, tile:Vector2i) -> void:
	UnitTile.move_to(unit, tile)
