# GLIMMERING ARMAMENTS - the active half of MÖBIAN RAINBOW (Primrose SP1 Task 5).
#
#   "For the rest of the scene you gain one of the following effects: Wormhole Grasp /
#    Shimmering Shield."
#
# ONE PROTOCOL WITH A TWO-CHOICE PROMPT (ruling 1), not two actions. Closer to the card's single
# heading, and the testkit responder already answers this prompt type - choose_from_gear, the native
# picker, has no answerer at all.
#
# THIS IS THE MOD'S FIRST choose_from_multiple_choice. It is answered through
# testkit/mod_choice_responder.gd's multiple_choice_queue, which PrimroseFixture.create_game_with_prompts
# installs in place of the stock responder; the stock one answers every multiple-choice prompt with
# one shared index and throws the prompt away, so "the menu listed these two things" could not be
# asserted at all.
#
# A PROTOCOL NEEDS AN OPEN TURN. unit_action.gd:144 refuses one unless unit.state.is_using_protocols,
# which only event_turn_start opens; PrimroseFixture.press_protocol opens it. Without that the press
# fails with "[ Gear not available ] reason : protocol" in red, and the assertion failure just looks
# like broken content.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_glimmering_armaments.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const CORE_ID := &'cp_mobian_rainbow'
const PROTOCOL_ID := &'action_glimmering_armaments'

const WORMHOLE := &'buff_wormhole_grasp'
const WORMHOLE_THREAT := &'buff_wormhole_grasp_threat'
const WORMHOLE_HALF := &'buff_wormhole_grasp_half'
const WORMHOLE_SLOW := &'buff_wormhole_grasp_slow'
const SHIELD := &'buff_shimmering_shield'
## SP1 TASK 6 appended this to SHIELD_BUNDLE. Task 5's report asked for these two assertions by name:
## the bundle tests are what say the protocol applies the WHOLE armament and nothing of the other one,
## so a bundle that grows and a test that does not is a mechanic shipped untested. Its own behaviour
## lives in test_shimmering_shield.gd.
const SHIELD_COVER := &'buff_shimmering_shield_cover'

const PRIMROSE_TILE := Vector2i(4, 4)

var game:Gamemaster
var responder
var primrose:Unit

func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func holds(buff_id:StringName) -> bool:
	return UnitCondition.has_buff(primrose, buff_id)

# ---------------------------------------------------------------- wiring and text

func test_the_protocol_is_wired():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % CORE_ID)
	if not Kit.is_valid(kit): return
	assert_eq(kit.actions.size(), 1, 'The core Kit carries exactly one action.')
	var action = kit.get_action(PROTOCOL_ID)
	assert_not_null(action, 'And it is %s.' % PROTOCOL_ID)
	if action == null: return
	assert_true(action is ActionSystem, 'An ActionSystem.')
	var specific := SpecificAction.from_id(primrose, CORE_ID, PROTOCOL_ID)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.PROTOCOL,
		'A PROTOCOL (Lancer.ACTION.PROTOCOL == 4, lancer.gd:27).')
	# consumes_core_power() is declared `-> int` on Action and ActionSystem (action.gd:167,
	# action_system.gd:32 - it returns the `consumes_cp` bool THROUGH an int return), so GUT's
	# assert_true refuses the value outright: "Cannot convert 1 to boolean". Compare the number rather
	# than coercing it; 0 is what an action that spends no core power returns.
	assert_eq(action.consumes_core_power(), 1, 'Spending the frame\'s one core power.')
	assert_eq(action.usage_group, &'glimmering_armaments',
		'With its own usage group: a protocol and any later pressable on one Kit need a group EACH '
		+ '(unit_action.gd:167-168).')
	assert_true(primrose.core.has_core_power, 'fixture: the Primrose starts with its core power.')

