# The shared Maiden's Blush spec fixture (SP1 Task 2).
#
# DELEGATES TO fitzgerald_fixture.gd rather than copying it, exactly as mk2_fixture.gd,
# subutai_fixture.gd and myconid_fixture.gd do: everything except create_<frame>() and this frame's
# own weapons is frame-agnostic.
#
# NOT FrameIsolation'd, for the reason fitzgerald_fixture.create_fitzgerald() records: a deep
# duplicate of the frame hands the unit COPIES of its trait Kits, whose compcon_id is a lazily
# derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
# unit.get_gear(&'mt_rend') stops finding anything. No Maiden's Blush spec writes to the frame's
# stats; the one test that needs armor on a frame with armor 0 writes core.current.armor directly and
# says so at its call site.
#
# THE GAMEMASTER IS THE SHARED ONE, which matters beyond the 2.65x it bought: the re-use branch of
# SpecFactory.setup_gamemaster builds a CampaignCore and hangs it on the map (spec_factory.gd:48-49),
# and the fresh branch returns before reaching those two lines.
# EventService.remove_unit_from_game dereferences map.campaign_core with no guard
# (event_service.gd:80), so on a fresh gamemaster the first death in a test throws before
# unit.remove_from_game(), leaving a corpse that still answers is_valid().
#
# NO SIZE RE-TRACKING. The Myconid's fixture ends create_myconid with UnitTile.move_to because that
# frame is size 2 and SpecFactory.create_unit adds every unit at size 1. The Maiden's Blush IS size 1,
# so the line would be a no-op that reads as load-bearing. Deliberately absent.
#
# Static functions, no state, NOT extends GutTest, NOT test_-prefixed, so GUT's directory scan never
# collects this as a test script.
extends RefCounted

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const FRAME_ID := &'mf_maidens_blush'
const REND_ID := &'mt_rend'
const UNCERTAINTY_FIELD_ID := &'mt_uncertainty_field'
const FADE_STRIKE_ID := &'mt_fade_strike'

## The core system (SP2). Not an mt_ trait but it sits in the frame's `traits` array beside them,
## which is what a cp_ Kit does - the prefix is what files it in the CORE SYSTEM box.
const CORE_ID := &'cp_caj_overhaul_modules'

## The licence's own Main melee weapon (li_mourning_cloak rank 3). weapon_type = 2 (MELEE), threat 2,
## attack_accuracy "1".
##
## IT POPS EXACTLY TWO VALUES off Dice.CHEAT_ROLL_QUEUE per attack, and BOTH halves of that are
## load-bearing: the d20, then ONE accuracy d6 (net +1, so roll_d6_accuracy rolls a single die,
## dice.gd:86-88), and then NOTHING for damage, because damage_dice is the flat string "3" - count 0,
## so roll_dice's loop body never runs (dice.gd:24). That is why the SWORD helpers queue a PAIR. The
## other helpers do not, and must not: mw_assault_rifle and mw_improvised_attack both roll 1d6, and
## the damage dice are rolled TWICE per attack (attack_util.gd:250-251), so they pop three - four for
## the rifle when the shooter is ENGAGED. A future modkit giving the sword dice damage would silently
## break every pair in this mod.
const MELEE_ID := &'mw_variable_sword'

## The plain vanilla rifle every Fitzgerald spec uses. NOT melee - its weapon_type is unset, so it is
## the archetype default, RIFLE (3, action_attack_weapon.gd:12) - which is the whole reason it is
## here: it is the clean negative control for Rend's and Fade Strike's MELEE filters.
##
## IT POPS THREE VALUES OFF Dice.CHEAT_ROLL_QUEUE PER ATTACK, AND FOUR WHEN ENGAGED - never one. It
## sets no attack_accuracy, but damage_dice is "1d6" and AttackUtil.DamageRoll.roll_base_damage rolls
## the damage dice TWICE on every attack, hit_rolls then crit_rolls (attack_util.gd:250-251), on a
## miss as much as on a crit. The FOURTH lands between the d20 and those two when the shooter carries
## ENGAGED or GRAPPLED: the rifle is not MELEE, so is_difficulty_when_engaged() is true
## (action_attack_weapon.gd:254-255), the engaged -1 becomes an accuracy mod (attack_roll.gd:173-174),
## and roll_d6_accuracy rolls one d6 for it and SUBTRACTS it (dice.gd:86-88, the signi at :65).
## Queue a BUFFER of 6s after whatever you are pinning; do not count the draws.
const RANGED_ID := &'mw_assault_rifle'

