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
# the consumer is the Naga itself, or an allied CHARACTER (is_character(), a drone included - ruling
# 2026-09-27) within the Naga's live Sensors (distance_between <= get_sensor_range(), no line of sight:
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
# Overshield rule - then a 3-space move the CONSUMER picks and takes, with a voluntary
# MovementType carrying ignore_engagement and ignore_rxns - planned and executed in activate, not
# through event_unit_pick_move; see the note there.
extends ActionReaction

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const HEAT_COST := 1
const OVERSHIELD_GAIN := 1
const MOVE_SPACES := 3

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

## ALWAYS DRAWN ON THE KIT (author decision 6, frame close). Its effect row is the card's passive
## sentence verbatim - the Kit's own text - which vanilla reads as "nothing special" and hides
## (action.gd:350-352). Drawn, it hides the Kit's duplicate plain text instead
## (tooltip_organ_kit.gd:77-83), so the passive appears ONCE and under its own name.
func show_in_tooltip(_kit:Kit) -> bool: return not is_situationally_activated

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
	if not consumer.is_character(): return false
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

	# THE CONSUMER CHOOSES THIS MOVE - nothing forces it - so it is planned and executed here, Green
	# Tide's surge shape (action_green_tide_surge.gd: event_unit_pick_move's budget branch, :112-113 and
	# :145-162, WITHOUT its knockback-immunity abort at :78). A pick_move naming the Naga as `unit` let
	# Heavy Frame / Fomorian Frame (buff_heavy_frame_knockback.gd compares that unit's size to the
	# mover's) refuse a size-3 ally after its heat was paid; omitting `unit` sends an AI-controlled
	# mover to the nearest reachable tile (target_action_util.gd:110-116) and strips the picker's label
	# (frame close, 2026-09-23). The specific names the CONSUMER, so the picker is its own, player or AI.
	var as_consumer := SpecificAction.from_context(context)
	as_consumer.unit = consumer
	var movement := MovementType.create(consumer, true)
	movement.ignore_engagement = true
	movement.ignore_rxns = true
	var pathfinder := await Pathfinder.generate_for_movement_budget(consumer, MOVE_SPACES, movement)
	if activation.abort_without_unit(consumer): return
	var plan := await TargetActionUtil.ask_for_movement_alt(consumer, pathfinder, as_consumer)
	if activation.abort_without_movement_plan(plan, consumer): return
	await activation.execute_events(pathfinder.generate_events(consumer, plan.move_path, [], as_consumer))
