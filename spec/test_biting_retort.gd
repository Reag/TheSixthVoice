# BITING RETORT - the OFFER and the +1 DIFFICULTY (Primrose SP3 Task 2).
#
#   "Biting Retort (Reaction, 1/round)
#    Trigger: A hostile character within line of sight attempts to hit you with a melee attack.
#    Effect:  The attack is made with +1 Difficulty. If the attack misses, the attacker takes 3 AP
#             Kinetic damage and must succeed a Hull save or be knocked prone."
#   (specs/sixth-voice/07-primrose.md, Rank II, "Weapon: Acrasial Falcata")
#
# THIS FILE COVERS THE FIRST SENTENCE AND THE TRIGGER. The riposte - the second sentence - is Task 3's
# and lands in this same file, against the self-clearing POST observer Task 0's probe settled on
# (ruling 25). Nothing here anticipates it.
#
# WHY THE CARD IS SPLIT ACROSS THE ATTACK PIPELINE. The +1 Difficulty has to land BEFORE the roll is
# built - event_unit_attack.gd awaits the PRE reactions at :31-32 and only calls AttackRoll.create at
# :53 - so the offer is an ATTACK **PRE** reaction, which is the Saladin's Warp Shield
# (content/frames/ha/mf_saladin/mt_warp_shield/) byte for byte. The riposte cannot be decided until
# after the roll exists, which is why it is a separate mechanism rather than more lines in the same
# activate().
#
# ---------------------------------------------------------------------------------------------
# HOW THE ROLL IS MEASURED, AND WHY NOT BY WHETHER THE ATTACK HIT
#
# RollRecorder below is Task 0's instrument, copied here because Task 3 deletes the probe file
# (spec/test_spike_biting_retort.gd) that first carried it. It is a Buff.TO.MODIFY_ATTACK_ROLL passive
# that NEVER APPLIES and only keeps a reference: event_unit_attack.gd:345-358 builds a context carrying
# `object = roll` and queries MODIFY_ATTACK_ROLL buffs on both the attacker and the target at every
# SEQUENCE_STEP, the first of which (auto_miss, :144) runs immediately after AttackRoll.create at :53 -
# so `roll.pre` is already final there. UnitCondition.does_buff_apply reaches
# check_if_passive_applies (unit_condition.gd:845-851), where the recorder takes the AttackRoll
# REFERENCE and returns false, so it never enters step_buffs and is never consumed. The roll is mutated
# in place afterwards (attack_roll.gd:65-71), so the same reference reads back the final base_roll,
# accuracy_roll, total_roll and hit.
#
# Measuring "did the attack flip from hit to miss" instead would measure the Primrose's evasion (8,
# plus up to 3 of Effervescent Immunity, which climbs on every miss this file forces) as much as the
# reaction. The roll's own named breakdown line cannot drift that way.
#
# WHY VANILLA BRACE IS TAKEN OFF THE PRIMROSE (drop_brace, measured by Task 0's first RED run):
# ms_brace is in every player mech's basic loadout - Frame.create_dummy()'s knockoff Everest is a
# PLAYER mech whatever its faction, so loadout_core.gd:184-185 hands both units the player list - and
# it is a reaction on DAMAGE **PRE** (content/gear/basic/ms_brace/action_brace.tres:8-9). So every
# swing that LANDS raises a second yes/no on the defender and competes for the same single reaction
# point. That is real engine behaviour the shipped card lives with: a Primrose that accepts Biting
# Retort has already spent the round's reaction and will not be offered Brace when the blow lands, and
# vice versa. Inside a file whose measurements ARE prompt counts and reaction points it is noise, so
# it is removed AND every count below is taken by NAME (offers()). Both, per the plan.
#
# WHY THE DAMAGE DICE ARE PINNED TO 1 AND ONLY THE ACCURACY DIE TO 6 (pin_dice): the Primrose is
# health 8 / armor 1 / evasion 8 (mf_primrose.tres:26-28) and the fixture is deliberately not
# FrameIsolation'd (primrose_fixture.gd:7-11), so its stats cannot be raised. A Heavy melee weapon
# rolling sixes is 13 damage and kills it mid-test. With 1s it is 2d6+1 = 3, less armor 1. The
# accuracy die stays at 6 so a -1 Difficulty is a visible -6 on the roll.
#
# AND WHY MOST SWINGS AT THE PRIMROSE ARE PINNED TO MISS. Dice.CHEAT_ROLL_QUEUE is ONE FLAT FIFO
# (dice.gd:13-17): the leading 6 is meant for the difficulty die, and on a roll that has NO accuracy
# source - a declined offer, an attack this reaction refuses - nothing consumes it, so it is handed
# straight to the first DAMAGE die instead. Measured on this file's first green run: a Falcata in the
# brawler's hands then deals 6+1+4 = 11, less armor 1 = 10, which structures an 8-health Primrose on
# the first blow and destroys it on the second - and a destroyed defender is not offered anything,
# which reads exactly like a broken gate. It cost the blinded-LOS control one red. Every test below
# that needs the Primrose to survive two attacks therefore uses MISS_D20; this is no loss of coverage,
# because the offer is raised at ATTACK PRE, before the roll exists at all, so hit and miss are the
# same case for everything in this task.
#
# ---------------------------------------------------------------------------------------------
# THREE JUDGMENT CALLS THIS TASK OWNED, all settled by measurement; the reasoning that belongs with
# the content is in action_biting_retort.gd's own header.
#
#  1. RULING 8 IS GATED ON THE RAW `action.threat`, NOT ON threat_distance(). Both are available at
#     PRE - test_the_triggering_context_carries_the_whole_trifecta measures that
#     SpecificAction.from_context(triggering context) is valid there, so threat_distance() COULD have
#     been called - and the raw field is still the right one, because threat_distance() folds in the
#     attacker's own THREAT_RANGE buffs and would therefore read a THROWN weapon in a threat-buffed
#     attacker's hands as a swing. test_a_thrown_attack_from_a_threat_buffed_attacker_still_offers_
#     nothing is the case that separates them, and it is the engine's own reading: get_target_range
#     (action_attack_weapon.gd:197-201) and ignores_cover (:206-212) both discriminate a throw on the
#     raw `threat > 0`.
#  2. THE ROLL IS MEASURED, NOT THE BUFF - see RollRecorder above.
#  3. action.show_in_tooltip(kit) ANSWERS TRUE HERE, and test_the_reaction_is_drawn_on_the_weapons_
#     card measures it rather than assuming. The Maiden's Blush's mt_uncertainty_field is the
#     precedent where the same question answered FALSE, and the difference is the localisation, not
#     the archetype: Action.show_in_tooltip (action.gd:350-353) returns false when the action has no
#     `effect` row of its own or when its row is the same string as the Kit's. The Uncertainty Field
#     prints its whole effect on the TRAIT's row and gives the action none; this reaction has its own
#     `.effect` row, different from gear.mw_acrasial_falcata.effect, so it is drawn. ICON_TARGETS'
#     row in test_content_integrity.gd is set to match, and that file's own
#     _action_reaches_a_player_facing_surface calls the identical function, so the two cannot drift.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_biting_retort.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const FALCATA := &'mw_acrasial_falcata'
const ATTACK := &'action_acrasial_falcata'
const RETORT := &'action_biting_retort'
const DIFFICULTY_BUFF := &'buff_biting_retort_difficulty'

