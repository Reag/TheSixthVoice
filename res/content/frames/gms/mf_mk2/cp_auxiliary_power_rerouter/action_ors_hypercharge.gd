## O.R.S HYPERCHARGE, the activation: a core-power protocol that applies the scene-long buff and
## READIES every intact Loading weapon on the spot.
##
## RULING 6 IS WHY THE RELOAD IS HERE AND NOT IN THE BUFF. "Ignore the Loading property" means the
## weapon behaves as if it never had it, so an empty Loading weapon is readied the moment the protocol
## resolves. The buff could not do this one whatever we wanted: it only ever reacts to a FIRING, and
## this reload has to land before the first shot under the protocol. The heat cost, by contrast,
## applies only to shots fired AFTERWARDS, which is exactly what a reacting buff is for.
##
## WHAT THE RELOAD IS ACTUALLY WORTH, NARROWLY: it readies a weapon left empty on a PREVIOUS turn,
## saving the M/K2 a Stabilize. That is the whole of it, because the protocol can only ever be
## activated before this turn's first shot.
##
## IT IS NOT, as an earlier version of this comment claimed, protection against "punishing the obvious
## order of play (shoot, then hypercharge)". Shoot-then-hypercharge in one turn is not punished, it is
## REFUSED: firing is a non-protocol, non-reaction action, so it ends the protocol phase
## (unit_action.gd:268 via does_action_end_protocol_phase, :309-314), and unit_action.gd:144 then
## refuses the protocol outright with REASON.PROTOCOL. spec/test_ors_hypercharge.gd:180
## (test_the_protocol_is_refused_outside_the_protocol_window) asserts that refusal, and it was
## measured on the way in: written as shoot-then-hypercharge inside one turn,
## test_activating_it_reloads_an_empty_weapon aborted with `[ Gear not available ] reason : protocol`
## (.superpowers/sdd/task3-green-1.log) - which is why that test flips the turn in the middle.
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
