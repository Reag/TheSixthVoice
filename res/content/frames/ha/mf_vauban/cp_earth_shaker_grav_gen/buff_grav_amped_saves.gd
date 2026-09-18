## The +1 difficulty half of GRAV-AMPED INTERFERENCE: "Saves you force are made with +1 Difficultly."
##
## THIS BUFF IS ON THE HOSTILE, NOT ON THE VAUBAN, AND IT HAS TO BE. UnitHasecheck.roll_check reads
## Buff.TO.SAVE buffs from the SAVER and only from the saver - the two lines that would also have read
## the forcer's are commented out (unit_hasecheck.gd:186-189). What it hands those buffs is a context
## carrying target_unit = the saver and, when the save was forced by somebody, unit/gear/action copied
## off the forcing action (:174-184). So the only way to write "saves YOU force" is a chip on everyone
## who might have to save, which asks who is forcing. The Assassin's Mark does exactly this
## (buff_assassins_mark_save_accuracy.gd) and the Minotaur's Maze is the other precedent.
##
## "SAVES YOU FORCE" IS OWNER-OR-SELF (design ruling 9, the author's call). The forcer arrives as
## context.unit, and get_owner_unit_or_self (unit.gd:270-273) turns a thing the Vauban owns into the
## Vauban - which is how the engine itself reads a forcer in UnitCondition.forced_save
## (unit_condition.gd:71). So a Grounding Charge mine or a Tesseract drone from the Iskander licence
## forcing a save is the Vauban forcing a save, and the licence's own gear synergises with the core.
## Measured by the SP2 probe; test_a_save_forced_by_a_mine_the_vauban_owns_is_at_plus_one_difficulty
## is the pin.
##
## WHICH VAUBAN. core.get_owner_unit(context.map) is the unit whose aura hung this chip, not "a
## Vauban" - two Vaubans on one side each hang their own chip and each answers for its own saves.
## (Their chips share a compcon_id, so PassiveAura.apply_aura_buffs_to_unit's "they already have it,
## from any source" check at passive_aura.gd:80 means the SECOND Vauban's chip is never applied while
## the first one's is held. That is the same one-chip-for-two-Vaubans behaviour SP1 recorded for
## Gravity Well and Sap's reprieve, and it is an author note for the close, not a defect to fix here.)
##
## THE CONTEXT VALIDITY GATE IS NOT OPTIONAL. UnitCondition.get_buffs_to asks
## is_buff_context_valid_for_passive before check_if_passive_applies, and a PLAIN CHECK - as opposed
## to a forced save - reaches roll_check with no forcing_action at all, so context.unit is absent
## (unit_hasecheck.gd:180). Without this gate the chip would be asked about a context it cannot
## answer.
extends BuffSkillSave

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) # the FORCER; absent on an unforced check

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false # all_save_types, so this is a formality
	var forcer:Unit = context.unit
	if not Unit.is_valid(forcer): return false
	var vauban:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(vauban): return false
	return forcer.get_owner_unit_or_self() == vauban
