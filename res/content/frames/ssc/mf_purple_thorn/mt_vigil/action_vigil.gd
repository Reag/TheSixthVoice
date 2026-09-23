# VIGIL (Purple Thorn, mt_vigil), rulings 2-3:
#
#   "2/round, whenever the Purple Thorn deals damage, it may immediately teleport to a free space
#    within range 3. This teleport occurs before any other attacks are resolved."
#
# A DAMAGE POST reaction on the trait Kit. NOT ActionReactionSelf: on a damage event context.unit
# is the VICTIM (event_unit_damage.gd:82-83 - `unit` the receiver, `target_unit` the dealer), so
# the gate reads the dealer off context.target_unit.get_attacker(context), the way Halo does. Four
# more clauses make "deals damage" mean what the card means: number > 0 (an armor-zeroed hit is
# not "deals damage" - and the POST IS still queued for one, with number 0, because the guard at
# event_unit_damage.gd:93 reads capped_damage which armor never touches; measured by
# spec/test_spike_purple_thorn_sp1_seams.gd), the type not HEAT, no SELF_INFLICTED flag (self-heat
# and overkill set target_unit = self, unit_action.gd:299-306), and a valid dealer at all (a burn
# tick or a hazard has none). The victim is ANY unit - the card says "deals damage", unqualified,
# so an object counts.
#
# ONE OFFER PER ATTACK, HOWEVER MANY VICTIMS OR DAMAGE TYPES. All of one attack's damage events run
# in one block and each queues its own DAMAGE POST, so a Blast would otherwise offer Vigil once per
# victim and spend both uses on one shot. The reaction stamps the enclosing declared attack's id
# (attack_trace.gd - the block-tree walk, since the context carries no `event`) in gear state at
# the TOP of activate, taken or not, and the predicate refuses a repeat; the .tres sets
# recheck_trigger_before_execution so the already-queued siblings re-ask and are refused.
#
# "BEFORE ANY OTHER ATTACKS ARE RESOLVED" = before the NEXT attack (ruling 3): the engine rolls
# every target of one attack before any damage lands (event_unit_attack_declared.gd:53-74), so there
# is no point between a Blast's hits to teleport at; DAMAGE POST is the first seam after damage and
# is still inside the attack - before its on-resolution effects (:212), its ATTACK_DECLARED POST
# (:221) and any follow-up Aux queued at Priority.ACTIVATE.followup_attack.
#
# THE TELEPORT IS PREVENTABLE, ON PURPOSE (ruling 3): Teleport.candidate_tiles with NO line of
# sight (Blinkspace's rule), Teleport.pathfinder (Pathfinder.create, where Immobilized and every
# MOVEMENT_RESTRICTION ban land), the pathfinder's own reticle through TargetActionUtil.ask_for_movement,
# Teleport.move_along - Abjuration of Metal's route. The card does not say "cannot be prevented".
# An Immobilized Thorn, or one inside an Interdiction Field, gets an empty pathfinder and is not
# offered at all.
#
# "MAY" = THE RETICLE'S CANCEL (author: reticle only, no yes/no). A cancelled pick, or no free space,
# spends nothing - spend_actions runs only once a tile is taken, so the next hit that round still
# offers. 2/ROUND: consumes_rxn is false (a trait, not the reaction point), so the archetype's
# default limit would be 99; get_per_round_hard_limit returns 2 and counts gear.uses_this_round,
# whose only writer is spend_actions. Own usage_group so nothing else on the Kit shares the tally.
#
# THE PREDICATE IS PURE (the Naga probe's rule): the bus polls it several times per activation, so
# no spend, no stamp, no prompt lives in triggers_on_event.
extends ActionReaction

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const AttackTrace := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/attack_trace.gd')

const TELEPORT_RANGE := 3
const USES_PER_ROUND := 2
## Gear state: the id of the last declared attack this trait was offered on.
const LAST_ATTACK_KEY := 'vigil_last_attack'

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return USES_PER_ROUND

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.number]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	if not is_damage_dealt_by(unit, triggering_event.context): return false
	# one offer per attack - see the header
	var attack_id := String(AttackTrace.enclosing_attack_id(triggering_event))
	return attack_id != gear.get_state(LAST_ATTACK_KEY, '')

## Ruling 2's reading of "deals damage": `dealer` dealt a positive amount of non-heat damage to
## somebody, and not to itself by its own hand. Static and side-effect free; Rend's chip and the
## specs read it too.
static func is_damage_dealt_by(dealer:Unit, context:Context) -> bool:
	if context == null: return false
	if context.number <= 0: return false
	if context.category_int == Lancer.DAMAGE_TYPE.HEAT: return false
	if context.flags.has(EventService.DAMAGE_FLAG.SELF_INFLICTED): return false
	if not Unit.is_valid(context.target_unit): return false
	return context.target_unit.get_attacker(context) == dealer

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	# 1. THE STAMP, FIRST. This attack has had its offer, whatever happens next.
	context.gear.set_state(LAST_ATTACK_KEY, String(AttackTrace.enclosing_attack_id(context.event)))
	if activation.abort_without_unit(unit): return

	# 2. THE FREE SPACES within 3, no line of sight required.
	var tiles := Teleport.candidate_tiles(unit, TELEPORT_RANGE, false)
	if tiles.is_empty(): return # nowhere to go; nothing spent

	# 3. THE PATHFINDER - the preventable route. Immobilized and every ban empty it.
	var pathfinder:Pathfinder = await Teleport.pathfinder(unit, tiles)
	if activation.abort_without_unit(unit): return
	if pathfinder == null or pathfinder.reachable_tiles.is_empty(): return # prevented; nothing spent

	# 4. THE RETICLE. Cancel = Tile.INVALID-shaped plan = nothing spent ("may").
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(context, pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return
	if activation.abort_without_unit(unit): return

	# 5. THE SPEND, then the teleport. From here the use is taken however the move goes.
	spend_actions(activation)
	await Teleport.move_along(activation, unit, pathfinder, plan)
