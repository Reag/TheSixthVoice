# FORM OF THE MYRIAD - "Until the end of your turn, Gemini charge may be redirected 3 additional times, Line or
# Range is not reduced upon redirection and each character can only be targeted once. Choose a weapon you
# have mounted, you may attack with it as part of this action. Precision Venting can trigger any number of
# times until the end of your turn. This action is Efficient, and refunds 1 Core Power at the end of any
# scene in which it's used." Design 3, rulings 17-21.
#
# THE PROMPTS A PRESS RAISES, IN ORDER, and how each is answered:
#   1. The core power's confirm - a yes/no (CommonActionUtil.confirm_use); responder.yesno_queue.
#   2. The weapon chooser (choose_from_gear) - only when more than one weapon is offered, since
#      choose_and_use auto-picks a lone candidate; responder.gear_queue (an index, or null to cancel).
#   3. The chosen weapon's own targeting - responder.chosen_plan_queue.
#   4. Gemini Charge's yes/no at ATTACK_DECLARED PRE (first leg only, ruling 18) - responder.yesno_queue.
#   5. One proxy picker per leg - responder.chosen_plan_queue, in chain order. An aborted plan stops the
#      chain.
#
# LEG CAPTURES are measured inside each prompt (the proxy is gone the moment the pick returns - harness
# traps, Koremasa SP5), and a leg's capture is told from the weapon's own targeting by its origin: the
# weapon aims from the Knot's tile, every leg from the character it starts at.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/myriad.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_form_of_the_myriad.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')
const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')
const MyriadAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/action_form_of_the_myriad.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const MAP_SIZE := Vector2i(20, 16)
const KNOT_TILE := Vector2i(1, 4)
const CONTACT_TILE := Vector2i(4, 4) # 3 from the Knot
## THE FULL-REACH CHAIN. Every link is 9 from the one before it: past the 7 an unchipped Gemini would
## have left after the 3 to the contact, inside the rifle's full 10 (ruling 18, "not reduced").
const CHAIN_B := Vector2i(4, 13)
const CHAIN_C := Vector2i(13, 13)
const CHAIN_D := Vector2i(13, 4)
const CHAIN_E := Vector2i(4, 8)
## 3 from E: a fifth leg would reach it, and there must never be a fifth leg.
const CHAIN_F := Vector2i(7, 8)
## A short chain for the tests that are about something else: 3 apart.
const NEAR_B := Vector2i(4, 7)
const NEAR_C := Vector2i(7, 7)
## The rail's chain: the first line due east through the contact, then bent south, then bent east.
const LINE_AIM := Vector2i(11, 4)
const PAST_TILE := Vector2i(6, 4) # on the first line, past the contact: cut when it bends
const LINE_LEG_1_AIM := Vector2i(4, 14) # due south from the contact, the full 10
const LINE_B := Vector2i(4, 8) # the nearest character on the first leg: the next leg starts here
const LINE_X := Vector2i(4, 11) # also on the first leg, past B: CUT once leg 2 bends at B (ruling 18)
const LINE_LEG_2_AIM := Vector2i(14, 8) # due east from B, the full 10
const LINE_C := Vector2i(9, 8)
const LINE_Y := Vector2i(12, 8) # on leg 2, past C: HIT, because no leg bends at C (the third picker is cancelled)
const RESPAWN_TILE := Vector2i(10, 2)

const SIXES:Array[int] = [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]


var game:Gamemaster
var responder
var knot:Unit
var contact:Unit
## One entry per targeting prompt: { origin, reach, targetable, unscoped }.
var captures:Array[Dictionary] = []

