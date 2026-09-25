# Panoply Coat (Grutte Pier trait, SP1). Design rulings 2-3.
#
#   "The Grutte Pier has Resistance to all damage and heat from attacks that originate from beyond
#    Range 10."
#
# THE PROBE COMES FIRST: a REAL rifle attack from 11 tiles, hit and damage both cheated, and the
# assertion is on HP. "The buff never matched" and "the context lacked the attacker" look the same,
# so nothing here asserts a meta or a buff query - only what the Pier actually lost.
#
# Arithmetic: armour 2 comes off BEFORE resistance halves (damage_modifications.gd, the non-heat
# branch), and Util.half rounds up. 6 kinetic: 6 - 2 = 4 unresisted, ceil(4 / 2) = 2 resisted.
# Heat ignores armour: 2 heat is 2, or 1 resisted.
#
# Ranges are closest-tile Chebyshev on a flat map (UnitRelation.distance_between): the Pier at
# (1, 5), a shooter at (12, 5) is 11 away, at (11, 5) exactly 10.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_panoply_coat.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/grutte_pier_fixture.gd')

const PIER_TILE := Vector2i(1, 5)
const BEYOND := Vector2i(12, 5) # 11 tiles out
const AT_TEN := Vector2i(11, 5) # exactly Range 10

## A plain hit on the Pier's evasion 8 (and on its e-defense 6) that is not a crit.
const HIT := 15
const MISS := 1

