# LOAD MUNITIONS' CHIP (SP4 Task 1, design ruling 14). Visible on the Thorn until the start of its
# next turn (until = START_OF_TURN in the .tres), the chosen mount's persistent_id in its state.
#
# A Buff.TO.ONHIT_EFFECT carrier - the Roland Chamber's shape (buff_roland_chamber.gd): the attack
# event collects every ONHIT_EFFECT buff on the ATTACKER with the attack's own context
# (event_unit_attack.gd:47-49), so check_if_passive_applies sees context.gear = the firing weapon,
# and applies only when that weapon sits on the loaded mount. Not onetime, so the per-attack
# consume_buffs (:117) leaves it standing for every hit until the turn start clears it.
#
# THE TWO EFFECTS (onhit_hem.gd, two .tres) carry the "hostile character" gate themselves, in
# should_abort, because the save lives there too and a passed save skips the WHOLE effect - hence
# the damage and the Impaired are two effects, not one.
extends Buff

## Gear-independent key: the chosen mount's persistent_id, written by action_load_munitions.gd.
const MOUNT_KEY := 'loaded_mount'

@export var effects:Array[OnHitEffect]

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if context == null or not GearCore.is_valid(context.gear): return false
	if not (context.action is ActionAttackWeapon): return false
	var loaded := String(core.get_state(MOUNT_KEY, ''))
	if loaded.is_empty() or not Unit.is_valid(context.unit): return false
	var owner:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(owner): return false
	var mount:MountCore = owner.core.loadout.get_mount_for_gear(context.gear)
	return MountCore.is_valid(mount) and String(mount.persistent_id) == loaded

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({array = effects})
