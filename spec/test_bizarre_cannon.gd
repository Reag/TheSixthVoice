# SP1 Tasks 3 and 4: Broadside (cp_broadside), the Bizarre Cannon's base profile, and the MORE BLACK
# POWDER protocol that ADDS its second profile for the rest of the scene.
#
# Design doc §2.5:
#   Heavy Cannon, AP, Inaccurate, Reliable 2, Heat 1 (Self). [Line 15] [2d6 kinetic].
#   On attack: you take 2 AP kinetic damage and are knocked back 2 spaces, away from the direction
#   of fire.
#
# "On attack" - so the recoil fires on a hit AND on a miss, which is why it hangs off activate()
# rather than an OnHitEffect. The firing tests in this file (both profiles, both directions, and
# MORE BLACK POWDER's prone save) each assert whatever subset of the recoil, self-damage, target
# damage and target-status facts is relevant to what that test is pinning - not all the same two
# things any more, now that the file covers more than the base profile.
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

# SP1 Task 4: MORE BLACK POWDER. A PROTOCOL that applies a scene-long marker, and a SECOND weapon
# profile on the same Kit that only exists while the marker is held. Ruling 8: the protocol ADDS the
# profile - both stay firable afterwards, chosen per shot - so nothing here may assert the base
# profile went away.
const MBP_ACTION_ID := &'action_more_black_powder'
const MBP_PROTOCOL_ID := &'action_more_black_powder_protocol'
const MARKER_ID := &'buff_more_black_powder'

## Read THIS MOD'S OWN compiled artifact, not the global tr(): same reasoning as
## test_fitzgerald_frame.gd:22 and test_content_integrity.gd:107.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SELF_DAMAGE := 2
const RELIABLE_ON_MISS := 2

const MBP_SELF_DAMAGE := 3
const MBP_RELIABLE_ON_MISS := 3

const FIRE_FROM := Vector2i(7, 4)
const AIM_EAST := Vector2i(11, 4)
const RECOIL_WEST := Vector2i(5, 4) # two tiles back down the barrel
const AIM_NORTH := Vector2i(7, 1)
const RECOIL_SOUTH := Vector2i(7, 6)

## Where the all-directions recoil lands, and why it is asserted as an exact tile.
##
## event_unit_pick_move.gd:87-93 filters the knockback origin tiles the moving unit is standing on,
## and when nothing is left it opens the pick to EVERY tile within the knockback distance - the
## "in any direction" shape - instead of a cone angled away from an origin. That ring is built by
## Tile.get_all_within (tile.gd:335-345), which walks x ascending then y ascending, so its FIRST
## playable entry is the ring's north-west corner: (7,4) - (3,3) = (4,1).
##
## The stock responder answers a move_tile prompt with request.params.tiles[0] when no
## chosen_move_tile is set (spec_factory.gd:417-431), so that corner is what gets picked, and it is
## picked deterministically.
##
## DELIBERATELY NOT SpecFactory.current_responder.chosen_move_tile. Setting that would also be
## deterministic, and it would test nothing: ask_for_movement_alt accepts whatever tile comes back
## and only checks Tile.distance <= max_budget against it
## (pathfinder.gd:711-717, target_action_util.gd:92-105) - it never checks the answer against the
## offered cone. A spec that names its own landing tile therefore lands there whatever cone the
## implementation opened, including the base profile's away-from-fire one. Reading tiles[0] back is
## the only way the OFFER is under test rather than the answer.
const RECOIL_ANY := Vector2i(4, 1)

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
	return _weapon(ACTION_ID)

## Any action on the Kit, by id. Named explicitly rather than through gear.get_solo_action(): the Kit
## carries THREE actions from Task 4 on, and "solo" would silently mean "whichever is first in the
## array" (gear_core.gd:337-339).
func _action(action_id:StringName) -> Action:
	var gear := _gear()
	if gear == null: return null
	var action := gear.get_action(action_id)
	return action if Action.is_valid(action) else null

