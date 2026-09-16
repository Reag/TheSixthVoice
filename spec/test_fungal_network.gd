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
const ACTIVE_BUFF := &'buff_fungal_network_active' # the Myconid's own "the zone is running" chip

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
## THE PROP IS GROUND-LOCKED BY THE FIXTURE, AND WITHOUT THAT THIS TEST STOPS MEASURING ANYTHING.
## THE LOCK IS THE ENGINE'S OWN GUARD, NOT A SPEC TRICK AND NOT AN ENGINE BUG.
## UnitCondition.apply_lock_to_ground_height (unit_condition.gd:920-927) sets the flag for any unit
## whose gear carries a PassiveTerrainZone with terrain_data.obstruction, and its comment at :922
## names this exact frame: "jericho cover needs to ignore itself when determining its floor height".
## The engine runs it on every unit add (map_node_3d.gd:125) and from apply_buffs_from_passive_gear
## (unit_condition.gd:873), so a cover the GAME deploys is locked from birth and never climbs -
## ActionSystemDeploy builds the core WITH the frame before spawning (action_system_deploy.gd:117).
## What bypassed the guard was the FIXTURE'S SHAPE: FitzgeraldFixture.create_deployable took a
## SpecFactory.create_unit knockoff Everest (spec_factory.gd:76-77), let it be added to the map with
## the auto-setter running against that wrong frame, and only then swapped in dep_jericho_cover -
## and nothing recomputed the flag. Fixed at the source 2026-09-16 (SP2.5 Task 4 review): the
## fixture now calls apply_lock_to_ground_height itself, and that call's header carries the full
## account. The paragraphs below are what it costs THIS test when the flag is wrong.
##
## THE FIXTURE'S DEPLOYABLE IS A JERICHO COVER, and a Jericho cover is dynamic TERRAIN as well as a
## unit: its mt_obstruction_hard_cover trait writes an obstruction voxel (map_state.gd:427-433) and
## MapState raises the tile's surface to one above it (map_state.gd:462 and :467, whose own comment
## names the Jericho). An UNLOCKED cover then reads its effective_floor back OFF that surface
## (unit_tile.gd:211-218 via unit_battle_state.gd:226) - so on every single pass of
## UnitTile.update_tracking_and_statuses it climbs one layer onto its own roof, without bound.
## MEASURED 2026-09-16, SP2.5 Task 4: floor 1, 2, 3, 4, 5 ... over four bare tracking passes with no
## mod content involved at all.
##
## AND THE BURST IS A 3-D MEASUREMENT. distance_between is maxi(horizontal, vertical)
## (unit_relation.gd:13-25, the maxi at :25), the vertical term is get_elevation_distance_between
## (unit_tile.gd:320-321), and PassiveAura.is_within_range uses the full call because this passive
## leaves applies_regardless_of_elevation at false (passive_aura.gd:85). A levitating cover therefore
## leaves the burst VERTICALLY while sitting on the same tile, and the aura genuinely stops reaching
## it - at which point every negative assertion below passes for the wrong reason and the
## applies_only_to_characters mutation stops reddening anything.
##
## THIS TEST WAS SITTING ON EXACTLY THAT BOUNDARY. Before SP2.5 Task 4 the press ran just few enough
## passes to leave the prop at floor 4: vertical = 4 - (1 + 2 - 1) = 2, equal to the burst, margin
## ZERO. Task 4's chip is applied to the MYCONID by an aura, and UnitCondition.apply_buffs runs a
## whole further tracking pass whenever the applying gear carries a PassiveAura
## (unit_condition.gd:713-714) - one more pass, floor 5, vertical 3, out of the burst. Any content
## that applies one more aura buff would have done the same, so the fragility was the test's, not
## the chip's.
##
## HOW THE FLAG BUYS THE MARGIN BACK: effective_floor_alt reads elevation_ground instead of the
## obstruction-raised surface when it is set (unit_tile.gd:213-214), and ground_height is not raised
## by the cover. Measured with it: floor 1, unmoved over seven passes, distance a stable 2, the prop
## still untouched and the control hostile still Slowed.
##
## THE LINE THAT USED TO BE IN THIS TEST IS GONE. Between 2026-09-16 and this review the body set
## `prop.state.lock_to_ground_height = true` by hand. That asserted the right value for the wrong
## reason - it hardcoded one unit's flag instead of DERIVING it from the frame, and left the six
## other specs sharing create_deployable on the same stale flag. The fixture call replaces it, and
## the T4-M6/M7 pair was re-run against this shape to prove the test still discriminates.
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
	for buff_id:StringName in [IMMUNITY_BUFF, ARMOR_BUFF, SPORES_BUFF, ACTIVE_BUFF]:
		assert_ne(tr('gear.%s.name' % buff_id), 'gear.%s.name' % buff_id,
			'%s has a chip name row' % buff_id)

