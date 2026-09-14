# AUXILIARY POWER REROUTER / O.R.S HYPERCHARGE (M/K2, SP1 Task 3): "For the rest of the scene, you
# ignore the loading property of your weapons but gain 1d3 heat each time you fire a Loading weapon."
#
# LOADING IS ONE BOOLEAN, GearCore.is_loaded. unit_action.gd:276 sets it false after any Loading
# weapon attack's spend_actions, :151 refuses an unloaded weapon unless the action overrides
# can_be_used_while_unloaded(), and only event_gear_reload sets it back. So the ability is a reacting
# buff that restores the flag after every firing, and the heat is charged from the same reaction.
# Between the drop and the restore nothing reads the flag: the UI never shows the weapon unloaded,
# and Stabilize never offers a reload (UnitAction.get_unloaded_weapons, unit_action.gd:411-416).
#
# RULING 6: activating the protocol also READIES every intact Loading weapon on the spot. "Ignore the
# Loading property" means the weapon behaves as if it never had it, so a weapon already fired and
# empty is loaded when the protocol resolves. The heat cost applies only to shots fired afterwards.
#
# RULING 7: the heat is PER FIRING ACTION. One 1d3 per Blast, two per two-weapon Skirmish, and
# reactions and freebies pay too ("each time you fire"). That falls straight out of the trigger:
# UNIT_ACTION POST fires once per gear activation that actually moved its usage counter
# (event_gear_activate.gd:110-111, gated at :100-104), so an aborted attack pays nothing and stays
# loaded.
#
# THE DICE STRATEGY IS "EVERY DIE THE SAME NUMBER", not a lined-up queue, and that is not laziness.
# Dice.CHEAT_ROLL_QUEUE is ONE global FIFO (dice.gd:9, :33-35) and the heat d3 is rolled LAST, after
# the attack has popped its d20, its accuracy die and however many damage dice the weapon rolls - a
# count this file must not have to know. Filling the queue with one repeated value makes the d3 come
# back that value whatever the attack consumed first, so the heat assertions can name an exact
# number. The same trick, for the same reason, as test_hybridized_shot.cheat_every_die_to_six().
# NEVER 1: Overkill rerolls damage dice that come up 1 (which is why dice.gd:32 picks 2 for its own
# CHEAT_ROLL_LOW), and a rerolling damage die would drain the queue unpredictably.
#
# AND THE TWO HEAT TESTS USE DIFFERENT NUMBERS ON PURPOSE. A single test asserting "3" passes just as
# well against a hard-coded 3 as against a rolled d3; test_two_loading_shots_pay_twice rolls a 3 and
# then a 2 and asserts 5, which no constant reproduces.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ors_hypercharge.gd
extends GutTest

const MK2Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/mk2_fixture.gd')

const CORE_ID := &'cp_auxiliary_power_rerouter'
const PROTOCOL_ID := &'action_ors_hypercharge'
const BUFF_ID := &'buff_ors_hypercharge'

## The frame's third ability, for the one test that runs all three at once.
const JETS_ID := &'mt_rapid_stabilization_jets'

## Heavy, LOADING, Ordnance (mw_anti_materiel_rifle.tres:14,16).
const AMR := &'mw_anti_materiel_rifle'
## Heavy, NOT loading (mw_heavy_machine_gun.tres:16,19) - the control for the LOADING gate.
const PLAIN_HEAVY := &'mw_heavy_machine_gun'
## AUX, LOADING, no Ordnance (mw_missile_rack.tres:22,25). A SECOND Loading weapon, so
## test_two_loading_shots_pay_twice does not have to fire one weapon twice.
const LOADING_AUX := &'mw_missile_rack'

## The key the engine resolves Hybridized Shot's accuracy line through - the BUFF's compcon_id, not
## the trait's. test_hybridized_shot.gd's test_the_bonus_is_labelled_with_the_traits_name records in
## full why the difference is invisible by coincidence and must not be "simplified" to the trait key.
const HYBRIDIZED_NAME_KEY := 'gear.buff_hybridized_shot.name'

