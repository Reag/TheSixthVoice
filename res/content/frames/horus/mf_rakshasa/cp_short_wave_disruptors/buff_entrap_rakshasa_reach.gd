## ENTRAP'S REACH (design 3.1, ruling 25): "Targets affected this way always consider you within range,
## threat, and line of sight." HIDDEN, on the entrapped unit, owned by the Rakshasa's core gear.
##
## ACTION_TILES with boolean = true ADDS the Rakshasa's occupied tiles to the holder's targeting set,
## after the range, Blinded and line-of-sight filters (unit_targeting.gd modify_action_tiles_from_buffs).
## The Hyperfocus waiver (buff_hyperfocus_range.gd) WITHOUT its last step: no line-of-sight intersection,
## because the card waives sight too. The AI reads the same set (ai_action_decider.gd:130).
##
## ATTACKS ONLY: weapon and tech attacks (ActionAttack). A system that merely targets gets nothing.
## HIDDEN AND INVISIBLE STILL PROTECT the Rakshasa: get_tiles_targetable keeps a tile only for a unit
## the action can_target_unit, which refuses a Hidden enemy (action.gd:219).
##
## Its REACTIONS never read this set (unit_relation.gd:227-267), which is why their waiver lives in
## unit_relation.gd_ext.gd, keyed on the visible buff_entrap_rakshasa.
extends Buff

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return context.map != null and Unit.is_valid(context.unit) and Action.is_valid(context.action)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	return context.action is ActionAttack and Unit.is_valid(core.get_owner_unit(context.map))

func get_values(core:BuffCore, context:Context) -> Context:
	var tiles := Tile.create_blank_bitwise_array()
	var rakshasa:Unit = core.get_owner_unit(context.map)
	if Unit.is_valid(rakshasa): Tile.add_array_to_bitwise_array(tiles, rakshasa.occupied_tiles())
	return Context.create({object = tiles, boolean = true})
