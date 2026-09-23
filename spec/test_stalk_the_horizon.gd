# STALK THE HORIZON (Purple Thorn core passive, SP1 Task 4).
#
#   "2/round, when a hostile character in Line of Sight starts to move, you may make an attack
#    against them with an Auxiliary weapon as a reaction."
#
# THE MOVE UNDER TEST is PurpleThornFixture.standard_move: it opens the MOVER's turn, then issues an
# event_unit_move with MovementType.create(unit, true) - voluntary, not a teleport, reactions
# provoked. OPENING THE MOVER'S TURN IS LOAD-BEARING AND DOUBLE-EDGED: event_turn_start refreshes
# EVERY unit's reaction point (event_turn_start.gd:42-44, "applied to ALL units"), so a hostile's
# turn start hands the Thorn its point back - which is exactly how a real round plays and why the
# 2/round bites at all - while the Thorn's PER-ROUND TALLY resets only at the THORN's own turn
# start (:79). So: two moves inside ONE hostile turn test the point; moves across two hostile turns
# test the tally; a Thorn turn start resets it. Every case here says which it is measuring.
#
# THE SHOT: choose_and_use with one Aux auto-picks it, the mover is the mandatory target, and the
# stock responder answers the compcon-plan request with that target - so a Stalk shot raises no
# prompt a spec has to queue for. The Nexus pops the d20, one d3 hit die, one d3 crit die.
#
# THE SEEKING CASE (SP1 J-5, landed SP2 Task 1). Ruling 5's own-LOS gate exists so a SEEKING Aux
# cannot fire through a wall. The Nexus wall case below cannot tell the two gates apart - its own
# LOS requirement fails too - so the Blink Bolt Launcher cases after it do: the weapon filter
# (get_possible_auxes) DOES offer the bolt behind the wall, and only the trait's can_see refuses.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_stalk_the_horizon.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const StalkAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/cp_lav_tactical_engine/action_stalk_the_horizon.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const THORN_TILE := Vector2i(4, 6)
## Four east: inside the Nexus's Range 10.
const MOVER_TILE := Vector2i(8, 6)
const MOVER_STEP := Vector2i(8, 7)
const MOVER_STEP_2 := Vector2i(8, 8)
## A second and third hostile, also in range, on their own rows.
const SECOND_TILE := Vector2i(9, 3)
const SECOND_STEP := Vector2i(9, 2)
const THIRD_TILE := Vector2i(9, 9)
const THIRD_STEP := Vector2i(9, 10)
## Twelve east: outside the Nexus's Range 10.
const FAR_TILE := Vector2i(16, 6)
const FAR_STEP := Vector2i(16, 7)
## The Purple Thorn's own SEEKING Aux (SP2).
const BLINK_BOLT := &'mw_blink_bolt_launcher'
## The column a wall stands in for the LOS case: between the Thorn and the mover.
const WALL_X := 6

const D20_HITS := 19
## On the map, far outside range 3 of anywhere the Thorn stands: cancels Vigil's reticle.
const CANCEL_VIGIL := Vector2i(25, 11)

var game:Gamemaster
var thorn:Unit
var mover:Unit
var responder
var shots:ShotWatcher

## Records the FLAGS of every attack declared against the unit it sits on - the IS_OVERWATCH /
## AS_RXN observable. Installed on the mover as a runtime trait Kit; never activates.
class ShotWatcher extends ActionReaction:
	var flags_seen:Array[Array] = []
	var seen_ids:Array[StringName] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.flags]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if seen_ids.has(triggering_event.id): return false
		seen_ids.append(triggering_event.id)
		flags_seen.append(triggering_event.context.flags.duplicate())
		return false


func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	mover = Fixture.create_hostile(game, MOVER_TILE)
	shots = ShotWatcher.new()
	install_on(mover, shots, &'spec_shot_watcher')
	# THE FRAME'S OTHER TWO TRAITS FIRE ON EVERY STALK HIT: Blessed Bolt offers a yes/no (default
	# YES, +3 to every number below) and Vigil opens a reticle (default: the first reachable tile,
	# which walks the Thorn about the board). Decline the one and cancel the other - an unreachable
	# answer empties the plan (test_vigil.gd's idiom) - so this file measures Stalk alone.
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func install_on(unit:Unit, reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func arm_nexus() -> void:
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)

