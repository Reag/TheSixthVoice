# UNCERTAINTY FIELD (Maiden's Blush trait, SP1 Task 4).
#
#   "1/round if the Maiden's Blush would teleport, it instead may become Invisible until the
#    beginning of its next turn. It immediately loses Invisible if it takes damage."
#
# ABSORBS spec/test_spike_teleport_interception.gd, which is deleted in this task (ruling 16). The
# probe's nine cases were characterisations of the 1.4.3 engine driven by an in-memory Buff; every one
# of them is re-asked here against the real trait - the two landing controls, the walk control, the
# veto, the scripted-involuntary case, the deferred spend, the replacement effect and the
# START_OF_TURN expiry.
#
# THE OFFER IS ONE YESNO PROMPT, AND THAT IS NOT THE ENGINE'S DOING. ReactionBus queues an activation
# for every reaction whose gate passes and asks nobody; the prompt is the CommonActionUtil.confirm_use
# inside activate(), exactly as it is for Flash Anchor. So "was it offered" and "was the player asked"
# are the same question here, and both are observable - the first through
# ReactionBus.does_reaction_trigger, the second through PromptWatcher.
#
# EVERY NEGATIVE CASE CARRIES A POSITIVE CONTROL in the same test. "No prompt appeared" is also what a
# deleted trait reports, and this file has eight negatives; see the Myconid frame close's finding 3.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_uncertainty_field.gd
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const TRAIT_ID := &'mt_uncertainty_field'
const ACTION_ID := &'action_uncertainty_field'
const BREAK_BUFF_ID := &'buff_uncertainty_field_break'

## Fade Strike's chip, for the one test that drives the frame's whole kit end to end.
const FADE_STRIKE_CHIP_ID := &'buff_fade_strike'

const BLUSH_TILE := Vector2i(2, 2)
const DESTINATION := Vector2i(5, 2)
const HOSTILE_TILE := Vector2i(8, 2)
const ALLY_TILE := Vector2i(2, 6)

## A source id no gear on the map owns, for the "Invisible from somewhere else survives" case.
const OTHER_SOURCE := &'some_other_cloak'

## VANILLA, and the reason the immunity case below is not a thought experiment: the NPC Scout's
## Rebound Scan hangs this BuffStatusImmunity - immune_to_statuses [hidden, invisible] - on every
## enemy within 3 of its target. Applied by id rather than rebuilt, so the test goes red if the
## vanilla buff ever stops granting that immunity.
const IMMUNITY_BUFF_ID := &'buff_rebound_scan'

## Comfortably above anything the Blush resists.
const BITING_DAMAGE := 5
## The armor given to the Blush in the zeroed-hit case, and the damage that exactly meets it. The
## frame's own armor is 0 (the sheet), so that test writes core.current.armor directly.
const TEST_ARMOR := 2

var game:Gamemaster
var blush:Unit
var hostile:Unit
var ally:Unit
var watcher:PromptWatcher
var responder:SpecFactory.ChoiceBusResponder

## How many times a deferred pathfinder spend ran; see test_accepting_skips_the_pathfinders_deferred_spend.
var spend_calls:int = 0

func before_each() -> void:
	game = MaidensBlushFixture.create_game(self)
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	hostile = MaidensBlushFixture.create_hostile(game, HOSTILE_TILE)
	ally = MaidensBlushFixture.create_ally(game, ALLY_TILE)
	# The responder SpecFactory.setup_gamemaster already added; the watcher only listens beside it.
	responder = SpecFactory.current_responder
	watcher = add_child_autoqfree(PromptWatcher.new())
	spend_calls = 0

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

func field_gear() -> GearCore:
	var gear:GearCore = blush.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

func field_source() -> StringName:
	var gear := field_gear()
	return gear.persistent_id if gear != null else &''

func uses_this_round() -> int:
	var gear := field_gear()
	if gear == null: return -1
	return gear.get_uses_this_round_alt(&'uncertainty_field')

## Invisible, sourced to THIS trait's gear - the source qualifier is the whole of ruling 6's
## refinement, so every read goes through it rather than through the bare unit.has_status().
func faded() -> bool:
	var source := field_source()
	if source.is_empty(): return false
	return UnitCondition.has_status(blush, Lancer.STATUS.INVISIBLE, source)

## Yes/no prompts opened since a mark, so a test that teleports twice can tell the two apart.
func yesnos_since(mark:int) -> Array[Dictionary]:
	return watcher.kinds(PromptWatcher.KIND.yesno).slice(mark)

func yesno_mark() -> int:
	return watcher.kinds(PromptWatcher.KIND.yesno).size()

## An INVOLUNTARY teleporting movement type that is NOT tagged as ours - what a hostile shove or a
## mission script issues. Built by hand rather than through Teleport.movement_type(unit, true), which
## would tag it and so would answer the wrong question.
func hostile_teleport_type() -> MovementType:
	var type := MovementType.create(blush, false)
	type.teleport = true
	type.ignore_engagement = true
	type.ignore_rxns = true # create_for_involuntary sets this on EVERY forced move; the gate ignores it
	return type

