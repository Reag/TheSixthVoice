# FLEET OF FOOT - the Leoleth's third sheet trait (SP1 Task 4).
#
#   "The Leoleth does not lose any movement from becoming Engaged."
#
# ONE PERMANENT HIDDEN BuffMovementType carrying a MovementType with ignore_engagement and nothing
# else (ruling 5). No script: the archetype already exists
# (engine/character/buff/archtypes/buff_movement_type.gd) and npcf_climber_sniper.tres is the same
# trait one flag over.
#
# TWO PLACES READ IT, AND BOTH ARE TESTED. MovementType.ignores_engagement() (movement_type.gd:104)
# is consulted by the PATHFINDER before it builds a single connection (pathfinder.gd:434, which
# guards the whole engaged-tile pass) and by the MID-MOVE STOP
# (unit_relation.gd:133-135, from event_unit_move.gd:252-253). A trait that fixed only one of them
# would leave half the card dead, so every claim here is made twice: once about what the Leoleth can
# reach, once about what it still has left.
#
# EVERY POSITIVE CASE HAS A CONTROL, and the control is a plain PLAYER mech on the same tiles with
# the same enemy. Without it "the Leoleth reached that tile" says nothing about engagement - it might
# simply be a tile anyone can reach.
#
# THE GEOMETRY, AND IT IS MEASURED RATHER THAN REASONED (SP1 Task 4 correction). The plan's draft
# stood the enemy OFF the mover's row, at (6,5), so that only its engagement zone was in the way.
# That does not wall anybody in, and the first run proved it: an engagement zone is a 3x3 square and
# movement here is CHEBYSHEV (the run's own map print shows the eight engaged tiles around the
# enemy, and the control reached its far tile), so a mover standing on the zone's EDGE row steps one
# row out, walks past and steps back for the same four steps it would have spent going through. The
# control test was red and the positive pathfinder test passed WITHOUT the trait.
#
# So the enemy stands ON the mover's row instead. The Leoleth is at (4,6), the enemy at (6,6), and
# the zone is (5,5)-(7,7): to get round it a plain mech has to reach row 4 or row 8, two rows out and
# back, which is six steps against a budget of four. The Leoleth ignores the zone and weaves around
# the BODY diagonally - (5,6) (6,5) (7,6) (8,6) - for exactly four. BEYOND is therefore reachable
# only by a unit that ignores engagement, which is the whole point of the test.
#
# THE CONTROL BAND IS ROW 10 for the same shape one zone clear of this one: zone (5,9)-(7,11)
# against this one's (5,5)-(7,7).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_fleet_of_foot.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const START := Vector2i(4, 6)
## ON the mover's row, two east: its zone reaches a full row above and below the line of travel, so
## going round it costs more than the budget. Its body is walked around diagonally instead.
const ENEMY_TILE := Vector2i(6, 6)
## Four steps east of START on flat ground, and the first tile past the enemy's engagement zone.
const BEYOND := Vector2i(8, 6)
## One step east: inside the zone. Entering it is what a vanilla mech's movement dies on.
const INTO_THE_ZONE := Vector2i(5, 6)
## Where the control mech stands, so the two never share a tile OR a zone.
const CONTROL_START := Vector2i(4, 10)
const CONTROL_BEYOND := Vector2i(8, 10)
const CONTROL_ENEMY_TILE := Vector2i(6, 10)
const CONTROL_INTO_THE_ZONE := Vector2i(5, 10)
## The sap case: a hostile three steps out that still has a step left when it arrives, so "it lost
## the rest of its movement" is a number the test can tell apart from "it spent everything walking".
const WALKER_START := Vector2i(8, 8)
const WALKER_END := Vector2i(5, 7)

