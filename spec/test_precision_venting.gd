# PRECISION VENTING - "1/round, whenever the Lovers Knot critically hits with a Ranged weapon it may
# clear 1 Heat." Design 1.2, rulings 4-5.
#
# The Maiden's Blush's Rend shape (a buff-supplied ON_CRIT OnHitEffect, reapplied each turn, the round
# hand-rolled on the trait gear) with the payoff swapped for event_unit_cool. No prompt: clearing heat
# is never a cost worth a click. AT 0 HEAT IT DOES NOT FIRE AND THE ROUND IS KEPT (ruling 5).
#
# Every "does not" test carries its own control: the fixture's heat is asserted before the attack, the
# attack is asserted to have landed (damage on the dummy), and the counter is read alongside the heat
# so a clear that never happened cannot pass as a clear that was correctly refused.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_precision_venting.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/lovers_knot_fixture.gd')

const KNOT_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4) # adjacent, so the rifle AND the sword reach without moving

## A d20 that crits against evasion -10; a d20 that hits and does not.
const CRIT := 30
const HIT := 13

var game:Gamemaster
var knot:Unit
var target:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	knot = Fixture.create_knot(game, KNOT_TILE)
	Fixture.equip(knot, Fixture.RANGED)
	Fixture.equip(knot, Fixture.RANGED_2)
	Fixture.equip(knot, Fixture.MELEE)
	target = Fixture.create_dummy(game, TARGET_TILE, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func shoot(d20:int, kit_id:StringName = Fixture.RANGED) -> void:
	await Fixture.open_turn(game, knot)
	await Fixture.attack(game, knot, kit_id, target, [d20])

# ---------------------------------------------------------------- the shape

func test_the_trait_and_its_buff_are_shaped_right():
	var kit:Kit = ContentLibrary.get_kit(Fixture.PRECISION_VENTING_ID)
	assert_true(Kit.is_valid(kit), 'mt_precision_venting is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_true(kit.actions.is_empty(), 'It carries no action - it is a pure passive.')
	assert_eq(kit.passives.size(), 1, 'One passive: the buff applicator.')
	var buff:Buff = ContentLibrary.get_buff(Fixture.PRECISION_VENTING_BUFF)
	assert_not_null(buff, 'buff_precision_venting is in the buffs index.')
	if buff == null: return
	assert_true(buff is BuffWeaponTypeOnHit, 'It is a BuffWeaponTypeOnHit.')
	assert_eq(buff.to, Buff.TO.ONHIT_EFFECT, 'It supplies an on-hit effect.')
	assert_true(buff.hide_from_player, 'Trait plumbing, never a chip on the unit.')
	assert_eq(buff.weapon_types_forbidden, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE],
		'Everything but MELEE (ruling 4: Blast, Burst, Cone and Line included).')
	assert_eq(buff.effects.size(), 1, 'One on-hit effect.')
	if buff.effects.is_empty(): return
	assert_eq(buff.effects[0].apply_on, OnHitEffect.STAGE.ON_CRIT, 'On a crit.')

# ---------------------------------------------------------------- the trigger

func test_a_ranged_crit_clears_one_heat():
	Fixture.set_heat(knot, 2)
	await shoot(CRIT)
	assert_gt(target.current_damage(), 0, 'Fixture: the rifle landed.')
	assert_eq(Fixture.heat(knot), 1, 'A ranged crit cleared exactly 1 heat.')
	assert_eq(Fixture.precision_venting_uses(knot), 1, 'And spent the 1/round.')

func test_a_second_crit_the_same_round_clears_nothing():
	Fixture.set_heat(knot, 3)
	await shoot(CRIT)
	assert_eq(Fixture.heat(knot), 2, 'Fixture: the first crit cleared 1.')
	var damage_before:int = target.current_damage()
	await shoot(CRIT, Fixture.RANGED_2) # another gun: the same one twice a turn is refused
	assert_gt(target.current_damage(), damage_before, 'Fixture: the second shot landed too.')
	assert_eq(Fixture.heat(knot), 2, 'The second crit in the same round clears nothing.')
	assert_eq(Fixture.precision_venting_uses(knot), 1, 'And the counter did not move again.')

func test_the_next_round_clears_again():
	# The control for the test above: the same second crit, a turn later, does clear.
	Fixture.set_heat(knot, 3)
	await shoot(CRIT)
	assert_eq(Fixture.heat(knot), 2, 'Fixture: the first crit cleared 1.')
	await Fixture.cycle_turn(game, knot)
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'The Knot\'s own turn start reset the round (ruling 3).')
	await shoot(CRIT)
	assert_eq(Fixture.heat(knot), 1, 'A crit in the new round clears again.')

