# Grit Latch Magnets, REINFORCEMENT BLAST (Fitzgerald rank III, SP4 Task 3 + Task 4).
#
# Card: "|Limited| 3, |Unique|. (Quick) Spend a charge and choose a Blast 1 area within Sensors. All
# characters within the area gain 1 armor until the end of your next turn."
#
# ================================ READ THIS BEFORE TRUSTING A GREEN ================================
#
# THE MECHANIC IS A PAIR OF BUFFS, AND unit.get_armor() IS PROOF OF ONLY ONE OF THEM.
#
# The engine has no channel that grants real armor. Incoming damage reads unit.core.current.armor
# (damage_modifications.gd:97), which is assigned in exactly two places repo-wide (unit_printer.gd:35
# and :73, both = core.get_armor() = frame.stat.armor + core.bonus.armor) and rebuilt only by
# UnitPrinter.recalculate_bonuses from pilot HASE, stat_override, NPC tier blocks and the
# PassiveStatIncrease passives of EQUIPPED GEAR. No buff channel writes it. So the card's one line of
# rules text is two resources, ruled by the author 2026-09-14 (rulings.md row 37, design §5.2's
# RESOLVED block), applied together by the one action:
#
#   buff_reinforcement_blast            Task 3. Buff.TO.STATBLOCK, armor = 1, VISIBLE. What the unit
#                                       readout shows and what every unit.get_armor() gate reads -
#                                       this mod's own Ripper Mod included, so a unit under
#                                       REINFORCEMENT BLAST does take the Ripper Mod's bonus die.
#                                       IT REDUCES NO INCOMING DAMAGE WHATSOEVER.
#   buff_reinforcement_blast_reduction  Task 4. A BuffResistDamage subclass, hidden. The half that
#                                       actually blunts the hit.
#
# THE TWO HALVES ARE TESTED THROUGH TWO DIFFERENT GETTERS, ON PURPOSE. Every test above the "TASK 4"
# divider reads unit.get_armor(), and get_armor() ALONE IS NOT PROOF THE ARMOR WORKS: every one of
# them passed against the STATBLOCK-only build that mitigated nothing, which is precisely how the SP4
# blocker was found (SP3's spec/test_ripper_mod.gd test_temporary_armor_counts is the executable
# proof of it, and its RED log for this file is .superpowers/sdd/sp4-t4-red.log). Every test BELOW
# that divider reads core.current.health (or core.current.heat) after a real hit and never touches an
# armor getter. Do not "simplify" a mitigation test into an armor assertion: it would go green
# against a build with no reduction buff at all.
#
# ===================================================================================================
#
# HOW A TILE-TARGETED BLAST IS DRIVEN FROM A SPEC. ActionSystemApplyBuff.activate, when its
# target_requirements_override carries a non-BURST RangePattern, takes the chosen tile, expands the
# AoE and reassigns target_units to map.get_all_units_at_tiles(aoe_tiles, specific.unit) filtered
# through can_target_unit (action_system_apply_buff.gd:113-118). That second argument is a VISIBILITY
# ASKER, not an exclusion - self is in the list when self is in the blast. Supplying target_tiles to
# event_gear_activate sets player_decides = false in ask_for_targets_alt
# (target_action_util.gd:194-195), so the supplied tile is used automatically and no prompt is
# raised: no mod-private choice type is involved and no testkit answerer is needed.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_reinforcement_blast.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const SYSTEM_ID := &'ms_grit_latch_magnets'
const ACTION_ID := &'action_reinforcement_blast'
const BUFF_ID := &'buff_reinforcement_blast'
## The hidden half. Task 4; see the banner above and the buff's own header.
const REDUCTION_BUFF_ID := &'buff_reinforcement_blast_reduction'

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

# Blast 1 is AoeCalculator.blast(centre, 1, ...) - a 3x3 square centred on the chosen tile
# (aoe_calculator.gd:13-15, a -radius..radius box), NOT a plus-shape. Every tile below is measured
# against that box.
const FITZ_TILE := Vector2i(2, 4)
const CENTRE := Vector2i(3, 4)       # blast covers x 2..4, y 3..5 - so the Fitzgerald is in its own blast
const IN_BLAST_ALLY := Vector2i(3, 3)
const IN_BLAST_HOSTILE := Vector2i(4, 5)
const ONE_TILE_OUT := Vector2i(5, 4) # x 5 is one column past the blast's eastern edge

# The Fitzgerald's Sensors is 10 (01-fitzgerald.md), and the default map is 15x9, so both of these
# are on the map with room to spare.
const SENSOR_RANGE := 10
const AT_SENSOR_RANGE := Vector2i(12, 4)     # distance 10 from FITZ_TILE
const BEYOND_SENSOR_RANGE := Vector2i(13, 4) # distance 11

var game:Gamemaster
var fitz:Unit
var magnets:GearCore

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	fitz = FitzgeraldFixture.create_fitzgerald(game, FITZ_TILE)
	magnets = fitz.core.equip_system(SYSTEM_ID)
	SpecFactory.apply_passive_buffs(fitz)
	await FitzgeraldFixture.open_turn(game, fitz)

func after_each() -> void:
	# Task 4's test_it_blunts_a_real_weapon_hit pins its damage die with Dice.CHEAT_ROLL_QUEUE, and a
	# queue left populated by an aborted test leaks into the next one - where it would quietly feed
	# the NEXT test's rolls from the wrong buffer. Every other test in the file rolls nothing.
	Dice.CHEAT_ROLL_QUEUE.clear()

## Fire REINFORCEMENT BLAST centred on a tile. See the file header for why a bare tile is enough.
func blast_at(tile:Vector2i) -> void:
	await SpecFactory.use(game, fitz, SYSTEM_ID, ACTION_ID, tile)

func _specific() -> SpecificAction:
	return SpecificAction.create(fitz, magnets, magnets.kit.get_action(ACTION_ID))

# ---------------------------------------------------------------- the card's own properties

