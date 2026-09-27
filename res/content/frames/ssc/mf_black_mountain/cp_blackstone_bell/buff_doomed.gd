## DOOMED (Black Mountain SP2, Fell the Mighty's mark, design ruling 13):
##
##   "Choose a hostile character within sensors and line of sight, they are DOOMED for the rest of the
##    scene. Allies attacks against a DOOMED character have +1 Accuracy and whenever an allied character
##    deals damage to them, they increase their Overshield by 1."
##
## ONE BUFF ON THE TARGET, TWO GATES. Visible, until MANUAL (the scene), and is_cleared_on_owner_death
## FALSE (author: DOOMED persists after the Black Mountain is destroyed) - clear_outgoing_buffs_from_unit
## skips such a buff (unit_condition.gd:1018). It ends with the target's death and the scene.
##
## THE GATES NEVER RESOLVE THE OWNER, so both keep working after the Black Mountain is gone. "Allies" is the
## BLACK MOUNTAIN's allies, read from two things on_application stores: the Black Mountain's side
## (unit.get_faction(), the value UnitRelation.are_allies compares - vanilla's own Buff.FACTION_KEY for such
## buffs, unit_condition.gd:750-754, stores core.faction instead, which a side change would leave stale) and
## its persistent id. "Allies" and "allied character" EXCLUDE the Black Mountain itself (ruling 3, the
## author's call) - the id is how.
##
## 1. ACCURACY: Marker Shells' target-side shape (to = ATTACK_ROLL_INCOMING, bonus_subtype accuracy,
##    bonus_value 1 on the .tres). attack_roll.gd:135 gathers it from the defender with the attack context
##    and :182-189 folds it in. check_if_passive_applies: the attacker (get_attacker - an owned drone's shot
##    is its owner's, an unowned one is itself) is a CHARACTER (is_character() - a drone included, ruling
##    2026-09-27) on the stored side and not the Black Mountain. Weapon and tech
##    attacks alike ("Allies attacks", unqualified) - so this is a BuffBonus, not a BuffWeaponType, which
##    would refuse every tech attack. Not is_onetime: it stays.
##
## 2. OVERSHIELD ON DAMAGE: the Rend chip's shape (buff_cruel_and_unnatural.gd) on the holder - a DAMAGE
##    POST trigger. Vigil's reading of "deals damage" (action_vigil.is_damage_dealt_by: the dealer is
##    target_unit.get_attacker, number > 0 - so a hit armour zeroes gives nothing - not HEAT, not
##    SELF_INFLICTED), plus: the victim is this holder, the dealer an allied character by the stored side
##    and not the Black Mountain. ONCE PER ATTACK (author): a two-type weapon's two damage events are one
##    attack; the stamp is AttackTrace.enclosing_attack_id joined to the dealer's id, in this buff's state,
##    refused by the predicate and RE-CHECKED at the top of activate, because event_buff_activate has no
##    recheck and both chunks' POSTs pass the predicate before either runs. Non-attack damage traces to its
##    own event id, so it counts once per event.
##    THE EFFECT: Overshield.increase_by(activation, dealer, 1, <the Black Mountain's core gear>) - additive,
##    and it hangs the "granted by" mark An End to All Things keys on. After the Black Mountain's death the
##    gear no longer resolves, and increase_by degrades to the plain increase with no mark - correct:
##    nothing of the Black Mountain's is left to key on it. activate is OVERRIDDEN and never clears the buff
##    (Buff.activate's default consumes it, buff.gd:254-255).
##
## TWO BLACK MOUNTAINS DOOMING ONE TARGET STACK: two sources, two buffs, two +1s, two shields - as two
## different effects would in Lancer (ruling 13).
extends BuffBonus

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const AttackTrace := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/attack_trace.gd')
const VigilAction := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_purple_thorn/mt_vigil/action_vigil.gd')

## Buff core state: the dooming Black Mountain's persistent id and its side (Faction.SIDE).
const DOOMED_BY_KEY := 'doomed_by'
const SIDE_KEY := 'doomed_by_side'
## Buff core state: every "<attack id>:<dealer id>" this mark has already paid Overshield for.
const PAID_KEY := 'doomed_paid'
const OVERSHIELD_PER_ATTACK := 1

func is_cleared_on_owner_death() -> bool: return false

func on_application(event:EventCore, core:BuffCore, _unit:Unit) -> void:
	var black_mountain := core.get_owner_unit(event.context.map)
	if not Unit.is_valid(black_mountain): return
	core.set_state(DOOMED_BY_KEY, String(black_mountain.core.persistent_id))
	core.set_state(SIDE_KEY, int(black_mountain.get_faction()))

## "Allies" of the Black Mountain that doomed this holder: a CHARACTER on its side, not the Black Mountain.
## Reads only what was stored at application.
static func is_an_ally_of_the_doomer(core:BuffCore, unit:Unit) -> bool:
	if not Unit.is_valid(unit) or not unit.is_character(): return false
	if String(unit.core.persistent_id) == String(core.get_state(DOOMED_BY_KEY, '')): return false
	var side:int = core.get_state(SIDE_KEY, -1)
	if side < 0: return false
	return Faction.is_ally(side as Faction.SIDE, unit.get_faction())

# ---------------------------------------------------------------- 1. accuracy

func is_buff_context_valid_for_passive(_core:BuffCore, context:Context) -> bool:
	return context != null and Unit.is_valid(context.unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	return is_an_ally_of_the_doomer(core, context.unit.get_attacker(context))

# ---------------------------------------------------------------- 2. Overshield on damage

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.number]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false # damage dealt TO the doomed holder
	if not Unit.is_valid(context.target_unit): return false
	var dealer:Unit = context.target_unit.get_attacker(context)
	if not VigilAction.is_damage_dealt_by(dealer, context): return false
	if not is_an_ally_of_the_doomer(core, dealer): return false
	return not core.state_has_id_in(PAID_KEY, stamp_for(triggering_event, dealer))

## Once per dealer per attack.
static func stamp_for(damage:EventCore, dealer:Unit) -> StringName:
	return StringName('%s:%s' % [AttackTrace.enclosing_attack_id(damage), dealer.core.persistent_id])

func activate(core:BuffCore, activation:EventCore) -> void:
	var damage:EventCore = activation.context.event
	if damage == null or damage.context == null or not Unit.is_valid(damage.context.target_unit): return
	var dealer:Unit = damage.context.target_unit.get_attacker(damage.context)
	if not Unit.is_valid(dealer): return

	# THE STAMP, FIRST - and the re-check event_buff_activate does not do for us.
	var stamp := stamp_for(damage, dealer)
	if core.state_has_id_in(PAID_KEY, stamp): return
	core.append_to_array_state(PAID_KEY, String(stamp))

	var black_mountain_gear := core.get_owner_gear(activation.context.map) # invalid once it is destroyed
	await Overshield.increase_by(activation, dealer, OVERSHIELD_PER_ATTACK, black_mountain_gear)
