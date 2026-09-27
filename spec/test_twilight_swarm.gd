# TWILIGHT SWARM (the Sluagh's rank-II Unique shield system, SP3 Tasks 3 and 4).
#
#   "OVERSHIELD, SHIELD, UNIQUE, LIMITED 3.
#    Damnation of the Host (Quick Tech): You gain OVERSHIELD equal to 1d6+GRIT.
#    Crown of Restless Dead (Free): An allied character within sensors gains OVERSHIELD equal to
#    your OVERSHIELD, then you take that much Energy damage. This damage cannot be prevented in any
#    way. You may only take this action 1/round."
#
# THIS KIT SHIPS NO BUFFS AT ALL. Everything both actions do is a write to state.overshield through
# the shared helper plus, for the Crown, one damage event. There is no chip to draw and nothing to
# expire, which is why this file's assertions are all numbers rather than buff presence.
#
# THE CARD'S FOUR TAGS MAP TO THREE THINGS AND ONE NOTHING. UNIQUE and SHIELD are
# Kit.SYSTEM_TAGS bits 1 and 16 (kit.gd:30), so system_tags = 17; LIMITED 3 is charges_max = 3;
# and there is NO OVERSHIELD FLAG IN THE ENGINE - the tag is an LCP-side descriptor with no
# counterpart. Vanilla's own ms_aceso_stabilizer.tres carries the identical four card tags and ships
# exactly system_tags = 17 and charges_max = 3, which is the precedent this copies. The profile test
# asserts is_ai() and is_nhp() FALSE as well as the two true ones, because a wrong literal (9, 25,
# 21) would satisfy a has-check on either of the bits that matter.
#
# RULING 3 IS PROVISIONAL AND LIVES IN ONE LINE. Damnation spends a charge; the Crown does not. The
# card does not say which actions the LIMITED covers, the author has asked //Bela//, and the
# implementation is action_crown_of_restless_dead.gd's `consumes_charges() -> false` override -
# `consumes_charges` is a FUNCTION on Action (action.gd:108), not an export, so this cannot be done
# in the .tres and cannot be flipped by editing data. test_crown_does_not_spend_a_charge is the pin.
#
# THE CROWN'S 1/ROUND IS THE ENGINE'S, NOT OURS, AND IT NEEDED ONE LINE OF DATA ANYWAY.
# Action.get_per_round_hard_limit returns 1 for any action whose cost is FREE (action.gd:156-158),
# so the card's "1/round" is free. But the tally is kept per USAGE GROUP and the group defaults to
# the KIT (gear_core.gd:166-168) - so without a distinct usage_group on the Crown, ONE Damnation in
# the round would fill the Crown's single slot and the Crown would be refused. That is what
# test_a_damnation_does_not_consume_crowns_one_per_round exists for, and it is the mutation in this
# sub-project most worth having.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_twilight_swarm.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## Two tiles east: comfortably inside the sheet's Sensors 10.
const ALLY_TILE := Vector2i(6, 6)
## TWELVE tiles east, and the number is chosen so ONE point of Overshield is not enough.
## Inexorable Formation adds the Sluagh's Overshield to its Sensors 1:1, and the Crown is unavailable
## at 0 Overshield - so there is no way to ask "out of range at Sensors 10" at all. The honest pair is
## Overshield 1 (Sensors 11, still short of 12) against Overshield 2 (Sensors 12, exactly enough).
const FAR_ALLY_TILE := Vector2i(16, 6)

## The sheet's Sensors, before Inexorable Formation adds anything.
const BASE_SENSORS := 10

## The d6 every Damnation test queues. Deliberately NOT 1 and NOT 6: queue()'s tail is 1s, so a 1
## would be indistinguishable from "the roll never happened", and 6 is the maximum, so an off-by-one
## in the Grit addition would be clipped by nothing but would read as plausible.
const D6 := 4

var game:Gamemaster
var sluagh:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_twilight_swarm(sluagh)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func swarm() -> GearCore:
	return sluagh.get_gear(SluaghFixture.TWILIGHT_SWARM)

func charges() -> int:
	var gear := swarm()
	return gear.charges_current if GearCore.is_valid(gear) else -1

func action(action_id:StringName) -> Action:
	var gear := swarm()
	return gear.get_action(action_id) if GearCore.is_valid(gear) else null

