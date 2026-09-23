## HYPERFOCUS'S CHIP ON THE THORN (Purple Thorn SP3 Task 2, rulings 12-13). VISIBLE, MANUAL.
##
## THE +1: a BuffBonus on attack_roll, flat +1 (the .tres, the Death's Head's shape), applying only
## when the attack's target IS the stored focus - the attack context carries no link to the focus,
## hence the stored id (Mark for Death's buff_mark_for_death_damage.gd:13-16). Weapon and tech
## attacks alike: "+1 to attack rolls against them" is unqualified.
##
## "THIS EFFECT ENDS IF YOU TAKE ANY ACTIONS THAT AFFECT A DIFFERENT HOSTILE CHARACTER" - ATTACKS
## ONLY. attack_declared POST where the Thorn is the attacker and the declared summary's
## all_attacked_units (declared_attack_summary.gd:9) holds a hostile character (is_actor, ruling 16)
## other than the focus: a miss, a Blast catch, a reaction shot (Stalk the Horizon) and an invade all
## count. An attack on an ally does not. The second half of ruling 13 - a tech SYSTEM aimed at another
## hostile (Lock On) - was DROPPED by the SP3 probe (test_spike_purple_thorn_sp3_seams.gd): a
## player's pick never reaches UNIT_ACTION POST's target_units. Rulings row, 2026-09-23.
##
## "UNLESS THE CURRENT TARGET IS DESTROYED": the death trigger, Mark for Death's shape
## (buff_mark_for_death_damage.gd:42-46) with one correction - vanilla asks whether the focus is still
## on the map, which at queue time it still is (measured here: that form left the chip standing after
## the focus died). Ours matches the dying unit instead - test_the_focus_dying_ends_it_and_frees_the_pick.
##
## activate is overridden: a triggered buff consumes itself by default (buff.gd:254-255), and ending
## is hyperfocus.gd's job, which takes the other two buffs and the stored id with it.
extends BuffBonus

const Hyperfocus := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/hyperfocus.gd')

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super(core, context) and context.map != null and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	var focus := Hyperfocus.focus_of(core.get_owner_gear(context.map), context.map)
	return focus != null and context.target_unit == focus

func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var gear := core.get_owner_gear(unit.map)
	var focus := Hyperfocus.focus_of(gear, unit.map)
	var context := triggering_event.context
	if not DeclaredAttackSummary.is_valid(context.resource):
		# The death trigger. DEATH POST is queued BEFORE the unit is removed (event_unit_die.gd:80-83)
		# and triggers are evaluated at QUEUE time (reaction_bus.gd:61), so the dying focus still
		# reads as alive here: match the dying unit against the stored id. focus == null covers a
		# focus that left the map some other way.
		if focus == null: return true
		return Unit.is_valid(context.unit) and context.unit == focus
	if context.unit != unit: return false
	for attacked:Unit in context.resource.all_attacked_units:
		if not Unit.is_valid(attacked) or attacked == focus: continue
		if attacked.is_actor() and UnitRelation.are_enemies(unit, attacked): return true
	return false

func activate(core:BuffCore, activation:EventCore) -> void:
	var map:MapState = X.map()
	Hyperfocus.end_focus(activation, core.get_owner_unit(map), core.get_owner_gear(map))