var game:Gamemaster
var leoleth:Unit
var enemy:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, START)
	enemy = LeolethFixture.create_hostile(game, ENEMY_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Where a STANDARD move could take this unit right now. include_boost false, because a Boosted
## reach would muddle "four steps at speed 4" with "eight steps at speed 8".
##
## AWAITED, and it has to be: generate_for_standard_move builds the graph on a worker thread
## (pathfinder.gd:234, `await X.run_worker_thread`), so it is a coroutine and a call without `await`
## is a PARSE error - which GUT reports as "does not extend GutTest" and skips the whole file.
## Vanilla's own callers all await it (test/gear/test_ms_eva_module.gd:18 and eight more).
func reachable(unit:Unit) -> Pathfinder:
	return await Pathfinder.generate_for_standard_move(unit, MovementType.create_for_standard_move(unit), false)

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_the_chip_is_hung():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.FLEET_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % LeolethFixture.FLEET_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	assert_true(GearCore.is_valid(leoleth.get_gear(LeolethFixture.FLEET_ID)),
		'And the live Leoleth carries it as gear.')
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.FLEET_BUFF),
		'The applicator hung the chip at the start of combat.')
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('gear.mt_fleet_of_foot.name'), StringName(''), 'It has a name row.')
	assert_eq(X.tr('gear.mt_fleet_of_foot.name'), 'Fleet of Foot', 'Named off the card.')
	assert_eq(X.tr('gear.mt_fleet_of_foot.effect'),
		'The Leoleth does not lose any movement from becoming |Engaged|.',
		'And the effect row is the card with the one glossary pipe.')

func test_the_chip_carries_ignore_engagement_and_nothing_else():
	# DECLARATIVE, and deliberately exhaustive: MovementType declares SEVENTEEN behavioural booleans
	# (movement_type.gd:5-25 - the plan's draft said fourteen) and merge_in ORs all of them except
	# `ignore_fall_damage` into the mover's type (:79-96, which has no line for it). A stray
	# `teleport = true` would also skip overwatch and fall damage, and every behavioural test in this
	# file would stay green.
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.FLEET_BUFF)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.FLEET_BUFF)
	if buff == null: return
	assert_true(buff is BuffMovementType, 'It is the vanilla BuffMovementType archetype - no script.')
	if not (buff is BuffMovementType): return
	assert_eq(buff.to, Buff.TO.MOVEMENT_TYPE, 'to = movement_type.')
	assert_true(buff.hide_from_player, 'Hidden: the trait card is the explanation.')
	assert_eq(buff.until, Lancer.UNTIL.MANUAL, 'And permanent.')
	var type:MovementType = buff.movement_type
	assert_not_null(type, 'It carries a MovementType.')
	if type == null: return
	assert_true(type.ignore_engagement, 'ignore_engagement is set - the whole card.')
	for flag:String in ['spend_move', 'voluntary', 'ignore_rxns', 'ignore_dangerous', 'ignore_difficult',
			'free_climb', 'flying', 'hovering', 'teleport', 'straight_line', 'must_move_max_possible',
			'can_break_interiors', 'can_move_through_enemies', 'cannot_move_uphill', 'jump_downhill',
			'ignore_fall_damage']:
		assert_false(type.get(flag), 'And %s is NOT set - merge_in ORs it into the mover (:79-96).' % flag)
	assert_true(type.other_tags.is_empty(), 'And it carries no tags.')

# ---------------------------------------------------------------- the pathfinder

func test_the_pathfinder_offers_tiles_past_an_adjacent_enemy():
	await LeolethFixture.open_turn(game, leoleth)
	assert_eq(leoleth.get_speed_max(), 4, 'fixture: four steps, and BEYOND is exactly four away.')
	assert_true((await reachable(leoleth)).is_movable(BEYOND),
		'The Leoleth walks straight through the engagement zone - pathfinder.gd:434 never builds it.')

func test_a_mech_without_the_trait_is_walled_in_by_the_same_enemy():
	# THE CONTROL, and it is what makes the test above mean anything: on identical geometry a plain
	# mech cannot reach the far tile, because every route to it passes through a tile the enemy
	# engages and an engaged tile has no outward connections.
	var control:Unit = LeolethFixture.create_ally(game, CONTROL_START)
	LeolethFixture.create_hostile(game, CONTROL_ENEMY_TILE)
	await LeolethFixture.open_turn(game, control)
	assert_eq(control.get_speed_max(), 4, 'fixture: the control has the same budget.')
	assert_false(LeolethFixture.has(control, LeolethFixture.FLEET_BUFF), 'fixture: and not the trait.')
	assert_false((await reachable(control)).is_movable(CONTROL_BEYOND),
		'A plain mech cannot get past the same enemy on the same geometry.')

