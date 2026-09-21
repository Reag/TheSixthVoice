# THE MORRÍGAN-CLASS NHP and IN TRIUMVIRATE (Sluagh rank III, SP4). Design section 4.2, ruling 23;
# spike specs/2026-09-20-adjacency-override-feasibility.md.
#
#   "AI, UNIQUE, HEAT SELF 2, 3 SP. Your mech gains the AI tag and the In Triumvirate quick tech
#    action. In Triumvirate (Quick Tech): Choose an allied character within Sensors. Until the end
#    of your next turn, your chosen ally is always treated as being adjacent to you while within
#    your Sensors, regardless of actual distance between you, and all attacks against them gain
#    +1 difficulty."
#
# THE SEAM. "Treated as being adjacent" is a fourth banner in this mod's unit_relation.gd_ext.gd: an
# adjacent_characters override, super first, that appends the partner named by a
# `reag_adjacent_to` buff while the OWNER's live Sensors still reach. is_adjacent(a, b) is
# adjacent_characters(a).has(b) (unit_relation.gd:7-8) - ONE-SIDED - so the action puts a pair buff
# on EACH end. Every reader that asks is_adjacent / adjacent_characters through the node sees the
# pair (Task 5 measures which); nothing that measures a radius does.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_in_triumvirate.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
## SP4 Task 5. The shared helper every Overshield read in this mod goes through - the same preload
## test_astral_guardian.gd and test_mark_retort.gd carry, for the one case below that reads a grant.
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

# (No OUR_TRANSLATION const here yet: SP4 Task 6 adds the card rows and the test that reads them.)

const SLUAGH_TILE := Vector2i(4, 6)
const NEAR_ALLY_TILE := Vector2i(10, 6)   # 6 from the Sluagh: not adjacent, inside Sensors 10
const EDGE_ALLY_TILE := Vector2i(15, 6)   # 11: one past Sensors 10, inside 11
const OTHER_ALLY_TILE := Vector2i(4, 9)   # 3
const HOSTILE_TILE := Vector2i(10, 9)     # 3 from the near ally, inside the rifle's Range 10

const BASE_SENSORS := 10
const HEAT_SELF := 2

## The ward case's numbers. A d20 of 11 beats create_ally's evasion 10 on its own; the ward makes the
## roll pop an accuracy die (attack_roll.gd:70), queued as 6 and applied as -6 (dice.gd:65), so
## 11 - 6 = 5 misses.
const D20_HITS_ONLY_WITHOUT_THE_WARD := 11
const WORST_ACCURACY_DIE := 6
## The rifle's 1d6, cheated ABOVE its Reliable 2 and no higher - test_wicked_host.gd's DAMAGE_DIE and
## its reasoning verbatim. Reliable is a FLOOR ON A HIT, not only a miss payout: get_values_by_type
## tops the total back up whenever `total < reliable` (attack_util.gd:141-144), so a cheated 1 lands
## 2 and a hit becomes indistinguishable from a miss by the damage number - which is the only
## evidence this case has.
const DAMAGE_DIE := 3
## What a MISS with the rifle still lands: it is Reliable 2.
const RELIABLE := 2

## SP4 Task 5. A guaranteed hit that never crits, test_astral_guardian.gd's D20_HITS.
const D20_HITS := 19
## SP4 Task 5. A guaranteed miss - nothing this fixture hands out has evasion below 1.
const D20_MISSES := 1
## SP4 Task 5. Astral Guardian's own d6, cheated. Chosen ABOVE the damage die so the ally ends the
## guardian case holding Overshield and taking nothing on HP, which is two readings of one shot.
const GUARDIAN_D6 := 4
## SP4 Task 5. What the Sluagh holds when the Mark's retort reads its dome, and therefore what the
## retort deals - test_mark_retort.gd's SHIELD.
const SHIELD := 3

