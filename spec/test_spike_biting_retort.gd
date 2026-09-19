# SP3 TASK 0 - THE PROBE: how can the BITING RETORT riposte OBSERVE the roll it just modified?
#
#   "A hostile character within LINE OF SIGHT attempts to hit you with a melee attack. The attack is
#    made with +1 DIFFICULTY. If the attack misses, the attacker takes 3 AP KINETIC damage and must
#    succeed a HULL SAVE or be knocked PRONE."
#
# The card is split across the attack pipeline because the engine is. The +1 Difficulty has to land
# BEFORE AttackRoll.create (event_unit_attack.gd:53), so the reaction is ATTACK **PRE** - the
# Saladin's Warp Shield, byte for byte. The riposte can only be decided AFTER the roll, so something
# else has to be listening at ATTACK **POST**. Design 3.1 named a buff with
# until = FINISH_ATTACK_ROLL and trigger_timing = POST for that job; reading event_unit_attack.gd
# says it cannot fire, because its tail runs in this order:
#
#     :120   UnitCondition.clear_buffs_until(core, clear_unit, Lancer.UNTIL.FINISH_ATTACK_ROLL)
#     :123   core.queue_reaction_events(ReactionBus.TRIGGER.ATTACK, ReactionBus.TIMING.POST)
#
# clear_buffs_until -> clear_buffs -> clear_buff ERASES the BuffCore from unit.state.buffs
# synchronously (unit_condition.gd:1010-1013 -> :952-965 -> :967-990, the erase at :980), and
# ReactionBus.trigger_occurred
# polls unit.state.buffs at QUEUE time (reaction_bus.gd:61-67). So the observer would be gone one
# line before anything asks it whether it wants to fire. THIS FILE MEASURES THAT, and the two
# candidate replacements, before any content is written.
#
# THIS IS A PROBE, NOT CONTENT. Every reaction and every buff below is built IN MEMORY - inner
# classes with their properties set in _init(), hung off a Kit that exists only for the length of a
# test - which is Spike 10's shape (test_spike_ripper_mod_ap.gd, since retired). No .tres ships from
# this task. Task 3 deletes this file once it has built whichever mechanism won.
#
# A PROBE ASSERTS WHAT IT MEASURED. Every assertion here was written against a real run's numbers, so
# a red in this file means the probe drifted from the engine, not that the engine is wrong.
#
# ---------------------------------------------------------------------------------------------
# HOW THE IN-MEMORY KIT REACHES THE REACTION BUS, since nothing else in this repo does it:
#
#   LoadoutCore.regenerate_derived_gear walks `equipped_kits` and builds a GearCore per Kit
#   (loadout_core.gd:173-174, :116-138), then calls regenerate_caches() (:275), which is what fills
#   `reactions_by_trigger` (:291-296) - the ONLY thing ReactionBus.trigger_occurred reads
#   (reaction_bus.gd:51). UnitPrinter.full_repair -> full_repair_loadout is the entry point
#   (unit_printer.gd:61-62, :82-83), and SpecFactory.apply_passive_buffs calls it. So appending a
#   hand-built Kit to equipped_kits and re-applying passive buffs is the whole installation.
#
#   Kit.compcon_id is a lazily-derived bare var whose getter falls back to the resource PATH
#   (kit.gd:11-16); an in-memory Kit has no path, so the id is SET BY HAND here. Without it
#   Kit.is_valid is false (kit.gd:48-49) and the gear is treated as missing. Action.get_id() has the
#   same shape (action.gd:90-92) and is answered the same way, through `original_id`.
#
#   inherit_or_create_gear matches on `gear.kit == kit` (loadout_core.gd:128), i.e. on INSTANCE
#   identity, so the GearCore - and its `state` dictionary, which candidate B's marker lives in -
#   survives every later full_repair.
#
# HOW THE ROLL IS MEASURED, since a POST observer is the very thing under test and cannot be assumed:
#
#   RollRecorder is a Buff.TO.MODIFY_ATTACK_ROLL passive that never applies and only records.
#   event_unit_attack.gd:345-358 builds a context carrying `object = roll` and queries
#   MODIFY_ATTACK_ROLL buffs on BOTH the attacker and the target at every SEQUENCE_STEP, the first of
#   which (auto_miss, :144) runs immediately after AttackRoll.create - so `pre` is already final
#   there. UnitCondition.does_buff_apply calls check_if_passive_applies (unit_condition.gd:845-851),
#   which is where the recorder grabs the AttackRoll REFERENCE and then returns false, so it never
#   enters step_buffs and is never consumed. The roll is mutated in place afterwards
#   (attack_roll.gd:65-71), so the same reference reads back the final base_roll / accuracy_roll /
#   total_roll / hit.
#
# WHY VANILLA BRACE IS TAKEN OFF THE PRIMROSE (arm(), and measured in the first RED run):
#   ms_brace is in every player mech's basic loadout and is a reaction on DAMAGE **PRE**
#   (content/gear/basic/ms_brace/action_brace.tres:8-9), so every swing that LANDS raises a second
#   yes/no prompt on the defender and competes for the same single reaction point. In the first run
#   of this file that showed up as test_p1_a counting two prompts where the reaction had only been
#   offered once, and as a Brace activation in the log directly under the probe's own. It is real
#   engine behaviour and the shipped Biting Retort will live with it - it is noted in the report -
#   but inside a probe whose measurements ARE prompt counts and reaction points it is pure noise, so
#   the gear is removed and its absence is asserted.
#
# WHY THE DAMAGE DICE ARE PINNED TO 1 AND ONLY THE ACCURACY DIE TO 6 (see pin_dice):
#   the Primrose is health 8 / armor 1 / evasion 8 (mf_primrose.tres:26-28) and is NOT
#   FrameIsolation'd (primrose_fixture.gd:7-11), so its stats cannot be raised. A heavy melee weapon
#   rolling sixes is 13 damage and kills it mid-test, and a dead holder is dropped at execution time
#   by event_buff_activate.check_specific_context's get_holder_unit guard - which would read exactly
#   like "the observer never fired". With 1s it is 2d6+1 = 3, less armor 1, so the Primrose survives
#   every case here. The accuracy die stays at 6 so a -1 Difficulty is a visible -6 on the roll.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_biting_retort.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

