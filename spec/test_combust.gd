# COMBUST - RAGE's face 4 (SP1 Task 10).
#
#   "4 Combust: Choose a blast 1 area within line of sight and SENSORS. All characters at least
#    partially within the area must succeed a Hull save or take 2d6 Kinetic damage and be knocked
#    Prone."
#
# A HIDDEN FREE ActionSystemApplyStatus SUBCLASS on the core Kit, offered by the roll through
# CommonActionUtil.choose_and_use (ruling 12). It is the ONLY face that asks the player anything.
#
# THE BLAST COMES FROM target_requirements_override, NOT from the archetype's own range_pattern
# export - that export is DEAD. activate reads get_range_pattern_for_targets (:59), which is
# Action's, returning get_target_requirements(specific).range_pattern (action.gd:204-206), and
# ActionSystemApplyStatus.get_target_requirements (:22-27) never copies its export in.
#
# AND apply_to_self IS FALSE, against ruling 12's letter. With it TRUE the action becomes self-only:
# can_target_unit short-circuits to `specific.unit == potential_target` (:35), get_target_requirements
# sets count = 0 (:26) and activate takes the confirm-and-done branch (:47-50) with no tile pick. With
# it false the Leoleth is STILL caught by its own blast, because the AoE sweep's whos_asking filter is
# UnitRelation.can_affect (map_state.gd:319-320) and that has no self clause.
#
# THE TARGET IS PICKED BY THE RESPONDER, EXPLICITLY. SpecFactory.current_responder.chosen_plan_queue
# is a FIFO of CompconPlans the stock responder regurgitates (spec_factory.gd:454-455), which is how
# maidens_blush_fixture.step already steers a tile pick. Letting it choose for itself would make the
# blast centre an emergent property of targeting order, and every dice queue below depends on knowing
# exactly who is in the area.
#
# THE DICE, MEASURED 2026-09-22 off this file's own run log: [the RAGE d6] then, PER TARGET IN SWEEP
# ORDER, [the save's d20] and - only on a failure - [d6, d6]. A face-4 turn with one failing character
# pops 4, 1, 6, 6 in that order and nothing else; the recharge loop pops nothing on this frame
# (event_turn_start.gd:89-91, GearCore.is_recharged defaults true) and the damage event itself rolls
# nothing, because apply_additional_effect rolls the 2d6 at QUEUE time.
#
# THE DICE, PER TARGET, IN ORDER: apply_to_targets loops the targets and for each one rolls the save's
# d20 (does_target_make_save -> UnitHasecheck.make_save) and then, ONLY on a failure,
# apply_additional_effect's 2d6 (action_system_apply_status.gd:93-101). So a single failing character
# costs [d20, d6, d6] and a passing one costs [d20]. Every test here puts exactly ONE character in the
# blast unless both are meant to fail identically.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_combust.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)
## Five east: well inside Sensors 10, and its Blast 1 does not reach the Leoleth.
const BLAST_CENTRE := Vector2i(11, 6)
const IN_THE_BLAST := Vector2i(11, 6)
const ALSO_IN_THE_BLAST := Vector2i(12, 6)
## Two tiles from the centre: outside a Blast 1.
const OUTSIDE_THE_BLAST := Vector2i(13, 6)

## Beats any save target this fixture hands out.
const SAVE_PASSES := 20
## Beats nothing.
const SAVE_FAILS := 1
const D6 := 6
const COMBUST_DAMAGE := 12 # 2d6 at sixes

## THE SELF-BLAST CASE ROLLS THREES, AND THAT IS MEASURED, NOT TIMID. The Leoleth is 8 HP with armor
## 1 (mf_leoleth.tres:49-50), so a maximised 2d6 lands 11 and takes it to -3: ALL SYSTEMS RED fires at
## STRUCTURED PRE and zeroes the negative, then event_unit_structure folds `health = mini(health +
## get_health_max(), get_health_max())` (event_unit_structure.gd:44) - so current_damage() reads back
## ZERO, the structure d6 comes off the queue's tail of 1s and Direct-Hits it, and the test would be
## measuring its own core power rather than the blast. Threes keep it upright with the number legible.
const SELF_D6 := 3
const SELF_BLAST_DAMAGE := 6 # 2d6 at threes

var game:Gamemaster
var leoleth:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Tell the stock responder exactly where the blast goes, before the roll happens.
func aim_at(tile:Vector2i) -> void:
	SpecFactory.current_responder.chosen_plan_queue.append(CompconPlan.create([tile], [], []))

