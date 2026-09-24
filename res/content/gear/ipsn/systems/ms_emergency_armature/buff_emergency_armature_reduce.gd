## ACTIVATE EMERGENCY ARMATURE's "reduce the incoming damage by 1d6" (Hazard SP2, ruling 9 as
## amended by the author on 2026-09-24: ONE POOL).
##
## WHY NOT buff_leadership_reduce.tres VERBATIM, which ruling 9 named. BuffResistDamage.get_values
## rolls `reduction_amount` afresh on EVERY call, and DamageModifications.create calls it twice per
## damage event (the reduce loop and the resistance loop) - so the Leader's reduction is not one 1d6
## at all. Worse for this card, a two-type hit is two damage events (event_unit_attack_declared.gd:
## 154-169), and a reduction buff survives the first (SKIP_CONSUMING_RESIST_BUFFS) and reduces the
## second IN FULL again. The card reduces "the incoming damage" once.
##
## THE POOL. The reaction rolls the 1d6 ONCE and hands it to arm(). Each damage event then draws what
## it can use from what the earlier events of the same hit left: min(pool left, what would land
## without us). The draw is keyed by the damage event's Context - DamageModifications.create is
## called for it twice (the preliminary figure before DAMAGE PRE and the final one after,
## event_unit_damage.gd:47-61) and several times over inside each, so a draw must be idempotent per
## event rather than a running subtraction.
##
## "WHAT WOULD LAND WITHOUT US" is DamageModifications.create run again with this buff switched off
## (PROBING), on the event's raw incoming amount: that is the engine's own arithmetic for halving,
## Exposed, armor (including armor an AttackRoll already used), resistance and every OTHER reduction,
## rather than a copy of it. The raw amount is context.number on the preliminary pass and the
## preliminary DamageModifications' damage_original on the final one (the event overwrote
## context.number with the preliminary result in between, event_unit_damage.gd:51-52).
##
## CONSUMED like any reduction buff: is_onetime, after the LAST type of the hit; `until =
## FINISH_DAMAGE` (the .tres) as the backstop the engine clears at the same point and at turn end.
extends BuffResistDamage

const POOL_KEY := 'emergency_armature_pool'
const DRAWN_KEY := 'emergency_armature_drawn'
const PROBING_KEY := 'emergency_armature_probing'

## Load the rolled 1d6 into a freshly applied copy of this buff.
static func arm(core:BuffCore, amount:int) -> void:
	if not BuffCore.is_valid(core): return
	core.state[POOL_KEY] = maxi(0, amount)
	core.state[DRAWN_KEY] = {}

static func pool(core:BuffCore) -> int:
	return int(core.state.get(POOL_KEY, 0))

func get_values(core:BuffCore, context:Context) -> Context:
	return Context.create({
		number = draw(core, context),
		flags = [BuffResistDamage.FLAG.REDUCE],
	})

## What this damage event takes from the pool, recorded against it.
func draw(core:BuffCore, context:Context) -> int:
	if core.state.get(PROBING_KEY, false): return 0
	if context == null or not Unit.is_valid(context.unit): return pool(core) # a tooltip asking, not a hit
	var drawn:Dictionary = core.state.get(DRAWN_KEY, {})
	var key:int = context.get_instance_id()
	var drawn_elsewhere:int = 0
	for other_key in drawn.keys():
		if other_key != key: drawn_elsewhere += int(drawn[other_key])
	var left:int = maxi(0, pool(core) - drawn_elsewhere)
	var used:int = 0
	if left > 0: used = mini(left, landing_without_us(core, context))
	drawn[key] = used
	core.state[DRAWN_KEY] = drawn
	return used

func landing_without_us(core:BuffCore, context:Context) -> int:
	var raw:int = context.number
	if DamageModifications.is_valid(context.resource): raw = context.resource.damage_original
	core.state[PROBING_KEY] = true
	var without:DamageModifications = DamageModifications.create(context.unit, raw, context)
	core.state[PROBING_KEY] = false
	return maxi(0, without.damage)
