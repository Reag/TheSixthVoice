# SYMBIOSIS (Myconid trait, SP1 Task 3).
#
#   "1/round, the Myconid may use a reaction an additional time. This cannot be used on reactions
#    that are 1/scene or 1/mission."
#
# THIS FILE REPLACES spec/test_spike_symbiosis.gd AND spec/test_spike_symbiosis_exclusion.gd, both
# deleted in the same commit. The spike's thirteen cases are all here: the four stat-route ones now
# asked of the real trait instead of vanilla Gaze, the seven buff-route and granted-point ones
# unchanged (they are the engine findings the whole design rests on, and ruling 13 - no buff may ever
# grant a reaction - is mod-wide, so it keeps a home), and the two readable-property ones. The
# exclusion probe's finding is here too, against the real buff.
#
# HOW THE TRAIT IS BUILT, and why it is two buffs:
#
#   mt_symbiosis carries a Gaze-shaped PassiveStatIncrease (Statblock.reactions = 1), so
#   core.get_reactions_max() is 2 and the refill really issues two points - and a PassiveBuffApplicator
#   carrying TWO hidden buffs, because Buff.trigger_timing is a single @export that
#   ReactionBus.does_buff_trigger compares directly (reaction_bus.gd:135). One buff subscribes at one
#   timing for every trigger it names, and this trait needs both:
#
#     buff_symbiosis            POST   unit_action -> stamp extra_spent when the SECOND point goes
#                                      new_turn    -> cap back to max-1 while the stamp is set
#                                      new_round   -> clear the stamp
#     buff_symbiosis_exclusion  -      ACTION_FORBIDDEN -> hide an excluded reaction as the second
#     buff_symbiosis_extra_use  -      +1 to a reaction's per-round hard limit while the stamp is unset
#
# THE THIRD ONE IS SP2.5 TASK 1, AND IT IS A DIFFERENT KIND OF BUFF. The first two live entirely in
# the reaction-POINT economy, which is one of the TWO gates a reaction can be refused by:
# is_gear_affordable's `requires_reaction_available() and not has_reaction` (unit_action.gd:182). A
# reaction with consumes_rxn = false never trips that gate - so the Uffish Gyre's and Halo's "1/round",
# which is the OTHER gate (is_under_per_round_limit, unit_action.gd:170-175), was untouched by the
# trait, and the author found in play that Symbiosis never offered a second Gyre. The third buff is on
# Buff.TO.ACTION_PER_ROUND, a channel the engine QUERIES rather than one the reaction bus fires, so it
# names no trigger and no timing at all.
#
# THE GYRE CASES DRIVE A REAL REACTION ON A REAL ALLY MOVE, because the point of the bug is that the
# two gates are different and a synthetic reaction shaped by this file could be made to pass either
# way. The spec-local reactions above stay exactly what they were - the POINT economy's cases - and
# the Pike's are the counter's.
#
# WHY THE ROUND IS A REAL ROUND HERE, unlike Halo's and Uffish Gyre's 1/round. Those are the engine's
# per-round hard limit on a reaction, which reset_per_round_usage clears at the Myconid's OWN turn
# start - per turn in truth, and accepted for vanilla parity. Symbiosis has no reaction of its own to
# carry that limit and its bookkeeping is ours, so it can afford the honest round: the stamp clears
# on NEW_ROUND POST (event_round_new.gd:77).
#
# THE SPEC-LOCAL REACTIONS ARE THE ONLY HONEST WAY TO DRIVE THIS. A reaction's per-round hard limit
# is 1 per GEAR (action_reaction.gd:69), so one Kit cannot react twice in a round however many points
# the unit has - the Gorgon spends its two on two different gears. And the exclusion cases need a
# reaction whose Kit declares uses_per_scene / charges_max exactly, fired FIRST or SECOND on demand.
# Runtime Kits on the unit's own loadout give all of that, and the idiom is already in the suite
# (test_draw_fire.install_recorder). Vanilla's own 1/scene and Limited Kits are still pinned, below,
# for the properties the gate reads - that is what keeps the synthetic gear honest.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_symbiosis.gd
extends GutTest

const MyconidFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/myconid_fixture.gd')

const TRAIT_ID := &'mt_symbiosis'
const BOOKKEEPING_BUFF := &'buff_symbiosis'
const EXCLUSION_BUFF := &'buff_symbiosis_exclusion'
const EXTRA_USE_BUFF := &'buff_symbiosis_extra_use'

## A vanilla 1/scene reaction Kit: the Manticore's Castigate The Enemies Of The Godhead, whose Kit
## declares uses_per_scene = 1. A vanilla control with no scene limit at all beside it.
const SCENE_LIMITED_REACTION_KIT := &'mt_castigate_the_enemies_of_the_godhead'
const UNLIMITED_REACTION_KIT := &'ms_overwatch'

const MYCONID_TILE := Vector2i(4, 4)
const DUMMY_TILE := Vector2i(10, 6)

## THE PIKE, for the per-round half of the trait (SP2.5 Task 1). The Uffish Gyre is a NON-consuming
## reaction with a 1/round hard limit of its own, so it is gated by
## UnitAction.is_under_per_round_limit (unit_action.gd:170-175) and never by the reaction POINT -
## which is why everything above this line is blind to it.
const PIKE_KIT := &'mw_psychopomp_fold_pike'
const GYRE_ID := &'action_uffish_gyre'
const ARMOR_CHIP := &'buff_uffish_gyre_armor'

## Allies for the Gyre, all well inside the strike's Threat 8 so a move never leaves it. The Myconid
## is SIZE 2: anchored at (4,4) it occupies (4..5, 4..5), and UnitRelation.distance_between measures
## between FOOTPRINTS, so x = 9 is 4 away from its east column and stays inside threat after a move
## east. Three of them because a chip is asserted on the mover, and a mover that already carries one
## cannot answer "did this Gyre fire".
##
## y = 2, 3 and 7 rather than a column: DUMMY_TILE is (10,6), which is where an ally at (9,6) would
## step into.
const ALLY_A := Vector2i(9, 2)
const ALLY_B := Vector2i(9, 3)
const ALLY_C := Vector2i(9, 7)

## The strike rolls against a fixed evasion 8 and a level-0 pilot has Grit 0, so 9 hits.
## test_uffish_gyre.D20_HITS, and the same reasoning.
const D20_HITS := 9

