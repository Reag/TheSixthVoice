# REND THAT WHICH IS CRUEL AND UNNATURAL (Purple Thorn core active, SP1 Task 4).
#
# NOT test_rend.gd: that file is the MAIDEN'S BLUSH's Rend trait (its SP1 Task 3), and this file's
# first draft overwrote it for one run before the collision was caught (2026-09-23) - the Blush's
# spec was restored from HEAD unchanged. The chip is buff_cruel_and_unnatural for the same reason:
# the Blush already ships a buff_cruel_and_unnatural, and ContentLibrary indexes buffs by basename.
#
#   "You may immediately Skirmish as a free action. Until the end of your next turn, whenever you
#    deal damage to a hostile character, they must make a Systems save or be teleported to free
#    space you choose within range 3 of their original position."
#
# THE PROMPTS A PRESS RAISES, IN ORDER, and how each is answered:
#   1. Rend's confirm - a yes/no (CommonActionUtil.confirm_use); responder.yesno_queue.
#   2. The free Skirmish's TARGETING - a compcon_plan request for the auto-picked single weapon;
#      responder.chosen_plan_queue, CompconPlan.create([tile], [], [target]). An aborted plan there
#      (CompconPlan.create_aborted()) is the "cancelled pick" case.
#   3. If that shot hits a hostile character while the chip is held (it is - the chip lands before
#      the shot), the SAVE pops a d20, and on a FAIL Rend's PICK opens - a compcon_plan request in
#      Rend's own name (Teleport.pick_tile); responder.chosen_plan_queue,
#      CompconPlan.create([landing], [], []). The offered tiles are read back the way test_hunt.gd
#      reads them: UnitTargeting.get_tiles_targetable on the prompt's `using`.
#
# THE DICE for a Nexus press that hits and fails the save: [19 (d20), 3 (hit die), 1 (crit die),
# 1 (the save - fails against 10)]. A PASS is a 20 in the fourth slot. The save pops AFTER the
# damage dice: DAMAGE POST runs after the damage lands.
#
# EVERY TELEPORT IS ASSERTED THROUGH Teleport.is_teleport (design §6) by a knockoff watcher on the
# victim.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rend_that_which_is_cruel.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const RendAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/cp_lav_tactical_engine/action_rend.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'
const TWO_TYPE_RIFLE := &'mw_sol_pattern_laser_rifle'
const INTERDICTION_FIELD := &'buff_interdiction_field'

const THORN_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(8, 6)
## Two east of the victim - free, within 3 of it - where the specs ask Rend's reticle to put it.
const SHOVE_LANDING := Vector2i(10, 6)
## Two east of the Thorn - free, within 3 - where Vigil's reticle lands in the order case.
const VIGIL_LANDING := Vector2i(6, 6)

const D20_HITS := 19
const SAVE_FAILS := 1
const SAVE_PASSES := 20
## On the map, far outside range 3 of anywhere the Thorn stands: cancels Vigil's reticle.
const CANCEL_VIGIL := Vector2i(25, 11)

var game:Gamemaster
var thorn:Unit
var hostile:Unit
var responder
var watcher:PromptWatcher
var moves:MoveWatcher

class MoveWatcher extends ActionReaction:
	var seen:Array[Dictionary] = []
	var seen_ids:Array[StringName] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if seen_ids.has(triggering_event.id): return false
		seen_ids.append(triggering_event.id)
		var context:Context = triggering_event.context
		seen.append({
			unit = context.unit,
			teleport = Teleport.is_teleport(context),
			voluntary = MovementType.is_contextual_move_voluntary(context),
			forcer = Teleport.forcer(context),
		})
		return false


