## GREEN TIDE, the Naga's rank-II system (SP3 Task 2, design rulings 15-17).
##
## "Tech, SP 2, HEAT SELF 1, UNIQUE. Charging Swarm (Quick): A Blast 1 area within sensors becomes
##  coated in a greenwash swarm. Until the start of your next turn, allied characters that start
##  their turn at least partially within the area or move into it for the first time in a round, may
##  immediately move up to their speed as a reaction. This movement is not affected by Slowed or
##  Immobilized." (specs/sixth-voice/10-naga.md, Rank II)
##
## THE SHAPE: the archetype deploys ONE marker, dep_green_tide, at the chosen centre, in the NAGA'S
## faction (ActionSystemDeploy.place_deployable, action_system_deploy.gd:110-127) - ruling 15, and the
## reason it is not Terrain.lay: a factionless marker has no allies. The marker's own trait carries
## the surge (an ActionReactionOnComingWithin at range 1 - "at least partially within" a Blast 1 is
## distance <= 1 from the centre) and the fx; a second trait kills it at the Naga's next turn start.
##
## PROMPTS: the queue responder records every yes/no; the surge's is titled with the action's own
## name. Move pickers are read off the PromptWatcher and filtered to the marker's trait Kit.
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const KIT_ID := &'ms_green_tide'
const ACTION_ID := &'action_charging_swarm'
const MARKER_FRAME := &'dep_green_tide'
const ZONE_KIT := &'mt_green_tide'
const SURGE_ID := &'action_green_tide_surge'
const EXPIRY_KIT := &'mt_green_tide_expiry'

const NAGA_TILE := Vector2i(4, 4)        # size 2: (4,4)-(5,5)
const CENTRE := Vector2i(10, 4)          # 5 from the Naga's east edge - inside Sensors 8
const SECOND_CENTRE := Vector2i(10, 8)
const INSIDE := Vector2i(11, 5)          # a corner of the Blast 1
const OUTSIDE := Vector2i(13, 4)         # 3 from the centre
const EDGE := Vector2i(11, 4)            # 1 from the centre: the first tile inside, walking west
const DEEPER := Vector2i(10, 5)          # 1 from the centre, a step past EDGE - still inside
const BEYOND_SENSORS := Vector2i(16, 4)  # 11 from the Naga's east edge

var game:Gamemaster
var responder
var watcher:PromptWatcher
var naga:Unit
var tide:GearCore

var log_lines:PackedStringArray = []
var battle_log:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

func _record_log(line:String) -> void: log_lines.append(line)


func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	tide = NagaFixture.equip(naga, KIT_ID)

func after_each() -> void:
	if battle_log.on_log_text.is_connected(_record_log): battle_log.on_log_text.disconnect(_record_log)
	Dice.CHEAT_ROLL_QUEUE.clear()
	if is_instance_valid(responder): responder.chosen_move_tile = Tile.INVALID


# ---------------------------------------------------------------- helpers

## Press Charging Swarm centred on `centre`, on the Naga's open turn. AS_FREEBIE for a second press
## in the same turn (the per-turn soft limit refuses a second QUICK use of one action otherwise).
func press(centre:Vector2i = CENTRE, flags:Array = []) -> void:
	await NagaFixture.open_turn(game, naga)
	await SpecFactory.use(game, naga, KIT_ID, ACTION_ID, centre, flags)
	UnitTile.update_tracking_and_statuses(game.map)

func swarms() -> Array[Unit]:
	return UnitAction.get_deployables_from(naga, tide, MARKER_FRAME)

## Hand the Naga's turn over: end it, so no later turn start on the map is ITS OWN (which would kill
## the swarm at its PRE - see test_the_swarm_dies_at_the_start_of_the_nagas_next_turn).
func end_nagas_turn() -> void:
	if naga.state.is_taking_turn: await SpecFactory.end_turn(game, naga)