## Run one event_unit_move and hand back its core, so a test can read `aborted`. The probe's helper.
func run_move(event_data:Dictionary) -> EventCore:
	var core := EventCore.create(&'event_unit_move', event_data)
	await game.execute_event_block(EventBlock.create_multiple([core]))
	return core

## THE BLINKSPACE SHAPE: a pathfinder over given tiles with a teleporting MovementType, then the
## pathfinder's own event (context.array = the path, one Step for a teleport). Every player-side
## teleport in vanilla is built this way, and it is the shape a vetoed core has to abort.
func teleport_by_path(to:Vector2i) -> EventCore:
	var pathfinder:Pathfinder = await Pathfinder.generate_for_given_tiles(
		blush, [to], Teleport.movement_type(blush)
	)
	var events:Array[EventCore] = pathfinder.generate_events(blush, pathfinder.path_to(to))
	assert_eq(events.size(), 1, 'fixture: the pathfinder produced exactly one move event.')
	if events.is_empty(): return null
	await game.execute_event_block(EventBlock.create_multiple(events))
	return events[0]

## Ask the ENGINE whether the field would be OFFERED at all, instead of inferring it from the absence
## of a prompt. does_reaction_trigger is the exact question reaction_bus.gd:53 asks before it queues an
## event_gear_activate, and it is the only observable that separates "never offered" from "offered,
## and then declined or aborted inside activate()". The event is BUILT, not executed.
func would_offer(event_data:Dictionary) -> bool:
	var gear := field_gear()
	if gear == null: return false
	var action = gear.kit.get_action(ACTION_ID)
	if not (action is ActionReaction): return false
	return ReactionBus.does_reaction_trigger(
		ReactionBus.TRIGGER.ENTIRE_MOVEMENT, ReactionBus.TIMING.PRE,
		action, gear, blush, EventCore.create(&'event_unit_move', event_data)
	)

func voluntary_teleport_data(to:Vector2i = DESTINATION) -> Dictionary:
	return {unit = blush, target_tiles = [to], resource = Teleport.movement_type(blush)}

## Put the Blush into the state a successful fade leaves it in, WITHOUT driving a teleport - same
## status, same until, same source as activate() applies.
## test_accepting_leaves_the_blush_on_its_origin_tile_invisible_and_aborts_the_move is the one test
## that proves activate() really produces this, and every damage case below builds on it.
func fade_by_hand() -> void:
	SpecFactory.apply(blush, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN, field_source())

func take_damage(amount:int, type:Lancer.DAMAGE_TYPE) -> void:
	await damage_unit(blush, amount, type)

## Damage ANYBODY, so the break buff's holder check can be driven from the other side of it.
func damage_unit(victim:Unit, amount:int, type:Lancer.DAMAGE_TYPE) -> void:
	await game.execute_event(&'event_unit_damage', {unit = victim, number = amount, category = type})

# ---------------------------------------------------------------- the wiring

func test_the_trait_its_reaction_and_its_break_buff_are_shaped_right():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_uncertainty_field is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')

	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, 'It carries action_uncertainty_field.')
	if action == null: return
	assert_true(action is ActionReactionSelf,
		'The SELF reaction archetype: the mover really is us in every case the card covers.')
	assert_has(action.triggers_on, ReactionBus.TRIGGER.ENTIRE_MOVEMENT, 'It triggers on entire_movement.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE,
		'PRE - the only timing at which the move can still be stopped (event_unit_move.gd:71-72).')
	assert_false(action.consumes_rxn,
		'It spends no reaction point: the card does not say it costs one.')
	assert_eq(action.usage_group, &'uncertainty_field',
		'Its own usage group, so a later action on this Kit cannot share its 1/round.')
	var specific := SpecificAction.create(blush, field_gear(), action)
	assert_eq(action.get_per_round_hard_limit(specific), 1,
		'1/round, overridden: a reaction that spends no point defaults to 99.')
	assert_eq(action.get_required_triggering_context(),
		[Context.PROP.unit, Context.PROP.resource] as Array[Context.PROP],
		'The mover and the movement type, as Strike and Fade requires of the same trigger.')

	var break_buff:Buff = ContentLibrary.get_buff(BREAK_BUFF_ID)
	assert_not_null(break_buff, 'buff_uncertainty_field_break is in the buffs index.')
	if break_buff == null: return
	assert_true(break_buff.hide_from_player, 'The break is bookkeeping: never a chip on the unit.')
	assert_has(break_buff.triggers_on, ReactionBus.TRIGGER.DAMAGE, 'It listens on damage.')
	assert_eq(break_buff.trigger_timing, ReactionBus.TIMING.POST, 'POST, after the damage has landed.')
	assert_eq(break_buff.until, Lancer.UNTIL.MANUAL, 'And it lasts the scene.')