## Ruling 14: the LCP's core `description` is EMPTY, and vanilla leaves 189 of 431 kits without an
## .effect row, so an empty LCP field means NO ROW rather than invented prose. This is the guard on
## that - it asserts the row is ABSENT, which is the only way a later session cannot quietly add one.
func test_the_core_kit_has_no_effect_row_because_the_lcp_has_no_description() -> void:
	assert_eq(tr('gear.cp_quietus_machines.effect'), 'gear.cp_quietus_machines.effect',
		'no effect row: the LCP core description is empty and we do not write our own')


# ===================== G. THE CHIP ON THE MYCONID ITSELF =====================
#
# SP2.5 Task 4, and the author's words: "we should probably put a dummy chip on the Myconid that has
# activated Fungal Network (shares icon with the core power) so that you can tell its running at a
# glance."
#
# WHAT IT IS. buff_fungal_network_active.tres - a plain Buff with no `to`, no statuses and no
# triggers, put on the Myconid alone by a THIRD PassiveAura on the same Kit
# (passive_fungal_network_self.tres). It exists to be DRAWN, and nothing else about a Buff is
# consulted to get it drawn: mech_info.gd:34 and tooltip_organ_unit.gd:130 both filter the unit's
# buff list on hide_from_player and on nothing else, so a visible buff IS a chip however empty it is.
#
# WHY A THIRD AURA RATHER THAN AN apply_buff INSIDE THE PROTOCOL. is_aura_active is per-GEAR, not
# per-passive (SP2 Task 3's finding: UnitPrinter.prep_for_initial_spawn sets one flag per piece of
# gear and pulls it down if ANY PassiveAura on the Kit declares starts_active = false,
# unit_printer.gd:19-21; UnitCondition does the same at unit_condition.gd:880 and :899 - NOT
# full_repair, which SP2 Task 3 named and the SP2.5 Task 4 review corrected: it takes a UnitCore
# (unit_printer.gd:61) and never touches the flag). So a PassiveAura on this Kit reads the very flag
# the zone runs on, and is cleared and applied by the very pass that clears and applies the zone
# (passive_aura.gd:37, :55-59, :62-64). There is one lifetime, and the chip cannot be up while the
# zone is down or the reverse.
#
# A buff applied by action_fungal_network.gd's activate() would be a SECOND lifetime with nothing to
# end it. The flag is pulled down by paths the protocol never sees - a mid-mission gear reapplication
# reaches unit_condition.gd:899, death reaches event_service.gd:67 - and a hand-applied chip would
# survive all of them and go on announcing a zone that had stopped. That is the failure this section
# exists to hold shut, and test_the_chip_is_gone_when_the_zone_is_down is the test that holds it.
#
# WHY THIS SECTION IS LAST RATHER THAN NEXT TO THE PROTOCOL. The section letters are cited from
# OUTSIDE this file - action_fungal_network.gd's header names "section E" for the death test - so
# inserting a letter in the middle would silently mis-point that comment at the wrong section.
# Appending breaks nothing.

## THE WHOLE POINT: press it, and the Myconid says so at a glance.
##
## THE LAST ASSERTION IS WHAT MAKES IT A CHIP rather than merely a buff. Both things that draw a
## unit's conditions filter on hide_from_player alone (mech_info.gd:34, tooltip_organ_unit.gd:130),
## so an effect-less buff really is rendered - and an effect-less buff with hide_from_player is
## rendered by nothing at all and would be a silent no-op that every other assertion here still
## passes.
##
## Reddened by: T4-M1, dropping passive_fungal_network_self.tres from cp_quietus_machines.tres's
## passives - i.e. never applying the buff.
func test_pressing_the_protocol_chips_the_myconid() -> void:
	UnitTile.update_tracking_and_statuses(game.map)
	assert_false(has(myconid, ACTIVE_BUFF),
		'control: a whole aura pass runs before the press and does NOT chip it')

	await press_protocol()

	assert_true(has(myconid, ACTIVE_BUFF), 'and the press does')
	var chips:Array[BuffCore] = UnitCondition.get_buffs(myconid, ACTIVE_BUFF)
	assert_eq(chips.size(), 1, 'exactly one chip, however often the aura pass re-enters')
	if chips.is_empty(): return
	assert_false(chips.front().base.hide_from_player,
		'and the player can see it - a hidden buff is drawn by nothing')

