# THE STEALING OF THE SOULS OF THE DEAD (the Sluagh's second sheet trait, SP1 Task 3).
#
#   "Whenever a hostile character is destroyed within Sensors, the Sluagh gains OVERSHIELD equal to
#    GRIT."
#
# EVERY DEATH HERE IS A DIRECT event_unit_die, NOT A KILL. A damage kill fires `structured` before
# `death` and rolls an unseeded structure-table d6 - for a low-structure fixture four of six outcomes
# destroy it and two do not (memory lancer-tactics-spec-harness-traps) - which is four moving parts
# for a trait that only cares that a death happened, at a known distance, to a known kind of unit.
# SluaghFixture.kill drives the event; SluaghFixture.meltdown drives the other one that reaches it.
#
# THE SHARED GAMEMASTER IS WHAT MAKES ANY OF THIS RUN. EventService.remove_unit_from_game
# dereferences map.campaign_core with no guard (event_service.gd:80), and only the re-use branch of
# SpecFactory.setup_gamemaster builds one (spec_factory.gd:47-48). Eight of the ten tests below kill
# something.
#
# GRIT IS 0 BY DEFAULT and every positive case sets it explicitly. SpecFactory.create_unit hands out
# a PilotCore at license_level 0 (Util.half is ceili, so only level 0 is Grit 0), which makes "Grit 0
# grants nothing" the fixture's resting state rather than something a test has to arrange.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_stealing_of_the_souls.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## Exactly the sheet's Sensors 10 away, measured east along one row. distance_between is Chebyshev
## over closest tiles and both units are size 1 at the same elevation, so this is simply dx.
const AT_SENSORS_TILE := Vector2i(14, 6)
## One further: 11, and the frame's Sensors is 10. Task 5 is where this same tile starts granting.
const BEYOND_SENSORS_TILE := Vector2i(15, 6)
## Somewhere close, for the cases whose subject is not distance.
const NEAR_TILE := Vector2i(6, 6)
const SECOND_NEAR_TILE := Vector2i(6, 8)

const GRIT := 2

var game:Gamemaster
var sluagh:Unit

var log_lines:PackedStringArray = []
var battle_log:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	log_lines = []
	battle_log.on_log_text.connect(_record_log)

func after_each() -> void:
	# The log bus is a SHARED resource that outlives the test, so a recorder left connected would
	# keep appending into a freed object for the rest of the run (test_uffish_gyre.gd's own note).
	if battle_log.on_log_text.is_connected(_record_log): battle_log.on_log_text.disconnect(_record_log)
	Dice.CHEAT_ROLL_QUEUE.clear()

func _record_log(line:String) -> void: log_lines.append(line)

func overshield() -> int: return Overshield.current(sluagh)

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.STEALING_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % SluaghFixture.STEALING_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	assert_true(GearCore.is_valid(sluagh.get_gear(SluaghFixture.STEALING_ID)),
		'And the live Sluagh carries it as gear.')

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mt_the_stealing_of_the_souls_of_the_dead.name',
			'gear.mt_the_stealing_of_the_souls_of_the_dead.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mt_the_stealing_of_the_souls_of_the_dead.name'),
		'The Stealing of the Souls of the Dead', 'The card\'s own name, definite article and all.')

func test_the_reaction_is_hidden_point_free_and_unlimited():
	# READ OFF THE LIVE GEAR, because that is what the bus polls. Untyped local: the three things
	# below are overrides on OUR script, and naming them through a typed ActionReaction local is a
	# parse error that GUT reports by SKIPPING the whole file.
	var gear:GearCore = sluagh.get_gear(SluaghFixture.STEALING_ID)
	assert_true(GearCore.is_valid(gear), 'fixture: the trait is on the unit.')
	if not GearCore.is_valid(gear): return
	var reaction = gear.get_solo_action()
	assert_true(reaction is ActionReaction, 'The trait\'s one action is a reaction.')
	if reaction is not ActionReaction: return
	assert_eq(reaction.triggers_on, [&'death'] as Array[StringName], 'It triggers on DEATH...')
	assert_eq(reaction.trigger_timing, ReactionBus.TIMING.POST, '...at POST, which is the only '
		+ 'timing where the dead unit has actually been marked dead (event_unit_die.gd:80-81).')
	assert_false(reaction.consumes_rxn,
		'It costs no reaction point - the card names no cost and it must fire on an enemy turn.')
	assert_false(reaction.show_in_tooltip(gear.kit),
		'And it never reaches the trait card: the card\'s own effect row says everything.')
	# ActionReaction returns 99 for a point-free reaction (action_reaction.gd:69) and 1 for one that
	# spends the point. The card has NO limit at all, so 99 is what it must keep - unlike Halo, which
	# overrides it to 1. Two hostiles dying to one Blast must grant twice.
	assert_eq(reaction.get_per_round_hard_limit(SpecificAction.create(sluagh, gear, reaction)), 99,
		'And there is no per-round limit on it.')

