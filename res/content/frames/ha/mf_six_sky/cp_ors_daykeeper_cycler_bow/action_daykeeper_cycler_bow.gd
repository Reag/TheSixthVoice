## DAYKEEPER CYCLER BOW (the Six Sky's integrated weapon; design 2.1, rulings 12-14, 17, 18):
##
##   Main Launcher, HEAT SELF 1, OVERKILL, 1d6+3 Energy, Range 10.
##   "This weapon gains +1 Accuracy against targets within Range 5."
##   On crit: "Choose yourself or the target to be immediately teleported to a free space within Range 2
##   of their space."
##
## THE ACCURACY (ruling 13) is the weapon's own modify_pre_attack_data, the last word on the roll
## (attack_roll.gd:192), as a NAMED line in the breakdown - Shatterhead's shape. It has to live here and
## not in get_attack_accuracy, which is handed only the gear and cannot see the target
## (action_attack.gd:31). Measured from the ATTACKER's space at roll time, so a Ritual shot measures from
## where the Ritual teleport put the Six Sky, and a relayed shot from the Six Sky, not the relay.
## THE ONE EXCEPTION is a PLANNED space (Pass F section 6.1 #3): the hit-chance preview hands the roll a
## virtual summary whose origin voxels stand on the tile the player means to move to
## (attack_preview.gd:40-46). The planned space is used exactly when the roll's summary is a valid
## DeclaredAttackSummary, the weapon is not a Blast, and its source_voxels DIFFER from what a
## declaration by context.unit from its current tile would produce (action_attack.gd:253-258, rebuilt in
## planned_anchor). A real roll declared where the shooter stands - relay or not - matches, and reads
## exactly as before. The one real-roll case that also differs is a shooter MOVED between declaration
## and roll: it is then measured from the declared space, which is where the engine measures its cover.
##
## NO HEAT IN A RITUAL (ruling 18). The Ritual fires this bow with Action.FLAG.NO_SELF_HEAT, which the
## engine honours for Heat Self at spend (unit_action.gd:226-227) and NOWHERE else - so this script reads
## the same flag as "no heat at all" and answers is_overkill false, which is the only gate on the
## Overkill heat event (event_unit_attack_declared.gd:173-178). apply_overkill is OVERRIDDEN to test the
## TAG instead, because vanilla's gates the rerolls on is_overkill too (action_attack_weapon.gd:259-260):
## without the override a Ritual shot would stop rerolling 1s, which the card never says. Any other
## mod's freebie that passes NO_SELF_HEAT to this bow gets the same reading.
##
## THE CRIT (ruling 14) resolves at once, in on_crit - UNLESS a Ritual is running (ruling 17, the
## author's): then the crit is only RECORDED on the Ritual's scope buff, and the Ritual resolves every
## record after its last attack, through the same resolve_crit_teleport. "Inside a Ritual" is the scope
## buff held AND this shot carrying NO_SELF_HEAT (buff_ritual_of_the_first_god.gd's live_scope), so an
## Overwatch fired mid-sequence resolves its own crit at once, like any other shot.
##
## YOURSELF is the PREVENTABLE route (the helper's pathfinder + move_along): Immobilized and a
## MOVEMENT_RESTRICTION ban both stop it, since the self-teleport is the Six Sky's own voluntary choice.
## THE TARGET is Teleport.shove - involuntary, so Immobilized does not stop it and a ban does
## (teleport.gd's four-way table). Both carry the calling activation's SpecificAction, so the forcer is
## the Six Sky and Heavenly Weaver and Starsickness see the teleport as its own.
##
## THE MENU OFFERS ONLY WHAT CAN HAPPEN (Pass F section 6.1 #2): each route's stopper is checked BEFORE
## the menu, so an Immobilized or banned Six Sky is not offered "yourself", a banned or boxed-in target
## is not offered as "the target", and when neither survives no menu is raised
## (resolve_crit_teleport).
##
## AN AI-CONTROLLED SIX SKY SKIPS THE MENU: no teleport at all. The choice is a player's, and an AI
## choosing a space would need a scoring pass this card does not justify.
extends ActionAttackWeapon

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const RitualScope := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/cp_ors_daykeeper_cycler_bow/buff_ritual_of_the_first_god.gd')

const BOW_ID := &'mw_daykeeper_cycler_bow'
const CLOSE_RANGE := 5
const CRIT_TELEPORT_RANGE := 2
const CHOICE_SELF := 0
const CHOICE_TARGET := 1

func modify_pre_attack_data(context:Context, pre_attack_data:AttackRoll.PreAttack) -> void:
	super.modify_pre_attack_data(context, pre_attack_data)
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.all_valid([attacker, context.target_unit]): return
	if close_range_distance(context, attacker) > CLOSE_RANGE: return
	# The kit, so the line shows the bow's glyph even before any UI has cached icon_from_kit (action.gd:324).
	var kit:Kit = context.gear.kit if GearCore.is_valid(context.gear) else null
	pre_attack_data.add_mod(name(SpecificAction.create(attacker, context.gear, self)), 1, get_icon(kit))