## "It goes on the Myconid only - not on allies, not on hostiles. They already carry their own
## chips." THREE POSITIVE CONTROLS, because three negative assertions over units nothing reached
## would pass just as well with the whole Kit dark.
##
## Reddened by: T4-M2, listing buff_fungal_network_active on passive_fungal_network_allies.tres
## instead - applying it through one of the BROADCAST auras. That moves it onto every adjacent ally
## AND off the Myconid at the same time, because that passive sets applies_to_self = false.
func test_the_chip_is_on_the_myconid_and_nobody_else() -> void:
	var friend := ally(ADJACENT_TILE)
	var foe := hostile(NEAR_TILE)
	var distant := ally(FAR_TILE)

	await press_protocol()

	assert_true(has(myconid, ACTIVE_BUFF), 'control: the Myconid wears it')
	assert_true(has(friend, ARMOR_BUFF), 'control: the ally cloud DID reach the adjacent ally')
	assert_true(has(foe, SPORES_BUFF), 'control: and the hostile cloud DID reach the hostile')

	assert_false(has(friend, ACTIVE_BUFF), 'the sheltered ally does not wear it')
	assert_false(has(foe, ACTIVE_BUFF), 'nor the choked hostile')
	assert_false(has(distant, ACTIVE_BUFF), 'nor an ally standing outside both clouds')

## THE LIFETIME, AND THE WHOLE REASON THE CHIP IS AN AURA. The chip must not be able to outlive the
## zone it announces.
##
## WHY THIS REACHES FOR THE FLAG DIRECTLY. Ruling 6 gives this card no off switch - the zone runs
## "for the rest of the scene" and the protocol hibernates itself - so there is no in-game button
## that turns it off for a spec to press. GearCore.set_aura_active (gear_core.gd:297) is the same
## call the protocol makes, with false instead of true, and it is the single flag every other path
## that darkens an aura also writes (unit_condition.gd:899 on a gear reapplication,
## event_service.gd:67 on death). Asserting against it is asserting against all of them.
##
## THE ALLY CONTROL IS NOT DECORATION: it is what proves the zone really went down in that call, so
## that the chip's absence is the chip FOLLOWING the zone rather than the chip never having been
## there. The preconditions above it prove both were up first.
##
## "THE ZONE" HERE MEANS THE AURAS, NOT THE GROUND CLOUD. Since SP2.5 Task 5 the Kit also carries a
## PassiveDynamicZone on a SECOND per-gear flag, and set_aura_active does not touch it
## (gear_core.gd:298 writes one field) - so the cloud is still drawn after the call below. That is
## not a bug and not a gap: no path in the game makes this call, which is why nothing in section H
## uses it. Read section H's header before concluding the two are out of step.
##
## Reddened by: T4-M3, applying the chip from action_fungal_network.gd's activate() with
## UnitCondition.apply_buff instead of from the passive - the parallel lifetime nothing clears.
func test_the_chip_is_gone_when_the_zone_is_down() -> void:
	var friend := ally(ADJACENT_TILE)
	await press_protocol()
	var gear := core_gear()
	assert_not_null(gear, 'precondition: the core Kit is on the frame')
	if gear == null: return
	assert_true(has(myconid, ACTIVE_BUFF), 'precondition: the chip is up')
	assert_true(has(friend, ARMOR_BUFF), 'precondition: and so is the zone it stands for')

	gear.set_aura_active(false, myconid)

	assert_false(has(friend, ARMOR_BUFF), 'control: the zone really did go down')
	assert_false(has(myconid, ACTIVE_BUFF), 'and the chip went with it, in the same pass')