# ---------------------------------------------------------------- the card

func test_a_hostile_death_within_sensors_grants_grit():
	SluaghFixture.set_grit(sluagh, GRIT)
	var victim:Unit = SluaghFixture.create_hostile(game, AT_SENSORS_TILE)
	assert_eq(UnitRelation.distance_between(sluagh, victim), 10,
		'fixture: exactly the sheet\'s Sensors away.')
	await SluaghFixture.kill(game, victim)
	assert_eq(overshield(), GRIT, 'A hostile character destroyed within Sensors grants GRIT.')

func test_a_hostile_death_beyond_sensors_grants_nothing():
	# ELEVEN, against a frame with Sensors 10. This same tile starts granting in Task 5, once
	# Inexorable Formation is on the frame and the Sluagh is holding Overshield - which is the live
	# read ruling 11 asks for, and which that task's spec pins from the other side.
	SluaghFixture.set_grit(sluagh, GRIT)
	var victim:Unit = SluaghFixture.create_hostile(game, BEYOND_SENSORS_TILE)
	assert_eq(UnitRelation.distance_between(sluagh, victim), 11, 'fixture: one past Sensors.')
	await SluaghFixture.kill(game, victim)
	# THE VACUITY GUARD every negative in this file now carries (close review, slice 2 M-1). Without
	# it "nothing was granted" is satisfied by a death that never happened, and event_unit_die's POST
	# queue is the only thing that reaches this trait at all.
	assert_false(Unit.is_valid(victim), 'fixture: it really died.')
	assert_eq(overshield(), 0, 'One tile past Sensors grants nothing.')

func test_a_hostile_drone_death_grants_too():
	# RULING 2026-09-27 (mod-wide): "character" is is_character(), a drone included - reversing row
	# 301 (2026-09-21), which excluded one via is_actor(). The canonical paragraph is in this file's
	# own header.
	#
	# THE TWO SETUP ASSERTIONS ARE KEPT AS ENGINE FACTS: a drone really is a character and really is
	# not an actor, though the second no longer decides anything here.
	SluaghFixture.set_grit(sluagh, GRIT)
	var drone:Unit = SluaghFixture.create_drone(game, NEAR_TILE, Faction.AI_ENEMY)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor - which no longer matters here.')
	await SluaghFixture.kill(game, drone)
	assert_false(Unit.is_valid(drone), 'fixture: it really died.')
	assert_eq(overshield(), GRIT, 'A hostile DRONE dying grants too.')

func test_a_hostile_object_death_grants_nothing():
	# The other half of the same ruling: a deployable is Frame.ENTITY.OBJECT, so is_character() is
	# already false for it (unit.gd:116 -> frame.gd:100) and is_actor() inherits that. A hostile MECH
	# and a friendly object each fail to separate the hostility clause from the character clause on
	# their own; this pair is what does.
	SluaghFixture.set_grit(sluagh, GRIT)
	var cover:Unit = SluaghFixture.create_hostile_object(game, NEAR_TILE)
	assert_false(cover.is_character(), 'fixture: a Jericho cover is not a character.')
	await SluaghFixture.kill(game, cover)
	assert_false(Unit.is_valid(cover), 'fixture: it really died.')
	assert_eq(overshield(), 0, 'A hostile OBJECT dying grants nothing.')

func test_an_allied_death_grants_nothing():
	SluaghFixture.set_grit(sluagh, GRIT)
	var friend:Unit = SluaghFixture.create_ally(game, NEAR_TILE)
	await SluaghFixture.kill(game, friend)
	assert_false(Unit.is_valid(friend), 'fixture: it really died.')
	assert_eq(overshield(), 0, 'An ALLY dying grants nothing - the card says hostile.')

func test_a_meltdown_grants():
	# RULING 11, "meltdowns included", and it is not a second gate: event_unit_meltdown runs its 4d6
	# burst and then executes event_unit_die itself (event_unit_meltdown.gd:63), so the DEATH trigger
	# fires exactly as it does for any other destruction. Asserted because "a meltdown is a different
	# event" is the obvious worry and this is the cheapest way to retire it.
	#
	# THE BURST IS REAL AND IT REACHES US. The victim stands at Sensors range rather than next door,
	# so the Sluagh - 8 HP, 0 armor - is nowhere near the explosion. A near tile would kill the mech
	# under test.
	SluaghFixture.set_grit(sluagh, GRIT)
	var victim:Unit = SluaghFixture.create_hostile(game, AT_SENSORS_TILE)
	await SluaghFixture.meltdown(game, victim)
	assert_false(Unit.is_valid(victim), 'fixture: the meltdown really destroyed it.')
	assert_eq(overshield(), GRIT, 'A meltdown is a destruction and grants too.')
	assert_eq(sluagh.current_damage(), 0, 'fixture: and the Sluagh was well outside the burst.')