func test_the_rows_resolve_and_both_markers_have_their_own_cards():
	for key:String in ['gear.cp_mobian_rainbow.action_glimmering_armaments.name',
			'gear.cp_mobian_rainbow.action_glimmering_armaments.effect',
			'gear.buff_wormhole_grasp.name', 'gear.buff_wormhole_grasp.effect',
			'gear.buff_shimmering_shield.name', 'gear.buff_shimmering_shield.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE MARKERS MUST HAVE ROWS OF THEIR OWN (memory lancer-tactics-buff-card-fallback). Translate.buff
	# falls through to the owner Kit's FIRST ACTION (translate.gd:73-76), and from this task on that
	# action is the PROTOCOL - so a marker with no rows would render the protocol's whole card, in the
	# second person, on the Primrose's status bar. The fallback SUCCEEDS, so no tr()-resolution guard
	# would ever fire; only this comparison does. The Vauban shipped exactly that bug through three
	# sub-projects.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	var core:BuffCore = UnitCondition.get_buff(primrose, WORMHOLE)
	assert_not_null(core, 'fixture: the marker is on the unit.')
	if core == null: return
	assert_eq(core.name_text(), X.tr('gear.buff_wormhole_grasp.name'),
		'The marker is titled off its OWN name row.')
	assert_ne(core.effect_text(), X.tr('gear.cp_mobian_rainbow.action_glimmering_armaments.effect'),
		'And its card is NOT the protocol\'s - which is what the fallback would give it.')

# ---------------------------------------------------------------- the prompt

func test_the_prompt_offers_exactly_the_two_effects():
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)

	assert_eq(responder.multiple_choice_prompts.size(), 1, 'Exactly one prompt was raised.')
	if responder.multiple_choice_prompts.is_empty(): return
	var prompt:Dictionary = responder.multiple_choice_prompts[0]
	assert_eq(Array(prompt.labels), [X.tr('gear.buff_wormhole_grasp.name'), X.tr('gear.buff_shimmering_shield.name')],
		'Two entries, in the card\'s order: Wormhole Grasp then Shimmering Shield.')
	assert_eq(prompt.answered, PrimroseFixture.WORMHOLE_INDEX, 'And index 0 is Wormhole Grasp.')
	# The labels ARE the chip names, one string in one place - so a renamed armament renames both the
	# menu entry and the chip, and this assertion is what stops them drifting apart.
	assert_eq(Array(prompt.disabled_reasons), ['', ''], 'Neither entry is greyed out; both are always available.')

func test_cancelling_spends_nothing():
	# RULING 1: "cancelling the prompt spends nothing." choice_bus.choose_from_multiple_choice returns
	# -1 on a cancel (choice_bus.gd:138-141), and the script returns BEFORE spend_actions - which is
	# what UnitAction.spend_actions_gain_heat calls spend_core_power from (unit_action.gd:272).
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.CANCEL_INDEX)

	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the prompt really was raised.')
	assert_true(primrose.core.has_core_power, 'The core power is untouched.')
	assert_false(holds(WORMHOLE), 'No Wormhole Grasp.')
	assert_false(holds(SHIELD), 'No Shimmering Shield.')
	assert_eq(primrose.get_gear(CORE_ID).get_uses_this_round_alt(&'glimmering_armaments'), 0,
		'And no usage was recorded, so the button is still live.')

# ---------------------------------------------------------------- the two armaments

func test_choosing_wormhole_grasp_spends_the_core_power_and_applies_the_whole_bundle():
	# A BUFF CANNOT CARRY OTHER BUFFS, so the protocol applies all four together. The marker is what
	# the unit_relation extension reads; the other three are what the card actually does.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)

	assert_false(primrose.core.has_core_power, 'The core power is spent.')
	assert_true(holds(WORMHOLE), 'The visible marker is held.')
	assert_true(holds(WORMHOLE_THREAT), 'And the +1 threat.')
	assert_true(holds(WORMHOLE_HALF), 'And the half-damage observer.')
	assert_true(holds(WORMHOLE_SLOW), 'And the on-hit Slow.')
	assert_false(holds(SHIELD), 'And NOT the other armament.')
	assert_false(holds(SHIELD_COVER), 'Nor its hidden cover chip (SP1 Task 6).')

func test_choosing_shimmering_shield_spends_the_core_power_and_applies_its_marker():
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.SHIELD_INDEX)

	assert_false(primrose.core.has_core_power, 'The core power is spent.')
	assert_true(holds(SHIELD), 'The Shimmering Shield marker is held.')
	assert_true(holds(SHIELD_COVER), 'And its hidden cover chip, the other half of the bundle (SP1 Task 6).')
	assert_false(holds(WORMHOLE), 'And NOT the other armament.')
	assert_false(holds(WORMHOLE_THREAT), 'Nor any of its companions.')
	assert_false(holds(WORMHOLE_HALF), 'Nor the half-damage observer.')
	assert_false(holds(WORMHOLE_SLOW), 'Nor the on-hit Slow.')

func test_the_chosen_marker_persists_across_a_turn_boundary():
	# "FOR THE REST OF THE SCENE" is until = MANUAL: nothing in the engine clears it on a turn boundary.
	# The Sherman's buff_coreburn_protocol is the vanilla precedent for exactly this shape.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_true(holds(WORMHOLE), 'fixture: the marker landed.')

	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, primrose)
	await SpecFactory.end_turn(game, primrose)

	assert_true(holds(WORMHOLE), 'A full turn later, the marker is still held.')
	assert_true(holds(WORMHOLE_THREAT), 'And so are its companions.')
	assert_true(holds(WORMHOLE_HALF), 'All of them.')
	assert_true(holds(WORMHOLE_SLOW), 'Every one.')

