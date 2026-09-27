## SOLFATARIC BREACH: the Vauban punishes anything the ground catches.
##
##   "Reaction, 1/round.
##    Trigger: A hostile character within Sensors and line of sight becomes Slowed or Immobilized.
##    Effect: They take 1d6 Kinetic damage and become impaired until the end of their next turn."
##
## THE SEAM. statuses_changed is owned by event_unit_apply_status (owns_trigger_types); PRE is fired
## on APPLICATION and POST on removal (reaction_bus.gd:31). The Vlad's Dismemberment
## (action_dismemberment_shred.gd, trigger_timing = 0) is vanilla's worked example of exactly this
## trigger, and this file is its shape with a different question in the gate.
##
## consumes_rxn = true, so this is a REAL reaction: the point is spent, a Jammed or Stunned Vauban
## cannot Breach, and the card's "1/round" is the engine's own default hard limit for a consuming
## reaction (action_reaction.gd:69 - :66 is is_jammable(), corrected 2026-09-18) - which is why there
## is no get_per_round_hard_limit override here.
##
## ============================ WHAT "BECOMES" MEANS ============================
##
## Design §0.5 originally read it as "does not already hold the status and is not immune, both checked
## at the pre-application timing, when the status is not yet on the unit". The SP1 probe measured that
## and BOTH halves are wrong about the timing:
##
##  - The trigger is queued from UnitCondition.on_status_application (unit_condition.gd:167), which
##    runs AFTER the StatusCondition is appended (:105-106). At this gate has_status is ALREADY true
##    for every application, first or fifth, so it cannot discriminate at all.
##  - An immune unit never reaches the gate ON THE DIRECT PATH: apply_status returns at :93-99, before
##    the append. NO IMMUNITY CLAUSE IS NEEDED THERE - and one IS needed on the buff-carried path
##    below, which is the half the design missed. apply_buff_alt appends the buff and then calls
##    on_status_application for every entry of applies_statuses (:757, :760-761) with NO immunity check
##    anywhere in it, and get_buffs_that_apply_status (:809-818) does not filter immunity either - so
##    instances_held() would read 1 and the gate would pass, while get_current_statuses (:375-382), the
##    function that decides what the unit actually HOLDS, DOES filter it and leaves the unit with
##    nothing. Shipped content reaches this: a hostile under the Aegis' buff_defense_net_status_immunity
##    or the Priest's buff_empowered_investiture_immunity (both immune_to_statuses = [impaired, slowed],
##    content/frames/npc/) walking into a Slowing cloud would be Breached for a becoming that never
##    happened. is_a_becoming refuses it explicitly.
##
## What IS readable is HOW MANY instances of the status the target holds, and "becomes" is exactly
## one. Two places carry them and both have to be counted:
##
##  - unit.state.statuses, one StatusCondition per direct application (duplicates and all, :105).
##  - buffs whose applies_statuses carries it. apply_buff_alt appends the buff at :757 and THEN calls
##    on_status_application for each of its statuses at :760-761 - so at this gate the new buff is
##    already in state.buffs and UnitCondition.get_buffs_that_apply_status (:809-818) counts it.
##    Design §0.6a: a zone-carried Slowed or Immobilized DOES fire this trigger, and is ruled a
##    becoming, card-literally.
##
## One predicate covers both, and covers the two mixed cases the design's branch wording does not
## name - a direct Slowed landing on a unit a cloud already Slowed, and the reverse. Both are two
## instances and both are refused, which is right: the target had it already.
##
## GRAPPLED IS DIFFERENT, because one grapple applies it TWICE (probe claim C): first UNSOURCED from
## Katamari.validate_attachments (katamari.gd:313), while state.is_larger_in_grapple is still stale
## and get_origin_unit_for_source names nobody, then SOURCED to the grappler from onhit_grapple.gd:18
## after recalculate_largest_unit. So the count rule would see two and refuse. Read the SOURCED
## application instead, count only SOURCED Grappled conditions, and take is_larger_in_grapple - which
## is correct by then. "Not larger than the grappler" is the engine's own reading of Immobilized
## (UnitCondition.is_immobilized, unit_condition.gd:413-418), which the Subutai's Juggernaut Drive
## already ruled for and which the Vlad's Dismemberment also counts (:33-34).
extends ActionReaction

## Dice.roll_string, NOT Dice.roll_dice - roll_dice takes a parsed Dictionary (dice.gd:22) and would
## not accept this string at all. roll_string is the string roller (dice.gd:79-80) and goes through
## roll_dice, so Dice.CHEAT_ROLL_QUEUE still pops for it. (Design §1.3 names roll_dice; corrected.)
const DAMAGE_DICE := '1d6'