## A DUMMY CHIP: it announces the zone and does nothing else. The card gives the Myconid itself
## nothing, so a chip on it that carried a `to` would be a rules change nobody asked for - and a
## quiet one, since every other test in this file would stay green.
##
## THE ALLY IS THE POSITIVE CONTROL ON BOTH HALVES: buff_fungal_network_armor is a chip from this
## same press that DOES carry a `to` (&"statblock"), so the armor readout moving on the ally and not
## on the Myconid is one measurement of the difference, and has_buff_to answering for the ally and
## not for the Myconid is the other. Without them, two assertions that a number did not move and a
## query found nothing would pass with the whole cloud dark.
##
## Reddened by: T4-M4, giving buff_fungal_network_active.tres a `to` - to = &"statblock" with a
## Statblock of armor 1 reddens the readout assertion, the query assertion and the `to` assertion at
## once.
func test_the_chip_carries_no_mechanical_effect() -> void:
	var friend := ally(ADJACENT_TILE)
	var myconid_armor:int = myconid.get_armor()
	var friend_armor:int = friend.get_armor()

	await press_protocol()

	var chips:Array[BuffCore] = UnitCondition.get_buffs(myconid, ACTIVE_BUFF)
	assert_eq(chips.size(), 1, 'precondition: the Myconid is wearing the chip')
	if chips.is_empty(): return
	var chip:Buff = chips.front().base

	assert_eq(friend.get_armor(), friend_armor + 1,
		'control: a chip from this same press that DOES carry a `to` moves a number (unit.gd:309)')
	assert_true(UnitCondition.has_buff_to(friend, Buff.TO.STATBLOCK),
		'control: and answers the query that moved it')

	assert_eq(myconid.get_armor(), myconid_armor, 'the Myconid is no tougher for wearing this one')
	assert_false(UnitCondition.has_buff_to(myconid, Buff.TO.STATBLOCK),
		'and it answers no such query')
	assert_eq(chip.to, Buff.TO.NONE, 'because it declares no channel at all')
	assert_true(chip.applies_statuses.is_empty(), 'nor any status')
	assert_true(chip.triggers_on.is_empty(), 'and nothing active either: it exists to be seen')


# ===================== H. THE GROUND CLOUD =====================
#
# SP2.5 Task 5, and the author's words after playtesting: "I dont see a FX for the cloud." They chose
# a zone effect on the ground so the burst-2 edge is visible in play.
#
# WHAT IT IS. passive_fungal_network_zone.tres - a PassiveDynamicZone, the FOURTH passive on
# cp_quietus_machines, drawing the reused vanilla scene res://content/fx_endless/gear/aura/
# fxe_nanites.tscn at every tile of the burst. It applies no buff, no status and no rule; that file's
# header says why that scene, and why every gameplay knob on its DynamicZone is left at the inert
# default.
#
# ============ WHAT THESE TESTS PROVE, AND WHAT THEY DO NOT ============
#
# AN FX IS HARD TO ASSERT ON, so it is worth being exact about where these stop.
#
# THEY PROVE, as far as live nodes in the scene tree: after the press, the Myconid's token owns an
# FxEndlessController (unit_token.gd:53) whose fxe_map holds one instantiated FxEndless per tile of
# the burst, each with id `fxe_nanites`. That is the real chain, not a stand-in for it -
# UnitToken.update_attached_fx walks every passive on every piece of gear and feeds each returned
# ticket to FxEndlessController.reconstruct_add (unit_token.gd:209-219), which instantiates the
# scene ContentLibrary maps that id to and add_child()s it (fx_endless_controller.gd:72-78 into
# :88-91). Nothing here fakes a step of that.
#
# THEY DO NOT PROVE THAT ANYTHING IS VISIBLE. Not one assertion below looks at the viewport. A node
# that exists at the right tile may still be invisible, mis-coloured, the wrong size, at the wrong
# height, or drawn under the terrain, and every test in this section would stay green. The height
# lock in particular - LOCK_TO.SURFACE, which is what makes this "on the ground" rather than at the
# token's centre (fx_endless.gd:11-18) - is a property of a VANILLA scene we reference and is not
# measured here at all. Whether the cloud reads as a cloud is the author's call in play, and the
# playtest note this task answers is exactly the evidence a spec cannot produce.
#
# THEY ALSO DO NOT PROVE the picture matches the ALLY half. It deliberately does not: the ally aura
# is range 1 and the cloud is drawn at 2, because two nested clouds would be two pictures. Only the
# hostile half's footprint is checked against the drawing, in
# test_the_cloud_is_drawn_over_the_burst_the_hostile_half_catches.
#
# ============ THE TWO FLAGS, WHICH ARE THE REAL RISK ============
#
# The cloud does NOT ride the is_aura_active flag the three PassiveAuras follow. PassiveDynamicZone
# is gated on gear.is_dynamic_zone_active (passive_dynamic_zone.gd:13-14), declared three lines above
# the aura flag on the same object (gear_core.gd:25 and :28). A picture on a lifetime of its own
# could outlive the mechanic it draws, so the writers of both flags were traced before this was
# built, and there are exactly four:
#
#   spawn          unit_printer.gd:16-21       both set true, each then pulled down by its own
#                                              passive type's starts_active. PAIRED.
#   gear reapply   unit_condition.gd:879-880   both set true...
#                  unit_condition.gd:898-899   ...and each pulled down the same way. PAIRED.
#   owner death    event_service.gd:65-68      both set false under one comment, "all auras and
#                                              zones turn off". PAIRED.
#   the setters    gear_core.gd:293 and :297   set_dynamic_zone_active / set_aura_active. The ONLY
#                                              unpaired writers - and nothing in engine/ calls
#                                              either. Every caller in the tree is content:
#                                              the Drake's Fortress Protocol, Hardlight Defense
#                                              System, and our own action_fungal_network.gd.
#
# So the flags cannot drift on their own. They can only be driven apart by the one script that drives
# them, which is why action_fungal_network.gd now sets both, and why
# test_the_two_activation_flags_never_disagree asserts their VALUES against each other at all three
# stages rather than trusting that paragraph.
#
# ONE CONSEQUENCE FOR READERS OF SECTION G. That section darkens the zone with
# `gear.set_aura_active(false, myconid)`, and THAT CALL DOES NOT PUT THE CLOUD OUT - it writes one
# flag (gear_core.gd:298) and never touches the other. Measured, not assumed: the Task 5 probe pressed
# the protocol, made that call, and read is_aura_active=false alongside is_dynamic_zone_active=true.
# It is a synthetic lever no path in the game pulls on this Kit - ruling 6 gives this card no off
# switch - so nothing below uses it. The cloud's lifetime is tested on the path the game really
# takes, the owner's death, which writes both.