## Ids for the runtime Kits this spec installs. Prefixed so they can never be confused with content.
const RXN_PLAIN_A := &'symbiosis_spec_rxn_plain_a'
const RXN_PLAIN_B := &'symbiosis_spec_rxn_plain_b'
const RXN_SCENE := &'symbiosis_spec_rxn_scene'     # uses_per_scene = 1  -> "1/scene"
const RXN_LIMITED_1 := &'symbiosis_spec_rxn_lim1'  # charges_max = 1     -> "1/mission"
const RXN_LIMITED_3 := &'symbiosis_spec_rxn_lim3'  # charges_max = 3     -> neither
const QUICK_SCENE := &'symbiosis_spec_quick_scene' # an ORDINARY action on a 1/scene Kit
const RXN_NONCONSUMING := &'symbiosis_spec_rxn_nonconsuming' # consumes_rxn=false, 1/scene Kit
const FREE_PLAIN := &'symbiosis_spec_free_plain'  # a naturally FREE ordinary action -> 1/round, not a reaction

## A spec-local reaction. DAMAGE POST, so one poke at the punching bag offers it; `armed` is what
## makes the ORDER deterministic - the bus evaluates every gate before any body runs, so two armed
## reactions on one poke would fire in an order nothing in the engine promises.
class SpecReaction extends ActionReaction:
	var armed := false
	var fired := 0
	## How many times the bus turned this reaction into an event_gear_activate - the block that raises
	## the player's prompt. ReactionBus.trigger_occurred reads get_priority() at exactly one place,
	## the EventBlock.create for a reaction that passed does_reaction_trigger (reaction_bus.gd:54-59),
	## and does_reaction_trigger asks UnitAction.can_activate_gear first (:121). So an armed reaction
	## that reached 0 here was never offered at all, which is what a hidden offer means end to end.
	##
	## NOT COUNTED IN triggers_on_event: with X.DEBUG_REACTION at its default &'' (global.gd:239) and
	## this reaction's id also empty, the bus's debug branch (reaction_bus.gd:106-115) calls
	## triggers_on_event at every timing of every trigger, gate or no gate. Measured: 3 calls with the
	## offer made, 2 with it hidden - a count that says nothing.
	var offered := 0

	func get_priority() -> int:
		if armed: offered += 1
		return super()

	func get_required_triggering_context() -> Array[Context.PROP]:
		return []

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		if not armed: return false
		return triggering_event.context.unit != unit # somebody ELSE took the damage

	func activate(_context:Context, activation:EventCore) -> void:
		fired += 1
		spend_actions(activation) # this is what spends the reaction point and moves the usage counter

## A spec-local ORDINARY action, on a Kit that is 1/scene. The exclusion gate's first clause is
## action.consumes_reaction(), and this is the thing that makes that clause discriminate: everything
## else about this Kit is exactly what the gate excludes.
class SpecQuick extends Action:
	var fired := 0

	func activate(_context:Context, activation:EventCore) -> void:
		fired += 1
		spend_actions(activation)

## A spec-local ORDINARY action that is naturally FREE - and therefore 1/round by the engine's own
## default, with no override anywhere: Action.get_per_round_hard_limit returns 1 whenever
## get_action_cost is ACTION_COST_FREE (action.gd:156-158). This is the DISCRIMINATING case for
## buff_symbiosis_extra_use's "is a reaction" clause: same cap, same gate, same everything - except
## that it is not an ActionReaction. Widening that clause to "anything capped at 1/round" reddens
## test_a_non_reaction_1_per_round_action_gets_no_extra_use and nothing else in this file.
class SpecFreeAction extends Action:
	var fired := 0

	func get_action_type(_specific:SpecificAction) -> Lancer.ACTION:
		return Lancer.ACTION.FREE

	func activate(_context:Context, activation:EventCore) -> void:
		fired += 1
		spend_actions(activation)

## A Buff.TO.STATBLOCK buff granting +1 reaction, built the way the Goblin's Instinct Rig builds its
## own: return a Statblock in the context's `object`. Carried over verbatim from the spike, because
## ruling 13 is mod-wide and this is the only thing in the suite that holds it.
class ReactionStatblockBuff extends Buff:
	func get_values(_core:BuffCore, _context:Context) -> Context:
		var statblock := Statblock.new()
		statblock.reactions = 1
		return Context.create({ object = statblock })

var game:Gamemaster
var myconid:Unit
var dummy:Unit

var rxn_a:SpecReaction
var rxn_b:SpecReaction
var rxn_scene:SpecReaction
var rxn_lim1:SpecReaction
var rxn_lim3:SpecReaction
var quick:SpecQuick
var rxn_nonconsuming:SpecReaction
var free_action:SpecFreeAction

var log_lines:PackedStringArray = []
var battle_log:BattleLogBus = load('res://ui/component/battle_log/battle_log_bus.tres')

func before_each() -> void:
	game = MyconidFixture.create_game(self)
	myconid = MyconidFixture.create_myconid(game, MYCONID_TILE)
	dummy = MyconidFixture.create_dummy(game, DUMMY_TILE, 10)
	install_spec_gear()
	UnitAction.every_new_turn_refresh(myconid)
	log_lines = []
	battle_log.on_log_text.connect(_record_log)

func after_each() -> void:
	if battle_log.on_log_text.is_connected(_record_log): battle_log.on_log_text.disconnect(_record_log)
	Dice.CHEAT_ROLL_QUEUE.clear()

func _record_log(line:String) -> void: log_lines.append(line)

# ---------------------------------------------------------------- fixture helpers

func _make_reaction(consumes_rxn:bool = true) -> SpecReaction:
	var rxn := SpecReaction.new()
	rxn.triggers_on.append(&'damage')
	rxn.trigger_timing = ReactionBus.TIMING.POST
	rxn.consumes_rxn = consumes_rxn
	return rxn

func _make_kit(kit_id:StringName, action:Action, uses_per_scene:int, charges_max:int) -> Kit:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.uses_per_scene = uses_per_scene
	kit.charges_max = charges_max
	kit.actions.append(action)
	return kit