func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	thorn = Fixture.create_thorn(game, THORN_TILE)
	hostile = Fixture.create_hostile(game, TARGET_TILE)
	moves = MoveWatcher.new()
	install_on(hostile, moves, &'spec_move_watcher')
	# THE FRAME'S TWO TRAITS FIRE ON EVERY HIT HERE TOO: Blessed Bolt offers a yes/no (default YES,
	# +3 to every number below) and Vigil opens a reticle BEFORE Rend's shove (ruling 8, measured) -
	# and the default answer, the first reachable tile, walks the Thorn about the board, which is
	# what made the Interdiction Field case pass its ban by accident on this file's first run (the
	# Thorn had left the field's 3). Decline the one and cancel the other by default; Rend's own
	# confirm is queued explicitly, and the order case sets Vigil's landing itself.
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.chosen_plan_queue.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func install_on(unit:Unit, reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func target_plan(target:Unit) -> CompconPlan:
	return CompconPlan.create([target.tile()], [], [target])

func landing_plan(tile:Vector2i) -> CompconPlan:
	return CompconPlan.create([tile], [], [])

## Press Rend with the Nexus mounted: confirm yes, aim the free shot at `target`, and - if the
## save is to fail - put the victim on `landing`. `save` is the fourth die.
func press(target:Unit = hostile, save:int = SAVE_FAILS, landing:Vector2i = SHOVE_LANDING) -> void:
	responder.yesno_queue.append(true)
	responder.chosen_plan_queue.append(target_plan(target))
	if landing != Tile.INVALID: responder.chosen_plan_queue.append(landing_plan(landing))
	Fixture.queue([D20_HITS, 3, 1, save])
	await Fixture.press_rend(game, thorn)

func chip() -> BuffCore:
	return UnitCondition.get_buff(thorn, Fixture.REND_CHIP)

## Rend's OWN pick prompts: the compcon_plan requests whose `using` is action_rend.
func pick_prompts() -> Array:
	return responder.plan_prompts.filter(func(info:Dictionary) -> bool:
		var using = info.using
		return SpecificAction.is_valid(using) and using.action.get_id() == Fixture.REND_ID)

## The tile set Rend's last pick was OFFERED (test_hunt.gd's reader).
func offered_tiles() -> Array[Vector2i]:
	var picks := pick_prompts()
	if picks.is_empty(): return []
	var using:SpecificAction = picks.back().using
	return UnitTargeting.get_tiles_targetable(using)

func victim_teleports(victim:Unit) -> Array[Dictionary]:
	return moves.seen.filter(func(record:Dictionary) -> bool: return record.unit == victim)

# ---------------------------------------------------------------- the press

func test_pressing_rend_spends_the_core_power_hangs_the_chip_and_fires_the_free_skirmish():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	assert_true(thorn.core.has_core_power, 'fixture: the core power is available.')
	var actions_before:int = UnitAction.current_total(thorn)
	await press(hostile, SAVE_PASSES) # a pass, so the shove does not confuse the shot's evidence
	assert_false(thorn.core.has_core_power, 'The core power is spent.')
	assert_true(BuffCore.is_valid(chip()), 'The chip is on the Thorn.')
	assert_eq(hostile.current_damage(), 3, 'The free Skirmish fired the Nexus for its die.')
	assert_eq(UnitAction.current_total(thorn), actions_before - 1,
		'ONE action gone - Rend\'s own QUICK. The Skirmish cost nothing (AS_FREEBIE).')

# Pass E item 3 as the author settled it (T6, 2026-09-27): the press already writes the engine's own
# "used" line (spend_actions -> unit_action.gd:231-234 -> action.gd:132-137), so this PINS that line
# rather than adding text. Read off the bus, test_thermal_death_axe.gd's pattern.
func test_a_press_writes_the_used_line_to_the_battle_log():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var action_name := X.tr('gear.cp_lav_tactical_engine.action_rend.name')
	assert_eq(action_name, 'Rend That which is Cruel and Unnatural', 'Fixture: the name resolves.')
	var lines:Array[String] = []
	var collect := func(text:String) -> void: lines.append(text)
	Action.battle_log.on_log_text.connect(collect)
	await press(hostile, SAVE_PASSES)
	# UNCONDITIONAL, and before the assertions: the bus is an autoload that outlives this test.
	if Action.battle_log.on_log_text.is_connected(collect): Action.battle_log.on_log_text.disconnect(collect)
	assert_false(thorn.core.has_core_power, 'Guard: the press went through.')
	assert_true(lines.any(func(text:String) -> bool: return text.contains(' used ') and text.contains(action_name)),
		'The press announced itself in the battle log: %s' % [lines])

func test_a_cancelled_weapon_pick_leaves_the_chip_and_the_spend():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	responder.yesno_queue.append(true)
	responder.chosen_plan_queue.append(CompconPlan.create_aborted())
	Fixture.queue([D20_HITS, 3, 1])
	await Fixture.press_rend(game, thorn)
	assert_eq(hostile.current_damage(), 0, 'No shot.')
	assert_true(BuffCore.is_valid(chip()), 'The chip stands...')
	assert_false(thorn.core.has_core_power, '...and the core power is spent. Cancelling forfeits the shot, nothing else.')

func test_declining_the_confirm_spends_nothing():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	responder.yesno_queue.append(false)
	await Fixture.press_rend(game, thorn)
	assert_true(thorn.core.has_core_power, 'A "no" at the confirm keeps the core power.')
	assert_false(BuffCore.is_valid(chip()), 'No chip.')

func test_a_second_press_is_refused_without_the_core_power():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await press(hostile, SAVE_PASSES)
	var confirms_before:int = responder.yesno_prompts.size()
	await Fixture.cycle_turn(game, thorn)
	responder.yesno_queue.append(true)
	await SpecFactory.use(game, thorn, Fixture.CORE_ID, Fixture.REND_ID)
	assert_eq(responder.yesno_prompts.size(), confirms_before, 'No confirm: the action is unavailable with the core power gone.')

func test_the_skirmish_offers_only_quick_available_weapons():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	Fixture.arm_rifle(thorn)
	var weapons := RendAction.skirmishable_weapons(thorn)
	var ids:Array[String] = []
	for weapon:SpecificAction in weapons: ids.append(String(weapon.gear.kit.compcon_id))
	ids.sort()
	assert_eq(ids, ['mw_assault_rifle', 'mw_nexus_light'] as Array[String], 'Both QUICK weapons are Skirmish candidates.')

# ---------------------------------------------------------------- the chip's clock

func test_the_chip_lasts_until_the_end_of_the_thorns_next_turn():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await press(hostile, SAVE_PASSES) # pressed on the Thorn's turn
	assert_true(BuffCore.is_valid(chip()), 'fixture: on.')
	await SpecFactory.end_turn(game, thorn)
	assert_true(BuffCore.is_valid(chip()), 'Still on after the turn it was pressed in ends.')
	await Fixture.cycle_turn(game, hostile) # somebody else's turn
	await SpecFactory.end_turn(game, hostile)
	assert_true(BuffCore.is_valid(chip()), 'Still on through a hostile turn.')
	await SpecFactory.start_turn(game, thorn)
	assert_true(BuffCore.is_valid(chip()), 'Still on at the start of the Thorn\'s NEXT turn...')
	await SpecFactory.end_turn(game, thorn)
	assert_false(BuffCore.is_valid(chip()), '...and gone at its end. "Until the end of your next turn."')

# ---------------------------------------------------------------- the save and the shove

func test_a_hit_on_a_hostile_character_forces_a_systems_save_and_a_fail_shoves_where_the_thorn_chooses():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await press(hostile, SAVE_FAILS, SHOVE_LANDING)
	assert_eq(hostile.current_damage(), 3, 'fixture: the free shot hit.')
	assert_eq(pick_prompts().size(), 1, 'Rend\'s reticle opened once, in Rend\'s name.')
	assert_eq(hostile.tile(), SHOVE_LANDING, 'The victim landed where the Thorn chose.')
	var teleports := victim_teleports(hostile)
	assert_eq(teleports.size(), 1, 'Exactly one move of the victim reached the bus...')
	if teleports.is_empty(): return
	assert_true(teleports[0].teleport, '...a TELEPORT by the Uncertainty Field\'s own reader...')
	assert_false(teleports[0].voluntary, '...INVOLUNTARY - a shove...')
	assert_eq(teleports[0].forcer, thorn, '...forced by the Thorn (so an Uncertainty Field would offer on it).')

func test_the_reticle_offers_the_free_spaces_within_three_of_the_victims_original_position():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var expected := Teleport.candidate_tiles(hostile, 3, false)
	await press(hostile, SAVE_FAILS, SHOVE_LANDING)
	var offered := offered_tiles()
	offered.sort()
	expected.sort()
	assert_eq(offered, expected, 'Exactly the free spaces within 3 of where the victim stood.')
	assert_false(offered.has(TARGET_TILE), 'Not the tile it stands on.')

func test_a_passed_save_moves_nobody():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await press(hostile, SAVE_PASSES, SHOVE_LANDING)
	assert_eq(hostile.current_damage(), 3, 'fixture: the shot hit.')
	assert_eq(pick_prompts().size(), 0, 'No reticle on a pass.')
	assert_eq(hostile.tile(), TARGET_TILE, 'The victim stays.')

func test_a_cancelled_pick_moves_nobody():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	responder.yesno_queue.append(true)
	responder.chosen_plan_queue.append(target_plan(hostile))
	responder.chosen_plan_queue.append(CompconPlan.create_aborted())
	Fixture.queue([D20_HITS, 3, 1, SAVE_FAILS])
	await Fixture.press_rend(game, thorn)
	assert_eq(pick_prompts().size(), 1, 'fixture: the reticle opened.')
	assert_eq(hostile.tile(), TARGET_TILE, 'Cancelled: the victim stays.')

func test_a_later_hit_while_the_chip_is_held_forces_a_save_too():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await press(hostile, SAVE_PASSES) # the press's own shot: a pass
	responder.chosen_plan_queue.append(landing_plan(SHOVE_LANDING))
	Fixture.queue([D20_HITS, 3, 1, SAVE_FAILS])
	await Fixture.shoot_again(game, thorn, hostile)
	assert_eq(hostile.current_damage(), 6, 'fixture: two hits.')
	assert_eq(pick_prompts().size(), 1, 'The second hit forced a save (failed) and opened the reticle.')
	assert_eq(hostile.tile(), SHOVE_LANDING, 'And shoved.')

func test_without_the_chip_a_hit_forces_nothing():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	responder.chosen_plan_queue.append(landing_plan(SHOVE_LANDING))
	Fixture.queue([D20_HITS, 3, 1, SAVE_FAILS])
	await Fixture.shoot(game, thorn, hostile)
	assert_eq(hostile.current_damage(), 3, 'fixture: a hit.')
	assert_eq(pick_prompts().size(), 0, 'No chip, no save, no reticle.')
	assert_eq(hostile.tile(), TARGET_TILE, 'Nobody moved.')

func test_a_hit_on_an_object_forces_nothing():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var crate:Unit = Fixture.create_object(game, Vector2i(8, 8))
	await press(crate, SAVE_FAILS, Vector2i(10, 8))
	assert_gt(crate.current_damage(), 0, 'fixture: the crate was hit.')
	assert_eq(pick_prompts().size(), 0, 'An object is not a "hostile character".')
	assert_eq(crate.tile(), Vector2i(8, 8), 'It stays.')

func test_a_hit_on_a_hostile_drone_forces_a_save():
	# A drone is a character (ruling 2026-09-27): it now qualifies for "a hostile character".
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var drone:Unit = Fixture.create_drone(game, Vector2i(8, 8))
	await press(drone, SAVE_FAILS, Vector2i(10, 8))
	assert_gt(drone.current_damage(), 0, 'fixture: the drone was hit.')
	assert_eq(pick_prompts().size(), 1, 'A drone is a hostile character: Rend\'s reticle opened.')
	assert_eq(drone.tile(), Vector2i(10, 8), 'Failed the save: shoved where the Thorn chose.')

func test_a_two_type_hit_forces_one_save():
	Fixture.equip(thorn, TWO_TYPE_RIFLE)
	responder.yesno_queue.append(true)
	responder.chosen_plan_queue.append(target_plan(hostile))
	responder.chosen_plan_queue.append(landing_plan(SHOVE_LANDING))
	responder.chosen_plan_queue.append(landing_plan(Vector2i(12, 6))) # a SECOND pick would take this
	Fixture.queue([D20_HITS, 4, 1, 2, 1, SAVE_FAILS, SAVE_FAILS]) # d20, two hit dice, two crit dice, then saves
	await Fixture.press_rend(game, thorn)
	assert_gt(hostile.current_damage(), 4, 'fixture: both types landed.')
	assert_eq(pick_prompts().size(), 1, 'TWO damage events, ONE save, ONE reticle (once per victim per attack).')
	assert_eq(hostile.tile(), SHOVE_LANDING, 'Shoved once.')

func test_an_interdiction_field_on_the_thorns_side_refuses_the_shove():
	# Teleport.shove is a target-tile move, so a MOVEMENT_RESTRICTION ban stops it (Sluagh ruling
	# 18). The Minotaur's field hung on the THORN: its check asks for a teleporting ENEMY mover
	# (buff_interdiction_field.gd:16-21), and a victim 4 away is outside FIELD_SIZE 3 - so the ban
	# is the doughnut: everything within 3 of the Thorn is off limits. The landing at (10,6) is 6
	# from the Thorn and legal; the victim at (8,6) is 4 from it. Move the Thorn to 2 from the
	# victim instead, so the lockdown branch bans every tile.
	Fixture.step(thorn, Vector2i(6, 6))
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), thorn, INTERDICTION_FIELD)
	await press(hostile, SAVE_FAILS, SHOVE_LANDING)
	assert_eq(pick_prompts().size(), 1, 'fixture: the save was forced and the reticle opened.')
	assert_true(offered_tiles().has(SHOVE_LANDING), 'fixture: the landing was offered, so only the MOVE was refused.')
	assert_eq(hostile.tile(), TARGET_TILE, 'A MOVEMENT_RESTRICTION ban stops the shove.')