func before_each() -> void:
	await get_tree().process_frame # a synchronous test's responder must be off the bus first
	var made:Array = Fixture.create_game_with_prompts(self, MAP_SIZE)
	game = made[0]
	responder = made[1]
	responder.plan_prompt.connect(_on_plan_prompt)
	captures.clear()
	knot = Fixture.create_knot(game, KNOT_TILE)
	Fixture.equip(knot, Fixture.RANGED)
	contact = Fixture.create_dummy(game, CONTACT_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func _on_plan_prompt(info:Dictionary) -> void:
	var using:SpecificAction = info.using
	if not SpecificAction.is_valid(using) or not Unit.is_valid(using.unit): return
	var original:Action = using.gear.get_solo_action()
	captures.append({
		origin = using.unit.tile(),
		reach = using.action.get_target_range(using),
		targetable = UnitTargeting.get_tiles_targetable(using),
		unscoped = UnitTargeting.get_tiles_targetable(SpecificAction.create(using.unit, using.gear, original)),
	})

## Only the legs: the weapon's own targeting aims from the Knot's tile.
func legs() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for capture:Dictionary in captures:
		if capture.origin != KNOT_TILE: found.append(capture)
	return found

func dummy(tile:Vector2i, evasion:int = 10) -> Unit:
	return Fixture.create_dummy(game, tile, evasion)

func plan_unit(unit:Unit) -> CompconPlan: return CompconPlan.create([unit.tile()], [], [unit])
func plan_tile(tile:Vector2i) -> CompconPlan: return CompconPlan.create([tile])

## Press Form of the Myriad. `plans` answer the weapon's targeting and then each leg, in order; `gears`
## answer the weapon chooser; `d20s` go first on the dice queue, a tail of sixes behind them.
func press(d20s:Array[int], plans:Array[CompconPlan], gears:Array = []) -> void:
	await Fixture.open_turn(game, knot)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, SIXES)
	responder.chosen_plan_queue.assign(plans)
	responder.gear_queue.assign(gears)
	await SpecFactory.use(game, knot, Fixture.CORE_ID, Fixture.MYRIAD_ACTION)

## A plain rifle shot in the same turn: AS_FREEBIE, because the per-turn soft limit refuses the same
## weapon twice in silence (harness traps, Primrose SP1).
func fire(target, d20s:Array[int], plans:Array[CompconPlan] = [], kit_id:StringName = Fixture.RANGED) -> void:
	await Fixture.open_turn(game, knot)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, SIXES)
	responder.chosen_plan_queue.assign(plans)
	await SpecFactory.use_solo(game, knot, kit_id, [target], [Action.FLAG.AS_FREEBIE])

func chip_held() -> bool: return UnitCondition.has_buff(knot, Fixture.MYRIAD_CHIP)

func myriad_action():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	if not Kit.is_valid(kit): return null
	for action:Action in kit.actions:
		if action.get_id() == Fixture.MYRIAD_ACTION: return action
	return null

func gear_ids(specifics:Array) -> Array[String]:
	var ids:Array[String] = []
	for specific in specifics: ids.append(String(specific.gear.kit.compcon_id))
	return ids


# ============ THE SHAPE (ruling 17) ============

func test_the_core_kit_carries_the_action_the_refund_and_the_stamp() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_true(Kit.is_valid(kit), 'The core system is in the kits index.')
	if not Kit.is_valid(kit): return
	var ids:Array[String] = []
	for action:Action in kit.actions: ids.append(String(action.get_id()))
	ids.sort()
	assert_eq(ids, ['action_efficient_refund', 'action_form_of_the_myriad'], 'The active and its Efficient refund.')
	var stamps:Array = kit.get_passives(PassiveDieCounter)
	assert_eq(stamps.size(), 1, 'The Efficient stamp passive: without it short_repair wipes the stamp.')
	if not stamps.is_empty(): assert_eq(stamps[0].key, Efficient.USED_KEY, 'Keyed on the stamp Efficient writes.')
	var applicators:Array = kit.get_passives(PassiveBuffApplicator)
	assert_eq(applicators.size(), 1, 'Gemini Charge\'s applicator is still there.')

	var action = myriad_action()
	assert_not_null(action, 'Form of the Myriad is on the core Kit.')
	if action == null: return
	assert_true(action is ActionSystem, 'A system action.')
	var specific := SpecificAction.create(knot, Fixture.core_gear(knot), action)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.FULL, 'A Full action.')
	assert_true(action.consumes_cp, 'It spends the core power.')
	assert_eq(action.usage_group, &'form_of_the_myriad', 'Its own usage group: it shares a Kit with a reaction.')

	var chip:Buff = ContentLibrary.get_buff(Fixture.MYRIAD_CHIP)
	assert_not_null(chip, 'The chip is in the buffs index.')
	if chip == null: return
	assert_false(chip.hide_from_player, 'A visible chip: the only sign the chain is live.')
	assert_eq(chip.until, Lancer.UNTIL.END_OF_THIS_TURN, '"Until the end of your turn".')