const START := Vector2i(2, 2)
const TARGET_TILE := Vector2i(7, 2)
## Well clear of the M/K2 and its target, for the one test that needs a third unit taking its own turn.
const ENEMY_TILE := Vector2i(2, 6)
## Two tiles along the row from START, so a standard move is available and the M/K2 ends up three
## tiles from TARGET_TILE - well inside the AMR's aim_range 20 and well outside engagement, which the
## Jets famously do NOT waive (see test_rapid_stabilization_jets.test_an_engaged_target_is_still_refused).
const MOVED_TILE := Vector2i(4, 2)
## A tile that is not on the 15x9 fixture map, so an activation aimed at it ABORTS mid-flight rather
## than being refused up front. Tile.is_valid bounds-checks it away inside
## TargetActionUtil.ask_for_targets_alt (target_action_util.gd:171), leaving a plan with no tiles and
## no units, which CompconPlan.is_valid_with_targets_alt refuses (compcon_plan.gd:45-52) and
## ActionAttack.activate aborts on at action_attack.gd:236 - BEFORE spend_actions at :262, which is
## the line that would have dropped is_loaded and moved the usage counter. Same constant, same
## reasoning, as test_swivel_gun.gd:67.
const OFF_MAP := Vector2i(99, 99)

var game:Gamemaster
var mk2:Unit
var target:Unit

func before_each() -> void:
	game = MK2Fixture.create_game(self)
	mk2 = MK2Fixture.create_mk2(game, START)
	target = MK2Fixture.create_dummy(game, TARGET_TILE, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func equip(weapon_id:StringName) -> GearCore:
	var weapon:GearCore = mk2.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(mk2)
	return weapon

func hypercharge() -> void:
	await SpecFactory.use(game, mk2, CORE_ID, PROTOCOL_ID)

## Every die in the rest of this activation comes back `every_die`. See the file header.
func cheat_every_die_to(every_die:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(every_die)
	Dice.cheat_attack([], buffer)

## Fire once at the punching bag, with every die in the activation fixed to `every_die` - so the
## heat d3 the buff rolls afterwards comes back `every_die` too.
##
## `flags` exists for AS_FREEBIE, and that flag buys past exactly one thing: the repeat-action rule.
## can_activate_gear returns early for a freebie (unit_action.gd:113-114) and so skips the per-turn
## SOFT limit of 1 (unit_action.gd:116, action.gd:161-163) and affordability - but is_gear_available
## has already run above it (:112), so REASON.UNLOADED still refuses a freebie. That is what makes a
## freebie a legitimate way to ask this file's question twice in one turn without weakening it.
func shoot(weapon:GearCore, every_die:int = 2, flags:Array = []) -> void:
	cheat_every_die_to(every_die)
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = mk2, target_unit = target,
		flags = flags,
	})

## Fire once for real and hand back the DeclaredAttackSummary the attack resolved through - the one
## object that remembers what each per-target roll was actually given.
##
## BUILDS THE EVENT BLOCK BY HAND instead of calling game.execute_event(), for the reason
## test_hybridized_shot.gd's own fire_and_capture() sets out at length: the summary is created inside
## the activation (action_attack.gd:253) and written onto the event's OWN context (:259), so the only
## way to see it afterwards is to hold the EventCore. level.gd:97 creates that core internally and
## returns void. core.context is re-read rather than cached because the variant-action path REPLACES
## it (event_gear_activate.gd:90-91).
func fire_and_capture(weapon:GearCore, flags:Array = []) -> DeclaredAttackSummary:
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = mk2, target_unit = target,
		flags = flags,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

## Did any roll of this resolved attack carry Hybridized Shot's +1?
##
## Reads the MOD LIST rather than accuracy_mods_total(), the way test_hybridized_shot.gd's
## got_the_bonus() does: cover is an accuracy mod like any other (attack_roll.gd:168-169), so a total
## can move without anything about the trait changing. The title is the buff's own name_text(), which
## is what attack_roll.gd:189 puts on the breakdown line.
func any_roll_got_hybridized_shot(declared:DeclaredAttackSummary) -> bool:
	for roll:AttackRoll in declared.attack_rolls:
		for mod:AttackRoll.AccuracyMod in roll.pre.accuracy_mods:
			if mod.title_key == tr(HYBRIDIZED_NAME_KEY) and mod.mod == 1: return true
	return false

