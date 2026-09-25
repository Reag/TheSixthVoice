# The shared Gloire spec fixture (SP1). shackleton_fixture.gd's shape, re-pointed.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, as every frame fixture since the Naga
# does: everything except create_gloire() and this frame's own helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var that does not survive duplicate() - at which point unit.get_gear(&'mt_...') stops
# finding anything. No Gloire spec writes to the frame's stats.
#
# SIZE 2, SO THE RE-TRACKING LINE IS LOAD-BEARING - the Shackleton's create_shackleton verbatim:
# create_unit adds every unit at size 1 and only full_repair() grows it, and without UnitTile.move_to
# the map indexes the Gloire at its anchor tile alone. A size-2 unit at anchor (x, y) occupies
# (x..x+1, y..y+1). Distances below are Chebyshev over CLOSEST tiles (UnitRelation.distance_between).
#
# THE GAME CARRIES ITS OWN RESPONDER (the Shackleton's MoveQueueResponder) and a PromptWatcher,
# because the Ram's knockback opens a reticle every spec here has to answer, and the direction specs
# read what was OFFERED: the stock responder answers a move_tile prompt with params.tiles[0] and
# ask_for_movement_alt never checks the answer against the offer, so only the offer is evidence.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const ShackletonFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const FRAME_ID := &'mf_gloire'
const LICENSE_ID := &'li_tortuga'

## The three sheet traits, in sheet order, then the core system (SP2).
const GUARDIAN_ID := &'mt_guardian'
const PUNISHER_ID := &'mt_hydraulic_punisher'
const PUNISHER_BUFF := &'buff_hydraulic_punisher'
const PUNISHER_USAGE := &'hydraulic_punisher'
const ZONE_CONTROL_ID := &'mt_extended_zone_control'
const ZONE_CONTROL_RAM_BUFF := &'buff_extended_zone_control_ram'
const ZONE_CONTROL_CQB_BUFF := &'buff_extended_zone_control_cqb'
const CORE_ID := &'cp_retaliation_protocol_amplification'
## The core system's three actions (SP2): the passive Rapid Rushdown, the RPA Pullback protocol, and
## the protocol's hidden collision reaction.
const RUSHDOWN_ID := &'action_rapid_rushdown'
const RUSHDOWN_USAGE := &'rapid_rushdown'
const RUSHDOWN_ARMOR_BUFF := &'buff_rapid_rushdown_armor'
const RUSHDOWN_REDUCTION_BUFF := &'buff_rapid_rushdown_armor_reduction'
const PULLBACK_ID := &'action_rpa_pullback'
const PULLBACK_BUFF := &'buff_rpa_pullback'
const PULLBACK_PULL_BUFF := &'buff_rpa_pullback_pull'
const PULLBACK_COLLIDE_ID := &'action_rpa_pullback_collide'
## The variant key RPA Pullback puts on every non-Superheavy weapon.
const PULLBACK_VARIANT := &'rpa_pullback'

## The basic Ram: weapon_type MELEE, size NONE, threat 1, Knockback 1, Prone through the ordinary
## on_hit. Every unit carries one.
const RAM := &'mw_ram'
const RAM_ACTION := &'action_ram'
## The basic Stand Up: clears Prone on the unit's own turn.
const STAND_UP := &'ms_stand_up'
## GMS Shotgun: MAIN CQB, threat 3 - the "+2 Range with CQB weapons" subject.
const SHOTGUN := &'mw_shotgun'
## The plain vanilla rifle: MAIN RIFLE, Range 10 - the ranged negative control.
const RIFLE := &'mw_assault_rifle'
## IPS-N War Pike: MAIN MELEE, threat 3, Knockback 1 - the "push then pull" subject under RPA
## Pullback, and the melee weapon the variant must appear on.
const PIKE := &'mw_war_pike'
## GMS Heavy Machine Gun: HEAVY RIFLE, Range 8 - a Heavy the variant must appear on.
const HMG := &'mw_heavy_machine_gun'
## GMS Cyclone Pulse Rifle: SUPERHEAVY - the one size the variant must NOT appear on.
const SUPERHEAVY := &'mw_cyclone_pulse_rifle'

