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
# already holding 2 Overshield keeps 2.
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

## Movement pickers the BLOOD opened (its pick_move carries the core Kit as `gear`).
func blood_move_prompts() -> Array[Dictionary]:
	var found:Array[Dictionary] = []
	for info:Dictionary in watcher.kinds(PromptWatcher.KIND.move_tile):
		var using = info.get('using')
		if using is SpecificAction and GearCore.is_valid(using.gear) \
				and using.gear.kit.compcon_id == NagaFixture.CORE_ID:
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
