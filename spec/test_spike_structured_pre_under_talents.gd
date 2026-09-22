# LEOLETH SP1 PROBE (design 1.0): does a STRUCTURED PRE reaction fire under the talents mod's
# wholesale replacement of event_unit_structure's execute, and does it run BEFORE the overflow is
# folded into the new structure bar?
#
# ALL SYSTEMS RED (ruling 6) is "when you would structure, you do not take any overflow damage".
# The engine's overflow IS the negative HP: event_unit_structure.execute decrements structure and
# then does `health = mini(health + get_health_max(), max)` (content/events/event_unit_structure.gd:38-40),
# so damage past zero is carried by the negative number into the next bar. Zeroing it at PRE is the
# whole rule - and PRE is awaited in execute_preblock (:33-34), a method the resident
# gavstarb-talents_1st_party extension (res/content/events/event_unit_structure.gd_ext.gd) does NOT
# override: it replaces `execute` wholesale, for its REROLL_STRUCTURE_STRESS buffs, and never calls
# super. The seams line of the design doc rules that the hook therefore fires under the replacement
# exactly as under vanilla. This file measures it.
#
# THE SHAPE IS ALL SYSTEMS RED'S, MINUS THE COVER: a 4-structure, 8 HP, 0-armor dummy carries a
# knockoff trait Kit whose one action is a hidden, point-free ActionReactionSelf on STRUCTURED PRE
# that stamps an Engine meta and sets a negative current.health to 0. One 13-damage hit takes it to
# -5 and queues the structure event. Under the engine's fold the numbers separate the two orders:
# PRE-before-fold leaves the new bar FULL (8); POST-after-fold leaves it at 3, and zeroing 3 does
# nothing, so the mutation cannot hide as "fired but harmlessly".
#
# THE DICE. event_unit_damage rolls nothing for a bare number. make_structure_check rolls
# `count = structure_max - structure_current` d6 (:80-83) - ONE die at the first structure - and a
# 6 is IMPAIRED (:89-92), which raises only an informational brochure the stock responder answers.
# Anything 2-4 rolls a SECOND d6 and destroys gear through a choose_from_gear prompt, and a 1 stuns;
# neither is wanted here. The queue is asserted empty afterwards, so the die count is pinned too.
#
# MUTATION: set TIMING to ReactionBus.TIMING.POST. test_a_pre_structured_zeroing_leaves_the_new_bar_full
# must go red on its HP line (3 where 8 is expected) while its LIVENESS line stays green - the
# reaction fired, and fired after the fold. The control and the resident tests stay green.
# MEASURED 2026-09-21: exactly that - 2/3, 19/20 asserts, the one red is the HP line at 3, the
# resident test green (so the talents replacement was live for the measurement). Green run 3/3,
# 20 asserts, no SKIPPED line. Restored byte-identical (SHA-256) afterwards.
#
# IF THE CLAIM TEST IS RED WITH THE LIVENESS LINE ALSO RED, the resident's replacement DID reach
# the preblock after all: stop and report; the design's fallback is a DAMAGE PRE RESIST_DAMAGE cap
# sized to the remaining HP, which is a different ruling.
#
# No production code. The Leoleth's real reaction is built on the core Kit by the SP1 plan.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_structured_pre_under_talents.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const TALENTS_MOD := 'gavstarb-talents_1st_party'
## The vanilla path of the event script, and the resident's extension of it at its unpacked path.
const STRUCTURE_SCRIPT := 'res://content/events/event_unit_structure.gd'
const TALENTS_EXTENSION := 'res://unpacked/%s/res/content/events/event_unit_structure.gd_ext.gd' % TALENTS_MOD
## The one method the resident adds. Its presence on the LIVE script is what proves the replacement
## is installed in this run, rather than merely present on disk.
const TALENTS_METHOD := &'make_structure_check_with_rerolls'
## The method the whole ruling hangs on: the resident must NOT define it.
const PREBLOCK := &'execute_preblock'

## THE MUTATION KNOB. PRE is the claim under test; POST is the mutation.
const TIMING := ReactionBus.TIMING.PRE

const META := &'reag_structured_pre_probe_fired'

const DUMMY_HP := 8
const DUMMY_STRUCTURE := 4
## Past zero by OVERFLOW: HP 8 - 13 = -5.
const HIT := 13
const OVERFLOW := HIT - DUMMY_HP
## A structure-check d6 of 6 is IMPAIRED: one brochure, no gear prompt, no second die.
const IMPAIRED_D6 := 6

const DUMMY_TILE := Vector2i(4, 4)

var game:Gamemaster
var dummy:Unit
var reaction:ZeroOverflow


## Stamps a meta on the Engine and clamps a negative HP to 0. Hidden and point-free, so the bus runs
## it with no prompt and outside the action economy - ALL SYSTEMS RED's own shape.
class ZeroOverflow extends ActionReactionSelf:
	var fired:int = 0

	func _init(timing:ReactionBus.TIMING) -> void:
		triggers_on = [ReactionBus.TRIGGER.STRUCTURED]
		trigger_timing = timing
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

	func activate(context:Context, _activation:EventCore) -> void:
		fired += 1
		Engine.set_meta(META, fired)
		var unit:Unit = context.unit
		if unit.core.current.health < 0: unit.core.current.health = 0


