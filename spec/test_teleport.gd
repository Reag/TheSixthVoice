# The TELEPORT helper (Maiden's Blush SP1 Task 1), born with Uncertainty Field and frozen in two
# halves: the observe/intercept half here, the perform half in SP2 (design §2.4).
#
# Roadmap §4: a shared helper is born with its first consumer, in its own sub-folder, with its own
# specs, and its interface is frozen the moment that sub-project ships. Five later frames consume
# this one - Purple Thorn, Leoleth (ZIP), Sluagh (Hunt), Koremasa (Vanish), Six Sky - so a rename
# here is five frames' worth of churn. test_the_frozen_interface_pins_these_eleven_signatures is the
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
#
# `hint` PINS THE ELEMENT TYPE OF A TYPED ARRAY (Important 3, SP1 slice-1 close review), where `type`
# and `class_name` alone cannot: Array[Vector2i] and a bare Array both report TYPE_ARRAY and an empty
# class_name, because the element type lives in `hint`/`hint_string` instead. Three entries carry one -
# candidate_tiles' return and the `tiles` argument of pathfinder and pick_tile - marked below with an
# optional 4th array element (for an argument) or a `return_hint` key (for a return). Pinned against
# PROPERTY_HINT_ARRAY_TYPE alone, never hint_string: the engine sets that enum for every typed array
# regardless of element type, where hint_string's exact spelling for Array[Vector2i] is not something
# this file can read back without a live run.
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

	# ---- THE PERFORM HALF (SP2, design §2.4), frozen with the six above ----
	# Two of these carry a parameter that SHADOWS something: candidate_tiles' `range` shadows
	# GDScript's built-in range(), and move_along's `pathfinder` shadows the sibling function of that
	# name. Both names are the design's and are pinned here, so neither can be quietly renamed to
	# make a future body tidier - the consumers are five later frames.
	candidate_tiles = {
		args = [
			['unit', TYPE_OBJECT, &'Unit'],
			['range', TYPE_INT, &''],
			['require_line_of_sight', TYPE_BOOL, &''],
			['keep', TYPE_CALLABLE, &''],
		],
		defaults = 1, return_type = TYPE_ARRAY, return_class = &'',
		return_hint = PROPERTY_HINT_ARRAY_TYPE,
	},
	pathfinder = {
		args = [['unit', TYPE_OBJECT, &'Unit'], ['tiles', TYPE_ARRAY, &'', PROPERTY_HINT_ARRAY_TYPE]],
		defaults = 0, return_type = TYPE_OBJECT, return_class = &'Pathfinder',
	},
	pick_tile = {
		args = [
			['context', TYPE_OBJECT, &'Context'],
			['activation', TYPE_OBJECT, &'EventCore'],
			['tiles', TYPE_ARRAY, &'', PROPERTY_HINT_ARRAY_TYPE],
		],
		defaults = 0, return_type = TYPE_VECTOR2I, return_class = &'',
	},
	move = {
		args = [
			['activation', TYPE_OBJECT, &'EventCore'],
			['unit', TYPE_OBJECT, &'Unit'],
			['tile', TYPE_VECTOR2I, &''],
			['own_involuntary', TYPE_BOOL, &''],
		],
		defaults = 1, return_type = TYPE_OBJECT, return_class = &'EventCore',
	},
	move_along = {
		args = [
			['activation', TYPE_OBJECT, &'EventCore'],
			['unit', TYPE_OBJECT, &'Unit'],
			['pathfinder', TYPE_OBJECT, &'Pathfinder'],
			['plan', TYPE_OBJECT, &'CompconPlan'],
		],
		defaults = 0, return_type = TYPE_OBJECT, return_class = &'EventCore',
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

## Hang a movement-type buff on `unit` whose merged resource is VOLUNTARY - the one shape that can
## un-harden an own-involuntary teleport. BuffMovementType is vanilla's own archetype for this
## (buff_ramjet_movement_type.tres is one of seventeen `to = &"movement_type"` resources in content/),
## and its get_values hands the resource straight back (buff_movement_type.gd:10-11), which is what
## MovementType.create merges at movement_type.gd:51.
##
## free_climb rides along as the MERGE'S OWN WITNESS. Nothing in Teleport reads or writes it, so
## reading it back true proves the buff really reached create() - without it, a helper that had somehow
## stopped merging buffs at all would make the voluntary assertion below green for the wrong reason.
func apply_a_voluntary_movement_type_buff() -> void:
	var buffed := MovementType.new()
	buffed.voluntary = true
	buffed.free_climb = true
	var buff := BuffMovementType.new()
	buff.movement_type = buffed
	buff.to = Buff.TO.MOVEMENT_TYPE
	buff.hide_from_player = true
	buff.until = Lancer.UNTIL.MANUAL
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(buff))

