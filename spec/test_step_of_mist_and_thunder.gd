# STEP OF MIST AND THUNDER, the Maiden's Blush's core power.
#
#   "Roll 2d6. You teleport to a free space within a Range equal to what you rolled, without
#    requiring line of sight. Characters adjacent to the space you teleport to must make a Systems
#    save or treat you as Invisible until the end of the scene. If you roll two 1s you teleport to a
#    space of the GM's choice. This teleportation cannot be prevented. This ability is Efficient and
#    will refund 1 Core Point at the end of any scene in which this ability was used."
#
# THIS FILE ABSORBS THE SP2 PROBE (test_spike_own_involuntary_teleport.gd), deleted in the same
# commit, for the cases that are about THIS ACTION rather than about the seam: that an Immobilized
# Blush still lands and that one inside a hostile Interdiction Field still lands. The seam-level
# facts stayed with the helper - test_teleport.gd's
# test_move_beats_a_movement_restriction_ban_while_the_pathfinder_route_loses_to_it is the one that
# discriminates the path route from a target tile, and it must outlive this file too.
#
# THE ORDER OF THE ACTION'S BODY IS THE RULING, and these tests are grouped to follow it: a declined
# confirm costs nothing, a cancelled pick costs nothing, and everything past the spend costs the quick
# action and the core point whatever happens next - a fade, a fizzle, a boxed-in snake eyes. "Spends
# nothing" is therefore asserted THREE WAYS everywhere it appears (core point, quick action, Efficient
# stamp), because a test that checks only the core point passes against an implementation that stamped
# the gear anyway.
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const ACTION_ID := &'action_step_of_mist_and_thunder'
const CHIP_ID := &'buff_mist_and_thunder_invisible'

## Room for a 2d6 of 12, and for a wall with standable ground on both sides.
const MAP_SIZE := Vector2i(20, 20)

const BLUSH_TILE := Vector2i(4, 4)
const LANDING := Vector2i(7, 4)

var game:Gamemaster
var blush:Unit
var watcher:PromptWatcher
## testkit/mod_choice_responder.gd - untyped, because its class is loaded at runtime and has no
## registrable class_name (shared/README.md).
var responder

func before_each() -> void:
	# THE QUEUED RESPONDER, not the stock one: pressing Step opens TWO yes/no prompts in one awaited
	# call - its own confirm, and then Uncertainty Field's offer to fade instead - and one answer for
	# both makes the field eat every teleport. See the fixture's own header.
	var pair := MaidensBlushFixture.create_game_with_sequenced_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_plan_queue.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func core_gear() -> GearCore:
	return blush.get_gear(MaidensBlushFixture.CORE_ID)

## The three ways "it spent nothing" has to be true at once.
func assert_spent_nothing(context:String) -> void:
	assert_true(blush.core.has_core_power, '%s: the core point is unspent.' % context)
	assert_eq(blush.state.actions, Lancer.ACTION_COST_FULL, '%s: the quick action is unspent.' % context)
	assert_false(Efficient.is_marked(core_gear()), '%s: the Efficient stamp is not set.' % context)

func press(rolls:Array[int], tile:Vector2i = Tile.INVALID, fade:bool = false) -> void:
	await MaidensBlushFixture.step(game, blush, responder, rolls, tile, fade)

## What the picker would offer for a given roll - the same call the action makes, so a test asserting
## on this is asserting on the real set rather than on a re-derivation of it.
func offered(within:int) -> Array[Vector2i]:
	return Teleport.candidate_tiles(blush, within, false)

func chip_on(character:Unit) -> BuffCore:
	for buff_core:BuffCore in character.state.buffs:
		if buff_core.base.compcon_id == CHIP_ID: return buff_core
	return null

# ---------------------------------------------------------------- the confirm

