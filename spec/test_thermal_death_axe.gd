# THE THERMAL DEATH AXE (Leoleth rank II, SP3 Task 1) - design ruling 15, sheet 09-leoleth.md.
#
#   "Heavy Melee | SP 1 | LIMITED 1, HEAT SELF 1
#    You may attack with this weapon without expending or requiring charges, and this weapon can be
#    destroyed even if it has no charges remaining. You may spend 1 charge to use the 'Thunderous'
#    profile when making an attack. At the end of your turn, this weapon gains 1 charge if you have
#    at least 4 spaces of unspent movement.
#    Standard: 1d6+2 Kinetic, Threat 2.   Thunderous: 2d6+2 Energy, Threat 2, AP."
#
# TWO PROFILES ARE TWO ActionAttackWeapons ON ONE KIT sharing usage_group &"thermal_death_axe"
# (attack-pipeline memory: a multi-profile weapon is several actions on one Kit). Standard overrides
# consumes_charges -> false (both halves of "without expending or requiring", unit_action.gd:153 and
# :274); Thunderous is SCRIPTLESS - the Action default is consumes_charges true, and the same two
# engine lines are exactly "spend 1 charge to use" (refused with REASON.NO_CHARGES at zero).
#
# THE RECHARGE is a hidden ActionReactionSelf on end_turn PRE (Toe To Toe's timing, and for the same
# reason: handle_ending_unit zeroes current.speed at event_turn_end.gd:70, after the PRE block at
# :15-17). "4 spaces of unspent movement" is current.speed >= 4 - the pooled budget ruling 2 reads.
#
# DESTRUCTIBLE AT ZERO lives in res/engine/character/unit/service/unit_printer.gd_ext.gd, probed by
# spec/test_spike_unit_printer_seam.gd; here it is asserted on the REAL Kit, and against a vanilla
# Limited weapon that must stay refused.
#
# TOE TO TOE IS ON THIS FRAME AND FIRES ON THE SAME TRIGGER AND TIMING, which is not a footnote here
# the way it would be on any other weapon: the axe IS an eligible melee weapon for the free Skirmish
# (Heavy MELEE is QUICK - action_attack_weapon.gd:87-91), so every end_turn in the recharge section
# would otherwise pop an unqueued attack roll and, worse, could swing the THUNDEROUS profile and
# spend the very charge under test. Each recharge case therefore steps the target out to FAR_TILE
# first, which shuts Toe To Toe's reach clause exactly as test_toe_to_toe.gd's own movement-gate
# cases do (its test_a_melee_weapon_with_nothing_in_reach_is_not_offered measures that clause). The
# one case that deliberately runs BOTH reactions in one end_turn is at the bottom of that section,
# and it pins the design's "order does not matter" claim.
#
# DICE. A swing pops a d20; the Leoleth's melee attacks carry no accuracy modifier of their own (the
# 43 As penalises only non-melee), so no accuracy die. Damage dice are cheated too so the numbers
# read: Standard 1d6+2 -> [d20, d6]; Thunderous 2d6+2 -> [d20, d6, d6]. The dummy is 200 HP, armor 0
# (leoleth_fixture.create_dummy), so every number asserted is the card's.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_thermal_death_axe.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

var game:Gamemaster
var leoleth:Unit
var target:Unit
var axe:GearCore

const LEOLETH_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(6, 4)   # 2 out: inside Threat 2, outside Threat 1
const ADJACENT_TILE := Vector2i(5, 4) # 1 out: inside a Threat 1 blade's reach too
## Out of reach of any melee weapon, which is what shuts Toe To Toe's offer for the recharge cases.
const FAR_TILE := Vector2i(16, 4)

## The card's number, literally: "at least 4 spaces of unspent movement".
const UNSPENT_SPACES_REQUIRED := 4

func before_each():
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, TARGET_TILE)
	axe = LeolethFixture.arm_axe(leoleth)

func after_each():
	Dice.CHEAT_ROLL_QUEUE.clear()

func _standard() -> ActionAttackWeapon:
	for action:Action in axe.kit.actions:
		if action.get_id() == LeolethFixture.TDA_STANDARD: return action
	return null

func _thunderous() -> ActionAttackWeapon:
	for action:Action in axe.kit.actions:
		if action.get_id() == LeolethFixture.TDA_THUNDEROUS: return action
	return null

func _recharge() -> Action:
	for action:Action in axe.kit.actions:
		if action.get_id() == LeolethFixture.TDA_RECHARGE: return action
	return null

