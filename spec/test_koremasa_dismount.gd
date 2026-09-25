# LASSISSIAN FOLLY, THE WAYS DOWN (Koremasa core power, design sections 2.3-2.5, rulings 2, 3, 12, 34):
#
#   "A mounted mech is impaired as long as you are riding them and may attempt to throw you off with a
#    contested Hull check as a Quick action."
#
# THREE WAYS A RIDE ENDS, one test group each:
#  - THE BUCK: a Quick, SITUATIONAL action on the RIDER's core Kit, offered to the stackup base only
#    (probe tests d-f). Contested Hull, the mount against the rider; a win throws the rider off.
#    make_contested_hull_check rolls the RIDER first (unit2, the number to beat), then the MOUNT.
#  - THE CLIMB-OFF (ruling 3, the author's divergence from Bel's text): a FREE action, offered only
#    while riding, onto a free tile adjacent to the mount.
#  - THE BREAK (ruling 2): the mount's death or exile, gear destruction, and the RIDER becoming
#    Stunned. Prone, Immobilized or Stunned on the MOUNT end nothing - Gut Reactor knocks the mount
#    Prone, and the harness's list would have the core passive throw its own rider off.
#
# EVERY WAY DOWN LEAVES NOTHING BEHIND (assert_dismounted): out of the stackup, one tile of its own
# adjacent to the mount, and none of the three ride buffs on either unit - which is also what makes
# the mount stop being Impaired (ruling 12: the ride chip IS the Impaired).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_koremasa_dismount.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 3)
const MOUNT_TILE := Vector2i(7, 3) ## size 2: (7,3) (8,3) (7,4) (8,4)
const LANDING := Vector2i(6, 3)
const OFF_EAST := Vector2i(9, 3) ## 1 from (8,3): a climb-off destination
const BYSTANDER_TILE := Vector2i(12, 8)

var game:Gamemaster
var responder
var koremasa:Unit
var mount:Unit
var bystander:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	mount = Fixture.create_mount(game, MOUNT_TILE)
	bystander = Fixture.create_hostile(game, BYSTANDER_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func ride() -> void:
	responder.chosen_move_tile = LANDING
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)
	responder.chosen_move_tile = Tile.INVALID
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: the Koremasa is riding.')

func open_turn(unit:Unit) -> void:
	for other:Unit in [koremasa, mount, bystander]:
		if other != unit and other.state.is_taking_turn: await SpecFactory.end_turn(game, other)
	await Fixture.cycle_turn(game, unit)

func offered_bucks(unit:Unit) -> Array[SpecificAction]:
	return UnitAction.get_situational_actions(unit).filter(func(specific:SpecificAction) -> bool:
		return specific.action.get_id() == Fixture.BUCK_ACTION
	)

func buck(rider_d20:int, mount_d20:int) -> void:
	await open_turn(mount)
	var offered := offered_bucks(mount)
	assert_eq(offered.size(), 1, 'LIVENESS: the mount is offered exactly one buck.')
	if offered.is_empty(): return
	Fixture.queue([rider_d20, mount_d20])
	await SpecFactory.use_specific(game, offered.front())

func climb_off_offered() -> bool:
	return UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.CLIMB_OFF_ACTION))

func climb_off(to:Vector2i) -> void:
	responder.chosen_move_tile = to
	await Fixture.use_core(game, koremasa, Fixture.CLIMB_OFF_ACTION)

## A status through the REAL event. UnitCondition.apply_status on SpecFactory.dummy_event() queues
## its statuses_changed reactions onto an event nobody executes, so the ride break could never fire -
## a "keeps its rider" test written that way passes whatever the break does (caught by mutation M1b).
func afflict(unit:Unit, status:StringName) -> void:
	await game.execute_event(&'event_unit_apply_status', {
		unit = unit, category = status, flags = [Lancer.UNTIL.MANUAL],
	})

func assert_dismounted() -> void:
	assert_false(UnitCondition.is_in_stackup(koremasa), 'The rider is out of the stackup.')
	assert_false(UnitCondition.is_in_stackup(mount), 'The mount is out of the stackup.')
	assert_false(Katamari.are_attached(koremasa, mount), 'They are no longer attached.')
	assert_eq(koremasa.occupied_tiles().size(), 1, 'The rider is back to its own footprint.')
	assert_eq(UnitRelation.distance_between(koremasa, mount), 1, 'It landed adjacent to the mount.')
	assert_false(mount.has_status(Lancer.STATUS.IMPAIRED), 'The mount is no longer impaired.')
	assert_true(Fixture.ride_buffs_on(mount, koremasa).is_empty(), 'Nothing of the ride is left on the mount.')
	assert_true(Fixture.ride_buffs_on(koremasa, koremasa).is_empty(), 'Nothing of the ride is left on the rider.')

