# HATRED - RAGE's face 6 (SP1 Task 12).
#
#   "6 Hatred: Whenever you take damage from a hostile character, they take 3 energy damage."
#
# A BUFF WITH A TRIGGER, not a reaction (ruling 14). Buff carries triggers_on, trigger_timing,
# triggers_on_event and activate of its own (buff.gd:138-139, :246-256) - this mod's
# buff_inexorable_formation.gd is the same shape. A reaction would pay the per-Kit reaction allowance
# and show up in the player's reaction list; the card is not a reaction.
#
# FOUR CLAUSES, AND ONLY ONE OF THEM IS ABOUT AN EVENT THAT NEVER ARRIVES (IMPLEMENTER CORRECTION,
# Task 12). End-of-turn burn carries NO target_unit (event_turn_end.gd:101-106 passes unit, number,
# category and flags and nothing else), so the damager clause refuses it with no special case - that
# half of the plan holds. THE ZERO-DAMAGE HALF DOES NOT: the plan expected event_unit_damage to abort
# before the POST reactions when armor ate the hit, and it does not. `capped_damage` is not the
# reduced number - it starts at 9999 (damage_modifications.gd:11) and only a BuffResistDamage CAP
# lowers it (:68-70), while armor reduces `damage`, floored at 0 (:116). So the abort at
# event_unit_damage.gd:93 never fires for armor, the POST queue at :196 is reached with number 0, and
# the gate IS asked. Measured on the first GREEN run of this file, which was 9/10 with exactly this
# test red. "Whenever you TAKE damage" is therefore a clause the CHIP has to carry.
#
# THE ANSWER IS 3 ENERGY WITH NO FLAGS, so armor applies - which is what the armor case measures.
#
# THE DAMAGE DIE IS 3, NOT 1: mw_assault_rifle is Reliable 2 and AttackUtil floors the total at
# reliable on a HIT as well as a miss (attack_util.gd:143-147). AND IT IS NOT 6, because the Leoleth
# has 8 HP and two sixes would structure it mid-test - and a hit above 4 also wakes vanilla ms_brace,
# which raises a yes/no of its own on an 8 HP frame (action_brace.gd:44-51).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hatred.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)
const SHOOTER_TILE := Vector2i(11, 6)
const SECOND_TILE := Vector2i(11, 8)

const D20_HITS := 19
## 1d6 at 3, floored at Reliable 2 either way, and under ms_brace's half-HP gate on an 8 HP frame.
const DAMAGE_DIE := 3
const ANSWER := 3

var game:Gamemaster
var leoleth:Unit
var shooter:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	shooter = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	LeolethFixture.arm_rifle(shooter)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- the wiring

func test_the_chip_is_wired_as_ruling_14_says():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.HATRED_CHIP)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.HATRED_CHIP)
	if buff == null: return
	assert_eq(buff.triggers_on, [ReactionBus.TRIGGER.DAMAGE] as Array[StringName],
		'It triggers on `damage` and nothing else.')
	assert_eq(buff.trigger_timing, ReactionBus.TIMING.POST,
		'POST: at PRE the number on the context is only the PRELIMINARY reduction '
		+ '(event_unit_damage.gd:55, before the PRE reactions at :59; the real one is computed at '
		+ ':62-67 afterwards), and the answer would be queued into the block BEFORE the hit it '
		+ 'answers.')
	assert_eq(buff.to, Buff.TO.NONE, 'It has no passive channel - it is purely a trigger.')
	assert_eq(buff.until, Lancer.UNTIL.START_OF_TURN, 'Until the start of the next turn.')
	assert_false(buff.hide_from_player, 'VISIBLE: one of the six face chips.')

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.buff_rage_hatred.name', 'gear.buff_rage_hatred.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.buff_rage_hatred.name'), 'Hatred', 'Named off the table.')
	assert_eq(X.tr('gear.buff_rage_hatred.effect'),
		'Whenever you take damage from a hostile character, they take 3 |energy| damage.',
		'And its effect row is that face\'s line, verbatim.')

# ---------------------------------------------------------------- the answer

func test_a_hostiles_hit_costs_it_three_energy():
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	assert_eq(shooter.current_damage(), 0, 'fixture: the shooter is undamaged.')
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_gt(leoleth.current_damage(), 0, 'LIVENESS: the shot landed.')
	assert_eq(shooter.current_damage(), ANSWER, 'And it cost the shooter 3.')

