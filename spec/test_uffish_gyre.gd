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
# It matters in a second way for test_a_further_gyre_is_refused_once_symbiosis_is_spent: an ally's
# turn start runs every_new_turn_refresh for everyone (reaction POINTS) but new_turn_refresh only for
# the unit whose turn it is (unit_action.gd:67-78), and the per-ROUND usage counter the Gyre's
# 1/round reads is cleared by the latter. So several allies can move in one "round" and the limit
# still binds, while the Myconid's own turn start releases it.
#
# A ROUND HOLDS TWO GYRES, NOT ONE, SINCE SP2.5 TASK 1. Symbiosis's "may use a reaction an additional
# time" now reaches this reaction: it is neither 1/scene nor 1/mission, so buff_symbiosis_extra_use
# adds +1 to the per-round cap through Buff.TO.ACTION_PER_ROUND (unit_action.gd:170-175) while the
# trait's extra is unspent. That was the author's bug - the second Gyre was silently never offered -
# and it is why the limit case in this file asks about the THIRD move. Nothing else here changed:
# every trigger, range and cost case still fires the round's FIRST Gyre.
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
## And one row UP, for a third. The Myconid occupies y 6..7, so (12,5) is dx 7 / dy 1 = 7 away -
## the same distance again. Needed since SP2.5 Task 1: a round now holds two Gyres, so the case that
## pins the limit needs a third, unarmored mover to ask it of.
const AT_7_HIGH := Vector2i(12, 5)

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
var logbook:LogRecorder

# ---------------------------------------------------------------- the attack-roll probe

## Records every AttackRoll the game resolves, so a test can read hit/crit/target_defense off the
## REAL roll rather than off a preview. The ATTACK trigger at POST is the only timing that sees one:
## event_unit_attack.execute_preblock runs the PRE reactions before AttackRoll.create exists
## (event_unit_attack.gd:31-32, :53), while the POST block is queued at :123 with the same core,
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

## The same idiom at PRE instead of POST: reads a caller-supplied number at the moment an attack is
## DECLARED, before AttackRoll.create exists (event_unit_attack.gd:31-32, :53). The one instrument in
## this file that measures WHEN something happened rather than what it was, and the only way to ask
## "had the reaction spent its use - and therefore emitted its popcorn - before the roll?" from
## inside the run. Never fires, for the same reason AttackRecorder never does.
class DeclarationProbe extends ActionReaction:
	var readings:Array[int] = []
	var read:Callable

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func triggers_on_event(_unit:Unit, _gear:GearCore, _triggering_event:EventCore) -> bool:
		if read.is_valid(): readings.append(int(read.call()))
		return false

## The battle log in the order the player reads it. BattleLogBus is one shared Resource loaded by
## path (action.gd:29) and every line goes through log_text, which emits on_log_text with the
## formatted string (battle_log_bus.gd:10-22) - so connecting to that signal records the run's lines
## in sequence without touching any UI.
class LogRecorder:
	var lines:Array[String] = []
	var bus:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

	func start() -> void:
		lines.clear()
		if not bus.on_log_text.is_connected(record): bus.on_log_text.connect(record)

	func stop() -> void:
		if bus.on_log_text.is_connected(record): bus.on_log_text.disconnect(record)

	func record(text:String) -> void: lines.append(text)

	## Index of the first line mentioning `needle`, or -1. The lines carry bbcode around the names,
	## so this matches on a substring rather than on a whole line.
	func first_containing(needle:String) -> int:
		for i:int in lines.size():
			if lines[i].contains(needle): return i
		return -1

# ---------------------------------------------------------------- fixture

func before_each() -> void:
	game = MyconidFixture.create_game(self, MAP_SIZE)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	# The log bus is a SHARED resource that outlives the test, so a recorder left connected would
	# keep appending into a freed object for the rest of the run.
	if logbook != null:
		logbook.stop()
		logbook = null

func pike_gear() -> GearCore: return myconid.get_gear(PIKE_KIT)
func strike() -> Action: return pike_gear().get_action(STRIKE_ID)
func gyre() -> Action: return pike_gear().get_action(GYRE_ID)
func strike_specific() -> SpecificAction: return SpecificAction.create(myconid, pike_gear(), strike())