## The distance the +1 is measured over - see the header's THE ACCURACY for when each branch runs.
## The planned branch is distance_between (unit_relation.gd:13-25) with the attacker moved to the
## planned anchor: horizontal from the planned tiles, vertical from effective_floor at the anchor.
static func close_range_distance(context:Context, attacker:Unit) -> int:
	var target:Unit = context.target_unit
	var anchor := planned_anchor(context)
	if anchor == Tile.INVALID: return UnitRelation.distance_between(attacker, target)
	var from_tiles := Tile.from_voxels(context.resource.source_voxels)
	var horizontal:int = Tile.get_closest_pair_between(from_tiles, target.occupied_tiles()).distance
	var vertical:int = UnitTile.get_elevation_distance_between(
		UnitTile.effective_floor(attacker, anchor),
		attacker.get_height(false),
		UnitTile.effective_floor(target),
		target.get_height(false),
	)
	return maxi(horizontal, vertical)

## The PLANNED space the roll's summary was built from, or Tile.INVALID for "the attacker as it stands".
## A declaration from the CURRENT space is rebuilt exactly as action_attack.gd:253-258 builds it - from
## context.unit (the relay, when there is one; event_unit_attack_declared.gd:57-65), over the summary's
## own directly-attacked tiles, from that unit's tile - and only origin voxels that DIFFER from it are a
## plan. A Blast's origin is the blast, never a space the attacker stands in, so it is never a plan.
static func planned_anchor(context:Context) -> Vector2i:
	if not DeclaredAttackSummary.is_valid(context.resource): return Tile.INVALID
	var summary:DeclaredAttackSummary = context.resource
	if summary.source_voxels.is_empty(): return Tile.INVALID
	var declaring := SpecificAction.create(context.unit, context.gear, context.action)
	var aoe = context.action.get_range_pattern_for_targets(declaring)
	if aoe and aoe.pattern == Lancer.AOE_TYPE.BLAST: return Tile.INVALID
	var from_here:Array[Vector3i] = context.action.get_origin_voxels(declaring, summary.directly_attacked_tiles, context.unit.tile())
	if summary.source_voxels == from_here: return Tile.INVALID
	# The minimum-x/z tile: get_occupied_voxels_alt grows +x/+z from the from_tile (unit_tile.gd:66-80).
	var anchor := Tile.INVALID
	for tile:Vector2i in Tile.from_voxels(summary.source_voxels):
		if anchor == Tile.INVALID or tile.x < anchor.x or (tile.x == anchor.x and tile.y < anchor.y):
			anchor = tile
	return anchor

func is_overkill(context:Context) -> bool:
	if context != null and context.flags.has(Action.FLAG.NO_SELF_HEAT): return false
	return super.is_overkill(context)

## Vanilla's body with the gate on the TAG rather than on is_overkill - see the header.
func apply_overkill(damage_roll:AttackUtil.DamageRoll, activation:EventCore) -> void:
	if not has_tag(Lancer.WEAPON_TAG.OVERKILL, activation.context): return
	damage_roll.overkill_heat_on_hit = AttackUtil.DamageRoll.modify_rolls_for_overkill(damage_roll.hit_rolls, damage_roll.dietype)
	damage_roll.overkill_heat_on_crit = (
		damage_roll.overkill_heat_on_hit +
		AttackUtil.DamageRoll.modify_rolls_for_overkill(damage_roll.crit_rolls, damage_roll.dietype)
	)

func on_crit(activation:EventCore, attacked_unit:Unit) -> void:
	await super.on_crit(activation, attacked_unit)
	var context := activation.context
	var six_sky:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(six_sky): return
	var scope:BuffCore = RitualScope.live_scope(six_sky, context)
	if scope != null:
		RitualScope.record_crit(scope, attacked_unit) # resolved by the Ritual, after its last attack
		return
	await resolve_crit_teleport(activation, six_sky, attacked_unit)

## The Six Sky's bow, as a SpecificAction, or null.
static func bow_of(six_sky:Unit) -> SpecificAction:
	if not Unit.is_valid(six_sky): return null
	var gear:GearCore = six_sky.get_gear(BOW_ID)
	if not GearCore.is_valid(gear) or gear.kit.actions.is_empty(): return null
	return SpecificAction.create(six_sky, gear, gear.kit.actions.front())

