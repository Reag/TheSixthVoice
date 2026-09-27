# DAYKEEPER CYCLER BOW - Six Sky SP2, design 2.1, rulings 12-14 and 18, plus the author's ruling of
# 2026-09-26 (SP2 build) that a crit's own teleport does NOT feed that same attack's Heavenly Weaver.
#
#   Main Launcher, HEAT SELF 1, OVERKILL, 1d6+3 Energy, Range 10.
#   "This weapon gains +1 Accuracy against targets within Range 5."
#   On crit: "Choose yourself or the target to be immediately teleported to a free space within Range 2
#   of their space."
#
# THE DICE, in the order the engine pops them (six_sky_fixture.fire_bow): the d20; the accuracy d6 only
# when the target is within 5; then anything the on-crit pops (a Starsickness save); then the damage
# dice, a HIT column and a CRIT column; then Overkill rerolls. Every test here that does not want an
# accuracy die stands its target at distance 7.
#
# THE PROMPTS a crit raises, and how each is answered:
#   1. the menu - a multiple choice, responder.multiple_choice_queue (0 = yourself, 1 = the target);
#   2. yourself - a MOVE picker (TargetActionUtil.ask_for_movement over the helper's pathfinder),
#      answered by responder.chosen_move_tile; Tile.INVALID cancels;
#   3. the target - the helper's reticle (Teleport.pick_tile), answered from
#      responder.chosen_plan_queue; CompconPlan.create_aborted() cancels.
# THE MENU OFFERS ONLY WHAT CAN HAPPEN (Pass F section 6.1 #2): an option whose teleport the engine
# would refuse (Immobilized, a ban, no free space) is dropped, and with nothing left no menu is raised -
# so the indices above hold only when both options survive.
# The Six Sky's own Starsickness offers a yes/no whenever it teleports a hostile; declined by default
# (chosen_yesnos = false) and queued explicitly where a test wants it.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_daykeeper_cycler_bow.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const SIX_SKY_TILE := Vector2i(4, 4)
const AT_FIVE := Vector2i(9, 4)
const AT_SIX := Vector2i(10, 4)
const AT_SEVEN := Vector2i(11, 4)
const AT_TEN := Vector2i(14, 4)
const AT_ELEVEN := Vector2i(15, 4)
## Two from the Six Sky, free: where "yourself" lands.
const SELF_LANDING := Vector2i(4, 6)
## Three from the Six Sky: outside the self teleport's reach.
const SELF_TOO_FAR := Vector2i(4, 7)
## Two east of the target at AT_SEVEN, free: where "the target" lands.
const TARGET_LANDING := Vector2i(13, 4)
## Three from the target: outside the shove's reach.
const TARGET_TOO_FAR := Vector2i(11, 7)
## On the map, far from everything: no pathfinder offers it, which is the move picker's cancel in the
## harness (test_phase_cloud.gd's UNREACHABLE). The picker's real cancel cannot be pressed from a spec.
const UNREACHABLE := Vector2i(15, 9)

## Fails against the Six Sky's Save 11 with Systems 0 (test_starsickness.gd's number).
const SAVE_FAILS := 10
const HIT_MISSES_BARE := 9 # 9 < evasion 10; 9 + an accuracy 6 = 15 hits

const INTERDICTION_FIELD := &'buff_interdiction_field'

var game:Gamemaster
var responder
var six_sky:Unit
var hostile:Unit
var watcher:PromptWatcher