# ---------------------------------------------------------------- section H helpers

const CLOUD_FXE := &'fxe_nanites' # the reused vanilla scene; FxEndless ids are scene BASENAMES
const CLOUD_RADIUS := 2           # passive_fungal_network_zone.tres, matching the hostile aura

func zone_passive() -> PassiveDynamicZone:
	var gear := core_gear()
	if gear == null: return null
	for passive:Passive in gear.kit.passives:
		if passive is PassiveDynamicZone: return passive
	return null

## The tiles the Myconid's token is ACTUALLY drawing the cloud on, read back off the live
## FxEndlessController rather than off the passive that fed it. fxe_map is keyed by the ticket's
## LOCAL tile (passive_dynamic_zone.gd:27 stores global - unit.tile()), so it is shifted back here.
func drawn_cloud_tiles() -> Array[Vector2i]:
	var out:Array[Vector2i] = []
	if not Unit.is_valid(myconid) or not is_instance_valid(myconid.token): return out
	var controller:FxEndlessController = myconid.token.AttachedFxEndless
	if not is_instance_valid(controller): return out
	for local_tile:Vector2i in controller.fxe_map.keys():
		for fxe in controller.fxe_map[local_tile]:
			if is_instance_valid(fxe) and fxe.id == CLOUD_FXE:
				out.append(local_tile + myconid.tile())
				break
	return out

## What the burst SHOULD cover, worked out here from the Myconid's footprint instead of asked of the
## engine - UnitTile.get_tiles_within is the function under test, so using it to build the
## expectation would assert nothing. Chebyshev over closest tiles is what "burst N from a size-2
## unit" means on this board: distance_between takes its horizontal reading from
## closest_tiles_between (unit_relation.gd:16 into :30-31), which minimises Tile.distance, and that
## is max(dx, dy) (tile.gd:380-387). Ruling 6.
func chebyshev_to_myconid(tile:Vector2i) -> int:
	var nearest := 99
	for occupied:Vector2i in myconid.occupied_tiles():
		nearest = mini(nearest, maxi(absi(tile.x - occupied.x), absi(tile.y - occupied.y)))
	return nearest

## Every on-map tile within CLOUD_RADIUS of the footprint, EXCLUDING the footprint itself
## (is_fxe_at_unit_tiles = false). On the default 15x9 map with the Myconid at (4,4) this is the 6x6
## block (2,2)..(7,7) less its four middle tiles: 36 - 4 = 32 tiles, none of them clipped by an edge.
func expected_cloud_tiles() -> Array[Vector2i]:
	var out:Array[Vector2i] = []
	for y:int in game.map.size.y:
		for x:int in game.map.size.x:
			var tile := Vector2i(x, y)
			var distance := chebyshev_to_myconid(tile)
			if distance > 0 and distance <= CLOUD_RADIUS: out.append(tile)
	return out