var game:Gamemaster
var sluagh:Unit
var ally:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_morrigan(sluagh)
	ally = SluaghFixture.create_ally(game, NEAR_ALLY_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func morrigan() -> GearCore: return sluagh.get_gear(SluaghFixture.MORRIGAN)
func action() -> Action: return morrigan().get_action(SluaghFixture.TRIUMVIRATE_ID)
func specific() -> SpecificAction: return SpecificAction.create(sluagh, morrigan(), action())
func paired(unit:Unit) -> bool: return UnitCondition.has_buff(unit, SluaghFixture.PAIR_CHIP)
func warded(unit:Unit) -> bool: return UnitCondition.has_buff(unit, SluaghFixture.WARD_CHIP)
func adjacent_both_ways(a:Unit, b:Unit) -> bool:
	return UnitRelation.is_adjacent(a, b) and UnitRelation.is_adjacent(b, a)

# ---------------------------------------------------------------- the profile

func test_the_kit_and_action_match_the_card():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.MORRIGAN)
	assert_eq(kit.compcon_id, SluaghFixture.MORRIGAN, 'Registered under its own id (get_kit never returns null).')
	assert_eq(kit.sp_cost, 3, 'SP 3.')
	assert_eq(kit.system_tags, 13, 'Unique + AI + NHP = 13, every vanilla NHP\'s value.')
	assert_true(kit.is_ai() and kit.is_nhp() and kit.is_unique(), 'The three tags.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	if kit.actions.is_empty(): return
	var tri:Action = kit.actions[0]
	assert_eq(tri.get_id(), SluaghFixture.TRIUMVIRATE_ID, 'In Triumvirate.')
	assert_true(tri is ActionSystemTargetUnit, 'An ActionSystemTargetUnit.')
	assert_eq(tri.action_type, Lancer.ACTION.QUICK, 'QUICK.')
	assert_true(tri.is_tech, 'Tech: jammable.')
	assert_eq(tri.self_heat_dice, '2', 'HEAT SELF 2 is self_heat_dice (unit_action.gd:291-294).')
	assert_true(tri.target_range_is_sensors, 'Within Sensors.')
	assert_false(tri.can_target_enemies, 'Allies only...')
	assert_true(tri.can_target_allies, '...')
	assert_false(tri.can_target_self, '...and not the Sluagh itself.')
	assert_true(tri.requires_target_character, 'A character (the archetype\'s reading - see the drone case).')

func test_pressing_it_costs_two_heat_and_lands_three_chips():
	# THE SELF-HEAT POPS NOTHING OFF THE DICE FIFO, and this assertion is what corrects
	# SluaghFixture.triumvirate's own header, which guessed that it popped one and asked to be
	# measured here. gain_self_heat calls Dice.roll_string(self_heat_dice) (unit_action.gd:291-294),
	# and roll_string on the flat string "2" goes through process_dice_string, which parses it as a
	# BONUS and returns count 0 (dice.gd:98-112) - so roll_dice's loop body never runs (:22-35) and
	# the queue is not touched. nightfare_shot's flat "3" reasoning applies after all.
	#
	# THE TURN IS OPENED FIRST, AND THAT IS WHAT THE FIRST MEASUREMENT CAUGHT: event_turn_start's
	# recharge loop rolls a d6 for every non-basic gear that is not yet recharged
	# (event_turn_start.gd:89-91), so the turn triumvirate() opens for us pops ONE entry with the
	# Morrígan equipped. Open it before queueing and the activation is isolated.
	await SluaghFixture.open_turn(game, sluagh)
	SluaghFixture.queue([5])
	var queued_before:int = Dice.CHEAT_ROLL_QUEUE.size()
	var heat_before:int = sluagh.core.current.heat
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_eq(sluagh.core.current.heat - heat_before, HEAT_SELF, 'HEAT SELF 2, through spend_actions -> gain_self_heat.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), queued_before, 'And it popped NOTHING: a flat self_heat_dice rolls no dice.')
	assert_true(paired(sluagh) and paired(ally), 'The pair: one chip on each end.')
	assert_true(warded(ally), 'The ward on the ally.')
	assert_false(warded(sluagh), 'Not on the Sluagh.')
	for chip_id:StringName in [SluaghFixture.PAIR_CHIP, SluaghFixture.WARD_CHIP]:
		var chip:BuffCore = UnitCondition.get_buff(ally, chip_id)
		assert_false(chip.base.hide_from_player, '%s is VISIBLE (ruling 23).' % chip_id)
		assert_eq(chip.base.until, Lancer.UNTIL.END_OF_OWNERS_NEXT_TURN, '%s: until = END_OF_OWNERS_NEXT_TURN (7).' % chip_id)
		assert_eq(chip.get_owner_unit(game.map), sluagh, '%s is owned by the Sluagh (from_gear the NHP), on either end.' % chip_id)

# ---------------------------------------------------------------- the seam

func test_the_partner_six_tiles_out_is_adjacent_in_both_directions():
	assert_eq(UnitRelation.distance_between(sluagh, ally), 6, 'fixture: six tiles apart.')
	assert_false(UnitRelation.is_adjacent(sluagh, ally) or UnitRelation.is_adjacent(ally, sluagh), 'Control: not adjacent before.')
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(UnitRelation.is_adjacent(sluagh, ally), 'THE CARD: the ally is adjacent to the Sluagh...')
	assert_true(UnitRelation.is_adjacent(ally, sluagh), '...and the Sluagh to the ally - two buffs, because is_adjacent is one-sided.')
	assert_true(UnitRelation.adjacent_characters(sluagh).has(ally), 'The list itself carries the partner (level 0)...')
	assert_true(UnitRelation.adjacent_characters(ally).has(sluagh), '...on both ends.')
	assert_eq(UnitRelation.distance_between(sluagh, ally), 6, 'And the DISTANCE is untouched: only the adjacency list widened.')

func test_a_third_unit_is_not_pulled_in():
	var other := SluaghFixture.create_ally(game, OTHER_ALLY_TILE)
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_false(UnitRelation.is_adjacent(sluagh, other), 'Only the named partner.')
	assert_false(UnitRelation.is_adjacent(ally, other), 'And the pair does not chain.')

func test_beyond_the_sluaghs_sensors_the_pair_goes_quiet_and_returns_when_sensors_grow():
	await SluaghFixture.triumvirate(game, sluagh, ally)
	SluaghFixture.step(ally, EDGE_ALLY_TILE)
	SluaghFixture.track(game)
	assert_eq(UnitRelation.distance_between(sluagh, ally), 11, 'fixture: eleven, one past Sensors 10.')
	assert_true(paired(ally), 'The chips stay...')
	assert_false(adjacent_both_ways(sluagh, ally), '..."while within your Sensors": not adjacent at 11, either way.')
	await SluaghFixture.grant_overshield(sluagh, 1)
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 1, 'fixture: Inexorable Formation lifts Sensors to 11.')
	assert_true(adjacent_both_ways(sluagh, ally), 'THE LIVE READ (fork 2): the OWNER\'s Sensors, tested on every call, both ends.')

func test_the_ward_gives_every_attack_on_the_ally_one_difficulty_and_is_not_consumed():
	# THE CARD IN NUMBERS, test_wicked_host.gd's idiom. The ally's evasion is 10 (create_ally). A d20
	# of 11 hits on its own; the ward makes the roll pop an accuracy die (attack_roll.gd:70), queued
	# as 6 and applied as -6 (dice.gd:65), so 11 - 6 = 5 misses. The rifle's Reliable 2 is what a miss
	# still lands, and DAMAGE_DIE is cheated ABOVE it so the hit and the miss are different numbers;
	# nothing reads the chip to decide.
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	SluaghFixture.arm_rifle(hostile)
	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_WARD, DAMAGE_DIE])
	await SluaghFixture.shoot(game, hostile, ally)
	assert_eq(ally.current_damage(), DAMAGE_DIE, 'Control: without the ward an 11 hits and the die lands 3.')
	await SluaghFixture.triumvirate(game, sluagh, ally)
	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_WARD, WORST_ACCURACY_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, hostile, ally)
	assert_eq(ally.current_damage(), DAMAGE_DIE + RELIABLE, 'With the ward the same 11 MISSED: 11 - 6 is 5. Only Reliable 2 landed.')
	assert_true(warded(ally), 'NOT one-time: the ward survives the roll (the card says "all attacks").')
	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_WARD, WORST_ACCURACY_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, hostile, ally)
	assert_eq(ally.current_damage(), DAMAGE_DIE + RELIABLE + RELIABLE, 'And the next attack is worse too.')

