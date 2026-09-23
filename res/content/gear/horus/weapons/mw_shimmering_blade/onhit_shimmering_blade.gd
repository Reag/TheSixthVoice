## THE SHIMMERING BLADE'S CRIT CLAUSE (Naga SP2 Task 1, design ruling 9).
##
## "On crit: Gain 2 Overshield, your target must succeed on a Systems save or become Slowed until the
##  end of their next turn." (specs/sixth-voice/10-naga.md, Rank I)
##
## THE SAVE IS ROLLED HERE, NOT THROUGH save_to_avoid - a departure from ruling 9's wiring, taken for
## the ruling's own outcome. should_abort runs the declarative save at the effect's stage and returns
## true on a PASS (on_hit_effect.gd:66-70), and apply_on_crits then `continue`s past on_crit
## (:47-51) - so a passed save would cost the Naga its shield too, where the ruling says the save is
## the target's and the shield is not. test_a_passed_save_still_leaves_the_shield is the pin.
##
## ORDER: the shield first, unconditionally, then the save - the card's order.
##
## THE ATTACKER IS get_attacker, not context.unit. A THROW keeps the Naga as context.unit (the thrown
## weapon deployable is spawned by on_attack, it does not make the swing - action_attack_weapon.gd
## :288-316), but a relay would not; get_attacker is the engine's own owner-resolving read
## (event_unit_attack.gd:37-38) and costs nothing to be right about.
##
## "Their next turn" is the HOLDER's clock: UNTIL.END_OF_NEXT_TURN is turned into END_OF_THIS_TURN at
## the holder's own turn start (unit_condition.gd:18-19) and cleared at that turn's end.
extends OnHitEffect

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const SHIELD:int = 2

func on_crit(activation:EventCore, attacked_unit:Unit) -> void:
	var context := activation.context
	if not Unit.is_valid(attacked_unit) or not Unit.is_valid(context.unit): return

	var attacker:Unit = context.unit.get_attacker(context)
	if Unit.is_valid(attacker): await Overshield.grant(activation, attacker, SHIELD)

	# The full trifecta as the forcer, for forced_save's unguarded forcing_action.unit and the
	# saver's TO.SAVE buffs (action_hunt_of_the_vagrant_sowche.gd's header).
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific) or not Unit.is_valid(attacked_unit): return
	var passed:bool = await UnitHasecheck.make_systems_save(activation, attacked_unit, specific, [Lancer.STATUS.SLOWED])
	if passed or not Unit.is_valid(attacked_unit): return

	var source:StringName = context.gear.persistent_id if GearCore.is_valid(context.gear) else &''
	UnitCondition.apply_status(activation, attacked_unit, Lancer.STATUS.SLOWED, Lancer.UNTIL.END_OF_NEXT_TURN, source)