func test_the_confirm_is_asked():
	await MaidensBlushFixture.open_turn(game, blush)
	await press([3, 4])
	# THE RESPONDER records yes/no prompts, not the watcher: PromptWatcher keeps one `prompts` array of
	# {kind, info} and exposes kinds() over it (prompt_watcher.gd:28,56), while
	# mod_choice_responder.gd keeps the typed yesno_prompts list this needs.
	assert_true(responder.yesno_prompts.size() >= 1, 'Pressing it opens a yes/no confirm.')
	assert_string_contains(responder.yesno_prompts[0].title, 'Step of Mist and Thunder',
		'And it is Step asking, named from its own localisation row.')

func test_declining_the_confirm_spends_nothing():
	await MaidensBlushFixture.open_turn(game, blush)
	responder.yesno_queue.append(false) # decline the confirm; nothing else is ever asked
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	assert_eq(blush.tile(), BLUSH_TILE, 'It did not move.')
	assert_spent_nothing('Declined')

func test_cancelling_the_pick_spends_nothing():
	# Blinkspace's behaviour, and the reason the spend sits below the pick rather than above the roll.
	await MaidensBlushFixture.open_turn(game, blush)
	responder.yesno_queue.append_array([true, false])
	responder.abort_all = true
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	responder.abort_all = false
	assert_eq(blush.tile(), BLUSH_TILE, 'It did not move.')
	assert_spent_nothing('Cancelled')

# ---------------------------------------------------------------- the range

func test_the_offered_set_is_every_standable_tile_within_the_rolled_total():
	var tiles := offered(7)
	assert_false(tiles.is_empty(), 'There is something to offer.')
	assert_false(tiles.any(func(tile:Vector2i) -> bool: return Tile.distance(tile, BLUSH_TILE) > 7),
		'Nothing beyond the roll.')
	assert_true(tiles.any(func(tile:Vector2i) -> bool: return Tile.distance(tile, BLUSH_TILE) == 7),
		'And the edge of it IS offered, so the assertion above is not vacuous.')

func test_a_standable_tile_behind_a_wall_is_offered():
	# "without requiring line of sight" - the clause, tested against real geometry.
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior',
		[Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5)])
	game.map.calculate_los_blockers()
	assert_true(offered(5).has(Vector2i(8, 4)), 'Blind, the tile past the wall is offered.')
	assert_false(Teleport.candidate_tiles(blush, 5, true).has(Vector2i(8, 4)),
		'Sighted it is not, so the wall really blocks.')

# ---------------------------------------------------------------- the spend and the landing

func test_picking_spends_the_quick_action_and_the_core_point_and_lands_the_mech():
	await MaidensBlushFixture.open_turn(game, blush)
	await press([3, 4], LANDING)
	assert_eq(blush.tile(), LANDING, 'It landed where we picked.')
	assert_false(blush.core.has_core_power, 'The core point is spent.')
	assert_ne(blush.state.actions, Lancer.ACTION_COST_FULL, 'And the quick action with it.')

func test_the_efficient_stamp_is_set_on_use():
	await MaidensBlushFixture.open_turn(game, blush)
	await press([3, 4], LANDING)
	assert_true(Efficient.is_marked(core_gear()),
		'Which is what gets the point back at the end of the scene.')

func test_a_second_press_in_the_same_turn_is_refused():
	await MaidensBlushFixture.open_turn(game, blush)
	await press([3, 4], LANDING)
	var landed := blush.tile()
	await press([3, 4], BLUSH_TILE)
	assert_eq(blush.tile(), landed, 'The second press moved nothing.')

# ---------------------------------------------------------------- "cannot be prevented"

