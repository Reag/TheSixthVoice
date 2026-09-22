# W.I.N.G (Leoleth rank I, SP2 Task 2) - design ruling 20, sheet 09-leoleth.md.
#
#   "System | SP 2 | UNIQUE, LIMITED 2
#    Enhanced Movement Suite (Protocol): You may spend a charge to clear the Prone, Slowed, and
#    Immobilized conditions if they weren't self inflicted. For the rest of the turn, you ignore
#    difficult terrain and may move over cover regardless of its size."
#
# A PROTOCOL NEEDS A TURN. unit_action.gd:144 refuses one unless unit.state.is_using_protocols, which
# only event_turn_start opens (event_turn_start.gd:82) - so every activation here goes through
# LeolethFixture.press_wing, which opens the turn first. Without it the failure you SEE is "no charge
# was spent, no chip appeared", which reads as broken content rather than a spec setup gap; the red
# "[ Gear not available ] reason : protocol" line in the log is the real tell (CLAUDE.md).
#
# "NOT SELF INFLICTED" IS THE ENGINE'S OWN TEST, not ours: UnitCondition.ability_can_clear
# (unit_condition.gd:472-477) refuses a status whose source gear is in the unit's own loadout, and
# refuses the underwater Slowed outright. clear_status_via_ability passes its can_clear_self_applied
# argument NOWHERE (:482), so the default false is always what runs - which is exactly the card.
#
# "MOVE OVER COVER REGARDLESS OF ITS SIZE" IS READ AS free_climb, A RECORDED DIVERGENCE (ruling 20):
# free_climb is the only movement flag that touches climbing at all (pathfinder.gd:774, where it
# halves the climb multiplier from 2 to 1) and the engine has no notion of "cover you may not climb".
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

var game:Gamemaster
var leoleth:Unit

const LEOLETH_TILE := Vector2i(4, 4)

func before_each():
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	LeolethFixture.arm_wing(leoleth)

func after_each():
	Dice.CHEAT_ROLL_QUEUE.clear()

func _gear() -> GearCore: return leoleth.get_gear(LeolethFixture.WING_ID)

## The Leoleth's own movement type as the pathfinder would build it for a standard move - which is
## where every MOVEMENT_TYPE buff on the unit is merged in (movement_type.gd:31-57).
func _movement() -> MovementType:
	return MovementType.create_for_standard_move(leoleth)

# ---------------------------------------------------------------- the card's printed numbers

func test_the_kit_is_registered_with_the_cards_stats():
	var kit := ContentLibrary.get_kit(LeolethFixture.WING_ID)
	assert_not_null(kit, '%s loads through ContentLibrary.' % LeolethFixture.WING_ID)
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 2, 'LIMITED 2.')
	assert_eq(kit.system_tags, 1, 'UNIQUE (Lancer.SYSTEM_TAG bit 0).')
	assert_eq(kit.actions.size(), 1, 'One action: the protocol.')

func test_the_action_is_a_protocol_that_spends_a_charge():
	var kit := ContentLibrary.get_kit(LeolethFixture.WING_ID)
	assert_not_null(kit, 'fixture: the kit loads.')
	if kit == null: return
	var action:Action = kit.actions[0]
	assert_eq(action.get_id(), LeolethFixture.WING_ACTION, 'Named action_enhanced_movement_suite.')
	assert_eq(action.get_action_type(SpecificAction.create(leoleth, _gear(), action)),
		Lancer.ACTION.PROTOCOL, 'A Protocol (Lancer.ACTION 4).')
	assert_true(action.consumes_charges(SpecificAction.create(leoleth, _gear(), action)),
		'It spends a charge - the Action default (action.gd:107), left unset in the .tres.')

func test_the_card_text_renders_rather_than_a_raw_key():
	assert_eq(X.tr('gear.ms_wing.name'), 'W.I.N.G', 'The Kit names itself.')
	assert_eq(X.tr('gear.ms_wing.action_enhanced_movement_suite.name'), 'Enhanced Movement Suite',
		'The action names itself - a system action needs its OWN name row (SP1 carry-forward 1).')
	assert_string_contains(
		X.tr('gear.ms_wing.action_enhanced_movement_suite.effect'), 'self inflicted',
		'The effect row is the card.')
	assert_string_contains(X.tr('gear.buff_wing.effect'), 'difficult terrain',
		'The chip carries its own effect row.')

# ---------------------------------------------------------------- the chip

func test_pressing_it_hangs_the_chip_and_spends_a_charge():
	assert_eq(_gear().charges_current, 2, 'Two charges to start.')
	await LeolethFixture.press_wing(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP), 'The chip is up.')
	assert_eq(_gear().charges_current, 1, 'One charge spent.')

