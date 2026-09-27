## MASTICATION OF THE MAAR: "Choose a Blast 1 area within Sensors and line of sight that contains no
## hostile Characters. For the rest of the scene it becomes difficult terrain."
##
## EXTENDS ActionSystemDeploy RATHER THAN ActionSystem, which is a departure from design §2.3 and is
## the plan's Task 4 header's subject. The short version: the archetype already IS "a QUICK tile pick
## within Sensors needing line of sight" - deploy_to_sensors is the engine's only "range = Sensors"
## idiom (action_system_deploy.gd:28-29), can_target_unit is false outright (:25-26),
## get_target_requirements duplicates the .tres override before touching it (:31-38), and
## get_glossary_tags puts a "Persists" tag on the card precisely because dep_maar sets
## is_deactivated_on_owner_death = false (:52-59). Writing this as a plain ActionSystem would have
## meant re-implementing all of that, worse.
##
## ONE CORRECTION TO THE PLAN'S LIST, measured 2026-09-18: `needs_los` (action_system_deploy.gd:11) is
## a DEAD EXPORT on 1.4.3 - it is declared and then read nowhere in engine/ or content/. The line of
## sight this action actually requires comes from Action.requires_line_of_sight, which returns
## `requires_line_of_sight_baseline` (action.gd:36, :124) and also defaults true. The behaviour the
## card wants is therefore delivered, just not by the export the archetype advertises; so this .tres
## sets NEITHER flag and leans on the Action default, and the SEVEN vanilla .tres files that set
## `needs_los = false` are quietly not getting what they asked for. (Seven, re-counted at the close:
## action_high_angle_fire_bombard, action_firebreak_pyro, action_lingering_flames_deploy,
## action_stasis_barrier, action_plasma_thrower_deploy_flames, action_dimensional_emblems_deploy,
## action_magnetic_shield. Reag-ThyHubris's mf_banshee/cp_the_keening/action_tear.tres is an eighth
## victim, in our own mods rather than vanilla's.)
##
## BUT THE SPAWN IS STILL Terrain.lay's, AND THAT IS NOT DECORATION EITHER. The archetype's
## place_deployable creates the unit with unit.get_faction() (:117) and QUEUES the spawn, returning a
## Unit that is not on the map yet. Design ruling 8 wants a FACTIONLESS crater - it is ground, not an
## ally - and a caller that can tell whether the spawn actually landed. Terrain.lay gives both: it
## builds the unit as Faction.NONE, runs the spawn INLINE and awaits it, and returns NULL when the
## core came back null or aborted or the unit never reached the map. It is also the shared helper
## frozen at SP1 for exactly this, with Leoleth's Decimate and the Shackleton queued behind it
## (roadmap §4). Nothing in this file reshapes it.
##
## THE TARGET FILTER HAS NO VANILLA PRECEDENT, and that was measured rather than assumed: nothing in
## engine/ or content/ refuses a target tile because of WHO is standing in its area of effect.
## UnitTargeting.filter_for_free_spaces is the only hook that looks at a tile's contents at all, it is
## reached only when requires_free_space is set, and it consults TargetRequirements.check_if_tile_is_free
## for the direct tile and - when aoe_must_be_free_space is set - for every tile of the resulting AOE
## (unit_targeting.gd:245-266). ms_caltrop_launcher is the shape to copy: it replaces that callable
## with a predicate of its own (action_caltrop_launcher.gd:7-18). The only difference here is that the
## predicate asks whether the unit is a HOSTILE CHARACTER rather than whether it is any unit at all,
## which is why it has to carry the acting unit - hence the .bind(specific) below.
##
## WHAT THE FILTER LETS THROUGH, all of it design ruling 8: allies, objects, markers (so two craters
## may overlap) and the Vauban itself. WHAT IT COSTS: filter_for_free_spaces drops the acting unit's
## OWN tiles before asking the predicate anything (unit_targeting.gd:252-256), so the Vauban cannot
## centre a crater on the space it is standing in - it can centre one beside it and stand in the
## result. A measured divergence from ruling 8, recorded in rulings.md (2026-09-18, "The Vauban cannot
## centre a Maar on its own space") and pinned by test_the_vaubans_own_tile_is_not_a_valid_centre.
##
## AND ONE MORE THING IT LETS THROUGH, WHICH IS A CLOSE RULING (M-5, 2026-09-18): INVALID ENDPOINTS.
## Replacing check_if_tile_is_free wholesale rather than composing with it drops the FIRST clause of
## TargetRequirements.standard_check_if_tile_is_free, which is a terrain test and not a unit test -
## `if map.get_surface_terrain_at(tile).is_invalid_endpoint(): return false` (target_requirements.gd:76,
## reached from the archetype's deploy_check_if_tile_is_free at action_system_deploy.gd:48). 45 vanilla
## .tres files set invalid_endpoint - wall tops, rocks, smokestacks, mt_stasis_barrier - so the Vauban
## really can centre a crater on one. THAT IS CORRECT AND IT IS KEPT. The card names exactly one
## restriction ("contains no hostile Characters"), so adding a terrain clause would narrow it; a
## MARKER has nothing to stand on and intersects setpieces without complaint; and this is the vanilla
## precedent the file already copies, deliberately, in vanilla's own words -
## action_caltrop_launcher.gd:13, "skip checking for invalid endpoints from setpieces; we can
## intersect those just fine". Terrain.lay bounds-checks and nothing else (terrain.gd:143), so no
## other layer re-imposes it. Pinned by test_a_tile_on_an_invalid_endpoint_is_still_a_valid_centre.
##
## AND A WARNING FOR ANYONE WRITING A SPEC AGAINST THIS: the filter governs the player's TARGETING
## SCREEN, not the activation. TargetActionUtil takes a supplied tile automatically and never
## re-validates it against get_tiles_targetable (target_action_util.gd:230-242), so
## SpecFactory.use(..., a_forbidden_tile) lays a crater there quite happily. Ask
## UnitTargeting.get_tiles_targetable, the way test_mastication_of_the_maar.gd does.
##
## IT SPENDS NOTHING BUT THE QUICK ACTION. No charges, no core point (the protocol spends that), no
## hibernation: the card is a Quick action usable every turn, and the only limit on how much of the
## board it can turn into difficult ground is how many turns the scene lasts.
extends ActionSystemDeploy