func test_an_immobilized_blush_still_lands():
	# THE CLAUSE THE WHOLE SHAPE EXISTS FOR, and half of what the SP2 probe measured. Both Immobilized
	# gates test movement_type.voluntary - pathfinder.gd:333 and event_unit_move.gd:451 - and
	# Teleport.move issues an INVOLUNTARY type, so neither bites.
	await MaidensBlushFixture.open_turn(game, blush)
	UnitCondition.apply_status(SpecFactory.dummy_event(), blush,
		Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	assert_true(UnitCondition.is_immobilized(blush), 'Fixture: immobilized.')
	await press([3, 4], LANDING)
	assert_eq(blush.tile(), LANDING, 'Immobilized does not stop it.')

func test_a_blush_inside_a_hostile_interdiction_field_still_lands():
	# The other half. Teleport.move sends an explicit single-step path, so event_unit_move never
	# builds a pathfinder (event_unit_move.gd:137-138 against :139-145) and no MOVEMENT_RESTRICTION
	# ban is ever read. The hostile must be within 3 for the field's lockdown branch - see the
	# fixture's equip_interdiction header.
	await MaidensBlushFixture.open_turn(game, blush)
	var hostile := MaidensBlushFixture.create_hostile(game, Vector2i(6, 4))
	MaidensBlushFixture.equip_interdiction(hostile)
	await press([3, 4], LANDING)
	assert_eq(blush.tile(), LANDING, 'The Interdiction Field does not stop it either.')

# ---------------------------------------------------------------- the saves and the chip

func test_every_character_adjacent_to_the_destination_rolls_a_systems_save():
	await MaidensBlushFixture.open_turn(game, blush)
	var adjacent := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4)) # adjacent to LANDING
	var distant := MaidensBlushFixture.create_hostile(game, Vector2i(12, 12))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1]) # the 2d6, then a save low enough to fail
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	assert_not_null(chip_on(adjacent), 'The adjacent character rolled, and failed.')
	assert_null(chip_on(distant), 'The one at range never rolled at all.')

func test_an_ally_adjacent_to_the_destination_rolls_too():
	# Verbatim over hostile-only (ruling 13): the card says "characters". An ally's chip is inert
	# except against ally-targeting attacks such as the Myconid's Uffish Gyre.
	await MaidensBlushFixture.open_turn(game, blush)
	var ally := MaidensBlushFixture.create_ally(game, Vector2i(8, 4))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	assert_not_null(chip_on(ally), 'Allies save too, and can fail.')

func test_the_fooled_enemy_sees_the_blush_as_invisible_and_another_enemy_does_not():
	await MaidensBlushFixture.open_turn(game, blush)
	var fooled := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	var other := MaidensBlushFixture.create_hostile(game, Vector2i(12, 12))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)

	assert_true(UnitCondition.is_invisible(blush, fooled), 'The one that failed cannot see it.')
	assert_false(UnitCondition.is_invisible(blush, other), 'The one that never rolled can.')

func test_the_blush_attacking_the_fooled_enemy_is_unaffected():
	# THE OWNER CLAUSE'S GUARD, and the one with no symptom until it bites.
	# get_invisibility_summary collects TREAT_AS_INVISIBLE buffs off BOTH context units with the same
	# context (unit_condition.gd:446-469) without tracking whose is whose - so without the
	# `context.target_unit == core.get_owner_unit(map)` clause, the Blush attacking its own victim
	# would find the VICTIM invisible.
	await MaidensBlushFixture.open_turn(game, blush)
	var fooled := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)

	assert_not_null(chip_on(fooled), 'Fixture: the chip landed.')
	assert_false(UnitCondition.is_invisible(fooled, blush),
		'The Blush sees its victim perfectly well - the chip only runs one way.')

func test_a_chip_from_one_blush_does_not_hide_a_second_one():
	# THE OWNER CLAUSE'S REAL GUARD, and the reason it is not redundant with the holder clause.
	# get_invisibility_summary collects TREAT_AS_INVISIBLE buffs off BOTH context units with the same
	# context (unit_condition.gd:446-469) without tracking whose is whose. The holder clause stops the
	# chip firing when the BLUSH attacks - measured, by deleting the owner clause and watching
	# test_the_blush_attacking_the_fooled_enemy_is_unaffected stay green. What only the owner clause
	# stops is this: a character fooled by one Maiden's Blush treating a DIFFERENT one as invisible,
	# having never been adjacent to anything the second one did.
	await MaidensBlushFixture.open_turn(game, blush)
	var fooled := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	var other_blush := MaidensBlushFixture.create_maidens_blush(game, Vector2i(2, 9))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)

	assert_true(UnitCondition.is_invisible(blush, fooled), 'Fixture: it cannot see the one that folded.')
	assert_false(UnitCondition.is_invisible(other_blush, fooled),
		"But the other Maiden's Blush is perfectly visible - the chip belongs to one mech.")