const NAME_KEY := 'gear.mw_acrasial_falcata.action_biting_retort.name'
const TRIGGER_KEY := 'gear.mw_acrasial_falcata.action_biting_retort.trigger'
const EFFECT_KEY := 'gear.mw_acrasial_falcata.action_biting_retort.effect'
## THIS MOD'S OWN compiled artifact, not the global tr() - test_rend_axe.gd and
## test_acrasial_falcata.gd carry the identical const for the identical reason: get_message returns an
## EMPTY StringName for a key the artifact does not carry, where the global tr() falls back to the raw
## key, so only this lookup can attribute a row to THIS mod rather than to a sibling Reag-* mod.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## Vanilla Brace, removed from the Primrose by drop_brace(). See the header.
const BRACE_ID := &'ms_brace'
## The two ids the basic improvised attack ships under - the player list carries the first, the NPC
## list the second. Looked up rather than hard-coded, so this file does not silently stop testing
## allow_basic if the loadout branch (loadout_core.gd:176-187) ever changes for a dummy frame.
const IMPROVISED_IDS:Array[StringName] = [&'mw_improvised_attack', &'npcf_improvised_attack']
## The Primrose's own Artful Caress buff, applied by hand to a HOSTILE in the ruling-8 discriminator
## below. It is a BuffWeaponTypeBonus - THREAT_RANGE +1 on sizes [HEAVY, SUPERHEAVY], type [MELEE] -
## and nothing about it is Primrose-specific once it is on a unit.
const CARESS_BUFF := &'buff_artful_caress'

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)
const ALLY_TILE := Vector2i(4, 5)
const AT_THREE := Vector2i(7, 4)   ## exactly threat 3 away: only a Falcata reaches this
const SHOOTER_TILE := Vector2i(10, 4)

