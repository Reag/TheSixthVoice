# SPIKE 4b (Myconid SP1 Task 1): can a UNIT_ACTION PRE buff ABORT a gear activation?
#
# Symbiosis (sheet 04-myconid.md): "1/round, the Myconid may use a reaction an additional time. This
# cannot be used on reactions that are 1/scene or 1/mission."
#
# The exclusion clause needs something that sees the ACTIVATION, not the budget - a reaction point
# does not know what it will be spent on. The natural place, UnitAction.can_take_reactions, is in the
# one autoload whose script extensions install and then never run (CLAUDE.md; measured 2026-09-02 on
# that very function). Spike 4 probed the budget and deliberately stopped one question short of this
# one, so design 1.1 makes SP1 open with it.
#
# THIS IS A PROBE, NOT CONTENT. It asserts only against VANILLA frames and vanilla gear - the Myconid
# does not exist yet - so every test here is a characterisation of the 1.4.3 engine. It is DELETED in
# SP1 Task 3, when test_symbiosis.gd carries the same case against the real buff, exactly as
# test_spike_symbiosis.gd is.
#
# IF THIS FILE CANNOT GO GREEN, SP1 STOPS AND REPORTS. The fallback (drop the clause, record a
# divergence) is the author's call, not the implementer's.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_symbiosis_exclusion.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## A plain vanilla rifle, so the free Overwatch every unit carries has something to shoot with.
## Vanilla's own test/gear/test_ms_overwatch.gd equips exactly this and nothing else.
const RIFLE_ID := &'mw_assault_rifle'
const OVERWATCH_ID := &'ms_overwatch'

const SHOOTER_TILE := Vector2i(0, 0)
const MOVER_FROM := Vector2i(1, 1)
const MOVER_TO := Vector2i(3, 3)

var game:Gamemaster
var shooter:Unit
var mover:Unit

## THE PROBE BUFF. UNIT_ACTION / PRE, and its activate() marks the TRIGGERING event core aborted -
## which for this trigger is the virtual event_unit_action core that event_gear_activate.gd:54 built
## and that :56 reads back through core.abort_when(virtual_core.aborted).
##
## It refuses anything that is not a reaction, so the negative case below (an ordinary action by the
## same unit) exercises THIS buff rather than a second one that could differ in some way nobody
## wrote down.
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive to be asked about the next activation too.
class AbortReactionsBuff extends Buff:
	var aborted_count := 0
	var seen_count := 0

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action]

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.unit != unit: return false
		seen_count += 1
		return context.action is ActionReaction

	func activate(_core:BuffCore, activation:EventCore) -> void:
		var triggering:EventCore = activation.context.event
		if not is_instance_valid(triggering): return
		triggering.set_aborted()
		aborted_count += 1

var probe:AbortReactionsBuff

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)

	shooter = SpecFactory.create_unit(game.map, SHOOTER_TILE)
	shooter.core.equip_system(RIFLE_ID)
	SpecFactory.apply_passive_buffs(shooter)
	UnitAction.every_new_turn_refresh(shooter)

	# evasion -10 so the overwatch shot cannot miss (the same number, for the same reason, as
	# test_knock_em_down.gd), 200 HP so nothing dies mid-probe, armor 0 so a landed shot always moves
	# current_damage() off zero.
	mover = FitzgeraldFixture.create_dummy(game, MOVER_FROM, -10)

	probe = null

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Attach the probe buff to the shooter. Applied through UnitCondition rather than through a
## PassiveBuffApplicator, because there is no Kit here to hang one off - the same apply_buff_alt +
## BuffCore.create pairing spec/test_spike_symbiosis.gd:65 uses.
func arm_probe() -> void:
	probe = AbortReactionsBuff.new()
	probe.triggers_on.append(&'unit_action')
	probe.trigger_timing = ReactionBus.TIMING.PRE
	probe.hide_from_player = true
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), shooter, BuffCore.create(probe))

