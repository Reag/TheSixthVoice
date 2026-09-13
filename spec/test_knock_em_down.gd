# SP1 Task 6: Knock 'em down.
#
# Design §2.2, rulings 11 and 15 (2026-09-13):
#   1/round, when the Fitzgerald critically hits a character with a Cannon, that character must
#   make a Hull save or be knocked Prone.
#
# There is no crit trigger in the engine: crit effects come through Buff.TO.ONHIT_EFFECT carrying
# an OnHitEffect whose apply_on is the ON_CRIT stage (event_unit_attack.gd:89-93), gathered from
# get_buffs_to(owner, Buff.TO.ONHIT_EFFECT, context). The engine only enforces a per-round limit for
# ActionReactions (reaction_bus.gd:116-124), never for a buff-triggered effect, so the 1/round is
# hand-rolled the way Crack Shot III does: buff_knock_em_down.gd gates on
# GearCore.get_uses_this_round_alt, and onhit_knock_em_down.gd increments it.
#
# RULING 15 is the whole point of the fifth test below: the round is spent by FORCING the save, pass
# or fail - not by the target actually going prone. So the increment has to happen in should_abort(),
# before super() rolls the save, exactly like Crack Shot III increments before calling
# UnitHasecheck.make_save. Test 5 lets the FIRST crit's save PASS and then proves the SECOND crit in
# the same round still does nothing - which is the only test that would fail under the alternative
# (spend-on-a-failed-save) reading.
#
# CRITS ARE FORCED THROUGH THE ATTACK ROLL, NOT THROUGH HaseBlock. attack_roll.gd:73 computes
# `crit = (total_roll >= 20) and hit and can_crit`, where total_roll is the cheated d20 base_roll
# plus the (possibly negative, from Bizarre Cannon's Inaccurate tag) accuracy die. cheat_a_crit()
# below cheats a base_roll of 30, which stays >= 20 even after the worst-case -6 accuracy die, and
# pins the target's evasion very low so the shot always lands too.
#
# THE HULL SAVE ITSELF IS PINNED THROUGH HaseBlock, NOT THE DICE QUEUE - same reasoning as
# test_bizarre_cannon.gd's MBP prone-save tests (and Task 4's finding): the attack ahead of the save
# pops an unpredictable number of accuracy/damage dice out of the same global queue, so queuing a
# specific d20 for the save would be guessing how many dice the attack ate first. A hase.hull of
# +-30 dominates whatever the save's own d20 comes up as, cheated or real.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const FRAME_ID := &'mf_fitzgerald'
const KIT_ID := &'cp_broadside'
const ACTION_ID := &'action_bizarre_cannon'
const TRAIT_ID := &'mt_knock_em_down'
const USAGE_KEY := &'knock_em_down'

const RIFLE_ID := &'mw_assault_rifle'

const RELIABLE_ON_MISS := 2 # Bizarre Cannon's Reliable 2

const FIRE_FROM := Vector2i(7, 4)
const AIM_EAST := Vector2i(11, 4)

var game:Gamemaster
var unit:Unit
var target:Unit

