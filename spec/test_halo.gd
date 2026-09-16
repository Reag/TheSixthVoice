# HALO (Myconid trait, SP1 Task 5).
#
#   "1/round, when the Myconid takes damage, an allied character within Sensors gains OVERSHIELD
#    equal to GRIT."
#
# WHAT "TAKES DAMAGE" MEANS HERE (ruling, 2026-09-15): any event_unit_damage of a type other than
# HEAT that lands a positive number on the Myconid.
#
# THE PLAN WAS WRONG ABOUT WHO ENFORCES THE "POSITIVE" HALF, and this file is where it showed.
# event_unit_damage.gd:93 aborts on `damage_modifications.capped_damage <= 0`, but capped_damage is a
# damage CAP contributed by BuffResistDamage.FLAG.CAP buffs - grunt save, paradox shield, flash aegis
# - defaulting to 9999 (damage_modifications.gd:11, :69). ARMOR NEVER TOUCHES IT. Armor reduces
# `context.number` instead, so a hit entirely stopped by armor sails past :93 and queues DAMAGE POST
# at :196 with number 0. Measured 2026-09-16: with no such clause in the gate,
# test_a_hit_zeroed_by_armor_does_not_offer_halo went RED with a prompt and a granted Overshield off
# a shot that bounced. The trait therefore carries a `context.number <= 0` clause of its own, and
# that test is a real gate rather than an engine observation.
#
# Damage soaked entirely by EXISTING Overshield still DOES offer Halo, because the soak happens
# inside damage() at :215-220 against a local, and never writes back to context.number. Burn ticks
# are damage events of type BURN and count. Heat never counts: heat is not damage in Lancer, and
# buff_suppress.gd:27-28 is vanilla's own exclusion of it from "damages".
#
# THE ALLY IS CHOSEN BY PROMPT, over allied characters within the Myconid's Sensors, the Myconid
# excluded, with NO line of sight required - Bel writes "within Sensors and line of sight" when sight
# is meant (Black Mountain, three times), so bare "within Sensors" is range only. Cancel declines,
# and declining does not spend the 1/round.
#
# "1/ROUND" IS THE ENGINE'S PER-ROUND HARD LIMIT, cleared at the Myconid's OWN turn start
# (reset_per_round_usage, unit_action.gd:78, from event_turn_start.gd:79) - per turn in truth, and
# accepted for vanilla parity, since every vanilla 1/round reaction has the property. Symbiosis alone
# gets the honest round, because its bookkeeping is ours.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_halo.gd
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const TRAIT_ID := &'mt_halo'
const ACTION_ID := &'action_halo'

## The map is the fixture's default 15x9, so x 0..14 and y 0..8. The Myconid is size 2 and occupies
## (2,4) (3,4) (2,5) (3,5); UnitRelation.distance_between measures closest tiles, so every distance
## below is from its near column.
const MYCONID_TILE := Vector2i(2, 4)
const NEAR_ALLY_TILE := Vector2i(8, 4)  # 5 from (3,4): inside Sensors 8
const FAR_ALLY_TILE := Vector2i(13, 4)  # 10 from (3,4): outside Sensors 8
const ENEMY_TILE := Vector2i(8, 7)

## Grit 2 for every positive case, so "gained Overshield equal to Grit" is a number no other quantity
## in the fixture happens to equal: the Myconid's armor is 2 as well, but the ally's Overshield can
## only have come from here.
const TEST_GRIT := 2

## Comfortably above the Myconid's armor 2, so capped_damage is positive and the POST is queued.
const BITING_DAMAGE := 5
## Exactly the Myconid's armor, so the damage event reaches DAMAGE POST carrying number 0. The
## engine does NOT abort this - see the header - so the trait's own gate is what refuses it.
const ZEROED_DAMAGE := 2

var game:Gamemaster
var myconid:Unit
var ally:Unit
var watcher:PromptWatcher
var responder:SpecFactory.ChoiceBusResponder