func specific(action_id:StringName) -> SpecificAction:
	return SpecificAction.create(sluagh, swarm(), action(action_id))

# ---------------------------------------------------------------- the profile

func test_the_profile_matches_the_card():
	# EVERY NUMBER OFF THE SHEET (specs/sixth-voice/08-sluagh.md:76-83), read from the RESOURCE.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.TWILIGHT_SWARM)
	assert_not_null(kit, 'ms_twilight_swarm loads as a Kit through ContentLibrary.')
	if kit == null: return
	# ASSERTED BEFORE THE GUARD BELOW, not after: ContentLibrary.get_kit never returns null for an
	# unknown id - it hands back the mt_missing_mechsystem placeholder (kit.gd:9), an empty Kit -
	# so a guard placed first would let this test return having asserted nothing discriminating.
	# test_nightfare_nexus.gd's RED run measured exactly that on 2026-09-21.
	assert_false(kit.actions.is_empty(), 'fixture: the Kit carries its actions.')
	assert_eq(kit.sp_cost, 2, 'SP 2, as the sheet says.')
	assert_false(kit.is_trait, 'It is licence gear, not a frame trait.')
	assert_eq(kit.charges_max, 3, 'LIMITED 3 is charges_max.')

	# THE BITWISE ASSERTION, both ways. 17 is UNIQUE (1) | SHIELD (16); the two false checks are what
	# a wrong literal would fail. There is deliberately no OVERSHIELD assertion - the engine has no
	# such flag, and ms_aceso_stabilizer.tres, which carries the identical four card tags, ships the
	# same 17.
	assert_eq(kit.system_tags, 17, 'system_tags is UNIQUE | SHIELD.')
	assert_true(kit.is_unique(), 'UNIQUE...')
	assert_true(kit.is_shield(), '...and SHIELD...')
	assert_false(kit.is_ai(), '...and not AI...')
	assert_false(kit.is_nhp(), '...and not NHP.')

func test_damnation_is_a_jammable_quick_tech():
	var damnation := action(SluaghFixture.DAMNATION_ID)
	assert_not_null(damnation, 'The Kit carries Damnation of the Host.')
	if damnation == null: return
	assert_true(damnation is ActionSystem, 'It is an ActionSystem.')
	assert_eq(damnation.get_action_type(specific(SluaghFixture.DAMNATION_ID)), Lancer.ACTION.QUICK,
		'A QUICK action.')
	assert_true(damnation.is_jammable(),
		'And a TECH one, which is what makes it jammable - ActionSystem.is_jammable returns is_tech.')
	# QUICK TECH HAS NO REPEAT-ACTION LIMIT ON A PLAYER MECH (ActionSystem's override returns 99).
	# Without it the SECOND press in a turn would abort at event_gear_activate with no "Gear not
	# available" line - the silent-abort trap memory lancer-tactics-spec-harness-traps records.
	#
	# THAT IS NOT THE SAME AS "AS OFTEN AS YOU LIKE", AND THE DISTINCTION COST A RUN (2026-09-21).
	# The repeat-action rule and the ACTION ECONOMY are two different gates. A QUICK costs one action
	# point and a mech's turn holds two, so exactly TWO Damnations fit in a turn however many charges
	# are left - which is why test_three_damnations_empty_the_system_and_a_fourth_is_refused walks
	# three turns rather than pressing three times in one. The first draft pressed three times in one
	# turn, spent two charges and read as a content bug.
	assert_eq(damnation.get_per_turn_soft_limit(specific(SluaghFixture.DAMNATION_ID)), 99,
		'With no repeat-action limit, because quick tech is the rule\'s own exemption - the action '
		+ 'economy is what caps a single turn at two.')

# ---------------------------------------------------------------- Damnation of the Host

func test_damnation_grants_a_d6_plus_grit():
	SluaghFixture.set_grit(sluagh, 2)
	SluaghFixture.queue([D6])
	await SluaghFixture.damnation(game, sluagh)
	assert_eq(Overshield.current(sluagh), D6 + 2,
		'1d6+GRIT, and the exact number - not merely "more than nothing".')