func before_each() -> void:
	await get_tree().process_frame # a synchronous test's responder must be gone (harness traps, SP5)
	var made:Array = Fixture.create_game_with_prompts(self)
	game = made[0]
	responder = made[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	six_sky = Fixture.create_six_sky(game, SIX_SKY_TILE)
	hostile = Fixture.create_dummy(game, AT_SEVEN)
	responder.chosen_yesnos = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.multiple_choice_queue.clear()
	responder.chosen_plan_queue.clear()
	responder.chosen_move_tile = Tile.INVALID

# ---------------------------------------------------------------- helpers

func bow() -> SpecificAction: return Fixture.bow_specific(six_sky)

func landing_plan(tile:Vector2i) -> CompconPlan: return CompconPlan.create([tile], [], [])

## The accuracy the bow's own pre-attack pass adds against `target`, alone: the whole PreAttack total,
## which for these dummies (no cover, no Prone, not Impaired, not engaged) is only the bow's line.
func accuracy_against(target:Unit) -> int:
	var specific := bow()
	var pre := AttackRoll.PreAttack.create(Context.create({
		unit = six_sky, gear = specific.gear, action = specific.action, target_unit = target,
	}))
	return pre.accuracy_mods_total()

## The helper's reticle prompts, i.e. the target option's picks.
func pick_prompts() -> Array:
	return responder.plan_prompts.filter(func(info:Dictionary) -> bool:
		var using = info.using
		return SpecificAction.is_valid(using) and using.action.get_id() == Fixture.BOW_ACTION and info.pathfinder == null)

func offered_tiles() -> Array[Vector2i]:
	var picks := pick_prompts()
	if picks.is_empty(): return []
	return UnitTargeting.get_tiles_targetable(picks.back().using)

## The self option's move pickers (a move_tile request, which the plan recorder never sees).
func move_pathfinders() -> Array:
	return watcher.kinds(PromptWatcher.KIND.move_tile)

func crit(dice_after_d20:Array[int] = []) -> void:
	var dice:Array[int] = [Fixture.CRIT_ROLL]
	dice.append_array(dice_after_d20)
	await Fixture.fire_bow(game, six_sky, hostile, dice)

func menu_labels() -> PackedStringArray:
	if responder.multiple_choice_prompts.is_empty(): return []
	return responder.multiple_choice_prompts.back().labels

# ---------------------------------------------------------------- the profile

func test_the_bow_carries_the_cards_profile():
	var specific := bow()
	assert_true(SpecificAction.is_valid(specific), 'fixture: the Six Sky wields the bow.')
	if not SpecificAction.is_valid(specific): return
	var action = specific.action
	assert_eq(action.get_id(), Fixture.BOW_ACTION)
	assert_true(specific.gear.kit.has_weapon(), 'The mw_ Kit carries the weapon.')
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.LAUNCHER, 'Launcher.')
	assert_eq(action.damage_dice, '1d6+3')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.ENERGY)
	assert_eq(action.self_heat_dice, '1', 'HEAT SELF 1.')
	assert_true(action.has_tag(Lancer.WEAPON_TAG.OVERKILL), 'OVERKILL.')

func test_its_range_is_ten_and_not_eleven():
	var tiles := UnitTargeting.get_tiles_in_range(bow())
	assert_true(tiles.has(AT_TEN), 'Range 10 reaches a target 10 away.')
	assert_false(tiles.has(AT_ELEVEN), '...and not one 11 away.')

# ---------------------------------------------------------------- +1 Accuracy within 5 (ruling 13)

func test_plus_one_accuracy_against_a_target_five_away():
	UnitTile.move_to(hostile, AT_FIVE)
	assert_eq(accuracy_against(hostile), 1, '+1 Accuracy within Range 5.')
	var pre := AttackRoll.PreAttack.create(Context.create({
		unit = six_sky, gear = bow().gear, action = bow().action, target_unit = hostile,
	}))
	var titles:Array = pre.accuracy_mods.map(func(mod) -> String: return mod.title_key)
	assert_has(titles, bow().action.name(bow()), 'It is a NAMED line in the roll breakdown, the bow.')

func test_no_accuracy_against_a_target_six_away():
	UnitTile.move_to(hostile, AT_SIX)
	assert_eq(accuracy_against(hostile), 0, 'Nothing at 6.')

