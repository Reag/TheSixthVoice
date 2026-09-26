## ENSORCEL'S SUPPRESSOR (design 3.2, ruling 22): "cannot apply any heat". HIDDEN, on the Ensorcel's
## target, owned by the Rakshasa's Scan gear.
##
## DAMAGE_IMMUNITY cancels a damage event outright (damage_modifications.gd:38-42). This one applies
## only to HEAT whose source (context.target_unit, the engine's "who did this", action_sear.gd:16) is
## the Rakshasa - so an invade that deals heat inside its own effect (vanilla Sear) stays on offer and
## lands without its heat. Sear's self-damage to the Rakshasa is Energy, and on the Rakshasa, so it is
## untouched.
##
## IT IS ALSO WHERE THE INVADE RUNS. action_ensorcel.gd executes this buff through event_buff_activate
## with the chosen invade's gear and action in the event's context; activate below runs that invade's
## on_hit and on-hit effects on the holder under the Ensorcel's own context cloned to the invade's gear
## and action - the engine's own variant swap (event_gear_activate.gd:89-90) - so SpecificAction
## .from_context names the Rakshasa, the invade's gear and the invade, a full forcing trifecta for any
## save the invade forces (Worm Code sees it, ruling 6). Anything the invade QUEUES is a child of this
## immediate block and resolves before action_ensorcel clears the buff. No AttackRoll is supplied:
## nothing here is an attack roll.
##
## until = END_OF_THIS_TURN is only the backstop; action_ensorcel clears it as soon as the block is done.
## activate does NOT call super, whose default clears the buff before the queued children run.
extends Buff

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if context.category_int != Lancer.DAMAGE_TYPE.HEAT: return false
	return Unit.is_valid(context.target_unit) and context.target_unit == core.get_owner_unit(context.map)

func activate(core:BuffCore, activation:EventCore) -> void:
	var target:Unit = core.get_holder_unit(activation.context.map)
	var ensorcel:EventCore = activation.context.event
	var invade:ActionAttackTech = activation.context.action as ActionAttackTech
	if not Unit.is_valid(target) or ensorcel == null or invade == null: return
	var own_context := activation.context
	activation.context = Context.clone(ensorcel.context, {
		gear = own_context.gear,
		action = invade,
		target_units = [target],
	})
	await invade.on_hit(activation, target)
	if Unit.is_valid(target): await OnHitEffect.apply_on_hits(invade.on_hit_effects, activation, target)
	activation.context = own_context