func test_the_system_is_limited_three_and_unique() -> void:
	var kit:Kit = ContentLibrary.get_kit(SYSTEM_ID)
	assert_true(Kit.is_valid(kit), 'ms_grit_latch_magnets is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 3, 'Limited 3.')
	assert_true(kit.is_unique(), 'Unique.')

func test_the_blast_is_a_quick_action() -> void:
	var action:Action = magnets.kit.get_action(ACTION_ID)
	assert_not_null(action, 'The kit carries action_reinforcement_blast.')
	if action == null: return
	assert_eq(action.get_action_type(_specific()), Lancer.ACTION.QUICK, 'REINFORCEMENT BLAST is a QUICK.')

func test_the_buff_is_player_visible() -> void:
	# SP4 ships exactly one visible buff and this is it: the armor chip is the whole player-facing
	# signal that the blast landed, since nothing else about it is legible on the map.
	var buff:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(buff, 'buff_reinforcement_blast is in the buffs index.')
	if buff == null: return
	assert_false(buff.hide_from_player, 'It shows as a chip on every unit that gained armor.')
	assert_eq(buff.to, Buff.TO.STATBLOCK, 'It is a STATBLOCK buff - the display channel.')

func test_the_system_and_its_buff_have_display_text() -> void:
	# Asserted against the compiled ARTIFACT rather than the csv, because Translate loads
	# localizations.en.translation and never reads the csv beside it: an edited csv that was never
	# re-scanned leaves a correct-looking source file next to an artifact that has never heard of
	# these keys, with the whole suite still green. (filesystem_manage(op="reimport") does NOT
	# regenerate it; only op="scan" and the headless --import do.) Same shape as
	# test_rapier_carronade.gd's test_the_carronade_has_display_text.
	#
	# THE BUFF'S KEYS ARE UNDER `gear.`, NOT `buff.`. Translate.buff (translate.gd:49-79) looks the
	# buff up as Translate.key(['gear', buff_id, property]) at :57 and has no buff.* branch anywhere,
	# so a `buff.buff_reinforcement_blast.name` row would compile fine and never be read - and this
	# buff's chip is by design the only on-map signal that the blast landed, so blank text there
	# costs the mechanic its entire player-facing half.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	#
	# `gear.<system>.effect` IS DELIBERATELY ABSENT and is not listed below. The LCP gives this system
	# an EMPTY `effect` - its rules live in the action's `detail`, which is the action row, and its
	# flavour in `description`, which is the `.flavor` row. Its only other content was the Limited 3 /
	# Unique tags, which the engine already renders as chips. So a kit row here could only be
	# invention, and the author's 2026-09-14 localization directive removed it. This is NOT the
	# cp_broadside case: that kit's row survives because it carries a real rule (an integrated weapon
	# takes no mount and no weapon mod) that the LCP encodes as `no_mods: true` rather than as prose,
	# and that the game renders nowhere else. Measured at the same time: 189 of vanilla's 431 kits
	# have a name row and no effect row, so omitting one is house style, not a gap.
	for key:String in [
		'gear.%s.name' % SYSTEM_ID,
		'gear.%s.%s.name' % [SYSTEM_ID, ACTION_ID],
		'gear.%s.%s.effect' % [SYSTEM_ID, ACTION_ID],
		'gear.%s.name' % BUFF_ID,
		'gear.%s.effect' % BUFF_ID,
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)

# ---------------------------------------------------------------- who the blast catches

func test_everybody_in_the_blast_gains_one_armor() -> void:
	# Ruling 23: "all characters" is hostiles, allies AND the Fitzgerald itself. No ally/enemy filter
	# on the action, can_apply_to_self = true, and objects fall out for free (see the object test).
	var ally := FitzgeraldFixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	assert_true(UnitRelation.are_allies(fitz, ally), 'fixture: the ally really is allied.')
	assert_true(UnitRelation.are_enemies(fitz, hostile), 'fixture: the hostile really is hostile.')
	var fitz_before:int = fitz.get_armor()
	var ally_before:int = ally.get_armor()
	var hostile_before:int = hostile.get_armor()

	await blast_at(CENTRE)

	assert_eq(ally.get_armor(), ally_before + 1, 'The ally gained 1 armor.')
	assert_eq(hostile.get_armor(), hostile_before + 1, 'So did the hostile.')
	assert_eq(fitz.get_armor(), fitz_before + 1, 'And so did the Fitzgerald, standing in its own blast.')

func test_a_unit_one_tile_outside_the_blast_gains_nothing() -> void:
	var inside := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var outside := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT, 10)
	var inside_before:int = inside.get_armor()
	var outside_before:int = outside.get_armor()

	await blast_at(CENTRE)

	assert_eq(inside.get_armor(), inside_before + 1, 'fixture: the blast did go off.')
	assert_eq(outside.get_armor(), outside_before, 'One tile past the edge is one tile too far.')

func test_the_blast_may_centre_on_empty_ground() -> void:
	# can_target_empty_tiles. Without it the action could only be aimed at a tile that already holds a
	# targetable unit, which is not what "choose a Blast 1 area" means - and the neighbour below would
	# never be reached.
	#
	# THE ACTIVATION BELOW DOES NOT OBSERVE THAT FLAG, so it cannot be the whole test. Handing
	# target_tiles to event_gear_activate sends ask_for_targets_alt down its `elif
	# was_supplied_a_target:` branch (target_action_util.gd:230-242), which filters the supplied tiles
	# through Tile.is_valid alone (:171) and returns them verbatim. can_target_empty_tiles is read in
	# exactly one place repo-wide - UnitTargeting.get_tiles_targetable (unit_targeting.gd:84) - and
	# that branch never calls it, so a build with the flag OFF would still armour the neighbour here.
	# The targetable-set assertion is what actually pins the flag; the activation pins that the buff
	# then reaches a unit the centre tile does not hold. Same technique as the sensor-range test below.
	var empty_centre := Vector2i(8, 4)
	var neighbour := FitzgeraldFixture.create_dummy(game, empty_centre + Vector2i(1, 0), 10)
	assert_eq(game.map.get_all_units_at_tile(empty_centre).size(), 0,
		'fixture: the chosen centre really is bare ground.')
	var targetable:Array[Vector2i] = UnitTargeting.get_tiles_targetable(_specific())
	assert_true(targetable.has(empty_centre),
		'Bare ground is an offerable centre: the player really can "choose a Blast 1 area".')
	var before:int = neighbour.get_armor()

	await blast_at(empty_centre)

	assert_eq(neighbour.get_armor(), before + 1, 'Aimed at nobody, it still armoured the neighbour.')

