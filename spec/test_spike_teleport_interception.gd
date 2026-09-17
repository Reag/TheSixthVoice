# SPIKE 5 (roadmap §5): can "if the Maiden's Blush would teleport, it instead may become Invisible"
# be expressed - is there a point BEFORE a teleport resolves at which a buff can veto it?
#
# Uncertainty Field (sheet 05-maidens-blush.md): "1/round if the Maiden's Blush would teleport, it
# instead may become Invisible until the beginning of its next turn. It immediately loses Invisible
# if it takes damage."
#
# THIS IS A PROBE, NOT CONTENT. It asserts only against a VANILLA unit and vanilla engine services -
# the Maiden's Blush does not exist yet - so every test here is a characterisation of the 1.4.3
# engine and stays true however the trait is eventually built. Delete it when test_uncertainty_field.gd
# lands in SP1, as test_spike_symbiosis.gd and test_spike_draw_fire.gd were deleted.
#
# WHERE THE SEAM IS. Every teleport in the engine is an event_unit_move whose context.resource is a
# MovementType with teleport = true: the Mourning Cloak's own Blinkspace Jump (action_blinkspace_
# jump.gd:57-58), the Dusk Wing's hologram teleport, the Fold Knife's on_crit (via event_unit_pick_
# move, which ends in the same event), every declarative NPC teleport (ActionSystemMovement with a
# teleporting MovementType), and the map editor's event_unit_teleport (which sets voluntary = false
# and the NO_RXNS flag). event_unit_move.execute fires ENTIRE_MOVEMENT / PRE on the real event core
# BEFORE undergo_move (event_unit_move.gd:71), and the very next line honours an abort set by a PRE
# listener (:72, abort_without_unit -> abort_when -> event_core.gd:26-29 returns the EXISTING flag).
# Flash Anchor (action_flash_lock.gd) and Thy Hubris' Dig In (action_dig_in.gd:101) both veto a move
# from a REACTION there; this probe asks whether a BUFF can do the same for a TELEPORT, and whether
# the listener can tell a teleport from a walk, read the destination, and fire the replacement effect.
#
# The listener is an in-memory Buff (the CountingProbe technique from the M/K2 spike,
# test_spike_mk2_reaction_timing.gd) applied with UnitCondition.apply_buff_alt + BuffCore.create,
# so a NO here costs nothing to act on and no content has to be unpicked.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_teleport_interception.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const START := Vector2i(2, 2)
const DESTINATION := Vector2i(5, 2)

var game:Gamemaster
var unit:Unit
var probe:TeleportProbe

## How many times a deferred pathfinder spend ran; see test_the_veto_skips_the_deferred_spend.
var spend_calls:int = 0

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	unit = SpecFactory.create_unit(game.map, START)
	unit.core.full_repair()
	probe = null
	spend_calls = 0

## THE PROBE BUFF. ENTIRE_MOVEMENT / PRE, for its holder's own moves only. triggers_on_event is the
## teleport filter - a walk is counted and refused, a teleport is accepted - and activate() is where
## a real Uncertainty Field would prompt, veto and apply Invisible. Both halves are switchable so
## the same buff serves as its own control.
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive to be asked about the next move too.
class TeleportProbe extends Buff:
	var heard_teleports:int = 0
	var heard_walks:int = 0
	var veto:bool = false
	var become_invisible:bool = false
	var last_destination:Vector2i = Tile.INVALID
	var last_voluntary:bool = false
	var last_flags:Array = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ENTIRE_MOVEMENT]
		trigger_timing = ReactionBus.TIMING.PRE
		to = Buff.TO.NONE
		hide_from_player = true
		until = Lancer.UNTIL.MANUAL

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]

	func triggers_on_event(_core:BuffCore, holder:Unit, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if context.unit != holder: return false
		if not MovementType.is_valid(context.resource): return false
		if not context.resource.teleport:
			heard_walks += 1
			return false
		return true

	func activate(_core:BuffCore, activation:EventCore) -> void:
		heard_teleports += 1
		var triggering:EventCore = activation.context.event
		if not is_instance_valid(triggering): return
		var context:Context = triggering.context
		last_voluntary = context.resource.voluntary
		last_flags = context.flags.duplicate()
		last_destination = read_destination(context)
		if veto: triggering.set_aborted()
		if become_invisible:
			UnitCondition.apply_status(activation, activation.context.unit, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN)

	## A move arrives with EITHER a full path (array of Pathfinder.Step, from Pathfinder.generate_
	## events) OR a single target tile (event_unit_teleport, SpecFactory.move). A prompt that wants
	## to show where the teleport was going has to read both shapes.
	static func read_destination(context:Context) -> Vector2i:
		if not context.target_tiles.is_empty(): return context.target_tiles.front()
		if not context.array.is_empty() and context.array.back() is Pathfinder.Step: return context.array.back().tile
		return Tile.INVALID

func arm_probe(veto:bool, become_invisible:bool = false) -> void:
	probe = TeleportProbe.new()
	probe.veto = veto
	probe.become_invisible = become_invisible
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(probe))

