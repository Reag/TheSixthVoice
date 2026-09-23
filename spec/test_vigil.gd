# VIGIL (Purple Thorn trait, SP1 Task 2).
#
#   "2/round, whenever the Purple Thorn deals damage, it may immediately teleport to a free space
#    within range 3. This teleport occurs before any other attacks are resolved."
#
# THE PICK IS A move_tile REQUEST, NOT reag_tile_set AND NOT compcon_plan. Vigil picks through
# TargetActionUtil.ask_for_movement over a real teleport pathfinder (the preventable route,
# ruling 3), whose player branch is choose_move_tile_for (target_action_util.gd:83). The stock
# responder answers it with responder.chosen_move_tile when set and with the first reachable tile
# otherwise (spec_factory.gd:417-428); testkit/prompt_watcher.gd records it as KIND.move_tile with
# the pathfinder, whose movable_tiles is what the player was actually offered. A CANCEL is driven
# the way test_abjuration_of_metal.gd drives one: answer with a tile the pathfinder cannot reach,
# and ask_for_movement_alt hands back a plan whose move_path is empty (target_action_util.gd:106).
# NOT responder.abort_all, which would also abort the attack's own targeting.
#
# THE DICE. The Nexus (Light) pops the d20, then one d3 for the HIT damage, then one d3 for the
# CRIT damage (roll_base_damage rolls both outcomes up front - "if hit:3 if crit:19" in the log),
# no accuracy die (Smart, against E-DEF 8: a 19 hits). So two shots in one case are
# [19, 3, 1, 19, 3, 1], not [19, 3, 19, 3]: measured on this file's second run, where the crit die
# ate the second d20 and the follow-up rolled a 3. The Missile Rack (Aux, BLAST 1, 1d3+1) pops one d20 PER TARGET and then ONE
# damage die for the whole attack (event_unit_attack_declared.gd:53-74 rolls every target first,
# then damage once). PurpleThornFixture.queue tails with 1s, which is a miss for any d20 that comes
# after the numbers given - so every queue here lists every d20 the case needs.
#
# EVERY TELEPORT IS ASSERTED THROUGH Teleport.is_teleport (design §6), read off ENTIRE_MOVEMENT PRE
# by a knockoff watcher on the hostile - the Uncertainty Field's own reader - so a route change
# that stops being a teleport goes red here, not only in play.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_vigil.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## A vanilla AUX BLAST 1 weapon: GMS Missile Rack, 1d3+1 EXPLOSIVE, Range 10, LOADING. One shot per
## case is all any case here needs.
const AUX_BLAST := &'mw_missile_rack'
## A vanilla weapon dealing TWO damage types on one hit: HA Sol-Pattern Laser Rifle, 1d6 ENERGY plus
## an additional damage value. Two event_unit_damage per victim, one attack.
const TWO_TYPE_RIFLE := &'mw_sol_pattern_laser_rifle'

const THORN_TILE := Vector2i(4, 6)
## Four east: inside the Nexus's Range 10, outside anything's threat.
const TARGET_TILE := Vector2i(8, 6)
## Two east of the Thorn - free, within 3 - where the specs ask the reticle to land.
const LANDING := Vector2i(6, 6)
## Where a SECOND landing goes: back to the start, which the first landing vacated.
const SECOND_LANDING := THORN_TILE
## On the map, far outside range 3 of anywhere the Thorn stands: the CANCEL answer.
const UNREACHABLE := Vector2i(25, 11)
## The Blast case's three victims: the centre and two neighbours inside a Blast 1 on the centre.
const BLAST_CENTRE := Vector2i(8, 6)
const BLAST_SIDE := Vector2i(9, 6)
const BLAST_BELOW := Vector2i(8, 7)
## The follow-up case: a target EXACTLY 10 from the Thorn (in the Nexus's range), and a landing
## three WEST, which puts the target at 13 - out of range for the mount's second Nexus.
const FAR_TARGET := Vector2i(14, 6)
const AWAY_LANDING := Vector2i(1, 6)
## The follow-up control: a landing that keeps the target in range.
const NEAR_LANDING := Vector2i(5, 6)

const D20_HITS := 19

