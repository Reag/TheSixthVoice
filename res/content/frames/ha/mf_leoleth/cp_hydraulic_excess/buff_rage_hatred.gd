# HATRED (ruling 14), RAGE's face 6:
#
#   "Whenever you take damage from a hostile character, they take 3 energy damage."
#
# A BUFF WITH A TRIGGER rather than a reaction. Buff carries triggers_on, trigger_timing,
# triggers_on_event and activate of its own (buff.gd:138-139, :246-256). A reaction would pay the
# per-Kit reaction allowance, appear in the player's reaction list and be capped at 1/round by
# ActionReaction.get_per_round_hard_limit - and the card says WHENEVER and is not a reaction.
# buff_inexorable_formation.gd is this mod's other one.
#
# FIVE CLAUSES, NOT THE PLAN'S FOUR - and only ONE of them is about an event that never arrives:
#   - context.unit == our holder. NOT a correctness clause here and that is MEASURED, not assumed
#     (SP1 Task 12, mutation 1): neutralising it reddened nothing, because are_enemies() refuses the
#     answer's own damage event - the only foreign damage event these specs put on the bus - and the
#     Leoleth is not its own enemy. It stays as a PERFORMANCE guard: the bus runs this gate for EVERY
#     unit's EVERY buff on EVERY damage event in the game (reaction_bus.gd:61-67), and one identity
#     compare is cheaper than the owner walk and the two relation reads below it.
#   - not HEAT. The Berserker's Aggression excludes heat the same way
#     (action_aggression_berserker.gd:20).
#   - the damager is a hostile CHARACTER, resolved through get_owner_unit_or_self (unit.gd:270-273) so
#     an OWNED drone's hit is answered by its owner (attribution, unaffected by the 2026-09-27
#     membership ruling). The resolution is load-bearing on this path: an attack's damage event
#     records the DRONE itself as target_unit (measured, SP1 Task 12), not the owner. An UNOWNED
#     drone resolves to itself and now passes the character test too (a drone is a character).
#   - SOMETHING HAS TO HAVE LANDED. THE PLAN EXPECTED THE ENGINE TO GIVE THIS ONE FREE AND IT DOES
#     NOT (implementer correction, SP1 Task 12, measured): event_unit_damage.gd:93 aborts on
#     `damage_modifications.capped_damage <= 0`, and capped_damage is NOT the reduced number - it
#     starts at DamageModifications.MAXIMUM_DAMAGE_CAP 9999 (damage_modifications.gd:11) and is
#     lowered ONLY by a Buff.TO.RESIST_DAMAGE buff carrying BuffResistDamage.FLAG.CAP (:68-70), i.e.
#     a paradox shield or a flash aegis. Armor reduces `damage` instead, floored at 0 (:116), so a
#     hit an armor-9 frame shrugs off arrives at the POST queue (:196) with context.number == 0 and
#     the gate IS asked. Measured on the first GREEN run: the log reads
#     `Player 23P took 0 ... (Reduced from 3 by armor)` and then
#     `> queueing reactions to damage post`. "Whenever you TAKE damage" means a number greater than
#     zero, so this clause is the card's, not the engine's.
#   - end-of-turn burn carries NO target_unit at all (event_turn_end.gd:101-106), so the damager
#     clause refuses it with no special case.
#
# THE DAMAGER IS READ OFF THE TRIGGERING EVENT, NOT OFF THE ACTIVATION (implementer correction, SP1
# Task 12). triggers_on_event is handed the triggering EventCore, but activate is handed the
# event_buff_activate core, whose context is built from exactly three keys - buff, unit and event
# (reaction_bus.gd:63-67, content/events/event_buff_activate.gd:6-11). activation.context.target_unit
# is therefore ALWAYS null; the damage event is activation.context.event.context. The plan's draft
# read the activation's own context and would have answered nobody, ever.
#
# THE ANSWER IS BUILT FROM THE UNIT, NOT FROM A SpecificAction. CommonActionUtil.queue_damage_events
# copies specific.gear and specific.action onto every event it builds (common_action_util.gd:97-99),
# and BuffResistDamage keys on context.action; ruling 14 says "no flags (armor and resistance
# apply)". Handing it the bare Unit builds an empty SpecificAction with only `unit` set (:81-82), so
# `target_unit` still records who did it and nothing else is claimed.
#
# activate DOES NOT CALL super, AND THAT IS LOAD-BEARING. Buff.activate's DEFAULT body is
# `UnitCondition.clear_buff(activation, activation.context.unit, core)` - it consumes the buff
# (buff.gd:254-255). The card says WHENEVER, so this chip must survive every hit it answers.
# buff_inexorable_formation.gd omits the super call for the same reason.
extends Buff

const ANSWER := 3

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	# were WE the one damaged?
	if context.unit != unit: return false
	# heat is not damage for this card
	if context.category_int == Lancer.DAMAGE_TYPE.HEAT: return false
	# "whenever you TAKE damage": a hit armor ate whole is not damage taken. See the header - the
	# engine's own capped_damage abort does not cover this and the event arrives here with number 0.
	if context.number <= 0: return false
	# somebody has to have done it - end-of-turn burn carries no damager at all
	return Unit.is_valid(damager(context, unit))

func activate(_core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	var triggering_event:EventCore = activation.context.event
	if triggering_event == null: return
	var them:Unit = damager(triggering_event.context, unit)
	if not Unit.is_valid(them): return
	CommonActionUtil.queue_damage_events(
		activation, unit, [them] as Array[Unit], ANSWER, Lancer.DAMAGE_TYPE.ENERGY
	)

## The hostile CHARACTER responsible for a damage event, or null.
##
## context.target_unit is the engine's "who did this" on a damage event (event_unit_damage.gd:35's
## own optional-context comment), and get_owner_unit_or_self walks an OWNED drone up to its owner
## (unit.gd:270-273, attribution - unaffected by the 2026-09-27 membership ruling). is_character(), a
## drone included (rulings.md, mod-wide row of 2026-09-27, reversing row 301/ruling 22) - so an
## UNOWNED drone, which resolves to itself, now passes this check and answers for its own hit.
func damager(context:Context, holder:Unit) -> Unit:
	if not Unit.is_valid(context.target_unit): return null
	var them:Unit = context.target_unit.get_owner_unit_or_self()
	if not Unit.is_valid(them): return null
	if not them.is_character(): return null
	if not UnitRelation.are_enemies(holder, them): return null
	return them