func test_the_rows_resolve_from_this_mods_own_translation() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	for key:String in [
		'gear.cp_integrated_redirection_aggregate.action_form_of_the_myriad.name',
		'gear.cp_integrated_redirection_aggregate.action_form_of_the_myriad.effect',
		'gear.buff_form_of_the_myriad.name',
		'gear.buff_form_of_the_myriad.effect',
	]:
		var text := String(translation.get_message(key))
		assert_true(text != '' and text != key, '%s resolves.' % key)


# ============ THE PRESS (rulings 17, 21) ============

func test_a_press_spends_the_core_power_stamps_efficient_and_raises_the_chip() -> void:
	assert_true(knot.core.has_core_power, 'Fixture: the core power is there to spend.')
	await press([14], [plan_unit(contact)])
	assert_gt(contact.current_damage(), 0, 'Guard: the Myriad attack landed.')
	assert_false(knot.core.has_core_power, 'The core power is spent.')
	assert_true(Efficient.is_marked(Fixture.core_gear(knot)), 'And stamped, so Efficient refunds it.')
	assert_true(chip_held(), 'The chip is up.')
	assert_eq(knot.state.actions, 0, 'A Full action: both actions are gone.')

func test_declining_the_confirm_costs_nothing() -> void:
	responder.yesno_queue.assign([false])
	await press([14], [plan_unit(contact)])
	assert_eq(responder.yesno_prompts.size(), 1, 'Asked.')
	assert_true(knot.core.has_core_power, 'Declined: the core power is kept.')
	assert_false(Efficient.is_marked(Fixture.core_gear(knot)), 'No stamp.')
	assert_false(chip_held(), 'No chip.')
	assert_eq(contact.current_damage(), 0, 'No attack.')
	# CONTROL: the same press, confirmed.
	await press([14], [plan_unit(contact)])
	assert_false(knot.core.has_core_power, 'CONTROL: confirmed, it is spent.')

# Pass E item 3 as the author settled it (T6, 2026-09-27): the press already writes the engine's own
# "used" line (spend_actions -> unit_action.gd:231-234 -> action.gd:132-137), so this PINS that line
# rather than adding text. Read off the bus, test_thermal_death_axe.gd's pattern.
func test_a_press_writes_the_used_line_to_the_battle_log() -> void:
	var action_name := X.tr('gear.cp_integrated_redirection_aggregate.action_form_of_the_myriad.name')
	assert_eq(action_name, 'Form of the Myriad', 'Fixture: the name resolves.')
	var lines:Array[String] = []
	var collect := func(text:String) -> void: lines.append(text)
	Action.battle_log.on_log_text.connect(collect)
	await press([14], [plan_unit(contact)])
	# UNCONDITIONAL, and before the assertions: the bus is an autoload that outlives this test.
	if Action.battle_log.on_log_text.is_connected(collect): Action.battle_log.on_log_text.disconnect(collect)
	assert_false(knot.core.has_core_power, 'Guard: the press went through.')
	assert_true(lines.any(func(text:String) -> bool: return text.contains(' used ') and text.contains(action_name)),
		'The press announced itself in the battle log: %s' % [lines])

