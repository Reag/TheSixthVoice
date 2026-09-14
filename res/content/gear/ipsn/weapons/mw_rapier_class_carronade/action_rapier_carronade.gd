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
## THE .tres CARRIES A target_requirements_override, AND THAT IS NOT DECORATION - recorded here
## because a .tres cannot hold a comment that survives an editor save. The flag the weapon actually
## needs is can_target_breakable_interiors, and the generated block has no room for it:
## get_target_requirements (action_attack_weapon.gd:216-223) builds a fresh TargetRequirements with
## count / range_pattern / can_target_setpieces / can_target_empty_tiles and never sets that one.
## An interior wall this weapon may not target is an interior wall that TRUNCATES the fired line,
## which would take the ruling ("the line reaches through interior walls" - rulings.md, 2026-09-14,
## "Rapier Class Carronade (SP4)") away before Task 2's demolition clause ever got to fire. The flag
## is declared in Task 1 even though nothing exercises it until Task 2: it is part of the weapon's
## declaration, not of the clause.
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
## SP4 TASK 2 ADDED activate() TO THIS FILE, for the second clause (10 AP kinetic to every object,
## terrain block and interior wall in the fired line). It hangs off activate() rather than an
## OnHitEffect because the clause fires whether the shot hits or misses, exactly as
## action_bizarre_cannon.gd's recoil does - that file is the direct precedent for the
## DeclaredAttackSummary lookup and the activation.aborted guard, and its warning about
## context.target_tiles is repeated below because it applies here word for word.
extends ActionAttackWeapon

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
## and super() is not called. Two vanilla weapons make the identical override, for the identical
## reason (an unconditional true, no tag fits): ms_stasis_bolt's
## action_interdiction_point_weapon.gd:10 and npcc_assassin's
## action_explosive_knives_assassin_weapon.gd:10. This override is idiomatic, not novel.
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
func ignores_cover(context:Context) -> bool: return true

## The second clause: "deals 10 |AP| kinetic damage to all objects and terrain within the line."
##
## A FLAT NUMBER, NOT A DICE STRING. The rules text says 10, not 1d6+4 and not "as the shot": the
## demolition is what the gun IS, not a consequence of how well it was aimed. Vanilla's own fixed
## map damage is written the same way - action_thermal_grenade.gd declares
## `const GRENADE_TERRAIN_DAMAGE:int = 10` and hands it straight to the event - so this is the
## idiomatic shape, and it is a const rather than an @export because no second profile of this
## weapon exists or is planned. (Contrast action_bizarre_cannon.gd, whose recoil magnitudes ARE
## exports precisely because a second profile varies them.) spec/test_rapier_carronade.gd's
## test_the_rules_text_promises_the_damage_the_code_deals reads this constant back out of the script
## and compares it with the number in the player-facing localization row, so the prose and the code
## cannot drift apart.
const LINE_TERRAIN_DAMAGE:int = 10