## The basic Improvised Attack: weapon_type = 2 (MELEE), weapon_size = 4 (NONE), and in every unit's
## BASIC loadout - so loadout.is_gear_basic() is true of it. Ruling 12 says neither Rend nor Fade
## Strike sees it, and the archetypes deliver that for free (BuffWeaponType.allow_basic and
## BuffModifyAttackRoll.allow_basic both default false). It needs no equipping; every unit has it.
const BASIC_MELEE_ID := &'mw_improvised_attack'

## mw_assault_rifle is Reliable 2, so a MISS with it still deals exactly 2 damage. Every "the shot
## landed" assertion in the trait specs therefore compares against this rather than against 0, and
## miss_from's own self-check asserts equality with it.
const RELIABLE_ON_MISS := 2

## A d20 low enough to miss evasion 10 however the accuracy die falls.
const MISS_ROLL := 1

static func create_game(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Gamemaster:
	return FitzgeraldFixture.create_game(test, map_size)

## A game whose responder can answer a SEQUENCE of yes/no prompts, and hand back the one it installed.
##
## WHY THE STOCK RESPONDER IS NOT ENOUGH FOR THIS FRAME. SpecFactory.ChoiceBusResponder answers every
## yes/no with the same `chosen_yesnos` (spec_factory.gd:507-517), and pressing Step of Mist and
## Thunder opens TWO in one awaited call: Step's own confirm, and then Uncertainty Field's offer to
## fade instead. With one answer for both, `true` makes the field eat every teleport - measured, and it
## made ten of this file's tests fail at once with the Blush sitting still - while `false` never gets
## past the confirm. testkit/mod_choice_responder.gd exists for exactly this and adds `yesno_queue`.
##
## add_responder = false is what stops TWO responders answering the same request; the Thy Hubris
## DomainWatcher spec (test_my_domain_trigger.gd:96-100) is the precedent for the whole shape.
static func create_game_with_sequenced_prompts(test:GutTest, map_size:Vector2i = FitzgeraldFixture.DEFAULT_MAP_SIZE) -> Array:
	var game := SpecFactory.setup_gamemaster(test, false,
		SpecFactory.create_combat(Landscape.create_default(map_size)), {}, false)
	game.map.shape.forbidden_interiors_enabled = true
	var responder = test.add_child_autoqfree(load('res://testkit/mod_choice_responder.gd').new())
	return [game, responder]

## A Maiden's Blush with its traits' passive buffs applied. PLAYER faction, which SpecFactory's own
## default gives us and which is load-bearing: CommonActionUtil.confirm_use returns true without
## asking when the unit is not player-controlled (common_action_util.gd:303, :329), so a
## non-player Blush would silently auto-accept every Uncertainty Field offer.
static func create_maidens_blush(game:Gamemaster, tile:Vector2i) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs
	return unit

## A FrameIsolation'd punching bag: 200 HP so it never dies mid-spec, armor 0 so damage numbers are
## the weapon's, and a caller-chosen evasion. Defaults to evasion 10 ("only hit when we say"), the
## value test_hole_puncher.gd chose for the same reason.
static func create_dummy(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.AI_ENEMY)

## An enemy-faction CHARACTER that can attack: the same punching bag with a rifle on it, so it can be
## the attacker in miss_from and the forcer in Uncertainty Field's hostile-teleport case.
static func create_hostile(game:Gamemaster, tile:Vector2i, evasion:int = 10) -> Unit:
	var hostile := create_dummy(game, tile, evasion)
	equip_ranged(hostile)
	return hostile

## A friendly character, for the cases that need somebody who is not an enemy.
static func create_ally(game:Gamemaster, tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

static func open_turn(game:Gamemaster, unit:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)

## Put a weapon on a unit as a SYSTEM, which is what keeps it out of loadout.basic - both
## BuffWeaponType and BuffModifyAttackRoll refuse basic gear by default (ruling 12), so a weapon
## equipped any other way would be invisible to Rend and to Fade Strike. Idempotent, so a spec may
## call it in before_each and again in a test.
static func equip_melee(unit:Unit) -> void:
	if GearCore.is_valid(unit.get_gear(MELEE_ID)): return
	unit.core.equip_system(MELEE_ID)
	SpecFactory.apply_passive_buffs(unit)

static func equip_ranged(unit:Unit) -> void:
	if GearCore.is_valid(unit.get_gear(RANGED_ID)): return
	unit.core.equip_system(RANGED_ID)
	SpecFactory.apply_passive_buffs(unit)

## The Improvised Attack needs no equipping - it is in the basic loadout of every unit
## (content/gear/basic/basic_loadout_mech_player.tres). This exists so a spec can SAY that, and fail
## loudly if a future engine stops handing it out, rather than discovering it as a null gear.
static func equip_basic_melee(unit:Unit) -> void:
	assert(GearCore.is_valid(unit.get_gear(BASIC_MELEE_ID)),
		'Every unit carries mw_improvised_attack in its basic loadout.')

## Fire a real attack that MISSES, from attacker at target. The attacker gets the rifle if it has none.
##
## Written here rather than in a spec because SP2's Abjuration of Metal triggers on exactly this - "a
## hostile character within sensors misses you with an attack" - and its whole spec is built on it.
## SP1's only caller is the frame spec's fixture self-check, which is deliberate: an unexercised
## fixture helper handed to SP2 is a helper SP2 debugs instead of using.
##
## CLEARS THE QUEUE FIRST, then queues two 1s - the d20, and one spare for whichever draw comes next
## (the engaged difficulty die if the attacker is engaged, otherwise the first damage roll). The rifle
## pops three or four values per attack (see RANGED_ID above), so NOTHING is left behind for the next
## roll and the trailing damage dice roll live, which is harmless: Reliable 2 fixes a miss's damage
## whatever they come up as. What matters is only that the d20 is 1.
## Hang the Minotaur's Interdiction Field on a hostile WITHOUT equipping the system or waking its
## aura. buff_interdiction_field.tres is `to = &"movement_restriction"` and its
## check_if_passive_applies asks only for a teleporting movement type and an enemy holder
## (buff_interdiction_field.gd:15-21), so none of the aura machinery is load-bearing for the BAN.
##
## THE HOLDER MUST BE WITHIN 3 OF THE MECH, and that is not a detail. get_values has TWO branches
## (:29-33): held further away it allows every tile EXCEPT its own 3-tile radius - a doughnut, which
## bans nothing a mech outside it wants - and held within 3 it allows the blank array, which is a
## total lockdown. Only the second is a usable positive control, and the first cost a red before it
## was understood (SP2 probe, 2026-09-17).
static func equip_interdiction(hostile:Unit) -> void:
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), hostile, &'buff_interdiction_field')

