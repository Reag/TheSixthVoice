# QUIETUS MACHINES / FUNGAL NETWORK (Myconid SP2 Task 3).
#
# "The Myconid releases a cloud of nanite spores around itself. For the rest of the scene all
# adjacent allies gain immunity to Impaired and have +1 armor. Hostile characters within burst 2 of
# the Myconid are Slowed and Impaired."
#
# THE SHAPE, AND WHERE TO READ THE REASONING. Ruling 6 (2026-09-15) makes this a ZONE with no off
# switch: two PassiveAuras on the core Kit, both starts_active = false, woken by the protocol which
# then hibernates itself. Each .tres in cp_quietus_machines/ carries its own account; this file only
# says what is TRUE OF THE RUNNING GAME, and each test names the mutation that reddens it.
#
# WHAT THIS FILE INHERITS FROM THE SP2 PROBE, which it replaces (spec/test_spike_status_aura.gd,
# deleted in Task 5). The probe established against synthetic content that a PassiveAura buff can
# carry statuses through Buff.applies_statuses, that they lift on leaving and return on re-entry,
# that they die with the owner, and that they are LOCKED while held. Those are engine facts; this
# file re-asserts them against the real Kit, because a green probe says nothing about whether this
# frame's .tres files are wired the way the probe's synthetic ones were.
#
# TWO MORE WERE PORTED IN THE SP2 TASK 5 REVIEW, and section C2 is where they live: the engine GATE
# that consumes the status (without it every other hostile test reads the same cache and a dead
# mechanic looks green), and the idempotence of the re-entrant aura pass.
#
# THE ONE THE PROBE HAD THAT IS DELIBERATELY NOT HERE is its source-qualified query
# (UnitCondition.has_status(unit, status, gear.persistent_id), which reaches a buff-carried status
# through get_buffs_that_apply_status, unit_condition.gd:809-817). Nothing takes that path on these
# statuses. get_buffs_that_apply_status has exactly ONE caller in the whole tree - the second
# disjunct of has_status at unit_condition.gd:392 - and every source-qualified has_status call in
# engine/ and content/ passes the CALLER'S OWN gear id, asking "did I apply this?"
# (event_gear_destroy.gd:36 and action_jump.gd:60 for FLYING, the two mf_vlad dismemberment actions
# for SHREDDED, both mw_pinaka_missiles actions for SLOWED); the only engine-generic one is
# unit_condition.gd:582, which asks for SLOWED from StatusType.SOURCE_UNDERWATER_STATUS_KEY and can
# never match our from_gear. Quietus Machines asks nothing of the sort, and its only script is four
# lines. The source-aware machinery this content DOES reach is the immunity check inside
# get_current_statuses, which keys on the buff's from_gear (unit_condition.gd:381) - and that is
# already pinned, by test_an_ally_impaired_by_another_buff_is_suppressed_while_inside. Recorded as a
# deliberate gap in progress-myconid-sp2.md rather than covered by a test of a path nothing takes.
#
# TWO FACTS THAT CHANGE HOW TESTS HERE MUST BE WRITTEN, both measured by the probe:
#
#  1. THE STATUSES ARE LOCKED. UnitCondition.clear_status (unit_condition.gd:310-324) rebuilds
#     unit.state.statuses, and a buff-supplied status was never in that array - so nothing strips
#     Slowed off a hostile still standing in the cloud. buff.gd:133 documents the export as exactly
#     that. Do not write a test that expects to clear one.
#
#  2. applies_to_self IS REDUNDANT ON THE HOSTILE AURA and NOT on the ally aura. A unit is its own
#     ally (Faction.is_ally(f, f) is true, faction.gd:30), so on the hostile passive
#     applies_to_allies = false already refuses the Myconid one line later (passive_aura.gd:70), and
#     flipping applies_to_self changes nothing measurable. On the ALLY passive there is no such
#     second line, so applies_to_self is the only thing keeping the Myconid out of its own ally
#     cloud - and there the mutation is real. Rulings row 2026-09-16.
#
# GEOMETRY. The Myconid is SIZE 2, and "adjacent" / "burst 2" are UnitRelation.distance_between,
# which measures CLOSEST TILES; PassiveAura.is_within_range compares it against aura_range at
# passive_aura.gd:85. So the ranges below are measured from the NEAREST of the Myconid's four tiles,
# not from its anchor - and at least one hostile test stands diagonally off a non-anchor tile so the
# spec can tell the two apart. Get this wrong and every range assertion in the file is measuring an
# anchor-only aura that happens to agree.
#
# THAT CITATION WAS :87 UNTIL THE WHOLE-SUB-PROJECT REVIEW, 2026-09-16, AND :87 IS A DIFFERENT RULE:
# it is the `applies_only_when_in_los` test, two rows down the same function. Same failure mode as
# the `unit_action.gd:119` error Task 5 corrected - a line that exists, sits in the right function
# and tells a coherent but WRONG story, so a reader who checks the load-bearing citation for every
# range constant in this file comes away believing the range test is a line-of-sight test. Written
# once in Task 3 and copied into both passive .tres files; all three corrected together.
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')

