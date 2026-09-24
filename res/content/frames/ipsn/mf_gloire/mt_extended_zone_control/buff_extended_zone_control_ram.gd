## EXTENDED ZONE CONTROL, the Ram half: "The Gloire can Ram targets within Range 3 and line of
## sight." Design ruling 5.
##
## The Ram is a MELEE attack with the default threat 1 (action_attack_weapon.gd:16; action_ram.tres
## sets only aim_range = 0), and get_target_range (:210-216) takes the melee branch into
## threat_distance, which adds every action_range / threat_range buff (:189-192, buff_bonus.gd:20-29):
## 1 + 2 = 3. Line of sight costs nothing - it is every attack's baseline
## (action.gd:36 requires_line_of_sight_baseline, read at unit_targeting.gd:36, :142). The size rule
## stays (action_ram.gd:20-29), and generate_knockback_events defaults its origin to the attacker's
## footprint (common_action_util.gd:131), so a Ram from three away pushes directly away from the
## Gloire. A melee attack from three away ignores cover as every melee attack does (:218-224) - the
## engine's rule, recorded.
##
## NO OVERWATCH LEAK: get_weapons_that_can_react_against walks loadout.get_all_weapons()
## (unit_relation.gd:235), which is mounted + integrated gear only (loadout_core.gd:521-525); mw_ram
## is basic and never in that pool.
##
## Siege Ram's gate (buff_siege_ram.gd:16), so a Siege Ram variant on the same Ram is offered at the
## same reach.
extends BuffBonus

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) and Action.is_valid(context.action)

func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
	return context.action.get_id() == &'action_ram'