## Hang a movement-type buff on `unit` whose merged resource's other_tags ALREADY carries
## Teleport.OWN_TAG - carried item 1 (SP1 slice-1 close review): merge_in propagates other_tags
## wholesale (movement_type.gd:96), so a buff resource that happens to carry our tag in ITS OWN
## other_tags would smuggle it into the merge the same way apply_a_voluntary_movement_type_buff()
## above smuggles in `voluntary`. Nothing writes this string but Teleport itself (grep across
## engine/, content/, ui/, addons/ and unpacked/ finds exactly two other_tags sites, both the
## Breacher's Follower Count, and neither touches this key), so this is a hand-built adversarial
## case, not a reachable one.
func apply_a_movement_type_buff_carrying_our_tag() -> void:
	var buffed := MovementType.new()
	buffed.other_tags = [Teleport.OWN_TAG] as Array[StringName]
	var buff := BuffMovementType.new()
	buff.movement_type = buffed
	buff.to = Buff.TO.MOVEMENT_TYPE
	buff.hide_from_player = true
	buff.until = Lancer.UNTIL.MANUAL
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(buff))

# ---------------------------------------------------------------- the interface itself

func test_the_frozen_interface_pins_these_eleven_signatures():
	# Roadmap §4 freezes the first six when SP1 ships and the last five when SP2 does. This pins the
	# FULL signature of each of the eleven -
	# argument count, each argument's name and order, each argument's type, the default-argument
	# count, and the return type - not only that the name survives. A rename, a reordered parameter,
	# a changed type or a silently-grown default is five later frames' worth of churn, and nothing
	# else in the suite would notice any of them until those frames are written.
	#
	# Deliberately does NOT fail if a TWELFTH function is added: the whole freeze contract is
	# "additions allowed, reshapes not", and a later frame may need one more (the roadmap's Black
	# Mountain note is the planned case for the Overshield helper, and the same rule applies here).
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
			if expected_arg.size() > 3:
				assert_eq(actual_arg.hint, expected_arg[3],
					'%s arg %d ("%s") is a TYPED array - hint pins the element type (Important 3).' % [required, i, expected_arg[0]])

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
		if expected.has('return_hint'):
			assert_eq(entry.return.hint, expected.return_hint,
				'%s returns a TYPED array - hint pins the element type (Important 3).' % required)

	# AND THE TAG'S VALUE, not only the six functions. OWN_TAG is part of the produced interface (plan
	# Task 1) and its STRING is a cross-frame contract: five consumer frames and SP2's Step all read
	# Teleport.OWN_TAG, and a rename or a typo in it is invisible to every other assertion in this file,
	# because is_own tags and reads back through the same constant and so stays green against any value
	# at all. Pinned as a literal for exactly that reason.
	assert_eq(Teleport.OWN_TAG, &'reag_own_teleport',
		'Teleport.OWN_TAG keeps its frozen VALUE, not merely its name.')

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