## The yes/no prompts the SURGE raised.
func surge_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	var surge_name:String = X.tr('gear.%s.%s.name' % [ZONE_KIT, SURGE_ID])
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(surge_name) or String(seen.get('desc', '')).contains(surge_name):
			found.append(seen)
	return found

## Movement pickers the surge opened (its pick_move names the marker's trait Kit as `gear`).
func surge_moves() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for info:Dictionary in watcher.kinds(PromptWatcher.KIND.move_tile):
		var using = info.get('using')
		if using is SpecificAction and GearCore.is_valid(using.gear) and using.gear.kit.compcon_id == ZONE_KIT:
			found.append(info)
	return found

## The furthest tile a picker offered, measured from where the mover stood.
func furthest_offered(info:Dictionary, from:Vector2i) -> int:
	var pathfinder:Pathfinder = info.get('pathfinder')
	if pathfinder == null: return -1
	var furthest := -1
	for tile:Vector2i in pathfinder.reachable_tiles: furthest = maxi(furthest, Tile.distance(from, tile))
	return furthest

func start_turn_of(unit:Unit, answers:Array[bool] = [true]) -> void:
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array(answers)
	responder.yesno_prompts.clear()
	await SpecFactory.start_turn(game, unit)

## Walk `unit` to `tile` (one event_unit_move; a STEP POST fires on every tile of the path).
func walk(unit:Unit, tile:Vector2i, answers:Array[bool] = [true], movement:MovementType = null) -> void:
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array(answers)
	responder.yesno_prompts.clear()
	await SpecFactory.move(game, unit, tile, movement)
	UnitTile.update_tracking_and_statuses(game.map)


# ---------------------------------------------------------------- wiring

func test_green_tide_is_a_unique_two_sp_system_with_one_quick_deploy() -> void:
	var kit := ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'ContentLibrary indexes Green Tide under its ms_ id.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_true(kit.is_unique(), 'UNIQUE.')
	assert_eq(kit.actions.size(), 1, 'One action: Charging Swarm.')
	var swarm := kit.actions[0] as ActionSystemDeploy
	assert_not_null(swarm, 'An ActionSystemDeploy - the Maar\'s archetype.')
	if swarm == null: return
	assert_eq(swarm.get_id(), ACTION_ID)
	assert_eq(swarm.action_type, Lancer.ACTION.QUICK, 'Quick.')
	assert_true(swarm.deploy_to_sensors, '"within sensors".')
	assert_eq(swarm.self_heat_dice, '1', 'HEAT SELF 1.')
	assert_false(swarm.is_tech, 'A Quick action, not a Quick Tech one (the LCP says Quick).')
	var pattern := swarm.get_range_pattern_for_targets(SpecificAction.create(naga, tide, swarm))
	assert_not_null(pattern, 'It targets an area.')
	if pattern != null:
		assert_eq(pattern.pattern, Lancer.AOE_TYPE.BLAST, 'A Blast...')
		assert_eq(pattern.value, 1, '...1.')
	assert_eq(swarm.deployable_frame.compcon_id, MARKER_FRAME)
	assert_true(swarm.deployable_frame.is_marker(), 'The swarm is a MARKER - no attacks, no cover, no sight.')
	assert_true(swarm.deployable_frame.is_deactivated_on_owner_death, 'The swarm dies with the Naga.')

## The haze is the mod's green copy of the nanite scene (author playtest 2026-09-23), and its id - the
## scene BASENAME - must resolve in ContentLibrary, or the swarm silently draws nothing.
func test_the_swarm_draws_the_green_haze() -> void:
	var zone_kit := load('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_green_tide/deployable/mt_green_tide.tres') as Kit
	var picture := zone_kit.passives[0] as PassiveDynamicZone
	assert_not_null(picture, 'The zone Kit carries its DynamicZone picture.')
	if picture == null: return
	assert_eq(picture.get_fxe_id(), &'fxe_green_tide', 'The tinted copy, not vanilla fxe_nanites.')
	assert_ne(ContentLibrary.get_fxendless_path(&'fxe_green_tide'), '', 'ContentLibrary maps the id to the scene.')

