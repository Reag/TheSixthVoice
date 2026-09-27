## MOBILIZED HYDRAULICS (Shackleton), the payload: +2 EXTRA_KNOCKBACK for the attack the trait armed.
## The Juggernaut talent's buff_momentum_knockback.gd is the shape.
##
## UNGATED (get_values leaves `boolean` false): action_attack_weapon.gd:327-331 adds a gated value
## only when the weapon already had knockback, and the card says the attack GAINS Knockback 2, so a
## weapon with none gets 2 and the Ram's 1 becomes 3. NOT is_onetime - see onhit_mobilized_hydraulics.gd
## for why the arming is a stamp on the attack's DeclaredAttackSummary rather than a buff consumed per
## target. action_attack_weapon.on_hit asks for EXTRA_KNOCKBACK with the attack's own context, whose
## resource IS that summary (:320, :325), so only the attack that was armed is read as armed.
extends Buff

const ARMED_META := &'reag_hydraulics_armed'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	return DeclaredAttackSummary.is_valid(context.resource) and context.resource.has_meta(ARMED_META)

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({number = 2})