## True while the probe buff is genuinely attached - read off state.buffs, the very field
## ReactionBus.trigger_occurred iterates.
func probe_is_attached() -> bool:
	for core:BuffCore in unit.state.buffs:
		if core.base == probe: return true
	return false

func teleport_type(voluntary:bool = true) -> MovementType:
	var type := MovementType.create(unit, voluntary)
	type.teleport = true
	return type

## Run one event_unit_move and hand back its core, so the test can read `aborted`. game.execute_event
## would do the same job but returns nothing.
func run_move(event_data:Dictionary) -> EventCore:
	var core := EventCore.create(&'event_unit_move', event_data)
	await game.execute_event_block(EventBlock.create_multiple([core]))
	return core

## THE BLINKSPACE JUMP SHAPE: a pathfinder over given tiles with a teleporting MovementType, then
## the pathfinder's own event (context.array = the path, one Step for a teleport). Every player-side
## teleport in vanilla is built this way.
func teleport_by_path(to:Vector2i) -> EventCore:
	var pathfinder:Pathfinder = await Pathfinder.generate_for_given_tiles(unit, [to], teleport_type())
	var events:Array[EventCore] = pathfinder.generate_events(unit, pathfinder.path_to(to))
	assert_eq(events.size(), 1, 'The pathfinder produced exactly one move event.')
	if events.is_empty(): return null
	await game.execute_event_block(EventBlock.create_multiple(events))
	return events[0]

## THE SCRIPTED SHAPE: event_unit_teleport's own body (content/events/event_unit_teleport.gd:26-38) -
## a target tile, an INVOLUNTARY teleporting MovementType, the NO_RXNS flag. What a mission script
## or a hostile "you are teleported" effect looks like from the inside.
func teleport_by_target_tile(to:Vector2i) -> EventCore:
	var type := teleport_type(false)
	type.ignore_engagement = true
	type.ignore_rxns = true
	return await run_move({
		unit = unit,
		target_tiles = [to],
		resource = type,
		flags = [EventUnitMove.FLAG.NO_RXNS],
	})


# ================================ A. CONTROLS ================================

func test_a_teleport_by_path_lands_without_the_probe() -> void:
	# THE CONTROL for the finding: the veto test below would pass just as happily against a fixture
	# whose teleports never went anywhere.
	var core := await teleport_by_path(DESTINATION)
	assert_eq(unit.tile(), DESTINATION, 'The teleport landed.')
	assert_false(core.aborted, 'And the move event completed.')
	assert_eq(unit.state.spaces_moved_this_turn, 1, 'A teleport is one step, however far it goes.')

func test_a_teleport_by_target_tile_lands_without_the_probe() -> void:
	var core := await teleport_by_target_tile(DESTINATION)
	assert_eq(unit.tile(), DESTINATION, 'The scripted teleport landed.')
	assert_false(core.aborted, 'And the move event completed.')

func test_the_probe_is_attached_and_hears_a_teleport_at_pre() -> void:
	# The second control: a veto that "worked" because the buff was never applied, or because the
	# bus never matched the trigger or the timing, is the exact false pass this file exists to avoid.
	arm_probe(false)
	assert_true(probe_is_attached(), 'The probe buff is on the unit.')
	await teleport_by_path(DESTINATION)
	assert_eq(probe.heard_teleports, 1, 'ENTIRE_MOVEMENT PRE reached the buff once, for the teleport.')
	assert_eq(unit.tile(), DESTINATION, 'A listener that does not veto leaves the teleport alone.')
	assert_true(probe.last_voluntary, 'A Blinkspace-shaped teleport is voluntary.')
	assert_eq(probe.last_destination, DESTINATION,
		'At PRE the destination is already chosen and readable: a prompt can say where the mech was going.')

func test_the_probe_ignores_an_ordinary_move() -> void:
	# The filter is the listener's own: the bus offers EVERY move at PRE and it is
	# context.resource.teleport that tells them apart. A walk must not be mistaken for a teleport.
	arm_probe(true) # armed to veto - a misfire here would strand the unit at START
	await SpecFactory.move(game, unit, DESTINATION)
	assert_eq(probe.heard_teleports, 0, 'A walk is not a teleport.')
	assert_gt(probe.heard_walks, 0, 'But the PRE did fire for it - the bus does not filter on movement type.')
	assert_eq(unit.tile(), DESTINATION, 'And the walk completed.')


