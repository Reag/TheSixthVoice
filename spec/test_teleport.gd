# The TELEPORT helper (Maiden's Blush SP1 Task 1), born with Uncertainty Field and frozen in two
# halves: the observe/intercept half here, the perform half in SP2 (design §2.4).
#
# Roadmap §4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Five later frames consume
# this one - Purple Thorn, Leoleth (ZIP), Sluagh (Hunt), Koremasa (Vanish), Six Sky - so a rename
# here is five frames' worth of churn. test_the_frozen_interface_pins_these_six_signatures is the
# guard, and it pins the whole signature - argument order, names, types, default count and return
# type - not only that a name survives.
#
# WHAT THE HELPER IS FOR. Every teleport in the engine is ONE event_unit_move whose context.resource
# is a MovementType with teleport = true, and nothing filters on that for you: the bus offers EVERY
# move at ENTIRE_MOVEMENT and the listener decides (spike 5, 2026-09-17). Four facts a listener needs
# - is this a teleport, where is it going, who forced it, and can I stop it - were each re-derived in
# the spike probe and would have been re-derived per frame. They are written once here.
#
# THIS FILE ASSERTS AGAINST VANILLA UNITS ONLY. The Maiden's Blush does not exist yet at this task,
# and the helper is frame-agnostic by construction; test_uncertainty_field.gd is what exercises it
# from inside a real reaction.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_teleport.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

const START := Vector2i(2, 2)
const DESTINATION := Vector2i(5, 2)
const ELSEWHERE := Vector2i(7, 2)

# The frozen contract itself (roadmap §4, design §1.4). Read off Script.get_script_method_list()'s own
# dictionary shape (Godot 4.7): each entry is {name, args, default_args, flags, id, return}; each arg
# and the return are property-info dicts {name, class_name, type, hint, hint_string, usage}. `type` is
# a Variant.Type - TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I, TYPE_OBJECT - and for a TYPE_OBJECT
# argument or return, `class_name` carries the script's class as a StringName (&'Unit', &'Context');
# for every other type it is the empty StringName &''. The named constants are used rather than the
# integers, so this file does not have to hard-code Godot's enum ordering.
#
# `defaults` is pinned PER FUNCTION, unlike test_overshield.gd's blanket zero: movement_type() really
# does take one default argument (own_involuntary), and it is part of the contract that it does - a
# caller writing Teleport.movement_type(unit) is the common case and the five later frames all use it.
const FROZEN_SIGNATURES := {
	is_teleport = {
		args = [['context', TYPE_OBJECT, &'Context']],
		defaults = 0, return_type = TYPE_BOOL, return_class = &'',
	},
	destination = {
		args = [['context', TYPE_OBJECT, &'Context']],
		defaults = 0, return_type = TYPE_VECTOR2I, return_class = &'',
	},
	forcer = {
		args = [['context', TYPE_OBJECT, &'Context']],
		defaults = 0, return_type = TYPE_OBJECT, return_class = &'Unit',
	},
	movement_type = {
		args = [['unit', TYPE_OBJECT, &'Unit'], ['own_involuntary', TYPE_BOOL, &'']],
		defaults = 1, return_type = TYPE_OBJECT, return_class = &'MovementType',
	},
	is_own = {
		args = [['movement_type', TYPE_OBJECT, &'MovementType']],
		defaults = 0, return_type = TYPE_BOOL, return_class = &'',
	},
	veto = {
		args = [['triggering', TYPE_OBJECT, &'EventCore']],
		defaults = 0, return_type = TYPE_NIL, return_class = &'',
	},
}

var game:Gamemaster
var unit:Unit
var forcing_unit:Unit