## The id the in-memory carrier Kit is given by hand. `mt_` because it stands in for a trait-shaped
## carrier; nothing in ContentLibrary answers to it and nothing needs to.
const PROBE_KIT_ID := &'mt_probe_biting_retort'
## The two action ids, mirrored as literals inside the inner classes (an inner class cannot be relied
## on to see the outer script's constants). test_fixture_the_ids_match_the_inner_classes pins them.
const PRE_ID := &'action_probe_retort_pre'
const POST_ID := &'action_probe_retort_post'
## Candidate B's marker, written on the shared GearCore by the PRE half and read by the POST half.
const ARMED_KEY := 'probe_retort_armed'
## Vanilla Brace, removed from the Primrose by arm(). See the header.
const BRACE_ID := &'ms_brace'

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)

## The one die that is not pinned to 1: the accuracy/difficulty die. Dice.roll_d6_accuracy(-1) rolls
## one d6, takes the max, and multiplies by signi(count) (dice.gd:86-88, :66), so a 6 here reads back
## as accuracy_roll == -6.
const ACCURACY_DIE := 6
const HIT_D20 := 19   ## beats evasion 8 (+ up to 3 of Effervescent Immunity) even at -6, never crits
const MISS_D20 := 1   ## cannot beat any evasion this fixture hands out

var game:Gamemaster
var responder
var primrose:Unit
var brawler:Unit
var probe_gear:GearCore
var recorder:RollRecorder


# ============================== THE IN-MEMORY PIECES ==============================

## A passive that never applies, and only takes a reference to the AttackRoll it was shown. See the
## header: this is the measurement channel that does not presuppose the answer to P2/P3.
class RollRecorder extends Buff:
	var reads := 0
	var last_roll:AttackRoll = null

	func _init() -> void:
		to = Buff.TO.MODIFY_ATTACK_ROLL
		hide_from_player = true

	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		if AttackRoll.is_valid(context.object):
			reads += 1
			last_roll = context.object
		return false ## never actually a modifier, so never collected and never consumed


## THE PRE HALF, which is action_warp_shield.gd with counters bolted on. Everything it applies is
## injected by the test, so one class serves P1, P2, P3 and P4.
class ProbeRetortPre extends ActionReactionAttacked:
	var difficulty:Buff = null      ## the -1 Difficulty, applied to the DEFENDER (i.e. us)
	var observer:Buff = null        ## the POST observer under test, or null
	var arms_gear_marker := false   ## candidate B: write ARMED_KEY on our own GearCore

	var triggers := 0               ## times triggers_on_event said yes (= times it was OFFERED)
	var accepts := 0                ## times the player said yes

	func _init() -> void:
		original_id = &'action_probe_retort_pre'
		usage_group = &'probe_retort_pre'
		triggers_on.append(ReactionBus.TRIGGER.ATTACK)
		trigger_timing = ReactionBus.TIMING.PRE
		require_unit_to_be = UNIT_ROLE.DEFENDER
		require_attacker_relation = RELATION.ENEMIES
		require_attacker_to_be_in_los = true
		weapon_types.append(Lancer.WEAPON_TYPE.MELEE)
		allow_basic = true

	func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
		if not super(unit, gear, triggering_event): return false
		triggers += 1
		return true

	## action_warp_shield.gd:5-19 verbatim, plus the bookkeeping. The confirm IS the offer, and
	## returning before spend_actions is what leaves the reaction unspent (there is no engine-level
	## reaction prompt: reaction_bus.gd:52-58 queues the activation and asks nobody).
	func activate(context:Context, activation:EventCore) -> void:
		var triggering_context:Context = context.event.context
		var defender:Unit = triggering_context.target_unit
		var declared:DeclaredAttackSummary = triggering_context.resource

		var confirmed := await CommonActionUtil.confirm_use(
			context, [defender], declared.all_attacked_tiles, SpecificAction.from_context(triggering_context)
		)
		if activation.abort_when(not confirmed): return
		spend_actions(activation)
		accepts += 1

		if difficulty: apply_buff(activation, defender, difficulty)
		if observer: apply_buff(activation, defender, observer)
		if arms_gear_marker: activation.context.gear.set_state('probe_retort_armed', true)