func test_the_licence_grants_green_tide_at_rank_2() -> void:
	var licence := load('res://unpacked/Reag-TheSixthVoice/res/content/licenses/horus/li_naga.tres') as UnlockTree
	var ids:Array[StringName] = []
	for kit:Kit in licence.rank_2.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'li_naga rank 2 grants Green Tide.')

func test_the_rows_resolve() -> void:
	assert_eq(tr('gear.ms_green_tide.name'), 'Green Tide')
	for key:String in [
		'gear.ms_green_tide.flavor',
		'gear.ms_green_tide.action_charging_swarm.name',
		'gear.ms_green_tide.action_charging_swarm.effect',
		'gear.mt_green_tide.action_green_tide_surge.name',
	]:
		assert_ne(tr(key), key, '%s resolves.' % key)

func test_a_tile_beyond_sensors_is_not_targetable() -> void:
	await NagaFixture.open_turn(game, naga)
	var targetable := UnitTargeting.get_tiles_targetable(SpecificAction.create(naga, tide, tide.kit.get_action(ACTION_ID)))
	assert_has(targetable, CENTRE, 'LIVENESS: a centre within Sensors is.')
	assert_does_not_have(targetable, BEYOND_SENSORS, 'One beyond Sensors is not.')


# ---------------------------------------------------------------- the press

func test_the_swarm_lands_in_the_nagas_faction_owned_by_the_naga_and_costs_1_heat() -> void:
	var heat := naga.core.current.heat
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'One swarm.')
	if laid.size() != 1: return
	var swarm:Unit = laid[0]
	assert_eq(swarm.tile(), CENTRE, 'At the chosen centre.')
	assert_eq(swarm.get_faction(), naga.get_faction(), 'In the Naga\'s faction - it has to know who its allies are.')
	assert_eq(swarm.get_owner_unit(), naga, 'Owned by the Naga.')
	assert_eq(naga.core.current.heat, heat + 1, 'HEAT SELF 1.')

func test_a_second_press_lays_a_second_swarm() -> void:
	await press()
	await press(SECOND_CENTRE, [Action.FLAG.AS_FREEBIE])
	assert_eq(swarms().size(), 2, 'The card lays a new area each time and removes nothing.')


# ---------------------------------------------------------------- start of turn

func test_an_ally_starting_its_turn_inside_is_offered_a_move_up_to_its_speed_for_its_reaction() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	var target_tile := INSIDE + Vector2i(3, 0)
	responder.chosen_move_tile = target_tile
	await start_turn_of(ally, [true])
	assert_eq(surge_prompts().size(), 1, 'Offered once, at the start of its turn.')
	assert_eq(surge_moves().size(), 1, 'A yes opens a move picker.')
	if surge_moves().size() != 1: return
	assert_eq(furthest_offered(surge_moves()[0], INSIDE), ally.core.get_speed_max(), '"up to their speed".')
	assert_eq(ally.tile(), target_tile, 'And the ally moves.')
	assert_eq(ally.core.current.reactions, ally.core.get_reactions_max() - 1, '"as a reaction" - it spends the ally\'s reaction.')

## SLICE 4 #7: the reaction is spent through vanilla's UnitAction.spend_reaction (the decrement plus
## its popcorn), and the use is logged under the ALLY, the way any reaction a unit takes is logged.
func test_a_surge_is_logged_once_under_the_ally() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	var swarm_name:String = laid[0].core.get_pilot_or_mech_name()
	assert_ne(swarm_name, ally.core.get_pilot_or_mech_name(), 'fixture: the swarm and the ally are told apart by name.')
	await end_nagas_turn()
	log_lines = []
	battle_log.on_log_text.connect(_record_log)
	responder.chosen_move_tile = INSIDE + Vector2i(3, 0)
	await start_turn_of(ally, [true])
	battle_log.on_log_text.disconnect(_record_log)
	assert_eq(surge_moves().size(), 1, 'LIVENESS: the surge ran.')
	var surge_name:String = X.tr('gear.%s.%s.name' % [ZONE_KIT, SURGE_ID])
	var used:Array[String] = []
	for line:String in log_lines:
		if line.contains(surge_name): used.append(line)
	assert_eq(used.size(), 1, 'One log line names the surge: %s' % [log_lines])
	if used.size() == 1:
		assert_false(used[0].contains(swarm_name), 'It is the ally\'s line, not the swarm\'s: %s' % used[0])

