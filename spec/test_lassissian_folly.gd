# LASSISSIAN FOLLY (Koremasa core power, design section 2.1-2.3, rulings 2-12):
#
#   "Move up to your speed towards a larger hostile mech character. If you end this movement
#    adjacent to them you move into their space and start riding them. While riding a mech in this
#    way, you occupy the same space as them, move when they move (even if you are Slowed or
#    Immobilized), and all of your attacks against them are considered critical hits. Resulting
#    damage is not rolled twice. A mounted mech is impaired as long as you are riding them [...]
#    For the rest of the scene, when you are adjacent to a larger hostile mech character, you may
#    begin riding them as a quick action."
#
# THE RIDE IS THE ENGINE'S OWN STACKUP (spike 7; its probe spec/test_spike_riding.gd is at 1dce97b,
# deleted at the frame close): PassiveAttachment is_stackup on the core Kit,
# CommonActionUtil.start_riding, and three buffs from the core Kit - the VISIBLE ride chip on the
# mount (it IS the Impaired, ruling 12), the hidden single-roll reduction beside it, and the hidden
# crit rule on the rider. This file covers what the probe did (tests a-c, g-j; a's engagement, b's
# Overwatch and c's knockback were ported here at the close) against the PRODUCTION Kit, plus
# everything the probe never had: the move, the pick, "ride now", and begin-riding's hibernation. The dismount side (climb-off, buck, what ends a ride) is
# spec/test_koremasa_dismount.gd; Gut Reactor is spec/test_gut_reactor.gd.
#
# GEOMETRY. The mount is SIZE 2 anchored at (7,3): it occupies (7,3) (8,3) (7,4) (8,4), and
# distance_between is Chebyshev over the closest tiles. The Koremasa starts at (3,3), four from it -
# out of reach, inside its speed 4.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_lassissian_folly.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 3)
const MOUNT_TILE := Vector2i(7, 3)
const LANDING := Vector2i(6, 3) ## 1 from (7,3): in reach after the move
const SHORT_LANDING := Vector2i(3, 6) ## 4 from the mount: a move that ends with nobody in reach
const BESIDE := Vector2i(6, 4) ## 1 from (7,4): where a test starts already in reach
const TWO_OUT := Vector2i(5, 4) ## 2 from (7,4)
const RIDE_TO := Vector2i(10, 3) ## three steps east for the mount
const SHOVE_TO := Vector2i(10, 5) ## two south of RIDE_TO, as a knockback would

var game:Gamemaster
var responder
var koremasa:Unit
var mount:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.MELEE) # before any state: equip full_repairs
	mount = Fixture.create_mount(game, MOUNT_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.unit_queue.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func place(unit:Unit, tile:Vector2i) -> void:
	UnitTile.move_to(unit, tile)
	UnitTile.update_tracking_and_statuses(game.map)

func folly(move_to:Vector2i = Tile.INVALID, ride_now = null) -> void:
	if ride_now != null: responder.yesno_queue.append(ride_now)
	responder.chosen_move_tile = move_to
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)

func begin_riding() -> void:
	await Fixture.use_core(game, koremasa, Fixture.BEGIN_RIDING_ACTION)

func begin_riding_offered() -> bool:
	return UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.BEGIN_RIDING_ACTION))

func wake_begin_riding() -> void:
	Fixture.core(koremasa).wake_action(Fixture.BEGIN_RIDING_ACTION)

## The d20, the blade's hit die, then its crit die (1d6+2): the probe's order.
func slash(target:Unit, d20:int, hit_die:int, crit_die:int) -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue([d20, hit_die, crit_die])
	await SpecFactory.use_solo(game, koremasa, Fixture.MELEE, target, [Action.FLAG.AS_FREEBIE])

func health_lost(unit:Unit, before:int) -> int: return before - unit.core.current.health

# ---------------------------------------------------------------- wiring