# ---------------------------------------------------------------- the climb-off (ruling 3)

func test_the_climb_off_is_a_free_movement_action():
	var action:Action = ContentLibrary.get_kit(Fixture.CORE_ID).get_action(Fixture.CLIMB_OFF_ACTION)
	assert_true(action is ActionSystemMovement, 'The climb-off is a movement action.')
	if action == null: return
	assert_eq(action.action_type, Lancer.ACTION.FREE, 'FREE (the author, ruling 3).')

func test_the_climb_off_is_offered_only_while_riding():
	await Fixture.open_turn(game, koremasa)
	assert_false(climb_off_offered(), 'Not riding: nothing to climb off.')
	await ride()
	assert_true(climb_off_offered(), 'Riding: offered, despite a rider having no movement of its own.')

func test_climbing_off_lands_beside_the_mount_and_ends_the_ride():
	await ride()
	var actions_before := koremasa.state.actions
	await climb_off(OFF_EAST)
	assert_eq(koremasa.tile(), OFF_EAST, 'It climbed down where it chose.')
	assert_dismounted()
	assert_eq(koremasa.state.actions, actions_before, 'A free action: nothing spent.')

func test_the_climb_off_cannot_go_further_than_beside_the_mount():
	await ride()
	await climb_off(Vector2i(11, 3)) # 3 from the mount
	assert_true(Fixture.is_riding(koremasa, mount), 'An out-of-range tile is refused; still riding.')

func test_after_climbing_off_it_can_climb_back_on():
	await ride()
	await climb_off(OFF_EAST)
	assert_true(UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.BEGIN_RIDING_ACTION)),
		'Begin-riding is on offer again: the ride left no stale state.')
	await Fixture.use_core(game, koremasa, Fixture.BEGIN_RIDING_ACTION)
	assert_true(Fixture.is_riding(koremasa, mount), 'And it rides again.')

func test_a_dismount_keeps_an_impaired_from_elsewhere_on_the_same_kit():
	# Ruling 12. Gut Reactor impairs from the SAME core Kit; ending the ride must not strip it.
	await ride()
	UnitCondition.apply_status(SpecFactory.dummy_event(), mount, Lancer.STATUS.IMPAIRED,
		Lancer.UNTIL.MANUAL, Fixture.core(koremasa).persistent_id)
	await climb_off(OFF_EAST)
	assert_false(UnitCondition.is_in_stackup(koremasa), 'fixture: dismounted.')
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'The other Impaired from the core Kit stays.')

# ---------------------------------------------------------------- the buck (probe d-f)

func test_the_buck_is_offered_to_the_mount_and_nobody_else():
	await open_turn(mount)
	assert_eq(offered_bucks(mount).size(), 0, 'Unridden, the mount is offered nothing.')
	await ride()
	await open_turn(mount)
	var offered := offered_bucks(mount)
	assert_eq(offered.size(), 1, 'Ridden, the mount is offered the buck.')
	if not offered.is_empty():
		assert_eq(offered.front().gear, Fixture.core(koremasa), "It comes from the RIDER's core Kit.")
		assert_eq(offered.front().unit, mount, "It is the MOUNT's action.")
		assert_eq(offered.front().action.action_type, Lancer.ACTION.QUICK, '"as a Quick action".')
	await open_turn(bystander)
	assert_eq(offered_bucks(bystander).size(), 0, 'Another hostile is offered nothing.')
	await open_turn(koremasa)
	assert_eq(offered_bucks(koremasa).size(), 0, 'The rider is not offered its own buck.')

func test_a_buck_that_wins_the_contested_hull_check_throws_the_rider_off():
	await ride()
	await buck(5, 15)
	assert_dismounted()

func test_a_buck_that_loses_leaves_the_rider_on_and_still_costs_the_quick_action():
	await ride()
	await buck(15, 5)
	assert_true(Fixture.is_riding(koremasa, mount), 'The rider hangs on.')
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'Still impaired.')
	assert_lt(mount.state.actions, Lancer.ACTION_COST_FULL, 'The failed buck still cost the mount its Quick action.')

func test_an_ai_mount_is_offered_the_buck_by_its_decider():
	# Ruling 34: the one AI option this core builds.
	await ride()
	await open_turn(mount)
	var options:Array[TargetingPick] = await AiActionDecider.create_action_options_for(mount)
	var bucks := options.filter(func(pick:TargetingPick) -> bool:
		return pick.specific.action.get_id() == Fixture.BUCK_ACTION)
	assert_eq(bucks.size(), 1, 'The AI mount weighs a buck among its options.')