const CORE_ID := &'cp_quietus_machines'
const PROTOCOL_ID := &'action_fungal_network'

const IMMUNITY_BUFF := &'buff_fungal_network_immunity'
const ARMOR_BUFF := &'buff_fungal_network_armor'
const REDUCTION_BUFF := &'buff_fungal_network_armor_reduction'
const SPORES_BUFF := &'buff_fungal_network_spores'

# The Myconid anchors at (4,4) and, being size 2, OCCUPIES (4,4) (5,4) (4,5) (5,5). Every tile below
# is chosen against that footprint, and the comment on each says which of its tiles it is measured
# from. distance_between is Chebyshev over closest tiles, so "adjacent" is a ring one tile out from
# the whole 2x2 block.
const MYCONID_TILE := Vector2i(4, 4)

const ADJACENT_TILE := Vector2i(6, 4)      # 1 from (5,4): inside the ALLY aura
const ADJACENT_TILE_2 := Vector2i(6, 5)    # 1 from (5,5): the SAME range as ADJACENT_TILE, off a
                                           # different corner, so an ally and a hostile can stand
                                           # inside the ally aura at once and be compared
const NEAR_TILE := Vector2i(7, 4)          # 2 from (5,4): outside the ally aura, inside the hostile one
const FAR_TILE := Vector2i(8, 4)           # 3 from (5,4): outside both
const DIAGONAL_TILE := Vector2i(7, 7)      # 2 from (5,5), the NON-ANCHOR corner - 3 from the anchor.
                                           # An anchor-only aura would miss this one, which is the
                                           # whole point of it being here.
const DAMAGE := 5

var game:Gamemaster
var myconid:Unit


func before_each() -> void:
	game = MyconidFixture.create_game(self)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)


# ---------------------------------------------------------------- fixture helpers

func core_gear() -> GearCore:
	var gear:GearCore = myconid.get_gear(CORE_ID)
	return gear if GearCore.is_valid(gear) else null

## Press the protocol. DELEGATES to MyconidFixture.fungal_network (SP2 Task 5), which is this same
## body lifted verbatim - its own header carries the reason the turn start is not decoration:
## unit_action.gd:144 refuses a protocol unless unit.state.is_using_protocols, which only
## event_turn_start opens. Without it every test here would fail with "Gear not available / reason :
## protocol" and read as broken content.
func press_protocol() -> void:
	await MyconidFixture.fungal_network(game, myconid)

func ally(tile:Vector2i) -> Unit:
	return MyconidFixture.create_dummy(game, tile, 10, Faction.PLAYER)

func hostile(tile:Vector2i) -> Unit:
	return MyconidFixture.create_dummy(game, tile, 10, Faction.AI_ENEMY)

func has(unit:Unit, buff_id:StringName) -> bool:
	return UnitCondition.has_buff(unit, buff_id)

## Damage a unit and report how much health it actually lost, which is the only honest way to ask
## whether the hidden reduction half ran - the visible chip is a number on a readout and blunts
## nothing (see buff_armor_statblock.gd).
func damage_taken(unit:Unit, amount:int, type:Lancer.DAMAGE_TYPE, flags:Array = []) -> int:
	var before:int = unit.core.current.health
	await game.execute_event(&'event_unit_damage', {
		unit = unit, number = amount, category = type, flags = flags,
	})
	return before - unit.core.current.health


# ===================== A. NOTHING HAPPENS UNTIL THE PROTOCOL IS PRESSED =====================

## Reddened by: starts_active = true on either passive.
func test_before_the_protocol_nothing_is_applied() -> void:
	var friend := ally(ADJACENT_TILE)
	var foe := hostile(NEAR_TILE)
	UnitTile.update_tracking_and_statuses(game.map)

	assert_false(has(friend, ARMOR_BUFF), 'the ally aura is dark')
	assert_false(has(friend, IMMUNITY_BUFF), 'both of its buffs are dark')
	assert_false(has(foe, SPORES_BUFF), 'and so is the hostile aura')
	assert_false(foe.has_status(Lancer.STATUS.SLOWED), 'no statuses either')

## The control for every test in this file: the protocol really does light both auras at once, and
## catches everyone ALREADY standing in range rather than only units that move afterwards. That is
## GearCore.set_aura_active running UnitTile.update_tracking_and_statuses itself
## (gear_core.gd:297-299) - the reason action_fungal_network.gd does not call it a second time.
##
## Reddened by: deleting the set_aura_active line.
func test_the_protocol_lights_both_auras_over_units_already_standing_there() -> void:
	var friend := ally(ADJACENT_TILE)
	var foe := hostile(NEAR_TILE)

	await press_protocol()

	assert_true(has(friend, ARMOR_BUFF), 'an ally already adjacent is caught by the press')
	assert_true(has(foe, SPORES_BUFF), 'and a hostile already in the burst')


