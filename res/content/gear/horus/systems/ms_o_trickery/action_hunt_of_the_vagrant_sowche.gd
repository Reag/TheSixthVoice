# HUNT OF THE VAGRANT SOWCHE, O' Trickery's second invade (SP2 Task 8, rulings 5 and 18).
#
#   "Your target must succeed a Systems save or be teleported to a free space adjacent to the closest
#    character. If there are multiple characters tied for closest, you choose. This can only be used
#    1/scene on each character."
#
# SIX STEPS IN on_hit, IN THIS ORDER, AND THE ORDER IS THE RULING. The stamp goes on FIRST, because
# the HIT is the "use" (ruling 18): a miss leaves the character available, a PASSED SAVE does not.
# Those two outcomes are the same absence of a move, so only the stamp tells them apart - which is
# also why the spec pins both.
#
# THE STAMP IS append_to_array_state, NOT state_add_id. The design and the brief both name a
# state_add_id that does not exist on GearCore: the writer is append_to_array_state
# (gear_core.gd:263-269) and the reader is state_has_id_in (:287-288). Vanilla's own per-target
# 1/scene stamp is specific.gear.append_to_array_state(USED_ON_KEY, target.core.persistent_id)
# (action_system_apply_buff.gd:161), and its refusal - which reads the stamp UNCONDITIONALLY rather
# than behind the once_per_scene_per_target flag (:70-73) - is the shape can_target_unit copies here.
# Gear state is cleared by short repair with the rest of it, which is what makes it "1/scene".
#
# THE SAVE'S FORCING ACTION MUST BE THE FULL TRIFECTA. UnitCondition.forced_save dereferences
# forcing_action.unit with no null guard (unit_condition.gd:70), and UnitHasecheck.run_save_event
# copies unit/gear/action off it onto the save event (:78-88) so the battle log and the saver's
# TO.SAVE buffs can read the forcer. A bare-unit call degrades both.
#
# "CHARACTER" IS Unit.is_character(), A DRONE INCLUDED (rulings.md, mod-wide row of 2026-09-27).
#
# THE SEARCH WALKS PAST WHATEVER HOLDS THE TARGET (holders_of, the Hunt-local half of that ruling).
# An engager is adjacent by definition (UnitRelation.can_be_engaged_by:154), so it is always at
# distance 1 and every tile in its ring is beside it: counted, it always wins, and the Hunt could
# never drag a target clear of the thing holding it - the card's whole point. The same holds for a
# grappler, engaging or not. test_hunt pins the drone, a mech engager and a same-side grappler.
#
# THE DESTINATION SET IS Teleport.candidate_tiles, NOT UnitTile.filter_to_free_tiles. The design
# named the latter "for the target's size"; it takes no unit and no size, returns void and filters in
# place (unit_tile.gd:605-610) with a per-tile predicate that knows nothing about a footprint
# (target_requirements.gd:74-84). candidate_tiles uses UnitTile.is_tile_standable with
# Katamari.create_solipsistic(mover) - the engine's real free-space test, which reaches Occupation's
# bigunit_invalid_endpoint (pathfinder.gd:805-812) and is therefore size-aware - and already drops the
# mover's own tiles, because a teleport to where you stand is not a move (Teleport.candidate_tiles' docstring). The `keep`
# hook exists for exactly this kind of caller-side filter.
#
# THE TILE PICK BELONGS TO THE SLUAGH'S PLAYER (ruling 5), and the helper delivers that without an
# argument: TargetActionUtil.ask_for_targets_alt defaults deciding_unit to specific.unit
# (target_action_util.gd:156), and pick_tile builds its specific from context.unit - the Sluagh.
#
# NOTHING VALIDATES THE ANSWERED PLAN, which is why the SPEC asserts on the offered set rather than
# on the landing: ask_for_targets_alt returns a player's plan unchecked when it carries no movement
# (target_action_util.gd:227). That is the engine's business, not this action's - the set handed to
# pick_tile is the contract this file owns, and it is the thing the spec reads back.
#
# NO BATTLE-LOG ROW IS INVENTED. The empty-set case logs through X.printv, because a battle_log row
# needs a localisation row and the localisation directive is the LCP verbatim.
extends ActionAttackTech

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')

## Vanilla's own key, so the two stamps are spelled the same way if anything ever reads both
## (action_system_apply_buff.gd:5).
const USED_ON_KEY := 'used_on'

