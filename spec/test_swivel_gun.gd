# SP2 Task 1: the Breech-loading Swivel Gun, its three-round counter, and the SINGLE SHOT profile.
#
# Design §3.1, rules sheet "Rank I":
#   Main Cannon, SP 0. "You can fire this cannon three times before it needs to be reloaded."
#   Single Shot: 1d6+2 kinetic, range 10, Loading.
#
# WHY THERE IS A COUNTER AT ALL. The engine's LOADING tag is a single BOOLEAN on GearCore
# (gear_core.gd is_loaded): UnitAction.spend sets it false after any shot whose action carries the
# tag (unit_action.gd:276) and event_gear_reload.gd:24-31 sets it back. There is no ammo count
# anywhere in the engine. So this weapon does NOT carry the engine LOADING tag - it would unload the
# gun after the FIRST shot, which is the exact behaviour the gun replaces - and instead rides a
# PassiveDieCounter (the Raleigh's chambered rounds, passive_chambered_rounds_die.tres) that counts
# down from 3 and drops is_loaded only when it reaches zero. The card text carries "Loading (3
# rounds)"; that is a localization row, not a tag. test_one_single_shot... below is where the missing
# tag is pinned.
#
# WHERE THE ROUND IS DECREMENTED, AND WHY IT IS A TEST AND NOT A COMMENT. The decrement site is
# Action.on_resolution(), which event_unit_attack_declared.gd:215 calls ONCE per attack activation,
# after all damage, on a hit and on a miss alike - and never at all for an activation that aborted
# before the attack was declared, because ActionAttack.activate returns at its
# abort_when(not CompconPlan.is_valid_with_targets(...)) guard well before spend_actions
# (action_attack.gd:233-261). That is the whole reason for choosing it over spend_actions(): a shot
# that was never fired must not cost a round. The Mjolnir resets its own counter in the same place
# (action_m35_mjolnir.gd:23-26). test_an_activation_that_aborts_before_attacking_does_not_eat_a_round
# is what pins it; without that test the decrement site is unproven and spend_actions would look
# equally correct.
#
# THREE SHOTS TAKE THREE TURNS, NOT THREE ACTIVATIONS IN ONE. Action.get_per_turn_soft_limit
# (action.gd:161-163) is 1 for anything that is not a free action - the no-repeat-action rule - so a
# second Single Shot in the same turn is refused by the TURN limit, which has nothing to do with the
# round counter and would make "the gun ran dry" indistinguishable from "the unit had nothing left to
# spend". new_turn() below is what keeps the two apart.
#
# DICE. The all-sixes buffer trick is SP1's, and its reasoning is in test_bizarre_cannon.gd:155-164:
# Dice.cheat_attack APPENDS, so every helper clears the queue first, and the buffer is longer than
# any plausible number of accuracy/damage dice so that the damage die is a 6 whatever the attack ate
# ahead of it. The hit is guaranteed by the target's evasion, not by the dice.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const KIT_ID := &'mw_breech_loading_swivel_gun'
const SINGLE_SHOT_ID := &'action_swivel_single_shot'
const LICENSE_ID := &'li_fitzgerald'

## The PassiveDieCounter's key in the gear's own state dictionary.
const COUNTER_KEY := 'swivel_rounds'
const STARTING_ROUNDS := 3

## Read THIS MOD'S OWN compiled artifact rather than the global tr(), so a display-text assertion is
## attributable to this mod and not to a sibling Reag-* mod loaded in the same testkit run. Same
## pattern as test_fitzgerald_frame.gd:20 and test_content_integrity.gd:107.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const FIRE_FROM := Vector2i(7, 4)
const AIM_EAST := Vector2i(11, 4)