# ===================== B. THE ALLY HALF =====================

## Reddened by: dropping either buff from passive_fungal_network_allies.tres.
func test_an_adjacent_ally_gains_the_armor_chip_and_the_immunity_chip() -> void:
	var friend := ally(ADJACENT_TILE)
	await press_protocol()

	assert_true(has(friend, ARMOR_BUFF), 'the visible +1 armor chip')
	assert_true(has(friend, IMMUNITY_BUFF), 'and the visible Impaired-immunity chip')
	assert_true(has(friend, REDUCTION_BUFF), 'and the hidden half that does the actual reducing')

## THE CHIP IS NOT THE MECHANIC. A STATBLOCK buff reduces no incoming damage whatsoever; the hidden
## BuffResistDamage sibling is what makes the hit smaller. This test is the reason both exist, and it
## is the one that would catch shipping only the chip.
##
## Reddened by: reduction_amount = "0" on buff_fungal_network_armor_reduction.tres.
func test_an_adjacent_ally_takes_one_less_kinetic_damage() -> void:
	var friend := ally(ADJACENT_TILE)
	var control := ally(FAR_TILE)
	await press_protocol()

	var sheltered:int = await damage_taken(friend, DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	var exposed:int = await damage_taken(control, DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)

	assert_eq(exposed, DAMAGE, 'control: an ally outside the cloud takes it all')
	assert_eq(sheltered, DAMAGE - 1, 'and one inside takes 1 less')

## Real armor does not stop AP, and neither may this. The guard lives in buff_armor_reduction.gd's
## check_if_passive_applies override, because damage_modifications.gd:110 subtracts other_reduction
## unconditionally while guarding only the real-armor branch with the AP flag.
##
## Reddened by: deleting that override.
func test_an_ap_hit_on_an_adjacent_ally_is_not_reduced() -> void:
	var friend := ally(ADJACENT_TILE)
	await press_protocol()
	assert_true(has(friend, REDUCTION_BUFF), 'precondition: the hidden half is on')

	var taken:int = await damage_taken(friend, DAMAGE, Lancer.DAMAGE_TYPE.KINETIC,
		[EventService.DAMAGE_FLAG.AP])

	assert_eq(taken, DAMAGE, 'armor-piercing goes through armor, so it goes through this')

## Armor ignores burn, and damage_types on the .tres is spelled out rather than using
## resist_everything PRECISELY because resist_everything would cover burn. buff_armor_reduction.gd's
## header gives the second, independent reason: burn stacks using the POST-reduction amount
## (event_unit_damage.gd:84 reads context.number, which execute_preblock already overwrote), so a
## reduction covering burn would shrink both the hit AND the burn stack that ticks later.
##
## THIS TEST REPLACED A HEAT ONE, WHICH WAS VACUOUS - worth recording, because the heat version
## looked perfectly reasonable and measured nothing. Heat does not come off HEALTH at all; it goes to
## the heat track. So damage_taken() returned 0 for the sheltered ally and 0 for the control, the
## assertion compared 0 to 0, and adding HEAT to damage_types left it green (measured, mutation M05).
## Burn is the damage type that is both excluded on purpose AND observable in health.
##
## Reddened by: adding BURN (4) to damage_types.
func test_a_burn_hit_on_an_adjacent_ally_is_not_reduced() -> void:
	var friend := ally(ADJACENT_TILE)
	var control := ally(FAR_TILE)
	await press_protocol()

	var sheltered:int = await damage_taken(friend, DAMAGE, Lancer.DAMAGE_TYPE.BURN)
	var exposed:int = await damage_taken(control, DAMAGE, Lancer.DAMAGE_TYPE.BURN)

	assert_eq(exposed, DAMAGE, 'control: burn comes off health in full')
	assert_eq(sheltered, exposed, 'and the cloud does not blunt it, because armor does not')

## "gain immunity to Impaired" has to mean an ALREADY-Impaired ally is cleaned up, not merely
## protected from the next application. BuffStatusImmunity.on_application (buff_status_immunity.gd:
## 10-12) is what does it.
##
## Reddened by: immune_to_statuses = [] on buff_fungal_network_immunity.tres.
func test_an_already_impaired_ally_loses_impaired_on_entering() -> void:
	var friend := ally(ADJACENT_TILE)
	UnitCondition.apply_status(SpecFactory.dummy_event(), friend, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL)
	assert_true(friend.has_status(Lancer.STATUS.IMPAIRED), 'precondition: really Impaired')

	await press_protocol()

	assert_false(friend.has_status(Lancer.STATUS.IMPAIRED), 'the cloud cleared it')

## The other half of the same promise: it cannot come back while the ally is inside.
##
## Reddened by: immune_to_statuses = [].
func test_an_ally_inside_cannot_be_given_impaired() -> void:
	var friend := ally(ADJACENT_TILE)
	await press_protocol()

	UnitCondition.apply_status(SpecFactory.dummy_event(), friend, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL)

	assert_false(friend.has_status(Lancer.STATUS.IMPAIRED), 'apply_status refuses it at unit_condition.gd:93-99')

## THE SECOND IMMUNITY PATH, and it is a different mechanism reaching the same place. An Impaired
## supplied by another BUFF's applies_statuses is not in unit.state.statuses, so
## BuffStatusImmunity.on_application's clear_status cannot touch it - it is instead SUPPRESSED by the
## has_gained_immunity_to_status check inside get_current_statuses (unit_condition.gd:379-382).
## Worth its own test because the two paths fail independently.
##
## Reddened by: immune_to_statuses = [].
func test_an_ally_impaired_by_another_buff_is_suppressed_while_inside() -> void:
	var friend := ally(ADJACENT_TILE)
	var impairing := Buff.new()
	impairing.compcon_id = &'buff_spec_impairing'
	impairing.applies_statuses = [&'impaired'] as Array[StringName]
	impairing.hide_from_player = true
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), friend, BuffCore.create(impairing))
	assert_true(friend.has_status(Lancer.STATUS.IMPAIRED), 'precondition: Impaired by a buff')

	await press_protocol()

	assert_true(has(friend, &'buff_spec_impairing'), 'the other buff is still held - it was not cleared')
	assert_false(friend.has_status(Lancer.STATUS.IMPAIRED), 'but the status it supplies is suppressed')