var game:Gamemaster
var thorn:Unit
var hostile:Unit
## testkit/mod_choice_responder.gd - untyped, because its class is loaded at runtime and has no
## registrable class_name (res/content/gear/shared/README.md).
var responder
var watcher:PromptWatcher
var moves:MoveWatcher


## Records every ENTIRE_MOVEMENT PRE the bus offers, read the way the Uncertainty Field reads a
## move. Never activates. Installed on the HOSTILE as a runtime trait Kit (the probe's idiom), so it
## sees the Thorn's moves from the other side of the board.
class MoveWatcher extends ActionReaction:
	## One record per move offered: {unit, teleport, voluntary}. ONE PER EVENT, not per poll: the
	## bus asks triggers_on_event several times for one event (the Naga probe's measurement - three
	## polls for one teleport here), so records are keyed by the triggering core's id.
	var seen:Array[Dictionary] = []
	var seen_ids:Array[StringName] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if seen_ids.has(triggering_event.id): return false
		seen_ids.append(triggering_event.id)
		var context:Context = triggering_event.context
		seen.append({
			unit = context.unit,
			teleport = Teleport.is_teleport(context),
			voluntary = MovementType.is_contextual_move_voluntary(context),
		})
		return false


func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	thorn = Fixture.create_thorn(game, THORN_TILE)
	hostile = Fixture.create_hostile(game, TARGET_TILE)
	moves = MoveWatcher.new()
	install_on(hostile, moves, &'spec_move_watcher')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false


# ---------------------------------------------------------------- helpers