# ---------------------------------------------------------------- the mid-move stop

func test_walking_into_engagement_leaves_the_budget_intact():
	await LeolethFixture.open_turn(game, leoleth)
	await LeolethFixture.walk(game, leoleth, INTO_THE_ZONE)
	assert_true(UnitCondition.is_engaged(leoleth), 'LIVENESS: it really is Engaged now.')
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() - 1,
		'And it lost exactly the one space it walked - nothing to engagement.')

func test_a_mech_without_the_trait_loses_its_budget_there():
	var control:Unit = LeolethFixture.create_ally(game, CONTROL_START)
	LeolethFixture.create_hostile(game, CONTROL_ENEMY_TILE)
	await LeolethFixture.open_turn(game, control)
	await LeolethFixture.walk(game, control, CONTROL_INTO_THE_ZONE)
	assert_true(UnitCondition.is_engaged(control), 'fixture: the control is Engaged too.')
	assert_eq(control.core.current.speed, 0,
		'And a plain mech loses everything - event_unit_move.gd:252-253.')

func test_a_size_99_engager_stops_nothing_either():
	# RULING 5'S ACCEPTED CONSEQUENCE, pinned. The Minotaur's Localized Maze is a COUNTS_AS_SIZE 99
	# buff (content/frames/horus/mf_minotaur/mt_localized_maze/buff_localized_maze.tres, to =
	# &"counts_as_size"), and "must stop when Engaged" effects built on it work by winning the size
	# compare in would_lose_movement_due_to_engagement_from (unit_relation.gd:140-143). That compare is
	# never reached for an ignoring mover: :135 returns false first. So the Leoleth walks through the
	# Maze, and the author accepted that when ruling 5 was taken.
	#
	# APPLIED AS THE VANILLA BUFF ITSELF, by id, rather than by faking a size: if the talents mod or a
	# modkit update changes what that buff does, this test should notice.
	SpecFactory.apply_buff(enemy, LeolethFixture.MAZE_BUFF)
	assert_true(LeolethFixture.has(enemy, LeolethFixture.MAZE_BUFF), 'fixture: the Maze buff is live.')
	await LeolethFixture.open_turn(game, leoleth)
	assert_true((await reachable(leoleth)).is_movable(BEYOND), 'The pathfinder still offers the far tile.')
	await LeolethFixture.walk(game, leoleth, INTO_THE_ZONE)
	assert_eq(leoleth.core.current.speed, leoleth.get_speed_max() - 1,
		'And walking in still costs only the step.')

func test_the_leoleth_still_saps_the_speed_of_what_it_engages():
	# THE OTHER HALF OF RULING 5. The card only says the LEOLETH does not lose movement, so a hostile
	# that walks into the Leoleth's reach must still lose the rest of its own - and it does, because
	# the stop is read off the MOVER's movement type and the mover here is the hostile.
	#
	# WHICH LINE PRODUCES THE ZERO, measured rather than assumed (the plan's draft cited the other
	# one). get_engaging_units(unit) returns the units engaging the MOVER (unit_relation.gd:190-200),
	# so for a hostile walking in it is [the Leoleth] - and event_unit_move.gd:252-253 zeroes the
	# WALKER. The second loop at :255-258 fires too, and zeroes the stationary Leoleth's own remaining
	# speed; nothing in Fleet of Foot touches that loop, which is the accepted shape rather than a
	# defect - the Leoleth's budget is refreshed at its own turn start anyway.
	#
	# THE WALKER ARRIVES WITH A STEP IN HAND (three steps against a budget of four), so `0` is a
	# number this test can tell apart from "it simply spent everything getting here".
	var walker:Unit = LeolethFixture.create_hostile(game, WALKER_START)
	await LeolethFixture.open_turn(game, walker)
	assert_eq(walker.core.current.speed, walker.get_speed_max(), 'fixture: the walker starts full.')
	await LeolethFixture.walk(game, walker, WALKER_END)
	assert_true(UnitCondition.is_engaged(walker), 'LIVENESS: it walked into the Leoleth\'s reach.')
	assert_eq(walker.core.current.speed, 0,
		'And it lost the rest of its movement - the Leoleth still engages.')