## The Gyre's own per-round counter - what UnitAction.is_under_per_round_limit reads
## (unit_action.gd:170-175) and what action_uffish_gyre.gd's spend_actions() feeds.
##
## IT MEANS "THE REACTION SPENT ITS USE", NOT "THE REACTION TRIGGERED", and the two differ on
## purpose: the Gyre's spend is a deferred callable the engine runs only when the STRIKE commits
## (action_attack.gd:262), so a Stunned or Jammed refusal leaves this where it was. (A DECLINED
## CONFIRM used to be the third such path; SP2.5 Task 2 suppressed the confirm, so the refusals are
## the callable's whole remaining job - see test_the_conditional_spend_now_only_guards_the_refusal_paths.)
## Where a test needs to know that the trigger itself fired, it says so with a positive control that
## runs the same move from the same geometry.
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

## Hangs a spec-local reaction on a unit's loadout. Always installed on the MOVER rather than the
## Myconid, because full_repair() below would reset the Pike's own usage counters mid-test.
## ReactionBus.trigger_occurred walks every unit on the map (reaction_bus.gd:50-51), so whose loadout
## a never-firing probe sits on does not change what it sees.
func install_reaction(on_unit:Unit, action:ActionReaction, kit_id:StringName) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append(action)
	on_unit.core.loadout.equipped_kits.append(kit)
	on_unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## The ATTACK-POST probe.
func install_recorder(on_unit:Unit) -> void:
	recorder = AttackRecorder.new()
	install_reaction(on_unit, recorder, &'uffish_gyre_spec_recorder_kit')

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
	#
	# BUT READ THE NAME NARROWLY: the `_and_is_armored` half is NOT evidence for that flag, and must
	# not be quoted as coverage of it. Flipping requires_line_of_sight_baseline to true reddens
	# nothing (mutation 3b), because the Gyre hands the strike a MANDATORY target and SpecFactory's
	# responder builds the plan straight out of it (spec_factory.gd:457-458) without ever consulting
	# UnitTargeting, which is where the baseline binds (unit_targeting.gd:36, :142) and which the LIVE
	# picker does consult (tilepicker_compcon.gd:439). What this half really proves is that the
	# TRIGGER, the roll and the on-hit all survive a blocked line - the first assertion is the
	# discriminating one (mutation 3a: adding a can_see test to the gate reddens it alone). The flag
	# itself is kept on the card's authority and wants an in-game check before the frame closes.
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
	# "Damage: none". THIS CLAUSE IS DOUBLE-GUARDED, and the health assertion below cannot see
	# either guard fail alone: action_psychopomp_strike.tres:27-31 leaves damage_dice empty, AND
	# action_psychopomp_strike.gd:76-77 overrides get_damage_for_attack to return {} outright.
	# Deleting the override leaves the base (action_attack.gd:77) reading the still-empty
	# damage_dice and building the same zero-damage summary, so the ally still takes nothing either
	# way - MEASURED, not assumed: action_psychopomp_strike.gd:69-71 records this exact mutation
	# (replacing the override's body with `return super(...)`) as reddening NOTHING (mutation 14,
	# 2026-09-16).
	#
	# THE COMMENT USED TO CLAIM THE OPPOSITE - "Reddened by deleting the override" - which its own
	# implementation file disproves in as many words. That claim is withdrawn (frame-close review).
	#
	# So the assertion below adds a second, mechanism-level check that DOES discriminate the
	# override, called directly rather than through a full attack: with no roll ever made, the
	# override must still hand back an empty dict. Reddened by deleting
	# action_psychopomp_strike.gd:76-77 - the base then falls through to
	# damage_data.get_for_attack_roll(attack_roll) (action_attack.gd:77), and since a bare
	# AttackRoll.new() defaults hit = false (attack_roll.gd:11), that resolves to get_miss()'s
	# {primary_type: reliable} = {KINETIC: 0} (attack_util.gd:118-126), not {} - in practice the base
	# runs one statement further still, to attack_roll.pre.applied_buffs (action_attack.gd:80), and
	# `pre` is null on a bare AttackRoll.new(), so the mutation reddens this assertion with a runtime
	# error rather than a clean mismatch. Either way the suite goes red.
	#
	# THE .tres's OWN EMPTY damage_dice - the other guard - is still not discriminated by anything
	# here. Labelled gap, not a claim: there is no cheap honest assertion for "and stays empty" that
	# is not the vacuous property-presence check the brief warns against.
	var ally := create_ally(AT_8)
	assert_eq(strike().get_damage_for_attack(strike_specific().to_context(), ally, AttackUtil.DamageRollSummary.new(), AttackRoll.new()), {},
		'The strike declares no damage at all, whatever the .tres carries - the mechanism the outcome assertion below cannot see alone.')
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