## THE VETO LISTENER, for test_veto_stops_a_real_teleport only. ENTIRE_MOVEMENT / PRE on its holder's
## own moves, and its activate() does nothing but call the helper - which is the point: the assertion
## is about Teleport.veto, not about a hand-written set_aborted().
##
## Does NOT call super() in activate(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive to be asked about the next move too.
class VetoListener extends Buff:
	var heard:int = 0

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
		return Teleport.is_teleport(context)

	func activate(_core:BuffCore, activation:EventCore) -> void:
		heard += 1
		Teleport.veto(activation.context.event)

var listener:VetoListener

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	unit = SpecFactory.create_unit(game.map, START)
	unit.core.full_repair()
	forcing_unit = FitzgeraldFixture.create_dummy(game, ELSEWHERE, 10)
	listener = null

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

## A context shaped like the one event_unit_move hands a PRE listener for a target-tile move.
## Hand-built rather than executed, so the reader tests below cost no event.
func tile_context(type:MovementType, tile:Vector2i = DESTINATION, source = null) -> Context:
	return Context.create({unit = unit, target_tiles = [tile], resource = type, object = source})

## The other shape: a pathfinder path, whose last Step carries the destination.
func path_context(type:MovementType, tile:Vector2i = DESTINATION) -> Context:
	var path:Array[Pathfinder.Step] = [Pathfinder.Step.create(tile, 1)]
	return Context.create({unit = unit, array = path, resource = type})

## Run one event_unit_move and hand back its core, so a test can read `aborted`. game.execute_event
## would do the same job but returns nothing. The spike probe's helper, verbatim.
func run_move(event_data:Dictionary) -> EventCore:
	var core := EventCore.create(&'event_unit_move', event_data)
	await game.execute_event_block(EventBlock.create_multiple([core]))
	return core

func arm_listener() -> void:
	listener = VetoListener.new()
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(listener))

# ---------------------------------------------------------------- the interface itself

func test_the_frozen_interface_pins_these_six_signatures():
	# Roadmap §4 freezes this list when SP1 ships. This pins the FULL signature of each of the six -
	# argument count, each argument's name and order, each argument's type, the default-argument
	# count, and the return type - not only that the name survives. A rename, a reordered parameter,
	# a changed type or a silently-grown default is five later frames' worth of churn, and nothing
	# else in the suite would notice any of them until those frames are written.
	#
	# Deliberately does NOT fail if a SEVENTH function is added: SP2 adds five (design §2.4), and the
	# whole freeze contract is "additions allowed, reshapes not".
	#
	# Through a Script-typed local, not Teleport.get_script_method_list() directly: GDScript reads a
	# preloaded script constant as a CLASS in a call position and refuses the call at parse time.
	var script:Script = Teleport
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'Teleport.%s survives.' % required)
		if not by_name.has(required): continue

		var entry:Dictionary = by_name[required]
		var expected:Dictionary = FROZEN_SIGNATURES[required]
		var expected_args:Array = expected.args

		assert_eq(entry.args.size(), expected_args.size(),
			'%s takes exactly %d argument(s).' % [required, expected_args.size()])
		for i:int in range(min(entry.args.size(), expected_args.size())):
			var actual_arg:Dictionary = entry.args[i]
			var expected_arg:Array = expected_args[i]
			assert_eq(actual_arg.name, expected_arg[0],
				'%s arg %d is named "%s".' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.type, expected_arg[1],
				'%s arg %d ("%s") has the frozen Variant.Type.' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.class_name, expected_arg[2],
				'%s arg %d ("%s") has the frozen class_name.' % [required, i, expected_arg[0]])

		# PINS `static`, NOT ONLY THE NAME (the Myconid frame close, finding 4, 2026-09-16). Every
		# caller spells Teleport.<fn>(...) on the preloaded script CONSTANT, never on an instance, and
		# GDScript refuses that at PARSE time if `static` is dropped - which is this whole file AND
		# test_uncertainty_field.gd going unparsable, with GUT logging 'Ignoring script ...' and
		# dropping both from the totals rather than failing them. What catches THAT is the
		# ignored-scripts / test-count check the suite is read with; this assertion is for the case
		# that still parses, a future session converting the helper to instance methods and updating
		# its callers to match. A bitwise AND against the single bit, as addons/gut/script_parser.gd
		# tests it, so an unrelated future flag cannot fail this.
		assert_true((entry.flags & METHOD_FLAG_STATIC) != 0,
			'%s is still static - a caller spells it on the class, not an instance.' % required)
		assert_eq(entry.default_args.size(), expected.defaults,
			'%s takes exactly %d default argument(s).' % [required, expected.defaults])

		assert_eq(entry.return.type, expected.return_type,
			'%s has the frozen return Variant.Type.' % required)
		assert_eq(entry.return.class_name, expected.return_class,
			'%s has the frozen return class_name.' % required)