func uses() -> int:
	return Fixture.uses_this_round(thorn, Fixture.CORE_ID, Fixture.STALK_ID)

func points() -> int:
	return thorn.core.current.reactions

## A hostile's standard move (opens ITS turn), with the Nexus's dice queued for the shot it may draw.
func moves(unit:Unit, to:Vector2i) -> void:
	Fixture.queue([D20_HITS, 3, 1])
	await Fixture.standard_move(game, unit, to)

## A second move inside the SAME turn - no turn start, so no point refresh.
func moves_again(unit:Unit, to:Vector2i) -> void:
	Fixture.queue([D20_HITS, 3, 1])
	await SpecFactory.move(game, unit, to)

## A full-height wall down column x, the Green Tide spec's shape: blocks LOS at every layer.
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	var ground := game.map.elevation(THORN_TILE)
	SpecFactory.set_tiles_elevation(game.map, ground + 6, wall)
	UnitTile.update_tracking_and_statuses(game.map)

# ---------------------------------------------------------------- the offer

func test_a_hostile_starting_a_standard_move_in_los_is_shot_by_the_aux_and_the_point_is_spent():
	arm_nexus()
	assert_eq(points(), 1, 'fixture: the Thorn has its point.')
	await moves(mover, MOVER_STEP)
	assert_eq(mover.tile(), MOVER_STEP, 'fixture: the move happened.')
	assert_eq(mover.current_damage(), 3, 'The Nexus fired at the mover for its die.')
	assert_eq(uses(), 1, 'One of the two uses this round is spent...')
	assert_eq(points(), 0, '...and so is the reaction point (author: it spends the point).')

func test_the_shot_is_a_reaction_and_not_an_overwatch():
	arm_nexus()
	await moves(mover, MOVER_STEP)
	assert_eq(shots.flags_seen.size(), 1, 'fixture: one attack was declared on the mover.')
	if shots.flags_seen.is_empty(): return
	var flags:Array = shots.flags_seen[0]
	assert_true(flags.has(Action.FLAG.AS_RXN), 'The shot is flagged AS_RXN - "as a reaction".')
	assert_false(flags.has(Action.FLAG.IS_OVERWATCH), 'And NOT IS_OVERWATCH: Impaler, Punisher Ammunition, Marker Shells and Lockbreaker do not key on it.')

func test_a_second_move_in_the_same_hostile_turn_is_not_shot_because_the_point_is_gone():
	arm_nexus()
	await moves(mover, MOVER_STEP)
	await moves_again(mover, MOVER_STEP_2)
	assert_eq(mover.tile(), MOVER_STEP_2, 'fixture: the second move happened.')
	assert_eq(mover.current_damage(), 3, 'Shot once: the point was spent on the first move.')
	assert_eq(uses(), 1, 'One use.')

func test_the_next_hostile_turn_refreshes_the_point_and_the_second_use_fires():
	arm_nexus()
	var second:Unit = Fixture.create_hostile(game, SECOND_TILE)
	await moves(mover, MOVER_STEP)
	await moves(second, SECOND_STEP) # its turn start hands the Thorn its point back
	assert_eq(second.current_damage(), 3, 'The second hostile\'s move was shot too.')
	assert_eq(uses(), 2, 'Two uses this round.')

func test_the_third_hostile_move_in_a_round_is_not_shot():
	arm_nexus()
	var second:Unit = Fixture.create_hostile(game, SECOND_TILE)
	var third:Unit = Fixture.create_hostile(game, THIRD_TILE)
	await moves(mover, MOVER_STEP)
	await moves(second, SECOND_STEP)
	await moves(third, THIRD_STEP)
	assert_eq(points(), 1, 'fixture: the point WAS there (the third turn start refreshed it).')
	assert_eq(third.current_damage(), 0, '2/round: the third mover is not shot.')
	assert_eq(uses(), 2, 'Still two.')