## Every runtime Kit goes on in ONE pass, before anything touches gear state. full_repair() clears
## every equipped gear's state dictionary and refills its charges, so installing one Kit after a test
## had spent another's charge would silently hand it back (test_heaer.gd's before_each records the
## same trap). apply_passive_buffs() is what regenerates derived gear - which is also where each
## Kit's reaction gets indexed into loadout.reactions_by_trigger - and re-applies the trait's own
## buffs; the re-track afterwards is MyconidFixture.create_myconid's line, repeated because
## full_repair has just rebuilt the caches it refreshes.
func install_spec_gear() -> void:
	rxn_a = _make_reaction()
	rxn_b = _make_reaction()
	rxn_scene = _make_reaction()
	rxn_lim1 = _make_reaction()
	rxn_lim3 = _make_reaction()
	quick = SpecQuick.new()
	rxn_nonconsuming = _make_reaction(false)
	free_action = SpecFreeAction.new()
	var kits:Array[Kit] = [
		_make_kit(FREE_PLAIN, free_action, 0, 0),
		_make_kit(RXN_PLAIN_A, rxn_a, 0, 0),
		_make_kit(RXN_PLAIN_B, rxn_b, 0, 0),
		_make_kit(RXN_SCENE, rxn_scene, 1, 0),
		_make_kit(RXN_LIMITED_1, rxn_lim1, 0, 1),
		_make_kit(RXN_LIMITED_3, rxn_lim3, 0, 3),
		_make_kit(QUICK_SCENE, quick, 1, 0),
		_make_kit(RXN_NONCONSUMING, rxn_nonconsuming, 1, 0),
	]
	for kit:Kit in kits: myconid.core.loadout.equipped_kits.append(kit)
	SpecFactory.apply_passive_buffs(myconid)
	UnitTile.move_to(myconid, MYCONID_TILE)

func disarm_all() -> void:
	for rxn:SpecReaction in [rxn_a, rxn_b, rxn_scene, rxn_lim1, rxn_lim3, rxn_nonconsuming]: rxn.armed = false

## Arm exactly one reaction and poke the dummy, which fires a DAMAGE event the Myconid can react to.
func react_with(rxn:SpecReaction) -> void:
	disarm_all()
	rxn.armed = true
	await game.execute_event(&'event_unit_damage', {
		unit = dummy, number = 1, category = Lancer.DAMAGE_TYPE.KINETIC,
	})
	disarm_all()

func reactions_left() -> int: return myconid.core.current.reactions
func reactions_max() -> int: return myconid.core.get_reactions_max()

func uses_this_round(kit_id:StringName) -> int:
	var gear:GearCore = myconid.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(gear.kit.actions[0]))

func bookkeeping_core() -> BuffCore:
	return UnitCondition.get_buff(myconid, BOOKKEEPING_BUFF)

func extra_spent() -> bool:
	var core := bookkeeping_core()
	if not BuffCore.is_valid(core): return false
	return bool(core.get_state('extra_spent', false))

# ---------------------------------------------------------------- the Gyre, for the per-round half

func pike_gear() -> GearCore: return myconid.get_gear(PIKE_KIT)
func gyre() -> Action: return pike_gear().get_action(GYRE_ID)

## The Gyre's own per-round counter - what UnitAction.is_under_per_round_limit reads and what
## action_uffish_gyre.spend_the_gyres_use feeds, deferred into the strike's commit. It means "the
## reaction spent its use", not "the reaction triggered". test_uffish_gyre.gyre_uses_this_round.
func gyre_uses_this_round() -> int:
	var gear:GearCore = pike_gear()
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(gyre()))

## Sixty sixes after the one d20 that matters, so no accuracy or damage die drains the FIFO into real
## RNG. test_uffish_gyre.queue_dice, verbatim.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## A voluntary standard move of one tile EAST inside the mover's own open turn: the ordinary case the
## Gyre's card describes. test_uffish_gyre.moves_east.
##
## OPENING THE MOVER'S TURN IS WHAT MAKES THE REPRO A REPRO. every_new_turn_refresh runs for every
## unit at any turn start (reaction POINTS) but new_turn_refresh only for the unit whose turn it is
## (unit_action.gd:67-78), and UnitAction.reset_per_round_usage - which clears the Gyre's 1/round -
## sits in the latter. So two allies can move in one round with the Myconid's counter untouched,
## which is exactly the situation the author hit.
func moves_east(unit:Unit) -> void:
	await MyconidFixture.open_turn(game, unit)
	await SpecFactory.move(game, unit, unit.tile() + Vector2i(1, 0),
		MovementType.create_for_standard_move(unit))

## One ally's move with the dice queued for a hit - the whole of "offer the Gyre once".
func gyre_at(ally:Unit) -> void:
	queue_dice(D20_HITS)
	await moves_east(ally)

## Is the engine gate that refuses a second use open for this action right now? The gate itself
## (unit_action.gd:170-175), asked directly, so a test can separate "the cap was raised" from "the
## activation happened" - the two differ for anything the SCENE or CHARGE counters refuse first.
func is_under_per_round_limit(kit_id:StringName) -> bool:
	var gear:GearCore = myconid.get_gear(kit_id)
	if not GearCore.is_valid(gear): return false
	return UnitAction.is_under_per_round_limit(
		SpecificAction.create(myconid, gear, gear.kit.actions[0]))

## The engine's own per-round hard limit for a Kit's solo action, BEFORE any buff is summed into it -
## the `round_cap` is_under_per_round_limit starts from (unit_action.gd:171).
func hard_limit(kit_id:StringName) -> int:
	var gear:GearCore = myconid.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	var action:Action = gear.kit.actions[0]
	return action.get_per_round_hard_limit(SpecificAction.create(myconid, gear, action))

## The per-round cap a Kit's solo action ACTUALLY has right now, buffs included - i.e.
## UnitAction.is_under_per_round_limit's body (unit_action.gd:171-174) with its final comparison
## removed, so the number is readable instead of only its verdict.
##
## THIS EXISTS BECAUSE THE VERDICT IS NOT ENOUGH, and that was measured rather than assumed: the
## mutation pass found that get_values returning `number = 2` reddens NOTHING behavioural. The stamp
## is set by the FIRST use that runs past the action's own cap, whatever the bonus was, and once it is
## set the buff stops applying - so a bonus of 2, 5 or 50 all produce exactly one extra use. That is a
## good property of the design (the stamp is a stronger guard than the number), but it leaves the
## number itself unpinned by any activation, and 0 is the only wrong value an activation test catches.
## Reading the cap through the real channel - get_buffs_to, so check_if_passive_applies still runs -
## is what pins it.
func effective_round_cap(kit_id:StringName) -> int:
	var gear:GearCore = myconid.get_gear(kit_id)
	if not GearCore.is_valid(gear): return -1
	var specific := SpecificAction.create(myconid, gear, gear.kit.actions[0])
	var context:Context = specific.to_context()
	var cap:int = specific.action.get_per_round_hard_limit(specific)
	for buff:BuffCore in UnitCondition.get_buffs_to(myconid, Buff.TO.ACTION_PER_ROUND, context):
		cap += buff.get_values(context).number
	return cap