# ---------------------------------------------------------------- is_teleport

func test_is_teleport_is_true_for_a_teleporting_move_context():
	assert_true(Teleport.is_teleport(tile_context(Teleport.movement_type(unit))),
		'A teleporting MovementType reads as a teleport.')

func test_is_teleport_is_false_for_a_walk():
	# THE DISCRIMINATING HALF. The bus offers EVERY move at ENTIRE_MOVEMENT and filters on nothing -
	# a helper that answered true for a walk would make every listener fire on every step.
	assert_false(Teleport.is_teleport(tile_context(MovementType.create(unit))),
		'An ordinary move is not a teleport.')

func test_is_teleport_is_false_when_the_context_carries_no_movement_type():
	# context.resource is OPTIONAL on event_unit_move (event_unit_move.gd:52), and :68 falls back to
	# MovementType.create(unit) when it is absent - so a listener really can be handed a context with
	# no resource, and must not throw on one.
	assert_false(Teleport.is_teleport(Context.create({unit = unit, target_tiles = [DESTINATION]})),
		'No movement type is not a teleport.')
	assert_false(Teleport.is_teleport(null), 'And a null context is not a teleport either.')

# ---------------------------------------------------------------- destination

func test_destination_reads_a_target_tile_move():
	assert_eq(Teleport.destination(tile_context(Teleport.movement_type(unit))), DESTINATION,
		'The target-tile shape exposes its destination.')

func test_destination_reads_a_pathfinder_path():
	# The Blinkspace shape: Pathfinder.generate_events puts the path in context.array as
	# Pathfinder.Step objects (pathfinder.gd:908-916), one Step for a teleport.
	assert_eq(Teleport.destination(path_context(Teleport.movement_type(unit))), DESTINATION,
		'The pathfinder-path shape exposes its destination too.')

func test_destination_is_invalid_when_the_context_carries_neither():
	assert_eq(Teleport.destination(Context.create({unit = unit})), Tile.INVALID,
		'Neither shape present reads as Tile.INVALID, not as (0, 0).')
	assert_eq(Teleport.destination(null), Tile.INVALID, 'And so does a null context.')

# ---------------------------------------------------------------- forcer

func test_forcer_reads_the_specific_action_that_caused_the_move():
	# Flash Anchor's read (action_flash_lock.gd:43-48): for an event_unit_move the source is
	# context.object as a SpecificAction. Built with NULL gear and NULL action on purpose - that is
	# exactly what EventUnitMove itself builds for a katamari passenger's mover
	# (event_unit_move.gd:318), and it is why the helper validates with has_valid_unit rather than
	# is_valid. A helper using is_valid would return null here and the whole hostile-forced-teleport
	# clause of Uncertainty Field would go silent.
	var source := SpecificAction.create(forcing_unit, null, null)
	var context := tile_context(Teleport.movement_type(unit), DESTINATION, source)
	assert_eq(Teleport.forcer(context), forcing_unit, 'The forcing unit is readable.')

