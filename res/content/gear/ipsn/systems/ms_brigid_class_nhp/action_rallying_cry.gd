## RALLYING CRY: Brigid pulls an ally back together. Hazard design ruling 14, section 4.2.
##
##   "Quick Action. 1/scene, expend a charge and choose an allied mech character within sensors.
##    They clear Impaired, Shredded, and Slowed if they weren't self-inflicted. If they are prone,
##    they stand up. They also clear 1d6+1 Heat."
##
## ActionSystemTargetUnit does the targeting: target_range_is_sensors reads the LIVE Sensors,
## can_target_enemies false, self false. The charge is the default consumes_charges (the Kit's
## charges_max 4) and 1/scene is the Kit's uses_per_scene 1 (unit_action.gd:147) - both spent by
## spend_actions, which the archetype calls before activate_for_target.
##
## "AN ALLIED MECH CHARACTER" IS is_mech(), NARROWED HERE. The archetype's requires_target_character
## is is_character(), which is TRUE of a drone (unit.gd:116); the card says mech, so the override
## asks is_mech() (:118), which also refuses a pilot on foot. can_target_unit is both the player's
## picking filter (action.gd:214) and the filter on a target handed straight to the plan
## (target_action_util.gd:172) - In Triumvirate's header has the long form. Self is refused here as
## well as by the archetype's can_target_self: the card says "allied", and the mod names "you or"
## when self is meant (Eyes of Night).
##
## "IF THEY WEREN'T SELF-INFLICTED" IS clear_status_via_ability'S OWN RULE: ability_can_clear keeps a
## status whose source is a gear on the unit's own loadout (unit_condition.gd:472-477,
## status_condition.gd:41-44) and clears every other source, sourceless included. (The function
## drops its own can_clear_self_applied argument at :482 - a vanilla slip that happens to be exactly
## this card's rule.)
##
## PRONE IS A SEPARATE CALL, because Prone is not a condition to the engine and
## clear_status_via_ability can never clear it. clear_status directly, as Remote Reboot does
## (action_remote_reboot_support.gd:34-35). The card puts no self-inflicted clause on the stand-up.
##
## THE HEAT: 1d6+1 rolled once here and queued as event_unit_cool, which caps it at current heat
## (event_unit_cool.gd:29) and refuses outright at 0 heat. Every step is unconditional on the others:
## a target with nothing to clear still costs the charge and the scene's use.
extends ActionSystemTargetUnit

const CLEARED:Array[StringName] = [Lancer.STATUS.IMPAIRED, Lancer.STATUS.SHREDDED, Lancer.STATUS.SLOWED]
const HEAT_CLEARED := '1d6+1'


func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super(potential_target, specific): return false
	if potential_target == specific.unit: return false
	return potential_target.is_mech()


func activate_for_target(context:Context, activation:EventCore, target_unit:Unit) -> void:
	if activation.abort_without_units([context.unit, target_unit]): return

	for status:StringName in CLEARED:
		UnitCondition.clear_status_via_ability(activation, target_unit, status)

	if target_unit.has_status(Lancer.STATUS.PRONE):
		UnitCondition.clear_status(activation, target_unit, Lancer.STATUS.PRONE)

	activation.queue_event(&'event_unit_cool', {
		unit = target_unit,
		number = Dice.roll_string(HEAT_CLEARED),
	})
