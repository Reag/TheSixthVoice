# COMPAT: what this mod does when a third-party mod has redefined a word on one of our cards.
#
# Our content ships to players running other mods. This file pins the DECISIONS we took where one of
# their mechanisms meets one of ours - not "must compose", which would remove the author's
# judgement, but whichever way the ruling actually went. What it buys is that a third-party update
# moving the mechanism goes RED here, instead of silently invalidating a ruling written in prose.
#
# The registry of contested seams, consulted at DESIGN time, is
# skills/lancer-tactics-content-authoring/references/compat-seams.md. Design:
# specs/2026-09-16-mod-compatibility-design.md.
#
# EVERY ASSERTION HERE PRINTS WHEN IT SKIPS. A resident mod is a convention, not a guarantee - the
# residency set lives in testkit/compat_seams.gd and is restored by restore-links.ps1 - and a silent
# skip reads green while testing nothing. That is not hypothetical: CCC's li_gms co-existence test
# skipped every run from the day it was written until 2026-09-16, for want of a competitor.
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')
const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')
const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const PurpleThornFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const HazardFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')
const ShackletonFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const GloireFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')
const GruttePierFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')
const KoremasaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const RakshasaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const LoversKnotFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')
const SixSkyFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const PatienceReduce := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/buff_patience_reduce.gd')
## Read-only here: the Mark's retort case asserts the dome is untouched between its two halves.
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const TALENTS_MOD := 'gavstarb-talents_1st_party'
## House Guard rank 1. Hidden buff, adjacency_range = 2, only_to_allies - see the registry row.
const HOUSE_GUARD_BUFF := &'buff_front_rank_adjacency_range'
## The helper the talents mod adds to UnitRelation. Its ABSENCE is what every guarded call in our
## content has to survive, so it doubles as this file's presence check.
const TALENTS_HELPER := &'get_adjacency_range_alt'

const IMMUNITY_BUFF := &'buff_fungal_network_immunity'
const ARMOR_BUFF := &'buff_fungal_network_armor'

# Same footprint as test_fungal_network.gd: the Myconid is SIZE 2, anchored at (4,4) and occupying
# (4,4) (5,4) (4,5) (5,5). distance_between is Chebyshev over CLOSEST tiles.
const MYCONID_TILE := Vector2i(4, 4)
const ADJACENT_TILE := Vector2i(6, 4)  # 1 from (5,4) - inside the ally aura either way
const NEAR_TILE := Vector2i(7, 4)      # 2 from (5,4) - OUTSIDE the ally aura, and exactly the tile
                                       # House Guard's widening pulls into "adjacent"

# The Maiden's Blush case builds its OWN game (see the test below), so these owe the Myconid's
# footprint nothing. The Blush folds three tiles east and the two characters stand beyond the landing.
const BLUSH_TILE := Vector2i(4, 4)
const BLUSH_LANDING := Vector2i(7, 4)
const SAVING_TILE := Vector2i(8, 4)  # 1 from the landing: Step asks it to save
const SPARED_TILE := Vector2i(9, 4)  # 2 from the landing: Step does not, and House Guard does not
                                     # change that - which is the ruling
const STEP_CHIP := &'buff_mist_and_thunder_invisible'

# The Vauban case builds its OWN game (see the test below). The Vauban is SIZE 1, so adjacency here is
# simply distance 1 from its one tile.
const VAUBAN_TILE := Vector2i(4, 4)
const VAUBAN_ADJACENT := Vector2i(5, 4)  # 1 out - inside the range-1 aura either way
const VAUBAN_NEAR := Vector2i(6, 4)      # 2 out - OUTSIDE the aura, and exactly the tile House
                                         # Guard's widening pulls into "adjacent"
const WELL_CHIP := &'buff_gravity_well'

# The Primrose case builds its OWN game (see the tests below). The Primrose is SIZE 1, so adjacency
# here is simply distance 1 from its one tile, and the mover starts inside the Drill's threat.
const PRIMROSE_TILE := Vector2i(4, 4)
const PRIMROSE_ADJACENT := Vector2i(5, 4)  # 1 out
const PRIMROSE_NEAR := Vector2i(6, 4)      # 2 out - exactly the tile House Guard's widening pulls
                                           # into "adjacent"

# SP4 Task 5. The Eternity Hammer's on-hit gather is measured from the TARGET
# (onhit_eternity_hammer.gd:160-164), not from the Primrose, so its own geometry needs its own tiles -
# reusing PRIMROSE_NEAR here would sit only 1 tile from PRIMROSE_ADJACENT (the target below), which is
# INSIDE the Hammer's own RADIUS 1 and would be a genuine bystander rather than the "widening would
# have to reach this" case the ruling test needs.
const HAMMER_FAR_HOSTILE_TILE := PRIMROSE_ADJACENT + Vector2i(2, 0)  # 2 out from the TARGET
# The Sluagh case builds its OWN game (see the tests below), as the Maiden's Blush, Vauban and
# Primrose cases do. The Sluagh is SIZE 1, so adjacency here is simply distance 1 from its one tile.
const SLUAGH_TILE := Vector2i(4, 6)
const SLUAGH_ADJACENT := Vector2i(5, 6)      # 1 out - adjacent with or without the widening
const SLUAGH_TWO_OUT := Vector2i(6, 6)       # 2 out - exactly the tile House Guard's widening pulls in
const SLUAGH_SHOOTER := Vector2i(10, 6)      # inside the assault rifle's Range 10 of everyone
const MARK_COVER_CHIP := &'buff_mark_soft_cover'
## The Mark's retort case (close review, slice 3 I-3). What the Sluagh holds, and therefore what the
## retort deals to whoever missed - the attacker's health is the observable.
const RETORT_SHIELD := 3
## Loses to any evasion this fixture hands out. Its queue needs no more entries than this: every
## further roll in that sequence (soft cover's accuracy die, the rifle's damage d6) is fed by
## SluaghFixture.queue's own tail of 1s, and a 1 is the right answer for all of them.
const SLUAGH_D20_MISSES := 1

# HAMMER_FAR_ALLY_TILE lived here until SP4 Task 5's review. It served a Primrose-side liveness pair
# that the review showed could not detect what it existed to detect (the widening the Hammer's gather
# would have to consult is the TARGET's, not the Primrose's), and which duplicated
# test_house_guard_still_widens_adjacency_with_our_unit_relation_extender_installed above tile for
# tile. The liveness assertion now runs on the target and on a HOSTILE - see that test's header.

# ---- Leoleth (SP1 Task 13): the STRUCTURE seam ----
# The resident talents mod replaces event_unit_structure's `execute` WHOLESALE for its reroll buffs
# and never calls super. ALL SYSTEMS RED hooks execute_preblock instead, which the resident leaves
# alone. Task 0's probe measured that with a knockoff reaction (spec/test_spike_structured_pre_under_talents.gd,
# frozen); this re-states it against the PRODUCTION reaction on the real frame.
const STRUCTURE_SCRIPT := 'res://content/events/event_unit_structure.gd'
const TALENTS_STRUCTURE_EXTENSION := 'res://unpacked/%s/res/content/events/event_unit_structure.gd_ext.gd' % TALENTS_MOD
## The one method the resident ADDS. Its presence on the LIVE script is what proves the replacement is
## installed in this run, rather than merely present on disk.
const TALENTS_STRUCTURE_METHOD := &'make_structure_check_with_rerolls'
## The method the whole ruling hangs on: the resident must NOT define it.
const PREBLOCK := &'execute_preblock'

const LEOLETH_TILE := Vector2i(4, 6)
## 13 against 8 HP and armor 1 leaves the bar at -4; the structure check's ONE d6 is cheated to 6,
## which is IMPAIRED - the only outcome with no gear prompt and no second die.
const LEOLETH_BIG_HIT := 13

var game:Gamemaster
var myconid:Unit


func before_each() -> void:
	game = MyconidFixture.create_game(self)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)

## The Eternity Hammer ruling test is the only test in this file that cheats dice, and
## PrimroseFixture.cheat_a_hit queues a 40-entry buffer of sixes that one swing does not exhaust.
## Dice.cheat_attack only APPENDS (dice.gd:13-17), so whatever GUT runs next would be handed a
## leftover 6 in place of its own first roll - cheat_a_hit's own header records a real run
## (test_knock_em_down.gd) lost to exactly that. Same after_each as test_eternity_hammer.gd:116-117.
func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- fixture helpers

## True when the talents mod is present AND its adjacency machinery is actually reachable. Both
## halves matter: the mod could be installed with its unit_relation.gd extension silently dead,
## which is the failure mode CLAUDE.md warns about for every .gd_ext.gd on an engine service.
func talents_adjacency_available() -> bool:
	return UnitRelation.has_method(TALENTS_HELPER)

## Announce the skip rather than passing quietly. Returns true when the caller should give up.
##
## gut.p AND pass_test, because pass_test alone does not print its message at the default log level
## - verified 2026-09-16 by mutating TALENTS_HELPER to a name nothing defines, which produced a
## silent 3/3. That is precisely the green-while-testing-nothing this file exists to avoid. Same
## pairing as CCC's test_li_gms.gd, which is where the idiom comes from.
func skipped_without_talents() -> bool:
	if talents_adjacency_available(): return false
	var message := 'SKIPPED: %s is not resident, so House Guard cannot widen anything. Restore the residency set with restore-links.ps1.' % TALENTS_MOD
	gut.p(message)
	pass_test(message)
	return true

func ally(tile:Vector2i) -> Unit:
	return MyconidFixture.create_dummy(game, tile, 10, Faction.PLAYER)

func widen_adjacency_on(unit:Unit) -> void:
	SpecFactory.apply_buff(unit, HOUSE_GUARD_BUFF)


# ===================== HOUSE GUARD WIDENS ADJACENCY - THE MECHANISM =====================

## THE HALF THAT MAKES THE RULING BELOW MEAN ANYTHING.
##
## Asserting "the Fungal Network ignores widened adjacency" is vacuous unless something is actually
## widening it. This is that something: with House Guard's buff on the Myconid, a unit TWO tiles out
## is returned by UnitRelation.adjacent_characters - which it never is in vanilla.
##
## Reddened by: the talents mod dropping its adjacent_characters override, or changing the channel
## name off &'adjacency_range'.
func test_house_guard_really_does_widen_adjacent_characters() -> void:
	if skipped_without_talents(): return
	var far_ally := ally(NEAR_TILE)

	assert_false(UnitRelation.adjacent_characters(myconid).has(far_ally),
		'Two tiles out is NOT adjacent before the buff.')

	widen_adjacency_on(myconid)

	assert_true(UnitRelation.adjacent_characters(myconid).has(far_ally),
		'House Guard pulls a unit two tiles out into adjacent_characters.')


# ===================== THE RULING: FUNGAL NETWORK IGNORES THE WIDENING =====================

## RULING, 2026-09-16, taken at the Myconid close and recorded rather than fixed - the author's
## call. The Fungal Network ally shelter does NOT respect widened adjacency.
##
## It is not an oversight in our content, it is where the engine measures: the shelter is a
## PassiveAura, and PassiveAura.is_within_range compares UnitRelation.distance_between against
## aura_range directly (passive_aura.gd:85). House Guard overrides adjacent_characters() and
## NOTHING ELSE - not distance_between - so no aura in the game sees it, ours or vanilla's. Vanilla
## Guardian does not respect it either (unit_relation.gd:457 scans a hard-coded 1).
##
## THIS TEST ASSERTS THE RULING, NOT COMPLIANCE. If the ruling is ever reversed - the fix shape is
## the talents mod's own Greater Guardian, which subclasses PassiveAura and overrides
## is_within_range through a GUARDED call to get_adjacency_range_alt - then this test inverts. It is
## here so that reversal is a deliberate edit rather than a silent drift.
func test_the_ally_shelter_ignores_widened_adjacency() -> void:
	if skipped_without_talents(): return
	var far_ally := ally(NEAR_TILE)
	widen_adjacency_on(myconid)

	await MyconidFixture.fungal_network(game, myconid)

	assert_true(UnitRelation.adjacent_characters(myconid).has(far_ally),
		'The widening is live for this ally.')
	assert_false(UnitCondition.has_buff(far_ally, IMMUNITY_BUFF),
		'RULED: the widened ally gets no Impaired immunity from the Fungal Network.')
	assert_false(UnitCondition.has_buff(far_ally, ARMOR_BUFF),
		'RULED: the widened ally gets no +1 armor from the Fungal Network.')