## This weapon's round-usage counter - the number event_gear_activate.gd:100-104 compares against the
## value it took before the activation, to decide whether the UNIT_ACTION POST (and so this whole
## ability) runs at all. Unchanged means the activation never got as far as spend_actions.
func round_uses(weapon:GearCore) -> int:
	return weapon.get_uses_this_round_alt(weapon.get_usage_group_for_action(weapon.get_solo_action()))

## Fire once from some OTHER unit, at us.
func shoot_from(shooter:Unit, weapon:GearCore, every_die:int = 2) -> void:
	cheat_every_die_to(every_die)
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = mk2,
	})

func has_the_chip() -> bool:
	return mk2.state.buffs.any(func(core:BuffCore) -> bool: return core.base.compcon_id == BUFF_ID)

## Why this weapon is unavailable right now, as a REASON enum value. The ordnance window is readable
## in exactly one place - unit_action.gd:146 turning it into REASON.ORDNANCE - so this is how the
## three-way test below says "open" and "shut" without inferring it from whether a shot happened.
func reason_for(weapon:GearCore) -> UnitAction.REASON:
	return UnitAction.get_gear_unavailable_reason(
		SpecificAction.create(mk2, weapon, weapon.get_solo_action()))

## A STANDARD move - the only kind that shuts the ordnance window. NOT SpecFactory.move()'s default
## MovementType, whose second argument is is_voluntary and not spend_move (movement_type.gd:34-44),
## while event_unit_move.gd:88-90 gates end_ordnance_phase() on spend_move. Only
## create_for_standard_move sets it (movement_type.gd:58-61). The same trap, with the same citation,
## as test_rapid_stabilization_jets.move_to() - which measured it going wrong.
func move_to(tile:Vector2i) -> void:
	await SpecFactory.move(game, mk2, tile, MovementType.create_for_standard_move(mk2))

# ---------------------------------------------------------------- the control

## Not decoration: every "stays loaded" assertion below is vacuous if firing never emptied the weapon
## in the first place. This is the one test in the file that must pass with the whole ability deleted.
func test_without_the_protocol_a_loading_weapon_empties() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr)
	assert_false(amr.is_loaded, 'Vanilla: the AMR is empty after one shot.')

## The other half of the control, and the reason test_a_non_loading_weapon_costs_nothing means
## anything: the HMG must actually FIRE. A weapon whose activation silently aborted would also cost
## no heat, and would read as the LOADING gate working.
func test_the_control_weapon_really_fires() -> void:
	var hmg := equip(PLAIN_HEAVY)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(hmg)
	assert_gt(round_uses(hmg), 0,
		'The HMG activation moved its round usage counter, so it really went off.')

# ---------------------------------------------------------------- the protocol

func test_the_protocol_is_refused_outside_the_protocol_window() -> void:
	var core_gear:GearCore = mk2.get_gear(CORE_ID)
	assert_true(GearCore.is_valid(core_gear), 'Fixture: the frame carries %s.' % CORE_ID)
	if not GearCore.is_valid(core_gear): return
	assert_false(mk2.state.is_using_protocols, 'The fixture has not opened a turn.')
	assert_eq(
		UnitAction.get_gear_unavailable_reason(
			SpecificAction.create(mk2, core_gear, core_gear.get_action(PROTOCOL_ID))),
		UnitAction.REASON.PROTOCOL,
		'A protocol needs the protocol window.')

func test_the_protocol_spends_the_core_power() -> void:
	await MK2Fixture.open_turn(game, mk2)
	assert_true(mk2.core.has_core_power, 'We start with it.')
	await hypercharge()
	assert_false(mk2.core.has_core_power, 'The protocol consumed it.')
	assert_true(has_the_chip(), 'And left its chip.')

