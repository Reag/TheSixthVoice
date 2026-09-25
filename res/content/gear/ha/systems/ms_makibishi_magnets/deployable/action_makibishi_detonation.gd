## THE MAKIBISHI MINE GOING OFF (design 3.1, rulings 24-25):
##
##   "When a character moves over or adjacent to this mine, they must make an Agility save or it
##    attaches to them and deals 1d3 AP Kinetic damage."
##
## VANILLA'S MINE, THE MESMER'S SHAPE (action_mesmer_mine_detonation.gd): the shared trigger
## (action_mine_trigger.tres - within 1, allies too, which is ruling 25's friendly fire) activates
## this with the triggering move as its event; the base class finds the triggering unit, filters
## Repulser-style IGNORE_MINES holders, plays the fx and hands over. Unlike the Mesmer's burst, only
## the TRIGGERING CHARACTER is reached - "they must make" - so get_target_units returns it alone.
##
## THE MAGNET COMES FROM THE MAKIBISHI KIT, NOT FROM THE MINE (ruling 25): the mine's owner is the
## Koremasa and its owner gear the Kit that laid it (UnitAction.set_deployable_owner), so the attached
## buff carries the Kit's persistent id - the victim's detach saves against the Koremasa, and a mine's
## magnet and a thrown one replace each other. The save is made against the mine's own specific,
## which inherits the owner's save target (unit_action.gd:525). The damage is the mine's, which
## generate_damage_events blames on the owner (common_action_util.gd:83-84).
extends ActionSystemMineDetonation

const ATTACHED := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ha/systems/ms_makibishi_magnets/buff_makibishi_attached.tres')

func get_target_units(_burst_tiles:Array[Vector2i], triggering_unit:Unit) -> Array[Unit]:
	var targets:Array[Unit] = []
	if Unit.is_valid(triggering_unit) and triggering_unit.is_character(): targets.append(triggering_unit)
	return targets

func activate_detonation_effects(all_targets:Array[Unit], forcing_action:SpecificAction, _burst_tiles:Array[Vector2i], activation:EventCore) -> void:
	var mine:Unit = forcing_action.unit
	var kit_gear:GearCore = mine.get_owner_gear() if Unit.is_valid(mine) else null
	for target:Unit in all_targets:
		if not Unit.is_valid(target): continue
		var passed:bool = await UnitHasecheck.make_save(activation, target, forcing_action, Lancer.HASE.AGI, [Lancer.STATUS.IMPAIRED])
		if not Unit.is_valid(target) or passed: continue
		UnitCondition.apply_buff(activation, target, ATTACHED, kit_gear)
		CommonActionUtil.queue_damage_events(
			activation, forcing_action, [target],
			Dice.roll_string('1d3'), Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP]
		)
