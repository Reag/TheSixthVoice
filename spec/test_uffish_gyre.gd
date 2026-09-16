# THE PSYCHOPOMP FOLD PIKE AND UFFISH GYRE (Myconid, SP2 Task 4).
#
#   Weapon: "PFP// \"PSYCHOPOMP\" Fold Pike. Main Melee, SP 0, Damage none, Threat 8.
#    Effect: Gain the Uffish Gyre reaction, which is the only way you can attack with this weapon."
#   Reaction, 1/round:
#    Trigger: "An allied character within threat starts to move. This does not require line of sight
#     or a clear path between you and the target."
#    Effect:  "Make a melee attack against evasion 8, on hit the allied character gains +2 armor
#     until the start of their next turn. This doesn't count against the maximum number of reactions
#     you can make in a turn."
#
# THE MOVING UNIT'S TURN IS OPENED, NOT THE MYCONID'S, and that is the one thing about this file
# that is easy to get wrong. The Gyre is a reaction to somebody ELSE's movement, so every trigger
# test opens the MOVER's turn - a spec that opened the Myconid's would look at a broken trigger.
# It matters in a second way for test_a_second_gyre_in_the_round_is_refused: an ally's turn start
# runs every_new_turn_refresh for everyone (reaction POINTS) but new_turn_refresh only for the unit
# whose turn it is (unit_action.gd:67-78), and the per-ROUND usage counter the Gyre's 1/round reads
# is cleared by the latter. So two allies can move in one "round" and the limit still binds, while
# the Myconid's own turn start releases it.
#
# WHY THE RANGE CASES USE A ROW AND NOT A DIAGONAL. The Myconid is SIZE 2: anchored at (4,6) it
# occupies (4..5, 6..7), and UnitRelation.distance_between measures between FOOTPRINTS, so its east
# column x = 5 is what "within threat 8" is measured from. An ally at (13,6) is at exactly 8 and one
# at (14,6) at 9. assert_the_footprint_is_where_we_think_it_is pins that in every range test.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_uffish_gyre.gd
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
## Preloaded for its SPENT_KEY alone: test_the_gyre_spends_no_reaction_point asks whether Symbiosis
## stamped this reaction as the round's extra, and re-typing that key here is how the two would
## silently drift apart.
const SymbiosisBookkeeping := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_myconid/mt_symbiosis/buff_symbiosis.gd')

const PIKE_KIT := &'mw_psychopomp_fold_pike'
const STRIKE_ID := &'action_psychopomp_strike'
const GYRE_ID := &'action_uffish_gyre'
const ARMOR_CHIP := &'buff_uffish_gyre_armor'
const ARMOR_REDUCTION := &'buff_uffish_gyre_armor_reduction'

## Vanilla GMS Main Rifle: Range 10, 1d6 kinetic, no accuracy of its own. The CONTROL weapon for the
## cover and Prone cases - a ranged weapon really does take both, which is what makes "the Pike takes
## neither" a statement about the Pike.
const RIFLE := &'mw_assault_rifle'
## Vanilla GMS melee, threat 1, 1d6+2 kinetic: the control for the crit case, since it has no
## can_crit override of its own.
const MELEE := &'mw_tactical_melee_weapon'

## Wide enough for an ally at threat 9 from a size-2 Myconid plus room to move past it.
const MAP_SIZE := Vector2i(30, 12)

## A size-2 Myconid anchored here occupies (4..5, 6..7); its EAST column is x = 5.
const MYCONID_TILE := Vector2i(4, 6)
const AT_8 := Vector2i(13, 6)  # exactly threat
const AT_9 := Vector2i(14, 6)  # one past it
const AT_5 := Vector2i(10, 6)  # behind the wall
const WALL_X := 8              # between the Myconid and AT_5
## ONE TILE INSIDE THREAT, and the reason several tests start there rather than at AT_8: every move
## in this file is one tile EAST, so an ally that has to move TWICE (a case plus its control) would
## be at 9 by the second move and the control would fail for range rather than for what it is
## testing. Measured the hard way - the first full run lost four controls to exactly that.
const AT_7 := Vector2i(12, 6)
const AT_7_LOW := Vector2i(12, 7) # the same distance, one row down, for a second ally

## The strike rolls against a fixed 8 and a level-0 pilot has Grit 0, so 9 hits, 7 misses and 20
## would crit if anything let it.
const D20_HITS := 9
const D20_MISSES := 7
const D20_CRITS := 20

## Higher than the fixed 8, so a roll of 9 tells the two apart in one number: it HITS the 8 and would
## MISS this. The design's own worked case.
const HIGH_EVASION := 12

var game:Gamemaster
var myconid:Unit
var watcher:PromptWatcher
var recorder:AttackRecorder

# ---------------------------------------------------------------- the attack-roll probe

