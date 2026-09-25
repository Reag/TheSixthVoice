# ZWARTE HOOP's on-hit carrier (design ruling 13): hands onhit_zwarte_hoop to every roll of the
# declared attack (event_unit_attack.gd:47-49). Not BuffWeaponTypeOnHit: a tech attack takes the
# Overshield and heat picks too.
extends Buff

@export var effects:Array[OnHitEffect]

func get_values(_core:BuffCore, _context:Context) -> Context:
	return Context.create({array = effects})