## Tile.get_closest_pair_between's "no pair at all" answer (tile.gd:409): a unit placed beyond the
## map has no occupied tiles and every distance to it reads as this. sluagh_fixture.gd:28-31 records
## the trap; a nearest-character search that did not guard it would pick the sentinel.
const UNREACHABLE := 1000

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not super.can_target_unit(potential_target, specific): return false
	if not GearCore.is_valid(specific.gear): return true
	return not specific.gear.state_has_id_in(USED_ON_KEY, potential_target.core.persistent_id)

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	var context:Context = activation.context
	if not Unit.is_valid(attacked_unit) or not Unit.is_valid(context.unit): return
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return

	# 1. THE STAMP, FIRST. The hit is the use.
	specific.gear.append_to_array_state(USED_ON_KEY, attacked_unit.core.persistent_id)

	# 2. THE SAVE. Saver = attacked_unit, forcer = specific.unit (unit_hasecheck.gd:42-45, :79-84 -
	# the saver is `target_unit = unit` at :79 and the forcer's three fields are :82-84).
	var passed:bool = await UnitHasecheck.make_systems_save(activation, attacked_unit, specific)
	if activation.abort_without_units([context.unit, attacked_unit]): return
	if passed: return

	# 3. THE CLOSEST CHARACTER.
	var closest:Unit = await pick_closest_character(context, attacked_unit)
	if not Unit.is_valid(closest): return
	if activation.abort_without_units([context.unit, attacked_unit]): return

	# 4. THE FREE SPACES ADJACENT TO IT.
	var tiles := destinations_beside(attacked_unit, closest)
	if tiles.is_empty():
		X.printv('  Hunt of the Vagrant Sowche: no free space beside %s; the save was still forced.'
			% closest.core.get_mech_name())
		return

	# 5. THE PICK - the Sluagh's player, through the helper's own reticle.
	var tile:Vector2i = await Teleport.pick_tile(context, activation, tiles)
	if tile == Tile.INVALID: return # cancelled; the stamp stands, the save was forced
	if activation.abort_without_units([context.unit, attacked_unit]): return

	# 6. THE SHOVE.
	var core:EventCore = await Teleport.shove(activation, attacked_unit, tile)
	if core != null and core.aborted:
		X.printv('  Hunt of the Vagrant Sowche: the teleport was vetoed before it resolved.')

## Every character tied for closest to `target`, as one prompt when there is more than one.
##
## ANY FACTION, THE SLUAGH INCLUDED, THE TARGET EXCLUDED (ruling 18). A single winner is auto-picked
## with no prompt at all - which is a behaviour the spec asserts on the ABSENCE of a recorded prompt,
## so it has to be a real branch rather than a one-element prompt. get_all_characters is the card's
## word already (is_character(), map_state.gd:231-235), drones included.
func pick_closest_character(context:Context, target:Unit) -> Unit:
	var best:int = UNREACHABLE
	var tied:Array[Unit] = []
	var holders := holders_of(target)
	for other:Unit in target.map.get_all_characters():
		if other == target or not Unit.is_valid(other): continue
		if holders.has(other): continue # see holders_of and the header
		var distance:int = UnitRelation.distance_between(target, other)
		if distance >= UNREACHABLE: continue # off the map; see the constant
		if distance < best:
			best = distance
			tied = [other]
		elif distance == best:
			tied.append(other)
	if tied.is_empty(): return null
	if tied.size() == 1: return tied[0]
	# AI-CONTROLLED, NO PROMPT. A tech attack is never gathered by Cascade Personalities' fallback,
	# so it is never scanned; vanilla's AI runs it (Cascades, or Hand Over Control's
	# buff_hand_over_control, unit.gd:252) and this picker would open with nobody to answer it.
	# Author's ruling 2026-09-28: the first tied character, in map order. Kill Host's shape.
	if not context.unit.is_player_controlled(): return tied[0]
	# Halo's prompt, on this mod's own precedent (action_halo.gd). can_voluntarily_cancel is TRUE:
	# declining leaves the target where it is, which is strictly better than forcing a choice the
	# player does not want - and the save was forced either way.
	return await choice_bus.choose_unit(tied, true, SpecificAction.from_context(context))

## Every unit holding `target` where it stands: engaging it, or in a grapple with it either way round.
## The Hunt-local half of the 2026-09-27 ruling - see the header.
static func holders_of(target:Unit) -> Array[Unit]:
	var holders:Array[Unit] = UnitRelation.get_engaging_units(target)
	for grapple:SpecificAction in UnitCondition.get_incoming_grapples(target):
		Util.append_nonduplicate(holders, grapple.unit)
	for grapple:SpecificAction in UnitCondition.get_outgoing_grapples(target):
		Util.append_nonduplicate(holders, grapple.unit)
	return holders

## Free spaces adjacent to `beside` that `mover` could actually stand in.
##
## COMPOSED FROM THE FROZEN HELPER rather than re-implemented: candidate_tiles is centred on the
## MOVER, so the range has to cover the distance to `beside` plus one, and the `keep` hook narrows it
## to the ring the card names. That gives size-awareness, the engine's own standability test and the
## "not where you already are" rule for free.
##
## COST: one UnitTile.get_tiles_within over a box of radius distance+1 rather than radius 1, once per
## Hunt. get_tiles_within's own header calls itself a bottleneck for large ranges; at a Sensors-10
## invade's distances this is a box of about 23x23 and it runs once, which is why it is not cached.
func destinations_beside(mover:Unit, beside:Unit) -> Array[Vector2i]:
	var ring := UnitTile.get_tiles_within(beside, 1, false)
	var reach:int = UnitRelation.distance_between(mover, beside) + 1
	return Teleport.candidate_tiles(mover, reach, false,
		func(tile:Vector2i) -> bool: return ring.has(tile))