func _weapon(action_id:StringName) -> ActionAttackWeapon:
	var action := _action(action_id)
	return action if action is ActionAttackWeapon else null

func _specific(action_id:StringName) -> SpecificAction:
	return SpecificAction.create(unit, _gear(), _action(action_id))

## Does gear_bar.gd's hide_if_disabled clause hide this action's button?
##
## This mirrors ONLY that one clause of gear_bar.gd:147 - not the surrounding
## is_action_hibernating_alt / is_situationally_activated / ActionReaction conditions - so it can
## only speak to the HIDDEN-versus-GREYED distinction this file cares about: `hide_if_disabled and
## not can_activate_gear` drops an action from the bar entirely; an unavailable action WITHOUT
## hide_if_disabled still gets a button, just a dead one. "The second profile does not exist until
## the protocol is used" is a claim about the first case, so asserting availability alone would not
## prove it. Do not lean on this helper for a claim about the whole gear-bar decision - it isn't one.
func _gear_bar_hides_when_disabled(action_id:StringName) -> bool:
	var action := _action(action_id)
	if action == null: return false
	return action.hide_if_disabled and not UnitAction.can_activate_gear(_specific(action_id))

## Open the unit's turn, once.
##
## The turn start is not decoration. unit_action.gd:119 refuses a PROTOCOL unless
## unit.state.is_using_protocols, which only event_turn_start opens - and More Black Powder is a
## protocol on this same Kit. The weapon profiles are QUICK actions and would activate without it;
## going through one helper means every test fires from the same state, and means a test that uses
## the protocol and then fires does not re-open a turn it is already in.
func open_turn() -> void:
	if not unit.state.is_taking_turn: await SpecFactory.start_turn(game, unit)

func fire_at(tile:Vector2i) -> void:
	await open_turn()
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, tile)

func fire_more_black_powder_at(tile:Vector2i) -> void:
	await open_turn()
	await SpecFactory.use(game, unit, KIT_ID, MBP_ACTION_ID, tile)

func use_protocol() -> void:
	await open_turn()
	await SpecFactory.use(game, unit, KIT_ID, MBP_PROTOCOL_ID)

## Enough sixes that the roll queue can never drain into real randomness, whatever the exact number
## of accuracy/difficulty dice the attack pops. The hit is guaranteed by the target's evasion, not
## by the dice, so the count does not have to be predicted.
##
## THE CLEAR IS NOT DECORATION. Dice.cheat_attack APPENDS to Dice.CHEAT_ROLL_QUEUE, so a value left
## over from an earlier call is popped BEFORE anything queued here and silently decides the roll -
## Task 6 lost time to exactly that, an intended crit resolving as a plain hit. Every test in this
## file calls its helper once and after_each clears, so nothing here is wrong today; the clear is so
## the next test added to this file cannot be the one that finds out. Task 6's cheat_a_crit /
## cheat_a_hit_no_crit and Task 7's cheat_every_die_to_six all open the same way.
func cheat_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	target.core.frame.stat.evasion = -10
	target.core.full_repair()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6])