## SLICE 4 #1: the pick_move carries NO `unit`. event_unit_pick_move.gd:78 aborts on
## is_immune_to_knockback_from(mover, from_specific), and buff_heavy_frame_knockback compares the
## specific's unit to the mover - the size-0.5 MARKER is smaller than everyone, so a Heavy Frame ally
## said yes, lost its reaction and did not move. The fixture proves the buff WOULD fire against the
## marker; the ally chooses this move, as with vanilla's Perimeter Command Plate.
func test_a_knockback_immune_ally_still_moves() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	SpecFactory.apply_buff(ally, &'buff_heavy_frame_knockback')
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	var zone:GearCore = laid[0].get_gear(ZONE_KIT)
	var from_marker := SpecificAction.create(laid[0], zone, zone.kit.get_action(SURGE_ID))
	assert_true(UnitCondition.is_immune_to_knockback_from(ally, from_marker, MovementType.create(ally, true)),
		'fixture: the Heavy Frame buff makes the ally immune to a move forced by the marker.')
	await end_nagas_turn()
	var target_tile := INSIDE + Vector2i(3, 0)
	responder.chosen_move_tile = target_tile
	await start_turn_of(ally, [true])
	assert_eq(surge_prompts().size(), 1, 'LIVENESS: offered.')
	assert_eq(surge_moves().size(), 1, 'The picker opens...')
	assert_eq(ally.tile(), target_tile, '...and the ally moves.')
	assert_eq(ally.core.current.reactions, ally.core.get_reactions_max() - 1, 'For its reaction.')

## The same for an UNCONDITIONAL knockback immunity (Fortress Protocol's buff, no size compare): a
## voluntary move is not knockback, so the surge asks no immunity at all - omitting the pick_move's
## `unit` would not have cleared this one.
func test_an_unconditionally_knockback_immune_ally_still_moves() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	SpecFactory.apply_buff(ally, &'buff_fortress_knockback')
	assert_true(UnitCondition.has_buff_to(ally, Buff.TO.KNOCKBACK_IMMUNITY), 'fixture: immune to all knockback.')
	await press()
	await end_nagas_turn()
	var target_tile := INSIDE + Vector2i(3, 0)
	responder.chosen_move_tile = target_tile
	await start_turn_of(ally, [true])
	assert_eq(surge_prompts().size(), 1, 'LIVENESS: offered.')
	assert_eq(ally.tile(), target_tile, 'The ally moves.')

## AUTHOR DECISION 4: the offer matches the drawn Blast, which is flat - an ally standing higher up
## inside the drawn area is "within" it (triggers_regardless_of_elevation = true).
func test_an_ally_higher_up_inside_the_drawn_area_is_offered() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	SpecFactory.set_tiles_elevation(game.map, 4, [INSIDE] as Array[Vector2i])
	assert_true(UnitRelation.distance_between(laid[0], ally) > 1,
		'fixture: measured WITH elevation the ally is out of range - the case discriminates.')
	assert_true(UnitRelation.distance_between(laid[0], ally, true) <= 1, 'fixture: but flat, it is inside.')
	await end_nagas_turn()
	await start_turn_of(ally, [false])
	assert_eq(surge_prompts().size(), 1, 'Offered: inside the drawn Blast, whatever the height.')

