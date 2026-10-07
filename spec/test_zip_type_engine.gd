# THE ZIP TYPE ENGINE (Leoleth rank II, SP3 Task 2) - design ruling 16, sheet 09-leoleth.md.
#
#   "UNIQUE | SP 2
#    Whenever you would move from something that is not your standard movement or Boost, you may
#    treat that movement as if it were teleportation. If you do, you gain 1 Heat."
#
# A TOGGLE (author's call): a buff cannot prompt, and the movement type must be in force when the
# PATH is priced - engagement (pathfinder.gd:434), difficult terrain (:99), reactions
# (movement_type.gd:101-102) all read it before a step is taken. So "you may" is a FREE engage
# action that hangs a visible chip, and a FREE disengage that clears it - vanilla's Retractable
# Profile shape (ms_retractable_profile/). The two actions wear DIFFERENT glyphs (the author's ask).
#
# THE CHIP is a BuffMovementType whose check_if_passive_applies refuses a context carrying
# EventUnitMove.FLAG.IS_STANDARD_MOVE - the flag MovementType.create puts in the buff context only
# for the phase controllers' standard move (movement_type.gd:35; ui/phase_ui/player_action/
# phase_ui_player_action.gd:127 builds it with create_for_standard_move, and a Boost is the SAME
# pathfinder with USE_BOOST added, target_action_util.gd:473-476). A system move
# (action_system_movement.gd:41), a reaction move and a pathfinder variant all go through
# MovementType.create(unit) with NO flag, so the chip merges `teleport = true` and the ZIP tag into
# them. A knockback never merges buffs at all (create_for_involuntary, :63-71).
#
# THE HEAT: the same chip triggers on entire_movement POST when the mover is its holder and the
# move's resource carries the tag - one movement EVENT, one heat, self-inflicted.
#
# THE HEAT ALSO GATES ON movement_type.voluntary (Fix 2, 2026-09-22; buff_zip_type_engine.gd's own
# header has the full reasoning). "A knockback never merges buffs at all", above, is true and stays
# true - create_for_involuntary is the one forced-move path that never calls get_buffs_to - but it
# is NOT the only forced-move shape: MovementType.create(unit, false) is a SEPARATE path (a HORUS
# puppet, a teleport event, mount-up) that passes is_voluntary=false yet DOES call get_buffs_to and
# DOES merge the chip in. test_a_puppeted_forced_move_costs_no_heat_while_engaged, below, is the
# measurement for that path specifically - test_a_knockback_costs_no_heat_while_engaged was never at
# risk from the bug this fixed.
#
# ENGAGEMENT IS MEASURED ON A DUMMY (departure 4): Fleet of Foot already puts ignore_engagement on
# every one of the Leoleth's voluntary moves, so on the frame itself that clause is vacuous.
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

var game:Gamemaster
var leoleth:Unit
var zip:GearCore

const LEOLETH_TILE := Vector2i(4, 4)
const TWO_EAST := LEOLETH_TILE + Vector2i(2, 0)

func before_each():
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	zip = LeolethFixture.arm_zip(leoleth)

func after_each():
	Dice.CHEAT_ROLL_QUEUE.clear()

func _engage() -> Action:
	for action:Action in zip.kit.actions:
		if action.get_id() == LeolethFixture.ZIP_ENGAGE: return action
	return null

func _disengage() -> Action:
	for action:Action in zip.kit.actions:
		if action.get_id() == LeolethFixture.ZIP_DISENGAGE: return action
	return null

## UnitAction.is_gear_available, NOT can_activate_gear: for a naturally FREE action the two agree
## anyway - Action.get_per_turn_soft_limit returns 99 once the action costs ACTION_COST_FREE or less
## (action.gd:162-164), so can_activate_gear's extra per-turn check (unit_action.gd:116) never binds
## here. is_gear_available is used because it is the engine's own availability predicate
## (unit_action.gd:162), and it runs is_available_to_activate at :156 - the gate both toggle halves
## actually carry.
func _available(action:Action) -> bool:
	return UnitAction.is_gear_available(SpecificAction.create(leoleth, zip, action))

## The movement type a SYSTEM move would build for this unit: MovementType.create(unit), no flag
## (action_system_movement.gd:41 merges exactly this).
func _system_type(unit:Unit) -> MovementType: return MovementType.create(unit)

func _held() -> bool: return LeolethFixture.has(leoleth, LeolethFixture.ZIP_CHIP)

# ---------------------------------------------------------------- the card's printed numbers

func test_the_kit_is_registered_with_the_cards_stats():
	var kit := ContentLibrary.get_kit(LeolethFixture.ZIP_ID)
	assert_not_null(kit, '%s loads.' % LeolethFixture.ZIP_ID)
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE.')
	assert_eq(kit.charges_max, 0, 'Not Limited.')
	assert_eq(kit.actions.size(), 2, 'Engage and disengage.')

