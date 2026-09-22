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


func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	tide = NagaFixture.equip(naga, KIT_ID)

func after_each() -> void:
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

func test_an_allied_drone_is_never_offered() -> void:
	var drone := NagaFixture.own_drone(NagaFixture.create_drone(game, INSIDE), naga)
	await press()
	await end_nagas_turn()
	await start_turn_of(drone, [true])
	assert_eq(surge_prompts().size(), 0, 'A drone is not a character (the mod-wide rule, ruling 21).')

## Ruling 22 (SP3): "allied characters" does not include the Naga itself - the card's own core
## passive says "you or an allied character" when it means both.
func test_the_naga_itself_is_never_offered() -> void:
	await press()
	await walk(naga, CENTRE + Vector2i(-2, -1), [true]) # size 2: its east edge ends 1 from the centre
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
	await walk(ally, OUTSIDE, [true])
	await walk(ally, EDGE, [true])
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
