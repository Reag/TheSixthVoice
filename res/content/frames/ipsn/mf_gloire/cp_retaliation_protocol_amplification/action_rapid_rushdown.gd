## RAPID RUSHDOWN, the Retaliation Protocol Amplification's passive half - Quick, 1/round.
##
##   "You take 2 heat and may move 4 spaces in any direction in a straight line. This movement
##    ignores engagement and doesn't provoke reactions. You may then ram as a free action. Until the
##    start of your next turn, you gain +1 Armor."
##
## Design specs/2026-09-24-gloire-design.md rulings 7-9.
##
## THE MOVE IS DATA (ruling 7): the .tres beside this file carries movement_range_fixed = 4 and an
## inline MovementType with straight_line, ignore_engagement and ignore_rxns set, and
## ActionSystemMovement.activate does the rest - pathfinder, reticle, spend, move
## (action_system_movement.gd:79-110). Full Speed Ahead is the mod's worked example of the same
## archetype with a straight line. The 2 heat is self_heat_dice on the .tres, paid through
## spend_actions like every self-heat in the game (unit_action.gd:227-229). "1/round" is
## get_per_round_hard_limit below, which unit_action.gd:171 enforces for a QUICK.
##
## "MAY MOVE": is_mandatory false, so the reticle can be cancelled - and a cancel returns from
## super.activate ABORTED before the spend (abort_without_movement_plan sits above spend_actions at
## action_system_movement.gd:98-99), so no heat, no action, no armour and no Ram. Slowed and
## Immobilized refuse it at is_available_to_activate (:22-28), which is RAW: Slowed forbids "special
## moves granted by systems".
##
## THE ARMOUR, THEN THE RAM (rulings 8-9), in the card's order and only after a CONFIRMED move -
## whether or not the tile changed. The armour is the mod's pair (buff_armor_statblock.gd /
## buff_armor_reduction.gd: one shows the number, one blunts the damage; read their headers), both
## until = START_OF_TURN, "until the start of your next turn". The Ram is the unit's own mw_ram
## activated AS_FREEBIE - force_landing's shape (common_action_util.gd:210-220): the flag waives cost
## and availability (unit_action.gd:110-114) but NOT targeting, so the Ram's own picker runs, a
## Siege Ram variant is offered as on any Ram, a cancel is a clean abort, and no legal target (nothing
## same-size-or-smaller within Extended Zone Control's Range 3 and line of sight) offers nothing.
## The Ram's Prone lands with mw_ram as its source, so Hydraulic Punisher resolves the Gloire as the
## knocker and adds the Impaired - the frame's loop.
##
## NO AI OPTION (ruling 15): the mod's convention for its core actives; ActionSystemMovement's own
## get_ai_custom_action_option returns null with ai_movement_target_burst_radius at 0.
extends ActionSystemMovement

const RAM := &'mw_ram'
const ARMOR_BUFF := &'buff_rapid_rushdown_armor'
const ARMOR_REDUCTION_BUFF := &'buff_rapid_rushdown_armor_reduction'

## "1/round".
func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit

	# 1. THE MOVE - reticle, spend (heat included), the dash. A cancelled reticle aborts here, unspent.
	await super.activate(context, activation)
	if activation.aborted: return
	if activation.abort_without_unit(unit): return

	# 2. THE ARMOUR, both halves, before the Ram: "Until the start of your next turn, you gain +1
	# Armor". from_gear is this Kit (action.gd:375), so the chip reads its own rows.
	apply_buff_id(activation, unit, ARMOR_BUFF)
	apply_buff_id(activation, unit, ARMOR_REDUCTION_BUFF)

	# 3. THE FREE RAM. The unit's own basic Ram, as a freebie; its picker decides the rest - but only
	# when there is someone to pick. The Ram's picker opens even over an empty field (measured
	# 2026-09-24: one compcon_plan prompt with nothing in it), which a player would have to cancel by
	# hand, so "no legal target = nothing offered" (ruling 8) is checked here first, the way the
	# testkit responder itself enumerates targets: the targetable tiles, the units on them, the
	# action's own can_target_unit.
	var ram:GearCore = unit.get_gear(RAM)
	if not GearCore.is_valid(ram): return
	var ram_specific := SpecificAction.create(unit, ram, ram.get_solo_action())
	var targetable_tiles := UnitTargeting.get_tiles_targetable(ram_specific)
	var targets:Array[Unit] = unit.map.get_all_units_at_tiles(targetable_tiles, unit)
	Util.filter(targets, ram_specific.action.can_target_unit.bind(ram_specific))
	if targets.is_empty(): return
	await activation.execute_event(&'event_gear_activate', {
		unit = unit,
		gear = ram,
		action = ram.get_solo_action(),
		flags = [Action.FLAG.AS_FREEBIE],
	})
