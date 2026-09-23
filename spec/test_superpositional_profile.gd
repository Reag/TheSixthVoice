# SUPERPOSITIONAL PROFILE (Purple Thorn rank III system, SP4 Task 2, design ruling 15).
#
#   UNIQUE, SHIELD, LIMITED 3, SP 2. Shimmer (Reaction, 1/round). Trigger: You are targeted by a
#   ranged attack. Effect: Expend a charge, the attack gains +2 DIFFICULTY, if the attack misses
#   you may immediately teleport to a space within range 3.
#
# Pinned here: the offer (a ranged weapon attack on the Thorn raises Shimmer's yes/no; a melee one
# and a tech one do not; no reaction point or no charge, no offer; a decline spends nothing); the
# yes (the point and a charge spent, +2 Difficulty on THAT roll - a 14 that hits without it misses
# with it); the blink (a miss opens the reticle within 3 and the Thorn teleports there - read by
# the Uncertainty Field's own Teleport.is_teleport; a hit opens nothing; a cancel leaves the point
# and the charge spent; the blink never spends a charge; the stamp is cleared either way); the card
# (UNIQUE + SHIELD = 17, the rows).
#
# THE HOSTILE SHOOTS WITH THE VANILLA ASSAULT RIFLE (1d6, RELIABLE 2, no accuracy die of its own)
# against the Thorn's Evasion 10. Dice per shot: the d20, then Shimmer's two Difficulty d6 when it
# is taken (the highest counts), then the damage d6. Fixture.shoot cycles the HOSTILE's turn, which
# hands every unit its reaction point back (event_turn_start.gd:42-44); a second shot in the same
# turn is shoot_again, which does not.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_superpositional_profile.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Shimmer := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_superpositional_profile/action_shimmer.gd')

const KIT_ID := &'ms_superpositional_profile'
const SHIMMER_ID := &'action_shimmer'
const BLINK_ID := &'action_shimmer_blink'
const DIFFICULTY_BUFF := &'buff_shimmer_difficulty'

const MELEE := &'mw_heavy_melee_weapon'
const FRAGMENT_SIGNAL := &'ms_fragment_signal'

const THORN_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(8, 6)
const ADJACENT_TILE := Vector2i(5, 6)
## Two west of the Thorn - free, within 3 - where the reticle is asked to land.
const LANDING := Vector2i(2, 6)
## Far outside range 3: the reticle's CANCEL answer.
const UNREACHABLE := Vector2i(25, 11)

## 14 hits Evasion 10 bare, and misses it under +2 Difficulty when the highest d6 is a 6.
const D20_EDGE := 14
const D20_HITS := 19
const RIFLE_D6 := 4

var game:Gamemaster
var thorn:Unit
var hostile:Unit
var gear:GearCore
var responder
var watcher:PromptWatcher
var moves:MoveWatcher


## The Thorn's moves, read the way the Uncertainty Field reads one (test_vigil.gd's MoveWatcher),
## installed on the hostile.
class MoveWatcher extends ActionReaction:
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
		seen.append({unit = context.unit, teleport = Teleport.is_teleport(context)})
		return false


