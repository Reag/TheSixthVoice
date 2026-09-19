# The shared Primrose spec fixture (SP1 Task 1). EVERY SIGNATURE HERE IS FROZEN for Tasks 2-7.
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as vauban_fixture.gd,
# maidens_blush_fixture.gd, myconid_fixture.gd, subutai_fixture.gd and mk2_fixture.gd do: everything
# except create_<frame>() and this frame's own weapon and prompt helpers is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'cp_mobian_rainbow') stops finding anything. No Primrose spec writes to the frame's
# stats.
#
# THE GAMEMASTER IS THE SHARED ONE. The re-use branch of SpecFactory.setup_gamemaster builds a
# CampaignCore and hangs it on the map (spec_factory.gd:47-48), and the fresh branch returns before
# reaching those two lines; EventService.remove_unit_from_game dereferences map.campaign_core with no
# guard (event_service.gd:80), so on a fresh gamemaster the first death in a test throws before
# unit.remove_from_game(), leaving a corpse that still answers is_valid().
#
# NO SIZE RE-TRACKING. The Myconid's fixture ends create_myconid with UnitTile.move_to because that
# frame is size 2 and SpecFactory.create_unit adds every unit at size 1. The Primrose IS size 1, so
# the line would be a no-op that reads as load-bearing. Deliberately absent.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_primrose'
const LICENSE_ID := &'li_primrose'
const MWR_ID := &'mt_magnetic_weight_redistribution'
const CARESS_ID := &'mt_artful_caress'
const CORE_ID := &'cp_mobian_rainbow'
const PROTOCOL_ID := &'action_glimmering_armaments'

## Vanilla IPS-N Combat Drill: the ONE vanilla SUPERHEAVY MELEE weapon (weapon_size 3, weapon_type 2,
## 3d6 kinetic + 1d6 energy, AP, Overkill, threat 1 by the export default). Everything about Wormhole
## Grasp's waiver and Magnetic Weight Redistribution's Superheavy clause rides on it.
const SUPERHEAVY_MELEE := &'mw_combat_drill'
## Vanilla GMS Heavy Melee Weapon: HEAVY MELEE, 2d6+1, threat 1. The other half of both cards.
const HEAVY_MELEE := &'mw_heavy_melee_weapon'
## Vanilla GMS Tactical Melee Weapon: MAIN MELEE (weapon_size defaults to MAIN), 1d6+2, threat 1.
## The negative control for both size filters.
const MAIN_MELEE := &'mw_tactical_melee_weapon'
## Vanilla HA Torch: MAIN MELEE, 1d6 energy PLUS A FLAT 3 BURN, Overkill, self heat 2, threat 1.
## The flat 3 is what makes Wormhole Grasp's "half damage, Heat, and Burn" measurable: 3 halved is
## 2 (Util.half is ceili, util.gd:14-15) and no dice are involved. A MAIN weapon can Overwatch in
## vanilla, which is deliberate - the half-damage buff carries no size filter and this case proves it
## without the waiver in the way.
const BURN_MELEE := &'mw_torch'
## The plain vanilla rifle every Fitzgerald spec uses: MAIN, weapon_type unset so it is the archetype
## default RIFLE (3), 1d6, Reliable 2, aim_range 10, threat 1 by the export default. It carries NO
## accuracy modifier, so an attack with it pops a d20 and nothing else off Dice.CHEAT_ROLL_QUEUE.
const MAIN_RIFLE := &'mw_assault_rifle'
## Vanilla GMS Anti-Materiel Rifle: HEAVY, weapon_type unset so RIFLE. The control that proves Artful
## Caress filters on TYPE and not only on SIZE.
const HEAVY_RIFLE := &'mw_anti_materiel_rifle'
## Vanilla RPG: the mod's standing BLAST vehicle (memory lancer-tactics-spec-harness-traps), for the
## "a Blast that misses the Primrose and hits an ally counts once" case.
const BLAST_LAUNCHER := &'mw_rocket_propelled_grenade'
## A vanilla TECH attack, and it needs no equipping: ms_fragment_signal is in every player mech's
## basic loadout (content/gear/basic/basic_loadout_mech_player.tres) and its single action is an
## ActionAttackTech.
const TECH_ID := &'ms_fragment_signal'

## SP2 Task 1. The Primrose's own rank-I weapon.
const REND_AXE := &'mw_rend_axe'

## SP3 Task 1. The Primrose's own rank-II weapon, and the mod's first SUPERHEAVY.
const FALCATA := &'mw_acrasial_falcata'

## SP3 Task 4. The Primrose's own rank-II weapon mod.
const DDMR := &'wm_ddmr'

