# PHASE CLOUD (Koremasa rank I, design 3.2, rulings 26-28):
#
#   "Vanish (Reaction, 1/round). Trigger: You take damage from a hostile character within sensors.
#    Effect: Expend a charge, a Blast one area centered on you is engulfed in smoke. All objects and
#    characters within benefit from soft cover until the end of your next turn, at which point the
#    smoke vanishes. You may teleport to a free space within range 5."
#
# THE JORMUNGANDR'S CHASSIS (ruling 26): a damage POST reaction, heat excluded, a number above 0, the
# dealer resolved to its OWNER, who must be a hostile actor within the Koremasa's sensors. A REAL
# reaction - the point and the charge are the price - with a yes/no first (a reaction is optional;
# the Jormungandr's has none only because its card says "automatically").
#
# SMOKE FIRST, THEN THE TELEPORT (ruling 27). The smoke is a MARKER deployable laid through the mod's
# Terrain.lay, whose Kit projects soft cover over the Koremasa's FOOTPRINT plus 1 - a 3x3 for a
# Koremasa on foot, the mount's footprint plus 1 for a rider (occupying_size, unit_battle_state.gd:211)
# - and which dies at the end of the Koremasa's next turn (vanilla's mt_expiration). The teleport is
# the frozen Teleport helper's PREVENTABLE route: the reticle's cancel is the "may".
#
# WHILE RIDING (ruling 28, and the SP3 probe at fca423a, ported to the end of this file): the reticle is planned from
# the rider's own unstacked shape BEFORE anything changes, so a DECLINED teleport leaves it mounted;
# a taken one dismounts first and then teleports from the Koremasa's own tile.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_phase_cloud.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Ride := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_koremasa/cp_overdrive_exploitation_sequences/koremasa_ride.gd')

const KOREMASA_TILE := Vector2i(4, 5)
const NEAR := Vector2i(8, 5)        ## 4 away: inside sensors 5
const FAR := Vector2i(12, 5)        ## 8 away: outside
const ALLY_TILE := Vector2i(4, 8)
const LANDING := Vector2i(4, 9)     ## 4 from the Koremasa, outside the smoke
const UNREACHABLE := Vector2i(15, 11) ## no pathfinder offers it: the reticle's cancel
const INSIDE := Vector2i(5, 6)      ## a corner of the 3x3 around KOREMASA_TILE
const OUTSIDE := Vector2i(6, 5)     ## 2 away: outside it

## The riding layout (spec/test_koremasa_dismount.gd's).
const RIDER_START := Vector2i(3, 3)
const MOUNT_TILE := Vector2i(7, 3) ## size 2: (7,3) (8,3) (7,4) (8,4)
const RIDE_LANDING := Vector2i(6, 3)
const RIDE_AWAY := Vector2i(7, 8)  ## 5 from the anchor (7,3), free
const BESIDE := Vector2i(9, 4)     ## adjacent to the mount's footprint, and within 5

var game:Gamemaster
var responder
var koremasa:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func on_foot() -> void:
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.PHASE_CLOUD_ID)

func riding() -> Unit:
	koremasa = Fixture.create_koremasa(game, RIDER_START)
	Fixture.equip(koremasa, Fixture.PHASE_CLOUD_ID)
	var mount := Fixture.create_mount(game, MOUNT_TILE)
	responder.chosen_move_tile = RIDE_LANDING
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)
	responder.chosen_move_tile = Tile.INVALID
	await SpecFactory.end_turn(game, koremasa)
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: riding.')
	return mount

## Hit the Koremasa for 2 from `dealer`, with the reticle told where to land.
func hit(dealer:Unit, landing:Vector2i = UNREACHABLE, type:Lancer.DAMAGE_TYPE = Lancer.DAMAGE_TYPE.KINETIC) -> void:
	responder.chosen_move_tile = landing
	await Fixture.damage(game, koremasa, 2, dealer, type)
	responder.chosen_move_tile = Tile.INVALID

func smokes() -> Array[Unit]:
	return Fixture.units_of_frame(game, Fixture.SMOKE_FRAME)

func vanished() -> bool:
	return not smokes().is_empty()

func soft(tile:Vector2i) -> bool:
	return game.map.get_surface_terrain_at(tile).is_soft_cover()

func assert_nothing_spent() -> void:
	assert_false(vanished(), 'No smoke.')
	assert_eq(Fixture.charges(koremasa, Fixture.PHASE_CLOUD_ID), 1, 'The charge is untouched.')
	assert_eq(koremasa.core.current.reactions, koremasa.core.get_reactions_max(), 'The reaction point is untouched.')