func test_the_core_kit_is_a_stackup_trait_carrying_the_folly():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_true(Kit.is_valid(kit), 'cp_overdrive_exploitation_sequences is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'The core system is a trait Kit.')
	assert_true(kit.passives.any(
		func(passive:Passive) -> bool: return passive is PassiveAttachment and passive.is_stackup),
		'It carries the stackup passive start_riding demands (common_action_util.gd:536-541).')
	var folly:Action = kit.get_action(Fixture.FOLLY_ACTION)
	assert_true(folly is ActionSystemMovement, 'Lassissian Folly is a movement action.')
	if not folly is ActionSystemMovement: return
	assert_eq(folly.action_type, Lancer.ACTION.QUICK, '(Quick).')
	assert_true(folly.consumes_cp, 'It is the core power (consumes_cp).')
	assert_eq(kit.uses_per_scene, 0, 'NOT Kit.uses_per_scene: that is Kit-wide and would block begin-riding and the buck.')

func test_begin_riding_is_a_quick_action_that_starts_asleep():
	var action:Action = ContentLibrary.get_kit(Fixture.CORE_ID).get_action(Fixture.BEGIN_RIDING_ACTION)
	assert_not_null(action, 'The Kit carries begin-riding.')
	if action == null: return
	assert_eq(action.action_type, Lancer.ACTION.QUICK, '"as a quick action".')
	assert_true(action.starts_hibernating, 'Asleep until the Folly has been used this scene.')

# ---------------------------------------------------------------- the move, then the ride

func test_the_folly_moves_then_rides_a_larger_hostile_it_ends_beside():
	await folly(LANDING)
	assert_true(Fixture.is_riding(koremasa, mount), 'It moved beside the mount, then climbed into its space.')
	assert_eq(koremasa.occupied_tiles(), mount.occupied_tiles(), 'It occupies the whole footprint.')
	assert_false(koremasa.core.has_core_power, 'The core power is spent.')

func test_the_ridden_mount_is_impaired_by_the_ride_chip():
	await folly(LANDING)
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'A mounted mech is impaired.')
	assert_true(UnitCondition.has_buff(mount, Fixture.RIDE_BUFF), 'Through the visible ride chip (ruling 12).')
	assert_false(UnitCondition.get_buff(mount, Fixture.RIDE_BUFF).base.hide_from_player, 'Which the player can see.')
	assert_true(UnitCondition.has_buff(mount, Fixture.SINGLE_ROLL_BUFF), 'The single-roll rule sits on the mount.')
	assert_true(UnitCondition.has_buff(koremasa, Fixture.CRIT_BUFF), 'The crit rule sits on the rider.')

func test_a_move_that_ends_out_of_reach_spends_the_core_power_and_rides_nothing():
	await folly(SHORT_LANDING)
	assert_eq(koremasa.tile(), SHORT_LANDING, 'fixture: the move happened.')
	assert_false(UnitCondition.is_in_stackup(koremasa), 'Nobody in reach: no ride.')
	assert_false(koremasa.core.has_core_power, 'The core power is spent all the same (ruling 9).')
	assert_false(mount.has_status(Lancer.STATUS.IMPAIRED), 'Nothing was impaired.')

func test_a_cancelled_move_spends_nothing():
	responder.abort_all = true
	await folly(LANDING)
	assert_eq(koremasa.tile(), KOREMASA_TILE, 'fixture: it did not move.')
	assert_true(koremasa.core.has_core_power, 'A cancelled reticle spends nothing.')
	assert_true(Fixture.core(koremasa).is_action_hibernating(Fixture.BEGIN_RIDING_ACTION),
		'And wakes nothing.')

func test_only_a_mount_in_reach_is_ridden():
	var second := Fixture.create_mount(game, Vector2i(4, 5)) # (4,5)..(5,6): 1 from (5,4)
	await folly(Vector2i(5, 4)) # 1 from `second`, 2 from `mount`
	assert_true(Fixture.is_riding(koremasa, second), 'It rides the one in reach.')
	assert_false(UnitCondition.is_in_stackup(mount), 'Not the one two tiles off.')

func test_of_two_mounts_in_reach_the_picked_one_is_ridden():
	var second := Fixture.create_mount(game, Vector2i(7, 5)) # (7,5)..(8,6): 1 from (6,4)
	responder.chosen_unit = second
	await folly(BESIDE) # 1 from both
	assert_true(Fixture.is_riding(koremasa, second), 'It rides the one the player picked.')
	assert_false(UnitCondition.is_in_stackup(mount), 'Not the other.')

func test_the_ride_is_mandatory_once_the_move_ends_in_reach():
	# "If you end this movement adjacent to them you move into their space": no yes/no after the move.
	await folly(LANDING)
	assert_eq(responder.yesno_prompts.size(), 0, 'No prompt: the card says you DO move into their space.')
	assert_true(Fixture.is_riding(koremasa, mount), 'And it rode.')

# ---------------------------------------------------------------- ride now (ruling 8)