## Same trick the other way: evasion 30 cannot be beaten by 20 plus any accuracy die, so the shot
## misses no matter how the dice fall. Clears first for the reason above.
func cheat_a_miss() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
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
	# Design doc §2.5 gives the Bizarre Cannon SP 0. Nothing else pins this - it is currently
	# satisfied only by Kit.sp_cost defaulting to 0 (kit.gd:29) - so an inspector save that ever
	# writes a non-zero sp_cost into cp_broadside.tres would go unnoticed without this assertion.
	assert_eq(kit.sp_cost, 0, '%s costs SP 0.' % KIT_ID)

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
	var keys:Array[String] = ['gear.%s.name' % KIT_ID, 'gear.%s.effect' % KIT_ID]
	# Every action on the Kit, not a hardcoded list, so a fourth profile cannot ship without its rows.
	for action_id:StringName in [ACTION_ID, MBP_PROTOCOL_ID, MBP_ACTION_ID]:
		keys.append('gear.%s.%s.name' % [KIT_ID, action_id])
		keys.append('gear.%s.%s.effect' % [KIT_ID, action_id])
	# The marker is a VISIBLE buff, so it gets its own tooltip rows. Without them Translate.buff falls
	# all the way back to the owner gear's own name/effect (translate.gd:65-78), and the marker would
	# render in the status bar wearing the Kit's text - which looks deliberate and is not.
	keys.append('gear.%s.name' % MARKER_ID)
	keys.append('gear.%s.effect' % MARKER_ID)
	for key:String in keys:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

	# The regression this pins: gear.<kit>.effect is the KIT-LEVEL rule (no weapon mount, no weapon
	# mod) plus a one-clause pointer at the protocol, while gear.<kit>.<protocol>.effect is the
	# protocol BUTTON's own full rules text. A prior revision overwrote the former with a copy of the
	# latter, which left the no-mount rule rendered nowhere in the game while the protocol's text
	# appeared twice. Non-empty alone does not catch that, and neither does mere distinctness - the
	# historical bad text was a paraphrase of the protocol's text, not a byte-identical copy, so an
	# assert_ne on the two full strings would have passed against the actual bug. Assert on what each
	# row must actually SAY instead: the kit row still states its own no-mount rule, and it does not
	# carry the protocol's distinctive stat block.
	var kit_effect:String = translation.get_message('gear.%s.effect' % KIT_ID)
	assert_true(kit_effect.contains('weapon mount'),
		'The Kit-level rule text still states the no-weapon-mount rule.')
	assert_true(kit_effect.contains('weapon mod'),
		'The Kit-level rule text still states the no-weapon-mod rule.')
	assert_false(kit_effect.contains('Heavy Cannon, AP, Reliable'),
		'The Kit-level rule text must not carry a copy of the protocol button\'s own stat block.')

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

# ---------------------------------------------------------------- MORE BLACK POWDER
#
# Design §2.5, rulings 8 and 11:
#   Active, MORE BLACK POWDER (Protocol): for the rest of this scene, the BIZARRE CANNON gains the
#   following profile - Heavy Cannon, AP, Reliable 3, Heat 1 (Self). [Line 15]
#   [2d6 kinetic + 1d6 explosive]. On attack: you take 3 AP kinetic damage and are knocked back
#   3 spaces, in any direction. On hit: targets must succeed on a Hull save or become prone.

func test_the_second_profile_is_hidden_before_the_protocol() -> void:
	# The turn is opened first so this is a fair comparison: outside a turn the unit has no actions
	# to spend, can_activate_gear is false for EVERYTHING, and "hidden" would prove nothing.
	await open_turn()

	var mbp := _weapon(MBP_ACTION_ID)
	assert_not_null(mbp, '%s carries %s as an ActionAttackWeapon.' % [KIT_ID, MBP_ACTION_ID])
	if mbp == null: return

	assert_true(mbp.hide_if_disabled,
		'hide_if_disabled: the gear bar DROPS this button rather than greying it out.')
	assert_false(mbp.is_available_to_activate(unit, _gear()),
		'Without the marker the profile refuses to activate.')
	assert_eq(
		UnitAction.get_gear_unavailable_reason(_specific(MBP_ACTION_ID)),
		UnitAction.REASON.SPECIFIC,
		'And it is refused for OUR reason (SPECIFIC = is_available_to_activate said no), not because'
		+ ' the unit happens to be out of actions or the gear is jammed.'
	)
	assert_true(_gear_bar_hides_when_disabled(MBP_ACTION_ID),
		'So the gear bar draws no button for it at all: the profile does not exist yet.')
	# Asked through can_activate_gear and NOT through _gear_bar_hides_when_disabled. The base profile
	# does not set hide_if_disabled, so _gear_bar_hides_when_disabled is `false and ...` = false for it
	# whatever its availability - it would pass here even from outside a turn, which is exactly the
	# state this fixture is supposed to rule out.
	assert_true(UnitAction.can_activate_gear(_specific(ACTION_ID)),
		'Fixture: the BASE profile IS usable right now, so the assertions above are about the missing'
		+ ' marker and not about the whole Kit being unusable.')

