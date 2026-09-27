# STARSICKNESS - Six Sky SP1, design 1.4, rulings 5 and 11:
#
#   "When the Six Sky teleports a hostile character, it may take 1 Heat. If it does, that character must
#    succeed on a Systems save or become Impaired until the end of their next turn."
#
# The yes/no goes through testkit/mod_choice_responder.gd, which records every prompt, so "not offered"
# is asserted as ZERO prompts rather than inferred from an unchanged heat gauge. Every "not offered" has
# its control: the teleport is asserted to have landed.
#
# THE SAVE DISCRIMINATES THE FORCER. The dummies have Systems 0; a d20 of 10 FAILS against the Six Sky's
# Save 11 and would PASS against the default 10 (event_unit_save.gd:41-42), so the Impaired below also
# proves the save was the Six Sky's.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_starsickness.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const SIX_SKY_TILE := Vector2i(4, 4)
const VICTIM_TILE := Vector2i(7, 4)
const VICTIM_DEST := Vector2i(9, 4)
const SECOND_TILE := Vector2i(7, 6)
const SECOND_DEST := Vector2i(9, 6)
## Fails against Save 11 with Systems 0, and would pass against 10.
const FAIL_BY_ONE := 10
const PASS_ROLL := 20

var game:Gamemaster
var responder
var six_sky:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game_with_prompts(self)
	game = made[0]
	responder = made[1]
	six_sky = Fixture.create_six_sky(game, SIX_SKY_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func offers() -> int: return responder.yesno_prompts.size()

# ---------------------------------------------------------------- yes

func test_yes_costs_one_heat_and_a_failed_save_impairs():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	assert_eq(victim.core.get_sys(), 0, 'PRECONDITION: Systems 0, so the d20 alone decides the save.')
	assert_eq(six_sky.get_save_target(), 11, 'PRECONDITION: the Six Sky\'s Save is 11.')
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_eq(victim.tile(), VICTIM_DEST, 'CONTROL: the hostile landed.')
	assert_eq(offers(), 1, 'One yes/no.')
	assert_eq(Fixture.heat(six_sky), 1, 'The Six Sky took 1 heat.')
	assert_true(Fixture.is_impaired(victim), 'A 10 fails the Six Sky\'s Save 11: Impaired.')

func test_a_passed_save_still_costs_the_heat_but_does_not_impair():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(PASS_ROLL)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_eq(offers(), 1, 'CONTROL: offered and taken.')
	assert_eq(Fixture.heat(six_sky), 1, '"If it does" - the heat is paid whatever the save does.')
	assert_false(Fixture.is_impaired(victim), 'A passed save: no Impaired.')

func test_impaired_lasts_until_the_end_of_the_hostiles_next_turn():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_true(Fixture.is_impaired(victim), 'PRECONDITION: Impaired.')
	await SpecFactory.start_turn(game, victim)
	assert_true(Fixture.is_impaired(victim), 'Through its next turn.')
	await SpecFactory.end_turn(game, victim)
	assert_false(Fixture.is_impaired(victim), 'Gone at the end of it.')

func test_impaired_during_the_hostiles_own_turn_outlasts_that_turn():
	# The case that tells END_OF_NEXT_TURN from END_OF_THIS_TURN: applied mid-way through the VICTIM's own
	# turn (a crit shove on an Overwatch, say), "their next turn" is the one after. Applied outside the
	# victim's turn - every other test here - the two lifetimes behave the same (mutation-measured).
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	await SpecFactory.start_turn(game, victim)
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_true(Fixture.is_impaired(victim), 'PRECONDITION: Impaired during its own turn.')
	await SpecFactory.end_turn(game, victim)
	assert_true(Fixture.is_impaired(victim), 'Still Impaired after the turn it was applied in.')
	await SpecFactory.start_turn(game, victim)
	await SpecFactory.end_turn(game, victim)
	assert_false(Fixture.is_impaired(victim), 'Gone at the end of its NEXT turn.')

func test_the_save_is_forced_in_starsicknesss_name_and_impaired_is_its_own():
	# A full SpecificAction (the reason action_starsickness exists), and the status sourced from the
	# trait's gear, as Stuncrown sources its own.
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	var gear:GearCore = six_sky.get_gear(Fixture.STARSICKNESS_ID)
	var specific := SpecificAction.create(six_sky, gear, gear.get_action(Fixture.STARSICKNESS_ACTION))
	assert_true(SpecificAction.is_valid(specific), 'The trait yields a VALID SpecificAction to force with.')
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_true(UnitCondition.has_status(victim, Lancer.STATUS.IMPAIRED, gear.persistent_id),
		'Impaired, sourced from the Starsickness gear.')

# ---------------------------------------------------------------- no, and not offered

func test_no_costs_nothing_and_forces_nothing():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	responder.yesno_queue.assign([false])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, victim, VICTIM_DEST)
	assert_eq(offers(), 1, 'CONTROL: it was offered.')
	assert_eq(Fixture.heat(six_sky), 0, 'Declined: no heat.')
	assert_false(Fixture.is_impaired(victim), 'And no save to fail.')