func test_retargeting_a_second_ally_clears_the_first_pair():
	var other := SluaghFixture.create_ally(game, OTHER_ALLY_TILE)
	await SluaghFixture.triumvirate(game, sluagh, ally)
	await SluaghFixture.triumvirate(game, sluagh, other)
	assert_false(paired(ally) or warded(ally), 'Fork 4: the first ally lost both chips.')
	assert_true(paired(other) and warded(other), 'The second holds them.')
	assert_eq(UnitCondition.get_buffs(sluagh, SluaghFixture.PAIR_CHIP).size(), 1, 'The Sluagh holds ONE pair chip, naming the new partner.')
	assert_true(adjacent_both_ways(sluagh, other), 'Adjacent to the new partner...')
	assert_false(UnitRelation.is_adjacent(sluagh, ally), '...and no longer to the old.')

func test_everything_clears_at_the_end_of_the_sluaghs_next_turn():
	# THE ORDINARY ROUND, and the ally's own turn inside it is LOAD-BEARING rather than decoration -
	# measured 2026-09-21, see the recorded-edge case below. clear_owners_turn_statuses skips any
	# END_OF_OWNERS_NEXT_TURN buff whose turn_count is still 0 (unit_condition.gd:62), and turn_count
	# ticks at the HOLDER's own turn start alone (new_turn_for_statuses, :24, called for the STARTING
	# unit only, event_turn_start.gd:76). Take the ally's turn out of this sequence and its two chips
	# outlive the Sluagh's turn end - which is the next case, not this one.
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	await SluaghFixture.triumvirate(game, sluagh, ally)
	await SpecFactory.end_turn(game, sluagh)
	assert_true(paired(sluagh) and paired(ally) and warded(ally), 'Survives the pressing turn\'s end.')
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.end_turn(game, hostile)
	assert_true(paired(sluagh) and paired(ally) and warded(ally), 'Survives the enemy\'s turn.')
	await SpecFactory.start_turn(game, ally)
	await SpecFactory.end_turn(game, ally)
	assert_true(paired(sluagh) and paired(ally) and warded(ally), 'And survives the ALLY\'s own turn end: the clock is the owner\'s, not the holder\'s.')
	await SpecFactory.start_turn(game, sluagh)
	assert_true(paired(sluagh) and paired(ally) and warded(ally), 'Survives the Sluagh\'s next turn start...')
	await SpecFactory.end_turn(game, sluagh)
	assert_false(paired(sluagh) or paired(ally) or warded(ally), '...and clears at its END: END_OF_OWNERS_NEXT_TURN, the owner being the Sluagh.')
	assert_false(adjacent_both_ways(sluagh, ally), 'Adjacency is back to the map.')