func _specific(profile:StringName) -> SpecificAction:
	var action:Action = _standard() if profile == LeolethFixture.TDA_STANDARD else _thunderous()
	return SpecificAction.create(leoleth, axe, action)

## REASON.NONE - the charge gate and every other blanket refusal, and NOT the repeat-action rule.
## UnitAction.is_gear_available is get_gear_unavailable_reason == NONE (unit_action.gd:162-163) and
## that chain never asks is_under_per_turn_limit, which lives one level up in can_activate_gear
## (:114). So this is the right predicate for "Thunderous needs a charge" and the WRONG one for
## "the profiles share a use" - see _under_per_turn_limit below.
func _available(profile:StringName) -> bool:
	return UnitAction.is_gear_available(_specific(profile))

## The repeat-action rule itself: gear.get_uses_this_turn(action) < action.get_per_turn_soft_limit
## (unit_action.gd:167-168), tallied per USAGE GROUP (gear_core.gd:183-188). Asked directly rather
## than through can_activate_gear, which would also answer true for a mech that could pay by
## overcharging (:117-118) and so could not say whether the group was spent.
func _under_per_turn_limit(profile:StringName) -> bool:
	return UnitAction.is_under_per_turn_limit(_specific(profile))

## Open the Leoleth's turn with a hit queued: [d20 19, then `damage` dice], no RAGE (never pressed).
##
## THE TURN START ITSELF POPS NOTHING on this frame - no Kit here declares recharge_on and RAGE is
## never pressed - so whatever the queue holds when this returns is what the swing will draw from.
func _open_turn_with_hit(damage_dice:Array[int]) -> void:
	if leoleth.state.is_taking_turn: await SpecFactory.end_turn(game, leoleth)
	var rolls:Array[int] = [19]
	rolls.append_array(damage_dice)
	LeolethFixture.queue(rolls)
	await SpecFactory.start_turn(game, leoleth)

## Put the target beyond every melee weapon's threat, so Toe To Toe offers nothing at end_turn and
## the only END_TURN PRE reaction left is the recharge under test.
func _silence_toe_to_toe() -> void:
	LeolethFixture.step(target, FAR_TILE)

# ---------------------------------------------------------------- the card's printed numbers

func test_the_kit_is_registered_with_the_cards_stats():
	var kit := ContentLibrary.get_kit(LeolethFixture.TDA_ID)
	assert_not_null(kit, '%s loads through ContentLibrary.' % LeolethFixture.TDA_ID)
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.charges_max, 1, 'LIMITED 1.')
	assert_eq(kit.actions.size(), 3, 'Two profiles and the recharge reaction.')
	assert_true(kit.is_destructable(), 'A destructible Kit shape (not a trait, not tagged indestructible).')

func test_the_standard_profile_is_a_heavy_melee_kinetic_swing():
	var action := _standard()
	assert_not_null(action, 'action_tda_standard is on the Kit.')
	if action == null: return
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'Heavy.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(action.damage_dice, '1d6+2', '1d6+2.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(action.threat, 2, 'Threat 2.')
	assert_eq(action.self_heat_dice, '1', 'HEAT SELF 1.')
	assert_true(action.tags.is_empty(), 'No tags on Standard.')
	assert_eq(action.usage_group, LeolethFixture.TDA_USAGE_GROUP, 'Shares the usage group.')
	assert_false(action.consumes_charges(_specific(LeolethFixture.TDA_STANDARD)),
		'"without expending or requiring charges".')

func test_the_thunderous_profile_is_a_heavy_melee_energy_ap_swing():
	var action := _thunderous()
	assert_not_null(action, 'action_tda_thunderous is on the Kit.')
	if action == null: return
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.HEAVY, 'Heavy.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(action.damage_dice, '2d6+2', '2d6+2.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.ENERGY, 'Energy.')
	assert_eq(action.threat, 2, 'Threat 2.')
	assert_eq(action.self_heat_dice, '1', 'HEAT SELF 1.')
	assert_eq(action.tags, [&'ap'] as Array[StringName], 'AP.')
	assert_eq(action.usage_group, LeolethFixture.TDA_USAGE_GROUP, 'Shares the usage group.')
	assert_true(action.consumes_charges(_specific(LeolethFixture.TDA_THUNDEROUS)),
		'"spend 1 charge to use" - the Action default, no script.')