## The other half of the same ruling, and the one that keeps the test above from passing for the
## wrong reason: a genuinely adjacent ally is sheltered exactly as before. Without this, deleting
## the whole ally aura would leave the ruling test green.
func test_a_genuinely_adjacent_ally_is_still_sheltered_with_the_widening_active() -> void:
	if skipped_without_talents(): return
	var near_ally := ally(ADJACENT_TILE)
	widen_adjacency_on(myconid)

	await MyconidFixture.fungal_network(game, myconid)

	assert_true(UnitCondition.has_buff(near_ally, IMMUNITY_BUFF),
		'A truly adjacent ally still gets Impaired immunity.')
	assert_true(UnitCondition.has_buff(near_ally, ARMOR_BUFF),
		'A truly adjacent ally still gets +1 armor.')


# ===================== THE RULING: STEP OF MIST AND THUNDER MEASURES ITS OWN RADIUS =====================

## RULING, 2026-09-17, taken at the Maiden's Blush DESIGN - the frame's `Contested seams:` line, and
## the first one on this project decided before the content existed rather than at a close.
##
## Step of Mist and Thunder's "characters adjacent to the space you teleport to must make a Systems
## save" is measured with UnitRelation.get_characters_within(unit, 1, false) - the engine's own radius,
## which goes through distance_between. House Guard overrides adjacent_characters() and NOTHING ELSE,
## so its widening does not reach the save. The Fungal Network reasoning exactly (see above): ask
## where the engine measures.
##
## THIS ASSERTS THE RULING, NOT COMPLIANCE, and inverts if the ruling is ever reversed - at which
## point Step would have to read adjacent_characters through a guarded call the way the talents mod's
## own Greater Guardian reads get_adjacency_range_alt.
##
## THREE ASSERTIONS BEHIND A PRECONDITION, and the first of the three is the one that keeps the other
## two honest: with the talents mod absent, or its extension silently dead, "nobody two tiles out
## saved" would be true for the boring reason. skipped_without_talents() announces that case rather
## than passing quietly. The precondition is that the Step landed at all - without it a Step that
## silently did nothing would leave both chip assertions trivially satisfied.
##
## IT FIRES THE CONTENT, which is what the Myconid ruling above does and what an earlier version of
## this test did not: asserting on UnitRelation.get_characters_within directly restates a property of
## the ENGINE, true whatever our action asks, and stayed green with the action moved to the other side
## of the seam. Step is pressed for real, and the observable is the chip actually hung on a character.
func test_house_guard_does_not_widen_step_of_mist_and_thunders_adjacent_saves() -> void:
	if skipped_without_talents(): return

	# ITS OWN GAME, AND ITS OWN RESPONDER. Pressing Step now opens exactly ONE yes/no prompt - its own
	# confirm; the Uncertainty Field can no longer take a Step (reach design ruling C, 2026-09-17). A
	# dedicated responder is still needed because MaidensBlushFixture.step() answers through
	# `yesno_queue` and lands the tile through `chosen_plan_queue`, and only the queued responder
	# (mod_choice_responder.gd) carries `yesno_queue` - the stock responder installed for the Myconid
	# cases above does not. before_each already installed that stock responder, and two live responders
	# would both answer every request, so that one is silenced rather than removed: its guard clauses
	# return before they count a choice (spec_factory.gd:446, :509).
	if is_instance_valid(SpecFactory.current_responder):
		SpecFactory.current_responder.choose_yesnos = false
		SpecFactory.current_responder.choose_plans = false
	var pair := MaidensBlushFixture.create_game_with_sequenced_prompts(self)
	game = pair[0]
	var responder = pair[1]

	var blush := MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	# ALLIES, because House Guard's widening is only_to_allies - a hostile control would be outside
	# the buff and the ruling would never be contested. Step asks "characters" either way (ruling 13).
	var near_character := MaidensBlushFixture.create_ally(game, SAVING_TILE)
	var far_character := MaidensBlushFixture.create_ally(game, SPARED_TILE)
	await MaidensBlushFixture.open_turn(game, blush)
	widen_adjacency_on(blush)

	# FOUR values queued, THREE drawn: the 2d6, then one Systems save low enough to fail. The fourth is
	# there for the failing case - a widened radius would ask far_character too, and an empty queue
	# would hand it a random d20 that might pass and leave this test green for the wrong reason.
	await MaidensBlushFixture.step(game, blush, responder, [3, 4, 1, 1], BLUSH_LANDING)
	assert_eq(blush.tile(), BLUSH_LANDING, 'Fixture: the Step landed where we picked.')

	# 1. THE WIDENING IS LIVE IN THIS RUN, measured from where the Blush actually stands. Without this
	# the two below prove nothing.
	assert_true(UnitRelation.adjacent_characters(blush).has(far_character),
		'House Guard pulls the character two tiles out into adjacent_characters.')

	# 2 and 3. What Step actually asked - the engine's own radius, unwidened.
	assert_true(UnitCondition.has_buff(near_character, STEP_CHIP),
		'The character ONE tile from the landing was asked to save, and failed.')
	assert_false(UnitCondition.has_buff(far_character, STEP_CHIP),
		'The one TWO tiles out was never asked, however wide House Guard has made "adjacent".')


# ===================== THE RULING: GRAVITY WELL MEASURES ITS OWN RANGE =====================

## RULING, 2026-09-18, taken at the Vauban DESIGN - the frame's `Contested seams:` line, and the
## second one on this project decided before the content existed rather than at a close.
##
## Gravity Well's "any adjacent allied mechs also benefit" is a PassiveAura of range 1, and
## PassiveAura.is_within_range compares UnitRelation.distance_between against aura_range directly
## (passive_aura.gd:85). House Guard overrides UnitRelation.adjacent_characters() and NOTHING ELSE -
## not distance_between - so its widening does not reach any aura in the game, ours or vanilla's.
## The Fungal Network reasoning exactly (see above): ask where the engine measures.
##
## THIS ASSERTS THE RULING, NOT COMPLIANCE, and inverts if the ruling is ever reversed - at which
## point the aura would have to subclass is_within_range through a GUARDED call to
## get_adjacency_range_alt, which is what the talents mod's own Greater Guardian does.
##
## THREE ASSERTIONS BEHIND A PRECONDITION, and the precondition is what keeps the other two honest:
## with the talents mod absent, or its extension silently dead, "the far ally got nothing" would be
## true for the boring reason. skipped_without_talents() announces that case rather than passing
## quietly.
func test_house_guard_does_not_widen_gravity_wells_shelter() -> void:
	if skipped_without_talents(): return

	game = VaubanFixture.create_game(self)
	var vauban := VaubanFixture.create_vauban(game, VAUBAN_TILE)
	# ALLIES, because House Guard's widening is only_to_allies - a hostile control would be outside
	# the buff and the ruling would never be contested. Gravity Well shelters allied MECHS, which
	# create_ally produces.
	var near_ally := VaubanFixture.create_ally(game, VAUBAN_ADJACENT)
	var far_ally := VaubanFixture.create_ally(game, VAUBAN_NEAR)
	widen_adjacency_on(vauban)
	VaubanFixture.lay_difficult(game, [VAUBAN_TILE])
	VaubanFixture.track(game)

	assert_true(UnitRelation.adjacent_characters(vauban).has(far_ally),
		'The widening is live for this ally - two tiles out reads as adjacent.')
	assert_false(UnitCondition.has_buff(far_ally, WELL_CHIP),
		'RULED: the widened ally is not sheltered by Gravity Well.')
	assert_true(UnitCondition.has_buff(near_ally, WELL_CHIP),
		'While a genuinely adjacent one is - so the assertion above is not vacuous.')

## The other half of the same ruling, and the one that keeps the test above from passing for the wrong
## reason: the shelter still WORKS with the widening active. Without this, deleting the whole aura
## would leave the ruling test green.
func test_a_genuinely_adjacent_allied_mech_is_still_sheltered_with_the_widening_active() -> void:
	if skipped_without_talents(): return

	game = VaubanFixture.create_game(self)
	var vauban := VaubanFixture.create_vauban(game, VAUBAN_TILE)
	var near_ally := VaubanFixture.create_ally(game, VAUBAN_ADJACENT)
	var shooter := VaubanFixture.create_hostile(game, Vector2i(10, 8))
	VaubanFixture.equip_ranged(shooter)
	widen_adjacency_on(vauban)
	VaubanFixture.lay_difficult(game, [VAUBAN_TILE])
	VaubanFixture.track(game)

	# FIRES THE CONTENT rather than restating a property of the engine: the observable is the -1
	# actually folded into a roll against the sheltered ally, the way test_gravity_well.gd measures it.
	var weapon:GearCore = shooter.get_gear(VaubanFixture.RANGED_ID)
	var specific := SpecificAction.create(shooter, weapon, weapon.get_solo_action())
	var pre := AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = near_ally}))
	var lines := 0
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == X.tr('gear.mt_gravity_well.name') and mod.mod == -1: lines += 1
	assert_eq(lines, 1, 'A truly adjacent allied mech still takes the -1 with the widening active.')


# ===================== THE THIRD EXTENDER OF unit_relation.gd COMPOSES =====================
#
# NEW AT THE PRIMROSE (SP1, 2026-09-19), and it is a claim about a THIRD-PARTY mod's code rather than
# about a word on a card. res/engine/character/unit/service/unit_relation.gd_ext.gd makes this mod
# the THIRD extender of that one vanilla file in a live install: gavstarb-talents_1st_party widens
# adjacent_characters for House Guard, Reag-ThyHubris suppresses overwatch for Earthstep, and ours
# waives the SUPERHEAVY refusal for Wormhole Grasp. All three call super, so ModLoader's chain
# composes them in whatever order the player's modset happens to produce.
#
# THE TWO TESTS ARE ONE ASSERTION IN TWO DIRECTIONS, on ONE unit holding BOTH mechanisms. Either
# alone would pass against a broken chain: if ours had dropped its super, the widening test would
# still pass (nothing we do touches adjacent_characters) - and if THEIRS had, the waiver test would,
# because ours sits below theirs in the chain and never asks. Only both, on one Primrose, say the
# chain is whole.
#
# ASSERTED THROUGH get_weapons_that_can_overwatch, which is the deepest call in the chain
# (action_overwatch.gd:21) and the one the SP1 probe measured at three depths: a call through the
# autoload node dispatches to the most-derived override and so does ONE unqualified static call below
# it, and no deeper - so this call reaches our waiver only if every link is intact.

func test_house_guard_still_widens_adjacency_with_our_unit_relation_extender_installed() -> void:
	if skipped_without_talents(): return

	game = PrimroseFixture.create_game(self)
	var primrose := PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	# ALLIES, because House Guard's widening is only_to_allies - a hostile control would be outside the
	# buff and the ruling would never be contested.
	var near_ally := PrimroseFixture.create_ally(game, PRIMROSE_ADJACENT)
	var far_ally := PrimroseFixture.create_ally(game, PRIMROSE_NEAR)

	# CORRECTED AT IMPLEMENTATION (2026-09-19): the brief's draft placed these two CONTROL assertions
	# BELOW the widen_adjacency_on() call they are the control for, which made the first of them
	# self-contradictory - measured red, `[Failed]: CONTROL: two tiles out is not adjacent before the
	# buff is consulted`, with `Applying buff ... buff_front_rank_adjacency_range` printed two lines
	# above it in the same test. The brief's own trailing comment ("RE-applied…") shows the intended
	# order, and it is the order this file's own test_house_guard_really_does_widen_adjacent_characters
	# (:111-121) already uses: measure vanilla FIRST, then widen. No assertion was added, removed or
	# weakened - only moved above the block that invalidated it.
	assert_false(UnitRelation.adjacent_characters(primrose).has(far_ally),
		'CONTROL: two tiles out is not adjacent before the buff is consulted... ')
	assert_true(UnitRelation.adjacent_characters(primrose).has(near_ally),
		'...while one tile out always is.')

	# BOTH MECHANISMS ON ONE UNIT: House Guard's chip AND Wormhole Grasp's marker. The marker is what
	# our own override reads, so with it held our extension is not merely installed, it is ACTIVE.
	widen_adjacency_on(primrose)
	SpecFactory.apply_buff(primrose, PrimroseFixture.WORMHOLE_GRASP)
	assert_true(UnitCondition.has_buff(primrose, PrimroseFixture.WORMHOLE_GRASP),
		'fixture: the Primrose holds the marker, so our override is live on this unit.')

	# Re-applied so the assertion below cannot be read as "the widening was never on".
	widen_adjacency_on(primrose)
	assert_true(UnitRelation.adjacent_characters(primrose).has(far_ally),
		'House Guard still pulls a unit two tiles out into adjacent_characters with our extender in '
		+ 'the same chain - so the talents mod\'s override is still reached.')

