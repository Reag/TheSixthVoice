## GEMINI CHARGE: narrow the redirect's picker to what the leg may actually reach (ruling 12).
##
## The picker is vanilla's own, on a proxy at the leg's start, with a duplicate of the weapon - so left
## alone it offers the contact itself (standing on the proxy's tile), the Knot, and anyone already
## attacked (Spike 8 test c), and for a Line any aim at all. buff_gemini_charge stamps the set it measured
## onto that duplicate, and this answers ACTION_TILES for it with boolean = false: an INTERSECTION, so the
## offered set can only shrink (unit_targeting.gd:164-184). No other action carries the stamp, so every
## other targeting prompt the Knot sees is untouched. Read from the proxy's owner - the Knot
## (get_owner_unit_or_self).
extends Buff

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
	return context.action != null and context.action.has_meta(Record.LEG_TILES)

func get_values(_core:BuffCore, context:Context) -> Context:
	return Context.create({
		object = context.action.get_meta(Record.LEG_TILES),
		boolean = false, # intersect: only these
	})