func test_the_rows_resolve_and_the_reaction_stays_off_the_trait_card():
	# THE THREE INVENTED UI ROWS ARE IN THIS LIST TOO, and they are the ones that most need it. The
	# battle-log call passes a LITERAL KEY (action_uncertainty_field.gd:105) which battle_log_bus.log_tr
	# tr()s itself, and Translate.action defaults return_key_if_blank = true - so a dropped CSV row or a
	# stale localizations.en.translation artifact puts the raw key straight into the battle log and
	# floating over the board, with every other test in this file still green.
	for key:String in ['gear.mt_uncertainty_field.name', 'gear.mt_uncertainty_field.effect',
			'gear.mt_uncertainty_field.action_uncertainty_field.name',
			'gear.mt_uncertainty_field.action_uncertainty_field.replaced.log',
			'gear.mt_uncertainty_field.action_uncertainty_field.replaced.pop',
			'gear.mt_uncertainty_field.broken.log']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE REACTION DOES NOT GET ITS OWN ROW ON THE TRAIT CARD, and that is an engine consequence of
	# the localisation, not a choice made in the .tres. Action.show_in_tooltip (action.gd:341-353)
	# returns false when the action's own `effect` equals the KIT's generic one, and ruling 17 says the
	# reaction row's effect is the card text "verbatim again" - i.e. identical. It also returns false
	# because this Kit has no `trigger` row, which is the clause that would otherwise force a true.
	#
	# This is what makes ICON_TARGETS[&'mt_uncertainty_field'] an EMPTY list rather than
	# [&'action_uncertainty_field'], correcting design §1.5. The two move together: if a later session
	# gives the reaction distinct text or the Kit a `trigger` row, this assertion and that row both
	# have to flip, and test_content_integrity's own
	# "listed exactly when it reaches a player-facing surface" assertion is what would catch the half
	# of it that got forgotten.
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	if not Kit.is_valid(kit): return
	var action = kit.get_action(ACTION_ID)
	if action == null: return
	assert_eq(X.tr('gear.mt_uncertainty_field.action_uncertainty_field.effect'),
		X.tr('gear.mt_uncertainty_field.effect'),
		'The reaction row repeats the card text exactly (ruling 17).')
	assert_true(Translate.gear('mt_uncertainty_field', 'trigger', false).is_empty(),
		'And the Kit has no trigger row - the LCP prints none for a trait.')
	assert_false(action.show_in_tooltip(kit),
		'So the engine draws no separate reaction row on the trait card, and the reaction needs no'
		+ ' icon of its own.')

# ---------------------------------------------------------------- which teleports

func test_a_unit_without_the_trait_teleports_untouched():
	# THE CONTROL for everything below: a fixture whose teleports never went anywhere would make every
	# "it stayed put" assertion in this file green for the wrong reason.
	var plain:Unit = SpecFactory.create_unit(game.map, Vector2i(11, 6))
	plain.core.full_repair()
	var core := await run_move({
		unit = plain, target_tiles = [Vector2i(13, 6)], resource = Teleport.movement_type(plain),
	})
	assert_eq(plain.tile(), Vector2i(13, 6), 'A teleport lands when nothing intercepts it.')
	assert_false(core.aborted, 'And its move core completed.')

func test_a_voluntary_teleport_offers_the_field():
	assert_true(would_offer(voluntary_teleport_data()), 'The engine offers the reaction at all.')
	var mark := yesno_mark()
	await teleport_by_path(DESTINATION)
	assert_eq(yesnos_since(mark).size(), 1,
		'Exactly one yes/no prompt: the confirm_use inside activate(), and nothing else.')

func test_accepting_leaves_the_blush_on_its_origin_tile_invisible_and_aborts_the_move():
	# THE WHOLE CARD, in one test. Every assertion here is a separate promise.
	responder.chosen_yesnos = true
	var core := await teleport_by_path(DESTINATION)
	assert_eq(blush.tile(), BLUSH_TILE, 'The teleport never happened.')
	assert_true(core.aborted, 'The move core reads aborted.')
	assert_eq(blush.state.spaces_moved_this_turn, 0, 'And nothing was recorded as moved.')
	assert_true(blush.has_status(Lancer.STATUS.INVISIBLE), 'The Blush is Invisible instead.')
	assert_true(faded(),
		'And that Invisible is sourced to THIS trait\'s gear - which is what the damage break and'
		+ ' every other-source case below depend on.')
	assert_eq(uses_this_round(), 1, 'The 1/round is spent.')

func test_an_immune_blush_still_pays_for_a_fade_that_grants_nothing():
	# THE AUTHOR'S RULING, 2026-09-17, AND IT IS DELIBERATE - NOT A BUG THIS FILE FAILED TO CATCH. A
	# Maiden's Blush that cannot hold Invisible is offered the fade anyway, and accepting spends the
	# round and cancels the teleport for nothing: activate() spends, vetoes, and only then calls
	# UnitCondition.apply_status, which returns before applying anything on an immune unit
	# (unit_condition.gd:93-99). The trait conditions the offer on the teleport and on the round, and on
	# nothing else; whether the mech can hold the status is not part of the rule.
	#
	# THE MUTATION THIS ANSWERS: add `if UnitCondition.is_immune_to_status(unit,
	# Lancer.STATUS.INVISIBLE, gear.persistent_id): return false` as a last clause of
	# triggers_on_event (action_uncertainty_field.gd:65-91). The field then never triggers, so the
	# teleport lands and the round stays unspent - would_offer, the tile, `aborted` and the use count
	# all flip. That is the "fix" this test exists to stop, and the ruling is written out at the
	# spend/veto/apply sequence in action_uncertainty_field.gd.
	#
	# Two ordinary vanilla NPC features put a player mech here: the Scout's Rebound Scan (the buff used
	# below) and the Bombard's Flare Drone aura, range 2 in LOS, applies_to_enemies.
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), blush, IMMUNITY_BUFF_ID)
	assert_true(UnitCondition.is_immune_to_status(blush, Lancer.STATUS.INVISIBLE, field_source()),
		'fixture: the Blush really cannot become Invisible.')
	assert_true(would_offer(voluntary_teleport_data()),
		'It is offered all the same - the gate asks nothing about immunity.')

	responder.chosen_yesnos = true
	var core := await teleport_by_path(DESTINATION)
	assert_eq(blush.tile(), BLUSH_TILE, 'Accepting still refuses the teleport...')
	assert_true(core.aborted, '...the move core still reads aborted...')
	assert_eq(uses_this_round(), 1, '...the 1/round is still spent...')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE),
		'...and the Invisible the whole trade was for never lands. Strictly worse than declining, and'
		+ ' card-faithful: the card conditions the fade on nothing.')

