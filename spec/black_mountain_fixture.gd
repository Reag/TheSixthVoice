# The shared Black Mountain spec fixture (SP1). Every later sub-project extends it; signatures here are
# additions-only from SP2 on.
#
# DELEGATES TO fitzgerald_fixture.gd for the game and the dummies, the way every frame fixture in this
# mod does; the dice and Lock On helpers are the Naga fixture's, re-pointed, because this frame reads the
# same seams (a rifle shot that consumes a lock, a lock applied by hand through the shared hook).
#
# NOT FrameIsolation'd for the Black Mountain itself, for fitzgerald_fixture.create_fitzgerald()'s reason:
# a deep duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate().
#
# "CHARACTER" IS Unit.is_character() (mod-wide ruling, 2026-09-27): a drone is one too. create_drone /
# own_drone exist for ATTRIBUTION - whether a drone's action counts as its own or (owned) as its
# owner's through get_attacker/get_owner_unit_or_self - not as a "not a character" negative control any
# more. "ALLIED CHARACTER" EXCLUDES THE BLACK MOUNTAIN ITSELF
# on every card here (ruling 3, the author's call), so the Black Mountain shooting is a negative control
# for An End to All Things and a POSITIVE one only for Dread Harbinger.
#
# THE MAP IS 30x12, the Naga's: Sensors 10 puts "one tile outside Sensors" at x = 15 from a Black
# Mountain at x = 4, which the 15x9 default would put off the east edge, where distances read as the
# 1000 sentinel and a "beyond Sensors" test passes for the wrong reason (memory
# lancer-tactics-spec-harness-traps).
#
# THE EMPEROR (create_emperor) IS THE RESIDENT gavstarb-ssc_emperor's mf_emperor, worn whole: its
# Imperial Vestment is the reaction ruling 6 fixes the helper for, and a spec that only exercised a
# knockoff would not measure the resident. Its Storm Shield grants at unit_spawn, which
# SpecFactory.create_unit never fires, so an Emperor here starts at 0 Overshield.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT never collects it.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const FRAME_ID := &'mf_black_mountain'
const LICENSE_ID := &'li_emperor'
const EMPEROR_ID := &'mf_emperor'
const EMPEROR_MOD := 'gavstarb-ssc_emperor'
const LICENSE_PATH := 'res://unpacked/gavstarb-ssc_emperor/res/content/licenses/ssc/li_emperor.tres'

## The sheet traits, in sheet order, then the core system (a shell until SP2). Fragile is VANILLA
## (content/frames/shared/mt_fragile.tres), referenced by the frame, never authored here.
const AN_END_ID := &'mt_an_end_to_all_things'
const AN_END_ACTION := &'action_an_end_to_all_things'
const AN_END_BONUS := &'buff_an_end_to_all_things_bonus'
const HARBINGER_ID := &'mt_dread_harbinger'
const HARBINGER_ACTION := &'action_dread_harbinger'
const HARBINGER_MARK := &'buff_dread_harbinger_mark'
const FRAGILE_ID := &'mt_fragile'
const CORE_ID := &'cp_blackstone_bell'

## The Overshield helper's "granted by" mark (design ruling 5), hidden, LOSE_OVERSHIELD.
const GRANTED_BY_MARK := &'buff_overshield_granted_by'

## Basic-loadout Kits every player mech carries. Lock On is the vanilla way to lock; Stabilize the
## vanilla way to lose a lock without consuming it.
const LOCK_ON := &'ms_lock_on'
const LOCK_ON_ACTION := &'action_lock_on'
const INVADE := &'ms_fragment_signal'

## The plain vanilla rifle: MAIN, RIFLE, 1d6, RELIABLE 2, aim_range 10, threat 1, no accuracy
## modifier. ITS RELIABLE 2 IS A FLOOR ON A HIT TOO (attack_util.gd:144-147), so never cheat a rifle
## damage die below 3 in a test whose evidence is that number.
const MAIN_RIFLE := &'mw_assault_rifle'

## A d20 that HITS evasion 10 and never crits (19 - 6 worst-case accuracy die = 13); one that CRITS
## (30 is >= 20 whatever the accuracy die does); one that MISSES.
const HIT_ROLL := 19
const CRIT_ROLL := 30
const MISS_ROLL := 1

const DEFAULT_MAP_SIZE := Vector2i(30, 12)

static func create_game(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder can answer a SEQUENCE of yes/no and unit prompts and hand back the one it
## installed - naga_fixture.create_game_with_prompt_queues verbatim. Needed wherever a spec must
## assert that a "may" prompt was or was NOT raised: the stock responder answers and records nothing.
## add_responder = false is what stops TWO responders answering the same request.
static func create_game_with_prompt_queues(test:GutTest, map_size:Vector2i = DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Black Mountain with its traits' passive buffs applied. PLAYER faction by default (SpecFactory's),
## which every hostile relation here depends on and which makes CommonActionUtil.confirm_use actually
## ask (common_action_util.gd:304).
static func create_black_mountain(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	return wear(game, tile, FRAME_ID, faction)

## An Emperor from the resident mod, worn whole (see the header). PLAYER by default: an allied Emperor
## is the case the Vestment fix is about.
static func create_emperor(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	return wear(game, tile, EMPEROR_ID, faction)

static func wear(game:Gamemaster, tile:Vector2i, frame_id:StringName, faction:Faction.SIDE) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile, faction)
	unit.core.frame = ContentLibrary.get_mech_frame(frame_id)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	UnitTile.move_to(unit, tile)
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10,
		faction:Faction.SIDE = Faction.AI_ENEMY) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, evasion, faction)
	UnitTile.update_tracking_and_statuses(game.map)
	return unit