## THE POST OBSERVER, as a triggered Buff. `until` and the self-clear mode are set per test, which is
## the whole experiment: P2 is until = FINISH_ATTACK_ROLL, P3 is until = END_OF_THIS_TURN.
class ProbeObserver extends Buff:
	enum CLEAR { NEVER, EXPLICIT, SUPER }
	var clear_mode:CLEAR = CLEAR.EXPLICIT

	var fires := 0
	var saw_hit:Array = []       ## roll.hit, one entry per activation
	var saw_attacker:Array = []  ## the attacking Unit, one entry per activation

	func _init() -> void:
		hide_from_player = true
		triggers_on.append(ReactionBus.TRIGGER.ATTACK)
		trigger_timing = ReactionBus.TIMING.POST

	## Deliberately empty, buff_uncertainty_field_break.gd's reasoning: a required prop is re-checked
	## at EXECUTION time as well as at collection time, and everything read below is read defensively.
	func get_required_triggering_context() -> Array[Context.PROP]:
		return []

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.target_unit != unit: return false ## WE were the one attacked
		return AttackRoll.is_valid(context.object)   ## hit or miss alike: we fire either way

	func activate(core:BuffCore, activation:EventCore) -> void:
		var context:Context = activation.context.event.context
		var unit:Unit = activation.context.unit
		fires += 1
		saw_hit.append(AttackRoll.check(context.object, &'hit'))
		saw_attacker.append(context.unit.get_attacker(context))
		match clear_mode:
			CLEAR.EXPLICIT: UnitCondition.clear_buff(activation, unit, core)
			CLEAR.SUPER: super(core, activation) ## Buff.activate's default body IS the clear (buff.gd:254-255)
			CLEAR.NEVER: pass


## A buff that never fires and only records what unit.state.buffs looked like at the moment
## ReactionBus polled it. does_buff_trigger calls triggers_on_event during the poll itself
## (reaction_bus.gd:133-139), which is the only vantage point from which "was the observer still on
## the unit when POST was asked?" can be answered directly. until = MANUAL (the default), so nothing
## in the attack's tail can take it away first.
class PostWitness extends Buff:
	var watched:Buff = null
	var polls := 0
	var watched_present_at_poll:Array = []

	func _init() -> void:
		hide_from_player = true
		triggers_on.append(ReactionBus.TRIGGER.ATTACK)
		trigger_timing = ReactionBus.TIMING.POST

	func get_required_triggering_context() -> Array[Context.PROP]:
		return []

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.target_unit != unit: return false
		if not AttackRoll.is_valid(context.object): return false
		polls += 1
		watched_present_at_poll.append(
			unit.state.buffs.any(func(c:BuffCore) -> bool: return c.base == watched)
		)
		return false ## never activates, so never clears itself


## CANDIDATE B: a second reaction on the SAME Kit, at POST, gated on the marker the PRE half wrote.
## consumes_rxn = false, so action_reaction.gd:69's hard limit becomes 99 and the marker is the only
## thing standing between it and every hostile melee miss - which test_p4_d proves by removing it.
class ProbeRetortPost extends ActionReactionAttacked:
	var require_marker := true
	var triggers := 0
	var fires := 0
	var saw_hit:Array = []

	func _init() -> void:
		original_id = &'action_probe_retort_post'
		usage_group = &'probe_retort_post'
		triggers_on.append(ReactionBus.TRIGGER.ATTACK)
		trigger_timing = ReactionBus.TIMING.POST
		require_unit_to_be = UNIT_ROLE.DEFENDER
		require_attacker_relation = RELATION.ENEMIES
		require_attacker_to_be_in_los = true
		weapon_types.append(Lancer.WEAPON_TYPE.MELEE)
		allow_basic = true
		require_miss = true
		consumes_rxn = false

	func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
		if not super(unit, gear, triggering_event): return false
		if require_marker and not gear.get_state('probe_retort_armed', false): return false
		triggers += 1
		return true

	func activate(context:Context, activation:EventCore) -> void:
		var triggering_context:Context = context.event.context
		fires += 1
		saw_hit.append(AttackRoll.check(triggering_context.object, &'hit'))
		spend_actions(activation)
		activation.context.gear.set_state('probe_retort_armed', false)


