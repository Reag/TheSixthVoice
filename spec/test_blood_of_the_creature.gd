# THE BLOOD OF THE CREATURE THAT BRINGS ABOUT THE BEGINNING OF DAYS (Naga core passive, SP1 Task 4),
# ruling 7:
#   "1/round, when you or an allied character within sensors consume Lock On, you may take 1 heat to
#    have the triggering character gain 1 OVERSHIELD and move 3 spaces. This movement ignores
#    engagement and doesn't provoke reactions."
#
# An `attack` POST reaction on cp_shimmering_veil in Autopod's shape, reading the consumption off
# the roll through the shared Lock-on hook. WHAT THIS FILE PROVES (design 1.4): the Naga consumes
# Lock On and is offered (the 1 heat lands, Overshield 1, a 3-space picker for the Naga); an ally
# within Sensors consuming is offered and the ALLY moves; an ally one tile outside Sensors is not;
# a drone cannot consume at all (no basic gear - measured) and the gate reads is_actor through the
# owner (ruling 21); an invade consuming
# Lock On offers; an attack that does not consume does not; a hostile consuming a lock on the Naga's
# ally does not; declining costs nothing; a second consumption in the round is not offered; an ally
# already holding 2 Overshield keeps 2. Added at the frame close (2026-09-23): the enemy-target gate
# on its own; a size-3 Heavy Frame ally still moves (the pick_move carries no `unit`); the move
# passes a NEW engagement; the move draws no Overwatch.
#
# TWO YES/NO PROMPTS PER CONSUMING SHOT, AND THEY NEED DIFFERENT ANSWERS: the attacker's own
# attack_declared consume prompt ("consume the lock?") and then the Naga's "take 1 heat?". The stock
# responder answers both the same way, so this file uses testkit/mod_choice_responder.gd through
# NagaFixture.create_game_with_prompt_queues: yesno_queue is consumed front to back, and every
# yes/no it saw is in yesno_prompts - which is what lets "was not offered" be asserted as a prompt
# count rather than only as an absence of heat. THE AI CONSUMES WITHOUT ASKING
# (action_consume_lock_on.gd:52), so a HOSTILE attacker's shot raises no consume prompt.
#
# DICE. A rifle shot that consumes pops the d20, then ONE accuracy die (buff_lock_consumed's +1),
# then the damage die; the invade pops the d20 alone (a tech attack's flat '2' rolls nothing). The
# queue tails with 1s. No save, no structure: the dummies have 200 HP.
#
# GEOMETRY. The Naga (size 2) at (4,4) occupies (4,4)-(5,5); Sensors 8, measured from its closest
# tile. IN_SENSORS (13,4) is 8 from (5,4); OUT_OF_SENSORS (14,4) is 9. The hostile they shoot stands
# at (9,4): 4 from the Naga, 4-5 from the allies, inside everyone's rifle range 10 and Lock On's
# Sensors. THREE_EAST (7,4) is where the responder sends the mover, 3 from (4,4).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_blood_of_the_creature.gd
extends GutTest

const NagaFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/naga_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const NAGA_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(9, 4)
const IN_SENSORS := Vector2i(13, 4)      # 8 from (5,4)
const OUT_OF_SENSORS := Vector2i(14, 4)  # 9 from (5,4)
const THREE_EAST := Vector2i(7, 4)       # the Naga's 3-space destination
const ALLY_THREE_SOUTH := Vector2i(13, 7) # the in-Sensors ally's 3-space destination
const SECOND_HOSTILE_TILE := Vector2i(9, 7)

var game:Gamemaster
var responder
var watcher:PromptWatcher
var naga:Unit
var hostile:Unit

func before_each() -> void:
	var pair := NagaFixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	naga = NagaFixture.create_naga(game, NAGA_TILE)
	hostile = NagaFixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

## The yes/no prompts whose title is the Blood's confirm - every OTHER yes/no in a consuming shot is
## the consume prompt. confirm_use_alt titles its prompt with the action's name, so the Blood's own
## name row is the filter.
func blood_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	var blood_name:String = X.tr('gear.cp_shimmering_veil.action_blood_of_the_creature.name')
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(blood_name) or String(seen.get('desc', '')).contains(blood_name):
			found.append(seen)
	return found