const DEFAULT_MAP_SIZE := Vector2i(16, 12)

## [game, responder, watcher] - the Shackleton fixture's game with THIS frame's responder (below),
## which carries the queueing responder every knockback reticle here is answered by, plus the
## target-picker abort SP2's cancel tests need.
static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(GloireResponder.new())
	var watcher = test.add_child_autoqfree(PromptWatcher.new())
	return [game, responder, watcher]

## A Gloire with its traits' passive buffs applied (Guardian's, Extended Zone Control's two).
## PLAYER faction unless told otherwise.
static func create_gloire(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile) # refresh the cached footprint, THEN rebuild the map's tile index
	return unit

## A FrameIsolation'd 200-HP, armor-0 punching bag (fitzgerald_fixture.create_dummy). Evasion -10:
## every d20 hits it, so a Ram lands without cheating dice.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = -10, faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	return ShackletonFixture.create_dummy(game, tile, evasion, faction)

## Put a Kit on a unit as an INTEGRATED system/weapon and hand back its GearCore. IDEMPOTENT.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	return ShackletonFixture.equip(unit, kit_id)

## End the unit's turn if open, then start it - a new round's worth of per-round tallies.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	await ShackletonFixture.cycle_turn(game, unit)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Ram a target from an already-open turn, the d20 fixed to a plain hit (10 against evasion -10
## lands; a 20 would be a crit, which the Ram's Prone does not need). SpecFactory.use_solo hands the
## target straight to the attack, so the reach rule is NOT exercised here - the targeting specs read
## UnitTargeting for that.
static func ram(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await open_turn(game, attacker)
	Dice.CHEAT_ROLL_QUEUE.append(10)
	await SpecFactory.use_solo(game, attacker, RAM, target)

## The same Ram AS A FREEBIE (Action.FLAG.AS_FREEBIE waives cost and availability, unit_action.gd:110-114),
## which is the only way to floor a second target in the SAME turn: the Ram is a quick action and the
## no-repeat rule (is_under_per_turn_limit) refuses a second paid one. It is also exactly the Ram
## Rapid Rushdown grants at SP2 (design ruling 8).
static func ram_free(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await open_turn(game, attacker)
	Dice.CHEAT_ROLL_QUEUE.append(10)
	await SpecFactory.use_solo(game, attacker, RAM, target, [Action.FLAG.AS_FREEBIE])

## The Ram as a SpecificAction, for UnitTargeting and range reads.
static func ram_specific(unit:Unit) -> SpecificAction:
	var gear:GearCore = unit.get_gear(RAM)
	return SpecificAction.create(unit, gear, gear.get_solo_action())

static func weapon_specific(unit:Unit, kit_id:StringName) -> SpecificAction:
	var gear:GearCore = unit.get_gear(kit_id)
	return SpecificAction.create(unit, gear, gear.get_solo_action())

## The knockback pools the player was offered since `from` (a watcher.prompts index), as the
## pathfinders' MOVABLE tiles - the tiles the reticle actually lets a player click.
static func offered_pools(watcher, from:int = 0) -> Array:
	return ShackletonFixture.offered_pools(watcher, from)

static func punisher_uses(unit:Unit) -> int:
	var gear:GearCore = unit.get_gear(PUNISHER_ID)
	return gear.get_uses_this_round_alt(PUNISHER_USAGE) if GearCore.is_valid(gear) else -1

static func is_punished(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, PUNISHER_BUFF)

## A full-height wall down column x (test_blink_bolt_launcher.gd's shape): blocks LOS at every layer.
static func build_wall_at(game:Gamemaster, x:int, base_tile:Vector2i) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(base_tile) + 6, wall)
	UnitTile.update_tracking_and_statuses(game.map)

# ---------------------------------------------------------------- SP2 helpers

## Press Rapid Rushdown aimed at `destination` (an anchor tile). target_tiles is how a spec aims a
## movement action (test_full_speed_ahead.gd's header: TEST_MODE makes the activation's target_tiles
## the list the reticle is asked to pick from). The turn must already be open.
static func rushdown_to(game:Gamemaster, unit:Unit, destination:Vector2i) -> void:
	await SpecFactory.use(game, unit, CORE_ID, RUSHDOWN_ID, [destination])

static func rushdown_specific(unit:Unit) -> SpecificAction:
	var gear:GearCore = unit.get_gear(CORE_ID)
	return SpecificAction.create(unit, gear, gear.kit.get_action(RUSHDOWN_ID))

static func pullback_specific(unit:Unit) -> SpecificAction:
	var gear:GearCore = unit.get_gear(CORE_ID)
	return SpecificAction.create(unit, gear, gear.kit.get_action(PULLBACK_ID))

## Press the RPA Pullback protocol from a freshly STARTED turn (a protocol needs the window,
## unit_action.gd:144). Returns whether the variant buff landed.
static func press_pullback(game:Gamemaster, unit:Unit) -> bool:
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.use(game, unit, CORE_ID, PULLBACK_ID)
	return has_pullback(unit)

static func has_pullback(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, PULLBACK_BUFF)

static func rushdown_uses(unit:Unit) -> int:
	var gear:GearCore = unit.get_gear(CORE_ID)
	return gear.get_uses_this_round_alt(RUSHDOWN_USAGE) if GearCore.is_valid(gear) else -1

static func is_braced(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, RUSHDOWN_ARMOR_BUFF) and UnitCondition.has_buff(unit, RUSHDOWN_REDUCTION_BUFF)

## Fire one weapon Kit at `target` from an already-open turn WITH the rpa_pullback variant enforced
## (event_gear_activate.gd:135-142 filters the menu to the required key and makes it non-blankable,
## so the responder's default index 0 IS the variant). `hits` are the d20s, one per line target, in
## the order the engine rolls them (measured 2026-09-24: NOT closest first - the picked target rolled
## before a nearer one on the same line, so a spec with two targets on the line orders `hits` by
## that). `tail` is every die after them: the weapon's damage dice - the 1d6 rifle popped TWO for a
## two-target line - and then the collision save's d20, read from the same queue. One value serves
## both because the damage lands on a 200-HP dummy and only the save's outcome matters: 1 fails any
## Hull save (1 + hull against 10), 20 passes. Eight copies, so however many damage dice the attack
## pops the save still reads `tail`; after_each clears the rest.
static func fire_pulled(game:Gamemaster, attacker:Unit, target:Unit, kit_id:StringName, hits:Array[int] = [10], tail:int = 1) -> void:
	await open_turn(game, attacker)
	Dice.CHEAT_ROLL_QUEUE.append_array(hits)
	for i in 8: Dice.CHEAT_ROLL_QUEUE.append(tail)
	await SpecFactory.use_solo(game, attacker, kit_id, target, [], PULLBACK_VARIANT)

## The variant groups a weapon offers this unit right now, by group key.
static func variant_keys_for(unit:Unit, kit_id:StringName) -> Array[StringName]:
	var specific := weapon_specific(unit, kit_id)
	var keys:Array[StringName] = []
	for group:VariantActionGroup in specific.action.get_alternate_actions(specific):
		for variant:VariantAction in group.list: keys.append(variant.key)
	return keys

## The Shackleton's MoveQueueResponder plus an ABORT for the next target picker(s) - SP2's "the free
## Ram's cancel costs nothing" needs the Ram's compcon_plan request refused while the dash's
## move_tile reticle before it is still answered, which abort_all cannot express (it aborts both).
## Each aborted request consumes one count; a spec that never sets it sees the queueing responder
## exactly.
class GloireResponder extends ShackletonFixture.MoveQueueResponder:
	var abort_plans:int = 0

	func choose_compcon_plan(request:ChoiceRequest):
		if abort_plans > 0:
			abort_plans -= 1
			choices_made += 1
			await get_tree().process_frame
			request.abort()
			return
		await super(request)