func test_the_recharge_is_a_hidden_end_turn_pre_reaction():
	var action := _recharge()
	assert_not_null(action, 'action_tda_recharge is on the Kit.')
	if action == null: return
	assert_true(action is ActionReactionSelf, 'An ActionReactionSelf.')
	if not (action is ActionReactionSelf): return
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.END_TURN] as Array[StringName], 'end_turn.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE, 'PRE - before speed is zeroed.')
	assert_false(action.consumes_rxn, 'Point-free.')
	assert_false(action.show_in_tooltip(axe.kit), 'Hidden: the Kit\'s effect row IS the card.')
	# CHARGE-FREE, and it is load-bearing rather than tidy: ReactionBus asks can_activate_gear
	# BEFORE triggers_on_event (reaction_bus.gd:119-124), so the Action default of true would have
	# unit_action.gd:153 refuse this reaction with REASON.NO_CHARGES in the only state it exists for.
	assert_false(action.consumes_charges(SpecificAction.create(leoleth, axe, action)),
		'It spends no charge - which is also the only way it can ever fire on an empty axe.')

func test_the_card_text_renders_rather_than_a_raw_key():
	for key:String in [
		'gear.mw_thermal_death_axe.name', 'gear.mw_thermal_death_axe.flavor',
		'gear.mw_thermal_death_axe.effect',
		'gear.mw_thermal_death_axe.action_tda_standard.name',
		'gear.mw_thermal_death_axe.action_tda_thunderous.name',
		'gear.mw_thermal_death_axe.action_tda_recharge.log',
	]:
		assert_ne(tr(key), key, '%s resolves.' % key)
	assert_eq(tr('gear.mw_thermal_death_axe.name'), 'Thermal Death Axe', 'The name.')
	assert_string_contains(tr('gear.mw_thermal_death_axe.effect'),
		'without expending or requiring charges', 'The effect paragraph is the card\'s.')

func test_the_two_profiles_are_named_apart_on_the_gear_bar():
	# Two buttons on one Kit, and Translate's fallback (translate.gd:73-76) would otherwise render
	# both of them "Thermal Death Axe" - the Rend Axe precedent.
	var standard:String = tr('gear.mw_thermal_death_axe.action_tda_standard.name')
	var thunderous:String = tr('gear.mw_thermal_death_axe.action_tda_thunderous.name')
	assert_ne(standard, thunderous, 'The two profiles do not share a label.')
	assert_string_contains(thunderous, 'Thunderous', 'And the charged one says so.')

# ---------------------------------------------------------------- charges

func test_it_starts_with_one_charge():
	assert_eq(axe.charges_current, 1, 'charges_max = 1, and full_repair fills it.')

func test_standard_swings_at_zero_charges_and_spends_none():
	axe.charges_current = 0
	assert_true(_available(LeolethFixture.TDA_STANDARD), '"without requiring charges".')
	await _open_turn_with_hit([3])
	# READ, NOT HARD-CODED: queue() lays the given rolls plus a tail whose length is the fixture's
	# business, so a literal here would go red the day that tail changes and say nothing about the axe.
	var dice_before:int = Dice.CHEAT_ROLL_QUEUE.size()
	var hp := target.core.current.health
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_STANDARD, target)
	assert_eq(target.core.current.health, hp - 5, 'It landed: 3 + 2 kinetic against armor 0.')
	assert_eq(axe.charges_current, 0, '"without expending charges".')
	# THREE POPS, NOT TWO, and it is the engine rather than the weapon: AttackUtil rolls the damage
	# dice TWICE - once for the hit column and once for the crit column (attack_util.gd:250-251) -
	# and sums the first N or the highest N of the pooled rolls (:256-257). So 1d6+2 costs a d20 and
	# two d6. HEAT SELF "1" costs nothing at all: process_dice_string parses a bare number as a
	# BONUS with count 0 (dice.gd:112-113), and roll_dice loops count times.
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), dice_before - 3,
		'Only the d20 and the two damage-column d6 were popped.')

func test_thunderous_is_refused_at_zero_charges():
	axe.charges_current = 0
	assert_false(_available(LeolethFixture.TDA_THUNDEROUS), 'REASON.NO_CHARGES (unit_action.gd:153).')
	assert_eq(UnitAction.get_gear_unavailable_reason(_specific(LeolethFixture.TDA_THUNDEROUS)),
		UnitAction.REASON.NO_CHARGES, 'And it is the charge that refuses it, not something else.')
	axe.charges_current = 1
	assert_true(_available(LeolethFixture.TDA_THUNDEROUS), 'Available with the charge.')