func test_a_no_moves_nothing_and_spends_nothing() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	await start_turn_of(ally, [false])
	assert_eq(surge_prompts().size(), 1, 'LIVENESS: offered.')
	assert_eq(surge_moves().size(), 0, 'No picker.')
	assert_eq(ally.tile(), INSIDE, 'No move.')
	assert_eq(ally.core.current.reactions, ally.core.get_reactions_max(), 'No reaction spent.')

func test_an_ally_starting_its_turn_outside_is_not_offered() -> void:
	var ally := NagaFixture.create_ally(game, OUTSIDE)
	await press()
	await end_nagas_turn()
	await start_turn_of(ally, [true])
	assert_eq(surge_prompts().size(), 0, 'Outside the area.')

func test_a_hostile_starting_its_turn_inside_is_never_offered() -> void:
	var hostile := NagaFixture.create_hostile(game, INSIDE)
	await press()
	await end_nagas_turn()
	await start_turn_of(hostile, [true])
	assert_eq(surge_prompts().size(), 0, '"allied characters" only.')
	assert_eq(hostile.tile(), INSIDE, 'Nothing moved it.')

func test_an_allied_drone_is_offered() -> void:
	# A drone is a character (ruling 2026-09-27), so it is offered the surge like any other ally - and
	# it is not the swarm's OWNER (the Naga), which is the only exclusion left (SP3 ruling 22).
	var drone := NagaFixture.own_drone(NagaFixture.create_drone(game, INSIDE), naga)
	await press()
	await end_nagas_turn()
	var target_tile := INSIDE + Vector2i(3, 0)
	responder.chosen_move_tile = target_tile
	await start_turn_of(drone, [true])
	assert_eq(surge_prompts().size(), 1, 'Offered once, at the start of its turn.')
	assert_eq(surge_moves().size(), 1, 'A yes opens a move picker.')
	if surge_moves().size() != 1: return
	assert_eq(drone.tile(), target_tile, 'And the drone moves.')

## Ruling 22 (SP3): "allied characters" does not include the Naga itself - the card's own core
## passive says "you or an allied character" when it means both.
##
## LIVENESS (fix wave, slice 4 #9): the walk must really END inside the area, or "not offered" is
## true of a Naga that never came near it. The same walk by an ALLY is offered - the control that
## this path triggers the surge at all. Mutation: drop the owner clause in triggers_on_event -> RED.
func test_the_naga_itself_is_never_offered() -> void:
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	var inside := CENTRE + Vector2i(-2, -1) # size 2: its east edge ends 1 from the centre
	await walk(naga, inside, [true])
	assert_eq(naga.tile(), inside, 'LIVENESS: the Naga really walked there...')
	assert_true(UnitRelation.distance_between(laid[0], naga) <= 1, '...and that is inside the Blast 1.')
	assert_eq(surge_prompts().size(), 0, 'Not the Naga.')


# ---------------------------------------------------------------- moving in

func test_an_ally_moving_in_is_offered_once_across_several_steps_inside() -> void:
	var ally := NagaFixture.create_ally(game, OUTSIDE)
	await press()
	await walk(ally, DEEPER, [false, true]) # decline on entry; a second offer would be answered yes
	assert_eq(ally.tile(), DEEPER, 'LIVENESS: the walk crossed the area and ended inside it.')
	assert_eq(surge_prompts().size(), 1, 'Offered on the first step in, and not again on the next one.')
	assert_eq(surge_moves().size(), 0, 'Declined, so no picker.')