func test_a_second_death_in_the_same_round_grants_again():
	# NO LIMIT ON THE CARD, so the reaction keeps ActionReaction's own 99 (action_reaction.gd:69)
	# rather than overriding it to 1 the way Halo does.
	#
	# THE OVERSHIELD IS SPENT BETWEEN THE TWO DEATHS, and that is what makes this test able to fail.
	# event_unit_overshield sets max(old, amount) and never adds (event_unit_overshield.gd:15), so a
	# second grant of 2 onto a unit already holding 2 changes no number at all - the naive version of
	# this test passes whether the second reaction fires or not. Two damage soaked by the shield
	# takes it to 0 without touching the 8 HP frame (event_unit_damage.gd:215-218), and the second
	# death then has something to prove.
	#
	# NO TURN STARTS ANYWHERE IN HERE, deliberately: uses_this_round is cleared by
	# UnitAction.new_turn_refresh at the SLUAGH's own turn start, so a start_turn between the two
	# deaths would make this vacuous even if the limit were 1.
	SluaghFixture.set_grit(sluagh, GRIT)
	var first:Unit = SluaghFixture.create_hostile(game, NEAR_TILE)
	var second:Unit = SluaghFixture.create_hostile(game, SECOND_NEAR_TILE)

	await SluaghFixture.kill(game, first)
	assert_eq(overshield(), GRIT, 'fixture: the first death granted.')

	await game.execute_event(&'event_unit_damage', {unit = sluagh, number = GRIT})
	assert_eq(overshield(), 0, 'fixture: the shield soaked it and is spent.')
	assert_eq(sluagh.current_damage(), 0, 'fixture: and none of it reached the 8 HP frame.')

	await SluaghFixture.kill(game, second)
	assert_eq(overshield(), GRIT, 'The second death in the same round grants again.')

func test_a_grit_zero_pilot_grants_nothing_and_fires_no_event():
	# Overshield.grant refuses an amount of 0 outright and fires NO event (overshield.gd:78), because
	# event_unit_overshield always plays a popcorn and writes a battle-log line (:17-22) - so without
	# the gate a level-0 pilot would see "now has 0 overshield" on screen for every enemy that died.
	# The reaction ALSO refuses at the gate, Halo's shape, so it is never even offered.
	#
	# ASSERTED ON THE GATE ITSELF as well as on the log, and the gate half is the only half that
	# discriminates. MEASURED 2026-09-20 (SP1 Task 3, mutation 4): with the Grit clause removed from
	# triggers_on_event the reaction IS offered and event_gear_activate runs, but activate()'s own
	# `abort_when(amount <= 0)` aborts it before spend_actions - and Overshield.grant refuses a 0
	# amount underneath that again - so NO battle-log line is written either way and the log assertion
	# below stays green under that mutation. The plan predicted a red there; three layers of guard say
	# otherwise, and the aborted event block is a print, not a battle-log row. Polling the gate
	# directly is what actually pins the first layer, which is the one that keeps the reaction from
	# being offered at all.
	var victim:Unit = SluaghFixture.create_hostile(game, NEAR_TILE)
	assert_eq(Overshield.grit(sluagh), 0, 'fixture: a fresh pilot is licence level 0, so Grit 0.')

	var gear:GearCore = sluagh.get_gear(SluaghFixture.STEALING_ID)
	var reaction = gear.get_solo_action()
	var death := SpecFactory.dummy_event({unit = victim})
	assert_false(reaction.triggers_on_event(sluagh, gear, death),
		'At Grit 0 the reaction is not even OFFERED - every other clause of the gate passes for this '
		+ 'victim, so the Grit clause is the only thing refusing it.')
	SluaghFixture.set_grit(sluagh, GRIT)
	assert_true(reaction.triggers_on_event(sluagh, gear, death),
		'...and the same victim DOES offer it once the pilot has Grit, so the line above is not '
		+ 'refusing for some other reason.')
	SluaghFixture.set_grit(sluagh, 0)

	log_lines = []
	await SluaghFixture.kill(game, victim)
	assert_eq(overshield(), 0, 'Nothing was granted.')
	for line:String in log_lines:
		assert_false(line.to_lower().contains('overshield'),
			'And no overshield line was written: %s' % line)
