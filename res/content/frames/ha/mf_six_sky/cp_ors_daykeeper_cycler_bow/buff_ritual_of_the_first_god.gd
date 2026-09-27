## THE RITUAL'S SCOPE (design 2.1-2.2, rulings 17 and 19): one hidden buff, one lifetime, two jobs.
##
## 1. SLOWED ON HIT. A BuffWeaponTypeOnHit (Buff.TO.ONHIT_EFFECT, read per attack at
##    event_unit_attack.gd:48-49) carrying onhit_ritual_slowed.tres: ON_HIT, a Systems save forced by the
##    bow, Slowed on a fail - Slowed's standard until is END_OF_NEXT_TURN (status_slowed.tres), which is
##    the card's "until the end of their next turn". ON_HIT covers a crit too (event_unit_attack.gd:84-93).
## 2. THE CRIT RECORD. The bow's on_crit appends each critted target here, in attack order, instead of
##    prompting; the Ritual reads the record back after its last attack (ruling 17, the author's).
##
## GATED ON THE RITUAL'S OWN SHOTS, not merely on the buff being held: from_compcon_id pins the bow, and
## the shot must carry Action.FLAG.NO_SELF_HEAT, which the Ritual passes to every attack it fires and no
## ordinary shot does. So an Overwatch or any other reaction that fires the bow while the Ritual is
## running (the buff is held) carries no Slowed and resolves its own crit at once. The flag travels from
## the gear activation to the declared attack and to each attack roll (action_attack.gd:273,
## event_unit_attack_declared.gd:55).
##
## APPLIED BY THE RITUAL BEFORE ITS FIRST ATTACK AND CLEARED ON EVERY EXIT, the Six Sky's death included
## (action_ritual_of_the_first_god.gd). until MANUAL: nothing else ever clears it.
extends BuffWeaponTypeOnHit

const BUFF_ID := &'buff_ritual_of_the_first_god'
## Buff core state: the persistent ids of every target the bow critted during this Ritual, in order.
const CRITS_KEY := 'ritual_crits'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	return is_ritual_shot(context)

static func is_ritual_shot(context:Context) -> bool:
	return context != null and context.flags.has(Action.FLAG.NO_SELF_HEAT)

## The scope a crit on this shot belongs to, or null when this shot is not the Ritual's.
static func live_scope(six_sky:Unit, context:Context) -> BuffCore:
	if not is_ritual_shot(context): return null
	return UnitCondition.get_buff(six_sky, BUFF_ID)

static func record_crit(scope:BuffCore, target:Unit) -> void:
	if scope == null or target == null: return
	scope.append_to_array_state(CRITS_KEY, str(target.core.persistent_id))

## Persistent ids, in the order the crits happened.
static func recorded_crits(scope:BuffCore) -> Array[String]:
	if scope == null: return []
	return scope.get_state_string_array(CRITS_KEY)
