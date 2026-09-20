# THE AoE HALF OF THE GREY BIRDS (ruling 17b): a TILE-targeted attack never asks
# ACTION_BANNED_UNITS at all, so the ban cannot reach it, and an AoE aimed at an ally would go
# through untouched. This rewrites the declared attack in place at ATTACK_DECLARED PRE so it is
# centred on the Sluagh instead.
#
# THE SEAM. event_unit_attack_declared.execute_preblock awaits the ATTACK_DECLARED PRE reactions
# (:21-23) BEFORE execute reads directly_attacked_tiles / all_attacked_tiles (:35-36), duplicates
# all_attacked_units for the per-target rolls (:54), runs them (:67) and hands all_attacked_tiles to
# the ground-damage event (:192-196). Nothing in between copies the summary, so rewriting its arrays
# IN PLACE is seen by every one of them.
#
# A BUFF, NOT A REACTION, and that is the difference from Draw Fire: the Sluagh is not the one
# reacting - its VICTIM is the one whose attack is rewritten - so there is no reaction point to
# spend, no 1/round, no prompt, and the listener has to live on the attacker. The bus asks every
# buff on every unit for every trigger (reaction_bus.gd:50, :61) with no filter of its own, so the
# holder test in triggers_on_event is load-bearing rather than a rare-case guard.
# buff_wormhole_grasp_half.gd is this mod's own precedent for a PRE buff mutating a declared attack.
#
# STEPS 2 AND 3 ARE action_draw_fire.gd:363-423, LINE FOR LINE, including the non-duplicate appends
# its own comments record as measured-redundant-and-kept - so a future change to the engine's
# get_aoe_tiles de-duplication shows up as one diff across both files. STEP 1 IS NOT: Draw Fire moves
# only the direct target tiles an ALLY stands on and has a whole splash case for an AoE that catches
# one without aiming at it, where this card moves EVERY direct target onto one aim tile. That is why
# this is a copy of two thirds rather than a call into that file, which would make the Sluagh depend
# on the Subutai's frame script. Two in-mod instances now; extract at the third (the Rakshasa).
#
# IT DOES NOT READ OR WRITE DRAW FIRE'S DRAWN_META STAMP. Both are PRE writers on the same summary,
# and the bus walks units in map order taking gear reactions then buffs - so a Subutai and a Sluagh
# acting on one shot compose, last writer winning, with both rebuilds refiltering through the
# attacker's own can_target_unit so the result is legal either way. No ruling says which card should
# win; recorded rather than invented.
#
# get_required_triggering_context RETURNS NOTHING, AND THAT IS THE WHOLE REASON THE EXPIRY SURVIVES.
# Draw Fire's is [unit, gear, action, resource] - correct for a reaction listening to ONE trigger.
# This buff listens to TWO, and Buff.check_required_triggering_context is asked for BOTH
# (buff.gd:258-262, via reaction_bus.gd:136 and again at event_buff_activate.gd:14): event_round_new
# carries only `map`, so any prop listed here would silently disable this buff's own expiry and
# leave the ban and the chip clearing without it. The summary is validated in triggers_on_event
# instead, which is where the branch already is.
extends "res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_o_trickery/buff_grey_birds_lifetime.gd"

## The two triggers are told apart by the SUMMARY, not by the event's name. Both branches need the
## answer to "is there a declared attack here?" anyway, and event_unit_attack_declared's own
## check_specific_context guarantees a valid one (:15-18) while event_round_new's context carries
## none - so this is the same discrimination the Argonaut's match on base.event_type makes
## (buff_argonaut_shield.gd:42-44), asked as the question each branch actually has.
static func is_attack(context:Context) -> bool:
	return context != null and DeclaredAttackSummary.is_valid(context.resource)

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if not is_attack(context): return super(core, unit, triggering_event) # the NEW_ROUND expiry

	# OUR HOLDER'S OWN ATTACK, and nobody else's. The bus polls this buff for every declared attack
	# by every unit on the map.
	if context.unit != unit: return false
	if not Action.is_valid(context.action): return false
	var owner:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(owner): return false
	# An attack already covering the Sluagh needs no re-aiming. There is no target_unit on this
	# context, so the question is asked of the summary.
	var summary:DeclaredAttackSummary = context.resource
	if summary.all_attacked_units.has(owner): return false
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return false
	# NO PATTERN, NO RECENTRE. get_range_pattern_for_targets returns reqs.range_pattern
	# (action.gd:204-206), which is null for a weapon whose .tres never set one - a single-target
	# shot, which the BAN already steers and which must not be rewritten twice.
	if specific.action.get_range_pattern_for_targets(
		specific, specific.unit.tile(), summary.directly_attacked_tiles
	) == null: return false
	return rebuild(owner, context, false)