func test_already_in_reach_the_koremasa_may_ride_without_moving():
	place(koremasa, BESIDE)
	await folly(SHORT_LANDING, true) # the reticle would carry it away; "ride now" must skip it
	assert_eq(responder.yesno_prompts.size(), 1, 'It was asked whether to ride now.')
	assert_true(Fixture.is_riding(koremasa, mount), 'Yes: it rode without moving.')
	assert_false(koremasa.core.has_core_power, 'The core power is spent.')

func test_declining_ride_now_moves_as_usual():
	place(koremasa, BESIDE)
	await folly(SHORT_LANDING, false)
	assert_eq(koremasa.tile(), SHORT_LANDING, 'No: the move went ahead.')
	assert_false(UnitCondition.is_in_stackup(koremasa), 'And ended out of reach.')

func test_out_of_reach_nothing_asks_to_ride_now():
	await folly(LANDING)
	assert_eq(responder.yesno_prompts.size(), 0, 'Nobody within 1 at the start: no ride-now prompt.')

func test_an_immobilized_koremasa_in_reach_may_still_ride_now():
	# The move is refused (action_system_movement.gd:26), the zero-length ride is not.
	place(koremasa, BESIDE)
	SpecFactory.apply(koremasa, Lancer.STATUS.IMMOBILIZED)
	await Fixture.open_turn(game, koremasa)
	assert_true(UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.FOLLY_ACTION)),
		'The Folly is on offer while Immobilized, because a mount is in reach.')
	await folly(Tile.INVALID, true)
	assert_true(Fixture.is_riding(koremasa, mount), 'And it rides.')

func test_an_immobilized_koremasa_out_of_reach_is_not_offered_the_folly():
	SpecFactory.apply(koremasa, Lancer.STATUS.IMMOBILIZED)
	await Fixture.open_turn(game, koremasa)
	assert_false(UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.FOLLY_ACTION)),
		'No move and no mount: nothing to do.')

# ---------------------------------------------------------------- begin riding

func test_begin_riding_sleeps_until_the_folly_is_used():
	place(koremasa, BESIDE)
	await Fixture.open_turn(game, koremasa)
	assert_true(Fixture.core(koremasa).is_action_hibernating(Fixture.BEGIN_RIDING_ACTION), 'Asleep at the start.')
	assert_false(begin_riding_offered(), 'Not offered before the Folly, even beside a mount.')

func test_the_folly_wakes_begin_riding_even_when_it_rides_nothing():
	await folly(SHORT_LANDING)
	assert_false(Fixture.core(koremasa).is_action_hibernating(Fixture.BEGIN_RIDING_ACTION),
		'"For the rest of the scene" starts with the Folly, ridden or not (ruling 9).')
	await Fixture.cycle_turn(game, koremasa)
	place(koremasa, BESIDE)
	assert_true(begin_riding_offered(), 'Next turn, beside a mount, it is offered.')
	await begin_riding()
	assert_true(Fixture.is_riding(koremasa, mount), 'And it rides.')
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'With the whole ride: the mount is impaired.')

func test_begin_riding_needs_a_mount_within_one():
	wake_begin_riding()
	place(koremasa, TWO_OUT)
	await Fixture.open_turn(game, koremasa)
	assert_false(begin_riding_offered(), 'Two tiles out: not offered.')

func test_begin_riding_is_not_offered_while_already_riding():
	await folly(LANDING)
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: riding.')
	await Fixture.cycle_turn(game, koremasa)
	assert_false(begin_riding_offered(), 'One stackup at a time.')
	assert_false(UnitAction.can_activate_gear(Fixture.specific(koremasa, Fixture.FOLLY_ACTION)),
		'Nor the Folly (the core power is spent anyway, but the stackup gate stands on its own).')

# ---------------------------------------------------------------- what counts as a mount (ruling 10)

func test_a_size_one_hostile_is_larger_than_the_koremasa():
	wake_begin_riding()
	var small := Fixture.create_hostile(game, Vector2i(3, 4))
	await Fixture.open_turn(game, koremasa)
	assert_true(begin_riding_offered(), 'compare_size reads size 1/2 as 0, so a size-1 mech is larger.')
	await begin_riding()
	assert_true(Fixture.is_riding(koremasa, small), 'And it rides.')

func test_a_size_half_hostile_is_not_larger():
	wake_begin_riding()
	var tiny := Fixture.create_hostile(game, Vector2i(3, 4))
	tiny.core.frame.stat.is_size_half = true
	tiny.core.full_repair()
	UnitTile.move_to(tiny, tiny.tile())
	await Fixture.open_turn(game, koremasa)
	assert_false(begin_riding_offered(), 'Same size: not a mount.')