## A tile that is not on the map. Tile.is_valid bounds-checks it away inside
## TargetActionUtil.ask_for_targets_alt (target_action_util.gd:171), which leaves the returned plan
## holding no tiles and no units - and Tile.all_valid / Unit.all_valid both answer FALSE for an empty
## array (tile.gd:58-60, unit.gd:93-95), so CompconPlan.is_valid_with_targets_alt refuses the plan
## (compcon_plan.gd:45-52) and ActionAttack.activate aborts at its guard. It is the same abort branch
## a player cancelling the tile picker takes (create_aborted() at target_action_util.gd:202), reached
## deterministically and without a prompt - which is what a spec needs.
const OFF_MAP := Vector2i(99, 99)

## 1d6+2 with the damage die cheated to a 6, against a target the fixture gives armor 0. The exact
## number is the point: it is the only assertion that proves the +2 and the die size are both wired,
## rather than merely that "some damage happened".
const SINGLE_SHOT_DAMAGE := 8

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	unit = FitzgeraldFixture.create_fitzgerald(game, FIRE_FROM)
	# equip_system works for a weapon Kit as well as a system - it just appends to equipped_kits
	# (loadout_core.gd:337-339) - and it is how SP1's test_knock_em_down.gd:185 equips a vanilla rifle.
	# The gun takes no mount this way, which is fine: the Fitzgerald's single Main mount is not what is
	# under test here, and an unmounted weapon skips ActionAttackWeapon's mounted-followup block.
	unit.core.equip_system(KIT_ID)
	SpecFactory.apply_passive_buffs(unit)
	# Evasion -10: every test in this file that fires wants a guaranteed hit, and none of them is about
	# missing. (The counter does not care either way - on_resolution runs on a miss too - but a miss
	# would make the damage assertion in test_single_shot_deals... meaningless.)
	target = FitzgeraldFixture.create_dummy(game, AIM_EAST, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## Kit.is_valid, NOT `kit is Kit`. ContentLibrary.get_kit (content_library.gd:231-236) logs an error
## and then hands back the PLACEHOLDER kit (Kit.UNKNOWN_ID = mt_missing_mechsystem) for an id it does
## not know - so `kit is Kit` is true for a weapon that does not exist, and an assert_not_null on it
## passes vacuously. Measured, not theorised: this file's RED run (no content on disk at all) reported
## "loads as a valid Kit" as PASSING, and its sp_cost == 0 assertion passed too, because the
## placeholder also costs 0. Kit.is_valid (kit.gd:46-47) is the check that rejects the placeholder.
func _kit() -> Kit:
	var kit = ContentLibrary.get_kit(KIT_ID)
	return kit if Kit.is_valid(kit) else null

func _license() -> UnlockTree:
	var tree = ContentLibrary.get_license_tree(LICENSE_ID)
	return tree if tree is UnlockTree else null

func _gear() -> GearCore:
	var gear := unit.get_gear(KIT_ID)
	return gear if GearCore.is_valid(gear) else null

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

func _counter() -> PassiveDieCounter:
	var gear := _gear()
	if gear == null: return null
	return gear.get_die_counter_passive()

## Rounds left in the gun, or -1 when the gun (or its counter) does not exist. -1 rather than 0 on
## purpose: a missing weapon must never read as "an empty one", which is the exact confusion that
## would let this whole file pass vacuously.
func rounds_left() -> int:
	var gear := _gear()
	var counter := _counter()
	if gear == null or counter == null: return -1
	return counter.get_current(gear)

## Fire SINGLE SHOT at a UNIT, not at a tile - and the difference is not cosmetic.
##
## Every other Fitzgerald spec fires the Bizarre Cannon, which carries a LINE range_pattern, so a
## supplied TILE resolves through get_aoe_tiles_with_targets into "everything standing on the line"
## and the unit standing there is attacked. Single Shot has no pattern at all, so a supplied tile is
## taken at face value as an aimed-at-the-GROUND shot: the engine spawns a dep_attack_ground_proxy
## Terrain unit on that tile, the attack rolls against the PROXY (evasion 5), the proxy eats the
## damage as event_map_damage and is then extracted and killed, and the real target beside it is
## untouched. Measured, not theorised: the first GREEN run of this file did exactly that - the log
## reads "rolled 19 against Terrain (5 Eva): hit!", the target took 0, and the proxy's removal pushed
## two engine errors (campaign_core is Nil in a spec, so remove_unit_from_game's get_lancer_by_id call
## fails) which GUT counts as test failures. Passing the Unit puts it in context.target_units, which
## ask_for_targets_alt keeps and turns into the attacked tiles directly. SP1's test_knock_em_down.gd:192
## already passes a Unit for the same reason when it fires a vanilla rifle.
func fire_single_shot_at(victim:Unit) -> void:
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, SINGLE_SHOT_ID, victim)

