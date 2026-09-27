## EXALT (Black Mountain SP2, Blackstone Bell's passive Bringer of Glory, design ruling 11):
##
##   "Reaction, 3/round. Trigger: An allied character within Sensors and line of sight destroys or deals
##    structure damage to a hostile mech character. Effect: The triggering allied character gains
##    Overshield equal to 1 + GRIT. If they already have Overshield it increases by that much instead. A
##    character can only benefit from this effect 1/round."
##
## A DAMAGE POST reaction - Vigil's reading of who dealt the damage (action_vigil.is_damage_dealt_by:
## context.unit is the VICTIM, the dealer is context.target_unit.get_attacker, so an owned drone's hit is
## its owner's). THE STRUCTURE IS READ AT THE DAMAGE, NOT AT THE STRUCTURE EVENT: event_unit_structure and
## event_unit_die carry the victim and flags only, never who did it, so the damage event is the last place
## the dealer can be read. DAMAGE POST is queued at event_unit_damage.gd:196, the structure event one line
## later (:197), so the shield lands BEFORE the structure roll - and the resident talents' replacement of
## the structure event's execute is never in the path.
##
## "DEALS STRUCTURE DAMAGE" = THIS DAMAGE TOOK THE MECH FROM ABOVE 0 HP TO 0 OR BELOW: at POST,
## health <= 0 and health + number > 0. Destruction always passes through it (the last structure is lost
## the same way). THE GATE IS EVALUATED WHEN THE POST IS QUEUED (reaction_bus.gd:61), right after this
## chunk and before any later chunk of the same hit lands - so a two-type hit fires on the chunk that
## crossed zero and the next chunk, finding HP already below zero, does not. recheck_trigger_before_execution
## stays FALSE on purpose: re-asked at run time, after both chunks, the first chunk's arithmetic would fail.
##
## THE REST OF THE GATE (rulings 3-4): not SELF_INFLICTED, the type not HEAT, number > 0; the victim a
## HOSTILE MECH of the Black Mountain (is_mech: a drone is not one), alive at the gate; the dealer an
## allied CHARACTER (is_actor) that is NOT the Black Mountain (are_allies is true of a unit and itself,
## unit_relation.gd:364-365), within the Black Mountain's Sensors and line of sight, measured from the Black
## Mountain to the ALLY (on this card the clause modifies "allied character"); and the dealer does not
## already hold buff_exalt_benefited.
##
## "1/ROUND PER CHARACTER" is buff_exalt_benefited: hidden, from this core gear, until START_OF_OWNERS_TURN
## (owner = the Black Mountain), so it clears at the Black Mountain's own turn start, where its per-round
## tally resets too (ruling 3). It is RE-CHECKED at the top of activate: one hit structuring two hostiles
## queues two POSTs, both pass the gate before either runs, and the second must be refused there.
##
## A REAL REACTION (author): consumes_rxn true, so it needs and spends the reaction point; the hard limit is
## 3 (ActionReaction's default for one that consumes a point is 1). Own usage_group. AUTOMATIC: the card
## has no "may", so no prompt. The reaction point refreshes at every unit's turn start while the 3 counts
## only from the Black Mountain's own turn start (Draw Fire's measured reading of "1/round").
##
## THE EFFECT is one call, Overshield.increase_by(activation, dealer, 1 + GRIT, this core gear): additive
## covers both sentences (an ally at 0 ends at 1 + GRIT, one holding N at N + 1 + GRIT), and the "granted
## by" mark it hangs is what An End to All Things keys on. GRIT is the BLACK MOUNTAIN's pilot's (Shield
## Wall's 1 + Overshield.grit). Sourceless damage (a burn tick) has no dealer and never triggers it.
extends ActionReaction

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const VigilAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/mt_vigil/action_vigil.gd')

const BENEFITED := &'buff_exalt_benefited'
const USES_PER_ROUND := 3

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return USES_PER_ROUND

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.number]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	if context == null or not Unit.is_valid(context.target_unit): return false
	var dealer:Unit = context.target_unit.get_attacker(context)
	if not VigilAction.is_damage_dealt_by(dealer, context): return false
	if not is_structure_damage_to_a_hostile_mech(unit, context): return false
	return can_benefit(unit, dealer)

## The victim is a live hostile MECH of the Black Mountain, and this damage took it from above 0 HP to 0
## or below. Read at queue time - see the header.
static func is_structure_damage_to_a_hostile_mech(black_mountain:Unit, context:Context) -> bool:
	var victim:Unit = context.unit
	if not Unit.is_valid(victim) or not victim.is_mech(): return false
	if not UnitRelation.are_enemies(black_mountain, victim): return false
	var health:int = victim.core.current.health
	return health <= 0 and health + context.number > 0

## "An allied character within Sensors and line of sight", not the Black Mountain, not yet exalted.
static func can_benefit(black_mountain:Unit, dealer:Unit) -> bool:
	if not Unit.is_valid(dealer) or dealer == black_mountain: return false
	if not dealer.is_actor() or not UnitRelation.are_allies(black_mountain, dealer): return false
	if UnitRelation.distance_between(black_mountain, dealer) > black_mountain.get_sensor_range(): return false
	if not UnitRelation.can_see(black_mountain, dealer): return false
	return UnitCondition.get_buffs(dealer, BENEFITED).is_empty()

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var triggering:Context = context.event.context
	var dealer:Unit = triggering.target_unit.get_attacker(triggering) if Unit.is_valid(triggering.target_unit) else null
	if activation.abort_without_units([unit, dealer]): return
	# The re-check event_gear_activate does not do for us (recheck_trigger_before_execution is off).
	if activation.abort_when(not can_benefit(unit, dealer)): return

	spend_actions(activation)
	apply_buff_id(activation, dealer, BENEFITED)
	await Overshield.increase_by(activation, dealer, 1 + Overshield.grit(unit), context.gear)