func test_accepting_skips_the_pathfinders_deferred_spend():
	# Pathfinder.generate_events attaches a deferred_spend callable to every move it builds (the
	# variant-action spend, e.g. a Lunge), and event_unit_move calls it only AFTER the PRE and the
	# abort check (:76-78). So whatever a teleport was going to spend through its pathfinder is never
	# spent when the field takes it. NOTE WHAT THIS DOES NOT COVER: an action's own spend_actions()
	# runs before it queues the move, so a vetoed reaction still stays spent regardless -
	# test_abjuration_of_metal.gd's test_a_vetoed_teleport_forfeits_the_skirmish is where that is
	# asserted today. IT USED TO BE SP2's Step spec asserting the same for the frame's core power
	# (ruling 4), but since Step can no longer be vetoed at all (reach design ruling C, 2026-09-17)
	# that spec now asserts the opposite.
	var spend := func(_core:EventCore) -> void: spend_calls += 1

	responder.chosen_yesnos = false
	var control := await run_move({
		unit = blush, target_tiles = [DESTINATION], resource = Teleport.movement_type(blush),
		deferred_spend = spend,
	})
	assert_false(control.aborted, 'Control: the declined teleport ran.')
	assert_eq(spend_calls, 1, 'Control: its deferred spend ran once.')

	responder.chosen_yesnos = true
	spend_calls = 0
	var origin := blush.tile()
	var vetoed := await run_move({
		unit = blush, target_tiles = [BLUSH_TILE], resource = Teleport.movement_type(blush),
		deferred_spend = spend,
	})
	assert_true(vetoed.aborted, 'The second teleport was taken by the field...')
	assert_eq(blush.tile(), origin, '...and went nowhere...')
	assert_eq(spend_calls, 0, '...and its deferred spend never ran.')

