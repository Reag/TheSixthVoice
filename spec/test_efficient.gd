# EFFICIENT: the shared core-power refund, born with the Maiden's Blush's Step of Mist and Thunder.
#
#   "This ability is Efficient and will refund 1 Core Point at the end of any scene in which this
#    ability was used."
#
# Two halves, and this file covers both: efficient.gd (the stamp and the refund, testable against any
# gear on any frame) and action_efficient_refund.gd (the hidden reaction that fires it, which needs a
# core Kit to sit on and so is tested on the Blush).
#
# THE REFUND FIRES FROM TWO TRIGGERS ON PURPOSE (ruling 15). combat_end IS the card and really reaches
# a living mech - event_combat_end fires COMBAT_END PRE then POST (event_combat_end.gd:26-28) BEFORE
# it walks the map collecting the surviving unit.cores (:33-42). unit_spawn is the safety net for the
# two cases combat_end cannot serve: a mech destroyed earlier was serialised at death with the stamp
# already in its gear state, and a Stunned one cannot react at all. Efficient.refund erases the stamp
# before returning, so the pair can never hand back two points - which is what the idempotence tests
# below pin.
extends GutTest

const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')
const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')

const BLUSH_TILE := Vector2i(4, 4)
const RESPAWN_TILE := Vector2i(6, 6)

var game:Gamemaster
var blush:Unit

func before_each() -> void:
	game = MaidensBlushFixture.create_game(self)
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func core_gear() -> GearCore:
	var gear:GearCore = blush.get_gear(MaidensBlushFixture.CORE_ID)
	assert_true(GearCore.is_valid(gear), 'Fixture: the Blush carries %s.' % MaidensBlushFixture.CORE_ID)
	return gear

## Spend the core point the way pressing the ability would, without pressing it: Step of Mist and
## Thunder does not exist until Task 4, and this file is about the REFUND.
func spend_and_stamp() -> GearCore:
	var gear := core_gear()
	blush.core.has_core_power = false
	Efficient.mark_used(gear)
	return gear

# ---------------------------------------------------------------- the helper itself

func test_mark_used_and_is_marked_round_trip():
	var gear := core_gear()
	assert_false(Efficient.is_marked(gear), 'A fresh gear is unmarked.')
	Efficient.mark_used(gear)
	assert_true(Efficient.is_marked(gear), 'And marked once stamped.')

func test_neither_function_throws_on_an_invalid_gear():
	# Both run on every combat end and every spawn of every unit on the map, where a throw is an error
	# storm rather than a wrong answer.
	Efficient.mark_used(null)
	assert_false(Efficient.is_marked(null), 'A null gear is simply not marked.')

func test_refund_on_an_unmarked_gear_does_nothing_and_returns_false():
	var gear := core_gear()
	blush.core.has_core_power = false
	assert_false(Efficient.refund(blush, gear), 'It reports that it did nothing.')
	assert_false(blush.core.has_core_power, 'And it did nothing - the point stays spent.')

func test_refund_on_a_marked_gear_restores_the_point_clears_the_stamp_and_returns_true():
	var gear := spend_and_stamp()
	assert_true(Efficient.refund(blush, gear), 'It reports the refund.')
	assert_true(blush.core.has_core_power, 'The point is back.')
	assert_false(Efficient.is_marked(gear), 'And the stamp is gone.')

func test_a_second_refund_returns_false_and_cannot_hand_back_a_second_point():
	# THE IDEMPOTENCE THE TWO TRIGGERS REST ON. Without it, a mech that survived a scene would be
	# refunded at combat_end and AGAIN at the next scene's spawn - and the second one would be free.
	var gear := spend_and_stamp()
	assert_true(Efficient.refund(blush, gear), 'First refund.')
	blush.core.has_core_power = false # as though it had been spent again next scene
	assert_false(Efficient.refund(blush, gear), 'Second refund declines.')
	assert_false(blush.core.has_core_power, 'And hands nothing back.')

func test_the_stamp_survives_a_serialize_deserialize_round_trip():
	# This is what makes the unit_spawn safety net work at all: a mech destroyed mid-scene is
	# serialised at death, and the stamp has to still be there when the next scene deserialises it.
	# GearCore.state is carried by GearCore.serialize (gear_core.gd:63-84) and the gear by the core.
	spend_and_stamp()
	var restored := UnitCore.deserialize(blush.core.serialize())
	assert_true(UnitCore.is_valid(restored), 'The core round-tripped.')
	var restored_gear:GearCore = restored.loadout.get_by_compcon_id(MaidensBlushFixture.CORE_ID)
	assert_true(GearCore.is_valid(restored_gear), 'And still carries the core Kit.')
	assert_true(Efficient.is_marked(restored_gear), 'With the stamp intact.')
	assert_false(restored.has_core_power, 'And the point still spent.')