## The one die not pinned to 1: the accuracy/difficulty die. Dice.roll_d6_accuracy(-1) rolls one d6,
## takes the max and multiplies by signi(count) (dice.gd:86-88, sum_rolls at :66), so a 6 here reads
## back as accuracy_roll == -6.
const ACCURACY_DIE := 6
const HIT_D20 := 19   ## beats evasion 8 (+ up to 3 of Effervescent Immunity) even at -6, never crits
const MISS_D20 := 1   ## cannot beat any evasion this fixture hands out

var game:Gamemaster
var responder
var primrose:Unit
var brawler:Unit
var recorder:RollRecorder


# ============================== THE MEASUREMENT INSTRUMENT ==============================

## A passive that never applies and only takes a reference to the AttackRoll it was shown. Task 0's
## RollRecorder, verbatim; see this file's header for why it can be trusted.
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


## A buff that never fires and only records what the TRIGGERING CONTEXT looked like at the moment
## ReactionBus polled it at ATTACK **PRE** - which is exactly the vantage point action_biting_retort's
## own triggers_on_event is called from. ReactionBus.trigger_occurred walks unit.state.buffs beside
## reactions_by_trigger, at both timings, and calls does_buff_trigger -> triggers_on_event during the
## poll itself (reaction_bus.gd:50-67, :128-139). Task 0's PostWitness is the same shape one timing
## over. Returning false means it never activates, so it never consumes itself and never perturbs
## anything it measures.
class PreWitness extends Buff:
	var polls := 0
	var specific_was_valid:Array = []  ## SpecificAction.from_context(...) survived, one entry per poll
	var raw_threat:Array = []          ## what `action.threat` said
	var buffed_threat:Array = []       ## what threat_distance(specific) said

	func _init() -> void:
		hide_from_player = true
		triggers_on.append(ReactionBus.TRIGGER.ATTACK)
		trigger_timing = ReactionBus.TIMING.PRE

	func get_required_triggering_context() -> Array[Context.PROP]:
		return []

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.target_unit != unit: return false
		if context.action is not ActionAttackWeapon: return false
		polls += 1
		var specific := SpecificAction.from_context(context)
		specific_was_valid.append(SpecificAction.is_valid(specific))
		raw_threat.append(context.action.threat)
		buffed_threat.append(context.action.threat_distance(specific) if SpecificAction.is_valid(specific) else -1)
		return false ## never activates


# ============================== FIXTURE ==============================

func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	brawler = PrimroseFixture.create_hostile(game, ADJACENT)
	PrimroseFixture.equip(primrose, FALCATA)
	PrimroseFixture.equip_heavy_melee(brawler)
	PrimroseFixture.equip_main_rifle(brawler)
	# AFTER the last full_repair on the Primrose, and it has to be: regenerate_derived_gear rebuilds
	# `basic` from the KitList whenever its size no longer matches (loadout_core.gd:189-194), so a
	# strip before a repair would simply be undone.
	drop_brace()
	recorder = RollRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), primrose, recorder)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Take vanilla Brace off the Primrose's BASIC loadout, then rebuild the reaction cache by hand -
## regenerate_caches() is what re-reads get_reactions() into reactions_by_trigger
# (loadout_core.gd:284-296), the only list ReactionBus.trigger_occurred consults.
func drop_brace() -> void:
	var kept:Array[GearCore] = []
	for gear:GearCore in primrose.core.loadout.basic:
		if gear.kit.compcon_id != BRACE_ID: kept.append(gear)
	primrose.core.loadout.basic = kept
	primrose.core.loadout.regenerate_caches()

func falcata() -> GearCore:
	return primrose.get_gear(FALCATA)

## The reaction's own trifecta on the Primrose. NOT PrimroseFixture.specific(), which answers with the
## Kit's SOLO action - gear_core.gd:337-339 returns actions[0], i.e. the attack profile.
func retort_specific() -> SpecificAction:
	var gear := falcata()
	return SpecificAction.create(primrose, gear, gear.get_action(RETORT))

## What the player is offered, as the prompt's own title renders it.
func retort_name() -> String:
	var specific := retort_specific()
	if not SpecificAction.is_valid(specific): return '<no action_biting_retort>'
	return specific.action.name(specific)

## How many of the recorded yes/no prompts were THIS reaction's offer.
##
## BY NAME, NOT BY TOTAL. CommonActionUtil.confirm_use titles its prompt with
## X.tr('battle.confirm.use').format({action = battle_log.formatted_action(specific)})
## (common_action_util.gd:362-371), and formatted_action embeds specific.action.name(specific)
## (battle_log_bus.gd:89-99). A total is a measurement of the whole scene - Task 0's first RED run was
## two prompts where the reaction had been offered once, the second being Brace - and
# test_shimmering_shield.gd's shield_lines() makes the same argument for roll breakdown lines.
func offers() -> int:
	var wanted := retort_name()
	var count := 0
	for prompt:Dictionary in responder.yesno_prompts:
		if str(prompt.get('title', '')).contains(wanted): count += 1
	return count