func test_an_object_in_the_blast_gains_nothing() -> void:
	# Vanilla's can_target_unit refuses anything that is not is_actor() (action_system_apply_buff.gd:64).
	# This action's own override sends only a DRONE past that line (the shared CharacterTarget helper,
	# Pass F T14 - a drone IS a character), so cover and every other object are still excluded with no
	# work on our side. This pins that the exclusion is real rather than an accident of where things
	# were standing; test_a_drone_in_the_blast_gains_one_armor is the other half.
	var cover := FitzgeraldFixture.create_deployable(game, IN_BLAST_ALLY, 40, 0, 5) # 5: the frame's own unmodified evasion
	assert_false(cover.is_actor(), 'fixture: the Jericho cover really is a non-actor object.')
	var witness := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var cover_before:int = cover.get_armor()
	var witness_before:int = witness.get_armor()

	await blast_at(CENTRE)

	assert_eq(witness.get_armor(), witness_before + 1, 'fixture: the blast did go off.')
	assert_eq(cover.get_armor(), cover_before, 'A piece of cover is not a character.')

func test_a_drone_in_the_blast_gains_one_armor() -> void:
	# "All characters within the area", and a drone IS a character (Pass A; author T14). activate
	# re-filters the blast through specific.action.can_target_unit (action_system_apply_buff.gd:117),
	# so the override is what lets the drone in. BOTH halves, read through their own getters (banner).
	var drone := FitzgeraldFixture.create_drone(game, IN_BLAST_ALLY, Faction.AI_ENEMY)
	assert_true(drone.is_drone(), 'fixture: a drone.')
	var before:int = drone.get_armor()

	await blast_at(CENTRE)

	assert_eq(drone.get_armor(), before + 1, 'The drone gains 1 armor (display half).')
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 1, 'And the reduction half.')

func test_it_reaches_the_fitzgeralds_sensor_range_and_no_further() -> void:
	# apply_to_sensors = true makes get_target_range return the unit's sensor range
	# (action_system_apply_buff.gd:48-49). Asserting the range function AND the targetable-tile set,
	# because the first alone would not notice a TargetRequirements that clipped the reach some other
	# way, and the second alone would not say the number came from Sensors rather than a literal.
	assert_eq(fitz.get_sensor_range(), SENSOR_RANGE, 'fixture: the Fitzgerald has Sensors 10.')
	var specific := _specific()
	assert_eq(specific.action.get_target_range(specific), SENSOR_RANGE,
		'The reach is the unit\'s Sensors, not a fixed apply_range.')
	var targetable:Array[Vector2i] = UnitTargeting.get_tiles_targetable(specific)
	assert_true(targetable.has(AT_SENSOR_RANGE), 'A tile exactly at Sensors can be chosen.')
	assert_false(targetable.has(BEYOND_SENSOR_RANGE), 'One tile past Sensors cannot.')

# ---------------------------------------------------------------- the lifetime
#
# UNTIL.END_OF_OWNERS_NEXT_TURN, and the two tests below are what tell it apart from
# END_OF_NEXT_TURN. The engine gates the owner-turn clear on the buff's own turn_count:
# clear_owners_turn_statuses (unit_condition.gd:55-66) skips a buff whose turn_count is still 0, and
# turn_count ticks up at the START of the turn of the unit WEARING the buff
# (new_turn_for_statuses, unit_condition.gd:24). So a buff placed during the Fitzgerald's turn
# survives that turn's end, survives the target's own whole next turn, and dies at the end of the
# Fitzgerald's NEXT turn. END_OF_NEXT_TURN would instead have cleared it at the end of the TARGET's
# own next turn (end_turn_for_statuses, :41-42, which runs on every unit at every turn end).
#
# Ruling 30 measured that this UNTIL works correctly for BUFFS and is broken only for STATUSES (the
# status branch at :65-67 has no turn_count gate and clears at the very next owner-end-turn). If
# these go red, stop and report rather than swapping the enum.

func test_the_armor_survives_the_targets_own_next_turn() -> void:
	var ally := FitzgeraldFixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var before:int = ally.get_armor()
	await blast_at(CENTRE)
	assert_eq(ally.get_armor(), before + 1, 'fixture: the blast landed.')

	# Ends the Fitzgerald's turn, then runs the ally's whole turn. END_OF_NEXT_TURN would expire here.
	await SpecFactory.pass_turn(game, ally)

	assert_eq(ally.get_armor(), before + 1, 'Still armoured: the clock is the FITZGERALD\'s turn.')

func test_the_armor_is_gone_at_the_end_of_the_fitzgeralds_next_turn() -> void:
	var ally := FitzgeraldFixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var ally_before:int = ally.get_armor()
	var fitz_before:int = fitz.get_armor()
	await blast_at(CENTRE)
	assert_eq(ally.get_armor(), ally_before + 1, 'fixture: the blast landed.')

	await SpecFactory.pass_turn(game, ally) # ticks the ally's copy of the buff to turn_count 1

	# NOT SpecFactory.pass_turn(game, fitz): that starts AND ends the turn in one call
	# (spec_factory.gd:212-220), so the assertion below could never tell END_OF_OWNERS_NEXT_TURN (7)
	# from its immediate neighbour START_OF_OWNERS_TURN (6) - a 6-build clears at
	# event_turn_start.gd:77, before pass_turn returns, and still reads "gone" afterwards. Splitting
	# the call and asserting in the MIDDLE is what closes that neighbour: on a 6-build the armor is
	# already gone here, and the card promises it for the whole of this turn.
	await SpecFactory.start_turn(game, fitz)
	assert_eq(ally.get_armor(), ally_before + 1,
		'Still armoured through the Fitzgerald\'s next turn: it expires at that turn\'s END, not its start.')

	await SpecFactory.end_turn(game, fitz)

	assert_eq(ally.get_armor(), ally_before, 'The ally\'s armor expired with the Fitzgerald\'s turn.')
	assert_eq(fitz.get_armor(), fitz_before, 'And so did the Fitzgerald\'s own.')

# ---------------------------------------------------------------- charges

func test_a_charge_is_spent() -> void:
	var before:int = magnets.charges_current
	await blast_at(CENTRE)
	assert_eq(magnets.charges_current, before - 1, 'One of the three charges is gone.')