func test_the_superheavy_waiver_still_works_with_the_talents_mod_resident() -> void:
	if skipped_without_talents(): return

	game = PrimroseFixture.create_game(self)
	var primrose := PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	var mover := PrimroseFixture.create_hostile(game, PRIMROSE_ADJACENT)
	PrimroseFixture.equip_superheavy_melee(primrose)
	widen_adjacency_on(primrose)

	var without := UnitRelation.get_weapons_that_can_overwatch(primrose, mover)
	var offers_without := without.any(func(s:SpecificAction) -> bool:
		return s.gear.kit.compcon_id == PrimroseFixture.SUPERHEAVY_MELEE)
	assert_false(offers_without,
		'CONTROL: with the talents mod resident and no marker, vanilla still refuses SUPERHEAVY.')

	SpecFactory.apply_buff(primrose, PrimroseFixture.WORMHOLE_GRASP)
	var with_marker := UnitRelation.get_weapons_that_can_overwatch(primrose, mover)
	var offers_with := with_marker.any(func(s:SpecificAction) -> bool:
		return s.gear.kit.compcon_id == PrimroseFixture.SUPERHEAVY_MELEE)
	assert_true(offers_with,
		'And the waiver still reaches the deepest call in the chain with two other mods extending the '
		+ 'same file - so ours composes with theirs.')


# ===================== RULING 18: DAZZLING WIND'S LEAP MEASURES ITS OWN RADIUS =====================
#
# RULING 18 (design, taken before the content existed - the frame's `Contested seams:` line).
# "adjacent to you" on the Leap's card is a distance-1 RADIUS from the mech's own tiles
# (action_leap.gd:59-62 - UnitRelation.get_characters_within(unit, 1, false, ...)), the Fungal
# Network and Gravity Well shape exactly: House Guard overrides adjacent_characters() and NOTHING
# ELSE, so its widening does not reach a radius query.
#
# THIS TEST IS THE RULING, NOT A DESCRIPTION OF IT. If a talents update ever moved the widening into
# get_characters_within, this goes red and somebody decides again rather than the prose quietly
# becoming false.
func test_house_guard_does_not_widen_the_leaps_adjacent_pick() -> void:
	if skipped_without_talents(): return
	var pair:Array = PrimroseFixture.create_game_with_prompts(self)
	var game:Gamemaster = pair[0]
	var responder = pair[1]
	var primrose:Unit = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	var wind:GearCore = PrimroseFixture.equip(primrose, PrimroseFixture.DAZZLING_WIND)
	await PrimroseFixture.open_turn(game, primrose)

	# A hostile two tiles from where each leap below will END: outside the card's own distance-1
	# reach.
	var far:Unit = PrimroseFixture.create_hostile(game, PRIMROSE_NEAR + Vector2i(1, 0))

	# CONTROL, ABOVE THE BUFF (SP1 finding 25): with no widening in play, two tiles out is not
	# offered. Landing at PRIMROSE_ADJACENT, one real tile away from where the Primrose starts, is
	# what makes this a genuine leap - CORRECTED AT IMPLEMENTATION: the brief's draft aimed this
	# activation at PRIMROSE_TILE, the Primrose's OWN starting tile, so nothing would have moved and
	# "nobody offered" would have been true for the wrong reason (a no-op activation, not a correctly
	# measured adjacency). The VACUITY assertion right below is what would have caught that.
	await game.execute_event(&'event_gear_activate', {
		unit = primrose, gear = wind, action = wind.kit.get_action(&'action_leap'),
		target_tiles = [PRIMROSE_ADJACENT] as Array[Vector2i],
	})
	assert_eq(primrose.tile(), PRIMROSE_ADJACENT, 'VACUITY: the control leap actually moved the mech.')
	assert_eq(responder.unit_prompts.size(), 0, 'CONTROL: two tiles out is not adjacent before the buff.')

	# A fresh turn: Leap is capped at the engine's own per-turn soft limit like any non-free action
	# (action.gd:161-163), so firing it twice in the same turn would be silently refused - the same
	# "nothing happened" trap as above, one level up the call stack.
	await SpecFactory.end_turn(game, primrose)
	await PrimroseFixture.open_turn(game, primrose)

	# Now with House Guard's widening live on the Primrose. THE only_to_allies TRAP: the resident
	# rank-1 buff (buff_front_rank_adjacency_range.tres) sets only_to_allies = true, and the talents
	# mod's own adjacent_characters() override (unit_relation.gd_ext.gd:40-44) filters its WIDENED
	# half to Faction.is_ally(u.state.faction, values.category) - so a HOSTILE two tiles out can NEVER
	# be pulled into adjacent_characters() by this buff, whatever Leap's own code does. Testing only a
	# hostile far unit would therefore pass whether Leap reads the widened set or its own radius - a
	# vacuous "green while testing nothing" of exactly the kind this file's header warns about.
	# far_ally, at the same distance the compat-seams doc measures ("an enemy two tiles out still
	# triggers nothing"), is what proves the widening is actually LIVE on this Primrose at the moment
	# of the ruling check, rather than merely silent because nothing here could ever show it.
	widen_adjacency_on(primrose)
	var far_ally:Unit = PrimroseFixture.create_ally(game, PRIMROSE_ADJACENT + Vector2i(0, 2))
	assert_true(UnitRelation.adjacent_characters(primrose).has(far_ally),
		'fixture: the widening is live on this Primrose - two tiles out reads as adjacent for an ally.')

	responder.unit_prompts.clear()
	# A perpendicular hop, not back onto PRIMROSE_ADJACENT: the brief's draft aimed this second leap
	# at the tile the Primrose already stood on after the first leap, which is the identical no-op
	# trap one tile later. One tile south keeps far at exactly Chebyshev distance 2 (dx 2, dy 1 -> 2).
	var second_landing := PRIMROSE_ADJACENT + Vector2i(0, 1)
	await game.execute_event(&'event_gear_activate', {
		unit = primrose, gear = wind, action = wind.kit.get_action(&'action_leap'),
		target_tiles = [second_landing] as Array[Vector2i],
	})
	assert_eq(primrose.tile(), second_landing, 'VACUITY: the second leap also actually moved the mech.')
	assert_eq(responder.unit_prompts.size(), 0,
		'RULING 18: the widening does not reach a radius query, so the Leap still offers nobody.')
	assert_true(Unit.is_valid(far), 'VACUITY: the hostile was there the whole time.')


# ===================== RULING 18: THE ETERNITY HAMMER'S BYSTANDER GATHER MEASURES ITS OWN RADIUS =====================
#
# RULING 18 (design, taken before the content existed - the frame's `Contested seams:` line), the same
# ruling the Leap test above pins, and the SAME UNDERLYING MECHANISM: "hostile characters adjacent to
# the target" on the Hammer's on-hit clause is a distance-1 radius measured from the TARGET
# (onhit_eternity_hammer.gd:160-164 - UnitRelation.get_characters_within(attacked_unit, RADIUS, false,
# an are_enemies(attacker, ...) filter, attacker)), the Fungal Network / Gravity Well / Leap shape
# exactly: House Guard overrides adjacent_characters() and NOTHING ELSE, so its widening never reaches
# a get_characters_within query, whichever unit happens to hold the buff.
#
# WHICH UNIT THE BUFF HAS TO SIT ON, AND WHY THIS IS NOT THE LEAP'S ANSWER. Corrected at SP4 Task 5's
# review: the first implementation put the buff on the PRIMROSE and read adjacent_characters(primrose),
# which cannot detect what the test exists to detect. The talents mod's override widens from the buffs
# held by THE UNIT BEING QUERIED and by nobody else - it builds Context.create({ unit = unit }) and
# asks UnitCondition.get_buffs_to(unit, &'adjacency_range', context) (unit_relation.gd_ext.gd:31-48) -
# so the hypothetical this ruling excludes, the Hammer's loop consulting the widened set, would be
# adjacent_characters(attacked_unit): the TARGET. A chip on the Primrose is simply invisible to that
# call, and a Primrose-side assertion would stay green under the very mutation it is meant to catch.
# The Leap precedent does not transfer, because there the two units coincide: action_leap.gd asks
# get_characters_within(unit, ...) about the PRIMROSE, so origin and buff-holder are one unit. Here
# they are two, and the buff goes on the target.
#
# AND UNLIKE THE LEAP, THIS SEAM REALLY CAN FIRE - which is what gives the ruling assertion its teeth.
# The note that sat here until 2026-09-19 said flatly that "a HOSTILE can never enter the widened set
# via this buff". That is true only from the ATTACKER's side of the query, and false from the target's,
# which is the side the Hammer measures from. buff_front_rank_adjacency_range.gd sets
# category = context.unit.state.faction under only_to_allies, and Faction.is_ally short-circuits on
# our_faction == check_faction (faction.gd:29-30), so is_ally(AI_ENEMY, AI_ENEMY) is TRUE: House Guard
# on an AI_ENEMY target widens to the other AI_ENEMY units around it. Those are precisely the PLAYER
# Primrose's hostiles, and they pass the Hammer's own are_enemies(attacker, other) filter unchanged. So
# the far hostile below genuinely WOULD burn if the gather consulted adjacent_characters, and the
# LIVENESS assertion is what proves that at the moment of the check rather than assuming it.
# (rulings.md's 2026-09-19 Primrose row still holds for the LEAP, where the origin is the buff-holding
# Primrose herself and only_to_allies really does keep every hostile out of the widened set.)
func test_house_guard_does_not_widen_the_eternity_hammers_bystander_gather() -> void:
	if skipped_without_talents(): return

	game = PrimroseFixture.create_game(self)
	var primrose := PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	PrimroseFixture.equip(primrose, PrimroseFixture.ETERNITY_HAMMER)
	# evasion -10: cheat_a_hit() alone already guarantees the swing lands (base_roll 19), but a
	# negative evasion is this mod's own established belt-and-braces shape for a target that must never
	# be the thing under test (test_eternity_hammer.gd:112 is the identical call). The health = 200 and
	# full_repair() that used to follow this line were removed at review as dead setup:
	# FitzgeraldFixture.create_dummy, which PrimroseFixture.create_dummy delegates to, already writes
	# health 200, armor 0 and the repair (fitzgerald_fixture.gd:105-109).
	var target := PrimroseFixture.create_dummy(game, PRIMROSE_ADJACENT, -10)

	# TWO TILES FROM THE TARGET, hostile to the Primrose - outside the Hammer's own RADIUS 1, and inside
	# House Guard's adjacency_range of 2, which together are exactly what make it the candidate a
	# widened adjacent_characters(target) query would have to pull in.
	var far_hostile := PrimroseFixture.create_hostile(game, HAMMER_FAR_HOSTILE_TILE)
	# So that IF the gather ever reached it, the save would fail and the Burn would land - the same
	# "would have happened" guard test_eternity_hammer.gd's own bystander tests use
	# (Fixture.force_agility_save_to_fail). A far_hostile that could only ever PASS its save would leave
	# the ruling assertion green whether or not the gather reached it.
	PrimroseFixture.force_agility_save_to_fail(far_hostile)

	# THE GEOMETRY IS ASSERTED, NOT DERIVED. HAMMER_FAR_HOSTILE_TILE is arithmetic on two constants, so
	# if PRIMROSE_ADJACENT ever moves the ruling assertion at the bottom silently degrades into "a
	# hostile five tiles away took no Burn" - green, and testing nothing. test_eternity_hammer.gd:345-348
	# spells out both of its own distances for the same reason.
	assert_eq(UnitRelation.distance_between(target, far_hostile), 2,
		'fixture: two tiles from the TARGET - outside the Hammer\'s RADIUS 1, inside House Guard\'s 2.')

	# 1. CONTROL, BEFORE THE BUFF - the same order test_house_guard_really_does_widen_adjacent_characters
	# above uses, and for the same reason: measuring vanilla first is what makes the assertion after the
	# buff a comparison rather than an assumption.
	assert_false(UnitRelation.adjacent_characters(target).has(far_hostile),
		'CONTROL: two tiles out is not adjacent to the target before the buff is consulted.')

	# ON THE TARGET, because the target is the unit the hypothetical query would ask about - see the
	# header. On the Primrose as well, so the ruling holds whichever of the two the gather measured from
	# and so this test still covers the case the first implementation covered.
	widen_adjacency_on(target)
	widen_adjacency_on(primrose)

	# 2. THE WIDENING IS LIVE ON THE TARGET, AND IT REACHES A HOSTILE, at the moment of the check below.
	# This is the assertion the whole test rests on: it says the set the gather would consult really does
	# contain far_hostile, so the ruling assertion at the bottom is a measurement rather than a green
	# taken for want of anything that could ever have fired.
	assert_true(UnitRelation.adjacent_characters(target).has(far_hostile),
		'House Guard on the TARGET pulls a same-faction hostile two tiles out into adjacent_characters '
		+ '- is_ally(AI_ENEMY, AI_ENEMY) is true, so only_to_allies does not keep it out from this side.')

	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.ETERNITY_HAMMER, target)
	assert_gt(target.current_damage(), 0, 'VACUITY: the swing actually landed.')

	# 3. RULING 18: the widening does not reach the bystander gather, however live it is on the TARGET
	# itself - two tiles from the target is still outside RADIUS 1, because get_characters_within never
	# consults adjacent_characters() at all.
	assert_eq(far_hostile.state.burn, 0,
		"RULING 18: a hostile two tiles from the target takes no Burn - the widening never reaches the "
		+ "Hammer's own get_characters_within query.")
	assert_eq(far_hostile.current_damage(), 0, 'and no HP loss either.')