## "ADJACENT" is 1, not 2. The ally aura and the hostile aura have different ranges and this is what
## keeps them apart.
##
## Reddened by: aura_range = 2 on passive_fungal_network_allies.tres.
func test_an_ally_at_range_2_gets_nothing() -> void:
	var inside := ally(ADJACENT_TILE)
	var outside := ally(NEAR_TILE)
	await press_protocol()

	assert_true(has(inside, ARMOR_BUFF), 'control: one tile closer IS sheltered')
	assert_false(has(outside, ARMOR_BUFF), 'two tiles out is not adjacent')
	assert_false(has(outside, IMMUNITY_BUFF), 'neither buff reaches it')

## The Myconid shelters others, not itself. Unlike the hostile aura, applies_to_self is the ONLY
## thing doing this here - see the file header.
##
## Reddened by: applies_to_self = true on passive_fungal_network_allies.tres.
func test_the_myconid_is_not_sheltered_by_its_own_cloud() -> void:
	var friend := ally(ADJACENT_TILE)
	await press_protocol()

	assert_true(has(friend, ARMOR_BUFF), 'control: the ally aura IS live')
	assert_false(has(myconid, ARMOR_BUFF), 'and the Myconid is outside it')
	assert_false(has(myconid, IMMUNITY_BUFF), 'both buffs')

## "all adjacent ALLIES" - so a hostile that closes to adjacent gets the hostile cloud and NOTHING
## from the ally one. Added at the SP2 whole-sub-project review, 2026-09-16, and it closes the one
## genuine coverage hole in this file: until it existed, no test in the suite ever placed a hostile
## within range 1 of the Myconid (the hostiles above stand at 2 and 3, and ADJACENT_TILE was only
## ever given to an ally), so applies_to_enemies = false on passive_fungal_network_allies.tres was
## unpinned - and DELETING the line would not even have looked like a change, because the export
## defaults to true (passive_aura.gd:10).
##
## WHY THAT FAILURE IS CARD-BREAKING AND SILENT. An adjacent hostile would gain the +1 armor pair -
## real, and read by every get_armor() gate including this mod's own Ripper Mod - and, worse,
## buff_fungal_network_immunity. The immunity is the serious half: get_current_statuses checks
## has_gained_immunity_to_status before folding a buff-supplied status in (unit_condition.gd:379-382),
## so the cloud's own Impaired would be SUPPRESSED on that hostile. "Hostile characters within burst 2
## are Slowed and Impaired" would quietly become "...and Impaired unless they close to adjacent",
## while every other test in this file stayed green. Hence the last assertion: it is the card's, not
## the flag's.
##
## THREE POSITIVE CONTROLS, because all-negative assertions on a unit nothing reached would pass with
## both auras dark: an ally at the SAME range does get the pair, the hostile does get the spores chip,
## and the range is asked of the engine rather than assumed.
##
## Reddened by: M18, applies_to_enemies = true (or deleted) on passive_fungal_network_allies.tres.
func test_an_adjacent_hostile_gets_nothing_from_the_ally_cloud() -> void:
	var friend := ally(ADJACENT_TILE)
	var foe := hostile(ADJACENT_TILE_2)
	await press_protocol()

	assert_eq(UnitRelation.distance_between(myconid, foe), 1,
		'precondition: the hostile really is ADJACENT, i.e. inside the ally aura range')
	assert_true(has(friend, ARMOR_BUFF), 'control: an ally at that same range IS sheltered')
	assert_true(has(friend, IMMUNITY_BUFF), 'control: with both of the ally chips')
	assert_true(has(foe, SPORES_BUFF), 'control: and the hostile IS reached - by the other aura')

	assert_false(has(foe, ARMOR_BUFF), 'but the hostile gets no armor chip')
	assert_false(has(foe, REDUCTION_BUFF), 'nor the hidden reduction that does the work')
	assert_false(has(foe, IMMUNITY_BUFF), 'nor the Impaired immunity')
	assert_true(foe.has_status(Lancer.STATUS.IMPAIRED),
		'so the cloud still Impairs it - which is the card, and what the immunity would suppress')


