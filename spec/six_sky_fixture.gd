# The shared Six Sky spec fixture (SP1). Every later sub-project extends it; signatures here are
# additions-only from SP2 on.
#
# DELEGATES TO fitzgerald_fixture.gd for the game and the dummies, the way every frame fixture in this
# mod does. NOT FrameIsolation'd for the Six Sky itself, for fitzgerald_fixture.create_fitzgerald()'s
# reason: a deep duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a
# lazily derived bare var (kit.gd:11-16) that does not survive duplicate().
#
# "CHARACTER" IS Unit.is_character(): a drone is a character (rulings.md, mod-wide row of 2026-09-27,
# reversing row 301). create_drone is still useful as a control for is_actor() (attribution) and
# is_mech() clauses, which a drone still fails.
#
# EVERY TELEPORT HERE GOES THROUGH THE FROZEN HELPER (roadmap section 4), so a spec exercises the very
# event shapes the traits observe: Teleport.move for the Six Sky's own unpreventable shape, Teleport.shove
# for a teleport of somebody else, both carrying the ACTOR's SpecificAction as the move's object.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const FRAME_ID := &'mf_six_sky'
const LICENSE_ID := &'li_sunzi'
const SUNZI_ID := &'mf_sunzi'
const SUNZI_MOD := 'gavstarb-ha_sunzi'
const LICENSE_PATH := 'res://unpacked/gavstarb-ha_sunzi/res/content/licenses/ha/li_sunzi.tres'

## The SP1 traits, in sheet order, then the core system and its integrated weapon (shells until SP2).
const WEAVER_ID := &'mt_heavenly_weaver'
const WEAVER_WATCH := &'buff_heavenly_weaver_watch'
const WEAVER_CHIP := &'buff_heavenly_weaver'
const WEAVER_USAGE := &'heavenly_weaver'
const STARSICKNESS_ID := &'mt_starsickness'
const STARSICKNESS_BUFF := &'buff_starsickness'
const STARSICKNESS_ACTION := &'action_starsickness'
const CORE_ID := &'cp_ors_daykeeper_cycler_bow'
const BOW_ID := &'mw_daykeeper_cycler_bow'

## GMS main rifle, Range 10, 1d6 Kinetic: the attack vehicle. RANGED_2 is a second gun, because the
## engine's per-turn soft limit silently refuses the same weapon twice in one turn.
const RANGED := &'mw_assault_rifle'
const RANGED_2 := &'mw_pistol'

## The Sunzi's Blink Charges: its Blink Mine is a resident-mod teleport source (design 1.5).
const BLINK_CHARGES_ID := &'ms_blink_charges'
const BLINK_MINE_ACTION := &'action_blink_mine'
const BLINK_MINE_FRAME := &'dep_blink_mine'
const BLINK_MINE_DETONATION := &'mt_blink_mine_detonation'
const REALSPACE_BREACH_ID := &'ms_realspace_breach'
const REALSPACE_BREACH_ACTION := &'action_realspace_breach'
const REALSPACE_BREACH_FRAME := &'dep_realspace_breach'
const REALSPACE_BREACH_DEP_KIT := &'mt_realspace_breach_dep'
# Vanilla HORUS Beckoner: a swap with no forcer on either move.
const BECKONER_ID := &'ms_beckoner'
const BECKON_ACTION := &'action_beckon'

## A d20 every attack in these files misses with, and one that hits (dummies have evasion 10).
const MISS_ROLL := 1
const HIT_ROLL := 15

