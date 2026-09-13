# SP1 Task 3: Broadside (cp_broadside) and the Bizarre Cannon's base profile.
#
# Design doc §2.5:
#   Heavy Cannon, AP, Inaccurate, Reliable 2, Heat 1 (Self). [Line 15] [2d6 kinetic].
#   On attack: you take 2 AP kinetic damage and are knocked back 2 spaces, away from the direction
#   of fire.
#
# "On attack" - so the recoil fires on a hit AND on a miss, which is why it hangs off activate()
# rather than an OnHitEffect. Both firing tests therefore assert the same two things about the
# FIRER, and differ only in whether the shot landed.
#
# WHY THE MAP IS 15x9 AND NOT THE DEFAULT. Landscape.create_default() is Tile.MIN_MAP_DIMENSION
# square - 5x5 - and a 2-space recoil needs two clear, in-bounds tiles behind the firer or the
# knockback is cut short and the test passes for the wrong reason (or fails for a reason that has
# nothing to do with the action). The firer stands at (7,4) with room in every direction.
#
# WHY THE TILE IS ASSERTED AND NOT JUST "IT MOVED". CommonActionUtil.generate_knockback_events
# (common_action_util.gd:108) computes its cone AWAY from origin_tiles, and DEFAULTS origin_tiles
# to the acting unit's OWN tiles when handed an empty array (:130) - so a wrong or missing origin
# does not error, it silently shoves the Fitzgerald in an arbitrary direction. Asserting the exact
# landing tile is what makes a reversed origin (it would land at (9,4)) or an empty one (it would
# land on whichever tile of the all-directions ring the picker reached first) fail. The second
# axis, test_the_recoil_follows_the_direction_of_fire, is what makes a HARDCODED vector fail.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_fitzgerald'
const KIT_ID := &'cp_broadside'
const ACTION_ID := &'action_bizarre_cannon'

## Read THIS MOD'S OWN compiled artifact, not the global tr(): same reasoning as
## test_fitzgerald_frame.gd:22 and test_content_integrity.gd:107.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SELF_DAMAGE := 2
const RELIABLE_ON_MISS := 2

const FIRE_FROM := Vector2i(7, 4)
const AIM_EAST := Vector2i(11, 4)
const RECOIL_WEST := Vector2i(5, 4) # two tiles back down the barrel
const AIM_NORTH := Vector2i(7, 1)
const RECOIL_SOUTH := Vector2i(7, 6)

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self, true,
		SpecFactory.create_combat(Landscape.create_default(Vector2i(15, 9))))

	unit = SpecFactory.create_unit(game.map, FIRE_FROM)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	# NOT FrameIsolation'd on purpose: this spec never writes to the Fitzgerald's stats, and a deep
	# duplicate of the frame would hand the unit COPIES of its trait Kits, whose compcon_id is a
	# lazily-derived bare var (kit.gd:11-16) that does not survive duplicate() - at which point
	# unit.get_gear(&'cp_broadside') stops finding anything.
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs

	target = SpecFactory.create_unit(game.map, AIM_EAST, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(target) # we DO rewrite this one's stats
	target.core.frame.stat.health = 200 # never dies; a death mid-spec would end the scene
	target.core.frame.stat.armor = 0 # so the damage numbers below are the weapon's, not armor's
	target.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func _kit() -> Kit:
	var kit = ContentLibrary.get_kit(KIT_ID)
	return kit if kit is Kit else null

func _gear() -> GearCore:
	var gear := unit.get_gear(KIT_ID)
	return gear if GearCore.is_valid(gear) else null

func _profile() -> ActionAttackWeapon:
	var gear := _gear()
	if gear == null: return null
	var action := gear.get_action(ACTION_ID)
	return action if action is ActionAttackWeapon else null

## Open the turn, then fire the kit's solo action at a tile.
##
## The turn start is not decoration. unit_action.gd:119 refuses a PROTOCOL unless
## unit.state.is_using_protocols, which only event_turn_start opens - and Task 4 hangs More Black
## Powder off a protocol on this same Kit. The base profile is a QUICK action and would activate
## without it; establishing the helper here means Task 4 does not have to discover that gate the
## hard way, and means both tasks' tests fire from the same state.
func fire_at(tile:Vector2i) -> void:
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.use_solo(game, unit, KIT_ID, tile)

## Enough sixes that the roll queue can never drain into real randomness, whatever the exact number
## of accuracy/difficulty dice the attack pops. The hit is guaranteed by the target's evasion, not
## by the dice, so the count does not have to be predicted.
func cheat_a_hit() -> void:
	target.core.frame.stat.evasion = -10
	target.core.full_repair()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6])

## Same trick the other way: evasion 30 cannot be beaten by 20 plus any accuracy die, so the shot
## misses no matter how the dice fall.
func cheat_a_miss() -> void:
	target.core.frame.stat.evasion = 30
	target.core.full_repair()
	Dice.cheat_attack([1], [1, 1, 1, 1, 1, 1])

# ---------------------------------------------------------------- the Kit

func test_the_core_kit_is_registered_as_a_trait() -> void:
	var kit := _kit()
	assert_not_null(kit, '%s loads as a valid Kit through ContentLibrary.' % KIT_ID)
	if kit == null: return
	assert_true(kit.is_trait, '%s is a trait Kit (no mount, no weapon mod, no Main slot).' % KIT_ID)

	var frame:Frame = ContentLibrary.get_mech_frame(FRAME_ID)
	assert_not_null(frame, 'fixture: the frame loads.')
	if frame == null: return
	assert_true(
		frame.traits.any(func(carried:Kit) -> bool: return carried.compcon_id == KIT_ID),
		'The frame carries %s in its traits.' % KIT_ID
	)
	# And it survives the trip through the loadout: regenerate_derived_gear builds a GearCore per
	# frame trait (loadout_core.gd:153-154), which is what makes the weapon actually fireable.
	assert_not_null(_gear(), 'A live Fitzgerald carries %s as gear.' % KIT_ID)