# ===================== C. THE HOSTILE HALF =====================

## Reddened by: dropping applies_statuses from buff_fungal_network_spores.tres.
func test_a_hostile_at_2_is_slowed_and_impaired() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()

	assert_true(has(foe, SPORES_BUFF), 'it wears the Fungal Network chip')
	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'and it is Slowed')
	assert_true(foe.has_status(Lancer.STATUS.IMPAIRED), 'and Impaired')

## THE GEOMETRY TEST. This tile is 2 from the Myconid's (5,5) corner and 3 from its anchor, so it
## passes only if the burst is measured from the whole footprint. Without it the whole file would be
## consistent with an anchor-only aura.
##
## Reddened by: aura_range = 1, or by anything that made distance_between anchor-relative.
func test_the_burst_is_measured_from_every_tile_the_myconid_occupies() -> void:
	var foe := hostile(DIAGONAL_TILE)
	await press_protocol()

	assert_eq(UnitRelation.distance_between(myconid, foe), 2,
		'precondition: 2 from the (5,5) corner - it is 3 from the anchor at (4,4)')
	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'and the burst reaches it')

## Reddened by: aura_range = 3 on passive_fungal_network_hostiles.tres.
func test_a_hostile_at_3_is_not() -> void:
	var inside := hostile(NEAR_TILE)
	var outside := hostile(FAR_TILE)
	await press_protocol()

	assert_true(inside.has_status(Lancer.STATUS.SLOWED), 'control: one tile closer IS caught')
	assert_false(has(outside, SPORES_BUFF), 'three tiles out is past the burst')
	assert_false(outside.has_status(Lancer.STATUS.SLOWED), 'and so it is not Slowed')

## THE ZONE IS HELD, NOT APPLIED ONCE. This is the test that separates ruling 6's reading from the
## fallback the design would have taken if the probe had failed (statuses applied on entry and at
## turn start, which would leave a hostile Slowed after walking out).
##
## Reddened by: giving buff_fungal_network_spores.tres an `until` of its own, or anything that
## stopped PassiveAura clearing it on the way out.
func test_a_hostile_stepping_from_2_to_3_loses_both() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()
	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'precondition: inside the cloud')

	UnitTile.move_to(foe, FAR_TILE)

	assert_false(has(foe, SPORES_BUFF), 'the chip lifted on the way out')
	assert_false(foe.has_status(Lancer.STATUS.SLOWED), 'and so did Slowed')
	assert_false(foe.has_status(Lancer.STATUS.IMPAIRED), 'and Impaired')

## And it comes back, which is what "are Slowed and Impaired" means for a zone.
##
## Reddened by: the same mutations.
func test_a_hostile_stepping_back_in_regains_both() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()
	UnitTile.move_to(foe, FAR_TILE)
	assert_false(foe.has_status(Lancer.STATUS.SLOWED), 'precondition: outside')

	UnitTile.move_to(foe, NEAR_TILE)

	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'back inside, Slowed again')
	assert_true(foe.has_status(Lancer.STATUS.IMPAIRED), 'and Impaired again')

## THE STATUSES ARE LOCKED WHILE THE HOSTILE IS INSIDE - buff.gd:133, and rulings row 2026-09-16.
## Nothing can strip them; the cloud is a condition of where you are standing. Recorded here because
## it is player-visible and a later frame reusing this channel inherits it.
##
## Reddened by: dropping applies_statuses (the status would never be there to survive the clear).
func test_the_statuses_cannot_be_cleared_while_the_hostile_stands_inside() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()
	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'precondition: Slowed by the cloud')

	UnitCondition.clear_status(SpecFactory.dummy_event(), foe, Lancer.STATUS.SLOWED)

	assert_true(foe.has_status(Lancer.STATUS.SLOWED),
		'clear_status touches only state.statuses; it lifts by leaving, and only by leaving')

## "Hostile CHARACTERS". A deployable standing in the cloud is untouched.
##
## Reddened by: applies_only_to_characters = false.
func test_a_hostile_deployable_is_untouched() -> void:
	var foe := hostile(NEAR_TILE)
	var prop := MyconidFixture.create_deployable(game, DIAGONAL_TILE)
	await press_protocol()

	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'control: a character at range IS caught')
	# Asked of the engine rather than hardcoded, because the deployable frame's own size decides
	# which of its tiles is nearest and the test must not silently drift out of the burst. The
	# control above and test_the_burst_is_measured_from_every_tile prove this range is live.
	assert_lte(UnitRelation.distance_between(myconid, prop), 2,
		'precondition: the deployable really is inside the burst')
	assert_false(prop.is_character(), 'precondition: and really is not a character')
	assert_false(has(prop, SPORES_BUFF), 'so the cloud does not touch it')
	assert_false(prop.has_status(Lancer.STATUS.SLOWED), 'no statuses either')