func test_thunderous_spends_the_charge_and_deals_energy_through_armor():
	target.core.frame.stat.armor = 2
	target.core.full_repair()
	await _open_turn_with_hit([4, 4])
	var hp := target.core.current.health
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_THUNDEROUS, target)
	assert_eq(target.core.current.health, hp - 10, '4 + 4 + 2 energy, AP: armor 2 subtracts nothing.')
	assert_eq(axe.charges_current, 0, '"spend 1 charge".')

func test_standard_is_reduced_by_armor():
	target.core.frame.stat.armor = 2
	target.core.full_repair()
	await _open_turn_with_hit([3])
	var hp := target.core.current.health
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_STANDARD, target)
	assert_eq(target.core.current.health, hp - 3, '5 kinetic minus armor 2: Standard is not AP.')

func test_each_swing_costs_one_heat():
	await _open_turn_with_hit([3])
	var heat := leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_STANDARD, target)
	assert_eq(leoleth.core.current.heat, heat + 1, 'HEAT SELF 1 on Standard.')
	await _open_turn_with_hit([4, 4])
	heat = leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_THUNDEROUS, target)
	assert_eq(leoleth.core.current.heat, heat + 1, 'HEAT SELF 1 on Thunderous.')

func test_a_miss_spends_the_charge_anyway():
	# The charge buys the PROFILE, not the hit: unit_action.gd:274 spends at activation.
	LeolethFixture.cheat_a_miss()
	await LeolethFixture.swing_axe(game, leoleth, target, LeolethFixture.TDA_THUNDEROUS)
	assert_eq(target.current_damage(), 0, 'fixture: it really missed.')
	assert_eq(axe.charges_current, 0, 'Spent on the swing, hit or miss.')

# ---------------------------------------------------------------- one Skirmish per turn

func test_the_two_profiles_share_one_use_per_turn():
	await _open_turn_with_hit([3])
	assert_true(_under_per_turn_limit(LeolethFixture.TDA_THUNDEROUS), 'fixture: both start unspent.')
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_STANDARD, target)
	assert_eq(axe.get_uses_this_turn(_thunderous()), 1,
		'The usage group counts the Standard swing against Thunderous too (gear_core.gd:183-188).')
	assert_false(_under_per_turn_limit(LeolethFixture.TDA_THUNDEROUS),
		'And Thunderous is spent for the turn.')
	assert_false(_under_per_turn_limit(LeolethFixture.TDA_STANDARD), 'So is Standard.')
	assert_true(_available(LeolethFixture.TDA_THUNDEROUS),
		'The repeat-action rule and nothing else: the charge is still there.')

# ---------------------------------------------------------------- the free-Skirmish offer

## Toe To Toe's reaction off the LIVE frame's gear, exactly as spec/test_toe_to_toe.gd reaches it.
func _toe_to_toe() -> ActionReactionSelf:
	var gear:GearCore = leoleth.get_gear(LeolethFixture.TOE_TO_TOE_ID)
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == LeolethFixture.TOE_TO_TOE_ACTION: return action
	return null

## What the free Skirmish would put in its pick menu right now, as ACTION ids rather than Kit ids -
## the whole question here is which PROFILE of one Kit is offered.
func _toe_to_toe_offer() -> Array[StringName]:
	var ids:Array[StringName] = []
	var action := _toe_to_toe()
	if action == null: return ids
	for specific:SpecificAction in action.eligible_attacks(leoleth): ids.append(specific.action.get_id())
	return ids

func test_toe_to_toe_offers_only_the_profiles_that_can_actually_swing():
	# THE AXE IS THE FIRST WEAPON ON THIS FRAME WITH A PROFILE THAT CAN BE INDIVIDUALLY UNAVAILABLE,
	# and Toe To Toe's eligible_attacks is what fills the pick menu. Its melee / QUICK / usage-group /
	# reach clauses all pass for an EMPTY Thunderous, so without an availability clause the end of the
	# turn raises a two-entry menu whose second entry the engine then refuses: choosing it reaches
	# event_gear_activate.gd:46-50, which logs [ Gear not available ] reason : NO_CHARGES and drops the
	# free Skirmish altogether. The offer has to agree with UnitAction about what can swing.
	assert_not_null(_toe_to_toe(), 'fixture: the frame carries Toe To Toe.')
	if _toe_to_toe() == null: return
	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(),
		'fixture: nothing moved, so the gate itself is open.')

	axe.charges_current = 1
	var charged := _toe_to_toe_offer()
	assert_true(charged.has(LeolethFixture.TDA_STANDARD), 'Charged: Standard is offered...')
	assert_true(charged.has(LeolethFixture.TDA_THUNDEROUS), '...and so is Thunderous.')

	axe.charges_current = 0
	assert_eq(_toe_to_toe_offer(), [LeolethFixture.TDA_STANDARD] as Array[StringName],
		'Empty: exactly Standard - Thunderous cannot swing, so it is not offered.')

