# GEMINI CHARGE IS ONE ATTACK FOR THE KNOT'S ONE-TIME ROLL BUFFS (Pass F task 11c, author report
# 2026-09-28). The card: "Attacks made this way are made against all characters simultaneously with one
# attack roll. This counts as one attack". So every target of one Gemini attack reads the SAME one-time
# attack-roll buffs the Knot held when the attack began, and they are consumed ONCE, after the whole
# attack - with their on_consumption side effects (Core Siphon's -1) landing once, then.
#
# THE BUG. The engine rolls each target of a declared attack as its own event_unit_attack, in order
# (event_unit_attack_declared.gd:54-67, event_block.gd:101-107), and each one consumes the one-time
# buffs its own roll read before the next target is built (event_unit_attack.gd:114). Core Siphon's +1
# (buff_core_siphon_accuracy, is_onetime, to = attack_roll) is therefore eaten by the FIRST roll, and its
# on_consumption hangs the -1 on the Knot at once - so the redirected target read the -1.
#
# The ruling-9 reading stands untouched: one d20 face, each target's own accuracy and difficulty. Only
# the attacker's one-time roll buffs change: they are now part of every target's own accuracy.
#
# A PLAIN MULTI-TARGET ATTACK IS LEFT AS VANILLA HAS IT (the declined-Line test pins it): the fix is
# scoped to a declared attack Gemini recorded.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/pf.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gemini_charge_onetime_buffs.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')

const MAP_SIZE := Vector2i(20, 16)
const KNOT_TILE := Vector2i(1, 4)
const CONTACT_TILE := Vector2i(4, 4) # 3 from the Knot
const SECOND_TILE := Vector2i(4, 7) # 3 south of the contact
const THIRD_TILE := Vector2i(7, 7) # 3 east of the second: the Myriad's second leg
const PAST_TILE := Vector2i(6, 4) # on the rail's line, past the contact
const LINE_AIM := Vector2i(11, 4)

## Vanilla SSC Core Siphon: +1 accuracy on the next attack roll, then -1 until the end of the turn.
const SIPHON := &'ms_core_siphon'
const SIPHON_PLUS := &'buff_core_siphon_accuracy'
const SIPHON_MINUS := &'buff_core_siphon_inaccuracy'
## Vanilla SSC Kinetic Compensator's +1: one-time, no on_consumption - the plain case.
const COMPENSATOR := &'buff_kinetic_compensator'

const SIXES:Array[int] = [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]


## Records every ATTACK_DECLARED POST the Knot makes.
class DeclaredRecorder extends Buff:
	var seen:Array[DeclaredAttackSummary] = []
	func _init() -> void:
		compcon_id = &'buff_spec_gemini_onetime_recorder'
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		hide_from_player = true
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]
	func triggers_on_event(_core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
		return triggering.context.unit.get_attacker(triggering.context) == unit
	func activate(_core:BuffCore, activation:EventCore) -> void:
		seen.append(activation.context.event.context.resource)


var game:Gamemaster
var responder
var knot:Unit
var contact:Unit
var recorder:DeclaredRecorder

func before_each() -> void:
	await get_tree().process_frame # a synchronous test's responder must be off the bus first
	var made:Array = Fixture.create_game_with_prompts(self, MAP_SIZE)
	game = made[0]
	responder = made[1]
	knot = Fixture.create_knot(game, KNOT_TILE)
	Fixture.equip(knot, Fixture.RANGED)
	Fixture.equip(knot, Fixture.LINE)
	Fixture.equip(knot, SIPHON) # equip everything BEFORE anything is spent: equip full_repairs
	contact = Fixture.create_dummy(game, CONTACT_TILE)
	recorder = DeclaredRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, recorder)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func dummy(tile:Vector2i) -> Unit: return Fixture.create_dummy(game, tile)
func plan_unit(unit:Unit) -> CompconPlan: return CompconPlan.create([unit.tile()], [], [unit])

func count(id:StringName) -> int:
	var found := 0
	for core:BuffCore in knot.state.buffs:
		if core.base.compcon_id == id: found += 1
	return found

## Press vanilla Core Siphon, as a player would: the +1 on the Knot, from the Core Siphon gear.
func siphon() -> void:
	await Fixture.open_turn(game, knot)
	await SpecFactory.use_solo(game, knot, SIPHON)

func fire(kit_id:StringName, target, d20s:Array[int], picks:Array[CompconPlan] = []) -> void:
	await Fixture.open_turn(game, knot)
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(d20s, SIXES)
	responder.chosen_plan_queue.assign(picks)
	await SpecFactory.use_solo(game, knot, kit_id, [target])

func roll_against(target:Unit) -> AttackRoll:
	if recorder.seen.is_empty(): return null
	for roll:AttackRoll in recorder.seen.back().attack_rolls:
		if roll.target_unit == target: return roll
	return null

