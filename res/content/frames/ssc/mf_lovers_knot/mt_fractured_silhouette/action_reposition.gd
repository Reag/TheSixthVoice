## REPOSITION - "Trigger: A hostile character at a lower elevation misses you with a ranged attack.
## Effect: You may immediately move up to half your speed." Design 1.3, ruling 6.
##
## Vanilla Acrobatics' missed-by trigger (t_ace/rank_1/action_acrobatics.gd) with the Nelson's
## Skirmisher's range override (action_skirmisher.gd:4-6), on the stock ActionReactionMovement: the
## standard "use reaction?" confirm, then the cancellable move picker, and spend_actions only once a
## plan exists (action_reaction_movement.gd:76-78) - so a declined offer or a cancelled pick costs
## nothing.
##
## THE SHOOTER IS context.unit, NOT get_attacker(): the card's subject is whoever fired, and a drone's
## shot has a drone for its unit. It must be a hostile CHARACTER, which in this mod is is_actor() (ruling
## 3: a drone is not one).
##
## "A RANGED ATTACK" IS UnitAction.is_ranged_weapon (unit_action.gd:555-559): any ActionAttackWeapon
## that is not MELEE. A tech attack is not an ActionAttackWeapon, so it never triggers this.
##
## "AT A LOWER ELEVATION" IS UnitTile.effective_floor, STRICTLY lower - vanilla Solar Backdrop's
## comparison (buff_solar_backdrop.gd:11). It is the unit's lowest foot (unit_tile.gd:211-218) plus the
## flight offset (+3 for a flier, :226-234), so a flying Knot stands above a grounded shooter on level
## ground. The talents mod's unit_tile.gd_ext.gd overrides get_unit_elevation_off_ground and calls
## super, so a zero-G unit counts at its hover height too - which is what elevation means on the card.
## Do NOT read UnitBattleState.PROP.ELEVATION instead: it likely double-counts flight (:294).
##
## A GRAPPLED KNOT TAKES NO REACTIONS. ActionReactionMovement.is_available_to_activate REPLACES
## ActionReaction's without calling it (action_reaction_movement.gd:44-49), so it checks only Slowed and
## Immobilized - and the larger party in a grapple is neither (unit_condition.gd:416). The override adds
## back the one engine rule that says so, UnitAction.can_take_reactions (unit_action.gd:378-386), which
## is what ActionReaction itself asks. Vanilla Acrobatics has the same gap; close review 2026-09-26.
extends ActionReactionMovement

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super(unit, gear): return false
	return UnitAction.can_take_reactions(unit, Context.create({unit = unit, gear = gear, action = self}))

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit,
		Context.PROP.target_units,
		Context.PROP.action,
		Context.PROP.object, # the AttackRoll
	]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var triggering_context:Context = triggering_event.context

	# a miss
	if AttackRoll.check(triggering_context.object, &'hit') != false: return false

	# with a ranged weapon
	var weapon_gear:GearCore = triggering_context.gear if GearCore.is_valid(triggering_context.gear) else null
	if not UnitAction.is_ranged_weapon(triggering_context.action, weapon_gear): return false

	# by a hostile character
	var shooter:Unit = triggering_context.unit
	if not Unit.is_valid(shooter) or not shooter.is_character(): return false
	if not UnitRelation.are_enemies(shooter, unit): return false

	# standing strictly lower
	return UnitTile.effective_floor(shooter) < UnitTile.effective_floor(unit)

## Half speed, rounded up (the mod's convention, rulings 2026-09-16).
func get_target_range(specific:SpecificAction) -> int:
	return Util.half(specific.unit.get_speed_max())
