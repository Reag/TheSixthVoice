# SAP (Vauban SP1 Task 4).
#
#   "When a hostile character within sensors and line of sight enters, or starts their turn, in an
#    area of difficult terrain, they must make a Hull save or become Slowed until the end of their
#    next turn. A character that succeeds this save is unaffected by Sap until the end of their next
#    turn."
#
# ABSORBS THE FIRST CLAIM OF spec/test_spike_vauban_probe.gd (design §1.0), which Task 6 deletes: a
# step-PRE reaction can Slow the mover before the step lands, AND THE MOVE STILL COMPLETES. Design
# §1.4 expected truncation; has_enough_move_to_reach_end reads current.speed only
# (event_unit_move.gd:468-476) and nothing in the move loop reads Slowed.
#
# THE VAUBAN HAS NO REACTION POINT IN before_each, AND THAT IS LOAD-BEARING RATHER THAN TIDY.
# Solfataric Breach is on this frame too (Task 3) and fires on exactly what Sap produces: a first
# Slowed on a hostile inside Sensors and sight. Its Impaired then costs the target 1 accuracy on
# every later save (unit_hasecheck.gd:195-196), which makes roll_check pop an EXTRA d6 off
# Dice.CHEAT_ROLL_QUEUE - so in a two-save test the second save would be handed the first save's
# leftover d20 as its difficulty die and the arithmetic would be nonsense. Sap is consumes_rxn =
# false, so it works perfectly with no point (is_gear_affordable only asks for one when
# requires_reaction_available, unit_action.gd:182), while Breach cannot fire at all. The ONE test that
# wants the two traits composing gives the point back explicitly and says so.
#
# EVERY SAVE POPS EXACTLY ONE d20, therefore: the save target is the FORCER's save target
# (event_unit_save.gd:41-43, so the Vauban's 12), the flat bonus is the SAVER's Hull (these dummies'
# is 0), and roll_d6_accuracy returns 0 without rolling when the accuracy bonus is 0 (dice.gd:86-88).
# A cheated 1 always fails and a cheated 20 always passes.
#
# DIFFICULT GROUND COSTS AN EXTRA POINT OF MOVEMENT (pathfinder.gd:93-100 sets extra_cost to 1, so a
# difficult tile costs 2), which is why the voluntary movers below are given speed 8: it keeps "it
# still arrived" a statement about Slowed rather than about the budget. The cases where the move's
# completion is not the claim use involuntary moves, which spend no speed and ignore the cost
# entirely (movement_type.gd:107-108) - and which the card and ruling 3 both count as entries.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_sap.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
## Only for create_deployable, which the Vauban fixture has no reason to re-expose.
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const TRAIT_ID := &'mt_sap'
const ACTION_ID := &'action_sap'
const REPRIEVE_BUFF := &'buff_sap_reprieve'
const BREACH_ID := &'mt_solfataric_breach'

const MAP_SIZE := Vector2i(15, 9)
const VAUBAN_TILE := Vector2i(2, 4)

## The main geometry: a four-step line east with a gap in the middle of the field.
##   (4,4) START clean -> (5,4) FIELD_A -> (6,4) clean -> (7,4) FIELD_B -> (8,4) DESTINATION clean
## The gap is what makes a second crossing a new entry rather than a step through. These single tiles
## serve the INVOLUNTARY cases, which go where they are told; the two voluntary walks need the bands
## below instead.
const START := Vector2i(4, 4)
const FIELD_A := Vector2i(5, 4)
const GAP := Vector2i(6, 4)
const FIELD_B := Vector2i(7, 4)
const DESTINATION := Vector2i(8, 4)

