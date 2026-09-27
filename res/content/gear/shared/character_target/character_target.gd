# CHARACTER TARGET: a buff-applying action that may target a DRONE. Born in close-out Pass F Task 11
# (2026-09-27, author decision T14) with three consumers at once:
#
#   Black Mountain  action_fell_the_mighty.gd       "a hostile character"
#   Rakshasa        action_entrap_rakshasa.gd       "a character"
#   Fitzgerald      action_reinforcement_blast.gd   "all characters within the area" (ms_grit_latch_magnets)
#
# A drone IS a character (close-out Pass A: "character" = Unit.is_character()). Vanilla's
# ActionSystemApplyBuff.can_target_unit refuses every non-actor outright -
# `if not potential_target.is_actor(): return false # cannot apply buffs to drones / objects`
# (action_system_apply_buff.gd:64) - so without this no buff action of ours could ever reach one.
# Throw Magnets (ms_makibishi_magnets) deliberately does NOT use it: a drone can never take the detach
# action, so the author kept it off drones (T14).
#
# THE CONSUMER SHAPE, which every consumer keeps - only a drone is sent here, everything else is still
# vanilla's own function, so objects stay refused:
#
#   func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
#       if not potential_target.is_drone(): return super(potential_target, specific)
#       return CharacterTarget.can_target_drone(self, potential_target, specific)
#
# A consumer with an extra gate after super applies it on the drone branch too.
#
# !! A COPY OF VANILLA. can_target_drone is ActionSystemApplyBuff.can_target_unit
# (engine/character/gear_action/archtypes/action_system_apply_buff.gd:59-79, modkit 1.4.3) with its
# is_actor() line (:64) removed and every member read through `action`. Lines :61-63 and :67-78 are
# otherwise verbatim. AFTER A MODKIT UPDATE, diff that function against this one: a gate vanilla adds
# there would silently not apply to drones here.
#
# FROZEN INTERFACE: can_target_drone, exactly this name, argument names and types.
# spec/test_character_target.gd pins it off Script.get_script_method_list().
#
# No class_name (res/content/gear/shared/README.md). Callers preload this file.
extends RefCounted

static func can_target_drone(action:ActionSystemApplyBuff, target:Unit, specific:SpecificAction) -> bool:
	if target == specific.unit and not action.can_apply_to_self: return false
	if action.is_tech and UnitCondition.is_immune_to_tech(target): return false
	if UnitRelation.is_hidden_from(target, specific.unit): return false
	# (vanilla's `if not potential_target.is_actor(): return false` is the one line not copied)

	# if we can't double apply, scan to make sure the target doesn't already have any of these buffs (from anyone)
	if not action.can_reapply and action.already_has_our_buff(target): return false

	# can only be used on a target 1/scene?
	if (
		(not action.skip_save(specific.unit, target)) and
		specific.gear.state_has_id_in(ActionSystemApplyBuff.USED_ON_KEY, target.core.persistent_id)
	): return false

	# -- apply onlies --
	if action.apply_only_to_self: return specific.unit == target
	if action.apply_only_to_enemies: return UnitRelation.are_enemies(specific.unit, target)
	if action.apply_only_to_allies: return UnitRelation.are_allies(specific.unit, target)
	return true
