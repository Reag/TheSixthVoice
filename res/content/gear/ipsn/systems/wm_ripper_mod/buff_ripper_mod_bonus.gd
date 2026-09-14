## RIPPER MOD, first clause: "+1d6 bonus damage against targets with at least 1 Armor."
##
## BONUS_DAMAGE_SPECIFIC rather than BONUS_DAMAGE, for the same reason Blasting Powder uses it: it is
## rolled once PER TARGET with the target in the context, and it is never halved
## (event_unit_attack_declared.gd:284-286 passes halve = false). A plain BONUS_DAMAGE buff could not
## ask "does THIS target have armor" at all.
##
## require_hit = true on the .tres does the attack-roll gating through super(): BuffDamage demands
## context.object is an AttackRoll and that it hit (buff_damage.gd:19-29). inherit_type_from_attack
## keeps the bonus the weapon's own damage type, which is what "bonus damage" means on the card.
##
## THIS FILE OWNS THE SHARED PREDICATE. buff_ripper_mod_strip_ap.gd preloads this script and calls
## is_modded_weapon rather than restating it - the buff_hole_puncher_arcing.gd pattern. The two buffs
## are two halves of one mod and must agree exactly on which weapon they belong to; if they drifted,
## the mod would buff one weapon and disarm another and nothing would say so.
extends BuffDamage

## Is `weapon` the weapon this mod instance is fitted to?
##
## TAKES ITS THREE INPUTS AS ARGUMENTS ON PURPOSE. The two callers meet this question in different
## contexts and cannot share a Context-shaped signature: here the context is an ATTACK
## (context.gear the weapon, context.unit the attacker), while in the strip buff it is a DAMAGE event
## whose target_unit is the DEALER and whose holder arrives as triggers_on_event's own `unit`.
##
## `from_gear` is the BuffCore's attribution - the GearCore of the mod that applied the buff, set by
## unit_condition.gd:884-891 when PassiveWeaponMod.applied_buffs are applied at the start of combat.
## Comparing it against the weapon's currently fitted mod is what makes a second Ripper Mod on a
## second weapon buff only its own.
static func is_modded_weapon(weapon:GearCore, holder:Unit, from_gear:StringName) -> bool:
	if not GearCore.is_valid(weapon) or not Unit.is_valid(holder): return false
	var mod:GearCore = weapon.get_weapon_mod(holder.core.loadout)
	return GearCore.is_valid(mod) and mod.persistent_id == from_gear

## get_armor() is the frame's armor plus state.stat_bonus.armor (unit.gd:309), so armor granted by a
## STATBLOCK buff - SP4's Reinforcement Blast, an ally's aura - counts exactly as the card's "targets
## with at least 1 Armor" reads. There is deliberately no AP gate here: that clause was ruling 9's
## fallback, withdrawn when Spike 10 proved the strip (design 4.2).
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	# get_attacker(context), not context.unit: on a RELAYED attack (Buff.TO.SET_ATTACK_RELAY, the
	# Ghast's nexus) context.unit is the relay, not the mech carrying the loadout - and
	# is_modded_weapon looks the mod up in holder.core.loadout, which a relay does not have. The
	# engine itself resolves the same way one line before it queries this buff
	# (event_unit_attack_declared.gd:274), and the sibling strip buff already passes the buff HOLDER
	# (buff_ripper_mod_strip_ap.gd), so this is the two halves agreeing rather than a new rule.
	if not Unit.is_valid(context.unit): return false
	if not is_modded_weapon(context.gear, context.unit.get_attacker(context), core.from_gear): return false
	if not Unit.is_valid(context.target_unit): return false
	return context.target_unit.get_armor() >= 1