# ---------------------------------------------------------------- the recharge

func test_a_turn_ending_with_four_unspent_spaces_regains_the_charge():
	_silence_toe_to_toe()
	axe.charges_current = 0
	await SpecFactory.start_turn(game, leoleth)
	assert_eq(leoleth.get_speed_max(), UNSPENT_SPACES_REQUIRED,
		'fixture: this frame\'s speed max IS the card\'s 4, so the two arithmetics below line up.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'fixture: speed 4, full.')
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(axe.charges_current, 1, '"gains 1 charge if you have at least 4 spaces of unspent movement".')

func test_a_turn_ending_with_three_unspent_spaces_does_not():
	_silence_toe_to_toe()
	axe.charges_current = 0
	await SpecFactory.start_turn(game, leoleth)
	await LeolethFixture.walk(game, leoleth, LEOLETH_TILE + Vector2i(0, 1)) # one step: 4 -> 3
	assert_eq(leoleth.core.current.speed, 3, 'fixture: one space spent.')
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(axe.charges_current, 0, 'Three is not "at least 4".')

func test_a_boost_keeps_the_budget_over_four():
	# Boost adds a speed max to the same pool (event_unit_boost.gd:37); 4 + 4 - 1 step = 7 >= 4. The
	# card counts the BUDGET, not "did you move" - which is what this case discriminates against a
	# naive spaces_moved_this_turn == 0 reading.
	_silence_toe_to_toe()
	axe.charges_current = 0
	await SpecFactory.start_turn(game, leoleth)
	await SpecFactory.use_solo(game, leoleth, &'ms_boost')
	await LeolethFixture.walk(game, leoleth, LEOLETH_TILE + Vector2i(0, 1))
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() * 2 - 1,
		'fixture: boosted to 8 and one space spent.')
	assert_gt(leoleth.state.spaces_moved_this_turn, 0, 'fixture: and it really did move.')
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(axe.charges_current, 1, 'Unspent budget, boosted or not, is what the card counts.')