# ================================ B. THE FINDING ================================

func test_an_entire_movement_pre_buff_vetoes_a_teleport() -> void:
	arm_probe(true)
	var core := await teleport_by_path(DESTINATION)
	assert_eq(probe.heard_teleports, 1, 'The buff saw exactly one teleport.')
	assert_eq(unit.tile(), START, 'THE FINDING: the teleport never happened.')
	assert_true(core.aborted, 'The move event reads aborted (event_unit_move.gd:72 pulled the cord).')
	assert_eq(unit.state.spaces_moved_this_turn, 0, 'Nothing was recorded as moved.')

func test_the_veto_reaches_a_scripted_involuntary_teleport_too() -> void:
	# The engine does NOT honour NO_RXNS or involuntariness for us - "not enforced; reactions need
	# to decide for themselves" (event_unit_move.gd:26). So a mission-script teleport, or a hostile
	# effect that teleports the mech, reaches the listener exactly like its own Blinkspace Jump, and
	# BOTH facts it would need to decide on are readable from the context. Whether Uncertainty
	# Field should fire on such a teleport is the design's call; the probe shows it CAN, and that it
	# can tell.
	arm_probe(true)
	var core := await teleport_by_target_tile(DESTINATION)
	assert_eq(probe.heard_teleports, 1, 'The scripted teleport reached the buff.')
	assert_eq(unit.tile(), START, 'And was vetoed.')
	assert_true(core.aborted, 'The move event reads aborted.')
	assert_false(probe.last_voluntary, 'The listener could see it was involuntary...')
	assert_true(probe.last_flags.has(EventUnitMove.FLAG.NO_RXNS), '...and that it asked not to be reacted to.')
	assert_eq(probe.last_destination, DESTINATION, 'The target-tile shape exposes its destination too.')

func test_the_veto_skips_the_deferred_spend() -> void:
	# Pathfinder.generate_events attaches a deferred_spend callable to every move it builds (the
	# variant-action spend, e.g. a Lunge), and event_unit_move only calls it AFTER the PRE and the
	# abort check (:74-77). So whatever a teleport was going to spend through its pathfinder is
	# never spent when the PRE vetoes it. NOTE WHAT THIS DOES NOT COVER: an action's own
	# spend_actions() runs before it queues the move (action_blinkspace_jump.gd:48) - a vetoed core
	# power stays spent. That is the design's problem to rule on, and it is recorded in the doc.
	var spend := func(_core:EventCore) -> void: spend_calls += 1

	var core := await run_move({unit = unit, target_tiles = [DESTINATION], resource = teleport_type(), deferred_spend = spend})
	assert_false(core.aborted, 'Control: the un-vetoed teleport ran.')
	assert_eq(spend_calls, 1, 'Control: the deferred spend ran once for it.')

	# The second teleport starts wherever the first landed and heads back; no reset needed.
	arm_probe(true)
	spend_calls = 0
	var origin := unit.tile()
	var vetoed := await run_move({unit = unit, target_tiles = [START], resource = teleport_type(), deferred_spend = spend})
	assert_true(vetoed.aborted, 'The second teleport was vetoed...')
	assert_eq(unit.tile(), origin, '...and went nowhere...')
	assert_eq(spend_calls, 0, '...and its deferred spend never ran.')

func test_the_replacement_effect_fires_from_the_same_hook() -> void:
	# "it instead may become Invisible": the same activate() that vetoes can apply the status, in
	# the same event, with no second hook needed.
	arm_probe(true, true)
	assert_false(unit.has_status(Lancer.STATUS.INVISIBLE), 'Not invisible to begin with.')
	await teleport_by_path(DESTINATION)
	assert_eq(unit.tile(), START, 'Vetoed.')
	assert_true(unit.has_status(Lancer.STATUS.INVISIBLE), 'And Invisible instead.')

func test_invisible_until_start_of_turn_clears_at_the_units_next_turn_start() -> void:
	# "until the beginning of its next turn" is Lancer.UNTIL.START_OF_TURN, which the turn-start
	# handler clears (unit_condition.gd:21). Characterised here so the design can name it without
	# a second probe.
	SpecFactory.apply(unit, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN)
	assert_true(unit.has_status(Lancer.STATUS.INVISIBLE), 'Applied.')
	await SpecFactory.start_turn(game, unit)
	assert_false(unit.has_status(Lancer.STATUS.INVISIBLE), 'Gone at the start of the next turn.')