func test_both_actions_are_free_and_wear_different_icons():
	var engage := _engage()
	var disengage := _disengage()
	assert_not_null(engage, 'action_zip_engage.')
	assert_not_null(disengage, 'action_zip_disengage.')
	if engage == null or disengage == null: return
	assert_true(engage is ActionSystemApplyBuff, 'Engage applies the chip.')
	assert_true(disengage is ActionSystemClearBuff, 'Disengage clears it.')
	assert_eq(engage.get_action_type(SpecificAction.create(leoleth, zip, engage)), Lancer.ACTION.FREE, 'Engage is FREE.')
	assert_eq(disengage.get_action_type(SpecificAction.create(leoleth, zip, disengage)), Lancer.ACTION.FREE, 'Disengage is FREE.')
	var on:Texture2D = engage.get_icon(zip.kit)
	var off:Texture2D = disengage.get_icon(zip.kit)
	assert_not_null(on, 'Engage has an icon (the Kit\'s).')
	assert_not_null(off, 'Disengage has an icon.')
	assert_ne(on, off, 'AND THEY DIFFER - the author\'s ask: on and off read differently at a glance.')
	assert_eq(on, zip.kit.icon_override, 'Engage inherits the Kit\'s glyph (family KIT).')

func test_the_card_text_renders_rather_than_a_raw_key():
	for key:String in [
		'gear.ms_zip_type_engine.name', 'gear.ms_zip_type_engine.flavor', 'gear.ms_zip_type_engine.effect',
		'gear.ms_zip_type_engine.action_zip_engage.name', 'gear.ms_zip_type_engine.action_zip_engage.effect',
		'gear.ms_zip_type_engine.action_zip_disengage.name', 'gear.ms_zip_type_engine.action_zip_disengage.effect',
		'gear.buff_zip_type_engine.name', 'gear.buff_zip_type_engine.effect',
	]:
		assert_ne(tr(key), key, '%s resolves.' % key)

## Nothing else asserts that the |teleportation=lancer.term.teleport| pipe actually resolves to a
## LIVE glossary term - if the key drifts to something that no longer exists,
## glossary_item.gd:229-233 still takes the explicit-tag branch and ships a dead link, with every
## other test in this file green. Confirm the three rows still carry the tag literally, and that the
## base game's own row for it (assets/localization/localizations.csv, read-only) still resolves.
func test_the_teleportation_pipes_link_to_a_live_glossary_term():
	for key:String in [
		'gear.ms_zip_type_engine.effect',
		'gear.ms_zip_type_engine.action_zip_engage.effect',
		'gear.buff_zip_type_engine.effect',
	]:
		assert_true(tr(key).contains('|teleportation=lancer.term.teleport|'), '%s carries the pipe.' % key)
	assert_ne(tr('lancer.term.teleport'), 'lancer.term.teleport', 'And the term itself resolves - a live link, not a dead one.')

# ---------------------------------------------------------------- the toggle

## UNCAPPED, BY THE AUTHOR'S OWN DECISION (Fix 3, 2026-09-22) - REVERSING THE PIN THIS TEST USED TO
## HOLD. Both halves are naturally FREE (action_type = 3), and unmodified, Action.
## get_per_round_hard_limit returns 1 whenever an action costs ACTION_COST_FREE or less
## (action.gd:156-158), which UnitAction.get_gear_unavailable_reason checks via
## is_under_per_round_limit (REASON.PER_ROUND, unit_action.gd:148, :170-175) - so the engine's
## DEFAULT caps each half to one flip per round. The card caps nothing: it grants the choice per
## MOVEMENT. This test used to PIN the capped default (a naturally FREE action is 1/round); it now
## pins the override instead - action_zip_engage.gd / action_zip_disengage.gd both override
## get_per_round_hard_limit to return 99, straight at the source rather than through a
## Buff.TO.ACTION_PER_ROUND buff (the engine's own sanctioned channel for RAISING this cap,
## unit_action.gd:173-174) - the cap should never apply to this gear at all, not merely while some
## buff is up.
##
## The counter is still cleared by UnitAction.reset_per_round_usage, which only the HOLDER's own turn
## start reaches (new_turn_refresh, unit_action.gd:78 <- event_turn_start.gd:79) - moot for the cap
## itself now, but still why the button is offered again next turn regardless.
##
## Vanilla's Retractable Profile never had this problem: both its halves are QUICK
## (action_retractable_profile_deactivate.tres: action_type = 1), so Action.get_per_round_hard_limit's
## FREE-only branch never applied to it in the first place.
func test_engaging_hangs_the_chip_and_the_two_actions_toggle_without_limit():
	assert_false(_held(), 'Off at the start.')
	await LeolethFixture.open_turn(game, leoleth)
	assert_true(_available(_engage()), 'Engage is offered while off.')
	assert_false(_available(_disengage()), 'Disengage is not.')
	await LeolethFixture.engage_zip(game, leoleth)
	assert_true(_held(), 'The chip landed.')
	assert_false(_available(_engage()), 'Engage is withdrawn while on.')
	assert_true(_available(_disengage()), 'Disengage is offered.')
	await LeolethFixture.disengage_zip(game, leoleth)
	assert_false(_held(), 'Cleared.')
	# THE PIN, REVERSED: before Fix 3 this next line was `assert_false` - "not again THIS round: a
	# naturally FREE action is 1/round." That was the engine's unmodified default outrunning the
	# card, which grants the choice per movement and caps nothing.
	assert_true(_available(_engage()), 'Offered again in THE SAME round - Fix 3 lifts the cap.')
	await LeolethFixture.engage_zip(game, leoleth)
	assert_true(_held(), 'And re-engaging really works a second time this round.')
	assert_true(_available(_disengage()), 'Disengage is offered again too.')
	await LeolethFixture.disengage_zip(game, leoleth)
	assert_false(_held(), 'And disengaging a second time this round works as well.')
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)
	assert_true(_available(_engage()), 'Next turn it is offered too, uncapped or not.')
	assert_false(_available(_disengage()), 'And disengage is withdrawn again, with no chip to clear.')