func test_a_full_repair_clears_the_stamp_and_restores_the_point_by_itself():
	# Not a case the helper handles - a case it must not fight. GearCore.full_repair clears the whole
	# state dictionary (gear_core.gd:152-154) and UnitPrinter.full_repair sets has_core_power
	# (unit_printer.gd:76), so a mech repaired between scenes is already whole and the stamp going
	# with it is correct rather than a lost refund.
	var gear := spend_and_stamp()
	blush.core.full_repair()
	assert_true(blush.core.has_core_power, 'The repair gave the point back on its own.')
	assert_false(Efficient.is_marked(gear), 'And took the stamp with it, so nothing refunds twice.')

# ---------------------------------------------------------------- the reaction, on the Blush

func test_the_refund_reaction_is_on_the_core_kit():
	var kit:Kit = ContentLibrary.get_kit(MaidensBlushFixture.CORE_ID)
	if not Kit.is_valid(kit): return fail_test('%s loaded.' % MaidensBlushFixture.CORE_ID)
	var action_ids:Array[StringName] = []
	for action:Action in kit.actions: action_ids.append(action.get_id())
	assert_true(action_ids.has(&'action_efficient_refund'),
		'A consumer wires the shared refund in by putting its own .tres on its core Kit.')

func test_the_refund_is_never_advertised_in_the_tooltip():
	# The player reads "Efficient" in the core power's own effect text, where the card puts it. A
	# tooltip row saying "Reaction: ..." would invent a second ability the card has not got - the same
	# reasoning that keeps this frame's damage-break and Fade Strike arming as hidden buffs.
	var kit:Kit = ContentLibrary.get_kit(MaidensBlushFixture.CORE_ID)
	if not Kit.is_valid(kit): return fail_test('%s loaded.' % MaidensBlushFixture.CORE_ID)
	for action:Action in kit.actions:
		if action.get_id() != &'action_efficient_refund': continue
		assert_false(action.show_in_tooltip(kit), 'The refund stays off every player-facing surface.')

## A mech arriving in the NEXT SCENE, built the way the campaign builds one: serialise the core,
## deserialise it, and wrap a fresh Unit around it. Hands back the new unit, which is the one to
## assert on - `blush` is the previous scene's and stays behind.
##
## TAKING THE PREVIOUS SCENE'S UNIT OFF THE MAP FIRST IS LOAD-BEARING, and both halves of that were
## measured (2026-09-17, with X.DEBUG_REACTION and a temporary print inside triggers_on_event):
##
##   - Re-spawning `blush` in place does not work and fails SILENTLY. map_bus.add_new_unit refuses a
##     persistent id that is already on the map and force-changes it ("FORCE-CHANGED added unit ID ...
##     because its original one was already previously spawned!"), re-registering the mech as a
##     DIFFERENT Unit whose gear state is empty - so at UNIT_SPAWN PRE the trigger saw the original,
##     marked, and at POST a new unit, unmarked. The refund correctly declined.
##   - Deserialising into a fresh Unit is not enough either, because UnitCore.deserialize KEEPS the
##     persistent id: with the original still standing, the arrival force-changed too.
##
## Neither is a content bug. A real next scene has nothing of the previous one on the map, which is
## what remove_from_game models here.
##
## Thy Hubris' action_cupiditas_vitae_efficient re-spawns its Draugr in place and passes anyway,
## because its refund is UNCONDITIONAL - it asks only `not unit.core.has_core_power`, which the
## re-registered unit still satisfies. This helper is stamp-gated on purpose (see the discriminator
## test below), so it needs the real path.
func spawn_into_next_scene(from:Unit) -> Unit:
	var saved:Dictionary = from.core.serialize()
	from.remove_from_game() # the previous scene ended; nothing of it is on the map any more
	var core := UnitCore.deserialize(saved)
	# A FRESH ID, because the map remembers every id it has EVER spawned, not merely the ones standing
	# on it - the force-change message says "previously spawned". The shared gamemaster lives for the
	# whole run, so a deserialised core reusing its id is force-changed however thoroughly the previous
	# unit was removed, and the force-change is what drops the gear state this test is about.
	core.persistent_id = Util.generate_random_hexcode()
	var arriving := Unit.create(core)
	assert_true(Efficient.is_marked(arriving.get_gear(MaidensBlushFixture.CORE_ID)) == Efficient.is_marked(from.get_gear(MaidensBlushFixture.CORE_ID)),
		'Fixture: the arrival carries whatever stamp the previous scene saved.')
	await game.execute_event('event_unit_spawn', {unit = arriving, target_tiles = [RESPAWN_TILE]})
	return arriving