## Pin the whole global cheat queue: the d20, then the accuracy die, then forty 1s of buffer.
func pin_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = [ACCURACY_DIE]
	for i:int in 40: buffer.append(1)
	Dice.cheat_attack([d20], buffer)

## One melee swing by the brawler at the Primrose, dice pinned, guarded against vacuity.
func swing(d20:int, flags:Array = []) -> void:
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(d20)
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.HEAVY_MELEE, primrose, flags)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'fixture: the swing really rolled.')

## A SECOND swing with the same weapon inside the SAME open turn.
##
## Without AS_FREEBIE the repeat-action rule refuses it SILENTLY - the caller's await returns normally
## and nothing is logged as unavailable - and the flag buys past that one rule and nothing else
## (unit_action.gd:114 short-circuits can_activate_gear, :225 skips the spend).
## test_ors_hypercharge.gd:405 and test_magnetic_weight_redistribution.gd:269 are the precedents.
##
## SAME ROUND IS THE POINT, not a convenience: uses_this_round is cleared only by
## UnitAction.reset_per_round_usage at a round boundary (unit_action.gd:87-88), never by a turn start,
## so anything measured here is really about the reaction's own 1/round.
func swing_again(d20:int) -> void:
	await swing(d20, [Action.FLAG.AS_FREEBIE])

## The rifle - the negative control for weapon_types.
func shoot() -> void:
	UnitTile.move_to(brawler, SHOOTER_TILE)
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.MAIN_RIFLE, primrose)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'fixture: the shot really rolled.')

## The roll's total accuracy, and how many of its named breakdown lines are OURS. Read off the mod list
## rather than off the total wherever it can be: the total is the sum of every accuracy source on the
## roll, so watching it alone measures the map as much as the reaction.
func accuracy_total() -> int:
	if recorder.last_roll == null: return 0
	return recorder.last_roll.pre.accuracy_mods_total()

## attack_roll.gd:189 titles an incoming-buff line with buff_core.name_text(). This reaction's chip
## carries localization_key_override = "mw_acrasial_falcata.action_biting_retort", so the line reads
## the reaction's own card name - which is what this counts, and what proves the override resolves.
func retort_lines() -> int:
	if recorder.last_roll == null: return 0
	var wanted := X.tr(NAME_KEY)
	var count := 0
	for mod:AttackRoll.AccuracyMod in recorder.last_roll.pre.accuracy_mods:
		if mod.title_key == wanted and mod.mod == -1: count += 1
	return count

func has_difficulty_buff() -> bool:
	return UnitCondition.has_buff(primrose, DIFFICULTY_BUFF)

func basic_melee_gear() -> GearCore:
	for id:StringName in IMPROVISED_IDS:
		var gear:GearCore = brawler.get_gear(id)
		if GearCore.is_valid(gear): return gear
	return null

## Hang a PreWitness on the Primrose and hand it back. See the class header.
func watch_pre() -> PreWitness:
	var witness := PreWitness.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), primrose, witness)
	return witness


# ============================== THE OFFER ==============================

func test_a_hostile_melee_attack_offers_the_reaction() -> void:
	responder.yesno_queue.append(false)
	await swing(HIT_D20)
	assert_eq(offers(), 1,
		'CommonActionUtil.confirm_use raised exactly one yes/no naming this reaction. There is no '
		+ 'engine-level reaction prompt - reaction_bus.gd:52-58 queues the activation and asks nobody '
		+ '- so the confirm IS the offer.')
	assert_not_null(recorder.last_roll,
		'VACUITY GUARD: the attack itself resolved, so "no prompt" cannot pass as "no attack".')

func test_accepting_puts_the_attack_at_minus_one() -> void:
	# One declined swing, then one accepted swing in the SAME turn (AS_FREEBIE). Declining leaves the
	# reaction point in hand, so the second offer really happens - and the two rolls are otherwise
	# identical, which is what makes the difference attributable.
	responder.yesno_queue.append(false)
	await swing(MISS_D20)
	var baseline_total:int = accuracy_total()
	var baseline_accuracy_roll:int = recorder.last_roll.accuracy_roll
	var baseline_roll:int = recorder.last_roll.total_roll

	responder.yesno_queue.append(true)
	await swing_again(MISS_D20)

	assert_eq(offers(), 2, 'fixture: both swings were offered.')
	assert_eq(baseline_total, 0, 'The declined swing carried no accuracy modifier at all.')
	assert_eq(baseline_accuracy_roll, 0, 'And rolled no accuracy die (dice.gd:86-88 skips it at 0).')
	assert_eq(baseline_roll, MISS_D20, 'So its total was the raw d20.')

	assert_eq(accuracy_total(), -1,
		'THE MEASUREMENT: the accepted swing is at -1. AttackRoll.PreAttack.create folds an '
		+ 'ATTACK_ROLL_INCOMING accuracy buff into a named AccuracyMod (attack_roll.gd:181-189), and '
		+ 'the PRE reaction ran before AttackRoll.create (event_unit_attack.gd:31-32, then :53).')
	assert_eq(retort_lines(), 1, 'One line of the breakdown, and it is titled with this reaction.')
	assert_eq(recorder.last_roll.accuracy_roll, -ACCURACY_DIE,
		'Which costs the roll a full difficulty die: roll_d6_accuracy(-1) takes the max of one d6 and '
		+ 'multiplies by signi(count) (dice.gd:86-88, sum_rolls at :66).')
	assert_eq(recorder.last_roll.total_roll, MISS_D20 - ACCURACY_DIE, 'And the total moved by exactly that.')

