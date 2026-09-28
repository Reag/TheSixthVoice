# PINPOINT MARK (Purple Thorn rank II system, SP3 Task 2, design rulings 12-13).
#
#   UNIQUE, LIMITED 3, SP 2. Hyperfocus (Quick): Expend a charge, choose a character within
#   Sensors: You have an additional +1 to attack rolls against them and they always count as within
#   range of your ranged weapons. This effect ends if you take any actions that affect a different
#   hostile character. You cannot choose a new target unless the current target is destroyed or the
#   scene ends.
#
# Pinned here: the pick (a charge, a hostile CHARACTER in Sensors, the lock while the focus lives,
# free again once it dies); the +1 (flat, against the focus only); the waiver (a focus 20 away is
# targetable by a Range 10 rifle; RANGE ONLY - behind a wall it is not, unless the weapon is SEEKING;
# never for a melee weapon); the end (an attack on another hostile - a hit, a Blast catch, an invade,
# a Stalk the Horizon shot - ends the buffs, the marker and the state; an attack on the focus or an
# ally does not; a Lock On on another hostile does NOT, the divergence the SP3 probe measured).
#
# ON THE THORN, so Vigil opens a reticle on every hit (cancelled) and Blessed Bolt's yes/no is
# declined - test_stalk_the_horizon.gd's idiom.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_pinpoint_mark.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const Hyperfocus := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/hyperfocus.gd')

const KIT_ID := &'ms_pinpoint_mark'
const ACTION_ID := &'action_hyperfocus'
const CHIP := &'buff_hyperfocus'
const RANGE := &'buff_hyperfocus_range'
const MARKER := &'buff_hyperfocused'

const BLINK_BOLT := &'mw_blink_bolt_launcher' # Aux, SEEKING, Range 10
const MISSILE_RACK := &'mw_missile_rack'      # Main, Blast 1, Range 10
const MELEE := &'mw_heavy_melee_weapon'       # Heavy Melee, Threat 1
const FRAGMENT_SIGNAL := &'ms_fragment_signal'
const LOCK_ON := &'ms_lock_on'

const THORN_TILE := Vector2i(4, 6)
## 14 east: inside Sensors 15, outside every Range 10 weapon here.
const FOCUS_TILE := Vector2i(18, 6)
## 20 east of the Thorn.
const FAR_TILE := Vector2i(24, 6)
const OTHER_TILE := Vector2i(8, 6)
const OTHER_STEP := Vector2i(8, 5)
const ALLY_TILE := Vector2i(8, 8)
const BESIDE_FOCUS := Vector2i(19, 6)
const WALL_X := 12

const D20_HITS := 19
const CANCEL_VIGIL := Vector2i(28, 0)

var game:Gamemaster
var thorn:Unit
var focus:Unit
var other:Unit
var gear:GearCore
var responder

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	focus = Fixture.create_hostile(game, FOCUS_TILE)
	other = Fixture.create_hostile(game, OTHER_TILE)
	# ARM EVERYTHING UP FRONT - equip() re-runs full_repair, which must never follow the pick.
	Fixture.arm_rifle(thorn)
	Fixture.mount_pair(thorn, 0, BLINK_BOLT, Fixture.AUX_NEXUS)
	Fixture.mount_pair(thorn, 2, MISSILE_RACK)
	Fixture.equip(thorn, MELEE)
	gear = Fixture.equip(thorn, KIT_ID)
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func hyperfocus(at:Unit) -> void:
	if not thorn.state.is_taking_turn: await Fixture.open_turn(game, thorn)
	await SpecFactory.use_solo(game, thorn, KIT_ID, at)

func action() -> Action:
	return gear.get_solo_action()

func focused_on() -> Unit:
	return Hyperfocus.focus_of(gear, game.map)

func is_fully_ended() -> bool:
	return (
		focused_on() == null and
		not UnitCondition.has_buff(thorn, CHIP) and
		not UnitCondition.has_buff(thorn, RANGE) and
		not UnitCondition.has_buff(focus, MARKER)
	)

func is_fully_focused() -> bool:
	return (
		focused_on() == focus and
		UnitCondition.has_buff(thorn, CHIP) and
		UnitCondition.has_buff(thorn, RANGE) and
		UnitCondition.has_buff(focus, MARKER)
	)

