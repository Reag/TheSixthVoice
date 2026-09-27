# The shared Hazard spec fixture (SP1 Task 1).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, as every frame fixture since the Naga
# does: everything except create_hazard() and this frame's own helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var that does not survive duplicate() - at which point
# unit.get_gear(&'cp_int_type_command_systems') stops finding anything. No Hazard spec writes to
# the frame's stats.
#
# THE GAMEMASTER IS THE SHARED ONE (fitzgerald_fixture.create_game). SIZE 1, so no re-tracking line.
# THE MAP IS 30x12: Sensors 10 must be exceeded on one side for DON'T GIVE UP THE MECH's "outside
# Sensors" case.
#
# GRIT IS THE PILOT'S: PilotCore.get_grit() is Util.half(license_level) (ceili), and a fixture unit
# starts at licence level 0 = Grit 0. set_grit() takes the Grit wanted and derives the level.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const FRAME_ID := &'mf_hazard'
const LICENSE_ID := &'li_hazard'

## The two sheet traits and the core system, in sheet order.
const WOF_ID := &'mt_weight_of_fire'
const SHIELD_WALL_ID := &'mt_shield_wall'
const CORE_ID := &'cp_int_type_command_systems'

## Weight of Fire's one aura buff (ruling 2).
const WOF_BUFF := &'buff_weight_of_fire'
## Shield Wall's END_TURN POST reaction (ruling 3).
const SHIELD_WALL_ACTION_ID := &'action_shield_wall'
## The core's two actions (rulings 4-7), and their buffs.
const SUPPORTING_FIRE_ID := &'action_supporting_fire'
const DGUTM_ID := &'action_dont_give_up_the_mech'
const SF_BUFF := &'buff_supporting_fire'           # the ally's +1 Accuracy
const SF_COST_BUFF := &'buff_supporting_fire_cost' # the Hazard's +1 Difficulty
const DGUTM_ACTIVE := &'buff_dgutm_active'         # the MANUAL switch the immunity aura requires
const DGUTM_KNOCKBACK := &'buff_dgutm_knockback'
const DGUTM_PRONE := &'buff_dgutm_prone'

## The plain vanilla rifle: MAIN, RIFLE, 1d6, RELIABLE 2, aim_range 10. ITS RELIABLE 2 IS A FLOOR
## ON A HIT TOO, so never cheat its damage die below the Reliable under test.
const MAIN_RIFLE := &'mw_assault_rifle'
## A vanilla AUX weapon with no Reliable: GMS Nexus (Light), 1d3, Range 10, SMART. Weight of Fire's
## "non-Auxiliary" negative control.
const AUX_NEXUS := &'mw_nexus_light'
const DEFAULT_MAP_SIZE := Vector2i(30, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder can answer a SEQUENCE of prompts and hands back the one it installed -
## sluagh_fixture.create_game_with_prompt_queues verbatim. add_responder = false is what stops TWO
## responders answering the same request.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	return FitzgeraldFixture.create_game_with_prompt_queues(test, map_size)

## A Hazard with its traits' passive buffs applied. PLAYER faction (SpecFactory's default), which
## every ally/hostile relation below depends on, and which makes confirm_use actually ask.
static func create_hazard(game:Gamemaster, tile:Vector2i, grit:int = 0) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	set_grit(unit, grit)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## A friendly MECH (a vanilla player unit, not isolated - its frame is the default mech frame).
static func create_ally(game:Gamemaster, tile:Vector2i, grit:int = 0) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)
	set_grit(unit, grit)
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## An enemy-faction CHARACTER: 200 HP, armor 0, caller-chosen evasion.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## A DRONE: a character that is neither a mech nor an actor - the negative control for every
## "allied mech" and "allied character" clause (Unit.is_character() IS true of a drone).
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := FitzgeraldFixture.create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	return drone

static func set_grit(unit:Unit, grit:int) -> void:
	FitzgeraldFixture.set_grit(unit, grit)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## End the unit's turn if open, then start it.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## Put a Kit on a unit as an INTEGRATED system/weapon and hand back its GearCore. IDEMPOTENT.
## equip_system full_repairs and apply_passive_buffs re-applies every passive buff - so equip first,
## press actions last.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	return FitzgeraldFixture.equip(unit, kit_id)

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s. CLEARS FIRST.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## Fire ONE weapon Kit at a target, cycling the attacker's turn first.
static func shoot(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName = MAIN_RIFLE, flags:Array = []) -> void:
	await cycle_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, kit_id, target, flags)

## The weapon's live tag value, read the way the engine reads it when it rolls damage.
static func tag_value(unit:Unit, kit_id:StringName, tag:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	var specific := SpecificAction.create(unit, gear, gear.get_solo_action())
	return specific.action.get_weapon_tags(specific).get(tag, 0)

static func reliable(unit:Unit, kit_id:StringName) -> int:
	return tag_value(unit, kit_id, Lancer.WEAPON_TAG.RELIABLE)

## The per-round tally of one action on one Kit, read the way the engine reads it.
static func uses_this_round(unit:Unit, kit_id:StringName, action_id:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round(gear.kit.get_action(action_id))

## Place a piece and re-run the tracking pass (auras update here). For setup, never the move under
## test.
static func step(unit:Unit, tile:Vector2i) -> void:
	UnitTile.move_to(unit, tile)