## Records every AttackRoll the game resolves, so a test can read hit/crit/target_defense off the
## REAL roll rather than off a preview. The ATTACK trigger at POST is the only timing that sees one:
## event_unit_attack.execute_preblock runs the PRE reactions before AttackRoll.create exists
## (event_unit_attack.gd:30-31, :54), while the POST block is queued at :123 with the same core,
## whose context.object is the finished roll (:56).
##
## A reaction that never fires - triggers_on_event records and returns false - so it costs no point,
## opens no prompt and cannot reorder anything. test_draw_fire.TerrainRecorder's idiom.
class AttackRecorder extends ActionReaction:
	var rolls:Array[AttackRoll] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var roll = triggering_event.context.object
		if roll is AttackRoll: rolls.append(roll)
		return false

	func last() -> AttackRoll: return rolls.back() if not rolls.is_empty() else null

# ---------------------------------------------------------------- fixture

func before_each() -> void:
	game = MyconidFixture.create_game(self, MAP_SIZE)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func pike_gear() -> GearCore: return myconid.get_gear(PIKE_KIT)
func strike() -> Action: return pike_gear().get_action(STRIKE_ID)
func gyre() -> Action: return pike_gear().get_action(GYRE_ID)
func strike_specific() -> SpecificAction: return SpecificAction.create(myconid, pike_gear(), strike())

## The Gyre's own per-round counter - what UnitAction.is_under_per_round_limit reads
## (unit_action.gd:170-175) and what action_uffish_gyre.gd's spend_actions() feeds.
##
## IT MEANS "THE REACTION SPENT ITS USE", NOT "THE REACTION TRIGGERED", and the two differ on
## purpose: the Gyre spends nothing unless the strike's own counter moved, so a declined confirm or a
## Stunned refusal leaves this at 0. Where a test needs to know that the trigger itself fired, it
## says so with a positive control that runs the same move from the same geometry.
func gyre_uses_this_round() -> int:
	var gear:GearCore = pike_gear()
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(gyre()))

func strike_uses_this_round() -> int:
	var gear:GearCore = pike_gear()
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(strike()))

## Sixty sixes after the one d20 we care about, so no accuracy or damage die drains the FIFO into
## real RNG. test_draw_fire.queue_dice's shape.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

func create_ally(tile:Vector2i, evasion:int = 10) -> Unit:
	return MyconidFixture.create_dummy(game, tile, evasion, Faction.PLAYER)

func create_hostile(tile:Vector2i, evasion:int = 10) -> Unit:
	return MyconidFixture.create_dummy(game, tile, evasion)

## A voluntary move of one tile EAST, inside the mover's own open turn - the ordinary case the card
## describes. `standard` spends the mover's move points, which is literally "a standard move";
## everything else about the two is identical as far as the gate is concerned.
func moves_east(unit:Unit, standard:bool = true) -> void:
	await MyconidFixture.open_turn(game, unit)
	var movement_type:MovementType = (
		MovementType.create_for_standard_move(unit) if standard else MovementType.create(unit, true)
	)
	await SpecFactory.move(game, unit, unit.tile() + Vector2i(1, 0), movement_type)

## The same move with the reactions flag set, which is the card's own exclusion.
func moves_east_ignoring_reactions(unit:Unit) -> void:
	await MyconidFixture.open_turn(game, unit)
	var movement_type := MovementType.create(unit, true)
	movement_type.ignore_rxns = true
	await SpecFactory.move(game, unit, unit.tile() + Vector2i(1, 0), movement_type)

## A REAL knockback, built the way the engine builds one, rather than a hand-rolled involuntary move:
## CommonActionUtil.generate_knockback_events is what every knocking effect in the game calls, and
## its movement type (common_action_util.gd:116-119) is what decides whether the Gyre sees it.
func knock_back(unit:Unit, spaces:int) -> void:
	await MyconidFixture.open_turn(game, unit)
	var events := CommonActionUtil.generate_knockback_events(unit, spaces, strike_specific(), myconid.occupied_tiles())
	assert_false(events.is_empty(), 'fixture: the knockback produced events.')
	await game.execute_event_block(EventBlock.create_multiple(events))

## A full-height column at WALL_X: blocks sight between the Myconid and anything east of it.
func build_wall() -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(WALL_X, y))
	SpecFactory.set_tiles_elevation(game.map, 6, wall)
	game.map.calculate_los_blockers()

## Equip a vanilla weapon on a unit and hand back its gear - the control weapons' installer.
## test_draw_fire.arm's shape.
func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	UnitTile.move_to(unit, unit.tile()) # full_repair rebuilt the size caches; re-track as the fixture does
	return weapon

## What a roll WOULD compute right now, without firing - the cover and Prone controls' instrument
## (test_draw_fire.preview, test_hybridized_shot.accuracy_for).
func preview(shooter:Unit, gear:GearCore, action:Action, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, gear, action)
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context)

func strike_preview(against:Unit) -> AttackRoll.PreAttack:
	return preview(myconid, pike_gear(), strike(), against)

## The ATTACK-POST probe, on the MOVER rather than the Myconid so that installing it cannot
## full_repair the Pike's own usage counters mid-test. ReactionBus.trigger_occurred walks every unit
## on the map (reaction_bus.gd:50-51), so whose loadout it sits on does not change what it sees.
func install_recorder(on_unit:Unit) -> void:
	recorder = AttackRecorder.new()
	var kit := Kit.new()
	kit.compcon_id = &'uffish_gyre_spec_recorder_kit'
	kit.is_trait = true
	kit.actions.append(recorder)
	on_unit.core.loadout.equipped_kits.append(kit)
	on_unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## The size-2 footprint is what every range constant in this file is measured against, and