func test_a_melee_crit_clears_nothing():
	Fixture.set_heat(knot, 2)
	await shoot(CRIT, Fixture.MELEE)
	assert_gt(target.current_damage(), 0, 'Fixture: the sword landed.')
	assert_eq(Fixture.heat(knot), 2, 'A melee crit is not a Ranged weapon critting.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'And the round is untouched.')

func test_a_hit_that_is_not_a_crit_clears_nothing():
	Fixture.set_heat(knot, 2)
	await shoot(HIT)
	assert_gt(target.current_damage(), 0, 'Fixture: the rifle landed.')
	assert_eq(Fixture.heat(knot), 2, 'A plain hit clears nothing.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'And the round is untouched.')

func test_at_zero_heat_the_round_is_kept():
	Fixture.set_heat(knot, 0)
	await shoot(CRIT)
	assert_gt(target.current_damage(), 0, 'Fixture: the rifle landed.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'At 0 heat it does not fire, and the round is kept (ruling 5).')
	# The control: the round kept above is still there to spend.
	Fixture.set_heat(knot, 2)
	await shoot(CRIT, Fixture.RANGED_2) # another gun: the same one twice a turn is refused
	assert_eq(Fixture.heat(knot), 1, 'A crit later the same round, with heat to clear, still clears.')
	assert_eq(Fixture.precision_venting_uses(knot), 1, 'And spends the round then.')

func test_another_units_ranged_crit_clears_nothing_from_the_knot():
	# "Only the Knot's own attacks" (ruling 4). An ally's rifle crits the same dummy.
	var ally:Unit = Fixture.create_hostile(game, Vector2i(5, 5), Faction.PLAYER)
	Fixture.set_heat(knot, 2)
	await Fixture.open_turn(game, ally)
	await Fixture.attack(game, ally, Fixture.RANGED, target, [CRIT])
	assert_gt(target.current_damage(), 0, 'Fixture: the ally\'s rifle landed.')
	assert_eq(Fixture.heat(knot), 2, 'Somebody else\'s crit clears nothing from the Knot.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'And the round is untouched.')

func test_a_drones_crit_does_not_vent_the_owning_knot():
	# get_attacker resolves the drone's attack to the Knot for buff COLLECTION (event_unit_attack.gd:38,
	# 47), so Precision Venting IS asked on the drone's crit - only buff_precision_venting.gd:33's
	# `context.unit != holder` refuses it (context.unit is the drone itself, never rewritten to the
	# owner). Heat 2 on BOTH: proves the guard, not merely that nothing on the Knot moved - a version
	# that let the buff through would read `activation.context.unit` as "the Knot" too and vent the
	# DRONE's heat instead, since onhit_precision_venting.gd never re-resolves through get_attacker.
	var drone:Unit = Fixture.create_owned_drone(game, Vector2i(6, 4), knot)
	Fixture.set_heat(knot, 2)
	Fixture.set_heat(drone, 2)
	await Fixture.open_turn(game, drone)
	await Fixture.attack(game, drone, Fixture.RANGED, target, [CRIT])
	assert_gt(target.current_damage(), 0, 'Fixture: the drone\'s rifle landed.')
	assert_eq(Fixture.heat(knot), 2, 'The owning Knot\'s heat is untouched by its drone\'s crit.')
	assert_eq(Fixture.heat(drone), 2, 'And the drone\'s own heat is untouched too.')
	assert_eq(Fixture.precision_venting_uses(knot), 0, 'The round on the Knot\'s own trait gear is not spent either.')
