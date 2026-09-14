## O.R.S HYPERCHARGE, the activation: a core-power protocol that applies the scene-long buff and
## READIES every intact Loading weapon on the spot.
##
## RULING 6 IS WHY THE RELOAD IS HERE AND NOT IN THE BUFF. "Ignore the Loading property" means the
## weapon behaves as if it never had it, so a weapon already fired and empty this turn is loaded when
## the protocol resolves - otherwise the ability would punish the obvious order of play (shoot, then
## hypercharge) for no reason the card gives. The heat cost applies only to shots fired AFTERWARDS,
## which is the buff's job: it only ever reacts to a firing, so it could not do this one.
##
## HUNG ON apply_additional_effect RATHER THAN ON activate(). That is the hook
## ActionSystemApplyBuff declares for exactly this ("OVERRIDE",
## action_system_apply_buff.gd:167-169), and it is reached only from inside apply_buffs_to_targets,
## after apply_buffs has run (:157-158) - so it cannot fire on a path where the buff was never
## applied. Overriding activate() would have had to re-derive that for itself: super() returns void
## whether it applied the buff or bailed out of a declined confirm_use (:104), so the override would
## need a has_buff() probe afterwards to tell the two apart. The hook makes the question moot.
extends ActionSystemApplyBuff

func apply_additional_effect(_specific:SpecificAction, target_unit:Unit, _activation:EventCore) -> void:
	# apply_only_to_self is set on the .tres, so target_unit is always the firer - but the engine
	# calls this once PER target and hands the target in, so reading the loadout off target_unit
	# rather than off specific.unit keeps the two in step if that ever stops being true.
	if not Unit.is_valid(target_unit): return
	for gear:GearCore in target_unit.core.loadout.get_all_weapons():
		if not gear.is_intact(): continue # a destroyed weapon is not "readied", it is wreckage
		if not is_loading_weapon(target_unit, gear): continue
		gear.is_loaded = true

## Does any attack profile on this weapon carry the Loading tag?
##
## get_all_weapons() (loadout_core.gd:521) is the engine's own enumeration - the same one
## UnitAction.get_unloaded_weapons filters for Stabilize's reload offer (unit_action.gd:411-416), so
## this readies exactly the set Stabilize would have offered.
##
## has_tag is asked of the ACTION, with a SpecificAction for context, because a tag can be granted by
## a weapon mod or by a buff on a per-weapon basis (action_attack_weapon.gd:161-172) - and because
## that is the same question unit_action.gd:276 asks when it drops the flag in the first place.
static func is_loading_weapon(unit:Unit, gear:GearCore) -> bool:
	for action:Action in gear.kit.actions:
		if not action is ActionAttackWeapon: continue
		if action.has_tag(Lancer.WEAPON_TAG.LOADING, SpecificAction.create(unit, gear, action)):
			return true
	return false