# ---------------------------------------------------------------- wiring

func test_the_kit_is_limited_1_unique_and_carries_a_real_reaction():
	var kit:Kit = ContentLibrary.get_kit(Fixture.PHASE_CLOUD_ID)
	assert_true(Kit.is_valid(kit), 'ms_phase_cloud is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.charges_max, 1, 'LIMITED 1.')
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.system_tags & 1, 1, 'UNIQUE.')
	var vanish:Action = kit.get_action(Fixture.VANISH_ACTION)
	assert_true(vanish is ActionReaction, 'Vanish is a reaction.')
	if not vanish is ActionReaction: return
	assert_true(vanish.consumes_rxn, 'A REAL reaction: it spends the point.')
	assert_eq(vanish.triggers_on, [&'damage'] as Array[StringName], 'On damage...')
	assert_eq(vanish.trigger_timing, ReactionBus.TIMING.POST, '...POST, so the number is final.')

# ---------------------------------------------------------------- the trigger (ruling 26)

func test_damage_from_a_hostile_within_sensors_vanishes():
	on_foot()
	var hostile := Fixture.create_hostile(game, NEAR)
	await hit(hostile)
	assert_true(vanished(), 'Smoke.')
	assert_eq(Fixture.charges(koremasa, Fixture.PHASE_CLOUD_ID), 0, 'The charge is spent.')
	assert_eq(koremasa.core.current.reactions, koremasa.core.get_reactions_max() - 1, 'So is the reaction point.')

func test_damage_from_beyond_sensors_does_not():
	on_foot()
	await hit(Fixture.create_hostile(game, FAR))
	assert_nothing_spent()

func test_damage_from_an_ally_does_not():
	on_foot()
	await hit(Fixture.create_ally(game, ALLY_TILE))
	assert_nothing_spent()

func test_heat_does_not():
	on_foot()
	await hit(Fixture.create_hostile(game, NEAR), UNREACHABLE, Lancer.DAMAGE_TYPE.HEAT)
	assert_nothing_spent()

func test_damage_nobody_dealt_does_not():
	on_foot()
	await hit(null)
	assert_nothing_spent()

func test_a_hostile_drones_damage_counts_as_its_owners():
	# Ruling 26: the dealer is resolved to its OWNER, the Jormungandr's damager().
	on_foot()
	var owner_unit := Fixture.create_hostile(game, NEAR)
	var drone := Fixture.create_hostile_drone(game, Vector2i(9, 7))
	drone.state.set_owner(owner_unit)
	await hit(drone)
	assert_true(vanished(), 'A drone\'s hit is its owner\'s, and the owner is within sensors.')

## The discriminating half (close review): the drone above and its owner are BOTH within 5, so a
## Vanish measuring to the drone would pass it too. Here the drone is close and the owner is not.
func test_a_close_drone_whose_owner_is_outside_sensors_does_not():
	on_foot()
	var owner_unit := Fixture.create_hostile(game, FAR)
	var drone := Fixture.create_hostile_drone(game, Vector2i(6, 6))
	drone.state.set_owner(owner_unit)
	await hit(drone)
	assert_nothing_spent()

func test_no_charge_no_vanish():
	on_foot()
	koremasa.get_gear(Fixture.PHASE_CLOUD_ID).charges_current = 0
	await hit(Fixture.create_hostile(game, NEAR))
	assert_false(vanished(), 'LIMITED 1: with the charge gone there is nothing to expend.')

func test_declining_the_reaction_spends_nothing():
	on_foot()
	responder.yesno_queue.assign([false])
	await hit(Fixture.create_hostile(game, NEAR))
	assert_nothing_spent()

# ---------------------------------------------------------------- the smoke (ruling 27)

func test_the_smoke_is_a_blast_1_of_soft_cover_around_the_koremasa():
	on_foot()
	assert_false(soft(INSIDE), 'fixture: no cover there before.')
	await hit(Fixture.create_hostile(game, NEAR))
	assert_true(soft(KOREMASA_TILE), 'Soft cover under the Koremasa.')
	assert_true(soft(INSIDE), 'And on the Blast 1 corner.')
	assert_false(soft(OUTSIDE), 'Not two away.')

func test_a_character_in_the_smoke_has_soft_cover_and_one_who_leaves_does_not():
	on_foot()
	var hostile := Fixture.create_hostile(game, NEAR)
	await hit(hostile) # declined teleport: it stays in the cloud
	assert_eq(CoverCalculator.determine_cover(koremasa, hostile).total, Lancer.COVER.SOFT,
		'Inside the smoke: soft cover.')
	await SpecFactory.move(game, koremasa, LANDING)
	assert_eq(CoverCalculator.determine_cover(koremasa, hostile).total, Lancer.COVER.NONE,
		'Out of it: none (cover is per tile, cover_calculator.gd:79-89).')