func test_it_is_refused_with_no_charges_left() -> void:
	# Set AFTER before_each's equips: full_repair() refills charges, so an earlier write is undone.
	magnets.charges_current = 0
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var before:int = hostile.get_armor()

	# The armor assertion below would also pass against an action that silently did nothing - it does
	# not tell a REFUSAL from a no-op. get_gear_unavailable_reason is what
	# event_gear_activate.check_specific_context calls before aborting, and unit_action.gd:153 is the
	# clause that reads charges_current, so asserting the reason proves the refusal is FOR LACK OF
	# CHARGES rather than some unrelated gate. Same shape as test_full_speed_ahead.gd's.
	assert_eq(
		UnitAction.get_gear_unavailable_reason(_specific()), UnitAction.REASON.NO_CHARGES,
		'The system itself reports NO_CHARGES, not some other gate.'
	)
	await blast_at(CENTRE)
	assert_eq(hostile.get_armor(), before, 'An empty system armours nobody.')

# ============================== TASK 4: THE HALF THAT ACTUALLY MITIGATES ============================
#
# EVERYTHING BELOW THIS LINE ASSERTS ON core.current.health (or core.current.heat) AFTER A REAL HIT.
# Not one of these tests calls an armor getter, and that is the whole reason they exist: the ruling
# that produced buff_reinforcement_blast_reduction was taken because the tests ABOVE this line passed
# in full against a build that blunted nothing.
#
# HOW THE HITS ARE DELIVERED. Most of these go through SpecFactory.damage, which fires
# event_unit_damage directly (spec_factory.gd:228-235) with unit / number / category / flags and
# nothing else. That is the SAME event a weapon's damage arrives on - DamageModifications.create is
# called from its execute_preblock (event_unit_damage.gd:52 and again at :63) either way - but with
# no gear, no action and no AttackRoll on the context, which makes the damage type and the flags the
# only variables in play. It also has no attack roll to miss and no action economy to run out of, so
# a test can land three separate hits on one unit inside one turn. test_it_blunts_a_real_weapon_hit
# is the counterweight: it fires an actual weapon, so the gate takes its ActionAttackWeapon branch
# and the context carries a real AttackRoll.
#
# WHY SO MANY "fixture:" CONTROL ASSERTIONS. Three of these tests are trivially passable:
# "an AP hit is not blunted" passes if the flag never reached the pipeline; "heat and burn are not
# blunted" passes if the damage never landed; "the reduction is not consumed" passes if the second
# hit was blunted by something else. Each one therefore carries a control that fails loudly in
# exactly that case. Task 2 of this sub-project shipped a test that stayed green under its own
# mutation and Task 3 found three more; the mutation checks for this task are recorded in
# .superpowers/sdd/sp4-task-4-report.md.

## Vanilla Main Rifle, 1d6 KINETIC, no AP (content/gear/gms/weapons/mw_assault_rifle.tres). Chosen
## because its damage type is on the reduction's list and it carries no second damage type and no
## on-hit effect. It DOES carry RELIABLE 2 - but that only substitutes a guaranteed 2 damage on a
## MISS (attack_util.gd:126, get_miss() vs get_hits()); a HIT rolls its die untouched, and this shot
## cannot miss at 19 accuracy against -10 evasion. So the number the target loses is the die minus
## the blast and nothing more.
const PLAIN_RIFLE := &'mw_assault_rifle'
const RIFLE_DIE := 6

## This mod's own rank II weapon mod, for the cross-gear test at the foot of the file. Its +1d6
## clause reads unit.get_armor() - the getter the DISPLAY half of this pair raises - so the two
## pieces of gear meet even though neither file mentions the other in code.
const RIPPER_MOD_ID := &'wm_ripper_mod'

## A flat hit big enough that a 1-point reduction cannot be confused with a rounding artefact of the
## halving at damage_modifications.gd:52/108, and small enough that nothing here dies: the fixture
## dummies carry 200 HP.
const FIXED_HIT := 10
## Heat, kept well under the heat capacity make_heat_target() gives - see that helper.
const HEAT_HIT := 4

## Deal a flat hit of one damage type and return the health it actually cost.
##
## Returns the LOSS rather than asserting on an absolute, so a test that lands several hits on one
## unit reads as a list of independent measurements instead of a running total.
func take(unit:Unit, amount:int, type:Lancer.DAMAGE_TYPE, flags:Array = []) -> int:
	var before:int = unit.core.current.health
	await SpecFactory.damage(game, unit, amount, type, flags)
	return before - unit.core.current.health

## The same for HEAT, which never touches health: event_unit_damage.gd:102-103 routes it to
## EventUnitDamage.heat() and into core.current.heat instead.
func take_heat(unit:Unit, amount:int) -> int:
	var before:int = unit.core.current.heat
	await SpecFactory.damage(game, unit, amount, Lancer.DAMAGE_TYPE.HEAT)
	return unit.core.current.heat - before

## How many copies of a buff a unit is wearing. Used as an "is it still there" probe rather than a
## boolean, so a build that stacked a second copy would also show up.
func count_buff(unit:Unit, buff_id:StringName) -> int:
	return unit.state.buffs.filter(
		func(core:BuffCore) -> bool: return core.base.compcon_id == buff_id).size()

# ---------------------------------------------------------------- it blunts the hit

func test_the_blast_actually_blunts_damage() -> void:
	# THE TEST THE WHOLE RULING EXISTS FOR. Its control is the SAME unit before the blast, so the
	# buff pair is the only thing that differs between the two measurements - no second frame, no
	# second faction, no second roll, nothing else that could account for the 1.
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var unbuffed := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(unbuffed, FIXED_HIT, 'fixture: nothing blunts this unit before the blast.')

	await blast_at(CENTRE)

	var buffed := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(buffed, FIXED_HIT - 1, 'One less, measured on core.current.health - not on get_armor().')
	assert_eq(unbuffed - buffed, 1, 'Exactly one point, and the blast is what changed between them.')

	# damage_types names all three types armor covers - KINETIC, ENERGY and EXPLOSIVE - not just the
	# one every other positive test in this file happens to fire with. Without these two, mutating the
	# .tres array down to [KINETIC] alone would leave every mitigation test here green.
	var energy := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.ENERGY)
	assert_eq(energy, FIXED_HIT - 1, 'ENERGY is blunted too.')
	var explosive := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.EXPLOSIVE)
	assert_eq(explosive, FIXED_HIT - 1, 'So is EXPLOSIVE.')