func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	watcher = add_child_autoqfree(PromptWatcher.new())
	thorn = Fixture.create_thorn(game, THORN_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	Fixture.arm_rifle(hostile)
	Fixture.equip(hostile, MELEE)
	Fixture.equip(hostile, FRAGMENT_SIGNAL)
	moves = MoveWatcher.new()
	install_on(hostile, moves, &'spec_move_watcher')
	gear = Fixture.equip(thorn, KIT_ID)
	responder.chosen_yesnos = false
	responder.chosen_move_tile = UNREACHABLE

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
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

## The hostile's rifle at the Thorn, its turn cycled first. `take` answers Shimmer's yes/no.
func rifle_at_thorn(rolls:Array[int], take:bool = true) -> void:
	responder.yesno_queue.assign([take])
	Fixture.queue(rolls)
	await Fixture.shoot(game, hostile, thorn, Fixture.MAIN_RIFLE)

## Shimmer's yes/no, counted apart from vanilla's Brace offer, which a heavy hit on the Thorn raises
## as a yes/no of its own (the melee case's Heavy Melee Weapon does exactly that).
func shimmer_offers() -> int:
	return responder.yesno_prompts.filter(func(prompt:Dictionary) -> bool:
		return not str(prompt.title).to_lower().contains('brace')
	).size()

func reticles() -> Array[Dictionary]:
	return watcher.kinds(PromptWatcher.KIND.move_tile)

func reactions() -> int: return thorn.core.current.reactions
func hp() -> int: return thorn.core.current.health
func stamp() -> String: return String(gear.get_state(Shimmer.STAMP_KEY, ''))

# ---------------------------------------------------------------- the offer

func test_a_ranged_attack_offers_shimmer():
	await rifle_at_thorn([D20_HITS, 1, 1, RIFLE_D6], false)
	assert_eq(shimmer_offers(), 1, 'A ranged attack on the Thorn raises Shimmer\'s yes/no.')

func test_a_decline_spends_nothing():
	var charges := gear.charges_current
	await rifle_at_thorn([D20_EDGE, RIFLE_D6], false)
	assert_eq(shimmer_offers(), 1, 'fixture: offered.')
	assert_eq(gear.charges_current, charges, 'A decline keeps the charge.')
	assert_eq(reactions(), 1, 'A decline keeps the point.')
	assert_eq(stamp(), '', 'A decline arms nothing.')
	assert_eq(reticles().size(), 0, 'No blink without Shimmer.')

func test_a_melee_attack_does_not_offer():
	Fixture.step(hostile, ADJACENT_TILE)
	responder.yesno_queue.assign([true])
	Fixture.queue([D20_HITS, RIFLE_D6])
	await Fixture.shoot(game, hostile, thorn, MELEE)
	assert_eq(shimmer_offers(), 0, 'A melee attack is not a ranged attack.')

func test_a_tech_attack_does_not_offer():
	responder.yesno_queue.assign([true])
	Fixture.queue([D20_HITS])
	await Fixture.shoot(game, hostile, thorn, FRAGMENT_SIGNAL)
	assert_eq(shimmer_offers(), 0, 'A tech attack is not a ranged attack.')

func test_with_no_charges_it_does_not_offer():
	gear.charges_current = 0
	await rifle_at_thorn([D20_HITS, RIFLE_D6])
	assert_eq(shimmer_offers(), 0, 'An empty LIMITED system offers nothing.')

func test_the_second_ranged_attack_that_round_does_not_offer():
	await rifle_at_thorn([D20_HITS, 1, 1, RIFLE_D6])
	assert_eq(shimmer_offers(), 1, 'fixture: the first was offered and taken.')
	responder.yesno_queue.assign([true])
	Fixture.queue([D20_HITS, RIFLE_D6])
	await Fixture.shoot_again(game, hostile, thorn, Fixture.MAIN_RIFLE)
	assert_eq(shimmer_offers(), 1, 'No reaction point left: the second attack offers nothing.')

# ---------------------------------------------------------------- the yes

func test_a_yes_spends_the_point_and_a_charge():
	var charges := gear.charges_current
	await rifle_at_thorn([D20_HITS, 1, 1, RIFLE_D6])
	assert_eq(gear.charges_current, charges - 1, 'Shimmer expends a charge.')
	assert_eq(reactions(), 0, 'Shimmer is the Thorn\'s reaction.')

func test_without_shimmer_the_edge_roll_hits():
	var before := hp()
	await rifle_at_thorn([D20_EDGE, RIFLE_D6], false)
	assert_eq(before - hp(), RIFLE_D6, 'The control: a 14 hits Evasion 10.')

func test_shimmer_makes_the_edge_roll_miss():
	var before := hp()
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(before - hp(), 2, "+2 Difficulty: 14 - 6 misses Evasion 10, and only the rifle's RELIABLE 2 lands.")

func test_the_difficulty_is_minus_two_accuracy_on_that_roll_only():
	var buff:Buff = ContentLibrary.get_buff(DIFFICULTY_BUFF)
	assert_not_null(buff, 'The buff loads.')
	if buff == null: return
	assert_eq(buff.to, Buff.TO.ATTACK_ROLL_INCOMING, 'On incoming attack rolls.')
	assert_eq(buff.bonus_subtype, &'accuracy', 'Accuracy, so it rolls as Difficulty dice.')
	assert_eq(buff.bonus_value, -2, '+2 Difficulty.')
	assert_eq(buff.until, Lancer.UNTIL.FINISH_ATTACK_ROLL, 'That roll only.')
	assert_true(buff.is_onetime, 'Consumed by the roll.')
	await rifle_at_thorn([D20_HITS, 1, 1, RIFLE_D6])
	assert_false(UnitCondition.has_buff(thorn, DIFFICULTY_BUFF), 'Gone once the roll is made.')

# ---------------------------------------------------------------- the blink

func test_a_miss_opens_the_reticle_and_the_thorn_teleports():
	responder.chosen_move_tile = LANDING
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(reticles().size(), 1, 'A miss opens the reticle.')
	assert_eq(thorn.tile(), LANDING, 'The Thorn lands where it was asked to.')
	var own := moves.seen.filter(func(seen:Dictionary) -> bool: return seen.unit == thorn)
	assert_eq(own.size(), 1, 'One move of the Thorn\'s.')
	if own.is_empty(): return
	assert_true(own[0].teleport, 'It is a teleport, read the Uncertainty Field\'s way.')

func test_the_reticle_offers_the_free_spaces_within_three():
	var expected := Teleport.candidate_tiles(thorn, 3, false)
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(reticles().size(), 1, 'fixture: the reticle opened.')
	if reticles().is_empty(): return
	var pathfinder:Pathfinder = reticles()[0].pathfinder
	var offered:Array[Vector2i] = pathfinder.movable_tiles.duplicate()
	offered.sort()
	expected.sort()
	assert_eq(offered, expected, "Exactly the free spaces within 3, line of sight not required (Vigil's set).")
	assert_true(offered.has(LANDING), 'The landing is on offer.')

func test_a_miss_without_shimmer_opens_nothing():
	responder.chosen_move_tile = LANDING
	await rifle_at_thorn([1, RIFLE_D6], false)
	assert_eq(shimmer_offers(), 1, 'fixture: offered and declined.')
	assert_eq(reticles().size(), 0, 'Only a Shimmered attack arms the blink: a plain miss opens nothing.')
	assert_eq(thorn.tile(), THORN_TILE, 'The Thorn stays put.')

func test_a_hit_opens_nothing():
	await rifle_at_thorn([D20_HITS, 1, 1, RIFLE_D6])
	assert_eq(reticles().size(), 0, 'A hit: no reticle.')
	assert_eq(thorn.tile(), THORN_TILE, 'The Thorn stays put.')
	assert_eq(stamp(), '', 'The stamp is cleared on a hit too.')

func test_a_cancelled_reticle_leaves_everything_spent():
	var charges := gear.charges_current
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(reticles().size(), 1, 'fixture: the reticle opened.')
	assert_eq(thorn.tile(), THORN_TILE, 'A cancel: no move.')
	assert_eq(gear.charges_current, charges - 1, 'The charge stays spent.')
	assert_eq(reactions(), 0, 'The point stays spent.')
	assert_eq(stamp(), '', 'The stamp is cleared on a miss too.')

func test_the_blink_never_spends_a_charge():
	var charges := gear.charges_current
	responder.chosen_move_tile = LANDING
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(thorn.tile(), LANDING, 'fixture: the blink happened.')
	assert_eq(gear.charges_current, charges - 1, 'One charge for the whole card - Shimmer\'s.')

func test_the_blink_runs_on_the_last_charge():
	gear.charges_current = 1
	responder.chosen_move_tile = LANDING
	await rifle_at_thorn([D20_EDGE, 6, 6, RIFLE_D6])
	assert_eq(gear.charges_current, 0, 'fixture: the last charge went on Shimmer.')
	assert_eq(thorn.tile(), LANDING, 'The blink still runs with the system empty.')

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 17, 'UNIQUE and SHIELD.')
	assert_true(kit.is_unique() and kit.is_shield(), 'Both flags read back.')
	assert_eq(kit.charges_max, 3, 'LIMITED 3.')
	var ids:Array = kit.actions.map(func(action:Action) -> StringName: return action.get_id())
	assert_eq(ids, [SHIMMER_ID, BLINK_ID], 'Shimmer and its blink.')

func test_the_rows_resolve():
	assert_eq(tr('gear.ms_superpositional_profile.name'), 'Superpositional Profile', 'The name row.')
	assert_eq(tr('gear.ms_superpositional_profile.action_shimmer.name'), 'Shimmer', 'The action row.')
	assert_string_contains(tr('gear.ms_superpositional_profile.action_shimmer.trigger'), 'ranged attack', 'The trigger row.')
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	if kit == null: return
	assert_true(kit.actions[0].show_in_tooltip(kit), 'Shimmer draws on the card.')
	assert_false(kit.actions[1].show_in_tooltip(kit), 'The blink does not.')