func test_the_chip_is_visible_and_survives_turns():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.ZIP_CHIP)
	assert_not_null(buff, 'The chip loads.')
	if buff == null: return
	assert_false(buff.hide_from_player, 'Visible: the only on-map signal that the engine is on.')
	assert_eq(buff.until, Lancer.UNTIL.MANUAL, 'Until disengaged.')
	assert_not_null(buff.icon, 'It has an icon.')
	assert_eq(buff.icon, zip.kit.icon_override, 'The engaged glyph - the same family as the Kit and engage.')
	await LeolethFixture.engage_zip(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)
	assert_true(_held(), 'Still on next turn.')

func test_the_chip_carries_the_engaged_fx_ticket():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.ZIP_CHIP)
	assert_not_null(buff, 'fixture: the chip loads.')
	if buff == null: return
	var scene:PackedScene = load(LeolethFixture.ZIP_FXE_PATH)
	assert_not_null(scene, 'fxe_zip_engaged.tscn loads.')
	assert_eq(buff.get_fxe_id(), &'fxe_zip_engaged', 'The chip names the scene.')
	assert_false(ContentLibrary.get_fxendless_path(&'fxe_zip_engaged').is_empty(),
		'And ContentLibrary indexed it (an fxe_ .tscn under res/content/, content_library.gd:319-321).')
	await LeolethFixture.engage_zip(game, leoleth)
	var core:BuffCore = UnitCondition.get_buff(leoleth, LeolethFixture.ZIP_CHIP)
	var tickets := buff.get_attached_fx(core, leoleth)
	assert_eq(tickets.size(), 1, 'One ticket on the token.')

# ---------------------------------------------------------------- what the chip does to a move

func test_engaged_a_system_move_is_a_teleport_tagged_zip():
	assert_false(_system_type(leoleth).teleport, 'Off: a system move walks.')
	await LeolethFixture.engage_zip(game, leoleth)
	var type := _system_type(leoleth)
	assert_true(type.teleport, 'On: a system move is a teleport.')
	assert_true(type.other_tags.has(LeolethFixture.ZIP_TAG), 'And it carries the ZIP tag.')

func test_engaged_a_standard_move_is_unchanged():
	await LeolethFixture.engage_zip(game, leoleth)
	var standard := MovementType.create_for_standard_move(leoleth)
	assert_false(standard.teleport, '"not your standard movement": IS_STANDARD_MOVE refuses the chip.')
	assert_false(standard.other_tags.has(LeolethFixture.ZIP_TAG), 'No tag.')

func test_engaged_a_knockback_is_unchanged():
	await LeolethFixture.engage_zip(game, leoleth)
	var shove := MovementType.create_for_involuntary(leoleth)
	assert_false(shove.teleport, 'create_for_involuntary merges no buffs.')
	assert_false(shove.other_tags.has(LeolethFixture.ZIP_TAG), 'No tag.')

func test_engaged_difficult_terrain_costs_nothing_extra_on_a_system_move():
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_tree_acacia', [LEOLETH_TILE + Vector2i(1, 0)])
	UnitTile.move_to(leoleth, LEOLETH_TILE)
	var before := await Pathfinder.generate_for_movement_budget(leoleth, 8, _system_type(leoleth))
	assert_eq(before.get_path_cost(before.path_to(LEOLETH_TILE + Vector2i(1, 0))), 2, 'Baseline: 1 + 1 for the forest.')
	await LeolethFixture.engage_zip(game, leoleth)
	var after := await Pathfinder.generate_for_movement_budget(leoleth, 8, _system_type(leoleth))
	assert_eq(after.get_path_cost(after.path_to(LEOLETH_TILE + Vector2i(1, 0))), 1, 'Teleport: teleport_cost is max(dz, distance) (pathfinder.gd:800-801).')

