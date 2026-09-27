## VANISH (Phase Cloud, Koremasa rank I; design 3.2, rulings 26-28):
##
##   "Trigger: You take damage from a hostile character within sensors. Effect: Expend a charge, a
##    Blast one area centered on you is engulfed in smoke. All objects and characters within benefit
##    from soft cover until the end of your next turn, at which point the smoke vanishes. You may
##    teleport to a free space within range 5."
##
## THE JORMUNGANDR'S CHASSIS (action_automatic_retaliation.gd): a DAMAGE reaction at POST (the number
## is final there), heat excluded, a number above 0 (armor that ate the whole hit arrives as 0), and
## the dealer resolved to its OWNER - a drone's or a mine's hit is its owner's (rulings row 70,
## attribution, unaffected by the 2026-09-27 membership ruling) - who must be a hostile CHARACTER
## within the Koremasa's sensors, measured to that owner (the Subutai Draw Fire ruling, row 95). A
## REAL reaction: the point and the charge are the price, the 1/round is the
## engine's (action_reaction.gd get_per_round_hard_limit), and a Kit at 0 charges refuses it
## (can_be_used_while_uncharged). Unlike the Jormungandr's it ASKS first - a reaction is a choice, and
## that one's card says "automatically".
##
## THE ORDER IS THE CARD'S (ruling 27): the spend, then the smoke where the Koremasa stands, then the
## optional teleport. The smoke is laid through the mod's Terrain.lay, and the zone measures its burst
## from the Koremasa's footprint (passive_footprint_smoke_zone.gd), so a rider smokes the mount's
## space plus 1. The teleport is the frozen Teleport helper's PREVENTABLE route - candidate_tiles,
## pathfinder, the pathfinder's own reticle, move_along - Vigil's and Calamitous Impact's; "may" is the
## reticle's cancel. NO line of sight, the mod's standing teleport reading (Blinkspace, Vigil ruling 3,
## the Shackleton's leap); the design's `los` placeholder named the parameter, not a value.
##
## WHILE RIDING (ruling 28, measured by the SP3 probe at fca423a; pinned in spec/test_phase_cloud.gd): the teleport ENDS THE
## RIDE, but only once a tile is taken - a declined teleport leaves the Koremasa mounted. So the tiles
## and the pathfinder are built BEFORE anything changes, from the rider's own unstacked shape: the
## Mule Harness climb-off's trick (action_mule_harness_climb_off.gd, stackup_order briefly -1) plus
## occupying_size set to the rider's own size, restored straight after. The probe measured that this
## offers exactly the tiles a real dismount does, and that the pathfinder still lands the move once
## the real dismount (koremasa_ride.gd, no relocation) has run. NEVER Teleport.move, which moves the
## rider alone and leaves the stackup corrupt (katamari.gd:94-96).
extends ActionReaction

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')
const Ride := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_koremasa/cp_overdrive_exploitation_sequences/koremasa_ride.gd')
const SmokeZone := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ha/systems/ms_phase_cloud/deployable/passive_footprint_smoke_zone.gd')

const TELEPORT_RANGE := 5
const SMOKE_KIT := &'mt_phase_cloud_smoke'

## The smoke: dep_phase_cloud_smoke.tres.
@export var smoke:Frame

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.number]

# DAMAGE event, POST. Pure: the bus polls it more than once per event.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false # "you take damage"
	if context.category_int == Lancer.DAMAGE_TYPE.HEAT: return false
	if context.number <= 0: return false
	var dealer := damager(context, unit)
	if not Unit.is_valid(dealer): return false
	return UnitRelation.distance_between(unit, dealer) <= unit.get_sensor_range()

## The hostile character behind a damage event, or null - the Jormungandr's damager() verbatim.
func damager(context:Context, holder:Unit) -> Unit:
	if not Unit.is_valid(context.target_unit): return null
	var them:Unit = context.target_unit.get_owner_unit_or_self()
	if not Unit.is_valid(them): return null
	if not them.is_character(): return null
	if not UnitRelation.are_enemies(holder, them): return null
	return them

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_without_unit(unit): return
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(unit): return

	# 1. THE PRICE: the reaction point and the charge, whatever follows.
	spend_actions(activation)

	# 2. THE SMOKE, where the Koremasa stands now (a rider: the mount's footprint).
	await lay_smoke(activation, context, unit)
	if activation.abort_without_unit(unit): return

	# 3. THE TELEPORT, planned before anything about a ride changes.
	var ride_gear:GearCore = unit.get_gear(Ride.CORE_ID)
	var riding := Ride.is_riding(unit, ride_gear)
	var pathfinder := await plan_teleport(unit, riding)
	if activation.abort_without_unit(unit): return
	if pathfinder == null or pathfinder.reachable_tiles.is_empty(): return # prevented or boxed in
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return # "may": declined
	if activation.abort_without_unit(unit): return

	# 4. A rider climbs down first - in place, since the teleport is the relocation.
	var dismounted := riding and Ride.is_riding(unit, ride_gear)
	var mount:Unit = Ride.current_mount(ride_gear, unit.map) if dismounted else null
	if dismounted: Ride.dismount(activation, unit, ride_gear, false)
	var move:EventCore = await Teleport.move_along(activation, unit, pathfinder, plan)
	# A VETOED or failed teleport (an Uncertainty Field-style listener aborting it at ENTIRE_MOVEMENT
	# PRE) would leave a dismounted rider standing inside its mount's footprint. Relocate it the way
	# every other dismount does (koremasa_ride.gd's relocate branch, the Mule Harness end action).
	if dismounted and Unit.is_valid(unit) and (move == null or move.aborted):
		var around:Array[Vector2i] = []
		if Unit.is_valid(mount): around = UnitTile.get_tiles_within(mount, 1, false)
		EventUnitMove.queue_events_to_make_sure_units_are_in_valid_spots([unit], activation, around)

## Lay the smoke at the Koremasa's anchor and record its footprint on the zone. A spawn that did not
## land (Terrain.lay's null) simply leaves no cloud.
func lay_smoke(activation:EventCore, context:Context, unit:Unit) -> void:
	if smoke == null: return
	var footprint:int = unit.state.occupying_size
	var laid:Unit = await Terrain.lay(activation, SpecificAction.from_context(context), unit.state.tile, smoke)
	if not Unit.is_valid(laid): return
	var zone:GearCore = laid.get_gear(SMOKE_KIT)
	if not GearCore.is_valid(zone) or footprint <= laid.state.occupying_size: return
	zone.set_state(SmokeZone.FOOTPRINT_KEY, footprint)
	UnitTile.update_tracking_and_statuses(unit.map, activation)
	laid.update_token()

## The teleport's pathfinder over every free space within 5, or null when there is none. For a rider,
## built from its own unstacked shape and restored straight after (see the header).
func plan_teleport(unit:Unit, riding:bool) -> Pathfinder:
	var old_order:int = unit.state.stackup_order
	var old_size:int = unit.state.occupying_size
	if riding:
		unit.state.stackup_order = -1
		unit.state.occupying_size = unit.core.get_size()
	var tiles := Teleport.candidate_tiles(unit, TELEPORT_RANGE, false)
	var pathfinder:Pathfinder = null
	if not tiles.is_empty(): pathfinder = await Teleport.pathfinder(unit, tiles)
	if riding and Unit.is_valid(unit):
		unit.state.stackup_order = old_order
		unit.state.occupying_size = old_size
	return pathfinder