func combust() -> Action:
	var gear:GearCore = leoleth.get_gear(LeolethFixture.CORE_ID)
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == LeolethFixture.COMBUST_ID: return action
	return null

# ------------------------------------------------- the hotbar (playtest 2026-09-22)

func specific_combust() -> SpecificAction:
	return SpecificAction.from_id(leoleth, LeolethFixture.CORE_ID, LeolethFixture.COMBUST_ID)

func test_combust_is_not_activatable_with_no_rage_at_all():
	# THE PLAYTEST BUG, 2026-09-22: the author had a permanent Combust button on the hotbar with RAGE
	# never pressed, and pressing it ran the whole card - blast 1, 2d6 Kinetic and Prone on a failed
	# Hull save - at will, once a round.
	#
	# Combust is the ONLY action on cp_hydraulic_excess that is neither an ActionReaction nor a
	# protocol, so it is the only one that reaches gear_bar.collect_gear_actions' admission test
	# (gear_bar.gd:143-150). It had hide_if_disabled unset and no is_available_to_activate override,
	# and that method defaults to TRUE (action.gd:175-176) - so the button was drawn and the action
	# was genuinely available. Nothing else on this frame leaked, which is why only this face did.
	var specific := specific_combust()
	assert_true(SpecificAction.is_valid(specific), 'fixture: the Combust specific resolves.')
	if not SpecificAction.is_valid(specific): return
	assert_false(UnitCondition.has_buff(leoleth, LeolethFixture.RAGE_CHIP),
		'fixture: RAGE was never pressed.')
	assert_false(UnitAction.can_activate_gear(specific),
		'Combust cannot be activated with no RAGE - it is not a player-initiated action.')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.SPECIFIC,
		'...and the refusal comes from is_available_to_activate, not from a cost or a charge.')

func test_combust_is_not_activatable_while_rage_is_up_on_another_face():
	# RAGE ALONE IS NOT THE GATE. The window is face 4 being RESOLVED, not the protocol being held -
	# so a Leoleth mid-scene on Swift must not be able to reach for Combust either.
	await LeolethFixture.rage(game, leoleth, 2)
	assert_true(UnitCondition.has_buff(leoleth, LeolethFixture.RAGE_CHIP), 'fixture: RAGE is up...')
	var specific := specific_combust()
	if not SpecificAction.is_valid(specific): return
	assert_false(UnitAction.can_activate_gear(specific),
		'...and Combust is still refused, because this turn rolled Swift.')

func test_the_button_is_hidden_and_not_merely_greyed():
	# BOTH HALVES ARE LOAD-BEARING, and this pins the pair. gear_bar.gd:146 drops an action only when
	# hide_if_disabled is set AND the gear is unavailable; with the availability override alone the
	# button would still be drawn on the bar, just greyed out, which is not what the card describes.
	var action := combust()
	assert_not_null(action, 'fixture: the action resolves.')
	if action == null: return
	assert_true(action.hide_if_disabled,
		'hide_if_disabled is set, so gear_bar drops the button rather than greying it.')
	assert_false(action.is_situationally_activated,
		'And NOT via is_situationally_activated, which would tell the engine it is usable by another unit.')

func test_the_window_is_shut_again_after_a_face_four_resolves():
	# THE OFFER OPENS THE WINDOW AND MUST SHUT IT. If it leaked, the button would come back for the
	# rest of the scene the first time the Leoleth ever rolled a 4 - a subtler version of the same bug.
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, 4, [SAVE_FAILS, D6, D6])
	var specific := specific_combust()
	if not SpecificAction.is_valid(specific): return
	assert_false(UnitAction.can_activate_gear(specific),
		'The window is shut again once the face has resolved.')

# ---------------------------------------------------------------- the wiring