## THE TWO VOLUNTARY-MOVE CASES USE A FULL-HEIGHT BAND INSTEAD OF A TILE, AND THAT IS A MEASUREMENT.
## The brief's geometry laid a single difficult tile at FIELD_A and walked (4,4) -> (8,4) through it.
## THE PATHFINDER SIDESTEPS IT. Measured 2026-09-18 with the terrain confirmed difficult at move time:
## Pathfinder.generate_for_given_tiles handed back `(5, 3)(6, 4)(7, 4)(8, 4)` - four CLEAN steps at
## cost 1 - so the mover spent 4 of its 8, never entered the field, and the gate was never asked. That
## is the pathfinder doing its job (a difficult tile is extra_cost 1, pathfinder.gd:93-100, so a
## one-tile detour is strictly cheaper than crossing), not a defect in the trait: every involuntary
## case in this file, which does no pathfinding at all, passed on the same run.
##
## A band spanning the map's full height leaves nothing to route around, which is the only way to make
## a VOLUNTARY move cross difficult ground on purpose. The involuntary cases keep the single tiles
## above - a shove goes where it is told.
const BAND_A := 5
const BAND_B := 7

## The turn-start case: a hostile and the cover it owns, both standing in the field.
const COVER_TILE := Vector2i(5, 5)
const TURN_FIELD:Array[Vector2i] = [FIELD_A, COVER_TILE]

## The knockback case: a three-tall column east of the mover, because the Ram's knockback cone offers
## the responder a choice of column tiles and this spec does not care which one it takes (the probe's
## own reasoning).
const RAM_FROM := Vector2i(4, 4)
const RAM_TARGET := Vector2i(5, 4)
const KNOCK_COLUMN:Array[Vector2i] = [Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5)]

## Out of Sensors: (11,4) is 9 tiles from the Vauban at (2,4), and the frame's sensor_range is 8.
const FAR_FIELD := Vector2i(11, 4)
const FAR_START := Vector2i(12, 4)

## Out of sight: (8,4) is 6 tiles out - inside Sensors - with the wall between.
const BLIND_FIELD := Vector2i(8, 4)
const BLIND_START := Vector2i(9, 4)
const WALL:Array[Vector2i] = [
	Vector2i(5,0), Vector2i(5,1), Vector2i(5,2), Vector2i(5,3),
	Vector2i(5,4), Vector2i(5,5), Vector2i(5,6),
]

var game:Gamemaster
var vauban:Unit

## A saver-side recorder for the forced-save context, and the cheap probe design §2.0 says is enough
## for SP1 (SP2's own probe measures the owner-or-self hop properly).
##
## UnitHasecheck.roll_check builds a buff_context whose target_unit is the SAVER and whose unit/gear/
## action are the FORCER's (unit_hasecheck.gd:171-183), then fetches TO.SAVE buffs from the SAVER
## (:186) - the forcer's own read is commented out at :188-189. So a TO.SAVE buff on the target can
## see who forced the save, which is the Assassin's Mark shape.
##
## check_if_passive_applies RETURNS FALSE after recording, deliberately: a buff that applied would be
## consumed at :191 and would also add a value to the roll, changing the arithmetic every other test
## in this file depends on. Recording from a predicate that then declines is the whole trick.
class SaveRecorder extends Buff:
	var saves:Array[Dictionary] = []

	func _init() -> void:
		compcon_id = &'buff_spec_sap_save_recorder'
		to = Buff.TO.SAVE
		until = Lancer.UNTIL.MANUAL
		hide_from_player = true

	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		saves.append({
			forcer = context.unit.core.persistent_id if Unit.is_valid(context.unit) else &'',
			gear = context.gear.kit.compcon_id if GearCore.is_valid(context.gear) else &'',
			action = context.action.get_id() if context.action != null else &'',
			hase = context.category_int,
		})
		return false

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	# See the header: keeps Solfataric Breach out of every dice sequence in this file.
	vauban.core.current.reactions = 0

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## Queue the d20s these saves (and any attack before them) will pop, in order, then sixty sixes so
## nothing drains the FIFO into real RNG.
func queue_rolls(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack(rolls, buffer)

## A hostile that can afford to walk through the field: speed 8, so a four-step path costing 5 or 6
## still completes and "it arrived" says something about Slowed rather than about movement points.
func walker(tile:Vector2i) -> Unit:
	var mover := VaubanFixture.create_hostile(game, tile)
	mover.core.frame.stat.speed = 8
	mover.core.full_repair()
	return mover

## One step, involuntary: spends no speed and ignores the terrain cost entirely, so the only thing
## under test is the gate. Ruling 3 counts a pull or a shove into the area as an entry.
func shove(mover:Unit, to_tile:Vector2i) -> void:
	await SpecFactory.move(game, mover, to_tile, MovementType.create_for_involuntary(mover))

## Difficult ground filling the full height of one column, or of two. See BAND_A's comment: this is
## what a VOLUNTARY move cannot route around.
func bands(column_a:int, column_b:int = -1) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for column:int in [column_a, column_b]:
		if column < 0: continue
		for y:int in MAP_SIZE.y: tiles.append(Vector2i(column, y))
	return tiles

func slowed_by_sap(target:Unit) -> bool:
	return UnitCondition.has_status(target, Lancer.STATUS.SLOWED, vauban.get_gear(TRAIT_ID).persistent_id)

func reprieved(target:Unit) -> bool:
	return UnitCondition.has_buff(target, REPRIEVE_BUFF)

func install_save_recorder(on:Unit) -> SaveRecorder:
	var recorder := SaveRecorder.new()
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), on, BuffCore.create(recorder))
	return recorder

