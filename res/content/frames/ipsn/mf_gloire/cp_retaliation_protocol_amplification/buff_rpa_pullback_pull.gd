## RPA PULLBACK, the pull's carrier (design ruling 12): a Buff.TO.ONHIT_EFFECT buff that hands the
## attack pipeline onhit_rpa_pullback whenever the attack in progress was composed with the
## &'rpa_pullback' variant.
##
## Hyper Reflex Mode's buff_hyper_reflex_mode_immobilize.tres is the buff-supplied on-hit shape
## (BuffWeaponTypeOnHit: `effects` is the payload, get_values hands it back). The gate is this
## file's, and it is Throughbolt's (buff_throughbolt_line_direction.gd:17): the composed action
## carries the variant's key in modified_by_variants. It REPLACES the archetype's gate rather than
## extending it: the archetype's size/type/basic filters were already applied by the variant buff
## when the menu was built, and the variant's key on the action is the whole condition.
##
## Both the per-target attack (event_unit_attack.gd:47-49) and the declared attack
## (event_unit_attack_declared.gd:42-44) collect ONHIT_EFFECT buffs with the composed action in the
## context, so the effect's on_resolution is reached - which is the stage the pull runs at, for the
## reason onhit_rpa_pullback.gd's header gives.
extends BuffWeaponTypeOnHit

const VARIANT_KEY := &'rpa_pullback'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not context.action is ActionAttackWeapon: return false
	return context.action.modified_by_variants.has(VARIANT_KEY)
