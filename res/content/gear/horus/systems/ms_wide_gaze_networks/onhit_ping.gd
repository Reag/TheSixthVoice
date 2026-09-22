## PING'S LOCK (Naga SP2 Task 2, ruling 11): "Your target becomes Locked on."
##
## THROUGH THE SHARED HOOK, NOT THE DECLARATIVE statuses ARRAY - the ruling the design left open
## ("a Ping on an ALREADY locked target - measured, then ruled"). apply_status APPENDS a second LOCKON
## condition unconditionally (unit_condition.gd:104-105), and an ability clear removes ONE condition
## (clear_specific_status, :326-329): so a declarative Ping on a locked target would leave a lock
## standing behind a Stabilize that the player saw succeed. Lockon.apply refuses an already-locked
## target (vanilla Lock On's own refusal, action_lock_on.gd:5-11), keeping the FIRST lock and its
## source. test_measured_a_raw_second_lockon_stacks_and_survives_one_ability_clear is the measurement,
## test_a_ping_on_a_locked_target_keeps_one_lock_and_still_impairs the ruling.
##
## THE CHIP GOES ON AFTER THE LOCK, AND ONLY IF THE TARGET IS NOW LOCKED. Not through the .tres'
## buffs array: apply_statuses_and_buffs runs BEFORE on_hit (on_hit_effect.gd:41-45), so a target
## immune to Lock On would be left Impaired with no lock - against "if the target has Lock On". On an
## already-locked target the relock is refused and the chip still hangs, which is the card.
extends OnHitEffect

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')
const CHIP := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping.tres')

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if not Unit.is_valid(attacked_unit): return
	var gear:GearCore = activation.context.gear
	Lockon.apply(activation, attacked_unit, gear)
	if not attacked_unit.has_status(Lancer.STATUS.LOCKON): return
	var chips:Array[Buff] = [CHIP]
	UnitCondition.apply_buffs(activation, attacked_unit, chips, gear)