func test_an_ally_who_never_acted_still_loses_both_chips_at_the_sluaghs_turn_end():
	# THE VANILLA EDGE, CLOSED (controller ruling, 2026-09-21: card fidelity over the edge). Left
	# alone, clear_owners_turn_statuses skips an END_OF_OWNERS_NEXT_TURN buff whose turn_count is
	# still 0 (unit_condition.gd:62), and turn_count ticks only at the HOLDER's own turn start
	# (new_turn_for_statuses, :24, called for the STARTING unit alone, event_turn_start.gd:76) - so
	# an ally that has not started a turn since the press used to keep its pair AND its ward one
	# Sluagh turn-end longer than "until the end of your next turn" (measured, and this case pinned
	# it that way until the ruling). lancer.gd:52 warns about exactly this.
	#
	# buff_in_triumvirate_pair.on_clear now makes the OWNER'S core the clock for all three chips:
	# when the Sluagh's own core goes - and its turn_count DID tick, so it goes on schedule - it
	# cascades clear_buffs_owned_by over every other unit. The ally never takes a turn here, which
	# is the whole arrangement: under the old behaviour it kept both chips and the widening was
	# one-sided for an extra turn.
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(paired(ally) and warded(ally), 'Liveness: the ally is holding both before the clock runs.')
	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_false(paired(sluagh), 'The Sluagh\'s own chip clears on schedule - its turn_count ticked at its own turn start.')
	assert_false(paired(ally) or warded(ally), 'AND the ally\'s two go with it, though the ally never took a turn: the owner\'s core is the clock.')
	assert_false(UnitRelation.is_adjacent(sluagh, ally) or UnitRelation.is_adjacent(ally, sluagh),
		'So the widening ends on the card\'s schedule in BOTH directions - no one-sided extra turn.')

