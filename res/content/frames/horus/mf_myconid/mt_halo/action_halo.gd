## HALO: the Myconid answers a hit by shielding somebody else.
##
##   "1/round, when the Myconid takes damage, an allied character within Sensors gains OVERSHIELD
##    equal to GRIT."
##
## EXTENDS ActionReaction, NOT ActionReactionSelf. On a damage event context.unit is the VICTIM
## (event_unit_damage.gd's own required context), which here happens to be us - so the Self
## archetype's gate would be accidentally right for the wrong reason, and would stop being right the
## day this trait wanted to see anybody else's damage. action_heaer_detonate.gd's header records the
## same choice on the same seam, and the Vorpal Gun's action_snicker_snack.gd is vanilla's worked
## precedent.
##
## WHAT "TAKES DAMAGE" MEANS (ruling, 2026-09-15). Any event_unit_damage of a type other than HEAT
## that lands a positive number on the Myconid.
##
## THE "ARMOR STOPPED ALL OF IT" HALF IS **OURS**, NOT THE ENGINE'S. The plan said
## event_unit_damage.gd:93 aborts the event on a hit entirely soaked by armor, so no gate was needed.
## It does not, and MEASURED 2026-09-16 it does not: `capped_damage` is a damage CAP contributed by
## BuffResistDamage.FLAG.CAP buffs (grunt save, paradox shield, flash aegis) and defaults to
## MAXIMUM_DAMAGE_CAP = 9999 (damage_modifications.gd:11, :69) - armor never touches it. Armor is
## applied to `context.number` instead (:55, :66), and a 2-damage hit on this frame's armor 2 reaches
## :196 with number 0, queues DAMAGE POST, and offered Halo. Hence the `context.number <= 0` clause
## in the gate below; test_a_hit_zeroed_by_armor_does_not_offer_halo is what it answers.
##
## THAT SAME NUMBER IS WHAT KEEPS SOAKED DAMAGE IN. The Overshield soak happens inside damage()
## (:215-220) against the local `damage_amount`, and never writes back to context.number - so damage
## absorbed entirely by existing Overshield still reads positive here and still offers Halo, which is
## the ruling. Burn ticks are damage events of type BURN and count too. Heat does not: heat is not
## damage in Lancer, and buff_suppress.gd:27-28 is vanilla's own exclusion of it from "damages".
##
## THE 1/ROUND IS THE ENGINE'S. get_per_round_hard_limit is overridden because ActionReaction returns
## 99 for a reaction that consumes no point (action_reaction.gd:69); the limit is consulted inside
## ReactionBus.does_reaction_trigger via can_activate_gear, so a Halo past the limit is never OFFERED
## rather than offered and refused. It clears at the Myconid's OWN turn start
## (reset_per_round_usage, unit_action.gd:78) - per turn in truth, accepted for vanilla parity.
##
## SYMBIOSIS RAISES THAT LIMIT BY ONE, AND THAT IS THE CARD (SP2.5 Task 1). The trait says "1/round,
## the Myconid may use a reaction an additional time", excluding only 1/scene and 1/mission ones;
## Halo is a reaction and is neither, so buff_symbiosis_extra_use adds +1 to the cap here through
## Buff.TO.ACTION_PER_ROUND (unit_action.gd:170-175) exactly as it does for the Uffish Gyre. So a
## round really holds TWO Halos while the trait's extra is unspent, and the THIRD is the one never
## offered. Nothing in this file changed for it - the +1 arrives through the engine's own channel -
## but the number below is no longer the whole story, which is why it is written here.
##
## NOTHING IS SPENT UNTIL AN ALLY IS CHOSEN. spend_actions runs after the prompt returns, so
## cancelling declines at no cost - which is the reading of "an allied character gains" that lets a
## player hold the round's Halo for a better moment.
extends ActionReaction

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## Bookkeeping, not a rule the player reads twice: the trait card's effect row says everything there
## is to say, and a reaction never reaches the gear bar anyway. show_in_tooltip is a FUNCTION on
## Action (action.gd:341), not an exported property, so this is the only way to set it - the same as
## ms_heaer's detonate and mt_blasting_powder's spend reaction.
func show_in_tooltip(_kit:Kit) -> bool: return false