func test_the_difficulty_chip_is_gone_after_the_roll() -> void:
	responder.yesno_queue.append(true)
	await swing(HIT_D20)
	assert_eq(offers(), 1, 'fixture: the reaction was offered and accepted.')
	assert_eq(accuracy_total(), -1, 'fixture: and it landed on the roll.')
	assert_false(has_difficulty_buff(),
		'is_onetime + until = FINISH_ATTACK_ROLL leaves nothing behind: consume_buffs takes the '
		+ 'one-time buffs the roll applied (event_unit_attack.gd:114) and clear_buffs_until sweeps the '
		+ 'rest (:120).')

func test_accepting_spends_the_reaction_for_the_round() -> void:
	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(offers(), 1, 'fixture: offered and accepted once.')
	assert_eq(primrose.core.current.reactions, 0,
		'consumes_rxn defaults to true, which is what buys the card its 1/round - and is why '
		+ 'action_biting_retort.gd must not override get_per_round_hard_limit.')

	await swing_again(MISS_D20)
	assert_eq(offers(), 1, 'The second hostile melee swing in the same round is not offered at all.')
	assert_eq(accuracy_total(), 0,
		'VACUITY GUARD: the second swing really rolled, and rolled clean - so "not offered" is not '
		+ '"not attacked".')

func test_declining_leaves_the_roll_alone_and_the_reaction_unspent() -> void:
	responder.yesno_queue.append(false)
	await swing(MISS_D20)
	assert_eq(offers(), 1, 'fixture: offered once.')
	assert_eq(accuracy_total(), 0, 'A declined reaction leaves the roll untouched.')
	assert_eq(primrose.core.current.reactions, 1,
		'And the reaction point is still in hand: activate() returns at abort_when BEFORE '
		+ 'spend_actions, which is the whole of what "declining is free" means.')

	responder.yesno_queue.append(true)
	await swing_again(MISS_D20)
	assert_eq(offers(), 2, 'So a later melee attack in the same round is offered again.')
	assert_eq(accuracy_total(), -1, 'And accepting it still works.')

func test_swinging_the_falcata_does_not_spend_the_reactions_round() -> void:
	# THE usage_group IS LOAD-BEARING, and this is the only test that says so. GearCore's per-round
	# counter is keyed by Action.usage_group, and an action that declares none falls back to the KIT's
	# compcon_id (gear_core.gd:166-168). The Falcata's attack profile declares none - it has no
	# per-round limit of its own to key - so without an explicit usage_group on the reaction the two
	# actions would SHARE the counter, and one swing of the weapon would put
	# UnitAction.is_under_per_round_limit (unit_action.gd:170-171) over the reaction's cap of 1. The
	# card's reaction would then be silently unavailable for the rest of any round the Primrose swung
	# in, which is most of them.
	await PrimroseFixture.attack(game, primrose, FALCATA, brawler)
	assert_gt(falcata().get_uses_this_round(falcata().get_action(ATTACK)), 0,
		'fixture: the swing really registered a use under the attack profile.')

	responder.yesno_queue.append(true)
	await swing(MISS_D20)
	assert_eq(offers(), 1, 'The reaction is still offered in the same round the weapon was swung.')
	assert_eq(accuracy_total(), -1, 'And still works.')

