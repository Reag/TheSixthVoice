# VAUBAN SP2, THE PROBE (design §2.0): three claims the core power is built on, measured against the
# 1.4.3 engine BEFORE any of it exists.
#
# THIS IS A PROBE, NOT CONTENT. Every resource it uses is built in code, in this file; nothing under
# spec/ is ever scanned into ContentLibrary. It is deleted in Task 5 once test_grav_amped_interference.gd
# pins the same claims against the real Kit - the same life cycle as SP1's own
# test_spike_vauban_probe.gd (34b4847), test_spike_status_aura.gd (Myconid SP2) and
# test_spike_teleport_interception.gd (Maiden's Blush SP1).
#
# THE THREE CLAIMS, AND WHAT READING THE ENGINE PREDICTS (2026-09-18):
#
#  A. "A saver-side BuffSkillSave keyed on context.unit sees the Vauban as the forcer - for a save the
#     Vauban forces itself AND for one forced by something it owns." UnitHasecheck.roll_check builds
#     the buff context with target_unit = the SAVER and, only when a forcing_action was supplied,
#     unit/gear/action copied off it (unit_hasecheck.gd:174-184); it then reads TO.SAVE buffs from the
#     SAVER ONLY - the forcer's read is commented out at :186-189. So the chip is target-side and the
#     forcer arrives as context.unit. The unread hop is what context.unit IS when a DEPLOYABLE forces
#     the save: event_unit_save.execute passes SpecificAction.from_context(context) into handle_check
#     (event_unit_save.gd:60), so it is whoever was named as the forcer when the event was queued.
#     Prediction: the deployable itself, and get_owner_unit_or_self() (unit.gd:270-273) is what makes
#     it the Vauban - the same call UnitCondition.forced_save makes for its own purposes (:71).
#
#  B. "forced_save POST carries the pass/fail result; PRE does not." PRE fires from execute_preblock
#     (event_unit_save.gd:33-34) before anything is rolled; context.boolean is assigned at :54; POST is
#     queued at :70. Prediction: POST reads boolean == false on a failure, true on a pass, with unit =
#     the forcer and target_unit = the saver at both timings.
#
#  C. "A forced_save POST reaction resolves INSIDE Sap's save, before Sap applies its Slowed."
#     make_hull_save -> run_save_event -> await event.execute_events([save_event])
#     (unit_hasecheck.gd:52-55, :74-89), and Sap's activate only reaches its apply_status after that
#     await returns. Prediction: a POST reaction's damage lands first, and a hostile it kills is never
#     Slowed. That is design ruling 10, which SP2's 3 AP clause is built on and which test_sap.gd
#     today only asserts in a comment.
#
# THREE CORRECTIONS TO THE PLAN'S OWN LISTING OF THIS FILE, each measured by the first run
# (0/8, 2026-09-18) and each a HARNESS mistake rather than the engine disagreeing:
#
#  1. Gamemaster.execute_event RETURNS VOID. The plan's force_hull_save read `core.context.boolean`
#     off it and got `Invalid access to property or key 'context' on a base object of type 'Nil'` in
#     all six tests that used it. Level.execute_event is `-> void` (level.gd:97-98); only
#     EventCore.execute_event returns the core (event_core.gd:70-75). Saves are forced here through
#     UnitHasecheck.make_hull_save instead, which is the production path (every vanilla caller in
#     content/ uses it) and hands back the bool directly.
#
#  2. A SAVE FORCED WITHOUT A FULL unit+gear+action TRIFECTA REACHES THE SAVER'S BUFFS WITH NO FORCER
#     AT ALL - the single most load-bearing thing this probe learned. roll_check copies the forcer
#     into the buff context only `if SpecificAction.is_valid(forcing_action)` (unit_hasecheck.gd:180),
#     and SpecificAction.is_valid demands all three of unit, gear and action
#     (specific_action.gd:16-23). The plan's helper passed `gear = null, action = null`, so
#     context.unit was never set, the chip's is_buff_context_valid_for_passive refused, and the gate
#     list came back EMPTY - which reads exactly like "the engine never consults a save buff". It
#     does; it just had nothing to consult it with. The battle log's tell is `failed a Hull save from
#     ?` - the `?` is handle_check's source string for an invalid forcing_action
#     (unit_hasecheck.gd:141-147). Production consequence for Task 2: buff_grav_amped_saves must
#     survive a forcer-less context rather than assume context.unit, which is what
#     is_buff_context_valid_for_passive below does.
#
#  3. THREE DAMAGE DOES NOT KILL A THREE-HP MECH. It takes it to 0 HP, event_unit_structure decrements
#     structure and, while structure remains, RESTORES it to full health
#     (event_unit_structure.gd:41-46). The kill case therefore gives its victim ONE structure, the
#     idiom test_heaer.gd's make_victim already uses. The survivor case cannot assert an exact HP
#     either, because the Vauban's OTHER SP1 trait - Solfataric Breach - also fires at the same turn
#     start and put 6 more damage on the survivor; it asserts the ORDERING directly instead, off what
#     the reaction's own gate saw.
#
# HOW THE CODE-BUILT GEAR GETS ONTO A UNIT: install() below appends a Kit to loadout.equipped_kits and
# calls full_repair(), which is what rebuilds LoadoutCore.reactions_by_trigger (loadout_core.gd:291-296)
# and LoadoutCore.auras (:298-301). Without it neither the reaction nor the aura exists as far as the
# engine is concerned.
#
# AN IN-CODE REACTION MUST CARRY AN ID, OR ITS GATE IS ASKED TWICE (SP1 probe, measured): get_id()
# falls back to the resource path's basename, empty for a code-built Resource, and
# ReactionBus.does_reaction_trigger opens with `if rxn.get_id() == X.DEBUG_REACTION`, whose default is
# also &'' (reaction_bus.gd:97-108, global.gd:239). original_id in _init() is the fix.
#
# AN AURA BUFF MAY NOT BE GENERIC: PassiveAura.apply_aura_buffs_to_unit asserts
# buff.compcon_id != Buff.GENERIC_ID (passive_aura.gd:79).
#
# AND THE CODE-BUILT BUFF IS NOT COPIED ON THE WAY TO THE UNIT, which is what lets `gates` below work
# at all: UnitCondition.apply_buffs does BuffCore.create(buff, ...) and BuffCore.create assigns
# `base = buff_base` by reference (buff_core.gd:26-31) - no duplicate() anywhere in the path - and
# does_buff_apply then calls core.base.check_if_passive_applies (unit_condition.gd:845-851).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_vauban_sp2_probe.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')

