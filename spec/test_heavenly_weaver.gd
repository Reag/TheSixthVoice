# HEAVENLY WEAVER - Six Sky SP1, design 1.3, rulings 5 and 7-10:
#
#   "1/round, when the Six Sky teleports itself, or another character, the next successful attack it
#    makes deals +1d6 Bonus damage."
#
# Every "does not" has its control half: a teleport that did not arm the chip is asserted to have
# LANDED, so "no chip" cannot be the boring answer of a move that never happened.
#
# The d20 queue: HIT_ROLL hits a 10-evasion dummy, MISS_ROLL misses it; every damage die is a 6, so the
# rifle deals 6 and the chip's 1d6 another 6.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_heavenly_weaver.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const SIX_SKY_TILE := Vector2i(4, 4)
const AWAY := Vector2i(6, 4)
const FAR := Vector2i(6, 6)
const TARGET_TILE := Vector2i(9, 4)
const OTHER_TILE := Vector2i(4, 7)
const OTHER_DEST := Vector2i(2, 7)
## The rifle's 1d6 on a 6, and the chip's 1d6 on a 6.
const RIFLE_DAMAGE := 6
const CHIP_DAMAGE := 6

## Vetoes every teleport of its holder at ENTIRE_MOVEMENT PRE through the frozen helper - the
## Uncertainty Field / Flash Anchor shape, test_teleport.gd's VetoListener re-pointed.
class VetoListener extends Buff:
	const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
	var heard:int = 0
	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		hide_from_player = true
		until = Lancer.UNTIL.MANUAL
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]
	func triggers_on_event(_core:BuffCore, holder:Unit, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == holder and Teleport.is_teleport(triggering_event.context)
	func activate(_core:BuffCore, activation:EventCore) -> void:
		heard += 1
		Teleport.veto(activation.context.event)

var game:Gamemaster
var six_sky:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	six_sky = Fixture.create_six_sky(game, SIX_SKY_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func armed() -> bool: return Fixture.weaver_chips(six_sky) > 0

# ---------------------------------------------------------------- arming

func test_it_starts_unarmed():
	assert_eq(Fixture.weaver_chips(six_sky), 0, 'No chip before any teleport.')
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'The round is unspent.')

func test_teleporting_itself_arms_it():
	await Fixture.teleport_self(six_sky, AWAY)
	assert_eq(six_sky.tile(), AWAY, 'CONTROL: the Six Sky landed.')
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'One chip.')
	assert_eq(Fixture.weaver_uses(six_sky), 1, 'The round is spent.')

func test_a_sourceless_voluntary_self_teleport_arms_it():
	# Ruling 5's second clause: the vanilla Blinkspace shape carries no object at all, so the mover is
	# the agent.
	var move:EventCore = await Fixture.teleport_self_without_a_source(six_sky, AWAY)
	assert_eq(six_sky.tile(), AWAY, 'CONTROL: the Six Sky landed.')
	assert_null(Teleport.forcer(move.context), 'PRECONDITION: the move had no readable forcer.')
	assert_true(armed(), 'Armed by its own voluntary teleport.')

func test_teleporting_an_ally_arms_it():
	var ally:Unit = Fixture.create_ally(game, OTHER_TILE)
	await Fixture.shove(six_sky, ally, OTHER_DEST)
	assert_eq(ally.tile(), OTHER_DEST, 'CONTROL: the ally landed.')
	assert_true(armed(), '"Or another character" - an ally counts.')

func test_teleporting_a_hostile_arms_it():
	var hostile:Unit = Fixture.create_dummy(game, OTHER_TILE)
	await Fixture.shove(six_sky, hostile, OTHER_DEST)
	assert_eq(hostile.tile(), OTHER_DEST, 'CONTROL: the hostile landed.')
	assert_true(armed(), 'A hostile is another character too.')

func test_teleporting_a_drone_does_not_arm_it():
	var drone:Unit = Fixture.create_drone(game, OTHER_TILE, Faction.PLAYER)
	await Fixture.shove(six_sky, drone, OTHER_DEST)
	assert_eq(drone.tile(), OTHER_DEST, 'CONTROL: the drone landed.')
	assert_false(armed(), 'A drone is not a character (ruling 4).')
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'And the round is untouched.')

