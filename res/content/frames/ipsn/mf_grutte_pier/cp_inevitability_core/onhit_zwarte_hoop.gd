# ZWARTE HOOP's "Increase your Overshield by +1 on hit" and "Clear +1 heat on hit" (design ruling 13).
#
# ONCE, ON THE FIRST HIT. On-hit effects run per hit target (event_unit_attack.gd:83-87); the card
# speaks of "the attack", so the counts on the DeclaredAttackSummary are paid out the first time any
# roll hits and then marked done. Overshield is ADDITIVE ("increase ... by"), the shared helper's
# increase (overshield.gd); the heat is event_unit_cool on the Pier, a no-op at 0 heat.
extends OnHitEffect

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const META := &'reag_zwarte_hoop_onhit'

func on_hit(activation:EventCore, _attacked_unit:Unit) -> void:
	var declared = activation.context.resource
	if not DeclaredAttackSummary.is_valid(declared) or not declared.has_meta(META): return
	var counts:Dictionary = declared.get_meta(META)
	if counts.get('done', true): return
	counts.done = true
	declared.set_meta(META, counts)
	var pier:Unit = activation.context.unit
	if not Unit.is_valid(pier): return
	if counts.get('overshield', 0) > 0:
		await Overshield.increase(activation, pier, counts.overshield)
	if counts.get('heat', 0) > 0:
		activation.queue_event(&'event_unit_cool', {unit = pier, number = counts.heat})
