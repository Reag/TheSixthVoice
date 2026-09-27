# AN END TO ALL THINGS (Black Mountain SP1, design ruling 7):
#   "2/round, when an allied character with OVERSHIELD you granted makes a successful attack roll
#    against a hostile character within sensors and line of sight, you may take 1 heat to have them
#    deal +3 bonus damage."
#
# An ATTACK POST reaction on mt_an_end_to_all_things gated on the shared helper's "granted by" mark
# (Overshield.is_granted_by), offering the Black Mountain's controller 1 heat for a one-time
# BONUS_DAMAGE_SPECIFIC +3 on the attacker, scoped to that defender - Eyes of Night's shape.
#
# THE "GRANTED BY" GATE IS DRIVEN THROUGH Overshield.grant_by DIRECTLY (design 1.4): the Black Mountain's
# own granters - Exalt, Fell the Mighty - arrive in SP2, and the helper is the seam they will use.
#
# WHAT THIS FILE PROVES: a marked ally's hit within Sensors and LOS raises the confirm and, on yes, costs
# 1 heat and deals +3; declining costs nothing and spends no use; an ally shielded by anyone ELSE is not
# offered; an ally whose mark was zeroed by damage is not; the Black Mountain's own hit is not (ruling
# 3); a hostile outside Sensors is not; a hostile behind a wall is not; a hostile drone is not; an
# unowned allied drone is not and an owned one is offered as its owner; a miss is not; 2/round, reset at
# the Black Mountain's turn; the +3 is consumed by the roll that read it; an invade counts.
#
# PROMPTS. The Black Mountain is PLAYER, so CommonActionUtil.confirm_use raises a yes/no titled with the
# reaction's name; the ally's own shot raises none (no lock to consume). The queued responder answers
# and records, so "not offered" is a prompt COUNT, not only an absence of heat.
#
# DICE. Hostiles have EVASION -10 so every d20 hits, and every queued die is a 4: the rifle deals 4
# (RELIABLE 2 is below that), +3 makes 7. Fixture.queue tails with 1s.
#
# GEOMETRY (map 30x12). The Black Mountain at (4,4), Sensors 10. The ally at (6,4); the hostile at
# (10,4), 6 from the Black Mountain and 4 from the ally. FAR_HOSTILE (15,4) is 11 from the Black Mountain
# and 9 from the ally - in rifle range, out of Sensors. WALL x = 8, rows 3-5, cuts the Black Mountain's
# sight of (10,4); SIDE_ALLY (10,7) shoots that hostile from due south, past the wall.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_an_end_to_all_things.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const BM_TILE := Vector2i(4, 4)
const ALLY_TILE := Vector2i(6, 4)
const SIDE_ALLY_TILE := Vector2i(10, 7)
const HOSTILE_TILE := Vector2i(10, 4)
const FAR_HOSTILE_TILE := Vector2i(15, 4)
const WALL:Array[Vector2i] = [Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5)]
const ALWAYS_HIT := -10
const RIFLE_DIE := 4
const BONUS := 3

var game:Gamemaster
var responder
var black_mountain:Unit
var ally:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	black_mountain = Fixture.create_black_mountain(game, BM_TILE)
	Fixture.arm_rifle(black_mountain)
	ally = Fixture.create_ally(game, ALLY_TILE)
	Fixture.arm_rifle(ally)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE, ALWAYS_HIT)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The confirm prompts this reaction raised - titled with its own name row.
func offers() -> int:
	var name:String = X.tr('gear.mt_an_end_to_all_things.action_an_end_to_all_things.name')
	var count := 0
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(name) or String(seen.get('desc', '')).contains(name): count += 1
	return count

func uses() -> int: return Fixture.uses_this_round(black_mountain, Fixture.AN_END_ID, Fixture.AN_END_ACTION)

func shoot(attacker:Unit, target:Unit = hostile) -> void:
	Fixture.queue([RIFLE_DIE, RIFLE_DIE, RIFLE_DIE, RIFLE_DIE])
	await Fixture.shoot(game, attacker, target)

func shoot_again(attacker:Unit, target:Unit = hostile) -> void:
	Fixture.queue([RIFLE_DIE, RIFLE_DIE, RIFLE_DIE, RIFLE_DIE])
	await Fixture.shoot_again(game, attacker, target)

func damage_taken(target:Unit) -> int: return 200 - Fixture.health(target)