func test_own_involuntary_stays_involuntary_under_a_movement_type_buff_that_is_voluntary():
	# THE ONE FLAG SP2'S "this teleportation cannot be prevented" RESTS ON, and the engine hands it
	# back unless the helper re-asserts it. MovementType.create sets `type.voluntary = is_voluntary`
	# (movement_type.gd:44) and THEN merges every Buff.TO.MOVEMENT_TYPE resource the unit holds (:51),
	# where merge_in is `voluntary = voluntary or other.voluntary` (:81). So one buffed movement type
	# authored voluntary = true turns Step back into a preventable teleport: both Immobilized gates test
	# that flag (pathfinder.gd:333, event_unit_move.gd:451) and Pathfinder.create is where every
	# MOVEMENT_RESTRICTION ban lands.
	#
	# LATENT, NOT LIVE - no vanilla resource and none of the three residents sets `voluntary` on a
	# movement-type buff, so nothing else in the suite would ever notice this going wrong, which is the
	# whole reason the case is built by hand here.
	apply_a_voluntary_movement_type_buff()

	var default_type := Teleport.movement_type(unit)
	assert_true(default_type.free_climb,
		'CONTROL: the buff really is merged into what create() returns...')
	assert_true(default_type.voluntary,
		'...and the DEFAULT shape is still voluntary, exactly as it is without the buff.')

	var own := Teleport.movement_type(unit, true)
	assert_true(own.free_climb, 'CONTROL: the same buff merged into the own-involuntary shape too...')
	assert_false(own.voluntary,
		'...and voluntary is re-asserted FALSE after that merge, which is the whole of "this'
		+ ' teleportation cannot be prevented".')
	assert_true(Teleport.is_own(own), 'And it is still tagged as ours.')

func test_a_buffed_tag_does_not_make_a_voluntary_teleport_read_as_ours():
	# THE SYMMETRIC HALF OF THE TEST ABOVE - carried item 1 (SP1 slice-1 close review), re-carried and
	# sharpened. movement_type() re-asserts `voluntary = false` after the engine's merge in the
	# own-involuntary branch, but until now did not re-assert the ABSENCE of OWN_TAG in the default
	# branch - and other_tags merges wholesale (movement_type.gd:96) exactly like every other buffed
	# field. So a Buff.TO.MOVEMENT_TYPE resource whose own other_tags happened to carry OWN_TAG would
	# leak the tag into a VOLUNTARY teleport too, and is_own() would read an ordinary, foreign teleport
	# as our own unpreventable Step.
	#
	# LATENT, NOT LIVE (see the fixture helper's own header) - built by hand for exactly that reason.
	apply_a_movement_type_buff_carrying_our_tag()

	var default_type := Teleport.movement_type(unit)
	assert_true(default_type.voluntary, 'CONTROL: the default shape is still voluntary.')
	assert_false(Teleport.is_own(default_type),
		'THE FINDING: is_own reads it as NOT ours, even though the buff\'s own other_tags smuggled the'
		+ ' tag in - a voluntary teleport is never ours, whatever tag arrives on the merge.')

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

# ================================================================================================
# THE PERFORM HALF (SP2). Everything above this line is SP1's and is unchanged.
# ================================================================================================

## An activation whose context carries unit + gear + action, so SpecificAction.from_context yields a
## VALID one and move()/move_along() have something real to hang on the event as its `object`. A bare
## SpecFactory.dummy_event() does not, which is the negative control in
## test_move_hangs_nothing_on_the_event_when_the_activation_has_no_action.
func sourced_activation() -> EventCore:
	var gear:GearCore = unit.get_gear(&'mw_improvised_attack')
	return SpecFactory.dummy_event({unit = unit, gear = gear, action = gear.get_solo_action()})

## Raise one tile of terrain between the unit and a tile beyond it, so line of sight is broken without
## making the far tile unstandable. test_hole_puncher.gd's recipe.
func wall_at(tiles:Array[Vector2i]) -> void:
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', tiles)
	game.map.calculate_los_blockers()

func immobilize(of:Unit) -> void:
	UnitCondition.apply_status(SpecFactory.dummy_event(), of,
		Lancer.STATUS.IMMOBILIZED, Lancer.UNTIL.MANUAL)

# ---------------------------------------------------------------- candidate_tiles

func test_candidate_tiles_excludes_a_tile_another_unit_is_standing_on():
	UnitTile.move_to(forcing_unit, DESTINATION)
	assert_false(Teleport.candidate_tiles(unit, 5, false).has(DESTINATION),
		'An occupied tile is not a free space.')

func test_candidate_tiles_excludes_the_units_own_tile():
	assert_false(Teleport.candidate_tiles(unit, 5, false).has(START),
		'Teleporting to where you already are is not a move.')

