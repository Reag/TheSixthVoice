## SHREDDER CANNON'S ON-HIT (Purple Thorn SP3 Task 1, ruling 11).
##
## THE CHIP ON THE TARGET, THEN ITS CLOCK ON THE THORN - the Naga's Ping (onhit_ping.gd) step for
## step, without the lock. The chip carries the Shredded and the +1 (buff_shredded_mark); the clock
## (buff_shredded_clock, the Ping's own clock script) ends it at the end of the Thorn's next turn
## whatever the turn order, where a target-side END_OF_OWNERS_NEXT_TURN would wait for the TARGET to
## start a turn (unit_condition.gd:24, :62) - the Ping bug.
##
## A SECOND HIT ON THE SAME TARGET RESTARTS THE WINDOW: apply_buff replaces the earlier chip from the
## same gear (apply_buff_alt's same-source clear, unit_condition.gd:741-747), and the earlier clock,
## keyed to that chip's persistent id, then finds nothing and does nothing. A hit on ANOTHER target
## gets its own chip and its own clock (the clocks stack).
##
## ANY TARGET: the card's "the target" is unqualified, so an object is Shredded too. Only the +1 is
## about characters, and that gate is the ATTACKER's (buff_shredded_mark.gd).
extends OnHitEffect

const CHIP := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/weapons/mw_shredder_cannon/buff_shredded_mark.tres')
const CLOCK := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/weapons/mw_shredder_cannon/buff_shredded_clock.tres')
const ClockScript := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_wide_gaze_networks/buff_ping_clock.gd')

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if not Unit.is_valid(attacked_unit): return
	var gear:GearCore = activation.context.gear
	var chip := UnitCondition.apply_buff(activation, attacked_unit, CHIP, gear)
	var thorn:Unit = activation.context.unit
	if chip == null or not Unit.is_valid(thorn) or not GearCore.is_valid(gear): return
	var clock := BuffCore.create(CLOCK, gear.persistent_id)
	clock.set_state(ClockScript.TARGET_KEY, String(attacked_unit.core.persistent_id))
	clock.set_state(ClockScript.CHIP_KEY, String(chip.persistent_id))
	UnitCondition.apply_buff_alt(activation, thorn, clock)
