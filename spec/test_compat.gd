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

var game:Gamemaster
var myconid:Unit


func before_each() -> void:
	game = MyconidFixture.create_game(self)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)


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

	# ITS OWN GAME, AND ITS OWN RESPONDER. Pressing Step opens TWO yes/no prompts in one awaited call -
	# its own confirm, then Uncertainty Field's offer to fade instead - and the stock responder answers
	# both with one value, which makes the field eat every teleport (maidens_blush_fixture.gd's
	# header). before_each already installed the stock responder for the Myconid cases above, and two
	# live responders would both answer every request, so that one is silenced rather than removed:
	# its guard clauses return before they count a choice (spec_factory.gd:446, :509).
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