const MAP_SIZE := Vector2i(15, 9)
const VAUBAN_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(6, 4)
const MINE_TILE := Vector2i(5, 4)

const CHIP_KIT := &'probe_sp2_chip_kit'
const CHIP_BUFF := &'buff_probe_sp2_chip'
const WATCH_KIT := &'probe_sp2_save_watcher'

## The trifecta a forced save needs a valid SpecificAction for (correction 2 in the header). Every
## player mech carries ms_fragment_signal in its basic loadout
## (content/gear/basic/basic_loadout_mech_player.tres), and LoadoutCore hands that list to anything
## whose frame is_player_mech() regardless of faction (loadout_core.gd:183-186) - so the AI-faction
## Everest dummies here have it too. It is a label, nothing more: make_hull_save never activates it.
const FORCING_GEAR := &'ms_fragment_signal'

var game:Gamemaster
var vauban:Unit
var hostile:Unit

# =============================== THE PROBE'S THROWAWAY RESOURCES ===============================

## The production buff's shape: a target-side save chip that applies only when the forcer, resolved
## through owner-or-self, is this aura's own unit. Records every gate it is asked, so a test can tell
## "the buff said no" apart from "the engine never asked".
class ForcerChip extends BuffSkillSave:
	## Set by the test before install(); the unit the chip is keyed to.
	var keyed_to:Unit = null
	## Every check_if_passive_applies call: {forcer, resolved, verdict}.
	var gates:Array[Dictionary] = []
	## When true, drop the owner-or-self resolution - THE MUTATION for claim A.
	var mutated := false

	func _init() -> void:
		compcon_id = CHIP_BUFF # an aura buff may not be generic (passive_aura.gd:79)
		to = Buff.TO.SAVE
		all_save_types = true
		bonus_subtype = Buff.BONUS_SUBTYPE.ACCURACY
		mod = -1
		hide_from_player = true

	func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
		return Unit.is_valid(context.unit) # the forcer; absent on a plain check AND on a trifecta-less save

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if not super.check_if_passive_applies(core, context): return false
		var forcer:Unit = context.unit
		if not Unit.is_valid(forcer): return false
		var resolved:Unit = forcer if mutated else forcer.get_owner_unit_or_self()
		var verdict:bool = Unit.is_valid(resolved) and resolved == keyed_to
		gates.append({
			forcer = forcer.core.persistent_id,
			resolved = resolved.core.persistent_id if Unit.is_valid(resolved) else &'',
			verdict = verdict,
		})
		return verdict