func place_wall() -> void:
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', WALL)
	game.map.calculate_los_blockers()

# ---------------------------------------------------------------- wiring and text

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_sap is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_eq(kit.passives.size(), 0, 'It carries no passives - the reprieve is applied by the script.')
	assert_eq(kit.actions.size(), 1, 'And exactly one action.')
	var action = kit.get_action(ACTION_ID)
	assert_not_null(action, 'The Kit carries action_sap.')
	if action == null: return
	assert_true(action is ActionReaction, 'It is a reaction.')
	assert_eq(action.triggers_on, [&'step', &'new_turn'] as Array[StringName],
		'Listening on BOTH halves of the card: entering, and starting a turn in.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE,
		'At PRE - which for `step` is the only timing the tile about to be entered is readable at '
		+ '(event_unit_move.gd:325-327).')
	assert_false(action.consumes_rxn,
		'NOT a real reaction: the card gives it no 1/round and no reaction point, so a Vauban that '
		+ 'has already Breached still Saps.')
	assert_eq(action.usage_group, &'action_sap', 'With its own usage group.')
	var specific := SpecificAction.from_id(vauban, TRAIT_ID, ACTION_ID)
	assert_eq(action.get_per_round_hard_limit(specific), 99, 'And no round cap at all.')

	# assert_not_null rather than the brief's Buff.is_valid: there IS no Buff.is_valid - Buff declares
	# only check_if_prohibited and check_required_triggering_context as statics, and the validity
	# helper lives on BuffCore instead. Measured 2026-09-18: the file did not PARSE with it, and every
	# other buff-wiring test in this mod (test_rend.gd:118-120, test_gather_round.gd:48-50) already
	# uses this shape. Same assertion, no weakening - get_buff returns the resource or null.
	var reprieve:Buff = ContentLibrary.get_buff(REPRIEVE_BUFF)
	assert_not_null(reprieve, 'buff_sap_reprieve is in the buffs index, so apply_buff_id finds it.')
	if reprieve == null: return
	assert_true(reprieve.hide_from_player, 'It is bookkeeping, never a chip on the unit.')
	assert_eq(reprieve.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'Until the end of their next turn.')

