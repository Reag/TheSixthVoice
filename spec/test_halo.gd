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
# AND SINCE SP2.5 TASK 1, SYMBIOSIS RELIEVES THAT LIMIT - so a ROUND holds two Halos, not one. Halo
# is a reaction and is neither 1/scene nor 1/mission, which is the whole of what the trait's card
# excludes, so buff_symbiosis_extra_use raises its per-round cap exactly as it does the Uffish Gyre's.
# The two are the same mechanism and not a Pike special case. test_a_second_halo_is_offered_while_
# symbiosis_is_unspent and test_a_third_offer_in_the_same_round_is_refused are the pair; the latter
# is what test_a_second_offer_in_the_same_round_is_refused became.
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
## A SECOND ally inside Sensors, for the 1/round cases only. Since SP2.5 Task 1 the round has two
## Halos in it, and "did the second one land" cannot be asked of a unit that already carries the
## first one's Overshield. 5 from (3,5), so the same distance as the first.
const SECOND_ALLY_TILE := Vector2i(8, 6)
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
##
## `flags` defaults to none, i.e. an ordinary hit. test_a_burn_tick_offers_halo (finding 5, frame
## close 2026-09-16) is the one caller that passes [NO_REDUCE, IS_EOT_BURN], to actually be the
## end-of-turn tick its name claims (event_turn_end.gd:101-106) rather than a bare BURN hit.
func take_damage(amount:int, type:Lancer.DAMAGE_TYPE, flags:Array = []) -> Array[Dictionary]:
	var before:int = watcher.kinds(PromptWatcher.KIND.unit).size()
	await game.execute_event(&'event_unit_damage', {
		unit = myconid, number = amount, category = type, flags = flags,
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

## Close-out Pass D: Halo grants through Overshield.grant_by, the Black Mountain's "granted by" family,
## so the shield answers whose it is. No card reads it for the Myconid today; this is uniformity.
func test_a_halo_shield_is_marked_as_granted_by_the_myconid():
	responder.chosen_unit = ally
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 1, 'Fixture: Halo was offered.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'Fixture: the ally took the shield.')
	assert_true(Overshield.is_granted_by(ally, myconid), "The shield is marked as the Myconid's.")
	assert_false(Overshield.is_granted_by(myconid, myconid), 'And the Myconid itself holds no mark.')

func test_heat_does_not_offer_halo():
	# CONTROL (frame close, finding 3, 2026-09-16): without this, the negative below is also green with
	# mt_halo deleted from the frame outright - it cannot tell "the HEAT clause refused it" from "the
	# trait is not there". Same shape as test_grit_zero_means_no_offer's control.
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'CONTROL: the engine offers Halo for an ordinary hit, so the clause below is doing the work.')
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

	# CONTROL, AFTER the assertions above rather than before (frame close, finding 3, 2026-09-16): a
	# would_offer() control would be MISLEADING here, not just redundant. would_offer() BUILDS the event
	# rather than running execute_preblock (see its own header), so its context.number is always the RAW
	# pre-armor amount - it cannot see the zeroing this test is about, and would read positive whether or
	# not the gate's `context.number <= 0` clause exists. A REAL hit is the only way to show mt_halo is
	# still there and would have opened a prompt, and it has to come SECOND so it does not spend the
	# round's one use before the case under test runs.
	responder.chosen_unit = ally
	var control := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(control.size(), 1,
		'CONTROL: an ordinary hit still offers Halo, so the clause above is doing the work.')

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
	# A REAL end-of-turn tick's damage event, not a bare BURN hit (frame close, finding 5, 2026-09-16).
	# The failed-save branch of a tick fires event_unit_damage carrying
	# flags = [NO_REDUCE, IS_EOT_BURN] (event_turn_end.gd:101-106). IS_EOT_BURN is not cosmetic:
	# event_unit_damage.gd:121-122 adds the amount to unit.state.burn ONLY when IS_EOT_BURN is absent,
	# so the unflagged event this test used to fire was quietly leaving BITING_DAMAGE worth of burn
	# sitting on the Myconid while claiming to model a tick.
	#
	# THE GATE OUTCOME IS UNCHANGED (verified, not assumed). triggers_on_event reads only context.unit
	# (action_halo.gd:99), context.category_int (:102-103) and context.number (:107); Overshield.grit and
	# eligible_allies read unit state, not the event's flags. NO_REDUCE returns damage_modifications
	# early at :59, before armor/resistance/exposure run - but BURN never reaches the armor step anyway
	# (damage_modifications.gd:90 is the HEAT/BURN branch, and only 'resisted' halving and
	# 'other_reduction' apply there), and this fixture's Myconid carries no resist or cap buff, so
	# context.number lands on BITING_DAMAGE either way.
	responder.chosen_unit = ally
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.BURN,
		[EventService.DAMAGE_FLAG.NO_REDUCE, EventService.DAMAGE_FLAG.IS_EOT_BURN])
	assert_eq(prompts.size(), 1, 'Burn offers Halo.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the ally gained Overshield.')
	assert_eq(myconid.state.burn, 0,
		'fixture: correctly flagged as an EOT tick, so it does not re-add to burn (event_unit_damage.gd:121-122).')