func test_a_full_axe_does_not_overflow():
	_silence_toe_to_toe()
	assert_eq(axe.charges_current, 1, 'fixture: full.')
	await SpecFactory.start_turn(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(axe.charges_current, 1, 'Capped at charges_max.')

## The recharge's gate, polled against a real END_TURN event core - test_toe_to_toe.gd's gate_open()
## idiom, and here for a second reason on top of its own: this reaction's cap lives in activate(),
## which returns QUIETLY, so no outcome assertion can tell "the gate refused to collect it" from "it
## was collected and had nothing to do".
func _recharge_gate_open() -> bool:
	var action := _recharge()
	if action == null: return false
	return action.triggers_on_event(leoleth, axe, EventCore.create(&'event_turn_end', {unit = leoleth}))

func test_the_recharge_gate_reads_speed_alone_and_not_the_charge():
	# WHY THE CAP CANNOT BE A CLAUSE HERE. Every END_TURN PRE reaction is COLLECTED in one pass and
	# only then executed (event_core.gd:52-55), and in production Toe To Toe is collected first - it
	# is a frame TRAIT and a Heavy Melee weapon is MOUNTED, which is get_all_gear()'s order
	# (loadout_core.gd:291-296, :511-518). So a cap read HERE is read against the axe as it stood
	# before the free Skirmish: a full axe would never be collected, the Skirmish would spend the
	# charge, and the turn would end empty. The cap moved into activate(); the gate is the card's
	# movement clause and nothing else.
	_silence_toe_to_toe()
	await SpecFactory.start_turn(game, leoleth)
	assert_eq(axe.charges_current, 1, 'fixture: the axe is FULL.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'fixture: nothing is spent.')
	assert_true(_recharge_gate_open(),
		'A full axe is still COLLECTED - the charge it holds now says nothing about the charge it will hold.')

	await LeolethFixture.walk(game, leoleth, LEOLETH_TILE + Vector2i(0, 1)) # one step: 4 -> 3
	assert_eq(leoleth.core.current.speed, 3, 'fixture: one space spent.')
	assert_false(_recharge_gate_open(), 'And three is still not "at least 4".')

func test_the_recharge_is_logged():
	# The battle log is the ONLY player-facing trace of a hidden reaction, so it is read off the bus
	# rather than only asserted to resolve: an unresolved key would reach the player as the raw key
	# with every other assertion in this file still green.
	_silence_toe_to_toe()
	axe.charges_current = 0
	var lines:Array[String] = []
	var collect := func(text:String) -> void: lines.append(text)
	Action.battle_log.on_log_text.connect(collect)
	await SpecFactory.start_turn(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	# UNCONDITIONAL, and before the assertions: the bus is an autoload that outlives this test, so a
	# lambda left connected by an early assertion failure would keep appending into a freed test's
	# array for the rest of the run.
	if Action.battle_log.on_log_text.is_connected(collect): Action.battle_log.on_log_text.disconnect(collect)
	assert_eq(axe.charges_current, 1, 'fixture: it recharged.')
	assert_true(lines.any(func(text:String) -> bool: return text.contains('regains a charge on')),
		'The recharge announced itself in the battle log, in real text: %s' % [lines])

func test_the_recharge_fires_beside_toe_to_toe_in_the_same_end_turn():
	# TWO END_TURN PRE REACTIONS ON ONE UNIT, IN THE **RECHARGE-FIRST** ORDER. Which order this is, is
	# not a detail: the batch is collected in get_all_gear() order - attacks, systems, TRAITS, mounts
	# (loadout_core.gd:291-296, :511-518) - and arm_axe equips the axe as a SYSTEM, so here the
	# recharge is collected and executed BEFORE the trait's free Skirmish. The production order is the
	# other one (a Heavy Melee weapon is MOUNTED), and
	# test_a_mounted_full_axe_recharges_after_toe_to_toe_swings_thunderous measures that.
	#
	# In this order the two are genuinely independent, which is what this case pins: a Skirmish never
	# touches current.speed, so the recharge's gate reads the same number either way.
	#
	# THE BLADE, NOT THE AXE, is what Toe To Toe offers here, and that is arranged rather than hoped:
	# the axe is swung first, which puts 1 on its usage group and takes BOTH its profiles out of
	# eligible_attacks (action_toe_to_toe.gd's "has not been used this turn" clause). Without that the
	# free Skirmish could pick Thunderous and spend the very charge under test.
	LeolethFixture.arm_melee(leoleth) # equip BEFORE zeroing: equip() full_repairs and would refill
	axe.charges_current = 0
	LeolethFixture.step(target, ADJACENT_TILE) # in reach of the Threat 1 blade as well as the axe
	await _open_turn_with_hit([3])
	await SpecFactory.use(game, leoleth, LeolethFixture.TDA_ID, LeolethFixture.TDA_STANDARD, target)
	var hp := target.core.current.health
	assert_eq(axe.get_uses_this_turn(_standard()), 1, 'fixture: the axe is spent for the turn.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(), 'fixture: nothing moved.')

	LeolethFixture.queue([19, 3])
	await SpecFactory.end_turn(game, leoleth)

	assert_lt(target.core.current.health, hp, 'Toe To Toe\'s free Skirmish landed...')
	assert_eq(axe.charges_current, 1, '...and the recharge fired in the same PRE block.')

## Answers Toe To Toe's weapon-pick menu with a NAMED profile instead of the first one.
##
## THE STOCK RESPONDER CANNOT DO THIS, and its knob for multiple choices is the wrong knob.
## CommonActionUtil.choose_and_use raises a ChoiceBus.TYPE.gear request whenever a player-controlled
## unit has more than one option (common_action_util.gd:658-676), and SpecFactory's
## ChoiceBusResponder.choose_gear answers it with request.params.array[0], unconditionally
## (spec_factory.gd:518-525). array[0] is Standard, because eligible_attacks walks kit.actions in
## order. chosen_multiple_choice_index belongs to ChoiceBus.TYPE.brochure (spec_factory.gd:527-533)
## and is never consulted for a gear pick.
##
## So the test switches the stock responder's gear branch off -
## `SpecFactory.current_responder.choose_gears = false`, the same idiom test_bleakshadow_gate.gd and
## test_compat.gd use for yesnos and plans - and adds one of these instead. It waits a frame and
## stays silent if something else already answered, exactly as testkit/tile_set_answerer.gd does.
class ProfilePicker:
	extends Node
	static var choice_bus:ChoiceBus = load('res://engine/choices/choice_bus.tres')

	## The action id to pick out of the menu.
	var wanted:StringName = &''
	## Read back by the test: a menu really was raised and this profile really was in it.
	var picked:bool = false

	func _ready() -> void:
		choice_bus.on_choice_request.connect(_on_request)

	func _on_request(request:ChoiceRequest) -> void:
		if request.type != ChoiceBus.TYPE.gear: return
		await get_tree().process_frame
		if request.resolved: return # something else answered first
		for option in request.params.array:
			if not (option is SpecificAction): continue
			if option.action.get_id() != wanted: continue
			picked = true
			request.send_response({object = option})
			return
		request.abort()

func test_a_mounted_full_axe_recharges_after_toe_to_toe_swings_thunderous():
	# THE PRODUCTION ORDER, AND THE BUG THE FINAL REVIEW FOUND. On a Leoleth in play the axe sits on a
	# MOUNT, and mounts are the LAST entry of get_all_gear() (loadout_core.gd:511-518) while Toe To Toe
	# is a frame TRAIT, one entry earlier. reaction_bus.trigger_occurred walks that order (:291-296),
	# EventCore collects the whole END_TURN PRE batch before executing any of it (event_core.gd:52-55),
	# and so the free Skirmish resolves BEFORE this reaction does.
	#
	# With the cap in the gate, a FULL axe was never collected at all; Toe To Toe then swung Thunderous,
	# spent the charge, and the turn ended empty - against a card that says the weapon gains one. The
	# gate now reads speed only and the cap is applied at activation, after the swing.
	#
	# THE SYSTEM COPY IS REMOVED FIRST, on purpose: before_each equips the axe through arm_axe, which
	# files it under the frame's integrated weapons - one entry BEFORE traits - and that copy would
	# reproduce the old recharge-first order and hide the whole point of this case.
	leoleth.core.unequip_system(LeolethFixture.TDA_ID)
	SpecFactory.apply_passive_buffs(leoleth) # unequip_system full_repairs; put the frame's buffs back
	assert_false(GearCore.is_valid(leoleth.get_gear(LeolethFixture.TDA_ID)),
		'fixture: the integrated copy is gone, so only the mounted one can answer.')

	var mounted:GearCore = null
	for mount:MountCore in leoleth.core.loadout.mounts:
		mounted = mount.equip_primary(LeolethFixture.TDA_ID)
		if GearCore.is_valid(mounted): break
	assert_true(GearCore.is_valid(mounted), 'fixture: the axe mounts on one of the frame\'s mounts.')
	if not GearCore.is_valid(mounted): return
	# MOUNTED, not integrated - which IS the ordering claim, so it is asserted rather than assumed.
	assert_true(leoleth.core.loadout.mounts.any(func(mount:MountCore) -> bool:
		return mount.get_gear().has(mounted)), 'fixture: it is reachable through the mounts...')
	assert_false(leoleth.core.loadout.attacks.has(mounted), '...and it is not an integrated attack...')
	assert_false(leoleth.core.loadout.systems.has(mounted), '...nor a system.')
	# FILLING A SLOT BY HAND DOES NOT REFRESH THE REACTION INDEX. reactions_by_trigger is rebuilt only
	# by regenerate_caches (loadout_core.gd:291-296), which production reaches through
	# regenerate_derived_gear (:275) every time the mech is printed or repaired after the mech editor
	# put the weapon on the mount. A spec that writes into slot_primary itself has to say so, or the
	# mounted axe's reaction is simply not in the batch and this case passes/fails for that reason.
	leoleth.core.loadout.regenerate_caches()
	mounted.charges_current = mounted.get_max_charges(leoleth.core)
	assert_eq(mounted.charges_current, 1, 'fixture: and it is FULL, which is the state that broke.')

	# THE ORDERING CLAIM ITSELF, read off the index the bus walks (reaction_bus.gd:50-52).
	var batch:Array = leoleth.core.loadout.reactions_by_trigger.get(ReactionBus.TRIGGER.END_TURN, [])
	var toe:GearCore = leoleth.get_gear(LeolethFixture.TOE_TO_TOE_ID)
	assert_gt(batch.find(toe), -1, 'fixture: Toe To Toe is in the END_TURN batch...')
	assert_gt(batch.find(mounted), -1, '...and so is the mounted axe.')
	assert_lt(batch.find(toe), batch.find(mounted),
		'The TRAIT is collected before the MOUNT, which is the production order this case exists for.')

	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max(),
		'fixture: nothing moved, so both reactions\' gates are open.')

	var picker := ProfilePicker.new()
	picker.wanted = LeolethFixture.TDA_THUNDEROUS
	add_child_autoqfree(picker)
	SpecFactory.current_responder.choose_gears = false

	# A hit: d20, then 2d6 for the hit column and 2d6 for the crit column (attack_util.gd:250-257).
	# queue() tails with 1s, so [19, 6, 6, 6] lands 6 + 6 + 2 = 14 ENERGY on a 200 HP dummy.
	LeolethFixture.queue([19, 6, 6, 6])
	var hp := target.core.current.health
	await SpecFactory.end_turn(game, leoleth)

	assert_true(picker.picked, 'LIVENESS: the two-entry menu was raised and Thunderous was taken out of it.')
	assert_eq(target.core.current.health, hp - 14,
		'The free Skirmish swung THUNDEROUS: 6 + 6 + 2 Energy, armor 0.')
	assert_eq(mounted.charges_current, 1,
		'And the axe is full again - the Skirmish spent the charge, the recharge gave it back.')

# ---------------------------------------------------------------- destructible at zero

func test_the_axe_is_destructible_with_a_charge():
	assert_true(UnitPrinter.get_destructable_gear([axe]).has(axe), 'A licensed weapon can be shot off.')

func test_the_axe_is_destructible_at_zero_charges():
	axe.charges_current = 0
	assert_true(UnitPrinter.get_destructable_gear([axe]).has(axe),
		'"can be destroyed even if it has no charges remaining" - only the extension can say so.')
	assert_true(LoadoutCore.get_destructable_gear([axe]).has(axe),
		'And the override survives LoadoutCore\'s delegation to UnitPrinter (loadout_core.gd:575-576).')

func test_an_empty_axe_on_a_mount_is_offered_by_the_structure_checks_production_entry():
	# DEPARTURE from the brief's single assertion. arm_axe equips the axe as an INTEGRATED system -
	# LoadoutCore.equip_system only appends to equipped_kits (:338-340) and regenerate_derived_gear
	# files it under `systems`; nothing in that path ever fills a MountCore - so
	# leoleth.core.loadout.mounts stays empty of gear and get_destructable_mounts could only ever
	# read [] no matter what the extension says. A Heavy Melee weapon is MOUNTED in play, and
	# event_unit_structure.gd:176 reads the mounts for any unit that has them (the Leoleth has Flex
	# and Heavy). So mount it, which is the level-1 depth the Task 0 probe measured.
	var mounted:GearCore = null
	for mount:MountCore in leoleth.core.loadout.mounts:
		mounted = mount.equip_primary(LeolethFixture.TDA_ID)
		if GearCore.is_valid(mounted): break
	assert_true(GearCore.is_valid(mounted), 'fixture: the axe mounts on one of the frame\'s mounts.')
	if not GearCore.is_valid(mounted): return
	mounted.charges_current = 0
	assert_false(mounted.has_charges_left(), 'fixture: and it is empty.')
	assert_false(LoadoutCore.get_destructable_mounts(leoleth.core.loadout.mounts).is_empty(),
		'The mount is offered through the structure check\'s production entry (level 1).')

func test_a_vanilla_limited_weapon_at_zero_charges_stays_non_destructible():
	var stub:GearCore = LeolethFixture.equip(leoleth, LeolethFixture.STUB_CANNON)
	stub.charges_current = 0
	axe.charges_current = 0
	assert_false(UnitPrinter.get_destructable_gear([stub]).has(stub), 'The Stub Cannon is refused, as vanilla.')
	assert_eq(UnitPrinter.get_destructable_gear([axe, stub]).size(), 1, 'Only the axe.')

# ---------------------------------------------------------------- the licence

func test_the_licence_grants_the_axe_at_rank_two():
	var tree = ContentLibrary.get_license_tree(LeolethFixture.LICENSE_ID)
	assert_not_null(tree, 'The licence loads.')
	if tree == null: return
	var rank_2:Array = tree.rank_2.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_true(rank_2.has(LeolethFixture.TDA_ID), 'Rank 2 grants the axe.')