# ===================== THE RULING: THE SLUAGH TAKES THE WIDENING =====================

## RULING, 2026-09-20, taken at the Sluagh DESIGN (ruling 6, the frame's `Contested seams:` line) -
## the OPPOSITE of the two rulings above, and for a reason rather than a preference.
##
## The Mark's soft cover is a PassiveAura SUBCLASS whose is_within_range is overridden to
## UnitRelation.is_adjacent, NOT the stock distance_between <= aura_range (passive_aura.gd:85). The
## talents mod overrides adjacent_characters and nothing else, and is_adjacent(a, b) IS
## adjacent_characters(a).has(b) (unit_relation.gd:7-8) - so the widening reaches this aura where it
## reaches no stock one. The Sluagh is itself an adjacency widener at SP4 (In Triumvirate), which is
## why refusing the seam here would mean measuring a radius and then re-adding its own widening by
## hand.
##
## THIS IS ALSO THE ONLY TEST IN THE SUITE THAT CAN TELL THE OVERRIDE FROM THE DEFAULT. Deleting
## passive_mark_cover_aura.gd's is_within_range reddens NOTHING in test_mark_of_the_dead.gd, because
## a radius of 1 and is_adjacent agree in vanilla. Measured at SP1 Task 7 and recorded there.
func test_house_guard_on_the_sluagh_widens_the_marks_soft_cover() -> void:
	if skipped_without_talents(): return
	var sluagh_game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(sluagh_game, SLUAGH_TILE)
	var far_ally:Unit = SluaghFixture.create_ally(sluagh_game, SLUAGH_TWO_OUT)

	# THE PRECONDITION, and it is what stops this passing for the boring reason: without the buff
	# two tiles out is not adjacent, so a green below would be meaningless.
	assert_false(UnitRelation.is_adjacent(sluagh, far_ally),
		'fixture: two tiles out is NOT adjacent before the buff.')
	widen_adjacency_on(sluagh)
	assert_true(UnitRelation.is_adjacent(sluagh, far_ally),
		'LIVENESS: House Guard on the SLUAGH really does pull it into is_adjacent.')

	await SluaghFixture.press_mark(sluagh_game, sluagh)
	assert_true(UnitCondition.has_buff(far_ally, MARK_COVER_CHIP),
		'RULED: the dome REACHES the widened ally - the aura asks is_adjacent, not a radius.')
	assert_eq(CoverCalculator.determine_cover(far_ally, SluaghFixture.create_hostile(
		sluagh_game, SLUAGH_SHOOTER)).total, Lancer.COVER.SOFT,
		'And the engine\'s own cover pipeline reads it.')

## THE OTHER HALF OF THE SAME RULING, and it is the half most content does not have: is_adjacent is
## ASYMMETRIC while the talents mod is installed. is_adjacent(a, b) reads a's buffs alone
## (unit_relation.gd:7-8), and the aura asks is_adjacent(aura_unit, moving_unit) - the SLUAGH first.
## So House Guard on the ALLY widens nothing for this card.
##
## Written as its own test rather than as a line in the one above, because it is a different claim
## about a different unit and it is the one a future reader will doubt.
func test_house_guard_on_the_ally_alone_does_not_widen_the_marks_soft_cover() -> void:
	if skipped_without_talents(): return
	var sluagh_game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(sluagh_game, SLUAGH_TILE)
	var far_ally:Unit = SluaghFixture.create_ally(sluagh_game, SLUAGH_TWO_OUT)

	widen_adjacency_on(far_ally)
	assert_true(UnitRelation.is_adjacent(far_ally, sluagh),
		'LIVENESS: the buff IS live on the ally - it pulls the Sluagh into the ALLY\'S list.')
	assert_false(UnitRelation.is_adjacent(sluagh, far_ally),
		'And that is one-sided: the SLUAGH\'S list is unchanged.')

	await SluaghFixture.press_mark(sluagh_game, sluagh)
	assert_false(UnitCondition.has_buff(far_ally, MARK_COVER_CHIP),
		'RULED: the dome does NOT reach it. Direction matters, and the aura reads the Sluagh.')

## THE SAME RULING ON A DIFFERENT MECHANISM, because the Mark's aura and Astral Guardian are two
## unrelated pieces of code that happen to ask the same question. A reaction gate is not an aura, and
## a regression in one would not touch the other.
##
## THE SHOT IS REAL and the observable is the ALLY'S Overshield, not a counter: a gate that passed
## but granted nothing would be a different defect with the same shape.
func test_house_guard_on_the_sluagh_lets_astral_guardian_reach_an_ally_two_tiles_out() -> void:
	if skipped_without_talents(): return
	var sluagh_game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(sluagh_game, SLUAGH_TILE)
	var far_ally:Unit = SluaghFixture.create_ally(sluagh_game, SLUAGH_TWO_OUT)
	var shooter:Unit = SluaghFixture.create_hostile(sluagh_game, SLUAGH_SHOOTER)
	SluaghFixture.arm_rifle(shooter)

	widen_adjacency_on(sluagh)
	assert_true(UnitRelation.is_adjacent(sluagh, far_ally), 'LIVENESS: the widening is live.')

	# [d20, the guardian's d6, the rifle's damage d6] - SluaghFixture.queue's own order.
	SluaghFixture.queue([19, 4, 5])
	await SluaghFixture.shoot(sluagh_game, shooter, far_ally)
	assert_eq(far_ally.current_damage(), 1,
		'RULED: Astral Guardian fired for an ally TWO tiles out - 4 Overshield absorbed 4 of the 5.')

## THE THIRD MECHANISM ON THE SAME SEAM, AND THE ONE RULING 6 CLAIMED WAS PINNED AND WAS NOT (close
## review, slice 3 I-3). rulings.md's 2026-09-20 row says all three "adjacent" effects take House
## Guard's widening and are "Pinned by spec/test_compat.gd (SP1)"; the Mark's aura had two cases and
## Astral Guardian one, and the Mark's RETORT had none. So nothing in the suite could tell
## action_mark_retort.gd's `UnitRelation.is_adjacent(unit, defender)` from a radius of 1 - they
## agree in vanilla, and only the talents mod's widening separates them.
##
## THE CONTROL IS INSIDE THE TEST, as the two halves of one shot sequence, because the widening can
## only be applied once and the honest control is the SAME attacker missing the SAME ally at the
## SAME tile without it. shoot() cycles the attacker's turn between the two, which hands every unit
## its reaction point back (event_turn_start.gd:42-44) - so the second half is not riding on
## bookkeeping the first half left behind.
##
## THE OBSERVABLE IS THE ATTACKER'S HEALTH, not a counter: a gate that passed and dealt nothing
## would be a different defect with the same shape. A miss with the rifle lands its Reliable 2 on
## the 200 HP ally and is irrelevant to that number.
func test_house_guard_on_the_sluagh_lets_the_marks_retort_answer_a_miss_two_tiles_out() -> void:
	if skipped_without_talents(): return
	var sluagh_game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(sluagh_game, SLUAGH_TILE)
	var far_ally:Unit = SluaghFixture.create_ally(sluagh_game, SLUAGH_TWO_OUT)
	var shooter:Unit = SluaghFixture.create_hostile(sluagh_game, SLUAGH_SHOOTER)
	SluaghFixture.arm_rifle(shooter)

	await SluaghFixture.press_mark(sluagh_game, sluagh)
	await SluaghFixture.grant_overshield(sluagh, RETORT_SHIELD)
	await SpecFactory.end_turn(sluagh_game, sluagh)

	# CONTROL, unwidened: two tiles out is not adjacent, so the retort is not offered.
	assert_false(UnitRelation.is_adjacent(sluagh, far_ally),
		'fixture: two tiles out is NOT adjacent before the buff.')
	var before:int = shooter.current_damage()
	SluaghFixture.queue([SLUAGH_D20_MISSES])
	await SluaghFixture.shoot(sluagh_game, shooter, far_ally)
	assert_eq(shooter.current_damage(), before,
		'CONTROL: with no widening, a miss on an ally two tiles out answers nothing.')

	widen_adjacency_on(sluagh)
	assert_true(UnitRelation.is_adjacent(sluagh, far_ally), 'LIVENESS: the widening is live.')
	assert_eq(Overshield.current(sluagh), RETORT_SHIELD,
		'fixture: and the dome is untouched - nothing was shot at the Sluagh.')

	SluaghFixture.queue([SLUAGH_D20_MISSES])
	await SluaghFixture.shoot(sluagh_game, shooter, far_ally)
	assert_eq(shooter.current_damage() - before, RETORT_SHIELD,
		'RULED: the Mark\'s retort answered a miss on an ally TWO tiles out - the gate asks '
		+ 'is_adjacent, not a radius. Rewrite it as distance_between <= 1 and this is the only '
		+ 'test in the suite that reddens.')

## THE CONTROL THAT KEEPS ALL THREE HONEST. Without the buff, the same ally at the same tile gets
## neither - so the three greens above are about the widening and not about the content being
## permanently generous. It runs WITHOUT the talents mod too, which is why it is the one test here
## that does not skip: nothing in it depends on the mod existing.
##
## ITS QUEUE WRITES THE SAME NUMBER IN BOTH DICE SLOTS, and that is the one correction this task
## makes to the plan's own spec source. The guardian's d6 and the rifle's damage d6 come out of ONE
## global FIFO (dice.gd:33-35), so in a case where the guardian is correctly REFUSED nothing pops the
## middle entry and the damage die is the SECOND number, not the third - the plan's [19, 4, 5] would
## have dealt 4 here and failed against its own expected 5 on a working build. Writing 5 in both
## slots makes the damage read identical whether or not a d6 was popped first, so the assertion is a
## statement about the gate rather than about queue alignment, and it keeps every bit of its
## discrimination: a guardian that DID fire would grant 5, absorb the whole 5 and leave 0 on HP.
## (The same correction test_astral_guardian.gd's header records for its own four negative cases,
## measured at SP1 Task 6.)
func test_without_the_widening_the_same_ally_two_tiles_out_gets_neither() -> void:
	var sluagh_game:Gamemaster = SluaghFixture.create_game(self)
	var sluagh:Unit = SluaghFixture.create_sluagh(sluagh_game, SLUAGH_TILE)
	var far_ally:Unit = SluaghFixture.create_ally(sluagh_game, SLUAGH_TWO_OUT)
	var shooter:Unit = SluaghFixture.create_hostile(sluagh_game, SLUAGH_SHOOTER)
	SluaghFixture.arm_rifle(shooter)

	await SluaghFixture.press_mark(sluagh_game, sluagh)
	assert_false(UnitCondition.has_buff(far_ally, MARK_COVER_CHIP),
		'No widening, no dome at two tiles out.')

	SluaghFixture.queue([19, 5, 5])
	await SluaghFixture.shoot(sluagh_game, shooter, far_ally)
	assert_eq(far_ally.current_damage(), 5,
		'And no guardian either: the ally took the whole 5 on HP.')


# ---------------------------------------------------------------- SP4: the Sluagh's own banner beside House Guard's

