# SPIKE PROBE, TEMPORARY - deleted in SP1 Task 1 once spec/test_rapid_stabilization_jets.gd covers
# the same ground against the real content. It answers the two questions design §1.1 flags as
# "two pieces to prove first", before any M/K2 content is wired.
#
# WHY IT IS WORTH A RUN OF ITS OWN. Rapid Stabilization Jets keeps unit.state.is_firing_ordnance
# open for a turn by re-asserting it from a BUFF reaction after every action and every move. Nothing
# in vanilla does that: no vanilla buff subscribes to ENTIRE_MOVEMENT at all. reaction_bus.gd:59-65
# polls every unit's state.buffs on every trigger, so the mechanism exists - what is unmeasured is
# whether these two triggers actually reach a buff rather than only a gear reaction.
#
# It builds its subject IN MEMORY (an inner class extending Buff, applied with
# UnitCondition.apply_buff) rather than from a .tres, so a NO here costs nothing to act on and no
# content has to be unpicked. The technique is lifted from spec/test_ripper_mod.gd:228-271
# (GrantApToEverything).
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_mk2_reaction_timing.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const START := Vector2i(2, 2)
const DESTINATION := Vector2i(4, 2)

var game:Gamemaster
var unit:Unit

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	unit = SpecFactory.create_unit(game.map, START)
	unit.core.full_repair()

## A buff that only counts. triggers_on is set by the caller, per question.
##
## activate() deliberately does NOT call super(): Buff.activate's default body (buff.gd:254-255)
## clears the buff from the unit, which would make every question look like "heard exactly once"
## whatever the truth was.
class CountingProbe extends Buff:
	var heard:int = 0
	func _init(listen_to:Array[StringName]) -> void:
		triggers_on = listen_to
		trigger_timing = ReactionBus.TIMING.POST
		to = Buff.TO.NONE
		hide_from_player = true
		until = Lancer.UNTIL.MANUAL
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]
	func triggers_on_event(_core:BuffCore, listening_unit:Unit, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == listening_unit
	func activate(_core:BuffCore, _activation:EventCore) -> void:
		heard += 1

func apply_probe(listen_to:Array[StringName]) -> CountingProbe:
	var probe := CountingProbe.new(listen_to)
	UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, probe)
	return probe

# ---------------------------------------------------------------- question A: movement

func test_a_buff_hears_entire_movement_post() -> void:
	var probe := apply_probe([ReactionBus.TRIGGER.ENTIRE_MOVEMENT])
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.move(game, unit, DESTINATION)
	gut.p('  ENTIRE_MOVEMENT heard: %d' % probe.heard)
	assert_gt(probe.heard, 0, 'ENTIRE_MOVEMENT POST reached a buff.')

func test_a_buff_hears_step_post() -> void:
	# The FALLBACK the design names (event_unit_move.gd:285), measured in the same run so the verdict
	# is a comparison rather than a guess.
	var probe := apply_probe([ReactionBus.TRIGGER.STEP])
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.move(game, unit, DESTINATION)
	gut.p('  STEP heard: %d' % probe.heard)
	assert_gt(probe.heard, 0, 'STEP POST reached a buff.')

# ---------------------------------------------------------------- question B: a later action

func test_an_aborted_activation_fires_no_unit_action_post() -> void:
	# MEASURED BY ACCIDENT AND KEPT ON PURPOSE. This started life as the Stabilize case for question
	# B and came back 0 - because Stabilize asks the player to choose between cooling and repairing,
	# nothing in this probe answers that prompt, and the activation ABORTS: the run log reads
	# "[ event_gear_activate FIN ] (aborted)".
	#
	# That is correct engine behaviour, not a hole. event_gear_activate.gd:96-101 gates the POST on
	# the gear's ROUND usage counter having actually moved, and an aborted activation never spends
	# anything - so an attack the player backs out of neither charges Hybridized Shot's once-per-turn
	# nor costs Hypercharge's 1d3 heat. Both of those rulings (design §0.7, §1.2) rest on this line,
	# and until now nothing measured it.
	var probe := apply_probe([ReactionBus.TRIGGER.UNIT_ACTION])
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.use_solo(game, unit, &'ms_stabilize') # aborts at its unanswered prompt
	gut.p('  UNIT_ACTION heard (aborted stabilize): %d' % probe.heard)
	assert_eq(probe.heard, 0, 'An aborted activation fires no UNIT_ACTION POST.')

func test_a_buff_hears_unit_action_post_from_a_weapon() -> void:
	# The same question asked of an ordinary weapon activation, because the gate on that POST is
	# "the gear's ROUND usage counter moved" (event_gear_activate.gd:96-101) and it is not obvious
	# that every universal action moves one.
	var target := FitzgeraldFixture.create_dummy(game, Vector2i(7, 2), -10)
	var weapon:GearCore = unit.core.equip_system(&'mw_assault_rifle')
	SpecFactory.apply_passive_buffs(unit)
	var probe := apply_probe([ReactionBus.TRIGGER.UNIT_ACTION])
	await SpecFactory.start_turn(game, unit)
	Dice.cheat_attack([19], [3, 3, 3, 3, 3, 3, 3, 3])
	await game.execute_event(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = unit, target_unit = target,
	})
	gut.p('  UNIT_ACTION heard (rifle): %d' % probe.heard)
	assert_gt(probe.heard, 0, 'UNIT_ACTION POST reached a buff when a weapon was fired.')

func test_a_buff_hears_unit_action_post_from_a_boost() -> void:
	var probe := apply_probe([ReactionBus.TRIGGER.UNIT_ACTION])
	await SpecFactory.start_turn(game, unit)
	await SpecFactory.use_solo(game, unit, &'ms_boost')
	gut.p('  UNIT_ACTION heard (boost): %d' % probe.heard)
	assert_gt(probe.heard, 0, 'UNIT_ACTION POST reached a buff when the unit boosted.')