func test_damnation_at_grit_zero_still_grants_the_d6():
	# RULING 25. Overshield.grant is a no-op at amount <= 0, and a Grit-sized grant on this frame is
	# allowed to hit it - but NOT here, because the d6 is always at least 1. The discriminating half
	# of the Grit test: drop the `+ grit` from the implementation and this stays green while the
	# test above goes red, which is why both exist.
	assert_eq(Overshield.grit(sluagh), 0, 'fixture: a fixture pilot is licence level 0, so Grit 0.')
	SluaghFixture.queue([D6])
	await SluaghFixture.damnation(game, sluagh)
	assert_eq(Overshield.current(sluagh), D6, 'The d6 alone, and it still lands.')

func test_damnation_spends_a_charge():
	assert_eq(charges(), 3, 'fixture: it starts at its LIMITED 3.')
	SluaghFixture.queue([D6])
	await SluaghFixture.damnation(game, sluagh)
	assert_eq(charges(), 2, 'One press, one charge.')

func test_three_damnations_empty_the_system_and_a_fourth_is_refused():
	# ONE PRESS PER TURN, ACROSS THREE TURNS, and the turn walk is not decoration - see the action
	# economy note on test_damnation_is_a_jammable_quick_tech. Charges are per-SCENE state
	# (GearCore.charges_current, restored only by a full repair), so walking turns does not refund
	# them; uses_this_round does reset, and nothing here reads it.
	#
	# THE OVERSHIELD VALUE IS THE EVIDENCE, NOT THE CHARGE COUNT. GearCore.spend_charge floors at 0
	# (gear_core.gd:250), so a fourth press that WENT THROUGH would leave charges at 0 either way -
	# the charge count cannot tell "refused" from "spent a charge it did not have". The shield can:
	# the queue's fourth entry is a 6, so a fourth Damnation would raise a Grit-0 mech from 4 to 6
	# under the helper's max semantics.
	SluaghFixture.queue([1, 1, D6, 6])
	await SluaghFixture.damnation(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	await SluaghFixture.damnation(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	await SluaghFixture.damnation(game, sluagh)
	assert_eq(charges(), 0, 'Three presses empty it.')
	assert_eq(Overshield.current(sluagh), D6,
		'fixture: the third press is the one that mattered - 1, 1, then 4, under max semantics.')
	assert_false(UnitAction.can_activate_gear(specific(SluaghFixture.DAMNATION_ID)),
		'And a fourth cannot be activated at all - unit_action.gd:153, REASON.NO_CHARGES.')

	await SpecFactory.use(game, sluagh, SluaghFixture.TWILIGHT_SWARM, SluaghFixture.DAMNATION_ID)
	assert_eq(Overshield.current(sluagh), D6,
		'Pressing it anyway grants nothing: the queued 6 was never rolled.')

# ---------------------------------------------------------------- Crown of Restless Dead

## Every tile this action would let the Sluagh pick right now. THE END-TO-END RANGE READ: it composes
## get_target_range (which is live Sensors) with can_target_unit (which carries no geometry at all -
## SP2's Grey Birds finding), so a tile is in here only if BOTH hold. Asserting can_target_unit alone
## would say nothing about range, and asserting get_target_range alone would say nothing about the
## faction and character filters.
func crown_targetable() -> Array[Vector2i]:
	return UnitTargeting.get_tiles_targetable(specific(SluaghFixture.CROWN_ID))

func crown_can_target(unit:Unit) -> bool:
	return action(SluaghFixture.CROWN_ID).can_target_unit(unit, specific(SluaghFixture.CROWN_ID))

func test_the_crown_is_a_free_action_with_its_own_usage_group():
	var crown := action(SluaghFixture.CROWN_ID)
	assert_not_null(crown, 'The Kit carries Crown of Restless Dead.')
	if crown == null: return
	assert_true(crown is ActionSystemTargetUnit, 'It is an ActionSystemTargetUnit.')
	assert_eq(crown.get_action_type(specific(SluaghFixture.CROWN_ID)), Lancer.ACTION.FREE,
		'A FREE action, which is where its 1/round comes from...')
	assert_eq(crown.get_per_round_hard_limit(specific(SluaghFixture.CROWN_ID)), 1,
		'...for free: Action.get_per_round_hard_limit returns 1 for any FREE action (action.gd:156-158).')
	# DEPARTURE 1's DECLARATIVE HALF. The tally is kept per usage group and the group defaults to the
	# KIT id (gear_core.gd:166-168), so a shared group would let one Damnation fill the Crown's single
	# slot. test_a_damnation_does_not_consume_crowns_one_per_round is the behavioural half; this is
	# what names the mechanism, so a reader deleting the line knows what it was for.
	assert_eq(crown.usage_group, &'crown_of_restless_dead',
		'And it keeps its OWN usage group, so Damnation uses are not tallied against it.')
	assert_true(crown.target_range_is_sensors, 'Its range is Sensors...')
	assert_true(crown.can_target_allies, '...it takes allies...')
	assert_false(crown.can_target_enemies, '...never enemies...')
	assert_false(crown.can_target_self, '...and never itself.')
	assert_true(crown.requires_target_character, 'And only CHARACTERS.')

func test_crown_gives_the_ally_the_sluaghs_overshield():
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 5)
	assert_eq(Overshield.current(ally), 0, 'fixture: the ally starts bare.')

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 5, 'The ally gains exactly what the Sluagh held.')