func test_after_the_thorns_own_turn_start_it_fires_again():
	arm_nexus()
	var second:Unit = Fixture.create_hostile(game, SECOND_TILE)
	var third:Unit = Fixture.create_hostile(game, THIRD_TILE)
	await moves(mover, MOVER_STEP)
	await moves(second, SECOND_STEP)
	await Fixture.cycle_turn(game, thorn) # the Thorn's turn: its per-round tally resets
	await SpecFactory.end_turn(game, thorn)
	await moves(third, THIRD_STEP)
	assert_eq(third.current_damage(), 3, 'A new round for the Thorn: the mover is shot.')
	assert_eq(uses(), 1, 'One use in the new round.')

# ---------------------------------------------------------------- what does not offer

func test_a_mover_out_of_line_of_sight_is_not_shot():
	arm_nexus()
	build_wall_at(WALL_X)
	assert_false(UnitRelation.can_see(thorn, mover), 'fixture: the wall blocks LOS.')
	await moves(mover, MOVER_STEP)
	assert_eq(mover.current_damage(), 0, 'Not in Line of Sight: no shot.')
	assert_eq(points(), 1, 'The point is untouched.')

func test_a_seeking_aux_is_not_fired_through_a_wall_by_the_traits_own_gate():
	Fixture.mount_pair(thorn, 0, BLINK_BOLT)
	build_wall_at(WALL_X)
	assert_false(UnitRelation.can_see(thorn, mover), 'fixture: the wall blocks LOS.')
	assert_false(StalkAction.get_possible_auxes(thorn, mover).is_empty(),
		'fixture: the weapon filter WOULD offer the SEEKING bolt behind the wall - so the refusal below is the TRAIT gate.')
	await moves(mover, MOVER_STEP)
	assert_eq(mover.current_damage(), 0, '"In Line of Sight": no shot, SEEKING or not.')
	assert_eq(points(), 1, 'The point is untouched.')
	assert_eq(uses(), 0, 'No use.')

func test_the_seeking_aux_is_fired_when_the_mover_is_in_sight():
	Fixture.mount_pair(thorn, 0, BLINK_BOLT)
	await moves(mover, MOVER_STEP)
	assert_eq(mover.current_damage(), 2, 'Control: in sight, the Blink Bolt Launcher fires for its 2.')
	assert_eq(uses(), 1, 'One use.')

func test_a_teleporting_hostile_is_not_shot():
	arm_nexus()
	await Fixture.open_turn(game, mover)
	Fixture.queue([D20_HITS, 3, 1])
	await SpecFactory.move(game, mover, MOVER_STEP, Teleport.movement_type(mover))
	assert_eq(mover.tile(), MOVER_STEP, 'fixture: it teleported.')
	assert_eq(mover.current_damage(), 0, 'A teleport is not "starts to move" (as for Overwatch).')

func test_an_involuntary_move_is_not_shot():
	arm_nexus()
	await Fixture.open_turn(game, mover)
	Fixture.queue([D20_HITS, 3, 1])
	await SpecFactory.move(game, mover, MOVER_STEP, MovementType.create(mover, false))
	assert_eq(mover.tile(), MOVER_STEP, 'fixture: it was moved.')
	assert_eq(mover.current_damage(), 0, 'Being pushed is not "starts to move".')

func test_an_allied_move_is_not_shot():
	arm_nexus()
	var ally:Unit = Fixture.create_ally(game, SECOND_TILE)
	await moves(ally, SECOND_STEP)
	assert_eq(ally.current_damage(), 0, 'Not hostile: no shot.')

func test_a_hostile_drone_is_not_shot():
	# "character" is is_actor() (row 301): a drone is a character but not an actor.
	arm_nexus()
	var drone:Unit = Fixture.create_drone(game, SECOND_TILE)
	assert_true(drone.is_character() and not drone.is_actor(), 'fixture: a drone.')
	await moves(drone, SECOND_STEP)
	assert_eq(drone.current_damage(), 0, 'A drone is not a "hostile character".')

func test_with_only_main_weapons_nothing_fires():
	Fixture.arm_rifle(thorn)
	await moves(mover, MOVER_STEP)
	assert_eq(mover.current_damage(), 0, 'No Auxiliary weapon: no shot.')
	assert_eq(points(), 1, 'The point is untouched.')