func test_forcer_is_null_when_the_move_carries_no_source():
	# The NORMAL answer for a player's own teleport: Blinkspace Jump passes no specific to
	# generate_events (action_blinkspace_jump.gd:64) and event_unit_teleport sets no `object` at all.
	# A caller must read null as "nobody readable", never as "me".
	assert_null(Teleport.forcer(tile_context(Teleport.movement_type(unit))),
		'No source reads as no forcer.')
	assert_null(Teleport.forcer(null), 'And so does a null context.')

# ---------------------------------------------------------------- movement_type and is_own

func test_movement_type_is_a_voluntary_untagged_teleport_by_default():
	# The Blinkspace shape, and it is PREVENTABLE on purpose: both Immobilized gates test
	# movement_type.voluntary (pathfinder.gd:333 and event_unit_move.gd:451), and Pathfinder.create is
	# also where every MOVEMENT_RESTRICTION ban lands. Abjuration of Metal (SP2) wants exactly this.
	var type := Teleport.movement_type(unit)
	assert_true(MovementType.is_valid(type), 'It is a MovementType.')
	assert_true(type.teleport, 'It teleports.')
	assert_true(type.voluntary, 'It is voluntary.')
	assert_false(Teleport.is_own(type), 'And it is NOT tagged as our own - a voluntary one needs no tag.')

func test_movement_type_own_involuntary_is_involuntary_ignores_engagement_and_is_tagged():
	# The "this teleportation cannot be prevented" shape (design §0.8): vanilla's own
	# event_unit_teleport type (event_unit_teleport.gd:26-29) MINUS the NO_RXNS flag, plus the tag.
	var type := Teleport.movement_type(unit, true)
	assert_true(type.teleport, 'It teleports.')
	assert_false(type.voluntary, 'It is involuntary - which is what beats the two Immobilized gates.')
	assert_true(type.ignore_engagement, 'It ignores engagement, as vanilla\'s involuntary teleport does.')
	assert_false(type.ignore_rxns,
		'But it does NOT ignore reactions: Uncertainty Field has to be offered on it.')
	assert_true(Teleport.is_own(type), 'And is_own reads the tag back.')

func test_is_own_is_false_for_every_movement_type_we_did_not_tag():
	# The whole point of the tag is telling OUR unpreventable Step from a HOSTILE shove, and both are
	# involuntary - so "involuntary" alone must not read as ours.
	assert_false(Teleport.is_own(MovementType.create(unit)), 'An ordinary voluntary move is not ours.')
	assert_false(Teleport.is_own(MovementType.create(unit, false)), 'Nor is a plain involuntary one.')
	assert_false(Teleport.is_own(MovementType.create_for_involuntary(unit)),
		'Nor is the engine\'s own create_for_involuntary, which is what a knockback uses.')
	assert_false(Teleport.is_own(null), 'And null is not ours.')

# ---------------------------------------------------------------- veto

func test_veto_stops_a_real_teleport():
	# The spike's finding, re-pinned against the helper rather than against a hand-written
	# set_aborted(). The two controls come first, because "the unit is still at START" is also what a
	# fixture whose teleports never worked would report.
	var control := await run_move({
		unit = unit, target_tiles = [DESTINATION], resource = Teleport.movement_type(unit),
	})
	assert_eq(unit.tile(), DESTINATION, 'CONTROL: an un-vetoed teleport lands.')
	assert_false(control.aborted, 'CONTROL: and its move core completed.')

	arm_listener()
	var origin := unit.tile()
	var vetoed := await run_move({
		unit = unit, target_tiles = [START], resource = Teleport.movement_type(unit),
	})
	assert_eq(listener.heard, 1, 'The listener saw exactly one teleport.')
	assert_eq(unit.tile(), origin, 'THE FINDING: the teleport never happened.')
	assert_true(vetoed.aborted, 'The move core reads aborted (event_unit_move.gd:72 pulled the cord).')
	assert_eq(unit.state.spaces_moved_this_turn, 1,
		'And nothing further was recorded as moved - only the control move counts.')