func install_on(unit:Unit, reaction:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(reaction)
	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## Tell the reticle where to land, then fire the Nexus (turn cycled first).
func shoot_landing_at(landing:Vector2i, target:Unit = hostile) -> void:
	responder.chosen_move_tile = landing
	Fixture.queue([D20_HITS, 3])
	await Fixture.shoot(game, thorn, target)

## The same, from a turn that is ALREADY open - the second shot of a round.
func shoot_again_landing_at(landing:Vector2i, target:Unit = hostile) -> void:
	responder.chosen_move_tile = landing
	Fixture.queue([D20_HITS, 3])
	await Fixture.shoot_again(game, thorn, target)

func reticles() -> Array[Dictionary]:
	return watcher.kinds(PromptWatcher.KIND.move_tile)

## What the reticle offered, read off the pathfinder the prompt carried.
func offered_tiles(index:int = 0) -> Array[Vector2i]:
	var seen := reticles()
	if seen.size() <= index: return []
	var pathfinder:Pathfinder = seen[index].pathfinder
	if pathfinder == null: return []
	return pathfinder.movable_tiles.duplicate()

func uses() -> int:
	return Fixture.uses_this_round(thorn, Fixture.VIGIL_ID, Fixture.VIGIL_ACTION_ID)

func thorn_teleports() -> Array[Dictionary]:
	return moves.seen.filter(func(record:Dictionary) -> bool: return record.unit == thorn)


# ---------------------------------------------------------------- the offer

func test_a_hit_offers_the_reticle_over_the_free_spaces_within_three_and_the_thorn_lands_there():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var expected := Teleport.candidate_tiles(thorn, 3, false)
	await shoot_landing_at(LANDING)
	assert_eq(hostile.current_damage(), 3, 'fixture: the Nexus hit for 3.')
	assert_eq(reticles().size(), 1, 'ONE reticle was raised for one hit.')
	var offered := offered_tiles()
	offered.sort()
	expected.sort()
	assert_eq(offered, expected, 'It offered exactly the free spaces within 3, line of sight not required.')
	assert_false(offered.has(THORN_TILE), 'The tile the Thorn stands on is not "a free space".')
	assert_eq(thorn.tile(), LANDING, 'The Thorn landed where it clicked.')
	assert_eq(uses(), 1, 'One of the two uses this round is spent.')
	var teleports := thorn_teleports()
	assert_eq(teleports.size(), 1, 'Exactly one move of the Thorn reached the bus...')
	if teleports.is_empty(): return
	assert_true(teleports[0].teleport, '...and it was a TELEPORT, by the Uncertainty Field\'s own reader.')
	assert_true(teleports[0].voluntary, 'And VOLUNTARY - the preventable Blinkspace shape (ruling 3).')

func test_the_offer_is_a_reticle_only_with_no_yes_no_before_it():
	# AUTHOR'S CALL (ruling 3): "may" is the reticle's cancel, not a confirm.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await shoot_landing_at(LANDING)
	assert_eq(reticles().size(), 1, 'fixture: the reticle was raised.')
	var confirms:Array = responder.yesno_prompts.filter(func(prompt:Dictionary) -> bool:
		return String(prompt.title).to_lower().contains('vigil'))
	assert_eq(confirms.size(), 0, 'No yes/no carried Vigil\'s name.')

func test_a_cancelled_reticle_spends_nothing_and_the_next_hit_that_round_offers_again():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await shoot_landing_at(UNREACHABLE)
	assert_eq(reticles().size(), 1, 'fixture: the first reticle was raised.')
	assert_eq(thorn.tile(), THORN_TILE, 'A cancelled pick moves nobody...')
	assert_eq(uses(), 0, '...and spends nothing.')
	await shoot_again_landing_at(LANDING)
	assert_eq(reticles().size(), 2, 'The next hit in the same round offers again.')
	assert_eq(thorn.tile(), LANDING, 'And this time it lands.')
	assert_eq(uses(), 1, 'One use spent in total.')

func test_the_offer_is_stamped_on_the_attack_taken_or_not():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	var gear:GearCore = thorn.get_gear(Fixture.VIGIL_ID)
	assert_eq(gear.get_state('vigil_last_attack', ''), '', 'fixture: no stamp before any attack.')
	await shoot_landing_at(UNREACHABLE)
	var stamp:String = gear.get_state('vigil_last_attack', '')
	assert_ne(stamp, '', 'A cancelled offer still stamps the attack it was offered on.')
	await shoot_again_landing_at(LANDING)
	assert_ne(gear.get_state('vigil_last_attack', ''), stamp, 'The next attack carries a different stamp.')


# ---------------------------------------------------------------- once per attack

func test_a_blast_hitting_three_offers_once():
	Fixture.mount_pair(thorn, 0, AUX_BLAST)
	var side:Unit = Fixture.create_hostile(game, BLAST_SIDE)
	var below:Unit = Fixture.create_hostile(game, BLAST_BELOW)
	responder.chosen_move_tile = LANDING
	Fixture.queue([D20_HITS, D20_HITS, D20_HITS, 2]) # three d20s, then the one damage die
	await Fixture.shoot(game, thorn, hostile, AUX_BLAST)
	assert_gt(hostile.current_damage(), 0, 'fixture: the centre took damage.')
	assert_gt(side.current_damage(), 0, 'fixture: the side victim took damage.')
	assert_gt(below.current_damage(), 0, 'fixture: the third victim took damage.')
	assert_eq(reticles().size(), 1, 'THREE damage events, ONE offer (ruling 2).')
	assert_eq(uses(), 1, 'And one use spent, not three.')
	assert_eq(thorn.tile(), LANDING, 'The Thorn landed once.')

func test_a_two_type_hit_offers_once():
	Fixture.equip(thorn, TWO_TYPE_RIFLE)
	responder.chosen_move_tile = LANDING
	Fixture.queue([D20_HITS, 4, 2]) # the d20, then one die per damage value
	await Fixture.shoot(game, thorn, hostile, TWO_TYPE_RIFLE)
	assert_gt(hostile.current_damage(), 4, 'fixture: both damage types landed (more than the first die alone).')
	assert_eq(reticles().size(), 1, 'TWO damage events, ONE offer.')
	assert_eq(uses(), 1, 'One use spent.')

func test_the_teleport_resolves_before_the_next_weapons_declared_attack():
	# RULING 3's "before any other attacks are resolved", MEASURED on the engine's own Aux/Aux
	# follow-up: the mount's second Nexus is queued at Priority.ACTIVATE.followup_attack on the
	# FIRST shot's activation, so it declares only after that shot's block - damage, DAMAGE POST,
	# and therefore Vigil - has run. The Thorn teleports THREE WEST first; the target is then 13
	# from it, out of Range 10, and the follow-up finds no target and never resolves. The control
	# below lands where the target stays in range, and the follow-up fires.
	Fixture.step(hostile, FAR_TARGET)
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS, Fixture.AUX_NEXUS)
	assert_eq(UnitRelation.distance_between(thorn, hostile), 10, 'fixture: exactly at the Nexus\'s range.')
	responder.chosen_move_tile = AWAY_LANDING
	Fixture.queue([D20_HITS, 3, 1, D20_HITS, 3, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.AUX_NEXUS, [Action.FLAG.CAN_FOLLOWUP])
	assert_eq(thorn.tile(), AWAY_LANDING, 'fixture: the Thorn teleported away on the first hit.')
	assert_eq(hostile.current_damage(), 3, 'The follow-up Nexus never fired: the teleport came first and took its target out of range.')

func test_the_follow_up_control_fires_when_the_landing_keeps_the_target_in_range():
	Fixture.step(hostile, FAR_TARGET)
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS, Fixture.AUX_NEXUS)
	responder.chosen_move_tile = NEAR_LANDING
	Fixture.queue([D20_HITS, 3, 1, D20_HITS, 3, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.AUX_NEXUS, [Action.FLAG.CAN_FOLLOWUP])
	assert_eq(thorn.tile(), NEAR_LANDING, 'fixture: the Thorn teleported one east.')
	assert_eq(hostile.current_damage(), 6, 'The follow-up fired: two Nexus hits landed.')
	assert_eq(reticles().size(), 2, 'And the second hit was its own attack, with its own offer.')


# ---------------------------------------------------------------- what does not offer

func test_an_armor_zeroed_hit_does_not_offer():
	# The POST is still queued (number 0 - the probe's measurement); the number > 0 gate refuses it.
	Fixture.arm_rifle(thorn)
	Fixture.set_armor(hostile, 3)
	responder.chosen_move_tile = LANDING
	Fixture.queue([D20_HITS, 1]) # Reliable 2 floors it at 2; armor 3 eats it
	await Fixture.shoot(game, thorn, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 0, 'fixture: armor zeroed the hit.')
	assert_eq(reticles().size(), 0, 'Dealing nothing is not "deals damage".')
	assert_eq(thorn.tile(), THORN_TILE, 'The Thorn stayed.')

func test_self_inflicted_heat_does_not_offer():
	# The shape unit_action.gd:299-306 issues for self-heat and overkill: target_unit = self plus
	# SELF_INFLICTED.
	responder.chosen_move_tile = LANDING
	await game.execute_event(&'event_unit_damage', {
		unit = thorn, target_unit = thorn, number = 1, category = Lancer.DAMAGE_TYPE.HEAT,
		flags = [EventService.DAMAGE_FLAG.SELF_INFLICTED],
	})
	assert_eq(thorn.core.current.heat, 1, 'fixture: the heat landed.')
	assert_eq(reticles().size(), 0, 'Heating yourself is not dealing damage.')

func test_damage_nobody_dealt_does_not_offer():
	responder.chosen_move_tile = LANDING
	await SpecFactory.damage(game, hostile, 2, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(hostile.current_damage(), 2, 'fixture: the damage landed.')
	assert_eq(reticles().size(), 0, 'A hazard with no dealer offers nothing.')

func test_being_shot_does_not_offer():
	Fixture.arm_rifle(hostile)
	responder.chosen_move_tile = LANDING
	Fixture.queue([D20_HITS, 4])
	await Fixture.shoot(game, hostile, thorn, Fixture.MAIN_RIFLE)
	assert_gt(thorn.current_damage(), 0, 'fixture: the Thorn was hit.')
	assert_eq(reticles().size(), 0, 'Taking damage is not dealing it.')

func test_the_third_damaging_attack_in_a_round_does_not_offer():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await shoot_landing_at(LANDING)
	await shoot_again_landing_at(SECOND_LANDING)
	assert_eq(thorn.tile(), SECOND_LANDING, 'fixture: two teleports taken.')
	assert_eq(uses(), 2, 'fixture: both uses spent.')
	await shoot_again_landing_at(LANDING)
	assert_eq(reticles().size(), 2, 'The third hit that round raises no reticle (2/round).')
	assert_eq(thorn.tile(), SECOND_LANDING, 'And the Thorn stays.')
	assert_eq(hostile.current_damage(), 9, 'fixture: all three shots landed regardless.')

func test_after_the_thorns_next_turn_start_it_offers_again():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await shoot_landing_at(LANDING)
	await shoot_again_landing_at(SECOND_LANDING)
	assert_eq(uses(), 2, 'fixture: the round is spent.')
	await shoot_landing_at(LANDING) # shoot() cycles the Thorn's turn: the tallies reset
	assert_eq(uses(), 1, 'A new turn start reset the tally and the hit was offered.')
	assert_eq(thorn.tile(), LANDING, 'And it landed.')

func test_an_immobilized_thorn_is_not_offered():
	# The preventable route (ruling 3): Pathfinder.create is the Immobilized gate (pathfinder.gd:333),
	# so the pathfinder over the free spaces comes back with nothing reachable and no reticle opens.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	UnitCondition.apply_status(SpecFactory.dummy_event(), thorn, Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)
	assert_true(UnitCondition.is_immobilized(thorn), 'fixture: immobilized.')
	assert_false(Teleport.candidate_tiles(thorn, 3, false).is_empty(), 'fixture: there ARE free spaces - the route is what stops it.')
	await shoot_landing_at(LANDING)
	assert_eq(hostile.current_damage(), 3, 'fixture: the hit landed.')
	assert_eq(reticles().size(), 0, 'No reticle for an Immobilized Thorn.')
	assert_eq(thorn.tile(), THORN_TILE, 'It did not move.')
	assert_eq(uses(), 0, 'And nothing was spent.')

func test_an_object_counts_as_dealing_damage():
	# The card says "deals damage", unqualified (ruling 2).
	var crate:Unit = Fixture.create_object(game, Vector2i(8, 8))
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	assert_false(crate.is_character(), 'fixture: a deployable is not a character.')
	await shoot_landing_at(LANDING, crate)
	assert_gt(crate.current_damage(), 0, 'fixture: the crate took damage.')
	assert_eq(reticles().size(), 1, 'Damaging an object offers Vigil.')
	assert_eq(thorn.tile(), LANDING, 'And the Thorn landed.')


# ---------------------------------------------------------------- wiring and card text

func test_the_wiring_and_the_card_text():
	var kit:Kit = ContentLibrary.get_kit(Fixture.VIGIL_ID)
	assert_not_null(kit, 'mt_vigil is indexed as a Kit.')
	if kit == null: return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var action = kit.get_action(Fixture.VIGIL_ACTION_ID)
	assert_not_null(action, 'action_vigil is on it.')
	if action == null: return
	assert_true(action is ActionReaction, 'A reaction...')
	assert_eq(action.triggers_on, [&'damage'] as Array[StringName], '...on DAMAGE...')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, '...POST.')
	assert_false(action.consumes_rxn, 'Point-free: a trait, not the reaction point.')
	assert_true(action.recheck_trigger_before_execution, 'Re-asks before running, so the stamp can refuse a queued sibling.')
	assert_eq(action.get_per_round_hard_limit(null), 2, '2/round.')
	assert_eq(action.usage_group, &'vigil', 'Its own usage group.')
	# Card text drawn ONCE (the Naga close's rule): the reaction's effect row is the Kit's own
	# sentence, so Action.show_in_tooltip hides it and the trait card draws the Kit alone.
	assert_false(action.show_in_tooltip(kit), 'The reaction hides from the trait card as a duplicate of the Kit\'s text.')
	var translation:Translation = load(OUR_TRANSLATION)
	if translation == null:
		fail_test('This mod has a compiled translation.')
		return
	for key:String in ['gear.mt_vigil.name', 'gear.mt_vigil.effect', 'gear.mt_vigil.action_vigil.name', 'gear.mt_vigil.action_vigil.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.mt_vigil.name'), 'Vigil', 'Named as the card.')
	assert_true(X.tr('gear.mt_vigil.effect').begins_with('2/round, whenever the Purple Thorn deals damage'),
		'The effect row opens as the card does.')