func test_a_partner_can_affect_refuses_is_not_adjacent_either_way():
	# THE WIDENING IS DISTANCE ONLY (controller ruling, 2026-09-21). adjacent_characters is
	# get_characters_within(unit, 1, false), which filters on is_character() (unit_relation.gd:42)
	# and on can_affect(whos_asking, other_unit) inside get_units_within (:60) - so the banner re-runs
	# both rather than waiving them, the doctrine its own file states three banners up.
	#
	# INVULNERABLE, ON BOTH ENDS, and the choice is forced rather than stylistic. can_affect
	# (:393-404) offers four refusals and the other three are unusable here:
	#  - EXILED is already refused one line earlier, by is_character(): is_active() excludes EXILED
	#    (unit.gd:113), so the mutation on the can_affect line would redden nothing and the case
	#    would be testing the wrong guard;
	#  - INTANGIBLE strips the very chips this case must keep - handle_intangibilty_changing clears
	#    every buff whose owner's tangibility does not match (unit_condition.gd:261-265);
	#  - a shard split needs map plumbing this fixture has no helper for.
	# INVULNERABLE appears in neither is_active() nor apply_status's special-case match, so it moves
	# nothing but can_affect. It refuses whichever side is the TARGET (:397), so one end alone would
	# close one direction only; both ends closes both, which is what "always treated as adjacent"
	# has to stop promising.
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(adjacent_both_ways(sluagh, ally), 'Liveness: adjacent both ways before the status lands.')
	SpecFactory.apply(ally, Lancer.STATUS.INVULNERABLE)
	SpecFactory.apply(sluagh, Lancer.STATUS.INVULNERABLE)
	assert_true(paired(sluagh) and paired(ally) and warded(ally), 'The chips are untouched - this is the banner refusing, not the buffs falling off.')
	assert_false(UnitRelation.is_adjacent(sluagh, ally), 'can_affect refuses the invulnerable TARGET, so the partner is not appended...')
	assert_false(UnitRelation.is_adjacent(ally, sluagh), '...and not in the other direction either.')

func test_it_cannot_target_a_hostile_or_the_sluagh_itself():
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	assert_false(action().can_target_unit(hostile, specific()), 'Not an enemy.')
	assert_false(action().can_target_unit_self(specific()), 'Not itself.')
	assert_false(UnitTargeting.get_tiles_targetable(specific()).has(EDGE_ALLY_TILE + Vector2i(1, 0)),
		'And nothing past Sensors is targetable (range lives on the picking path, SP3\'s finding).')

func test_an_allied_drone_is_a_legal_partner():
	# The Crown's ruling (author, 2026-09-21) on the same archetype: requires_target_character is
	# Unit.is_character(), "active mech/pilot/drone" (unit.gd:116). PROPOSED for the frame close
	# alongside the trigger-side is_actor() reading; pinned as the accepted behaviour so a reversal
	# is one test and one override.
	var drone := SluaghFixture.create_drone(game, OTHER_ALLY_TILE)
	assert_true(action().can_target_unit(drone, specific()), 'A drone passes the filter.')
	await SluaghFixture.triumvirate(game, sluagh, drone)
	assert_true(adjacent_both_ways(sluagh, drone), 'And the pair works on it.')

# ---------------------------------------------------------------- Task 5: what the pair reaches
#
# Spike section 3's list, measured on THIS frame's own readers. Every one of the Sluagh's three
# "adjacent" effects sits on UnitRelation.is_adjacent(sluagh, x) by SP1's ruling 6 - which is why
# In Triumvirate reaches them - and Guardian sits on a radius, which is why it does not.
#
# THESE ARE MEASUREMENTS, NOT TDD. Task 4 built the mechanism; what is new here is the evidence that
# each reader is on the widened function rather than on a distance, and one of them (the cover
# leaving) is the only assertion in the suite that can see the pair buff's on_clear self-erase.

