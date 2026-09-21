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

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

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

func test_the_recorded_edge_an_ally_who_has_not_acted_keeps_its_chips_past_the_sluaghs_turn_end():
	# Fork 3, ACCEPTED and pinned - and the MEASUREMENT (2026-09-21) corrected the plan's guess of
	# which way this edge falls. The clock is the OWNER's turn end, read by
	# clear_owners_turn_statuses for every buff from the Sluagh's gear; but that function skips an
	# END_OF_OWNERS_NEXT_TURN buff whose turn_count is still 0 (unit_condition.gd:62), and
	# turn_count ticks only at the HOLDER's own turn start (new_turn_for_statuses,
	# unit_condition.gd:24, called for the STARTING unit alone, event_turn_start.gd:76). So it is
	# the ally who has NOT taken a turn in between that keeps its chips one Sluagh turn end LONGER,
	# not the ally who acted - the brief had it the other way round. lancer.gd:52's own warning
	# ("will clear at end of NEXT owner end turn they see"), measured.
	#
	# THE ASYMMETRY IS THE POINT, and it is what a player would actually see: the Sluagh's own chip
	# goes on schedule, so for that extra turn the widening is ONE-SIDED - the ally still counts the
	# Sluagh as adjacent while the Sluagh no longer counts the ally. Recorded, not guarded (spike
	# section 4 fork 3: vanilla's own buffs on this lifetime behave the same).
	await SluaghFixture.triumvirate(game, sluagh, ally)
	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_false(paired(sluagh), 'The Sluagh\'s own chip clears on schedule - its turn_count ticked at its own turn start.')
	assert_true(paired(ally) and warded(ally), 'The ally\'s two do NOT: turn_count is still 0, so :62 skips them.')
	assert_false(UnitRelation.is_adjacent(sluagh, ally), 'So the widening is one-sided for that extra turn...')
	assert_true(UnitRelation.is_adjacent(ally, sluagh), '...the ally still counts the Sluagh as adjacent.')

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
