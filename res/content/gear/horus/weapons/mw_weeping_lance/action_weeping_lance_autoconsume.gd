## WEEPING LANCE's forced consume (SP4 Task 1, ruling 18): the forgo profile ALWAYS consumes Lock On.
##
## Seeking Payload's shape (action_seeking_payload_autoconsume_lock.gd): vanilla's consume reaction by
## path, at Priority.ATTACK.mandatory so it runs before the basic loadout's prompting copy, and
## confirm_consume -> true. When the vanilla copy runs after it, is_valid_target_for_consuming_lock
## finds no LOCKON left and it asks nothing (action_consume_lock_on.gd:34-36, :57-62).
##
## Gated on the ATTACK being the Lance's forgo profile, read from the triggering action's marker. The
## plain profile never matches, so its consume stays vanilla's yes/no.
extends "res://content/gear/basic/ms_lock_on/action_consume_lock_on.gd"

const WeepingLance := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/weapons/mw_weeping_lance/action_weeping_lance.gd')

## Bookkeeping, not a card row: the weapon's own Effect row already says it (the relock's reason).
func show_in_tooltip(_kit:Kit) -> bool: return false
func get_priority() -> int: return Priority.ATTACK.mandatory
func confirm_consume(unit:Unit, target_unit:Unit) -> bool: return true

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var context:Context = triggering_event.context
	if context.gear != gear: return false # this Lance, not another weapon
	return WeepingLance.is_forgo(context.action)
