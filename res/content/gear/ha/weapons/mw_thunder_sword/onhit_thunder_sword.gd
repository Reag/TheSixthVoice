## THUNDER SWORD's chip lands on the damaged CHARACTER, not on whatever attacked_unit the sword
## happens to hit. The card says "the damaged character", which is is_character() - a drone included
## (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22): Unit.is_character() answers
## TRUE for a drone - its own comment says "active mech/pilot/drone" (unit.gd:116).
##
## THE BUG THIS FIXES: onhit_thunder_sword.tres was scriptless, on the bare engine OnHitEffect
## (onhit_rend_nexus.tres's own header is that in-mod precedent for going scriptless in the first
## place). apply_statuses_and_buffs (on_hit_effect.gd:76-88) hands buff_thunder_sword straight to
## UnitCondition.apply_buffs with attacked_unit as the target and NO character filter of its own
## (:88), so a hit that lands on a non-character (a wreck, a deployable) chips it exactly as if it
## were a character.
##
## THE GATE GOES IN should_abort, THE MODEL IS onhit_ddmr.gd / onhit_greenlight.gd's shape.
## apply_on_hits (on_hit_effect.gd:42-46) consults should_abort ONCE per effect, before EITHER
## apply_statuses_and_buffs or on_hit runs - it is the sole gate upstream of both. Aborting here,
## rather than filtering inside apply_statuses_and_buffs, also means a non-character hit never
## reaches the require_consume_lock check or a save_to_avoid roll that should_abort's own body would
## otherwise run (:57-72) - either would fire uselessly against a target the chip was never going to
## land on anyway. This card sets neither flag today, but the override sits where the engine's own
## contract puts the gate, not where this card happens to need the least code.
##
## NO STATUS TO PRESERVE: onhit_thunder_sword.tres's only non-default export is `buffs` - apply_on
## is STAGE.ON_HIT, the export's own default (on_hit_effect.gd:12), which is the only stage this
## override touches. A real character hit at ON_HIT still falls through to super(), unchanged.
extends OnHitEffect

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on and Unit.is_valid(attacked_unit) and not attacked_unit.is_character(): return true
	return await super(stage, activation, attacked_unit)