## THE ENGAGED MOVE RUNS FIRST AND THE CONTROL SECOND, and that ordering is the test.
##
## Control-first is what the plan drafted, and it PASSES FOR THE BORING REASON - measured on the
## first RED run of this file, where this was the one test that went green with no content on disk
## at all. Overwatch is capped 1/ROUND, and a round cap is cleared by UnitAction.new_turn_refresh ->
## reset_per_round_usage (unit_action.gd:78), which event_turn_start calls ONLY for the unit whose
## turn is starting (event_turn_start.gd:79). The all-units loop three lines earlier (:43-44) is
## every_new_turn_refresh, which hands back the reaction POINT and resets the per-TURN counters and
## nothing else. So a watcher that has already overwatched once cannot overwatch again this round,
## whoever starts a turn - and "the second move drew no reaction" says nothing about teleportation.
##
## Engaged-first is self-verifying instead. If the chip does its job the teleport draws nothing, the
## watcher's single overwatch is still in hand, and the walk that follows spends it - so BOTH
## assertions can only pass together. If the chip does nothing, the teleport is overwatched and the
## zero-damage assertion fails immediately.
func test_engaged_a_system_move_skips_overwatch():
	# Vanilla test_ms_overwatch.gd geometry: the watcher adjacent, the mover leaves. Spec units carry
	# ms_overwatch from the basic loadout; the watcher needs only a weapon.
	var watcher:Unit = LeolethFixture.create_hostile(game, LEOLETH_TILE + Vector2i(-1, 0))
	watcher.core.equip_system(&'mw_heavy_melee_weapon')
	SpecFactory.apply_passive_buffs(watcher)
	# THE DAMAGE DICE ARE 1s, AND THAT IS THE LEOLETH'S 8 HP: mw_heavy_melee_weapon is 2d6+1, so a
	# cheated pair of sixes is 13 - 1 armor = 12, which kills the frame outright. Ones give 3 - 1 = 2,
	# comfortably above the zero this asserts and well short of the 8 that would end the test.
	await LeolethFixture.engage_zip(game, leoleth)
	LeolethFixture.queue([19, 1, 1])
	await SpecFactory.move(game, leoleth, TWO_EAST, _system_type(leoleth))
	assert_eq(leoleth.tile(), TWO_EAST, 'It arrived.')
	assert_eq(leoleth.current_damage(), 0, 'Engaged: a teleport ignores reactions (movement_type.gd:101-102).')
	# CONTROL: the same move, walking. It proves the geometry really is overwatchable AND that the
	# watcher's one per-round overwatch was still unspent when the teleport went past it.
	await LeolethFixture.disengage_zip(game, leoleth)
	UnitTile.move_to(leoleth, LEOLETH_TILE)
	LeolethFixture.queue([19, 1, 1])
	await SpecFactory.move(game, leoleth, TWO_EAST, _system_type(leoleth))
	assert_gt(leoleth.current_damage(), 0, 'CONTROL: walking, the watcher catches it.')

func test_engaged_a_chip_holder_walks_out_of_an_engagement():
	# On a DUMMY, because Fleet of Foot makes this vacuous on the Leoleth (departure 4).
	var mover:Unit = LeolethFixture.create_ally(game, Vector2i(10, 4))
	var enemy:Unit = LeolethFixture.create_hostile(game, Vector2i(11, 4))
	assert_true(Unit.is_valid(enemy), 'fixture: the engaging hostile exists.')
	UnitTile.update_tracking_and_statuses(game.map)
	assert_true(UnitCondition.is_engaged(mover), 'fixture: engaged.')
	var walking := _system_type(mover)
	assert_false(walking.ignores_engagement(), 'CONTROL: a plain dummy\'s system move honours engagement.')
	SpecFactory.apply_buff(mover, LeolethFixture.ZIP_CHIP, zip)
	var zipping := _system_type(mover)
	assert_true(zipping.teleport and zipping.ignores_engagement(), 'With the chip: a teleport, engagement ignored.')

# ---------------------------------------------------------------- the heat

func test_a_zip_move_costs_exactly_one_heat():
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, TWO_EAST, _system_type(leoleth))
	assert_eq(leoleth.tile(), TWO_EAST, 'It moved two tiles in one event.')
	assert_eq(leoleth.core.current.heat, heat + 1, '"If you do, you gain 1 Heat" - per movement EVENT, not per space.')

func test_a_standard_move_costs_no_heat_while_engaged():
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	await LeolethFixture.walk(game, leoleth, LEOLETH_TILE + Vector2i(1, 0))
	assert_eq(leoleth.core.current.heat, heat, 'Standard movement is exempt.')

func test_a_boosted_move_costs_no_heat_while_engaged():
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, LEOLETH_TILE + Vector2i(1, 0),
		MovementType.create_for_standard_move(leoleth), [EventUnitMove.FLAG.USE_BOOST])
	assert_eq(leoleth.core.current.heat, heat, 'A Boost is the standard pathfinder with USE_BOOST added - exempt.')