func test_the_allys_own_self_inflicted_damage_is_still_blunted():
	# Real armor covers self-inflicted non-AP damage too, and so must this stand-in for it:
	# buff_resist_damage.gd:44 is `if not resist_self_inflicted and context.flags.has(
	# EventService.DAMAGE_FLAG.SELF_INFLICTED): return false`, so without the export on
	# buff_uffish_gyre_armor_reduction.tres:23 an ally standing in its own area damage would be the
	# one case its Gyre-granted armor did not cover. UNGUARDED UNTIL THIS TEST (frame-close review):
	# `grep -rn "SELF_INFLICTED" spec/` used to return only test_reinforced_chassis.gd's two hits, a
	# different buff entirely - no spec anywhere in the mod drove a SELF_INFLICTED event at any of
	# the three armor-reduction buffs this shared script backs.
	#
	# NOT THE AP CASE: buff_armor_reduction.gd:137-139 returns false before reaching super() (and
	# therefore before buff_resist_damage.gd:44) on an AP context, which would refuse this test for
	# the wrong reason if AP were also set - test_an_ap_hit_on_the_ally_is_not_reduced above already
	# covers that guard on its own. This test's damage carries no AP flag, so it is the AP guard's
	# sibling case, not a repeat of it.
	#
	# Reddened by deleting `resist_self_inflicted = true` from
	# buff_uffish_gyre_armor_reduction.tres:23.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_REDUCTION), 'fixture: the reduction is on.')

	var before:int = ally.core.current.health
	await SpecFactory.damage(game, ally, 5, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.SELF_INFLICTED])
	assert_eq(before - ally.core.current.health, 3,
		'Self-inflicted kinetic is blunted exactly like an ordinary hit.')

func test_the_battle_log_names_the_pike_for_the_reduction():
	# COSMETIC, MEASURED, AND PINNED SO IT CANNOT MOVE UNNOTICED. buff_armor_reduction.gd's
	# divergence 4 records that a blunted hit logs the reducing BUFF's name rather than "armor", and
	# left this specific question open for whoever built the Pike: that fall-through wants the owning
	# Kit to have exactly ONE action, and this Kit has two. Measured here - Translate.buff walks
	# gear.<buff_id> (translate.gd:56-58), then gear.<kit_id>.<buff_id> (:68-70), then
	# gear.<kit_id>.<SOLO ACTION> (:72-75), and get_solo_action() is kit.actions[0] with no arity
	# check (gear_core.gd:337-339) - so it lands on the STRIKE's name, not the Gyre's.
	#
	# SP2.5 TASK 3 RENAMED THE STRIKE ITSELF TO "Uffish Gyre" (the weapon-profile rename; the author
	# reported the card was wrong, see mw_psychopomp_fold_pike.tres's header), so the expected string
	# below moved from "Psychopomp Fold Pike" to "Uffish Gyre" - the SAME text the CONTROL below
	# reads off the visible chip, but for an unrelated reason: the CONTROL has its own localisation
	# row (gear.buff_uffish_gyre_armor.name), while this one still arrives via the three-hop
	# fall-through above, landing on the STRIKE's row
	# (gear.mw_psychopomp_fold_pike.action_psychopomp_strike.name). Two different keys, one string,
	# by coincidence of the rename - the fall-through did not start reading the chip's row.
	#
	# AND THAT RENAME COST THE REORDER GUARD, SO THE MECHANISM IS NOW ASSERTED DIRECTLY (SP2.5 Task
	# 3 review). This test's other job has always been that reordering the Kit's `actions` cannot
	# silently change what the player reads. Before the rename the two candidate rows held DIFFERENT
	# strings - action_psychopomp_strike.name was "Psychopomp Fold Pike", action_uffish_gyre.name
	# "Uffish Gyre" - so swapping the array reddened the string assertion below all by itself. Both
	# rows now read "Uffish Gyre", so the string cannot tell them apart any more and a swap would
	# leave it green. The get_solo_action() assertion puts the guard back by pinning the HOP instead
	# of its output: it is the very call translate.gd:72 makes, so it is what a reorder breaks.
	# MEASURED, not reasoned - mutation T3-M2 swapped mw_psychopomp_fold_pike.tres's actions to
	# [gyre, strike] and this test went RED on exactly that assertion while both string assertions
	# stayed green, which is the whole finding in one run.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	var reduction:BuffCore = UnitCondition.get_buff(ally, ARMOR_REDUCTION)
	assert_not_null(reduction, 'fixture: the reduction is on the ally.')
	if reduction == null: return
	var solo:Action = pike_gear().get_solo_action()
	assert_eq(solo.get_id() if solo != null else &'', STRIKE_ID,
		'THE GUARD: kit.actions[0], the hop translate.gd:72 takes, is still the strike - so the row read below is the strike s.')
	assert_eq(reduction.name_text(), 'Uffish Gyre',
		'The hidden reduction still reads as the strike, the Kit s first action - now the same text as the chip, for a different reason (see header).')
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