# ============================== FIXTURE ==============================

func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	brawler = PrimroseFixture.create_hostile(game, ADJACENT)
	PrimroseFixture.equip_heavy_melee(brawler)
	PrimroseFixture.equip_main_rifle(brawler)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Hang a hand-built Kit carrying `actions` on the Primrose, and attach the roll recorder.
##
## CALLED BY EVERY TEST RATHER THAN BY before_each, because the Kit's contents ARE the experiment.
func arm(actions:Array) -> void:
	var kit := Kit.new()
	kit.compcon_id = PROBE_KIT_ID
	kit.actions.assign(actions)
	primrose.core.loadout.equipped_kits.append(kit)
	SpecFactory.apply_passive_buffs(primrose)
	probe_gear = primrose.get_gear(PROBE_KIT_ID)
	assert_true(GearCore.is_valid(probe_gear), 'fixture: the probe Kit became a GearCore on the Primrose.')
	drop_brace()
	recorder = RollRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), primrose, recorder)

## Take vanilla Brace off the Primrose's BASIC loadout, then rebuild the reaction cache by hand.
##
## AFTER the last full_repair, and it has to be: regenerate_derived_gear rebuilds `basic` from the
## KitList whenever its size no longer matches (loadout_core.gd:190-194), so a strip before a repair
## would simply be undone. regenerate_caches() is what re-reads get_reactions() into
## reactions_by_trigger (:284-296).
func drop_brace() -> void:
	var kept:Array[GearCore] = []
	for gear:GearCore in primrose.core.loadout.basic:
		if gear.kit.compcon_id != BRACE_ID: kept.append(gear)
	primrose.core.loadout.basic = kept
	primrose.core.loadout.regenerate_caches()

## The standard PRE half: -1 Difficulty on the incoming roll, nothing else.
func difficulty_buff() -> BuffBonus:
	var buff := BuffBonus.new()
	buff.to = Buff.TO.ATTACK_ROLL_INCOMING
	buff.bonus_subtype = Buff.BONUS_SUBTYPE.ACCURACY
	buff.bonus_value = -1
	buff.is_onetime = true
	buff.until = Lancer.UNTIL.FINISH_ATTACK_ROLL
	buff.hide_from_player = true
	return buff

func observer(until:Lancer.UNTIL, clear_mode:ProbeObserver.CLEAR = ProbeObserver.CLEAR.EXPLICIT) -> ProbeObserver:
	var buff := ProbeObserver.new()
	buff.until = until
	buff.clear_mode = clear_mode
	return buff

func watch(watched:Buff) -> PostWitness:
	var w := PostWitness.new()
	w.watched = watched
	UnitCondition.apply_buff(SpecFactory.dummy_event(), primrose, w)
	return w

## Pin the whole global cheat queue: the d20, then the accuracy die, then forty 1s of buffer. See the
## file header for why everything after the accuracy die is a 1.
func pin_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = [ACCURACY_DIE]
	for i:int in 40: buffer.append(1)
	Dice.cheat_attack([d20], buffer)

## End `unit`'s turn and open a fresh one. Used by exactly one test, which measures what a turn
## boundary does to an END_OF_THIS_TURN observer; every OTHER repeat swing goes through
## swing_again(), so that no test accidentally measures a turn boundary it did not mean to.
func fresh_turn(unit:Unit) -> void:
	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

## One melee swing by the brawler at the Primrose, with the dice pinned, guarded against vacuity.
func swing(d20:int, flags:Array = []) -> void:
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(d20)
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.HEAVY_MELEE, primrose, flags)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'fixture: the swing really rolled.')

## A SECOND swing with the same weapon inside the SAME open turn.
##
## Without AS_FREEBIE the repeat-action rule refuses it SILENTLY - the caller's await returns
## normally and nothing is logged as unavailable - and the flag buys past that one rule and nothing
## else (unit_action.gd:114 short-circuits can_activate_gear, :225 skips the spend).
## test_ors_hypercharge.gd:405 and test_magnetic_weight_redistribution.gd:269 are the precedents.
##
## SAME TURN IS THE POINT, not a convenience: the Primrose's reaction point is still spent, so the
## PRE half cannot re-arm the observer, and anything the observer does on this swing is left over
## from the first one.
func swing_again(d20:int) -> void:
	await swing(d20, [Action.FLAG.AS_FREEBIE])

## The same, with the rifle - the negative control for weapon_types.
func shoot() -> void:
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.MAIN_RIFLE, primrose)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'fixture: the shot really rolled.')

