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
##     rather than to everyone;
##   - the OWNER clause (context.target_unit is the Blush) is what stops it firing the OTHER way
##     round. Without it, the Blush attacking its own victim would find the victim invisible, because
##     the summary would pick the chip up off the DEFENDER and never ask who put it there.
##
## The owner clause is the one with no obvious symptom until it bites, and
## test_the_blush_attacking_the_fooled_enemy_is_unaffected is its guard.
##
## NOT is_onetime, WHICH IS WHAT MAKES IT LAST THE SCENE.
## AttackUtil.check_if_invisibility_forces_miss (attack_util.gd:59-76) consumes only one-time buffs,
## so a persistent one keeps applying to every attack its holder makes at the Blush. `until = MANUAL`
## does the rest: nothing expires it, and `from_gear` being the core Kit means it dies with the mech
## that placed it.
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
