## The Breech-loading Swivel Gun's SINGLE SHOT profile: Main Cannon, 1d6+2 kinetic, range 10.
##
## "You can fire this cannon three times before it needs to be reloaded."
##
## THIS ACTION DELIBERATELY DOES NOT CARRY THE ENGINE'S LOADING TAG, and the absence is load-bearing
## rather than an oversight. GearCore.is_loaded is a single BOOLEAN: UnitAction.spend sets it false
## after any shot whose action carries the tag (unit_action.gd:276) and event_gear_reload.gd:24-31
## sets it back, and there is no ammunition count anywhere in the engine. Tagging this profile
## LOADING would therefore empty the gun after the FIRST shot, which is the exact behaviour the
## three-round magazine replaces. The counter below is the magazine; is_loaded is dropped only when
## it runs out, which is what puts the gun on UnitAction.get_unloaded_weapons and so makes Stabilize
## offer Reload for it (action_stabilize.gd:85). The player-facing "Loading (3 rounds)" is a
## localization row, not a tag.
##
## THE DECREMENT SITE IS on_resolution(), NOT spend_actions() OR activate(). on_resolution is called
## once per attack activation by event_unit_attack_declared.gd:215, after all damage, on a hit and on
## a miss alike - and never at all when the activation aborted before the attack was declared, since
## ActionAttack.activate returns at its abort_when(not CompconPlan.is_valid_with_targets(...)) guard
## well ahead of spend_actions (action_attack.gd:233-261). A shot that was never fired must not cost
## a round, and that is the whole reason for the choice; test_swivel_gun.gd's
## test_an_activation_that_aborts_before_attacking_does_not_eat_a_round is what pins it. The Raleigh's
## Mjolnir manages its own counter from the same place (action_m35_mjolnir.gd:23-26).
##
## KNOWN AND ACCEPTED CONSEQUENCE: an activation that aborts AFTER spend_actions - only a level exit
## does this in practice (event_unit_attack_declared.gd guards every stage with
## abort_if_level_exited) - spends the action but no round. That is the right way round: the
## alternative trades a real in-mission bug (a cancelled target picker silently eating ammunition) for
## a bookkeeping discrepancy in a scene that is already over.
extends ActionAttackWeapon

## What one shot costs. Named rather than inlined because SP2 Task 2's Grapeshot profile is the same
## idea at a different number - it spends all three at once - and the two should read alike.
const ROUNDS_PER_SHOT := 1

## Belt and braces beside the engine's own UNLOADED gate, and not redundant with it.
## UnitAction.get_gear_unavailable_reason checks is_loaded BEFORE it asks this
## (unit_action.gd:151-158), so at zero rounds the engine's reason is UNLOADED and this never speaks.
## It exists so the gun's own count of rounds - rather than a boolean set as a side effect of the last
## shot - is what refuses the button, which is the state a reader of this weapon expects to be
## authoritative. It also covers the window in which something else sets is_loaded true without
## refilling the magazine.
## PARTIAL RELOAD (author ruling, 2026-09-14, superseding ruling 22/33's "no partial reload").
##
## `is_loaded` does DOUBLE DUTY in this engine and that is the whole difficulty. `unit_action.gd:151`
## turns a false into REASON.UNLOADED - the gun cannot fire at all - while
## `UnitAction.get_unloaded_weapons` (`:411-416`) uses the SAME flag to decide whether Stabilize
## offers Reload for it (`action_stabilize.gd:85`). So the obvious way to let a part-spent gun be
## topped up - drop `is_loaded` below a full magazine - would also make a 2-round gun unfireable,
## which is far worse than the lockout it was meant to fix.
##
## This override is the seam that splits the two meanings apart. `can_be_used_while_unloaded` is a
## plain overridable on `action.gd:120` (vanilla `ActionReaction` already overrides it at
## `action_reaction.gd:65`), and it is checked in the same breath as the flag - so with it true, a
## false `is_loaded` no longer refuses THIS profile, and the round counter in
## `is_available_to_activate` below becomes the sole firing gate. The tooltip reads it too
## (`tooltip_organ_action.gd:163`), so a part-loaded gun does not render an "unloaded" warning while
## it is still perfectly fireable.
##
## The file header's own note - that this profile's counter check "covers the window in which
## something else sets is_loaded true without refilling the magazine" - is now the load-bearing
## direction as well: the counter is authoritative for firing, `is_loaded` only for offering Reload.
func can_be_used_while_unloaded() -> bool: return true

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	if not GearCore.is_valid(gear): return false
	var counter:PassiveDieCounter = gear.get_die_counter_passive()
	# No counter on the Kit at all: fall back to behaving as an ordinary Main Cannon rather than as a
	# permanently dead button. The vanilla precedents guard their counter reads the same way
	# (action_m35_mjolnir.gd:6).
	if counter == null: return true
	return counter.get_current(gear) >= ROUNDS_PER_SHOT

func on_resolution(activation:EventCore) -> void:
	super.on_resolution(activation)
	var unit:Unit = activation.context.unit
	var gear:GearCore = activation.context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	var counter:PassiveDieCounter = gear.get_die_counter_passive()
	if counter == null: return
	counter.decrease(unit, gear, ROUNDS_PER_SHOT)
	# ANY round short of a full magazine now surfaces the gun to Stabilize's Reload variant, not just
	# an empty one (author ruling, 2026-09-14 - see can_be_used_while_unloaded above). Before this,
	# `is_loaded` dropped only at 0, and since Reload is offered exclusively for unloaded weapons a
	# gun sitting at 2 could not be topped up - so Grapeshot, which needs exactly 3, was unreachable
	# until the other two rounds had been fired off one turn at a time.
	#
	# Read against the counter's own max rather than a literal 3, so the magazine size lives in one
	# place (passive_swivel_rounds.tres). max_value is the plain export; the Leader-talent
	# max_value_with_kits path (passive_die_counter.gd:63-65) does not apply to this gear.
	if counter.get_current(gear) >= counter.max_value: return
	gear.is_loaded = false
