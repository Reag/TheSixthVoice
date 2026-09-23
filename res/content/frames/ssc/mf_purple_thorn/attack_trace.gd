# ATTACK TRACE: which declared attack a damage event belongs to. Born with the Purple Thorn's
# Vigil (SP1 Task 2) and read by Rend's chip too (Task 4) - both cards say "whenever you deal
# damage" and both must act ONCE PER ATTACK, not once per victim or once per damage type.
#
# THE PROBLEM IT SOLVES (measured by spec/test_spike_purple_thorn_sp1_seams.gd, 2026-09-23): an
# event_unit_damage's context carries `unit` (the victim), `target_unit` (the dealer), `object`
# (the AttackRoll), `number`, `category`, `flags`, `gear` and `action` - and NO `event`. The
# declared-attack core that produced it is not in the context at all, and the AttackRoll carries no
# id of its own either. All of one attack's damage events run in ONE block
# (event_unit_attack_declared.gd:127-169, :199) and each queues DAMAGE POST separately, so a Blast
# hitting three characters, or a two-type hit, would offer Vigil once per event.
#
# THE ANSWER IS THE BLOCK TREE. EventBlocks are Nodes, and `core.execute_events(damage_events)`
# makes an immediate child block of the declared attack's own block (event_core.gd:77-81,
# event_block.gd:175-183). So from the damage core's `block` (set the moment the block runs it,
# event_block.gd:94), walking get_parent() reaches the block whose event_cores holds the
# event_unit_attack_declared core - and that core's id (Util.generate_random_hexcode at creation,
# event_core.gd:20) is the attack's identity. Pinned by the probe: two rifle shots trace to two
# different ids, and the id the trace finds is the one ATTACK_DECLARED POST sees on
# `context.event.id`.
#
# THE FALLBACK IS THE DAMAGE CORE'S OWN ID. A bare event_unit_damage (a burn tick, a hazard,
# SpecFactory.damage) has no declared attack above it, and "each damage event is its own attack"
# is the right answer for those: nothing there could multi-hit.
#
# READ AT QUEUE TIME AND AT RUN TIME. A reaction's triggers_on_event is polled when the POST is
# queued (the damage core is executing, its block set) and again before the reaction runs when
# recheck_trigger_before_execution is on; both walks find the same block.
#
# No class_name (res/content/gear/shared/README.md): callers preload this file. Stateless.
extends RefCounted

static func enclosing_attack_id(damage:EventCore) -> StringName:
	if damage == null: return &''
	var node = damage.block
	while node is EventBlock:
		for core:EventCore in node.event_cores:
			if core.base.event_type == &'event_unit_attack_declared': return core.id
		node = node.get_parent()
	return damage.id
