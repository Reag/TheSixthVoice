# BLINKBLADE SLICE (Koremasa rank II, design section 4, ruling 29):
#
#   Limited 3, Unique. SLASH (Quick): "Expend a charge and move up to five spaces in a straight line,
#   ignoring terrain penalties, passing through characters, and ignoring reactions and engagement.
#   Any hostile character you moved through must make a Hull Save or take 3 Kinetic damage and become
#   Locked On."
#
# FULL SPEED AHEAD'S SHAPE WITH THREE CHANGES (ruling 29): caught at distance 0 only - hostiles
# actually passed through, never those merely beside the line; no flying; no AP. The MovementType is
# straight_line, can_move_through_enemies, ignore_rxns, ignore_engagement, ignore_difficult,
# ignore_dangerous (author) and ignore_fall_damage (author, at spec review). Five spaces is the fixed
# budget, not the Koremasa's Speed of 4.
#
# HOW A SPEC AIMS IT: the responder's chosen_move_tile (testkit/mod_choice_responder.gd), with
# target_tiles as well so the stock branch agrees (test_full_speed_ahead.gd's header). Cancel is the
# responder's abort_all, which choose_move_tile reads.
#
# THE SAVE is d20 + the dummy's Hull 0 against the Koremasa's save target 10.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_blinkblade_slice.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const START := Vector2i(2, 5)
const RANGE := 5
const END := START + Vector2i(RANGE, 0)

const FAIL := 5
const PASS := 15
const SLASH_DAMAGE := 3