func test_a_mover_out_of_the_auxs_range_is_not_shot():
	arm_nexus()
	Fixture.step(mover, FAR_TILE)
	await moves(mover, FAR_STEP)
	assert_eq(mover.current_damage(), 0, 'Twelve out: past Range 10.')

func test_without_a_reaction_point_nothing_fires():
	arm_nexus()
	thorn.core.current.reactions = 0
	await Fixture.open_turn(game, mover) # (a turn start would refresh it, so open first...)
	thorn.core.current.reactions = 0     # ...and take it away again)
	await moves_again(mover, MOVER_STEP)
	assert_eq(mover.current_damage(), 0, 'No point, no reaction.')

func test_the_thorns_own_move_is_not_shot():
	arm_nexus()
	await moves(thorn, Vector2i(4, 7))
	assert_eq(thorn.current_damage(), 0, 'It does not stalk itself.')

# ---------------------------------------------------------------- wiring and card text

func test_the_aux_filter_is_return_fires():
	arm_nexus()
	Fixture.arm_rifle(thorn)
	var auxes := StalkAction.get_possible_auxes(thorn, mover)
	assert_eq(auxes.size(), 1, 'One Aux can react against the mover...')
	if auxes.is_empty(): return
	assert_eq(auxes[0].gear.kit.compcon_id, Fixture.AUX_NEXUS, '...the Nexus; the rifle is filtered out.')

func test_the_wiring_and_the_card_text():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_not_null(kit, 'cp_lav_tactical_engine is indexed as a Kit.')
	if kit == null: return
	assert_true(kit.is_trait, 'It is a trait Kit (the core system).')
	assert_eq(kit.actions.size(), 2, 'Two actions.')
	var action = kit.get_action(Fixture.STALK_ID)
	assert_not_null(action, 'action_stalk_the_horizon is on it.')
	if action == null: return
	assert_true(action is ActionReaction, 'A reaction...')
	assert_eq(action.triggers_on, [&'entire_movement'] as Array[StringName], '...on ENTIRE_MOVEMENT...')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE, '...PRE - Overwatch\'s trigger.')
	assert_true(action.consumes_rxn, 'It SPENDS the reaction point (author).')
	assert_eq(action.get_per_round_hard_limit(null), 2, '2/round.')
	assert_eq(action.usage_group, &'stalk_the_horizon', 'Its own usage group.')
	assert_ne(action.usage_group, kit.get_action(Fixture.REND_ID).usage_group, 'Distinct from Rend\'s.')
	# Card text drawn ONCE (SP5, the Blood of the Creature's shape): the reaction's own
	# show_in_tooltip override forces it to draw instead of hiding as a duplicate of the Kit's
	# sentence, so it gets its own name, its own family glyph, and the Kit's plain-text row hides
	# behind it (tooltip_organ_kit.gd:77-83) - see test_content_integrity.gd's ICON_TARGETS row.
	assert_true(action.show_in_tooltip(kit), 'The reaction draws its own row, under its own name and glyph (SP5).')
	var translation:Translation = load(OUR_TRANSLATION)
	if translation == null:
		fail_test('This mod has a compiled translation.')
		return
	for key:String in ['gear.cp_lav_tactical_engine.name', 'gear.cp_lav_tactical_engine.flavor', 'gear.cp_lav_tactical_engine.effect',
			'gear.cp_lav_tactical_engine.action_stalk_the_horizon.name', 'gear.cp_lav_tactical_engine.action_stalk_the_horizon.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.cp_lav_tactical_engine.name'), 'LAV Tactical Engine', 'Named as the card.')
	assert_eq(X.tr('gear.cp_lav_tactical_engine.action_stalk_the_horizon.name'), 'Stalk the Horizon', 'The passive is named as the card.')
	assert_true(X.tr('gear.cp_lav_tactical_engine.effect').begins_with('2/round, when a hostile character in Line of Sight'),
		'The Kit\'s effect row is the passive line, opening as the card does.')
	assert_true(X.tr('gear.cp_lav_tactical_engine.flavor').begins_with('The Long-range Automatic Vigilance engine'),
		'The core flavour is the sheet\'s.')