func assert_offered_and_paid(message:String) -> void:
	assert_eq(offers(), 1, message + ' Offered once.')
	assert_eq(Fixture.heat(black_mountain), 1, message + ' The Black Mountain took 1 heat.')
	assert_eq(damage_taken(hostile), RIFLE_DIE + BONUS, message + ' The hostile took the rifle plus 3.')
	assert_eq(uses(), 1, message + ' One of the two uses spent.')

func assert_not_offered(message:String, target:Unit = hostile) -> void:
	assert_eq(offers(), 0, message + ' Not offered.')
	assert_eq(Fixture.heat(black_mountain), 0, message + ' No heat.')
	assert_eq(uses(), 0, message + ' Nothing spent.')

# ---------------------------------------------------------------- the offer

func test_the_kit_and_its_reaction_are_registered() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.AN_END_ID)
	assert_true(Kit.is_valid(kit), 'mt_an_end_to_all_things is in the kits index.')
	if not Kit.is_valid(kit): return
	var action:Action = kit.get_action(Fixture.AN_END_ACTION)
	assert_true(action is ActionReactionAttacked, 'An ActionReactionAttacked.')
	if action is ActionReactionAttacked:
		assert_true(action.require_hit, 'A successful attack roll.')
		assert_false(action.consumes_rxn, 'A trait, not a reaction point.')
		assert_eq(action.get_per_round_hard_limit(null), 2, '2/round.')
	var bonus:Buff = ContentLibrary.get_buff(Fixture.AN_END_BONUS)
	assert_not_null(bonus, 'buff_an_end_to_all_things_bonus is in the buffs index.')
	if bonus == null: return
	assert_eq(bonus.to, Buff.TO.BONUS_DAMAGE_SPECIFIC, 'Specific bonus damage: never halved, read per roll.')
	assert_true(bonus.is_onetime and bonus.hide_from_player, 'One-time and hidden.')
	assert_ne(bonus.until, Lancer.UNTIL.FINISH_DAMAGE, 'NEVER FINISH_DAMAGE (Eyes of Night\'s measurement).')

func test_a_marked_allys_hit_is_offered_and_yes_costs_a_heat_for_plus_three() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	assert_true(Overshield.is_granted_by(ally, black_mountain), 'fixture: marked.')
	await shoot(ally)
	assert_offered_and_paid('A marked ally hit a hostile within Sensors and LOS.')

func test_declining_costs_nothing_and_spends_no_use() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	responder.yesno_queue.assign([false])
	await shoot(ally)
	assert_eq(offers(), 1, 'Offered.')
	assert_eq(Fixture.heat(black_mountain), 0, 'Declined: no heat.')
	assert_eq(damage_taken(hostile), RIFLE_DIE, 'And no +3.')
	assert_eq(uses(), 0, 'And the use is still there.')

func test_an_ally_shielded_by_somebody_else_is_not_offered() -> void:
	await Fixture.grant_overshield(ally, 3) # a plain grant: vanilla, another mod, anyone but the Black Mountain
	assert_true(Overshield.has(ally), 'fixture: shielded.')
	assert_false(Overshield.is_granted_by(ally, black_mountain), 'fixture: but not by the Black Mountain.')
	await shoot(ally)
	assert_not_offered('Overshield from another source.')
	assert_eq(damage_taken(hostile), RIFLE_DIE, 'Plain damage.')

func test_an_ally_whose_granted_shield_was_zeroed_is_not_offered() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 2)
	await Fixture.damage(game, ally, 5, hostile)
	assert_eq(Overshield.current(ally), 0, 'fixture: the shield is gone.')
	assert_false(Overshield.is_granted_by(ally, black_mountain), 'fixture: and the mark with it.')
	await shoot(ally)
	assert_not_offered('The Overshield the Black Mountain granted is spent.')

func test_the_black_mountains_own_hit_is_never_offered() -> void:
	# Ruling 3 (the author's call): "allied character" excludes the Black Mountain, even one that
	# somehow holds its own mark.
	await Fixture.grant_overshield_by(black_mountain, black_mountain, 3)
	assert_true(Overshield.is_granted_by(black_mountain, black_mountain), 'fixture: it marked itself.')
	await shoot(black_mountain)
	assert_not_offered('The Black Mountain is not an allied character of itself.')

func test_a_hostile_outside_sensors_is_not_offered() -> void:
	var far := Fixture.create_hostile(game, FAR_HOSTILE_TILE, ALWAYS_HIT)
	assert_eq(UnitRelation.distance_between(black_mountain, far), 11, 'fixture: one past Sensors 10.')
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	await shoot(ally, far)
	assert_not_offered('The hostile is out of Sensors (ruling 4: measured to the HOSTILE on this card).', far)
	assert_eq(damage_taken(far), RIFLE_DIE, 'Plain damage.')