## Both overrides call super first, so they compose in either install order. This case runs OUR
## banner (In Triumvirate at six tiles) and THEIRS (House Guard at two) on the same Sluagh in the
## same run, and asserts both are live. The registry's Sixth Voice row (compat-seams.md).
##
## THE TWO CASES BELOW USE THE FILE'S OWN `game` rather than a Sluagh game of their own, which is the
## one difference from the four cases above. Those need SluaghFixture.create_game for its 30x12 map
## (a Sensors-13 read stands units 13 tiles out); six tiles fits the Myconid fixture's 15x9 with room
## to spare, and the Myconid standing at (4,4)-(5,5) is nothing to either assertion - neither the
## near ally at two out nor the far partner at six is measured through it.
func test_in_triumvirate_and_house_guard_widen_the_same_sluagh_together() -> void:
	if skipped_without_talents(): return
	var sluagh := SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_morrigan(sluagh)
	var near := ally(SLUAGH_TWO_OUT)
	var far := ally(SLUAGH_TILE + Vector2i(6, 0))

	assert_false(UnitRelation.is_adjacent(sluagh, near) or UnitRelation.is_adjacent(sluagh, far),
		'Control: neither adjacent.')

	widen_adjacency_on(sluagh)
	await SluaghFixture.triumvirate(game, sluagh, far)

	assert_true(UnitRelation.is_adjacent(sluagh, near),
		'House Guard still widens with our banner installed...')
	assert_true(UnitRelation.is_adjacent(sluagh, far),
		'...and our banner is live with House Guard resident. Same run, same unit.')

## The channels are separate: House Guard's buff does not make a Triumvirate partner, and our pair
## buff is not a House Guard radius. Read by name, not by effect.
##
## THE LITERAL &'adjacency_range' RATHER THAN A CONSTANT, deliberately: this file names the third
## party's BUFF (HOUSE_GUARD_BUFF) and its HELPER, not its channel, and a constant of ours for a
## string they own would read as though we shipped it. The last two lines are what stop the first
## from being vacuous - applying THEIR buff puts exactly one entry on that channel, so the name is
## the right one, and our pair is still alone on ours.
func test_the_two_widenings_read_different_channels() -> void:
	if skipped_without_talents(): return
	var sluagh := SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_morrigan(sluagh)
	var far := ally(SLUAGH_TILE + Vector2i(6, 0))

	await SluaghFixture.triumvirate(game, sluagh, far)

	assert_true(UnitCondition.get_buffs_to(sluagh, &'adjacency_range').is_empty(),
		'Our pair sits on no talents channel.')
	assert_false(UnitCondition.get_buffs_to(sluagh, SluaghFixture.ADJACENT_TO).is_empty(),
		'It sits on ours.')

	widen_adjacency_on(sluagh)

	assert_eq(UnitCondition.get_buffs_to(sluagh, &'adjacency_range').size(), 1,
		'...and that literal IS the channel talents reads: House Guard\'s own buff is the only thing on it.')
	assert_eq(UnitCondition.get_buffs_to(sluagh, SluaghFixture.ADJACENT_TO).size(), 1,
		'...and it never joined ours.')


# ===================== THE STRUCTURE SEAM (Leoleth, ALL SYSTEMS RED) =====================

## Every method visible on a script, base scripts included.
func method_names(script:Script) -> Array[StringName]:
	var names:Array[StringName] = []
	for method:Dictionary in script.get_script_method_list(): names.append(StringName(method.name))
	return names

## Only the methods a script DEFINES ITSELF, which is what "does not override it" means.
## get_script_method_list() returns the INHERITED ones too, so this reads the source instead - copied
## verbatim from spec/test_spike_structured_pre_under_talents.gd, where it was measured against the
## live resident.
func own_method_names(script:Script) -> Array[StringName]:
	var names:Array[StringName] = []
	var regex := RegEx.new()
	regex.compile('(?m)^func\\s+(\\w+)\\s*\\(')
	for found:RegExMatch in regex.search_all(script.source_code): names.append(StringName(found.get_string(1)))
	return names

## True when the talents mod's structure replacement is actually LIVE in this run. Announce the skip
## rather than passing quietly - the same pairing skipped_without_talents() above uses, and for the
## same measured reason (pass_test alone does not print at the default log level).
func skipped_without_talents_structure() -> bool:
	var live:Script = load(STRUCTURE_SCRIPT)
	if live != null and method_names(live).has(TALENTS_STRUCTURE_METHOD): return false
	var message := 'SKIPPED: %s is not resident, so the STRUCTURED PRE seam is unmeasured here. Restore the residency set with restore-links.ps1.' % TALENTS_MOD
	gut.p(message)
	pass_test(message)
	return true

## THE RULING, STRUCTURALLY. The resident replaces `execute` and defines no `execute_preblock` of its
## own, so vanilla's STRUCTURED PRE await (event_unit_structure.gd:33-34) still runs under it. A
## resident update that starts overriding the preblock reddens this BEFORE it can silently retire
## ALL SYSTEMS RED.
func test_the_talents_replacement_still_leaves_the_structure_preblock_alone() -> void:
	if skipped_without_talents_structure(): return
	var extension:Script = load(TALENTS_STRUCTURE_EXTENSION)
	assert_not_null(extension, 'The resident\'s extension loads from its unpacked path.')
	if extension == null: return
	var own := own_method_names(extension)
	assert_true(own.has(&'execute'),
		'LIVENESS: the resident really does replace execute - the seam the registry records.')
	assert_false(own.has(PREBLOCK),
		'THE RULING: it defines no %s of its own, so vanilla\'s STRUCTURED PRE await still runs.' % PREBLOCK)

## THE RULING, BEHAVIOURALLY, AGAINST THE PRODUCTION REACTION. Task 0's probe measured a knockoff on a
## dummy; this is the real Leoleth with the real cp_hydraulic_excess, under the real resident.
func test_a_structured_leoleth_takes_no_overflow_with_the_talents_mod_resident() -> void:
	if skipped_without_talents_structure(): return
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(), 'fixture: full HP.')
	await LeolethFixture.structure(game, leoleth, LEOLETH_BIG_HIT)
	assert_eq(leoleth.core.current.structure, 3, 'LIVENESS: it really structured.')
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(),
		'And the new bar is EXACTLY full under the resident\'s replacement - no overflow carried.')

## And the other half of the card, under the resident: the hard-cover chip.
func test_a_structured_leoleth_gains_hard_cover_with_the_talents_mod_resident() -> void:
	if skipped_without_talents_structure(): return
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	var shooter:Unit = LeolethFixture.create_hostile(game, Vector2i(12, 6))
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.NONE,
		'fixture: no cover in the open.')
	await LeolethFixture.structure(game, leoleth, LEOLETH_BIG_HIT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP), 'The chip landed...')
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.HARD,
		'...and the cover pipeline reads HARD off it, with the resident live.')


# ===================== THE unit_printer SEAM (Leoleth, Thermal Death Axe) =====================
# The resident gavstarb-ssc_emperor extends unit_printer.gd (full_repair, super-calling) and so do we
# (get_destructable_gear, super-calling). Ruled at design: super-first whitelists compose in any
# install order. This pins that BOTH extensions are in the live chain in one run AND our override
# still answers under it.
#
# IDENTIFIED BY SOURCE, NOT BY PATH, which Task 0's probe measured: ModLoader installs each extension
# with take_over_path, so only the MOST-DERIVED script in the chain has a resource_path at all - and
# it is the VANILLA path - while every script beneath it reports "". The idiom below is
# spec/test_spike_unit_printer_seam.gd's live_chain()/chain_has_source(), copied.
const SSC_EMPEROR_MOD := 'gavstarb-ssc_emperor'
## A line only OUR extension's source carries.
const OUR_PRINTER_MARKER := 'THERMAL DEATH AXE (Leoleth, mw_thermal_death_axe)'
## A line only the resident's source carries: the frame id its full_repair override branches on.
const EMPEROR_PRINTER_MARKER := 'mf_emperor'

func live_printer_chain() -> Array[Script]:
	var chain:Array[Script] = []
	var script:Script = UnitPrinter.get_script()
	while script != null:
		chain.append(script)
		script = script.get_base_script()
	return chain

func printer_chain_has_source(needle:String) -> bool:
	return live_printer_chain().any(func(script:Script) -> bool: return script.source_code.contains(needle))

## Announce the skip rather than passing quietly - the pairing every guarded case in this file uses.
func skipped_without_emperor_printer() -> bool:
	if printer_chain_has_source(EMPEROR_PRINTER_MARKER): return false
	var message := 'SKIPPED: %s is not resident, so the unit_printer seam is unmeasured against a co-extender. Restore the residency set with restore-links.ps1.' % SSC_EMPEROR_MOD
	gut.p(message)
	pass_test(message)
	return true

func test_the_empty_axe_is_still_destructible_with_the_emperor_extender_in_the_chain() -> void:
	if skipped_without_emperor_printer(): return
	assert_true(printer_chain_has_source(OUR_PRINTER_MARKER), 'LIVENESS: ours is in the same chain.')
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	var axe:GearCore = LeolethFixture.arm_axe(leoleth)
	assert_true(GearCore.is_valid(axe), 'fixture: the axe is equipped.')
	axe.charges_current = 0
	assert_true(UnitPrinter.get_destructable_gear([axe]).has(axe),
		'THE RULING: super-first whitelists compose - the empty axe is offered with the resident co-extending the file.')

## Naga SP3 (design ruling 14) put a SECOND id on the same whitelist - Binding Fangs, whose card says
## the axe's sentence word for word. Same override, same chain, so the same ruling; pinned by name so
## a whitelist that ever loses the Fangs goes red here as well as in test_binding_fangs.gd.
func test_the_empty_binding_fangs_are_destructible_with_the_emperor_extender_in_the_chain() -> void:
	if skipped_without_emperor_printer(): return
	var naga:Unit = NagaFixture.create_naga(game, LEOLETH_TILE)
	var fangs:GearCore = NagaFixture.equip(naga, &'mw_binding_fangs')
	assert_true(GearCore.is_valid(fangs), 'fixture: the Fangs are equipped.')
	if not GearCore.is_valid(fangs): return
	fangs.charges_current = 0
	assert_false(fangs.has_charges_left(), 'fixture: and empty.')
	assert_true(UnitPrinter.get_destructable_gear([fangs]).has(fangs),
		'THE RULING, extended: the empty Fangs are offered with the resident co-extending the file.')

## The other half of "compose": the resident's own override still runs under ours. Read structurally,
## because its effect (an mf_emperor health correction) needs an Emperor and a pilot to show.
func test_both_extensions_are_in_one_chain_and_vanilla_is_its_root() -> void:
	if skipped_without_emperor_printer(): return
	assert_true(printer_chain_has_source(OUR_PRINTER_MARKER), 'Ours is in the chain...')
	assert_true(printer_chain_has_source(EMPEROR_PRINTER_MARKER), '...the resident is in the same chain...')
	# THE YEAR IS DELIBERATELY NOT MATCHED: every modkit release re-stamps the per-file copyright line,
	# so baking 2026 in would turn this into a release-day red that says nothing about the seam.
	var root_header:String = live_printer_chain().back().source_code.get_slice('\n', 0)
	assert_true(root_header.begins_with('# Copyright (c) ') and root_header.contains('Wickworks'),
		'...and vanilla is its root, so every super() call still lands (%d scripts deep).' % live_printer_chain().size())

# ------------------------------------------------- and a co-extender of the SAME FUNCTION
# The Emperor cases above put a second extension on the FILE; this one puts a second extension on the
# FUNCTION. Reag-ThyHubris' unit_printer.gd_ext.gd whitelists mw_injector_drill in its own
# get_destructable_gear override, super-first and by kit id, exactly as ours whitelists the axe
# (unpacked/Reag-ThyHubris/res/engine/character/unit/service/unit_printer.gd_ext.gd:27-35). Both mods
# load in every testkit run, so the composition is measurable here and nowhere else.
#
# THIS IS THE RULING, not an accident of install order: each override calls super() FIRST and then
# APPENDS its own kit to whatever came back, so the two whitelists union whichever mod ModLoader
# installed first. The negative control is one test up - mw_stub_cannon, which neither mod
# whitelists, stays refused (spec/test_thermal_death_axe.gd's vanilla-limited case).
const THY_HUBRIS_MOD := 'Reag-ThyHubris'
## The Draugr's weapon, whose card says the same thing ours does: destructible with no charges left.
const INJECTOR_DRILL := &'mw_injector_drill'

func skipped_without_the_drill() -> bool:
	if ContentLibrary.get_kit(INJECTOR_DRILL) != null: return false
	var message := 'SKIPPED: %s is not loaded, so the get_destructable_gear whitelist is unmeasured against a same-function co-extender.' % THY_HUBRIS_MOD
	gut.p(message)
	pass_test(message)
	return true