func test_the_second_profile_carries_its_own_statistics() -> void:
	var mbp := _weapon(MBP_ACTION_ID)
	assert_not_null(mbp, 'fixture: the second profile loads.')
	if mbp == null: return

	assert_eq(mbp.get_id(), MBP_ACTION_ID, 'The action ids itself off its own filename.')
	assert_eq(mbp.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'weapon_type is CANNON.')
	assert_eq(mbp.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'weapon_size is HEAVY.')
	assert_eq(mbp.damage_dice, '2d6', 'damage_dice is 2d6.')
	assert_eq(mbp.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'The base damage is KINETIC.')
	assert_not_null(mbp.range_pattern, 'The profile has a range pattern.')
	if mbp.range_pattern != null:
		assert_eq(mbp.range_pattern.pattern, Lancer.AOE_TYPE.LINE, 'Still a LINE.')
		assert_eq(mbp.range_pattern.value, 15, 'Still 15 long.')

	# "+ 1d6 explosive damage" - a second DamageValue riding along with the kinetic dice.
	assert_eq(mbp.additional_damage_values.size(), 1, 'One additional damage value.')
	if mbp.additional_damage_values.size() == 1:
		var extra:DamageValue = mbp.additional_damage_values[0]
		assert_eq(extra.dice, '1d6', 'The extra damage is 1d6...')
		assert_eq(extra.type, Lancer.DAMAGE_TYPE.EXPLOSIVE, '...and it is EXPLOSIVE.')

	var specific := _specific(MBP_ACTION_ID)
	assert_true(mbp.has_tag(Lancer.WEAPON_TAG.AP, specific), 'AP.')
	assert_true(mbp.has_tag(Lancer.WEAPON_TAG.RELIABLE, specific), 'Reliable.')
	# The one tag the base profile has that this one drops. Asserted because copying the base .tres
	# and forgetting to trim the array is exactly how this would go wrong, and INACCURATE is invisible
	# in a test that only ever cheats a guaranteed hit.
	assert_false(mbp.has_tag(Lancer.WEAPON_TAG.INACCURATE, specific), 'NOT Inaccurate.')
	assert_eq(mbp.reliable_damage, '3', 'Reliable 3, up from the base profile 2.')
	assert_eq(mbp.self_heat_dice, '1', 'Heat 1 (self), same as the base profile.')

	# The recoil magnitudes live in the .tres, not in the script: action_bizarre_cannon.gd activate()
	# reads these @export properties, which is what lets this profile differ from the base one
	# without overriding activate() at all - and so without firing the base recoil as well.
	assert_eq(mbp.recoil_damage_dice, '3', 'The recoil wound is 3, not the base profile 2.')
	assert_eq(mbp.recoil_knockback, 3, 'The shove is 3 spaces, not the base profile 2.')

	# Ruling 11: this prone save is its own effect. It belongs to THIS profile only.
	assert_eq(mbp.on_hit_effects.size(), 1, 'One on-hit effect: the Hull save against prone.')
	if mbp.on_hit_effects.size() == 1:
		var on_hit:OnHitEffect = mbp.on_hit_effects[0]
		assert_eq(on_hit.apply_on, OnHitEffect.STAGE.ON_HIT, 'It fires ON HIT, not on attack.')
		assert_eq(on_hit.statuses, [&'prone'] as Array[StringName], 'It applies prone.')
		assert_true(on_hit.save_to_avoid, 'A save avoids it...')
		assert_eq(on_hit.save_type, Lancer.HASE.HULL, '...and the save is HULL.')
	var base := _weapon(ACTION_ID)
	assert_true(base != null and base.on_hit_effects.is_empty(),
		'The BASE profile has no on-hit effect: only More Black Powder prones.')