# ---------------------------------------------------------------- the base profile's statistics

func test_the_base_profile_is_a_heavy_cannon_firing_a_line_15() -> void:
	var action := _profile()
	assert_not_null(action, '%s carries %s as an ActionAttackWeapon.' % [KIT_ID, ACTION_ID])
	if action == null: return

	assert_eq(action.get_id(), ACTION_ID, 'The action ids itself off its own filename.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'weapon_type is CANNON.')
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'weapon_size is HEAVY.')
	assert_eq(action.damage_dice, '2d6', 'damage_dice is 2d6.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'damage_type is KINETIC.')

	assert_not_null(action.range_pattern, 'The profile has a range pattern.')
	if action.range_pattern == null: return
	assert_eq(action.range_pattern.pattern, Lancer.AOE_TYPE.LINE, 'The pattern is a LINE.')
	assert_eq(action.range_pattern.value, 15, 'The line is 15 long.')

func test_the_base_profile_carries_its_tags() -> void:
	var action := _profile()
	var gear := _gear()
	assert_not_null(action, 'fixture: the profile loads.')
	assert_not_null(gear, 'fixture: the gear exists.')
	if action == null or gear == null: return

	# Asked through a SpecificAction rather than the raw `tags` array: has_tag reads
	# get_weapon_tags, which is also where weapon mods and WEAPON_TAG buffs would add or remove
	# one, so this is the value the attack pipeline will actually see.
	var specific := SpecificAction.create(unit, gear, action)
	assert_true(action.has_tag(Lancer.WEAPON_TAG.AP, specific), 'AP.')
	assert_true(action.has_tag(Lancer.WEAPON_TAG.INACCURATE, specific), 'Inaccurate.')
	assert_true(action.has_tag(Lancer.WEAPON_TAG.RELIABLE, specific), 'Reliable.')
	assert_eq(action.reliable_damage, '2', 'Reliable 2.')
	assert_eq(action.self_heat_dice, '1', 'Heat 1 (self).')

func test_the_kit_and_its_profile_have_display_text() -> void:
	# A named action on a multi-action kit is keyed gear.<kit>.<action>.* - the Apocalypse Rail's
	# gear.cp_apocalypse_rail.action_charge_rail.name is the vanilla precedent - and a missing row
	# does not fail anything, it just renders the raw key in the gear bar.
	#
	# Asserted against the compiled ARTIFACT rather than the csv, because Translate loads
	# localizations.en.translation and never reads the csv beside it: an edited csv that was never
	# re-scanned leaves a correct-looking source file next to an artifact that has never heard of
	# these keys. (filesystem_manage(op="reimport") does NOT regenerate it; only op="scan" and the
	# headless --import do.)
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in [
		'gear.%s.name' % KIT_ID,
		'gear.%s.effect' % KIT_ID,
		'gear.%s.%s.name' % [KIT_ID, ACTION_ID],
		'gear.%s.%s.effect' % [KIT_ID, ACTION_ID],
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

# ---------------------------------------------------------------- the recoil

func test_firing_costs_two_ap_kinetic_self_damage_on_a_hit() -> void:
	cheat_a_hit()
	await fire_at(AIM_EAST)

	assert_gt(target.current_damage(), RELIABLE_ON_MISS,
		'The shot landed: more damage than Reliable 2 alone could have dealt.')
	# The Fitzgerald has armor 1 (mf_fitzgerald.tres), so a plain 2 kinetic would land as 1. Exactly
	# 2 is the evidence that the DAMAGE_FLAG.AP went along with it.
	assert_eq(unit.current_damage(), SELF_DAMAGE,
		'The Fitzgerald took 2 AP kinetic from its own cannon, through its own armor.')
	assert_eq(unit.tile(), RECOIL_WEST,
		'The Fitzgerald was shoved two tiles back down the barrel, away from the line it fired.')

func test_firing_costs_two_ap_kinetic_self_damage_and_knocks_back_on_a_MISS() -> void:
	cheat_a_miss()
	await fire_at(AIM_EAST)

	assert_eq(target.current_damage(), RELIABLE_ON_MISS,
		'The shot missed: the target took only the Reliable 2.')
	assert_eq(unit.current_damage(), SELF_DAMAGE,
		'The recoil does not care whether the shot landed.')
	assert_eq(unit.tile(), RECOIL_WEST, 'Nor does the knockback.')

func test_the_recoil_follows_the_direction_of_fire() -> void:
	# The same shot along the other axis. Without this, a recoil that always shoved due west - a
	# hardcoded vector rather than a cone measured away from the aimed tile - would pass every
	# other test in this file.
	cheat_a_hit()
	var north:Unit = SpecFactory.create_unit(game.map, AIM_NORTH, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(north)
	north.core.frame.stat.health = 200
	north.core.frame.stat.evasion = -10
	north.core.full_repair()

	await fire_at(AIM_NORTH)

	assert_gt(north.current_damage(), RELIABLE_ON_MISS, 'The northward shot landed.')
	assert_eq(unit.tile(), RECOIL_SOUTH,
		'Firing north shoved the Fitzgerald south, not west: the cone follows the aimed tile.')
	assert_eq(target.current_damage(), 0,
		'Fixture held: the eastward target was never in the line of fire.')