func test_the_accuracy_turns_a_bare_miss_into_a_hit_at_five():
	UnitTile.move_to(hostile, AT_FIVE)
	var before := Fixture.health(hostile)
	await Fixture.fire_bow(game, six_sky, hostile, [HIT_MISSES_BARE, 6, 6, 6])
	assert_lt(Fixture.health(hostile), before, 'A 9 plus the accuracy die hits at 5.')

func test_the_same_roll_misses_at_six():
	UnitTile.move_to(hostile, AT_SIX)
	var before := Fixture.health(hostile)
	await Fixture.fire_bow(game, six_sky, hostile, [HIT_MISSES_BARE, 6, 6])
	assert_eq(Fixture.health(hostile), before, 'The same 9 misses at 6, where no accuracy die is rolled.')

# ---------------------------------------------------------------- heat outside the Ritual (ruling 18)

func test_heat_self_one_outside_the_ritual():
	await Fixture.fire_bow(game, six_sky, hostile, [Fixture.HIT_ROLL, 6, 6])
	assert_lt(Fixture.health(hostile), 200, 'fixture: the shot landed.')
	assert_eq(Fixture.heat(six_sky), 1, 'HEAT SELF 1, and no Overkill heat on a roll with no 1.')

func test_overkill_heat_outside_the_ritual():
	# hit column 1, crit column 6, then the Overkill reroll of the 1 - a 6.
	await Fixture.fire_bow(game, six_sky, hostile, [Fixture.HIT_ROLL, 1, 6, 6])
	assert_eq(Fixture.heat(six_sky), 2, 'HEAT SELF 1 plus 1 Overkill heat for the rerolled 1.')

# ---------------------------------------------------------------- the crit (ruling 14)

func test_a_crit_offers_yourself_or_the_target():
	responder.multiple_choice_queue.assign([-1])
	await crit()
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'A crit raises the menu.')
	assert_eq(menu_labels(), PackedStringArray([
		tr('gear.mw_daykeeper_cycler_bow.crit_self'),
		tr('gear.mw_daykeeper_cycler_bow.crit_target'),
	]), 'Two options: yourself, then the target.')
	assert_ne(tr('gear.mw_daykeeper_cycler_bow.crit_self'), 'gear.mw_daykeeper_cycler_bow.crit_self',
		'and both have text.')

func test_a_hit_that_is_not_a_crit_raises_no_menu():
	await Fixture.fire_bow(game, six_sky, hostile, [Fixture.HIT_ROLL, 6, 6])
	assert_lt(Fixture.health(hostile), 200, 'fixture: the shot landed.')
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'Only a crit asks.')