func test_a_knockback_costs_no_heat_while_engaged():
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, TWO_EAST, MovementType.create_for_involuntary(leoleth))
	assert_eq(leoleth.core.current.heat, heat, 'Involuntary: no buffs merged, no tag, no heat.')

## FIX 2 (2026-09-22): a knockback is NOT the only shape a forced move takes, and it is the ONE
## path never at risk - create_for_involuntary never calls get_buffs_to at all (movement_type.gd:
## 63-71), so the test above proves nothing about a forced move that DOES merge buffs. Three vanilla
## producers build a "counts as involuntary!!" forced move via MovementType.create(unit, false)
## instead (movement_type.gd:34-51 - is_voluntary=false, but the get_buffs_to call and the merge
## loop both still run): action_puppet_system.gd:8 (a HORUS puppet), event_unit_teleport.gd:26, and
## mt_mount_up/action_mount_up.gd:56. That path DOES merge this chip's teleport/other_tags in, so
## before Fix 2 the resulting move both looked like a ZIP teleport AND charged 1 Heat for a move the
## Leoleth never chose.
func test_a_puppeted_forced_move_costs_no_heat_while_engaged():
	await LeolethFixture.engage_zip(game, leoleth)
	var forced := MovementType.create(leoleth, false)
	assert_true(forced.teleport,
		'fixture: unlike create_for_involuntary, this path DOES merge the chip in.')
	assert_true(forced.other_tags.has(LeolethFixture.ZIP_TAG), 'fixture: and it carries the ZIP tag.')
	assert_false(forced.voluntary, 'fixture: and it is still recorded as involuntary.')
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, TWO_EAST, forced)
	assert_eq(leoleth.core.current.heat, heat,
		'Fix 2: triggers_on_event (buff_zip_type_engine.gd) now gates on movement_type.voluntary, '
		+ 'so a tagged but INVOLUNTARY move still charges no Heat.')

func test_disengaged_a_system_move_walks_and_costs_nothing():
	await LeolethFixture.engage_zip(game, leoleth)
	await LeolethFixture.disengage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	var type := _system_type(leoleth)
	assert_false(type.teleport, 'Off again: it walks.')
	await SpecFactory.move(game, leoleth, TWO_EAST, type)
	assert_eq(leoleth.core.current.heat, heat, 'And costs nothing.')

func test_the_heat_is_the_holders_alone():
	# Another unit's tagged move must not heat the Leoleth: the trigger checks the mover is the holder.
	await LeolethFixture.engage_zip(game, leoleth)
	var other:Unit = LeolethFixture.create_ally(game, Vector2i(10, 4))
	SpecFactory.apply_buff(other, LeolethFixture.ZIP_CHIP, zip)
	var heat := leoleth.core.current.heat
	var other_heat := other.core.current.heat
	await SpecFactory.move(game, other, Vector2i(12, 4), _system_type(other))
	assert_eq(other.core.current.heat, other_heat + 1, 'The other holder paid.')
	assert_eq(leoleth.core.current.heat, heat, 'The Leoleth did not.')