func test_a_hostile_teleporting_the_six_sky_does_not_arm_it():
	var hostile:Unit = Fixture.create_hostile(game, OTHER_TILE)
	await Fixture.shove(hostile, six_sky, AWAY)
	assert_eq(six_sky.tile(), AWAY, 'CONTROL: the Six Sky was moved.')
	assert_false(armed(), 'It was the hostile\'s teleport, not the Six Sky\'s (ruling 7).')

func test_somebody_elses_teleport_of_an_ally_does_not_arm_it():
	var ally:Unit = Fixture.create_ally(game, OTHER_TILE)
	var other_ally:Unit = Fixture.create_ally(game, Vector2i(2, 2))
	await Fixture.shove(other_ally, ally, OTHER_DEST)
	assert_eq(ally.tile(), OTHER_DEST, 'CONTROL: the ally landed.')
	assert_false(armed(), 'Only a teleport the SIX SKY causes arms it.')

func test_a_plain_move_does_not_arm_it():
	await SpecFactory.move(game, six_sky, Vector2i(5, 4))
	assert_eq(six_sky.tile(), Vector2i(5, 4), 'CONTROL: the Six Sky moved.')
	assert_false(armed(), 'Walking is not teleporting.')

func test_a_vetoed_teleport_does_not_arm_it():
	var listener := VetoListener.new()
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), six_sky, BuffCore.create(listener))
	var move:EventCore = await Fixture.teleport_self(six_sky, AWAY)
	assert_eq(listener.heard, 1, 'PRECONDITION: the veto heard the teleport.')
	assert_true(move.aborted, 'PRECONDITION: and aborted it.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'The Six Sky never left.')
	assert_false(armed(), 'A vetoed teleport is not a teleport (ruling 5).')
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'And the round is untouched.')

func test_a_sunzi_blink_mine_credits_the_six_sky():
	# A RESIDENT-MOD source (design 1.5). The mine is deployed by the Sunzi's own action, so it is owned
	# the way the game owns it; the move then carries the detonation's own SpecificAction, the exact
	# shape action_blink_mine_detonation.gd emits - the MINE as forcer, resolved owner-or-self.
	Fixture.equip(six_sky, Fixture.BLINK_CHARGES_ID)
	await SpecFactory.use(game, six_sky, Fixture.BLINK_CHARGES_ID, Fixture.BLINK_MINE_ACTION, [Vector2i(5, 4)])
	var mines:Array = game.map.get_all_units().filter(func(unit:Unit) -> bool:
		return unit.core.frame != null and unit.core.frame.resource_path.get_file().get_basename() == Fixture.BLINK_MINE_FRAME)
	assert_eq(mines.size(), 1, 'PRECONDITION: the Sunzi\'s action laid one Blink Mine.')
	if mines.size() != 1: return
	var mine:Unit = mines[0]
	assert_eq(mine.get_owner_unit(), six_sky, 'PRECONDITION: the Six Sky owns it.')
	var detonation:GearCore = mine.get_gear(Fixture.BLINK_MINE_DETONATION)
	assert_true(GearCore.is_valid(detonation), 'PRECONDITION: the mine carries its detonation.')
	if not GearCore.is_valid(detonation): return
	var ally:Unit = Fixture.create_ally(game, OTHER_TILE)
	var movement_type := MovementType.create_for_involuntary(ally)
	movement_type.teleport = true
	await game.execute_event(&'event_unit_move', {
		unit = ally,
		target_tiles = [OTHER_DEST],
		resource = movement_type,
		object = SpecificAction.create(mine, detonation, detonation.get_solo_action()),
	})
	assert_eq(ally.tile(), OTHER_DEST, 'CONTROL: the ally landed.')
	assert_true(armed(), 'The Six Sky\'s mine teleported a character: the Six Sky teleported it.')

# ---------------------------------------------------------------- the damage

func test_without_the_chip_the_rifle_does_its_own_damage():
	# The control for every damage number below.
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	var before := Fixture.health(target)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_eq(before - Fixture.health(target), RIFLE_DAMAGE, 'The rifle alone.')

func test_the_next_hit_deals_one_d6_more_and_spends_the_chip():
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	assert_true(armed(), 'PRECONDITION: armed.')
	var before := Fixture.health(target)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_eq(before - Fixture.health(target), RIFLE_DAMAGE + CHIP_DAMAGE, 'The rifle plus the 1d6.')
	assert_false(armed(), 'The chip is spent.')