## MyconidFixture.create_myconid's re-tracking line is what makes the map agree. Without it the
## Myconid is indexed at its anchor alone and AT_8 is 9 away, not 8 - which would look like a
## broken threat rather than a broken fixture.
func assert_the_footprint_is_where_we_think_it_is() -> void:
	assert_eq(myconid.occupied_tiles().size(), 4, 'fixture: the Myconid is size 2.')
	for tile:Vector2i in myconid.occupied_tiles():
		assert_true(game.map.get_all_units_at_tile(tile).has(myconid),
			'fixture: the map indexes the Myconid at %s.' % tile)

# ---------------------------------------------------------------- the activation gate

func test_the_strike_cannot_be_pressed_from_the_gear_bar():
	# "the only way you can attack with this weapon" is the Gyre, so the strike must be refused when
	# anything else asks for it. The refusal is the ENGINE's own hibernation flag
	# (starts_hibernating on the .tres -> REASON.HIBERNATING at unit_action.gd:154), applied by
	# GearCore.short_repair at scene setup (gear_core.gd:139-142), and this test was written first
	# and watched go RED against a .tres without that line.
	#
	# The reason is asserted as well as the refusal: HIBERNATING is what the player is shown, and a
	# different reason (a spent usage, a destroyed Kit) would refuse the press too while meaning
	# something else entirely.
	var ally := create_ally(AT_8)
	await MyconidFixture.open_turn(game, myconid)

	assert_eq(UnitAction.get_gear_unavailable_reason(strike_specific()), UnitAction.REASON.HIBERNATING,
		'The strike is hibernating, and that is the reason the player is shown.')
	assert_false(UnitAction.can_activate_gear(strike_specific()), 'So it cannot be activated.')

	# POSITIVE CONTROL ON THE GATE ITSELF, taken here and not at the end of the test, because the
	# press below spends the Myconid's Quick: asked again afterwards, can_activate_gear would come
	# back false for the per-turn limit and this control would pass for the wrong reason. (First
	# written that way; the RED run caught it - the second press ABORTED with "specific: invalid"
	# and the closing assertion passed only because the chip was still on the ally from the first.)
	pike_gear().wake_action(STRIKE_ID)
	assert_true(UnitAction.can_activate_gear(strike_specific()),
		'Awake and otherwise untouched, it IS activatable - so hibernation is the whole refusal.')
	pike_gear().hibernate_action(STRIKE_ID)

	queue_dice(D20_HITS)
	await SpecFactory.use(game, myconid, PIKE_KIT, STRIKE_ID, ally)
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP),
		'Pressing it does nothing: no armor was granted.')

	# And the very same press, with the action woken by hand exactly as action_uffish_gyre.gd wakes
	# it, lands - so what the refusal above refused was a press that otherwise works.
	pike_gear().wake_action(STRIKE_ID)
	queue_dice(D20_HITS)
	await SpecFactory.use(game, myconid, PIKE_KIT, STRIKE_ID, ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And the very same press now lands.')

func test_the_gyre_wakes_the_strike_only_for_its_own_shot():
	# THE BRACKET, which is what makes the hibernate gate compatible with the reaction that has to
	# get past it. The strike is asleep before, awake for exactly the length of the Gyre's
	# choose_and_use, and asleep again after - so a second reaction, an Overwatch weapon sweep or a
	# gear-bar press in the next turn all meet a hibernating action again.
	var ally := create_ally(AT_8)
	assert_true(pike_gear().is_action_hibernating(STRIKE_ID), 'Asleep to begin with.')

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: and its shot landed.')
	assert_eq(strike_uses_this_round(), 1,
		'The strike really activated - it has its own usage group, and its counter moved.')

	assert_true(pike_gear().is_action_hibernating(STRIKE_ID), 'And it is asleep again afterwards.')
	assert_eq(UnitAction.get_gear_unavailable_reason(strike_specific()), UnitAction.REASON.HIBERNATING,
		'So the gear bar is told HIBERNATING again, not something the shot left behind.')

# ---------------------------------------------------------------- the trigger

func test_an_ally_starting_a_standard_move_at_8_offers_the_gyre():
	# The card's ordinary case, at exactly threat. Reddened by moving the strike's threat to 7: the
	# gate reads the number off the weapon (action_uffish_gyre.strike_range), never off a constant.
	var ally := create_ally(AT_8)
	assert_the_footprint_is_where_we_think_it_is()
	assert_eq(UnitRelation.distance_between(myconid, ally), 8, 'fixture: the ally is at exactly 8.')

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'The Gyre fired.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And the ally is armored.')

