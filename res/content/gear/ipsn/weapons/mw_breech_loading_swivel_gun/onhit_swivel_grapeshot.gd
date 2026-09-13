## The Grapeshot profile's on-hit effect: Hull save or Shredded.
##
## The save/status wiring itself (save_to_avoid, save_type, statuses) is declarative on the .tres,
## and the engine's base OnHitEffect already does the actual work: should_abort()
## (on_hit_effect.gd:67-73) rolls the save and, on a pass, returns true - which skips
## apply_statuses_and_buffs entirely, so a passed save never applies Shredded at all.
##
## WHOLE-BRANCH REVIEW, FINDING 1 (2026-09-13): the override below returns
## Lancer.UNTIL.END_OF_NEXT_TURN, and content/statuses/status_shredded.tres already declares
## standard_until = 1, which IS END_OF_NEXT_TURN (lancer.gd:46-48). So this override changes NOTHING
## about the shipped behaviour - it returns exactly what OnHitEffect's own default
## (StatusType.get_standard_until(status), on_hit_effect.gd:89-91) would already have answered. The
## header used to claim this hook was "the one hook OnHitEffect does NOT already implement to the
## design's wording" - that is false, and is corrected here.
##
## KEPT ANYWAY, DELIBERATELY: this is now a declaration, not a behavioural change. It pins ruling
## 10's decided value against a future edit to status_shredded.tres's standard_until - if vanilla
## ever changes Shredded's default duration, the Grapeshot's own clause ("until the end of your next
## turn") must not silently move with it. The measured-evidence section below is exactly why this
## particular value was chosen, and it is still true and still worth keeping. Precedent for an
## OnHitEffect subclass in this mod: onhit_knock_em_down.gd (mt_knock_em_down).
##
## test_swivel_gun.gd's test_the_shredded_duration_pins_the_override_directly asserts this method's
## return value straight off the loaded .tres - THAT is what actually pins the mod's own decision;
## the four-turn integration test below it only proves the engine currently honours it.
##
## RULING 10 (2026-09-13), AND THE RESULT ACTUALLY MEASURED.
##
## Tried first as Lancer.UNTIL.END_OF_OWNERS_NEXT_TURN, per the design and ruling 10's stated first
## choice. lancer.gd:52 comments that value as "not fully implemented for statuses; will clear at
## end of NEXT owner end turn they see." A real run of test_swivel_gun.gd's
## test_the_shredded_duration_is_the_ruled_boundary, with this override returning
## END_OF_OWNERS_NEXT_TURN, printed `survived_firer_turn_end=false`: Shredded was gone the moment
## the FIRER's own turn ended - the SAME turn Grapeshot was fired in - not at the end of the firer's
## NEXT turn as the clause and the enum's own comment both describe.
##
## Reading why, in unit_condition.gd: clear_owners_turn_statuses (called from
## content/events/event_turn_end.gd's handle_ending_unit, once per unit whose turn ends) gates a
## BUFF's clearing on `buff.turn_count <= 0` so a buff survives at least one full turn - but the
## STATUS branch six lines below it (unit_condition.gd:65-67) carries no such gate at all, and
## clears any status with `until == owner_until` and this ending unit as its owner unconditionally,
## the very first time that owner's turn ends. So the warning is right and the enum comment's own
## description of the behaviour is not: it does not "clear at end of NEXT owner end turn", it clears
## at the very NEXT owner-end-turn event full stop, counting from whenever the status was applied -
## which, for a status applied mid-turn by the owner's own action, is the end of that SAME turn.
##
## FALLBACK TAKEN, PER RULING 10: Lancer.UNTIL.END_OF_NEXT_TURN - "until the end of your next turn"
## read from the TARGET's own seat, the way vanilla's Shredded-on-hit precedents already phrase it
## everywhere (the Raleigh's action_m35_mjolnir.gd, and every npcf_*.gd hit/crit Shredded effect in
## the base game). This is the ordinary status-expiry path (unit_condition.new_turn_for_statuses /
## end_turn_for_statuses), and the same test - rerun against this value - confirmed it survives the
## firer's own turn ending, survives to the start of the TARGET's own next turn, and clears at the
## end of the TARGET's own next turn: the exact "until the end of your next turn" boundary the
## design clause means, just measured from the victim rather than the Fitzgerald.
extends OnHitEffect

func get_applied_duration_for_statuses(status:StringName, context:Context, attacked_unit:Unit) -> Lancer.UNTIL:
	return Lancer.UNTIL.END_OF_NEXT_TURN