## An enemy-faction CHARACTER.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return create_dummy(game, tile, evasion)

## A friendly CHARACTER - the ally the cards shield and reward.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return create_dummy(game, tile, 10, Faction.PLAYER)

## A DRONE: a character that is NOT an actor (unit.gd:116-117). The negative control for every
## "character" clause. Flipped on an already-isolated frame, so only the one flag differs.
static func create_drone(game:Gamemaster, tile:Vector2i, faction:Faction.SIDE = Faction.PLAYER) -> Unit:
	var drone := create_dummy(game, tile, 10, faction)
	drone.core.frame.is_drone = true
	drone.core.full_repair()
	return drone

## Give a drone an OWNER, so Unit.get_attacker() resolves its shots to that owner
## (unit_battle_state.gd:255-261). An unowned drone is the control.
static func own_drone(drone:Unit, owner:Unit) -> Unit:
	drone.state.set_owner(owner)
	return drone

## A three-tile forbidden-interior wall: blocks sight at every layer (rakshasa_fixture.raise_wall).
## create_game sets forbidden_interiors_enabled first, which is what makes the interior a full-height
## blocker (landscape_node.gd:608).
static func raise_wall(game:Gamemaster, tiles:Array[Vector2i]) -> void:
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', tiles)
	game.map.calculate_los_blockers()

## Put a Kit on a unit as a SYSTEM, and hand back its GearCore. IDEMPOTENT, and the idempotence is
## load-bearing: equip_system full_repairs, which CLEARS every gear's state and usage and the unit's
## heat, so equip everything BEFORE a test spends anything.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	UnitTile.update_tracking_and_statuses(unit.map)
	return unit.get_gear(kit_id)

