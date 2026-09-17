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

## The licence's own Main melee weapon (li_mourning_cloak rank 3). weapon_type = 2 (MELEE), threat 2,
## attack_accuracy "1" - so every attack with it pops a d20 AND an accuracy die off
## Dice.CHEAT_ROLL_QUEUE, which is why every cheat helper in the trait specs queues a PAIR.
const MELEE_ID := &'mw_variable_sword'

## The plain vanilla rifle every Fitzgerald spec uses. NOT melee - its weapon_type is unset, i.e. CQB
## (0) - which is the whole reason it is here: it is the clean negative control for Rend's and Fade
## Strike's MELEE filters. It carries NO accuracy modifier, so an attack with it pops a d20 and
## nothing else.
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
## CLEARS THE QUEUE FIRST and queues exactly two values, no buffer. A leftover cheat from an earlier
## attack would hand this one the wrong d20, and a leftover from THIS one would hand the next roll a 1
## - which matters most in SP2, where Abjuration's own d6 and its follow-up Skirmish pop from the same
## global FIFO during this very activation.
static func miss_from(game:Gamemaster, attacker:Unit, target:Unit) -> void:
	equip_ranged(attacker)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([MISS_ROLL, MISS_ROLL], [])
	await SpecFactory.use_solo(game, attacker, RANGED_ID, [target])