## Press Step of Mist and Thunder with the 2d6 fixed, answering the confirm and the tile pick.
##
## `tile` defaults to Tile.INVALID, meaning "take the first tile the picker offers" - which is what
## SpecFactory's responder does on its own with can_target_empty_tiles and no unit targets
## (spec_factory.gd:481-482), and is what the many tests that do not care where it lands rely on.
##
## CLEARS THE QUEUE FIRST and queues exactly the two values the roll needs. The queue is one global
## FIFO shared by every roll in the run: a leftover would hand Step the wrong range, and a leftover
## from Step would hand the next roll a 1. On a SNAKE EYES call the action draws a third value for the
## random destination (ruling 9), so pass it in `rolls` as a third entry when that is what the test is
## about.
## NO FADE ANSWER, SINCE reach design ruling C (2026-09-17). Step used to open TWO yes/no prompts in
## one awaited call - its own confirm, then Uncertainty Field's offer to fade instead - and this
## helper queued an answer for both. The field is now permanently exempt from Step, so only the
## confirm is ever asked, and a second queued answer would sit in the responder's queue waiting to
## answer the NEXT prompt: a test that presses Step twice would have its second confirm declined by a
## leftover and pass for the wrong reason.
##
## Takes the responder rather than reading SpecFactory.current_responder: this needs the queued one
## from create_game_with_sequenced_prompts, and silently doing nothing on the stock responder (which
## has no yesno_queue) would be a whole spec file passing for the wrong reason.
static func step(game:Gamemaster, blush:Unit, responder, rolls:Array[int],
		tile:Vector2i = Tile.INVALID) -> void:
	responder.yesno_queue.append(true)
	if tile != Tile.INVALID:
		responder.chosen_plan_queue.append(CompconPlan.create([tile], [], []))
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array(rolls)
	await SpecFactory.use(game, blush, CORE_ID, &'action_step_of_mist_and_thunder')

static func miss_from(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	equip_ranged(attacker)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([MISS_ROLL, MISS_ROLL], [])
	await SpecFactory.use_solo(game, attacker, RANGED_ID, [target])