func test_a_further_gyre_is_refused_once_symbiosis_is_spent():
	# "1/round", which ActionReaction does NOT give a non-consuming reaction - it returns 99
	# (action_reaction.gd:69) - so action_uffish_gyre.get_per_round_hard_limit puts it back.
	# Reddened by deleting that override, exactly as it always was: with the cap at 99 every move
	# below fires and the counter runs past 2.
	#
	# THIS IS test_a_second_gyre_in_the_round_is_refused, UPDATED AND NOT WEAKENED (SP2.5 Task 1).
	# Symbiosis relieves a non-consuming reaction's per-round cap - that is the whole of that task,
	# and the author's own bug report - so the SECOND Gyre of a round is the trait's extra and the
	# THIRD is the one refused. The claim here is unchanged: the round's Gyres run out, and the gate
	# that stops them is the per-round limit by name. Only the number moved. The Symbiosis side of it
	# is spec/test_symbiosis.gd's; this file's job is the OVERRIDE, and that is what the reason
	# assertion and the count pin.
	#
	# THREE DIFFERENT ALLIES, because the chip from an earlier mover would otherwise still be on it
	# and "did this one fire" could not be asked of the armor at all.
	var first := create_ally(AT_8)
	var second := create_ally(AT_7_LOW) # at 7, so its SECOND move still starts inside threat
	var third := create_ally(AT_7_HIGH)

	queue_dice(D20_HITS)
	await moves_east(first)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the first move fired it.')

	queue_dice(D20_HITS)
	await moves_east(second)
	assert_eq(gyre_uses_this_round(), 2,
		'CONTROL: the second is Symbiosis s extra use, so it fires.')
	assert_true(UnitCondition.has_buff(second, ARMOR_CHIP), 'CONTROL: and arms the second ally.')

	assert_eq(UnitAction.get_gear_unavailable_reason(
		SpecificAction.create(myconid, pike_gear(), gyre())), UnitAction.REASON.PER_ROUND,
		'And now the per-round limit is what refuses it, by name (unit_action.gd:148).')
	queue_dice(D20_HITS)
	await moves_east(third)
	assert_eq(gyre_uses_this_round(), 2, 'The third ally s move did not fire it again.')
	assert_false(UnitCondition.has_buff(third, ARMOR_CHIP), 'And the third ally got nothing.')

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
	# action_uffish_gyre hands its spend to choose_and_use as a deferred callable, which the engine
	# runs only when the strike commits - and a strike refused in check_specific_context never
	# reaches execute(), let alone action_attack.gd:262. So a Myconid that could not strike has not
	# used its reaction. Pinned below, and by test_the_conditional_spend_now_only_guards_the_refusal_paths
	# and test_a_jammed_myconid_cannot_strike.
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