func test_two_mods_whitelisting_the_same_function_compose_rather_than_cancel() -> void:
	if skipped_without_the_drill(): return
	var leoleth:Unit = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	var axe:GearCore = LeolethFixture.arm_axe(leoleth)
	var drill:GearCore = LeolethFixture.equip(leoleth, INJECTOR_DRILL)
	assert_true(GearCore.is_valid(axe), 'fixture: the axe is equipped.')
	assert_true(GearCore.is_valid(drill), 'fixture: and so is the other mod\'s drill.')
	if not (GearCore.is_valid(axe) and GearCore.is_valid(drill)): return
	axe.charges_current = 0
	drill.charges_current = 0
	assert_false(axe.has_charges_left(), 'fixture: both are empty...')
	assert_false(drill.has_charges_left(), '...which is the only state either whitelist is for.')
	assert_eq(UnitPrinter.get_destructable_gear([axe, drill]).size(), 2,
		'THE RULING: super-first whitelists UNION - both mods\' weapons are offered in one run.')


# ===================== THE OVERSHIELD SEAM (Naga, Shimmering Veil) =====================
# The resident gavstarb-ssc_emperor extends event_unit_overshield.gd (super-calling: it fires an
# invented &"overshield_emperor" trigger at PRE and POST and adds an optional `boolean` context
# prop). Ruled at the Naga's design (its Contested seams line): both of our grants - the core
# passive's "gain 1 OVERSHIELD" and the Shimmering Blade's "Gain 2 Overshield" (SP2) - go through the
# frozen Overshield.grant, which fires the vanilla event the resident extends ADDITIVELY; its trigger
# is noise to us and ours is unchanged by it. This pins that with the resident live, a grant still
# lands the number. Identified by SOURCE in the live script chain, the unit_printer idiom above.
const EMPEROR_OVERSHIELD_MARKER := 'overshield_emperor'
const OVERSHIELD_EVENT_SCRIPT := 'res://content/events/event_unit_overshield.gd'

func live_overshield_chain() -> Array[Script]:
	var chain:Array[Script] = []
	var script:Script = load(OVERSHIELD_EVENT_SCRIPT)
	while script != null:
		chain.append(script)
		script = script.get_base_script()
	return chain

func skipped_without_emperor_overshield() -> bool:
	if live_overshield_chain().any(func(script:Script) -> bool: return script.source_code.contains(EMPEROR_OVERSHIELD_MARKER)):
		return false
	var message := 'SKIPPED: %s is not resident, so the overshield seam is unmeasured against its extender. Restore the residency set with restore-links.ps1.' % SSC_EMPEROR_MOD
	gut.p(message)
	pass_test(message)
	return true

func test_an_overshield_grant_still_lands_the_number_with_the_emperor_extender_live() -> void:
	if skipped_without_emperor_overshield(): return
	var game:Gamemaster = LeolethFixture.create_game(self)
	var unit:Unit = LeolethFixture.create_ally(game, Vector2i(4, 4))
	assert_eq(Overshield.current(unit), 0, 'fixture: none to start.')
	await Overshield.grant(SpecFactory.dummy_event({unit = unit}), unit, 1)
	assert_eq(Overshield.current(unit), 1, 'THE RULING: a grant of 1 under the resident reads 1 - additive extension, no interference.')
	await Overshield.grant(SpecFactory.dummy_event({unit = unit}), unit, 2)
	assert_eq(Overshield.current(unit), 2, 'And the engine max semantics survive it too.')


# ===================== THE TELEPORT SEAM (Purple Thorn, Vigil) =====================
# Ruled at the Purple Thorn's design (its Contested seams line): teleport is contested by no
# resident (talents ADDS sources only), and the resident Orator's rank-3 Demoralize returns an
# EMPTY allowed set for every movement type - so under that lockdown the Thorn's own two teleports
# (Vigil, Shimmer), which take the PREVENTABLE route on purpose (rulings 3 and 15), offer nothing.
# Recorded, not fought: the cards say "may teleport", never "cannot be prevented". This pins the
# mechanism that ruling rides on - a MOVEMENT_RESTRICTION ban stops a Vigil teleport - against
# VANILLA's Interdiction Field, the same channel a resident's ban would use, so a resident update
# that changes how bans compose with Pathfinder.create goes red here.
#
# NO RESIDENT IS NEEDED FOR THIS ONE, so it never skips. The field is the Minotaur's
# buff_interdiction_field hung straight on the HOSTILE (its check_if_passive_applies asks only for a
# teleporting movement type and an ENEMY mover, buff_interdiction_field.gd:16-21); the Thorn at 2
# from it is inside FIELD_SIZE 3, which is the total lockdown branch (:29-33).
const PURPLE_THORN_TILE := Vector2i(4, 6)
const THORN_TARGET_TILE := Vector2i(6, 6) # 2 east: inside the field, inside the Nexus's range
const INTERDICTION_FIELD := &'buff_interdiction_field'

func test_a_vigil_teleport_is_stopped_by_a_movement_restriction_ban() -> void:
	var pair := PurpleThornFixture.create_game_with_prompt_queues(self)
	var thorn_game:Gamemaster = pair[0]
	var responder = pair[1]
	var watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	var thorn:Unit = PurpleThornFixture.create_thorn(thorn_game, PURPLE_THORN_TILE)
	var hostile:Unit = PurpleThornFixture.create_hostile(thorn_game, THORN_TARGET_TILE)
	# THE RIFLE, NOT AN AUX: an Aux hit offers Blessed Bolt, and this file's before_each already
	# installed the STOCK responder (which answers yes) on the shared gamemaster beside the queued one
	# - measured on this pin's first run, where the Nexus landed 6. A Main hit wakes only Vigil.
	PurpleThornFixture.arm_rifle(thorn)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), hostile, INTERDICTION_FIELD)
	assert_true(UnitCondition.has_buff(hostile, INTERDICTION_FIELD), 'fixture: the field is up.')
	responder.chosen_move_tile = Vector2i(3, 6)
	PurpleThornFixture.queue([19, 4, 1])
	await PurpleThornFixture.shoot(thorn_game, thorn, hostile, PurpleThornFixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'fixture: the hit landed, so Vigil had its trigger.')
	assert_eq(watcher.kinds(&'move_tile').size(), 0,
		'THE RULING: under a MOVEMENT_RESTRICTION ban the reticle is not even raised - the preventable route.')
	assert_eq(thorn.tile(), PURPLE_THORN_TILE, 'The Thorn stayed.')
	assert_eq(PurpleThornFixture.uses_this_round(thorn, PurpleThornFixture.VIGIL_ID, PurpleThornFixture.VIGIL_ACTION_ID), 0,
		'And nothing was spent.')
	Dice.CHEAT_ROLL_QUEUE.clear()


# ===================== THE HAZARD: FOUR "ADJACENT" CLAUSES, RULED TWO WAYS =====================
#
# Ruled at the Hazard's design (its Contested seams line; author): ask where the engine measures.
# The two AURAS (Weight of Fire, DONT GIVE UP THE MECH's immunity) measure distance_between against
# aura_range and IGNORE House Guard - the Fungal Network and Gravity Well position. The two HELPER
# callers (Shield Wall's pick through adjacent_characters, Supporting Fire's trigger through
# is_adjacent) TAKE it - the Sluagh position. Direction follows the engine: the widening is read off
# the HAZARD's buffs, so each pin puts it there. Every pin has its control inside it (the same ally
# at the same tile, before and after the widening, or a genuinely adjacent one beside it).
const HAZARD_TILE := Vector2i(4, 8)
const HAZARD_ADJACENT := Vector2i(5, 8) # 1 out
const HAZARD_TWO_OUT := Vector2i(6, 8)  # 2 out - the tile House Guard's widening pulls into "adjacent"

func make_hazard_game() -> Array:
	var hazard_game:Gamemaster = HazardFixture.create_game(self)
	var hazard:Unit = HazardFixture.create_hazard(hazard_game, HAZARD_TILE, 4)
	return [hazard_game, hazard]

func test_house_guard_does_not_widen_weight_of_fire() -> void:
	if skipped_without_talents(): return
	var pair := make_hazard_game()
	var hazard_game:Gamemaster = pair[0]
	var hazard:Unit = pair[1]
	var near_ally := HazardFixture.create_ally(hazard_game, HAZARD_ADJACENT)
	var far_ally := HazardFixture.create_ally(hazard_game, HAZARD_TWO_OUT)
	widen_adjacency_on(hazard)
	UnitTile.update_tracking_and_statuses(hazard_game.map)
	assert_true(UnitRelation.is_adjacent(hazard, far_ally), 'LIVENESS: the widening is live for this ally.')
	assert_false(UnitCondition.has_buff(far_ally, HazardFixture.WOF_BUFF),
		'RULED: the widened ally gets no Weight of Fire - the aura measures distance.')
	assert_true(UnitCondition.has_buff(near_ally, HazardFixture.WOF_BUFF),
		'While a genuinely adjacent one does - so the assertion above is not vacuous.')

func test_house_guard_does_not_widen_the_dgutm_immunity() -> void:
	if skipped_without_talents(): return
	var pair := make_hazard_game()
	var hazard_game:Gamemaster = pair[0]
	var hazard:Unit = pair[1]
	var near_ally := HazardFixture.create_ally(hazard_game, HAZARD_ADJACENT)
	var far_ally := HazardFixture.create_ally(hazard_game, HAZARD_TWO_OUT)
	widen_adjacency_on(hazard)
	# THE SWITCH, NOT THE PRESS: pressing would raise a move reticle for both allies, which this file's
	# stock responder answers by moving them. The seam under test is the aura's range, not the moves.
	var core:GearCore = hazard.get_gear(HazardFixture.CORE_ID)
	SpecFactory.apply_buff(hazard, HazardFixture.DGUTM_ACTIVE, core)
	UnitTile.update_tracking_and_statuses(hazard_game.map)
	assert_true(UnitRelation.is_adjacent(hazard, far_ally), 'LIVENESS: the widening is live for this ally.')
	assert_true(UnitCondition.has_buff(near_ally, HazardFixture.DGUTM_KNOCKBACK),
		'A genuinely adjacent ally is immune - the aura is up.')
	assert_false(UnitCondition.has_buff(far_ally, HazardFixture.DGUTM_KNOCKBACK),
		'RULED: the widened ally is not - the aura measures distance.')

func test_house_guard_on_the_hazard_lets_shield_wall_reach_an_ally_two_tiles_out() -> void:
	if skipped_without_talents(): return
	var pair := make_hazard_game()
	var hazard_game:Gamemaster = pair[0]
	var hazard:Unit = pair[1]
	var far_ally := HazardFixture.create_ally(hazard_game, HAZARD_TWO_OUT)
	# CONTROL: the same turn end without the widening shields nobody.
	await HazardFixture.open_turn(hazard_game, hazard)
	await SpecFactory.end_turn(hazard_game, hazard)
	assert_eq(Overshield.current(far_ally), 0, 'CONTROL: two tiles out is not offered in vanilla.')
	widen_adjacency_on(hazard)
	assert_true(UnitRelation.is_adjacent(hazard, far_ally), 'LIVENESS: the widening is live.')
	await HazardFixture.open_turn(hazard_game, hazard)
	await SpecFactory.end_turn(hazard_game, hazard)
	assert_eq(Overshield.current(far_ally), 1 + 4,
		'RULED: Shield Wall reached the widened ally - 1 + Grit 4 Overshield (the only candidate, so any responder picks it).')

func test_house_guard_on_the_hazard_lets_supporting_fire_trigger_two_tiles_out() -> void:
	if skipped_without_talents(): return
	var pair := make_hazard_game()
	var hazard_game:Gamemaster = pair[0]
	var hazard:Unit = pair[1]
	var far_ally := HazardFixture.create_ally(hazard_game, HAZARD_TWO_OUT)
	# CONTROL: the same turn start without the widening offers nothing - and spends nothing, so the
	# 1/round is still there for the ruled half.
	await SpecFactory.start_turn(hazard_game, far_ally)
	await SpecFactory.end_turn(hazard_game, far_ally)
	assert_false(UnitCondition.has_buff(far_ally, HazardFixture.SF_BUFF), 'CONTROL: not offered in vanilla.')
	widen_adjacency_on(hazard)
	assert_true(UnitRelation.is_adjacent(hazard, far_ally), 'LIVENESS: the widening is live.')
	await SpecFactory.start_turn(hazard_game, far_ally)
	assert_true(UnitCondition.has_buff(far_ally, HazardFixture.SF_BUFF),
		'RULED: Supporting Fire triggered for the widened ally.')
	assert_true(UnitCondition.has_buff(hazard, HazardFixture.SF_COST_BUFF), 'And the Hazard paid.')