func test_the_action_is_wired_as_ruling_12_says():
	var action := combust()
	assert_not_null(action, 'The core Kit carries %s.' % LeolethFixture.COMBUST_ID)
	if action == null: return
	assert_true(action is ActionSystemApplyStatus, 'It is an ActionSystemApplyStatus subclass.')
	if not (action is ActionSystemApplyStatus): return
	var specific := SpecificAction.create(leoleth, leoleth.get_gear(LeolethFixture.CORE_ID), action)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.FREE, 'A FREE action (lancer.gd:27).')
	assert_true(action.apply_to_sensors, 'Its range is SENSORS...')
	assert_eq(action.get_target_range(specific), leoleth.get_sensor_range(), '...read live off the unit.')
	assert_false(action.apply_to_self,
		'apply_to_self is FALSE, against ruling 12\'s letter: with it true the action becomes '
		+ 'self-only and never picks a tile (action_system_apply_status.gd:35, :26, :47-50). The '
		+ 'Leoleth is still caught by its own blast, through the AoE sweep.')
	assert_false(action.apply_only_to_enemies, 'No faction filter...')
	assert_false(action.apply_only_to_allies, '...in either direction: the card says all characters.')
	assert_true(action.save_to_avoid, 'A save avoids it...')
	assert_eq(action.save_type, Lancer.HASE.HULL, '...and it is a HULL save.')
	assert_eq(action.applied_statuses, [Lancer.STATUS.PRONE] as Array[StringName], 'It applies Prone.')
	assert_eq(action.apply_until, Lancer.UNTIL.MANUAL,
		'MANUAL: Prone has no natural lifetime, and Stabilize is what clears it.')
	assert_false(action.show_in_tooltip(ContentLibrary.get_kit(LeolethFixture.CORE_ID)),
		'Hidden: it is reachable only through the RAGE roll, never off the gear bar.')
	# THE BLAST, and where it really comes from.
	var reqs:TargetRequirements = action.get_target_requirements(specific)
	assert_not_null(reqs, 'It has target requirements.')
	if reqs == null: return
	assert_eq(reqs.count, 1, 'One tile is picked.')
	assert_true(reqs.can_target_empty_tiles, 'And it can be an empty one - the card says an AREA.')
	assert_not_null(reqs.range_pattern,
		'The pattern lives on the REQUIREMENTS, not on the archetype\'s own range_pattern export - '
		+ 'that export is dead (action.gd:204-206 reads this one).')
	if reqs.range_pattern == null: return
	assert_eq(reqs.range_pattern.pattern, Lancer.AOE_TYPE.BLAST, 'A BLAST...')
	assert_eq(reqs.range_pattern.value, 1, '...of 1.')

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('gear.cp_hydraulic_excess.action_combust.name'), StringName(''),
		'Our own artifact carries the action\'s name row - it is logged and popcorned when it fires.')
	assert_eq(X.tr('gear.cp_hydraulic_excess.action_combust.name'), 'Combust', 'Named off the table.')

# ---------------------------------------------------------------- the blast

func test_a_character_that_fails_the_save_takes_2d6_and_is_knocked_prone():
	var victim:Unit = LeolethFixture.create_hostile(game, IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST,
		[SAVE_FAILS, D6, D6] as Array[int])
	assert_eq(victim.current_damage(), COMBUST_DAMAGE, 'A failed Hull save costs 2d6 Kinetic.')
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'And knocks it Prone.')

func test_a_character_that_passes_takes_nothing_and_stays_up():
	var victim:Unit = LeolethFixture.create_hostile(game, IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST, [SAVE_PASSES] as Array[int])
	assert_eq(victim.current_damage(), 0, 'A passed save takes nothing...')
	assert_false(victim.has_status(Lancer.STATUS.PRONE), '...and stays on its feet.')

func test_an_ally_in_the_blast_is_hit_too():
	# "ALL CHARACTERS", with no faction filter in either direction. This is the case that makes
	# apply_only_to_allies / apply_only_to_enemies being false mean something.
	var ally:Unit = LeolethFixture.create_ally(game, IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST,
		[SAVE_FAILS, D6, D6] as Array[int])
	assert_eq(ally.current_damage(), COMBUST_DAMAGE, 'An ally in the area takes it too.')
	assert_true(ally.has_status(Lancer.STATUS.PRONE), 'And goes down with everyone else.')

func test_the_leoleth_in_its_own_blast_saves_like_anyone():
	# APPLY_TO_SELF IS FALSE and the Leoleth is caught ANYWAY, which is the whole of Departure 6:
	# map.get_all_units_at_tiles filters by UnitRelation.can_affect(whos_asking, unit)
	# (map_state.gd:319-320), and can_affect has no self clause (unit_relation.gd:393-404).
	#
	# THE 2d6 IS ROLLED LOW HERE - see SELF_D6's header. A maximised one structures an 8 HP frame, and
	# ALL SYSTEMS RED then hands the bar back to full, so the damage number stops being readable.
	aim_at(LEOLETH_TILE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST,
		[SAVE_FAILS, SELF_D6, SELF_D6] as Array[int])
	assert_eq(leoleth.current_damage(), SELF_BLAST_DAMAGE - leoleth.core.frame.stat.armor,
		'The Leoleth takes its own 2d6, less its armor 1.')
	assert_gt(leoleth.core.current.health, 0,
		'fixture: and it stayed up, so that number is the blast and not the structure fold.')
	assert_true(leoleth.has_status(Lancer.STATUS.PRONE), 'And is knocked Prone by its own blast.')