func targetable(kit_id:StringName) -> Array[Vector2i]:
	var weapon := thorn.get_gear(kit_id)
	return UnitTargeting.get_tiles_targetable(SpecificAction.create(thorn, weapon, weapon.get_solo_action()))

func flat_bonus(kit_id:StringName, against:Unit) -> int:
	var weapon := thorn.get_gear(kit_id)
	var ctx := Context.create({unit = thorn, gear = weapon, action = weapon.get_solo_action(), target_unit = against})
	return AttackRoll.PreAttack.create(ctx).flat_bonus

## A rifle shot at `at`, the Thorn's turn cycled first (the fixture's shoot).
func rifle_at(at:Unit) -> void:
	Fixture.queue([D20_HITS, 4])
	await Fixture.shoot(game, thorn, at, Fixture.MAIN_RIFLE)

## The Green Tide spec's full-height wall down column x.
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(THORN_TILE) + 6, wall)
	UnitTile.update_tracking_and_statuses(game.map)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE.')
	assert_eq(kit.charges_max, 3, 'LIMITED 3.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var hf := kit.actions[0] as ActionSystemTargetUnit
	assert_not_null(hf, 'Hyperfocus targets a unit.')
	if hf == null: return
	assert_eq(hf.get_id(), ACTION_ID, 'Its id.')
	assert_eq(hf.action_type, Lancer.ACTION.QUICK, 'Quick.')
	assert_true(hf.target_range_is_sensors, 'Within Sensors.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Pinpoint Mark', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('The Pinpoint systems on the TIAX-UYL line'), 'The flavour row.')
	assert_eq(X.tr('gear.%s.%s.name' % [KIT_ID, ACTION_ID]), 'Hyperfocus', 'The action row.')
	assert_true(X.tr('gear.%s.%s.effect' % [KIT_ID, ACTION_ID]).begins_with('Expend a charge'), 'The effect row.')
	assert_eq(X.tr('gear.%s.name' % CHIP), 'Hyperfocus', 'The chip\'s name row.')
	assert_eq(X.tr('gear.%s.name' % MARKER), 'Hyperfocus', 'The marker\'s name row.')

func test_the_waiver_is_hidden_and_the_chip_and_marker_are_not():
	assert_true(ContentLibrary.get_buff(RANGE).hide_from_player, 'The range waiver is hidden plumbing.')
	assert_false(ContentLibrary.get_buff(CHIP).hide_from_player, 'The Thorn\'s chip is visible.')
	assert_false(ContentLibrary.get_buff(MARKER).hide_from_player, 'The focus\'s marker is visible.')

# ---------------------------------------------------------------- the pick

func test_hyperfocus_spends_a_charge_and_marks_the_target():
	assert_eq(gear.charges_current, 3, 'fixture: three charges.')
	await hyperfocus(focus)
	assert_eq(gear.charges_current, 2, 'A charge is spent.')
	assert_true(is_fully_focused(), 'The focus is stored, the Thorn carries both buffs, the focus the marker.')

func test_only_a_hostile_character_can_be_chosen():
	var specific := SpecificAction.create(thorn, gear, action())
	var ally := Fixture.create_ally(game, ALLY_TILE)
	var drone := Fixture.create_drone(game, Vector2i(8, 4))
	assert_true(action().can_target_unit(focus, specific), 'A hostile character: yes.')
	assert_false(action().can_target_unit(ally, specific), 'An ally: no.')
	assert_true(action().can_target_unit(drone, specific), 'A hostile drone is a character (ruling 2026-09-27): yes.')

func test_a_second_hyperfocus_is_refused_while_the_focus_lives():
	await hyperfocus(focus)
	assert_false(action().is_available_to_activate(thorn, gear), 'Locked while the focus lives.')
	await hyperfocus(other)
	assert_eq(focused_on(), focus, 'The attempt changed nothing.')
	assert_eq(gear.charges_current, 2, 'And spent nothing.')

func test_the_focus_dying_ends_it_and_frees_the_pick():
	await hyperfocus(focus)
	await game.execute_event(&'event_unit_die', {unit = focus})
	assert_false(UnitCondition.has_buff(thorn, CHIP), 'The Thorn\'s chip is gone...')
	assert_false(UnitCondition.has_buff(thorn, RANGE), '...and the waiver...')
	assert_true(action().is_available_to_activate(thorn, gear), '...and a new target may be chosen.')

# --------------------------------------------------------- the scene end (Pass F task 14, test debt)

## Pass F task 14 (open-items H): "or the scene ends" - both buffs re-derive the stored focus every
## check (buff_hyperfocus.gd's check_if_passive_applies, buff_hyperfocus_range.gd's), and the stored
## id is gear STATE (hyperfocus.gd's header), which GearCore.short_repair wipes but does not itself
## touch the buff objects. So a short repair silently ends the mechanical effect - the lock, the +1,
## the waiver - without clearing the visible chip/marker buffs the way end_focus does. Pinned here so
## a future change to either buff's applies-check can't quietly stop re-deriving the focus.
func test_a_gear_short_repair_ends_the_lock_the_bonus_and_the_waiver():
	await hyperfocus(focus)
	Fixture.step(focus, FAR_TILE)
	gear.short_repair()
	assert_null(focused_on(), 'The stored id is gear state, wiped by a short repair.')
	assert_true(action().is_available_to_activate(thorn, gear), 'A new Hyperfocus may be chosen.')
	assert_eq(flat_bonus(Fixture.MAIN_RIFLE, focus), 0, 'The +1 re-derives the focus every check; gone with the state.')
	assert_does_not_have(targetable(Fixture.MAIN_RIFLE), FAR_TILE, 'The waiver re-derives too: 20 away is out of Range 10 again.')

## The whole-unit form (UnitPrinter.short_repair, called by every equipped gear's own short_repair) -
## the actual scene-end call, not just Pinpoint Mark's own kit.
func test_a_unit_wide_short_repair_ends_it_the_same_way():
	await hyperfocus(focus)
	Fixture.step(focus, FAR_TILE)
	thorn.core.short_repair()
	assert_null(focused_on(), 'UnitPrinter.short_repair runs every equipped gear\'s short_repair, Pinpoint Mark included.')
	assert_true(action().is_available_to_activate(thorn, gear), 'A new Hyperfocus may be chosen.')
	assert_eq(flat_bonus(Fixture.MAIN_RIFLE, focus), 0, 'The +1 is gone.')
	assert_does_not_have(targetable(Fixture.MAIN_RIFLE), FAR_TILE, 'The waiver is gone.')

# ---------------------------------------------------------------- the +1

func test_attacks_on_the_focus_gain_flat_plus_one_and_others_do_not():
	var focus_before := flat_bonus(Fixture.MAIN_RIFLE, focus)
	var other_before := flat_bonus(Fixture.MAIN_RIFLE, other)
	await hyperfocus(focus)
	assert_eq(flat_bonus(Fixture.MAIN_RIFLE, focus), focus_before + 1, '+1 against the focus.')
	assert_eq(flat_bonus(Fixture.MAIN_RIFLE, other), other_before, 'Nothing against anyone else.')

# ---------------------------------------------------------------- the waiver

func test_a_focus_twenty_tiles_away_is_in_range_of_a_range_ten_rifle():
	assert_does_not_have(targetable(Fixture.MAIN_RIFLE), FOCUS_TILE, 'Control: 14 away is out of the rifle\'s Range 10.')
	await hyperfocus(focus)
	assert_has(targetable(Fixture.MAIN_RIFLE), FOCUS_TILE, 'Focused: in range.')
	Fixture.step(focus, FAR_TILE)
	assert_has(targetable(Fixture.MAIN_RIFLE), FAR_TILE, 'And still at 20: "always count as within range".')

func test_a_focus_behind_a_wall_is_not_reached_by_a_weapon_that_needs_line_of_sight():
	await hyperfocus(focus)
	build_wall_at(WALL_X)
	assert_false(UnitRelation.can_see(thorn, focus), 'fixture: the wall blocks LOS.')
	assert_does_not_have(targetable(Fixture.MAIN_RIFLE), FOCUS_TILE, 'RANGE ONLY: the rifle still needs to see it.')

func test_a_seeking_weapon_reaches_the_focus_behind_a_wall_and_beyond_its_range():
	build_wall_at(WALL_X)
	assert_does_not_have(targetable(BLINK_BOLT), FOCUS_TILE, 'Control: 14 is past the bolt\'s Range 10.')
	# Chosen through the wall by setting the focus directly: Hyperfocus itself needs sight to pick.
	Fixture.step(focus, Vector2i(10, 6))
	await hyperfocus(focus)
	Fixture.step(focus, FOCUS_TILE)
	assert_false(UnitRelation.can_see(thorn, focus), 'fixture: behind the wall.')
	assert_has(targetable(BLINK_BOLT), FOCUS_TILE, 'SEEKING needs no sight, so the waiver keeps the tile.')

func test_a_melee_weapon_gets_no_waiver():
	await hyperfocus(focus)
	Fixture.step(focus, Vector2i(7, 6))
	assert_does_not_have(targetable(MELEE), Vector2i(7, 6), 'Threat 1 at 3 tiles: a melee weapon is not a ranged weapon.')

# ---------------------------------------------------------------- the end

func test_an_attack_on_the_focus_keeps_it():
	await hyperfocus(focus)
	Fixture.step(focus, Vector2i(12, 6))
	await rifle_at(focus)
	assert_gt(focus.current_damage(), 0, 'fixture: the attack on the focus happened.')
	assert_true(is_fully_focused(), 'Attacking the focus is the point of it.')

func test_an_attack_on_another_hostile_ends_everything():
	await hyperfocus(focus)
	await rifle_at(other)
	assert_true(is_fully_ended(), 'Buffs, marker and stored id all gone.')
	assert_true(action().is_available_to_activate(thorn, gear), 'And a new Hyperfocus may be chosen (design ruling 13).')

func test_a_miss_on_another_hostile_ends_it_too():
	await hyperfocus(focus)
	Fixture.queue([1])
	await Fixture.shoot(game, thorn, other, Fixture.MAIN_RIFLE)
	assert_true(is_fully_ended(), 'An attack affects its target hit or miss.')

func test_a_blast_catching_another_hostile_ends_it():
	await hyperfocus(focus)
	Fixture.step(other, BESIDE_FOCUS)
	Fixture.queue([D20_HITS, D20_HITS, 2])
	await Fixture.shoot(game, thorn, focus, MISSILE_RACK)
	assert_true(is_fully_ended(), 'The Blast was aimed at the focus but caught another hostile.')

func test_an_invade_on_another_hostile_ends_it():
	await hyperfocus(focus)
	Fixture.queue([D20_HITS])
	await Fixture.shoot(game, thorn, other, FRAGMENT_SIGNAL)
	assert_true(is_fully_ended(), 'A tech attack is an attack.')

func test_an_attack_on_an_ally_does_not_end_it():
	var ally := Fixture.create_ally(game, ALLY_TILE)
	await hyperfocus(focus)
	# The friendly-fire confirm is a yes/no (TargetActionUtil.confirm_friendly_fire), and this file
	# declines yes/nos by default - which silently cancels the attack. Accept that one.
	responder.yesno_queue.append(true)
	await rifle_at(ally)
	assert_gt(ally.current_damage(), 0, 'fixture: the attack on the ally happened.')
	assert_true(is_fully_focused(), '"A different HOSTILE character".')

func test_a_stalk_the_horizon_shot_at_another_hostile_ends_it():
	await hyperfocus(focus)
	Fixture.queue([D20_HITS, 3, 1])
	await Fixture.standard_move(game, other, OTHER_STEP)
	assert_gt(other.current_damage(), 0, 'fixture: Stalk the Horizon fired the Nexus at the mover.')
	assert_true(is_fully_ended(), 'A reaction shot is an action that affects it.')

func test_a_lock_on_on_another_hostile_does_not_end_it_the_measured_divergence():
	await hyperfocus(focus)
	await SpecFactory.use_solo(game, thorn, LOCK_ON, other)
	assert_true(other.has_status(Lancer.STATUS.LOCKON), 'fixture: the lock landed (so the action happened).')
	assert_true(is_fully_focused(),
		'DIVERGENCE (rulings 2026-09-23, the SP3 probe): a tech SYSTEM does not end Hyperfocus.')

# ---------------------------------------------------------------- limited

func test_the_empty_kit_is_not_destructible():
	assert_true(UnitPrinter.get_destructable_gear([gear]).has(gear), 'With a charge: destructible.')
	gear.charges_current = 0
	assert_false(UnitPrinter.get_destructable_gear([gear]).has(gear), 'Empty: not (vanilla, unit_printer.gd:316-319).')