func test_a_jammed_myconid_cannot_strike():
	# RULING 11's OTHER CROSS-SEAM CLAIM, and the brief was explicit that it is to be TESTED rather
	# than asserted in a comment - which is what it was until the SP2 Task 4 review.
	#
	# The asymmetry is two is_jammable() implementations reached through one call site.
	# UnitAction.get_gear_unavailable_reason's Jammed elif (unit_action.gd:142) asks
	# UnitAction.is_action_jammable (:573-576), which asks the ACTION: ActionAttack.is_jammable
	# returns true outright (action_attack.gd:24), while ActionReaction.is_jammable returns
	# requires_reaction_available() (action_reaction.gd:66) - false for a consumes_rxn = false
	# reaction. So the Gyre is not jammable and the strike is, and the Myconid is refused at the
	# second seam rather than the first, exactly as it is when Stunned.
	#
	# Both halves asserted, as in the Stunned test above: "the ally was not armored" alone would pass
	# just as well if the reaction had never triggered, which is a different mechanism.
	var ally := create_ally(AT_7)
	SpecFactory.apply(myconid, Lancer.STATUS.JAMMED)
	assert_true(myconid.has_status(Lancer.STATUS.JAMMED), 'fixture: the Myconid really is Jammed.')
	assert_true(UnitAction.can_activate_gear(SpecificAction.create(myconid, pike_gear(), gyre())),
		'The REACTION is not refused: a non-consuming reaction is not jammable.')

	# The reason the strike is refused, asked of the engine directly and as a FREEBIE - which is how
	# the Gyre asks it - with the action woken exactly as the Gyre wakes it.
	pike_gear().wake_action(STRIKE_ID)
	assert_eq(UnitAction.get_gear_unavailable_reason(strike_specific(), true), UnitAction.REASON.JAMMED,
		'And the STRIKE is refused, as a freebie, for being Jammed.')
	pike_gear().hibernate_action(STRIKE_ID)

	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(strike_uses_this_round(), 0, 'End to end: the strike never activated.')
	assert_false(UnitCondition.has_buff(ally, ARMOR_CHIP), 'So the ally was not armored.')
	assert_eq(gyre_uses_this_round(), 0, 'And the Gyre spent no use on a strike that never happened.')

	# POSITIVE CONTROL: unjammed, the same ally's next move from the same geometry arms it - so what
	# was refused was a strike that otherwise lands, with this die.
	UnitCondition.clear_status(SpecFactory.dummy_event(), myconid, Lancer.STATUS.JAMMED)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'CONTROL: unjammed, the strike lands.')
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: and the Gyre spends its use when it does.')

