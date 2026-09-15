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
#     buff_symbiosis_exclusion  PRE    unit_action -> abort an excluded reaction taken as the second
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

## A vanilla 1/scene reaction Kit: the Manticore's Castigate The Enemies Of The Godhead, whose Kit
## declares uses_per_scene = 1. A vanilla control with no scene limit at all beside it.
const SCENE_LIMITED_REACTION_KIT := &'mt_castigate_the_enemies_of_the_godhead'
const UNLIMITED_REACTION_KIT := &'ms_overwatch'

const MYCONID_TILE := Vector2i(4, 4)
const DUMMY_TILE := Vector2i(10, 6)

## Ids for the runtime Kits this spec installs. Prefixed so they can never be confused with content.
const RXN_PLAIN_A := &'symbiosis_spec_rxn_plain_a'
const RXN_PLAIN_B := &'symbiosis_spec_rxn_plain_b'
const RXN_SCENE := &'symbiosis_spec_rxn_scene'     # uses_per_scene = 1  -> "1/scene"
const RXN_LIMITED_1 := &'symbiosis_spec_rxn_lim1'  # charges_max = 1     -> "1/mission"
const RXN_LIMITED_3 := &'symbiosis_spec_rxn_lim3'  # charges_max = 3     -> neither
const QUICK_SCENE := &'symbiosis_spec_quick_scene' # an ORDINARY action on a 1/scene Kit

## A spec-local reaction. DAMAGE POST, so one poke at the punching bag offers it; `armed` is what
## makes the ORDER deterministic - the bus evaluates every gate before any body runs, so two armed
## reactions on one poke would fire in an order nothing in the engine promises.
class SpecReaction extends ActionReaction:
	var armed := false
	var fired := 0

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

func _make_reaction() -> SpecReaction:
	var rxn := SpecReaction.new()
	rxn.triggers_on.append(&'damage')
	rxn.trigger_timing = ReactionBus.TIMING.POST
	rxn.consumes_rxn = true
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
	var kits:Array[Kit] = [
		_make_kit(RXN_PLAIN_A, rxn_a, 0, 0),
		_make_kit(RXN_PLAIN_B, rxn_b, 0, 0),
		_make_kit(RXN_SCENE, rxn_scene, 1, 0),
		_make_kit(RXN_LIMITED_1, rxn_lim1, 0, 1),
		_make_kit(RXN_LIMITED_3, rxn_lim3, 0, 3),
		_make_kit(QUICK_SCENE, quick, 1, 0),
	]
	for kit:Kit in kits: myconid.core.loadout.equipped_kits.append(kit)
	SpecFactory.apply_passive_buffs(myconid)
	UnitTile.move_to(myconid, MYCONID_TILE)

func disarm_all() -> void:
	for rxn:SpecReaction in [rxn_a, rxn_b, rxn_scene, rxn_lim1, rxn_lim3]: rxn.armed = false

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

func test_both_bookkeeping_buffs_are_applied_and_hidden():
	# Neither is ever a chip on the unit, which is why VISIBLE_BUFFS does not grow in SP1. If either
	# were visible the player would carry two permanent icons explaining nothing.
	for buff_id:StringName in [BOOKKEEPING_BUFF, EXCLUSION_BUFF]:
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
	# The refusal has to be an ABORT, not a no-op body: event_gear_activate.gd:100-104 gates the POST
	# on the usage having moved, and a refusal that still billed the point would be strictly worse for
	# the player than not having the trait. The ROUND counter is what that gate reads, so it is the
	# one asserted here.
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

func test_the_refusal_writes_a_battle_log_line_naming_symbiosis():
	# Without this the refusal reads as the activation simply not happening, which in play is
	# indistinguishable from a bug. Asserted on the rendered line rather than on the key, so it also
	# pins that the CSV row exists and reached the compiled artifact.
	await react_with(rxn_a)
	log_lines = []
	await react_with(rxn_scene)
	var named := false
	for line:String in log_lines:
		if line.contains('Symbiosis'): named = true
	assert_true(named, 'The battle log says why the reaction was refused: %s' % [log_lines])
