## The Breech-loading Swivel Gun's GRAPESHOT profile: Main Cannon, 2d6 kinetic, Line 10, Heat 2
## (self), Reliable 3. "Fire all three shots at once."
##
## Design §3.1. Where Single Shot spends ONE round per activation, Grapeshot spends ALL THREE at
## once and requires all three to be present to fire at all - there is no partial Grapeshot. See
## action_swivel_single_shot.gd for the full reasoning behind the counter, the missing engine
## LOADING tag, and why the decrement site is on_resolution() rather than spend_actions() or
## activate() - all of that reasoning applies here unchanged, just at a different number.
##
## The on-hit save/status (Hull save or Shredded) is wired declaratively via on_hit_effects,
## pointing at onhit_swivel_grapeshot.tres - see that script for ruling 10.
extends ActionAttackWeapon

## All three rounds, spent in one activation. Named for the same reason
## action_swivel_single_shot.gd names ROUNDS_PER_SHOT: the two profiles read alike.
const ROUNDS_PER_SHOT := 3

## Requires the FULL magazine - "fire all three shots at once" is not available with one or two
## rounds left. Belt and braces beside the engine's own UNLOADED gate, same reasoning as
## action_swivel_single_shot.gd's own override.
func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	if not GearCore.is_valid(gear): return false
	var counter:PassiveDieCounter = gear.get_die_counter_passive()
	# No counter on the Kit at all: fall back to behaving as an ordinary Main Cannon rather than as a
	# permanently dead button (same guard as the Single Shot profile and the vanilla precedents).
	if counter == null: return true
	return counter.get_current(gear) >= ROUNDS_PER_SHOT

## Same decrement site as Single Shot, and for the same reason (see that file's header): this only
## runs once per attack activation, after all damage, and never for an activation that aborted
## before the attack was declared - so a Grapeshot that never fired never empties the gun.
func on_resolution(activation:EventCore) -> void:
	super.on_resolution(activation)
	var unit:Unit = activation.context.unit
	var gear:GearCore = activation.context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	var counter:PassiveDieCounter = gear.get_die_counter_passive()
	if counter == null: return
	# Empty it outright rather than decreasing by ROUNDS_PER_SHOT: Grapeshot is only ever fireable at
	# a full magazine (is_available_to_activate above), so the two are equivalent in practice, but
	# setting straight to 0 is what the design means by "fire all three at once" and does not depend
	# on the gate above having actually been checked.
	counter.update_value(unit, gear, 0)
	# Out of rounds either way - drops is_loaded, same as Single Shot, surfacing Reload on Stabilize.
	gear.is_loaded = false
