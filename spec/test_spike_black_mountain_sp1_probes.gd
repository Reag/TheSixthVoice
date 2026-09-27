# BLACK MOUNTAIN SP1 PROBES (design 1.2): the two facts this frame is built on, measured before any
# content is written, and kept as specs the Naga's way.
#
# P1 - THE ORDER OF THE CONSUME (ruling 9). Dread Harbinger's payoff is a statuses_changed POST buff on
# the locked target that pays only when the lock was CONSUMED, and it wants to read that off
# buff_lock_consumed at activate time. action_consume_lock_on.gd:42-43 clears the status FIRST (which
# queues the STATUSES_CHANGED POST virtual event, unit_condition.gd:216-218) and applies
# buff_lock_consumed SECOND, so by the time the queued block executes the chip is on the target; it is
# stripped only at event_unit_attack.gd:114, after the roll. A knockoff buff records what it sees. The
# CONTROL is a Stabilize-shaped clear: the lock is lost, no chip, so the record must read false.
#
# P2 - THE VESTMENT DOUBLE-COUNT (ruling 6, the compat finding). The resident gavstarb-ssc_emperor's
# Imperial Vestment reacts to EVERY overshield event; when the shielded unit is the Emperor it rewrites
# the event's number at PRE to min(current + delta, 6 + Grit), where delta is the event's number unless
# the event carries `boolean = true`, in which case delta = number - current
# (action_imperial_vestment.gd:14-22). The frozen Overshield.increase() hands grant() current + amount
# with no boolean, so an Emperor holding 2 increased by 1 ends at 2 + 3 = 5. WRITTEN RED FIRST; the
# helper's `boolean = true` (ruling 6) turns it green. The second P2 row pins the Emperor's OWN rule -
# a plain grant lands additively and capped - which is recorded, not ours to fix.
#
# If P1 is red on its claim with its LIVENESS lines green, stop and report: ruling 9 falls back to the
# Naga's stash-the-source-at-PRE shape. If P2's control row (the plain grant) moves, the resident has
# changed its rule and the compat row in test_compat.gd is what records the new one.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_black_mountain_sp1_probes.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const ALLY_TILE := Vector2i(4, 4)
const HOSTILE_TILE := Vector2i(8, 4) # inside the rifle's range 10
const EMPEROR_TILE := Vector2i(4, 8)

## P1's knockoff: Ping's shape (buff_ping.gd), POST so "true" means LOST, gated the way the real mark
## will be, recording what it sees instead of paying. Its activate is overridden so it does NOT clear
## itself (buff.gd:254-255), which is also what the real mark needs until it decides to.
class ConsumeProbe extends Buff:
	var saw_consumed_chip:Array[bool] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.STATUSES_CHANGED]
		trigger_timing = ReactionBus.TIMING.POST
		hide_from_player = true

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.category]

	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		if triggering_event.context.unit != unit: return false
		return Lockon.is_lost(triggering_event)

	func activate(_core:BuffCore, activation:EventCore) -> void:
		var holder:Unit = activation.context.unit
		saw_consumed_chip.append(UnitCondition.has_buff(holder, Lockon.CONSUMED_BUFF))

var game:Gamemaster

func before_each() -> void:
	game = Fixture.create_game(self)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- P1: the order of the consume

func probe_on(hostile:Unit) -> ConsumeProbe:
	var probe := ConsumeProbe.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event({unit = hostile}), hostile, probe)
	return probe

func test_p1_a_post_listener_on_the_locked_target_sees_the_consumed_chip_when_the_lock_is_consumed() -> void:
	var ally := Fixture.create_ally(game, ALLY_TILE)
	Fixture.arm_rifle(ally)
	var hostile := Fixture.create_hostile(game, HOSTILE_TILE)
	assert_true(Fixture.lock_by_hand(ally, hostile), 'fixture: locked by hand through the shared hook.')
	var probe := probe_on(hostile) # AFTER the lock: the apply (PRE) is never seen
	Fixture.queue([Fixture.HIT_ROLL, 3, 3]) # d20, the consumed lock's accuracy d6, the damage d6
	await Fixture.shoot(game, ally, hostile)
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: the shot consumed the lock.')
	assert_eq(probe.saw_consumed_chip.size(), 1, 'LIVENESS: the loss fired the POST listener once.')
	if probe.saw_consumed_chip.size() < 1: return
	assert_true(probe.saw_consumed_chip[0],
		'THE FACT: buff_lock_consumed is on the holder when the STATUSES_CHANGED POST block runs (ruling 9).')
	assert_false(UnitCondition.has_buff(hostile, Lockon.CONSUMED_BUFF),
		'And the chip is gone once the attack has rolled (event_unit_attack.gd:114) - the window is the queued block.')