func test_an_ally_at_9_does_not():
	# One tile past threat. The discriminating half of the pair above: a gate written with >= or with
	# a hardcoded 9 would pass that one and fail this.
	var far := create_ally(AT_9)
	var near := create_ally(AT_8)
	assert_eq(UnitRelation.distance_between(myconid, far), 9, 'fixture: the far ally is at 9.')

	queue_dice(D20_HITS)
	await moves_east(far)
	assert_eq(gyre_uses_this_round(), 0, 'Nothing fired.')
	assert_false(UnitCondition.has_buff(far, ARMOR_CHIP), 'And the far ally got nothing.')

	# POSITIVE CONTROL: the very same move, one tile closer, does fire.
	queue_dice(D20_HITS)
	await moves_east(near)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: an ally at 8 taking the same move does fire it.')
	assert_true(UnitCondition.has_buff(near, ARMOR_CHIP), 'CONTROL: and is armored.')

func test_an_ally_behind_a_wall_at_5_offers_and_is_armored():
	# "This does not require line of sight or a clear path between you and the target." Asserted all
	# the way to the armor, not just to the trigger: the sentence covers the STRIKE too, so the
	# .tres turns requires_line_of_sight_baseline off as well. A reaction that fired at a target the
	# attack could not legally pick would be a trigger that passed and a card that did not work.
	var ally := create_ally(AT_5)
	build_wall()
	assert_false(UnitRelation.can_see(myconid, ally), 'fixture: the wall really does block sight.')
	assert_eq(UnitRelation.distance_between(myconid, ally), 5, 'fixture: and the ally is at 5.')

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'The Gyre fired through the wall.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And the ally was armored through it.')

func test_a_knocked_back_ally_does_not_offer():
	# DESIGN RULING 11 IS WRONG ABOUT THIS ONE, and wrong in the same sentence that names the gate
	# excluding it: "Boosts, standard moves, knockback and pulls all count ... gated by
	# MovementType.is_contextual_move_reactable". That predicate is `not ignores_reactions()`, and
	# ignores_reactions() is `ignore_rxns or teleport or NOT VOLUNTARY` (movement_type.gd:101-102) -
	# so every forced move is excluded twice over. The GATE is the author's call and stands; the
	# list was a mistaken belief about what it covers. Vanilla parity: Overwatch does not fire on
	# forced movement either, which is the tabletop rule. Rulings row 2026-09-16.
	#
	# Driven through the engine's own knockback builder rather than a hand-rolled involuntary move,
	# so this measures what a real shove does and not what this file believes one looks like.
	# Starts at 5 so that the shove eastward leaves it at 7, still inside threat for the control.
	var ally := create_ally(AT_5)
	assert_true(MovementType.create_for_involuntary(ally).ignores_reactions(),
		'fixture: an involuntary move ignores reactions, which is what a knockback builds.')
	var before:Vector2i = ally.tile()

	queue_dice(D20_HITS)
	await knock_back(ally, 2)
	assert_ne(ally.tile(), before, 'fixture: the ally really was shoved.')
	assert_eq(gyre_uses_this_round(), 0, 'The Gyre did not fire on the shove.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And granted nothing.')

	# POSITIVE CONTROL: the same ally, from its new tile, taking a move of its own.
	assert_lte(UnitRelation.distance_between(myconid, ally), 8, 'fixture: still inside threat.')
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: a voluntary move by the same ally does fire it.')

func test_a_move_that_ignores_reactions_does_not():
	# The other half of the reactability gate, and the one the card names. Reddened by deleting the
	# is_contextual_move_reactable line. At 7 so that the control move, one tile further east, is
	# still inside threat.
	var ally := create_ally(AT_7)

	queue_dice(D20_HITS)
	await moves_east_ignoring_reactions(ally)
	assert_eq(gyre_uses_this_round(), 0, 'A move flagged to ignore reactions offers nothing.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And grants nothing.')

	# POSITIVE CONTROL: the identical move without the flag.
	queue_dice(D20_HITS)
	await moves_east(ally, false)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: the same move without the flag fires it.')

func test_a_move_that_is_not_a_standard_move_offers_too():
	# "starts to move", not "takes a Move action". spend_move is no part of the gate, and this is
	# what says so: a Boost, a Lunge or any other voluntary movement is inside the card.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally, false)
	assert_eq(gyre_uses_this_round(), 1, 'A voluntary move that spends no move points still fires it.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'And armors the mover.')

func test_a_hostile_moving_never_offers():
	# "An ALLIED character". Reddened by turning are_allies into are_enemies, which is Overwatch's
	# own sense and the easiest thing to copy wrongly out of action_overwatch.gd.
	var hostile := create_hostile(AT_8)
	var ally := create_ally(Vector2i(13, 7))

	queue_dice(D20_HITS)
	await moves_east(hostile)
	assert_eq(gyre_uses_this_round(), 0, 'A hostile mover offers nothing.')
	assert_false(UnitCondition.has_buff(hostile, ARMOR_CHIP), 'And is never armored by us.')

	# POSITIVE CONTROL: an ally the same distance away, taking the same move.
	assert_eq(UnitRelation.distance_between(myconid, ally), 8, 'fixture: the ally is at 8 too.')
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: an ally at the same range does fire it.')

func test_the_myconids_own_move_never_offers():
	# UnitRelation.are_allies(unit, unit) is TRUE - Faction.is_ally of a faction against itself
	# (faction.gd:30) - so without the explicit `mover != unit` clause a Myconid would pike itself
	# every time it moved. Reddened by dropping that clause.
	var ally := create_ally(AT_8)

	queue_dice(D20_HITS)
	await moves_east(myconid, false)
	assert_eq(gyre_uses_this_round(), 0, 'The Myconid does not react to its own movement.')
	assert_false(UnitCondition.has_buff(myconid, ARMOR_CHIP), 'And armors nobody.')

	# POSITIVE CONTROL: it is not that the Gyre is broken - an ally moving fires it at once.
	# (The Myconid moved one tile east, so the ally is now 7 away rather than 8.)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: an ally moving fires it.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'CONTROL: and is armored.')

# ---------------------------------------------------------------- the roll

func test_the_strike_rolls_against_8_whatever_the_evasion():
	# "against evasion 8". An Evasion 12 ally and a d20 of 9: against the real Evasion the roll
	# misses, against the fixed 8 it hits, so one number tells the two apart. Reddened by deleting
	# modify_pre_attack_data - which is also what proves the 8 is OURS and not
	# AttackUtil.calculate_target_defense's unreachable `return 8` fallthrough (attack_util.gd:46).
	var ally := create_ally(AT_8, HIGH_EVASION)
	assert_eq(AttackUtil.calculate_target_defense(ally, AttackRoll.ATTACK_TYPE.WEAPON), HIGH_EVASION,
		'fixture: the engine would otherwise roll against 12.')
	assert_eq(strike_preview(ally).target_defense, 8, 'The pre-attack data says 8.')

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP),
		'A 9 hit, which it could only do against the 8.')

