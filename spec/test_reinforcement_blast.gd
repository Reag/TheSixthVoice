# Grit Latch Magnets, REINFORCEMENT BLAST (Fitzgerald rank III, SP4 Task 3 + Task 4).
#
# Card: "|Limited| 3, |Unique|. (Quick) Spend a charge and choose a Blast 1 area within Sensors. All
# characters within the area gain 1 armor until the end of your next turn."
#
# ================================ READ THIS BEFORE TRUSTING A GREEN ================================
#
# TASK 3 SHIPS ONLY HALF THE MECHANIC, AND EVERY ASSERTION IN THIS FILE PASSES AGAINST THAT HALF.
#
# The engine has no channel that grants real armor. Incoming damage reads unit.core.current.armor
# (damage_modifications.gd:97), which is assigned in exactly two places repo-wide (unit_printer.gd:35
# and :73, both = core.get_armor() = frame.stat.armor + core.bonus.armor) and rebuilt only by
# UnitPrinter.recalculate_bonuses from pilot HASE, stat_override, NPC tier blocks and the
# PassiveStatIncrease passives of EQUIPPED GEAR. No buff channel writes it. So the mechanic is a
# PAIR of buffs, ruled by the author 2026-09-14 (rulings.md row 37, design §5.2's RESOLVED block):
#
#   buff_reinforcement_blast            Task 3, this file. Buff.TO.STATBLOCK, armor = 1, VISIBLE.
#                                       What the unit readout shows and what every unit.get_armor()
#                                       gate reads - this mod's own Ripper Mod included.
#                                       IT REDUCES NO INCOMING DAMAGE WHATSOEVER.
#   buff_reinforcement_blast_reduction  Task 4. A BuffResistDamage subclass. The half that actually
#                                       blunts the hit.
#
# EVERY ARMOR ASSERTION BELOW IS THROUGH unit.get_armor(), AND get_armor() ALONE IS NOT PROOF THE
# ARMOR WORKS. It passed on the STATBLOCK-only build that mitigated nothing, which is precisely how
# the SP4 blocker was found (SP3's spec/test_ripper_mod.gd test_temporary_armor_counts is the
# executable proof of it). The assertions that would catch a one-channel build are Task 4's, and they
# are appended to the bottom of this file - test_the_blast_actually_blunts_damage above all. Until
# they exist, this file proves TARGETING, LIFETIME and CHARGES, and nothing about mitigation.
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

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const SYSTEM_ID := &'ms_grit_latch_magnets'
const ACTION_ID := &'action_reinforcement_blast'
const BUFF_ID := &'buff_reinforcement_blast'

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## The vanilla Jericho cover: an OBJECT, so Unit.is_actor() is false for it (unit.gd:117) and
## ActionSystemApplyBuff.can_target_unit refuses it outright ("cannot apply buffs to drones /
## objects").
const DEPLOYABLE_FRAME := &'dep_jericho_cover'

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
	game = Fixture.create_game(self)
	fitz = Fixture.create_fitzgerald(game, FITZ_TILE)
	magnets = fitz.core.equip_system(SYSTEM_ID)
	SpecFactory.apply_passive_buffs(fitz)
	await Fixture.open_turn(game, fitz)

func after_each() -> void:
	# Nothing in TASK 3 queues a roll, so this clear is currently a no-op. Kept deliberately: Task 4's
	# mitigation tests fix rolls with Dice.CHEAT_ROLL_QUEUE to measure the damage reduction, and a
	# queue left populated by an aborted test leaks into the next one.
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
	for key:String in [
		'gear.%s.name' % SYSTEM_ID,
		'gear.%s.effect' % SYSTEM_ID,
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
	var ally := Fixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var hostile := Fixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
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
	var inside := Fixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var outside := Fixture.create_dummy(game, ONE_TILE_OUT, 10)
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
	var neighbour := Fixture.create_dummy(game, empty_centre + Vector2i(1, 0), 10)
	assert_eq(game.map.get_all_units_at_tile(empty_centre).size(), 0,
		'fixture: the chosen centre really is bare ground.')
	var targetable:Array[Vector2i] = UnitTargeting.get_tiles_targetable(_specific())
	assert_true(targetable.has(empty_centre),
		'Bare ground is an offerable centre: the player really can "choose a Blast 1 area".')
	var before:int = neighbour.get_armor()

	await blast_at(empty_centre)

	assert_eq(neighbour.get_armor(), before + 1, 'Aimed at nobody, it still armoured the neighbour.')

func test_an_object_in_the_blast_gains_nothing() -> void:
	# can_target_unit refuses anything that is not is_actor() (action_system_apply_buff.gd:64), so the
	# card's "all characters" excludes cover, drones and other objects with no work on our side. This
	# pins that the exclusion is real rather than an accident of where things were standing.
	var cover := make_deployable(IN_BLAST_ALLY)
	var witness := Fixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
	var cover_before:int = cover.get_armor()
	var witness_before:int = witness.get_armor()

	await blast_at(CENTRE)

	assert_eq(witness.get_armor(), witness_before + 1, 'fixture: the blast did go off.')
	assert_eq(cover.get_armor(), cover_before, 'A piece of cover is not a character.')

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
	var ally := Fixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
	var before:int = ally.get_armor()
	await blast_at(CENTRE)
	assert_eq(ally.get_armor(), before + 1, 'fixture: the blast landed.')

	# Ends the Fitzgerald's turn, then runs the ally's whole turn. END_OF_NEXT_TURN would expire here.
	await SpecFactory.pass_turn(game, ally)

	assert_eq(ally.get_armor(), before + 1, 'Still armoured: the clock is the FITZGERALD\'s turn.')

func test_the_armor_is_gone_at_the_end_of_the_fitzgeralds_next_turn() -> void:
	var ally := Fixture.create_dummy(game, IN_BLAST_ALLY, 10, Faction.AI_ALLY)
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
	var hostile := Fixture.create_dummy(game, IN_BLAST_HOSTILE, 10)
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

# ---------------------------------------------------------------- fixtures

## The vanilla Jericho cover, hostile, armor 0 so the number below is the buff's or nothing. Lifted
## from test_heaer.gd's make_deployable rather than imported across spec files, matching the house
## rule that each spec owns its fixtures.
func make_deployable(tile:Vector2i) -> Unit:
	var dep := SpecFactory.create_unit(game.map, tile, Faction.AI_ENEMY)
	dep.core.frame = ContentLibrary.get_mech_frame(DEPLOYABLE_FRAME)
	FrameIsolation.isolate_frame(dep)
	dep.core.frame.stat.health = 40
	dep.core.frame.stat.armor = 0
	dep.core.full_repair()
	assert_false(dep.is_actor(), 'fixture: the Jericho cover really is a non-actor object.')
	return dep