## Movement pickers the BLOOD opened. Since the frame close its pick_move carries NO `unit` (the
## Heavy Frame fix), so SpecificAction.is_valid fails and ask_for_movement_alt takes its no-ability
## branch (target_action_util.gd:111-114), which opens choose_move_tile WITHOUT a `using` - the core
## Kit no longer rides on the prompt. So a Blood picker is told apart by its BUDGET: 3, where Wire
## Slither's (the other picker a consuming INVADE opens) is 2 and carries its own Kit.
func blood_move_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for info:Dictionary in watcher.kinds(PromptWatcher.KIND.move_tile):
		var using = info.get('using')
		if using is SpecificAction and GearCore.is_valid(using.gear) \
				and using.gear.kit.compcon_id != NagaFixture.CORE_ID:
			continue
		var pathfinder:Pathfinder = info.get('pathfinder')
		if pathfinder != null and pathfinder.max_budget == 3:
			found.append(info)
	return found

func uses_this_round() -> int:
	return NagaFixture.uses_this_round(naga, NagaFixture.CORE_ID, NagaFixture.BLOOD_ID)

## Lock the target BY HAND with `locker`'s ms_lock_on as the source (NagaFixture.lock_by_hand's
## header says why not a real Lock On: the Naga's own would offer Wire Slither and move it), then
## have `shooter` fire a rifle at it, answering the consume prompt YES (for a player shooter - the
## AI consumes without asking) and the Blood's prompt with `blood_answer`.
func lock_and_shoot(locker:Unit, shooter:Unit, target:Unit, blood_answer:bool = true) -> void:
	assert_true(NagaFixture.lock_by_hand(locker, target), 'fixture: the lock landed.')
	NagaFixture.arm_rifle(shooter)
	responder.yesno_queue.clear()
	if shooter.is_player_controlled(): responder.yesno_queue.append(true) # consume
	responder.yesno_queue.append(blood_answer)
	NagaFixture.queue([19, 3, 3])
	await NagaFixture.shoot(game, shooter, target)

# ---------------------------------------------------------------- the wiring

func test_the_core_kit_and_its_three_actions_are_registered() -> void:
	var kit:Kit = ContentLibrary.get_kit(NagaFixture.CORE_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % NagaFixture.CORE_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'A frame trait.')
	var ids:Array = kit.actions.map(func(action:Action) -> StringName: return action.get_id())
	assert_eq(ids, [NagaFixture.SALVATION_ID, NagaFixture.RELOCK_ID, NagaFixture.BLOOD_ID] as Array,
		'The protocol, its hidden relock, and the passive\'s reaction, in that order.')
	assert_true(GearCore.is_valid(naga.get_gear(NagaFixture.CORE_ID)), 'The live Naga carries it.')
	var blood:ActionReaction = kit.get_action(NagaFixture.BLOOD_ID)
	assert_eq(blood.triggers_on, [&'attack'] as Array[StringName], 'The Blood reacts to attacks...')
	assert_eq(blood.trigger_timing, ReactionBus.TIMING.POST, '...at POST, with the roll in context.')
	assert_false(blood.consumes_rxn, 'A trait, not a reaction point.')
	assert_eq(blood.get_per_round_hard_limit(SpecificAction.create(naga, naga.get_gear(NagaFixture.CORE_ID), blood)), 1, '1/round.')
	assert_true(blood.show_in_tooltip(kit), 'The Blood IS the card\'s passive line: it shows on the Kit.')
	var relock:ActionReaction = kit.get_action(NagaFixture.RELOCK_ID)
	assert_false(relock.show_in_tooltip(kit), 'The relock is bookkeeping and hides.')

func test_the_rows_resolve() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_shimmering_veil.name', 'gear.cp_shimmering_veil.effect',
			'gear.cp_shimmering_veil.action_blood_of_the_creature.name',
			'gear.cp_shimmering_veil.action_blood_of_the_creature.effect',
			'gear.cp_shimmering_veil.action_blood_of_the_creature.trigger']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_shimmering_veil.name'), 'Shimmering Veil', 'Named off the card.')

# ---------------------------------------------------------------- the offer

