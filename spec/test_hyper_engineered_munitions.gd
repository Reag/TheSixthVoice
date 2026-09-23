# HYPER ENGINEERED MUNITIONS (Purple Thorn rank III system, SP4 Task 1, design ruling 14).
#
#   UNIQUE, LIMITED 3, SP 2. Load Munitions (Protocol): Choose a mount that contains only ranged
#   weapons: until the start of your next turn, whenever you hit a hostile character with a weapon
#   on this mount, the target takes 1 AP Kinetic damage and must succeed on a Hull save or become
#   Impaired until the end of their next turn.
#
# Pinned here: the picker (only all-ranged, non-empty mounts, in loadout order; the stock gear
# answer accepts a MountCore; a cancel spends nothing; the AI picks the first without a prompt; no
# eligible mount = unavailable); the chip (a charge, visible, gone at the Thorn's next turn start);
# the hit (1 AP Kinetic through armor, a Hull save, Impaired on a fail and not on a pass, the point
# dealt either way); what does nothing (the other mount, a miss, an object, a drone); and the extra
# point offering Vigil ONCE for the attack, not twice.
#
# THE MOUNTS: 0 = [Fold Knife, Pistol] (a melee Aux beside a ranged one - OUT), 1 = [Nexus] (IN),
# 2 = the Flex holding the Main rifle (IN). So the picker offers [mount 1, mount 2].
#
# SHOTS DO NOT CYCLE THE THORN'S TURN once the protocol is pressed - a turn start is exactly what
# ends the chip - so every shot after the press is Fixture.shoot_again (AS_FREEBIE).
#
# DICE per rifle hit on a character: the d20, then the Hull save's d20 (on-hit effects run before
# damage is rolled, event_unit_attack.gd:85-88 against event_unit_attack_declared.gd:74), then the
# d6. The rifle's RELIABLE 2 floors a hit, so the d6 is never below 3 here.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hyper_engineered_munitions.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const LoadMunitions := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_hyper_engineered_munitions/action_load_munitions.gd')
const ChipScript := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_hyper_engineered_munitions/buff_loaded_munitions.gd')

const KIT_ID := &'ms_hyper_engineered_munitions'
const ACTION_ID := &'action_load_munitions'
const CHIP := &'buff_loaded_munitions'

const FOLD_KNIFE := &'mw_fold_knife' # SSC, Aux MELEE

const THORN_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(8, 6)
const CANCEL_VIGIL := Vector2i(28, 0)

const D20_HITS := 19
const D20_MISSES := 1
const SAVE_PASSES := 20
const SAVE_FAILS := 1
const RIFLE_D6 := 4

var game:Gamemaster
var thorn:Unit
var target:Unit
var gear:GearCore
var responder
var watcher

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	target = Fixture.create_hostile(game, TARGET_TILE)
	arm(thorn)
	gear = Fixture.equip(thorn, KIT_ID)
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func arm(unit:Unit, with_nexus_mount:bool = true) -> void:
	Fixture.mount_pair(unit, 0, FOLD_KNIFE, Fixture.AUX_PISTOL)
	if with_nexus_mount: Fixture.mount_pair(unit, 1, Fixture.AUX_NEXUS)
	Fixture.mount_pair(unit, 2, Fixture.MAIN_RIFLE)

func mount(index:int) -> MountCore:
	return thorn.core.loadout.mounts[index]

## Press Load Munitions, the Thorn's turn opened first (a protocol needs the turn start,
## unit_action.gd:144). `pick` is the gear_queue entry: an index into the offered mounts, or null.
func load_munitions(pick = 1) -> void:
	if not thorn.state.is_taking_turn: await Fixture.open_turn(game, thorn)
	responder.gear_queue = [pick]
	await SpecFactory.use_solo(game, thorn, KIT_ID)

func chip() -> BuffCore:
	return UnitCondition.get_buff(thorn, CHIP)

func hp(unit:Unit) -> int: return unit.core.current.health

func rifle_hit(at:Unit, save:int) -> void:
	Fixture.queue([D20_HITS, save, RIFLE_D6])
	await Fixture.shoot_again(game, thorn, at, Fixture.MAIN_RIFLE)

## Vigil's reticle is a move_tile request (test_vigil.gd's header), recorded by the watcher. Nothing
## else on this Thorn raises one: the Blessed Bolt is Aux-only and declined, and no shot here moves.
func vigil_prompts() -> int:
	return watcher.kinds(PromptWatcher.KIND.move_tile).size()