## Record ONE use of a Kit's solo action exactly as the engine records it: UnitAction.spend's last
## line is gear.increment_action_usage_for_action (unit_action.gd:279), and nothing else moves the
## round counter the gate reads.
##
## USED WHERE THE QUESTION IS THE GATE AND NOT THE ACTIVATION. A free ORDINARY action and a reaction
## reach that counter by completely different routes - one needs the holder's turn open and an action
## budget, the other needs a trigger and a point - so driving both through real activations would
## make the two halves of a comparison differ in half a dozen ways besides the one being measured.
## Incrementing by hand puts them in identical state and leaves exactly one difference: the class.
func record_one_use(kit_id:StringName) -> void:
	var gear:GearCore = myconid.get_gear(kit_id)
	if not GearCore.is_valid(gear): return
	gear.increment_action_usage_for_action(gear.kit.actions[0])

## A plain vanilla-statblock unit, for the spike's control cases.
func plain_unit(tile:Vector2i = Vector2i(2, 2)) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	SpecFactory.apply_passive_buffs(unit)
	return unit

func apply_reaction_statblock_buff(unit:Unit) -> void:
	var base := ReactionStatblockBuff.new()
	base.to = Buff.TO.STATBLOCK
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(base))
	unit.update_cached_values_and_token()

# ================================ the trait itself ================================

func test_the_trait_is_on_the_frame_and_is_a_trait():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_symbiosis is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait, not equippable gear.')
	assert_true(kit.actions.is_empty(), 'It is pure passives: no actions.')
	var frame:Frame = ContentLibrary.get_mech_frame(&'mf_myconid')
	var trait_ids:Array[StringName] = []
	for t:Kit in frame.traits: trait_ids.append(t.compcon_id)
	assert_has(trait_ids, TRAIT_ID, 'The frame carries it.')

func test_the_trait_carries_the_gaze_shaped_stat_increase():
	# Asserted on the RESOURCE as well as on the unit, because "max is 2" would also be true of a
	# frame whose statblock said reactions = 2 - which would be a different, permanent, uncapped
	# thing, and the whole design turns on the +1 coming from a passive the bookkeeping can reason
	# about.
	#
	# Kit.get_passives(type) is the real name; the GearCore-level get_passives_of_type the brief
	# quoted (gear_core.gd:357) has no Kit-level twin - kit.gd:157 is the one, and gear_core's
	# forwards straight to it.
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_symbiosis is in the kits index.')
	if not Kit.is_valid(kit): return
	var increases:Array[Passive] = kit.get_passives(PassiveStatIncrease)
	assert_eq(increases.size(), 1, 'Exactly one PassiveStatIncrease.')
	if increases.is_empty(): return
	var passive:PassiveStatIncrease = increases[0]
	assert_not_null(passive.stat, 'It carries a statblock.')
	if passive.stat == null: return
	assert_eq(passive.stat.reactions, 1, '+1 reaction, as mt_gaze does.')
	assert_false(passive.is_override, 'An increase, not an override.')
	assert_eq(ContentLibrary.get_mech_frame(&'mf_myconid').stat.reactions, 1,
		'And the frame itself still declares the ordinary one.')

func test_the_effect_row_resolves():
	assert_ne(X.tr('gear.mt_symbiosis.name'), 'gear.mt_symbiosis.name', 'The trait is named.')
	assert_ne(X.tr('gear.mt_symbiosis.effect'), 'gear.mt_symbiosis.effect', 'It has rule text.')

# ================ the stat route (the spike's section A, against the real trait) ================

func test_a_plain_frame_has_one_reaction_per_turn():
	assert_eq(plain_unit().core.get_reactions_max(), 1,
		'The default statblock grants exactly one reaction.')

func test_the_myconid_reaction_max_is_two():
	assert_eq(reactions_max(), 2,
		'unit_printer.gd:134 folds the passive into core.bonus and unit_core.gd:415 adds it.')

func test_a_plain_frame_cannot_react_twice_in_a_turn():
	var unit := plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	assert_false(UnitAction.has_reaction(unit), 'One reaction, spent.')

func test_the_myconid_can_really_react_twice_in_one_turn():
	# Two DIFFERENT reaction Kits, because the per-round hard limit is 1 per GEAR. Driven through real
	# activations rather than through UnitAction.spend_reaction, so this asserts the second reaction
	# HAPPENS and not merely that a counter allows it.
	assert_eq(reactions_left(), 2, 'fixture: two points to start.')
	await react_with(rxn_a)
	assert_eq(rxn_a.fired, 1, 'The first reaction fired.')
	assert_eq(reactions_left(), 1, 'And spent a point.')
	await react_with(rxn_b)
	assert_eq(rxn_b.fired, 1, 'The second reaction fired too.')
	assert_eq(reactions_left(), 0, 'Both points are gone.')

# ============ the buff route: ruling 13, mod-wide (the spike's section B, unchanged) ============

func test_a_statblock_buff_raises_the_unit_level_reaction_max():
	var unit := plain_unit()
	apply_reaction_statblock_buff(unit)
	assert_eq(unit.get_reactions_max(), 2,
		'unit.gd:315 adds state.stat_bonus.reactions, which unit_battle_state.gd:231-234 fills.')

func test_a_statblock_buff_does_not_reach_the_core_reaction_max():
	var unit := plain_unit()
	apply_reaction_statblock_buff(unit)
	assert_eq(unit.core.get_reactions_max(), 1,
		'unit_core.gd:415 is frame.stat + core.bonus only; no buff can write core.bonus.')

func test_the_turn_refill_ignores_a_statblock_reaction_buff():
	var unit := plain_unit()
	apply_reaction_statblock_buff(unit)
	UnitAction.every_new_turn_refresh(unit)
	assert_eq(unit.core.current.reactions, 1,
		'unit_action.gd:69 sets current.reactions = unit.core.get_reactions_max().')

func test_a_statblock_buff_does_not_buy_a_second_reaction():
	# The same finding as behaviour rather than as a number, so an engine change that fixed one and
	# not the other cannot leave ruling 13 half-true. This is why Symbiosis is a PASSIVE plus
	# bookkeeping and not "a buff that grants a reaction" - which is the shape everybody reaches for.
	var unit := plain_unit()
	apply_reaction_statblock_buff(unit)
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	assert_false(UnitAction.has_reaction(unit), 'The +1 is inert at the gate that matters.')

# ======= the granted-point route: what the bookkeeping uses (the spike's section C) =======

func test_a_hand_granted_reaction_point_buys_a_second_reaction():
	# common_action_util.gd:734 already does exactly this += 1 to keep Flank and Overwatch from
	# double-billing one reaction, so direct assignment is an established vanilla move - which is
	# what buff_symbiosis.gd leans on to take a point back.
	var unit := plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	unit.core.current.reactions += 1
	assert_true(UnitAction.has_reaction(unit), 'A granted point is spendable with no clamp in the way.')

