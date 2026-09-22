# WIRE SLITHER (Naga, mt_wire_slither), ruling 6:
#
#   "1/round, when the Naga takes a Tech Action, it may immediately move two spaces. This movement
#    ignores engagement and doesn't provoke reactions."
#
# A unit_action POST reaction on the trait Kit, on the ActionReactionMovement archetype (the
# Subutai's Juggernaut Drive is the in-mod precedent): the archetype opens a movement picker for the
# HOLDER with a fixed budget (movement_range_fixed = 2 on the .tres), cancellable because
# is_mandatory is false ("may"), spends the round with spend_actions AFTER the plan is confirmed, and
# runs the move with the .tres's MovementType - voluntary, ignore_engagement, ignore_rxns - merged
# with the Naga's own standard type (flying, intangible, movement buffs). A cancelled picker spends
# nothing (activation.abort_without_movement_plan runs before spend_actions), which is the "declining
# costs nothing and the next tech action that round still offers" case in the spec.
#
# THE TRIGGER (measured by spec/test_spike_naga_sp1_seams.gd before this file existed):
# event_gear_activate queues UNIT_ACTION POST only when the gear's use count rose (:100-111), so an
# aborted action does not slither, and the virtual event carries the ACTION used (:119-132). The tech
# predicate is UnitAction.is_tech's own two clauses (unit_action.gd:567-571) applied to that action
# instead of the Kit - the card says "takes a Tech Action", not "uses a tech system":
# ActionAttackTech (an invade; descends from ActionAttack, NOT ActionSystem, which is why both
# clauses are needed) or ActionSystem with is_tech (Lock On, Scan). Freebies count: a free Lock On is
# a Tech Action.
#
# THE PREDICATE IS PURE, AND HAS TO BE. The probe measured the bus polling triggers_on_event FOUR
# times per targeted activation, on action instances that are not always the same object (one poll
# per attack sees a duplicate with an empty resource_path), and polling this reaction once more
# about ITS OWN activation after it fires. So: no spend, no stamp, no prompt in here; read the action
# by class and flag, never by identity or path; and refuse ourselves - which the predicate does
# naturally, since an ActionReactionMovement is neither class.
#
# 1/ROUND: consumes_rxn is false (a trait, not a reaction point), so the archetype's default hard
# limit would be 99; get_per_round_hard_limit returns 1 instead, and it counts gear.uses_this_round,
# whose only writer is spend_actions (memory lancer-tactics-reactions-and-usage) - hence the
# archetype's explicit spend, which this file inherits. Universal Compatibility and Mine Deployers
# are the two vanilla reactions on this trigger; Mine Deployers is the one with the same limit.
#
# SLOWED OR IMMOBILIZED: the archetype's is_available_to_activate refuses a VOLUNTARY move to a
# Slowed or Immobilized holder (action_reaction_movement.gd:46-51). Immobilized is the card's own
# rule for any move; Slowed is the archetype's reading and is recorded as a judgment item for the
# author in the ledger - a Slowed Naga does not slither at all rather than slithering one space.
extends ActionReactionMovement

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.action]

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# super(): the triggering unit is the holder (triggering_unit_is = UNIT) and the .tres carries a
	# valid MovementType.
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	return is_tech_action(triggering_event.context.action)

## Ruling 6's predicate. Static and side-effect free; the spec calls it directly as well.
static func is_tech_action(action:Action) -> bool:
	if action is ActionAttackTech: return true
	return action is ActionSystem and action.is_tech