## Fire, then wreck the line.
##
## THE ORDER MATTERS AND IS NOT NEGOTIABLE. super.activate() is what declares the attack, and
## declaring the attack is what puts the fired line on the context (see swept_tiles below) - so the
## map damage cannot be queued first. It also means the attack's own incidental ground damage
## (event_unit_attack_declared.gd:180-196, which an AOE weapon gets for free) has already landed by
## the time this queues, and GamemasterCore.tile_damage ACCUMULATES across events
## (landscape_node.gd:813): the 10 is added to whatever the shot itself already did to those tiles,
## which is the reading the rules text wants.
##
## HOW MUCH THE SHOT ITSELF ALREADY DID, AND WHY IT IS THE SAME ON A HIT AND A MISS. The incidental
## ground damage is get_damage_to_terrain_and_objects(specific, base_damage)
## (event_unit_attack_declared.gd:183), which returns
## DamageRollSummary.get_non_heat_amount(damage_data.get_hits()) (action_attack.gd:57-69).
## get_hits() reads each roll's own `hit` value (attack_util.gd:127) and is ROLL-INDEPENDENT: it is
## never asked whether the attack landed, and the per-attack-roll bonus damage that WOULD vary goes
## into a duplicate summary instead (event_unit_attack_declared.gd:142, roll_specific_bonus_damage
## at :288) and never reaches base_damage. So for this weapon - 1d6+1, no reliable, no bonus damage
## - the base attack puts the SAME number into the ground whether it hit or missed: 7 with the
## damage die at a 6. That is what the clause's 10 is carrying over a standard block's 15 health
## (terraindata_standard_block.tres): 7 + 10 = 17 destroys it, 7 alone never does.
## (An earlier note here and in the spec claimed the base attack did 20 on a hit and 7 on a miss.
## It was a cheat-dice artefact, not engine behaviour - see the spec's section header.)
##
## THE ABORT GUARD. An aborted activation is a shot that was never fired: ActionAttack.activate
## bails before spend_actions when targeting is cancelled, so there is no cost, no attack and there
## must be no demolition either. Vanilla guards its own followup attacks the same way
## (action_attack_weapon.gd:61), and the frame's Bizarre Cannon guards its recoil the same way.
##
## IT IS UNREACHABLE BY THE ABORTS THE SPEC EXERCISES, AND LOAD-BEARING FOR THE REST. That was
## MEASURED rather than assumed: moving it below the queue_event left the whole spec green
## (.superpowers/sdd/sp4-t2-mutation-b-abort-guard-below-queue.log, 2026-09-14). The reason is that
## every abort spec/test_rapier_carronade.gd can reach - the cancelled or invalid targeting plan
## (action_attack.gd:236), the friendly-fire and aoe-no-targets confirms (:247, :249) and the
## mid-choice unit check (:250) - happens BEFORE context.resource is assigned the
## DeclaredAttackSummary (action_attack.gd:259). In those states swept_tiles() comes back empty and
## the is_empty() guard below catches it first.
##
## THE ABORTS AFTER THAT ASSIGNMENT ARE WHAT THIS GUARD IS FOR, and they exist in the engine today:
## action_attack.gd:266 (abort_without_unit, immediately after run_attack_effects) and the two
## inside run_attack_effects itself (:201, :227), which are handed this same activation and set
## aborted through abort_when -> set_aborted (event_core.gd:26-32). In any of those states the
## declared summary is valid and non-empty, so this guard is the ONLY thing standing between an
## aborted shot and a queued demolition. Do NOT read the green mutation as permission to delete it -
## read it with the second mutation beside it, which removed BOTH and reconstructed the line from
## the targeting hint, and did put 10 AP into terrain the shot never swept
## (.superpowers/sdd/sp4-t2-mutation-b2-line-from-the-hint.log).
func activate(context:Context, activation:EventCore) -> void:
	await super.activate(context, activation) # make the attack
	if activation.aborted: return
	# NO Unit.is_valid(context.unit) / GearCore.is_valid(context.gear) guard here, unlike the sibling
	# action_bizarre_cannon.gd:28. That weapon's recoil() dereferences both (it knocks the FIRER
	# back, off the firer's own tiles). Nothing below touches either one: the tile list comes off
	# context.resource and the event is addressed to tiles, so a firer that died or was unequipped
	# mid-activation still leaves a well-formed demolition. Adding the guard would not be wrong, only
	# inert - and the abort guard above already covers the case where the engine noticed.

	var swept := swept_tiles(context)
	# A shot whose line cannot be reconstructed must damage NOTHING. Handing event_map_damage an
	# empty tile list would be harmless today (its check_specific_context refuses one), but any
	# future fallback to "the unit's own tiles" - the mistake generate_knockback_events makes by
	# design, see action_bizarre_cannon.gd - would put 10 AP under the firer's own feet.
	if swept.is_empty(): return

	activation.queue_event(&'event_map_damage', {
		target_tiles = swept,
		number = LINE_TERRAIN_DAMAGE,
		flags = [
			# AP: the rules text says AP, and it does two separate jobs here. It waives the
			# terrain's own armor in LandscapeNode.damage_tile (landscape_node.gd:890, the `if not
			# is_ap` line - a standard block has 2), and
			# it is the flag event_map_damage.gd:59 turns into DAMAGE_FLAG.AP on every object damage
			# event it spawns.
			EventMapDamage.FLAG.AP,
			# "...to all OBJECTS and terrain". Without this the event touches terrain only; with it,
			# every is_object() unit standing in the line takes the 10 as a damage event of its own,
			# with no attack roll involved (event_map_damage.gd:57-70). The attack's own incidental
			# ground damage never sets it, which is why this flag is the whole of the object half of
			# the clause.
			EventMapDamage.FLAG.ALSO_DAMAGE_OBJECTS,
			# The interior-wall half, ruled in on 2026-09-14. It is UNCONDITIONAL DEMOLITION and not
			# the 10 doing the work: terraindata_breakable_interior.tres has health = 0, so
			# TerrainBlockData.is_destructable() is false and no amount of map damage could ever
			# touch it (event_map_damage.gd:46-53 removes the setpiece outright, before and
			# independently of any damage). The author ruled it in knowing that - there was no middle
			# option, because without can_target_breakable_interiors on the targeting side the line
			# is truncated at the first interior wall anyway.
			EventMapDamage.FLAG.REMOVE_BREAKABLE_INTERIORS,
			# NOT BURN. BURN marks the tiles as burnt (landscape_node.gd:798 - event_map_damage.gd
				# is only 91 lines long and merely forwards the flag) and is what the
			# Thermal Grenade sets, because a thermal grenade sets fires. This is a solid shot of
			# kinetic; it knocks a hole in things and starts nothing. The engine agrees with that
			# reading elsewhere: event_unit_attack_declared.gd:188 adds BURN to a weapon's own ground
			# damage only when the damage type is not KINETIC.
		],
	})

