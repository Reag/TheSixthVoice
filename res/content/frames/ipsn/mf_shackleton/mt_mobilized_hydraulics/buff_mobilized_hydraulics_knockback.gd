## MOBILIZED HYDRAULICS (Shackleton), the payload: +2 EXTRA_KNOCKBACK while the trait is armed for the
## attack in progress. The Juggernaut talent's buff_momentum_knockback.gd is the shape.
##
## UNGATED (get_values leaves `boolean` false): action_attack_weapon.gd:327-331 adds a gated value
## only when the weapon already had knockback, and the card says the attack GAINS Knockback 2, so a
## weapon with none gets 2 and the Ram's 1 becomes 3. NOT is_onetime - see onhit_mobilized_hydraulics.gd
## for why the arming is a state flag cleared at on_resolution rather than a buff consumed per target.
extends Buff

const ARMED_KEY := 'armed'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return bool(trait_gear.get_state(ARMED_KEY, false))

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({number = 2})
