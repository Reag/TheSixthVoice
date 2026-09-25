# Bulwark (Grutte Pier trait, SP1). Design rulings 4-5.
#
#   "At the start of each round, until the Grutte Pier takes its turn, all allied characters within
#    Range 3 have soft cover."
#
# NOT test_bulwark.gd: the Leoleth's RAGE Bulwark already owns that file.
#
# The window: a NEW_ROUND POST reaction hangs buff_bulwark_gate (until = START_OF_TURN) on the Pier,
# and a PassiveAura gated on that buff gives each ally in range buff_bulwark_cover. The Pier's own
# turn start clears the gate, and clearing a buff whose gear holds an aura re-runs every aura
# (unit_condition.gd:987-989), so the cover lifts in the same event.
#
# Cover is read the way the engine reads it: CoverCalculator.determine_cover for the total, and
# AttackRoll.PreAttack.create for what a real roll would see (test_all_systems_red.gd's pair).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_grutte_pier_bulwark.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')

const PIER_TILE := Vector2i(5, 5)
const ALLY_AT_3 := Vector2i(8, 5)
const ALLY_AT_4 := Vector2i(9, 5)
const HOSTILE_AT_3 := Vector2i(5, 8)
const SHOOTER_TILE := Vector2i(8, 1) # 4 from the ally at 3, in the open

var game:Gamemaster
var pier:Unit
var near_ally:Unit
var far_ally:Unit
var near_hostile:Unit
var shooter:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	pier = Fixture.create_pier(game, PIER_TILE)
	near_ally = Fixture.create_dummy(game, ALLY_AT_3, 8, Faction.PLAYER)
	far_ally = Fixture.create_dummy(game, ALLY_AT_4, 8, Faction.PLAYER)
	near_hostile = Fixture.create_dummy(game, HOSTILE_AT_3)
	shooter = Fixture.create_dummy(game, SHOOTER_TILE)
	Fixture.equip(shooter, Fixture.RIFLE)
	Fixture.equip(shooter, Fixture.INVADE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func cover_of(unit:Unit) -> Lancer.COVER:
	return CoverCalculator.determine_cover(unit, shooter).total

## The cover a real roll from the shooter's `kit_id` would see against `target`.
func roll_cover(target:Unit, kit_id:StringName) -> Lancer.COVER:
	var gear:GearCore = shooter.get_gear(kit_id)
	var specific := SpecificAction.create(shooter, gear, gear.get_solo_action())
	var pre := AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = target}))
	return pre.cover

func test_fixture_the_distances():
	assert_eq(UnitRelation.distance_between(pier, near_ally), 3, 'fixture: an ally at Range 3.')
	assert_eq(UnitRelation.distance_between(pier, far_ally), 4, 'fixture: an ally at Range 4.')
	assert_eq(UnitRelation.distance_between(pier, near_hostile), 3, 'fixture: a hostile at Range 3.')

func test_nothing_is_covered_before_the_round_starts():
	assert_false(Fixture.has(pier, Fixture.BULWARK_GATE), 'No gate before a round starts.')
	assert_false(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'No chip on the ally.')
	assert_eq(cover_of(near_ally), Lancer.COVER.NONE, 'And no cover.')

func test_at_round_start_an_ally_within_three_has_soft_cover():
	await Fixture.new_round(game)
	assert_true(Fixture.has(pier, Fixture.BULWARK_GATE), 'The round start raised the gate on the Pier.')
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'The ally at Range 3 wears the chip.')
	assert_eq(cover_of(near_ally), Lancer.COVER.SOFT, 'The cover pipeline reads SOFT.')
	assert_eq(roll_cover(near_ally, Fixture.RIFLE), Lancer.COVER.SOFT, 'And a real weapon roll sees it.')

func test_an_ally_at_four_is_not_covered():
	await Fixture.new_round(game)
	assert_false(Fixture.has(far_ally, Fixture.BULWARK_COVER), 'Range 4 is outside Range 3.')
	assert_eq(cover_of(far_ally), Lancer.COVER.NONE, 'No cover.')