func test_the_chooser_offers_every_mounted_weapon_attack_and_honours_the_pick() -> void:
	Fixture.equip(knot, Fixture.RANGED_2)
	Fixture.equip(knot, Fixture.LINE)
	var offered_before := gear_ids(MyriadAction.myriad_weapons(knot))
	assert_true(offered_before.has(String(Fixture.RANGED_2)), 'Fixture: the pistol is offered while intact.')
	knot.get_gear(Fixture.RANGED_2).is_destroyed = true
	var expected := gear_ids(MyriadAction.myriad_weapons(knot))
	assert_false(expected.has(String(Fixture.RANGED_2)), 'A destroyed weapon is not (is_gear_available).')
	assert_true(expected.has(String(Fixture.RANGED)) and expected.has(String(Fixture.LINE)), 'The rifle and the rail are.')
	var rail_index := expected.find(String(Fixture.LINE))
	assert_gt(rail_index, 0, 'Fixture: the rail is NOT the first entry, so honouring the pick is proved.')

	await press([14], [plan_tile(LINE_AIM)], [rail_index])
	assert_eq(responder.gear_prompts.size(), 1, 'One weapon chooser.')
	if responder.gear_prompts.is_empty(): return
	assert_eq(gear_ids(responder.gear_prompts[0].array), expected, 'It offers exactly those weapons\' attacks.')
	assert_eq(contact.current_damage(), 7, 'The rail fired: 1d6+1, unhalved (no one to redirect to).')

func test_cancelling_the_chooser_spends_the_power_and_keeps_the_chip_for_this_turn() -> void:
	Fixture.equip(knot, Fixture.RANGED_2)
	var b := dummy(NEAR_B)
	var c := dummy(NEAR_C)
	await press([14], [], [null])
	assert_eq(responder.gear_prompts.size(), 1, 'The chooser was offered.')
	assert_eq(contact.current_damage(), 0, 'Cancelled: no attack.')
	assert_false(knot.core.has_core_power, 'The core power is still spent.')
	assert_true(Efficient.is_marked(Fixture.core_gear(knot)), 'And stamped.')
	assert_true(chip_held(), 'The chip stands.')
	# CONTROL: the chip chains any other attack this turn.
	await fire(contact, [14], [plan_unit(b), plan_unit(c), CompconPlan.create_aborted()])
	assert_eq(b.current_damage(), 3, 'A later rifle shot this turn chains: the first leg.')
	assert_eq(c.current_damage(), 3, 'And the second.')

# "Choose a weapon you have mounted, you may attack with it" - ONE weapon. The Knot's own Main and Heavy
# mounts have no secondary slot, but Improved Armament's flex mount holds two Aux, and CAN_FOLLOWUP (a
# Skirmish's permission, copied from Rend) fired the second one free (close review 2026-09-26).
func test_the_myriad_fires_one_weapon_even_from_a_two_aux_mount() -> void:
	var armament:Kit = ContentLibrary.get_kit(&'cb_improved_armament')
	assert_true(Kit.is_valid(armament), 'Fixture: Improved Armament is in the kits index.')
	if not Kit.is_valid(armament): return
	knot.core.pilot.core_bonuses.append(armament)
	knot.core.full_repair_and_regenerate_loadout()
	var flex:MountCore = knot.core.loadout.mounts.back()
	flex.equip_primary(&'mw_pistol')
	flex.equip_secondary(&'mw_nexus_light')
	SpecFactory.apply_passive_buffs(knot)
	var pistol := knot.get_gear(&'mw_pistol')
	var nexus := knot.get_gear(&'mw_nexus_light')
	assert_true(GearCore.is_valid(pistol) and GearCore.is_valid(nexus), 'Fixture: two Aux weapons are mounted.')
	if not (GearCore.is_valid(pistol) and GearCore.is_valid(nexus)): return
	assert_eq(knot.core.loadout.get_mount_for_gear(nexus), knot.core.loadout.get_mount_for_gear(pistol), 'Fixture: on ONE mount.')
	var pistol_index := gear_ids(MyriadAction.myriad_weapons(knot)).find('mw_pistol')
	assert_gt(pistol_index, -1, 'Fixture: the pistol is offered.')
	await press([14, 14], [plan_unit(contact), plan_unit(contact)], [pistol_index])
	assert_gt(contact.current_damage(), 0, 'Guard: the pistol shot landed.')
	assert_eq(nexus.get_uses_this_turn(), 0, 'No free follow-up from the other Aux.')
	assert_eq(responder.plan_prompts.size(), 1, 'One targeting prompt: the pistol\'s.')