func test_cover_on_the_ally_adds_no_difficulty():
	# A fixed 8 makes the ally's defensive state irrelevant, and cover is difficulty rather than
	# defence, so modify_pre_attack_data does not cancel it. Nothing in the Pike's script does
	# either: ActionAttackWeapon.ignores_cover already returns true for a MELEE weapon with
	# threat > 0 (action_attack_weapon.gd:206-212). The CONTROL is what makes this a statement about
	# the Pike rather than about the terrain - the same terrain is cover against a rifle.
	#
	# THE COVER IS THE WALL, NOT A ONE-BLOCK STEP, and the first run is why. cover_calculator.gd:148-151
	# ignores intervening terrain whose ground elevation is not above BOTH ends of the ray, and the
	# Myconid is SIZE 2 - its upper voxel is already level with a height-1 block, so a raised tile
	# gives its target no cover at all against it (measured: cover came back NONE for the rifle too,
	# which would have made this test pass for the wrong reason). test_draw_fire.gd's header records
	# the same trap from the other side. The full-height column clears that test comfortably.
	var ally := create_ally(AT_5)
	build_wall()
	var rifle := arm(myconid, RIFLE)

	assert_ne(preview(myconid, rifle, rifle.get_solo_action(), ally).cover, Lancer.COVER.NONE,
		'CONTROL: the wall really is cover for this ally against an ordinary weapon.')
	assert_eq(strike_preview(ally).cover, Lancer.COVER.NONE, 'The Pike sees no cover.')
	assert_eq(strike_preview(ally).accuracy_mods_total(), 0, 'And nothing modifies its roll.')

func test_a_prone_ally_adds_no_accuracy():
	# The other half of the same clause, and this one IS a real override
	# (action_psychopomp_strike.is_accuracy_against_prone): Prone is +1 accuracy for the ATTACKER
	# (attack_roll.gd:176-178) and no melee or cover rule cancels it. Reddened by deleting the
	# override, which restores ActionAttack's `return true` (action_attack.gd:45).
	var ally := create_ally(AT_8)
	SpecFactory.apply(ally, Lancer.STATUS.PRONE)
	var rifle := arm(myconid, RIFLE)

	assert_eq(preview(myconid, rifle, rifle.get_solo_action(), ally).accuracy_mods_total(), 1,
		'CONTROL: Prone really is +1 accuracy for an ordinary weapon.')
	assert_eq(strike_preview(ally).accuracy_mods_total(), 0, 'The Pike takes none of it.')

func test_a_crit_is_a_plain_hit():
	# can_crit is false, so a natural 20 is a hit and nothing more: AttackRoll.roll_attack computes
	# `crit = (total_roll >= 20) and hit and can_crit` (attack_roll.gd:73). Read off the REAL roll
	# through the ATTACK-POST probe. The control is a vanilla melee weapon taking the same 20 from
	# the same Myconid, which does crit - so this is a statement about the Pike, not about the
	# cheated die.
	var ally := create_ally(AT_8)
	var hostile := create_hostile(Vector2i(6, 6), -10) # adjacent, for the threat-1 control weapon
	install_recorder(ally)

	queue_dice(D20_CRITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired.')
	assert_not_null(recorder.last(), 'fixture: a roll was recorded.')
	if recorder.last() == null: return
	assert_true(recorder.last().hit, 'A 20 hits.')
	assert_false(recorder.last().crit, 'And is a plain hit: the Pike cannot crit.')

	var melee := arm(myconid, MELEE)
	await MyconidFixture.open_turn(game, myconid)
	queue_dice(D20_CRITS)
	await SpecFactory.use_solo(game, myconid, MELEE, hostile)
	assert_true(recorder.last().crit, 'CONTROL: an ordinary weapon taking the same 20 does crit.')

func test_no_damage_is_ever_dealt():
	# "Damage: none". get_damage_for_attack returns {}, so nothing is rolled at all - an empty
	# damage_dice alone would still build a zero-damage summary and log a damage line. Reddened by
	# deleting the override.
	var ally := create_ally(AT_8)
	var before:int = ally.core.current.health

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: the strike hit.')
	assert_eq(ally.core.current.health, before, 'The ally took no damage from being piked.')

func test_a_miss_grants_nothing():
	# The negative control for every on-hit assertion in this file: the armor rides on
	# OnHitEffect.STAGE.ON_HIT, so a miss must leave the ally with nothing. Without this, an on-hit
	# accidentally set to ON_ATTACK would pass every other test here.
	var ally := create_ally(AT_8)

	queue_dice(D20_MISSES)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'The Gyre fired and spent its use.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'But a miss grants no chip.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'And no reduction either.')