func test_a_character_two_tiles_out_is_untouched():
	var outside:Unit = LeolethFixture.create_hostile(game, OUTSIDE_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST, [SAVE_PASSES] as Array[int])
	assert_eq(outside.current_damage(), 0, 'Blast 1 is radius 1: two tiles out is outside it.')
	assert_false(outside.has_status(Lancer.STATUS.PRONE), 'And it stays up.')

func test_two_characters_in_the_blast_each_make_their_own_save():
	# Both fail, so the queue is [save, d6, d6] twice and their ORDER does not matter - which is what
	# makes this the only multi-target case in the file.
	var one:Unit = LeolethFixture.create_hostile(game, IN_THE_BLAST)
	var two:Unit = LeolethFixture.create_hostile(game, ALSO_IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST,
		[SAVE_FAILS, D6, D6, SAVE_FAILS, D6, D6] as Array[int])
	assert_eq(one.current_damage(), COMBUST_DAMAGE, 'Each of them rolled its own save...')
	assert_eq(two.current_damage(), COMBUST_DAMAGE, '...and each took its own 2d6.')

# ---------------------------------------------------------------- "characters"

func test_a_deployable_in_the_blast_is_untouched():
	# RULING 22, and it is not cosmetic: a non-character AUTO-FAILS every forced save without rolling
	# (unit_hasecheck.gd:52-53), so without the is_actor filter every deployable in the area would be
	# Proned and hit - and would silently eat two d6 out of every queue in this file.
	var cover:Unit = LeolethFixture.create_hostile_object(game, IN_THE_BLAST)
	assert_false(cover.is_character(), 'fixture: a Jericho cover is not a character.')
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST, [] as Array[int])
	assert_eq(cover.current_damage(), 0, 'A deployable in the area is untouched.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 60,
		'And NOTHING was rolled for it - no save, no damage. (queue() tails with sixty 1s.)')

func test_a_drone_in_the_blast_is_untouched():
	# RULING 22's other half: a drone IS a character (unit.gd:116 - "active mech/pilot/drone") and is
	# NOT an actor (:117). Every "character" clause on this frame is is_actor().
	var drone:Unit = LeolethFixture.create_drone(game, IN_THE_BLAST, Faction.AI_ENEMY)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor, which is the rule this frame uses.')
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST, [] as Array[int])
	assert_eq(drone.current_damage(), 0, 'A drone in the area is untouched.')
	assert_false(drone.has_status(Lancer.STATUS.PRONE), 'And stays up.')

func test_the_prone_has_no_natural_lifetime():
	# apply_until = MANUAL (ruling 12). Prone is cleared by standing up, not by a turn passing - so a
	# lifetime here would quietly hand the victim a free recovery.
	#
	# THE TURN THAT IS CYCLED IS THE VICTIM'S OWN, AND THAT IS THE WHOLE TEST. The archetype's default
	# is END_OF_NEXT_TURN (action_system_apply_status.gd:6), and a STATUS with that lifetime is demoted
	# to END_OF_THIS_TURN by the HOLDER'S turn START (unit_condition.gd:17-19) and only then cleared by
	# any turn's end (:32-33). The plan's draft cycled the LEOLETH's turn instead, which never reaches
	# either line for the victim - measured 2026-09-22: with apply_until = 1 that version stayed green
	# and only the declarative wiring test went red, so the behavioural half discriminated nothing.
	var victim:Unit = LeolethFixture.create_hostile(game, IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_COMBUST,
		[SAVE_FAILS, D6, D6] as Array[int])
	assert_true(victim.has_status(Lancer.STATUS.PRONE), 'fixture: it went down.')
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, victim) # a natural lifetime would be demoted here...
	await SpecFactory.end_turn(game, victim)   # ...and cleared here
	assert_true(victim.has_status(Lancer.STATUS.PRONE),
		'And it is still Prone after a whole turn of its own.')

func test_another_face_offers_nothing():
	var bystander:Unit = LeolethFixture.create_hostile(game, IN_THE_BLAST)
	aim_at(BLAST_CENTRE)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_REACH)
	assert_eq(bystander.current_damage(), 0, 'A 3 combusts nobody...')
	assert_false(bystander.has_status(Lancer.STATUS.PRONE), '...and knocks nobody down.')