func test_a_hand_granted_reaction_point_does_not_survive_the_turn_refill():
	# Which is why a granted point cannot BY ITSELF express 1/round: the refill runs on every unit at
	# every turn start, so the point is re-issued per turn unless something takes it away again. That
	# something is buff_symbiosis on NEW_TURN POST, queued after the refill.
	var unit := plain_unit()
	unit.core.current.reactions += 1
	UnitAction.every_new_turn_refresh(unit)
	assert_eq(unit.core.current.reactions, 1, 'The refill assigns, it does not top up.')

func test_the_printer_clamp_erases_a_hand_granted_reaction_point():
	var unit := plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	unit.core.current.reactions += 1
	UnitPrinter.clamp_current_stats_to_max(unit.core)
	assert_eq(unit.core.current.reactions, 1, 'unit_printer.gd:169 clamps to the CORE max.')

# ================ the exclusion is readable (the spike's section D, unchanged) ================

func test_a_one_per_scene_reaction_kit_declares_its_scene_limit():
	var kit := ContentLibrary.get_kit(SCENE_LIMITED_REACTION_KIT)
	assert_true(Kit.is_valid(kit), 'The Manticore trait Kit loaded.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.uses_per_scene, 1,
		'kit.gd:39 is where 1/scene lives, readable without a script extension.')