func accuracy_against(target:Unit) -> int:
	var roll := roll_against(target)
	return roll.pre.accuracy_mods_total() if roll else -99


# ============ CONTROL: ONE TARGET ============

func test_a_single_target_shot_spends_the_siphon_on_its_one_roll() -> void:
	await siphon()
	assert_eq(count(SIPHON_PLUS), 1, 'Fixture: the Knot holds Core Siphon\'s +1.')
	var asked:int = responder.yesno_prompts.size() # Core Siphon's own confirm is one
	await fire(Fixture.RANGED, contact, [14])
	assert_eq(responder.yesno_prompts.size(), asked, 'Guard: nobody to redirect to, no offer.')
	assert_eq(accuracy_against(contact), 1, 'The one roll reads the +1.')
	assert_eq(count(SIPHON_PLUS), 0, 'The +1 is consumed.')
	assert_eq(count(SIPHON_MINUS), 1, 'And the -1 lands, once.')


# ============ THE FIX ============

func test_a_redirected_target_reads_the_siphon_the_contact_read() -> void:
	var second := dummy(SECOND_TILE)
	await siphon()
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(Fixture.gemini_uses(knot), 1, 'Guard: the shot was redirected.')
	assert_eq(accuracy_against(contact), 1, 'The contact reads the +1.')
	assert_eq(accuracy_against(second), 1, 'The redirected target reads the SAME +1: one attack, one roll.')
	assert_eq(count(SIPHON_PLUS), 0, 'The +1 is consumed after the attack.')
	assert_eq(count(SIPHON_MINUS), 1, 'The -1 lands exactly once.')

func test_every_leg_of_a_myriad_attack_reads_the_siphon() -> void:
	var second := dummy(SECOND_TILE)
	var third := dummy(THIRD_TILE)
	await siphon()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, ContentLibrary.get_buff(Fixture.MYRIAD_CHIP))
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second), plan_unit(third), CompconPlan.create_aborted()])
	assert_not_null(roll_against(third), 'Guard: two legs, three targets.')
	for unit:Unit in [contact, second, third]:
		assert_eq(accuracy_against(unit), 1, '%s reads the +1.' % unit.tile())
	assert_eq(count(SIPHON_PLUS), 0, 'Consumed once, after.')
	assert_eq(count(SIPHON_MINUS), 1, 'The -1 lands exactly once.')

func test_a_one_time_bonus_with_no_side_effect_reaches_every_target_and_is_spent_once() -> void:
	var second := dummy(SECOND_TILE)
	await Fixture.open_turn(game, knot)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, ContentLibrary.get_buff(COMPENSATOR))
	assert_eq(count(COMPENSATOR), 1, 'Fixture: the Knot holds Kinetic Compensator\'s +1.')
	await fire(Fixture.RANGED, contact, [14], [plan_unit(second)])
	assert_eq(accuracy_against(contact), 1, 'The contact reads the +1.')
	assert_eq(accuracy_against(second), 1, 'So does the redirected target.')
	assert_eq(count(COMPENSATOR), 0, 'And it is spent by the attack.')

func test_a_line_that_bends_gives_every_character_on_the_leg_the_siphon() -> void:
	var second := dummy(SECOND_TILE)
	var further := dummy(Vector2i(4, 9))
	await siphon()
	await fire(Fixture.LINE, LINE_AIM, [14], [CompconPlan.create([Vector2i(4, 11)])])
	assert_eq(Fixture.gemini_uses(knot), 1, 'Guard: the line bent.')
	for unit:Unit in [contact, second, further]:
		assert_eq(accuracy_against(unit), 1, '%s reads the +1.' % unit.tile())
	assert_eq(count(SIPHON_MINUS), 1, 'The -1 lands exactly once.')


# ============ SCOPE: A PLAIN MULTI-TARGET ATTACK STAYS VANILLA ============

func test_a_declined_line_keeps_vanillas_per_roll_consumption() -> void:
	# The probe's finding, pinned: vanilla consumes a one-time roll buff on the FIRST roll of any
	# multi-target attack. Only an attack Gemini recorded is changed.
	var past := dummy(PAST_TILE)
	dummy(SECOND_TILE) # someone to redirect to, so the offer is made and declined
	await siphon()
	var asked:int = responder.yesno_prompts.size() # Core Siphon's own confirm is one
	responder.yesno_queue.assign([false])
	await fire(Fixture.LINE, LINE_AIM, [14])
	assert_eq(responder.yesno_prompts.size(), asked + 1, 'Guard: Gemini was offered, and declined.')
	assert_eq(Fixture.gemini_uses(knot), 0, 'Guard: nothing was redirected.')
	assert_eq(accuracy_against(contact), 1, 'The first roll reads the +1.')
	assert_eq(accuracy_against(past), -1, 'Vanilla: the second roll already reads the -1.')
	assert_eq(count(SIPHON_MINUS), 1, 'The -1, once.')