func test_a_second_press_in_the_same_round_is_refused():
	# CORRECTED (review fix pass, 2026-09-22). The prior comment and assertion blamed can_reapply /
	# is_available_to_activate (action_system_apply_buff.gd:36) for this refusal - FALSE, and the
	# task's own mutation 5 proved it: removing can_reapply = false from the .tres left this test
	# green. The real chain, traced against live 1.4.3 source:
	#   - Lancer.ACTION_COST[Lancer.ACTION.PROTOCOL] is 0, i.e. ACTION_COST_FREE (lancer.gd:27-39).
	#   - Action.get_per_round_hard_limit therefore returns 1 for this action (action.gd:156-158):
	#     a free-cost action is naturally 1/round.
	#   - UnitAction.is_under_per_round_limit (unit_action.gd:170-175) fails on the second press in
	#     the same round.
	#   - UnitAction.get_gear_unavailable_reason returns REASON.PER_ROUND at unit_action.gd:148, an
	#     elif branch that runs BEFORE the is_available_to_activate check at :156 - so can_reapply is
	#     never even consulted on this path.
	#
	# can_reapply = false STAYS on the .tres (AUTHOR RULING, 2026-09-22) as a SECOND lock, but it
	# guards a different door: it only bites if something raises the round cap via a
	# Buff.TO.ACTION_PER_ROUND buff (unit_action.gd:173-174). Nothing in this mod grants one, so NO
	# TEST HERE PINS can_reapply - the author accepted that gap knowingly. Do not mistake this test
	# for coverage of that line.
	await LeolethFixture.press_wing(game, leoleth)
	assert_eq(_gear().charges_current, 1, 'fixture: the first press spent one charge.')
	await LeolethFixture.press_wing(game, leoleth)
	assert_eq(_gear().charges_current, 1,
		'The second press in the same round spends nothing: UnitAction.is_under_per_round_limit '
		+ 'refuses it once the engine\'s natural 1/round cap on a free-cost action is used up '
		+ '(unit_action.gd:148, :170-175).')
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP),
		'And the chip the first press hung is untouched.')

func test_the_third_use_is_refused():
	await LeolethFixture.press_wing(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await LeolethFixture.press_wing(game, leoleth)
	assert_eq(_gear().charges_current, 0, 'Both charges spent.')
	await SpecFactory.end_turn(game, leoleth)
	await LeolethFixture.press_wing(game, leoleth)
	assert_eq(_gear().charges_current, 0,
		'A third press does nothing: unit_action.gd:153 refuses it with REASON.NO_CHARGES.')
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP),
		'And no chip was hung by the refused press.')

func test_the_chip_is_gone_at_the_end_of_the_turn():
	await LeolethFixture.press_wing(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP), 'Up during the turn.')
	await SpecFactory.end_turn(game, leoleth)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP),
		'"For the rest of the turn" - UNTIL 2, END_OF_THIS_TURN.')

func test_the_chip_is_visible_and_carries_only_two_flags():
	var buff := ContentLibrary.get_buff(LeolethFixture.WING_CHIP)
	assert_not_null(buff, 'The chip is a standalone buff_*.tres in the buffs index.')
	if buff == null: return
	assert_false(buff.hide_from_player,
		'Visible: it is the only signal that the suite is running this turn.')
	assert_eq(buff.until, Lancer.UNTIL.END_OF_THIS_TURN, 'UNTIL 2.')
	assert_eq(buff.to, Buff.TO.MOVEMENT_TYPE, 'A MOVEMENT_TYPE buff.')

	# TWO FLAGS AND ONLY TWO - the reasoning buff_fleet_of_foot.tres records. merge_in ORs fifteen of
	# the seventeen booleans into the mover's type (movement_type.gd:79-96), so a stray flag here
	# silently grants the frame something the card never promised.
	var movement_type:MovementType = buff.movement_type
	assert_not_null(movement_type, 'It carries a MovementType sub-resource.')
	if movement_type == null: return
	assert_true(movement_type.ignore_difficult, 'ignore_difficult.')
	assert_true(movement_type.free_climb, 'free_climb.')
	for flag:String in [
		'spend_move', 'voluntary', 'ignore_rxns', 'ignore_engagement', 'ignore_dangerous',
		'flying', 'hovering', 'teleport', 'straight_line', 'must_move_max_possible',
		'can_break_interiors', 'can_move_through_enemies', 'cannot_move_uphill', 'jump_downhill',
		'ignore_fall_damage',
	]:
		assert_false(movement_type.get(flag), '%s is NOT set.' % flag)

# ---------------------------------------------------------------- the movement half

func test_the_chip_puts_both_flags_on_a_standard_move():
	assert_false(_movement().ignores_difficult_terrain(), 'Not before pressing.')
	await LeolethFixture.press_wing(game, leoleth)
	assert_true(_movement().ignores_difficult_terrain(), 'ignore_difficult reaches the mover.')
	assert_true(_movement().free_climb, 'And so does free_climb.')

func test_difficult_terrain_costs_one():
	SpecFactory.add_setpieces_to_landscape(
		game.get_landscape_node(), &'setpiece_tree_acacia', [LEOLETH_TILE + Vector2i(1, 0)])
	UnitTile.move_to(leoleth, LEOLETH_TILE)

	var before := await Pathfinder.generate_for_movement_budget(leoleth, 8, _movement())
	assert_eq(before.get_path_cost(before.path_to(LEOLETH_TILE + Vector2i(1, 0))), 2,
		'Baseline: one step plus one for entering difficult ground.')

	await LeolethFixture.press_wing(game, leoleth)
	var after := await Pathfinder.generate_for_movement_budget(leoleth, 8, _movement())
	assert_eq(after.get_path_cost(after.path_to(LEOLETH_TILE + Vector2i(1, 0))), 1,
		'With the chip, the forest costs its step and nothing more.')

