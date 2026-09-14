## HYBRIDIZED SHOT: +1 Accuracy on the M/K2's first attack, on its own turn, with a Loading weapon
## that is not SUPERHEAVY.
##
## ONE RESOURCE, BOTH HALVES - the Lockbreaker shape (buff_lockbreaker.gd is passive on `to` AND
## reactive on `triggers_on` from one script). check_if_passive_applies is the PAYER, read by the
## attack roll; triggers_on_event + activate is the CHARGER, which spends the once-per-turn after the
## attack has resolved. Both read the SAME predicate, qualifies(), so the two can never drift: a
## payer wider than the charger pays twice in a turn, a charger wider than the payer denies a bonus
## that was never given, and nothing in a run would say so.
##
## WHY A PER-TURN COUNTER AND NOT A STAMP. UnitAction.every_new_turn_refresh (unit_action.gd:67-70)
## clears uses_this_turn for EVERY unit at EVERY turn start (event_turn_start.gd:44), which is
## exactly the lifetime the card asks for, and the is_taking_turn gate makes "this turn" unambiguous.
## The Roland Chamber's declared-attack stamp is the other precedent and is a trap here: the attack
## PREVIEW builds a virtual DeclaredAttackSummary (attack_preview.gd:40-46), so any bookkeeping taken
## inside a roll is also taken while the player is merely hovering a target. A counter that only the
## POST reaction moves cannot be reached by a preview - and event_gear_activate.gd:99-104 gates that
## POST on the gear's usage having actually moved, so an ABORTED attack neither pays nor charges.
##
## THE VALUE IS CONSTANT AND THE GATE DOES ALL THE WORK. attack_roll.gd:183-184 calls
## buff_core.get_values() BARE, with no context, so get_values cannot see the roll; only
## check_if_passive_applies is handed the context. BuffBonus supplies get_values from bonus_value on
## the .tres, so this script overrides only the gate.
##
## activate() DOES NOT CALL super(): the default (buff.gd:254-255) would clear the buff from the
## unit, and this one must survive to be re-evaluated next turn. It is reapplied at the start of each
## turn anyway (reapply_at_the_start_of_each_turn on the applicator), but a buff that deletes itself
## mid-turn would also stop the charger from ever running twice - which is how a second qualifying
## attack would quietly get the bonus back.
extends BuffBonus

## The once-per-turn counter's key on the trait Kit's own GearCore. Declared here because both halves
## read it.
const USAGE_KEY:StringName = &'hybridized_shot'

## The card's three clauses, asked once. context.action is the action the attack was declared
## through; a non-weapon action casts to null and is refused.
static func qualifies(context:Context) -> bool:
	var weapon:ActionAttackWeapon = context.action as ActionAttackWeapon
	if weapon == null: return false
	if weapon.weapon_size == Lancer.WEAPON_SIZE.SUPERHEAVY: return false
	if not weapon.has_tag(Lancer.WEAPON_TAG.LOADING, context): return false
	if not Unit.is_valid(context.unit): return false
	return context.unit.state.is_taking_turn # "on your turn"

## THE PAYER.
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not qualifies(context): return false
	var trait_gear:GearCore = core.get_owner_gear(context.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_turn_alt(USAGE_KEY) == 0

## THE CHARGER. The triggering unit must be the holder: reaction_bus.trigger_occurred polls every
## unit's buffs on every trigger, so without this an enemy's Loading shot would spend our bonus.
func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if triggering_event.context.unit != unit: return false
	if not qualifies(triggering_event.context): return false
	var trait_gear:GearCore = core.get_owner_gear(unit.map)
	if not GearCore.is_valid(trait_gear): return false
	return trait_gear.get_uses_this_turn_alt(USAGE_KEY) == 0

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	var trait_gear:GearCore = core.get_owner_gear(unit.map)
	if not GearCore.is_valid(trait_gear): return
	trait_gear.increment_action_usage_for_per_turn(USAGE_KEY)