## RULING 6. The reload is the ACTION's job, not the buff's: the buff only ever reacts to a firing,
## and this weapon was fired before the protocol existed.
##
## THE TURN FLIP IN THE MIDDLE IS THE REAL ORDER OF PLAY, not spec scaffolding. Firing ends the
## protocol window - any non-protocol, non-reaction action does (unit_action.gd:268 via
## does_action_end_protocol_phase) - and event_gear_activate refuses an unavailable action outright,
## so "shoot, then hypercharge" is only reachable across a turn boundary. Measured: written as
## shoot-then-hypercharge inside one turn, the activation aborts with
## `[ Gear not available ] reason : protocol` and this test fails for a reason that has nothing to do
## with reloading (.superpowers/sdd/task3-green-1.log).
##
## And the extra assertion after the flip is what makes the last one mean something: if a new turn
## reloaded weapons by itself, the protocol would be getting credit for the engine's work.
func test_activating_it_reloads_an_empty_weapon() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await shoot(amr)
	assert_false(amr.is_loaded, 'Empty before.')
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	assert_false(amr.is_loaded,
		'Fixture: still empty at the start of the next turn - only a reload clears Loading.')
	await hypercharge()
	assert_true(amr.is_loaded, 'The protocol readied it.')

# ---------------------------------------------------------------- firing under it

func test_a_loading_weapon_stays_loaded() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await shoot(amr)
	assert_true(amr.is_loaded, 'The buff put the flag straight back.')

func test_firing_it_costs_the_rolled_d3_in_heat() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(amr, 3)
	assert_eq(mk2.core.current.heat - before, 3, 'Exactly the cheated d3.')

func test_a_non_loading_weapon_costs_nothing() -> void:
	var hmg := equip(PLAIN_HEAVY)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(hmg, 3)
	assert_eq(mk2.core.current.heat, before, 'No Loading tag, no heat.')

func test_two_loading_shots_pay_twice() -> void:
	# RULING 7: per firing action. Two DIFFERENT weapons, so the per-turn soft limit is not in play.
	# Two DIFFERENT die values, so no constant charge reproduces the total (3 + 2 = 5).
	var amr := equip(AMR)
	var rack := equip(LOADING_AUX)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	var before:int = mk2.core.current.heat
	await shoot(amr, 3)
	await shoot(rack, 2)
	assert_eq(mk2.core.current.heat - before, 5,
		'One 1d3 per firing, not one per turn - and the ROLLED value each time, not a constant.')

func test_the_chip_is_still_there_next_turn() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, mk2)
	assert_true(has_the_chip(), 'until = MANUAL: it lasts the scene.')

## THE HOLDER GUARD, which nothing else in this file reaches.
## reaction_bus.trigger_occurred polls EVERY unit's buffs on every trigger (reaction_bus.gd:50,
## :61-62) and hands each of them the SAME triggering event, so our buff is asked about an enemy's
## Loading shot. Without the holder check it would put the ENEMY's weapon back and heat US for it.
## Both halves are asserted: our heat, and the enemy's weapon staying empty.
func test_an_enemys_loading_shot_neither_heats_us_nor_reloads_them() -> void:
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()

	var enemy := MK2Fixture.create_dummy(game, ENEMY_TILE, -10)
	var enemy_amr:GearCore = enemy.core.equip_system(AMR)
	SpecFactory.apply_passive_buffs(enemy)
	await SpecFactory.end_turn(game, mk2)
	await SpecFactory.start_turn(game, enemy)

	var before:int = mk2.core.current.heat
	await shoot_from(enemy, enemy_amr, 3)
	assert_eq(mk2.core.current.heat, before, "Somebody else's Loading shot does not heat us.")
	assert_false(enemy_amr.is_loaded, 'And it does not reload their weapon either.')

# ---------------------------------------------------------------- the aborted activation

