# REACH's Reliable half (ruling 11, and the J measurement that ruling deferred to SP1).
#
# THE ENGINE ADDS RELIABLE. ActionAttackWeapon.add_tag_to_collection matches on the tag, and the
# RELIABLE arm is `new_value = old_value + tag_value` (action_attack_weapon.gd:134). Only THROWN takes
# a maxi (:135). Ruling 11's own reason says the function "writes weapon_tags[tag] = value"; it does
# not. So a flat added_tag_value of 2 would make a printed-Reliable-3 weapon Reliable FIVE, which
# Lancer's Reliable does not do and which the design's own spec list forbids ("a Reliable-3 weapon
# still deals 3").
#
# SO THIS RETURNS THE TOP-UP, NOT THE TARGET: maxi(0, added_tag_value - printed). On a Reliable-0
# weapon that is 2; on a Reliable-2 weapon, 0; on a Reliable-3 weapon, 0. Adding zero is a no-op, so
# the higher value stands in every direction, which is the rule.
#
# get_base_value_for_tag IS THE SAFE READER. It looks at the action's own `reliable_damage` export
# through Util.get_tiered_int (:119-126) and does NOT call get_weapon_tags - which this function is
# being called from (:169-172), so anything that did would recurse for ever.
#
# WEAPON MODS ARE NOT COUNTED as "printed", deliberately: get_weapon_tags folds a PassiveWeaponMod's
# added_tags in at :163-165, AFTER the base tags and BEFORE the buffs, and a mod's Reliable is not on
# the weapon's card. Recorded rather than defended - no weapon mod in this mod or in vanilla adds
# Reliable today, so there is nothing to measure it against.
#
# THE TIER comes from the unit, exactly as get_weapon_tags reads it (:145).
extends BuffWeaponTypeTag

func get_values(_core:BuffCore, context:Context) -> Context:
	var printed:int = 0
	if context.action is ActionAttackWeapon:
		var tier:int = 1
		if Unit.is_valid(context.unit): tier = context.unit.core.tier
		printed = context.action.get_base_value_for_tag(Lancer.WEAPON_TAG.RELIABLE, tier)
	return Context.create({
		category = added_tag,
		number = maxi(0, added_tag_value - printed),
	})