## The cloud does not choke the Myconid's own side.
##
## Reddened by: applies_to_allies = true on passive_fungal_network_hostiles.tres.
func test_an_ally_at_2_is_not_slowed() -> void:
	var friend := ally(NEAR_TILE)
	var foe := hostile(Vector2i(2, 4))
	await press_protocol()

	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'control: a hostile at the same range IS caught')
	assert_false(has(friend, SPORES_BUFF), 'an ally is not')
	assert_false(friend.has_status(Lancer.STATUS.SLOWED), 'and is not Slowed')

## Nor the Myconid itself. NOTE WHAT THIS CAN AND CANNOT PIN, corrected against measurement: on the
## hostile passive the two exclusion flags are MUTUALLY redundant, because a unit is its own ally
## (Faction.is_ally(f, f) is true, faction.gd:30). applies_to_self = false refuses the Myconid at
## passive_aura.gd:69; applies_to_allies = false would refuse it one line later at :70. So flipping
## EITHER alone leaves this test green - measured, mutations M04 and M10b - and no single-flag
## mutation reddens it. What it pins is the OUTCOME, which is the card. Rulings row 2026-09-16.
##
## Reddened by: opening BOTH flags on the hostile passive.
func test_the_myconid_is_not_caught_by_its_own_cloud() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()

	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'control: the hostile aura IS live')
	assert_false(has(myconid, SPORES_BUFF), 'and the Myconid is outside it')
	assert_false(myconid.has_status(Lancer.STATUS.SLOWED), 'it does not Slow itself')


# ========== C2. THE STATUSES ARE REAL TO THE ENGINE, AND APPLIED ONCE ==========
#
# PORTED FROM THE DELETED PROBE (SP2 Task 5 review). Deleting test_spike_status_aura.gd took three
# characterisations with it that nothing in section C replaces, and two of them are load-bearing for
# THIS content precisely because buff_fungal_network_spores.tres is a script-less .tres whose entire
# mechanism is applies_statuses: if that channel stops reaching the engine, nothing else here would
# say so. Re-asserted below against the real Kit and a real hostile, not the probe's synthetic Kit.
# The third - a SOURCE-QUALIFIED UnitCondition.has_status - was deliberately not ported; the file
# header says why.

## THE TEST THAT MATTERS MOST IN THIS FILE, and the one the probe's own commentary warned would be
## missing without it. Every other hostile-half test above asks has_status or is_slowed, and both of
## those read unit.state.cached_statuses (unit.gd:210-211) - the very array
## UnitCondition.get_current_statuses wrote when it folded in the buff's applies_statuses
## (unit_condition.gd:379-382). A status that lived only in that cache, consulted by nothing, would
## leave all of section C green over a dead mechanic.
##
## So ask an engine GATE instead. UnitAction.is_boost_prohibited (unit_action.gd:497-510) tests
## UnitCondition.is_slowed at :499, which is has_status for SLOWED or PRONE (unit_condition.gd:
## 407-411) - the same predicate the movement archetype consults before allowing a voluntary move
## (action_system_movement.gd:25). A hostile in the cloud is really refused a Boost, which is what
## the card's "Slowed" has to mean.
##
## Reddened by: M17 (applies_statuses = [impaired] on buff_fungal_network_spores.tres).
func test_a_hostile_in_the_cloud_is_really_refused_a_boost() -> void:
	var foe := hostile(NEAR_TILE)
	assert_false(UnitAction.is_boost_prohibited(foe),
		'control: the gate is OPEN before the press - without this the two below measure nothing')

	await press_protocol()

	assert_true(UnitCondition.is_slowed(foe), 'the engine predicate agrees with the cache')
	assert_true(UnitAction.is_boost_prohibited(foe), 'and an engine GATE acts on it')

## The other half of the same fact: the GATE follows the zone. A hostile that walks out of the cloud
## can Boost again, which is what makes this a zone rather than a status applied on the way in - and
## it is the gate, not just the chip, that lifts.
##
## Reddened by: M17.
func test_a_hostile_stepping_out_of_the_cloud_can_boost_again() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()
	assert_true(UnitAction.is_boost_prohibited(foe), 'precondition: the gate is shut while inside')

	UnitTile.move_to(foe, FAR_TILE)

	assert_false(UnitAction.is_boost_prohibited(foe),
		'the gate lifts with the zone, which is what "while inside" has to mean')