func test_the_gyre_asks_the_player_nothing():
	# THIS TEST USED TO SAY THE OPPOSITE, and the author's playtest is why (SP2.5 Task 2). It was
	# test_the_player_is_asked_to_confirm_the_friendly_attack, which pinned a friendly-fire yes/no
	# raised on every single trigger; the author asked for it gone, and it is. The reaction fires on
	# somebody ELSE's turn, so the prompt interrupted a turn the player was only watching to ask
	# about an attack whose whole effect is to hand that ally armor. The card names no decision.
	#
	# BOTH PROMPTS ARE ASSERTED ABSENT, because the flag that removes one removes the other and a
	# test that watched only the yes/no would not notice if the picker came back.
	# action_uffish_gyre.gd passes Action.FLAG.SKIP_PLAYER_DECISIONS, which
	# TargetActionUtil.confirm_friendly_fire reads at target_action_util.gd:433 (returning before
	# choice_bus.quick_yesno at :435) and which :150 -> :162 also uses to turn player_decides off,
	# routing the strike past choice_bus.choose_compcon_plan at :200 into the supplied-target branch
	# at :230-242.
	#
	# THE CONTROL IS THE SAME STRIKE AT THE SAME ALLY, pressed directly with the target made
	# mandatory - NEAR-IDENTICAL to the Gyre's own call shape, not the same shape with one flag
	# removed. choose_and_use unconditionally injects Action.FLAG.AS_FREEBIE alongside
	# TARGETS_ARE_MANDATORY (common_action_util.gd:693-696), and the Gyre's additional_action_flags
	# carry CAN_FOLLOWUP beside SKIP_PLAYER_DECISIONS; SpecFactory.use passes its `flags` argument
	# straight through with no additions of its own (spec_factory.gd:248-265, `flags = flags`), so
	# the control below carries TARGETS_ARE_MANDATORY alone. That does not touch the conclusion: the
	# two things this test reads a confirm result off of are CONTROLLED_BY_OPPONENT and
	# SKIP_PLAYER_DECISIONS (target_action_util.gd:432-433 for the yes/no, :150-162 for the picker),
	# and the control matches the Gyre's real call on both. What makes the two zeroes above evidence
	# about the FLAG rather than about the fixture is that match, not an identical call shape - an
	# absent prompt proves nothing unless something in the same test proves the watcher would have
	# seen it.
	var ally := create_ally(AT_8)
	queue_dice(D20_HITS)
	await moves_east(ally)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired, so there WAS something to ask about.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: and its shot landed.')

	assert_eq(watcher.kinds(PromptWatcher.KIND.yesno).size(), 0,
		'No yes/no was raised at all - no friendly-fire confirm: %s' % [watcher.prompts])
	assert_eq(watcher.kinds(PromptWatcher.KIND.compcon_plan).size(), 0,
		'And no targeting plan either: the mover is the only legal target. %s' % [watcher.prompts])

	# POSITIVE CONTROL. The Myconid's own turn is opened for it, which resets the per-round counter -
	# hence the two assertions above being taken first.
	await MyconidFixture.open_turn(game, myconid)
	pike_gear().wake_action(STRIKE_ID)
	queue_dice(D20_HITS)
	await SpecFactory.use(game, myconid, PIKE_KIT, STRIKE_ID, ally, [Action.FLAG.TARGETS_ARE_MANDATORY])
	pike_gear().hibernate_action(STRIKE_ID)

	var yesnos := watcher.kinds(PromptWatcher.KIND.yesno)
	assert_eq(yesnos.size(), 1,
		'CONTROL: the same strike at the same ally, without the flag, DOES ask: %s' % [watcher.prompts])
	if yesnos.is_empty(): return
	assert_eq(String(yesnos[0].description), 'battle.confirm.friendly_fire',
		'CONTROL: and what it asks is the friendly-fire confirmation the Gyre no longer raises.')
	assert_eq(watcher.kinds(PromptWatcher.KIND.compcon_plan).size(), 1,
		'CONTROL: and it opens the targeting plan the Gyre no longer opens: %s' % [watcher.prompts])

