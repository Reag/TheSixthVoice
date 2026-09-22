# BEGIN DEACTIVATING THE A.R.C. (Leoleth rank III, design ruling 17):
#
#   "You can begin to deactivate this system as a protocol. At the start of your next turn it
#    deactivates."
#
# TWO SENTENCES, TWO MECHANISMS, AND THIS IS THE FIRST ONE. All this protocol does is STAMP the
# chip; buff_arc's own new_turn POST trigger reads the stamp and switches the system off at the
# holder's next turn start. A protocol that cleared the chip outright would read the card's first
# sentence and lose its second - the A.R.C. is still live for the rest of the turn you begin on,
# which is the whole cost of switching it off.
#
# NOT ActionSystemClearBuff, WHICH IS WHAT THE ZIP'S OFF SWITCH USES. That archetype clears
# immediately and has no way to defer; this one is a plain ActionSystem whose activate writes one
# key, the Goblin's action_symbiosis_end.gd shape (a self-targeted ActionSystem overriding
# is_available_to_activate and activate, and nothing else).
#
# AVAILABLE WHILE THE CHIP IS HELD, FULL STOP. Pressing it a second time re-stamps the same value
# and changes nothing, which is preferable to a second availability rule the card does not have.
# ActionSystem's default get_target_requirements is already count = 0, self-targeting
# (action_system.gd:55-60), so no targeting override is needed.
#
# FIX (frame-close review, CONFIRMED): activate() NEVER CALLED spend_actions. Action.activate is an
# assert(false) stub (action.gd:102-103) precisely because every concrete action has to call it
# itself, and all ten engine/character/gear_action/archtypes/action_system_*.gd archetypes do -
# ActionSystemApplyBuff calls it at action_system_apply_buff.gd:122, right after confirming targets
# and before doing any of the actual effect, which is the shape followed below. Skipping it meant:
#   - no log_usage / popcorn_usage (unit_action.gd:229-231, called from spend_actions_gain_heat via
#     UnitAction.spend) - pressing "End Automatic Retaliation Core" was silent in the battle log,
#     while pressing the activation protocol logs.
#   - gear.increment_action_usage_for_action (unit_action.gd:279, inside UnitAction.spend) never ran,
#     so specific.gear.get_uses_this_round(specific.action) stayed 0 forever and
#     UnitAction.is_under_per_round_limit (unit_action.gd:170-175) could never trip the engine's
#     natural 1/round hard limit on a free-cost action (action.gd:156-158) - the protocol could be
#     pressed repeatedly in the same round with the chip already held.
#   - content/events/event_gear_activate.gd:100-104 gates Scanpedia.scan_kit, the UNIT_ACTION POST
#     reaction block, and the lose-hidden check on `pre_activate_uses !=
#     get_uses_this_round_alt(...)` - a comparison that only spend_actions' call into
#     gear.increment_action_usage_for_action can ever make true. All three were skipped.
#
# THE GOBLIN'S action_symbiosis_end.gd (content/frames/horus/mf_goblin/cp_instinct_rig/) - cited
# above as this file's shape - HAS THE SAME OMISSION IN VANILLA. That is how this bug was imported:
# the shape was copied faithfully, including the missing call. Do not copy this file (or that one)
# again as a template without adding spend_actions - grep the source for it before trusting a
# "matches an existing pattern" review comment.
#
# THE 1/ROUND HARD LIMIT BECOMING REAL IS THE CORRECT BEHAVIOUR, NOT A REGRESSION TO GUARD AGAINST:
# "you CAN BEGIN to deactivate" reads as a single decision per round, matching the activation
# protocol's own can_reapply = false. spec/test_automatic_retaliation.gd's deactivation tests
# (search "deactivation") each press it exactly once per round, so none of them exercise the new cap
# - verified by reading every call site before this fix, not assumed.
extends ActionSystem

## The stamp's key is buff_arc.gd's own constant, preloaded rather than retyped so the two cannot
## drift apart silently. Preloading a sibling mod script is this mod's established shape (the frozen
## Teleport and Terrain helpers are reached the same way).
const BuffArc := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ha/systems/ms_jormungandr_class_nhp/buff_arc.gd')

const CHIP := &'buff_arc'

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return UnitCondition.has_buff(unit, CHIP, gear.persistent_id)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_when(not Unit.is_valid(unit)): return
	# Scoped to OUR gear's own chip, the way the ZIP's disengage scopes its clear: a second copy of
	# this Kit is impossible (UNIQUE), but the id is free and states the intent.
	var chip:BuffCore = UnitCondition.get_buff(unit, CHIP, context.gear.persistent_id)
	if activation.abort_when(not is_instance_valid(chip)): return
	# spend_actions AFTER the availability aborts above and BEFORE the stamp itself, exactly where
	# ActionSystemApplyBuff.activate places it relative to its own abort_without_units (:120) and its
	# effect (apply_buffs_to_targets, :130) - see the header's FIX note.
	spend_actions(activation)
	chip.set_state(BuffArc.DEACTIVATING, true)
