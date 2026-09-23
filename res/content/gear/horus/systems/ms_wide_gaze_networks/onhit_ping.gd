## PING'S LOCK (Naga SP2 Task 2, ruling 11): "Your target becomes Locked on."
##
## THROUGH THE SHARED HOOK, NOT THE DECLARATIVE statuses ARRAY - the ruling the design left open
## ("a Ping on an ALREADY locked target - measured, then ruled"). apply_status APPENDS a second LOCKON
## condition unconditionally (unit_condition.gd:104-105), and a SOURCE-SPECIFIC clear removes only
## the copies carrying its source (clear_status with a source, :310-324 - a gear-destroyed
## clear_status_source, event_unit_clear_status): so a declarative Ping on a locked target would
## leave a stale second lock, with the wrong source, standing behind such a clear. Lockon.apply
## refuses an already-locked target (vanilla Lock On's own refusal, action_lock_on.gd:5-11), keeping
## the FIRST lock and its source. (Corrected at the frame close: Stabilize is NOT such a clear -
## clear_status_via_ability walks every copy, :479-483 - so the first build's "a lock left standing
## behind a Stabilize the player saw succeed" was the wrong example; the refusal stands on the sourced
## clear.) test_measured_a_raw_second_lockon_stacks_and_survives_one_sourced_clear measures both,
## test_a_ping_on_a_locked_target_that_keeps_its_lock_does_not_stack_a_second is the ruling.
##
## THEN THE WINDOW, AND ONLY IF THE TARGET IS NOW LOCKED. Not through the .tres' buffs array:
## apply_statuses_and_buffs runs BEFORE on_hit (on_hit_effect.gd:41-45), so a target immune to Lock
## On would carry a window that can never Impair it. On an already-locked target the relock is
## refused and the window still opens, which is the card. buff_ping's on_application hangs the
## Impaired (this lock's statuses_changed PRE was queued before the chip existed).
##
## THEN THE CLOCK, ON THE NAGA (author decision 1): buff_ping_clock, keyed to this chip, ends the
## window at the end of the Naga's next turn whatever the turn order (see its header).
extends OnHitEffect

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')
const CHIP := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping.tres')
const CLOCK := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping_clock.tres')
const ClockScript := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping_clock.gd')

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if not Unit.is_valid(attacked_unit): return
	var gear:GearCore = activation.context.gear
	Lockon.apply(activation, attacked_unit, gear)
	if not attacked_unit.has_status(Lancer.STATUS.LOCKON): return
	var chip := UnitCondition.apply_buff(activation, attacked_unit, CHIP, gear)
	var naga:Unit = activation.context.unit
	if not Unit.is_valid(naga) or not GearCore.is_valid(gear): return
	var clock := BuffCore.create(CLOCK, gear.persistent_id)
	clock.set_state(ClockScript.TARGET_KEY, String(attacked_unit.core.persistent_id))
	clock.set_state(ClockScript.CHIP_KEY, String(chip.persistent_id))
	UnitCondition.apply_buff_alt(activation, naga, clock)