func test_a_passed_save_hangs_no_chip():
	# The negative control for every chip assertion above.
	await MaidensBlushFixture.open_turn(game, blush)
	var lucky := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 20]) # a save it cannot fail
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	assert_null(chip_on(lucky), 'Passing the save leaves nothing behind.')

func test_the_chip_survives_turns_and_the_fooled_units_own_attack():
	# "until the end of the scene", and the clause that delivers it is is_onetime = false:
	# AttackUtil.check_if_invisibility_forces_miss consumes only ONE-TIME buffs (attack_util.gd:59-76),
	# so a persistent chip keeps applying to every attack its holder makes at the Blush. A one-time
	# chip would read identically until the holder's first shot and then silently be gone.
	await MaidensBlushFixture.open_turn(game, blush)
	var fooled := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.append_array([true, false]) # confirm yes, fade no
	responder.chosen_plan_queue.append(CompconPlan.create([LANDING], [], []))
	Dice.CHEAT_ROLL_QUEUE.append_array([3, 4, 1])
	await SpecFactory.use(game, blush, MaidensBlushFixture.CORE_ID, ACTION_ID)
	assert_not_null(chip_on(fooled), 'Fixture: the chip landed.')

	# A full round of turns, and then the holder shoots at the Blush.
	await SpecFactory.end_turn(game, blush)
	await MaidensBlushFixture.miss_from(game, fooled, blush)

	assert_not_null(chip_on(fooled), 'Still worn after a turn and an attack.')
	assert_true(UnitCondition.is_invisible(blush, fooled), 'And still applying.')

# ---------------------------------------------------------------- snake eyes

func test_snake_eyes_skips_the_picker_and_lands_within_two():
	# Ruling 9. The third cheat value is the random destination index, drawn through Dice so a spec
	# can fix it - which is the whole reason pick_random_tile does not use Array.pick_random.
	await MaidensBlushFixture.open_turn(game, blush)
	await press([1, 1, 1])
	assert_ne(blush.tile(), BLUSH_TILE, 'It moved.')
	assert_true(Tile.distance(blush.tile(), BLUSH_TILE) <= 2, 'And no further than 2.')

func test_snake_eyes_still_spends_the_core_point_and_stamps_the_gear():
	await MaidensBlushFixture.open_turn(game, blush)
	await press([1, 1, 1])
	assert_false(blush.core.has_core_power, 'The point is spent.')
	assert_true(Efficient.is_marked(core_gear()), 'And the stamp set, so Efficient still refunds it.')

# ---------------------------------------------------------------- the field takes it

func test_the_field_offers_on_step_and_a_veto_leaves_the_point_spent_and_no_save_rolled():
	# RULING 4 END TO END, and the most valuable test in this file: the real Uncertainty Field on the
	# real frame, a real Step, a real veto, and then the ABSENCE of a save. The absence is asserted
	# positively - the adjacent character wears no chip - rather than by nothing having crashed.
	await MaidensBlushFixture.open_turn(game, blush)
	var adjacent := MaidensBlushFixture.create_hostile(game, Vector2i(8, 4))
	await press([3, 4], LANDING, true) # this time the player TAKES the fade

	assert_eq(blush.tile(), BLUSH_TILE, 'The field replaced the teleport, so it never moved.')
	assert_true(blush.has_status(Lancer.STATUS.INVISIBLE), 'It faded instead.')
	assert_false(blush.core.has_core_power, 'The core point stays spent (ruling 4).')
	assert_true(Efficient.is_marked(core_gear()), 'And Efficient still refunds it at scene end.')
	assert_null(chip_on(adjacent), 'Nobody saved: the save is a consequence of arriving.')