func before_each() -> void:
	game = MyconidFixture.create_game(self)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)
	MyconidFixture.set_grit(myconid, TEST_GRIT)
	ally = MyconidFixture.create_ally(game, NEAR_ALLY_TILE)
	# The responder SpecFactory.setup_gamemaster already added; the watcher only listens beside it.
	responder = SpecFactory.current_responder
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Hit the Myconid, and hand back the unit prompts that hit opened. Sliced from a `before` mark
## rather than read whole, so a test that pokes twice can tell the two apart.
func take_damage(amount:int, type:Lancer.DAMAGE_TYPE) -> Array[Dictionary]:
	var before:int = watcher.kinds(PromptWatcher.KIND.unit).size()
	await game.execute_event(&'event_unit_damage', {
		unit = myconid, number = amount, category = type,
	})
	return watcher.kinds(PromptWatcher.KIND.unit).slice(before)

func halo_gear() -> GearCore:
	var gear:GearCore = myconid.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

func uses_this_round() -> int:
	var gear:GearCore = halo_gear()
	if gear == null: return -1
	return gear.get_uses_this_round(gear.kit.get_action(ACTION_ID))

## Ask the ENGINE whether Halo would be OFFERED at all, instead of inferring it from the absence of
## a prompt. ReactionBus.does_reaction_trigger is the exact question reaction_bus.gd:53 asks before
## it queues an event_gear_activate, and it is the only observable that separates "never offered"
## from "offered, and then aborted inside activate()".
##
## THAT DISTINCTION IS WHY THIS EXISTS. activate() re-derives the grant and aborts on amount <= 0,
## so a Grit 0 Myconid opens no prompt whether the gate refuses it or not - which made the gate's
## Grit clause look load-bearing when it was not (mutation 2, measured 2026-09-16: deleting it left
## the whole file green). Offered-and-aborted is not the same thing: it wastes an event_gear_activate
## block on every single hit the Myconid takes, for the whole of licence level 0 - and every
## UNIT_ACTION PRE reaction and buff on the map fires on its virtual core along the way
## (event_gear_activate.gd:53-56), whether or not the activation goes on to do anything. This is what
## makes the spec able to tell.
##
## The event is BUILT, not executed, so context.number here is the RAW damage rather than the
## post-armor amount. The gate's own post-armor clause is therefore tested behaviourally instead, by
## test_a_hit_zeroed_by_armor_does_not_offer_halo.
func would_offer(amount:int, type:Lancer.DAMAGE_TYPE) -> bool:
	var gear:GearCore = halo_gear()
	if gear == null: return false
	var action = gear.kit.get_action(ACTION_ID)
	if not (action is ActionReaction): return false
	var event := EventCore.create(&'event_unit_damage', {
		unit = myconid, number = amount, category = type,
	})
	return ReactionBus.does_reaction_trigger(
		&'damage', ReactionBus.TIMING.POST, action, gear, myconid, event
	)

# ---------------------------------------------------------------- the wiring

func test_the_trait_and_its_hidden_action_are_shaped_right():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_halo is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, 'It carries action_halo.')
	if action == null: return
	assert_true(action is ActionReaction, 'The plain reaction archetype, not ActionReactionSelf.')
	assert_has(action.triggers_on, &'damage', 'It triggers on damage.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST,
		'POST, after the damage has landed - there is no other seam.')
	assert_false(action.consumes_rxn,
		'It spends no reaction point: the card does not say it costs one.')
	assert_false(action.show_in_tooltip(kit),
		'Hidden: the trait card already says everything, and a reaction never reaches the gear bar.')
	assert_eq(action.get_required_triggering_context().size(), 0,
		'Nothing is required of the triggering context - the HEAER reasoning.')
	var specific := SpecificAction.create(myconid, halo_gear(), action)
	assert_eq(action.get_per_round_hard_limit(specific), 1,
		'1/round, overridden: a reaction that spends no point defaults to 99.')