# ---------------------------------------------------------------- the 1/round

func test_a_second_halo_is_offered_while_symbiosis_is_unspent():
	# SP2.5 TASK 1, AND IT WIDENS THAT FIX BEYOND THE PIKE DELIBERATELY. Symbiosis says "1/round, the
	# Myconid may use a reaction an additional time", excluding only 1/scene and 1/mission ones. Halo
	# is a reaction and is neither, so the trait relieves ITS per-round cap on exactly the same terms
	# as the Uffish Gyre's - buff_symbiosis_extra_use filters on `action is ActionReaction` and not on
	# one action id, which is the card read straight.
	#
	# ASKED OF THE ENGINE AND THEN OF THE PROMPT, in that order, because they are different claims:
	# would_offer() is ReactionBus.does_reaction_trigger, i.e. whether the cap lets the reaction be
	# COLLECTED at all, and the prompt is whether the activation then ran. The first is where the cap
	# lives; the second is what the player sees.
	responder.chosen_unit = ally
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'fixture: the first hit offers Halo.')
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(uses_this_round(), 1, 'fixture: the first Halo was taken.')

	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'The engine still offers it inside the same round: Symbiosis has an extra use.')
	var second_ally := MyconidFixture.create_ally(game, SECOND_ALLY_TILE)
	responder.chosen_unit = second_ally
	var second := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(second.size(), 1, 'And the prompt really opens a second time.')
	assert_eq(uses_this_round(), 2, 'The second Halo was taken.')
	assert_eq(Overshield.current(second_ally), TEST_GRIT,
		'And the ally chosen for it gained Overshield, so it resolved and did not merely count.')

