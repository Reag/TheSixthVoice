## The chip a character wears after failing Step of Mist and Thunder's Systems save: for the rest of
## the scene it treats the Maiden's Blush as Invisible.
##
##   "Characters adjacent to the space you teleport to must make a Systems save or treat you as
##    Invisible until the end of the scene."
##
## TWO CLAUSES, AND BOTH ARE LOAD-BEARING FOR DIFFERENT REASONS.
## UnitCondition.get_invisibility_summary (unit_condition.gd:446-469) collects TREAT_AS_INVISIBLE
## buffs off BOTH context units with the same context - "EITHER unit can either 'count as invis' or
## 'treat target as invis'", in its own words - and it does not track whose buffs are whose. So:
##
##   - the HOLDER clause (context.unit is us) is what makes the chip belong to the fooled character
##     rather than to everyone: only the character that failed the save misses because of it;
##   - the OWNER clause (context.target_unit is the Blush) is what keeps the chip pointed at ONE
##     mech. MEASURED 2026-09-17, and NOT what an earlier draft of this header claimed: removing it
##     does not let the Blush find its own victim invisible, because the holder clause already
##     refuses that - the Blush is not the chip's holder. What only the owner clause stops is a
##     character fooled by one Maiden's Blush treating a DIFFERENT one as invisible, having never
##     been adjacent to anything the second one did.
##
## So the guards are test_a_chip_from_one_blush_does_not_hide_a_second_one for the owner clause, and
## test_the_blush_attacking_the_fooled_enemy_is_unaffected for the chip's one-directionality as a
## whole - that one reddens only when BOTH clauses go, because either alone refuses it.
##
## NOT is_onetime, WHICH IS WHAT MAKES IT LAST THE SCENE.
## AttackUtil.check_if_invisibility_forces_miss (attack_util.gd:59-76) consumes only one-time buffs,
## so a persistent one keeps applying to every attack its holder makes at the Blush. `until = MANUAL`
## does the rest: nothing expires it.
##
## THE ONE EARLY EXIT IS THE BLUSH'S OWN DESTRUCTION, AND IT IS NOT `from_gear`, which is an id
## rather than a lifetime: BuffCore.create stores a string and nothing sweeps on it
## (buff_core.gd:26-31). What clears the chip is EventService.remove_unit_from_game, which walks the
## dead unit's own gear and drops the buffs it owns off every other unit (event_service.gd:71 ->
## UnitCondition.clear_outgoing_buffs_from_unit -> clear_buffs_owned_by, unit_condition.gd:1015-1021).
## A cp_ Kit is inside that walk because loadout_core.get_all_gear includes `traits`, and the walk
## skips a buff only when is_cleared_on_owner_death() is false - this one takes the default true
## (buff.gd:181). test_the_chip_dies_with_the_blush_that_placed_it is the guard.
##
## Thy Hubris' buff_tear_invisibility.gd is the in-house precedent for a context-gated
## TREAT_AS_INVISIBLE buff; this one is simpler, because its question is about identity rather than
## geometry.
extends Buff

## Both units, because both clauses below dereference one. get_buffs_to runs this for every buff on
## every unit involved in a roll, so an unguarded null here is an error storm rather than a wrong
## answer.
func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	if context == null: return false
	return Unit.is_valid(context.unit) and Unit.is_valid(context.target_unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var map:MapState = context.map
	# The attacker is the character that failed the save and wears this chip.
	if context.unit != core.get_holder_unit(map): return false
	# The defender is the Maiden's Blush that placed it - read through the SOURCE GEAR.
	#
	# THIS IS NOT REDUNDANT WITH THE HOLDER CLAUSE ABOVE, though it looks it, and the difference was
	# measured: removing it does NOT make the Blush's own attacks find its victim invisible (the holder
	# clause already refuses that, because the Blush is not the chip's holder). What it protects is a
	# SECOND Maiden's Blush - without it, a character fooled by Blush A would treat Blush B as invisible
	# too, having never been adjacent to anything B did.
	return context.target_unit == core.get_owner_unit(map)