## How many of the recorded yes/no prompts were OUR reaction's offer, counted by the action id that
## CommonActionUtil.confirm_use bakes into the title through battle_log.formatted_action. Counted by
## name rather than by total, test_shimmering_shield.gd's reasoning: a total is a measurement of the
## whole scene, and this file has already been surprised once by a second prompt it did not raise.
func offers_for(action_id:StringName) -> int:
	var count := 0
	for prompt:Dictionary in responder.yesno_prompts:
		if str(prompt.get('title', '')).contains(action_id): count += 1
	return count

func difficulty_total() -> int:
	if recorder.last_roll == null: return 0
	return recorder.last_roll.pre.accuracy_mods_total()

## How many lines of the roll's own breakdown are a -1 Difficulty. Read off the named mod list rather
## than off the total, test_shimmering_shield.gd's reasoning: the total is the sum of every accuracy
## source on the roll, so watching only the total measures the map as much as the reaction.
func minus_one_lines() -> int:
	if recorder.last_roll == null: return 0
	var count := 0
	for mod:AttackRoll.AccuracyMod in recorder.last_roll.pre.accuracy_mods:
		if mod.mod == -1: count += 1
	return count


# ============================== FIXTURE CHARACTERISATION ==============================

func test_fixture_the_hand_built_kit_reaches_the_reaction_bus() -> void:
	var pre := ProbeRetortPre.new()
	arm([pre])
	assert_eq(probe_gear.kit.compcon_id, PROBE_KIT_ID, 'The hand-set compcon_id survives.')
	assert_true(probe_gear.kit.has_reaction(), 'The Kit answers has_reaction().')
	assert_true(
		primrose.core.loadout.reactions_by_trigger.get(ReactionBus.TRIGGER.ATTACK, []).has(probe_gear),
		'And regenerate_caches put the gear in reactions_by_trigger[attack] - the only list '
		+ 'ReactionBus.trigger_occurred reads (reaction_bus.gd:51).')

func test_fixture_the_ids_match_the_inner_classes() -> void:
	assert_eq(ProbeRetortPre.new().get_id(), PRE_ID, 'PRE_ID mirrors the literal in ProbeRetortPre.')
	assert_eq(ProbeRetortPost.new().get_id(), POST_ID, 'POST_ID mirrors the literal in ProbeRetortPost.')

func test_fixture_vanilla_brace_is_off_the_primrose_and_raises_no_prompt() -> void:
	arm([])
	assert_false(GearCore.is_valid(primrose.get_gear(BRACE_ID)), 'ms_brace is gone from the loadout.')
	await swing(HIT_D20)
	assert_gt(primrose.core.get_health_max() - primrose.core.current.health, 0,
		'vacuity guard: the swing landed, which is the case that used to raise the Brace prompt.')
	assert_eq(responder.yesno_prompts.size(), 0,
		'And with no probe reaction installed, a landed hostile swing raises no yes/no at all.')

func test_fixture_the_recorder_sees_a_plain_swing() -> void:
	arm([])
	await swing(HIT_D20)
	assert_gt(recorder.reads, 0, 'The MODIFY_ATTACK_ROLL channel showed the recorder the roll.')
	assert_not_null(recorder.last_roll, 'And it kept the reference.')
	assert_eq(recorder.last_roll.base_roll, HIT_D20, 'The d20 is the one that was pinned.')
	assert_eq(recorder.last_roll.accuracy_roll, 0, 'No accuracy source on a bare swing.')
	assert_eq(recorder.last_roll.total_roll, HIT_D20, 'So the total is the raw d20.')
	assert_true(recorder.last_roll.hit, 'And 19 beats the Primrose evasion.')


# ============================== P1: DOES THE PRE HALF WORK AT ALL? ==============================

func test_p1_a_a_hostile_melee_swing_offers_the_pre_reaction() -> void:
	var pre := ProbeRetortPre.new()
	arm([pre])
	responder.yesno_queue.append(false)
	await swing(HIT_D20)
	assert_eq(pre.triggers, 1, 'triggers_on_event said yes exactly once.')
	assert_eq(offers_for(PRE_ID), 1,
		'And CommonActionUtil.confirm_use raised exactly one yes/no naming this reaction - there is '
		+ 'no engine-level reaction prompt (reaction_bus.gd:52-58 queues the activation and asks '
		+ 'nobody), so the confirm IS the offer.')
	assert_eq(responder.yesno_prompts.size(), 1, 'And nothing else asked anything.')
	assert_not_null(recorder.last_roll, 'vacuity guard: the attack itself resolved.')

func test_p1_b_a_ranged_swing_offers_nothing() -> void:
	var pre := ProbeRetortPre.new()
	arm([pre])
	await shoot()
	assert_eq(pre.triggers, 0, 'weapon_types = [MELEE] refused the rifle.')
	assert_eq(offers_for(PRE_ID), 0, 'So nothing was offered.')
	assert_not_null(recorder.last_roll, 'vacuity guard: the shot itself resolved.')