func test_candidate_tiles_excludes_tiles_beyond_the_range():
	var near := Teleport.candidate_tiles(unit, 2, false)
	assert_false(near.any(func(tile:Vector2i) -> bool: return Tile.distance(tile, START) > 2),
		'Nothing beyond the range is offered.')
	assert_true(near.any(func(tile:Vector2i) -> bool: return Tile.distance(tile, START) == 2),
		'And the edge of the range IS - so the assertion above is not vacuous.')

func test_candidate_tiles_includes_a_tile_behind_a_wall_only_without_line_of_sight():
	# The clause Step of Mist and Thunder needs: "without requiring line of sight".
	wall_at([Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)])
	var behind := Vector2i(6, 2)
	assert_true(Teleport.candidate_tiles(unit, 5, false).has(behind),
		'Blind, the tile behind the wall is a candidate.')
	assert_false(Teleport.candidate_tiles(unit, 5, true).has(behind),
		'Sighted, it is not - so the wall really blocks.')

func test_candidate_tiles_honours_a_bound_keep():
	var only_north := func(tile:Vector2i) -> bool: return tile.y < START.y
	var kept := Teleport.candidate_tiles(unit, 2, false, only_north)
	assert_false(kept.is_empty(), 'Something survived the filter.')
	assert_true(kept.all(func(tile:Vector2i) -> bool: return tile.y < START.y),
		'And only what keep() allowed - this is the hook Abjuration hangs its pull rule on.')

# ---------------------------------------------------------------- pathfinder

func test_pathfinder_over_a_tile_set_reaches_exactly_the_standable_ones():
	var tiles := Teleport.candidate_tiles(unit, 3, false)
	var pf:Pathfinder = await Teleport.pathfinder(unit, tiles)
	assert_true(pf.using_movement_type.teleport, 'It is a teleport pathfinder.')
	assert_true(pf.valid_destinations.all(tiles.has),
		'It reaches nothing we did not offer it.')
	assert_false(pf.valid_destinations.is_empty(), 'And it reaches something.')

func test_pathfinder_is_empty_for_an_immobilized_unit():
	# THE PREVENTABLE ROUTE, on purpose. Pathfinder.create refuses a voluntary move by an immobilized
	# unit (pathfinder.gd:333), and Teleport.pathfinder is deliberately voluntary - Abjuration's
	# teleport is an ordinary one that Immobilized should stop.
	immobilize(unit)
	var pf:Pathfinder = await Teleport.pathfinder(unit, Teleport.candidate_tiles(unit, 3, false))
	assert_true(pf.valid_destinations.is_empty(), 'Immobilized stops this route, as it should.')

# ---------------------------------------------------------------- move

func test_move_lands_by_tile_and_returns_a_completed_core():
	var core:EventCore = await Teleport.move(sourced_activation(), unit, DESTINATION)
	assert_not_null(core, 'It handed the move core back.')
	assert_false(core.aborted, 'Which did not abort.')
	assert_eq(unit.tile(), DESTINATION, 'And the mech is there.')

func test_move_returns_an_aborted_core_when_a_pre_listener_vetoes():
	# NOT THE UNCERTAINTY FIELD ANY MORE (reach design ruling C, 2026-09-17): the field can no longer
	# take a Step. What this still pins is the GENERIC seam Step's own guard depends on - `move` hands
	# back an aborted core whenever any PRE listener vetoes it, arm_listener's hand-built one included -
	# and that is why nobody arrives, so nobody saves.
	arm_listener()
	var core:EventCore = await Teleport.move(sourced_activation(), unit, DESTINATION)
	assert_not_null(core, 'Still handed back.')
	assert_true(core.aborted, 'Marked aborted.')
	assert_eq(unit.tile(), START, 'And nothing moved.')

func test_the_own_involuntary_move_lands_while_immobilized_and_the_voluntary_one_does_not():
	# Ruling 8 in one test, and the pair is the point: the flag is what does the work.
	immobilize(unit)
	await Teleport.move(sourced_activation(), unit, DESTINATION)
	assert_eq(unit.tile(), DESTINATION, 'Own-involuntary clears the gate.')

	UnitTile.move_to(unit, START)
	await Teleport.move(sourced_activation(), unit, DESTINATION, false)
	assert_eq(unit.tile(), START, 'Voluntary does not.')