# ============ THE CHAIN (ruling 18) ============

func test_a_four_leg_chain_hits_five_characters_once_each_at_full_reach() -> void:
	var b := dummy(CHAIN_B)
	var c := dummy(CHAIN_C)
	var d := dummy(CHAIN_D)
	var e := dummy(CHAIN_E)
	var f := dummy(CHAIN_F)
	await press([14], [plan_unit(contact), plan_unit(b), plan_unit(c), plan_unit(d), plan_unit(e), plan_unit(f)])
	var found := legs()
	assert_eq(found.size(), 4, 'Four legs: "redirected 3 additional times".')
	assert_eq(responder.chosen_plan_queue.size(), 1, 'The fifth pick was never asked for.')
	for i:int in found.size():
		assert_eq(found[i].reach, 10, 'Leg %d has the rifle\'s full 10 ("not reduced").' % (i + 1))
	if found.size() == 4:
		assert_eq(found[0].origin, CONTACT_TILE, 'Leg 1 starts at the contact.')
		assert_eq(found[1].origin, CHAIN_B, 'Leg 2 at the character leg 1 reached.')
		assert_eq(found[2].origin, CHAIN_C, 'Leg 3 at the next.')
		assert_eq(found[3].origin, CHAIN_D, 'Leg 4 at the next.')
		assert_true(found[0].targetable.has(CHAIN_B), 'B, 9 from the contact, is offered: past the 7 left unchipped.')
		# EACH CHARACTER ONCE: the picker never offers someone already attacked. The control is the same
		# weapon from the same space, unscoped.
		assert_false(found[1].targetable.has(CONTACT_TILE), 'Leg 2 does not offer the contact.')
		assert_true(found[1].unscoped.has(CONTACT_TILE), 'CONTROL: unscoped, it would.')
		assert_false(found[2].targetable.has(CHAIN_B), 'Leg 3 does not offer B.')
		assert_true(found[2].unscoped.has(CHAIN_B), 'CONTROL: unscoped, it would.')
		assert_false(found[3].targetable.has(CHAIN_C), 'Leg 4 does not offer C.')
		assert_true(found[3].unscoped.has(CHAIN_C), 'CONTROL: unscoped, it would.')
	for unit:Unit in [contact, b, c, d, e]:
		assert_eq(unit.current_damage(), 3, '%s is hit once, halved: 3.' % unit.tile())
	assert_eq(f.current_damage(), 0, 'Nobody past the fourth leg.')
	assert_eq(responder.yesno_prompts.size(), 2, 'Two yes/nos: the press, and Gemini\'s first leg only.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'One Gemini use (ruling 18: its 1/round is not lifted).')

func test_cancelling_the_second_leg_stops_at_two_targets() -> void:
	var b := dummy(NEAR_B)
	var c := dummy(NEAR_C)
	await press([14], [plan_unit(contact), plan_unit(b), CompconPlan.create_aborted(), plan_unit(c)])
	assert_eq(legs().size(), 2, 'Two pickers: the second was cancelled.')
	assert_eq(contact.current_damage(), 3, 'The contact is hit.')
	assert_eq(b.current_damage(), 3, 'The first leg\'s character is hit.')
	assert_eq(c.current_damage(), 0, 'The chain stopped: nobody else.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'The committed leg spent the round.')

func test_without_the_chip_one_leg_only() -> void:
	var b := dummy(NEAR_B)
	var c := dummy(NEAR_C)
	await fire(contact, [14], [plan_unit(b), plan_unit(c)])
	assert_false(chip_held(), 'Fixture: no chip.')
	assert_eq(legs().size(), 1, 'One leg.')
	if not legs().is_empty(): assert_eq(legs()[0].reach, 7, 'At the remaining reach: 10 - 3.')
	assert_eq(b.current_damage(), 3, 'Redirected once.')
	assert_eq(c.current_damage(), 0, 'And no further.')
	assert_eq(responder.chosen_plan_queue.size(), 1, 'The second leg was never asked for.')

func test_a_line_chain_bends_at_each_leg() -> void:
	Fixture.equip(knot, Fixture.LINE)
	var knot_gears := MyriadAction.myriad_weapons(knot)
	var rail_index := gear_ids(knot_gears).find(String(Fixture.LINE))
	var past := dummy(PAST_TILE)
	var b := dummy(LINE_B)
	var x := dummy(LINE_X)
	var c := dummy(LINE_C)
	var y := dummy(LINE_Y)
	await press([14], [plan_tile(LINE_AIM), plan_tile(LINE_LEG_1_AIM), plan_tile(LINE_LEG_2_AIM), CompconPlan.create_aborted()], [rail_index])
	var found := legs()
	assert_eq(found.size(), 3, 'Two committed legs, and the third picker cancelled.')
	if found.size() >= 2:
		assert_eq(found[0].origin, CONTACT_TILE, 'Leg 1 bends at the contact.')
		assert_eq(found[0].reach, 10, 'With the full Line 10.')
		assert_eq(found[1].origin, LINE_B, 'Leg 2 bends at the NEAREST character on leg 1.')
		assert_eq(found[1].reach, 10, 'Also the full Line 10.')
	assert_eq(past.current_damage(), 0, 'Past the contact on the first line: cut.')
	assert_eq(x.current_damage(), 0, 'Past B on leg 1: cut, because the shot bends again at B (ruling 18, author 2026-09-26).')
	for unit:Unit in [contact, b, c, y]:
		assert_eq(unit.current_damage(), 4, '%s: 1d6+1 = 7, halved up to 4 (every character up to a bend is hit).' % unit.tile())


# ============ PRECISION VENTING (ruling 20) ============

func test_two_crits_in_one_myriad_attack_clear_two_heat_and_the_gate_returns_after_the_turn() -> void:
	var b := dummy(NEAR_B)
	Fixture.set_heat(knot, 3)
	await press([20], [plan_unit(contact), plan_unit(b), CompconPlan.create_aborted()])
	assert_gt(b.current_damage(), 0, 'Guard: the redirect landed.')
	assert_eq(Fixture.heat(knot), 1, 'Two crits (the contact\'s 20, and the shared face on B) clear 2.')

	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'The chip ends with the Knot\'s turn.')
	await Fixture.cycle_turn(game, knot)
	responder.chosen_yesnos = false # no redirects: two separate shots
	Fixture.set_heat(knot, 3)
	await fire(contact, [20])
	assert_eq(Fixture.heat(knot), 2, 'CONTROL: a crit next turn clears 1.')
	var before := contact.current_damage()
	await fire(contact, [20])
	assert_gt(contact.current_damage(), before, 'Guard: the second shot landed.')
	assert_eq(Fixture.heat(knot), 2, 'Without the chip, the second crit this round clears nothing.')

# Pass E (Lovers Knot item 1, AUTHOR: FIX): a vent under the chip does not count toward Precision
# Venting's 1/round, so a crit later the SAME round - a reaction shot after the chip has gone - still
# vents. The later shot is a freebie with no new turn: the Knot's round resets only at its own turn start.
func test_a_vent_under_the_chip_leaves_the_round_for_a_later_crit_that_round() -> void:
	Fixture.set_heat(knot, 3)
	await press([20], [plan_unit(contact)])
	assert_eq(Fixture.heat(knot), 2, 'Guard: the Myriad crit vented 1.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'A vent under the chip spends nothing of the round.')

	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'Fixture: the chip ended with the Knot\'s turn.')
	responder.chosen_yesnos = false # no redirect: one plain shot
	var before := contact.current_damage()
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([20], SIXES)
	await SpecFactory.use_solo(game, knot, Fixture.RANGED, [contact], [Action.FLAG.AS_FREEBIE])
	assert_gt(contact.current_damage(), before, 'Guard: the later shot landed.')
	assert_eq(Fixture.heat(knot), 1, 'Its crit still vents: the round was never spent.')


# ============ A SPENT GEMINI ROUND (ruling 19) ============

func test_a_spent_gemini_round_is_restored() -> void:
	var b := dummy(NEAR_B)
	var c := dummy(NEAR_C)
	await fire(contact, [14], [plan_unit(b)])
	assert_eq(b.current_damage(), 3, 'Fixture: an earlier shot redirected.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'Fixture: Gemini\'s round is spent.')
	await press([14], [plan_unit(contact), plan_unit(c), CompconPlan.create_aborted()])
	assert_eq(c.current_damage(), 3, 'The Myriad attack redirects all the same.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'And the round is spent again.')
	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'Fixture: the chip is gone.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'Spent by the Myriad attack, so the chip\'s expiry does not stamp it twice.')

# Ruling 19 as Pass E fixed it (Lovers Knot item 4, AUTHOR): the Myriad's turn keeps its two Geminis,
# but a round the Myriad restored and then left unused is spent again when the chip expires - no extra
# reaction Gemini later that round.
func test_a_restored_gemini_round_is_spent_again_when_the_chip_expires() -> void:
	Fixture.equip(knot, Fixture.RANGED_2) # two weapons, so the chooser is offered and can be cancelled
	var b := dummy(NEAR_B)
	await fire(contact, [14], [plan_unit(b)])
	assert_eq(b.current_damage(), 3, 'Fixture: an earlier shot redirected.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'Fixture: Gemini\'s round is spent.')
	await press([14], [], [null])
	assert_true(chip_held(), 'Fixture: the chip is up, the Myriad attack cancelled.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'The Myriad restored the spent round for its turn.')
	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'Fixture: the chip ended with the Knot\'s turn.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'The chip\'s expiry spends the restored round again.')

# Pass F final review (vanilla bug, reports/2026-09-27-map-state-source-lookup.md): on_clear used to
# find the core gear through MapState.get_gear_by_id, which returns null the moment ANY unit earlier
# in the map's unit list than the Knot carries a buff with situational gear - the search stops at
# that unit's buff loop and never reaches the Knot's own loadout. A decoy dummy is given a throwaway
# situational-gear buff and pushed ahead of the Knot in the tree's unit list (the same technique
# test_makibishi_magnets.gd's simulate_load_with_victim_first uses), with the source cache cleared as
# it is after every load (map_state.gd:102). Fixed by reading the chip holder's own loadout directly
# (buff_form_of_the_myriad.gd's on_clear), since the chip's holder IS the owner here.
func test_the_chip_still_restamps_when_a_situational_gear_buff_precedes_the_knot_in_the_unit_list() -> void:
	Fixture.equip(knot, Fixture.RANGED_2) # two weapons, so the chooser is offered and can be cancelled
	var b := dummy(NEAR_B)
	var decoy := dummy(NEAR_C)
	# ANY buff with valid situational_gear trips the bug; its own compcon_id and semantics are unused -
	# but it must be MANUAL (not END_OF_THIS_TURN, which the Knot's own turn end would clear it as too,
	# hiding the trap before the chip's own on_clear ever runs). buff_makibishi_attached is MANUAL.
	var decoy_buff:Buff = ContentLibrary.get_buff(&'buff_makibishi_attached')
	var decoy_core := BuffCore.create(decoy_buff, &'')
	decoy_core.situational_gear = GearCore.create_from_id(Fixture.RANGED)
	decoy.state.buffs.append(decoy_core)

	await fire(contact, [14], [plan_unit(b)])
	assert_eq(b.current_damage(), 3, 'Fixture: an earlier shot redirected.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'Fixture: Gemini\'s round is spent.')
	await press([14], [], [null])
	assert_true(chip_held(), 'Fixture: the chip is up, the Myriad attack cancelled.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'Fixture: the Myriad restored the spent round for its turn.')

	# Push the decoy ahead of the Knot in the tree's own unit list, and clear the source cache the
	# way a load leaves it (map_state.gd:102) - the same reordering test_makibishi_magnets.gd uses.
	var tree_units = game.map_node.units
	tree_units.erase(knot)
	tree_units.append(knot)
	game.map.update_unit_tile_tracking(game.map_node.get_all_units_in_tree())
	game.map.cached_source_to_unit.clear()
	var order:Array = game.map.all_units.keys()
	assert_lt(order.find(decoy.core.persistent_id), order.find(knot.core.persistent_id), 'fixture: the decoy is listed first.')
	assert_null(game.map.get_gear_by_id(Fixture.core_gear(knot).persistent_id),
		'Guard: this alone reproduces the vanilla bug - the engine\'s own lookup finds nothing.')

	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'Fixture: the chip ended with the Knot\'s turn.')
	assert_eq(Fixture.gemini_uses(knot), 1, 'The chip\'s expiry still re-stamps the round, despite the decoy.')

func test_a_myriad_turn_with_no_earlier_gemini_leaves_the_round_open() -> void:
	Fixture.equip(knot, Fixture.RANGED_2)
	await press([14], [], [null])
	assert_true(chip_held(), 'Fixture: the chip is up.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'Fixture: no Gemini this round.')
	await SpecFactory.end_turn(game, knot)
	assert_false(chip_held(), 'Fixture: the chip ended with the Knot\'s turn.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'CONTROL: nothing was restored, so nothing is spent at expiry.')


# ============ EFFICIENT (ruling 17) ============

## A mech arriving in the NEXT SCENE, built the way the campaign builds one (test_efficient.gd's
## spawn_into_next_scene, whose header explains the remove and the fresh id).
func spawn_into_next_scene(from:Unit) -> Unit:
	var saved:Dictionary = from.core.serialize()
	from.remove_from_game()
	var core := UnitCore.deserialize(saved)
	core.persistent_id = Util.generate_random_hexcode()
	var arriving := Unit.create(core)
	await game.execute_event('event_unit_spawn', {unit = arriving, target_tiles = [RESPAWN_TILE]})
	return arriving

func test_a_used_myriad_is_refunded_when_the_knot_spawns_into_the_next_scene() -> void:
	await press([14], [plan_unit(contact)])
	assert_false(knot.core.has_core_power, 'Fixture: spent.')
	var arriving := await spawn_into_next_scene(knot)
	assert_true(arriving.core.has_core_power, 'The next scene starts with the point back.')
	assert_false(Efficient.is_marked(arriving.get_gear(Fixture.CORE_ID)), 'And the stamp cleared.')

## LAST IN THE FILE, for test_efficient.gd's reason: event_combat_end emits campaign_bus.end_level.
func test_a_used_myriad_is_refunded_at_combat_end() -> void:
	await press([14], [plan_unit(contact)])
	assert_false(knot.core.has_core_power, 'Fixture: spent.')
	await game.execute_event('event_combat_end',
		{boolean = true, flags = [EventService.COMBAT_END_FLAG.SKIP_BANNER]})
	assert_true(knot.core.has_core_power, 'The scene ended and the point came back.')
	assert_false(Efficient.is_marked(Fixture.core_gear(knot)), 'And the stamp cleared.')