func test_an_ally_teleport_is_not_offered():
	var ally:Unit = Fixture.create_ally(game, VICTIM_TILE)
	await Fixture.shove(six_sky, ally, VICTIM_DEST)
	assert_eq(ally.tile(), VICTIM_DEST, 'CONTROL: the ally landed.')
	assert_eq(offers(), 0, '"A HOSTILE character" - never an ally.')

func test_a_hostile_drone_is_offered():
	# A drone is a character (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 4).
	var drone:Unit = Fixture.create_drone(game, VICTIM_TILE)
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(six_sky, drone, VICTIM_DEST)
	assert_eq(drone.tile(), VICTIM_DEST, 'CONTROL: the drone landed.')
	assert_eq(offers(), 1, 'A drone is a character (ruling 2026-09-27), so it is offered like any other.')
	assert_eq(Fixture.heat(six_sky), 1, 'The Six Sky took 1 heat.')
	assert_true(Fixture.is_impaired(drone), 'A 10 fails the Six Sky\'s Save 11: Impaired.')

func test_teleporting_itself_is_not_offered():
	await Fixture.teleport_self(six_sky, VICTIM_DEST)
	assert_eq(six_sky.tile(), VICTIM_DEST, 'CONTROL: the Six Sky landed.')
	assert_eq(offers(), 0, 'The Six Sky is not hostile to itself.')

func test_a_hostile_teleported_by_someone_else_is_not_offered():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	var ally:Unit = Fixture.create_ally(game, Vector2i(2, 2))
	await Fixture.shove(ally, victim, VICTIM_DEST)
	assert_eq(victim.tile(), VICTIM_DEST, 'CONTROL: the hostile landed.')
	assert_eq(offers(), 0, 'Only a teleport the SIX SKY causes.')

func test_a_hostile_teleporting_the_six_sky_is_not_offered():
	var hostile:Unit = Fixture.create_hostile(game, VICTIM_TILE)
	await Fixture.shove(hostile, six_sky, Vector2i(4, 7))
	assert_eq(six_sky.tile(), Vector2i(4, 7), 'CONTROL: the Six Sky was moved.')
	assert_eq(offers(), 0, 'The mover is the Six Sky, not a hostile.')

# ---------------------------------------------------------------- no limit, and the AI

func test_every_hostile_teleport_is_its_own_offer():
	# No per-round limit (ruling 11): two hostiles, two moves, two offers.
	var first:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	var second:Unit = Fixture.create_dummy(game, SECOND_TILE)
	responder.yesno_queue.assign([true, true])
	VaubanFixture.queue_save_dice(PASS_ROLL)
	await Fixture.shove(six_sky, first, VICTIM_DEST)
	VaubanFixture.queue_save_dice(PASS_ROLL)
	await Fixture.shove(six_sky, second, SECOND_DEST)
	assert_eq(second.tile(), SECOND_DEST, 'CONTROL: both landed.')
	assert_eq(offers(), 2, 'Two offers.')
	assert_eq(Fixture.heat(six_sky), 2, 'Two heat.')

func test_an_ai_six_sky_declines():
	var ai_six_sky:Unit = Fixture.create_six_sky(game, Vector2i(2, 8), Faction.AI_ENEMY)
	var player_mech:Unit = Fixture.create_dummy(game, VICTIM_TILE, 10, Faction.PLAYER)
	assert_true(UnitRelation.are_enemies(ai_six_sky, player_mech), 'PRECONDITION: a hostile to it.')
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.shove(ai_six_sky, player_mech, VICTIM_DEST)
	assert_eq(player_mech.tile(), VICTIM_DEST, 'CONTROL: the player mech landed.')
	assert_eq(offers(), 0, 'Nothing is asked of the player.')
	assert_eq(Fixture.heat(ai_six_sky), 0, 'The AI declines: no heat.')
	assert_false(Fixture.is_impaired(player_mech), 'And no save.')

# ---------------------------------------------------------------- close review: who teleported it

func test_a_hostile_walking_into_the_six_skys_realspace_breach_is_offered():
	var breach:Unit = await Fixture.deploy_realspace_breach(game, six_sky, Vector2i(5, 5))
	assert_not_null(breach, 'PRECONDITION: the Sunzi action laid a breach.')
	if breach == null: return
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	responder.yesno_queue.assign([true])
	VaubanFixture.queue_save_dice(FAIL_BY_ONE)
	await Fixture.breach_teleport(game, breach, victim, VICTIM_DEST)
	assert_eq(victim.tile(), VICTIM_DEST, 'CONTROL: the hostile landed.')
	assert_eq(offers(), 1, 'The Six Sky breach teleported a hostile: offered.')
	assert_true(Fixture.is_impaired(victim), 'And the save was forced.')

func test_a_hostile_swapped_by_the_six_skys_beckoner_is_offered():
	var victim:Unit = Fixture.create_dummy(game, VICTIM_TILE)
	await Fixture.open_turn(game, six_sky)
	responder.yesno_queue.assign([true])
	await Fixture.beckon(game, six_sky, victim)
	assert_eq(victim.tile(), SIX_SKY_TILE, 'CONTROL: the Beckoner swapped the two.')
	assert_eq(offers(), 1, 'The Six Sky teleported a hostile: offered.')