## The two literal statuses on the card. Grappled is handled separately - it is the engine's reading
## of Immobilized rather than a third status the card names (ruling 5).
const CARD_STATUSES:Array[StringName] = [Lancer.STATUS.SLOWED, Lancer.STATUS.IMMOBILIZED]

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit,     # the unit getting the status
		Context.PROP.category, # the status
	]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	# THE FREE HALF OF THE STATUS TEST GOES FIRST, and it is the cheapest clause in the gate: two
	# StringName compares, no allocation, and it refuses every statuses_changed firing on the map that
	# is not one of three statuses - Prone, Engaged, Lockon, Burn, Shredded, this trait's own Impaired.
	# Everything below it costs more: UnitRelation.distance_between allocates two Arrays and a
	# Dictionary through closest_tiles_between (unit_relation.gd:13-25, :31) before its four vertical
	# UnitTile reads, and can_see traces per-tile LOS. is_a_becoming keeps its own copy of this test -
	# it is a public predicate the header documents and must answer correctly when called directly -
	# so this is a duplicate on purpose, and behaviour is identical: every clause here is a
	# side-effect-free predicate of a conjunction. (The SP1 review asked for the opposite reorder, on
	# the premise that is_a_becoming was the expensive clause and distance_between the O(1) one.
	# Re-measured 2026-09-18 from source: both halves of that premise are false.)
	#
	# IT COSTS ONE MUTATION, AND THAT IS RECORDED RATHER THAN HIDDEN. Before this hoist,
	# test_a_status_that_is_not_on_the_card_never_fires went red on neutralising the CARD_STATUSES
	# clause inside is_a_becoming alone. It now takes BOTH lines - this one and that one - exactly as
	# the grapple pair below takes both of its clauses, and for the same reason: two clauses that
	# overlap on purpose. The test still discriminates; the mutation is a pair, not a line.
	var status:StringName = context.category_str
	if status != Lancer.STATUS.GRAPPLED and not CARD_STATUSES.has(status): return false
	var target:Unit = context.unit
	if not Unit.is_valid(target): return false
	# SHADOWED BY are_enemies BELOW AND KEPT ANYWAY: a faction is never its own enemy
	# (unit_relation.gd:361-362), so this line refuses nothing that line would not. It is documentation
	# of the card's "hostile" reading, not behaviour under test - no spec can separate it.
	if target == unit: return false
	if not target.is_character(): return false
	if not UnitRelation.are_enemies(unit, target): return false
	if not is_a_becoming(target, context): return false
	if UnitRelation.distance_between(unit, target) > unit.get_sensor_range(): return false
	return UnitRelation.can_see(unit, target)

## Did THIS application make the target Slowed or Immobilized when it was not before?
func is_a_becoming(target:Unit, context:Context) -> bool:
	var status:StringName = context.category_str
	if status == Lancer.STATUS.GRAPPLED: return is_the_sourced_grapple_of_a_smaller_unit(target, context)
	if not CARD_STATUSES.has(status): return false
	# THE BUFF-CARRIED PATH BRINGS ITS OWN IMMUNE UNITS (see the header). apply_buff_alt fires this
	# trigger for an immune target too and instances_held() would count the buff, so without this line
	# the Breach fires on a becoming the engine never granted. Dead on the direct path, where
	# apply_status has already refused at :93-99 - and NOT dead on the zone path, which is why the
	# clause is here rather than absent: test_a_zone_carried_slowed_on_an_immune_hostile_does_not_fire
	# goes red without it (measured 2026-09-18). The source argument is the status' own source, which is
	# what lets a tech-immunity buff answer for a tech-sourced status (unit_condition.gd:519-525).
	if UnitCondition.is_immune_to_status(target, status, StringName(context.string)): return false
	return instances_held(target, status) == 1

## How many separate instances of `status` the target holds right now: listed StatusConditions plus
## buffs that carry it. See the header - at this gate both the appended StatusCondition and the
## appended buff are already in place, so exactly one means this application is the becoming.
func instances_held(target:Unit, status:StringName) -> int:
	var held := 0
	for condition:StatusCondition in target.state.statuses:
		if condition.type == status: held += 1
	held += UnitCondition.get_buffs_that_apply_status(target, status).size()
	return held