func test_p1_control_a_stabilize_shaped_clear_fires_the_listener_with_no_consumed_chip() -> void:
	var ally := Fixture.create_ally(game, ALLY_TILE)
	var hostile := Fixture.create_hostile(game, HOSTILE_TILE)
	assert_true(Fixture.lock_by_hand(ally, hostile), 'fixture: locked.')
	var probe := probe_on(hostile)
	await Fixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: cleared by ability.')
	assert_eq(probe.saw_consumed_chip.size(), 1, 'LIVENESS: the loss fired the listener once.')
	if probe.saw_consumed_chip.size() < 1: return
	assert_false(probe.saw_consumed_chip[0], 'THE CONTROL: a lock lost any other way shows no consumed chip.')

# ---------------------------------------------------------------- P2: the Vestment double-count

const EMPEROR_OVERSHIELD_MARKER := 'overshield_emperor'
const OVERSHIELD_EVENT_SCRIPT := 'res://content/events/event_unit_overshield.gd'
const VESTMENT_KIT := &'mt_imperial_vestment_emperor'

func emperor_resident() -> bool:
	var script:Script = load(OVERSHIELD_EVENT_SCRIPT)
	while script != null:
		if script.source_code.contains(EMPEROR_OVERSHIELD_MARKER): return true
		script = script.get_base_script()
	return false

## Announce the skip rather than passing quietly (test_compat.gd's idiom).
func skipped_without_the_emperor() -> bool:
	if emperor_resident() and Frame.is_valid(ContentLibrary.get_mech_frame(Fixture.EMPEROR_ID)): return false
	var message := 'SKIPPED: %s is not resident, so the Vestment double-count is unmeasured. Restore the residency set with restore-links.ps1.' % Fixture.EMPEROR_MOD
	gut.p(message)
	pass_test(message)
	return true

func test_p2_fixture_the_emperor_wears_the_vestment_and_the_resident_extends_the_event() -> void:
	if skipped_without_the_emperor(): return
	var emperor := Fixture.create_emperor(game, EMPEROR_TILE)
	assert_eq(emperor.core.frame.compcon_id, Fixture.EMPEROR_ID, 'The resident\'s Emperor frame is worn.')
	assert_true(GearCore.is_valid(emperor.get_gear(VESTMENT_KIT)), 'Imperial Vestment is on its loadout.')
	assert_eq(Overshield.current(emperor), 0, 'No Storm Shield here: create_unit fires no spawn event.')

func test_p2_increase_by_one_on_an_emperor_holding_two_ends_at_three_under_the_resident() -> void:
	# RED BEFORE RULING 6: the helper hands the event 3 with no boolean, the Vestment reads delta = 3 and
	# writes min(2 + 3, 6 + Grit) = 5.
	if skipped_without_the_emperor(): return
	var emperor := Fixture.create_emperor(game, EMPEROR_TILE)
	await Fixture.grant_overshield(emperor, 2)
	assert_eq(Overshield.current(emperor), 2, 'fixture: the Emperor holds 2 (a grant from 0 is 0 + 2 to the Vestment too).')
	await Fixture.increase_overshield(emperor, 1)
	assert_eq(Overshield.current(emperor), 3,
		'THE FIX: increase() by 1 on an Emperor holding 2 ends at 3, because the event says boolean = true (ruling 6).')

func test_p2_a_plain_grant_of_three_on_an_emperor_holding_two_ends_at_five_which_is_the_emperors_rule() -> void:
	# Recorded, not ours to fix: Imperial Vestment says a grant to the Emperor increases rather than
	# replaces, capped at 6 + Grit. A plain grant() carries no boolean, so the Emperor's card lands.
	if skipped_without_the_emperor(): return
	var emperor := Fixture.create_emperor(game, EMPEROR_TILE)
	await Fixture.grant_overshield(emperor, 2)
	await Fixture.grant_overshield(emperor, 3)
	assert_eq(Overshield.current(emperor), 5, 'THE EMPEROR\'S RULE: 2 + 3, additive and under its cap.')

func test_p2_control_a_non_emperor_ally_is_untouched_either_way() -> void:
	# The Vestment rewrites the number only when the SHIELDED unit is the Emperor; for anyone else the
	# vanilla body runs untouched, boolean or no boolean. FIX (finding 4): an Emperor must actually be
	# ON THE MAP for the Vestment reaction to be POLLED at all - without one this control could not
	# fail whatever the code did. Assert only the ALLY: a live Emperor's own Vestment has a known echo
	# onto ITSELF (memory sixth-voice-build-state), which is not this control's business.
	if skipped_without_the_emperor(): return
	var _emperor := Fixture.create_emperor(game, EMPEROR_TILE)
	var ally := Fixture.create_ally(game, ALLY_TILE)
	await Fixture.grant_overshield(ally, 2)
	await Fixture.increase_overshield(ally, 1)
	assert_eq(Overshield.current(ally), 3, 'increase() on an ordinary ally is plain arithmetic.')
	await Fixture.grant_overshield(ally, 3)
	assert_eq(Overshield.current(ally), 3, 'And a plain grant keeps the engine max rule.')