func test_the_conditional_spend_now_only_guards_the_refusal_paths():
	# THIS TEST USED TO BE test_a_declined_friendly_fire_confirm_costs_nothing, and SP2.5 Task 2 took
	# its subject away: with the confirm suppressed there is no decline path left to be free.
	#
	# THE CONDITIONAL SPEND ITSELF STAYS, and this is the test that says why. action_uffish_gyre.gd
	# hands its spend to choose_and_use as a deferred callable the engine runs only when the strike
	# commits (action_attack.gd:262). That used to guard three paths - a declined targeting plan, a
	# declined friendly-fire confirm, and a Stunned or Jammed refusal. The flag removed the first
	# two; the THIRD is still real, and is now the callable's entire job. Simplifying it back into
	# an unconditional spend because "the confirm is gone" would charge a Stunned Myconid its
	# 1/round for a strike that never happened.
	#
	# TWO HALVES, and the first is the sharper one for the flag: a responder set to decline
	# EVERYTHING cannot stop the strike any more, because nothing asks it. Before this task that
	# same line cost the Gyre its shot.
	var first := create_ally(AT_7)
	var second := create_ally(AT_7_LOW)
	SpecFactory.current_responder.chosen_yesnos = false

	queue_dice(D20_HITS)
	await moves_east(first)
	assert_true(UnitCondition.has_buff(first, ARMOR_CHIP),
		'A responder that declines everything cannot refuse this strike: it landed.')
	assert_eq(strike_uses_this_round(), 1, 'The strike really activated.')
	assert_eq(gyre_uses_this_round(), 1, 'And the deferred spend ran, because the strike committed.')
	assert_eq(watcher.kinds(PromptWatcher.KIND.yesno).size(), 0,
		'Which is because the declining responder was never asked anything: %s' % [watcher.prompts])

	# THE OTHER HALF: the refusal path, which is what the callable still exists for. A second mover
	# is used rather than the same one because `first` is now at 8 and one more step would put it at
	# 9, outside threat - the trigger would fail for range and this half would pass for the wrong
	# reason.
	SpecFactory.apply(myconid, Lancer.STATUS.STUNNED)
	assert_true(UnitAction.can_activate_gear(SpecificAction.create(myconid, pike_gear(), gyre())),
		'CONTROL: the REACTION is still available - Stunned does not touch a non-consuming reaction, and Symbiosis s extra use keeps the per-round cap open for a second Gyre - so it really is offered.')

	queue_dice(D20_HITS)
	await moves_east(second)
	assert_false(UnitCondition.has_buff(second, ARMOR_CHIP), 'A Stunned Myconid strikes nobody.')
	assert_eq(strike_uses_this_round(), 1, 'The strike never activated a second time.')
	assert_eq(gyre_uses_this_round(), 1,
		'And the Gyre spent nothing for it: an unconditional spend would read 2 here.')
	assert_true(pike_gear().is_action_hibernating(STRIKE_ID),
		'And the strike was put back to sleep even though the activation aborted.')

	# POSITIVE CONTROL, closing the loop the way test_a_stunned_myconid_cannot_strike:796-802 does
	# (and the way the test this replaced did): the SAME ally, from the SAME pre-move tile, still
	# fires a Gyre once unstunned - so the four negatives above are evidence that Stunned refused
	# THIS trigger, not evidence of a trigger that had quietly stopped matching from AT_7_LOW.
	# Without this, a future range regression at AT_7_LOW would make this half pass for exactly the
	# "wrong reason" the comment above warns about. "Starts to move" means the trigger reads the
	# PRE-move tile (this file's own header, and event_unit_move.gd:71), and `second`'s refused move
	# already carried it from distance 7 to distance 8 - still within threat - so this further move
	# starts from 8 and fires the round's SECOND Gyre, Symbiosis's extra use, same arithmetic as
	# test_a_further_gyre_is_refused_once_symbiosis_is_spent's second case.
	UnitCondition.clear_status(SpecFactory.dummy_event(), myconid, Lancer.STATUS.STUNNED)
	queue_dice(D20_HITS)
	await moves_east(second)
	assert_true(UnitCondition.has_buff(second, ARMOR_CHIP), 'CONTROL: unstunned, the strike lands.')
	assert_eq(strike_uses_this_round(), 2, 'CONTROL: and the strike really activated a second time.')
	assert_eq(gyre_uses_this_round(), 2,
		'CONTROL: and the Gyre spends its use - the round s SECOND, Symbiosis s extra.')