var game:Gamemaster
var responder
var koremasa:Unit
var blade:GearCore

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, START)
	blade = Fixture.equip(koremasa, Fixture.BLINKBLADE_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func slash() -> ActionSystemMovement:
	if not GearCore.is_valid(blade): return null
	return blade.kit.get_action(Fixture.SLASH_ACTION) as ActionSystemMovement

func specific() -> SpecificAction:
	return SpecificAction.create(koremasa, blade, slash())

## SLASH to `tile` from the Koremasa's open turn, with the saves loaded first.
func slash_to(tile:Vector2i, saves:Array[int] = []) -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue(saves)
	responder.chosen_move_tile = tile
	await game.execute_event(&'event_gear_activate', {
		unit = koremasa,
		gear = blade,
		action = slash(),
		target_tiles = [tile] as Array[Vector2i],
	})

func lost(unit:Unit, before:int) -> int: return before - unit.core.current.health

func locked(unit:Unit) -> bool: return unit.has_status(Lancer.STATUS.LOCKON)

func reachable(pathfinder:Pathfinder, tile:Vector2i) -> bool:
	return pathfinder.reachable_tiles.has(tile)

# ---------------------------------------------------------------- the Kit and the move

func test_the_system_is_limited_three_unique_sp_three():
	var kit:Kit = ContentLibrary.get_kit(Fixture.BLINKBLADE_ID)
	assert_true(Kit.is_valid(kit), 'ms_blinkblade_slice is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, 3, 'SP 3.')
	assert_eq(kit.charges_max, 3, 'Limited 3.')
	assert_true(kit.is_unique(), 'Unique.')
	assert_eq(kit.actions.size(), 1, 'One action.')

func test_slash_is_a_quick_movement_action():
	var action := slash()
	assert_not_null(action, 'SLASH is an ActionSystemMovement.')
	if action == null: return
	assert_eq(action.get_action_type(specific()), Lancer.ACTION.QUICK, 'Quick.')

func test_the_budget_is_five_not_the_koremasas_speed():
	var action := slash()
	assert_not_null(action, 'fixture: the action loads.')
	if action == null: return
	assert_eq(koremasa.get_speed_max(), 4, 'fixture: the Koremasa\'s Speed is 4.')
	assert_eq(action.get_target_range(specific()), RANGE, '"up to five spaces".')

func test_the_movement_type_carries_every_clause():
	var action := slash()
	assert_not_null(action, 'fixture: the action loads.')
	if action == null: return
	var type := action.get_movement_type(koremasa)
	assert_true(type.straight_line, '"in a straight line".')
	assert_true(type.can_move_through_enemies, '"passing through characters".')
	assert_true(type.ignore_rxns, '"ignoring reactions".')
	assert_true(type.ignore_engagement, '"and engagement".')
	assert_true(type.ignore_difficult, '"ignoring terrain penalties": difficult.')
	assert_true(type.ignore_dangerous, '"ignoring terrain penalties": dangerous (author).')
	assert_true(type.ignore_fall_damage, 'No fall damage mid-line (author, at spec review).')
	assert_false(type.flying, 'Not a flight.')
	assert_true(type.voluntary, 'A voluntary move.')

func test_it_moves_five_in_a_straight_line():
	var pathfinder := await slash_pathfinder()
	assert_true(pathfinder != null and reachable(pathfinder, END), 'Five spaces is offered.')
	assert_false(pathfinder != null and reachable(pathfinder, END + Vector2i(1, 0)), 'Six is not.')
	await slash_to(END)
	assert_eq(koremasa.tile(), END, 'Five spaces east.')

func test_a_charge_is_spent():
	var before := blade.charges_current
	await slash_to(END)
	assert_eq(koremasa.tile(), END, 'LIVENESS: it moved.')
	assert_eq(blade.charges_current, before - 1, '"Expend a charge".')

func test_a_cancel_spends_nothing():
	var before := blade.charges_current
	await Fixture.open_turn(game, koremasa)
	responder.abort_all = true
	await game.execute_event(&'event_gear_activate', {unit = koremasa, gear = blade, action = slash()})
	assert_eq(koremasa.tile(), START, 'Cancelled: it stayed.')
	assert_eq(blade.charges_current, before, 'No charge spent.')
	assert_true(UnitAction.is_gear_available(specific()), 'And the Quick is not spent either.')

func test_it_is_refused_with_no_charges():
	blade.charges_current = 0
	assert_eq(UnitAction.get_gear_unavailable_reason(specific()), UnitAction.REASON.NO_CHARGES,
		'Limited: no charges, no Slash.')

# ---------------------------------------------------------------- who is caught

func test_through_two_hostiles_and_an_ally_each_hostile_fails_and_pays():
	var first := Fixture.create_hostile(game, START + Vector2i(1, 0))
	var ally := Fixture.create_ally(game, START + Vector2i(2, 0))
	var second := Fixture.create_hostile(game, START + Vector2i(3, 0))
	var before_first := first.core.current.health
	var before_second := second.core.current.health
	var before_ally := ally.core.current.health
	var pathfinder := await slash_pathfinder()
	assert_true(pathfinder != null and reachable(pathfinder, END), '"passing through characters": offered.')
	await slash_to(END, [FAIL, FAIL])
	assert_eq(koremasa.tile(), END, 'It passed through all three to a free tile.')
	assert_eq(lost(first, before_first), SLASH_DAMAGE, 'The first hostile takes 3.')
	assert_eq(lost(second, before_second), SLASH_DAMAGE, 'The second hostile takes 3.')
	assert_true(locked(first), 'The first is Locked On.')
	assert_true(locked(second), 'The second is Locked On.')
	assert_eq(lost(ally, before_ally), 0, 'The ally takes nothing...')
	assert_false(locked(ally), '...and is not Locked On.')

func test_a_passed_save_costs_nothing():
	var hostile := Fixture.create_hostile(game, START + Vector2i(2, 0))
	var before := hostile.core.current.health
	await slash_to(END, [PASS])
	assert_eq(koremasa.tile(), END, 'LIVENESS: it moved.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 60, 'LIVENESS: exactly one save was rolled.')
	assert_eq(lost(hostile, before), 0, 'Saved: no damage.')
	assert_false(locked(hostile), 'Saved: not Locked On.')

func test_a_large_hostile_passed_through_twice_saves_once():
	var big := Fixture.create_mount(game, START + Vector2i(2, 0)) # size 2: two tiles of the line
	var before := big.core.current.health
	await slash_to(END, [FAIL, FAIL])
	assert_true(big.occupied_tiles().has(START + Vector2i(3, 0)), 'fixture: it spans two tiles of the line.')
	assert_eq(Dice.CHEAT_ROLL_QUEUE.size(), 61, 'One save, not two.')
	assert_eq(lost(big, before), SLASH_DAMAGE, 'One helping of 3.')

func test_a_hostile_beside_the_line_is_not_caught():
	var beside := Fixture.create_hostile(game, START + Vector2i(2, -1))
	var before := beside.core.current.health
	await slash_to(END, [FAIL])
	assert_eq(koremasa.tile(), END, 'LIVENESS: it moved past.')
	assert_eq(lost(beside, before), 0, '"you moved through" - adjacency is not enough.')
	assert_false(locked(beside), 'Not Locked On.')

func test_the_damage_is_not_ap():
	var hostile := Fixture.create_hostile(game, START + Vector2i(2, 0))
	hostile.core.frame.stat.armor = 1
	hostile.core.full_repair()
	var before := hostile.core.current.health
	await slash_to(END, [FAIL])
	assert_eq(lost(hostile, before), SLASH_DAMAGE - 1, '3 Kinetic, and armor bites: not AP.')

func test_an_already_locked_hostile_still_takes_the_damage():
	var hostile := Fixture.create_hostile(game, START + Vector2i(2, 0))
	UnitCondition.apply_status(SpecFactory.dummy_event(), hostile, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL)
	var before := hostile.core.current.health
	await slash_to(END, [FAIL])
	assert_eq(lost(hostile, before), SLASH_DAMAGE, 'The damage lands.')
	assert_true(locked(hostile), 'Still Locked On.')

func test_a_flying_hostile_is_not_caught():
	var flier := Fixture.create_hostile(game, START + Vector2i(2, 0))
	SpecFactory.apply(flier, Lancer.STATUS.FLYING)
	var before := flier.core.current.health
	await slash_to(END, [FAIL])
	assert_eq(koremasa.tile(), END, 'LIVENESS: it moved under it.')
	assert_eq(lost(flier, before), 0, 'A flier overhead is not moved through (the Trample filter).')

# ---------------------------------------------------------------- terrain

## THE PICKER DOES NOT CHECK THE BUDGET IN A SPEC. The responder answers chosen_move_tile as given
## (spec_factory.gd:423-430), and the plan is built to it whether or not the pathfinder offered it -
## so a unit LANDING on a tile proves nothing about what the move cost. Every cost claim below is
## asserted against Slash's own pathfinder instead (measured: with ignore_difficult deleted, a
## landing-only version of the next test stayed green).
func slash_pathfinder() -> Pathfinder:
	var action := slash()
	if action == null: return null
	return await action.generate_action_pathfinder(specific())

func test_difficult_terrain_costs_nothing():
	var line:Array[Vector2i] = []
	for i:int in range(1, RANGE): line.append(START + Vector2i(i, 0))
	VaubanFixture.lay_difficult(game, line)
	var walk := MovementType.create(koremasa)
	walk.straight_line = true
	var control := await Pathfinder.generate_for_movement_budget(koremasa, RANGE, walk)
	assert_false(reachable(control, END), 'fixture: a straight walk of 5 cannot cross it.')
	var pathfinder := await slash_pathfinder()
	assert_not_null(pathfinder, 'fixture: the action loads.')
	if pathfinder == null: return
	assert_true(reachable(pathfinder, END), 'Slash reaches five spaces across four difficult tiles.')

func test_dangerous_terrain_in_transit_costs_nothing():
	var lava:Array[Vector3i] = [Vector3i(4, 0, 5), Vector3i(5, 0, 5)]
	SpecFactory.add_blocks_to_landscape(game.get_landscape_node(), 'block_lava', lava)
	assert_true(game.map.get_surface_terrain_at(Vector2i(4, 5)).is_dangerous(), 'fixture: (4, 5) is dangerous.')
	var before := koremasa.core.current.health
	await slash_to(END, [1, 1]) # if a transit check fired, a 1 would fail it
	assert_eq(koremasa.tile(), END, 'It crossed the lava.')
	assert_eq(koremasa.core.current.health, before, 'And took no dangerous-terrain damage.')

func test_a_dip_mid_line_deals_no_fall_damage():
	# high, low, low, high: a 3-drop (fall damage 3 on a straight line without the flag,
	# katamari.gd:104-115), then a 1-climb back up. Costed as a walk: 2 + 1 + 2 = 5.
	SpecFactory.set_tiles_elevation(game.map, 3, [START] as Array[Vector2i])
	SpecFactory.set_tiles_elevation(game.map, 0, [START + Vector2i(1, 0), START + Vector2i(2, 0)] as Array[Vector2i])
	SpecFactory.set_tiles_elevation(game.map, 1, [START + Vector2i(3, 0)] as Array[Vector2i])
	UnitTile.move_to(koremasa, START)
	var pathfinder := await slash_pathfinder()
	assert_true(pathfinder != null and reachable(pathfinder, START + Vector2i(3, 0)),
		'The far lip is within the five (2 + 1 + 2).')
	var before := koremasa.core.current.health
	await slash_to(START + Vector2i(3, 0))
	assert_eq(koremasa.tile(), START + Vector2i(3, 0), 'It crossed the dip.')
	assert_eq(koremasa.core.current.health, before, 'No fall damage on the way down.')

## "in a straight line": a single pillar on the line cuts off everything behind it, where any
## free-routing move would step round it. (A straight line may run at ANY angle - the engine's line
## is rasterised - so "the endpoint is off the eight directions" is not a test of it.)
func test_a_pillar_on_the_line_is_not_walked_round():
	var pillar := START + Vector2i(2, 0)
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(START) + 6, [pillar] as Array[Vector2i])
	var walk := MovementType.create(koremasa)
	var control := await Pathfinder.generate_for_movement_budget(koremasa, RANGE, walk)
	assert_true(reachable(control, START + Vector2i(4, 0)), 'fixture: a free walk of 5 goes round the pillar.')
	var pathfinder := await slash_pathfinder()
	assert_not_null(pathfinder, 'fixture: the action loads.')
	if pathfinder == null: return
	assert_true(reachable(pathfinder, START + Vector2i(1, 0)), 'Up to the pillar is fine.')
	assert_false(reachable(pathfinder, START + Vector2i(4, 0)), 'Behind it, on the same line, is not.')

func test_it_stops_at_a_wall():
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(START.x + 3, y))
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(START) + 6, wall)
	var action := slash()
	assert_not_null(action, 'fixture: the action loads.')
	if action == null: return
	var pathfinder:Pathfinder = await action.generate_action_pathfinder(specific())
	assert_true(reachable(pathfinder, START + Vector2i(2, 0)), 'Up to the wall is fine.')
	assert_false(reachable(pathfinder, START + Vector2i(4, 0)), 'Nothing beyond it.')
	assert_false(reachable(pathfinder, END), 'Not the far end either.')