## ONE assertion instead of thirty-two, and a readable failure either way round.
func assert_cloud_covers(expected:Array[Vector2i], context:String) -> void:
	var drawn := drawn_cloud_tiles()
	var missing:Array = expected.filter(func(tile:Vector2i) -> bool: return not drawn.has(tile))
	var extra:Array = drawn.filter(func(tile:Vector2i) -> bool: return not expected.has(tile))
	assert_eq(drawn.size(), expected.size(), '%s: %s tiles drawn' % [context, expected.size()])
	assert_true(missing.is_empty(), '%s: nothing missing from the cloud (missing %s)' % [context, missing])
	assert_true(extra.is_empty(), '%s: and nothing outside it (extra %s)' % [context, extra])


## THE FLOOR OF THE WHOLE SECTION: a dark protocol draws nothing, and the SAME query finds the cloud
## once it is pressed. The control is what makes the first half mean anything - "nothing is drawn" is
## also what an unset `fxe` and a misspelt scene id produce, since get_attached_fx returns [] for a
## blank id before it ever consults the flag (passive_dynamic_zone.gd:19). The precondition above
## covers the third way to ship no picture, the passive simply not being on the Kit.
##
## Reddened by: T5-M2, starts_active = true on passive_fungal_network_zone.tres.
func test_the_ground_cloud_is_dark_before_the_protocol() -> void:
	var gear := core_gear()
	assert_not_null(gear, 'precondition: the core Kit is on the frame')
	if gear == null: return
	var zone := zone_passive()
	assert_not_null(zone, 'precondition: the Kit carries a PassiveDynamicZone')
	if zone == null: return

	myconid.update_token() # a full fx rebuild happens before the press, and still draws nothing
	assert_false(gear.is_dynamic_zone_active, 'the zone flag is down at spawn')
	assert_true(zone.get_attached_fx(gear, myconid).is_empty(), 'so the passive offers no tickets')
	assert_eq(drawn_cloud_tiles().size(), 0, 'and the token is drawing no cloud')

	await press_protocol()

	assert_gt(drawn_cloud_tiles().size(), 0,
		'control: the very same query DOES find the cloud once the protocol is pressed')

## THE WHOLE POINT, asserted as far down the chain as a spec can reach: after the press there is a
## live FxEndless node parented to the Myconid's token controller at every tile of the burst, and
## every one of them is the scene this passive names. See the section header for what that still does
## NOT say about anything being visible.
##
## Reddened by: T5-M1 (dropping passive_fungal_network_zone.tres from cp_quietus_machines.tres) and
## T5-M4 (dropping the set_dynamic_zone_active line from action_fungal_network.gd) - two different
## ways to ship the card with no picture.
func test_pressing_the_protocol_raises_the_ground_cloud() -> void:
	assert_eq(drawn_cloud_tiles().size(), 0, 'control: nothing is drawn before the press')

	await press_protocol()

	assert_cloud_covers(expected_cloud_tiles(), 'after the press')

	# ...and it is really the named scene, instantiated, not an empty ticket or some other fx.
	var controller:FxEndlessController = myconid.token.AttachedFxEndless
	var live_nodes := 0
	var foreign_ids:Array[StringName] = []
	for local_tile:Vector2i in controller.fxe_map.keys():
		for fxe in controller.fxe_map[local_tile]:
			if not is_instance_valid(fxe): continue
			if fxe.id == CLOUD_FXE: live_nodes += 1
			elif not foreign_ids.has(fxe.id): foreign_ids.append(fxe.id)
	assert_eq(live_nodes, expected_cloud_tiles().size(), 'one live FxEndless per tile of the burst')
	assert_true(foreign_ids.is_empty(),
		'and every one of them is that scene, not another fx (found %s)' % [foreign_ids])
	assert_ne(ContentLibrary.get_fxendless_path(CLOUD_FXE), '',
		'the id resolves through ContentLibrary, which is how reconstruct_add found the scene')

## THE PICTURE AND THE RULE ON THE SAME THREE TILES. This is the test that earns the radius: each
## tile is asserted twice over, once for what the board SHOWS and once for what the hostile half
## DOES, and the two are computed by unrelated code - UnitTile.get_tiles_within for the drawing
## (passive_dynamic_zone.gd:24), UnitRelation.distance_between for the aura (passive_aura.gd:85).
## A cloud drawn at the wrong radius passes every other test in this section.
##
## DIAGONAL_TILE is the one that matters most: it is 2 from the Myconid's NON-anchor corner and 3
## from its anchor, so a drawing measured from the anchor alone would leave it clear while the
## hostile standing on it choked.
##
## Reddened by: T5-M5, radius = 1 on the DynamicZone sub-resource - which shrinks the picture and
## leaves NEAR_TILE and DIAGONAL_TILE Slowed under clear ground.
func test_the_cloud_is_drawn_over_the_burst_the_hostile_half_catches() -> void:
	var near_foe := hostile(NEAR_TILE)
	var diagonal_foe := hostile(DIAGONAL_TILE)
	var far_foe := hostile(FAR_TILE)

	await press_protocol()
	var drawn := drawn_cloud_tiles()

	assert_true(drawn.has(NEAR_TILE), 'the cloud is drawn at range 2...')
	assert_true(has(near_foe, SPORES_BUFF), '...where the hostile half catches')
	assert_true(drawn.has(DIAGONAL_TILE), 'and on the non-anchor diagonal...')
	assert_true(has(diagonal_foe, SPORES_BUFF), '...where it also catches')

	assert_false(drawn.has(FAR_TILE), 'and NOT at range 3...')
	assert_false(has(far_foe, SPORES_BUFF), '...where it does not catch either')