func test_declining_lets_the_teleport_land_and_leaves_the_round_unspent():
	# Declining returns BEFORE spend_actions, which is what lets a player hold the round's fade for a
	# teleport they actually mind losing.
	responder.chosen_yesnos = false
	var mark := yesno_mark()
	var core := await teleport_by_path(DESTINATION)
	assert_eq(yesnos_since(mark).size(), 1, 'The player was still asked.')
	assert_eq(blush.tile(), DESTINATION, 'And the teleport landed.')
	assert_false(core.aborted, 'The move core completed.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'No Invisible.')
	assert_eq(uses_this_round(), 0, 'And the round is unspent.')

func test_a_walk_is_not_offered():
	# The bus offers EVERY move at ENTIRE_MOVEMENT and filters on nothing; Teleport.is_teleport is
	# what tells them apart. Without this the field would offer on every step the Blush ever takes.
	assert_true(would_offer(voluntary_teleport_data()),
		'CONTROL: the engine does offer the field for a teleport, so the negative below is the'
		+ ' teleport clause doing the work and not a dead trait.')
	assert_false(would_offer({unit = blush, target_tiles = [DESTINATION], resource = MovementType.create(blush)}),
		'A walk is not offered.')

	responder.chosen_yesnos = true
	var mark := yesno_mark()
	await SpecFactory.move(game, blush, DESTINATION)
	assert_eq(yesnos_since(mark).size(), 0, 'And no prompt was opened for it.')
	assert_eq(blush.tile(), DESTINATION, 'The walk completed.')

func test_a_scripted_no_rxns_teleport_is_not_offered():
	# event_unit_teleport - the map editor's and every mission script's teleport - sets NO_RXNS
	# unconditionally (event_unit_teleport.gd:31). The ENGINE does not honour that flag for us ("not
	# enforced; reactions need to decide for themselves", event_unit_move.gd:26), so this clause is
	# ours, and ruling 3 is what it encodes: a hostile effect can be refused, a mission cannot.
	var scripted := {
		unit = blush, target_tiles = [DESTINATION], resource = hostile_teleport_type(),
		flags = [EventUnitMove.FLAG.NO_RXNS],
	}
	assert_true(would_offer(voluntary_teleport_data()), 'CONTROL: a teleport IS offered.')
	assert_false(would_offer(scripted), 'A NO_RXNS placement is not.')

	responder.chosen_yesnos = true
	var core := await run_move(scripted)
	assert_eq(blush.tile(), DESTINATION, 'And it landed.')
	assert_false(core.aborted, 'Un-vetoed.')

func test_a_hostile_forced_teleport_is_offered():
	# RULING 3, the author's call, and the widest clause on the card: an enemy that teleports the mech
	# can be refused by fading. Read exactly as Flash Anchor reads a forced move - context.object as a
	# SpecificAction with a valid unit, then UnitRelation.are_enemies.
	var forced := {
		unit = blush, target_tiles = [DESTINATION], resource = hostile_teleport_type(),
		object = SpecificAction.create(hostile, null, null),
	}
	assert_true(would_offer(forced), 'A hostile forced teleport is offered.')

	responder.chosen_yesnos = true
	var core := await run_move(forced)
	assert_eq(blush.tile(), BLUSH_TILE, 'Accepting refuses the shove...')
	assert_true(core.aborted, '...and the move core reads aborted.')
	assert_true(faded(), '...and the Blush fades instead.')

func test_an_involuntary_teleport_with_no_readable_forcer_is_not_offered():
	# The prompt-spam guard, and Flash Anchor's own (action_flash_lock.gd:42 carries the comment
	# "required to come from a hostile source (to prevent prompt spam)"). An involuntary teleport that
	# names nobody is the shape a mission script takes when it forgets NO_RXNS.
	var anonymous := {unit = blush, target_tiles = [DESTINATION], resource = hostile_teleport_type()}
	assert_true(would_offer(voluntary_teleport_data()), 'CONTROL: a teleport IS offered.')
	assert_false(would_offer(anonymous), 'An involuntary teleport with no forcer is not.')

func test_our_own_involuntary_teleport_is_not_offered():
	# STEP OF MIST AND THUNDER IS PERMANENTLY EXEMPT (reach design ruling C, 2026-09-17), REVERSING
	# ruling 157. The card's "This teleportation cannot be prevented" is read as absolute, including
	# against the mech's own trait.
	#
	# THE RULE IS NOT "STEP IS SPECIAL". It is that no OWN-INVOLUNTARY teleport is vetoable by the
	# mech's own trait, which is what the OWN tag means; Step is simply the only thing that takes that
	# shape today. Later consumers of Teleport.move - Purple Thorn, Leoleth, Sluagh, Koremasa, Six Sky -
	# inherit it without knowing the decision was taken.
	#
	# THE SHIPPED VERSION OF THIS TEST ASSERTED THE OPPOSITE and is inverted rather than deleted, which
	# is the record the reversal is entitled to: the clause it pinned (Teleport.is_own in
	# triggers_on_event) is gone, and mutation 5 puts it back to prove this test is what holds it out.
	var own_type := Teleport.movement_type(blush, true)
	var own_involuntary := {unit = blush, target_tiles = [DESTINATION], resource = own_type}
	assert_false(own_type.voluntary,
		'Fixture: it really is involuntary, so the voluntary clause cannot be what answers.')
	assert_true(would_offer(voluntary_teleport_data()), 'CONTROL: an ordinary teleport IS offered.')
	assert_false(would_offer(own_involuntary),
		'But our own unpreventable teleport is not - the is_own clause that used to admit it is gone.')

func test_an_own_involuntary_teleport_that_names_US_as_the_forcer_is_not_offered_either():
	# THE FALL-THROUGH RULING C RESTS ON, pinned rather than assumed. With the is_own clause gone a real
	# Step reaches the forcer check, and Teleport.forcer returns the BLUSH ITSELF - Teleport.move passes
	# the calling action's SpecificAction as the event's object (roadmap 4, corrected at the frame
	# close). UnitRelation.are_enemies is Faction.is_enemy(f, f) (unit_relation.gd:361-362), which is
	# false, so the gate refuses. The exemption is SAFE rather than accidental, and this is the test
	# that says which.
	var own_type := Teleport.movement_type(blush, true)
	var self_forced := {
		unit = blush, target_tiles = [DESTINATION], resource = own_type,
		object = SpecificAction.create(blush, field_gear(), field_gear().kit.get_action(ACTION_ID)),
	}
	assert_eq(Teleport.forcer(Context.create(self_forced)), blush,
		'Fixture: the forcer really does read back as the mech itself.')
	assert_false(would_offer(self_forced),
		'And a mech is not its own enemy, so the forcer clause refuses it too.')

func test_an_involuntary_teleport_forced_by_an_ally_is_not_offered():
	# The other half of the forcer clause, and the one that makes UnitRelation.are_enemies do work:
	# without it, an ALLY's repositioning effect would prompt the player to refuse it. Reading the
	# forcer at all is tested above; this is the test that the RELATION is read too.
	var friendly := {
		unit = blush, target_tiles = [DESTINATION], resource = hostile_teleport_type(),
		object = SpecificAction.create(ally, null, null),
	}
	assert_true(would_offer(voluntary_teleport_data()), 'CONTROL: a teleport IS offered.')
	assert_false(would_offer(friendly), 'An ally moving us is not a thing to fade out of.')

func test_a_prospector_tunnel_is_not_offered():
	# A Prospector tunnel is not a teleport (close-out Pass F Task 4, 2026-09-27): the talents mod's
	# Prospector hands the move a runtime MovementType subclass carrying
	# `func is_tunneling() -> bool: return true`, VOLUNTARY like any ordinary player-side teleport - so
	# without Teleport.is_tunnel this reads exactly like Abjuration's own teleport and the field would
	# offer to fade instead of tunnelling.
	var s := GDScript.new()
	s.source_code = "extends MovementType\nfunc is_tunneling() -> bool: return true\n"
	s.reload()
	var type:MovementType = s.new()
	type.teleport = true
	type.voluntary = true
	assert_true(would_offer(voluntary_teleport_data()), 'CONTROL: an ordinary teleport IS offered.')
	assert_false(would_offer({unit = blush, target_tiles = [DESTINATION], resource = type}),
		'But a tunnel is not - is_tunnel excludes it even though it is voluntary and reads as a teleport.')

func test_a_second_offer_in_the_same_round_is_refused():
	# The engine's per-round hard limit, consulted inside does_reaction_trigger via can_activate_gear -
	# so the second teleport is never OFFERED rather than offered and refused.
	responder.chosen_yesnos = true
	await teleport_by_path(DESTINATION)
	assert_eq(uses_this_round(), 1, 'Fixture: the first fade spent the round.')

	assert_false(would_offer(voluntary_teleport_data(Vector2i(7, 2))),
		'A second teleport in the same round is not offered.')
	var mark := yesno_mark()
	var core := await teleport_by_path(Vector2i(7, 2))
	assert_eq(yesnos_since(mark).size(), 0, 'No prompt.')
	assert_eq(blush.tile(), Vector2i(7, 2), 'And this one lands.')
	assert_false(core.aborted, 'Un-vetoed.')

# ------------------------------------------------- the consolation shares this round (ruling B)

## Drive a real Abjuration of Metal whose cone comes back EMPTY, and take the consolation fade.
##
## The hostile is moved ADJACENT first, because that is what empties the cone at a roll of one: no
## tile one space away closes as much as it costs to reach, and the attacker's far side is two away.
## EVERY die in the run is fixed at 1 - the triggering d20, the engaged difficulty die, the rifle's
## damage dice and Abjuration's own d6 - so the roll cannot come back as a 2 and offer a tile after
## all. The stock responder answers every yes/no true, which is both prompts: Abjuration's confirm and
## then the consolation.
func abjuration_with_an_empty_cone() -> void:
	responder.chosen_yesnos = true
	UnitTile.move_to(hostile, Vector2i(3, 2))
	MaidensBlushFixture.equip_ranged(hostile)
	Dice.CHEAT_ROLL_QUEUE.clear()
	for _die in 13: Dice.CHEAT_ROLL_QUEUE.append(MaidensBlushFixture.MISS_ROLL)
	await SpecFactory.use_solo(game, hostile, MaidensBlushFixture.RANGED_ID, [blush])

func test_a_consolation_fade_spends_the_round_the_interception_would_have_used():
	# THE RISK RULING B CARRIES, MEASURED (reach design §2). The field's 1/round is the ENGINE's, held
	# in gear.uses_this_round under this action's usage_group and read by
	# UnitAction.is_under_per_round_limit - and a direct call from another action is outside every path
	# that normally maintains it. If the consolation spent Abjuration's accounting instead of this
	# trait's, a player would fade through the consolation AND again on a real teleport in the same
	# round, with nothing red anywhere.
	await abjuration_with_an_empty_cone()
	assert_eq(uses_this_round(), 1, 'Fixture: the consolation fired and spent a round.')

	assert_false(would_offer(voluntary_teleport_data()),
		'So an ordinary teleport in the same round is not offered the fade at all.')
	var mark := yesno_mark()
	var core := await teleport_by_path(DESTINATION)
	assert_eq(yesnos_since(mark).size(), 0, 'No prompt.')
	assert_eq(blush.tile(), DESTINATION, 'And this one lands.')
	assert_false(core.aborted, 'Un-vetoed.')

func test_a_spent_round_refuses_the_consolation_too():
	# THE SAME GATE FROM THE OTHER SIDE. The engine refuses a second INTERCEPTION by never offering it
	# (ReactionBus asks can_activate_gear before it queues anything), but nothing stands between
	# Abjuration and a direct call - so fade() has to ask for itself. Without that question the mech
	# fades twice in one round: once at a teleport and once as a consolation.
	responder.chosen_yesnos = true
	await teleport_by_path(DESTINATION)
	assert_eq(uses_this_round(), 1, 'Fixture: the first fade spent the round at a real teleport.')
	assert_eq(blush.tile(), BLUSH_TILE, 'Fixture: and vetoed it, so the mech is still on its origin.')

	# BREAK THE INVISIBLE BEFORE THE ATTACK, so the miss below is an ordinary one. Left standing, the
	# fade would force the miss itself and the setup would be arguing with the thing it is setting up -
	# a red here has to mean "the consolation fired twice", never "the attack never happened".
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_false(faded(), 'Fixture: the fade is broken, so the mech is an ordinary target again.')
	assert_eq(uses_this_round(), 1, 'Fixture: and breaking it did not give the round back.')

	var mark := yesno_mark()
	await abjuration_with_an_empty_cone()

	assert_eq(uses_this_round(), 1, 'The consolation was refused: still one fade this round.')
	assert_eq(yesnos_since(mark).size(), 1,
		"And exactly one prompt was opened - Abjuration's own confirm, with no fade offer behind it.")

func test_the_reaction_spends_no_reaction_point():
	# consumes_rxn = false. The card does not charge one, and a mech that fades out of a hostile shove
	# on the enemy's turn must not lose its Overwatch for it.
	responder.chosen_yesnos = true
	var before:int = blush.core.current.reactions
	await teleport_by_path(DESTINATION)
	assert_eq(uses_this_round(), 1, 'Fixture: it really did fire.')
	assert_eq(blush.core.current.reactions, before, 'And the reaction point is untouched.')

func test_the_invisible_clears_at_the_blushs_next_turn_start():
	# "until the beginning of its next turn" is Lancer.UNTIL.START_OF_TURN, which
	# UnitCondition.new_turn_for_statuses clears inside handle_starting_unit
	# (unit_condition.gd:21). Driven through a REAL fade rather than fade_by_hand, so the duration the
	# trait applies is what expires - not one a helper chose.
	#
	# IT TAKES A REAL TURN, and that is the half this test was missing. The duration is only observable
	# against the turn END: an UNTIL.END_OF_THIS_TURN fade would also be gone by the assertion at the
	# bottom, so without the middle assertion this test stays green for a trait that drops the fade a
	# whole enemy turn early - which is the fade the frame's entire kit is built to survive.
	# SpecFactory.start_turn is what makes the end real: event_turn_end refuses a unit that never
	# started one (event_turn_end.gd:13), and only its execute() runs end_turn_for_statuses
	# (:40 -> unit_condition.gd:33-34), which is what clears END_OF_THIS_TURN.
	await SpecFactory.start_turn(game, blush)
	assert_true(blush.state.is_taking_turn,
		'fixture: the Blush really is taking a turn, so the end of it below is a real turn end.')
	responder.chosen_yesnos = true
	await teleport_by_path(DESTINATION)
	assert_true(faded(), 'Fixture: faded.')

	await SpecFactory.end_turn(game, blush)
	assert_true(faded(),
		'It SURVIVES the end of the turn it was taken on - "until the beginning of its NEXT turn", not'
		+ ' until the end of this one. This is the assertion that makes the duration observable.')

	await SpecFactory.start_turn(game, blush)
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'Gone at the start of the next turn.')