const DEFAULT_MAP_SIZE := Vector2i(16, 10)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder answers a SEQUENCE of prompts and records every one
## (testkit/mod_choice_responder.gd), and the responder itself: [game, responder].
static func create_game_with_prompts(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	prompts_responder = responder
	return [game, responder]

## The last create_game_with_prompts responder, so press_ritual can answer the Ritual's confirm. Reset
## by every create_game_with_prompts; a stale one is caught by is_instance_valid.
static var prompts_responder

## A Six Sky with its traits' passive buffs applied. PLAYER faction by default (SpecFactory's), which
## every hostile relation here depends on and which makes CommonActionUtil.confirm_use actually ask.
static func create_six_sky(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
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

static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return create_dummy(game, tile, 10, Faction.PLAYER)

## A hostile CHARACTER holding the rifle.
static func create_hostile(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := create_dummy(game, tile)
	equip(unit, RANGED)
	return unit

## A DRONE: a character that is not an ACTOR. Flipped on an already-isolated frame, so only the one
## flag differs from create_dummy.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var drone := create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## A drone OWNED by `owner` and holding the rifle - Unit.get_owner_unit reads state.deployable_owner_id,
## so get_attacker resolves this drone's attacks to the owner (unit.gd:276-282), owner's buffs and all.
static func create_owned_drone(game:Gamemaster, tile:Vector2i, owner:Unit) -> Unit:
	var drone := create_drone(game, tile, owner.get_faction())
	drone.state.deployable_owner_id = owner.core.persistent_id
	equip(drone, RANGED)
	return drone

## Put a Kit on a unit as a SYSTEM and hand back its GearCore. equip_system full_repairs, which CLEARS
## every gear's state and usage AND the unit's heat, so equip everything BEFORE a test spends anything.
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
## (unit_action.gd:74-76, :86-87 - design ruling 4).
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

# ---------------------------------------------------------------- teleports

## An activation carrying `actor`'s unit + gear + action, so the helper hangs a VALID SpecificAction on
## the move as its object and Teleport.forcer reads `actor` (test_teleport.gd's sourced_activation).
static func activation_of(actor:Unit) -> EventCore:
	var gear:GearCore = actor.get_gear(&'mw_improvised_attack')
	return SpecFactory.dummy_event({unit = actor, gear = gear, action = gear.get_solo_action()})

## The Six Sky teleports itself: the helper's unpreventable own shape, forcer = the Six Sky.
static func teleport_self(six_sky:Unit, tile:Vector2i) -> EventCore:
	return await Teleport.move(activation_of(six_sky), six_sky, tile)

## A VOLUNTARY self-teleport with NO forcer at all - the vanilla Blinkspace shape (no object on the move),
## which design ruling 5's second clause credits to the mover.
static func teleport_self_without_a_source(six_sky:Unit, tile:Vector2i) -> EventCore:
	return await Teleport.move(SpecFactory.dummy_event(), six_sky, tile, false)

## `actor` teleports `who`: a target-tile shove carrying `actor`'s SpecificAction.
static func shove(actor:Unit, who:Unit, tile:Vector2i) -> EventCore:
	return await Teleport.shove(activation_of(actor), who, tile)

## The Six Sky lays a Sunzi Realspace Breach with the Sunzi's own action, and the breach is handed back
## (null if it was not laid).
static func deploy_realspace_breach(game:Gamemaster, six_sky:Unit, tile:Vector2i) -> Unit:
	equip(six_sky, REALSPACE_BREACH_ID)
	await SpecFactory.use(game, six_sky, REALSPACE_BREACH_ID, REALSPACE_BREACH_ACTION, [tile])
	for unit:Unit in game.map.get_all_units():
		if unit.core.frame != null and unit.core.frame.resource_path.get_file().get_basename() == REALSPACE_BREACH_FRAME:
			return unit
	return null

## `who` walks into `breach` and is teleported to `tile`, with the EXACT object the Sunzi's breach
## builds (ms_realspace_breach/deployable/action_teleport.gd:33-36): SpecificAction.from_context on the
## breach's reaction - the BREACH's gear and action - and then `unit` overwritten with the WALKER, since
## a plain walk carries no SpecificAction of its own.
static func breach_teleport(game:Gamemaster, breach:Unit, who:Unit, tile:Vector2i) -> void:
	var gear:GearCore = breach.get_gear(REALSPACE_BREACH_DEP_KIT)
	var action:Action = null
	for candidate:Action in gear.kit.actions:
		if candidate.resource_path.get_file() == 'action_teleport.tres': action = candidate
	var movement_type := MovementType.create_for_involuntary(who)
	movement_type.teleport = true
	await game.execute_event(&'event_unit_move', {
		unit = who,
		target_tiles = [tile],
		resource = movement_type,
		object = SpecificAction.create(who, gear, action),
	})

## The Six Sky hits `target` with vanilla BECKONER, a tech attack whose on_hit swaps the two with two
## involuntary teleports carrying NO object at all (action_beckon.gd:18-35).
static func beckon(game:Gamemaster, six_sky:Unit, target:Unit) -> void:
	equip(six_sky, BECKONER_ID)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([HIT_ROLL], [6, 6, 6, 6])
	await SpecFactory.use(game, six_sky, BECKONER_ID, BECKON_ACTION, [target])

# ---------------------------------------------------------------- reads

static func heat(unit:Unit) -> int: return unit.core.current.heat
static func health(unit:Unit) -> int: return unit.core.current.health

static func weaver_uses(unit:Unit) -> int:
	var gear:GearCore = unit.get_gear(WEAVER_ID)
	return gear.get_uses_this_round_alt(WEAVER_USAGE) if GearCore.is_valid(gear) else -1

static func weaver_chips(unit:Unit) -> int:
	return UnitCondition.get_buffs(unit, WEAVER_CHIP).size()

static func is_impaired(unit:Unit) -> bool:
	return UnitCondition.has_status(unit, Lancer.STATUS.IMPAIRED)

## Fire `kit_id`'s solo action from `attacker` at `target` with the d20s queued first and a tail of
## sixes behind them for every damage die. CLEARS THE QUEUE FIRST.
static func attack(game:Gamemaster, attacker:Unit, kit_id:StringName, target:Unit, d20s:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])
	await SpecFactory.use_solo(game, attacker, kit_id, [target])

# ---------------------------------------------------------------- SP2: the bow and the Ritual

const BOW_ACTION := &'action_daykeeper_cycler_bow'
const RITUAL_ACTION := &'action_ritual_of_the_first_god'
const RITUAL_BUFF := &'buff_ritual_of_the_first_god'
const BOW_SCRIPT := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/cp_ors_daykeeper_cycler_bow/action_daykeeper_cycler_bow.gd'

## The d20 that crits (20 + anything is >= 20, and hits evasion 10).
const CRIT_ROLL := 20

## Fire the bow at `target` with EXACTLY `dice` queued, in the order the engine pops them: the d20,
## then the accuracy d6 when the target is within 5 (attack_roll.gd:70), then any on-hit save and
## anything an on-crit pops, then the damage dice - a HIT column and a CRIT column
## (AttackUtil rolls the weapon's dice once per column), then any Overkill rerolls. A tail of 6s
## follows, so a die the test did not plan for reads as a 6 rather than as random. CLEARS THE QUEUE.
static func fire_bow(game:Gamemaster, six_sky:Unit, target:Unit, dice:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array(dice)
	Dice.CHEAT_ROLL_QUEUE.append_array([6, 6, 6, 6, 6, 6, 6, 6])
	await SpecFactory.use_solo(game, six_sky, BOW_ID, [target])

## Press Ritual of the First God (opening the Six Sky's turn first), with `dice` queued. CLEARS THE
## QUEUE; no tail - a Ritual's dice are the test's to plan, target by target.
##
## `confirm` answers the Ritual's own "use it?" (close review) YES by pushing it to the FRONT of the
## queued responder's yes/no queue, ahead of anything the test queued for later prompts. A game with the
## stock responder confirms on its own (choose_yesnos defaults true).
static func press_ritual(game:Gamemaster, six_sky:Unit, dice:Array[int] = [], confirm:bool = true) -> void:
	if not six_sky.state.is_taking_turn: await open_turn(game, six_sky)
	if confirm and is_instance_valid(prompts_responder): prompts_responder.yesno_queue.push_front(true)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array(dice)
	await SpecFactory.use(game, six_sky, CORE_ID, RITUAL_ACTION)

static func bow_specific(six_sky:Unit) -> SpecificAction:
	var gear:GearCore = six_sky.get_gear(BOW_ID)
	if not GearCore.is_valid(gear): return null
	return SpecificAction.create(six_sky, gear, gear.kit.actions.front())

static func is_slowed(unit:Unit) -> bool:
	return UnitCondition.has_status(unit, Lancer.STATUS.SLOWED)

static func ritual_buffs(unit:Unit) -> int:
	return UnitCondition.get_buffs(unit, RITUAL_BUFF).size()
