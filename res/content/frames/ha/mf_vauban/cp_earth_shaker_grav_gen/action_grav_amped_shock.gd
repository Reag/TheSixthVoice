## The third clause of GRAV-AMPED INTERFERENCE: "When a hostile character fails a save you forced,
## they take 3 AP Kinetic damage. Each character can be affected by this ability only once per round."
##
## THE VANILLA SHAPE IS THE LESSON OF THE OPEN DOOR (action_the_lesson_of_the_open_door.gd): a
## forced_save reaction at POST that checks it was the forcer and that the save failed, then queues
## one damage event naming itself as the damager. This is that, plus a hostile-character test, plus
## the per-character cadence, minus the confirmation prompt - the Lesson asks the player because it is
## a core bonus the pilot may want to hold; this is automatic, for the rest of the scene, and a
## yes/no on every failed save in the Vauban's field would be intolerable.
##
## WHY POST AND NOT PRE. context.boolean - whether the save passed - is assigned at
## event_unit_save.gd:54, after PRE has already run from execute_preblock (:33-34), and POST is queued
## at :70. There is nothing to react to at PRE. Measured by the SP2 probe (claim B), which also
## confirmed context.unit is the FORCER and context.target_unit the SAVER at that timing.
##
## WHY IT EXTENDS ActionReactionOnComingWithin, WHICH IS NOT A SAVE ARCHETYPE. Only for its
## once-per-round-per-character bookkeeping: has_unit_already_been_affected (:86) and
## record_unit_affected_and_abort_if_already_affected (:95) hang a buff_track_affection buff on the
## affected unit with the reacting gear's KIT id in its `from_kit` state (:102-103), which is the
## engine's own mechanism and is shared with every vanilla card that needs it.
##
## DESIGN §4 SAID THOSE WERE STATICS. THEY ARE NOT - they are instance methods, which is exactly why
## a plain ActionReaction cannot borrow them and this file subclasses instead. The alternative was to
## re-implement the same five lines against the same buff id, and a second implementation of an
## interop surface is a thing that drifts.
##
## SO THE ARCHETYPE'S OWN EXPORTS DECIDE NOTHING HERE. triggers_on_event below overrides the
## archetype's outright and NEVER CALLS super - the archetype's version filters on move/turn event
## types, distance and elevation (:44-75), none of which a forced_save event has any business with.
## when_enter_within, triggers_on_coming_within_range and the rest are inert, and the .tres subscribes
## to forced_save and to nothing else, so no move event ever reaches this file at all.
## test_the_archetypes_movement_exports_are_inert_here pins both halves, because an inert export that
## looks live is what a later reader trips on.
##
## WHAT IS NOT INERT: can_only_affect_a_unit_once_per_round and once_per_round_is_specific_to_gear are
## read by has_unit_already_been_affected itself (:87), so the .tres sets them deliberately.
## once_per_round_is_specific_to_gear stays FALSE: the card says "each character can be affected by
## this ability only once per round", and with two Vaubans on the board that is still one 3 AP per
## character per round rather than one per Vauban. (Author note for the close - the card is genuinely
## ambiguous, and false is the stricter reading.)
##
## AND "ONCE PER ROUND" IS SPELT "UNTIL THE START OF YOUR TURN". buff_track_affection declares
## until = 3 = Lancer.UNTIL.START_OF_TURN (content/gear/shared/buff_track_affection.tres,
## lancer.gd:46-48), cleared by UnitCondition.new_turn_for_statuses (:23) when the AFFECTED unit's own
## turn begins - not on a round tick. That is the cadence every vanilla once-per-round-per-character
## card runs on, so it is the engine's reading of the card rather than an approximation of it.
##
## WHY IT SPENDS NOTHING. consumes_rxn is false, so this is a trait rather than a reaction the pilot
## spends - which matters concretely: Solfataric Breach IS a real reaction (1/round, point spent), and
## if this one consumed the point too, a hostile Slowed by a failed Sap save in the Vauban's own field
## would eat the point that Breach needs in the same instant. And because it consumes nothing,
## ActionReaction.get_per_round_hard_limit already returns 99 (action_reaction.gd:69); it is written
## out anyway, below, for the reason mt_sap's is - the cadence is a RULING and a later edit that
## flipped consumes_rxn would otherwise silently acquire a cap of 1.
##
## WHAT consumes_rxn ACTUALLY DECIDES, measured 2026-09-18, because it is not what it looks like: it
## does NOT decide whether the point is taken. A consuming reaction does not spend itself - the engine
## only reaches UnitAction.spend through Action.spend_actions, which an ActionReaction's own activate()
## has to call, and this one never does (the same fact action_solfataric_breach.gd's header records
## from the other side, where Breach DOES call it). What it decides is AVAILABILITY:
## ActionReaction.is_available_to_activate returns early for a non-consuming reaction and otherwise
## demands UnitAction.can_take_reactions, i.e. current.reactions > 0 (unit_action.gd:374-380). So the
## observable clause is test_a_vauban_with_no_reaction_point_left_still_shocks, and that is the test
## that reddens when this flag is flipped.
##
## THE ORDER INSIDE activate. record_unit_affected_and_abort_if_already_affected FIRST, then the
## damage. It returns true when it has aborted the activation - the queued-block race its own comment
## describes: triggers_on_event's check and this one can be separated by other queued work, so the
## gate is asked twice on purpose. That redundancy is real and it is why deleting the gate from
## triggers_on_event ALONE does not redden the cadence test - see the Task 3 report's mutation section;
## the clause is kept because without it the reaction raises a whole event_gear_activate block on every
## subsequent failed save, only to abort it.
extends ActionReactionOnComingWithin

## The gear-state key action_grav_amped_interference.gd sets. A String: GearCore.get_state takes one
## (gear_core.gd:259).
const FIELD_STATE_KEY := 'grav_amped'

const SHOCK_DAMAGE := 3

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.target_units, # the unit MAKING the save
		Context.PROP.unit,         # the unit FORCING it
	]

func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 99 # the cap is per CHARACTER, below; see the header

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	# NOTE: deliberately does not call super - see the header.
	if not GearCore.is_valid(gear): return false
	if not gear.get_state(FIELD_STATE_KEY, false): return false # dark until the protocol

	var context:Context = triggering_event.context
	if context.boolean == true: return false # they made the save

	var forcer:Unit = context.unit
	if not Unit.is_valid(forcer): return false
	if forcer.get_owner_unit_or_self() != unit: return false # "a save YOU forced" - ruling 9

	var target:Unit = context.target_unit
	if not Unit.is_valid(target): return false
	if not target.is_character(): return false
	if not UnitRelation.are_enemies(unit, target): return false

	return not has_unit_already_been_affected(gear, target)

func activate(context:Context, activation:EventCore) -> void:
	var triggering:Context = context.event.context
	var target:Unit = triggering.target_unit
	if activation.abort_without_unit(target): return
	if record_unit_affected_and_abort_if_already_affected(activation, target): return

	activation.queue_event(&'event_unit_damage', {
		unit = target,
		number = SHOCK_DAMAGE,
		category = Lancer.DAMAGE_TYPE.KINETIC,
		flags = [EventService.DAMAGE_FLAG.AP],
		target_unit = context.unit, # who gets the credit: the Vauban
	})