func test_the_effect_row_resolves():
	assert_ne(X.tr('gear.mt_halo.name'), 'gear.mt_halo.name', 'The trait is named.')
	assert_ne(X.tr('gear.mt_halo.effect'), 'gear.mt_halo.effect', 'It has rule text.')

# ---------------------------------------------------------------- what counts as taking damage

func test_kinetic_damage_offers_halo_and_the_chosen_ally_gains_overshield_equal_to_grit():
	responder.chosen_unit = ally
	# The positive half of would_offer(), so the negative assertions elsewhere cannot be passing
	# because the helper simply always says no.
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'The engine offers the reaction at all.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 1, 'One unit prompt was opened.')
	if prompts.is_empty(): return
	assert_has(prompts[0].units, ally, 'The ally was offered.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And gained Overshield equal to Grit.')
	assert_eq(uses_this_round(), 1, 'The 1/round is spent.')

func test_heat_does_not_offer_halo():
	# Heat is not damage in Lancer, and it reaches DAMAGE POST through the same event - so this is a
	# gate the trait has to carry rather than something the engine does for it.
	var prompts := await take_damage(3, Lancer.DAMAGE_TYPE.HEAT)
	assert_eq(prompts.size(), 0, 'No prompt.')
	assert_eq(Overshield.current(ally), 0, 'And the ally gained nothing.')
	assert_gt(myconid.core.current.heat, 0, 'fixture: the heat really was applied.')

func test_a_hit_zeroed_by_armor_does_not_offer_halo():
	# A REAL GATE, not an engine observation (measured 2026-09-16; see the header). The event is NOT
	# aborted - capped_damage is a buff cap, not the armor-reduced amount - so it reaches DAMAGE POST
	# carrying number 0, and only the trait's own `context.number <= 0` clause stops a Myconid
	# handing out Overshield every time a shot bounces off its armor.
	var health_before:int = myconid.core.current.health
	var prompts := await take_damage(ZEROED_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(myconid.core.current.health, health_before, 'fixture: armor really stopped all of it.')
	assert_eq(prompts.size(), 0, 'No prompt.')

func test_damage_fully_soaked_by_overshield_does_offer_halo():
	# The soak happens inside damage() at :215-220 against a local `damage_amount`, and never writes
	# back to context.number - so soaked damage still reads positive at the gate, and is damage that
	# reached the Myconid. Ruled deliberately, 2026-09-15. This is the test that keeps the
	# `context.number <= 0` clause honest: it must refuse the bounced shot WITHOUT refusing this.
	await Overshield.grant(SpecFactory.dummy_event({unit = myconid}), myconid, 20)
	responder.chosen_unit = ally
	var health_before:int = myconid.core.current.health
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(myconid.core.current.health, health_before,
		'fixture: the Overshield really absorbed all of it.')
	assert_eq(prompts.size(), 1, 'Halo is still offered.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the ally still gained Overshield.')

func test_a_burn_tick_offers_halo():
	# Burn ticks are ordinary damage events of type BURN, including the end-of-turn ones.
	responder.chosen_unit = ally
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.BURN)
	assert_eq(prompts.size(), 1, 'Burn offers Halo.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the ally gained Overshield.')

# ---------------------------------------------------------------- the 1/round

func test_a_second_offer_in_the_same_round_is_refused():
	# The engine's per-round hard limit is consulted inside does_reaction_trigger, via
	# can_activate_gear, so the prompt never opens a second time - there is nothing to decline.
	responder.chosen_unit = ally
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(uses_this_round(), 1, 'fixture: the first Halo was taken.')
	var second := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(second.size(), 0, 'The second hit in the same round offers nothing.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the ally gained nothing more.')

func test_declining_leaves_the_one_per_round_unspent():
	# spend_actions runs only after a unit is chosen (action.gd:144), so a cancel costs nothing - and
	# the proof is that the NEXT hit in the same round still offers.
	responder.abort_all = true
	var first := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(first.size(), 1, 'The prompt opened.')
	assert_eq(Overshield.current(ally), 0, 'And was declined.')
	assert_eq(uses_this_round(), 0, 'Declining spent nothing.')
	responder.abort_all = false
	responder.chosen_unit = ally
	var second := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(second.size(), 1, 'So the next hit in the same round still offers it.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And this time it lands.')