## THE RE-ENTRANT AURA PASS IS IDEMPOTENT, and the re-entry is real rather than theoretical.
## UnitCondition.apply_buffs sets update_tracking_and_statuses whenever the applying gear carries a
## PassiveAura (unit_condition.gd:713-714); post_apply_buff_cache_update then hands the real event to
## unit.update_cached_values_and_token (:775), which at unit.gd:158-160 calls UnitTile.move_to - a
## WHOLE FRESH aura pass. So applying the spore buff re-enters the pass that applied it. What stops
## that repeating is passive_aura.gd:80's has_buff skip and already_has_all_buffs (:95-96), both of
## which already see the buff because unit.state.buffs.append happens at unit_condition.gd:757,
## BEFORE on_application at :758 and long before the re-entry.
##
## HOW THIS DIFFERS FROM THE PROBE'S VERSION, which counted on_application calls from a Buff
## subclass: buff_fungal_network_spores.tres is script-less by design, so there is nothing to
## subclass without inventing content. The observable used instead is the BuffCore's IDENTITY. A
## re-application would NOT show up as a second chip - multiple_copies_can_stack is false by default
## (buff.gd:131), so apply_buff_alt clears the matching old one first (:741-747) - but it would
## replace the BuffCore, and BuffCore.create stamps a fresh random persistent_id on every instance
## (buff_core.gd:26-32, the id at :29). A stable id across a second pass is therefore the same fact
## the counter gave, read from the other end, and it catches the clear-and-re-apply case a bare count
## would miss.
##
## Reddened by: M16 (the spores buff listed TWICE on passive_fungal_network_hostiles.tres with
## multiple_copies_can_stack = true). That is the only way our content can reach a double application
## at all: the guard is engine-side, so no ordinary mutation of a .tres can force one.
func test_the_cloud_applies_its_chip_exactly_once_per_hostile() -> void:
	var foe := hostile(NEAR_TILE)
	await press_protocol()

	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'control: the cloud really did apply')
	var chips:Array[BuffCore] = UnitCondition.get_buffs(foe, SPORES_BUFF)
	assert_eq(chips.size(), 1, 'ONE chip for one hostile, however often the pass re-enters')
	if chips.is_empty(): return
	var first_id:StringName = chips.front().persistent_id

	UnitTile.update_tracking_and_statuses(game.map) # a whole further pass over a hostile already in

	var after:Array[BuffCore] = UnitCondition.get_buffs(foe, SPORES_BUFF)
	assert_eq(after.size(), 1, 'still exactly one after a second pass')
	if after.is_empty(): return
	assert_eq(after.front().persistent_id, first_id,
		'and the SAME BuffCore - the pass did not quietly clear and re-apply it')

## Two occupants, two applications: one each, not one between them and not one per re-entrant pass.
##
## NOT A STATEMENT ABOUT COST. The applications are linear in occupants; the WORK is not, and nothing
## here measures it. update_tracking_and_statuses loops every unit on the map (unit_tile.gd:20) and
## PassiveAura.update_unit loops them all again inside that (passive_aura.gd:28) - so one pass is
## already O(n^2), and per the note above each application triggers another whole pass.
##
## Reddened by: M16.
func test_a_second_hostile_is_one_more_chip_not_a_multiple() -> void:
	var first := hostile(NEAR_TILE)
	var second := hostile(Vector2i(2, 4)) # 2 from the (4,4) corner, the far side of the footprint
	await press_protocol()

	assert_true(first.has_status(Lancer.STATUS.SLOWED), 'control: the first really is in the cloud')
	assert_true(second.has_status(Lancer.STATUS.SLOWED), 'control: and so is the second')
	assert_eq(UnitCondition.get_buffs(first, SPORES_BUFF).size(), 1, 'one chip on the first')
	assert_eq(UnitCondition.get_buffs(second, SPORES_BUFF).size(), 1, 'and one on the second')


# ===================== D. THE PROTOCOL ITSELF =====================

## "For the rest of the scene" with no off switch: one press, and the button is gone.
##
## MEASURED, AND IT CORRECTS THE OBVIOUS ASSERTION. There are TWO refusals here, not one, and the
## one that wins is not the one this action arranges. get_gear_unavailable_reason is an elif chain,
## and `consumes_core_power() and not unit.core.has_core_power` sits at unit_action.gd:145 - NINE
## branches above `is_action_hibernating` at :154. So the reason reported after a press is
## NO_CORE_POWER (19), because the press spent the frame's core power, and REASON.HIBERNATING is
## unreachable while that holds.
##
## The hibernate is therefore belt-and-braces against the core power, and it is still worth having:
## it is what the card's "for the rest of the scene" actually says, it is independent of any future
## effect that refreshes core power mid-mission, and it is what takes the button off the bar rather
## than merely greying it. This test asserts BOTH - that the press is refused, and that the
## hibernation flag is really set - so that deleting the hibernate line still reddens something even
## though the refusal would survive it.
##
## Reddened by: deleting the hibernate_action line (the second assertion), or by anything that let a
## second press through (the first).
func test_a_second_press_in_the_same_scene_is_refused() -> void:
	await press_protocol()
	var gear := core_gear()
	assert_not_null(gear, 'precondition: the core Kit is on the frame')
	if gear == null: return

	var specific := SpecificAction.create(myconid, gear, gear.get_action(PROTOCOL_ID))
	assert_ne(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.NONE,
		'there is no second press')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.NO_CORE_POWER,
		'and the reason the player is shown is the spent core power, which outranks the hibernate')
	assert_true(gear.is_action_hibernating(PROTOCOL_ID),
		'the action hibernated itself all the same - that is what "rest of the scene" means')