func test_the_reaction_is_a_real_one_and_the_engine_supplies_its_one_per_round() -> void:
	# action_reaction.gd:69 - get_per_round_hard_limit returns 1 when the reaction consumes the action
	# economy and 99 when it does not. The card says 1/round, consumes_rxn is left at its default true,
	# and so the engine's own answer is already the card's. An override here would be an inert line
	# that reads as load-bearing (SP2's Rend Axe lesson, one archetype over).
	var specific := retort_specific()
	assert_true(SpecificAction.is_valid(specific), 'the Falcata carries action_biting_retort.')
	if not SpecificAction.is_valid(specific): return
	assert_true(specific.action is ActionReactionAttacked, 'It is an ActionReactionAttacked.')
	assert_true(specific.action.consumes_reaction(), 'It is a "real" reaction and eats the point.')
	assert_eq(specific.action.get_per_round_hard_limit(specific), 1, 'So the engine caps it at 1/round.')
	assert_eq(specific.action.trigger_timing, ReactionBus.TIMING.PRE,
		'And it fires at PRE, which is the only timing at which the roll does not exist yet.')


# ============================== WHAT IT REFUSES ==============================

func test_a_ranged_attack_offers_nothing() -> void:
	await shoot()
	assert_eq(offers(), 0, 'weapon_types = [MELEE] refuses a rifle.')
	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the shot itself resolved.')
	assert_eq(accuracy_total(), 0, 'And rolled clean.')

func test_a_thrown_melee_attack_offers_nothing() -> void:
	# RULING 8: "melee attack" means a melee weapon used AT THREAT, never its thrown variant. A throw is
	# the same action with threat set to 0 (action_attack_weapon.gd:349-372), so weapon_types = [MELEE]
	# on the .tres cannot tell the two apart - which is exactly what triggers_on_event's extra clause is
	# for. Fired through use_specific with the fixture's thrown variant, which is what
	# VariantActionGroup.get_variant_specifics builds when a player picks Thrown off the sub-menu
	# (test_magnetic_weight_redistribution.gd's thrown case is the idiom).
	#
	# FIRED FROM THE SAME ADJACENT TILE A REAL SWING WOULD COME FROM, deliberately: nothing downstream
	# of event_gear_activate re-validates range (test_acrasial_falcata.gd records the measurement), so
	# distance would prove nothing here - and holding the position fixed makes threat 0 the ONLY
	# difference between this test and test_a_hostile_melee_attack_offers_the_reaction.
	var thrown := PrimroseFixture.thrown_variant(
		PrimroseFixture.specific(brawler, PrimroseFixture.HEAVY_MELEE))
	assert_eq(thrown.action.threat, 0, 'fixture: the thrown variant really has threat 0.')

	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	await SpecFactory.use_specific(game, thrown, primrose)

	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the throw really rolled.')
	assert_eq(offers(), 0, 'A throw is not a melee attack (ruling 8).')
	assert_eq(accuracy_total(), 0, 'So the roll is untouched.')

func test_a_thrown_attack_from_a_threat_buffed_attacker_still_offers_nothing() -> void:
	# THE CASE THAT SEPARATES THE TWO READINGS OF RULING 8, and the reason the gate reads the raw
	# `action.threat` rather than threat_distance(). Artful Caress is a THREAT_RANGE +1 on Heavy and
	# Superheavy MELEE weapons; a thrown variant is still Heavy and still Melee, so the buff still
	# applies to it and threat_distance() answers 1 for a weapon whose printed threat is 0. A gate
	# written on threat_distance() would read this throw as a swing and offer the reaction.
	#
	# NOT A CONTRIVANCE: any NPC carrying a threat-widening effect - an enemy Primrose is the obvious
	# one, and this frame ships two more threat sources in SP3 - reaches this state by playing normally.
	SpecFactory.apply_buff(brawler, CARESS_BUFF)
	var base := PrimroseFixture.specific(brawler, PrimroseFixture.HEAVY_MELEE)
	assert_eq(base.action.threat_distance(base), 2,
		'fixture: the buff really landed - a Heavy melee weapon at printed threat 1 now reaches 2.')

	var thrown := PrimroseFixture.thrown_variant(base)
	assert_eq(thrown.action.threat, 0, 'The throw prints threat 0 -')
	assert_eq(thrown.action.threat_distance(thrown), 1,
		'- but threat_distance() answers 1, because the buff does not care that it is a throw. THIS is '
		+ 'what the two candidate gates disagree about.')

	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	await SpecFactory.use_specific(game, thrown, primrose)

	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the throw really rolled.')
	assert_eq(offers(), 0, 'And it is still a throw, still not a melee attack (ruling 8).')

func test_an_ally_swinging_at_us_offers_nothing() -> void:
	var ally := PrimroseFixture.create_ally(game, ALLY_TILE)
	PrimroseFixture.equip_heavy_melee(ally)
	await PrimroseFixture.open_turn(game, ally)
	pin_dice(HIT_D20)
	await SpecFactory.use_solo(game, ally, PrimroseFixture.HEAVY_MELEE, primrose)

	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the ally really swung and really rolled.')
	assert_eq(offers(), 0,
		'require_attacker_relation = ENEMIES: the card says "a HOSTILE character".')