func test_p1_c_accepting_puts_one_difficulty_on_the_roll() -> void:
	var pre := ProbeRetortPre.new()
	pre.difficulty = difficulty_buff()
	arm([pre])

	responder.yesno_queue.append(false)
	await swing(HIT_D20)
	var baseline := difficulty_total()
	var baseline_accuracy_roll:int = recorder.last_roll.accuracy_roll
	var baseline_total:int = recorder.last_roll.total_roll

	responder.yesno_queue.append(true)
	await swing_again(HIT_D20) ## same turn: declining the first offer left the reaction point in hand

	assert_eq(pre.accepts, 1, 'Exactly one of the two offers was accepted.')
	assert_eq(baseline, 0, 'The declined swing carried no accuracy modifier at all.')
	assert_eq(baseline_accuracy_roll, 0, 'And rolled no accuracy die (dice.gd:86-88 skips it at 0).')
	assert_eq(baseline_total, HIT_D20, 'So its total was the raw d20.')

	assert_eq(difficulty_total(), -1,
		'THE MEASUREMENT: the accepted swing is at -1. PreAttack.create folds an '
		+ 'ATTACK_ROLL_INCOMING accuracy buff into a named AccuracyMod (attack_roll.gd:181-189), and '
		+ 'the PRE reaction ran before AttackRoll.create (event_unit_attack.gd:31-32 then :53).')
	assert_eq(minus_one_lines(), 1, 'One line, and it is the reaction\'s.')
	assert_eq(recorder.last_roll.accuracy_roll, -ACCURACY_DIE,
		'Which cost the roll a full difficulty die: roll_d6_accuracy(-1) takes the max of one d6 and '
		+ 'multiplies by signi(count) (dice.gd:86-88, sum_rolls at :66).')
	assert_eq(recorder.last_roll.total_roll, HIT_D20 - ACCURACY_DIE, 'And the total moved by exactly that.')

func test_p1_d_the_difficulty_buff_is_gone_after_the_roll() -> void:
	var pre := ProbeRetortPre.new()
	var difficulty := difficulty_buff()
	pre.difficulty = difficulty
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(HIT_D20)
	assert_eq(pre.accepts, 1, 'fixture: the reaction was accepted.')
	assert_false(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == difficulty),
		'is_onetime + until = FINISH_ATTACK_ROLL leaves nothing behind: consume_buffs takes the '
		+ 'one-time buffs the roll applied (event_unit_attack.gd:114) and clear_buffs_until sweeps '
		+ 'the rest (:120).')


# ================ P2: THE DESIGN'S OBSERVER - FINISH_ATTACK_ROLL AT POST ================

func test_p2_a_a_finish_attack_roll_observer_never_fires_at_post() -> void:
	var obs := observer(Lancer.UNTIL.FINISH_ATTACK_ROLL, ProbeObserver.CLEAR.NEVER)
	var pre := ProbeRetortPre.new()
	pre.difficulty = difficulty_buff()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)

	assert_eq(pre.accepts, 1, 'fixture: the reaction was accepted, so the observer WAS applied.')
	assert_false(recorder.last_roll.hit, 'fixture: and the attack missed, which is the riposte case.')
	assert_eq(obs.fires, 0,
		'THE FINDING: it never fires. event_unit_attack.gd:120 clears every '
		+ 'until = FINISH_ATTACK_ROLL buff off the unit, and :123 queues the POST reactions on the '
		+ 'line after - so the observer is gone before anything asks it. Design 3.1 cannot be built '
		+ 'as written.')

func test_p2_b_it_is_already_off_the_unit_when_post_is_polled() -> void:
	var obs := observer(Lancer.UNTIL.FINISH_ATTACK_ROLL, ProbeObserver.CLEAR.NEVER)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	var witness := watch(obs)
	responder.yesno_queue.append(true)
	await swing(MISS_D20)

	assert_eq(pre.accepts, 1, 'fixture: the observer was applied.')
	assert_eq(witness.polls, 1,
		'fixture: ReactionBus polled this unit\'s buffs exactly once at ATTACK POST '
		+ '(reaction_bus.gd:61-67).')
	assert_eq(witness.watched_present_at_poll, [false],
		'AND THE OBSERVER WAS ALREADY GONE AT THAT MOMENT. This is the mechanism behind P2, measured '
		+ 'from inside the poll itself rather than inferred from the fire count: '
		+ 'UnitCondition.clear_buff erases the BuffCore from unit.state.buffs synchronously '
		+ '(unit_condition.gd:980).')


# ============ P3: CANDIDATE A - A LONGER-LIVED, SELF-CLEARING OBSERVER ============