func test_an_unlimited_reaction_kit_declares_no_scene_limit():
	var kit := ContentLibrary.get_kit(UNLIMITED_REACTION_KIT)
	assert_true(Kit.is_valid(kit), 'The Overwatch Kit loaded.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.uses_per_scene, 0, 'So the exclusion is a readable property, not a guess.')
	assert_eq(kit.charges_max, 0, 'And Limited X - the 1/mission shape - is kit.gd:35, beside it.')

# ================================ the bookkeeping ================================

func test_all_three_bookkeeping_buffs_are_applied_and_hidden():
	# None is ever a chip on the unit, which is why VISIBLE_BUFFS does not grow in SP1 and does not
	# grow for the third one either. If any were visible the player would carry permanent icons
	# explaining nothing.
	#
	# THE COUNT IS ALSO THE WIRING TEST for SP2.5 Task 1: buff_symbiosis_extra_use reaches the unit
	# only through mt_symbiosis's one PassiveBuffApplicator, so dropping it from that array reddens
	# this test as well as every Gyre test below - which is what makes "the trait is all three or
	# none" something the suite states rather than something the .tres asserts about itself.
	for buff_id:StringName in [BOOKKEEPING_BUFF, EXCLUSION_BUFF, EXTRA_USE_BUFF]:
		var core:BuffCore = UnitCondition.get_buff(myconid, buff_id)
		assert_true(BuffCore.is_valid(core), '%s is on the Myconid.' % buff_id)
		if not BuffCore.is_valid(core): continue
		assert_true(core.base.hide_from_player, '%s is hidden.' % buff_id)

func test_the_stamp_is_set_only_when_the_second_reaction_is_taken():
	assert_false(extra_spent(), 'Nothing spent yet.')
	await react_with(rxn_a)
	assert_false(extra_spent(),
		'One reaction is the ordinary allowance, not the extra.')
	await react_with(rxn_b)
	assert_true(extra_spent(), 'The second one is the extra, and it is stamped.')

func test_the_next_turn_start_leaves_one_reaction_once_the_extra_is_spent():
	await react_with(rxn_a)
	await react_with(rxn_b)
	await SpecFactory.start_turn(game, dummy)
	assert_eq(reactions_max(), 2, 'The max is untouched: the trait is still a +1.')
	assert_eq(reactions_left(), 1,
		'But the refilled point is taken straight back: one reaction for the rest of the round.')

func test_the_myconids_own_turn_start_also_caps_once_the_extra_is_spent():
	# THE COMMON CASE IN PLAY, and the one the dummy-turn test above cannot see. A turn start runs
	# handle_starting_unit (event_turn_start.gd:65) FIRST, and that is the only place
	# apply_buffs_from_passive_gear is called with is_start_of_turn_reapplication (:99) - for the
	# STARTING unit alone. So the Myconid's own turn start is the one turn start where the
	# applicator's reapply_at_the_start_of_each_turn could hand the trait a fresh BuffCore and wipe
	# the stamp, before the refill at :43-44 and the cap queued at :56 ever run.
	#
	# Without this test the export's default is unfalsifiable by the suite: setting it to true
	# reddens nothing, because every other bookkeeping test starts the DUMMY's turn (deliberately -
	# that is what pins "ANY unit's turn start"). Written after that mutation check came back green
	# where the plan expected two reds.
	await react_with(rxn_a)
	await react_with(rxn_b)
	assert_true(extra_spent(), 'fixture: the extra for this round has gone.')
	await SpecFactory.start_turn(game, myconid)
	assert_true(extra_spent(), 'The stamp survived the Myconid own turn start.')
	assert_eq(reactions_left(), 1, 'And the refilled extra was taken straight back.')

func test_a_round_in_which_only_one_reaction_was_taken_never_caps():
	# The other half of the same behaviour, and the one that would go unnoticed: a cap that fired
	# unconditionally would make Symbiosis do nothing at all, and every test above would still pass.
	await react_with(rxn_a)
	await SpecFactory.start_turn(game, dummy)
	assert_eq(reactions_left(), 2, 'The full two, because the extra was never spent.')

func test_the_next_rounds_first_turn_start_restores_the_full_two():
	# "1/round" is a REAL round for this trait: the stamp clears on NEW_ROUND POST
	# (event_round_new.gd:77), which runs before the round's first turn starts (:84).
	await react_with(rxn_a)
	await react_with(rxn_b)
	await SpecFactory.start_turn(game, dummy)
	assert_eq(reactions_left(), 1, 'Still capped inside the round.')
	await game.execute_event(&'event_round_new', {})
	assert_false(extra_spent(), 'The new round cleared the stamp.')
	await SpecFactory.start_turn(game, dummy)
	assert_eq(reactions_left(), 2, 'And the extra is available again.')

# ================================ the exclusion ================================

func test_a_one_per_scene_reaction_is_allowed_as_the_first_reaction():
	# The permissive half first, because the refusal below is indistinguishable from "this reaction
	# never worked" without it.
	await react_with(rxn_scene)
	assert_eq(rxn_scene.fired, 1, 'A 1/scene reaction taken first is perfectly ordinary.')
	assert_eq(reactions_left(), 1, 'And it spent the ordinary point.')

func test_a_one_per_scene_reaction_is_refused_as_the_second_reaction():
	await react_with(rxn_a)
	assert_eq(reactions_left(), 1, 'fixture: the ordinary reaction has been taken.')
	await react_with(rxn_scene)
	assert_eq(rxn_scene.fired, 0, 'The 1/scene reaction did not happen.')

func test_the_refused_reaction_spends_no_usage_and_no_reaction_point():
	# The refusal must not be a no-op body: a refusal that still billed the point would be strictly
	# worse for the player than not having the trait. Since Pass F (T21) the reaction is never offered
	# at all (test_a_spent_scene_reaction_is_not_offered), and this pins the ruling's "the player
	# loses nothing: point and usage are not spent". The ROUND counter is the usage asserted here.
	await react_with(rxn_a)
	var points_before:int = reactions_left()
	await react_with(rxn_scene)
	assert_eq(reactions_left(), points_before, 'The reaction point is untouched.')
	assert_eq(uses_this_round(RXN_SCENE), 0, 'And the usage counter never moved.')

func test_a_limited_one_reaction_is_refused_as_the_second_reaction():
	# "1/mission" is Limited 1 (kit.gd:35).
	await react_with(rxn_a)
	await react_with(rxn_lim1)
	assert_eq(rxn_lim1.fired, 0, 'A Limited 1 reaction is excluded too.')

func test_a_limited_three_reaction_is_not_excluded():
	# The discriminating case for the exclusion predicate. A Limited 2+ reaction is neither 1/scene
	# nor 1/mission, so Symbiosis works on it - and a gate written as "charges_max > 0" would refuse
	# this one and no test above would notice.
	await react_with(rxn_a)
	await react_with(rxn_lim3)
	assert_eq(rxn_lim3.fired, 1, 'A Limited 3 reaction is still allowed as the extra.')
	assert_eq(reactions_left(), 0, 'And it spent the extra point.')

func test_an_ordinary_action_is_never_aborted():
	# A QUICK action on a Kit that IS 1/scene, taken after a reaction has already been spent - so
	# everything the gate excludes is true of it except that it is not a reaction. Dropping the
	# consumes_reaction() clause from the gate reddens exactly this.
	await MyconidFixture.open_turn(game, myconid)
	await react_with(rxn_a)
	await SpecFactory.use_solo(game, myconid, QUICK_SCENE)
	assert_eq(quick.fired, 1, 'The ordinary 1/scene action went through.')

func test_after_the_cap_the_ordinary_reaction_may_still_be_one_per_scene():
	# THE OVER-REFUSAL THIS TEST EXISTS TO PREVENT. Once the round's extra has gone, every later turn
	# start refills to 2 and buff_symbiosis caps straight back to max - 1: the Myconid stands at 1 of 2
	# with NOTHING spent that turn. A gate reading `current < max` alone would call that turn's FIRST
	# reaction the extra and abort it - and the card restricts the EXTRA use only. Reachable in play:
	# react twice on one turn, then face any 1/scene reaction later in the same round.
	await react_with(rxn_a)
	await react_with(rxn_b)
	assert_true(extra_spent(), 'fixture: the round extra has gone.')
	await SpecFactory.start_turn(game, dummy)
	assert_eq(reactions_left(), 1, 'fixture: the cap left one point, and none of it is spent yet.')
	log_lines = []
	await react_with(rxn_scene)
	assert_eq(rxn_scene.fired, 1, 'The turn first reaction is the ordinary allowance, 1/scene or not.')
	assert_eq(uses_this_round(RXN_SCENE), 1, 'And its usage counter moved, so it really activated.')
	var refused := false
	for line:String in log_lines:
		if line.contains('Symbiosis'): refused = true
	assert_false(refused, 'And nothing was refused in the battle log: %s' % [log_lines])

func test_a_non_consuming_reaction_is_neither_refused_nor_stamped():
	# The gate's FIRST clause is action.consumes_reaction() (buff_symbiosis_exclusion.gd:check_if_passive_applies) - the
	# action here is present and real, its consumes_reaction() just returns false, so this is a real
	# clause doing real work, not a vacuous one. Everything else about this reaction is built to fail
	# the OTHER clauses the ordinary way: uses_per_scene = 1 makes is_excluded() true, and it fires as
	# the Myconid's SECOND reaction of the turn (current.reactions == max - 1, the round's extra still
	# unspent), so current < max and not is_extra_spent() are both true too. Only the
	# consumes_reaction() clause can be what lets it through - which is exactly what deleting it
	# (below, as a mutation check) is here to prove.
	#
	# THE NAME IS NARROWER THAN IT READS, SINCE SP2.5. A non-consuming reaction CAN be stamped now -
	# that is the whole point of buff_symbiosis_extra_use, and it is how the Gyre and Halo get their
	# second use. THIS one escapes for a different reason: it declares no get_per_round_hard_limit
	# override, so action_reaction.gd:69 hands it 99, and buff_symbiosis.is_cap_relieved_use asks
	# uses_this_round > hard_limit - 1 > 99, false. Neither the stamp nor the take-back runs. Read
	# the assertion below as "not stamped BECAUSE its cap was never relieved", not as a claim about
	# non-consuming reactions in general.
	await react_with(rxn_a)
	assert_eq(reactions_left(), reactions_max() - 1,
		'fixture: the ordinary reaction has been taken, one point short of the max.')
	log_lines = []
	await react_with(rxn_nonconsuming)
	assert_eq(rxn_nonconsuming.fired, 1, 'The non-consuming reaction fired normally, not refused.')
	var refused := false
	for line:String in log_lines:
		if line.contains('Symbiosis'): refused = true
	assert_false(refused, 'And no Symbiosis refusal reached the battle log: %s' % [log_lines])
	assert_false(extra_spent(), 'Not stamped as the extra: a non-consuming reaction spends no point.')
	assert_eq(reactions_left(), reactions_max() - 1,
		'And the reaction point count is unchanged from before this reaction.')

# ===================== the per-round half: the Uffish Gyre (SP2.5 Task 1) =====================

func test_a_second_gyre_in_the_round_is_offered_after_symbiosis():
	# THE AUTHOR'S REPRO, and the bug this sub-project exists for. An ally moved and the Gyre fired;
	# on the next ally's turn - same round, the Myconid not having taken its turn - another ally moved
	# and Symbiosis did not offer it again.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)

	await gyre_at(first)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the first ally move fired the Gyre.')

	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2,
		'Symbiosis offers the Gyre a second time in the same round.')
	assert_true(UnitCondition.has_buff(second, ARMOR_CHIP),
		'And the second ally really was armored, so the reaction resolved and did not merely count.')