func test_a_marked_blush_is_refunded_when_it_spawns_into_the_next_scene():
	# The SAFETY NET half (ruling 15), and the shape both first-party precedents use - the Barbarossa's
	# action_regain_cp.gd and Thy Hubris' action_cupiditas_vitae_efficient. It is what serves a mech
	# that was destroyed earlier in the scene, or Stunned and unable to react at combat end.
	spend_and_stamp()
	var arriving := await spawn_into_next_scene(blush)
	assert_true(arriving.core.has_core_power, 'The next scene starts with the point back.')
	assert_false(Efficient.is_marked(arriving.get_gear(MaidensBlushFixture.CORE_ID)),
		'And the stamp cleared, so it cannot fire again.')

func test_an_unmarked_blush_is_not_refunded_at_spawn():
	# THE DISCRIMINATOR between this helper and the unconditional precedents. Thy Hubris' version
	# restores the point on every spawn without asking, which is safe there because that frame's only
	# core-point spender IS the Efficient ability. This helper is shared, so a later consumer's core
	# Kit may hold an action that spends the point and is not Efficient - and the stamp is the only
	# thing that tells those two apart.
	blush.core.has_core_power = false
	var arriving := await spawn_into_next_scene(blush)
	assert_false(arriving.core.has_core_power, 'No stamp, no refund.')

func test_a_marked_blush_is_refunded_at_combat_end():
	# THE CARD'S OWN TIMING, and the half neither first-party precedent implements. event_combat_end
	# fires COMBAT_END PRE then POST (event_combat_end.gd:26-28) BEFORE it walks
	# context.map.get_all_characters() collecting the surviving unit.cores (:33-42), so a point
	# restored at POST is inside the core the campaign keeps.
	#
	# SKIP_BANNER and LAST IN THE FILE, both deliberate. The event ends by emitting
	# campaign_bus.end_level (:63) and this fixture uses the SHARED gamemaster at the tree root, so
	# anything it tears down would reach later scripts in the run, not just later tests here. The
	# banner await is already skipped under X.TEST_MODE (:54) but the flag says so out loud.
	spend_and_stamp()
	await game.execute_event('event_combat_end',
		{boolean = true, flags = [EventService.COMBAT_END_FLAG.SKIP_BANNER]})
	assert_true(blush.core.has_core_power, 'The scene ended and the point came back.')
	assert_false(Efficient.is_marked(core_gear()), 'And the stamp cleared.')

func test_the_core_kit_carries_the_stamp_passive_with_resets_on_spawn_off():
	# THE ONE LINE THE unit_spawn SAFETY NET RESTS ON, pinned structurally as well as behaviourally.
	# GearCore.short_repair throws away every gear-state key except those of PassiveDieCounter passives
	# with resets_on_spawn = false (gear_core.gd:144-150), and EVERY spawn runs short_repair
	# (unit_printer.gd:8-10 via map_bus.gd:8, reached with full_repair = false from
	# event_unit_spawn.gd:68). Without this passive the stamp is serialised faithfully and then wiped
	# before any UNIT_SPAWN reaction can read it - which is exactly how it failed when first built, and
	# it failed SILENTLY: the refund simply declined.
	#
	# The spawn test above would also go red, but only after a two-minute run and with a message about
	# core points rather than about the passive. This one names the cause.
	var kit:Kit = ContentLibrary.get_kit(MaidensBlushFixture.CORE_ID)
	if not Kit.is_valid(kit): return fail_test('%s loaded.' % MaidensBlushFixture.CORE_ID)
	# Kit.get_passives returns Array[Passive], not a typed array of what it filtered for, so the
	# element is taken untyped rather than declared.
	var stamps:Array = kit.get_passives(PassiveDieCounter)
	assert_eq(stamps.size(), 1, 'The core Kit carries exactly one die-counter stamp.')
	if stamps.is_empty(): return
	var stamp:PassiveDieCounter = stamps[0]
	assert_eq(stamp.key, Efficient.USED_KEY, 'Its key is the one Efficient reads and writes.')
	assert_false(stamp.resets_on_spawn, 'And it survives a spawn, which is its whole purpose.')
	assert_false(stamp.show_in_tooltips, 'Invisible: the player reads Efficient on the card.')
	assert_false(stamp.log_changes, 'And silent: the stamp moving is not a battle-log event.')