# ---------------------------------------------------------------- reactions

func test_leaving_a_hostiles_threat_on_foot_draws_overwatch():
	# CONTROL for the test below: the watcher really does take the shot on an ordinary walk.
	var watcher := Fixture.create_hostile(game, START + Vector2i(0, -1))
	Fixture.equip(watcher, Fixture.MELEE)
	await Fixture.open_turn(game, koremasa)
	Fixture.queue([15])
	var before := koremasa.core.current.health
	await SpecFactory.move(game, koremasa, START + Vector2i(0, 2))
	assert_lt(koremasa.core.current.health, before, 'fixture: a walk out of threat is punished.')

func test_no_overwatch_fires_on_slash():
	var watcher := Fixture.create_hostile(game, START + Vector2i(0, -1))
	Fixture.equip(watcher, Fixture.MELEE)
	var before := koremasa.core.current.health
	await Fixture.open_turn(game, koremasa)
	Dice.CHEAT_ROLL_QUEUE.assign([15, 15, 15, 15])
	responder.chosen_move_tile = END
	await game.execute_event(&'event_gear_activate', {
		unit = koremasa, gear = blade, action = slash(), target_tiles = [END] as Array[Vector2i],
	})
	assert_eq(koremasa.tile(), END, 'LIVENESS: it left.')
	assert_eq(koremasa.core.current.health, before, '"ignoring reactions": nothing fired.')

