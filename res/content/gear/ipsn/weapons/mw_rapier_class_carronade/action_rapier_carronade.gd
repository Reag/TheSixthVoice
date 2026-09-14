## The Rapier Class Carronade, the Fitzgerald's rank III weapon.
##
## "Main Cannon, Heat 2 (self), AP. 1d6+1 kinetic, Line 8. Ignores cover and deals 10 AP kinetic
## damage to all objects or terrain within the line." (Design §5.1, rules sheet "Rank III".)
##
## Everything except "ignores cover" is DATA, and lives in action_rapier_carronade.tres: the dice,
## the AP tag, the self-heat, the Line 8 range pattern and the targeting override are all exports
## ActionAttackWeapon already has. This script exists for the one clause the resource format cannot
## express.
##
## WHY "IGNORES COVER" IS A METHOD OVERRIDE AND NOT A TAG. There is no "ignores cover" entry in
## Lancer.WEAPON_TAG - the nearest thing is SEEKING, and SEEKING is not what this weapon is: it also
## waives line of sight, changes how the shot is previewed, and would make the Hole Puncher trait's
## ARCING grant redundant in a way the design does not intend. What the engine actually consults is
## a plain method. attack_roll.gd:153-157 gates the ENTIRE cover block -
##
##     if action is ActionAttackWeapon and not action.ignores_cover(context) and ignore_cover_buffs.is_empty():
##
## - so an attacker that answers true never runs CoverCalculator.determine_cover at all. The
## consequences are therefore negative and quiet: PreAttack.cover stays NONE, cover_sources stays
## empty, and no cover line is ever added to the accuracy breakdown. Nothing announces itself, which
## is why the spec's cover test fires a vanilla Cannon at the same target from the same tile as a
## control.
##
## The base implementation (action_attack_weapon.gd:206-212) is true only for SEEKING and for a
## melee weapon with threat; neither describes a Main Cannon, so there is nothing to fall through to
## and super() is not called.
##
## WHO ELSE READS THIS FUNCTION. buff_hole_puncher_soft_cover.gd's check_if_passive_applies calls it
## BY NAME:
##
##     if context.action.ignores_cover(context): return false
##
## That early return is the whole of the Hole Puncher interaction. On the Fitzgerald this weapon is
## both a Cannon and a Line weapon, so the trait hands it ARCING and it can be fired at a target
## nobody can see - but the trait's -1 "soft cover" is the price of shooting blind, and a weapon that
## ignores cover in its own right has no cover for that -1 to be "exactly" equal to. Delete the
## override below and the trait silently starts charging the Carronade for a penalty it is immune to;
## nothing would fail to compile. That is what the blindfire test in spec/test_rapier_carronade.gd
## pins.
##
## CONTEXT IS IGNORED ON PURPOSE. The answer must not depend on target, gear or geometry: the trait's
## gate above asks with one context and attack_roll.gd asks with another, and a conditional answer
## would let the two disagree - the trait standing aside while the cover calculation still ran, or
## the reverse.
##
## THE .tres CARRIES A target_requirements_override, AND THAT IS NOT DECORATION - recorded here
## because a .tres cannot hold a comment that survives an editor save. The flag the weapon actually
## needs is can_target_breakable_interiors, and the generated block has no room for it:
## get_target_requirements (action_attack_weapon.gd:216-223) builds a fresh TargetRequirements with
## count / range_pattern / can_target_setpieces / can_target_empty_tiles and never sets that one.
## An interior wall this weapon may not target is an interior wall that TRUNCATES the fired line,
## which would take the ruling ("the line reaches through interior walls" - SP4 plan, ruling 2) away
## before Task 2's demolition clause ever got to fire. The flag is declared in Task 1 even though
## nothing exercises it until Task 2: it is part of the weapon's declaration, not of the clause.
##
## An override REPLACES the generated block wholesale - the function returns on its first line, it
## does not merge. So can_target_setpieces and can_target_empty_tiles, which every AOE weapon gets
## for free, are re-declared in the .tres; dropping either silently narrows what the gun may be
## aimed at. And the override carries the SAME RangePattern SubResource the action does, not a
## second copy: ranged_distance (:182-184) reads reqs.range_pattern while get_target_range (:202-203)
## reads the action's own, so two separately-authored patterns would make the weapon's reach depend
## on which function asked.
##
## There is no action_type line in the .tres either, and that is deliberate: ActionAttackWeapon
## exports no such property (only action_system.gd and action_attack_tech.gd do). get_action_type
## (:87-91) derives it from weapon_size, returning FULL only for SUPERHEAVY - so weapon_size = MAIN
## IS the statement that this is a QUICK action, and writing action_type beside it would be an
## unknown property on this resource rather than a second opinion.
##
## weapon_size = 1, NOT 2. Lancer.WEAPON_SIZE is { AUX, MAIN, HEAVY, SUPERHEAVY, NONE }, so MAIN is
## 1 and 2 is HEAVY - which is what the frame's own Bizarre Cannon is, and is easy to copy across by
## mistake from action_bizarre_cannon.tres. The rules text says "Main Cannon"; a HEAVY reading would
## have changed which mount the gun fits and how the AI prices it, and nothing but this number says
## which it is.
##
## SP4 TASK 2 ADDS activate() TO THIS FILE, for the second clause (10 AP kinetic to every object,
## terrain block and interior wall in the fired line). It hangs off activate() rather than an
## OnHitEffect because the clause fires whether the shot hits or misses, exactly as
## action_bizarre_cannon.gd's recoil does - see that file for the DeclaredAttackSummary lookup and
## the activation.aborted guard such an override needs.
extends ActionAttackWeapon

func ignores_cover(context:Context) -> bool: return true