func test_crown_leaves_the_sluagh_at_zero_overshield_and_full_health():
	# RULING 7's WHOLE POINT: the self-damage is unpreventable, and the Sluagh's OWN Overshield still
	# soaks it - the soak lives inside damage() (event_unit_damage.gd:215-218) and is applied after
	# every flag alike. So the mech hands its shield over and ends at nothing, not at nothing AND
	# five health down. That is the fiction of the transfer, and it is the difference between a
	# support tool and a suicide button.
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 5)
	var health_before:int = sluagh.core.current.health

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(sluagh), 0, 'The Sluagh keeps none of it...')
	assert_eq(sluagh.core.current.health, health_before, '...and takes no HEALTH damage at all.')
	assert_eq(sluagh.current_damage(), 0, 'Nothing reached the frame.')

func test_the_self_damage_is_unpreventable_by_armor():
	# NO_REDUCE, MEASURED RATHER THAN READ. damage_modifications.gd:59 returns before armor on that
	# flag, and the pipeline's ONLY armor read is unit.core.current.armor (:97) - which no buff can
	# write, so the armor is set on the pool directly, the idiom test_rapier_carronade.gd and
	# test_reinforcement_blast.gd both use.
	#
	# THE NUMBERS ARE WHAT DISCRIMINATE: with Overshield 5 and armor 2, an unflagged 5 would arrive
	# as 3 and leave TWO Overshield standing. NO_REDUCE makes it arrive as 5 and take all five.
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	sluagh.core.current.armor = 2
	await SluaghFixture.grant_overshield(sluagh, 5)
	assert_eq(sluagh.core.current.armor, 2, 'fixture: the Sluagh really has 2 armor.')

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 5, 'fixture: the ally got the full amount.')
	assert_eq(Overshield.current(sluagh), 0,
		'And the armor bought nothing: 5 arrived as 5. Unflagged it would arrive as 3 and leave 2.')
	assert_eq(sluagh.current_damage(), 0, 'The shield still absorbed all of it.')

func test_crown_does_not_spend_a_charge():
	# RULING 3, PROVISIONAL. One line in action_crown_of_restless_dead.gd, and this is its pin. If
	# Bel says the LIMITED covers both actions, that override goes and this test inverts.
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 3)
	assert_eq(charges(), 3, 'fixture: full charges.')

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 3, 'fixture: the Crown really fired.')
	assert_eq(charges(), 3, 'And spent no charge: the LIMITED is Damnation alone.')

func test_crown_at_zero_overshield_is_unavailable():
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	assert_eq(Overshield.current(sluagh), 0, 'fixture: the Sluagh holds nothing.')
	await SluaghFixture.open_turn(game, sluagh)
	assert_false(UnitAction.can_activate_gear(specific(SluaghFixture.CROWN_ID)),
		'With no shield there is nothing to hand over, so the action is not offered.')

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 0, 'And pressing it anyway gives the ally nothing.')

