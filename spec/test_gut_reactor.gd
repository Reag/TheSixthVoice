# GUT REACTOR (Koremasa core passive, design section 2.6, rulings 19-20):
#
#   "1/round, when you deal damage to an exposed character, they take 1d3+1 Energy damage and must
#    succeed an Engineering save or else be knocked prone and become impaired until the end of their
#    next turn."
#
# A HIDDEN-PROMPT DAMAGE POST REACTION on the core Kit (consumes_rxn false, its own 1/round). "You" is
# the dealer resolved owner-or-self (Unit.get_attacker), so the Koremasa's deployables count; HEAT is
# not damage here; "deal damage" is more than 0 after armor. ORDER, ruling 20: spend the 1/round
# FIRST (so the bonus cannot re-trigger it), deal the bonus INLINE, then the save - Prone MANUAL
# (until they stand), Impaired END_OF_NEXT_TURN. A non-character auto-fails the save.
#
# EVERY DAMAGE HERE IS A DIRECT event_unit_damage FROM THE KOREMASA (target_unit = the dealer,
# event_unit_damage.gd:83), so the dice are exactly [the bonus d3, the save d20] - except the one
# test that swings a real weapon. The target is Exposed, which DOUBLES both the trigger and the
# bonus (damage_modifications.gd:55-57): a d3 of 1 is 2 Energy, doubled to 4.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gut_reactor.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 3)
const HOSTILE_TILE := Vector2i(4, 3)
const MOUNT_TILE := Vector2i(7, 3)
const LANDING := Vector2i(6, 3)

## The save: d20 + Engineering (the dummy's 0) against the Koremasa's save target 10.
const FAIL := 5
const PASS := 15

var game:Gamemaster
var responder
var koremasa:Unit
var hostile:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.MELEE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_move_tile = Tile.INVALID

# ---------------------------------------------------------------- helpers

func expose(unit:Unit) -> void:
	UnitCondition.apply_status(SpecFactory.dummy_event(), unit, Lancer.STATUS.EXPOSED, Lancer.UNTIL.MANUAL)

## `number` Kinetic to `target`, dealt by `dealer`, after loading [d3, save d20].
func hurt(target:Unit, number:int, d3:int, save:int, dealer:Unit = null,
		type:Lancer.DAMAGE_TYPE = Lancer.DAMAGE_TYPE.KINETIC) -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue([d3, save])
	await game.execute_event(&'event_unit_damage', {
		unit = target, number = number, category = type,
		target_unit = dealer if dealer != null else koremasa,
	})

func lost(unit:Unit, before:int) -> int: return before - unit.core.current.health

func status_until(unit:Unit, status:StringName) -> int:
	for condition:StatusCondition in unit.state.statuses:
		if condition.type == status: return condition.until
	return -1

# ---------------------------------------------------------------- wiring

func test_gut_reactor_is_a_non_reaction_point_damage_reaction_on_the_card():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	var action:Action = kit.get_action(Fixture.GUT_REACTOR_ACTION) if Kit.is_valid(kit) else null
	assert_true(action is ActionReaction, 'Gut Reactor is a reaction.')
	if not action is ActionReaction: return
	assert_false(action.consumes_rxn, '"1/round", not "Reaction".')
	assert_true(action.show_in_tooltip(kit), 'It is on the card, under its own rows.')

# ---------------------------------------------------------------- the bonus and the save

func test_damage_to_an_exposed_hostile_adds_the_bonus_doubled():
	expose(hostile)
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, PASS)
	assert_eq(lost(hostile, before), 3 * 2 + (1 + 1) * 2, 'The hit, doubled (6), then 1d3+1 Energy, doubled (4).')

func test_the_bonus_is_the_d3_plus_one():
	expose(hostile)
	var before := hostile.core.current.health
	await hurt(hostile, 3, 3, PASS)
	assert_eq(lost(hostile, before), 6 + (3 + 1) * 2, 'A d3 of 3: 4 Energy, doubled to 8.')

func test_a_failed_save_knocks_them_prone_and_impairs_them():
	expose(hostile)
	await hurt(hostile, 3, 1, FAIL)
	assert_true(hostile.has_status(Lancer.STATUS.PRONE), 'Knocked prone.')
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'And impaired.')
	assert_eq(status_until(hostile, Lancer.STATUS.PRONE), Lancer.UNTIL.MANUAL, 'Prone until they stand.')
	assert_eq(status_until(hostile, Lancer.STATUS.IMPAIRED), Lancer.UNTIL.END_OF_NEXT_TURN,
		'Impaired "until the end of their next turn".')