func test_a_hostile_the_black_mountain_cannot_see_is_not_offered() -> void:
	var side_ally := Fixture.create_ally(game, SIDE_ALLY_TILE)
	Fixture.arm_rifle(side_ally)
	Fixture.raise_wall(game, WALL)
	assert_false(UnitRelation.can_see(black_mountain, hostile), 'fixture: the wall blocks the Black Mountain\'s sight of the hostile.')
	assert_true(UnitRelation.can_see(side_ally, hostile), 'fixture: and not the side ally\'s.')
	await Fixture.grant_overshield_by(black_mountain, side_ally, 3)
	await shoot(side_ally)
	assert_not_offered('No line of sight to the hostile.')

func test_a_hostile_drone_is_not_offered() -> void:
	var drone := Fixture.create_drone(game, Vector2i(10, 2), Faction.AI_ENEMY)
	drone.core.frame.stat.evasion = ALWAYS_HIT
	drone.core.full_repair()
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	await shoot(ally, drone)
	assert_not_offered('A drone is not a hostile CHARACTER (ruling 3).', drone)

func test_an_allied_drones_hit_is_not_offered_unless_it_is_owned_by_a_marked_ally() -> void:
	var drone := Fixture.create_drone(game, Vector2i(6, 6))
	Fixture.arm_rifle(drone)
	await Fixture.grant_overshield_by(black_mountain, drone, 3) # even a marked drone
	await shoot(drone)
	assert_not_offered('An unowned drone is not a character.')
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	Fixture.own_drone(drone, ally)
	await shoot(drone)
	assert_eq(offers(), 1, 'An owned drone\'s shot is its owner\'s, and the owner is a marked allied character.')
	assert_eq(Fixture.heat(black_mountain), 1, 'Paid.')

func test_a_miss_is_not_offered() -> void:
	var evasive := Fixture.create_hostile(game, Vector2i(10, 2), 10)
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	Fixture.queue([Fixture.MISS_ROLL, RIFLE_DIE, RIFLE_DIE])
	await Fixture.shoot(game, ally, evasive)
	assert_eq(damage_taken(evasive), 2, 'fixture: missed - the rifle\'s RELIABLE 2 is what landed (attack_util.gd:144-147).')
	assert_not_offered('A miss is not a successful attack roll.', evasive)

func test_two_per_round_reset_at_the_black_mountains_turn() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	await shoot(ally)
	await shoot_again(ally)
	await shoot_again(ally)
	assert_eq(offers(), 2, 'Offered twice, not three times.')
	assert_eq(Fixture.heat(black_mountain), 2, 'Two heat.')
	assert_eq(damage_taken(hostile), 3 * RIFLE_DIE + 2 * BONUS, 'Three rifle hits, two of them +3.')
	assert_eq(uses(), 2, 'Both uses spent.')
	await Fixture.cycle_turn(game, black_mountain)
	await shoot(ally)
	assert_eq(offers(), 3, 'The Black Mountain\'s turn reset the tally (ruling 3).')

func test_the_bonus_is_consumed_by_the_roll_that_read_it() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	await shoot(ally)
	assert_eq(damage_taken(hostile), RIFLE_DIE + BONUS, 'fixture: the first hit took the +3.')
	assert_false(UnitCondition.has_buff(ally, Fixture.AN_END_BONUS), 'The one-time buff is gone after the roll.')
	responder.yesno_queue.assign([false])
	await shoot_again(ally)
	assert_eq(damage_taken(hostile), 2 * RIFLE_DIE + BONUS, 'A declined second hit is a plain rifle hit: nothing rode over.')

func test_an_invade_counts_and_its_plus_three_is_heat() -> void:
	# Fragment Signal deals 2 heat on a hit; the +3 inherits the attack's type. A tech attack rolls
	# against E-DEF (the dummy's frame default 8), which the -10 evasion does not touch - so this one
	# shot queues a 19, not the file's 4 (measured: a 4 "against Enemy (8 E-def): miss").
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	Fixture.queue([Fixture.HIT_ROLL])
	await Fixture.invade(game, ally, hostile)
	assert_eq(offers(), 1, 'An invade is a successful attack roll.')
	assert_eq(Fixture.heat(black_mountain), 1, 'Paid.')
	assert_eq(Fixture.heat(hostile), 2 + BONUS, 'The hostile took Fragment Signal\'s 2 heat plus 3.')