func test_a_two_level_climb_costs_two():
	SpecFactory.set_tiles_elevation(game.map, 3, [LEOLETH_TILE + Vector2i(1, 0)])
	UnitTile.move_to(leoleth, LEOLETH_TILE)

	var before := await Pathfinder.generate_for_movement_budget(leoleth, 8, _movement())
	assert_eq(before.get_path_cost(before.path_to(LEOLETH_TILE + Vector2i(1, 0))), 4,
		'Baseline: 2 levels of elevation at the climb multiplier of 2 (pathfinder.gd:774).')

	await LeolethFixture.press_wing(game, leoleth)
	var after := await Pathfinder.generate_for_movement_budget(leoleth, 8, _movement())
	assert_eq(after.get_path_cost(after.path_to(LEOLETH_TILE + Vector2i(1, 0))), 2,
		'free_climb halves the multiplier to 1: 2 levels, 2 points.')

# ---------------------------------------------------------------- the status half

func test_a_hostile_applied_prone_slow_and_immobilize_all_clear():
	# SpecFactory.apply(unit, status, until, source) is the harness's own one-liner
	# (spec_factory.gd:237-238 -> UnitCondition.apply_status). NOT the event: event_unit_apply_status
	# takes `category` and `flags`, not `status` and `until` (test/gear/test_ms_mule_harness.gd:72),
	# and nothing here needs the event's side effects.
	var forcer := LeolethFixture.create_hostile(game, Vector2i(8, 8))
	for status:StringName in [
		Lancer.STATUS.PRONE, Lancer.STATUS.SLOWED, Lancer.STATUS.IMMOBILIZED,
	]:
		SpecFactory.apply(leoleth, status, Lancer.UNTIL.MANUAL, String(forcer.core.persistent_id))
		assert_true(leoleth.has_status(status), 'fixture: %s is on.' % status)

	await LeolethFixture.press_wing(game, leoleth)
	for status:StringName in [
		Lancer.STATUS.PRONE, Lancer.STATUS.SLOWED, Lancer.STATUS.IMMOBILIZED,
	]:
		assert_false(leoleth.has_status(status), '%s was cleared.' % status)

func test_a_self_applied_prone_stays():
	# The source is a piece of the Leoleth's OWN loadout, which is the engine's whole definition of
	# "self inflicted" (ability_can_clear, unit_condition.gd:475 -> condition.is_unit_owner).
	var own_gear := _gear()
	SpecFactory.apply(leoleth, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL,
		String(own_gear.persistent_id))
	assert_true(leoleth.has_status(Lancer.STATUS.PRONE), 'fixture: Prone is on.')

	await LeolethFixture.press_wing(game, leoleth)
	assert_true(leoleth.has_status(Lancer.STATUS.PRONE),
		'"if they weren\'t self inflicted" - a status from our own gear stays.')
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.WING_CHIP),
		'And the movement half still landed: one charge buys BOTH halves (ruling 20), so a status '
		+ 'it could not clear does not make the press a waste.')

func test_the_underwater_slow_stays():
	# StatusType.SOURCE_UNDERWATER_STATUS_KEY is the literal 'underwater' (status_type.gd:26).
	SpecFactory.apply(leoleth, Lancer.STATUS.SLOWED, Lancer.UNTIL.MANUAL,
		StatusType.SOURCE_UNDERWATER_STATUS_KEY)
	assert_true(leoleth.has_status(Lancer.STATUS.SLOWED), 'fixture: Slowed is on.')

	await LeolethFixture.press_wing(game, leoleth)
	assert_true(leoleth.has_status(Lancer.STATUS.SLOWED),
		'ability_can_clear refuses the underwater Slowed by name (unit_condition.gd:476).')

func test_it_leaves_other_statuses_alone():
	var forcer := LeolethFixture.create_hostile(game, Vector2i(8, 8))
	SpecFactory.apply(leoleth, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL,
		String(forcer.core.persistent_id))
	assert_true(leoleth.has_status(Lancer.STATUS.IMPAIRED), 'fixture: Impaired is on.')

	await LeolethFixture.press_wing(game, leoleth)
	assert_true(leoleth.has_status(Lancer.STATUS.IMPAIRED),
		'The card names exactly three conditions; Impaired is not one of them.')

# ---------------------------------------------------------------- the licence

func test_the_licence_grants_wing_at_rank_one():
	var tree := ContentLibrary.get_license_tree(LeolethFixture.LICENSE_ID)
	assert_not_null(tree, 'fixture: the licence loads.')
	if tree == null or tree.rank_1 == null: return
	var ids:Array = tree.rank_1.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_true(ids.has(LeolethFixture.WING_ID), 'Rank 1 grants W.I.N.G.')