func test_armor_applies_to_the_answer():
	# "no flags" (ruling 14) means the damage event takes the ordinary reduction path. A 1-armor
	# shooter therefore takes 2, not 3 - which is also what proves the answer is a real damage event
	# rather than a direct write to the HP bar.
	FrameIsolation.isolate_frame(shooter)
	shooter.core.frame.stat.armor = 1
	shooter.core.full_repair()
	assert_eq(shooter.core.current.armor, 1, 'fixture: the shooter has armor 1.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(shooter.current_damage(), ANSWER - 1, 'And armor took one off the answer.')

func test_a_second_hit_in_the_same_round_answers_again():
	# "WHENEVER", with no 1/round anywhere in the card. A reaction would have been limited by the
	# engine's own per-round hard limit; a buff trigger is not, which is one of the reasons ruling 14
	# is a buff.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(shooter.current_damage(), ANSWER, 'fixture: the first hit was answered.')
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot_again(game, shooter, leoleth)
	assert_eq(shooter.current_damage(), ANSWER * 2, 'And so was the second, in the same round.')

# ---------------------------------------------------------------- what does NOT answer

func test_heat_damage_costs_nothing():
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	await game.execute_event(&'event_unit_damage', {
		unit = leoleth, number = 2, category = Lancer.DAMAGE_TYPE.HEAT, target_unit = shooter,
	})
	assert_gt(leoleth.core.current.heat, 0, 'LIVENESS: the heat really landed.')
	assert_eq(shooter.current_damage(), 0, 'And heat is not damage for this card.')

func test_a_zero_damage_hit_costs_nothing():
	# An armor-9 Leoleth takes nothing from a 3. The gate IS asked - the event reaches DAMAGE POST
	# with number 0, see this file's header - and the chip's own "something has to have landed"
	# clause is what refuses it. The chip is still held, which is what separates "refused" from
	# "absent".
	FrameIsolation.isolate_frame(leoleth)
	leoleth.core.frame.stat.armor = 9
	leoleth.core.full_repair()
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.HATRED_CHIP), 'fixture: the chip is held.')
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(leoleth.current_damage(), 0, 'fixture: armor 9 ate the whole hit.')
	assert_eq(shooter.current_damage(), 0, 'So nothing was answered.')

func test_end_of_turn_burn_costs_nothing():
	# event_turn_end queues its burn damage with unit, number, category and flags and NO target_unit
	# (:101-106), so the damager clause refuses it without a special case. The Leoleth burning at the
	# end of its own turn must not answer itself.
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	leoleth.state.burn = 2
	# The end-of-turn engineering check decides whether the burn lands; a 1 fails it.
	LeolethFixture.queue([1])
	await SpecFactory.end_turn(game, leoleth)
	assert_gt(leoleth.current_damage(), 0, 'LIVENESS: the burn really landed.')
	assert_eq(shooter.current_damage(), 0, 'And nobody was answered for it.')

func test_an_allys_friendly_fire_costs_nothing():
	var friend:Unit = LeolethFixture.create_ally(game, SECOND_TILE)
	LeolethFixture.arm_rifle(friend)
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, friend, leoleth)
	assert_gt(leoleth.current_damage(), 0, 'LIVENESS: the friendly shot landed.')
	assert_eq(friend.current_damage(), 0, 'But the card says HOSTILE character.')

func test_a_hostile_drones_hit_costs_its_owner():
	# ATTRIBUTION, unaffected by the 2026-09-27 membership ruling: get_owner_unit_or_self resolves an
	# OWNED drone's hit to the character that owns it (unit.gd:270-273), so the owner answers rather
	# than the drone. An UNOWNED drone would resolve to itself and now answers for itself instead (see
	# test_an_unowned_hostile_drones_hit_costs_it_the_answer below) - a drone is a character too.
	var drone:Unit = LeolethFixture.create_drone(game, SECOND_TILE, Faction.AI_ENEMY)
	LeolethFixture.own_drone(drone, shooter)
	LeolethFixture.arm_rifle(drone)
	assert_eq(drone.get_owner_unit_or_self(), shooter, 'fixture: the drone resolves to its owner.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, drone, leoleth)
	assert_gt(leoleth.current_damage(), 0, 'LIVENESS: the drone\'s shot landed.')
	assert_eq(drone.current_damage(), 0, 'The drone itself takes nothing...')
	assert_eq(shooter.current_damage(), ANSWER, '...and its OWNER takes the 3.')

func test_an_unowned_hostile_drones_hit_costs_it_the_answer():
	# THE ELEVENTH CASE (Task 12, Step 5 mutation 3), now read the OTHER way: a drone is a character
	# (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22). An OWNED drone still
	# resolves to its owner - get_owner_unit_or_self() walks past it (attribution, unchanged - see
	# test_a_hostile_drones_hit_costs_its_owner above) - but an UNOWNED drone resolves to itself
	# (unit.gd:270-273, no owner id), and the damager clause now tests is_character(), which is TRUE
	# for a drone (unit.gd:116). So the hit is answered, by the drone itself.
	var drone:Unit = LeolethFixture.create_drone(game, SECOND_TILE, Faction.AI_ENEMY)
	LeolethFixture.arm_rifle(drone)
	assert_eq(drone.get_owner_unit_or_self(), drone, 'fixture: an unowned drone resolves to itself.')
	assert_true(drone.is_character(), 'fixture: and it IS a character...')
	assert_false(drone.is_actor(), '...though still not an actor - attribution is unaffected.')
	await LeolethFixture.rage(game, leoleth, LeolethFixture.FACE_HATRED)
	LeolethFixture.queue([D20_HITS, DAMAGE_DIE])
	await LeolethFixture.shoot(game, drone, leoleth)
	assert_gt(leoleth.current_damage(), 0, 'LIVENESS: the drone\'s shot landed.')
	assert_eq(drone.current_damage(), ANSWER,
		'A drone is a character (ruling 2026-09-27), so it answers for its own hit.')