func test_the_shield_marker_persists_across_a_turn_boundary():
	# DESIGN 1.5 SAYS "CHOOSING SHIMMERING SHIELD LIKEWISE", and the test above presses Wormhole only -
	# so this is that case, run rather than reasoned (SP1 final review, I3). The two bundles are
	# separate .tres files with separately declared `until` values, so the sibling test proves nothing
	# about this one: a Shield marker authored with until = END_OF_TURN would leave every assertion in
	# this file green except these.
	#
	# test_shimmering_shield.test_the_shield_bundle_is_wired asserts marker.until == MANUAL statically;
	# this is the half that presses the protocol and cycles the clock the engine actually runs.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.SHIELD_INDEX)
	assert_true(holds(SHIELD), 'fixture: the marker landed.')

	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, primrose)
	await SpecFactory.end_turn(game, primrose)

	assert_true(holds(SHIELD), 'A full turn later, the marker is still held.')
	assert_true(holds(SHIELD_COVER), 'And so is its hidden cover chip - the half that does the work.')

func test_a_second_press_is_refused_once_the_core_power_is_spent():
	# "ONE OF THE FOLLOWING EFFECTS", and this is what enforces it: consumes_cp = true, and
	# UnitAction.get_gear_unavailable_reason refuses an action whose consumes_core_power() is true on a
	# unit with has_core_power false (unit_action.gd:145, REASON.NO_CORE_POWER). There is deliberately
	# NO hibernate_action call - the design names none, and the core-power gate already answers. See
	# the plan's "Handed forward" for the one-line UX alternative.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_true(holds(WORMHOLE), 'fixture: the first press landed.')

	var specific := SpecificAction.from_id(primrose, CORE_ID, PROTOCOL_ID)
	assert_eq(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.NO_CORE_POWER,
		'A second press is refused for want of a core power.')
	assert_false(UnitAction.is_gear_available(specific), 'So the button is not available at all.')
	assert_false(holds(SHIELD), 'And the other armament was never gained.')

# ================================================================ the use-FX, and its CALL SITE
#
# FIXED AT THE SP5 CLOSE (spec/test_spin.gd's tests 16-17 are the precedent this pair copies).
# fxg_use = fxg_super_activation.tscn on the .tres was wired since SP1 and was INERT for three
# sub-projects: nothing in the engine calls ActionSystem.run_system_fxgs automatically
# (action_system.gd:70-105 is the only reader; every one of its ~60 callers invokes it from their
# own activate), so the protocol's FX had never played. action_spin.gd's own header names this file
# by path as the still-live case until now.

## WIRING ALONE, AND THIS TEST CANNOT SEE THE HALF THAT MATTERS MOST - see the next test.
func test_the_protocol_carries_its_own_use_fx():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	var action = kit.get_action(PROTOCOL_ID)
	assert_not_null(action, '%s is on the kit.' % PROTOCOL_ID)
	if action == null: return
	assert_not_null(action.fxg_use, 'Glimmering Armaments carries a use-FX.')
	if action.fxg_use == null: return
	assert_true(action.fxg_use.resource_path.ends_with('fxg_super_activation.tscn'),
		'The shared core-power flourish, not a bespoke one: %s' % action.fxg_use.resource_path)

## RULING 20 IS NOT BREACHED - it forbids a spec on the ANIMATION, not on whether the call exists.
## A SOURCE-LEVEL ASSERTION IS THIS MOD'S OWN PRECEDENT for a claim behaviour cannot reach: see
## test_spin.gd's own test_activate_actually_calls_run_system_fxgs and its header for the full
## reasoning (test_unit_relation_extension.gd and test_draw_fire.gd are the two earlier instances).
func test_activate_actually_calls_run_system_fxgs():
	# THE UNPACKED PATH, not the mirror path - raw FileAccess needs the on-disk location.
	const SOURCE := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_primrose/cp_mobian_rainbow/action_glimmering_armaments.gd'
	var src := FileAccess.get_file_as_string(SOURCE)
	assert_false(src.is_empty(), 'The action\'s source reads back.')
	if src.is_empty(): return

	# SCOPED TO activate'S BODY AND TO NON-COMMENT LINES - the call is named repeatedly in comments
	# above and inside the function, so a bare src.contains() would stay green with the statement
	# deleted or commented out.
	var body:String = src.substr(src.find('func activate('))
	assert_gt(body.length(), 0, 'func activate is in the file.')
	var called := false
	for line:String in body.split('\n'):
		var code := line.strip_edges()
		if code.begins_with('#'): continue
		if code.contains('await run_system_fxgs('): called = true
	assert_true(called,
		'activate() really calls run_system_fxgs - without it fxg_super_activation.tscn never plays, however wired.')