func test_a_second_crown_in_one_round_is_refused():
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 4)
	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 4, 'fixture: the first Crown landed.')

	# The Sluagh is at 0 now, so re-arm it - otherwise "the second did nothing" would be the
	# zero-Overshield gate above rather than the round limit, and the test would prove the wrong thing.
	await SluaghFixture.grant_overshield(sluagh, 6)
	assert_false(UnitAction.can_activate_gear(specific(SluaghFixture.CROWN_ID)),
		'The round is spent, even with a fresh shield to give.')
	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 4, 'So the ally is still on the first Crown four.')
	assert_eq(Overshield.current(sluagh), 6, 'And the Sluagh paid nothing the second time.')

func test_a_damnation_does_not_consume_crowns_one_per_round():
	# DEPARTURE 1's BEHAVIOURAL HALF, and the single most valuable case in this sub-project. Both
	# actions live on one Kit. GearCore.get_usage_group_for_action falls back to the KIT id when an
	# action names no group (gear_core.gd:166-168), and the Crown's hard limit is ONE use of its group
	# per round - so with a shared group the Damnation below would fill it and the Crown would be
	# refused for the rest of the round. Every other Crown test arranges its Overshield with
	# grant_overshield(), which touches no usage group at all, so this is the ONLY case that would
	# notice.
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	SluaghFixture.queue([D6])
	await SluaghFixture.damnation(game, sluagh)
	assert_eq(Overshield.current(sluagh), D6, 'fixture: the Damnation landed, in this same round.')

	assert_true(UnitAction.can_activate_gear(specific(SluaghFixture.CROWN_ID)),
		'The Crown is still available: its usage group is its own.')
	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), D6, 'And it fires, in the same round as the Damnation.')

func test_crowns_round_resets_at_the_sluaghs_own_turn_start():
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 4)
	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 4, 'fixture: the first Crown landed.')

	# uses_this_round is cleared by UnitAction.new_turn_refresh -> reset_per_round_usage, which runs
	# at the turn start of the unit whose turn it is (event_turn_start.gd:79, unit_action.gd:87-88) -
	# so it is the SLUAGH'S own turn that gives the Crown back, not anybody else's.
	await SpecFactory.end_turn(game, sluagh)
	await SluaghFixture.open_turn(game, sluagh)
	await SluaghFixture.grant_overshield(sluagh, 6)
	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 6, 'A new turn, a new Crown.')

func test_an_ally_beyond_sensors_cannot_be_targeted():
	var far := SluaghFixture.create_ally(game, FAR_ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 1)
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 1,
		'fixture: one point of Overshield buys one tile of Sensors - Inexorable Formation.')
	assert_false(crown_targetable().has(FAR_ALLY_TILE),
		'Twelve tiles is past Sensors 11, so the Crown cannot reach it.')
	assert_true(crown_can_target(far),
		'...and NOT because of the faction or character filters, which pass - can_target_unit '
		+ 'carries no geometry at all. The range is the whole of the refusal.')

	# THERE IS DELIBERATELY NO "AND PRESSING IT ANYWAY DOES NOTHING" HALF HERE, unlike every other
	# negative in this file - AND THE REASON IS AN ENGINE FACT WORTH KNOWING (measured 2026-09-21,
	# after the first draft of this test failed on it).
	#
	# A SUPPLIED TARGET IS FILTERED BY can_target_unit AND BY NOTHING ELSE.
	# TargetActionUtil.ask_for_targets_alt does exactly one filter on the units it was handed:
	# `Util.filter(supplied_units, specific.action.can_target_unit.bind(specific))`
	# (target_action_util.gd:173; :172 is the Unit.is_valid filter one line above it). No range check, no line of sight, no get_tiles_targetable. Range is
	# enforced ONLY on the path where the player picks - get_tiles_targetable, which is what the
	# assertion above reads - so a target handed in directly reaches activate_for_target however far
	# away it is standing, and the Crown duly fires.
	#
	# THAT IS NOT A SPEC ARTEFACT. The AI supplies units by the same route
	# (incoming_supplied_units is documented "if the AI already has an idea of WHO to target"), so
	# this is how the engine behaves for anything that pre-picks. It means the tile read IS the pin
	# for range on this card, and a behavioural assertion here would be asserting a bug that is not
	# ours. The faction and character negatives below DO carry their behavioural halves, because
	# those gates live in can_target_unit and therefore survive the supply path.