## RULING 7's OTHER HALF: an activation that ABORTS neither heats nor reloads. Two project rulings
## rest on it, and until now nothing in this file reached it.
##
## THE ABORT IS REAL, NOT A REFUSAL, and the two are not the same branch. A refused activation
## (REASON.UNLOADED, REASON.PROTOCOL) never enters event_gear_activate.execute at all, so it could
## never have reached the POST gate; an OFF_MAP shot does enter, runs all the way to
## ActionAttack.activate's is_valid_with_targets guard (action_attack.gd:236) and returns from THERE,
## one line short of spend_actions at :262. That is the case event_gear_activate.gd:100-104 exists
## for: the event executed, the usage counter did not move, so no UNIT_ACTION POST is queued and this
## buff is never asked. The counter assertion below is what says which of the two branches was taken.
##
## THE CONTROL AT THE BOTTOM IS NOT DECORATION. "No heat" is what a completely dead buff also reads
## like. Firing for real straight afterwards, in the same turn, with the same weapon, proves the heat
## was reachable from exactly this state - and it is reachable only because the aborted attempt cost
## nothing at all, not even the turn's action.
func test_an_aborted_activation_neither_heats_nor_reloads() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()

	var before:int = mk2.core.current.heat
	var uses_before:int = round_uses(amr)
	cheat_every_die_to(3)
	await SpecFactory.use_solo(game, mk2, AMR, OFF_MAP)

	assert_eq(round_uses(amr), uses_before,
		'Fixture: the activation aborted before spend_actions - its round counter never moved, which'
		+ ' is exactly the condition event_gear_activate.gd:100-104 gates the POST on.')
	assert_eq(mk2.core.current.heat, before, 'A shot that was never fired costs no heat.')

	await shoot(amr, 3)
	assert_eq(mk2.core.current.heat - before, 3,
		'control: a real shot from that same state, same turn, same weapon, does charge the d3 - so'
		+ ' the assertion above measured the abort and not a dead buff.')

## The reload half of the same ruling, and it has to be staged differently because the engine will
## not let the two halves meet. A weapon can only be unloaded going INTO an activation if that
## activation is then refused for REASON.UNLOADED (unit_action.gd:151, checked inside
## is_gear_available before anything a freebie can skip) - so "unloaded AND aborts at the plan" is
## unreachable, and this asserts the refusal branch instead.
##
## THE HAND-SET FLAG IS THE ENGINE'S OWN MOVE, not spec licence: unit_action.gd:276 is a bare
## `gear.is_loaded = false`, and this stages the state that line produces. It also records something
## true about the design that no other test says: Hypercharge does NOT grant
## can_be_used_while_unloaded, so a weapon that somehow reaches an unloaded state stays unusable -
## the ability works by restoring the flag after each firing, never by waiving the check.
func test_a_refused_activation_does_not_reload_the_weapon() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	assert_true(amr.is_loaded, 'Fixture: ruling 6 readied it on activation.')

	amr.is_loaded = false
	var before:int = mk2.core.current.heat
	cheat_every_die_to(3)
	await shoot(amr, 3)

	assert_false(amr.is_loaded,
		'An activation the engine refused did not reload the weapon behind its back.')
	assert_eq(mk2.core.current.heat, before, 'And charged no heat for it.')

# ---------------------------------------------------------------- integration