# ---------------------------------------------------------------- what ends a ride (ruling 2)

func test_the_mount_knocked_prone_keeps_its_rider():
	await ride()
	await afflict(mount, Lancer.STATUS.PRONE)
	assert_true(mount.has_status(Lancer.STATUS.PRONE), 'fixture: the mount is prone.')
	assert_true(Fixture.is_riding(koremasa, mount), 'Prone on the mount ends nothing.')

func test_the_mount_immobilized_or_stunned_keeps_its_rider():
	await ride()
	await afflict(mount, Lancer.STATUS.IMMOBILIZED)
	await afflict(mount, Lancer.STATUS.STUNNED)
	assert_true(mount.has_status(Lancer.STATUS.STUNNED), 'fixture: the mount is stunned.')
	assert_true(Fixture.is_riding(koremasa, mount), 'Immobilized or Stunned on the mount ends nothing.')

func test_the_rider_prone_or_immobilized_keeps_riding():
	await ride()
	await afflict(koremasa, Lancer.STATUS.IMMOBILIZED)
	await afflict(koremasa, Lancer.STATUS.PRONE)
	assert_true(Fixture.is_riding(koremasa, mount), 'Only Stunned on the rider breaks the ride.')

func test_the_rider_stunned_falls_off():
	await ride()
	await afflict(koremasa, Lancer.STATUS.STUNNED)
	assert_true(koremasa.has_status(Lancer.STATUS.STUNNED), 'fixture: the rider is stunned.')
	assert_dismounted()

func test_the_mount_dying_leaves_nothing_of_the_ride_on_the_rider():
	await ride()
	mount.core.current.structure = 1
	Fixture.queue([])
	await game.execute_event(&'event_unit_damage', {
		unit = mount, number = 9999, category = Lancer.DAMAGE_TYPE.KINETIC,
		flags = [EventService.DAMAGE_FLAG.AP],
	})
	assert_true(Unit.is_valid(koremasa), 'The rider is still on the field.')
	assert_false(UnitCondition.is_in_stackup(koremasa), 'Out of the stackup.')
	assert_eq(koremasa.occupied_tiles().size(), 1, 'Back to its own footprint.')
	assert_true(Fixture.ride_buffs_on(koremasa, koremasa).is_empty(), 'The crit rule went with the mount.')

func test_the_mount_exiled_ends_the_ride():
	await ride()
	await game.execute_event(&'event_unit_exile', {unit = mount})
	assert_false(UnitCondition.is_in_stackup(koremasa), 'Out of the stackup.')
	assert_true(Fixture.ride_buffs_on(koremasa, koremasa).is_empty(), 'Nothing of the ride on the rider.')
	assert_true(Fixture.ride_buffs_on(mount, koremasa).is_empty(), 'Nothing of the ride on the exiled mount.')

## INVULNERABLE and a DIRECT Intangible detach the stackup ENGINE-side (Katamari.dettach_everything,
## unit_condition.gd:156-157; handle_intangibilty_changing, :256-273) and raise only a statuses_changed
## event - no exile or intangible trigger. The Stasis Generator and the Specter's Ghostwalk
## (action_ghostwalk_specter.gd:7) are the vanilla sources. Found by the close review: the break used
## to take a status only on the rider and only Stunned, so the ride buffs outlived the ride.
func test_the_mount_made_invulnerable_ends_the_ride():
	await ride()
	await afflict(mount, Lancer.STATUS.INVULNERABLE)
	assert_true(mount.has_status(Lancer.STATUS.INVULNERABLE), 'fixture: the mount is invulnerable.')
	assert_dismounted()

func test_the_mount_made_intangible_ends_the_ride():
	await ride()
	await afflict(mount, Lancer.STATUS.INTANGIBLE)
	assert_true(mount.has_status(Lancer.STATUS.INTANGIBLE), 'fixture: the mount is intangible.')
	assert_dismounted()

func test_the_rider_made_invulnerable_ends_the_ride():
	await ride()
	await afflict(koremasa, Lancer.STATUS.INVULNERABLE)
	assert_dismounted()

func test_the_rider_made_intangible_ends_the_ride():
	await ride()
	await afflict(koremasa, Lancer.STATUS.INTANGIBLE)
	assert_dismounted()

func test_the_break_is_hidden_from_the_card():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	var action:Action = kit.get_action(Fixture.RIDE_BREAK_ACTION)
	assert_true(action is ActionReactionBreakConnection, 'The ride break is a break-connection reaction.')
	if action == null: return
	assert_false(action.show_in_tooltip(kit), 'Not on the card.')
	assert_false(action.consumes_rxn, 'Costs no reaction.')