func test_a_miss_keeps_the_chip_for_the_next_hit():
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.MISS_ROLL])
	assert_true(armed(), '"The next SUCCESSFUL attack": a miss does not spend it (require_hit).')
	# A turn boundary, because the engine's per-turn soft limit silently refuses the same gun twice.
	await Fixture.cycle_turn(game, six_sky)
	var before := Fixture.health(target)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_eq(before - Fixture.health(target), RIFLE_DAMAGE + CHIP_DAMAGE, 'The hit after the miss carries it.')
	assert_false(armed(), 'And spends it.')

func test_the_chip_waits_across_rounds_until_used():
	# Ruling 8, the author's call: it lasts until used.
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.cycle_turn(game, six_sky)
	await Fixture.cycle_turn(game, six_sky)
	assert_true(armed(), 'Two turn boundaries later, still armed.')
	var before := Fixture.health(target)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_eq(before - Fixture.health(target), RIFLE_DAMAGE + CHIP_DAMAGE, 'And still pays out.')

func test_an_owned_drones_hit_does_not_spend_the_chip():
	# Ruling 9. The drone attacks with its OWNER's buffs (get_attacker, unit.gd:276-282), so it is the
	# holder check that keeps the charge for the Six Sky's own attack.
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	var drone:Unit = Fixture.create_owned_drone(game, Vector2i(6, 2), six_sky)
	assert_eq(drone.get_attacker(), six_sky, 'PRECONDITION: the drone\'s attacks are blamed on the Six Sky.')
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.open_turn(game, drone)
	var before := Fixture.health(target)
	await Fixture.attack(game, drone, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_eq(before - Fixture.health(target), RIFLE_DAMAGE, 'CONTROL: the drone hit, for the rifle alone.')
	assert_true(armed(), 'The Six Sky\'s charge waits for the Six Sky.')

# ---------------------------------------------------------------- the round

func test_it_arms_once_a_round():
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_false(armed(), 'PRECONDITION: armed, then spent.')
	await Fixture.teleport_self(six_sky, FAR)
	assert_eq(six_sky.tile(), FAR, 'CONTROL: the second teleport landed.')
	assert_false(armed(), '1/round: the second teleport in the round does not re-arm it.')
	assert_eq(Fixture.weaver_uses(six_sky), 1, 'One use this round.')

func test_it_re_arms_next_round_after_use():
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	await Fixture.cycle_turn(game, six_sky)
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'PRECONDITION: the round reset at its own turn start.')
	await Fixture.teleport_self(six_sky, FAR)
	assert_true(armed(), 'Armed again.')

func test_re_arming_while_armed_neither_stacks_nor_spends_the_round():
	# Ruling 8: a charge carried into a new round, then a teleport. The round must survive, so a use of
	# the chip later that round can still be followed by a fresh arming.
	var target:Unit = Fixture.create_dummy(game, TARGET_TILE)
	Fixture.equip(six_sky, Fixture.RANGED)
	await Fixture.open_turn(game, six_sky)
	await Fixture.teleport_self(six_sky, AWAY)
	await Fixture.cycle_turn(game, six_sky)
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'PRECONDITION: a new round, the chip still held.')
	await Fixture.teleport_self(six_sky, FAR)
	assert_eq(six_sky.tile(), FAR, 'CONTROL: that teleport landed.')
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'No second chip.')
	assert_eq(Fixture.weaver_uses(six_sky), 0, 'And the round is NOT spent.')
	await Fixture.attack(game, six_sky, Fixture.RANGED, target, [Fixture.HIT_ROLL])
	assert_false(armed(), 'PRECONDITION: the chip is spent on a hit.')
	await Fixture.teleport_self(six_sky, AWAY)
	assert_true(armed(), 'So the same round can still arm it afresh.')

# ---------------------------------------------------------------- scene end

func test_the_chip_does_not_survive_into_the_next_scene():
	# MEASURED, not cleared by us: buffs live on UnitBattleState (unit_battle_state.gd:21), and the next
	# level builds each unit from its core with a fresh one (Unit.create, unit.gd:76) - which is what a
	# lancer carried out of a scene is (event_combat_end stores unit.core, not the unit).
	await Fixture.teleport_self(six_sky, AWAY)
	assert_true(armed(), 'CONTROL: the live unit carries the chip.')
	var next_scene:Unit = Unit.create(six_sky.core)
	assert_eq(UnitCondition.get_buffs(next_scene, Fixture.WEAVER_CHIP).size(), 0,
		'The same core, rebuilt for the next scene, does not.')