## THE ONE READING NO OTHER CONFIGURATION CAN PRODUCE: the SAME Loading weapon fired TWICE in one
## turn, the first shot carrying Hybridized Shot's +1 and the second not.
##
## This test replaces a vacuous one. The version this branch shipped built a preview through
## SpecificAction.create + Context.clone and asserted accuracy_mods_total() == 2 without firing a
## shot - a number made entirely of the AMR's own attack_accuracy = "1"
## (mw_anti_materiel_rifle.tres:17) and Hybridized Shot's +1, neither of which Hypercharge touches.
## It passed in the pre-implementation red run (.superpowers/sdd/mk2-sp1-task3-red.log) with the core
## system and the frame's traits entry entirely absent, and no mutation pinned it.
##
## WHY THE SECOND SHOT IS THE PIN. Vanilla forbids it outright: unit_action.gd:276 drops is_loaded
## inside the first shot's spend_actions, and unit_action.gd:151 then refuses the weapon for
## REASON.UNLOADED inside is_gear_available - which a freebie does NOT skip (unit_action.gd:112 runs
## before the freebie early-return at :114). Only this buff's restore makes a second activation
## reachable at all, so the second summary coming back non-null is a direct reading of the restore.
##
## HYBRIDIZED SHOT IS THE RULER, and it is what makes the two shots distinguishable. It is once per
## turn, charged by its own UNIT_ACTION POST reaction, so the first shot spends it and the second
## cannot have it. "One shot with the bonus, one without, from one weapon in one turn" is a shape no
## single shot and no pair of different weapons can fake.
##
## AS_FREEBIE ON THE SECOND SHOT, and only for the repeat-action rule: the per-turn SOFT limit is 1
## for anything not free (action.gd:161-163 via unit_action.gd:116), and overcharge is the only other
## thing that lifts it - which would drag overcharge heat into the picture. See shoot()'s header for
## why that flag cannot weaken the Loading question this test is asking. The idiom is established:
## test/gear/test_mw_autogun.gd:33 and test_blasting_powder.gd:133.
##
## READ OFF RESOLVED ATTACKS. A preview cannot answer this - it never spends anything, so two
## previews taken before any shot both read +1 whatever the implementation does. Only the
## DeclaredAttackSummary an attack really resolved through remembers what each roll was handed; see
## fire_and_capture() above and, in full, test_hybridized_shot.gd's own copy of it.
##
## MUTATION-TESTED 2026-09-14, which is the thing the old test could not survive: deleting
## `fired.gear.is_loaded = true` from buff_ors_hypercharge.activate turns this test red at both of
## its structural assertions - the flag is not back after the first shot, and the second activation
## is refused so fire_and_capture hands back null
## (.superpowers/sdd/mk2-sp1-task3-mutation-no-restore.log, 13/16, taking
## test_a_loading_weapon_stays_loaded and test_a_freebie_shot_pays_the_heat_too with it). The test
## this replaced stayed GREEN with the entire core system deleted.
func test_hypercharge_lets_one_loading_weapon_fire_twice_and_only_the_first_is_hybridized() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()

	cheat_every_die_to(2)
	var first := await fire_and_capture(amr)
	assert_true(amr.is_loaded,
		'The buff put the flag back after the first shot - the only reason a second one exists.')

	cheat_every_die_to(2)
	var second := await fire_and_capture(amr, [Action.FLAG.AS_FREEBIE])

	assert_true(DeclaredAttackSummary.is_valid(first), 'Fixture: the first shot really resolved.')
	assert_true(DeclaredAttackSummary.is_valid(second),
		'The SECOND shot of the SAME Loading weapon resolved in the same turn - which vanilla refuses'
		+ ' outright, and only the restore in buff_ors_hypercharge.activate makes reachable.')
	if not (DeclaredAttackSummary.is_valid(first) and DeclaredAttackSummary.is_valid(second)): return

	assert_true(any_roll_got_hybridized_shot(first),
		"The first shot's resolved roll carried Hybridized Shot's +1...")
	assert_false(any_roll_got_hybridized_shot(second),
		'...and the second did not: one +1 per turn, spent on the first of two shots that only'
		+ ' Hypercharge could have made possible.')