func test_the_gyre_announces_itself_before_the_roll():
	# THE ORDER THE PLAYER SEES, and the whole justification for the .tres's emit_text_popcorn_on_use:
	# the Gyre fires on somebody ELSE's turn, so the label naming it has to arrive before the attack
	# roll it explains. A popcorn that turns up afterwards is announcing a roll the player has already
	# watched, which is the thing the flag exists to prevent.
	#
	# TWO INSTRUMENTS, because neither is sufficient alone.
	#  - The counter, read from an ATTACK/PRE probe. Action.popcorn_usage is reached from exactly one
	#    place - UnitAction.spend_actions_gain_heat, unit_action.gd:234 - and that same call moved the
	#    per-round counter fifteen lines earlier (:225 -> UnitAction.spend's
	#    increment_action_usage_for_action at :279) with nothing awaited in between. So a counter that
	#    already reads 1 when the attack is DECLARED (event_unit_attack.gd:31-32, before
	#    AttackRoll.create at :53) means the popcorn has already been emitted. It is a proxy, but a
	#    tight one, and it is the only way to see a disabled-in-tests fx call at all.
	#  - The battle log, which needs no proxy: log_usage at :233 writes
	#    "event.gear_activate.reacted.log" for the reaction and ActionAttack's own writes
	#    "...used.log" for the strike, and this asserts the first comes first.
	#
	# Reddened by awaiting choose_and_use and spending afterwards - this file's shape until the SP2
	# Task 4 review - because the strike's own spend (action_attack.gd:262) happens before the roll
	# while the await does not return until long after it.
	var ally := create_ally(AT_8)
	var probe := DeclarationProbe.new()
	probe.read = gyre_uses_this_round
	install_reaction(ally, probe, &'uffish_gyre_spec_declaration_probe_kit')

	logbook = LogRecorder.new()
	logbook.start()
	queue_dice(D20_HITS)
	await moves_east(ally)
	logbook.stop()

	assert_eq(gyre_uses_this_round(), 1, 'fixture: the Gyre fired.')
	assert_true(UnitCondition.has_buff(ally, ARMOR_CHIP), 'fixture: and its shot landed.')
	# THE PROBE FIRES MORE THAN ONCE FOR ONE SHOT - measured 2026-09-16: three PRE readings (and, with
	# an ATTACK/POST recorder installed beside it, two POST ones) for a single Gyre strike, so the
	# engine enters those reaction blocks repeatedly rather than once per roll. That count is an
	# engine detail this test has no stake in and must not pin. What it DOES pin is every reading: a
	# count would be brittle and "the first one" would hide a later zero.
	assert_false(probe.readings.is_empty(),
		'fixture: the declaration probe saw the attack: %s' % [probe.readings])
	for reading:int in probe.readings:
		assert_eq(reading, 1,
			'The Gyre had already spent its use - and so already popcorned and logged - when the attack was declared: %s' % [probe.readings])

	# A THIRD CASUALTY OF THE SP2.5 TASK 3 RENAME, NOT NAMED IN THE BRIEF - found by running this file
	# after the CSV edit, not by reading it. Renaming the strike to "Uffish Gyre" makes it share a
	# name with the reaction, so a bare 'Psychopomp Fold Pike' search no longer finds the strike's
	# line at all (assert_gte on strike_line went -1). battle_log_bus.gd's formatted_action (:89-94)
	# is what still tells the two lines apart: it prefixes a line with the KIT's own name only when
	# `specific.action is ActionAttackWeapon and action_name != kit_name` (:93) - true for the strike
	# (an ActionAttackWeapon whose name now differs from the Kit's "PFP// \"PSYCHOPOMP\" Fold Pike"),
	# false for the Gyre (an ActionReaction, never profiled this way) - so only the strike's line
	# reads "...Fold Pike: Uffish Gyre" while the reaction's reads a bare "...Uffish Gyre triggered.".
	# Search the composite fragment, not the bare name, or this half of the probe goes blind rather
	# than red.
	#
	# MEASURED, NOT INFERRED (2026-09-16, by inverting the assert_lt below and reading the dump). The
	# four lines this run writes, in order, BBCode stripped:
	#   0  "Player Q0Y started turn."
	#   1  "Player 5EU [Uffish Gyre] triggered."                                   <- the REACTION
	#   2  "...and attacked with [PFP// "PSYCHOPOMP" Fold Pike: Uffish Gyre]."     <- the STRIKE
	#   3  "...and rolled 9 against Player Q0Y (8 Eva): hit!"
	# So the two searches below land on 1 and 2 - two DIFFERENT lines, which is what keeps the
	# assert_lt honest. And it stays honest under regression: if the strike ever logged first, line 2
	# would also be the first line containing 'Uffish Gyre', the two indices would be EQUAL, and
	# assert_lt would go red. The weaker-looking search does not cost the test its teeth.
	var reaction_line:int = logbook.first_containing('Uffish Gyre')
	var strike_line:int = logbook.first_containing('Fold Pike: Uffish Gyre')
	assert_gte(reaction_line, 0, 'fixture: the reaction wrote a battle-log line: %s' % [logbook.lines])
	assert_gte(strike_line, 0, 'fixture: and so did the strike: %s' % [logbook.lines])
	if reaction_line < 0 or strike_line < 0: return
	assert_lt(reaction_line, strike_line,
		'And the player reads the Gyre triggering BEFORE the Pike swings, not after: %s' % [logbook.lines])

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