func test_the_extra_use_raises_the_cap_by_exactly_one():
	# "an additional time" is ONE, and this is the only test that can see the number. Measured, not
	# assumed: the mutation pass showed get_values returning `number = 2` reddens nothing at all
	# behaviourally, because the stamp is set by the first use that runs past the action's own cap
	# whatever the bonus was, and after that the buff stops applying. So every value of 1 or more
	# produces exactly one extra use, and only 0 is caught by an activation test. See
	# effective_round_cap for the whole of it.
	#
	# Read through UnitCondition.get_buffs_to rather than off the resource, so check_if_passive_applies
	# still runs and the two excluded controls below mean something.
	assert_eq(hard_limit(RXN_PLAIN_A), 1, 'fixture: the action s own cap is 1.')
	assert_eq(effective_round_cap(RXN_PLAIN_A), 2, 'Symbiosis makes it 2, not 3 and not 1.')
	assert_eq(effective_round_cap(RXN_SCENE), 1,
		'CONTROL: an excluded reaction s cap is untouched, so the +1 is not a blanket one.')

	await react_with(rxn_a)
	await react_with(rxn_b)
	assert_true(extra_spent(), 'fixture: the round s extra has gone.')
	assert_eq(effective_round_cap(RXN_PLAIN_A), 1,
		'And once it has, the cap is back to the action s own: the bonus is not permanent.')

func test_the_same_consuming_reaction_twice_in_a_round_bills_one_point_per_use():
	# THE ACTIVATION-LEVEL HALF of the test above, and the fourth budget state the take-back's own
	# header does not enumerate. Everything else in this file that fires one gear twice in a round is
	# the Gyre or Halo, both consumes_rxn = false, where the activation moves no point and the
	# take-back is the only thing that bills it. rxn_a CONSUMES: UnitAction.spend has already taken
	# the point at unit_action.gd:257 by the time the UNIT_ACTION POST runs, so a take-back on top
	# charges one activation twice and leaves the Myconid with nothing on a turn it reacted once.
	#
	# The cap-level assertions above cannot see any of that - they read effective_round_cap and
	# is_under_per_round_limit, both of which sit upstream of the point spend, and record_one_use
	# bypasses activation entirely. This is the test that walks the whole path.
	await react_with(rxn_a)                   # turn A: 2 -> 1, uses 1, under its own cap, no stamp
	assert_false(extra_spent(), 'fixture: one use is within the action s own cap, so nothing is spent yet.')

	await SpecFactory.start_turn(game, dummy) # turn B: refilled to 2, the stamp is still unset
	assert_eq(reactions_left(), 2, 'fixture: the refill stands while the extra is unspent.')

	await react_with(rxn_a)                   # the same gear again, allowed ONLY by the raised cap
	assert_eq(rxn_a.fired, 2, 'CONTROL: the raised cap really offered the same gear a second time.')
	assert_true(extra_spent(), 'The round s extra is stamped spent by the over-cap use.')
	assert_eq(reactions_left(), 1,
		'And one reaction costs one point: the engine s spend is not doubled by the take-back.')

func test_a_third_gyre_in_the_round_is_refused():
	# "an additional time", singular. The second use is Symbiosis's; the third has nothing left to
	# relieve it, because taking the second set the stamp and the stamp is what
	# buff_symbiosis_extra_use reads before applying.
	#
	# NOT reddened by get_values returning number = 2, and that is a property of the design rather
	# than a hole in this test - the stamp closes the door on the first over-cap use however wide the
	# buff opened it. test_the_extra_use_raises_the_cap_by_exactly_one is what pins the number.
	#
	# THE REASON IS ASSERTED AS WELL AS THE REFUSAL. PER_ROUND (unit_action.gd:148) is the gate this
	# whole task is about; a different reason - a spent scene use, a destroyed Kit - would refuse the
	# third Gyre too while meaning something else entirely.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)
	var third := MyconidFixture.create_ally(game, ALLY_C)

	await gyre_at(first)
	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2, 'CONTROL: the extra really was available for the second.')

	assert_eq(UnitAction.get_gear_unavailable_reason(
		SpecificAction.create(myconid, pike_gear(), gyre())), UnitAction.REASON.PER_ROUND,
		'And now the per-round limit is what refuses it, by name.')
	await gyre_at(third)
	assert_eq(gyre_uses_this_round(), 2, 'So the third ally s move did not fire it.')
	assert_false(UnitCondition.has_buff(third, ARMOR_CHIP), 'And the third ally got nothing.')

func test_the_second_gyre_spends_symbiosis_for_the_round():
	# The stamp is what makes "1/round" true of the whole trait rather than of each channel
	# separately. A non-consuming reaction moves no reaction point, so buff_symbiosis's original
	# value-based test can never see this use - is_cap_relieved_use is what does, and dropping it
	# reddens this test and the two order tests below.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)

	await gyre_at(first)
	assert_eq(gyre_uses_this_round(), 1, 'fixture: the first Gyre fired.')
	assert_false(extra_spent(),
		'CONTROL: the FIRST Gyre is not the extra - it is inside the reaction s own 1/round.')

	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2, 'fixture: the second Gyre fired.')
	assert_true(extra_spent(), 'And the second one spent Symbiosis for the round.')

func test_an_extra_ordinary_reaction_is_refused_after_a_second_gyre():
	# ONE EXTRA PER ROUND, TOTAL - the first of the two orders. The Gyre spends no reaction POINT, so
	# without the take-back in buff_symbiosis.activate() the Myconid would still be holding both
	# points here and could spend the second on an ordinary reaction as well: two extras out of one
	# round's "1/round". Dropping the take-back reddens this test.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)

	await gyre_at(first)
	assert_eq(reactions_left(), reactions_max(),
		'fixture: the first Gyre cost no reaction point, as its card says.')
	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2, 'fixture: the second Gyre fired.')
	assert_eq(reactions_left(), reactions_max() - 1,
		'And the extra was billed to the point budget, since it was not billed to the reaction.')

	# POSITIVE CONTROL FIRST: the ORDINARY reaction is untouched - the card restricts the extra only,
	# and a take-back that ate the whole budget would be strictly worse than not having the trait.
	await react_with(rxn_a)
	assert_eq(rxn_a.fired, 1, 'CONTROL: the turn s ordinary reaction still goes through.')
	await react_with(rxn_b)
	assert_eq(rxn_b.fired, 0, 'But there is no second one: Symbiosis went on the Gyre.')