func test_the_protocol_spends_the_core_power_and_applies_the_marker() -> void:
	# action_type = 4 (PROTOCOL) on the .tres is otherwise asserted nowhere: SpecFactory.start_turn
	# opens is_using_protocols unconditionally, so a .tres edit that quietly turned this into a QUICK
	# action would leave every other test in this file green while "Protocol" - which is in the rules
	# text - stopped being true.
	assert_true(UnitAction.is_protocol(_specific(MBP_PROTOCOL_ID)),
		'MORE BLACK POWDER is a PROTOCOL action.')

	assert_true(unit.core.has_core_power, 'Fixture: the Fitzgerald starts with its core power.')
	assert_false(UnitCondition.has_buff(unit, MARKER_ID), 'Fixture: and without the marker.')

	await use_protocol()

	assert_false(unit.core.has_core_power, 'MORE BLACK POWDER consumed the core power.')
	assert_true(UnitCondition.has_buff(unit, MARKER_ID),
		'And the Fitzgerald now carries %s.' % MARKER_ID)

func test_the_marker_persists_across_turns() -> void:
	# "For the rest of this scene" is not an engine lifetime - there is no END_OF_SCENE in
	# Lancer.UNTIL - so the marker is a MANUAL buff, which nothing expires. This is the test that
	# pins that against an until= that looked tidier and quietly ends the profile a turn later.
	await use_protocol()
	assert_true(UnitCondition.has_buff(unit, MARKER_ID), 'Fixture: the marker was applied.')

	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

	assert_true(UnitCondition.has_buff(unit, MARKER_ID),
		'The marker survived a turn boundary: until = MANUAL, so only the scene ending clears it.')
	assert_false(_gear_bar_hides_when_disabled(MBP_ACTION_ID),
		'And the second profile is still on the gear bar on the new turn.')

func test_both_profiles_are_firable_after_the_protocol() -> void:
	# Ruling 8, and the reason this is a test rather than a comment: the protocol ADDS the profile.
	# The base shot 2 self-damage against this one 3 is a real choice on a 6 HP frame, so an
	# implementation that swapped the profiles instead of adding one would be wrong while looking
	# right in every other test in this file.
	await use_protocol()

	assert_true(UnitAction.can_activate_gear(_specific(ACTION_ID)),
		'The base profile is still firable after the protocol.')
	assert_true(UnitAction.can_activate_gear(_specific(MBP_ACTION_ID)),
		'And the second profile is now firable too.')
	# Only the second profile is worth asking the gear-bar predicate about: it is the one carrying
	# hide_if_disabled, so it is the only one for which "is it drawn" can answer anything.
	assert_false(_gear_bar_hides_when_disabled(MBP_ACTION_ID),
		'And the second profile now has a button on the bar, where a moment ago it had none.')

func test_firing_one_profile_spends_the_shared_allowance_for_the_other() -> void:
	# Both profiles share the Kit's usage group by ENGINE DEFAULT, not by anything either .tres sets:
	# GearCore.get_usage_group_for_action (gear_core.gd:166-168) falls back to kit.compcon_id whenever
	# an action leaves usage_group empty, and neither action_bizarre_cannon.tres nor
	# action_more_black_powder.tres sets one. Ruling 8 is that this is correct - the protocol only
	# ADDS a profile to choose per shot, it does not grant a second allowance - but nothing else in
	# this file would notice if the two ever stopped sharing: test_both_profiles_are_firable_after_the
	# _protocol only checks availability before either has been fired. Without this test, a future
	# .tres edit that gave either profile its own usage_group would let a player fire 2d6 AND
	# 2d6+1d6 in the same round with nothing here to catch it.
	cheat_a_hit()
	await use_protocol()
	await fire_at(AIM_EAST)

	assert_false(UnitAction.can_activate_gear(_specific(MBP_ACTION_ID)),
		'The second profile is unavailable this turn: the shared per-turn allowance is spent, not the'
		+ ' marker (which is still held) and not is_available_to_activate (which only ever gates on the'
		+ ' marker).')