const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

func get_target_requirements(specific:SpecificAction) -> TargetRequirements:
	# super() duplicates target_requirements_override before touching it, so the shared Resource is
	# never mutated; it then installs the archetype's own mine-adjacency check, which this line
	# replaces. The Maar is not a mine (dep_maar leaves is_mine false), so nothing is lost.
	var reqs := super.get_target_requirements(specific)
	reqs.check_if_tile_is_free = no_hostile_character_here.bind(specific)
	return reqs

## The predicate UnitTargeting calls for the centre tile and for every tile of its Blast 1
## (unit_targeting.gd:253-265). Callable.bind APPENDS, so the engine's call(tile, map) arrives here as
## (tile, map, specific).
##
## include_markers is TRUE on purpose (map_state.gd:314-321): the filter has to SEE a marker in order
## to deliberately let it through, and leaving markers invisible would make the "two craters may
## overlap" clause an accident of the accessor rather than a decision. whos_asking stays null because
## that argument filters by UnitRelation.can_affect, which is a different question from "is anybody
## standing here".
static func no_hostile_character_here(tile:Vector2i, map:MapState, specific:SpecificAction) -> bool:
	if not SpecificAction.has_valid_unit(specific): return true
	return not map.get_all_units_at_tile(tile, null, true).any(func(unit:Unit) -> bool:
		if unit.has_status(Lancer.STATUS.EXILED): return false # not really here
		if not unit.is_character(): return false # objects and markers do not block - ruling 8
		return UnitRelation.are_enemies(specific.unit, unit)
	)

func activate(context:Context, activation:EventCore) -> void:
	# The archetype's own activate down to the spawn (action_system_deploy.gd:63-75), ordering
	# included - with ONE deliberate divergence, corrected here at the close because the header used
	# to claim "line for line" and it is not.
	#
	# WHAT IS DROPPED IS LINE :75's EMPTY-TARGET FALLBACK. The archetype spawns at
	# `plan.target_tiles if not plan.target_tiles.is_empty() else unit.occupied_tiles()`; the loop
	# below has no else. A plan that is valid but EMPTY is reachable - CompconPlan.is_valid_with_targets
	# refuses only when requires_tile_target holds and neither tiles nor units are all-valid
	# (compcon_plan.gd:48-52), and Tile.all_valid([]) is vacuously true - so such a press spends the
	# Quick action and lays nothing.
	#
	# THAT IS THE RIGHT TRADE HERE. The fallback exists for smoke mines detonating at their layer's
	# feet (the archetype says so at :74), and the Vauban cannot centre a crater on its own tile at
	# all: filter_for_free_spaces drops the acting unit's own tiles before the predicate is asked
	# (unit_targeting.gd:252-256, pinned by test_the_vaubans_own_tile_is_not_a_valid_centre). So the
	# fallback would deploy exactly where the targeting screen refuses to let the player aim, which is
	# worse than laying nothing. No spec produces an empty plan, so nothing reddens either way; the
	# divergence is recorded rather than tested.
	var unit:Unit = context.unit

	# get the chosen target tile, either from the player or the AI
	var plan:CompconPlan = await get_deploy_plan_targets(context, activation)
	if activation.abort_when(not CompconPlan.is_valid_with_targets(plan, context)): return

	spend_actions(activation)
	await run_system_fxgs(unit, plan.target_tiles)
	if activation.abort_without_unit(unit): return

	# ...and then the spawn is ours, for the faction and the return value. See the header.
	for centre:Vector2i in plan.target_tiles:
		var laid:Unit = await Terrain.lay(activation, SpecificAction.from_context(context), centre, deployable_frame)
		if laid == null: return # the spawn did not land; nothing to report, nothing to clean up
		if activation.abort_if_level_exited(): return