func test_the_smoke_outlasts_this_turn_and_vanishes_at_the_end_of_the_koremasas_next():
	on_foot()
	var hostile := Fixture.create_hostile(game, NEAR)
	await SpecFactory.start_turn(game, hostile)
	await hit(hostile)
	await SpecFactory.end_turn(game, hostile)
	assert_true(vanished(), 'Still there once the hostile\'s turn is over.')
	await SpecFactory.start_turn(game, koremasa)
	assert_true(vanished(), 'Still there as the Koremasa\'s next turn begins.')
	await SpecFactory.end_turn(game, koremasa)
	assert_false(vanished(), 'Gone at the end of it.')
	assert_false(soft(KOREMASA_TILE), 'And its cover with it.')

# ---------------------------------------------------------------- the teleport (ruling 27)

func test_the_koremasa_may_teleport_within_5_and_the_smoke_stays_behind():
	on_foot()
	await hit(Fixture.create_hostile(game, NEAR), LANDING)
	assert_eq(koremasa.tile(), LANDING, 'It landed where it chose.')
	assert_true(soft(KOREMASA_TILE), 'The smoke stays where it was laid.')
	assert_false(soft(LANDING), 'And is not where it went.')

func test_the_reticle_offers_the_free_spaces_within_5():
	on_foot()
	var hostile := Fixture.create_hostile(game, NEAR)
	var expected := Teleport.candidate_tiles(koremasa, 5, false) # with the hostile on the board
	var watcher = add_child_autoqfree(PromptWatcher.new())
	await hit(hostile, LANDING)
	var seen:Array = watcher.kinds(PromptWatcher.KIND.move_tile)
	assert_eq(seen.size(), 1, 'ONE reticle.')
	var offered:Array[Vector2i] = []
	if not seen.is_empty() and seen[0].pathfinder != null: offered.assign(seen[0].pathfinder.movable_tiles)
	offered.sort()
	expected.sort()
	assert_false(offered.is_empty(), 'fixture: a reticle was raised.')
	assert_eq(offered, expected, 'Exactly the free spaces within 5, no line of sight required (the mod-wide teleport reading).')

func test_a_declined_teleport_leaves_the_smoke_and_the_koremasa():
	on_foot()
	await hit(Fixture.create_hostile(game, NEAR), UNREACHABLE)
	assert_eq(koremasa.tile(), KOREMASA_TILE, 'It stayed.')
	assert_true(vanished(), 'The smoke was laid anyway.')
	assert_eq(Fixture.charges(koremasa, Fixture.PHASE_CLOUD_ID), 0, 'The charge is spent: the teleport is only a "may".')