## THE STANDARD MOVE IS ABANDONED, NOT RESUMED - measured. event_unit_move re-checks after every
## STEP POST that the mover is still where it expected to be (event_unit_move.gd:458,
## has_enough_move_to_reach_end), and a spend_move move whose mover the surge carried elsewhere
## fails that check and aborts: the ally ends where the SURGE put it. That is vanilla's rule for any
## reaction that moves a mover mid-path (a knockback from overwatch is the same case).
func test_a_standard_move_is_interrupted_and_ends_where_the_surge_put_the_ally() -> void:
	var ally := NagaFixture.create_ally(game, OUTSIDE)
	await press()
	await NagaFixture.open_turn(game, ally)
	# THE WALK FITS THE ALLY'S SPEED: a standard move whose path outruns the mover's remaining speed
	# aborts on its own (has_enough_move_to_reach_end), which would read as the surge's doing.
	var destination := CENTRE + Vector2i(0, -1) # 3 west of OUTSIDE, through the area
	assert_true(Tile.distance(OUTSIDE, destination) <= ally.core.current.speed, 'fixture: the walk is affordable.')
	var surge_to := Vector2i(12, 6)
	responder.chosen_move_tile = surge_to
	await walk(ally, destination, [true], MovementType.create_for_standard_move(ally))
	assert_eq(surge_prompts().size(), 1, 'LIVENESS: offered on entry.')
	assert_eq(ally.tile(), surge_to, 'The ally is where the surge put it - the rest of its move was abandoned.')

func test_an_ally_with_no_reaction_is_not_offered_and_keeps_its_once_per_round() -> void:
	var ally := NagaFixture.create_ally(game, OUTSIDE)
	await press()
	ally.core.current.reactions = 0
	await walk(ally, EDGE, [true])
	assert_eq(surge_prompts().size(), 0, 'No reaction, no offer.')
	ally.core.current.reactions = 1
	await walk(ally, DEEPER, [false])
	assert_eq(surge_prompts().size(), 1,
		'The refusal burned nothing: with its reaction back, its next step inside is offered.')

## Ruling 23 (SP3): the OFFER is the round's one chance, yes or no. A step POST fires on every tile
## of a path, so recording only a yes would re-ask a player who declined on every tile they crossed.
func test_an_ally_offered_at_turn_start_is_not_offered_again_that_round() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	await start_turn_of(ally, [false])
	assert_eq(surge_prompts().size(), 1, 'LIVENESS: offered at turn start (declined).')
	# walk() clears the recorded prompts, so each walk is asserted on its own (slice 4 #9).
	await walk(ally, OUTSIDE, [true])
	assert_eq(ally.tile(), OUTSIDE, 'LIVENESS: it left the area.')
	assert_eq(surge_prompts().size(), 0, 'Walking out: not offered.')
	await walk(ally, EDGE, [true])
	assert_eq(ally.tile(), EDGE, 'LIVENESS: and came back in.')
	assert_eq(surge_prompts().size(), 0, 'Re-entering later the same round: not offered again.')


# ---------------------------------------------------------------- not affected by Slowed or Immobilized

func test_a_slowed_ally_moves_its_full_speed() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	SpecFactory.apply(ally, Lancer.STATUS.SLOWED)
	await start_turn_of(ally, [true])
	assert_eq(surge_moves().size(), 1, 'LIVENESS: the picker opened.')
	if surge_moves().size() != 1: return
	assert_eq(furthest_offered(surge_moves()[0], INSIDE), ally.core.get_speed_max(), 'Its full speed, Slowed or not.')

func test_an_immobilized_ally_moves_at_all() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	SpecFactory.apply(ally, Lancer.STATUS.IMMOBILIZED)
	var target_tile := INSIDE + Vector2i(2, 0)
	responder.chosen_move_tile = target_tile
	await start_turn_of(ally, [true])
	assert_true(ally.has_status(Lancer.STATUS.IMMOBILIZED), 'fixture: still Immobilized.')
	assert_eq(surge_moves().size(), 1, 'LIVENESS: the picker opened.')
	if surge_moves().size() != 1: return
	assert_eq(furthest_offered(surge_moves()[0], INSIDE), ally.core.get_speed_max(), 'Its full speed...')
	assert_eq(ally.tile(), target_tile, '...and it really moves (ruling 17: an involuntary move for this ally only).')