## SP2 Task 3. The Primrose's own rank-I system.
const DAZZLING_WIND := &'ms_dazzling_wind'

## The two markers GLIMMERING ARMAMENTS chooses between, and the prompt indices that pick them.
## buff_wormhole_grasp already exists as a bare file (SP1 Task 0, the probe); Task 5 fills it.
const WORMHOLE_GRASP := &'buff_wormhole_grasp'
const SHIMMERING_SHIELD := &'buff_shimmering_shield'
const WORMHOLE_INDEX := 0
const SHIELD_INDEX := 1
## choice_bus.choose_from_multiple_choice returns -1 when the player cancels (choice_bus.gd:138-141,
## `request.response_data.number`), and the responder sends whatever index it is handed.
const CANCEL_INDEX := -1

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose prompts are answered by testkit/mod_choice_responder.gd instead of the stock one, and
## the responder itself. Returns [Gamemaster, responder].
##
## NEEDED BY EVERY SPEC THAT PRESSES THE PROTOCOL. The stock SpecFactory.ChoiceBusResponder answers a
## multiple-choice prompt from a single `chosen_multiple_choice_index` and throws the prompt away; the
## testkit responder answers a SEQUENCE from `multiple_choice_queue` and RECORDS every prompt, which
## is what test_glimmering_armaments' "the prompt offers exactly the two effects" reads. It still
## inherits the stock choose_gear and choose_yesno, so Overwatch's own weapon pick is answered too.
##
## add_responder = false on setup_gamemaster (spec_factory.gd:16, :52) so the stock one is never
## created: two live responders would BOTH answer every request.
static func create_game_with_prompts(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Primrose with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own default
## gives us and which is load-bearing: CommonActionUtil.confirm_use returns true without asking when
## the unit is not player-controlled (common_action_util.gd:303, :329).
static func create_primrose(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. Defaults to evasion 10 ("only hit when we say").
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER. Speed 4, so a four-step standard move exactly spends it - which is what
## the Overwatch cases in test_wormhole_grasp.gd walk on.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	var hostile := create_dummy(game, tile, evasion)
	hostile.core.frame.stat.speed = 4
	hostile.core.full_repair()
	return hostile

## A friendly character, for the cases that need somebody who is not an enemy.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Put a Kit on a unit as a SYSTEM, and hand back its GearCore. IDEMPOTENT.
##
## THE IDEMPOTENCE IS LOAD-BEARING, not tidiness. UnitPrinter.equip_system calls full_repair
## (unit_printer.gd:180), which sets core.has_core_power = true (:76) and rebuilds the loadout, and
## SpecFactory.apply_passive_buffs calls full_repair again and re-applies every passive buff from
## scratch - which hands buff_effervescent_immunity a FRESH BuffCore with its `stacks` state back at
## zero. So a spec that equips a weapon after pressing the protocol would silently refund the core
## power, and one that equips after accumulating misses would silently reset the counter.
##
## THE RULE EVERY PRIMROSE SPEC FOLLOWS: equip everything first, press the protocol LAST, and never
## equip again inside a test that has already pressed or already counted.
static func equip(unit:Unit, kit_id:StringName) -> GearCore:
	var existing := unit.get_gear(kit_id)
	if GearCore.is_valid(existing): return existing
	var gear := unit.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(unit)
	return unit.get_gear(kit_id)

static func equip_superheavy_melee(unit:Unit) -> GearCore: return equip(unit, SUPERHEAVY_MELEE)
static func equip_heavy_melee(unit:Unit) -> GearCore: return equip(unit, HEAVY_MELEE)
static func equip_main_rifle(unit:Unit) -> GearCore: return equip(unit, MAIN_RIFLE)

## Fit the DDMR to a weapon the unit already carries, and re-apply the passive buffs the way spawning
## would. EQUIP EVERY WEAPON FIRST: equip_system calls full_repair(), which empties every equipped
## gear's state dictionary (test_ripper_mod.gd's equip_modded records the same trap).
static func fit_ddmr(unit:Unit, weapon:GearCore) -> GearCore:
	unit.core.loadout.equip_weapon_mod(DDMR, weapon)
	SpecFactory.apply_passive_buffs(unit)
	return unit.get_gear(DDMR)

## The SpecificAction for a Kit's solo action on a unit that already carries it. Returns a
## SpecificAction whose .gear is null if the unit does not carry it, which SpecificAction.is_valid
## reports - never an error.
static func specific(unit:Unit, kit_id:StringName) -> SpecificAction:
	return SpecificAction.from_id(unit, kit_id)

## The THROWN variant of a melee weapon's action: the engine's own construction, in two lines.
##
## action_attack_weapon.get_alternate_actions builds the Thrown sub-menu by duplicating the action and
## setting weapon.threat = 0 (action_attack_weapon.gd:349-372), and
## VariantActionGroup.get_variant_specifics is what applies that callable to a
## create_duplicate_for_variant() copy (:96-98). A throw is therefore THREAT == 0 and nothing else,
## which is what ruling 8 keys on and what ignores_cover() reads (action_attack_weapon.gd:206-212).
##
## Built here rather than through get_variant_specifics because the vanilla weapons these specs use
## carry no Thrown tag at all - no vanilla Heavy or Superheavy melee weapon does - so there would be
## no variant group to pick out of. The duplicate is per-call, so nothing leaks into the shared
## ContentLibrary Action the way a direct write to specific.action would.
static func thrown_variant(specific_action:SpecificAction) -> SpecificAction:
	var thrown:ActionAttackWeapon = specific_action.action.create_duplicate_for_variant()
	thrown.threat = 0
	thrown.modified_by_variants.append(&'thrown')
	return SpecificAction.create(specific_action.unit, specific_action.gear, thrown)

## Fire a weapon the unit already carries at a target, opening its turn first if it is not already in
## one. Does NOT clear the dice queue - the caller's cheat_* call is what decides the roll.
static func attack(game:Gamemaster, attacker:Unit, weapon_id:StringName, target:Unit) -> void:
	await open_turn(game, attacker)
	await SpecFactory.use_solo(game, attacker, weapon_id, target)

## A guaranteed HIT that is never a crit: base_roll 19 minus the worst-case -6 accuracy die is 13,
## always short of attack_roll.gd:73's total_roll >= 20 crit threshold, while a target evasion of 10
## or less still guarantees the hit half. The trailing sixes are a buffer against however many
## damage / self-damage / overkill dice a given shot pops.
##
## CLEARS THE QUEUE FIRST. Dice.cheat_attack only APPENDS (dice.gd:13-17), so a still-nonempty queue
## from an earlier shot's unused buffer would hand the next attack roll a leftover 6 instead of the
## fresh value - which silently turns an intended crit into a plain hit. test_knock_em_down.gd records
## a real run where exactly that happened.
static func cheat_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 40: buffer.append(6)
	Dice.cheat_attack([19], buffer)

## A guaranteed MISS: base_roll 1 cannot beat any evasion this fixture hands out. The buffer still
## matters, because a miss can still roll Reliable damage.
static func cheat_a_miss() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 40: buffer.append(6)
	Dice.cheat_attack([1], buffer)

## A guaranteed CRITICAL hit: base_roll 30 clears total_roll >= 20 even against a -6 accuracy die.
static func cheat_a_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 40: buffer.append(6)
	Dice.cheat_attack([30], buffer)

## Pin a unit's HASE so a forced save cannot pass, and re-repair so core.current picks it up.
##
## THROUGH HaseBlock, NOT THE DICE QUEUE, and deliberately: the attack ahead of the save pops an
## unpredictable number of accuracy and damage dice out of the same global FIFO, so queuing a specific
## d20 for the save would be guessing how many the attack ate first. A hase of +-30 dominates whatever
## the save's own d20 comes up as. test_knock_em_down.gd:27-31 records the same reasoning.
static func force_save_to_fail(unit:Unit) -> void:
	unit.core.frame.hase = HaseBlock.create(-30, 0, 0, 0)
	unit.core.full_repair()

static func force_save_to_pass(unit:Unit) -> void:
	unit.core.frame.hase = HaseBlock.create(30, 0, 0, 0)
	unit.core.full_repair()

## Press GLIMMERING ARMAMENTS and answer its prompt with `choice_index`.
##
## THE RESPONDER IS AN ARGUMENT because it has to be: it is created by create_game_with_prompts via
## test.add_child_autoqfree and is never assigned to SpecFactory.current_responder, so no helper could
## find it. MaidensBlushFixture.step has the same shape for the same reason.
##
## THE TURN IS NOT DECORATION: unit_action.gd:144 refuses a protocol unless
## unit.state.is_using_protocols, which only event_turn_start opens. Without it the press fails with
## "[ Gear not available ] reason : protocol" and every assertion downstream reads as broken content.
##
## SpecFactory.use(game, unit, kit_id, action_id) rather than use_solo(): use_solo fires the Kit's
## FIRST action, and this Kit's actions array is [action_glimmering_armaments] today but is not
## promised to stay a single entry.
##
## CALL THIS LAST - see equip()'s header.
static func press_protocol(game:Gamemaster, primrose:Unit, responder, choice_index:int) -> void:
	responder.multiple_choice_queue.append(choice_index)
	await open_turn(game, primrose)
	await SpecFactory.use(game, primrose, CORE_ID, PROTOCOL_ID)