## TAKE-OFF AND LANDING ARE NOT MOVES (fix 2026-10-07). entire_movement POST does NOT fire once per
## event_unit_move: UnitCondition queues an EXTRA one on whatever event flips FLYING, on apply
## (unit_condition.gd:175-177) and on clear (:226-228) - "if we landed or whatever, it also counts as
## having moved". A flying move by a grounded unit gets FLYING applied at event_unit_move.gd:96-98 and
## cleared at :120, so its ONE event fires THREE POSTs, and the chip charged 3 Heat.
func test_a_flying_zip_move_charges_once_not_for_takeoff_and_landing():
	await LeolethFixture.engage_zip(game, leoleth)
	var type := _system_type(leoleth)
	type.flying = true
	assert_false(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: it starts grounded, so the move takes off.')
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, TWO_EAST, type)
	assert_eq(leoleth.tile(), TWO_EAST, 'It moved.')
	assert_false(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: and landed at the end of the move.')
	assert_eq(leoleth.core.current.heat, heat + 1, 'One move, one Heat - take-off and landing add nothing.')

## TAKE-OFF AND LANDING AS ACTIONS (2026-10-07 survey). Vanilla's Takeoff (granted by the GMS Type-I
## Flight System, which a Leoleth can take) and Land (every player mech's basic loadout) move no one:
## they flip FLYING on their OWN activation event, after dressing that event with
## MovementType.create(unit) to impersonate a move (action_takeoff.gd:50-52, action_land.gd:39-41).
## That type merges the chip's tag, and the flip queues an entire_movement POST on that event - so
## before the fix each press cost 1 Heat. Heat is read straight after the press: the Type-I's own
## Size+1 Heat lands at END of turn, so it cannot leak into these numbers.
const FLIGHT_KIT := &'ms_type_i_flight_system'
const TAKEOFF := &'action_takeoff'
const LAND_KIT := &'ms_land'
const LAND := &'action_land'

func _take_off() -> void:
	LeolethFixture.equip(leoleth, FLIGHT_KIT)
	await LeolethFixture.engage_zip(game, leoleth)
	await SpecFactory.use(game, leoleth, FLIGHT_KIT, TAKEOFF)

func test_taking_off_costs_no_zip_heat():
	LeolethFixture.equip(leoleth, FLIGHT_KIT)
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, FLIGHT_KIT, TAKEOFF)
	assert_true(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: the Takeoff took.')
	assert_eq(leoleth.core.current.heat, heat, 'Taking off is not a move - no ZIP Heat.')

func test_landing_costs_no_zip_heat():
	await _take_off()
	assert_true(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: airborne before landing.')
	var heat := leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, LAND_KIT, LAND)
	assert_false(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: the Land took.')
	assert_eq(leoleth.core.current.heat, heat, 'Landing is not a move - no ZIP Heat.')

## CONTROL for the fix: a ZIP move made while ALREADY flying flips nothing, and must still pay its 1.
func test_a_zip_move_while_already_flying_still_costs_one_heat():
	await _take_off()
	var heat := leoleth.core.current.heat
	await SpecFactory.move(game, leoleth, TWO_EAST, _system_type(leoleth))
	assert_eq(leoleth.tile(), TWO_EAST, 'It moved.')
	assert_true(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: and is still airborne - no flip.')
	assert_eq(leoleth.core.current.heat, heat + 1, 'The ZIP move itself still costs its 1 Heat.')

# ---------------------------------------------------------------- the real archetype, end to end

## A knockoff ActionSystemMovement on a runtime Kit, driven through the stock responder's
## chosen_move_tile (spec_factory.gd:379, :417-424), so one test runs the production code path:
## activate -> get_movement_type (merges MovementType.create) -> pathfinder -> event.
##
## original_id IS LOAD-BEARING, and it is the only way a `.new()` action can be named: Action.get_id
## derives the id from the resource PATH (action.gd:90-92) and a runtime instance has none, so
## without this GearCore.get_action (gear_core.gd:332-335) matches nothing and SpecFactory.use fires
## a null action.
const KNOCKOFF_KIT := &'reag_knockoff_dash_kit'
const KNOCKOFF_DASH := &'reag_knockoff_dash'

class KnockoffDash extends ActionSystemMovement:
	func _init() -> void:
		original_id = &'reag_knockoff_dash'
		movement_type = MovementType.new()
		movement_type.voluntary = true
		movement_range_fixed = 4
		action_type = Lancer.ACTION.FREE
		usage_group = &'reag_knockoff_dash'

func test_a_real_system_movement_action_teleports_and_heats():
	var kit := Kit.new()
	kit.compcon_id = KNOCKOFF_KIT
	kit.actions.append(KnockoffDash.new())
	leoleth.core.loadout.equipped_kits.append(kit)
	leoleth.core.full_repair()
	SpecFactory.apply_passive_buffs(leoleth)
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	SpecFactory.current_responder.chosen_move_tile = TWO_EAST
	await SpecFactory.use(game, leoleth, KNOCKOFF_KIT, KNOCKOFF_DASH)
	SpecFactory.current_responder.chosen_move_tile = Tile.INVALID
	assert_eq(leoleth.tile(), TWO_EAST, 'The dash landed where the responder chose.')
	assert_eq(leoleth.core.current.heat, heat + 1, 'THE SEAM END TO END: one heat for the tagged teleport.')

## The case that found it (2026-10-07): a Rapid Burst Jump Jet boost, measured at 3 Heat. RBJJ applies
## FLYING itself, on its OWN activation event, after overwriting that event's context.resource with the
## tagged movement type to impersonate a move (action_rapid_burst_jump_jet_system.gd) - so the
## take-off POST lands on a NON-move event that still reads as a ZIP teleport. The landing POST and the
## move's own POST both land on the move event.
##
## 1 IS NOT THE CARD'S NUMBER. RBJJ is a Boost ("Your mech can Boost to fly") and the card exempts a
## Boost, so by the card it should cost 0 and not teleport at all - but the chip cannot see which action
## built the move (its buff context carries only the unit and flags), and the author kept that out of
## scope on 2026-10-07. If the Boost exemption is ever fixed, this assertion becomes heat + 0.
const RBJJ_KIT := &'ms_rapid_burst_jump_jet_system'
const RBJJ_ACTION := &'action_rapid_burst_jump_jet_system'

func test_a_jump_jet_boost_charges_once_not_for_takeoff_and_landing():
	LeolethFixture.equip(leoleth, RBJJ_KIT)
	await LeolethFixture.engage_zip(game, leoleth)
	var heat := leoleth.core.current.heat
	SpecFactory.current_responder.chosen_move_tile = TWO_EAST
	await SpecFactory.use(game, leoleth, RBJJ_KIT, RBJJ_ACTION)
	SpecFactory.current_responder.chosen_move_tile = Tile.INVALID
	assert_eq(leoleth.tile(), TWO_EAST, 'The jump landed where the responder chose.')
	assert_false(leoleth.has_status(Lancer.STATUS.FLYING), 'fixture: and came down again.')
	assert_eq(leoleth.core.current.heat, heat + 1, 'One jump, one Heat - take-off and landing add nothing.')

# ---------------------------------------------------------------- compat: the Trueblack Aegis (Pass F Task 15)

## Ruling 2026-09-27 "ZIP disengage and a forced deactivate": a Napoleon's Trueblack Aegis
## (content/frames/ha/mf_napoleon/cp_trueblack_aegis/, base game, read-only) switches ZIP off.
## Equipped here for the seam only - the Leoleth is not a Napoleon, but nothing in
## action_activate_aegis.gd cares who is holding the core power.
##
## CORRECTED 2026-09-28 (review fix #1): the paragraph this replaced claimed the blanket clear at
## action_activate_aegis.gd:44-50 was what dropped the chip "metatag or not", and called the
## metatag-only restriction test "no metatag involved". Both were wrong about WHICH loop actually
## runs. action_activate_aegis.gd:13-29 runs FIRST, not the blanket clear: it collects every gear
## whose buff is_buff_prohibited (:55-79, true for the ZIP chip - see below) into
## discovered_activated_gear, then for each of ITS actions carrying METATAG.deactivate, fires a REAL
## event_gear_activate(AS_FREEBIE) (:22-28). Before this task, action_zip_disengage.tres carried no
## such metatag, so that loop skipped it and the LATER blanket clear (:44-50) was genuinely what
## dropped the chip, silently. Now that the metatag exists, the FIRST loop finds it and fires the
## real disengage action - the blanket clear at :44-50 never gets a chance to run against the zip
## chip at all, because it is already gone. is_buff_prohibited itself is unchanged by any of this:
## the zip system is not a shield, its chip is not applied by a PassiveBuffApplicator/PassiveWeaponMod,
## UnitAction.is_tech(zip) is false and the zip kit is not a trait, so the "anything else" branch at
## :77 fires either way - which is why _held() still reads false either way, but THROUGH A DIFFERENT
## MECHANISM now.
##
## CORRECTED 2026-09-28 (review fix #2, author ruling "match vanilla"): fix #1 measured that firing
## disengage via the :13-29 loop raised an EXTRA yes/no prompt beyond the Aegis' own (2 total against
## a 1-prompt baseline), because action_zip_disengage.gd extends ActionSystemClearBuff, whose
## activate() (action_system_clear_buff.gd:70-71) unconditionally awaits
## CommonActionUtil.confirm_use - and AS_FREEBIE alone does not suppress that (confirm_use_alt only
## skips for Action.FLAG.SKIP_PLAYER_DECISIONS, common_action_util.gd:330, which the Aegis loop never
## passes). The author ruled: match vanilla - no prompt when the Aegis forces it, keep the prompt
## when the player presses disengage themselves. Fixed in action_zip_disengage.gd's own activate()
## override: when context.flags carries AS_FREEBIE (the Aegis loop's own marker, :27 -
## `flags = [Action.FLAG.AS_FREEBIE]` - and the discriminator a player's own press never carries;
## engine convention pairs AS_FREEBIE with SKIP_PLAYER_DECISIONS for a fully-silent forced action,
## e.g. action_reaction_break_connection.gd:75, and the Aegis loop simply omits the second flag) it
## adds SKIP_PLAYER_DECISIONS itself before delegating to super.activate(), so
## ActionSystemClearBuff's confirm_use is skipped for exactly the forced case and untouched otherwise.
## Measured side by side, same fixture, same Aegis, isolating the Aegis' OWN one confirm as the
## baseline:
##   Aegis alone (nothing engaged):                1 yesno prompt, actions -1, heat +0.
##   Aegis + ZIP engaged (THIS TEST):               1 yesno prompt (+0), actions -1 (+0), heat +0.
##   Aegis + siege stabilizers engaged (VANILLA):   1 yesno prompt (+0), actions -1 (+0), heat +0.
## ZIP now matches vanilla exactly. The player's own disengage press (no AS_FREEBIE) is pinned
## separately below to confirm it still confirms.
const AEGIS_ID := &'cp_trueblack_aegis'
const AEGIS_ACTION_ID := &'action_activate_aegis'
const AEGIS_RESTRICTION_BUFF := &'buff_trueblack_aegis_restrictions'

func test_a_trueblack_aegis_fires_the_tagged_disengage_with_no_extra_confirm_prompt():
	LeolethFixture.equip(leoleth, AEGIS_ID)
	await LeolethFixture.open_turn(game, leoleth)
	await LeolethFixture.engage_zip(game, leoleth)
	assert_true(_held(), 'fixture: engaged before the Aegis fires.')
	var watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	var actions_before:int = leoleth.state.actions
	var heat_before:int = leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, AEGIS_ID, AEGIS_ACTION_ID)
	assert_false(_held(), 'The chip is still cleared either way - now through the tagged disengage action.')
	assert_eq(watcher.kinds(&'yesno').size(), 1,
		'THE FIX (author ruling "match vanilla"): ZERO extra confirm prompts beyond the Aegis\' own '
		+ 'measured baseline of 1 - equal to the Siege Stabilizers reference below.')
	assert_eq(leoleth.state.actions, actions_before - 1,
		'No extra ACTION cost beyond the Aegis\' own (AS_FREEBIE) - unchanged by this fix.')
	assert_eq(leoleth.core.current.heat, heat_before, 'And no extra heat either.')

## THE OTHER HALF OF THE RULING: the player's OWN disengage (no AS_FREEBIE in context.flags) must
## still raise its confirm - the fix in action_zip_disengage.gd's activate() only adds
## SKIP_PLAYER_DECISIONS when AS_FREEBIE is present, so a normal press is untouched.
func test_the_players_own_disengage_still_confirms():
	await LeolethFixture.open_turn(game, leoleth)
	await LeolethFixture.engage_zip(game, leoleth)
	assert_true(_held(), 'fixture: engaged.')
	var watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	await LeolethFixture.disengage_zip(game, leoleth)
	assert_false(_held(), 'Cleared.')
	assert_eq(watcher.kinds(&'yesno').size(), 1,
		'The player\'s own disengage still raises its own confirm prompt - only the FORCED case '
		+ '(AS_FREEBIE) skips it.')

## THE REFERENCE, side by side with the test above. ms_siege_stabilizers is base-game content
## (content/gear/ha/systems/ms_siege_stabilizers/, read-only), equipped here purely to measure the
## seam vanilla itself already exercises - the Leoleth is not licensed for it either.
func test_a_vanilla_deactivate_tagged_action_fires_with_no_extra_prompt_or_cost():
	var stab:GearCore = LeolethFixture.equip(leoleth, &'ms_siege_stabilizers')
	LeolethFixture.equip(leoleth, AEGIS_ID)
	await LeolethFixture.open_turn(game, leoleth)
	await SpecFactory.use(game, leoleth, &'ms_siege_stabilizers', &'action_siege_stabilizers')
	assert_true(UnitCondition.has_buff(leoleth, &'buff_siege_stabilizers', stab.persistent_id),
		'fixture: engaged before the Aegis fires.')
	var watcher = add_child_autoqfree(load('res://testkit/prompt_watcher.gd').new())
	var actions_before:int = leoleth.state.actions
	var heat_before:int = leoleth.core.current.heat
	await SpecFactory.use(game, leoleth, AEGIS_ID, AEGIS_ACTION_ID)
	assert_false(UnitCondition.has_buff(leoleth, &'buff_siege_stabilizers', stab.persistent_id),
		'Cleared, the same as ZIP.')
	assert_eq(watcher.kinds(&'yesno').size(), 1,
		'THE REFERENCE: vanilla\'s own deactivate-tagged action (plain ActionSystem, no confirm_use '
		+ 'call in its activate()) raises ONLY the Aegis\' own prompt - none of its own.')
	assert_eq(leoleth.state.actions, actions_before - 1, 'Same action cost as the Aegis alone.')
	assert_eq(leoleth.core.current.heat, heat_before, 'No heat.')

## THE FIX, RED before action_zip_disengage.tres gains metatags = [deactivate]: the restriction buff
## forbids disengage while it is up, because neither of its two exemptions (id contains 'deactivate',
## or the metatag) match today.
func test_the_disengage_metatag_exempts_it_from_the_aegis_restriction():
	assert_true(_disengage().metatags.has(Action.METATAG.deactivate),
		'THE FIX: disengage carries the deactivate metatag, the sanctioned channel '
		+ '(action.gd METATAG comment: "napoleon CP activates this").')
	SpecFactory.apply_buff(leoleth, AEGIS_RESTRICTION_BUFF, zip)
	var buff_context:Context = SpecificAction.create(leoleth, zip, _disengage()).to_context()
	assert_false(UnitCondition.has_buff_to(leoleth, Buff.TO.ACTION_FORBIDDEN, buff_context),
		'And the restriction no longer forbids it - check_if_passive_applies\' metatag exemption '
		+ '(buff_trueblack_aegis_restrictions.gd:19) now matches.')

# ---------------------------------------------------------------- the licence

func test_the_licence_grants_the_zip_at_rank_two():
	var tree = ContentLibrary.get_license_tree(LeolethFixture.LICENSE_ID)
	assert_not_null(tree, 'The licence loads.')
	if tree == null: return
	var rank_2:Array = tree.rank_2.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_eq(rank_2, [LeolethFixture.TDA_ID, LeolethFixture.ZIP_ID] as Array, 'Rank 2: the axe, then the ZIP, sheet order.')