## AUTHOR DECISION 3: the Immobilized ally's move is NARROWED to the voluntary one wherever a flag can
## say so. It stays involuntary (every Immobilized gate is `voluntary and ...`), but it takes no fall
## damage, does not "jump downhill", and keeps its MOVEMENT_TYPE buffs (built from MovementType.create).
## What no flag can narrow is recorded in the script's header (difficult terrain, cost-1 climbing).
func test_an_immobilized_allys_move_is_voluntary_in_everything_but_the_immobilized_gate() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	SpecFactory.apply(ally, Lancer.STATUS.IMMOBILIZED)
	responder.chosen_move_tile = INSIDE + Vector2i(2, 0)
	await start_turn_of(ally, [true])
	assert_eq(surge_moves().size(), 1, 'LIVENESS: the picker opened.')
	if surge_moves().size() != 1: return
	var pathfinder:Pathfinder = surge_moves()[0].get('pathfinder')
	if pathfinder == null: return fail_test('fixture: no pathfinder on the picker.')
	var movement:MovementType = pathfinder.using_movement_type
	assert_false(movement.voluntary, 'Still involuntary - the only way past Immobilized.')
	assert_false(movement.takes_fall_damage(), 'No fall damage, as a voluntary move takes none.')
	assert_false(movement.jump_downhill, 'Does not jump downhill.')
	assert_false(movement.ignore_difficult, 'Does not claim to ignore difficult terrain (the engine still does - recorded).')

## The behaviour behind takes_fall_damage(): a wall 3 above the ground across the whole map between the ally
## and its destination. An involuntary step climbs it at cost 1 (pathfinder.gd:772) and the drop off the
## far side is a 3-level fall - Lancer.fall_damage_for_dz(3) = 3 - which a voluntary move never takes.
func test_an_immobilized_ally_takes_no_fall_damage() -> void:
	var ally := NagaFixture.create_ally(game, INSIDE)
	await press()
	await end_nagas_turn()
	var wall:Array[Vector2i] = []
	for y:int in NagaFixture.DEFAULT_MAP_SIZE.y: wall.append(Vector2i(12, y))
	var ground := game.map.elevation(INSIDE) # the default landscape is not at 0
	SpecFactory.set_tiles_elevation(game.map, ground + 3, wall)
	SpecFactory.apply(ally, Lancer.STATUS.IMMOBILIZED)
	var target_tile := Vector2i(13, 5)
	responder.chosen_move_tile = target_tile
	var hp := ally.core.current.health
	await start_turn_of(ally, [true])
	assert_eq(ally.tile(), target_tile, 'LIVENESS: it crossed the wall.')
	assert_eq(game.map.elevation(target_tile), ground, 'fixture: and landed back on the ground...')
	assert_eq(Lancer.fall_damage_for_dz(3), 3, 'fixture: ...a drop worth 3 damage.')
	assert_eq(ally.core.current.health, hp, 'No fall damage.')


# ---------------------------------------------------------------- lifetime

func test_the_swarm_dies_at_the_start_of_the_nagas_next_turn() -> void:
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	var swarm:Unit = laid[0]
	await SpecFactory.end_turn(game, naga)
	assert_true(Unit.is_valid(swarm) and swarm.is_on_map(), 'It outlasts the Naga\'s turn end...')
	await SpecFactory.start_turn(game, naga)
	assert_false(Unit.is_valid(swarm) and swarm.is_on_map(), '..."until the start of your next turn".')

func test_the_swarm_dies_with_the_naga() -> void:
	await press()
	var laid := swarms()
	assert_eq(laid.size(), 1, 'fixture: one swarm.')
	if laid.size() != 1: return
	var swarm:Unit = laid[0]
	await game.execute_event(&'event_unit_die', {unit = naga})
	assert_false(Unit.is_valid(naga), 'fixture: the Naga really died.')
	assert_false(Unit.is_valid(swarm) and swarm.is_on_map(), 'The swarm goes with it.')