func test_an_ally_is_not_a_mount():
	wake_begin_riding()
	var friend := Fixture.create_mount(game, Vector2i(3, 4), 2, Faction.PLAYER)
	assert_true(UnitRelation.distance_between(koremasa, friend) <= 1, 'fixture: the ally is in reach.')
	await Fixture.open_turn(game, koremasa)
	assert_false(begin_riding_offered(), '"hostile".')

func test_a_drone_is_not_a_mount():
	wake_begin_riding()
	var drone := Fixture.create_hostile_drone(game, Vector2i(3, 4))
	SpecFactory.change_size(drone, 2)
	await Fixture.open_turn(game, koremasa)
	assert_false(begin_riding_offered(), '"mech".')

# ---------------------------------------------------------------- the ride itself (probe b, c)

func test_the_rider_moves_with_its_mount_even_immobilized_and_slowed():
	await folly(LANDING)
	SpecFactory.apply(koremasa, Lancer.STATUS.IMMOBILIZED)
	SpecFactory.apply(koremasa, Lancer.STATUS.SLOWED)
	Fixture.queue([])
	await SpecFactory.move(game, mount, RIDE_TO)
	assert_eq(mount.tile(), RIDE_TO, 'fixture: the mount walked.')
	assert_true(Fixture.is_riding(koremasa, mount), 'The rider came along.')
	await SpecFactory.move(game, mount, SHOVE_TO, MovementType.create_for_involuntary(mount))
	assert_eq(mount.tile(), SHOVE_TO, 'fixture: the mount was shoved.')
	assert_true(Fixture.is_riding(koremasa, mount), 'Still along for the ride.')
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'Still impaired.')

## Ruling 4 (the author's "kept"), measured by spike test b and pinned here at the close: the rider's
## basic Overwatch fires when its mount WALKS (a hostile starting a move inside threat 1), and not
## when the mount is shoved. The hit is on the mount, so it is a crit rolled once: 1 + 2.
func test_the_riders_overwatch_fires_when_its_mount_walks():
	await folly(LANDING)
	var before := mount.core.current.health
	Fixture.queue([11, 1, 6])
	await SpecFactory.move(game, mount, RIDE_TO)
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: still riding.')
	assert_eq(health_lost(mount, before), 1 + 2, 'Overwatch took its shot at the walking mount.')

func test_control_the_riders_overwatch_ignores_a_shove():
	await folly(LANDING)
	var before := mount.core.current.health
	Fixture.queue([11, 1, 6])
	await SpecFactory.move(game, mount, SHOVE_TO, MovementType.create_for_involuntary(mount))
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: still riding.')
	assert_eq(health_lost(mount, before), 0, 'An involuntary move provokes nothing.')

## Spike tests a and c, the two engine facts SP2 had not re-pinned: rider and mount ENGAGE each other
## (two hostiles at distance 0; design's Contested seams line), and a rider cannot be knocked off
## (unit_condition.gd:552).
func test_rider_and_mount_are_engaged_with_each_other():
	assert_false(koremasa.has_status(Lancer.STATUS.ENGAGED), 'fixture: four apart, not engaged.')
	await folly(LANDING)
	assert_true(koremasa.has_status(Lancer.STATUS.ENGAGED), 'The rider is Engaged with its mount.')
	assert_true(mount.has_status(Lancer.STATUS.ENGAGED), 'The mount is Engaged with its rider.')

func test_the_rider_cannot_be_knocked_off():
	var shove := MovementType.create_for_involuntary(koremasa)
	var by_mount := SpecificAction.create(mount, null, null)
	assert_false(UnitCondition.is_immune_to_knockback_from(koremasa, by_mount, shove, false), 'fixture: on foot it can be knocked back.')
	await folly(LANDING)
	assert_true(UnitCondition.is_immune_to_knockback_from(koremasa, by_mount, shove, false), 'Riding, it is immune to knockback.')
	await SpecFactory.move(game, koremasa, SHOVE_TO, shove)
	assert_true(Fixture.is_riding(koremasa, mount), 'A shove aimed at the rider leaves it riding.')

func test_the_rider_cannot_move_by_itself():
	await folly(LANDING)
	await Fixture.cycle_turn(game, koremasa)
	assert_false(UnitAction.can_activate_gear(SpecificAction.from_id(koremasa, &'ms_boost')), 'No Boost while riding.')

