# ONCE PER ROUND, ON HIT: the mod's shared "1/round, when you (crit / hit / damage) ..., the target
# must succeed a save or ..." trait. Extracted in close-out Pass D (2026-09-27) from four line-for-line
# copies, at the README's own trigger (the third instance):
#
#   Fitzgerald      mt_knock_em_down        crit, Cannon                      TRAIT = the trait Kit
#   Maiden's Blush  mt_rend                 crit, melee                       TRAIT = the trait Kit
#   Primrose        mt_magnetic_weight_...  crit, Heavy/Superheavy melee      TRAIT = the trait Kit
#   Primrose        cp_mobian_rainbow       hit, Overwatch (Wormhole Grasp)   TRAIT = the CORE Kit
#
# FROZEN INTERFACE: is_unspent and spend, exactly these names, argument names and types.
# spec/test_once_per_round.gd pins them off Script.get_script_method_list(). A later frame that needs
# more extends this file in its own sub-project, with every earlier spec still green.
#
# No class_name (res/content/gear/shared/README.md). Callers preload this file.
#
# THE SHAPE, which every consumer keeps: a BuffWeaponTypeOnHit subclass supplies an OnHitEffect, and
# the two halves of the limit live one in each.
#   - The buff's check_if_passive_applies gates on is_unspent(core.get_owner_gear(map), KEY) after
#     super - so the weapon filters (declarative on the .tres) run first.
#   - The OnHitEffect's should_abort calls spend(...) at `stage == apply_on`, BEFORE super, because
#     super is what rolls the save.
#
# WHY HAND-ROLLED: the engine enforces a per-round limit only for ActionReactions
# (reaction_bus.gd:126-139), never for a buff-triggered effect. Crack Shot III's buff_watch_this.gd
# counts the same way.
#
# THE ROUND IS SPENT BY FORCING THE SAVE, PASS OR FAIL (Fitzgerald ruling 15, inherited by Rend's 14,
# Magnetic Weight's 12 and Wormhole Grasp's 10): the trigger is the hit, not the status. Spending in
# on_crit/on_hit instead would spend only on a FAILED save, because a passed save makes should_abort
# return true and those are never reached.
#
# THE CHARACTER GATE: every card's subject is "the target" or "a character", and event_unit_attack.gd
# reaches apply_on_crits / apply_on_hits for ANY valid target unit - it checks is_character() only
# two lines later, for the crit bark. Without it a hit on a destructible object would spend the round
# on a save that can do nothing (a non-character is immune to Prone outright, unit_condition.gd:502).
# A drone IS a character (close-out Pass A), so a drone target spends the round.
#
# THE BOOKKEEPING FLAG: increment_action_usage's second argument, increment_per_turn_counter, is
# FALSE. It gates only the uses_this_turn tally (gear_core.gd:180-181 - uses_this_round and
# uses_this_scene are written either way); the limit is the per-ROUND counter is_unspent reads, and
# the per-turn soft limit at unit_action.gd:168 asks per-ACTION against the usage group of the action
# being taken (the weapon's), never this key. A true here would write a counter nobody reads.
extends RefCounted

## True when the round's one use is still open on `gear` under `usage_key`. An invalid gear reads
## SPENT, never open - a buff whose source gear is gone must not fire.
static func is_unspent(gear:GearCore, usage_key:StringName) -> bool:
	if not GearCore.is_valid(gear): return false
	return gear.get_uses_this_round_alt(usage_key) == 0

## Spend the round on `attacker`'s gear `gear_id`, when `target` is a valid character. Call it from
## OnHitEffect.should_abort at `stage == apply_on`, BEFORE super rolls the save.
static func spend(attacker:Unit, target:Unit, gear_id:StringName, usage_key:StringName) -> void:
	if not Unit.is_valid(target) or not target.is_character(): return
	if not Unit.is_valid(attacker): return
	var gear:GearCore = attacker.get_gear(gear_id)
	if GearCore.is_valid(gear): gear.increment_action_usage(usage_key, false)