## Close the turn and open the next one, so the no-repeat-action rule stops shadowing the round
## counter. See this file's header.
func new_turn() -> void:
	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## A guaranteed hit whose damage die is a 6. The target's evasion (-10, from before_each) is what
## guarantees the hit; the queue only fixes the numbers. Clears first - Dice.cheat_attack appends.
func cheat_a_hit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6, 6, 6])

# ---------------------------------------------------------------- the Kit and the licence

func test_the_swivel_gun_is_registered_and_granted_at_licence_rank_1() -> void:
	var kit := _kit()
	assert_not_null(kit, '%s loads as a valid Kit through ContentLibrary.' % KIT_ID)
	if kit == null: return
	# Registration, not merely parsing: ContentLibrary files by FILENAME PREFIX, and mw_ is what puts
	# this in the kits index at all. The id is asserted because _kit() could only ever have returned
	# the placeholder otherwise, and this says so out loud.
	assert_eq(kit.compcon_id, KIT_ID, 'And it is filed under its own id, not the missing-gear stub.')
	assert_false(kit.is_trait,
		'It is equippable gear, not a frame trait - so it is destructible and takes a weapon slot.')
	assert_eq(kit.sp_cost, 0, 'The gun costs SP 0.')

	var license := _license()
	assert_not_null(license, 'fixture: %s loads.' % LICENSE_ID)
	if license == null: return
	assert_not_null(license.rank_1, 'fixture: the licence has a rank_1.')
	if license.rank_1 == null: return
	var granted:Array = license.rank_1.granted_gear.map(func(g:Kit) -> StringName: return g.compcon_id)
	assert_has(granted, KIT_ID, 'Licence rank 1 grants the Swivel Gun.')
	# Rank 2 is the frame's rank and must not have been disturbed by the edit that filled rank 1.
	assert_true(license.rank_2 != null and not license.rank_2.granted_frames.is_empty(),
		'Rank 2 still grants the frame.')

	# And it survives the trip onto a live unit, which is what makes it fireable at all.
	assert_not_null(_gear(), 'A Fitzgerald that equipped it carries it as gear.')
	var shot := _weapon(SINGLE_SHOT_ID)
	assert_not_null(shot, '%s carries %s as an ActionAttackWeapon.' % [KIT_ID, SINGLE_SHOT_ID])
	if shot == null: return
	assert_eq(shot.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'weapon_type is CANNON.')
	assert_eq(shot.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'weapon_size is MAIN.')
	assert_eq(shot.aim_range, 10, 'Range 10.')
	# Single Shot is a plain aimed shot. Asserted because the Fitzgerald's own Hole Puncher and
	# Blasting Powder traits both key off "fires a Line", and a stray range_pattern here would quietly
	# enrol this profile in both of them.
	assert_null(shot.range_pattern, 'Single Shot fires no AOE pattern: it is not a Line.')

	# Display text. The compiled ARTIFACT, not the csv: Translate reads localizations.en.translation
	# and never the csv beside it, so an edited-but-unscanned csv leaves a correct-looking source file
	# next to an artifact that has never heard of these keys.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in [
		'gear.%s.name' % KIT_ID,
		'gear.%s.effect' % KIT_ID,
		'gear.%s.%s.name' % [KIT_ID, SINGLE_SHOT_ID],
		'gear.%s.%s.effect' % [KIT_ID, SINGLE_SHOT_ID],
		# PassiveDieCounter.update_value logs its changes as Translate.gear(kit_id, key)
		# (passive_die_counter.gd:48), so the counter's own key needs a row or the battle log reads
		# "gear.mw_breech_loading_swivel_gun.swivel_rounds changed to 2".
		'gear.%s.%s' % [KIT_ID, COUNTER_KEY],
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