func test_the_rows_resolve_and_the_reaction_stays_off_the_trait_card():
	for key:String in ['gear.mt_sap.name', 'gear.mt_sap.effect',
			'gear.mt_sap.action_sap.name', 'gear.mt_sap.action_sap.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

	# THE REACTION GETS NO ROW OF ITS OWN ON THE TRAIT CARD, and there are two independent reasons -
	# which is deliberate, because the card is one paragraph describing one thing and a second copy of
	# it under a "Trigger:" heading is noise. First, the .gd overrides show_in_tooltip to false
	# outright (design §1.4, the Poisoned Soil lesson). Second, even without the override,
	# Action.show_in_tooltip (action.gd:350-353) returns false when an action's own effect equals the
	# KIT's generic one, and ruling 17 of the Maiden's Blush - the convention this follows - makes them
	# identical.
	#
	# This is what makes ICON_TARGETS[&'mt_sap'] an EMPTY list.
	assert_eq(X.tr('gear.mt_sap.action_sap.effect'), X.tr('gear.mt_sap.effect'),
		'The reaction row repeats the card text exactly.')
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	if not Kit.is_valid(kit): return
	var action = kit.get_action(ACTION_ID)
	if action == null: return
	assert_false(action.show_in_tooltip(kit), 'So no separate reaction row is drawn.')

# ---------------------------------------------------------------- entering

func test_a_hostile_entering_the_field_is_asked_for_a_hull_save_forced_by_the_vaubans_sap():
	# THE FORCER TRIPLE IS A CROSS-SUB-PROJECT CONTRACT. SP2's Grav-Amped Interference keys both its
	# +1 difficulty aura and its 3 AP reaction on "saves you force", resolved through
	# forcing_action.unit.get_owner_unit_or_self() (ruling 9) - so if this save were forced by anything
	# other than (the Vauban, the Sap gear, the Sap action), the core power would quietly not see it.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var mover := VaubanFixture.create_hostile(game, START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1])

	await shove(mover, FIELD_A)

	assert_eq(recorder.saves.size(), 1, 'Exactly one save was forced.')
	if recorder.saves.is_empty(): return
	assert_eq(recorder.saves[0].hase, Lancer.HASE.HULL, 'A HULL save, as the card says.')
	assert_eq(recorder.saves[0].forcer, vauban.core.persistent_id, 'Forced by the Vauban.')
	assert_eq(recorder.saves[0].gear, TRAIT_ID, 'Through the Sap gear.')
	assert_eq(recorder.saves[0].action, ACTION_ID, 'And the Sap action.')

func test_a_failed_save_slows_the_mover_and_the_move_still_completes():
	# THE PROBE'S CLAIM A, against the real trait. Design §1.4 expected the move to truncate here.
	# Four steps, one of them difficult: cost 2 + 1 + 1 + 1 = 5 against speed 8, so three are left
	# over - and asserting the exact remainder is what says Slowed took nothing extra rather than
	# happening not to matter.
	#
	# A BAND, NOT A TILE - see BAND_A. With one difficult tile the pathfinder walked around it, spent
	# 4, and the gate was never asked.
	VaubanFixture.lay_difficult(game, bands(BAND_A))
	var mover := walker(START)
	queue_rolls([1])

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_standard_move(mover))

	assert_true(slowed_by_sap(mover), 'The failed save Slowed the mover, sourced to the Sap gear.')
	assert_eq(mover.tile(), DESTINATION, 'And it still arrived: Slowed does not shorten the move it lands during.')
	assert_eq(mover.core.current.speed, 3, 'Having spent 5 of its 8 - one difficult tile at cost 2, three at 1.')

func test_a_passed_save_grants_a_hidden_reprieve_and_no_slow():
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var mover := VaubanFixture.create_hostile(game, START)
	queue_rolls([20])

	await shove(mover, FIELD_A)

	assert_false(slowed_by_sap(mover), 'A passed save Slows nobody.')
	assert_true(reprieved(mover), 'It grants the hidden reprieve instead.')

func test_a_reprieved_hostile_is_not_asked_again():
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var mover := VaubanFixture.create_hostile(game, START)
	var recorder := install_save_recorder(mover)
	queue_rolls([20, 1]) # the second roll is here to be NOT popped

	await shove(mover, FIELD_A)
	assert_true(reprieved(mover), 'fixture: the first save passed and granted the reprieve.')
	await shove(mover, START)
	await shove(mover, FIELD_A)

	assert_eq(recorder.saves.size(), 1, 'Only the first entry asked; the reprieve refused the second.')
	assert_false(slowed_by_sap(mover), 'And nothing Slowed it.')