## THE AURA, IN BOTH DIRECTIONS - it arrives with the pair and it leaves with it, and nobody moves.
##
## ARRIVING is passive_mark_cover_aura.gd asking is_adjacent rather than a radius (SP1 Task 7's
## override, pinned by test_compat.gd as the only test that can tell it from the default) PLUS
## In Triumvirate calling UnitTile.update_tracking_and_statuses by hand: auras refresh from that
## function alone (unit_tile.gd:15-24, passive_aura.gd:24) and from apply_buffs only when the OWNER
## gear holds a PassiveAura (unit_condition.gd:713-715) - which the NHP does not.
##
## LEAVING is the half that needed content to be written for it, and it is the mutation target.
## clear_buff calls on_clear BEFORE erasing the core (unit_condition.gd:979-980, with Wickworks' own
## "comes before actually falling off... hm."), so the refresh made inside on_clear would still SEE
## the pair and re-shelter the ally. buff_in_triumvirate_pair.on_clear therefore erases itself from
## unit.state.buffs first. Delete that one line and this case's last assertion goes red while
## everything else in the file stays green - measured, Task 5 Step 4.
##
## THE FIVE-STEP SEQUENCE is the owner's clock (END_OF_OWNERS_NEXT_TURN, with the cascade): the
## Sluagh's turn end, the enemy's whole turn, then the Sluagh's next turn start and end. The ally
## never takes a turn, which is deliberate - it is the arrangement the cascade exists for.
func test_the_marks_soft_cover_reaches_the_far_partner_and_leaves_when_the_pair_expires():
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	await SluaghFixture.press_mark(game, sluagh)
	assert_false(UnitCondition.has_buff(ally, SluaghFixture.SOFT_COVER_CHIP),
		'Control: six out, no cover from the dome.')
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(UnitCondition.has_buff(ally, SluaghFixture.SOFT_COVER_CHIP),
		'THE MOMENT IT LANDS: the aura re-read (update_tracking_and_statuses by hand) shelters the far partner.')
	assert_eq(CoverCalculator.determine_cover(ally, hostile).total, Lancer.COVER.SOFT,
		'And the engine\'s own cover pipeline reads it, six tiles from the dome\'s centre.')

	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.end_turn(game, hostile)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)

	assert_false(paired(ally), 'fixture: the pair expired.')
	assert_false(UnitCondition.has_buff(ally, SluaghFixture.SOFT_COVER_CHIP),
		'AND THE COVER LEFT WITH IT - the pair buff\'s on_clear erases itself and refreshes tracking. Nobody moved.')

## ASTRAL GUARDIAN, a REACTION GATE rather than an aura, and therefore a second and unrelated piece
## of code asking the same question (test_compat.gd's own reasoning for its House Guard pair).
##
## THE QUEUE IS [d20, the guardian's d6, the rifle's damage d6] - SluaghFixture.queue's own order,
## because the POST reactions run at event_unit_attack.gd:123 and damage is rolled afterwards at
## event_unit_attack_declared.gd:74. DAMAGE_DIE is 3, ABOVE the rifle's Reliable 2, so the number
## read is the die and not the floor (attack_util.gd:141-144).
##
## BOTH READINGS ARE ASSERTED, and that is what makes the case immune to queue alignment: a guardian
## that was refused pops no middle entry, so the damage die would be the 4 - landing 4 on HP and
## leaving no Overshield, which fails both lines rather than one.
func test_astral_guardian_fires_for_the_far_partners_hit():
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	SluaghFixture.arm_rifle(hostile)
	await SluaghFixture.triumvirate(game, sluagh, ally)
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, hostile, ally)
	assert_eq(Overshield.current(ally), GUARDIAN_D6 - DAMAGE_DIE,
		'Astral Guardian granted 4 and the hit took 3: the far partner is "adjacent" to the guardian.')
	assert_eq(ally.current_damage(), 0, 'And the dome took the whole hit - nothing reached HP.')