func activate(core:BuffCore, activation:EventCore) -> void:
	var triggering:EventCore = activation.context.event
	if not is_attack(triggering.context if triggering != null else null):
		super(core, activation) # Buff.activate's default body: clear myself
		return
	var owner:Unit = core.get_owner_unit(activation.context.map)
	if not Unit.is_valid(owner): return
	# RUN LIVE, and its return is deliberately not checked: unlike Draw Fire there is nothing to
	# spend, so a rebuild that has become illegal since the dry run simply leaves the attack alone.
	rebuild(owner, triggering.context, true)

## DRY (live = false) answers "would the rebuilt area contain the owner?"; LIVE writes the four
## summary arrays in place.
##
## THE AIM TILE IS THE OWNER'S OCCUPIED TILE CLOSEST TO THE ATTACKER, not its anchor - the generous
## reading of "could target you" and the one a player aiming by hand picks. Draw Fire's own header
## (action_draw_fire.gd:289-301) records what that choice does and does not change.
static func rebuild(owner:Unit, triggering_context:Context, live:bool) -> bool:
	var specific := SpecificAction.from_context(triggering_context)
	var summary:DeclaredAttackSummary = triggering_context.resource
	var map:MapState = specific.unit.map
	if summary.directly_attacked_tiles.is_empty(): return false
	var aim:Vector2i = Tile.closest_possible_to(owner.occupied_tiles(), specific.unit.tile())

	# 1. "THEY MUST TARGET YOU WITH THAT ACTION": every direct target tile becomes the aim tile,
	# deduped to one. This is where this file and Draw Fire part company - that one moves only the
	# tiles an ALLY is standing on and leaves the rest where the attacker put them.
	var new_targets:Array[Vector2i] = [aim]

	# 2. the area and the units in it - action_draw_fire.gd:363-400, line for line
	var reqs := specific.action.get_target_requirements(specific)
	var pattern := specific.action.get_range_pattern_for_targets(specific, specific.unit.tile(), new_targets)
	var new_tiles:Array[Vector2i] = []
	var new_units:Array[Unit] = []
	if pattern and not reqs.aoe_is_just_for_show:
		# A BURST IS CENTRED ON THE ACTOR (range_pattern.gd:45-46 takes occupied_tiles[0] and ignores
		# target_tiles entirely): there is nothing to re-aim, so refuse outright rather than
		# half-apply. Draw Fire's own copy of this line is measured redundant - the reach check below
		# refuses a Burst one step later - and is kept for the same reason: it says WHY.
		if pattern.pattern == Lancer.AOE_TYPE.BURST: return false
		for tile:Vector2i in specific.action.get_aoe_tiles_with_targets(pattern, new_targets, specific.unit.tile(), specific):
			Util.append_nonduplicate(new_tiles, tile)
		for aoe_unit:Unit in map.get_all_units_at_tiles(new_tiles, specific.unit):
			Util.append_nonduplicate(new_units, aoe_unit)
	else:
		# Reachable only for a tile-targeted attack with no usable pattern (aoe_is_just_for_show);
		# a unit-targeted one is steered by the ban and never gets here.
		new_tiles = new_targets
		Util.append_nonduplicate(new_units, owner)
	# THE ATTACKER'S OWN TARGETING HAS THE LAST WORD - including our own ban, which answers false for
	# the owner (its target_unit == owner clause) and so lets them through.
	Util.filter(new_units, specific.action.can_target_unit.bind(specific))
	CommonActionUtil.sort_deployables_and_grunts_to_back(new_units)

	# A Line or Cone that cannot reach the owner, refused (ruling 17).
	if not new_units.has(owner): return false
	if not live: return true

	# 3. IN PLACE. ASSIGNED, never replaced: the arrays' declared element types are preserved and any
	# future reader that caches one before the PRE reactions run still sees the rewrite.
	summary.directly_attacked_tiles.assign(new_targets)
	summary.all_attacked_tiles.assign(new_tiles)
	summary.all_attacked_units.assign(new_units)
	# A Blast's cover origin is its CENTRE, not the firer (action_attack.gd:179-185), and
	# PreAttack.create takes cover from source_voxels - so recomputing this is what gives the
	# recentred blast the right cover.
	summary.source_voxels.assign(specific.action.get_origin_voxels(specific, new_targets, specific.unit.tile()))
	return true