func test_a_slowed_but_unreprieved_hostile_is_asked_again_and_a_second_failure_reapplies():
	# Ruling 4: an already-Slowed, unreprieved hostile still saves on its next entry, and a second
	# failure re-applies the status. Two listed StatusConditions is what "re-applies" looks like - and
	# it is also what Solfataric Breach's gate counts, which is why that trait refuses the second one.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var mover := VaubanFixture.create_hostile(game, START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1, 1])

	await shove(mover, FIELD_A)
	assert_true(slowed_by_sap(mover), 'fixture: the first save failed.')
	await shove(mover, START)
	await shove(mover, FIELD_A)

	assert_eq(recorder.saves.size(), 2, 'Being Slowed is no protection; it saves again.')
	var listed := 0
	for condition:StatusCondition in mover.state.statuses:
		if condition.type == Lancer.STATUS.SLOWED: listed += 1
	assert_eq(listed, 2, 'And a second failure re-applies the status.')

func test_walking_in_out_and_in_again_in_one_move_asks_twice():
	# Ruling 3, the author's call, over a once-per-round or once-per-movement cap. The clean column
	# between the two bands is what makes the second crossing a new entry rather than a step through.
	# Cost 2 + 1 + 2 + 1 = 6 against speed 8, so the whole walk is affordable.
	#
	# TWO BANDS, NOT TWO TILES - see BAND_A.
	VaubanFixture.lay_difficult(game, bands(BAND_A, BAND_B))
	var mover := walker(START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1, 1])

	await SpecFactory.move(game, mover, DESTINATION, MovementType.create_for_standard_move(mover))

	assert_eq(mover.tile(), DESTINATION, 'fixture: the whole walk happened.')
	assert_eq(recorder.saves.size(), 2, 'In, out and in again is TWO entries and two saves.')

func test_moving_from_one_difficult_tile_to_the_next_is_not_a_new_entry():
	# The other half of ruling 3, and the one that stops a walk THROUGH a field asking on every step.
	VaubanFixture.lay_difficult(game, [FIELD_A, GAP, FIELD_B])
	var mover := VaubanFixture.create_hostile(game, START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1, 1, 1])

	await shove(mover, FIELD_A)
	await shove(mover, GAP)
	await shove(mover, FIELD_B)

	assert_eq(recorder.saves.size(), 1, 'One entry, at the edge; the two steps inside ask nothing.')

func test_a_knockback_into_the_field_still_saves():
	# Ruling 3: "Knockbacks and pulls into the area count as entries." The real knockback path -
	# event_unit_pick_move into event_unit_move with the knocked unit as context.unit and IS_KNOCKBACK
	# set - which the probe measured reaching the step-PRE gate exactly like a walk.
	VaubanFixture.lay_difficult(game, KNOCK_COLUMN)
	var rammer := VaubanFixture.create_ally(game, RAM_FROM)
	var mover := VaubanFixture.create_hostile(game, RAM_TARGET, 0)
	queue_rolls([15, 1]) # the Ram's attack roll, then the Sap save

	await SpecFactory.use_solo(game, rammer, &'mw_ram', mover)

	assert_eq(mover.tile().x, 6, 'fixture: the Ram knocked it one tile east, into the column.')
	assert_true(mover.has_status(Lancer.STATUS.PRONE), 'fixture: and Prone, so the Ram really landed.')
	assert_true(slowed_by_sap(mover), 'An involuntary entry is still an entry.')

# ---------------------------------------------------------------- starting a turn in it

