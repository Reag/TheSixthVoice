# LOAD MUNITIONS (Purple Thorn rank III, Hyper Engineered Munitions; SP4 Task 1, design ruling 14):
#
#   "Choose a mount that contains only ranged weapons: until the start of your next turn, whenever
#    you hit a hostile character with a weapon on this mount, the target takes 1 AP Kinetic damage
#    and must succeed on a Hull save or become Impaired until the end of their next turn."
#
# A PROTOCOL (action_type 4 in the .tres) on a plain self-targeted ActionSystem - the default
# get_target_requirements is already count = 0 (action_system.gd:55-60). The one prompt is a MOUNT
# PICKER: choice_bus.choose_from_gear_for over MountCores, which vanilla raises only inside
# structure damage (event_unit_structure.gd:206-229) and whose panel draws a mount natively
# (choice_gear_panel.gd). "May" is the picker's own cancel: a cancelled pick spends nothing.
#
# ELIGIBLE = every weapon action on the mount passes UnitAction.is_ranged_weapon, and there is at
# least one ("contains only ranged weapons" - an empty mount contains no ranged weapon to load).
# A mount holding a melee Aux beside a ranged one is out. Integrated weapons live in the loadout's
# `attacks`, not in `mounts`, so they are never offered.
#
# THE AI PICKS THE FIRST ELIGIBLE MOUNT WITHOUT A PROMPT - the structure event's own AI branch shape
# (it never prompts a non-player unit). The protocol is unavailable with no eligible mount at all.
#
# SPEND AFTER THE PICK (the ARC deactivation's FIX note: every concrete action calls spend_actions
# itself). The charge is the default consumes_charges. The chip (buff_loaded_munitions) carries the
# chosen mount's persistent_id in its state - a MountCore keeps its persistent_id across
# full_repair's loadout rebuild (mount_core.gd:71-72) - and does all the work from there.
extends ActionSystem

const CHIP := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_hyper_engineered_munitions/buff_loaded_munitions.tres')
const ChipScript := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_hyper_engineered_munitions/buff_loaded_munitions.gd')


## Every mount on `unit` that holds at least one weapon and nothing but ranged weapons, in loadout
## order. Static and pure; the specs read it.
static func eligible_mounts(unit:Unit) -> Array[MountCore]:
	var eligible:Array[MountCore] = []
	if not Unit.is_valid(unit): return eligible
	for mount:MountCore in unit.core.loadout.mounts:
		if is_all_ranged(mount): eligible.append(mount)
	return eligible

static func is_all_ranged(mount:MountCore) -> bool:
	if not MountCore.is_valid(mount): return false
	var weapons := 0
	for gear:GearCore in mount.get_gear():
		for action:Action in gear.kit.get_weapon_actions():
			if not UnitAction.is_ranged_weapon(action, gear): return false
			weapons += 1
	return weapons > 0

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return not eligible_mounts(unit).is_empty()

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_without_unit(unit): return
	var mounts := eligible_mounts(unit)
	if activation.abort_when(mounts.is_empty()): return

	var chosen = null
	if unit.is_player_controlled():
		chosen = await choice_bus.choose_from_gear_for({
			array = mounts,
			title = X.tr('battle.select_option'),
			can_voluntarily_cancel = true,
			whois = unit,
		})
	else:
		chosen = mounts[0]
	if activation.abort_without_unit(unit): return
	if activation.abort_when(not (chosen is MountCore) or not mounts.has(chosen)): return # cancelled; nothing spent

	spend_actions(activation)
	var chip := UnitCondition.apply_buff(activation, unit, CHIP, context.gear)
	if chip != null: chip.set_state(ChipScript.MOUNT_KEY, String(chosen.persistent_id))
