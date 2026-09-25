## HYDRAULIC PUNISHER: "1/round, when the Gloire knocks a hostile character Prone, they become
## Impaired until they clear Prone." Design ruling 3.
##
## The Vlad's Dismemberment (action_dismemberment_shred.gd) line for line, with Prone for Immobilized
## and a buff for the Shredded: a STATUSES_CHANGED PRE reaction - PRE is an APPLICATION
## (reaction_bus.gd:31) - fired from UnitCondition.on_status_application (unit_condition.gd:165-167)
## as the virtual event_unit_apply_status, whose `string` is the persistent id of the SOURCE gear.
## The Ram's Prone arrives with mw_ram's GearCore id (on_hit_effect.gd:80-82 passes
## context.gear.persistent_id), and UnitRelation.get_origin_unit_for_source (unit_relation.gd:428-437)
## resolves any gear id to the unit whose loadout holds it - basic gear included, because
## loadout_core.gd:285-288 indexes get_all_gear(). That is "when the Gloire knocks": the question is
## WHO applied the Prone, not what the Gloire is doing at the time, so a Siege Ram, a Knockback
## collision or (SP2) RPA Pullback's collision save all count, and another unit's Ram never does.
##
## NOT A REACTION POINT (consumes_rxn false): the card says "1/round", not "Reaction". The limit is
## this file's get_per_round_hard_limit, counted on usage_group `hydraulic_punisher` and reset at the
## Gloire's own turn start (Supporting Fire's measurement, rulings 2026-09-24). A Prone on a hostile
## who already carries our buff does NOT fire, so it does not spend the round either: a target knocked
## down twice is Impaired once, and the second knockdown leaves the round for someone else.
##
## NO PROMPT - the card has no "may" - so the AI needs nothing and a player is never asked.
##
## HIDDEN FROM THE CARD. localization_key_override (in the .tres) points this reaction's rows at the
## Kit's own, which is also what makes Action.show_in_tooltip answer false (action.gd:348).
##
## "The unit is a hostile CHARACTER": is_character() refuses deployables and props, are_enemies the
## Gloire's own side.
extends ActionReaction

const BUFF_ID := &'buff_hydraulic_punisher'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit, # the unit the status landed on
		Context.PROP.category, # the status
	]

## "1/round" (action_reaction.gd:67 would answer 99 for a non-consuming reaction).
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var triggering_context := triggering_event.context
	var knocked:Unit = triggering_context.unit
	var status:StringName = triggering_context.category_str
	var source:String = triggering_context.string
	# was the applied status Prone?
	if status != Lancer.STATUS.PRONE: return false
	# a hostile character?
	if not Unit.is_valid(knocked) or not knocked.is_character(): return false
	if knocked == unit or not UnitRelation.are_enemies(unit, knocked): return false
	# were we the one to apply it?
	if UnitRelation.get_origin_unit_for_source(source, triggering_context.map) != unit: return false
	# are we already punishing them?
	if UnitCondition.has_buff(knocked, BUFF_ID, gear.persistent_id): return false
	return true

func activate(context:Context, activation:EventCore) -> void:
	var knocked:Unit = context.event.context.unit
	if activation.abort_without_unit(knocked): return
	# RECORDED FIRST. A reaction does not spend itself: the engine reaches UnitAction.spend
	# (unit_action.gd:279 records the round use) only through Action.spend_actions, which an
	# ActionReaction's own activate() has to call - the Vauban's Solfataric Breach's lesson. Without it
	# uses_this_round never moves and the 1/round limit above never bites. Nothing is spent besides
	# the tally: consumes_rxn is false, the action type is RXN (cost FREE) and there is no self heat.
	spend_actions(activation)
	apply_buff_id(activation, knocked, BUFF_ID) # from_gear = this Kit (action.gd:375), so the chip reads its card