func test_a_passed_save_leaves_them_standing():
	expose(hostile)
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, PASS)
	assert_eq(lost(hostile, before), 10, 'fixture: the bonus landed.')
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'Not prone.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Not impaired.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 1, 'The round is spent whether they pass or fail.')

# ---------------------------------------------------------------- what triggers it

func test_an_unexposed_target_triggers_nothing():
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, FAIL)
	assert_eq(lost(hostile, before), 3, 'Only the hit: no bonus.')
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'No save.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 0, 'Nothing spent.')

func test_heat_is_not_damage_here():
	expose(hostile)
	var before := hostile.core.current.health
	await hurt(hostile, 2, 1, FAIL, null, Lancer.DAMAGE_TYPE.HEAT)
	assert_eq(Fixture.heat(hostile), 2, 'fixture: the heat landed.')
	assert_eq(lost(hostile, before), 0, 'No bonus.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 0, 'Nothing spent.')

func test_damage_armor_ate_whole_triggers_nothing():
	expose(hostile)
	hostile.core.frame.stat.armor = 5
	hostile.core.full_repair()
	var before := hostile.core.current.health
	await hurt(hostile, 1, 1, FAIL) # 2 after Exposed, less than the armor
	assert_eq(lost(hostile, before), 0, 'fixture: nothing got through.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 0, '"Deal damage" means more than 0.')

func test_someone_elses_damage_triggers_nothing():
	expose(hostile)
	var other := Fixture.create_ally(game, Vector2i(3, 5))
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, FAIL, other)
	assert_eq(lost(hostile, before), 6, 'Only the ally\'s hit.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 0, '"When YOU deal damage".')

func test_the_koremasas_own_deployable_counts():
	# Ruling 19: owner-or-self, the Snicker Snack shape - a mine's damage is its owner's.
	expose(hostile)
	var dep := FitzgeraldFixture.create_deployable(game, Vector2i(3, 6), 10, 0, 5, Faction.PLAYER)
	UnitAction.set_deployable_owner(dep, koremasa, Fixture.core(koremasa))
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, PASS, dep)
	assert_eq(lost(hostile, before), 10, 'The deployable\'s hit counts as the Koremasa\'s: the bonus landed.')

func test_a_second_damage_in_the_turn_triggers_nothing_and_the_bonus_never_re_triggers():
	expose(hostile)
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, PASS)
	assert_eq(lost(hostile, before), 10, 'fixture: the first hit, and exactly ONE bonus.')
	await hurt(hostile, 3, 1, PASS)
	assert_eq(lost(hostile, before), 16, 'The second hit is only its own 6: 1/round.')
	assert_eq(Fixture.gut_reactor_uses(koremasa), 1, 'One use.')

func test_it_re_arms_at_the_koremasas_next_turn():
	expose(hostile)
	await hurt(hostile, 3, 1, PASS)
	await Fixture.cycle_turn(game, koremasa)
	var before := hostile.core.current.health
	await hurt(hostile, 3, 1, PASS)
	assert_eq(lost(hostile, before), 10, 'A new turn, a new bonus (ruling 18).')

func test_a_real_melee_hit_triggers_it():
	expose(hostile)
	var before := hostile.core.current.health
	await Fixture.open_turn(game, koremasa)
	# d20 15 hits evasion 10; the blade's 1d6+2 rolls a hit die and a crit die (1, 1); then the bonus d3 and the save.
	Fixture.queue([15, 1, 1, 1, PASS])
	await SpecFactory.use_solo(game, koremasa, Fixture.MELEE, hostile)
	assert_eq(lost(hostile, before), (1 + 2) * 2 + 4, 'The hit (6) and the bonus (4).')

# ---------------------------------------------------------------- on its own mount (ruling 2)

func test_knocking_its_own_mount_prone_keeps_the_koremasa_riding():
	# The standing hostile is beside the Koremasa, and "ride now" would take it: out of the way first.
	UnitTile.move_to(hostile, Vector2i(3, 9))
	var mount := Fixture.create_mount(game, MOUNT_TILE)
	responder.chosen_move_tile = LANDING
	await Fixture.use_core(game, koremasa, Fixture.FOLLY_ACTION)
	assert_true(Fixture.is_riding(koremasa, mount), 'fixture: riding.')
	expose(mount)
	await hurt(mount, 3, 1, FAIL)
	assert_true(mount.has_status(Lancer.STATUS.PRONE), 'The mount is knocked prone.')
	assert_true(Fixture.is_riding(koremasa, mount), 'And the Koremasa stays on.')