## True while the probe buff is genuinely attached. Read off state.buffs, which is the very field
## BuffCore.get_holder_unit walks and the very field ReactionBus.trigger_occurred iterates.
func probe_is_attached() -> bool:
	for core:BuffCore in shooter.state.buffs:
		if core.base == probe: return true
	return false

## Walk the mover past the shooter, which is what offers Overwatch.
func provoke() -> void:
	await SpecFactory.move(game, mover, MOVER_TO)

func overwatch_uses() -> int:
	var gear:GearCore = shooter.get_gear(OVERWATCH_ID)
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_turn()

# ---------------------------------------------------------------- the controls

func test_the_fixture_offers_a_real_reaction_to_abort() -> void:
	# THE CONTROL, and the probe is worthless without it: every assertion in the abort test below
	# would pass just as happily against a fixture that never offered a reaction in the first place.
	assert_eq(shooter.core.current.reactions, 1, 'The shooter starts with its one reaction point.')
	assert_eq(overwatch_uses(), 0, 'And has not overwatched yet.')
	await provoke()
	assert_eq(mover.tile(), MOVER_TO, 'The mover completed its move.')
	assert_gt(mover.current_damage(), 0, 'Overwatch fired and the shot landed.')
	assert_eq(overwatch_uses(), 1, 'The usage counter moved.')
	assert_eq(shooter.core.current.reactions, 0, 'And the reaction point was spent.')

func test_the_probe_buff_is_really_applied_and_really_sees_the_activation() -> void:
	# The second control. An abort that "worked" because the buff was never applied, or because
	# does_buff_trigger never matched the trigger name or the timing, is the exact false pass this
	# file exists to avoid.
	arm_probe()
	assert_true(probe_is_attached(), 'The probe buff is on the shooter.')
	await provoke()
	assert_gt(probe.seen_count, 0, 'The bus polled the buff on a UNIT_ACTION PRE for this unit.')

# ---------------------------------------------------------------- the finding

func test_a_unit_action_pre_buff_aborts_the_reactions_effect() -> void:
	arm_probe()
	await provoke()
	assert_eq(probe.aborted_count, 1, 'The buff marked exactly one activation aborted.')
	assert_eq(mover.tile(), MOVER_TO, 'The mover still completed its move.')
	assert_eq(mover.current_damage(), 0, 'THE FINDING: the overwatch shot never happened.')

func test_the_aborted_reaction_moved_no_usage_counter() -> void:
	# event_gear_activate.gd:100-104 gates the POST - and Scanpedia, and the hidden-clearing - on the
	# usage having actually moved. If the counter moved anyway the refusal would be cosmetic, and the
	# exclusion clause unbuildable as designed.
	arm_probe()
	await provoke()
	assert_eq(overwatch_uses(), 0, 'The reaction is not recorded as used.')

func test_the_aborted_reaction_spent_no_reaction_point() -> void:
	# UnitAction.spend is reached only from Action.spend_actions, inside activate() - which never
	# runs. Asserted separately from the counter because the two are different mechanisms, and a
	# future engine that kept one and lost the other is worth hearing about precisely.
	arm_probe()
	var points_before:int = shooter.core.current.reactions
	await provoke()
	assert_eq(shooter.core.current.reactions, points_before, 'The reaction point is untouched.')

# ---------------------------------------------------------------- the negative

func test_an_ordinary_action_by_the_same_unit_is_untouched() -> void:
	# The same buff, the same unit, the same UNIT_ACTION PRE seam - and a QUICK weapon attack, which
	# triggers_on_event refuses because context.action is not an ActionReaction. Without this the
	# probe would be just as green against a buff that aborted EVERYTHING, which is not a seam
	# Symbiosis can use.
	await SpecFactory.start_turn(game, shooter)
	arm_probe()
	await SpecFactory.use_solo(game, shooter, RIFLE_ID, [mover])
	assert_eq(probe.aborted_count, 0, 'Nothing was aborted.')
	assert_gt(mover.current_damage(), 0, 'The ordinary attack landed.')