func test_a_real_fade_arms_fade_strike_at_the_blushs_next_turn_start():
	# THE FRAME'S SIGNATURE CHAIN, END TO END, and the justification ruling 7 rests on: teleport, fade
	# through the enemy turn, reroll the first melee strike. Both halves are pinned separately - this
	# file owns the fade, test_fade_strike.gd owns the chip - but test_fade_strike.arm() HAND-APPLIES
	# the status, so until this test nothing drove a real Uncertainty Field Invisible into a real
	# arming. The two sources agree today (same status, same START_OF_TURN, and the arming buff is
	# source-agnostic); this is the assertion that survives a future change to either trait.
	#
	# THE TIMING IS THE WHOLE POINT. event_turn_start fires NEW_TURN / PRE before handle_starting_unit
	# clears START_OF_TURN statuses, so a fade that lasts "until the beginning of its next turn" is
	# still up when the arming buff looks and gone by the time the turn runs.
	#
	# THE MUTATION THIS TEST ANSWERS, in action_uncertainty_field.gd's apply_status call: the duration
	# Lancer.UNTIL.START_OF_TURN -> Lancer.UNTIL.END_OF_THIS_TURN. end_turn_for_statuses clears
	# END_OF_THIS_TURN at the Blush's turn end (unit_condition.gd:33-34), so by the NEW_TURN / PRE
	# below there is no Invisible left to arm on and the chip assertion goes red. It is the HAND-OFF
	# between the two traits that this mutation attacks, which is what makes it the right one here and
	# not the obvious PRE -> POST on buff_fade_strike_arm.tres - that one also reddens
	# test_fade_strike.gd's own test_invisible_at_turn_start_leaves_the_chip_on_the_blush, so it does
	# not isolate this chain at all.
	#
	# WHICH IS WHY THE TURN IS STARTED FIRST. event_turn_end refuses a unit that never started a turn
	# (event_turn_end.gd:13) and end_turn_for_statuses only runs inside its execute() (:40), so without
	# this line the turn end below is not a turn end and the mutation above has nothing to act on.
	await SpecFactory.start_turn(game, blush)
	assert_true(blush.state.is_taking_turn,
		'fixture: a real turn, so the end of it really expires end-of-turn durations.')
	responder.chosen_yesnos = true
	await teleport_by_path(DESTINATION)
	assert_true(faded(), 'Fixture: a REAL fade, taken from a real teleport offer.')

	await SpecFactory.end_turn(game, blush)
	await SpecFactory.start_turn(game, blush)
	assert_true(UnitCondition.has_buff(blush, FADE_STRIKE_CHIP_ID),
		'The field\'s own Invisible armed Fade Strike\'s chip.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE),
		'And the fade itself is gone once the turn is running - the chip is what survives it.')