## The tiles the shot actually swept.
##
## READ OFF THE DECLARED ATTACK, NOT context.target_tiles. This is action_bizarre_cannon.gd's
## recoil_origin_tiles() lookup and its warning applies here verbatim: context.target_tiles is only
## an incoming targeting HINT (event_gear_activate.gd:22-23). A spec or the AI may supply it, but
## when a player aims the shot the tiles are picked inside ActionAttack.get_attack_plan and land in
## plan.target_tiles, never back on the context - so in real play context.target_tile is
## Tile.INVALID and an implementation that trusted it would demolish nothing for the only user who
## matters. What IS always set by the time super.activate() returns is context.resource, the
## DeclaredAttackSummary (action_attack.gd:252-259).
##
## all_attacked_tiles is "all tiles directly targeted + caught in any AOE blasts"
## (declared_attack_summary.gd:10), which for a Line weapon is the whole swept line - measured as
## [(3,4), (4,4), (6,4), (7,4), (8,4), (9,4), (10,4)] for an eight-long line whose third ring was a
## forbidden interior. directly_attacked_tiles (plan.target_tiles, the aimed-at tile alone) is the
## fallback for an attack that somehow produced no AOE expansion; it is deliberately NOT a fallback
## to the firer's position, and the caller above refuses to queue anything when both come back empty.
##
## THIS IS WHERE THE CLAUSE INHERITS THE WEAPON'S TARGETING. Because the summary is what the engine
## itself swept, the interior walls the .tres's can_target_breakable_interiors admitted are in this
## list, and the tiles ARCING kept in it (no line-of-sight filter, Action.get_aoe_tiles_with_targets)
## are too. Recomputing the line here instead would quietly answer a different question.
##
## THE RESULT IS DUPLICATED, AND THAT IS DELIBERATE. all_attacked_tiles is the summary's own live
## array, and the caller hands what comes back to a QUEUED event that runs later - so returning it
## by reference would let anything that mutated the summary in between silently change which tiles
## get demolished. Nothing mutates it today; the duplicate makes the question not worth asking.
func swept_tiles(context:Context) -> Array[Vector2i]:
	if not DeclaredAttackSummary.is_valid(context.resource): return []
	var declared:DeclaredAttackSummary = context.resource
	var fired:Array[Vector2i] = declared.all_attacked_tiles
	if fired.is_empty(): fired = declared.directly_attacked_tiles
	return fired.duplicate()