func test_p3_a_an_end_of_this_turn_observer_fires_once_at_post_on_a_miss() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN)
	var pre := ProbeRetortPre.new()
	pre.difficulty = difficulty_buff()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)

	assert_eq(obs.fires, 1, 'It fires, exactly once. A buff that outlives :120 is still in '
		+ 'unit.state.buffs when :123 polls.')
	assert_eq(obs.saw_hit, [false], 'And it read the roll\'s outcome: a miss.')
	assert_eq(obs.saw_attacker, [brawler],
		'And the attacker, through context.unit.get_attacker(context) - the same accessor '
		+ 'event_unit_attack.gd:38 uses.')

func test_p3_b_it_fires_on_a_hit_too_so_it_can_clean_itself_up() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN)
	var pre := ProbeRetortPre.new()
	pre.difficulty = difficulty_buff()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(HIT_D20)

	assert_true(recorder.last_roll.hit, 'fixture: the swing landed even at -1.')
	assert_eq(obs.fires, 1, 'It still gets an activation on a hit - which is what gives it somewhere '
		+ 'to clear itself. triggers_on_event deliberately does not gate on roll.hit.')
	assert_eq(obs.saw_hit, [true], 'And it can tell: the riposte would simply return here.')

## Split in two rather than looped over [MISS_D20, HIT_D20] inside one test: a second before_each()
## call would hand the scene a SECOND mod_choice_responder through add_child_autoqfree, and two live
## responders both answer every request (primrose_fixture.gd:95).
func test_p3_c_clearing_itself_inside_activate_takes_it_off_on_the_miss_path() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(obs.fires, 1, 'fixture: it fired on the miss.')
	assert_false(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'And cleared itself inside its own activation, via UnitCondition.clear_buff.')

func test_p3_c2_and_on_the_hit_path() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(HIT_D20)
	assert_eq(obs.fires, 1, 'fixture: it fired on the hit too.')
	assert_false(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'THE TEST THAT CATCHES AN OBSERVER THAT OUTLIVES ITS ROLL: nothing is left armed after a hit '
		+ 'either.')

func test_p3_d_super_does_the_clearing_just_as_well() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN, ProbeObserver.CLEAR.SUPER)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(obs.fires, 1, 'fixture: it fired.')
	assert_false(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'Buff.activate\'s default body IS UnitCondition.clear_buff(activation, '
		+ 'activation.context.unit, core) (buff.gd:254-255), so a trailing super() is the same '
		+ 'clear written shorter. Task 3 should call the explicit clear FIRST instead, so an early '
		+ 'return inside the riposte cannot leave a second one armed.')

func test_p3_e_without_the_self_clear_it_fires_again_on_the_next_swing() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN, ProbeObserver.CLEAR.NEVER)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(obs.fires, 1, 'fixture: the first swing fired it.')
	assert_true(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'fixture: and with CLEAR.NEVER it is still on the unit.')

	await swing_again(MISS_D20)
	assert_eq(pre.accepts, 1,
		'fixture: nothing re-armed - the reaction point is spent, so the PRE half was not even '
		+ 'offered a second time.')
	assert_eq(obs.fires, 2,
		'THE SELF-CLEAR IS LOAD-BEARING: an observer that survives its own roll ripostes every '
		+ 'further attack in the turn off ONE accepted reaction. Nothing in the attack pipeline '
		+ 'takes an END_OF_THIS_TURN buff away.')

func test_p3_f_a_self_clearing_observer_does_not_fire_on_a_later_swing() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(obs.fires, 1, 'fixture: the armed swing fired it once.')

	await swing_again(MISS_D20)
	assert_eq(pre.accepts, 1, 'fixture: the second swing re-armed nothing.')
	assert_eq(obs.fires, 1, 'And the riposte stayed silent: no observer, no riposte.')
	assert_not_null(recorder.last_roll, 'vacuity guard: the second swing really rolled.')

## MEASURED, NOT ASSUMED, and it corrects this file's own first draft. BuffCore.turn_count starts at
## 0 (buff_core.gd:7) and end_turn_for_statuses clears an END_OF_THIS_TURN buff as soon as
## turn_count >= 0 (unit_condition.gd:33-42) - on EVERY unit, at the end of EVERY turn, not only at
## the holder's own. So the observer cannot outlive the attacker's turn even with CLEAR.NEVER, which
## is exactly the safety net Task 3 wants underneath the self-clear.
func test_p3_g_an_end_of_this_turn_observer_cannot_outlive_the_attackers_turn() -> void:
	var obs := observer(Lancer.UNTIL.END_OF_THIS_TURN, ProbeObserver.CLEAR.NEVER)
	var pre := ProbeRetortPre.new()
	pre.observer = obs
	arm([pre])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_true(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'fixture: it is on the unit while the attacker\'s turn is still open.')

	await fresh_turn(brawler)
	assert_false(
		primrose.state.buffs.any(func(c:BuffCore) -> bool: return c.base == obs),
		'And the attacker\'s own turn end swept it off the PRIMROSE - end_turn_for_statuses runs '
		+ 'over every unit on the map.')

	responder.yesno_queue.append(false) ## the fresh turn handed the reaction point back; decline it
	await swing(MISS_D20)
	assert_eq(obs.fires, 1, 'So a swing on the other side of the boundary finds nothing to fire.')


