# SHIMMER'S BLINK (SP4 Task 2, design ruling 15) - the second half of the card:
#
#   "... if the attack misses you may immediately teleport to a space within range 3."
#
# A HIDDEN companion: an ATTACK POST ActionReactionAttacked on the DEFENDER, point-free
# (consumes_rxn false, so the archetype's own limit is 99), never a charge (consumes_charges ->
# false, the Lucifer's record-heat companion shape), and ARMED ONLY BY SHIMMER'S STAMP - the
# triggering attack event's id in gear state (action_shimmer.gd). Without the stamp nothing here
# ever triggers, so an attack Shimmer was not taken on can never teleport the Thorn.
#
# IT TRIGGERS ON A HIT TOO, deliberately, and does nothing there but clear the stamp - so the stamp
# is cleared either way (design 4.2) rather than left to go stale. require_miss is NOT set; the
# miss test is in activate.
#
# THE TELEPORT IS VIGIL'S (ruling 3), PREVENTABLE: Teleport.candidate_tiles with no line of sight,
# Teleport.pathfinder (Immobilized and every MOVEMENT_RESTRICTION ban empty it), the pathfinder's
# own reticle, Teleport.move_along. "May" = the reticle's cancel; there is nothing to spend.
#
# THE PREDICATE IS PURE (the Naga probe's rule): no clear, no prompt in triggers_on_event.
extends ActionReactionAttacked

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const Shimmer := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_superpositional_profile/action_shimmer.gd')

const TELEPORT_RANGE := 3

func consumes_charges(_specific:SpecificAction) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	var stamp := String(gear.get_state(Shimmer.STAMP_KEY, ''))
	if stamp.is_empty() or stamp != String(triggering_event.id): return false
	return super(unit, gear, triggering_event)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	# 1. THE STAMP, CLEARED FIRST, hit or miss.
	context.gear.set_state(Shimmer.STAMP_KEY, '')
	var roll = context.event.context.object
	if not AttackRoll.is_valid(roll) or roll.hit: return
	if activation.abort_without_unit(unit): return

	# 2. THE FREE SPACES within 3, no line of sight required.
	var tiles := Teleport.candidate_tiles(unit, TELEPORT_RANGE, false)
	if tiles.is_empty(): return

	# 3. THE PATHFINDER - the preventable route.
	var pathfinder:Pathfinder = await Teleport.pathfinder(unit, tiles)
	if activation.abort_without_unit(unit): return
	if pathfinder == null or pathfinder.reachable_tiles.is_empty(): return

	# 4. THE RETICLE. Cancel = no move.
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return
	if activation.abort_without_unit(unit): return

	# 5. Logged as a use (the tally only; no charge, no point), then the teleport.
	spend_actions(activation)
	await Teleport.move_along(activation, unit, pathfinder, plan)