func test_move_hangs_the_calling_actions_specific_on_the_event():
	# NOT FOR NAMING THE VETO ANY MORE (reach design ruling C, 2026-09-17): Uncertainty Field can no
	# longer take a Step to log by name, since the field never offers on one. What this object still
	# buys is forcer() safety: Teleport.forcer(context) reads it back to return the mech ITSELF for a
	# Step, which is what makes UnitRelation.are_enemies(unit, unit) false and the exemption safe rather
	# than accidental (forcer()'s own docstring, above). Abjuration's own vetoed teleport still logs
	# against replaced_name by name, through move_along()'s own object.
	var core:EventCore = await Teleport.move(sourced_activation(), unit, DESTINATION)
	assert_true(SpecificAction.is_valid(core.context.object),
		'The move carries a SpecificAction as its object.')
	assert_eq(core.context.object.unit, unit, 'And it is ours.')

func test_move_hangs_nothing_on_the_event_when_the_activation_has_no_action():
	# The negative control for the test above, and the shape a spec's bare dummy event produces.
	var core:EventCore = await Teleport.move(SpecFactory.dummy_event(), unit, DESTINATION)
	assert_false(SpecificAction.is_valid(core.context.object),
		'Nothing readable, rather than a half-built specific.')
	assert_eq(unit.tile(), DESTINATION, 'And it still moved.')

# ---------------------------------------------------------------- move_along

func test_move_along_lands_along_a_plan_and_returns_the_movers_core():
	var pf:Pathfinder = await Teleport.pathfinder(unit, [DESTINATION] as Array[Vector2i])
	var plan := CompconPlan.new()
	plan.move_path = pf.path_to(DESTINATION)
	assert_false(plan.move_path.is_empty(), 'Fixture: there is a path to walk.')

	var core:EventCore = await Teleport.move_along(sourced_activation(), unit, pf, plan)
	assert_not_null(core, 'It handed a core back.')
	assert_eq(core.context.unit, unit, 'The MOVER us, not a katamari passenger.')
	assert_eq(unit.tile(), DESTINATION, 'And the mech is there.')

func test_move_beats_a_movement_restriction_ban_while_the_pathfinder_route_loses_to_it():
	# THE PAIR THAT MUST OUTLIVE THE SP2 PROBE. test_spike_own_involuntary_teleport.gd measured this
	# and is deleted in Task 4, and nothing else in this file discriminates the two routes: without a
	# live ban on the map, a hand-built path and a target tile behave identically, so move() could
	# quietly go back to target_tiles and every other test here would stay green.
	#
	# WHY IT WORKS. EventUnitMove.undergo_move takes context.array straight when it is given a path
	# (event_unit_move.gd:137-138) and otherwise builds a pathfinder ITSELF (:139-145) - and
	# Pathfinder.create is where every MOVEMENT_RESTRICTION buff on the map is read and intersected
	# (:345-352), with no voluntariness check on that read. So the ONLY route that escapes a ban is
	# one that never builds a pathfinder.
	#
	# The Minotaur's Interdiction Field is hung straight on the hostile rather than equipped and woken:
	# buff_interdiction_field.tres is `to = movement_restriction` and its check_if_passive_applies
	# asks only for a teleporting movement type and an enemy holder. IT HAS TWO BRANCHES and only the
	# near one is a lockdown - held further than 3 away it allows every tile EXCEPT its own radius
	# (:29-33), which would ban nothing we care about. At distance 2 it allows the blank array.
	UnitTile.move_to(forcing_unit, Vector2i(4, 2))
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), forcing_unit, &'buff_interdiction_field')
	assert_true(UnitRelation.are_enemies(unit, forcing_unit), 'Fixture: the field is a hostile one.')

	var pf:Pathfinder = await Teleport.pathfinder(unit, Teleport.candidate_tiles(unit, 4, false))
	assert_true(pf.valid_destinations.is_empty(),
		'The ban is live: the PREVENTABLE route finds nowhere to go.')

	await Teleport.move(sourced_activation(), unit, DESTINATION)
	assert_eq(unit.tile(), DESTINATION,
		'And move() lands anyway - no pathfinder is ever built, so no ban is ever read.')