## DELIBERATELY EMPTY, overriding the empty default only to say so out loud. A required triggering
## prop is re-checked at execution time, not only at collection time (event_gear_activate.gd:37), and
## everything this reaction reads it reads defensively below. Requiring a prop would abort the
## activation in exactly the cases the ability exists for. The HEAER's reasoning, verbatim.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

## ActionReaction returns 99 for a reaction that consumes no reaction point. The card says 1/round.
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 1

## Allied CHARACTERS within our Sensors, excluding ourselves.
##
## get_all_characters(), not get_all_units(): the card says "an allied character", so a friendly
## drone, turret or other deployable is not a candidate. Excluding self matters because
## UnitRelation.are_allies is true of a unit and itself.
##
## NO LINE OF SIGHT (ruling, 2026-09-15). Bel writes "within Sensors and line of sight" when sight is
## meant - three times on Black Mountain alone - so bare "within Sensors" is range only.
## UnitRelation.distance_between measures closest tiles, so a size-2 Myconid's reach is measured from
## all four of its own tiles.
func eligible_allies(unit:Unit) -> Array[Unit]:
	var allies:Array[Unit] = []
	if not Unit.is_valid(unit) or unit.map == null: return allies
	for other:Unit in unit.map.get_all_characters():
		if other == unit or not Unit.is_valid(other): continue
		if not UnitRelation.are_allies(unit, other): continue
		# REACHABLE AT ALL, on the Uffish Gyre's own test (action_uffish_gyre.gd:130) - author's call
		# at the frame close, 2026-09-16. are_allies and a distance are not enough: can_affect
		# (unit_relation.gd:390-401) also excludes an EXILED ally, one whose INTANGIBLE state differs
		# from ours, an INVULNERABLE one, and one we share no shard with. Without this the prompt
		# offers an ally the halo cannot reach and really fires event_unit_overshield at them.
		if not UnitRelation.can_affect(unit, other): continue
		if UnitRelation.distance_between(unit, other) > unit.get_sensor_range(): continue
		allies.append(other)
	return allies

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	# THE MYCONID took the damage. context.unit on a damage event is the victim.
	if context.unit != unit: return false
	# Not heat. The cast is buff_suppress.gd:27-28's, and Context.PROP.category is OPTIONAL on a
	# damage event (it defaults to Kinetic), so this reads a value that is always present.
	var damage_type:Lancer.DAMAGE_TYPE = context.category_int as Lancer.DAMAGE_TYPE
	if damage_type == Lancer.DAMAGE_TYPE.HEAT: return false
	# And some damage actually landed. See the header: the engine does NOT abort a hit that armor
	# reduced to nothing, so without this the Myconid would Halo off a shot that bounced. Read off
	# context.number, which is the post-armor amount and is untouched by the Overshield soak.
	if context.number <= 0: return false
	# Grit 0 grants nothing, and Overshield.grant refuses a grant of 0 outright - so offering the
	# prompt would ask the player to pick an ally for no effect, on every hit, for the whole of
	# licence level 0.
	if Overshield.grit(unit) <= 0: return false
	# And somebody to shield. A prompt about nobody is worse than no prompt.
	return not eligible_allies(unit).is_empty()

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	# Re-derived LIVE rather than carried over from the gate: the gate ran when the reaction was
	# queued, and an ally may have died or been displaced by something else reacting to the same hit.
	var candidates := eligible_allies(unit)
	if activation.abort_when(candidates.is_empty()): return
	var amount:int = Overshield.grit(unit)
	if activation.abort_when(amount <= 0): return

	var chosen:Unit = await choice_bus.choose_unit(
		candidates, true, SpecificAction.from_context(context)
	)
	# Cancelled. Return BEFORE spend_actions, which is what makes declining free - and the 1/round
	# still available for a later hit in the same round.
	if not Unit.is_valid(chosen): return
	if activation.abort_without_unit(unit): return

	spend_actions(activation)
	# grant_by, not grant (close-out Pass D): the same grant plus the Black Mountain family's hidden
	# "granted by" mark, so Overshield.is_granted_by(chosen, unit) answers. Nothing reads it for the
	# Myconid today; it is taken for uniformity, and a null gear would degrade to the plain grant.
	await Overshield.grant_by(activation, chosen, amount, context.gear)