func test_inexorable_formation_extends_crowns_reach():
	# THE LIVE READ, and the pair to the test above: the ONLY thing that differs is one more point of
	# Overshield. ActionSystemTargetUnit.get_target_range returns specific.unit.get_sensor_range()
	# when target_range_is_sensors, and that getter is frame + state.stat_bonus.sensor_range
	# (unit.gd:305) - which Inexorable Formation's STATBLOCK buff writes. So the Sluagh's own shield
	# decides how far its Crown reaches, which is this frame's whole shape in one interaction.
	var far := SluaghFixture.create_ally(game, FAR_ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 2)
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 2, 'fixture: Sensors 12 at 2 Overshield.')
	assert_true(crown_targetable().has(FAR_ALLY_TILE), 'Twelve tiles is now exactly in reach.')

	await SluaghFixture.crown(game, sluagh, far)
	assert_eq(Overshield.current(far), 2, 'And the Crown reaches it.')
	assert_eq(Overshield.current(sluagh), 0, 'At the usual price.')

func test_crown_grants_nothing_extra_to_an_ally_already_above_it_and_still_costs_the_sluagh():
	# RULING 21's ORDER, MEASURED. `amount` is read ONCE, before anything moves, and the grant is the
	# helper MAX semantics - so an ally already above it keeps what it had, and the Sluagh pays the
	# full amount regardless. Reading `amount` after the grant, or reading the ally value, would
	# make this test the one that notices.
	var ally := SluaghFixture.create_ally(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(ally, 8)
	await SluaghFixture.grant_overshield(sluagh, 3)

	await SluaghFixture.crown(game, sluagh, ally)
	assert_eq(Overshield.current(ally), 8, 'The ally keeps its eight: the grant is a max, not a sum.')
	assert_eq(Overshield.current(sluagh), 0, 'And the Sluagh still paid all three.')
	assert_eq(sluagh.current_damage(), 0, 'Soaked, as ever.')

func test_crown_cannot_target_a_hostile_or_the_sluagh_itself():
	var hostile := SluaghFixture.create_hostile(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 4)
	assert_false(crown_can_target(hostile), 'can_target_enemies is false, so a hostile is refused...')
	assert_false(crown_targetable().has(ALLY_TILE), '...and its tile is not offered.')
	assert_false(action(SluaghFixture.CROWN_ID).can_target_unit_self(specific(SluaghFixture.CROWN_ID)),
		'And the Sluagh cannot crown itself - the card says "an ALLIED character".')

	await SluaghFixture.crown(game, sluagh, hostile)
	assert_eq(Overshield.current(hostile), 0, 'A hostile gains nothing.')
	assert_eq(Overshield.current(sluagh), 4, 'And the Sluagh pays nothing.')

func test_crown_can_crown_an_allied_drone():
	# AUTHOR'S RULING, 2026-09-27 (mod-wide), REVERSING THIS CARD'S OWN 2026-09-21 FRAME-CLOSE
	# RULING. "Character" is is_character() again - the LCP's own DRONE tag: "Drones are Size 1/2
	# characters." The canonical paragraph is in action_stealing_of_the_souls.gd's header.
	#
	# requires_target_character is `potential_target.is_character()`
	# (action_system_target_unit.gd:16), which a drone now passes in its own right, and
	# action_crown_of_restless_dead.gd's own can_target_unit override asks exactly the same
	# predicate - a redundant restatement, not a narrowing.
	var drone := SluaghFixture.create_drone(game, ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 4)
	assert_true(drone.is_character(), 'fixture: the engine counts a drone as a character...')
	assert_false(drone.is_actor(), '...though not as an ACTOR, which no longer matters here.')
	assert_true(crown_can_target(drone), 'So the Crown MAY target an allied drone...')
	assert_true(crown_targetable().has(ALLY_TILE), '...and its tile is offered.')

	await SluaghFixture.crown(game, sluagh, drone)
	assert_eq(Overshield.current(drone), 4, 'It gains the Sluagh\'s Overshield...')
	assert_eq(Overshield.current(sluagh), 0, '...and the Sluagh pays for it, exactly as with any character.')

# ---------------------------------------------------------------- the card and the licence

func test_the_card_rows_resolve():
	# Through THIS MOD'S OWN compiled artifact first, so a sibling Reag-* mod loaded in the same
	# testkit run cannot hold this green.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in [
			'gear.ms_twilight_swarm.name', 'gear.ms_twilight_swarm.flavor',
			'gear.ms_twilight_swarm.action_damnation_of_the_host.name',
			'gear.ms_twilight_swarm.action_damnation_of_the_host.effect',
			'gear.ms_twilight_swarm.action_crown_of_restless_dead.name',
			'gear.ms_twilight_swarm.action_crown_of_restless_dead.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.ms_twilight_swarm.name'), 'Twilight Swarm', 'The card name.')

	# X.tr KEEPS THE GLOSSARY PIPES (SP1 Task 7's finding), so these pin the pipes as well as the
	# words. All four labels were checked against assets/localization/localizations.csv on
	# 2026-09-21 and resolve case-insensitively: |OVERSHIELD| -> lancer.term.overshield,
	# |GRIT| -> lancer.term.grit, |sensors| -> lancer.stat.sensor_range (whose .short is "Sensors"),
	# |Energy| -> lancer.damagetype.energy (whose .short is "Energy"). The CASE inside the pipes is
	# the LCP'S, not the glossary's - the localisation directive is verbatim, and this card writes
	# "sensors" and "Energy" where SP1's own rows happened to write "Sensors" and "energy".
	assert_eq(X.tr('gear.ms_twilight_swarm.action_damnation_of_the_host.effect'),
		'You gain |OVERSHIELD| equal to 1d6+|GRIT|',
		'The LCP verbatim - including its missing full stop, which is the source and not a slip here.')
	assert_eq(X.tr('gear.ms_twilight_swarm.action_crown_of_restless_dead.effect'),
		'An allied character within |sensors| gains |OVERSHIELD| equal to your |OVERSHIELD|, then '
		+ 'you take that much |Energy| damage. This damage cannot be prevented in any way. You may '
		+ 'only take this action 1/round.',
		'The LCP verbatim, pipes added. No divergence is recorded for this card and none is wanted.')

	# THE ENGINE REALLY READS THESE KEYS. Translate.action looks up
	# gear.<kit>.<action>.effect first (translate.gd:26-29), which is where a two-action Kit has to
	# put them - a Kit-level row would be found by BOTH actions through the fallback and each would
	# render the other's text.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.TWILIGHT_SWARM)
	if kit == null or kit.actions.size() < 2: return assert_true(false, 'fixture: the Kit loaded.')
	assert_eq(Translate.action(kit, kit.actions[0], 'effect', false),
		X.tr('gear.ms_twilight_swarm.action_damnation_of_the_host.effect'),
		'Damnation finds its own row...')
	assert_eq(Translate.action(kit, kit.actions[1], 'effect', false),
		X.tr('gear.ms_twilight_swarm.action_crown_of_restless_dead.effect'),
		'...and the Crown finds its own, not Damnation.')