# ---------------------------------------------------------------- the three rounds

func test_a_fresh_gun_starts_with_three_rounds() -> void:
	var counter := _counter()
	assert_not_null(counter, '%s carries a PassiveDieCounter.' % KIT_ID)
	if counter == null: return
	assert_eq(counter.key, COUNTER_KEY, 'The counter is keyed %s.' % COUNTER_KEY)
	assert_eq(counter.starting_value, STARTING_ROUNDS, 'It starts at 3...')
	assert_eq(counter.max_value, STARTING_ROUNDS, '...and cannot be topped up past 3.')
	# min_value DEFAULTS TO 1 (passive_die_counter.gd:14) and update_value_core clamps to it (:67), so
	# a rounds counter that does not set it explicitly can never reach zero and the gun never runs dry.
	# The Raleigh's passive_chambered_rounds_die.tres sets it to 0 for the same reason.
	assert_eq(counter.min_value, 0, 'And it is allowed to reach 0 - min_value defaults to 1.')
	assert_true(counter.show_in_tooltips,
		'The rounds left are shown to the player: unlike the Mjolnir, this number is the whole weapon.')

	assert_eq(rounds_left(), STARTING_ROUNDS, 'A gun nobody has fired reads 3 rounds.')
	var gear := _gear()
	assert_true(gear != null and gear.is_loaded, 'And it is loaded.')

func test_one_single_shot_leaves_two_rounds_and_the_gun_still_loaded() -> void:
	# THE TAG ASSERTION IS THE POINT OF PUTTING IT HERE. If the action carried the engine's LOADING
	# tag, UnitAction.spend (unit_action.gd:276) would set is_loaded false after this very shot and the
	# "still firable" half below would fail - so this is where the missing tag is load-bearing, and
	# where a copy-paste from a vanilla Loading cannon would be caught.
	var shot := _weapon(SINGLE_SHOT_ID)
	assert_not_null(shot, 'fixture: the profile loads.')
	if shot == null: return
	assert_false(shot.has_tag(Lancer.WEAPON_TAG.LOADING, _specific(SINGLE_SHOT_ID)),
		'The profile does NOT carry the engine LOADING tag: the counter is what tracks its ammunition.')

	cheat_a_hit()
	await fire_single_shot_at(target)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot actually landed.')
	assert_eq(rounds_left(), 2, 'One shot spent exactly one round.')
	var gear := _gear()
	assert_true(gear != null and gear.is_loaded, 'The gun is still loaded with two rounds in it.')
	# And still firable on a fresh turn, which is the claim "still loaded" is standing in for.
	await new_turn()
	assert_true(UnitAction.can_activate_gear(_specific(SINGLE_SHOT_ID)),
		'And it can be fired again next turn.')