func before_each() -> void:
	Engine.remove_meta(META)
	game = Fixture.create_game(self)
	dummy = SpecFactory.create_unit(game.map, DUMMY_TILE, Faction.PLAYER)
	FrameIsolation.isolate_frame(dummy)
	dummy.core.frame.stat.health = DUMMY_HP
	dummy.core.frame.stat.armor = 0
	dummy.core.frame.stat.structure = DUMMY_STRUCTURE
	dummy.core.full_repair()
	assert_eq(dummy.core.current.health, DUMMY_HP, 'fixture: full HP.')
	assert_eq(dummy.core.current.structure, DUMMY_STRUCTURE, 'fixture: full structure.')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Engine.remove_meta(META)


# ---------------------------------------------------------------- helpers

## The knockoff Kit on the dummy's own loadout as a runtime trait Kit (the Sluagh probe's idiom).
## full_repair() regenerates derived gear, which is where the Kit's reaction gets indexed by trigger.
func install_reaction() -> void:
	reaction = ZeroOverflow.new(TIMING)
	var kit := Kit.new()
	kit.compcon_id = &'structured_pre_probe_kit'
	kit.is_trait = true
	kit.actions.append(reaction)
	dummy.core.loadout.equipped_kits.append(kit)
	dummy.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## One real damage event for HIT, which queues the structure event itself
## (event_unit_damage.gd queue_structure_or_stress_if_necessary). The structure check's one d6 is
## cheated to IMPAIRED.
func hit_past_zero() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.append(IMPAIRED_D6)
	await game.execute_event(&'event_unit_damage', {
		unit = dummy, number = HIT, category = Lancer.DAMAGE_TYPE.KINETIC,
	})


# ---------------------------------------------------------------- the probe

## THE CLAIM. The PRE reaction zeroes the -5 before execute folds it into the new bar, so the new
## bar is exactly full.
func test_a_pre_structured_zeroing_leaves_the_new_bar_full() -> void:
	install_reaction()
	await hit_past_zero()
	assert_eq(reaction.fired, 1, 'LIVENESS: the reaction fired exactly once for the one structure.')
	assert_eq(Engine.get_meta(META, 0), 1, 'LIVENESS: the meta was stamped from inside activate.')
	assert_eq(dummy.core.current.structure, DUMMY_STRUCTURE - 1, 'One structure was lost.')
	assert_eq(dummy.core.current.health, dummy.get_health_max(),
		'HP is the new bar EXACTLY: no overflow was carried, because the zeroing ran BEFORE the fold.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'Exactly one d6 was rolled: the structure check.')

## CONTROL: with nothing reacting, the engine carries the overflow. Pins the number the claim reads
## its ordering off, so a fixture or engine change shows here rather than as a wrong verdict.
func test_without_the_reaction_the_overflow_is_carried() -> void:
	await hit_past_zero()
	assert_false(Engine.has_meta(META), 'Nothing stamped the meta.')
	assert_eq(dummy.core.current.structure, DUMMY_STRUCTURE - 1, 'One structure was lost.')
	assert_eq(dummy.core.current.health, dummy.get_health_max() - OVERFLOW,
		'The 5 past zero came off the new bar: 8 - 5 = 3.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'Exactly one d6 was rolled: the structure check.')

## THE SEAM. The talents mod's replacement is LIVE in this run (its own method is on the script the
## engine loads for the event) and it defines no execute_preblock of its own - so the claim above
## was measured under the resident, not under vanilla. A resident that starts overriding the
## preblock reddens this before it can silently retire ALL SYSTEMS RED.
func test_the_talents_replacement_is_live_and_leaves_the_preblock_alone() -> void:
	var live:Script = load(STRUCTURE_SCRIPT)
	assert_not_null(live, 'The event script loads.')
	var live_methods := method_names(live)
	if not live_methods.has(TALENTS_METHOD):
		var message := 'SKIPPED: %s is not resident, so the STRUCTURED PRE seam was measured under vanilla only. Restore the residency set with restore-links.ps1.' % TALENTS_MOD
		gut.p(message)
		pass_test(message)
		return
	assert_true(live_methods.has(TALENTS_METHOD),
		'LIVENESS: the script the engine loads for event_unit_structure carries the resident\'s %s.' % TALENTS_METHOD)
	var extension:Script = load(TALENTS_EXTENSION)
	assert_not_null(extension, 'The resident\'s extension script loads from its unpacked path.')
	var own := own_method_names(extension)
	assert_true(own.has(&'execute'), 'The resident replaces execute (the seam the registry records).')
	assert_false(own.has(PREBLOCK),
		'THE RULING: the resident defines no %s of its own, so vanilla\'s STRUCTURED PRE await still runs.' % PREBLOCK)

## Every method visible on the script, base scripts included.
func method_names(script:Script) -> Array[StringName]:
	var names:Array[StringName] = []
	for method:Dictionary in script.get_script_method_list(): names.append(StringName(method.name))
	return names

## Only the methods THIS script's source defines - get_script_method_list walks the inheritance
## chain, so the vanilla base's execute_preblock would show through it and hide the very thing
## under test. Script.get_script_method_list on a base-less view is not available, so the names are
## read off the source text's `func ` declarations instead.
func own_method_names(script:Script) -> Array[StringName]:
	var names:Array[StringName] = []
	var regex := RegEx.new()
	regex.compile('(?m)^func\\s+(\\w+)\\s*\\(')
	for found:RegExMatch in regex.search_all(script.source_code): names.append(StringName(found.get_string(1)))
	return names