func test_it_blunts_a_real_weapon_hit() -> void:
	# The counterweight to the direct damage events everything else here uses. A weapon attack puts an
	# ActionAttackWeapon on the context, so BuffResistDamage.check_if_passive_applies takes its
	# weapon branch (buff_resist_damage.gd:47-55) before ever reaching the damage_types line - our
	# weapon_sizes and weapon_types are both empty, so it must fall THROUGH that branch rather than
	# return early - and the context carries a real AttackRoll, which is what
	# damage_modifications.gd:100-101 uses to track armor across an attack roll.
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, -10) # -10 evasion: the shot lands
	# NOT followed by another SpecFactory.apply_passive_buffs(fitz). equip_system() calls
	# full_repair(), which empties every equipped gear's state dictionary - harmless here, nothing has
	# been used yet - but re-running the passive-buff pass would stack a second copy of the frame's
	# trait buffs on a unit that already has them from before_each. The rifle grants no passive buffs
	# of its own, so there is nothing to apply.
	fitz.core.equip_system(PLAIN_RIFLE)
	var unbuffed := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(unbuffed, FIXED_HIT, 'fixture: nothing blunts this unit before the blast.')

	await blast_at(CENTRE)

	# One QUICK for the blast and one for the shot; a mech has two. If the shot were ever refused for
	# action economy the assertion below would read 0, which is why it is an exact number and not a
	# "less than" - a refusal cannot be mistaken for a very effective reduction.
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [RIFLE_DIE, RIFLE_DIE, RIFLE_DIE, RIFLE_DIE])
	var before:int = hostile.core.current.health
	await SpecFactory.use_solo(game, fitz, PLAIN_RIFLE, hostile)

	assert_eq(before - hostile.core.current.health, RIFLE_DIE - 1,
		'1d6 pinned to 6, less the blast\'s 1 - the reduction reaches a real attack.')

func test_a_unit_outside_the_blast_is_not_blunted() -> void:
	var inside := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var outside := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT, 10)

	await blast_at(CENTRE)

	var in_loss := await take(inside, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(in_loss, FIXED_HIT - 1, 'fixture: the blast did go off.')
	var out_loss := await take(outside, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(out_loss, FIXED_HIT, 'One tile past the edge takes it in full.')

# ---------------------------------------------------------------- what it deliberately does NOT blunt

func test_an_ap_hit_is_not_blunted() -> void:
	# The reason buff_reinforcement_blast_reduction.gd overrides check_if_passive_applies at all:
	# damage_modifications.gd:103 guards only the ARMOR branch with the AP flag, so a plain
	# BuffResistDamage would happily reduce an AP hit that real armor could not touch.
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	# CONTROL A, AND IT IS NOT DECORATION: this test passes trivially against an AP flag that never
	# reached the pipeline at all. This witness stands OUTSIDE the blast, so neither of our buffs is
	# on it, and carries two points of REAL frame armor - which the engine bypasses only when the
	# flag is genuinely set (damage_modifications.gd:103). If it takes the hit in full, the flag is
	# real, and it is an engine channel of its own saying so rather than anything of ours.
	var witness := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT, 10)
	witness.core.frame.stat.armor = 2
	witness.core.full_repair()
	assert_eq(witness.core.current.armor, 2, 'fixture: the witness really has 2 armor.')

	await blast_at(CENTRE)

	var through_armor := await take(
		witness, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP])
	assert_eq(through_armor, FIXED_HIT, 'fixture: the AP flag is live - it walked past 2 real armor.')

	var ap := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP])
	assert_eq(ap, FIXED_HIT, 'AP goes through the reduction exactly as it goes through armor.')

	# CONTROL B: the same buffed unit, the same amount, no flag. Without it the assertion above passes
	# against a build where the blast never reached this unit in the first place.
	var plain := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(plain, FIXED_HIT - 1, 'fixture: the reduction IS live on this unit - the flag is what stops it.')

func test_heat_is_not_blunted() -> void:
	# HEAT is off damage_types because armor ignores it. resist_everything would have got this one
	# right by itself (buff_resist_damage.gd:60 excludes HEAT) - it is BURN that it gets wrong, which
	# is why the export is spelled out; see the burn test below.
	var hostile := make_heat_target(IN_BLAST_HOSTILE)

	await blast_at(CENTRE)

	var gained := await take_heat(hostile, HEAT_HIT)
	assert_eq(gained, HEAT_HIT, 'Every point of heat landed.')
	# The control: without it, "heat is not blunted" is satisfied by heat that never arrived.
	var plain := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(plain, FIXED_HIT - 1, 'fixture: the reduction IS live on this unit.')

func test_burn_is_not_blunted() -> void:
	# THE TEST THAT PINS damage_types AGAINST resist_everything. resist_everything excludes HEAT and
	# NOT BURN (buff_resist_damage.gd:60), and burn damage does reach the reduction branch
	# (damage_modifications.gd:93-94 subtracts other_reduction for burn), so a build that used the
	# convenient flag instead of the explicit list would quietly blunt burn - which armor never does.
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)

	await blast_at(CENTRE)

	var burned := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.BURN)
	assert_eq(burned, FIXED_HIT, 'Burn lands in full.')
	# The control, and it doubles as proof the damage was really typed BURN: event_unit_damage.gd:121
	# stacks burn on the unit for exactly that damage type and no other.
	assert_eq(hostile.state.burn, FIXED_HIT, 'fixture: it really was burn, not kinetic wearing its name.')
	var plain := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(plain, FIXED_HIT - 1, 'fixture: the reduction IS live on this unit.')

# ---------------------------------------------------------------- it is not used up