func test_three_single_shots_empty_the_gun_and_the_fourth_is_refused_as_unloaded() -> void:
	for shot_number:int in STARTING_ROUNDS:
		cheat_a_hit()
		await fire_single_shot_at(target)
		assert_eq(rounds_left(), STARTING_ROUNDS - (shot_number + 1),
			'After shot %d the gun holds %d rounds.' % [shot_number + 1, STARTING_ROUNDS - (shot_number + 1)])
		await new_turn()

	var gear := _gear()
	assert_not_null(gear, 'fixture: the gun is still on the unit.')
	if gear == null: return
	assert_eq(rounds_left(), 0, 'Three shots emptied it.')
	assert_false(gear.is_loaded,
		'And emptying it dropped is_loaded, which is what makes Stabilize offer Reload'
		+ ' (action_stabilize.gd:85 builds its Reload variant from UnitAction.get_unloaded_weapons).')

	# THE REFUSAL IS ASSERTED THROUGH THE ENGINE'S OWN REASON, not merely as "nothing happened". A
	# spec that only checked for no damage would pass just as well against a unit that had simply run
	# out of actions - the trap memory lancer-tactics-spec-harness-traps names.
	assert_eq(UnitAction.get_gear_unavailable_reason(_specific(SINGLE_SHOT_ID)),
		UnitAction.REASON.UNLOADED,
		'A fourth shot is refused, and the engine refuses it for being UNLOADED.')

	var damage_before:int = target.current_damage()
	cheat_a_hit()
	await fire_single_shot_at(target)
	assert_eq(target.current_damage(), damage_before, 'And firing it does nothing at all.')
	assert_eq(rounds_left(), 0, 'The counter cannot go below zero either.')

	# The gun's OWN gate, separately. is_loaded is checked before is_available_to_activate in
	# get_gear_unavailable_reason (unit_action.gd:151-158), so UNLOADED above masks it entirely -
	# handing the gear back its boolean is the only way to see whether the action would refuse on its
	# own count of rounds, which is what makes the empty gun's greyed-out button read as the weapon's
	# state rather than as a side effect.
	gear.is_loaded = true
	assert_false(_weapon(SINGLE_SHOT_ID).is_available_to_activate(unit, gear),
		'With the counter at 0 the profile refuses on its own account, not only via is_loaded.')
	assert_eq(UnitAction.get_gear_unavailable_reason(_specific(SINGLE_SHOT_ID)),
		UnitAction.REASON.SPECIFIC,
		'And the engine then names OUR reason: SPECIFIC = is_available_to_activate said no.')

func test_single_shot_deals_its_1d6_plus_2_kinetic_on_a_hit() -> void:
	cheat_a_hit()
	await fire_single_shot_at(target)

	# Exactly 8 - a cheated 6 plus the flat 2, through armor 0. "More than zero" would be satisfied by
	# any damage_dice at all; this is what proves the profile's own numbers are wired.
	assert_eq(target.current_damage(), SINGLE_SHOT_DAMAGE,
		'Single Shot dealt 1d6+2: a cheated 6 and the flat +2.')
	var shot := _weapon(SINGLE_SHOT_ID)
	assert_true(shot != null and shot.damage_dice == '1d6+2', 'damage_dice is 1d6+2.')
	assert_true(shot != null and shot.damage_type == Lancer.DAMAGE_TYPE.KINETIC, 'The damage is KINETIC.')

func test_an_activation_that_aborts_before_attacking_does_not_eat_a_round() -> void:
	# THIS IS THE TEST THAT PINS THE DECREMENT SITE. on_resolution never runs for an activation that
	# aborted before the attack was declared; spend_actions() and an activate() override would both
	# have charged a round here. See the OFF_MAP constant for exactly which engine guard does the
	# aborting and why it is the same one a cancelled tile picker reaches.
	assert_eq(rounds_left(), STARTING_ROUNDS, 'Fixture: the gun is full.')

	cheat_a_hit()
	await FitzgeraldFixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, SINGLE_SHOT_ID, OFF_MAP)

	assert_eq(target.current_damage(), 0, 'Fixture: no attack was made, so nothing was damaged.')
	assert_eq(rounds_left(), STARTING_ROUNDS, 'A shot that was never fired costs no round.')

	# The activation cost NOTHING, not even the turn's action - so the very same turn can still fire.
	# This is also what proves the abort happened before spend_actions rather than after it.
	cheat_a_hit()
	await SpecFactory.use(game, unit, KIT_ID, SINGLE_SHOT_ID, target)
	assert_eq(target.current_damage(), SINGLE_SHOT_DAMAGE,
		'The aborted activation spent no action either: the same turn still fires.')
	assert_eq(rounds_left(), STARTING_ROUNDS - 1, 'And that real shot is the only one that cost a round.')
