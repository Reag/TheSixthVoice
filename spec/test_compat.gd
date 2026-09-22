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

## The other half of "compose": the resident's own override still runs under ours. Read structurally,
## because its effect (an mf_emperor health correction) needs an Emperor and a pilot to show.
func test_both_extensions_are_in_one_chain_and_vanilla_is_its_root() -> void:
	if skipped_without_emperor_printer(): return
	assert_true(printer_chain_has_source(OUR_PRINTER_MARKER), 'Ours is in the chain...')
	assert_true(printer_chain_has_source(EMPEROR_PRINTER_MARKER), '...the resident is in the same chain...')
	assert_true(live_printer_chain().back().source_code.begins_with('# Copyright (c) 2026 Wickworks'),
		'...and vanilla is its root, so every super() call still lands (%d scripts deep).' % live_printer_chain().size())