func test_the_reduction_survives_the_hit_it_blunted() -> void:
	# is_onetime is deliberately left at its false default. damage_modifications.gd:113 hands EVERY
	# RESIST_DAMAGE buff it consulted to buffs_to_consume, and UnitCondition.consume_buffs
	# (unit_condition.gd:937-938) then filters that list down to buff.base.is_onetime before clearing
	# anything - so a non-one-time buff is collected and dropped. Real armor is not spent by being
	# used, and neither is this.
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)

	await blast_at(CENTRE)
	assert_eq(count_buff(hostile, REDUCTION_BUFF_ID), 1, 'fixture: exactly one reduction buff landed.')

	var first := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(first, FIXED_HIT - 1, 'The first hit was blunted...')
	# THE ASSERTION THAT MAKES THE SECOND HIT MEAN SOMETHING. Without it, "both hits were reduced by
	# 1" is also what you would see if the buff had been consumed and something else were doing the
	# reducing; with it, the thing still standing on the unit is named.
	assert_eq(count_buff(hostile, REDUCTION_BUFF_ID), 1,
		'...and blunting it did not use it up.')

	var second := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(second, FIXED_HIT - 1, 'So the second hit is blunted by the same 1.')

# ---------------------------------------------------------------- both halves, one clock

func test_both_halves_expire_together_with_the_fitzgeralds_next_turn() -> void:
	# The two buffs are one mechanic, so they must share a lifetime exactly: a reduction that outlived
	# its chip would blunt hits with nothing on screen to explain it, and a chip that outlived its
	# reduction would promise armor the engine no longer honours. Both carry until = 7
	# (END_OF_OWNERS_NEXT_TURN); this is what proves they actually move together.
	var ally := FitzgeraldFixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var armor_before:int = ally.get_armor()

	await blast_at(CENTRE)
	assert_eq(ally.get_armor(), armor_before + 1, 'fixture: the display half landed.')
	assert_eq(count_buff(ally, REDUCTION_BUFF_ID), 1, 'fixture: and so did the reduction half.')

	await SpecFactory.pass_turn(game, ally) # ticks the ally's copies to turn_count 1

	# START AND END SPLIT, not SpecFactory.pass_turn(game, fitz), for the reason
	# test_the_armor_is_gone_at_the_end_of_the_fitzgeralds_next_turn gives in full: pass_turn does
	# both halves in one call, so an assertion after it could not tell END_OF_OWNERS_NEXT_TURN from
	# START_OF_OWNERS_TURN. Task 3 measured that this hid a lifetime bug.
	await SpecFactory.start_turn(game, fitz)
	var mid_turn := await take(ally, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(mid_turn, FIXED_HIT - 1, 'Still blunting through the whole of the Fitzgerald\'s next turn.')

	await SpecFactory.end_turn(game, fitz)

	assert_eq(ally.get_armor(), armor_before, 'The display half expired...')
	assert_eq(count_buff(ally, REDUCTION_BUFF_ID), 0, '...and the reduction half is off the unit too.')
	var after := await take(ally, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(after, FIXED_HIT, 'Full damage again: both halves went at the same moment.')

func test_an_owned_drones_pair_expires_with_the_fitzgeralds_next_turn() -> void:
	# PROBE, Pass F T11, pinned. until = 7 (END_OF_OWNERS_NEXT_TURN) is skipped while the BUFF's
	# turn_count <= 0 (unit_condition.gd:62), and turn_count rises only in new_turn_for_statuses, called
	# from event_turn_start.handle_starting_unit for the unit whose turn starts and its OWNED
	# deployables. A drone the Fitzgerald owns starts its turn with the Fitzgerald, so its copies age
	# on the same clock as test_both_halves_expire_together_with_the_fitzgeralds_next_turn's ally.
	var drone := FitzgeraldFixture.create_drone(game, IN_BLAST_ALLY, Faction.PLAYER)
	drone.state.set_owner(fitz)
	var armor_before:int = drone.get_armor()

	await blast_at(CENTRE)
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 1, 'fixture: the pair landed on the owned drone.')

	await SpecFactory.end_turn(game, fitz)
	await SpecFactory.start_turn(game, fitz)
	assert_eq(drone.get_armor(), armor_before + 1, "Still armoured through the Fitzgerald's next turn.")
	await SpecFactory.end_turn(game, fitz)
	assert_eq(drone.get_armor(), armor_before, 'The display half expired at the end of it...')
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 0, '...and the reduction half with it.')

func test_an_unowned_drones_pair_expires_with_the_fitzgeralds_next_turn() -> void:
	# Pass F T11b, the author's ruling on the T11 probe ("Clear it myself"). The engine alone never
	# ages an unowned drone's copies: turn_count rises only when the HOLDER starts a turn
	# (new_turn_for_statuses, from event_turn_start.handle_starting_unit), and a drone starts one only
	# as its OWNER's deployable - so END_OF_OWNERS_NEXT_TURN was skipped at every Fitzgerald turn end
	# (unit_condition.gd:62) and the pair stayed for the scene (T11's measured limit). The Kit's hidden
	# action_reinforcement_blast_age reaction ages them at the Fitzgerald's turn start, so the engine's
	# own clear takes both halves at the END of the Fitzgerald's next turn, as for anyone else.
	var drone := FitzgeraldFixture.create_drone(game, IN_BLAST_HOSTILE, Faction.AI_ENEMY)
	var hostile := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT + Vector2i(3, 0), 10)
	var armor_before:int = drone.get_armor()
	await blast_at(CENTRE)
	assert_eq(drone.get_armor(), armor_before + 1, 'fixture: the pair landed on the unowned drone.')

	await SpecFactory.end_turn(game, fitz)
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 1, 'Not cleared at the end of the turn it was applied.')
	await SpecFactory.pass_turn(game, hostile)
	await SpecFactory.start_turn(game, fitz)
	assert_eq(drone.get_armor(), armor_before + 1, "Still armoured through the Fitzgerald's next turn...")
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 1, '...both halves.')
	await SpecFactory.end_turn(game, fitz)
	assert_eq(drone.get_armor(), armor_before, 'The display half expired at the end of it...')
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 0, '...and the reduction half with it.')

