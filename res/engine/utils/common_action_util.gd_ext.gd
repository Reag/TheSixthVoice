# Script extension on the CommonActionUtil autoload - the mod's THIRD autoload extension (after
# unit_relation.gd_ext.gd and unit_printer.gd_ext.gd, whose headers explain why a .gd_ext.gd's PATH
# is its declaration and every rule for this file has to live here, each under its own banner).
#
# The FIRST extender of this vanilla file anywhere: no resident and none of the 25 installed zips
# touch it (swept 2026-09-24). The install log is NOT evidence that the override runs;
# spec/test_spike_shackleton_sp1_seam.gd is (a real War Pike knockback through
# action_attack_weapon.on_hit reaches it, and goes RED with the EXTENDED_AUTOLOADS entry removed
# while the target still moves), and mod_main.gd's EXTENDED_AUTOLOADS entry is load-bearing: without
# the deferred reload the live node keeps its pre-extension script (upstream bug 5, unfixed in 1.4.3).
#
# DEPTH: every vanilla knockback reaches generate_knockback_events through a QUALIFIED call through
# the autoload node (`CommonActionUtil.generate_knockback_events`, e.g. action_attack_weapon.gd:337,
# and every NPC/system/talent caller) - depth 0 of the ONE-LEVEL rule. Nothing inside vanilla's own
# file calls it unqualified, so no sibling override is needed.
#
# ============================================================================================
# SPATIAL REROUTING (Shackleton, mt_spatial_rerouting) - "Knockback the Shackleton inflicts can be in
# any direction other than up." Design specs/2026-09-24-shackleton-design.md rulings 3-4.
#
# super builds the pick-move event exactly as vanilla does; when the KNOCKING unit carries the trait,
# its `array` (the knockback origin tiles) is emptied before the event is returned. That is vanilla's
# own "the origin is under the mover" branch (event_unit_pick_move.gd:84-90): with no origin left,
# every tile within the distance is offered instead of a cone angled away. The movement type super
# built is untouched, so the push is still straight, must-move-max and involuntary, and
# cannot_move_uphill = true is what keeps "other than up" (downhill is allowed, as vanilla allows it).
# The deciding party is vanilla's too: the Shackleton's controller picks, and an AI picks the worst
# tile for an enemy (target_action_util.gd:38-39, :60-66).
#
# Keyed on specific.unit, which is who the helper itself credits with the push (the event's `unit`),
# so it covers the Shackleton's weapons, the Ram, Mobilized Hydraulics' extra knockback and any
# knockback its systems cause - and nothing that merely HITS the Shackleton.
# ============================================================================================
extends "res://engine/utils/common_action_util.gd"

const SPATIAL_REROUTING := &'mt_spatial_rerouting'

static func generate_knockback_events(
	target_unit:Unit,
	knockback_amount:int,
	specific:SpecificAction,
	origin_tiles:Array[Vector2i] = [],
	additional_flags:Array = [], # EventUnitPickMove.FLAG
) -> Array[EventCore]:
	var events:Array[EventCore] = super(target_unit, knockback_amount, specific, origin_tiles, additional_flags)
	if specific == null or not Unit.is_valid(specific.unit): return events
	if not GearCore.is_valid(specific.unit.get_gear(SPATIAL_REROUTING)): return events
	for event:EventCore in events:
		if event.context.flags.has(EventUnitPickMove.FLAG.KNOCKBACK): event.context.array = []
	return events