# ---------------------------------------------------------------- the damage break

func test_kinetic_damage_above_zero_clears_the_invisible():
	fade_by_hand()
	assert_true(faded(), 'Fixture: faded.')
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'Taking damage broke the fade.')

func test_damage_to_somebody_else_leaves_the_fade_alone():
	# THE HOLDER CHECK (buff_uncertainty_field_break.gd:59). The bus polls EVERY unit's buffs on every
	# DAMAGE POST with the SAME event, so without that one line the Blush drops its fade the moment
	# anybody on the map is shot - a player-visible defect, and one no other test in this file would see,
	# because every other damage case aims at the Blush.
	#
	# Driven through a REAL fade rather than fade_by_hand: this is the case where what is being
	# protected is the whole chain, not just the status.
	responder.chosen_yesnos = true
	await teleport_by_path(DESTINATION)
	assert_true(faded(), 'Fixture: the Blush really faded.')

	await damage_unit(hostile, BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_gt(hostile.current_damage(), 0, 'Fixture: the hostile really took the damage.')
	assert_true(faded(),
		'And the Blush kept its fade - somebody else being shot is not "it takes damage".')

	# THE CONTROL, in the same test: the identical hit on the Blush DOES break it, so the assertion
	# above is the holder check doing the work and not a break buff that never fires at all.
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_false(faded(), 'CONTROL: the same damage on the Blush itself breaks it.')

func test_heat_does_not_clear_the_invisible():
	# Heat is not damage in Lancer, and it reaches DAMAGE POST through the same event - so this is a
	# gate the trait has to carry rather than something the engine does for it. buff_suppress.gd:28 is
	# vanilla's own exclusion of heat from "damages".
	fade_by_hand()
	await take_damage(3, Lancer.DAMAGE_TYPE.HEAT)
	assert_true(faded(), 'Heat leaves the fade alone.')
	assert_gt(blush.core.current.heat, 0, 'fixture: the heat really was applied.')

func test_a_hit_zeroed_by_armor_does_not_clear_the_invisible():
	# A REAL GATE, not an engine observation. event_unit_damage does NOT abort a hit armor reduced to
	# nothing: capped_damage is a BuffResistDamage cap defaulting to 9999, never the armor-reduced
	# amount (measured on the Myconid, 2026-09-16), so the event reaches DAMAGE POST carrying
	# context.number 0 and only the trait's own `<= 0` clause refuses it.
	#
	# THE FRAME'S OWN ARMOR IS 0 (the sheet), so this test writes core.current.armor directly rather
	# than FrameIsolation'ing the frame - a deep duplicate would hand the unit COPIES of its trait
	# Kits, whose compcon_id does not survive duplicate(), and field_gear() would stop finding
	# anything. The health assertion below is the fixture self-check that the armor really applied; if
	# it fails, the armor write is what to fix, not the trait.
	blush.core.current.armor = TEST_ARMOR
	fade_by_hand()
	var health_before:int = blush.core.current.health
	await take_damage(TEST_ARMOR, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(blush.core.current.health, health_before, 'fixture: armor really stopped all of it.')
	assert_true(faded(), 'A shot that bounced off the armor does not break the fade.')

func test_an_overshield_soaked_hit_clears_it():
	# RULING 6, and the case that makes the `<= 0` clause a POST-armor read rather than a "did it
	# hurt" read: the Overshield soak happens inside damage() against a local and never writes back to
	# context.number, so a hit absorbed entirely by Overshield still reads positive and still breaks
	# the fade.
	await game.execute_event(&'event_unit_overshield', {unit = blush, number = 10})
	assert_eq(blush.state.overshield, 10, 'fixture: the Overshield is up.')
	fade_by_hand()
	var health_before:int = blush.core.current.health
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(blush.core.current.health, health_before, 'fixture: the Overshield soaked all of it.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'And the fade broke anyway.')

func test_burn_damage_clears_the_invisible():
	# A burn TICK is an event_unit_damage of category BURN (event_turn_end.gd queues one), so what
	# matters to this trait is the category, and that is what is driven here directly. Ruling 6 counts
	# it.
	fade_by_hand()
	await take_damage(2, Lancer.DAMAGE_TYPE.BURN)
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE), 'Burn breaks the fade.')

func test_invisible_from_another_source_survives_the_damage():
	# THE SOURCE QUALIFIER (ruling 6's refinement). A Cloaking Field's or a Mirage's Invisible is not
	# the Blush's own trait's to strip. Both are applied, and only ours goes.
	fade_by_hand()
	SpecFactory.apply(blush, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.MANUAL, OTHER_SOURCE)
	assert_true(UnitCondition.has_status(blush, Lancer.STATUS.INVISIBLE, OTHER_SOURCE),
		'fixture: the other source applied.')
	await take_damage(BITING_DAMAGE, Lancer.DAMAGE_TYPE.KINETIC)
	assert_false(faded(), 'Ours went...')
	assert_true(UnitCondition.has_status(blush, Lancer.STATUS.INVISIBLE, OTHER_SOURCE),
		'...and theirs stayed.')
	assert_true(blush.has_status(Lancer.STATUS.INVISIBLE),
		'So the Blush is still Invisible overall - which is the point of the qualifier.')