## A forced_save POST reaction that records the context it was handed and optionally damages the
## saver - claims B and C.
class SaveWatcher extends ActionReaction:
	var seen:Array[Dictionary] = []
	## Kinetic damage dealt to the saver on a FAILED save; 0 to only watch.
	var damage_on_failure := 0

	func _init() -> void:
		original_id = &'action_probe_sp2_save_watcher' # see the header: an id-less reaction is double-gated
		triggers_on = [ReactionBus.TRIGGER.FORCED_SAVE]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.target_units, Context.PROP.unit]

	func get_per_round_hard_limit(_specific:SpecificAction) -> int:
		return 99

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		var saver:Unit = context.target_unit
		seen.append({
			forcer = context.unit.core.persistent_id if Unit.is_valid(context.unit) else &'',
			saver = saver.core.persistent_id if Unit.is_valid(saver) else &'',
			boolean_present = context.is_property_present(Context.PROP.boolean),
			passed = context.boolean,
			# claim C: what the SAVER looked like at the moment this POST gate was asked, i.e. after
			# the roll resolved but before anything the forcing action does afterwards.
			saver_slowed = Unit.is_valid(saver) and saver.has_status(Lancer.STATUS.SLOWED),
			saver_health = saver.core.current.health if Unit.is_valid(saver) else -999,
		})
		return damage_on_failure > 0 and context.boolean == false

	func activate(context:Context, activation:EventCore) -> void:
		var triggering:Context = context.event.context
		activation.queue_event(&'event_unit_damage', {
			unit = triggering.target_unit,
			number = damage_on_failure,
			category = Lancer.DAMAGE_TYPE.KINETIC,
			target_unit = context.unit,
		})

# =============================== FIXTURE ===============================

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	hostile = VaubanFixture.create_hostile(game, HOSTILE_TILE)
	VaubanFixture.track(game)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Append a code-built Kit and re-index the loadout. full_repair() is what makes the engine see it.
func install(on:Unit, kit_id:StringName, actions:Array[Action] = [], passives:Array[Passive] = []) -> void:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	for action:Action in actions: kit.actions.append(action)
	for passive:Passive in passives: kit.passives.append(passive)
	on.core.loadout.equipped_kits.append(kit)
	on.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## Hang `chip` on every hostile through an unbounded, hostiles-only aura on `vauban` - the production
## shape, so the probe measures the delivery route too and not only the buff's own gate.
func install_chip(chip:ForcerChip) -> void:
	var aura := PassiveAura.new()
	aura.buffs.append(chip)
	aura.aura_range = 99
	aura.applies_to_self = false
	aura.applies_to_allies = false
	aura.applies_to_enemies = true
	aura.applies_only_to_characters = true
	install(vauban, CHIP_KIT, [], [aura])

func install_watcher(damage_on_failure:int = 0) -> SaveWatcher:
	var watcher := SaveWatcher.new()
	watcher.damage_on_failure = damage_on_failure
	install(vauban, WATCH_KIT, [watcher])
	return watcher

## Deploy a REAL vanilla grounding mine from the Vauban and hand back the deployable unit.
##
## ms_grounding_charges is Iskander-licence gear (content/gear/ha/systems/ms_grounding_charges) whose
## action_grounding_mine is an ActionSystemDeploy - so a tile target deploys it with no prompt. The
## mine's TRIGGER action is deliberately NOT driven here: action_grounding_mine_trigger.activate calls
## TargetActionUtil.ask_for_targets_alt, an interactive pick, and a probe that hangs measures nothing.
## What this probe needs from the mine is only that it is a real unit the Vauban OWNS.
func deploy_grounding_mine() -> Unit:
	var gear := vauban.core.equip_system(&'ms_grounding_charges')
	SpecFactory.apply_passive_buffs(vauban)
	await VaubanFixture.open_turn(game, vauban)
	await SpecFactory.use(game, vauban, &'ms_grounding_charges', &'action_grounding_mine', MINE_TILE)
	var deployed:Array = UnitAction.get_deployables_from(vauban, gear)
	return deployed.front() if not deployed.is_empty() else null