func test_choosing_the_target_teleports_it_to_the_space_picked():
	responder.multiple_choice_queue.assign([1])
	responder.chosen_plan_queue.append(landing_plan(TARGET_LANDING))
	await crit()
	assert_eq(pick_prompts().size(), 1, 'The target option opens the reticle.')
	assert_true(offered_tiles().has(TARGET_LANDING), 'A free space 2 from the target is offered...')
	assert_false(offered_tiles().has(TARGET_TOO_FAR), '...and one 3 from it is not.')
	assert_false(offered_tiles().has(SELF_LANDING), '...and nothing is measured from the Six Sky.')
	assert_eq(hostile.tile(), TARGET_LANDING, 'The target is teleported there.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'The Six Sky stays put.')

func test_choosing_yourself_teleports_the_six_sky_to_the_space_picked():
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = SELF_LANDING
	await crit()
	var pickers := move_pathfinders()
	assert_eq(pickers.size(), 1, 'The self option opens a move picker.')
	if pickers.is_empty(): return
	var pathfinder:Pathfinder = pickers.front().pathfinder
	assert_true(pathfinder.is_movable(SELF_LANDING), 'A free space 2 away is offered...')
	assert_false(pathfinder.is_movable(SELF_TOO_FAR), '...and one 3 away is not.')
	assert_eq(six_sky.tile(), SELF_LANDING, 'The Six Sky is teleported there.')
	assert_eq(hostile.tile(), AT_SEVEN, 'The target stays put.')

func test_a_dead_target_leaves_only_yourself_on_the_menu():
	# A crit OUTSIDE the Ritual cannot outlive its target (on_crit runs before damage), so the dead
	# case is the Ritual's deferred one; the shared resolver is driven directly here.
	var specific := bow()
	await game.execute_event(&'event_unit_die', {unit = hostile})
	assert_false(Unit.is_valid(hostile), 'fixture: the target is dead.')
	responder.multiple_choice_queue.assign([-1])
	var activation := SpecFactory.dummy_event({unit = six_sky, gear = specific.gear, action = specific.action})
	await load(Fixture.BOW_SCRIPT).resolve_crit_teleport(activation, six_sky, hostile)
	assert_eq(menu_labels(), PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_self')]),
		'Only yourself is offered.')

func test_immobilized_stops_the_self_teleport():
	# Pass F section 6.1 #2: the menu offers only what can happen, so "Yourself" is not on it at all.
	UnitCondition.apply_status(SpecFactory.dummy_event(), six_sky, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	responder.multiple_choice_queue.assign([-1])
	responder.chosen_move_tile = SELF_LANDING
	await crit()
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(menu_labels(), PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_target')]),
		'Immobilized: "Yourself" is not offered, only the target.')
	assert_eq(move_pathfinders().size(), 0, 'No move picker opens.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'Immobilized: the preventable self teleport does not happen.')

func test_immobilized_does_not_stop_the_target_teleport():
	UnitCondition.apply_status(SpecFactory.dummy_event(), hostile, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	responder.multiple_choice_queue.assign([1])
	responder.chosen_plan_queue.append(landing_plan(TARGET_LANDING))
	await crit()
	assert_eq(hostile.tile(), TARGET_LANDING, 'An Immobilized target is still teleported (involuntary).')

func test_an_enemy_interdiction_field_stops_the_self_teleport():
	# A hostile holding the field 1 from the Six Sky bans every tile to a teleporting enemy of it
	# (buff_interdiction_field.gd). SELF_LANDING is legal without it (the self test above).
	# 2 away, not adjacent: an adjacent hostile would ENGAGE the Six Sky, and the engaged -1 turns the
	# d20 20 into a non-crit.
	var warden := Fixture.create_dummy(game, Vector2i(6, 6))
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), warden, INTERDICTION_FIELD)
	responder.multiple_choice_queue.assign([-1])
	responder.chosen_move_tile = SELF_LANDING
	await crit()
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(menu_labels(), PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_target')]),
		'A ban on the Six Sky: "Yourself" is not offered, only the target.')
	assert_eq(move_pathfinders().size(), 0, 'No move picker opens.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'A ban stops the self teleport.')

func test_an_allied_interdiction_field_stops_the_target_teleport():
	# An ALLY of the Six Sky holding the field 1 from the target bans the target, its enemy. The shove is
	# target-tile, so the ban would refuse it (event_unit_move.gd:139-146): the author's ruling
	# (2026-09-27, Pass F T2) is that "The target" is then not offered at all.
	var warden := Fixture.create_ally(game, Vector2i(12, 5))
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), warden, INTERDICTION_FIELD)
	responder.multiple_choice_queue.assign([-1])
	responder.chosen_plan_queue.append(landing_plan(TARGET_LANDING))
	await crit()
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(menu_labels(), PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_self')]),
		'A ban on the target: "The target" is not offered, only yourself.')
	assert_eq(pick_prompts().size(), 0, 'No reticle opens.')
	assert_eq(hostile.tile(), AT_SEVEN, 'A ban stops the target teleport (Teleport.shove is target-tile).')

func test_a_boxed_in_target_is_not_offered():
	# Every free space within 2 of the target filled: the shove would have nowhere to go.
	var corner := Vector2i(15, 0)
	UnitTile.move_to(hostile, corner)
	UnitTile.update_tracking_and_statuses(game.map)
	var around := Teleport.candidate_tiles(hostile, 2, false)
	assert_false(around.is_empty(), 'PRECONDITION: the corner has free spaces within 2 before boxing.')
	for tile:Vector2i in around: Fixture.create_dummy(game, tile)
	assert_true(Teleport.candidate_tiles(hostile, 2, false).is_empty(), 'fixture: the target is boxed in.')
	var specific := bow()
	responder.multiple_choice_queue.assign([-1])
	var activation := SpecFactory.dummy_event({unit = six_sky, gear = specific.gear, action = specific.action})
	await load(Fixture.BOW_SCRIPT).resolve_crit_teleport(activation, six_sky, hostile)
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(menu_labels(), PackedStringArray([tr('gear.mw_daykeeper_cycler_bow.crit_self')]),
		'Boxed in: "The target" is not offered, only yourself.')

func test_nothing_possible_raises_no_menu():
	# An Immobilized Six Sky crits terrain: "Yourself" cannot happen and a ground proxy is no target.
	UnitCondition.apply_status(SpecFactory.dummy_event(), six_sky, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	var proxy := TargetActionUtil.create_targeting_proxy(Vector2i(4, 1), null, 1, &'dep_attack_ground_proxy')
	assert_true(Unit.is_valid(proxy), 'PRECONDITION: the proxy is a valid unit, as the engine makes it.')
	responder.multiple_choice_queue.assign([-1])
	await load(Fixture.BOW_SCRIPT).resolve_crit_teleport(SpecFactory.dummy_event(), six_sky, proxy)
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'Nothing can happen, so no menu is raised.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE)

func test_a_cancelled_target_pick_teleports_nobody():
	responder.multiple_choice_queue.assign([1])
	responder.chosen_plan_queue.append(CompconPlan.create_aborted())
	await crit()
	assert_eq(pick_prompts().size(), 1, 'fixture: the reticle opened.')
	assert_eq(hostile.tile(), AT_SEVEN, 'Cancelled: the target stays.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'and so does the Six Sky.')

func test_a_cancelled_self_pick_teleports_nobody():
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = UNREACHABLE
	await crit()
	assert_eq(move_pathfinders().size(), 1, 'fixture: the move picker opened.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'Cancelled: the Six Sky stays.')

func test_a_space_the_picker_did_not_offer_is_never_taken():
	# An OCCUPIED space 2 away, never offered. What refuses it is the pathfinder, not a guard of ours:
	# Teleport.candidate_tiles drops the occupied space, Pathfinder.path_to returns [] for a tile outside
	# its set (pathfinder.gd:698-700) and the straight-path fallback is off for a teleport (:713), so the
	# plan's path is empty and teleport_self treats it as a cancel.
	var blocker := Fixture.create_ally(game, SELF_LANDING)
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = SELF_LANDING
	await crit()
	assert_eq(move_pathfinders().size(), 1, 'fixture: the move picker opened.')
	assert_false(move_pathfinders().front().pathfinder.is_movable(SELF_LANDING), 'fixture: the space was not offered.')
	assert_eq(six_sky.tile(), SIX_SKY_TILE, 'The Six Sky does not take it.')
	assert_eq(blocker.tile(), SELF_LANDING)

func test_a_cancelled_menu_teleports_nobody():
	responder.multiple_choice_queue.assign([-1])
	await crit()
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(responder.plan_prompts.size(), 0, 'Nothing is picked after a cancel.')
	assert_eq(hostile.tile(), AT_SEVEN)
	assert_eq(six_sky.tile(), SIX_SKY_TILE)

func test_an_ai_six_sky_skips_the_menu():
	var ai_sky := Fixture.create_six_sky(game, Vector2i(4, 8), Faction.AI_ENEMY)
	var player_target := Fixture.create_dummy(game, Vector2i(11, 8), 10, Faction.PLAYER)
	# The first damage set rolls a 2 and the second a 6: a crit keeps the higher, 6+3 = 9; a plain hit
	# would deal 2+3 = 5. So the damage itself proves the crit (no 1s: Overkill would reroll them).
	await Fixture.fire_bow(game, ai_sky, player_target, [Fixture.CRIT_ROLL, 2])
	assert_eq(Fixture.health(player_target), 200 - 9, 'fixture: the AI Six Sky CRITTED (a hit would be 5).')
	assert_eq(responder.multiple_choice_prompts.size(), 0, 'An AI Six Sky is never asked.')
	assert_eq(ai_sky.tile(), Vector2i(4, 8))
	assert_eq(player_target.tile(), Vector2i(11, 8))

# ---------------------------------------------------------------- the crit feeds the traits

func test_a_crit_teleport_of_a_hostile_triggers_starsickness_and_arms_the_weaver():
	responder.multiple_choice_queue.assign([1])
	responder.chosen_plan_queue.append(landing_plan(TARGET_LANDING))
	responder.yesno_queue.assign([true])
	await crit([SAVE_FAILS])
	assert_eq(hostile.tile(), TARGET_LANDING, 'fixture: the target was teleported.')
	assert_eq(responder.yesno_prompts.size(), 1, 'Starsickness offers: the Six Sky teleported a hostile.')
	assert_true(Fixture.is_impaired(hostile), 'Yes, and a failed save: Impaired.')
	assert_eq(Fixture.heat(six_sky), 2, 'HEAT SELF 1 plus Starsickness 1.')
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'and Heavenly Weaver is armed.')

func test_a_self_crit_teleport_arms_the_weaver():
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = SELF_LANDING
	await crit()
	assert_eq(six_sky.tile(), SELF_LANDING, 'fixture: the Six Sky teleported.')
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'Teleporting itself arms Heavenly Weaver.')

func test_the_critting_attack_does_not_take_the_weaver_it_armed():
	# The author's ruling (SP2 build): "the next successful attack" is a LATER attack. The chip lands
	# mid-attack, before this attack's damage is rolled, and would otherwise be spent on it: the tail
	# of 6s would make that 9 + 6.
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = SELF_LANDING
	var before := Fixture.health(hostile)
	await crit([6, 6])
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'The chip is still held after the attack that armed it...')
	assert_eq(before - Fixture.health(hostile), 9, '...and that attack dealt 1d6+3 and no more.')

func test_the_next_attack_after_the_crit_takes_the_weaver():
	responder.multiple_choice_queue.assign([0])
	responder.chosen_move_tile = SELF_LANDING
	await crit([6, 6])
	assert_eq(Fixture.weaver_chips(six_sky), 1, 'fixture: armed by the crit.')
	await Fixture.cycle_turn(game, six_sky) # the per-turn soft limit refuses a second shot this turn
	var before := Fixture.health(hostile)
	await Fixture.fire_bow(game, six_sky, hostile, [Fixture.HIT_ROLL, 6, 6])
	assert_eq(before - Fixture.health(hostile), 15, 'The NEXT hit deals 1d6+3 plus the Weaver 1d6.')
	assert_eq(Fixture.weaver_chips(six_sky), 0, 'and spends it.')

func test_a_crit_on_a_ground_proxy_offers_only_yourself():
	# Close review: a shot at terrain rolls against a real dep_attack_ground_proxy unit
	# (action_attack_weapon.gd:273-286), whose damage reaction lands wherever it stands. "The target"
	# would carry the terrain damage somewhere the bow never aimed.
	var proxy := TargetActionUtil.create_targeting_proxy(Vector2i(4, 1), null, 1, &'dep_attack_ground_proxy')
	assert_true(Unit.is_valid(proxy), 'PRECONDITION: the proxy is a valid unit, as the engine makes it.')
	responder.multiple_choice_queue.assign([-1])
	await load(Fixture.BOW_SCRIPT).resolve_crit_teleport(SpecFactory.dummy_event(), six_sky, proxy)
	assert_eq(responder.multiple_choice_prompts.size(), 1, 'fixture: the menu was raised.')
	assert_eq(menu_labels().size(), 1, 'Only "Yourself": a targeting proxy is not a target to teleport.')