## The cloud is a ring around the frame, not a blanket over it: a particle haze on the Myconid's own
## four tiles would hide the mech, and both vanilla HORUS nanite zones leave them clear for the same
## reason (mt_hive_drone.tres, ms_swarm_body.tres). It also makes the drawn set exactly the set of
## tiles a hostile can stand in and be caught.
##
## THE POSITIVE CONTROL IS THE RING one tile out from each of those four: without it, "the footprint
## is clear" would pass just as well with the whole cloud dark.
##
## Reddened by: T5-M6, is_fxe_at_unit_tiles = true.
func test_the_cloud_leaves_the_myconids_own_tiles_clear() -> void:
	await press_protocol()
	var drawn := drawn_cloud_tiles()
	var occupied := myconid.occupied_tiles()
	assert_eq(occupied.size(), 4, 'precondition: the Myconid is size 2 and holds four tiles')

	for tile:Vector2i in occupied:
		assert_false(drawn.has(tile), 'no haze on %s, which the frame is standing on' % [tile])

	for tile:Vector2i in [Vector2i(3, 4), Vector2i(6, 4), Vector2i(4, 3), Vector2i(4, 6)]:
		assert_true(drawn.has(tile),
			'control: %s is one step off the footprint and IS drawn' % [tile])

## THE FLAG-AGREEMENT GUARD, and the reason this task was worth doing carefully. The cloud rides
## is_dynamic_zone_active and the three auras ride is_aura_active; if the two ever disagree the board
## shows a burst that is not there, or hides one that is. Asserted at all three stages the engine
## writes them - spawn, the press, the owner's death - and asserted AGAINST EACH OTHER, so the test
## fails whichever of the two goes wrong.
##
## THE ALLY IS THE POSITIVE CONTROL ON THE LAST STAGE: it proves the death really tore the mechanic
## down, so that "both flags false" is the pair agreeing rather than a corpse answering anything.
##
## Reddened by: T5-M4, dropping set_dynamic_zone_active from action_fungal_network.gd - after which
## the press lights the auras and leaves the zone dark, and the middle stage disagrees.
func test_the_two_activation_flags_never_disagree() -> void:
	var friend := ally(ADJACENT_TILE)
	var gear := core_gear()
	assert_not_null(gear, 'precondition: the core Kit is on the frame')
	if gear == null: return

	assert_eq(gear.is_dynamic_zone_active, gear.is_aura_active, 'at spawn the two flags agree')
	assert_false(gear.is_aura_active, 'and they agree on DARK (unit_printer.gd:16-21)')

	await press_protocol()

	assert_eq(gear.is_dynamic_zone_active, gear.is_aura_active, 'after the press they still agree')
	assert_true(gear.is_aura_active, 'and they agree on LIT')
	assert_true(has(friend, ARMOR_BUFF), 'control: the mechanic really is up')

	await game.execute_event(&'event_unit_damage', {
		unit = myconid, number = 9999, category = Lancer.DAMAGE_TYPE.KINETIC,
	})

	assert_false(Unit.is_valid(myconid), 'precondition: the Myconid is dead')
	assert_eq(gear.is_dynamic_zone_active, gear.is_aura_active, 'and after death they agree again')
	assert_false(gear.is_aura_active, 'on DARK (event_service.gd:65-68 writes both)')
	assert_false(has(friend, ARMOR_BUFF), 'control: the mechanic really did go down with it')