# ---------------------------------------------------------------- who is eligible

func test_no_ally_within_sensors_means_no_offer():
	# Not "the prompt opens and is empty": a prompt about nobody is worse than no prompt.
	UnitTile.move_to(ally, FAR_ALLY_TILE)
	assert_gt(UnitRelation.distance_between(myconid, ally), myconid.get_sensor_range(),
		'fixture: the ally really is outside Sensors.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 0, 'No prompt.')
	assert_eq(uses_this_round(), 0, 'And nothing was spent.')

func test_an_enemy_within_sensors_is_not_an_ally():
	# The other half of the same clause. Without it "allied character" would be doing no work, and an
	# in-Sensors hostile would be handed Overshield by the Myconid it just shot.
	UnitTile.move_to(ally, FAR_ALLY_TILE)
	var enemy:Unit = MyconidFixture.create_dummy(game, ENEMY_TILE, 10)
	assert_lt(UnitRelation.distance_between(myconid, enemy), myconid.get_sensor_range(),
		'fixture: the enemy really is inside Sensors.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 0, 'A hostile is not a candidate.')

func test_grit_zero_means_no_offer():
	# At licence level 0 the grant would be 0, and Overshield.grant refuses that outright - so without
	# the GATE the reaction would be offered, wasting an event_gear_activate block - and every
	# UNIT_ACTION PRE reaction and buff on the map firing on its virtual core - and then abort inside
	# activate() on every single hit the Myconid took, for the whole of licence level 0.
	#
	# ASSERTED THROUGH would_offer(), NOT THROUGH THE ABSENCE OF A PROMPT, and that is the whole
	# point of this test: activate()'s own `abort_when(amount <= 0)` already closes the prompt, so a
	# prompt-count assertion is green with the gate deleted (mutation 2, measured 2026-09-16). See
	# would_offer()'s header.
	MyconidFixture.set_grit(myconid, 0)
	assert_eq(Overshield.grit(myconid), 0, 'fixture: Grit really is 0.')
	responder.chosen_unit = ally
	assert_false(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'The reaction is not offered at all - not offered and then quietly aborted.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 0, 'No prompt.')
	assert_eq(uses_this_round(), 0, 'And nothing was spent.')

func test_the_myconid_is_never_a_candidate():
	# "an allied character" - and UnitRelation.are_allies is true of a unit and itself, so this is an
	# explicit exclusion rather than something the relation does for us. A Myconid that could Halo
	# itself would be a very different trait.
	responder.chosen_unit = ally
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 1, 'The prompt opened.')
	if prompts.is_empty(): return
	assert_false(prompts[0].units.has(myconid), 'The Myconid is not in its own candidate list.')
	assert_eq(Overshield.current(myconid), 0, 'And gained nothing itself.')

func test_an_ally_out_of_line_of_sight_but_within_sensors_is_a_candidate():
	# THE CARD SAYS SENSORS, NOT SIGHT (ruling, 2026-09-15): Bel writes "within Sensors and line of
	# sight" when sight is meant, three times on Black Mountain alone, so bare "within Sensors" is
	# range only. Nothing else in the suite would notice a can_see() creeping into the gate.
	SpecFactory.set_tiles_elevation(game.map, 6, [Vector2i(5, 4), Vector2i(5, 5)])
	assert_false(UnitRelation.can_see(myconid, ally),
		'fixture: the wall really does block sight to the ally.')
	assert_lt(UnitRelation.distance_between(myconid, ally), myconid.get_sensor_range(),
		'fixture: and the ally is still inside Sensors.')
	responder.chosen_unit = ally
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 1, 'Halo is still offered.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the blind ally gains the Overshield.')