# ============ P4: CANDIDATE B - A SECOND REACTION GATED ON A GEAR MARKER ============

func test_p4_a_a_marker_gated_post_reaction_fires_on_the_miss() -> void:
	var pre := ProbeRetortPre.new()
	pre.difficulty = difficulty_buff()
	pre.arms_gear_marker = true
	var post := ProbeRetortPost.new()
	arm([pre, post])
	responder.yesno_queue.append(true)
	await swing(MISS_D20)

	assert_eq(pre.accepts, 1, 'fixture: the PRE half was accepted, so the marker was written.')
	assert_eq(post.fires, 1, 'The POST reaction fired on the miss.')
	assert_eq(post.saw_hit, [false], 'And require_miss is what let it through '
		+ '(action_reaction_attacked.gd:101-107).')
	assert_false(probe_gear.get_state(ARMED_KEY, false), 'And it disarmed the marker behind itself.')

func test_p4_b_it_does_not_fire_when_the_pre_half_was_declined() -> void:
	var pre := ProbeRetortPre.new()
	pre.arms_gear_marker = true
	var post := ProbeRetortPost.new()
	arm([pre, post])
	responder.yesno_queue.append(false)
	await swing(MISS_D20)

	assert_eq(pre.accepts, 0, 'fixture: declined.')
	assert_false(probe_gear.get_state(ARMED_KEY, false), 'fixture: so nothing armed the marker.')
	assert_eq(post.triggers, 0, 'And the POST reaction was never even offered.')
	assert_eq(post.fires, 0, 'Let alone fired.')
	assert_false(recorder.last_roll.hit, 'vacuity guard: this WAS a miss - the case it exists for.')

func test_p4_c_require_miss_keeps_it_off_a_hit() -> void:
	var pre := ProbeRetortPre.new()
	pre.arms_gear_marker = true
	var post := ProbeRetortPost.new()
	arm([pre, post])
	responder.yesno_queue.append(true)
	await swing(HIT_D20)

	assert_eq(pre.accepts, 1, 'fixture: armed.')
	assert_true(recorder.last_roll.hit, 'fixture: and the swing landed.')
	assert_eq(post.fires, 0, 'require_miss refused it.')
	assert_true(probe_gear.get_state(ARMED_KEY, false),
		'BUT THE MARKER IS STILL SET - a hit gives candidate B nowhere to disarm itself, so it needs '
		+ 'a second cleanup path that candidate A gets for free.')

func test_p4_d_without_the_marker_it_fires_on_any_hostile_melee_miss() -> void:
	var post := ProbeRetortPost.new()
	post.require_marker = false
	arm([post]) ## no PRE half at all
	await swing(MISS_D20)

	assert_eq(post.fires, 1,
		'THE MARKER IS THE ONLY GATE. consumes_rxn = false makes get_per_round_hard_limit 99 '
		+ '(action_reaction.gd:69) and is_available_to_activate short-circuit true (:51), so nothing '
		+ 'else was ever holding this reaction back.')

func test_p4_e_consumes_rxn_false_leaves_the_rounds_reaction_point_unspent() -> void:
	var post := ProbeRetortPost.new()
	post.require_marker = false
	arm([post])
	await PrimroseFixture.open_turn(game, brawler)
	var before:int = primrose.core.current.reactions
	assert_eq(before, 1, 'fixture: the turn start re-issued the Primrose its reaction point.')
	await swing(MISS_D20)
	assert_eq(post.fires, 1, 'fixture: it fired.')
	assert_eq(primrose.core.current.reactions, before,
		'And spent nothing: UnitAction.spend only takes a reaction point when the action '
		+ 'consumes_reaction().')

func test_p4_f_the_pre_half_by_contrast_does_spend_it() -> void:
	var pre := ProbeRetortPre.new()
	arm([pre])
	await PrimroseFixture.open_turn(game, brawler)
	assert_eq(primrose.core.current.reactions, 1, 'fixture: one reaction point in hand.')
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(pre.accepts, 1, 'fixture: accepted.')
	assert_eq(primrose.core.current.reactions, 0,
		'consumes_rxn defaults to true, which is what buys the card its 1/round - and is why '
		+ 'action_biting_retort.gd must NOT override get_per_round_hard_limit.')