func test_a_second_gyre_is_refused_after_an_extra_ordinary_reaction():
	# THE OTHER ORDER. Here the stamp is set by buff_symbiosis's original value-based path - two
	# points gone - and buff_symbiosis_extra_use.check_if_passive_applies reads it and declines to
	# raise the cap. Deleting that read reddens this test.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)

	await react_with(rxn_a)
	await react_with(rxn_b)
	assert_true(extra_spent(), 'fixture: the round s extra went on an ordinary second reaction.')

	# POSITIVE CONTROL: the Gyre's OWN 1/round is untouched by any of this.
	await gyre_at(first)
	assert_eq(gyre_uses_this_round(), 1, 'CONTROL: the Gyre s own once-per-round still fires.')
	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 1, 'But it is not offered a second time: Symbiosis is spent.')
	assert_false(UnitCondition.has_buff(second, ARMOR_CHIP), 'And the second ally got nothing.')

func test_a_non_reaction_1_per_round_action_gets_no_extra_use():
	# JUDGMENT CALL 1, PINNED. buff_symbiosis_extra_use's first clause is `action is ActionReaction`,
	# and this is what makes it discriminate rather than decorate: a naturally-free ORDINARY action
	# carries the SAME 1/round cap by Action.get_per_round_hard_limit's own default
	# (action.gd:156-158), so "capped at 1/round" would have let it through and nothing else in this
	# file would have noticed.
	#
	# Both kits are put in identical state by hand - see record_one_use - so the only difference
	# between the two answers below is the action's class.
	assert_eq(hard_limit(FREE_PLAIN), 1,
		'fixture: a naturally free ordinary action is 1/round by the engine s own default.')
	assert_eq(hard_limit(RXN_PLAIN_A), 1, 'fixture: and so is an ordinary consuming reaction.')

	record_one_use(FREE_PLAIN)
	record_one_use(RXN_PLAIN_A)
	assert_true(is_under_per_round_limit(RXN_PLAIN_A),
		'CONTROL: the reaction s cap was raised, so a second use is still under it.')
	assert_false(is_under_per_round_limit(FREE_PLAIN),
		'The free action s was not: it is not a reaction, and the card says reaction.')

func test_a_1_per_scene_reaction_gets_no_extra_use():
	# JUDGMENT CALL 2, AND THE TEST SHAPE IS THE FINDING. The card excludes 1/scene and 1/mission
	# reactions, and buff_symbiosis_extra_use honours that by calling the exclusion half's
	# is_excluded(kit) - shared, not copied.
	#
	# BUT THE CLAUSE IS BELT-AND-BRACES HERE, MEASURED RATHER THAN ASSUMED, so this test asserts on
	# the GATE and not on an activation. uses_per_scene is read in exactly one place -
	# `gear.get_uses_this_scene(action) >= kit.uses_per_scene` at unit_action.gd:147 - and Limited X
	# in `not gear.has_charges_left()` at :153; both are separate counters (gear_core.gd:197-202) that
	# no buff channel reaches, and both sit AHEAD of PER_ROUND (:148) in the same elif chain. So an
	# excluded reaction is refused whatever the round cap says, and a test written against "did it
	# fire" would have passed with the exclusion clause deleted. The cap is the only thing the clause
	# can move, so the cap is what is asserted.
	record_one_use(RXN_PLAIN_A)
	record_one_use(RXN_SCENE)
	record_one_use(RXN_LIMITED_1)
	record_one_use(RXN_LIMITED_3)

	assert_true(is_under_per_round_limit(RXN_PLAIN_A),
		'CONTROL: an unrestricted reaction s cap is raised.')
	assert_true(is_under_per_round_limit(RXN_LIMITED_3),
		'CONTROL: and so is a Limited 3 one, which is neither 1/scene nor 1/mission.')
	assert_false(is_under_per_round_limit(RXN_SCENE), 'A 1/scene reaction s is not.')
	assert_false(is_under_per_round_limit(RXN_LIMITED_1), 'Nor is a Limited 1 one - "1/mission".')

func test_the_extra_use_is_gone_on_the_next_round():
	# The stamp is cleared on NEW_ROUND POST (event_round_new.gd:77), so the extra comes back - and
	# not before. Both halves are here, because "gone" and "back" are the same line of code read from
	# two sides: not clearing the stamp reddens the second half, clearing it early the first.
	#
	# THE TWO CLOCKS ARE DIFFERENT AND BOTH ARE NEEDED. Symbiosis's stamp is a REAL round; the Gyre's
	# own 1/round counter is cleared by UnitAction.reset_per_round_usage at the MYCONID's own turn
	# start (design ruling 5). So the round boundary alone leaves the Gyre's counter at 2 and nothing
	# would fire; the Myconid's turn start is what resets it.
	var first := MyconidFixture.create_ally(game, ALLY_A)
	var second := MyconidFixture.create_ally(game, ALLY_B)
	var third := MyconidFixture.create_ally(game, ALLY_C)

	await gyre_at(first)
	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2, 'fixture: both this round s Gyres have gone.')
	await gyre_at(third)
	assert_eq(gyre_uses_this_round(), 2, 'Still gone later in the SAME round.')

	await game.execute_event(&'event_round_new', {})
	assert_false(extra_spent(), 'The new round cleared the stamp.')
	await SpecFactory.start_turn(game, myconid)
	assert_eq(gyre_uses_this_round(), 0, 'fixture: and the Myconid s own turn start cleared the Gyre s.')

	await gyre_at(first)
	await gyre_at(second)
	assert_eq(gyre_uses_this_round(), 2, 'And the extra is available again in the new round.')

func test_a_spent_scene_reaction_is_not_offered():
	# T21 (Pass F): the excluded reaction is HIDDEN, not offered and then refused. The ruling: "the
	# player loses nothing: point and usage are not spent" - so there is nothing to explain in the
	# battle log either, and the old refusal row is gone. Asserted at both ends: the engine's own
	# availability gate, and the reaction bus never asking the reaction at all.
	var gear:GearCore = myconid.get_gear(RXN_SCENE)
	var specific := SpecificAction.create(myconid, gear, rxn_scene)
	assert_true(UnitAction.can_activate_gear(specific), 'fixture: offered as the FIRST reaction.')
	await react_with(rxn_a)
	assert_false(UnitAction.can_activate_gear(specific), 'As the extra, the gear is unavailable.')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific), UnitAction.REASON.FORBIDDEN,
		'Refused by the ACTION_FORBIDDEN buff, not by some other gate.')
	log_lines = []
	await react_with(rxn_scene)
	assert_eq(rxn_scene.offered, 0, 'The bus never offered the 1/scene reaction.')
	assert_eq(rxn_scene.fired, 0, 'The 1/scene reaction did not happen.')
	var named := false
	for line:String in log_lines:
		if line.contains('Symbiosis'): named = true
	assert_false(named, 'Nothing is refused, so nothing is logged: %s' % [log_lines])
