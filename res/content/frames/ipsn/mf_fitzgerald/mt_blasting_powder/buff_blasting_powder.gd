## Blasting Powder: +N bonus damage to the Nth character hit by one Line attack, N counted from 0.
##
## WHY THIS CAN BE COMPUTED AT ALL. Buff.TO.BONUS_DAMAGE_SPECIFIC is rolled once PER TARGET and is
## never halved (the roll_bonus_damage call at event_unit_attack_declared.gd:284-286 passes
## halve = false on :285), and unlike the ATTACK_ROLL channel,
## AttackUtil.DamageRoll.roll_bonus_damage DOES hand the context to get_values (attack_util.gd:298) -
## so the value can depend on which target is being rolled for.
##
## THE ORDERING THIS DEPENDS ON. Every attack_roll is appended to the shared DeclaredAttackSummary
## as its own event resolves (event_unit_attack.gd:63), and event_unit_attack_declared.gd runs ALL
## of those attack-roll events (:67) before it rolls any damage (:74 onwards) - so by the time the
## first target's bonus is computed, the summary already knows about every target. get_all_hit_units
## (declared_attack_summary.gd:48-52) returns them in resolution order, which for a Line is
## closest-first-ish: see hit_index at the bottom of this file for what "-ish" costs.
##
## THE ROUND IS NOT SPENT HERE. get_values runs once per target, so counting the round in this file
## would spend it on the first target and deny the second and third their bonus. The spend lives in
## action_blasting_powder_spend.gd, a hidden ATTACK_DECLARED POST reaction that runs after every
## per-target bonus has been computed. See that file.
extends BuffDamage

const USAGE_KEY:StringName = &'blasting_powder'

## require_hit = true on the .tres does two thirds of the gating for free, through super():
## BuffDamage.is_buff_context_valid_for_passive demands context.object is an AttackRoll, and
## check_if_passive_applies demands context.object.hit - which is the rules sheet's "successful
## ranged attack" clause and the per-target hit test in one.
##
## The CHARACTER gate is ruling 5's own wording - "the next CHARACTER hit" - and the same call the
## author made for Knock 'em down (Task 6 review finding 1): a Line that punches through a wreck on
## its way to a mech should not be handing the wreck bonus damage. It cannot cost a character their
## bonus, because objects are sorted to the BACK of the attacked-unit list before any of this runs
## (common_action_util.gd:474-480), so no character ever resolves after one.
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not Unit.is_valid(context.target_unit) or not context.target_unit.is_character(): return false
	var weapon:ActionAttackWeapon = context.action as ActionAttackWeapon
	if weapon == null: return false
	if weapon.range_pattern == null or weapon.range_pattern.pattern != Lancer.AOE_TYPE.LINE: return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_round_alt(USAGE_KEY) == 0

## super() supplies the damage TYPE and the inherit-from-attack flag; only the dice string is ours.
## A value of '0' is not a bonus of zero, it is NO BONUS ROLL AT ALL - roll_bonus_damage skips a
## buff whose value comes back '' or '0' (attack_util.gd:302) - which is exactly what the first
## character hit should get.
func get_values(core:BuffCore, context:Context) -> Context:
	var values:Context = super.get_values(core, context)
	values.string = str(hit_index(context))
	return values

## This target's position among the CHARACTERS this attack HIT, in resolution order. Guarded to 0
## whenever the question cannot be answered - a damage PREVIEW has no DeclaredAttackSummary, and
## find() returns -1 for a unit that is not in the list - so the value can never come back negative
## and subtract damage.
##
## THE CHARACTER FILTER IS NOT REDUNDANT, even though check_if_passive_applies above has already
## refused every non-character. Without it this function counts a position in the UNFILTERED hit
## list while the gate counts characters, and the two only agree because vanilla happens to sort
## every object behind every character (common_action_util.gd:474-480, clause 3). That is one line
## of engine code away from being untrue, and the failure would be silent: a wreck in the line would
## push the mech behind it up a bonus step. Filtering here makes the index mean what the gate means,
## whatever vanilla sorts.
##
## What the filter deliberately does NOT do is re-order. Resolution order is the engine's, and it is
## only roughly closest-first: the same sort pushes npct_grunt units to the BACK (:477), and grunts
## ARE characters - so a grunt standing nearest is the LAST character hit and collects the LARGEST
## bonus. spec/test_blasting_powder.gd pins that; the author has not yet ruled on whether it is
## wanted.
static func hit_index(context:Context) -> int:
	if not DeclaredAttackSummary.is_valid(context.resource): return 0
	if not Unit.is_valid(context.target_unit): return 0
	var characters_hit:Array[Unit] = context.resource.get_all_hit_units().filter(
		func(hit_unit:Unit) -> bool: return hit_unit.is_character())
	return maxi(0, characters_hit.find(context.target_unit))
