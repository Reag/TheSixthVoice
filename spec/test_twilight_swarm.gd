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
	# EVERY NUMBER OFF THE SHEET (specs/sixth-voice/08-sluagh.md:76-85), read from the RESOURCE.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.TWILIGHT_SWARM)
	assert_not_null(kit, 'ms_twilight_swarm loads as a Kit through ContentLibrary.')
	if kit == null: return
	# ASSERTED BEFORE THE GUARD BELOW, not after: ContentLibrary.get_kit never returns null for an
	# unknown id - it hands back the mt_missing_mechsystem placeholder (kit.gd:13), an empty Kit -
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
