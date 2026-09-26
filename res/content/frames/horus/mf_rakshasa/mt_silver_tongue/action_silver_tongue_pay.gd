## SILVER TONGUE, the price: the 2 heat and the 1/round, paid on the rerolled attack itself. Design
## 1.3, ruling 9.
##
## An ATTACK PRE ActionReactionAttacked on the Rakshasa's OWN tech attack that carries
## Action.FLAG.WAS_REROLLED_AGAINST_NEW_TARGET - i.e. the new event_unit_attack that
## event_unit_attack.gd:327-339 builds once the player has picked a new target. So a cancelled pick
## never gets here and costs nothing, and the reroll pays exactly once, before its roll.
##
## spend_actions IS the whole activate: it pays the .tres's self_heat_dice of 2 through
## UnitAction.gain_self_heat_alt (unit_action.gd:296-306, SELF_INFLICTED) and moves uses_this_round on
## the usage group `silver_tongue`, which buff_silver_tongue.is_round_spent reads. That round resets at
## the Rakshasa's own turn start (ruling 3).
##
## KNOWN LIMIT, recorded rather than fought: the flag says a reroll happened, not WHOSE buff offered
## it. handle_reroll_miss_against_new_target pools every REROLL_MISS_AGAINST_NEW_TARGET buff into one
## prompt, so if another such buff ever offered a reroll on the Rakshasa's tech attack (no vanilla one
## covers tech attacks today - No Escape and the Tlaloc are weapon-only), this would charge for it.
##
## NOT A REACTION POINT, HIDDEN (localization_key_override): the log reads "Silver Tongue".
extends ActionReactionAttacked

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var context:Context = triggering_event.context
	if context.unit != unit: return false # the Rakshasa's own attack, not a drone's
	if context.action is not ActionAttackTech: return false
	return context.flags.has(Action.FLAG.WAS_REROLLED_AGAINST_NEW_TARGET)

func activate(_context:Context, activation:EventCore) -> void:
	spend_actions(activation)
