## HYPERFOCUS'S RANGE WAIVER ON THE THORN (Purple Thorn SP3 Task 2, ruling 12): "they always count as
## within range of your ranged weapons". HIDDEN, MANUAL.
##
## ACTION_TILES with boolean = true ADDS tiles to the targeting set after the range and LOS filters
## (unit_targeting.gd modify_action_tiles_from_buffs) - the Monarch's Seeking Payload and the Metahook
## are the vanilla users. The context is {unit, gear, action}: no target, hence the stored id.
##
## RANGE ONLY (author, ruling 12): the focus's tiles are intersected with the Thorn's Line of Sight,
## so a focus behind a wall stays out of reach - UNLESS the weapon itself does not require LOS
## (SEEKING, action_attack_weapon.gd requires_line_of_sight), in which case nothing is taken away
## that the weapon would not have waived anyway.
##
## "Ranged weapons" = UnitAction.is_ranged_weapon (a weapon attack that is not MELEE); a melee weapon
## and every tech action get nothing.
extends Buff

const Hyperfocus := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_pinpoint_mark/hyperfocus.gd')

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return context.map != null and Unit.is_valid(context.unit) and Action.is_valid(context.action)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not UnitAction.is_ranged_weapon(context.action, context.gear): return false
	return Hyperfocus.focus_of(core.get_owner_gear(context.map), context.map) != null

func get_values(core:BuffCore, context:Context) -> Context:
	var tiles := Tile.create_blank_bitwise_array()
	var focus := Hyperfocus.focus_of(core.get_owner_gear(context.map), context.map)
	if focus != null:
		Tile.add_array_to_bitwise_array(tiles, focus.occupied_tiles())
		var specific := SpecificAction.from_context(context)
		if SpecificAction.is_valid(specific) and context.action.requires_line_of_sight(specific):
			tiles = Tile.bitwise_array_intersection(tiles, UnitTile.get_tiles_in_los(context.unit, context.unit.tile()))
	return Context.create({object = tiles, boolean = true})