# ===================== THE RULING: UNFATHOMABLE WEIGHT'S BURST IS NOT ADJACENCY =====================

## RULING, 2026-09-24, the Shackleton design's `Contested seams:` line (adjacency - IGNORED, by
## geometry). Deferred from SP1 to SP2 with the burst it pins.
##
## Unfathomable Weight's "Burst 1 area around you" is UnitTile.get_aoe_tiles(unit, BURST, 1) -
## AoeCalculator.burst over the footprint - and never UnitRelation.adjacent_characters, which is the
## only thing House Guard overrides. House Guard is also only_to_allies and the card pushes only
## hostiles, so today no unit can be widened INTO this card at all; what this pins is the geometry,
## so that re-implementing the burst through adjacency, or the talents mod widening hostiles, turns
## it red rather than silently pushing units two tiles out.
##
## LIVENESS FIRST, as every pin in this file: an ally two tiles out IS adjacent under the buff.
func test_house_guard_does_not_widen_unfathomable_weights_burst() -> void:
	if skipped_without_talents(): return
	if is_instance_valid(SpecFactory.current_responder):
		SpecFactory.current_responder.choose_yesnos = false
		SpecFactory.current_responder.choose_moves = false
	var made:Array = ShackletonFixture.create_game(self)
	var sgame:Gamemaster = made[0]
	var sresponder = made[1]
	# Size 2 at (5,5) covers (5..6, 5..6); its Burst 1 stops at x = 4 and x = 7.
	var shackleton := ShackletonFixture.create_shackleton(sgame, Vector2i(5, 5))
	var far_ally := ShackletonFixture.create_dummy(sgame, Vector2i(8, 5), -10, Faction.PLAYER)
	var far_hostile := ShackletonFixture.create_dummy(sgame, Vector2i(3, 5))
	var near_hostile := ShackletonFixture.create_dummy(sgame, Vector2i(7, 6))
	var burst_before := UnitTile.get_aoe_tiles(shackleton, Lancer.AOE_TYPE.BURST, 1)
	widen_adjacency_on(shackleton)
	UnitTile.update_tracking_and_statuses(sgame.map)
	assert_true(UnitRelation.adjacent_characters(shackleton).has(far_ally),
		'LIVENESS: House Guard widens adjacency two tiles out.')
	assert_eq(UnitTile.get_aoe_tiles(shackleton, Lancer.AOE_TYPE.BURST, 1), burst_before,
		'RULED: the burst is geometry, untouched by the widening.')

	await ShackletonFixture.open_turn(sgame, shackleton)
	sresponder.yesno_queue.assign([true])
	sresponder.move_tile_queue.assign([Vector2i(9, 6)])
	await SpecFactory.use(sgame, shackleton, ShackletonFixture.CORE_ID, ShackletonFixture.WEIGHT_ID)
	assert_eq(near_hostile.tile(), Vector2i(9, 6), 'A hostile inside the burst is pushed - the press ran.')
	assert_eq(far_hostile.tile(), Vector2i(3, 5), 'RULED: one two tiles out is not.')
	assert_eq(far_ally.tile(), Vector2i(8, 5), 'Nor the widened ally.')


# ===================== GLOIRE (SP1): THE KNOCKBACK-DIRECTION SEAM, OURS =====================

## The one seam the Gloire's design found REACHED is our own: the Shackleton's
## common_action_util.gd_ext.gd overrides generate_knockback_events for every push on the map, and
## every push the Gloire inflicts - the Ram's Knockback 1 here, a Panic Breaker under RPA Pullback at
## SP2 - goes through it. The override acts only when the KNOCKER wears mt_spatial_rerouting, so the
## Gloire's pushes keep vanilla's away-cone (design, Contested seams). What this pins is that reading:
## a Gloire Ram from Extended Zone Control's Range 3 offers the cone, never every direction. A later
## widening of the extender's gate (say, to "any IPS-N frame") turns this red instead of silently
## handing the Gloire the Shackleton's trait.
##
## LIVENESS FIRST, as every pin in this file: the live CommonActionUtil node carries the extension.
func test_the_gloires_ram_keeps_vanillas_knockback_cone_with_the_rerouting_extender_live() -> void:
	var script:Script = CommonActionUtil.get_script()
	var found := false
	while script != null:
		if script.source_code.contains('SPATIAL_REROUTING'): found = true
		script = script.get_base_script()
	assert_true(found, 'LIVENESS: the CommonActionUtil node carries the Shackleton\'s extension in its chain.')
	if is_instance_valid(SpecFactory.current_responder):
		SpecFactory.current_responder.choose_yesnos = false
		SpecFactory.current_responder.choose_moves = false
	var made:Array = GloireFixture.create_game(self)
	var ggame:Gamemaster = made[0]
	var gwatcher = made[2]
	# Size 2 at (4,4) covers (4..5, 4..5); the hostile at (8,4) is 3 from the east edge - a Ram only
	# Extended Zone Control can reach, so the pin is on the Gloire's own reach.
	var gloire := GloireFixture.create_gloire(ggame, Vector2i(4, 4))
	var hostile := GloireFixture.create_dummy(ggame, Vector2i(8, 4))
	var before:int = gwatcher.prompts.size()
	await GloireFixture.ram(ggame, gloire, hostile)
	var pools:Array = GloireFixture.offered_pools(gwatcher, before)
	assert_eq(pools.size(), 1, 'the Ram hit from three away: one knockback reticle was offered.')
	if pools.size() != 1: return
	var pool:Array = pools[0]
	assert_has(pool, Vector2i(9, 4), 'RULED: the push is offered away from the Gloire,')
	assert_does_not_have(pool, Vector2i(7, 4), 'and never back toward it - vanilla\'s cone, not the Shackleton\'s every-direction offer.')
	assert_false(GearCore.is_valid(gloire.get_gear(&'mt_spatial_rerouting')), 'fixture: the Gloire does not wear Spatial Rerouting.')


# ===================== THE GRUTTE PIER (SP2) - attack-roll modification, Reliable =====================

## House Guard's Shield of the Legion (talents mod, rank 3) reads "anything modifying the total" as
## total - (base + accuracy + flat) (action_shield_of_the_legion_miss.gd:83). Patience in All Things
## lowers the total AND the d20 together (buff_patience_reduce.lower), so that difference - and with it
## House Guard's would-have-hit arithmetic - is unchanged by a spend. RULED: composes.
##
## Two halves: the talents mod still computes other_bonus that way (reddened by a talents update that
## changes the formula), and our lowering leaves it where it was (reddened by lowering one without the
## other).
const HOUSE_GUARD_MISS_PATH := 'res://unpacked/gavstarb-talents_1st_party/res/content/talents/support/t_house_guard/rank_3/action_shield_of_the_legion_miss.gd'
const HOUSE_GUARD_OTHER_BONUS := 'attack_roll.total_roll - (attack_roll.base_roll + attack_roll.accuracy_roll + attack_roll.pre.flat_bonus)'

func test_patience_leaves_house_guards_other_bonus_where_it_was() -> void:
	if not ResourceLoader.exists(HOUSE_GUARD_MISS_PATH):
		fail_test('%s is resident and must be loaded - restore it with restore-links.ps1.' % TALENTS_MOD)
		return
	var source:String = load(HOUSE_GUARD_MISS_PATH).source_code
	assert_string_contains(source, HOUSE_GUARD_OTHER_BONUS, 'House Guard still reads a modified total this way.')
	var roll := AttackRoll.create(myconid, AttackRoll.PreAttack.new())
	roll.base_roll = 11
	roll.accuracy_roll = 1
	roll.pre.flat_bonus = 2
	roll.total_roll = 16 # 2 more than base + accuracy + flat: something else already modified it
	var other_bonus := roll.total_roll - (roll.base_roll + roll.accuracy_roll + roll.pre.flat_bonus)
	PatienceReduce.lower(roll, 3)
	assert_eq(roll.total_roll, 13, 'fixture: the number rolled is 3 lower.')
	assert_eq(roll.total_roll - (roll.base_roll + roll.accuracy_roll + roll.pre.flat_bonus), other_bonus,
		'RULED: House Guard sees the same other_bonus after a Patience spend.')

## Zwarte Hoop's +Reliable goes through native_reliable.raise, the same carrier as Weight of Fire, so
## it and the Clark's Redundant Scattering Module (resident since 2026-09-24) add and both come off
## the shared rifle export - test_native_reliable.gd pins the carrier's two orders; this pins that the
## Grutte Pier's loop really uses it. RULED: composes.
const CLARK_ID := 'fateofman-ipsn_clark'
const CLARK_MOD := &'wm_redundant_scattering_module'

func test_zwarte_hoops_reliable_and_the_clarks_module_add_and_both_come_off() -> void:
	if ContentLibrary.get_kit(CLARK_MOD) == null:
		fail_test('%s is resident and must be loaded - restore it with restore-links.ps1.' % CLARK_ID)
		return
	# before_each's stock responder would answer the loop's prompts AND the variant request a second
	# time ("Attempted to execute an event that is already in progress"); it has no switch for the
	# latter, so it goes, and the Grutte Pier game's own queue-driven responder answers alone.
	if is_instance_valid(SpecFactory.current_responder):
		SpecFactory.current_responder.queue_free()
		await get_tree().process_frame
	var made:Array = GruttePierFixture.create_game_with_prompts(self)
	var pgame:Gamemaster = made[0]
	var responder = made[1]
	var pier := GruttePierFixture.create_pier(pgame, Vector2i(2, 5))
	var target := GruttePierFixture.create_dummy(pgame, Vector2i(5, 5), 30) # every roll misses
	GruttePierFixture.equip(pier, GruttePierFixture.RIFLE)
	assert_not_null(pier.core.loadout.equip_weapon_mod(CLARK_MOD, pier.get_gear(GruttePierFixture.RIFLE)), 'fixture: the Clark module fits the rifle.')
	SpecFactory.apply_passive_buffs(pier)
	await GruttePierFixture.open_turn(pgame, pier)
	GruttePierFixture.set_charges(pier, 2)
	responder.multiple_choice_queue.assign([0, 0]) # +1 Reliable, twice
	var before := target.core.current.health
	await GruttePierFixture.attack(pgame, pier, target, GruttePierFixture.RIFLE, [2])
	assert_eq(before - target.core.current.health, 5, 'A miss: 2 printed + 2 Zwarte Hoop + 1 (the Clark, one damage die).')
	var action:ActionAttackWeapon = ContentLibrary.get_kit(GruttePierFixture.RIFLE).actions[0]
	assert_eq(action.reliable_damage, '2', 'The shared rifle reads its printed Reliable 2 afterwards.')


# ===================== KOREMASA: RIDING MEASURES A RADIUS (design ruling 11) =====================

## RULING, 2026-09-25 (Koremasa design, ruling 11): Lassissian Folly and begin-riding measure
## "adjacent" as a RADIUS, distance_between <= 1 (UnitRelation.get_units_within), and IGNORE House
## Guard's widening - the card describes a physical climb into the mount's space.
##
## WHY THE ALLY IS HERE. House Guard's rank-1 buff is only_to_allies (see
## test_house_guard_does_not_widen_the_leaps_adjacent_pick), so it can never pull a HOSTILE into
## adjacent_characters - and a mount is always hostile. Asserting "the hostile two tiles out is not
## a mount" alone would therefore pass even if our code read is_adjacent. The ally two tiles out is
## the proof the widening is LIVE on this Koremasa at the moment of the check; the hostile is the
## ruling. Recorded plainly: for this card the widening cannot reach a mount by either route.
const KOREMASA_TILE := Vector2i(10, 2)
const KOREMASA_MOUNT_FAR := Vector2i(12, 2)  # size 2, (12,2)..(13,3): 2 from the Koremasa
const KOREMASA_MOUNT_NEAR := Vector2i(11, 3) # size 2, (11,3)..(12,4): 1 from the Koremasa (the same mount, moved)
const KOREMASA_ALLY := Vector2i(10, 4)       # 2 from the Koremasa