func test_a_hostile_starting_its_turn_in_the_field_saves_and_the_cover_it_owns_does_not():
	# THE SECOND HALF OF THE CARD, and the negative control that makes the gate's is_character() clause
	# load-bearing. event_turn_start fires a VIRTUAL new_turn PRE core for every deployable the
	# turn-taker owns (event_turn_start.gd:17-21), with the deployable as context.unit - so without
	# that clause a Jericho cover standing in the field would be asked to save, and
	# UnitHasecheck.make_hull_save returns false for a non-character without rolling anything
	# (unit_hasecheck.gd:53), which Sap would read as a FAILURE and Slow a piece of cover.
	VaubanFixture.lay_difficult(game, TURN_FIELD)
	var hostile := VaubanFixture.create_hostile(game, FIELD_A)
	VaubanFixture.equip_ranged(hostile)
	var cover := hostile_owned_cover(hostile)
	queue_rolls([1])

	await SpecFactory.start_turn(game, hostile)

	assert_true(slowed_by_sap(hostile), 'Starting its turn in the field, the hostile saves and fails.')
	assert_false(UnitCondition.has_status(cover, Lancer.STATUS.SLOWED),
		'Its cover, standing in the same field, is not a character and is never asked.')
	assert_false(reprieved(cover), 'Nor reprieved - it was never in the conversation at all.')

## A hostile-owned Jericho cover at COVER_TILE. Extracted only so the test above reads as one
## sentence; the OWNERSHIP is what puts it in event_turn_start's virtual-core loop (:17-21), and
## without it the test would prove nothing at all.
func hostile_owned_cover(owner_unit:Unit) -> Unit:
	var cover:Unit = FitzgeraldFixture.create_deployable(game, COVER_TILE, 10, 0, 5, Faction.AI_ENEMY)
	UnitAction.set_deployable_owner(cover, owner_unit, owner_unit.get_gear(VaubanFixture.RANGED_ID))
	VaubanFixture.track(game)
	assert_true(cover.state.is_owned_by(owner_unit),
		'fixture: the cover is owned by the hostile, so its turn start reaches this deployable.')
	assert_false(cover.is_character(), 'fixture: and it is an OBJECT, not a character.')
	return cover

func test_a_hostile_starting_its_turn_on_clean_ground_is_not_asked():
	# The control for the test above: the turn start itself is not what asks, the ground is.
	VaubanFixture.lay_difficult(game, [FIELD_B])
	var hostile := VaubanFixture.create_hostile(game, FIELD_A)
	var recorder := install_save_recorder(hostile)
	queue_rolls([1])

	await SpecFactory.start_turn(game, hostile)

	assert_eq(recorder.saves.size(), 0, 'Standing on clean ground, nobody is asked.')

# ---------------------------------------------------------------- who and where

func test_an_ally_and_the_vauban_itself_are_never_asked():
	# THE VAUBAN GOES FIRST, AND THE ORDER IS LOAD-BEARING RATHER THAN ARBITRARY. Measured 2026-09-18
	# with the brief's original order - ally into the field, then the Vauban after it: a unit cannot
	# END a move on a tile another unit occupies, so the Vauban's shove stopped short at (4,3) and it
	# never entered the field at all. Its assertion then passed for the wrong reason and said nothing
	# about the gate's `target == unit` clause, which is the whole point of the second half. Sending
	# the Vauban in, out again, and only then the ally keeps both halves real; the two fixture
	# assertions are what stop the order quietly rotting back.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	var ally := VaubanFixture.create_ally(game, START)
	var ally_recorder := install_save_recorder(ally)
	var vauban_recorder := install_save_recorder(vauban)
	queue_rolls([1, 1])

	await shove(vauban, FIELD_A)
	assert_eq(vauban.tile(), FIELD_A, 'fixture: the Vauban really is standing in its own field.')
	await shove(vauban, VAUBAN_TILE)
	await shove(ally, FIELD_A)
	assert_eq(ally.tile(), FIELD_A, 'fixture: and the ally really entered it too.')

	assert_eq(ally_recorder.saves.size(), 0, 'The card says HOSTILE character.')
	assert_eq(vauban_recorder.saves.size(), 0, 'And the Vauban does not Sap itself.')
	assert_false(slowed_by_sap(ally), 'So nobody was Slowed.')
	assert_false(slowed_by_sap(vauban), 'Not even standing in its own field.')