func test_a_hostile_owned_drones_pair_ages_on_its_owners_turn_and_expires_with_the_fitzgeralds() -> void:
	# Pass F T11b. A drone a hostile NPC owns starts its turn with that NPC, so the ENGINE ages its
	# copies (turn_count 0 -> 1 on the NPC's turn) and the ageing reaction leaves it alone - it acts
	# only on a drone no unit on the map owns. Expiry is then the ordinary END_OF_OWNERS_NEXT_TURN.
	var hostile := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT + Vector2i(3, 0), 10)
	var drone := FitzgeraldFixture.create_drone(game, IN_BLAST_HOSTILE, Faction.AI_ENEMY)
	drone.state.set_owner(hostile)
	assert_true(drone.state.is_owned_by(hostile), 'fixture: the hostile owns the drone.')
	var armor_before:int = drone.get_armor()
	await blast_at(CENTRE)
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 1, 'fixture: the pair landed on the owned drone.')
	assert_eq(pair_turn_counts(drone), [0, 0], 'fixture: fresh copies, not yet aged.')

	await SpecFactory.end_turn(game, fitz)
	await SpecFactory.pass_turn(game, hostile)
	assert_eq(pair_turn_counts(drone), [1, 1], "Both copies aged once, on the owner's turn.")
	await SpecFactory.start_turn(game, fitz)
	assert_eq(pair_turn_counts(drone), [1, 1], "The Fitzgerald's turn start does not age an owned drone again.")
	assert_eq(drone.get_armor(), armor_before + 1, "Still armoured through the Fitzgerald's next turn.")
	await SpecFactory.end_turn(game, fitz)
	assert_eq(drone.get_armor(), armor_before, 'The display half expired at the end of it...')
	assert_eq(count_buff(drone, REDUCTION_BUFF_ID), 0, '...and the reduction half with it.')

## The turn_count of each of the pair's cores on `unit`, sorted.
func pair_turn_counts(unit:Unit) -> Array:
	var counts:Array = []
	for buff_core:BuffCore in unit.state.buffs:
		if buff_core.base.compcon_id in [BUFF_ID, REDUCTION_BUFF_ID]: counts.append(buff_core.turn_count)
	counts.sort()
	return counts

# ---------------------------------------------------------------- the hidden half's own wiring

func test_the_reduction_buff_is_hidden_and_permanent_for_its_lifetime() -> void:
	# Properties rather than behaviour, and each one is load-bearing somewhere else in the file:
	# hide_from_player keeps it out of test_content_integrity.gd's VISIBLE_BUFFS (two chips for one
	# effect would be a display bug, not a feature); is_onetime false is what
	# test_the_reduction_survives_the_hit_it_blunted depends on; and the two halves' `until` values
	# must be identical or the mechanic tears in half.
	var reduction:Buff = ContentLibrary.get_buff(REDUCTION_BUFF_ID)
	assert_not_null(reduction, 'buff_reinforcement_blast_reduction is in the buffs index.')
	if reduction == null: return
	assert_true(reduction is BuffResistDamage, 'It is a BuffResistDamage, the mitigating channel.')
	assert_eq(reduction.to, Buff.TO.RESIST_DAMAGE, 'Registered to the channel the damage pipeline reads.')
	assert_true(reduction.hide_from_player, 'Hidden: the visible half already wears the chip.')
	assert_false(reduction.is_onetime, 'Not consumed by the hit it blunts.')
	var visible:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(visible, 'fixture: the visible half is indexed too.')
	if visible == null: return
	assert_eq(reduction.until, visible.until, 'Both halves run on exactly the same clock.')

# ---------------------------------------------------------------- a second blast on the same unit
#
# THE STACKING BEHAVIOUR OF THE PAIR, WHICH NOTHING ELSE IN THIS FILE PINS. Both halves rely on
# `multiple_copies_can_stack` defaulting false (buff.gd:131) while ActionSystemApplyBuff's
# `can_reapply` defaults TRUE (action_system_apply_buff.gd:17) - so a second blast on the same unit
# is allowed, and today refreshes rather than adds: apply_buff_alt clears an existing copy with the
# same compcon_id, from_gear, `to` and `until` before appending the new one
# (unit_condition.gd:739-746). Setting the stack flag on ONE half later would give +2 armor with -1
# mitigation, or the reverse, with the whole rest of this suite green.

func test_a_second_blast_refreshes_the_pair_rather_than_stacking_it() -> void:
	var hostile := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var before:int = hostile.get_armor()

	await blast_at(CENTRE)
	assert_eq(count_buff(hostile, BUFF_ID), 1, 'fixture: one copy of the display half landed.')
	assert_eq(count_buff(hostile, REDUCTION_BUFF_ID), 1, 'fixture: and one of the reduction half.')

	# A TURN BOUNDARY IS REQUIRED, and it is not scene-setting. Action.get_per_turn_soft_limit
	# (action.gd:161-163) returns 1 for anything costing more than a free action, so a second QUICK
	# activation of the same gear in the same turn is refused outright by
	# UnitAction.is_under_per_turn_limit (unit_action.gd:167-168) and this test would then be
	# asserting that a no-op changes nothing. event_turn_end.gd:72 is what clears uses_this_turn.
	# The first pair SURVIVES this boundary - clear_owners_turn_statuses skips a buff whose own
	# turn_count is still 0 (unit_condition.gd:55-66), and turn_count ticks only at the start of the
	# turn of the unit WEARING it, which this hostile never takes - so the second blast really does
	# land on a unit that already carries both halves, which is the whole point.
	await SpecFactory.end_turn(game, fitz)
	await SpecFactory.start_turn(game, fitz)
	assert_eq(count_buff(hostile, BUFF_ID), 1, 'fixture: the first pair is still on the unit...')
	assert_eq(count_buff(hostile, REDUCTION_BUFF_ID), 1, '...both halves of it.')

	await blast_at(CENTRE)

	assert_eq(count_buff(hostile, BUFF_ID), 1, 'The display half was refreshed, not stacked.')
	assert_eq(count_buff(hostile, REDUCTION_BUFF_ID), 1, 'And so was the reduction half.')
	assert_eq(hostile.get_armor(), before + 1, 'Two blasts are still exactly one armor, not two.')
	var loss := await take(hostile, FIXED_HIT, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(loss, FIXED_HIT - 1, 'And still exactly one point of mitigation, to match.')

# ------------------------------------------------- the blast arms this mod's own Ripper Mod
#
# AN INTENDED INTERACTION THAT SPANS TWO CHANNELS NO SINGLE SPEC OTHERWISE BINDS, ruled intended by
# the author on 2026-09-14 and pinned here at their request.
#
# buff_ripper_mod_bonus.gd:42 gates the Ripper Mod's +1d6 on `context.target_unit.get_armor() >= 1`,
# and the DISPLAY half of this pair raises exactly that getter by 1 on every character in the blast,
# hostiles included (ruling 23: "all characters" has no ally filter). So firing REINFORCEMENT BLAST
# at enemies hands the Fitzgerald's own Ripper-modded weapon +1d6 against them while the blast blunts
# only 1 - a net +5 on a d6 pinned to 6. That is the ruling, not a bug.
#
# WHY IT LIVES HERE AND NOT IN spec/test_ripper_mod.gd. That file's test_temporary_armor_counts
# builds its STATBLOCK buff BY HAND, on purpose, so the rank II mod's spec does not depend on rank
# III content loading - and its assertions are the executable proof of the SP4 blocker and must not
# be touched. The consequence is that nothing tied the SHIPPED buff_reinforcement_blast to the
# Ripper gate. This test is that tie, and it owns it because this file owns the blast.

## Fire a weapon's solo profile once at `target` and return the health it cost. Same shape as
## spec/test_ripper_mod.gd's shoot() - read that file for why the dice buffer is oversized and why
## event_gear_activate is driven directly - but takes the target as an argument, because this test
## shoots two different units.
func shoot(weapon:GearCore, target:Unit, die:int) -> int:
	var before:int = target.core.current.health
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [die, die, die, die, die, die, die, die])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(),
		gear = weapon,
		unit = fitz,
		target_unit = target,
	})
	return before - target.core.current.health