# ---------------------------------------------------------------- the armor

func test_a_hit_applies_the_chip_and_the_reduction():
	# An armor grant in this mod is always TWO buffs (design ruling 8): the visible STATBLOCK chip
	# that every unit.get_armor() gate reads, and the hidden reduction that actually blunts the
	# damage. Both are asserted by id, because dropping either from the on-hit leaves a mechanic
	# that half works - a chip that blunts nothing, or damage going missing with nothing on screen.
	var ally := create_ally(AT_8)
	var armor_before:int = ally.get_armor()

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'The visible chip is on the ally.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'And so is the hidden reduction.')
	assert_eq(ally.get_armor(), armor_before + 2, 'The readout says two more armor.')

func test_the_ally_takes_2_less_kinetic_until_its_next_turn_start():
	# The mitigating half doing its job. Reddened by setting reduction_amount to "1".
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'fixture: the reduction is on.')

	var before:int = ally.core.current.health
	await SpecFactory.damage(game, ally, 5, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(before - ally.core.current.health, 3, 'Five kinetic landed as three.')

func test_and_not_after_its_next_turn_start():
	# "until the start of THEIR next turn" - the struck ally's own turn start, which is the unit
	# UnitCondition.new_turn_for_statuses clears START_OF_TURN buffs on (unit_condition.gd:22-23).
	# Reddened by setting either half's `until` to MANUAL, which would make the armor permanent.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: armored.')

	await SpecFactory.end_turn(game, ally)
	await SpecFactory.start_turn(game, ally)
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'The chip is gone at its next turn start.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'And so is the reduction.')

	var before:int = ally.core.current.health
	await SpecFactory.damage(game, ally, 5, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(before - ally.core.current.health, 5, 'Five kinetic lands as five again.')

func test_an_ap_hit_on_the_ally_is_not_reduced():
	# Real armor does not stop AP, and neither may this stand-in: damage_modifications.gd:103 guards
	# only the ARMOR branch with the AP flag while `other_reduction` is subtracted unconditionally at
	# :110, so buff_armor_reduction.gd overrides check_if_passive_applies to refuse an AP context.
	# Reddened by deleting that override.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'fixture: the reduction is on.')

	var before:int = ally.core.current.health
	await SpecFactory.damage(game, ally, 5, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP])
	assert_eq(before - ally.core.current.health, 5, 'Five AP kinetic landed as five.')

	# POSITIVE CONTROL: the very same five, without the flag, is blunted - so the reduction was there
	# the whole time and AP is what got through it.
	before = ally.core.current.health
	await SpecFactory.damage(game, ally, 5, Lancer.DAMAGE_TYPE.KINETIC)
	assert_eq(before - ally.core.current.health, 3, 'CONTROL: the same hit without AP lands as three.')

func test_the_battle_log_names_the_pike_for_the_reduction():
	# COSMETIC, MEASURED, AND PINNED SO IT CANNOT MOVE UNNOTICED. buff_armor_reduction.gd's
	# divergence 4 records that a blunted hit logs the reducing BUFF's name rather than "armor", and
	# left this specific question open for whoever built the Pike: that fall-through wants the owning
	# Kit to have exactly ONE action, and this Kit has two. Measured here - Translate.buff walks
	# gear.<buff_id> (translate.gd:56-58), then gear.<kit_id>.<buff_id> (:68-70), then
	# gear.<kit_id>.<SOLO ACTION> (:72-75), and get_solo_action() is kit.actions[0] with no arity
	# check (gear_core.gd:337-339) - so it lands on the STRIKE's name, not the Gyre's.
	#
	# A real string and the right weapon, which is why it is accepted rather than fixed; it is pinned
	# because reordering the Kit's actions would silently change what the player reads.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	var reduction:BuffCore = UnitCondition.get_buff(ally, ARMOR_REDUCTION)
	assert_not_null(reduction, 'fixture: the reduction is on the ally.')
	if reduction == null: return
	assert_eq(reduction.name_text(), 'Psychopomp Fold Pike',
		'The hidden reduction reads as the strike, the Kit s first action.')
	assert_eq(UnitCondition.get_buff(ally, ARMOR_CHIP).name_text(), 'Uffish Gyre',
		'CONTROL: the visible chip has a row of its own and reads correctly.')

# ---------------------------------------------------------------- the action economy

func test_the_gyre_spends_no_reaction_point():
	# "This doesn't count against the maximum number of reactions you can make in a turn."
	# consumes_rxn = false, so ActionReaction.is_available_to_activate returns before
	# UnitAction.can_take_reactions is ever asked (action_reaction.gd:49). Reddened by setting
	# consumes_rxn = true.
	#
	# THE SYMBIOSIS MIRROR (ruling 11's other half). test_symbiosis's
	# test_a_non_consuming_reaction_is_neither_refused_nor_stamped makes this claim against a
	# synthetic reaction; this is it against the real one. Both the point count AND the Symbiosis
	# stamp are asserted, because the trait's bookkeeping keys on the point going.
	var ally := create_ally(AT_8)
	await MyconidFixture.open_turn(game, myconid)
	var before:int = myconid.core.current.reactions
	assert_gt(before, 0, 'fixture: the Myconid has reactions to spend.')

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired.')
	assert_eq(myconid.core.current.reactions, before, 'And spent no reaction point.')
	var symbiosis:BuffCore = UnitCondition.get_buff(myconid, &'buff_symbiosis')
	assert_not_null(symbiosis, 'fixture: Symbiosis is on the Myconid.')
	if symbiosis == null: return
	assert_false(bool(symbiosis.get_state(SymbiosisBookkeeping.SPENT_KEY, false)),
		'And Symbiosis did not stamp it as the round s extra reaction.')

func test_a_second_gyre_in_the_round_is_refused():
	# "1/round", which ActionReaction does NOT give a non-consuming reaction - it returns 99
	# (action_reaction.gd:69) - so action_uffish_gyre.get_per_round_hard_limit puts it back.
	# Reddened by deleting that override.
	#
	# TWO DIFFERENT ALLIES, because the chip from the first would otherwise still be on the mover and
	# "did the second fire" could not be asked of the armor at all.
	var first := create_ally(AT_8)
	var second := create_ally(AT_7_LOW) # at 7, so its SECOND move still starts inside threat

	queue_dice(D20_HITS)
	await moves_east(first)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the first move fired it.')

	queue_dice(D20_HITS)
	await moves_east(second)
	assert_eq(gyre_uses_this_round(), 1, 'The second ally s move did not fire it again.')
	assert_false(UnitCondition.has_buff(second, ARMOR_CHIP), 'And the second ally got nothing.')

	# POSITIVE CONTROL, and it also pins design ruling 5's accepted divergence: the counter is
	# cleared by UnitAction.reset_per_round_usage, which runs at the MYCONID's own turn start
	# (event_turn_start -> new_turn_refresh, unit_action.gd:74-78) - not at a game round boundary.
	await SpecFactory.start_turn(game, myconid)
	assert_eq(gyre_uses_this_round(), 0, 'CONTROL: the Myconid s own turn start clears the counter.')
	queue_dice(D20_HITS)
	await moves_east(second)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: and the same ally s next move fires it again.')
	assert_true(UnitCondition.has_buff(second, ARMOR_CHIP), 'CONTROL: and arms it.')

func test_a_stunned_myconid_cannot_strike():
	# RULING 11's CROSS-SEAM CLAIM, and the second half of it (test_symbiosis owns the first). A
	# non-consuming reaction passes its OWN gates while Stunned - action_reaction.gd:62-66 derive all
	# four can_be_used_while_* from requires_reaction_available(), which is false here - so the Gyre
	# really does trigger. The refusal comes from the STRIKE, re-validated inside choose_and_use by
	# event_gear_activate.check_specific_context (content/events/event_gear_activate.gd:46-51), which
	# prints "[ Gear not available ] reason : STUNNED" in red and aborts.
	#
	# BOTH HALVES ARE ASSERTED, and the reason with them. "The ally was not armored" alone would pass
	# just as well if the Gyre had never triggered at all, which is a different mechanism and a
	# different bug; the positive control at the end fires the very same move from the very same
	# geometry, so the trigger is proven by construction.
	#
	# THE GYRE'S 1/ROUND IS NOT SPENT HERE, and that is deliberate rather than an oversight:
	# action_uffish_gyre.activate spends nothing unless the strike's own usage counter moved, so a
	# Myconid that could not strike has not used its reaction. Pinned below, and by
	# test_a_declined_friendly_fire_confirm_costs_nothing.
	var ally := create_ally(AT_7)
	SpecFactory.apply(myconid, Lancer.STATUS.STUNNED)
	assert_true(UnitAction.can_activate_gear(SpecificAction.create(myconid, pike_gear(), gyre())),
		'The REACTION is not refused: a non-consuming reaction survives Stunned.')

	# The reason the strike is refused, asked of the engine directly and as a FREEBIE - which is how
	# the Gyre asks it - with the action woken exactly as the Gyre wakes it.
	pike_gear().wake_action(STRIKE_ID)
	assert_eq(UnitAction.get_gear_unavailable_reason(strike_specific(), true), UnitAction.REASON.STUNNED,
		'And the STRIKE is refused, as a freebie, for being Stunned.')
	pike_gear().hibernate_action(STRIKE_ID)

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(strike_uses_this_round(), 0, 'End to end: the strike never activated.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'So the ally was not armored.')
	assert_eq(gyre_uses_this_round(), 0, 'And the Gyre spent no use on a strike that never happened.')

	# POSITIVE CONTROL: unstunned, the same ally's next move arms it - so what was refused was a
	# strike that otherwise lands, from this geometry, with this die.
	UnitCondition.clear_status(SpecFactory.dummy_event(), myconid, Lancer.STATUS.STUNNED)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'CONTROL: unstunned, the strike lands.')
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: and the Gyre spends its use when it does.')

func test_the_player_is_asked_to_confirm_the_friendly_attack():
	# MEASURED, and it is what makes action_uffish_gyre.gd's spend conditional. The design and the
	# plan both assumed the strike would run silently: choose_and_use auto-picks when a
	# player-controlled unit has exactly one option (common_action_util.gd:657-659) and the target is
	# mandatory. It does - there is no weapon menu - but the ATTACK itself asks twice: a compcon
	# targeting plan, and TargetActionUtil.confirm_friendly_fire's yes/no, which fires precisely
	# because the target is an ALLY (action_attack.gd:247, target_action_util.gd:430-435).
	#
	# Pinned rather than suppressed. The confirm is correct in play - "you are about to attack your
	# own teammate" is worth asking once - and it is the cancel path the spend guard exists for.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired, so there was something to ask about.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: and its shot landed.')

	var yesnos := watcher.kinds(PromptWatcher.KIND.yesno)
	assert_eq(yesnos.size(), 1, 'Exactly one yes/no was raised: %s' % [watcher.prompts])
	if yesnos.is_empty(): return
	assert_eq(String(yesnos[0].description), 'battle.confirm.friendly_fire',
		'And it is the friendly-fire confirmation.')

func test_a_declined_friendly_fire_confirm_costs_nothing():
	# THE CANCEL PATH, and the reason action_uffish_gyre.activate checks the strike's usage counter
	# before spending. Declining aborts the child activation (action_attack.gd:247), so nothing was
	# struck - and charging the round's one use for a shot the player refused would be Draw Fire's
	# mistake in reverse (action_draw_fire.gd:170-200: nothing is spent until the draw has landed).
	var ally := create_ally(AT_7)
	SpecFactory.current_responder.chosen_yesnos = false

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'The refused strike granted nothing.')
	assert_eq(strike_uses_this_round(), 0, 'And never activated.')
	assert_eq(gyre_uses_this_round(), 0, 'So the Gyre spent none of its 1/round.')
	assert_true(pike_gear().is_action_hibernating(STRIKE_ID),
		'And the strike was put back to sleep even though the activation aborted.')

	# POSITIVE CONTROL: say yes to the very next move and everything lands, so the refusal above was
	# the decline and not a broken trigger.
	SpecFactory.current_responder.chosen_yesnos = true
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'CONTROL: confirmed, the strike lands.')
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: and the use is spent.')