func test_on_one_hit_vigil_teleports_first_and_rends_shove_second():
	# RULING 8, MEASURED (spec/test_spike_purple_thorn_sp1_seams.gd): the gear reaction runs before
	# the buff on one DAMAGE POST. So Vigil's move_tile reticle is raised BEFORE Rend's compcon_plan
	# pick, and the Thorn has already landed when the victim is shoved.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	responder.chosen_move_tile = VIGIL_LANDING
	await press(hostile, SAVE_FAILS, SHOVE_LANDING)
	assert_eq(thorn.tile(), VIGIL_LANDING, 'fixture: Vigil landed.')
	assert_eq(hostile.tile(), SHOVE_LANDING, 'fixture: the victim was shoved.')
	var kinds:Array[StringName] = []
	for prompt:Dictionary in watcher.prompts:
		if prompt.kind == PromptWatcher.KIND.move_tile: kinds.append(&'vigil')
		elif prompt.kind == PromptWatcher.KIND.compcon_plan and SpecificAction.is_valid(prompt.info.using) \
				and prompt.info.using.action.get_id() == Fixture.REND_ID: kinds.append(&'rend')
	assert_eq(kinds, [&'vigil', &'rend'] as Array[StringName], 'MEASURED ORDER: the trait\'s teleport, then the chip\'s shove.')