func test_the_second_profile_costs_exactly_three_ap_kinetic_self_damage() -> void:
	cheat_a_hit()
	await use_protocol()
	await fire_more_black_powder_at(AIM_EAST)

	assert_gt(target.current_damage(), MBP_RELIABLE_ON_MISS,
		'The shot landed: more damage than Reliable 3 alone could have dealt.')
	# EXACTLY three, and the exactness is the whole assertion. The Fitzgerald has armor 1, so a
	# non-AP 3 would land as 2; the base profile numbers would land as 2; and a recoil that fired
	# TWICE - the trap that made the base action magnitudes @export properties instead of consts -
	# would land as 6.
	assert_eq(unit.current_damage(), MBP_SELF_DAMAGE,
		'The Fitzgerald took 3 AP kinetic from its own cannon: once, at this profile number.')

func test_the_second_profile_knocks_back_three_spaces_in_any_direction() -> void:
	# Fired NORTH on purpose. The base profile recoil cone opens AWAY from the fired line, which from
	# here is south - so a landing tile to the north-west is one that cone could not offer at any
	# distance. That is what makes this test discriminate rather than merely pass.
	cheat_a_hit()
	var north:Unit = SpecFactory.create_unit(game.map, AIM_NORTH, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(north)
	north.core.frame.stat.health = 200
	north.core.frame.stat.evasion = -10
	north.core.full_repair()

	await use_protocol()
	await fire_more_black_powder_at(AIM_NORTH)

	assert_gt(north.current_damage(), MBP_RELIABLE_ON_MISS, 'Fixture: the northward shot landed.')
	# Exactly this tile, for two reasons at once: it is 3 away (not the base profile 2), and it is the
	# first tile of the ALL-DIRECTIONS ring rather than of a cone. A recoil that fired twice would
	# land at (1,0) - the first entry of the ring recentred on this tile - so this also catches the
	# double shove.
	assert_eq(unit.tile(), RECOIL_ANY,
		'The Fitzgerald was shoved 3 spaces north-west while firing north: the knockback pick was'
		+ ' opened in every direction, and it happened once.')

func test_the_second_profile_prones_a_target_that_fails_its_hull_save() -> void:
	cheat_a_hit()
	# A save the target cannot make, whatever the d20 does. Pinning the OUTCOME through the stat
	# rather than through Dice.CHEAT_ROLL_QUEUE matters here: the queue is global and the attack ahead
	# of the save pops an unpredictable number of accuracy and damage dice out of it, so queueing a
	# particular d20 for the save would be guessing at how many dice the attack ate first.
	target.core.frame.hase = HaseBlock.create(-30, 0, 0, 0)
	target.core.full_repair()

	await use_protocol()
	await fire_more_black_powder_at(AIM_EAST)

	assert_gt(target.current_damage(), MBP_RELIABLE_ON_MISS, 'Fixture: the shot landed.')
	assert_true(target.has_status(Lancer.STATUS.PRONE),
		'The target failed its Hull save and went prone.')

func test_a_target_that_passes_its_hull_save_is_not_proned() -> void:
	# The other half, and the one that proves the save is consulted at all: without it a profile that
	# applied prone unconditionally would pass the test above.
	cheat_a_hit()
	target.core.frame.hase = HaseBlock.create(30, 0, 0, 0)
	target.core.full_repair()

	await use_protocol()
	await fire_more_black_powder_at(AIM_EAST)

	assert_gt(target.current_damage(), MBP_RELIABLE_ON_MISS,
		'Fixture: the shot still landed, so the save is what spared it and not a miss.')
	assert_false(target.has_status(Lancer.STATUS.PRONE),
		'A passed Hull save leaves the target on its feet.')
