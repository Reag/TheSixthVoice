## The vent itself: spend the round, then clear 1 heat from the Knot (the Fuel Rod Gun's
## event_unit_cool, queued behind the attack the way ms_auto_cooler queues it).
##
## NO PROMPT (ruling 5): the card's "may" is never a cost worth a click.
##
## THE HEAT IS RE-READ HERE. buff_precision_venting only hands this effect out while the Knot has heat,
## but that was read when the on-hits were collected, before the roll; a crit that finds nothing to
## clear by the time it lands keeps the round (ruling 5). Under CANNOT_COOL the round IS spent - the Knot
## has heat, the clear is simply refused by event_unit_cool (:17-22), and that is the target's problem,
## not a decline.
##
## A VENT UNDER THE MYRIAD CHIP IS FREE (Pass E, Lovers Knot item 1, AUTHOR): while
## buff_form_of_the_myriad is held the round is not counted, so a crit later the same round - a
## reaction shot after the chip has expired - can still vent. buff_precision_venting stands its gate
## down under the chip; this is the other half, the increment.
##
## THE BOOKKEEPING FLAG. increment_action_usage's second argument is passed false to match this mod's
## other buff-rolled 1/round traits (onhit_rend.gd's reasoning): it gates only the per-turn tally.
extends OnHitEffect

const TRAIT_ID:StringName = &'mt_precision_venting'
const USAGE_KEY:StringName = &'precision_venting'
const MYRIAD_CHIP := &'buff_form_of_the_myriad'

func on_crit(activation:EventCore, attacked_unit:Unit) -> void:
	var knot:Unit = activation.context.unit
	if not Unit.is_valid(knot) or knot.core.current.heat <= 0: return
	var trait_gear:GearCore = knot.get_gear(TRAIT_ID)
	if GearCore.is_valid(trait_gear) and not UnitCondition.has_buff(knot, MYRIAD_CHIP):
		trait_gear.increment_action_usage(USAGE_KEY, false)
	activation.queue_event(&'event_unit_cool', {
		unit = knot,
		number = 1,
	})