# ---------------------------------------------------------------- the picker

func test_only_mounts_of_nothing_but_ranged_weapons_are_offered():
	assert_eq(LoadMunitions.eligible_mounts(thorn), [mount(1), mount(2)] as Array[MountCore],
		'The Nexus mount and the Flex rifle are eligible; the knife-and-pistol pair is not.')
	await load_munitions(0)
	assert_eq(responder.gear_prompts.size(), 1, 'One mount picker was raised.')
	if responder.gear_prompts.is_empty(): return
	assert_eq(responder.gear_prompts[0].array, [mount(1), mount(2)],
		'The picker offers exactly the eligible mounts, in loadout order.')

func test_an_empty_mount_is_not_offered():
	var bare := Fixture.create_thorn(game, Vector2i(4, 9))
	arm(bare, false)
	assert_true(bare.core.loadout.mounts[1].is_empty(), 'fixture: mount 1 is empty.')
	assert_eq(LoadMunitions.eligible_mounts(bare), [bare.core.loadout.mounts[2]] as Array[MountCore],
		'An empty mount "contains only ranged weapons" vacuously and is still not offered.')

func test_with_no_eligible_mount_the_protocol_is_unavailable():
	var bare := Fixture.create_thorn(game, Vector2i(4, 9))
	Fixture.mount_pair(bare, 0, FOLD_KNIFE)
	var bare_gear := Fixture.equip(bare, KIT_ID)
	assert_false(bare_gear.get_solo_action().is_available_to_activate(bare, bare_gear),
		'Nothing to load: the protocol is not available.')
	assert_true(gear.get_solo_action().is_available_to_activate(thorn, gear),
		'fixture: the armed Thorn can press it.')

func test_a_pick_spends_a_charge_and_hangs_the_chip_on_that_mount():
	var charges := gear.charges_current
	await load_munitions(1)
	assert_eq(gear.charges_current, charges - 1, 'Load Munitions expends a charge.')
	assert_not_null(chip(), 'The chip is on the Thorn.')
	if chip() == null: return
	assert_false(chip().base.hide_from_player, 'The chip is visible.')
	assert_eq(chip().base.until, Lancer.UNTIL.START_OF_TURN, 'It lasts until the start of the next turn.')
	assert_eq(String(chip().get_state(ChipScript.MOUNT_KEY, '')), String(mount(2).persistent_id),
		'It carries the chosen (second offered) mount, the Flex.')

func test_the_chip_is_gone_at_the_thorns_next_turn_start():
	await load_munitions(1)
	assert_not_null(chip(), 'fixture: loaded.')
	await Fixture.cycle_turn(game, thorn)
	assert_null(chip(), 'The start of the Thorn\'s next turn ends it.')

func test_a_cancelled_pick_spends_nothing():
	var charges := gear.charges_current
	await load_munitions(null)
	assert_eq(responder.gear_prompts.size(), 1, 'fixture: the picker was raised.')
	assert_eq(gear.charges_current, charges, 'A cancel keeps the charge.')
	assert_null(chip(), 'A cancel hangs no chip.')
	assert_eq(gear.get_uses_this_round(gear.get_solo_action()), 0, 'A cancel is not a use.')

func test_the_ai_loads_the_first_eligible_mount_without_a_prompt():
	var ai := SpecFactory.create_unit(game.map, Vector2i(20, 6), Faction.AI_ENEMY)
	ai.core.frame = ContentLibrary.get_mech_frame(Fixture.FRAME_ID)
	SpecFactory.apply_passive_buffs(ai)
	arm(ai)
	Fixture.equip(ai, KIT_ID)
	await Fixture.open_turn(game, ai)
	await SpecFactory.use_solo(game, ai, KIT_ID)
	assert_eq(responder.gear_prompts.size(), 0, 'The AI is never prompted.')
	var ai_chip := UnitCondition.get_buff(ai, CHIP)
	assert_not_null(ai_chip, 'The AI loaded a mount.')
	if ai_chip == null: return
	assert_eq(String(ai_chip.get_state(ChipScript.MOUNT_KEY, '')), String(ai.core.loadout.mounts[1].persistent_id),
		'It loaded the FIRST eligible mount.')

# ---------------------------------------------------------------- the hit

func test_a_hit_from_the_loaded_mount_deals_one_extra_kinetic():
	await load_munitions(1)
	var before := hp(target)
	await rifle_hit(target, SAVE_PASSES)
	assert_eq(before - hp(target), RIFLE_D6 + 1, 'The rifle\'s 4, then the munitions\' 1.')