func test_an_attack_on_somebody_else_offers_nothing() -> void:
	var ally := PrimroseFixture.create_ally(game, ALLY_TILE)
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.HEAVY_MELEE, ally)

	assert_gt(ally.current_damage(), 0,
		'VACUITY GUARD: the brawler really swung at the ally, standing right beside us.')
	assert_eq(offers(), 0,
		'require_unit_to_be = DEFENDER: the card says "attempts to hit YOU".')

func test_a_blinded_primrose_does_not_riposte_an_attacker_it_cannot_see() -> void:
	# THE ONE CONSTRUCTIBLE NEGATIVE for require_attacker_to_be_in_los. UnitRelation.can_see carries the
	# Blinded rule (unit_relation.gd:206-216): a BLINDED unit sees only what it could ENGAGE, i.e. what
	# is adjacent. A wall cannot sit between two adjacent tiles, so the ONLY way to have a melee
	# attacker out of a defender's sight is a blinded defender and an attacker with reach - which needs
	# a threat-3 weapon, i.e. a Falcata in enemy hands.
	PrimroseFixture.equip(brawler, FALCATA)
	UnitTile.move_to(brawler, AT_THREE)
	# THE REACH IS ASSERTED, NOT FIRED. use_solo hands event_gear_activate a pre-chosen target and
	# nothing downstream re-validates distance (test_acrasial_falcata.gd records the measurement), so
	# a swing landing at AT_THREE would prove nothing about range. UnitTargeting.get_tiles_in_range is
	# the engine's own legal-target computation, the same one the player's picker consults.
	var reach:Array[Vector2i] = UnitTargeting.get_tiles_in_range(PrimroseFixture.specific(brawler, FALCATA))
	assert_has(reach, PRIMROSE_TILE, 'fixture: a threat-3 Falcata really reaches us from three tiles.')

	SpecFactory.apply(primrose, Lancer.STATUS.BLINDED)
	assert_true(primrose.has_status(Lancer.STATUS.BLINDED), 'fixture: the Primrose is Blinded.')
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(MISS_D20)
	await SpecFactory.use_solo(game, brawler, FALCATA, primrose)
	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the swing really rolled.')
	assert_eq(offers(), 0, 'A Blinded Primrose cannot see a foe three tiles away, so it is not offered.')

	# THE CONTROL, in the same test so the two cannot drift: clear the Blinded and the identical attack
	# from the identical tile IS offered. Without it, "no offer" could just as well mean the attack was
	# illegal.
	#
	# BOTH SWINGS MISS, and that is the fix for this test's own first red: see the FIFO note in the
	# file header. Two LANDED Falcata blows structure and then destroy an 8-health Primrose, and a
	# destroyed defender is offered nothing - which reads exactly like the control failing.
	UnitCondition.clear_status(SpecFactory.dummy_event(), primrose, Lancer.STATUS.BLINDED)
	assert_false(primrose.has_status(Lancer.STATUS.BLINDED), 'fixture: and now it is not.')
	responder.yesno_queue.append(false)
	var reads_before:int = recorder.reads
	pin_dice(MISS_D20)
	await SpecFactory.use_solo(game, brawler, FALCATA, primrose, [Action.FLAG.AS_FREEBIE])
	assert_gt(recorder.reads, reads_before, 'VACUITY GUARD: the second swing really rolled too.')
	assert_eq(offers(), 1, 'Sighted, the very same attack offers the reaction.')


# ============================== WHAT IT ACCEPTS THAT IS EASY TO LOSE ==============================

func test_a_basic_improvised_melee_attack_is_still_a_melee_attack() -> void:
	# allow_basic = true. ActionReactionAttacked refuses an attack made with BASIC gear unless the
	# reaction opts in (action_reaction_attacked.gd:113, :124), and a mech swinging its own fists is
	# still "a melee attack" on the card's reading. The improvised attack is weapon_type MELEE and
	# leans on the export default threat of 1 (content/gear/basic/improvised_attack/
	# action_improvised_attack.tres), so it is the only basic melee attack in the tree that reaches
	# this gate at all.
	var gear := basic_melee_gear()
	assert_true(GearCore.is_valid(gear), 'fixture: the brawler carries a basic improvised attack.')
	if not GearCore.is_valid(gear): return
	assert_true(brawler.core.loadout.is_gear_basic(gear),
		'fixture: and the engine really counts it as BASIC - which is what allow_basic is about.')

	responder.yesno_queue.append(false)
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(HIT_D20)
	await SpecFactory.use_solo(game, brawler, gear.kit.compcon_id, primrose)
	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the punch really rolled.')
	assert_eq(offers(), 1, 'A basic melee attack is offered too.')

