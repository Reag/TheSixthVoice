## FORM OF THE MYRIAD (Lovers Knot, cp_integrated_redirection_aggregate's active), design 3, rulings 17-21:
##
##   "Until the end of your turn, Gemini charge may be redirected 3 additional times, Line or Range is not
##    reduced upon redirection and each character can only be targeted once. Choose a weapon you have
##    mounted, you may attack with it as part of this action. Precision Venting can trigger any number of
##    times until the end of your turn. This action is Efficient, and refunds 1 Core Power at the end of
##    any scene in which it's used."
##
## A FULL ActionSystem that consumes the core power (both on the .tres). activate, in order:
##
## 1. THE CONFIRM, then THE SPEND and THE EFFICIENT STAMP. CommonActionUtil.confirm_use (a non-player
##    unit auto-confirms), the vanilla archetype's order (action_system_apply_buff.gd:103, :122) and the
##    Purple Thorn's Rend: a declined confirm costs nothing, and from the spend on the core power is gone
##    whatever the attack then does. Efficient.mark_used sits right after spend_actions so the stamp and
##    the spend can never disagree (the frozen helper, roadmap §4). The design's order began at the spend;
##    the confirm is the mod's and vanilla's standing guard on a one-a-mission button.
## 2. THE CHIP (buff_form_of_the_myriad, visible, END_OF_THIS_TURN). The chip IS the ability: Gemini's
##    buff reads it for its leg count and reach (ruling 18) and Precision Venting's for its round gate
##    (ruling 20); neither needs anything else from here.
## 3. A SPENT GEMINI ROUND IS RESTORED (ruling 19) by clearing the stamp on this same core gear - Gemini's
##    applicator lives on this Kit, so its round and this action share one GearCore. Gemini's 1/round is
##    not otherwise lifted: the chain commits one use and stamps it again. Recorded, not fought: a round
##    restored here and then left unused by the Myriad attack stays open until the Knot's next turn start,
##    reachable only by a reaction attack later the same round.
## 4. THE ATTACK. CommonActionUtil.choose_and_use over every attack of every mounted weapon (ruling 21):
##    the Purple Thorn's Rend without its QUICK-only filter, so a Superheavy's Full attack is offered too.
##    choose_and_use_no_spend (the shot costs the action economy nothing - choose_and_use adds AS_FREEBIE,
##    which still spends loading and charges, unit_action.gd:236-279), no mandatory target, NO flags,
##    and NOT counts_as_overwatch (the seventh argument, action_rend.gd's correction). NOT CAN_FOLLOWUP:
##    that is Rend's, because Rend is a Skirmish; this card chooses ONE weapon, and the flag fired the
##    other Aux of an Improved Armament flex mount free (close review 2026-09-26). Cancelling the
##    chooser or its targeting is the card's "may": the power stays spent and the chip stays up for any
##    other attack this turn. A melee or Blast weapon may be chosen; Gemini simply does not offer on it.
extends ActionSystem

const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')
const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

## The visible chip - buff_form_of_the_myriad.tres.
@export var chip:Buff

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	var specific:SpecificAction = SpecificAction.from_context(context)

	# 1. THE CONFIRM, THEN THE SPEND AND THE STAMP.
	var confirmed:bool = await CommonActionUtil.confirm_use(context)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_unit(unit): return
	spend_actions(activation)
	Efficient.mark_used(gear)

	# 2. THE CHIP.
	apply_buff(activation, unit, chip)

	# 3. A SPENT GEMINI ROUND IS RESTORED.
	gear.uses_this_round.erase(Record.USAGE_KEY)

	# 4. THE ATTACK.
	var weapons := myriad_weapons(unit)
	if weapons.is_empty(): return # nothing mounted to fire; the chip stands
	await CommonActionUtil.choose_and_use(
		activation,
		specific,
		weapons,
		CommonActionUtil.choose_and_use_no_spend,
		[], # no mandatory target: the player aims the shot
		[], # ONE weapon: no follow-up from the opposite mount slot
		false # NOT overwatch
	)

## Every attack of every mounted weapon (integrated ones included - LoadoutCore.get_all_weapons) that
## could fire as a freebie right now: a weapon already fired this turn is still offered, while loading,
## charges and destruction still refuse (UnitAction.is_gear_available with as_freebie). Static and
## side-effect free; the spec reads it too.
static func myriad_weapons(unit:Unit) -> Array[SpecificAction]:
	var weapons:Array[SpecificAction] = []
	if not Unit.is_valid(unit): return weapons
	for gear:GearCore in unit.core.loadout.get_all_weapons():
		for action:ActionAttackWeapon in gear.kit.get_weapon_actions():
			var candidate := SpecificAction.create(unit, gear, action)
			if not UnitAction.is_gear_available(candidate, true): continue
			weapons.append(candidate)
	return weapons
