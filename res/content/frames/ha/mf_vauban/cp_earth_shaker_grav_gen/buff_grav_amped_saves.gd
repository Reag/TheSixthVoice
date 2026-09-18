## The +1 difficulty half of GRAV-AMPED INTERFERENCE: "Saves you force are made with +1 Difficulty."
##
## QUOTED AS SHIPPED, NOT AS THE LCP SPELLS IT. Bel's sheet reads "+1 Difficultly"; the author
## escalated that typo under the LCP-verbatim directive and it ships corrected (ruling R1, 2026-09-18
## frame close). Recorded here so a later reader diffing the card against the sheet knows the
## divergence is deliberate.
##
## THIS BUFF IS ON THE HOSTILE, NOT ON THE VAUBAN, AND IT HAS TO BE. UnitHasecheck.roll_check reads
## Buff.TO.SAVE buffs from the SAVER and only from the saver: the live read is unit_hasecheck.gd:186,
## and the three lines below it are commented out (:187-189), of which :188-189 are the two that would
## also have read the forcer's. What it hands those buffs is a context
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
## THE CONTEXT VALIDITY GATE IS BELT-AND-BRACES, NOT LOAD-BEARING - corrected at the close,
## 2026-09-18, because the header used to claim the opposite and two other documents copied it.
## UnitCondition.does_buff_apply is a short-circuit `and` chain that asks
## is_buff_context_valid_for_passive (unit_condition.gd:848) and then check_if_passive_applies (:849),
## and it is the only caller of the first in engine/ content/ ui/. The no-forcer case it is supposed
## to catch - a PLAIN CHECK reaches roll_check with no forcing_action, so context.unit is never filled
## in (unit_hasecheck.gd:180) - is already answered two lines below by check_if_passive_applies's own
## `if not Unit.is_valid(forcer): return false`, and Context.unit is a plain typed var that is simply
## left null, so there is nothing to throw on either. Neutralising this override to `return true`
## reddens NOTHING, including
## test_a_save_with_no_valid_forcer_is_untouched_and_does_not_throw - that test pins the guard BELOW,
## and neutralising THAT is what reddens it. The override stays because it is free and it states the
## contract; it is just not the thing holding the roof up.
extends BuffSkillSave

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) # the FORCER; absent on an unforced check

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false # all_save_types, so this is a formality
	var forcer:Unit = context.unit
	if not Unit.is_valid(forcer): return false # THE load-bearing no-forcer guard - see the header
	var vauban:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(vauban): return false
	return forcer.get_owner_unit_or_self() == vauban