## THE MARK'S RETORT, the third of this frame's "adjacent" readers and the second reaction gate.
##
## THE OBSERVABLE IS THE ATTACKER'S HEALTH, which is what makes the Reliable 2 rifle safe here -
## test_mark_retort.gd's own header. The shot MISSES (the retort's trigger), the ally takes the
## floored 2 that a miss still lands, and none of that is read.
##
## THE QUEUE IS ALL 1s AND THE ALIGNMENT CANNOT MATTER. The Mark is up, so the far partner is
## sheltered by the case above and the roll spends a d6 on the difficulty between the d20 and the
## damage - [d20, difficulty d6, damage d6] - but D20_MISSES and SluaghFixture.queue's tail are both
## 1, so every slot reads the same whichever way it lands.
func test_the_marks_retort_fires_for_a_miss_against_the_far_partner():
	var hostile := SluaghFixture.create_hostile(game, HOSTILE_TILE)
	SluaghFixture.arm_rifle(hostile)
	await SluaghFixture.grant_overshield(sluagh, SHIELD)
	await SluaghFixture.press_mark(game, sluagh)
	await SluaghFixture.triumvirate(game, sluagh, ally)
	SluaghFixture.queue([D20_MISSES, D20_MISSES])
	await SluaghFixture.shoot(game, hostile, ally)
	assert_eq(hostile.current_damage(), SHIELD,
		'The retort dealt the Sluagh\'s Overshield to the attacker of its far partner.')

## A VANILLA READER, and the reason the seam had to be adjacent_characters rather than a rule of our
## own: Stabilize's "clear a condition on an adjacent ally" offers the partner six tiles out without
## knowing anything about this mod (action_stabilize.gd:282, the spike's measured witness). Recorded
## as the card working - 37 content readers sit on that function and every one of them widens.
func test_stabilize_offers_the_far_partners_condition():
	SpecFactory.apply(ally, Lancer.STATUS.IMPAIRED)
	assert_false(UnitCondition.get_ability_clearable_conditions_on(ally).is_empty(),
		'Control: the partner carries a condition Stabilize could clear.')
	var stabilize:Action = ContentLibrary.get_kit(&'ms_stabilize').actions[0]
	assert_true(stabilize.has_method(&'get_adjacent_allies_with_clearable_conditions'),
		'Control: this is Stabilize\'s own helper.')
	assert_false(stabilize.get_adjacent_allies_with_clearable_conditions(sluagh).has(ally),
		'Control: six out, not offered.')
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(stabilize.get_adjacent_allies_with_clearable_conditions(sluagh).has(ally),
		'A VANILLA reader of adjacent_characters sees the pair (spike section 3). The card working, recorded.')

## AND THE LINE THE WIDENING DOES NOT CROSS. Guardian scans get_units_within(attacked, 1, ...) - a
## hard-coded 1 through distance_between (unit_relation.gd:454-457) - so a Sluagh holding Guardian
## does not become a guardian for its far partner, however adjacent the rest of the engine thinks it
## is. Design fork 5 accepts that, and the whole distance_between family goes with it (PassiveAura's
## radius, get_characters_within, is_close_enough_to_engage - spike section 3).
func test_guardian_on_the_sluagh_does_not_cover_the_far_partner():
	var touching := SluaghFixture.create_ally(game, SLUAGH_TILE + Vector2i(1, 0))
	SpecFactory.apply_buff(sluagh, &'buff_guardian')
	await SluaghFixture.triumvirate(game, sluagh, ally)
	assert_true(UnitRelation.is_adjacent(sluagh, ally), 'Liveness: the pair is up.')
	assert_true(UnitRelation.get_guardian_units(touching).has(sluagh),
		'Control: the Sluagh DOES guard the ally it genuinely touches, so the buff is live.')
	assert_false(UnitRelation.get_guardian_units(ally).has(sluagh),
		'Guardian scans get_units_within(attacked, 1) - a radius (unit_relation.gd:454-457). Never widened. Fork 5.')