func test_a_hostile_entering_the_field_outside_sensors_is_not_asked():
	VaubanFixture.lay_difficult(game, [FAR_FIELD])
	var mover := VaubanFixture.create_hostile(game, FAR_START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1])
	assert_gt(Tile.distance(VAUBAN_TILE, FAR_FIELD), vauban.get_sensor_range(),
		'fixture: the ENTERED TILE is beyond Sensors 8 - which is where ruling 3 measures.')

	await shove(mover, FAR_FIELD)

	assert_eq(recorder.saves.size(), 0, 'Out of Sensors, out of reach.')

func test_a_hostile_entering_the_field_out_of_line_of_sight_is_not_asked():
	place_wall()
	VaubanFixture.lay_difficult(game, [BLIND_FIELD])
	var mover := VaubanFixture.create_hostile(game, BLIND_START)
	var recorder := install_save_recorder(mover)
	queue_rolls([1])
	assert_lt(Tile.distance(VAUBAN_TILE, BLIND_FIELD), vauban.get_sensor_range(),
		'fixture: the entered tile IS within Sensors - so sight is the only thing that can refuse it.')
	assert_false(UnitTile.is_tile_in_los(game.map, vauban.occupied_tiles(),
		UnitTile.effective_height(vauban, true), BLIND_FIELD, vauban.core.persistent_id),
		'fixture: and the wall blocks sight to it.')

	await shove(mover, BLIND_FIELD)

	assert_eq(recorder.saves.size(), 0, 'No sight of the entered tile, no save.')

# ---------------------------------------------------------------- economy, and the two traits together

func test_sap_needs_no_reaction_point_and_has_no_round_cap():
	# before_each has already set the Vauban's reactions to 0, and every test above it has fired Sap
	# anyway - so this test is about the SECOND half: three separate hostiles entering in one round
	# are all asked, where a real reaction would have answered once.
	VaubanFixture.lay_difficult(game, [FIELD_A, FIELD_B, GAP])
	assert_eq(vauban.core.current.reactions, 0, 'fixture: the Vauban has no reaction point at all.')
	var first := VaubanFixture.create_hostile(game, START)
	var second := VaubanFixture.create_hostile(game, Vector2i(5, 3))
	var third := VaubanFixture.create_hostile(game, Vector2i(7, 3))
	queue_rolls([1, 1, 1])

	await shove(first, FIELD_A)
	await shove(second, GAP)
	await shove(third, FIELD_B)

	assert_true(slowed_by_sap(first), 'The first is Sapped.')
	assert_true(slowed_by_sap(second), 'So is the second.')
	assert_true(slowed_by_sap(third), 'And the third - no point, no cap.')

func test_a_sap_failure_feeds_solfataric_breach():
	# THE TWO TRAITS TOGETHER, which is design §1.4's step order and the frame's whole engine: the
	# Slowed Sap applies is an ORDINARY status sourced to the Sap gear (ruling 4), so it is exactly
	# what Breach's gate sees. Everywhere else in this file the Vauban has no reaction point precisely
	# so that this does NOT happen and the dice stay readable; here the point is given back.
	VaubanFixture.lay_difficult(game, [FIELD_A])
	vauban.core.current.reactions = 1
	var mover := VaubanFixture.create_hostile(game, START)
	queue_rolls([1])

	await shove(mover, FIELD_A)

	assert_true(slowed_by_sap(mover), 'fixture: the save failed and Sap Slowed it.')
	assert_true(UnitCondition.has_status(mover, Lancer.STATUS.IMPAIRED,
		vauban.get_gear(BREACH_ID).persistent_id),
		'And Solfataric Breach fired on that Slowed, Impairing it.')
	assert_gt(mover.current_damage(), 0, 'Taking the Breach\'s 1d6 Kinetic.')