func test_the_blast_arms_this_mods_own_ripper_mod_against_the_units_it_catches() -> void:
	# Both dummies carry armor 0 from the fixture, so the Ripper gate can only be opened by the
	# blast - and the control, one tile outside it, is never opened at all.
	var control := FitzgeraldFixture.create_dummy(game, ONE_TILE_OUT, -10)
	var caught := FitzgeraldFixture.create_dummy(game, IN_BLAST_HOSTILE, -10)
	assert_eq(control.get_armor(), 0, 'fixture: the control has no armor of its own.')
	assert_eq(caught.get_armor(), 0, 'fixture: nor does the unit the blast will catch.')

	# EXACTLY spec/test_ripper_mod.gd's equip_modded(), in its order, and the order is load-bearing.
	# LoadoutCore.equip_weapon_mod (loadout_core.gd:343-363) appends the mod kit AND patches a
	# hand-made GearCore into `systems`, but GearCore.get_weapon_mod (gear_core.gd:377-380) only
	# returns a mod that get_equipped_systems() reports - which it does not until the loadout has
	# been rebuilt. The full_repair() inside SpecFactory.apply_passive_buffs is that rebuild.
	# Measured: asking for the mod BEFORE this line returns null, and the test then reads as
	# "the blast did nothing" rather than "the mod was never fitted" (first run, 2026-09-14).
	#
	# THIS IS A SECOND apply_passive_buffs PASS on a unit before_each already ran one over - which
	# test_it_blunts_a_real_weapon_hit above deliberately avoids. It is safe HERE because the pass is
	# needed for the mod at all, and because no buff anywhere in this mod sets
	# multiple_copies_can_stack, so apply_buff_alt clears the matching old copy before appending
	# (unit_condition.gd:739-746) and the frame's traits are refreshed rather than doubled. The
	# control shot below is the guard on that: a doubled trait buff would move its number off 6.
	var rifle := fitz.core.equip_system(PLAIN_RIFLE)
	fitz.core.loadout.equip_weapon_mod(RIPPER_MOD_ID, rifle)
	SpecFactory.apply_passive_buffs(fitz)
	var mod:GearCore = rifle.get_weapon_mod(fitz.core.loadout)
	assert_true(GearCore.is_valid(mod), 'fixture: the Ripper Mod really is fitted to the rifle.')

	# THE CONTROL IS A REAL SHOT FROM THE SAME MODDED WEAPON, not a number written down here. The
	# assertion at the foot is a DIFFERENCE against it, so this test fails if EITHER channel stops
	# working: kill the blast's STATBLOCK half and the caught unit stops opening the gate; kill the
	# Ripper gate and neither shot gets the die. A raw expected number would not say which.
	var unblasted := await shoot(rifle, control, RIFLE_DIE)
	assert_eq(unblasted, RIFLE_DIE,
		'fixture: against 0 armor the modded rifle is just its die - no bonus, nothing blunted.')

	# A fresh turn, for the per-turn soft limit reason spelled out in the stacking test above: the
	# rifle has been fired once, and a second shot inside the same turn would be refused and read as
	# a suspiciously effective reduction.
	await SpecFactory.end_turn(game, fitz)
	await SpecFactory.start_turn(game, fitz)

	await blast_at(CENTRE)
	assert_eq(caught.get_armor(), 1, 'fixture: the display half raised the getter the mod reads.')

	var blasted := await shoot(rifle, caught, RIFLE_DIE)

	assert_eq(blasted - unblasted, RIFLE_DIE - 1,
		'The blast is worth the mod\'s whole bonus die less the 1 it blunts: +1d6 in, -1 out.')
	assert_eq(blasted, RIFLE_DIE + RIFLE_DIE - 1,
		'Spelled out: the weapon\'s 6, the Ripper Mod\'s 6, less the reduction half\'s 1.')

# ---------------------------------------------------------------- fixtures

## A dummy that can actually HOLD heat. EventUnitDamage.heat (event_unit_damage.gd:201-208) only adds
## to core.current.heat when get_heat_max() > 0 and otherwise CONVERTS the damage to ENERGY - which is
## on the reduction's damage_types list, so on a heat_max of 0 the heat test would silently become a
## test of energy damage and go red for entirely the wrong reason. The shared fixture leaves heat at
## the isolated frame's default; 20 is the same number test_blasting_powder.gd's _make_target uses,
## for the same reason. HEAT_HIT is far below it, so nothing here overheats.
func make_heat_target(tile:Vector2i) -> Unit:
	var target := FitzgeraldFixture.create_dummy(game, tile, 10)
	target.core.frame.stat.heat = 20
	target.core.full_repair()
	assert_true(target.get_heat_max() > 0, 'fixture: this dummy can hold heat at all.')
	return target