# ---------------------------------------------------------------- every hit a crit, rolled once (probe g-j)

func test_a_plain_hit_on_the_mount_is_a_crit_dealing_the_single_roll():
	await folly(LANDING)
	var before := mount.core.current.health
	await slash(mount, 11, 1, 6) # 11 against evasion 10: a plain hit
	assert_eq(health_lost(mount, before), 1 + 2, 'The single roll (1+2), not the crit\'s best die (6+2).')

func test_the_crit_is_real():
	await folly(LANDING)
	await slash(mount, 11, 1, 6)
	# Exploit Weakness (SP1) fires only on a crit, and the ride's own Impaired is one condition: this
	# is the card combination ruling 15 records, and the cleanest outside witness that the crit landed.
	assert_eq(Fixture.heat(mount), 1, 'The 11 became a crit: Exploit Weakness dealt 1 heat for the Impaired.')

func test_a_natural_crit_on_the_mount_is_rolled_once_too():
	await folly(LANDING)
	var before := mount.core.current.health
	await slash(mount, 20, 1, 6)
	assert_eq(health_lost(mount, before), 1 + 2, '"Resulting damage is not rolled twice" covers every attack on the mount.')

## A MAXIMIZED crit deals get_maximized(), not get_crits() (attack_util.gd:118-121) - Brutal's
## Predator on a natural 20 (event_unit_attack.gd:72-74), the Naga's BATS. There is no second roll
## to undo, so the reduction must stand aside (close review): 1d6+2 maximized is 8.
func test_a_maximized_crit_on_the_mount_deals_the_maximum():
	await folly(LANDING)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), koremasa, &'buff_predator', Fixture.core(koremasa))
	var before := mount.core.current.health
	await slash(mount, 20, 1, 6)
	assert_eq(health_lost(mount, before), 6 + 2, 'Predator maximizes the natural 20: the blade\'s maximum, nothing taken off.')

## Exposed doubles the incoming number before armor and every reduction (damage_modifications.gd:
## 55-57, then :62-68), so the reduction doubles with it (buff_lassissian_folly_single_roll.gd). A
## doubled crit of 8 is 16; less armor 2 and the doubled difference (8 - 3) * 2 is 4 - which is the
## single roll's (1 + 2) * 2 - 2. Unexercised until the close review (every other mount has armor 0
## and is not Exposed): drop the doubling and the hit deals 9. An Exposed target also wakes the
## Koremasa's own Gut Reactor (no AttackRoll, so no reduction): 1d3+1 on the fixture's 3s is 4,
## doubled 8, less armor 6.
func test_an_exposed_armored_mount_takes_the_single_roll_doubled_less_armor():
	mount.core.frame.stat.armor = 2
	mount.core.full_repair()
	await folly(LANDING)
	SpecFactory.apply(mount, Lancer.STATUS.EXPOSED)
	assert_eq(mount.core.get_armor(), 2, 'fixture: armor 2.')
	var before := mount.core.current.health
	await slash(mount, 11, 1, 6)
	assert_eq(Fixture.gut_reactor_uses(koremasa), 1, 'fixture: Gut Reactor fired on the Exposed mount.')
	assert_eq(health_lost(mount, before), ((1 + 2) * 2 - 2) + ((3 + 1) * 2 - 2), 'The single roll doubled less armor, plus the Gut Reactor bonus.')

func test_control_the_same_hit_unmounted_is_a_plain_hit():
	place(koremasa, BESIDE)
	var before := mount.core.current.health
	await slash(mount, 11, 1, 6)
	assert_eq(health_lost(mount, before), 1 + 2, 'Plain hit damage.')
	assert_eq(Fixture.heat(mount), 0, 'No crit, so no Exploit Weakness.')

func test_control_a_natural_crit_unmounted_rolls_twice():
	place(koremasa, BESIDE)
	var before := mount.core.current.health
	await slash(mount, 20, 1, 6)
	assert_eq(health_lost(mount, before), 6 + 2, 'Vanilla crit: the better of the two dice.')

func test_the_crit_rule_is_only_against_the_mount():
	await folly(LANDING)
	var other := Fixture.create_hostile(game, Vector2i(6, 2)) # 1 from the rider's (7,3)
	var before := other.core.current.health
	await slash(other, 11, 1, 6)
	assert_eq(health_lost(other, before), 1 + 2, 'A hit on anyone else is an ordinary hit.')
	assert_eq(Fixture.heat(other), 0, 'Not a crit.')