## The cloud ends the one way the card allows - see section E. Asked of the PASSIVE rather than of the
## token, because the token goes with the unit and a dead Myconid has none; get_attached_fx is safe on
## a corpse precisely because should_show_attached_fx is consulted before the unit is touched
## (passive_dynamic_zone.gd:19 returns [] before reaching UnitTile.get_tiles_within at :24).
##
## THE PRE-DEATH READING IS THE CONTROL, and it is not optional: an empty ticket list is ALSO what an
## unset fxe or a misspelt scene id produces (passive_dynamic_zone.gd:19 returns [] for a blank id),
## so "empty after death" on its own would be green for three different reasons.
##
## WHAT IT CHARACTERISES. The behaviour is the ENGINE'S - event_service.gd:65-68 puts both flags down
## on the owner's death and our content asks nothing of it - so, like section E's death test, this
## pins an outcome rather than a line of ours. Unlike section E's, it does NOT stay green with the
## feature deleted: the precondition catches that (T5-M1). What it guards is a regression in that
## cleanup, which would leave a cloud hanging over a wreck with nothing left to announce.
func test_the_cloud_goes_out_with_its_owner() -> void:
	await press_protocol()
	var gear := core_gear()
	var zone := zone_passive()
	assert_not_null(zone, 'precondition: the Kit carries a PassiveDynamicZone')
	if zone == null: return
	assert_gt(zone.get_attached_fx(gear, myconid).size(), 0, 'control: the cloud was up')

	await game.execute_event(&'event_unit_damage', {
		unit = myconid, number = 9999, category = Lancer.DAMAGE_TYPE.KINETIC,
	})

	assert_false(Unit.is_valid(myconid), 'precondition: the Myconid is dead')
	assert_false(gear.is_dynamic_zone_active, 'the zone flag went down with it')
	assert_true(zone.get_attached_fx(gear, myconid).is_empty(), 'and the cloud offers no tickets')

## A DynamicZone IS A RULES OBJECT, and this one is registered with the map like any other
## (map_state.gd:435-438). Every rule it could carry is a separate export left at its inert default,
## because this task is a picture and not a balance change.
##
## OF THE FOUR KNOBS CHECKED BELOW, THREE ARE CHECKED BY OUTCOME rather than by reading the export:
## the zone's absence from map.dynamic_zones_that_affect_sight and from shape.effect_barrier_shards
## are things MapState.update_tile_tracking did or did not do (map_state.gd:439-442), and
## is_guide_checked is the very function UnitTile.get_tiles_with_guide calls at unit_tile.gd:755. So
## a knob flipped by hand on the sub-resource is caught by what it would DO.
##
## THE FOURTH IS NOT, AND IT IS WORTH SAYING SO. `can_cross_boundary` is asserted as a raw property,
## because the only places it does anything are inside a path computation (pathfinder.gd:172 and
## :361) and inside a move event (event_unit_move.gd:388), and reaching either needs a movement
## fixture this file does not have. That assertion therefore proves the export is at its default and
## NOT that a unit can walk out of the cloud. Recorded as a deliberate gap rather than dressed up.
##
## THE FIRST ASSERTION IS THE POSITIVE CONTROL for the two that follow: the zone really IS in the
## map's list, so "not in the sight list" and "not in the barrier list" are exclusions rather than an
## unregistered zone being absent from everything.
##
## Reddened by: T5-M7, can_see_into = false on the DynamicZone sub-resource - which puts the cloud
## into dynamic_zones_that_affect_sight (map_state.gd:439-440) and makes a decoration block line of
## sight for every unit on the board; T5-M10, can_effects_cross_boundary = false, which fences every
## effect at the cloud's edge; and T5-M8, ai_guides = AVOID_TRY, which makes the AI treat the
## decoration as dangerous ground.
func test_the_ground_zone_is_a_picture_and_not_a_rule() -> void:
	await press_protocol()
	UnitTile.update_tracking_and_statuses(game.map)

	assert_eq(game.map.dynamic_zones.size(), 1,
		'control: the cloud is registered with the map as a real dynamic zone')
	assert_eq(game.map.dynamic_zones_that_affect_sight.size(), 0,
		'and blocks no line of sight (map_state.gd:439-440 never collected it)')
	assert_eq(game.map.shape.effect_barrier_shards.size(), 0,
		'and fences no effects (map_state.gd:441-442 never collected it either)')

	var zone := zone_passive()
	assert_not_null(zone, 'precondition: the Kit carries a PassiveDynamicZone')
	if zone == null: return
	assert_true(zone.dynamic_zone.can_cross_boundary,
		'and fences no movement - pathfinder.gd:172 and :361 only act when this is false')
	for guide:int in Zone.GUIDE.values():
		assert_false(zone.dynamic_zone.is_guide_checked(guide),
			'and steers the AI nowhere: no guide %s (unit_tile.gd:755)' % [guide])