# ---------------------------------------------------------------- refusals

func test_it_is_refused_while_riding():
	var mount := Fixture.create_mount(game, Vector2i(6, 5))
	responder.chosen_move_tile = Vector2i(5, 5)
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)
	responder.chosen_move_tile = Tile.INVALID
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: the Koremasa is riding.')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific()), UnitAction.REASON.STACKED_UP,
		'A rider cannot Slash.')

func test_it_is_refused_while_slowed():
	SpecFactory.apply(koremasa, Lancer.STATUS.SLOWED)
	assert_eq(UnitAction.get_gear_unavailable_reason(specific()), UnitAction.REASON.SPECIFIC, 'Slowed.')

func test_it_is_refused_while_immobilized():
	SpecFactory.apply(koremasa, Lancer.STATUS.IMMOBILIZED)
	assert_eq(UnitAction.get_gear_unavailable_reason(specific()), UnitAction.REASON.SPECIFIC, 'Immobilized.')

# ---------------------------------------------------------------- the card

func test_the_card_rows_resolve():
	for key:String in ['gear.ms_blinkblade_slice.name', 'gear.ms_blinkblade_slice.flavor',
			'gear.ms_blinkblade_slice.action_slash.name', 'gear.ms_blinkblade_slice.action_slash.effect']:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.ms_blinkblade_slice.action_slash.name'), 'Slash', 'The action is Slash.')
