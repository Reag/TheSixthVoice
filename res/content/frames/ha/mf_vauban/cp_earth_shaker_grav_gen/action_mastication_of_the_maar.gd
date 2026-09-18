## MASTICATION OF THE MAAR: "Choose a Blast 1 area within Sensors and line of sight that contains no
## hostile Characters. For the rest of the scene it becomes difficult terrain."
##
## EXTENDS ActionSystemDeploy RATHER THAN ActionSystem, which is a departure from design §2.3 and is
## the plan's Task 4 header's subject. The short version: the archetype already IS "a QUICK tile pick
## within Sensors needing line of sight" - deploy_to_sensors is the engine's only "range = Sensors"
## idiom (action_system_deploy.gd:28-29), can_target_unit is false outright (:25-26),
## get_target_requirements duplicates the .tres override before touching it (:31-38), and
## get_glossary_tags puts a "Persists" tag on the card precisely because dep_maar sets
## is_deactivated_on_owner_death = false (:53-60). Writing this as a plain ActionSystem would have
## meant re-implementing all of that, worse.
##
## ONE CORRECTION TO THE PLAN'S LIST, measured 2026-09-18: `needs_los` (action_system_deploy.gd:11) is
## a DEAD EXPORT on 1.4.3 - it is declared and then read nowhere in engine/ or content/. The line of
## sight this action actually requires comes from Action.requires_line_of_sight, which returns
## `requires_line_of_sight_baseline` (action.gd:36, :124) and also defaults true. The behaviour the
## card wants is therefore delivered, just not by the export the archetype advertises; so this .tres
## sets NEITHER flag and leans on the Action default, and eight vanilla .tres files that set
## `needs_los = false` are quietly not getting what they asked for.
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
## result. A measured divergence from ruling 8, recorded for the close and pinned by
## test_the_vaubans_own_tile_is_not_a_valid_centre.
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
	# The archetype's own activate, copied line for line down to the spawn
	# (action_system_deploy.gd:63-75), ordering included.
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
