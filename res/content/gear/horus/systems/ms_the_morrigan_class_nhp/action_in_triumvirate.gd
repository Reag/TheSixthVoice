## IN TRIUMVIRATE: the Morrígan names a partner. Design ruling 23, section 4.2.
##
##   "Quick Tech. Choose an allied character within Sensors. Until the end of your next turn, your
##    chosen ally is always treated as being adjacent to you while within your Sensors, regardless
##    of actual distance between you, and all attacks against them gain +1 difficulty."
##
## ActionSystemTargetUnit does the targeting: target_range_is_sensors reads the LIVE Sensors
## (unit.get_sensor_range(), so Inexorable Formation counts), can_target_enemies false, self false,
## requires_target_character - the archetype's is_character(), which INCLUDES a drone: the Crown's
## ruling (author, 2026-09-21) on this same archetype, PROPOSED for the frame close beside the
## trigger-side is_actor() reading. HEAT SELF 2 is self_heat_dice = "2" on the .tres, rolled by
## spend_actions -> UnitAction.gain_self_heat (unit_action.gd:229, :291-294).
##
## THREE BUFFS, ALL from_gear THIS NHP, ALL END_OF_OWNERS_NEXT_TURN:
##  - buff_in_triumvirate_pair on the SLUAGH, state partner = the ally's id;
##  - buff_in_triumvirate_pair on the ALLY, state partner = the Sluagh's id;
##  - buff_in_triumvirate_ward on the ALLY.
## Two pair cores because is_adjacent is one-sided (unit_relation.gd:7-8, spike measured).
## action_project_shield.gd is the vanilla shape: BuffCore.create + set_state + apply_buff_alt.
##
## RE-TARGETING CLEARS THE PREVIOUS PAIR FIRST (fork 4): every unit is walked with
## clear_buffs_owned_by(this gear) - the clear_all_previous_buffs idiom
## (action_system_apply_buff.gd:130-132) - so the Sluagh never holds two partners.
##
## THEN THE TRACKING REFRESH, BY HAND. The Mark's soft-cover aura asks is_adjacent and re-evaluates
## only from UnitTile.update_tracking_and_statuses (unit_tile.gd:15-24) or from buffs applied by
## aura-bearing gear (unit_condition.gd:713-715); this Kit holds no aura. Ruling 23's last sentence.
extends ActionSystemTargetUnit

const PAIR := &'buff_in_triumvirate_pair'
const WARD := &'buff_in_triumvirate_ward'
const PARTNER_KEY := 'partner'   # buff_in_triumvirate_pair.gd reads the same key


func activate_for_target(context:Context, activation:EventCore, target_unit:Unit) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not Unit.is_valid(target_unit) or not GearCore.is_valid(gear): return

	# THE ABORT COMES FIRST, and the order is the point: it used to sit after the clear loop, where
	# a unit lost between targeting and here would leave the PREVIOUS pair cleared and no new pair
	# applied - the card would have un-paired the Sluagh for nothing. Nothing is torn down until the
	# activation is known to be good.
	if activation.abort_without_units([unit, target_unit]): return

	# Fork 4: one partner at a time.
	for other:Unit in context.map.get_all_units():
		UnitCondition.clear_buffs_owned_by(activation, other, gear.persistent_id)

	var on_sluagh := BuffCore.create(ContentLibrary.get_buff(PAIR), gear.persistent_id)
	on_sluagh.set_state(PARTNER_KEY, target_unit.core.persistent_id)
	UnitCondition.apply_buff_alt(activation, unit, on_sluagh)

	var on_ally := BuffCore.create(ContentLibrary.get_buff(PAIR), gear.persistent_id)
	on_ally.set_state(PARTNER_KEY, unit.core.persistent_id)
	UnitCondition.apply_buff_alt(activation, target_unit, on_ally)

	UnitCondition.apply_buff_alt(activation, target_unit, BuffCore.create(ContentLibrary.get_buff(WARD), gear.persistent_id))

	# The aura re-read (ruling 23).
	UnitTile.update_tracking_and_statuses(context.map, activation)