## ALL THREE OF THE FRAME'S ABILITIES ON ONE SHOT, which nothing else on this branch does. The AMR is
## the reason one test can cover them: Ordnance AND Loading AND not Superheavy
## (mw_anti_materiel_rifle.tres:14,16), so it is simultaneously the only weapon the Jets matter to,
## the only one Hypercharge matters to, and a legal subject for Hybridized Shot.
##
## THE ORDER IS FORCED BY THE ENGINE, not chosen for convenience, and getting it wrong is how this
## test would quietly become a test of nothing:
##  - HYPERCHARGE FIRST. It is a protocol, and ANY non-protocol non-reaction action shuts the protocol
##    window (unit_action.gd:268 via does_action_end_protocol_phase, :309-314), after which
##    unit_action.gd:144 refuses it with REASON.PROTOCOL. Both the move and the Jets would close it.
##  - THEN THE MOVE. A protocol does not shut the ordnance window - does_action_end_ordnance_phase
##    (:316-318) defers to does_action_end_protocol_phase, which returns false for a protocol - so
##    Hypercharge leaves the window as it found it, and the move is what actually shuts it.
##  - THEN THE JETS, which re-open it. Their own activation shuts it on the way in (a free action is
##    non-protocol and non-reaction), which is why action_rapid_stabilization_jets sets the flag again
##    after super().
##
## FOUR READINGS, ONE SHOT, and each belongs to a different ability:
##  - the window was SHUT after the move and OPEN after the Jets, read as REASON.ORDNANCE then
##    REASON.NONE rather than inferred from whether a shot landed - a shot can fail for six reasons;
##  - the AMR is still LOADED after firing, which only buff_ors_hypercharge's restore can produce
##    (unit_action.gd:276 drops the flag inside the attack's own spend_actions);
##  - the heat moved by exactly the rolled d3, which is the other half of Hypercharge;
##  - the resolved roll carried Hybridized Shot's +1, read off the DeclaredAttackSummary the attack
##    really went through rather than off a preview.
##
## THE FIXTURE ASSERTIONS ARE NOT DECORATION. Without the REASON.ORDNANCE check after the move, a
## build where moving never shut the window would still show REASON.NONE afterwards and the Jets would
## be getting credit for nothing; and without DeclaredAttackSummary.is_valid the accuracy assertion
## would be reading an empty roll list, which is trivially "no bonus" and would flip the wrong way.
func test_the_three_abilities_compose_on_one_amr_shot() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)

	await hypercharge()
	assert_true(has_the_chip(), 'Fixture: the protocol landed, before anything could shut its window.')

	await move_to(MOVED_TILE)
	assert_eq(reason_for(amr), UnitAction.REASON.ORDNANCE,
		'Fixture: a standard move shut the ordnance window - so the Jets below have work to do.')

	await SpecFactory.use_solo(game, mk2, JETS_ID)
	assert_eq(reason_for(amr), UnitAction.REASON.NONE,
		'The Jets re-opened the ordnance window after the move, with Hypercharge already running.')

	var before:int = mk2.core.current.heat
	cheat_every_die_to(3)
	var declared := await fire_and_capture(amr)

	assert_true(DeclaredAttackSummary.is_valid(declared),
		'The Ordnance, Loading, non-Superheavy shot resolved with all three abilities live.')
	if not DeclaredAttackSummary.is_valid(declared): return
	assert_true(any_roll_got_hybridized_shot(declared),
		"...and it was the turn's first qualifying attack, so it carried Hybridized Shot's +1.")
	assert_true(amr.is_loaded,
		'...and Hypercharge put the Loading flag straight back, so the gun is ready again.')
	assert_eq(mk2.core.current.heat - before, 3,
		'...and charged exactly the rolled d3 for it.')

## RULING 7 says a freebie pays too ("each time you fire"). This is the half of that claim a spec can
## reach: gear_core.gd:175-176 increments uses_this_round unconditionally and only gates the per-TURN
## counter on the freebie flag, so a freebie moves the number event_gear_activate.gd:100-104 reads
## and the POST fires exactly as it does for a paid action.
##
## The first shot is a normal activation on purpose: it is what spends the repeat-action allowance,
## so the freebie is doing real work here rather than being an arbitrary flag on the only shot.
func test_a_freebie_shot_pays_the_heat_too() -> void:
	var amr := equip(AMR)
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await shoot(amr, 2)

	var before:int = mk2.core.current.heat
	await shoot(amr, 3, [Action.FLAG.AS_FREEBIE])
	assert_eq(mk2.core.current.heat - before, 3,
		'The freebie paid its own 1d3 - and the ROLLED value, not a constant.')

# ---------------------------------------------------------------- attribution