func test_the_extra_point_is_ap():
	Fixture.set_armor(target, 2)
	await load_munitions(1)
	var before := hp(target)
	await rifle_hit(target, SAVE_PASSES)
	assert_eq(before - hp(target), (RIFLE_D6 - 2) + 1, 'Armor 2 takes 2 off the rifle and none off the AP point.')

func test_a_failed_hull_save_impairs_until_the_end_of_their_next_turn():
	await load_munitions(1)
	await rifle_hit(target, SAVE_FAILS)
	assert_true(UnitCondition.has_status(target, &'impaired'), 'A failed Hull save: Impaired.')
	assert_eq(StatusType.get_standard_until(&'impaired'), Lancer.UNTIL.END_OF_NEXT_TURN,
		'Applied on its standard until - the end of their next turn.')

func test_a_passed_save_avoids_the_impaired_but_not_the_point():
	await load_munitions(1)
	var before := hp(target)
	await rifle_hit(target, SAVE_PASSES)
	assert_false(UnitCondition.has_status(target, &'impaired'), 'A passed save: no Impaired.')
	assert_eq(before - hp(target), RIFLE_D6 + 1, 'The AP point is dealt whether or not the save passes.')

func test_the_other_mounts_hits_do_nothing():
	await load_munitions(1) # the Flex rifle
	var before := hp(target)
	Fixture.queue([D20_HITS, 2])
	await Fixture.shoot_again(game, thorn, target, Fixture.AUX_NEXUS)
	assert_eq(before - hp(target), 2, 'The Nexus (mount 1) deals only its own 2.')
	assert_false(UnitCondition.has_status(target, &'impaired'), 'No save was forced.')

func test_a_miss_does_nothing():
	await load_munitions(1)
	var before := hp(target)
	Fixture.queue([D20_MISSES])
	await Fixture.shoot_again(game, thorn, target, Fixture.MAIN_RIFLE)
	assert_eq(before - hp(target), 2, "A miss deals only the rifle's RELIABLE 2 - no munitions point.")
	assert_false(UnitCondition.has_status(target, &'impaired'), 'A miss forces no save.')

func test_a_hit_on_an_object_does_nothing():
	var object := Fixture.create_object(game, Vector2i(8, 8))
	await load_munitions(1)
	var before := hp(object)
	Fixture.queue([D20_HITS, RIFLE_D6, SAVE_FAILS])
	await Fixture.shoot_again(game, thorn, object, Fixture.MAIN_RIFLE)
	assert_eq(before - hp(object), RIFLE_D6, 'An object takes only the rifle - no AP point, no save die spent.')

func test_a_hit_on_a_drone_does_nothing():
	var drone := Fixture.create_drone(game, Vector2i(8, 8))
	await load_munitions(1)
	var before := hp(drone)
	Fixture.queue([D20_HITS, RIFLE_D6, SAVE_FAILS])
	await Fixture.shoot_again(game, thorn, drone, Fixture.MAIN_RIFLE)
	assert_eq(before - hp(drone), RIFLE_D6, 'A drone is a character but not an actor: only the rifle.')
	assert_false(UnitCondition.has_status(drone, &'impaired'), 'No save forced on a drone.')

func test_the_extra_point_offers_vigil_once_for_the_attack():
	await load_munitions(1)
	await rifle_hit(target, SAVE_PASSES)
	assert_eq(vigil_prompts(), 1, 'Two damage events in one attack; Vigil opens its reticle once.')

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE.')
	assert_eq(kit.charges_max, 3, 'LIMITED 3.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var load_action := kit.actions[0] as ActionSystem
	assert_not_null(load_action, 'Load Munitions is a system action.')
	if load_action == null: return
	assert_eq(load_action.get_id(), ACTION_ID, 'Its id.')
	assert_eq(load_action.action_type, Lancer.ACTION.PROTOCOL, 'A Protocol.')

func test_the_rows_resolve():
	assert_eq(tr('gear.ms_hyper_engineered_munitions.name'), 'Hyper Engineered Munitions', 'The name row.')
	assert_eq(tr('gear.ms_hyper_engineered_munitions.action_load_munitions.name'), 'Load Munitions', 'The action row.')
	assert_eq(tr('gear.buff_loaded_munitions.name'), 'Load Munitions', 'The chip names itself.')
	assert_string_contains(tr('gear.buff_loaded_munitions.effect'), 'Hull save', 'The chip carries the card text.')