func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self, true,
		SpecFactory.create_combat(Landscape.create_default(Vector2i(15, 9))))

	unit = SpecFactory.create_unit(game.map, FIRE_FROM)
	unit.core.frame = ContentLibrary.get_mech_frame(FRAME_ID)
	# NOT FrameIsolation'd, same reasoning as test_bizarre_cannon.gd: a deep duplicate of the frame
	# would hand the unit copies of its trait Kits, and Kit.compcon_id is a lazily-derived bare var
	# that does not survive duplicate(), which would break unit.get_gear() lookups on those traits.
	SpecFactory.apply_passive_buffs(unit) # full_repair() + the frame's trait Kits' passive buffs

	target = SpecFactory.create_unit(game.map, AIM_EAST, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(target) # we DO rewrite this one's stats
	target.core.frame.stat.health = 200 # never dies mid-spec
	target.core.frame.stat.evasion = -10 # every test here needs a guaranteed hit
	target.core.frame.stat.armor = 0
	target.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func _gear() -> GearCore:
	var gear := unit.get_gear(KIT_ID)
	return gear if GearCore.is_valid(gear) else null

func _trait_gear() -> GearCore:
	var gear := unit.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

## Open the unit's turn, once. Mirrors test_bizarre_cannon.gd: MORE BLACK POWDER needs it and so
## does the Fitzgerald's own protocol, so every fixture in this mod fires through the same helper.
func open_turn() -> void:
	if not unit.state.is_taking_turn: await SpecFactory.start_turn(game, unit)

func fire_at(tile:Vector2i) -> void:
	await open_turn()
	await SpecFactory.use(game, unit, KIT_ID, ACTION_ID, tile)

## A guaranteed CRITICAL hit. base_roll of 30 clears total_roll >= 20 even against the Bizarre
## Cannon's worst-case -6 Inaccurate accuracy die, and the target's evasion (-10, set in before_each)
## guarantees the hit half. The trailing 6s are a buffer against however many damage/self-damage/
## recoil dice a given shot pops, same trick as test_bizarre_cannon.gd's cheat_a_hit().
##
## CLEARS THE QUEUE FIRST. This test file fires more than once per test (test 5 fires three times),
## and Dice.cheat_attack only APPENDS - so a still-nonempty queue from an earlier shot's unused
## buffer 6s would hand the next shot's attack roll a leftover 6 instead of the fresh 30, silently
## turning an intended crit into a plain hit. Confirmed by a real run: the third shot in test 5 rolled
## a leftover 6 instead of 30 before this clear() was added, and read "hit!" instead of "crit!" in
## the log - a bug in this HELPER, not in the trait.
func cheat_a_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([30], [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])

## A guaranteed HIT that is never a crit: base_roll 19 minus the worst-case -6 accuracy die is 13,
## always short of the total_roll >= 20 crit threshold, while the target's -10 evasion still
## guarantees hit = true. Same values as test_bizarre_cannon.gd's cheat_a_hit(). Clears the queue
## first for the same reason as cheat_a_crit() above.
func cheat_a_hit_no_crit() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack([19], [6, 6, 6, 6, 6, 6])

func force_save_to_fail() -> void:
	target.core.frame.hase = HaseBlock.create(-30, 0, 0, 0)
	target.core.full_repair()

func force_save_to_pass() -> void:
	target.core.frame.hase = HaseBlock.create(30, 0, 0, 0)
	target.core.full_repair()

# ---------------------------------------------------------------- the trait

func test_a_cannon_crit_forces_a_hull_save_and_prones_on_a_failure() -> void:
	force_save_to_fail()

	cheat_a_crit()
	await fire_at(AIM_EAST)

	assert_gt(target.current_damage(), RELIABLE_ON_MISS, 'Fixture: the shot landed.')
	assert_true(target.has_status(Lancer.STATUS.PRONE),
		'A Cannon crit forced a Hull save, and the target failed it and went prone.')
	# Proves the round was actually spent, not just that prone happened to apply - the only way this
	# reads 1 is if onhit_knock_em_down.should_abort ran and incremented the trait's own gear.
	var trait_gear := _trait_gear()
	assert_not_null(trait_gear, 'fixture: the trait is reachable as gear through unit.get_gear().')
	if trait_gear != null:
		assert_eq(trait_gear.get_uses_this_round_alt(USAGE_KEY), 1,
			"Knock 'em down spent its 1/round usage.")

func test_a_passed_save_leaves_the_target_standing() -> void:
	force_save_to_pass()

	cheat_a_crit()
	await fire_at(AIM_EAST)

	assert_gt(target.current_damage(), RELIABLE_ON_MISS,
		'Fixture: the shot still landed, so the save is what spared it and not a miss.')
	assert_false(target.has_status(Lancer.STATUS.PRONE), 'A passed Hull save leaves the target standing.')

func test_a_cannon_hit_that_is_not_a_crit_does_nothing() -> void:
	# Would fail its save if forced - discriminates "the effect never triggered" from "it triggered
	# and happened to pass".
	force_save_to_fail()

	cheat_a_hit_no_crit()
	await fire_at(AIM_EAST)

	assert_gt(target.current_damage(), RELIABLE_ON_MISS, 'Fixture: the shot landed.')
	assert_false(target.has_status(Lancer.STATUS.PRONE),
		"A hit that is not a crit does not trigger Knock 'em down.")

func test_a_rifle_crit_does_nothing() -> void:
	unit.core.equip_system(RIFLE_ID)
	SpecFactory.apply_passive_buffs(unit)
	# Would fail its save if forced - same discrimination as the non-crit test above.
	force_save_to_fail()

	cheat_a_crit()
	await open_turn()
	await SpecFactory.use_solo(game, unit, RIFLE_ID, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the rifle shot landed.')
	assert_false(target.has_status(Lancer.STATUS.PRONE),
		"A Rifle crit does not trigger Knock 'em down: the weapon_types = [CANNON] gate holds.")

func test_the_second_cannon_crit_in_a_round_does_nothing_and_the_next_round_works_again() -> void:
	# RULING 15. The first crit's save PASSES on purpose: if the round were spent only by a FAILED
	# save (the alternative reading), this pass would leave the 1/round untouched and the second crit
	# below would still be free to force (and fail) its own save. Ruling 15 says the round was already
	# spent by forcing the first save at all, pass or fail.
	force_save_to_pass()
	cheat_a_crit()
	await fire_at(AIM_EAST)

	assert_gt(target.current_damage(), RELIABLE_ON_MISS, 'Fixture: the first shot crit and landed.')
	assert_false(target.has_status(Lancer.STATUS.PRONE), 'Fixture: the first Hull save passed.')
	var trait_gear := _trait_gear()
	assert_not_null(trait_gear, 'fixture: the trait gear is reachable.')
	if trait_gear != null:
		assert_eq(trait_gear.get_uses_this_round_alt(USAGE_KEY), 1,
			'Fixture: the first crit spent the 1/round usage despite the passed save.')

	# Second crit, same round. The save is now pinned to auto-FAIL: if the round limit were not
	# actually gating the buff, this shot would force a save and the target would go prone.
	force_save_to_fail()
	cheat_a_crit()
	await fire_at(AIM_EAST)

	assert_false(target.has_status(Lancer.STATUS.PRONE),
		'The second crit in the same round does nothing: the 1/round usage was already spent.')

	# A new round (a new turn, in this single-unit spec) resets the usage - and the save is still
	# pinned to auto-fail, so the trait re-firing is what makes this prone.
	await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)
	assert_eq(trait_gear.get_uses_this_round_alt(USAGE_KEY), 0,
		'Fixture: the new round reset the usage counter.')

	cheat_a_crit()
	await fire_at(AIM_EAST)

	assert_true(target.has_status(Lancer.STATUS.PRONE),
		"Knock 'em down works again on the new round.")