func test_the_licence_grants_it_at_rank_two():
	var licence:UnlockTree = ContentLibrary.get_license_tree(SluaghFixture.LICENSE_ID)
	assert_not_null(licence, 'li_sluagh loads as an UnlockTree.')
	if licence == null: return
	var rank_2_ids:Array[StringName] = []
	for kit:Kit in licence.rank_2.granted_gear: rank_2_ids.append(kit.compcon_id)
	assert_true(rank_2_ids.has(SluaghFixture.TWILIGHT_SWARM), 'Rank 2 grants Twilight Swarm...')
	assert_true(rank_2_ids.has(SluaghFixture.NIGHTFARE_NEXUS), '...beside the Nightfare Nexus.')
	# UnlockTree.license_name reads rank_2.granted_frames.front() (unlock_tree.gd:28-32), so a
	# granted_gear edit that clobbered granted_frames would rename the whole licence "???".
	assert_eq(licence.rank_2.granted_frames.size(), 1, 'And rank 2 still grants the frame itself.')
	# UPDATED, SP4 Task 3 (2026-09-21): rank 3 now grants Bleakshadow Gate, exactly as the line this
	# replaces predicted ("until SP4"). Only the claim THIS task could break survives: Twilight
	# Swarm did not wander into rank 3 either.
	var rank_3_ids:Array[StringName] = []
	for kit:Kit in licence.rank_3.granted_gear: rank_3_ids.append(kit.compcon_id)
	assert_false(rank_3_ids.has(SluaghFixture.TWILIGHT_SWARM), 'And rank 3 does NOT also grant it.')