## A real EventCore with a real, valid EventBlock. make_*_save routes through run_save_event, which
## calls event.execute_events - a no-op unless event.block is a real, is_block_valid() EventBlock
## (event_core.gd:77-81, :48). Lifted from this mod's own test_weak_computer.gd, which lifted it from
## test/gear/test_ms_stable_structure.gd and test/talent/test_t_technophile.gd.
func save_event() -> EventCore:
	var event := SpecFactory.dummy_event()
	event.block = EventBlock.create_multiple([event])
	add_child_autoqfree(event.block)
	return event

## Force a Hull save on `hostile` in the named forcer's name, through the same production call every
## vanilla save-forcing action in content/ makes. `forcing` MUST be a valid trifecta or the saver's
## buffs never see a forcer at all - see correction 2 in the header. Returns whether it passed.
func force_hull_save(forcing:SpecificAction) -> bool:
	return await UnitHasecheck.make_hull_save(save_event(), hostile, forcing)

## The forcer as the engine's own callers name one: unit + gear + action.
func forcer(unit:Unit, gear_id:StringName = FORCING_GEAR, action_id:StringName = &'') -> SpecificAction:
	return SpecificAction.from_id(unit, gear_id, action_id)

## Queue a d20 that EXACTLY makes the save, then a 3 for the difficulty die, then a long tail of
## sixes so nothing downstream drains the FIFO into real RNG (test_draw_fire.gd's shape).
##
## The arithmetic, stated once: event_unit_save reads the save target off the FORCER
## (event_unit_save.gd:41-43) and the flat bonus off the SAVER's Hull (:47-51); roll_check then adds
## Dice.roll_d6_accuracy(accuracy_bonus), which for -1 rolls ONE d6 and negates it
## (dice.gd:86-88, sum_rolls' `result *= signi(dice.count)` at :66). So a d20 of
## (save_target - hull) passes by exactly 0 with no chip and fails by 3 with it.
func queue_exact_pass(save_target:int, hull:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var queue:Array[int] = [save_target - hull, 3]
	for i:int in 60: queue.append(6)
	Dice.CHEAT_ROLL_QUEUE.assign(queue)

## A d20 five under the target, then a long tail of sixes: an unambiguous failure.
func queue_clear_failure(save_target:int, hull:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var queue:Array[int] = [maxi(save_target - hull - 5, 1)]
	for i:int in 60: queue.append(6)
	Dice.CHEAT_ROLL_QUEUE.assign(queue)

# =============================== CLAIM A: the forcer reaches a target-side save buff ===============================

func test_claim_a_the_vauban_forcing_a_save_itself_is_seen() -> void:
	var chip := ForcerChip.new()
	chip.keyed_to = vauban
	install_chip(chip)
	assert_true(UnitCondition.has_buff(hostile, CHIP_BUFF), 'fixture: the aura hung the chip on the hostile')

	var target:int = vauban.get_save_target()
	var hull:int = hostile.core.get_hull()
	gut.p('  save target %d, hostile Hull %d' % [target, hull])
	queue_exact_pass(target, hull)

	var passed:bool = await force_hull_save(forcer(vauban))

	assert_gt(chip.gates.size(), 0, 'the engine asked the chip whether it applies')
	var gate:Dictionary = chip.gates.back()
	gut.p('  gate saw forcer %s, resolved to %s, verdict %s' % [gate.forcer, gate.resolved, gate.verdict])
	assert_true(gate.verdict, 'and the chip said yes: the forcer resolved to the Vauban')
	assert_false(passed, 'the -1 reached the roll: a d20 that exactly made the target now fails')

## THE NEGATIVE CONTROL FOR CORRECTION 2: the same save forced with no gear and no action at all.
## Nothing about the chip changes; the engine simply never hands it a forcer.
func test_claim_a_a_save_forced_without_gear_or_action_reaches_the_chip_with_no_forcer() -> void:
	var chip := ForcerChip.new()
	chip.keyed_to = vauban
	install_chip(chip)

	var target:int = vauban.get_save_target()
	var hull:int = hostile.core.get_hull()
	queue_exact_pass(target, hull)

	var bare := SpecificAction.create(vauban, null, null)
	gut.p('  SpecificAction.is_valid(unit-only) = %s' % SpecificAction.is_valid(bare))
	var passed:bool = await force_hull_save(bare)

	assert_true(chip.gates.is_empty(), 'the chip was NEVER asked: roll_check copies the forcer in only for a valid trifecta (unit_hasecheck.gd:180)')
	assert_true(passed, 'so no -1 reached the roll, however the buff is written')

func test_claim_a_a_save_forced_by_an_unrelated_hostile_is_refused() -> void:
	var chip := ForcerChip.new()
	chip.keyed_to = vauban
	install_chip(chip)
	var stranger := VaubanFixture.create_hostile(game, Vector2i(9, 7))
	VaubanFixture.track(game)

	var target:int = stranger.get_save_target()
	var hull:int = hostile.core.get_hull()
	queue_exact_pass(target, hull)

	var passed:bool = await force_hull_save(forcer(stranger))

	assert_true(passed, 'no -1: a save forced by somebody else is untouched')
	assert_false(chip.gates.is_empty(), 'the chip was still asked')
	assert_false(chip.gates.back().verdict, 'and refused')

func test_claim_a_a_save_forced_by_a_mine_the_vauban_owns_resolves_through_owner_or_self() -> void:
	var mine:Unit = await deploy_grounding_mine()
	assert_true(Unit.is_valid(mine), 'fixture: a grounding mine was deployed')

	var chip := ForcerChip.new()
	chip.keyed_to = vauban
	install_chip(chip)
	gut.p('  the mine reports owner %s' % [mine.get_owner_unit().core.persistent_id if Unit.is_valid(mine.get_owner_unit()) else '<none>'])

	var target:int = mine.get_save_target()
	var hull:int = hostile.core.get_hull()
	gut.p('  the mine save target %d, hostile Hull %d' % [target, hull])
	queue_exact_pass(target, hull)

	var mine_forcer := forcer(mine, &'mt_grounding_mine', &'action_grounding_mine_trigger')
	assert_true(SpecificAction.is_valid(mine_forcer), 'fixture: the mine names a valid trifecta')
	var passed:bool = await force_hull_save(mine_forcer)

	assert_false(chip.gates.is_empty(), 'the engine asked the chip')
	var gate:Dictionary = chip.gates.back()
	gut.p('  gate saw forcer %s, resolved to %s, verdict %s' % [gate.forcer, gate.resolved, gate.verdict])
	gut.p('  (the Vauban is %s, the mine is %s)' % [vauban.core.persistent_id, mine.core.persistent_id])
	assert_true(gate.verdict, 'owner-or-self turned the mine into the Vauban')
	assert_false(passed, 'and the -1 reached the roll')

func test_claim_a_mutation_dropping_owner_or_self_loses_the_mine() -> void:
	var mine:Unit = await deploy_grounding_mine()
	assert_true(Unit.is_valid(mine), 'fixture: a grounding mine was deployed')

	var chip := ForcerChip.new()
	chip.keyed_to = vauban
	chip.mutated = true # THE MUTATION: compare context.unit directly instead of resolving the owner
	install_chip(chip)

	var target:int = mine.get_save_target()
	var hull:int = hostile.core.get_hull()
	queue_exact_pass(target, hull)

	var passed:bool = await force_hull_save(forcer(mine, &'mt_grounding_mine', &'action_grounding_mine_trigger'))

	assert_false(chip.gates.is_empty(), 'the engine still asked')
	assert_false(chip.gates.back().verdict, 'MUTATION: without owner-or-self the mine is a stranger')
	assert_true(passed, 'and the save is untouched - which is the clause earning its place')

# =============================== CLAIM B: what forced_save POST carries ===============================

func test_claim_b_post_carries_the_forcer_the_saver_and_a_failure() -> void:
	var watcher := install_watcher()
	var target:int = vauban.get_save_target()
	var hull:int = hostile.core.get_hull()
	queue_clear_failure(target, hull)

	var passed:bool = await force_hull_save(forcer(vauban))

	assert_false(passed, 'fixture: the save failed')
	assert_eq(watcher.seen.size(), 1, 'the POST reaction was asked exactly once')
	var seen:Dictionary = watcher.seen.front()
	gut.p('  POST saw forcer %s, saver %s, boolean_present %s, passed %s' % [seen.forcer, seen.saver, seen.boolean_present, seen.passed])
	assert_eq(seen.forcer, vauban.core.persistent_id, 'context.unit is the FORCER')
	assert_eq(seen.saver, hostile.core.persistent_id, 'context.target_unit is the SAVER')
	assert_true(seen.boolean_present, 'context.boolean is present at POST')
	assert_false(seen.passed, 'and it reports the failure')

func test_claim_b_post_reports_a_pass_as_a_pass() -> void:
	var watcher := install_watcher()
	Dice.CHEAT_ROLL_QUEUE.clear()
	var queue:Array[int] = [20]
	for i:int in 60: queue.append(6)
	Dice.CHEAT_ROLL_QUEUE.assign(queue)

	var passed:bool = await force_hull_save(forcer(vauban))

	assert_true(passed, 'fixture: the save passed')
	assert_eq(watcher.seen.size(), 1, 'asked once')
	assert_true(watcher.seen.front().passed, 'and POST reports the pass')

# =============================== CLAIM C: a POST reaction lands inside Sap's save ===============================

func test_claim_c_a_post_reaction_kills_before_sap_applies_its_slowed() -> void:
	# A hostile with 3 HP and ONE structure, standing in difficult ground, taking its turn: Sap fires
	# at new_turn PRE, forces the Hull save, and the watcher's 3 Kinetic resolves inside that save.
	# The single structure is what makes 3 damage lethal - see correction 3 in the header.
	hostile.core.frame.stat.structure = 1 # FrameIsolation'd by the fixture, so this reaches no shared Frame
	hostile.core.full_repair()
	hostile.core.current.health = 3
	VaubanFixture.lay_difficult(game, [HOSTILE_TILE])
	VaubanFixture.track(game)
	var watcher := install_watcher(3)

	queue_clear_failure(vauban.get_save_target(), hostile.core.get_hull())

	await VaubanFixture.open_turn(game, hostile)

	assert_eq(watcher.seen.size(), 1, 'Sap forced exactly one save and the watcher saw it')
	var seen:Dictionary = watcher.seen.front()
	gut.p('  at the POST gate the saver had %d HP and Slowed = %s' % [seen.saver_health, seen.saver_slowed])
	assert_false(seen.passed, 'fixture: the hostile failed it')
	assert_false(seen.saver_slowed, 'the reaction was asked BEFORE Sap applied its Slowed')
	assert_false(Unit.is_valid(hostile) and hostile.is_on_map(), 'the 3 Kinetic killed it inside the save')
	assert_false(Unit.is_valid(hostile) and hostile.has_status(Lancer.STATUS.SLOWED), 'and it was never Slowed')

func test_claim_c_a_survivor_is_still_slowed_afterwards() -> void:
	# The control for the test above: same arrangement, 1 damage and full structure, so Sap's own
	# Slowed still lands and the ordering claim cannot be read as "the reaction broke Sap".
	#
	# NOT AN HP ASSERTION. The Vauban's other SP1 trait, Solfataric Breach, also fires at this same
	# turn start and put 6 more damage on the survivor (measured 2026-09-18), which structures it and
	# restores its health - so the ordering is pinned off what the reaction's own gate saw instead.
	hostile.core.current.health = 3
	VaubanFixture.lay_difficult(game, [HOSTILE_TILE])
	VaubanFixture.track(game)
	var watcher := install_watcher(1)

	queue_clear_failure(vauban.get_save_target(), hostile.core.get_hull())

	await VaubanFixture.open_turn(game, hostile)

	assert_eq(watcher.seen.size(), 1, 'one save')
	var seen:Dictionary = watcher.seen.front()
	gut.p('  at the POST gate the saver had %d HP and Slowed = %s' % [seen.saver_health, seen.saver_slowed])
	assert_eq(seen.saver_health, 3, 'the gate was asked before the reaction had taken its HP')
	assert_false(seen.saver_slowed, 'and before Sap applied its Slowed')
	assert_true(Unit.is_valid(hostile), 'fixture: 1 damage left it alive')
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'and Sap still applied its Slowed afterwards')
