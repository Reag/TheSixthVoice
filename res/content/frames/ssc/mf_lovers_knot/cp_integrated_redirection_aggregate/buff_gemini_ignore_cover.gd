## GEMINI CHARGE: suppress the cover the ENGINE measures for a redirected target (ruling 10).
##
## PreAttack.create measures every target's cover from the declared attack's single source_voxels -
## the Knot's (attack_roll.gd:118-119, :158) - which for a redirected shot is the wrong place. An
## attacker-side IGNORE_COVER skips that calculation outright (:131, :156); scoped to the targets
## buff_gemini_charge recorded, it leaves the contact's cover and every other attack untouched.
## buff_gemini_shared_roll then puts on the cover measured from the leg's own start.
##
## Also queried from the TARGET side (:161) and from anywhere else that asks the Knot for IGNORE_COVER,
## so it answers only when the Knot is the attacker and the target is one it redirected to.
extends Buff

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var holder:Unit = core.get_holder_unit(context.map)
	if not Unit.is_valid(holder) or not Unit.is_valid(context.unit): return false
	if context.unit.get_attacker(context) != holder or context.target_unit == holder: return false
	return Record.is_redirected(context.resource, context.target_unit)