# ---------------------------------------------------------------- wiring and card text

func test_the_wiring_and_the_card_text():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_not_null(kit, 'fixture: the core Kit loads.')
	if kit == null: return
	var action = kit.get_action(Fixture.REND_ID)
	assert_not_null(action, 'action_rend is on it.')
	if action == null: return
	assert_true(action is ActionSystem, 'An ActionSystem...')
	assert_eq(action.action_type, Lancer.ACTION.QUICK, '...QUICK...')
	assert_true(action.consumes_cp, '...that consumes the core power.')
	assert_eq(action.usage_group, &'rend', 'Its own usage group.')
	assert_true(action.show_in_tooltip(kit), 'The active has its own text and draws on the core card.')
	var buff:Buff = action.chip
	assert_not_null(buff, 'It carries the chip.')
	if buff == null: return
	assert_eq(buff.compcon_id, Fixture.REND_CHIP, 'buff_cruel_and_unnatural.')
	assert_eq(buff.until, Lancer.UNTIL.END_OF_NEXT_TURN, '"Until the end of your next turn".')
	assert_false(buff.hide_from_player, 'VISIBLE.')
	assert_eq(buff.triggers_on, [&'damage'] as Array[StringName], 'A DAMAGE trigger...')
	assert_eq(buff.trigger_timing, ReactionBus.TIMING.POST, '...POST.')
	var translation:Translation = load(OUR_TRANSLATION)
	if translation == null:
		fail_test('This mod has a compiled translation.')
		return
	for key:String in ['gear.cp_lav_tactical_engine.action_rend.name', 'gear.cp_lav_tactical_engine.action_rend.effect',
			'gear.buff_cruel_and_unnatural.name', 'gear.buff_cruel_and_unnatural.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.cp_lav_tactical_engine.action_rend.name'), 'Rend That which is Cruel and Unnatural', 'Named as the card.')
	assert_true(X.tr('gear.cp_lav_tactical_engine.action_rend.effect').begins_with('You may immediately'), 'Opens as the card does.')
	assert_true(X.tr('gear.buff_cruel_and_unnatural.effect').begins_with('Until the end of your next turn'), 'The chip carries the second sentence.')
