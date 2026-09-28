## GEMINI CHARGE, "this counts as one attack": hands the attack pipeline onhit_gemini_one_attack, which
## makes every target of a Gemini attack read the Knot's one-time roll buffs and consumes them once,
## after the whole attack (Pass F task 11c; the effect's header has the mechanism).
##
## A Buff.TO.ONHIT_EFFECT carrier (the RPA Pullback's shape, buff_rpa_pullback_pull.gd): both the
## per-target attack (event_unit_attack.gd:47-49) and the declared attack
## (event_unit_attack_declared.gd:42-44) collect it with the attack's own context, so the effect's
## on_attack and on_resolution are both reached. Permanent and hidden like the other Gemini buffs; it
## answers only when the Knot is the attacker and Gemini recorded the declared attack. The weapon-type
## gate of the archetype is replaced: the record is the whole condition.
extends BuffWeaponTypeOnHit

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var holder:Unit = core.get_holder_unit(context.map)
	if not Unit.is_valid(holder) or not Unit.is_valid(context.unit): return false
	if context.unit.get_attacker(context) != holder: return false
	return not Record.record_of(context.resource).is_empty()