# ---------------------------------------------------------------- localisation

## Our OWN compiled artifact, not the global TranslationServer: a bare tr() would answer from
## whatever is loaded and pass against text nobody ships (test_myconid_frame.gd's note).
func our_translation() -> Translation:
	return load('res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation')

func test_the_weapon_name_row_carries_its_quotes():
	# The LCP stores the name with escaped quotes (PFP// \"PSYCHOPOMP\" Fold Pike); the card's real
	# text has plain ones, and in a CSV field that means the whole value is quoted and each inner "
	# is doubled. Asserted through the compiled artifact rather than read off the CSV, because
	# getting the escaping wrong yields a row that still LOOKS right in the source file - the
	# artifact is what the player sees. Reddened by breaking the escaping.
	var translation:Translation = our_translation()
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_eq(String(translation.get_message('gear.mw_psychopomp_fold_pike.name')),
		'PFP// "PSYCHOPOMP" Fold Pike', 'The weapon name keeps both of its quotation marks.')
	assert_eq(Translate.gear(PIKE_KIT, 'name'), 'PFP// "PSYCHOPOMP" Fold Pike',
		'And that is what the game asks Translate for.')

func test_the_gyres_effect_row_keeps_the_lcps_apostrophe():
	# RULING 14, byte-exactness. The LCP's detail field carries U+2019 RIGHT SINGLE QUOTATION MARK in
	# "doesn't" (raw bytes e2 80 99), not an ASCII apostrophe, and the directive is the LCP verbatim
	# once the HTML wrapper and the glossary pipes are accounted for. A CSV typed on a keyboard would
	# quietly get this wrong and nothing else in the suite would notice.
	var translation:Translation = our_translation()
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	var effect := String(translation.get_message('gear.mw_psychopomp_fold_pike.action_uffish_gyre.effect'))
	assert_true(effect.contains('doesn’t'), 'The effect row keeps the LCP s curly apostrophe.')
	assert_false(effect.contains("doesn't"), 'And does not carry an ASCII one instead.')
	assert_true(effect.begins_with('Make a melee attack against evasion 8,'),
		'And the rest of the sentence is the card s.')
