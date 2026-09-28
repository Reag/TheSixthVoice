# NATIVE RELIABLE - the shared carrier for "increase Reliable" effects. Consumers: the Hazard's
# Weight of Fire (buff_weight_of_fire.gd), the Statistical Compensator
# (action_statistical_compensator.gd) and the Grutte Pier's Zwarte Hoop (action_zwarte_hoop_spend.gd,
# which also reuses SENTINEL_PRIORITY and CARRIER_EVENT for its own sentinel).
#
# FROZEN INTERFACE (close-out Pass F Task 21): raise, is_raised, STATE_META, SENTINEL_PRIORITY,
# CARRIER_EVENT. spec/test_native_reliable.gd pins the two signatures and the three constants'
# values, and fails on a third public function; an addition updates that pin in the same commit.
#
# Replaced reliable_topup.gd on 2026-09-24, on the approach the
# Clark's author (fateofman-ipsn_clark, Redundant Scattering Module) recommended: raise the number
# the engine reads instead of paying a second damage event after the fact.
#
# WHY IT CAN WORK. The engine reads the Reliable floor ONCE, from the weapon action's own export, at
# content/events/event_unit_attack/event_unit_attack_declared.gd:82
# (`base_damage.reliable = unit.get_tiered_int(action.reliable_damage)`) - AFTER the ATTACK_DECLARED
# PRE reactions (:23). So a PRE reaction that raises `reliable_damage` gets the engine's own
# arithmetic for every roll of the attack: misses, low hits, crits, armor, resistance, the damage
# log's "Reliable" label (event_unit_damage.gd:255). ONE damage event per roll, so anything reacting
# to damage fires once - the top-up dealt a second event and fired it twice.
#
# WHY IT IS DANGEROUS, AND WHAT THIS FILE IS FOR. The action is the Kit's own resource, SHARED by
# every unit carrying that weapon, enemies included. A raise that is never lowered is on every
# rifle of that kind until the game restarts. The Clark lowers at ATTACK_DECLARED POST, which the
# attack SKIPS when it stops early - execute() returns at :47 and :69 when the attacker is no longer
# valid (killed by a reaction to its own attack), so POST never fires.
#
# SO THE LOWER IS NOT A POST REACTION. raise() queues a SENTINEL block as a child of the attack's
# own event block, at priority -1000. EventBlock.execute runs every unfinished child after its
# events finish, WHETHER OR NOT THE EVENT ABORTED (event_block.gd:139-143), lowest priority first -
# so the lower runs after every POST reaction, before anything else queued on that block (a
# follow-up attack queued there must not read our raise). The sentinel's deferred condition does the
# lowering and returns false, so its carrier event never runs. If the level exits instead, the
# block is freed and the sentinel's tree_exiting lowers it. Both paths are idempotent.
#
# ANOTHER WRITER (the Clark, residency set since 2026-09-24). We add our amount ON TOP of whatever
# is there, and at the end restore our saved base ONLY IF the export still holds what we last
# wrote. The Clark saves the value it finds and writes it back at its POST, which is always before
# our sentinel. Either order then comes out clean:
#   Clark first:  O -> O+d (Clark) -> O+d+g (us). Clark POST writes O. Not ours: we leave O.
#   us first:     O -> O+g (us) -> O+g+d (Clark). Clark POST writes O+g, which IS ours: we write O.
# The residue: if another writer raised on top of us and never lowered (its own POST skipped), its
# value stays, and ours inside it. That writer's leak, and we cannot tell it from a deliberate write.
#
# THE WEAPON CARD IS NOT THIS. The WEAPON_TAG buffs still draw the raised number on the card; this
# is only what the ENGINE reads, and only for the length of one attack.
#
# RefCounted, no class_name (the mod's shared-helper rule): preload it.
extends RefCounted

## The raise record, on the shared ActionAttackWeapon: {base, written, raises = {token: amount}}.
const STATE_META := &'reag_native_reliable'
## Children run lowest-first; this must beat anything else queued on the attack's block.
const SENTINEL_PRIORITY := -1000
## The sentinel's carrier. Never executed - the deferred condition always refuses it.
const CARRIER_EVENT := &'event_delay'

## Raise the Reliable the engine reads for this declared attack by `amount`, until the attack's
## block is done. `declared` is the ATTACK_DECLARED EventCore (a reaction's context.event). One
## raise per `source` per attack - a second call is a no-op.
static func raise(declared:EventCore, amount:int, source:StringName) -> void:
	if amount <= 0 or declared == null: return
	var action = declared.context.action
	var unit:Unit = declared.context.unit
	if not (action is ActionAttackWeapon) or not Unit.is_valid(unit): return
	# refuse outright rather than raise something nothing would ever lower
	if not is_instance_valid(declared.block) or not declared.block.is_inside_tree(): return

	var token := '%s:%s' % [declared.id, source]
	var state:Dictionary = action.get_meta(STATE_META, {})
	if state.is_empty(): state = {base = action.reliable_damage, written = '', raises = {}}
	if state.raises.has(token): return
	state.raises[token] = amount

	action.reliable_damage = str(unit.get_tiered_int(action.reliable_damage) + amount)
	state.written = action.reliable_damage
	action.set_meta(STATE_META, state)

	var lower := func() -> bool:
		_lower(action, token, unit)
		return false # never run the carrier
	var sentinel := EventBlock.create(CARRIER_EVENT, {}, 'reag_native_reliable_%s' % token)
	sentinel.deferred_required_conditions = lower
	sentinel.tree_exiting.connect(func() -> void: _lower(action, token, unit))
	declared.block.queue_block(sentinel, SENTINEL_PRIORITY)

## True while any raise is live on this action. For specs and for anyone debugging a leak.
static func is_raised(action:Action) -> bool:
	return action != null and action.has_meta(STATE_META)

## Undo one raise. Idempotent: a token already lowered does nothing.
static func _lower(action:ActionAttackWeapon, token:String, unit:Unit) -> void:
	if not is_instance_valid(action) or not action.has_meta(STATE_META): return
	var state:Dictionary = action.get_meta(STATE_META)
	if not state.raises.has(token): return
	var amount:int = state.raises[token]
	state.raises.erase(token)
	var still_ours:bool = action.reliable_damage == state.written

	if state.raises.is_empty():
		if still_ours: action.reliable_damage = state.base
		action.remove_meta(STATE_META)
		return

	if still_ours: # another of our raises is still live (a nested attack): take off only this one
		var tier:int = unit.core.tier if Unit.is_valid(unit) else 1
		action.reliable_damage = str(maxi(0, Util.get_tiered_int(action.reliable_damage, tier) - amount))
		state.written = action.reliable_damage