## Rule 14's menu, then the pick, then the teleport. Shared by the immediate crit and the Ritual's
## deferred ones (action_ritual_of_the_first_god.gd), so this signature is fixed.
##
## THE MENU OFFERS ONLY WHAT CAN HAPPEN (Pass F section 6.1 #2; the author's ruling of 2026-09-27 for
## the target half). Both teleports' inputs are built BEFORE the menu and an option survives only when
## its own would land somewhere: "yourself" needs a non-empty preventable pathfinder (Immobilized and a
## ban both empty it), "the target" needs a teleportable target with at least one space the shove's
## ban check would allow. One survivor still gets a one-entry menu, because the card says "may" and the
## menu is its cancel; none raises no menu at all. `target` may be dead by now (a deferred crit), which
## drops "the target" the same way.
static func resolve_crit_teleport(activation:EventCore, six_sky:Unit, target:Unit) -> void:
	if not Unit.is_valid(six_sky): return
	if not six_sky.is_player_controlled(): return
	var bow := bow_of(six_sky)
	if not SpecificAction.is_valid(bow): return

	var self_pf:Pathfinder = await self_teleport_pathfinder(six_sky)
	if not Unit.is_valid(six_sky): return
	var target_tiles:Array[Vector2i] = await target_teleport_tiles(target)
	if not Unit.is_valid(six_sky): return

	var labels:Array = []
	var choices:Array[int] = []
	if self_pf != null:
		labels.append(Translate.gear(BOW_ID, 'crit_self'))
		choices.append(CHOICE_SELF)
	if not target_tiles.is_empty():
		labels.append(Translate.gear(BOW_ID, 'crit_target'))
		choices.append(CHOICE_TARGET)
	if choices.is_empty(): return # nothing can happen: no menu

	var picked:int = await choice_bus.choose_from_multiple_choice(bow, labels, true)
	if picked < 0 or picked >= choices.size() or not Unit.is_valid(six_sky): return

	if choices[picked] == CHOICE_SELF: await teleport_self(activation, bow, six_sky, self_pf)
	elif choices[picked] == CHOICE_TARGET: await teleport_target(activation, bow, target, target_tiles)

## Yourself's input: the helper's PREVENTABLE pathfinder over every free space within 2, or null when
## no space survives it (none free, Immobilized, or banned).
static func self_teleport_pathfinder(six_sky:Unit) -> Pathfinder:
	var tiles := Teleport.candidate_tiles(six_sky, CRIT_TELEPORT_RANGE, false)
	if tiles.is_empty(): return null
	var pathfinder:Pathfinder = await Teleport.pathfinder(six_sky, tiles)
	if pathfinder == null or pathfinder.valid_destinations.is_empty(): return null
	return pathfinder

## The target's input: every free space within 2 of ITS space that the shove could actually reach, or
## [] when it is not a teleportable target. Teleport.shove is a target-tile move, and a target-tile
## move builds its own pathfinder with the shove's movement type (event_unit_move.gd:139-146), which is
## where every MOVEMENT_RESTRICTION ban lands (pathfinder.gd:345-353) - so the same pathfinder, built
## here, is exactly the engine's own refusal test. Involuntary, so Immobilized does not empty it.
static func target_teleport_tiles(target:Unit) -> Array[Vector2i]:
	if not is_teleportable_target(target): return []
	var tiles := Teleport.candidate_tiles(target, CRIT_TELEPORT_RANGE, false)
	if tiles.is_empty(): return []
	var pathfinder:Pathfinder = await Pathfinder.generate_for_given_tiles(target, tiles, Teleport.forced_movement_type(target))
	if pathfinder == null or not Unit.is_valid(target): return []
	var reachable:Array[Vector2i] = []
	for tile:Vector2i in pathfinder.valid_destinations:
		if tiles.has(tile): reachable.append(tile)
	return reachable

## Yourself: the preventable route, over the pathfinder resolve_crit_teleport built before the menu.
static func teleport_self(activation:EventCore, bow:SpecificAction, six_sky:Unit, pathfinder:Pathfinder) -> void:
	if not Unit.is_valid(six_sky): return
	if pathfinder == null or pathfinder.valid_destinations.is_empty(): return # Immobilized, or banned
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(bow.to_context(), pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return # cancelled
	if not Unit.is_valid(six_sky): return
	await Teleport.move_along(activation, six_sky, pathfinder, plan)

## "The target" is offered for a valid, living unit (ruling 14) that is not one of the engine's
## TARGETING PROXIES. A shot at terrain rolls against a real dep_attack_ground_proxy
## (action_attack_weapon.gd:273-286) whose damage reaction lands wherever it stands, so teleporting it
## would carry the terrain damage somewhere the bow never aimed (close review).
const PROXY_FRAMES:Array[StringName] = [&'dep_attack_ground_proxy', &'dep_targeting_proxy']
static func is_teleportable_target(target:Unit) -> bool:
	if not Unit.is_valid(target): return false
	return not (target.core.frame != null and target.core.frame.compcon_id in PROXY_FRAMES)

## The target: the helper's reticle over the spaces resolve_crit_teleport found the shove could reach
## (target_teleport_tiles), then the shove.
static func teleport_target(activation:EventCore, bow:SpecificAction, target:Unit, tiles:Array[Vector2i]) -> void:
	if tiles.is_empty(): return
	if not is_teleportable_target(target): return
	var tile:Vector2i = await Teleport.pick_tile(bow.to_context(), activation, tiles)
	if tile == Tile.INVALID: return # cancelled
	if not Unit.is_valid(target): return
	await Teleport.shove(activation, target, tile)