## The second of a grapple's two Grappled applications, on a target that is not the larger of the two.
##
## NO IMMUNITY CLAUSE IS NEEDED ON THIS BRANCH, and that is a measurement rather than an omission. The
## clause above (:99) exists for the BUFF-CARRIED path, which bypasses apply_status' own immunity
## refusal - and no shipped buff carries Grappled. Both of the engine's Grappled applications go
## through UnitCondition.apply_status (katamari.gd:313, onhit_grapple.gd:18), which returns at
## unit_condition.gd:93-99 BEFORE the append for an immune unit, so an immune target never reaches
## this gate on that path at all.
##
## IT FIRES ON THE GRAPPLER TOO, CARD-LITERALLY, AND THAT IS RULED (R2, ruling row 203). onhit_grapple
## applies Grappled to the ATTACKING unit at :17 - sourced to the victim - and to the attacked unit at
## :18, both after recalculate_largest_unit at :14. So a hostile that grabs something LARGER than
## itself is, by the engine's own definition (UnitCondition.is_immobilized, unit_condition.gd:413-418),
## Immobilized by its own grapple - and being the first of the pair to reach this gate, it is the one
## the round cap lets through. No narrowing: the card says "becomes Immobilized" and the engine says
## this is that. test_a_hostile_that_grapples_a_larger_unit_is_itself_breached pins it.
##
## An empty context.string is the UNSOURCED katamari duplicate, which names nobody and whose
## is_larger_in_grapple is still stale; skipping it is what stops one grapple reading as two becomings.
## Exactly one SOURCED Grappled listed is then the "first holding" test for this status.
##
## THE TWO CLAUSES OVERLAP, MEASURED, AND BOTH STAY. At the unsourced application the only Grappled
## listed is that same unsourced one, so `sourced` is 0 and the count clause refuses it on its own -
## deleting the string guard alone leaves this file green (2026-09-18). Deleting BOTH does redden
## test_a_grapple_of_a_larger_target_does_not_fire_the_breach, which is the positive evidence that the
## unsourced application really does reach this gate and really does read a stale is_larger_in_grapple
## there, exactly as probe claim C recorded. The string guard is kept as the clause that says WHY.
func is_the_sourced_grapple_of_a_smaller_unit(target:Unit, context:Context) -> bool:
	if context.string.is_empty(): return false
	var sourced := 0
	for condition:StatusCondition in target.state.statuses:
		if condition.type != Lancer.STATUS.GRAPPLED: continue
		if not condition.source.is_empty(): sourced += 1
	if sourced != 1: return false
	return not target.state.is_larger_in_grapple

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	var triggering:Context = context.event.context
	var target:Unit = triggering.unit
	if not Unit.is_valid(unit) or not Unit.is_valid(target) or not GearCore.is_valid(gear): return

	# PAID FIRST, AND NOTHING BELOW CAN REFUSE IT. A consuming reaction does not spend itself: the
	# engine only reaches UnitAction.spend (unit_action.gd:236-280 - :279 records the usage and :280
	# informs the UI, which are the two lines this comment's own argument rests on) through
	# Action.spend_actions
	# (action.gd:144-147), which an ActionReaction's own activate() has to call - vanilla's
	# Dismemberment does not, because its consumes_rxn is false. Without this line the point is never
	# taken AND gear.uses_this_round is never incremented, so the engine's 1/round hard limit
	# (is_under_per_round_limit, unit_action.gd:170-176) never bites and the Breach fires on every
	# qualifying application in the round. Measured 2026-09-18: four of this trait's specs go red
	# without it.
	#
	# BEFORE the damage rather than after, for two reasons. A Breach that kills its target must still
	# cost the point, and the abort guard below returns early. And the damage event is a window: any
	# reaction the damage itself provokes would otherwise be gated against an unpaid point and an
	# unrecorded round use, letting one Vauban Breach twice off one reaction. Draw Fire spends last
	# because its live guards can still refuse the draw; nothing here can.
	spend_actions(activation)

	# EXECUTED INLINE rather than queued, so the two halves of the card land in the card's order and
	# so the abort guard below can actually see a kill. queue_event would run the damage after this
	# function returns, at which point the Impaired would already be on a corpse. Teleport.move does
	# the same thing from inside an activate() (Teleport._run, teleport.gd:478-485).
	#
	# ONE SPEC PINS THIS, AND IT HAD TO BE BUILT ON PURPOSE. Swapping this line for queue_event left all
	# 18 tests of the first draft green (measured 2026-09-18): every spec there awaited the whole event
	# chain, so the queued damage had landed by the time any assertion read it, and none of them killed
	# its target - the only case where the ordering is observable, and one that needs a hostile the 1d6
	# can finish. The review added exactly that case. Re-measured 2026-09-18 with the mutation in place:
	# 19/20, and the one red is test_a_breach_that_kills_its_target_never_applies_the_impaired, on the
	# Impaired landing before the damage that kills.
	await activation.execute_event(&'event_unit_damage', {
		unit = target,
		number = Dice.roll_string(DAMAGE_DICE),
		category = Lancer.DAMAGE_TYPE.KINETIC,
		target_unit = unit, # WHO has done this - the Vauban, so the damage is attributed to it
		gear = gear,
		action = self,
	})
	if activation.abort_without_unit(target): return

	# Impaired is NOT in CARD_STATUSES, so a Breach can never chain off its own effect.
	UnitCondition.apply_status(
		activation, target,
		Lancer.STATUS.IMPAIRED, Lancer.UNTIL.END_OF_NEXT_TURN,
		gear.persistent_id
	)