func test_a_third_offer_in_the_same_round_is_refused():
	# THE 1/ROUND IS STILL A 1/ROUND, and this is the test that used to say so about the SECOND offer
	# (test_a_second_offer_in_the_same_round_is_refused, until SP2.5 Task 1). It is updated rather
	# than weakened: the claim is unchanged - the round's Halos run out and the prompt stops opening -
	# and so is what reddens it. Deleting action_halo's get_per_round_hard_limit override still does,
	# because ActionReaction hands a non-consuming reaction 99 (action_reaction.gd:69) and a third
	# offer would then open too. What moved is only WHERE the line falls, because the second offer is
	# now Symbiosis's extra.
	#
	# The engine's per-round hard limit is consulted inside does_reaction_trigger via
	# can_activate_gear, so the prompt never opens a third time - there is nothing to decline.
	var second_ally := MyconidFixture.create_ally(game, SECOND_ALLY_TILE)
	responder.chosen_unit = ally
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(uses_this_round(), 1, 'fixture: the first Halo was taken.')
	responder.chosen_unit = second_ally
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(uses_this_round(), 2, 'CONTROL: the second is Symbiosis s extra, and it lands.')
	assert_eq(Overshield.current(second_ally), TEST_GRIT, 'CONTROL: on the ally chosen for it.')

	var third := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(third.size(), 0, 'The third hit in the same round offers nothing.')
	assert_eq(uses_this_round(), 2, 'Nothing more was spent.')
	assert_false(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'And the engine does not offer it: Symbiosis is spent, so the cap is back to one.')
	assert_eq(Overshield.current(ally), TEST_GRIT, 'And the first ally gained nothing more.')

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
	# CONTROL, before the ally moves out of range (frame close, finding 3, 2026-09-16): proves mt_halo
	# is present and would be offered for this very ally at its current distance, so moving it away is
	# what the Sensors clause below actually answers, rather than the trait simply not being there.
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'CONTROL: the engine offers Halo while the ally is still in range.')
	# Not "the prompt opens and is empty": a prompt about nobody is worse than no prompt.
	UnitTile.move_to(ally, FAR_ALLY_TILE)
	assert_gt(UnitRelation.distance_between(myconid, ally), myconid.get_sensor_range(),
		'fixture: the ally really is outside Sensors.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 0, 'No prompt.')
	assert_eq(uses_this_round(), 0, 'And nothing was spent.')

func test_an_enemy_within_sensors_is_not_an_ally():
	# CONTROL, before the ally moves out of range (frame close, finding 3, 2026-09-16): the same proof
	# as test_no_ally_within_sensors_means_no_offer - that mt_halo really is wired up and would be
	# offered here, so its absence below is the are_allies clause at work, not an absent trait.
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'CONTROL: the engine offers Halo while an ally is in range.')
	# The other half of the same clause. Without it "allied character" would be doing no work, and an
	# in-Sensors hostile would be handed Overshield by the Myconid it just shot.
	UnitTile.move_to(ally, FAR_ALLY_TILE)
	var enemy:Unit = MyconidFixture.create_dummy(game, ENEMY_TILE, 10)
	assert_lt(UnitRelation.distance_between(myconid, enemy), myconid.get_sensor_range(),
		'fixture: the enemy really is inside Sensors.')
	var prompts := await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(prompts.size(), 0, 'A hostile is not a candidate.')

func test_an_ally_we_cannot_affect_is_not_a_candidate():
	# REACHABILITY, the Uffish Gyre's own test (action_uffish_gyre.gd:130), added to Halo at the
	# frame close on the author's call (2026-09-16).
	#
	# THE PROBE IS INTANGIBLE, AND THE FIRST DRAFT'S EXILED WAS VACUOUS - watched, not reasoned. An
	# EXILED ally never reaches can_affect at all: get_all_characters filters through is_character ->
	# is_active, and is_active ends with `not has_status(EXILED)` (unit.gd:113), so the eligible-ally
	# loop has already dropped it before the new clause is consulted. Commenting the clause out left
	# an EXILED-based test green. INTANGIBLE is not in is_active, so an intangible ally IS a
	# character, IS allied and IS in range - and can_affect refuses it only because our own
	# intangibility differs (unit_relation.gd:397). That is the one clause here doing real work, and
	# it is the state frame 5's Teleport helper is most likely to produce.
	#
	# Asked through would_offer rather than by counting prompts, for the reason
	# test_grit_zero_means_no_offer gives: a prompt count cannot tell "never offered" from "offered
	# and then aborted".
	assert_true(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'CONTROL: this ally IS a candidate while we can reach it, so the clause below is doing the work.')

	UnitCondition.apply_status(SpecFactory.dummy_event(), ally, Lancer.STATUS.INTANGIBLE, Lancer.UNTIL.MANUAL)
	assert_true(ally.has_status(Lancer.STATUS.INTANGIBLE), 'fixture: the ally really is intangible.')
	assert_false(myconid.has_status(Lancer.STATUS.INTANGIBLE), 'fixture: and we are not, so the states differ.')
	assert_true(ally.is_character(), 'fixture: it is STILL a character, unlike an exiled one.')
	assert_lt(UnitRelation.distance_between(myconid, ally), myconid.get_sensor_range(),
		'fixture: and it has not moved - it is still well inside Sensors.')

	assert_false(would_offer(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC),
		'An ally we cannot affect is not a candidate, so Halo is not offered at all.')

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