## A protocol is confined to the protocol window. Without an open turn unit_action.gd:144 refuses it
## with REASON.PROTOCOL - which is also the failure mode every other test in this file would show if
## press_protocol() stopped opening a turn, so it is worth naming once.
##
## Reddened by: action_type = 1 (QUICK) on action_fungal_network.tres.
func test_the_protocol_is_refused_outside_the_protocol_window() -> void:
	var gear := core_gear()
	assert_not_null(gear, 'precondition: the core Kit is on the frame')
	if gear == null: return

	var specific := SpecificAction.create(myconid, gear, gear.get_action(PROTOCOL_ID))
	assert_false(myconid.state.is_using_protocols, 'precondition: no turn has been opened')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.PROTOCOL,
		'and a protocol is refused outside its window')


# ===================== E. THE ZONE DIES WITH ITS OWNER =====================

## The only way the cloud ends. Aura buffs carry the aura gear as from_gear (passive_aura.gd:82), and
## owner death clears them. NOTE, as the probe records, that this cannot isolate WHICH of three
## death-keyed paths in EventService.remove_unit_from_game does it - :66-68 deactivates the dead
## unit's auras, :71 clears the outgoing buffs, :92 re-runs the tracking pass. The OUTCOME is the
## card, and the outcome is what this pins.
##
## This test stays green with the feature deleted - it is a characterisation of engine cleanup, not
## of our content - and is here so a regression in that cleanup is not silent.
func test_the_myconids_death_strips_everything() -> void:
	var friend := ally(ADJACENT_TILE)
	var foe := hostile(NEAR_TILE)
	await press_protocol()
	assert_true(has(friend, ARMOR_BUFF), 'precondition: the ally half is up')
	assert_true(foe.has_status(Lancer.STATUS.SLOWED), 'precondition: the hostile half is up')

	await game.execute_event(&'event_unit_damage', {
		unit = myconid, number = 9999, category = Lancer.DAMAGE_TYPE.KINETIC,
	})

	assert_false(Unit.is_valid(myconid), 'precondition: the Myconid is dead')
	assert_true(Unit.is_valid(friend), 'precondition: the ally is not - assertions on a corpse measure nothing')
	assert_false(has(friend, ARMOR_BUFF), 'the shelter went with it')
	assert_false(has(friend, IMMUNITY_BUFF), 'both ally buffs')
	assert_false(has(foe, SPORES_BUFF), 'and the cloud lifted off the hostile')
	assert_false(foe.has_status(Lancer.STATUS.SLOWED), 'statuses included')


# ===================== F. THE CARD =====================

func test_the_core_kit_is_a_trait_on_the_frame() -> void:
	var gear := core_gear()
	assert_not_null(gear, 'the Myconid carries cp_quietus_machines')
	if gear == null: return
	assert_true(gear.kit.is_trait, 'as a frame trait, not equippable gear')

## The localisation rows are the LCP verbatim once the glossary pipes are stripped - the author's
## standing directive. Asserted through tr(), which is the compiled artifact's own lookup path - not
## a guard against a stale translation (test_myconid_frame.test_every_new_display_row_resolves reads
## the artifact directly for the core rows); the byte-exactness against the LCP itself is checked by
## script at the sub-project close.
func test_the_display_rows_resolve() -> void:
	assert_ne(tr('gear.cp_quietus_machines.name'), 'gear.cp_quietus_machines.name',
		'the core system has a name row')
	assert_ne(tr('gear.cp_quietus_machines.action_fungal_network.name'),
		'gear.cp_quietus_machines.action_fungal_network.name', 'and the protocol has one')
	assert_ne(tr('gear.cp_quietus_machines.action_fungal_network.effect'),
		'gear.cp_quietus_machines.action_fungal_network.effect', 'and an effect row')
	for buff_id:StringName in [IMMUNITY_BUFF, ARMOR_BUFF, SPORES_BUFF]:
		assert_ne(tr('gear.%s.name' % buff_id), 'gear.%s.name' % buff_id,
			'%s has a chip name row' % buff_id)

## Ruling 14: the LCP's core `description` is EMPTY, and vanilla leaves 189 of 431 kits without an
## .effect row, so an empty LCP field means NO ROW rather than invented prose. This is the guard on
## that - it asserts the row is ABSENT, which is the only way a later session cannot quietly add one.
func test_the_core_kit_has_no_effect_row_because_the_lcp_has_no_description() -> void:
	assert_eq(tr('gear.cp_quietus_machines.effect'), 'gear.cp_quietus_machines.effect',
		'no effect row: the LCP core description is empty and we do not write our own')