static func arm_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Cycle the unit's turn: end it if open, then start it. Clears the per-TURN soft limit so a second
## non-free action can be taken, and (event_turn_start.gd:79) resets THIS unit's per-round tallies -
## so a spec measuring an N/round must not cycle the Black Mountain's turn between its attempts.
static func cycle_turn(game:Gamemaster, unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## Load the dice FIFO with EXACTLY these numbers, then a long tail of 1s. CLEARS FIRST:
## Dice.cheat_attack only APPENDS (dice.gd:13-17). The tail is 1s so every unplanned die (a structure
## check, a recharge roll) is as harmless as it can be; a rifle damage die of 1 still lands 2 through
## RELIABLE, which is why an evidence die is queued explicitly.
static func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 60: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## Fire the rifle at a target, CYCLING the attacker's turn first (the per-turn soft limit swallows a
## second shot in one turn silently). POPS the d20, then - ONLY when a Lock On is consumed - one
## accuracy d6 for buff_lock_consumed's +1, then the damage d6. Queue the dice BEFORE calling this.
static func shoot(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await cycle_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target)

## A SECOND rifle shot from an attacker whose turn is ALREADY open, cycling nothing - AS_FREEBIE
## bypasses the per-turn soft limit (unit_action.gd:114). The only way to fire twice in one turn
## without handing every unit on the map its reaction point back.
static func shoot_again(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	await SpecFactory.use_solo(game, attacker, MAIN_RIFLE, target, [Action.FLAG.AS_FREEBIE])

## Fragment Signal, the basic invade: an ActionAttackTech. POPS ONE ENTRY - the d20 (a tech attack's
## flat '2' rolls nothing). Opens the turn if needed.
static func invade(game:Gamemaster, unit:Unit, target:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, INVADE, target)

## Lock On: a QUICK tech action, so the turn is opened first. Pops NOTHING off the dice queue. A
## PLAYER locker raises a confirm yes/no (action_system_apply_status.gd:49), answered by the responder.
static func lock_on(game:Gamemaster, unit:Unit, target:Unit) -> void:
	if not unit.state.is_taking_turn: await open_turn(game, unit)
	await SpecFactory.use(game, unit, LOCK_ON, LOCK_ON_ACTION, target)

## Lock a target BY HAND through the shared hook, with `locker`'s own ms_lock_on gear as the source -
## the status a real Lock On writes, none of the action's prompts.
static func lock_by_hand(locker:Unit, target:Unit) -> bool:
	return Lockon.apply(SpecFactory.dummy_event({unit = locker}), target, locker.get_gear(LOCK_ON))

## Clear a status the way Stabilize does: naga_fixture.clear_like_stabilize verbatim. Runs inside a
## REAL root event block so the POSTs it queues actually execute before this returns.
static func clear_like_stabilize(game:Gamemaster, unit:Unit, status:StringName) -> void:
	var core := EventCore.new()
	core.base = ClearViaAbilityEvent.new()
	core.base.event_type = &'event_reag_spec_clear_via_ability'
	core.context = Context.create({unit = unit, category = status})
	core.id = Util.generate_random_hexcode()
	await game.execute_event_block(EventBlock.create_multiple([core]))

class ClearViaAbilityEvent extends EventBase:
	func get_required_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.category]
	func execute(core:EventCore) -> void:
		UnitCondition.clear_status_via_ability(core, core.context.unit, core.context.category_str)

## Overshield through the shared helper, the way production does (a dummy event: the helper's level
## path, the one every spec takes).
static func grant_overshield(unit:Unit, amount:int) -> void:
	await Overshield.grant(SpecFactory.dummy_event({unit = unit}), unit, amount)

static func increase_overshield(unit:Unit, amount:int) -> void:
	await Overshield.increase(SpecFactory.dummy_event({unit = unit}), unit, amount)

## Overshield GRANTED BY the Black Mountain, through the helper's grant_by with the core Kit's gear as
## the granter - the gear SP2's Exalt and Fell the Mighty will pass. Until SP2 this is the only way
## a spec puts a "granted by" mark on an ally, which is why An End to All Things' specs use it.
static func grant_overshield_by(granter:Unit, target:Unit, amount:int) -> void:
	await Overshield.grant_by(SpecFactory.dummy_event({unit = granter}), target, amount, granter.get_gear(CORE_ID))

## Deal `amount` damage to `unit`, recorded as `dealer`'s (koremasa_fixture.damage). Kinetic.
static func damage(game:Gamemaster, unit:Unit, amount:int, dealer:Unit = null,
		type:Lancer.DAMAGE_TYPE = Lancer.DAMAGE_TYPE.KINETIC) -> void:
	var data := {unit = unit, number = amount, category = type}
	if Unit.is_valid(dealer): data.target_unit = dealer
	await game.execute_event(&'event_unit_damage', data)

# ---------------------------------------------------------------- SP2 additions (Blackstone Bell)

const EXALT_ACTION := &'action_exalt'
const EXALT_BENEFITED := &'buff_exalt_benefited'
const FELL_ACTION := &'action_fell_the_mighty'
const DOOMED := &'buff_doomed'
const EFFICIENT_REFUND := &'action_efficient_refund'

## GRIT IS THE PILOT'S: PilotCore.get_grit() is half the licence level, rounded up, and a fixture unit
## starts at level 0 = Grit 0 (hazard_fixture.set_grit, verbatim).
static func set_grit(unit:Unit, grit:int) -> void:
	if not Unit.is_valid(unit) or not PilotCore.is_valid(unit.core.pilot): return
	unit.core.pilot.license_level = grit * 2

## Put a unit at `health` HP without an event, so the next hit that exceeds it crosses zero - the
## "deals structure damage" Exalt reads. Structure is left alone unless given (1 = the next structure
## destroys it).
static func weaken(unit:Unit, health:int, structure:int = -1) -> void:
	unit.core.current.health = health
	if structure > 0: unit.core.current.structure = structure

## Give EVERY unit its reaction point back WITHOUT resetting anyone's per-round tallies: start the turn of
## a bystander (event_turn_start.gd:43-44 runs every_new_turn_refresh on all units, :79 new_turn_refresh
## only on the starter). How a spec gets a second Exalt out of one Black Mountain inside one round.
static func refresh_reactions(game:Gamemaster, bystander:Unit) -> void:
	if bystander.state.is_taking_turn: await SpecFactory.end_turn(game, bystander)
	await SpecFactory.start_turn(game, bystander)

## Fell the Mighty on `target`: the Protocol, so the Black Mountain's turn is opened first
## (unit_action.gd:144). A PLAYER Black Mountain aims through the responder's targeting answer.
static func fell(game:Gamemaster, black_mountain:Unit, target:Unit) -> void:
	if not black_mountain.state.is_taking_turn: await open_turn(game, black_mountain)
	await SpecFactory.use(game, black_mountain, CORE_ID, FELL_ACTION, target)

static func is_doomed(unit:Unit) -> bool: return not UnitCondition.get_buffs(unit, DOOMED).is_empty()
static func overshield(unit:Unit) -> int: return Overshield.current(unit)
static func has_core_power(unit:Unit) -> bool: return unit.core.has_core_power

# ---------------------------------------------------------------- reads

static func heat(unit:Unit) -> int: return unit.core.current.heat
static func health(unit:Unit) -> int: return unit.core.current.health
static func is_locked(unit:Unit) -> bool: return UnitCondition.has_status(unit, Lancer.STATUS.LOCKON)
static func marks(unit:Unit) -> int: return UnitCondition.get_buffs(unit, HARBINGER_MARK).size()

## The per-round tally of one action on one Kit, read the way the engine reads it.
static func uses_this_round(unit:Unit, kit_id:StringName, action_id:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round(gear.kit.get_action(action_id))
