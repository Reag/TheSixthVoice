## Hole Puncher, LOS half: grants ARCING to the Fitzgerald's Cannons and to anything it fires as a
## Line, which is what makes ActionAttackWeapon.requires_line_of_sight answer false
## (action_attack_weapon.gd:242-244).
##
## ARCING, not SEEKING: SEEKING also makes ignores_cover() true (action_attack_weapon.gd:207), which
## would skip the cover calculation the trait's second clause depends on.
##
## This script also owns the trait's "is this a Cannon or a Line weapon?" predicate, as a static
## shared by all three Hole Puncher buffs. It is deliberately ONE definition: this trait is the
## template every later Cannon/Line gate in this mod copies (Blasting Powder, the Carronade), and a
## duplicated predicate would drift.
extends BuffWeaponType

## Does the weapon in this context fall under Hole Puncher?
##
## Two independent ways in, exactly as the rules sheet words it - "Cannon OR Line weapons":
## the weapon's TYPE is Cannon, or its range pattern IS a Line whatever its type. The second clause
## is what catches a Rifle firing a Line, and what will catch the Fitzgerald's later Line gear.
##
## `is_weapon_type` needs the gear as well as the action, because a weapon's type can be changed by
## what it is mounted in; the context carries both on every seam that reads this
## (action_attack_weapon.gd:166-171 for WEAPON_TAG, attack_roll.gd:131-134 for the attack roll).
static func applies_to_weapon(context:Context) -> bool:
	if not context.action is ActionAttackWeapon: return false
	var weapon:ActionAttackWeapon = context.action
	if not Action.is_valid(weapon): return false
	if weapon.is_weapon_type(Lancer.WEAPON_TYPE.CANNON, context.gear): return true
	return weapon.range_pattern != null and weapon.range_pattern.pattern == Lancer.AOE_TYPE.LINE


func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return applies_to_weapon(context)

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({category = Lancer.WEAPON_TAG.ARCING, number = 0})
