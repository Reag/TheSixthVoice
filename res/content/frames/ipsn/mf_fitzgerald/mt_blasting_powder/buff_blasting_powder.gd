## Blasting Powder: +N bonus damage to the Nth character hit by one Line attack, N counted from 0.
##
## WHY THIS CAN BE COMPUTED AT ALL. Buff.TO.BONUS_DAMAGE_SPECIFIC is rolled once PER TARGET and is
## never halved (event_unit_attack_declared.gd:281-284 passes halve = false), and unlike the
## ATTACK_ROLL channel, AttackUtil.DamageRoll.roll_bonus_damage DOES hand the context to get_values
## (attack_util.gd:298) - so the value can depend on which target is being rolled for.
##
## THE ORDERING THIS DEPENDS ON. Every attack_roll is appended to the shared DeclaredAttackSummary
## as its own event resolves (event_unit_attack.gd:63), and event_unit_attack_declared.gd runs ALL
## of those attack-roll events (:68) before it rolls any damage (:75 onwards) - so by the time the
## first target's bonus is computed, the summary already knows about every target. get_all_hit_units
## (declared_attack_summary.gd:48-52) returns them in resolution order, which for a Line is
## closest-first.
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

## This target's position among the units this attack HIT, closest-first. Guarded to 0 whenever the
## question cannot be answered - a damage PREVIEW has no DeclaredAttackSummary, and find() returns
## -1 for a unit that is not in the list - so the value can never come back negative and subtract
## damage.
static func hit_index(context:Context) -> int:
	if not DeclaredAttackSummary.is_valid(context.resource): return 0
	if not Unit.is_valid(context.target_unit): return 0
	return maxi(0, context.resource.get_all_hit_units().find(context.target_unit))