func test_the_pier_does_not_cover_itself():
	await Fixture.new_round(game)
	assert_false(Fixture.has(pier, Fixture.BULWARK_COVER), 'The Pier is not its own ally.')
	assert_eq(cover_of(pier), Lancer.COVER.NONE, 'No cover on the Pier.')

func test_a_hostile_within_three_is_not_covered():
	await Fixture.new_round(game)
	assert_false(Fixture.has(near_hostile, Fixture.BULWARK_COVER), 'Hostiles are not sheltered.')

func test_the_cover_lifts_when_the_piers_turn_starts():
	await Fixture.new_round(game)
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'fixture: the ally is covered.')
	await SpecFactory.start_turn(game, pier)
	assert_false(Fixture.has(pier, Fixture.BULWARK_GATE), 'The gate is gone at the Pier\'s turn start.')
	assert_false(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'And the chip with it.')
	assert_eq(cover_of(near_ally), Lancer.COVER.NONE, 'No cover any more.')

func test_another_units_turn_does_not_lift_it():
	await Fixture.new_round(game)
	await SpecFactory.start_turn(game, near_ally)
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'Only the PIER taking its turn ends the window.')
	assert_true(Fixture.has(pier, Fixture.BULWARK_GATE), 'The gate is still up.')

func test_the_next_round_raises_it_again():
	await Fixture.new_round(game)
	await SpecFactory.start_turn(game, pier)
	await SpecFactory.end_turn(game, pier)
	assert_false(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'fixture: lifted.')
	await Fixture.new_round(game)
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'Each round starts with the ally sheltered again.')

func test_hard_cover_from_elsewhere_still_wins():
	# Max-then-zero (cover_calculator.gd:19-24): soft is a floor. The Goblin's buff_symbiosis_cover
	# (HARD) stands in for terrain, as test_all_systems_red.gd does.
	SpecFactory.apply_buff(near_ally, &'buff_symbiosis_cover')
	await Fixture.new_round(game)
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'fixture: the chip landed.')
	assert_eq(cover_of(near_ally), Lancer.COVER.HARD, 'HARD is kept, not lowered to SOFT.')

func test_a_tech_attack_ignores_the_cover():
	await Fixture.new_round(game)
	assert_eq(roll_cover(near_ally, Fixture.INVADE), Lancer.COVER.NONE, 'Only weapon attacks read cover (attack_roll.gd:153-169).')

func test_the_chip_is_visible_and_the_gate_is_not():
	await Fixture.new_round(game)
	var chip:BuffCore = UnitCondition.get_buff(near_ally, Fixture.BULWARK_COVER)
	var gate:BuffCore = UnitCondition.get_buff(pier, Fixture.BULWARK_GATE)
	assert_not_null(chip, 'fixture: the chip.')
	assert_not_null(gate, 'fixture: the gate.')
	if chip == null or gate == null: return
	assert_false(chip.base.hide_from_player, 'The cover chip is the on-map sign.')
	assert_true(gate.base.hide_from_player, 'The gate is plumbing.')

# ---------------------------------------------------------------- measured, not fought (ruling 4)
#
# MEASURED 2026-09-25 (SP1): the round-start reaction still fires on a Stunned or a Shut Down Pier,
# and its allies are sheltered. The design left it open (reaction_bus.gd:121 asks can_activate_gear)
# and said either answer is recorded, neither fought. It reads as the card does: Bulwark is a
# trait, and a trait is not an action the status takes away. Pinned so a change is noticed.

func test_a_stunned_pier_still_shelters_its_allies():
	SpecFactory.apply(pier, Lancer.STATUS.STUNNED)
	await Fixture.new_round(game)
	assert_true(Fixture.has(pier, Fixture.BULWARK_GATE), 'Stunned: the gate still rises.')
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'And the ally is sheltered.')

func test_a_shut_down_pier_still_shelters_its_allies():
	SpecFactory.apply(pier, Lancer.STATUS.SHUTDOWN)
	await Fixture.new_round(game)
	assert_true(Fixture.has(pier, Fixture.BULWARK_GATE), 'Shut Down: the gate still rises.')
	assert_true(Fixture.has(near_ally, Fixture.BULWARK_COVER), 'And the ally is sheltered.')