func test_the_naga_consuming_lock_on_is_offered_and_pays_a_heat_for_a_shield_and_a_move() -> void:
	responder.chosen_move_tile = THREE_EAST
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(naga, naga, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the shot consumed the lock.')
	assert_eq(blood_prompts().size(), 1, 'The Naga was asked once: "take 1 heat?"')
	assert_eq(naga.core.current.heat, heat_before + 1, 'It paid 1 heat.')
	assert_eq(Overshield.current(naga), 1, 'The triggering character - the Naga itself - gained 1 Overshield.')
	assert_eq(blood_move_prompts().size(), 1, 'And was offered a move...')
	assert_eq(naga.tile(), THREE_EAST, '...of 3 spaces, to where the responder chose.')
	assert_eq(uses_this_round(), 1, 'The Blood is spent for the round.')

func test_an_ally_within_sensors_consuming_is_offered_and_the_ally_moves() -> void:
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	assert_eq(UnitRelation.distance_between(naga, ally), 8, 'fixture: exactly Sensors (8) away.')
	responder.chosen_move_tile = ALLY_THREE_SOUTH
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(ally, ally, hostile)
	assert_eq(blood_prompts().size(), 1, 'The NAGA was asked - it is the Naga that pays.')
	assert_eq(naga.core.current.heat, heat_before + 1, 'The Naga paid 1 heat...')
	assert_eq(Overshield.current(ally), 1, '...and the ALLY gained the Overshield...')
	assert_eq(Overshield.current(naga), 0, '...not the Naga.')
	assert_eq(ally.tile(), ALLY_THREE_SOUTH, 'And the ALLY moved 3, driven by its own controller.')
	assert_eq(naga.tile(), NAGA_TILE, 'The Naga stayed.')

func test_an_ally_one_tile_outside_sensors_is_not_offered() -> void:
	var ally := NagaFixture.create_ally(game, OUT_OF_SENSORS)
	assert_eq(UnitRelation.distance_between(naga, ally), 9, 'fixture: one past Sensors.')
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(ally, ally, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally did consume the lock.')
	assert_true(blood_prompts().is_empty(), 'No prompt: the ally is outside Sensors.')
	assert_eq(naga.core.current.heat, heat_before, 'No heat.')
	assert_eq(Overshield.current(ally), 0, 'No shield.')
	assert_eq(uses_this_round(), 0, 'Nothing spent.')

func test_a_drone_cannot_consume_at_all_and_the_gate_reads_is_actor_through_the_owner() -> void:
	# MEASURED, AND NOT WHAT THE DESIGN EXPECTED: a drone CANNOT consume Lock On in this engine.
	# loadout_core.gd:179 gives a drone frame NO basic gear at all, so it carries no ms_lock_on - and
	# the consume reaction lives on that Kit. So "an allied drone consuming" is not a case the board
	# can produce; the first version of this test locked with the drone's own gear, got false back,
	# and was vacuous. What CAN be pinned is (1) that fact, (2) the gate on an unowned drone, and (3)
	# ruling 21's owner resolution at the gate: an OWNED drone's consumer resolves to the Naga.
	var drone := NagaFixture.create_drone(game, IN_SENSORS)
	assert_true(drone.is_character(), 'RULE: a drone IS a character to the engine (unit.gd:116)...')
	assert_false(drone.is_actor(), '...and is NOT an actor (:117), which is what "character" means on this frame.')
	assert_false(GearCore.is_valid(drone.get_gear(NagaFixture.LOCK_ON)),
		'ENGINE: a drone has no basic gear (loadout_core.gd:179), so no ms_lock_on and no consume reaction.')
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(naga, drone, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.LOCKON),
		'MEASURED: the shot of the drone left the lock in place - nothing on a drone can consume one.')
	assert_gt(hostile.current_damage(), 0, 'LIVENESS: the shot of the drone did land.')
	assert_true(blood_prompts().is_empty(), 'So nothing was offered.')
	assert_eq(naga.core.current.heat, heat_before, 'No heat.')

	# The gate itself, read directly (ruling 21). Unowned: not an actor, refused. Owned by the Naga:
	# the hook resolves the consumer to the OWNER (Unit.get_attacker -> get_owner_unit_or_self,
	# unit.gd:270-282), and the owner is the Naga itself - "you".
	var blood:Script = load('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_naga/cp_shimmering_veil/action_blood_of_the_creature.gd')
	assert_false(blood.is_you_or_an_allied_character_within_sensors(naga, drone),
		'An unowned drone is not "an allied character".')
	NagaFixture.own_drone(drone, naga)
	var resolved:Unit = Lockon.consumer(Context.create({unit = drone}))
	assert_eq(resolved, naga, 'The consumer of an OWNED drone resolves to its owner, the Naga.')
	assert_true(blood.is_you_or_an_allied_character_within_sensors(naga, resolved),
		'And the Naga is "you": the gate would open for a consumption by an owned drone, if one could exist.')

func test_an_invade_consuming_lock_on_offers_too() -> void:
	responder.chosen_move_tile = THREE_EAST
	assert_true(NagaFixture.lock_by_hand(naga, hostile), 'fixture: locked.')
	responder.yesno_queue.clear()
	responder.yesno_queue.append_array([true, true]) # consume, then take the heat
	NagaFixture.queue([19])
	var heat_before:int = naga.core.current.heat
	await NagaFixture.invade(game, naga, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the invade consumed the lock.')
	assert_eq(blood_prompts().size(), 1, 'A tech attack consuming Lock On is a consumption: asked.')
	assert_eq(naga.core.current.heat, heat_before + 1, 'Paid.')
	assert_eq(Overshield.current(naga), 1, 'Shielded.')
	assert_eq(naga.tile(), THREE_EAST, 'Moved.')

func test_an_attack_that_consumes_nothing_offers_nothing() -> void:
	NagaFixture.arm_rifle(naga)
	responder.yesno_queue.clear()
	responder.yesno_queue.append(true)
	NagaFixture.queue([19, 3])
	var heat_before:int = naga.core.current.heat
	await NagaFixture.shoot(game, naga, hostile)
	assert_gt(hostile.current_damage(), 0, 'LIVENESS: the shot landed.')
	assert_true(blood_prompts().is_empty(), 'No lock was consumed: nothing to offer.')
	assert_eq(naga.core.current.heat, heat_before, 'No heat.')
	assert_eq(uses_this_round(), 0, 'Nothing spent.')

func test_a_hostile_consuming_a_lock_on_the_nagas_ally_offers_nothing() -> void:
	# "You or an allied character" - and the locked target must be an ENEMY of the Naga. Here the
	# hostile locks and shoots an ALLY: a consumption, but not one of ours. The AI consumes with no
	# prompt, so the queue holds only the Blood's would-be answer.
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(hostile, hostile, ally)
	assert_false(ally.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the hostile consumed its lock on the ally.')
	assert_true(blood_prompts().is_empty(), 'A hostile\'s consumption is not "you or an allied character".')
	assert_eq(naga.core.current.heat, heat_before, 'No heat.')

func test_the_locked_target_must_be_an_enemy_of_the_naga_on_its_own() -> void:
	# The ENEMY gate (action_blood_of_the_creature.gd:53) ALONE (close review slice 2 #5): the test
	# above fails it together with the consumer gate. No board produces a consumption on a non-enemy -
	# vanilla's consume refuses one (action_consume_lock_on.gd:62-67) and factions are symmetric
	# (faction.gd:22-26) - so the gate is read on a synthesized attack event instead: the Naga itself
	# consuming ("you", so the consumer gate passes), the consumed buff on the target (Lockon's
	# attack_declared shape), and only the target's faction changed between the two.
	var blood:ActionReaction = ContentLibrary.get_kit(NagaFixture.CORE_ID).get_action(NagaFixture.BLOOD_ID)
	var core := naga.get_gear(NagaFixture.CORE_ID)
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	SpecFactory.apply_buff(ally, Lockon.CONSUMED_BUFF)
	SpecFactory.apply_buff(hostile, Lockon.CONSUMED_BUFF)
	var on_ally_targets:Array[Unit] = [ally]
	var on_hostile_targets:Array[Unit] = [hostile]
	var on_ally := EventCore.create(&'event_unit_attack', {unit = naga, target_units = on_ally_targets})
	var on_hostile := EventCore.create(&'event_unit_attack', {unit = naga, target_units = on_hostile_targets})
	assert_true(Lockon.was_consumed(on_ally.context), 'LIVENESS: the synthesized event reads as a consumption.')
	assert_eq(Lockon.consumer(on_ally.context), naga, 'LIVENESS: by the Naga - "you".')
	assert_true(blood.triggers_on_event(naga, core, on_hostile),
		'CONTROL: the same event on a HOSTILE target triggers - every other gate is open.')
	assert_false(blood.triggers_on_event(naga, core, on_ally),
		'THE CLAIM: an ALLIED locked target refuses it, on the enemy gate alone.')

# ---------------------------------------------------------------- the move

## Size 3 with Heavy Frame's knockback immunity, which compares the mover to the pick_move's `unit`
## (buff_heavy_frame_knockback.gd: immune when context.unit is SMALLER) - and
## event_unit_pick_move.gd:78 aborts every non-shunt pick_move on that immunity.
func test_a_size_three_heavy_frame_ally_still_moves() -> void:
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	SpecFactory.change_size(ally, 3)
	UnitTile.move_to(ally, IN_SENSORS)
	SpecFactory.apply_buff(ally, &'buff_heavy_frame_knockback')
	assert_eq(ally.get_size(), 3, 'fixture: size 3.')
	assert_eq(UnitRelation.distance_between(naga, ally), 8, 'fixture: within Sensors.')
	var core := naga.get_gear(NagaFixture.CORE_ID)
	var blood:Action = core.kit.get_action(NagaFixture.BLOOD_ID)
	assert_true(UnitCondition.is_immune_to_knockback_from(ally, SpecificAction.create(naga, core, blood),
			MovementType.create(ally, true)),
		'LIVENESS: a move attributed to the size-2 Naga WOULD be refused as knockback.')
	responder.chosen_move_tile = ALLY_THREE_SOUTH
	await lock_and_shoot(ally, ally, hostile)
	assert_false(hostile.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally consumed the lock.')
	assert_eq(blood_prompts().size(), 1, 'Offered and taken.')
	assert_eq(Overshield.current(ally), 1, 'Shielded.')
	assert_eq(ally.tile(), ALLY_THREE_SOUTH,
		'THE CLAIM: the ally chooses its own move - no `unit` on the pick_move, as Perimeter Command Plate.')

## THE ENGAGEMENT GEOMETRY - test_wire_slither.gd's, one budget higher. The Naga at (4,4) occupies
## (4,4)-(5,5); a SIZE-2 hostile at (1,4) occupies (1,4)-(2,5), two out (no engagement yet), and
## engages anchors with x <= 3 and y 2-6. ENGAGED_DESTINATION (2,2) is two steps from (4,4) through
## (3,3), an engaged anchor with no outward connections (pathfinder.gd:454); the unengaged way round
## ((4,3) or (5,3), (4,2), (3,1), (2,2)) is FOUR steps, one past the Blood's 3. Size 2 because a
## size-1 hostile never stops a size-2 mover (unit_relation.gd:140-143); inside the budget-3 scan
## ring because an engager outside it marks nothing (pathfinder.gd:256).
const ENGAGER_TILE := Vector2i(1, 4)
const ENGAGED_DESTINATION := Vector2i(2, 2)

func test_the_move_ignores_engagement() -> void:
	var engager := NagaFixture.create_hostile(game, ENGAGER_TILE)
	SpecFactory.change_size(engager, 2)
	UnitTile.move_to(engager, ENGAGER_TILE)
	assert_eq(UnitRelation.distance_between(naga, engager), 2, 'fixture: two out - a NEW engagement.')
	var control := await Pathfinder.generate_for_movement_budget(naga, 3, MovementType.create(naga, true))
	assert_false(control.is_movable(ENGAGED_DESTINATION),
		'CONTROL: a plain voluntary 3-space move cannot reach it - the zone stops it at (3,3).')
	responder.chosen_move_tile = ENGAGED_DESTINATION
	await lock_and_shoot(naga, naga, hostile)
	assert_eq(blood_prompts().size(), 1, 'LIVENESS: offered and taken.')
	assert_eq(blood_move_prompts().size(), 1, 'LIVENESS: the picker opened.')
	assert_eq(naga.tile(), ENGAGED_DESTINATION, 'THE CLAIM: "ignores engagement" - it slid past the zone.')

func test_the_move_provokes_no_overwatch() -> void:
	# A rifle hostile adjacent to the Naga's (4,5): its threat 1 covers the Naga's start, and the
	# Blood's move walks the Naga out of it. The dice tail is 1s, and the rifle's Reliable 2 lands
	# even on a miss - BUT THE BLOOD'S OWN OVERSHIELD, granted before the move, soaks that 1 (2 less
	# the Naga's 1 armor): measured, a mutated move drew the Overwatch and current_damage stayed 0.
	# So the claim is read off the Overwatch's own tally, with the shield as a second witness.
	var watcher_hostile := NagaFixture.create_hostile(game, Vector2i(3, 6))
	NagaFixture.arm_rifle(watcher_hostile)
	assert_eq(UnitRelation.distance_between(naga, watcher_hostile), 1, 'fixture: adjacent - in threat 1.')
	responder.chosen_move_tile = THREE_EAST
	await lock_and_shoot(naga, naga, hostile)
	assert_eq(naga.tile(), THREE_EAST, 'LIVENESS: the Blood moved the Naga out of the threat.')
	assert_eq(NagaFixture.uses_this_round(watcher_hostile, &'ms_overwatch', &'action_overwatch'), 0,
		'THE CLAIM: "doesn\'t provoke reactions" - the adjacent rifle never Overwatched.')
	assert_eq(Overshield.current(naga), 1, 'And the Blood\'s shield is untouched.')
	assert_eq(naga.current_damage(), 0, 'No damage.')

# ---------------------------------------------------------------- "may" and 1/round

func test_declining_costs_nothing_and_the_round_is_still_open() -> void:
	var heat_before:int = naga.core.current.heat
	await lock_and_shoot(naga, naga, hostile, false)
	assert_eq(blood_prompts().size(), 1, 'Asked once...')
	assert_eq(naga.core.current.heat, heat_before, '...declined: no heat.')
	assert_eq(Overshield.current(naga), 0, 'No shield.')
	assert_true(blood_move_prompts().is_empty(), 'No move.')
	assert_eq(naga.tile(), NAGA_TILE, 'Stayed put.')
	assert_eq(uses_this_round(), 0, '"MAY": declining spends nothing - the spend runs only after a yes.')

	# The next consumption that round is offered again.
	var second := NagaFixture.create_hostile(game, SECOND_HOSTILE_TILE)
	responder.chosen_move_tile = THREE_EAST
	await lock_and_shoot(naga, naga, second, true)
	assert_eq(blood_prompts().size(), 2, 'Asked again on the next consumption.')
	assert_eq(naga.core.current.heat, heat_before + 1, 'This time it paid.')
	assert_eq(naga.tile(), THREE_EAST, 'And moved.')

func test_a_second_consumption_in_the_round_is_not_offered() -> void:
	responder.chosen_move_tile = THREE_EAST
	await lock_and_shoot(naga, naga, hostile)
	assert_eq(uses_this_round(), 1, 'fixture: spent on the first consumption.')
	var heat_after_first:int = naga.core.current.heat
	# The second shot is the NAGA's again, in the same round: shoot() cycles the Naga's turn, which
	# WOULD reset its per-round tally (event_turn_start.gd:79). So the second consumer is an ALLY
	# whose turn cycle leaves the Naga's tallies alone.
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	var second := NagaFixture.create_hostile(game, SECOND_HOSTILE_TILE)
	await lock_and_shoot(ally, ally, second)
	assert_false(second.has_status(Lancer.STATUS.LOCKON), 'LIVENESS: the ally consumed a second lock.')
	assert_eq(blood_prompts().size(), 1, '1/ROUND: not asked a second time.')
	assert_eq(naga.core.current.heat, heat_after_first, 'No second heat.')
	assert_eq(Overshield.current(ally), 0, 'No shield for the ally.')

func test_an_ally_already_holding_two_overshield_keeps_two() -> void:
	# Overshield.grant is the engine's max(old, amount) (event_unit_overshield.gd:15) - Lancer's own
	# rule, recorded in ruling 7: "gain 1 OVERSHIELD" on a unit holding 2 changes nothing.
	var ally := NagaFixture.create_ally(game, IN_SENSORS)
	await NagaFixture.grant_overshield(ally, 2)
	assert_eq(Overshield.current(ally), 2, 'fixture: holding 2.')
	responder.chosen_move_tile = ALLY_THREE_SOUTH
	await lock_and_shoot(ally, ally, hostile)
	assert_eq(blood_prompts().size(), 1, 'Offered and taken...')
	assert_eq(Overshield.current(ally), 2, '...and the shield stays 2: max semantics, not additive.')
	assert_eq(ally.tile(), ALLY_THREE_SOUTH, 'The move still happens.')