func test_an_immobilized_koremasa_smokes_but_does_not_teleport():
	# The PREVENTABLE route (ruling 27): Immobilized gates a voluntary teleport (pathfinder.gd:333).
	on_foot()
	UnitCondition.apply_status(SpecFactory.dummy_event(), koremasa, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	await hit(Fixture.create_hostile(game, NEAR), LANDING)
	assert_true(vanished(), 'Smoke.')
	assert_eq(koremasa.tile(), KOREMASA_TILE, 'No teleport.')

# ---------------------------------------------------------------- riding (ruling 28)

func test_a_rider_smokes_the_mounts_footprint_dismounts_and_teleports():
	var mount := await riding()
	await hit(mount, RIDE_AWAY)
	assert_true(soft(Vector2i(9, 5)), 'The smoke covers the mount\'s footprint plus 1 (the far corner).')
	assert_true(soft(Vector2i(6, 2)), 'And the near corner.')
	assert_false(soft(Vector2i(10, 3)), 'But no further.')
	assert_eq(koremasa.tile(), RIDE_AWAY, 'The Koremasa teleported away.')
	assert_false(UnitCondition.is_in_stackup(koremasa), 'Out of the stackup.')
	assert_false(UnitCondition.is_in_stackup(mount), 'So is the mount.')
	assert_eq(koremasa.occupied_tiles(), [RIDE_AWAY] as Array[Vector2i], 'Its own one-tile footprint.')
	assert_eq(mount.tile(), MOUNT_TILE, 'The mount stayed put.')
	assert_false(mount.has_status(Lancer.STATUS.IMPAIRED), 'The ride\'s Impaired is gone.')
	assert_true(Fixture.ride_buffs_on(mount, koremasa).is_empty(), 'Nothing of the ride on the mount.')
	assert_true(Fixture.ride_buffs_on(koremasa, koremasa).is_empty(), 'Nothing of the ride on the rider.')

func test_a_rider_that_declines_the_teleport_stays_mounted():
	var mount := await riding()
	await hit(mount, UNREACHABLE)
	assert_true(vanished(), 'Smoke.')
	assert_true(Fixture.is_riding(koremasa, mount), 'Still riding (ruling 28).')
	assert_true(mount.has_status(Lancer.STATUS.IMPAIRED), 'The mount is still Impaired by the ride.')

## A listener that vetoes one unit's teleports at ENTIRE_MOVEMENT PRE - the Uncertainty Field's seam
## (Teleport.veto, event_unit_move.gd:71-72), installed on the board as a runtime trait Kit.
class TeleportVeto extends ActionReaction:
	var target:Unit
	var vetoed:int = 0

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == target and Teleport.is_teleport(triggering_event.context)

	func activate(context:Context, _activation:EventCore) -> void:
		vetoed += 1
		Teleport.veto(context.event)

func test_a_rider_whose_teleport_is_vetoed_lands_beside_the_mount_not_inside_it():
	var mount := await riding()
	var veto := TeleportVeto.new()
	veto.target = koremasa
	var kit := Kit.new()
	kit.compcon_id = &'spec_teleport_veto'
	kit.is_trait = true
	kit.actions.append(veto)
	mount.core.loadout.equipped_kits.append(kit)
	mount.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	# BESIDE is both a teleport destination and one of the tiles the relocation offers: vanilla's
	# queue_events_to_make_sure_units_are_in_valid_spots lets a PLAYER pick its landing (a move_tile
	# prompt, event_unit_pick_move), and the responder answers both prompts with the same tile.
	await hit(mount, BESIDE)
	assert_eq(veto.vetoed, 1, 'fixture: the teleport was vetoed.')
	assert_false(UnitCondition.is_in_stackup(koremasa), 'The ride ended when the tile was taken.')
	assert_eq(koremasa.occupied_tiles().size(), 1, 'Its own footprint.')
	var overlap := koremasa.occupied_tiles().filter(func(tile:Vector2i) -> bool: return mount.occupied_tiles().has(tile))
	assert_true(overlap.is_empty(), 'Not left standing inside the mount: relocated like any dismount.')
	assert_eq(UnitRelation.distance_between(koremasa, mount), 1, 'Beside it.')

# ---------------------------------------------------------------- the planned shape (ex-probe, the close)

## Ported from spec/test_koremasa_vanish_probe.gd at the frame close, and run through Vanish's OWN
## plan_teleport rather than the probe's copy - which had measured with line of sight ON while
## production passes it off (action_vanish.gd:126). The reticle is planned from the rider's unstacked
## shape BEFORE the dismount, so it must offer exactly what a real dismount would.
func vanish_action() -> Action:
	return ContentLibrary.get_kit(Fixture.PHASE_CLOUD_ID).get_action(Fixture.VANISH_ACTION)

func test_a_riders_planned_teleport_offers_what_a_real_dismount_would():
	var mount := await riding()
	var planned:Pathfinder = await vanish_action().plan_teleport(koremasa, true)
	assert_true(Fixture.is_riding(koremasa, mount), 'Still riding after the plan: nothing changed.')
	assert_eq(koremasa.occupied_tiles().size(), 4, 'The rider still spans the mount.')
	assert_not_null(planned, 'A pathfinder was planned.')
	if planned == null: return
	var virtual:Array[Vector2i] = planned.movable_tiles.duplicate()
	Ride.dismount(SpecFactory.dummy_event(), koremasa, Fixture.core(koremasa), false)
	var real:Pathfinder = await vanish_action().plan_teleport(koremasa, false)
	assert_not_null(real, 'fixture: a real dismount plans too.')
	if real == null: return
	var real_tiles:Array[Vector2i] = real.movable_tiles.duplicate()
	virtual.sort()
	real_tiles.sort()
	assert_false(virtual.is_empty(), 'fixture: something is offered.')
	assert_eq(virtual, real_tiles, 'The unstacked plan offers exactly the real dismount\'s tiles.')

## The control: planned as a rider (no unstacking), nothing is reachable - a rider has no movement
## of its own (pathfinder.gd:343), so the unstacked shape is what makes the escape possible.
func test_control_planned_without_unstacking_a_rider_reaches_nothing():
	await riding()
	var planned:Pathfinder = await vanish_action().plan_teleport(koremasa, false)
	var reachable := planned != null and planned.is_reachable(RIDE_AWAY)
	assert_false(reachable, 'Still stacked, the escape tile is unreachable.')
