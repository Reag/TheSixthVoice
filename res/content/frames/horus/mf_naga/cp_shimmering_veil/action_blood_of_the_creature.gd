# THE BLOOD OF THE CREATURE THAT BRINGS ABOUT THE BEGINNING OF DAYS (Naga, cp_shimmering_veil's
# passive), ruling 7:
#
#   "1/round, when you or an allied character within sensors consume Lock On, you may take 1 heat to
#    have the triggering character gain 1 OVERSHIELD and move 3 spaces. This movement ignores
#    engagement and doesn't provoke reactions."
#
# AUTOPOD'S AUTONOMOUS ASSAULT SHAPE (action_autonomous_assault.gd:18-28): an `attack` POST reaction
# on the core Kit, fired once per attacked unit with the AttackRoll in the triggering context's
# `object`. CONSUMPTION IS NOT AN EVENT: action_consume_lock_on.gd:42-43 clears the status and hangs
# buff_lock_consumed at ATTACK_DECLARED PRE; event_unit_attack.gd:54 copies it onto the roll as
# `consumed_lock` before the buff is stripped at :113-120, and ATTACK POST is queued at :123 with
# that roll. The shared hook reads the flag (Lockon.was_consumed) and resolves the attacker
# (Lockon.consumer -> Unit.get_attacker, so an OWNED drone's shot counts as its owner's - ruling 21's
# "a drone acts as its owner"). Weapon and tech attacks alike: an invade consuming Lock On counts.
#
# THE GATE, in the card's order: the lock was consumed; the locked target is an ENEMY of the Naga;
# the consumer is the Naga itself, or an allied CHARACTER (is_actor, ruling 21 - an unowned drone is
# not one) within the Naga's live Sensors (distance_between <= get_sensor_range(), no line of sight:
# the card names Sensors only). Eyes of Night is the mod's "you or an allied character within
# Sensors" clause verbatim. PURE: the bus polls this several times per attack (the SP1 probe), so no
# spend, stamp or prompt lives here.
#
# 1/ROUND: consumes_rxn is false (a trait, not a reaction point), so get_per_round_hard_limit returns
# 1 explicitly and spend_actions inside activate is what writes uses_this_round. "You may take 1
# heat": CommonActionUtil.confirm_use for the NAGA's controller - it pays - and declining before the
# spend costs nothing. Yes: 1 HEAT self through UnitAction.gain_self_heat_alt (vanilla's own
# self-heat shape, an event_unit_damage HEAT flagged SELF_INFLICTED), then Overshield.grant(1) on the
# consumer - engine-max semantics, so an ally already holding 2 keeps 2, which is Lancer's own
# Overshield rule - then event_unit_pick_move on the consumer, number 3, with a voluntary
# MovementType carrying ignore_engagement and ignore_rxns (Quick March's shape moves a unit that is
# not the holder; the mover's own controller drives the picker).
extends ActionReaction

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const HEAT_COST := 1
const OVERSHIELD_GAIN := 1
const MOVE_SPACES := 3

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.target_units, Context.PROP.object]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var triggering:Context = triggering_event.context
	if not Lockon.was_consumed(triggering): return false
	var attacked:Unit = triggering.target_unit
	if not Unit.is_valid(attacked): return false
	if not UnitRelation.are_enemies(unit, attacked): return false
	return is_you_or_an_allied_character_within_sensors(unit, Lockon.consumer(triggering))

## "You or an allied character within sensors", read from the Naga's side.
static func is_you_or_an_allied_character_within_sensors(naga:Unit, consumer:Unit) -> bool:
	if not Unit.is_valid(consumer): return false
	if consumer == naga: return true
	if not UnitRelation.are_allies(naga, consumer): return false
	if not consumer.is_actor(): return false
	return UnitRelation.distance_between(naga, consumer) <= naga.get_sensor_range()

func activate(context:Context, activation:EventCore) -> void:
	var naga:Unit = context.unit
	var triggering:Context = context.event.context
	var consumer:Unit = Lockon.consumer(triggering)
	if activation.abort_without_units([naga, consumer]): return

	# "You may take 1 heat" - the Naga's controller decides, and it is the Naga that pays.
	var confirmed:bool = await CommonActionUtil.confirm_use(
		context, [consumer], [], SpecificAction.from_context(triggering))
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([naga, consumer]): return

	spend_actions(activation)
	UnitAction.gain_self_heat_alt(HEAT_COST, SpecificAction.from_context(context), activation)
	await Overshield.grant(activation, consumer, OVERSHIELD_GAIN)
	if activation.abort_without_units([naga, consumer]): return

	var movement := MovementType.create(consumer, true)
	movement.ignore_engagement = true
	movement.ignore_rxns = true
	activation.queue_event(&'event_unit_pick_move', {
		target_unit = consumer,
		resource = movement,
		number = MOVE_SPACES,
		# tell the event who did it
		unit = naga,
		gear = context.gear,
		action = context.action,
	})