## A buff that answers "no" to everything and records what it was asked about.
##
## reaction_bus.trigger_occurred walks EVERY unit's buffs on every trigger and hands each of them the
## triggering event (reaction_bus.gd:50, :61-62), and event_unit_damage puts the responsible gear and
## action on its context for exactly this - "optionally put here (for reactions to inspect)",
## event_unit_damage.gd:36-37. Returning false means does_buff_trigger (reaction_bus.gd:133-139)
## builds no event block, so this observes the damage event without taking any part in it.
##
## Buff.new() as a spec fixture is vanilla's own idiom (test/event/test_event_unit_damage.gd:67,
## test/event/test_event_turn_end.gd:39); the inner class only exists because triggers_on_event has
## to be overridden, which a bare Buff cannot do. The name deliberately does not begin with `Test`,
## GUT's inner-class prefix, so the scan never collects it as a test class.
class HeatSourceSpy extends Buff:
	## [kit compcon_id, action id] for every HEAT damage event that landed on the holder.
	var heat_sources:Array = []

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.unit == unit and context.category_int == Lancer.DAMAGE_TYPE.HEAT:
			heat_sources.append([
				context.gear.kit.compcon_id if GearCore.is_valid(context.gear) else &'',
				context.action.get_id() if Action.is_valid(context.action) else &'',
			])
		return false

## POST rather than PRE so the recording happens on a damage event that actually resolved; the PRE
## pass at event_unit_damage.gd:59 runs before the invulnerable/zero-damage aborts.
func install_heat_spy() -> HeatSourceSpy:
	var spy := HeatSourceSpy.new()
	var triggers:Array[StringName] = [ReactionBus.TRIGGER.DAMAGE]
	spy.triggers_on = triggers
	spy.trigger_timing = ReactionBus.TIMING.POST
	spy.hide_from_player = true
	UnitCondition.apply_buff_alt(
		SpecFactory.dummy_event({number = 0, map = game.map}), mk2, BuffCore.create(spy))
	return spy

## THE HEAT IS THE ABILITY'S, NOT THE GUN'S - the claim buff_ors_hypercharge.gd makes in a prominent
## comment and, until now, nothing checked.
##
## It is real, and it is fragile in a specific way: UnitAction.gain_self_heat_alt copies
## specific.gear and specific.action straight into the event_unit_damage context (unit_action.gd:305-306),
## and the buff hands it a SpecificAction built by hand around the CORE SYSTEM's own gear and its
## protocol action. The obvious tidy-up - SpecificAction.from_context(activation.context) - looks
## equivalent and is not: a reacting buff runs as event_buff_activate, whose context carries no gear
## and no action at all (content/events/event_buff_activate.gd:7-11), so the damage would arrive
## anonymous. Nothing about the heat NUMBER would change, and every other test in this file would
## stay green.
##
## MEASURED, not reasoned: making exactly that substitution leaves the heat NUMBER untouched, turns
## this test red on both of its assertions with an empty gear id and an empty action id, and leaves
## the other 15 tests in this file green
## (.superpowers/sdd/mk2-sp1-task3-mutation-attribution.log, 15/16).
##
## Note what this does NOT claim. The heat line in the battle log is
## event.unit_damage.heated_self.log, which formats only an amount and a damage-type icon
## (event_unit_damage.gd:108-115) - it names no source either way. What the attribution reaches is
## the damage context itself: reactions inspecting it, and anything downstream that asks what caused
## the heat.
func test_the_heat_is_attributed_to_the_core_system_not_the_weapon() -> void:
	var amr := equip(AMR)
	var spy := install_heat_spy()
	await MK2Fixture.open_turn(game, mk2)
	await hypercharge()
	await shoot(amr, 3)

	assert_eq(spy.heat_sources.size(), 1,
		'Fixture: exactly one HEAT damage event landed on the M/K2 - the ability charging its d3.')
	if spy.heat_sources.size() != 1: return
	assert_eq(spy.heat_sources[0][0], CORE_ID,
		'The heat names the CORE SYSTEM as its gear, not the gun that fired.')
	assert_eq(spy.heat_sources[0][1], PROTOCOL_ID,
		'And the protocol the player pressed as its action, not the weapon attack.')
