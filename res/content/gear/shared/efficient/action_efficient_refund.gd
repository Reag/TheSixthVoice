# The hidden half of EFFICIENT: the reaction that hands the Core Point back. A consumer puts an
# action_efficient_refund.tres pointing at THIS script on its own core Kit, beside the ability that
# calls Efficient.mark_used. Born with the Maiden's Blush (SP2); see efficient.gd's header for the
# family.
#
# WHY TWO TRIGGERS (design §0.15, ruling 15). The card says "at the end of any scene in which this
# ability was used", and both first-party precedents refund at the NEXT SPAWN instead - the
# Barbarossa's action_regain_cp.gd and the Tritton's Fusillade refresh. Neither is quite the card:
#
#   - combat_end IS the card, and it really reaches a living mech. event_combat_end fires COMBAT_END
#     PRE then POST (event_combat_end.gd:26-28) BEFORE it walks the map collecting the surviving
#     unit.cores (:33-42), so a point restored at POST is inside the core the campaign keeps.
#   - unit_spawn is the SAFETY NET, for the two cases combat_end cannot serve: a mech destroyed
#     earlier in the scene was serialised at death with the stamp already in its gear state
#     (gear_core.gd:84) and is not on the map to react; and a Stunned one cannot react at all.
#
# Efficient.refund is idempotent - it erases the stamp before returning - so the pair can never hand
# back two points.
#
# NOT ActionReactionSelf, although every instinct says it should be. That archetype's whole body is
# `triggering_context.unit != unit` over a REQUIRED unit prop (action_reaction_self.gd:8-14), and the
# combat-end event carries NO unit: its required context is [boolean] alone (event_combat_end.gd:10-11).
# A required prop the event does not have means the reaction is never even offered. So this extends
# ActionReaction, declares no required context, and does the unit check itself for the spawn half only.
extends ActionReaction

const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')

## Nothing: see the header. The two triggers disagree about what the event carries, and demanding the
## intersection (nothing) is what lets one reaction listen to both.
func get_required_triggering_context() -> Array[Context.PROP]: return []

## NEVER ADVERTISED. The player already reads "Efficient" in the core power's own effect text, where
## the card puts it; a tooltip row saying "Reaction: ..." would invent a second ability the card has
## not got. This is the same reasoning that keeps the Maiden's Blush's damage-break and Fade Strike
## arming as hidden buffs rather than reactions (design §0.2).
func show_in_tooltip(_kit:Kit) -> bool: return false

## ActionReaction already answers 99 for a reaction that consumes no reaction point
## (action_reaction.gd:69), so this is not a change - it is a statement, because the limit matters
## here and the default is easy to mistake for an oversight. The refund can legally fire twice in one
## ROUND across two scenes (combat_end, then the next scene's unit_spawn), and a limit of 1 would
## silently drop the safety net.
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# NOTHING TO GIVE BACK, and checked FIRST so an unmarked gear costs one dictionary lookup per
	# combat end and per spawn of every unit on the map and nothing else.
	#
	# DROPPING THIS LINE DOES NOT MERELY LOOSEN THE GUARD - it takes the whole run down. Measured
	# 2026-09-17: without it the refund is offered to EVERY unit on the map at every combat end and
	# every spawn, and the run aborts with leaked RIDs rather than reddening a test. The stamp is what
	# scopes this reaction to the one mech that spent a point.
	if not Efficient.is_marked(gear): return false
	# The spawn half is per-unit and has to say so; the combat-end half is global and has no unit to
	# compare against. event_core.gd:6 holds `base`, event_base.gd:5 holds `event_type`.
	if triggering_event.base.event_type == &'event_unit_spawn':
		return triggering_event.context.unit == unit
	return true

## NO spend_actions. consumes_rxn is false on the .tres and this is bookkeeping, not an action: a
## mech that spends its reaction point on getting its own core point back would be paying twice.
func activate(context:Context, _activation:EventCore) -> void:
	Efficient.refund(context.unit, context.gear)
