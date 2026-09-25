## MAKIBISHI MAGNETS, THE SECOND MINE (design 3.1, ruling 24):
##
##   "On use, you may choose to expend a second charge, if you do, you may deploy a second mine in
##    valid space."
##
## THE ISKANDER'S MINE DEPLOYERS (action_mine_deployers.gd), narrowed to this Kit: a hidden
## self-reaction on `unit_action` after a NON-FREEBIE deploy of THIS Kit's own mine, offering that
## same deploy again through choose_and_use with choose_and_use_no_spend. The freebie still spends a
## CHARGE (unit_action.gd:274 - "freebies still expend charges"), which is the card's "expend a second
## charge", and at 0 charges the deploy is not available, so nothing is offered. With one candidate
## the menu is skipped (common_action_util.gd:660) and the deploy's own reticle IS the offer: its
## cancel is the "may". The second mine may not go adjacent to the first - the deploy's own "valid
## space" (action_system_deploy.gd:42-45).
##
## "A mine" is read literally (ruling 24): Throw Magnets offers nothing. An Iskander carrying the Kit
## gets a third from its own trait; recorded, not fought.
extends ActionReactionSelf

const MINE_ACTION := &'action_makibishi_mine'

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action]

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var context:Context = triggering_event.context
	# not the second mine itself, and not somebody else's freebie deploy of it
	if context.flags.has(Action.FLAG.AS_FREEBIE): return false
	# THIS Kit's own mine
	if context.gear != gear: return false
	if context.action == null or context.action.get_id() != MINE_ACTION: return false
	return UnitAction.is_gear_available(second_mine(unit, gear), true)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if activation.abort_without_unit(unit): return
	var mine := second_mine(unit, context.gear)
	if not UnitAction.is_gear_available(mine, true): return
	await CommonActionUtil.choose_and_use(
		activation,
		SpecificAction.from_context(context),
		[mine] as Array[SpecificAction],
		CommonActionUtil.choose_and_use_no_spend,
	)

func second_mine(unit:Unit, gear:GearCore) -> SpecificAction:
	return SpecificAction.create(unit, gear, gear.get_action(MINE_ACTION))