var game:Gamemaster
var pier:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	pier = Fixture.create_pier(game, PIER_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func hostile_at(tile:Vector2i) -> Unit:
	return Fixture.create_dummy(game, tile)

## HP lost to `kit_id` fired from `from`.
func hp_lost_to(from:Vector2i, kit_id:StringName, dice:Array[int]) -> int:
	var shooter := hostile_at(from)
	assert_eq(UnitRelation.distance_between(pier, shooter), 11 if from == BEYOND else 10, 'fixture: the range is what the test says.')
	var before:int = pier.core.current.health
	await Fixture.attack(game, shooter, pier, kit_id, dice)
	return before - pier.core.current.health

func heat_gained_from(from:Vector2i, kit_id:StringName, dice:Array[int]) -> int:
	var shooter := hostile_at(from)
	var before:int = pier.core.current.heat
	await Fixture.attack(game, shooter, pier, kit_id, dice)
	return pier.core.current.heat - before

## A raw damage event, as a save, a zone or a status would deal it - no AttackRoll.
func hp_lost_to_raw(amount:int, type:Lancer.DAMAGE_TYPE, source:Unit, flags:Array = []) -> int:
	var before:int = pier.core.current.health
	await game.execute_event(&'event_unit_damage', {
		unit = pier, number = amount, category = type, flags = flags, target_unit = source,
	})
	return before - pier.core.current.health

# ---------------------------------------------------------------- the probe

func test_probe_a_real_rifle_hit_from_eleven_tiles_is_halved():
	assert_eq(await hp_lost_to(BEYOND, Fixture.RIFLE, [HIT, 6]), 2,
		'6 kinetic - 2 armour = 4, halved to 2: resisted from beyond Range 10.')

func test_the_same_hit_from_exactly_ten_tiles_is_not():
	assert_eq(await hp_lost_to(AT_TEN, Fixture.RIFLE, [HIT, 6]), 4,
		'Range 10 is not BEYOND Range 10: the full 4.')

# ---------------------------------------------------------------- what else it covers

func test_heat_from_a_tech_attack_beyond_ten_is_halved():
	# "all damage AND HEAT": an Invade's 2 heat is a HEAT damage event carrying the AttackRoll.
	assert_eq(await heat_gained_from(BEYOND, Fixture.INVADE, [HIT]), 1, 'Two heat from 11 out, halved to 1.')

func test_heat_from_a_tech_attack_at_ten_is_not():
	assert_eq(await heat_gained_from(AT_TEN, Fixture.INVADE, [HIT]), 2, 'The full 2 from Range 10.')

func test_reliable_damage_on_a_miss_from_beyond_ten_is_halved():
	# Reliable damage still carries the AttackRoll (event_unit_damage.gd:255-263), so it is damage
	# from an attack. Armour out of the way: the rifle's Reliable 2 would otherwise be armoured to 0.
	pier.core.current.armor = 0
	assert_eq(await hp_lost_to(BEYOND, Fixture.RIFLE, [MISS, 6, 6]), 1, 'Reliable 2 on a miss, halved to 1.')

func test_reliable_damage_on_a_miss_at_ten_is_not():
	pier.core.current.armor = 0
	assert_eq(await hp_lost_to(AT_TEN, Fixture.RIFLE, [MISS, 6, 6]), 2, 'Reliable 2 on a miss, in full.')

# ---------------------------------------------------------------- what it does not

func test_damage_from_a_distant_source_that_is_not_an_attack_is_not_resisted():
	# A save's damage, a zone's, a status's: no AttackRoll in context.object (ruling 3).
	var far := hostile_at(BEYOND)
	assert_eq(await hp_lost_to_raw(6, Lancer.DAMAGE_TYPE.KINETIC, far), 4, 'No attack, no resistance: 6 - 2 = 4.')

func test_the_piers_own_self_heat_is_not_resisted():
	var before:int = pier.core.current.heat
	await game.execute_event(&'event_unit_damage', {
		unit = pier, number = 2, category = Lancer.DAMAGE_TYPE.HEAT,
		flags = [EventService.DAMAGE_FLAG.SELF_INFLICTED], target_unit = pier,
	})
	assert_eq(pier.core.current.heat - before, 2, 'Self-heat lands in full.')

func test_end_of_turn_burn_is_not_resisted():
	var far := hostile_at(BEYOND)
	assert_eq(await hp_lost_to_raw(3, Lancer.DAMAGE_TYPE.BURN, far, [EventService.DAMAGE_FLAG.IS_EOT_BURN]), 3,
		'Burn ticking at the end of a turn ignores resistance anyway, and is no attack.')

func test_sourceless_damage_does_not_crash_and_is_not_resisted():
	# Tormentor Spines reads target_unit before checking it; this buff checks first.
	assert_eq(await hp_lost_to_raw(6, Lancer.DAMAGE_TYPE.KINETIC, null), 4, 'No source: the full 4, and no crash.')

# ---------------------------------------------------------------- where the attack came from (close review)

## The attack's own Knockback moves the Pier BEFORE its damage lands: on_hit queues the push on the
## per-target attack (action_attack_weapon.gd:337), and the damage events are built and run after
## every roll (event_unit_attack_declared.gd:147-200). "Originate from beyond Range 10" is where the
## attack was made from, so the push must not count.
func test_a_hit_from_ten_that_knocks_the_pier_to_eleven_is_not_resisted():
	var shooter := hostile_at(AT_TEN)
	Fixture.equip(shooter, Fixture.RIFLE)
	await Fixture.open_turn(game, shooter) # before the push: a turn start would clear it
	var push:BuffCore = UnitCondition.apply_buff_id(SpecFactory.dummy_event(), shooter, &'buff_zwarte_hoop_knockback')
	push.set_state('n', 1)
	var before:int = pier.core.current.health
	await Fixture.attack(game, shooter, pier, Fixture.RIFLE, [HIT, 6])
	assert_eq(UnitRelation.distance_between(pier, shooter), 11, 'fixture: the hit pushed the Pier out to 11.')
	assert_eq(before - pier.core.current.health, 4, 'Made from Range 10: the full 4, wherever the push left it.')

func test_the_resistance_is_hidden_and_lives_on_the_pier():
	assert_true(Fixture.has(pier, Fixture.PANOPLY_BUFF), 'The trait keeps the buff on the Pier.')
	var kit:Kit = ContentLibrary.get_kit(Fixture.PANOPLY_ID)
	assert_true(Kit.is_valid(kit) and kit.is_trait, 'mt_panoply_coat is an indexed trait.')
	var buff:BuffCore = UnitCondition.get_buff(pier, Fixture.PANOPLY_BUFF)
	if buff == null: return
	assert_true(buff.base.hide_from_player, 'Hidden: the card is what the player reads.')