func test_house_guard_does_not_widen_the_koremasas_reach_to_a_mount() -> void:
	if skipped_without_talents(): return
	var koremasa := KoremasaFixture.create_koremasa(game, KOREMASA_TILE)
	var far_mount := KoremasaFixture.create_mount(game, KOREMASA_MOUNT_FAR)
	var far_ally := KoremasaFixture.create_ally(game, KOREMASA_ALLY)
	KoremasaFixture.core(koremasa).wake_action(KoremasaFixture.BEGIN_RIDING_ACTION)
	await KoremasaFixture.open_turn(game, koremasa)
	var begin := KoremasaFixture.specific(koremasa, KoremasaFixture.BEGIN_RIDING_ACTION)

	assert_eq(UnitRelation.distance_between(koremasa, far_mount), 2, 'fixture: the mount is two tiles out.')
	assert_false(UnitAction.can_activate_gear(begin), 'CONTROL: two tiles out is no mount before the buff.')

	widen_adjacency_on(koremasa)
	assert_true(UnitRelation.adjacent_characters(koremasa).has(far_ally),
		'VACUITY: House Guard is live on the Koremasa - the ally two tiles out now counts as adjacent.')
	assert_false(UnitAction.can_activate_gear(begin), 'RULED: begin-riding still does not reach two tiles out.')

	UnitTile.move_to(far_mount, KOREMASA_MOUNT_NEAR)
	UnitTile.update_tracking_and_statuses(game.map)
	assert_eq(UnitRelation.distance_between(koremasa, far_mount), 1, 'fixture: the mount stepped in.')
	assert_true(UnitAction.can_activate_gear(begin), 'A mount genuinely one tile out is still offered with the widening on.')

# ---------------------------------------------------------------- the Scan action (Rakshasa, Ensorcel)

## The talents mod's Scan extension (resident): after vanilla's activate it rewrites context.target_unit
## to whatever run_system_fxgs was handed. Registry row: "The Scan action".

## The member only the resident's extension declares.
const TALENTS_SCAN_MEMBER := 'target_unit_orator'

## True when the live Scan action is running under talents' extension: some script in its chain
## declares the resident's member. ModLoader's extension takes over the vanilla path, so the path
## cannot tell. Announced, never silent.
func skipped_without_talents_scan() -> bool:
	var scan_kit:Kit = ContentLibrary.get_kit(RakshasaFixture.SCAN)
	var script:Script = scan_kit.actions.front().get_script() if scan_kit != null and not scan_kit.actions.is_empty() else null
	while script != null:
		if script.source_code.contains(TALENTS_SCAN_MEMBER): return false
		script = script.get_base_script()
	var message := 'SKIPPED: %s is not resident, so its Scan extension is unmeasured here. Restore the residency set with restore-links.ps1.' % TALENTS_MOD
	gut.p(message)
	pass_test(message)
	return true

## THE RULING (design 3.2, ruling 20): Ensorcel is a VARIANT of Scan that swaps in our own action, so
## talents' extension keeps running on the plain Scan and never sees the replacement. With the resident
## live: the variant is still offered, and the blank variant still scans.
func test_ensorcel_is_still_offered_and_plain_scan_still_scans_with_the_talents_mod_resident() -> void:
	if skipped_without_talents_scan(): return
	var rakshasa := RakshasaFixture.create_rakshasa(game, Vector2i(1, 1))
	var hostile := RakshasaFixture.create_hostile(game, Vector2i(1, 3))
	# Turn first: the chip is START_OF_TURN, so a turn start would strip one applied before it.
	await RakshasaFixture.open_turn(game, rakshasa)
	SpecFactory.apply_buff(rakshasa, RakshasaFixture.MODE_CHIPS[RakshasaFixture.MODE.ENSORCEL],
		rakshasa.get_gear(RakshasaFixture.CORE_ID))
	var scan_gear:GearCore = rakshasa.get_gear(RakshasaFixture.SCAN)
	var scan:Action = scan_gear.get_solo_action()
	assert_eq(scan.get_alternate_actions(SpecificAction.create(rakshasa, scan_gear, scan)).size(), 1,
		'RULED: the Ensorcel variant is offered on the resident-extended Scan.')
	assert_true(Scanpedia.is_anything_unscanned(hostile), 'fixture: something to learn.')
	await SpecFactory.use_solo(game, rakshasa, RakshasaFixture.SCAN, hostile)
	assert_false(Scanpedia.is_anything_unscanned(hostile), 'RULED: the blank variant still scans under the resident.')

# ---------------------------------------------------------------- the declared attack's targets (Lovers Knot, Gemini Charge)

## Registry row "The declared attack's targets": Gemini Charge WRITES DeclaredAttackSummary.all_attacked_units
## at ATTACK_DECLARED PRE; the talents mod's NOAH ward (resident, action_diluvian_ark_ward.gd_ext.gd)
## READS it at the same timing. THE RULING (design, Contested seams): Gemini runs at an EARLY priority,
## so a PRE reader later in the block sees the appended target. The ward's TRIGGER gate is evaluated
## before any block runs, so it fires for the contact; its ACTIVATE then protects every adjacent ally
## in the list - the redirected one included.
##
## NOT PINNED HERE, AND WHY: the Emperor's Sovereign Presence and Field Analyst's Information Handling
## both read only their HOLDER's own attack (context.unit == unit), so neither ever reads a Lovers
## Knot's summary unless the Knot's own pilot is the reader - and Field Analyst reads at POST, after
## every PRE, which test_gemini_charge.gd's POST recorder already pins.
const KNOT_TILE := Vector2i(8, 2)
const KNOT_CONTACT := Vector2i(11, 2)
const KNOT_WARD := Vector2i(12, 1) # adjacent to both the contact and the redirected target
const KNOT_SECOND := Vector2i(13, 2)
const NOAH := &'ms_noah_class_nhp'

func test_the_noah_ward_protects_the_redirected_target_because_gemini_appends_first() -> void:
	var knot := LoversKnotFixture.create_knot(game, KNOT_TILE)
	LoversKnotFixture.equip(knot, LoversKnotFixture.RANGED)
	var contact := LoversKnotFixture.create_dummy(game, KNOT_CONTACT)
	var second := LoversKnotFixture.create_dummy(game, KNOT_SECOND)
	var ward := LoversKnotFixture.create_dummy(game, KNOT_WARD)
	var noah := LoversKnotFixture.equip(ward, NOAH)
	SpecFactory.apply_buff(ward, &'buff_diluvian_ark', noah)
	var recorder := KnotDeclaredRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), knot, recorder)
	await LoversKnotFixture.open_turn(game, knot)

	Dice.CHEAT_ROLL_QUEUE.clear()
	# the ward's d6 (4+ protects), then a d20 that would hit anyone who is not protected
	Dice.cheat_attack([6, 14], [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])
	SpecFactory.current_responder.chosen_plan_queue.assign([CompconPlan.create([second.tile()], [], [second])])
	await SpecFactory.use_solo(game, knot, LoversKnotFixture.RANGED, [contact])

	assert_eq(LoversKnotFixture.gemini_uses(knot), 1, 'VACUITY: the shot was redirected.')
	var contact_roll := knot_roll_against(recorder, contact)
	var second_roll := knot_roll_against(recorder, second)
	assert_not_null(contact_roll, 'The contact was rolled against.')
	assert_not_null(second_roll, 'The redirected target was rolled against.')
	if contact_roll == null or second_roll == null: return
	assert_false(contact_roll.hit, 'VACUITY: the ward triggered - the contact was auto-missed.')
	assert_false(second_roll.hit, 'RULED: the ward protected the APPENDED ally too - it ran after Gemini.')
	assert_eq(second_roll.base_roll, 0, 'An auto-miss, not a rolled miss.')

## Keeps every ATTACK_DECLARED POST summary its holder makes: the rolls outlive the attack only here.
class KnotDeclaredRecorder extends Buff:
	var summaries:Array[DeclaredAttackSummary] = []
	func _init() -> void:
		compcon_id = &'buff_spec_compat_knot_recorder'
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		hide_from_player = true
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]
	func triggers_on_event(_core:BuffCore, unit:Unit, triggering:EventCore) -> bool:
		return triggering.context.unit.get_attacker(triggering.context) == unit
	func activate(_core:BuffCore, activation:EventCore) -> void:
		summaries.append(activation.context.event.context.resource)

func knot_roll_against(recorder:KnotDeclaredRecorder, target:Unit) -> AttackRoll:
	if recorder.summaries.is_empty(): return null
	for roll:AttackRoll in recorder.summaries.back().attack_rolls:
		if roll.target_unit == target: return roll
	return null


# ===================== SIX SKY x THE SUNZI'S BLINK ANCHOR (design 2.3, the teleport seam) =====================

const SUNZI_REDIRECT_KIT := &'cp_reality_carver_sunzi'
const SIX_SKY_START := Vector2i(4, 5)
## Where the Six Sky asks the Ritual to put it: 6 from the anchor spot's hostile, so a Ritual fired
## from HERE would attack nobody.
const RITUAL_ASKED := Vector2i(12, 5)
const SUNZI_TILE := Vector2i(20, 5)
## Adjacent to the allied Sunzi: where its Blink Anchor redirect puts the teleporting ally.
const ANCHOR_SPOT := Vector2i(21, 5)
## 2 from the anchor spot, 11 from where the Six Sky asked to land.
const NEAR_ANCHOR := Vector2i(23, 5)

func skipped_without_the_sunzi() -> bool:
	if Kit.is_valid(ContentLibrary.get_kit(SUNZI_REDIRECT_KIT)): return false
	var message := 'SKIPPED: %s is not resident, so there is no Blink Anchor to redirect the Ritual. Restore the residency set with restore-links.ps1.' % SixSkyFixture.SUNZI_MOD
	gut.p(message)
	pass_test(message)
	return true

## THE RULING (design Contested seams, "teleport"): our observers read at POST, from where the unit
## ACTUALLY landed, and our performers use the helper's routes, which a Sunzi anchor may redirect like
## any other teleport. So an allied Sunzi's Blink Anchor may pull the Ritual's teleport to its side:
## Heavenly Weaver still arms (the teleport was the Six Sky's own), and the Ritual's target list is
## taken from the space the Six Sky really occupies - the anchor's.
##
## Reddened by: the Sunzi's redirect moving off ENTIRE_MOVEMENT PRE or dropping the array rewrite, the
## Ritual measuring its targets from the space it asked for rather than the one it reached, or the
## Weaver's agent losing the forcer across the rewrite.
func test_a_sunzi_blink_anchor_redirects_the_rituals_teleport_and_the_ritual_follows() -> void:
	if skipped_without_the_sunzi(): return
	if is_instance_valid(SpecFactory.current_responder):
		SpecFactory.current_responder.choose_yesnos = false
		SpecFactory.current_responder.choose_plans = false
		SpecFactory.current_responder.choose_moves = false
		SpecFactory.current_responder.choose_multiple_choices = false
	var made:Array = SixSkyFixture.create_game_with_prompts(self, Vector2i(30, 10))
	game = made[0]
	var responder = made[1]
	var watcher:PromptWatcher = add_child_autoqfree(PromptWatcher.new())

	var six_sky := SixSkyFixture.create_six_sky(game, SIX_SKY_START)
	var sunzi := SixSkyFixture.create_ally(game, SUNZI_TILE)
	var kit:Kit = ContentLibrary.get_kit(SUNZI_REDIRECT_KIT)
	sunzi.core.loadout.equipped_kits.append(kit)
	sunzi.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	var hostile := SixSkyFixture.create_dummy(game, NEAR_ANCHOR)

	# The Ritual's picker asks first (RITUAL_ASKED); the anchor's own picker second (ANCHOR_SPOT).
	responder.chosen_yesnos = false
	responder.yesno_queue.assign([true]) # the anchor's "use it?"
	responder.chosen_move_tile = RITUAL_ASKED
	var move_prompts := [0]
	watcher.prompt.connect(func(kind:StringName, _info:Dictionary) -> void:
		if kind != PromptWatcher.KIND.move_tile: return
		move_prompts[0] += 1
		if move_prompts[0] == 2: responder.chosen_move_tile = ANCHOR_SPOT)

	await SixSkyFixture.press_ritual(game, six_sky, [15, 1, 20, 6, 6, 6]) # d20, accuracy, save, hit, crit, Weaver
	responder.chosen_move_tile = Tile.INVALID

	assert_eq(move_prompts[0], 2, 'VACUITY: the anchor offered its own picker after the Ritual.')
	assert_eq(six_sky.tile(), ANCHOR_SPOT, 'The anchor pulled the Six Sky to its side.')
	assert_eq(SixSkyFixture.weaver_chips(six_sky), 0, 'RULED: the Weaver armed, and the first hit spent it...')
	assert_eq(200 - SixSkyFixture.health(hostile), 15, '...on the hostile beside the ANCHOR: 9 + the Weaver 6.')