func test_both_threat_readings_are_available_at_pre_and_they_disagree_about_a_throw() -> void:
	# THE MEASUREMENT BEHIND JUDGMENT CALL 1, taken from the reaction's OWN vantage point rather than
	# reconstructed: PreWitness records what the triggering context looked like inside
	# ReactionBus.does_buff_trigger at ATTACK PRE, which is the same poll, on the same event, in the
	# same loop, that calls action_biting_retort.triggers_on_event (reaction_bus.gd:50-67).
	#
	# What it settles: threat_distance() IS callable there - the context carries the whole trifecta,
	# because event_unit_attack.gd's get_required_context (:10-21) demands unit, gear and action - so
	# gating on the raw `action.threat` is a CHOICE, not a workaround. And the two readings really do
	# disagree, on exactly the case ruling 8 is about.
	var witness := watch_pre()
	SpecFactory.apply_buff(brawler, CARESS_BUFF)

	# 1: an ordinary swing, with the threat buff on the attacker.
	await PrimroseFixture.open_turn(game, brawler)
	pin_dice(MISS_D20)
	await SpecFactory.use_solo(game, brawler, PrimroseFixture.HEAVY_MELEE, primrose, [Action.FLAG.AS_FREEBIE])

	# 2: the THROWN variant of that same weapon, from the same tile.
	var thrown := PrimroseFixture.thrown_variant(
		PrimroseFixture.specific(brawler, PrimroseFixture.HEAVY_MELEE))
	pin_dice(MISS_D20)
	await SpecFactory.use_specific(game, thrown, primrose)

	assert_eq(witness.polls, 2, 'fixture: the witness was polled once per attack, at PRE.')
	assert_eq(witness.specific_was_valid, [true, true],
		'SpecificAction.from_context(triggering context) is VALID at ATTACK PRE, both times - so '
		+ 'threat_distance() was available to the gate and was not chosen by default.')
	assert_eq(witness.raw_threat, [1, 0],
		'The raw `threat` field separates the swing from the throw, which is how the engine itself '
		+ 'does it (get_target_range action_attack_weapon.gd:197-201, ignores_cover :206-212).')
	assert_eq(witness.buffed_threat, [2, 1],
		'threat_distance() does NOT: Artful Caress widens the throw too, so it reads 1 where the '
		+ 'printed threat is 0. A gate written on it would call this throw a melee attack.')


# ============================== THE CARD ==============================

func test_the_rows_resolve() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in [NAME_KEY, TRIGGER_KEY, EFFECT_KEY]:
		assert_ne(translation.get_message(key), StringName(''),
			'%s is carried by THIS mod, not by a sibling.' % key)

func test_the_reaction_is_drawn_on_the_weapons_card() -> void:
	# MEASURED, NOT ASSUMED - judgment call 3 in this file's header. Action.show_in_tooltip
	# (action.gd:341-353) walks: not situationally activated; the KIT's own `trigger` row (we have
	# none - the trigger row belongs to the action); the action having a file of its own; no
	# localization_key_override; and finally an `effect` row of its own that differs from the Kit's.
	# That last clause is the one that decides it here, and it is why the Maiden's Blush's
	# mt_uncertainty_field answers FALSE while this answers TRUE.
	var gear := falcata()
	assert_true(GearCore.is_valid(gear), 'fixture: the Primrose carries the Falcata.')
	if not GearCore.is_valid(gear): return
	var action:Action = gear.get_action(RETORT)
	assert_not_null(action, 'fixture: and the Kit carries the reaction.')
	if action == null: return
	assert_true(action.show_in_tooltip(gear.kit),
		'The reaction is drawn on the weapon card - it has an effect row of its own, different from '
		+ 'the Kit\'s. test_content_integrity.gd\'s ICON_TARGETS row for it says the same thing '
		+ 'through the same call.')
	assert_ne(X.tr(EFFECT_KEY), X.tr('gear.mw_acrasial_falcata.effect'),
		'And the two rows really are different text, which is the clause that decides it.')

func test_the_reaction_keeps_the_falcatas_swing_as_the_solo_action() -> void:
	# Appending a second action to a weapon Kit is not free: GearCore.get_solo_action returns
	# kit.actions[0] (gear_core.gd:337-339), which is what SpecFactory.use_solo fires and what
	# Translate.buff falls through to. The reaction goes SECOND in the array, so every existing
	# test_acrasial_falcata.gd case keeps firing the swing.
	var gear := falcata()
	if not GearCore.is_valid(gear): return assert_true(false, 'no Falcata to inspect.')
	var solo:Action = gear.get_solo_action()
	assert_not_null(solo, 'the Kit has a solo action.')
	if solo == null: return
	assert_eq(solo.get_id(), ATTACK, 'and it is still the attack profile, not the reaction.')
