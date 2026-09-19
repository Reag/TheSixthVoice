## THE ETERNITY HAMMER'S BYSTANDER BURN (Primrose rank III, SP4 Task 2). The swing itself is Task 1's
## and is entirely declarative on action_eternity_hammer.tres; this script is the card's second
## sentence and nothing else.
##
## "On hit: hostile characters adjacent to the target must make an |Agility save| or take 2 |Burn|."
## (specs/sixth-voice/07-primrose.md, Rank III; localizations.csv gear.mw_eternity_hammer.effect)
##
## ================= WHERE THIS SITS IN THE ATTACK, AND IT IS EARLIER THAN IT READS =================
##
## ON_HIT RUNS BEFORE THE TARGET TAKES A SINGLE POINT OF THE SWING'S OWN DAMAGE. This is the one
## engine fact SP4 Task 2 adds to the tree, and it is worth stating because the card's wording ("on
## hit ... take 2 Burn") invites the opposite assumption.
##
##   event_unit_attack_declared.gd:67   await core.execute_events(unit_attacked_events)  <-- the rolls
##     -> event_unit_attack.gd:83         if roll.hit:
##     -> event_unit_attack.gd:85-87        OnHitEffect.apply_on_hits(...)               <-- WE ARE HERE
##   event_unit_attack_declared.gd:74-121  ====== ROLL DAMAGE ======
##   event_unit_attack_declared.gd:154     damage_events.append(event_unit_damage for the target)
##   event_unit_attack_declared.gd:199     await core.execute_events(damage_events)      <-- target hurt
##
## So every bystander has saved and burned while the target is still untouched; the target's three
## dice, its own flat 2 Burn, the Overkill heat (:175) and the ground damage (:192) all land after.
## Two consequences a reviewer should hold on to:
##
## - A BYSTANDER CANNOT BE SAVED BY THE TARGET DYING, because the target cannot be dead yet. The
##   attack's own kill happens two stages later, at :199.
## - THE GATHER SEES THE BOARD AS IT WAS BEFORE THE SWING LANDED. Nobody has been knocked back,
##   nothing has been destroyed out of the radius. This is the state the player was looking at when
##   they confirmed the attack, which is the reading the card wants.
##
## INLINE, NOT QUEUED - MEASURED, NOT ASSUMED (this task's J decision).
## SP3 ruling 27 established that queueing DEFERS: a queued block runs only after the activation
## returns, while execute_events interrupts and runs now (event_core.gd:77-81). The deferral is the
## load-bearing half; the two queue calls differ in ORDER, not in timing, and the engine's own doc
## comments are explicit - queue_event is DEPTH-FIRST (:83), queue_events is BREADTH-FIRST (:90).
## BOTH SHAPES WERE BUILT AND RUN HERE, and the engine's own event trace is what separated them:
##
##   inline    [ event_unit_attack ] > [ event_unit_save ] > [ event_unit_damage 2 burn ] > FIN
##   queued    [ event_unit_attack ] > [ event_unit_save ] > FIN > [ event_unit_damage 2 burn ]
##
## NEITHER OF THE TWO MEASURED SHAPES REACHES THE TARGET'S OWN DAMAGE, which is the thing worth
## knowing and the reason this was a real question: `activation` here IS the event_unit_attack, so
## queueing from on_hit lands the block on the ATTACK ROLL's block, which drains the moment that roll
## finishes and still long before :199. The Tachyon Lance's own comment - "a little bit after the
## rest of it resolves" - holds for IT because on_targeted_tiles queues onto the DECLARED attack's
## block instead. Queueing on the roll would not buy that, and there is no ordering hazard to avoid.
## Both shapes pass all of tests 9-15 identically, with the same 49 asserts.
##
## A THIRD SHAPE EXISTS AND WOULD REACH PAST THE SWING - DO NOT READ THE ABOVE AS "on_hit CANNOT".
## event_unit_attack_declared.gd:63 hands every event_unit_attack `event = core`, commented "so
## things can opt into queueing to us instead of on the individual attack roll", and Context keeps it
## as `context.event` (context.gd:35). So `activation.context.event.queue_events(...)` from here
## queues onto the DECLARED block - the same block the Tachyon Lance reaches from its earlier stage -
## and would land AFTER :199, with the target already hurt and possibly already dead. That is exactly
## the state this clause does not want: the card's bystanders are the ones standing beside the target
## when the hammer connects, not the ones still standing after it has resolved, and a burn landing
## after the kill would also break "a bystander cannot be saved by the target dying" above. Named
## here, not taken.
##
## INLINE is kept on two grounds that outlive the current tests:
##
## - EACH BYSTANDER'S SAVE AND ITS OWN BURN STAY ADJACENT. The trace above shows the queued burn
##   landing only after the whole on_hit loop has returned, so with N bystanders every save in the
##   radius would roll first and every burn would land afterwards in a block - not how the sentence
##   reads, and not what a player watching three saves in a row would expect.
## - A BYSTANDER THAT DIES TO ITS BURN IS GONE BEFORE THE NEXT ITERATION BEGINS, so the Unit.is_valid
##   guard below is a real guard rather than a decoration. Queued, all the deaths happen after the
##   loop has finished walking the array.
##
## The Tachyon Lance's queue_events(..., 3) (content/gear/ha/weapons/mw_tachyon_lance/
## onhit_tachyon_lance.gd:60) is the design's cited precedent and is NOT a counter-example: it is a
## different stage (on_targeted_tiles, once per ATTACK, before any roll) and it deliberately wants to
## land "a little bit after the rest of it resolves". This effect is once per TARGET and wants the
## opposite.
##
## ============================== THE GATHER, AND WHY IT IS THIS CALL ==============================
##
## Ruling 18 is "a measured radius, widening ignored", and this is the same call shape
## ms_dazzling_wind/action_leap.gd:59-62 already uses for its own distance-1 hostile query. Vanilla's
## nearest twin is content/frames/npc/npcc_scout/rebound_scan/action_rebound_scan_scout.gd:14 -
## get_characters_within(attacked_unit, 3, false, are_enemies..., scout) - an on-hit radius measured
## from the TARGET and filtered as the ATTACKER, line for line what this needs.
##
## - unit = attacked_unit, whos_asking = attacker (unit_relation.gd:34-43, :45-65). The radius is
##   measured from the TARGET's tiles, which is what the card says; can_affect (:60) and the filter
##   are answered as the ATTACKER, which is what "hostile" means on a Primrose card. Pass only the
##   one and both questions collapse onto the same unit (:55 defaults whos_asking to unit).
## - THE TARGET EXCLUDES ITSELF WITHOUT ANY HELP FROM US. other_unit != unit is the first clause of
##   the engine's own loop (unit_relation.gd:58). An `if other == attacked_unit: continue` here would
##   be an inert line that reads as load-bearing; deliberately absent.
##   test_the_target_itself_is_not_in_the_loop is what would notice the engine ever dropping it.
## - require_los = false. The card says "adjacent", not "adjacent and visible". action_leap.gd:56-58
##   states the reasoning for its own copy of this argument and it is repeated here verbatim: at
##   distance 1 line of sight is very nearly always true anyway, which is exactly why leaving the
##   default would be a difference nobody would ever see in a test and somebody would eventually see
##   in play. NOTHING IN THE SUITE PINS IT - flipping it to true reddens nothing, because no spec
##   stages a wall between the Primrose and a bystander. Measured, recorded, left alone: the card
##   does not need the coverage and inventing a wall test to manufacture it would be measuring the
##   pathfinder, not this weapon.
## - get_characters_within FILTERS TO is_character() (unit_relation.gd:42), so the card's "hostile
##   CHARACTERS" needs nothing added - and that clause is load-bearing rather than cosmetic. A
##   deployable is entity_type OBJECT or MARKER (frame.gd:58-62), and make_agility_save
##   SHORT-CIRCUITS A NON-CHARACTER TO false - the FAILURE branch - without rolling anything
##   (unit_hasecheck.gd:47-48, "noncharacters always fail; doesn't even count as a force"). An
##   ungated loop would therefore auto-burn every hostile crate, mine and cover beside the target,
##   silently and with no save on screen. SP3's Biting Retort ruling records the same engine edge
##   from the other side. test_a_hostile_deployable_adjacent_to_the_target_is_untouched is the pin.
##   (Two different clauses do the work depending on the neighbour: a MARKER never even reaches the
##   character filter, because get_units_within excludes markers at :59 unless asked for them; an
##   OBJECT like dep_jericho_cover passes :59 and is dropped at :42. The spec uses the OBJECT, which
##   is the harder of the two.)
##   MEASURED, not merely argued (added at Task 2's review, which is when the mutation was finally
##   run): replacing this call with the underlying get_units_within(attacked_unit, RADIUS, false,
##   false, ...) - same arguments plus the include_markers default - reddens
##   test_a_hostile_deployable_adjacent_to_the_target_is_untouched and NOTHING ELSE, 14/15, with the
##   cover taking exactly the 2 Burn and 2 damage the auto-fail predicts. So the pin discriminates,
##   and it is the only thing in the suite that does.
##
## ================================= THE ATTACKER, AND THE PROXY CASE =================================
##
## context.unit, not context.unit.get_attacker(context). The engine keeps both (event_unit_attack.gd
## :37-38) and they differ only for a PROXY attacker - a thrown weapon or a Throughbolt round, which
## is a MARKER unit standing in for its owner. This profile can produce neither: it carries no THROWN
## tag (action_eternity_hammer.tres tags = [overkill]), so get_alternate_actions never builds a throw
## for it, and no Primrose gear makes a proxy swing. If either ever becomes possible, this is the
## line to revisit - "hostile" and the Burn's credited source would both be answered by the round
## rather than by the pilot.
##
## ================================= apply_on IS NOT WHAT GATES THIS =================================
##
## onhit_eternity_hammer.tres sets apply_on = STAGE.ON_HIT, which is the export default
## (on_hit_effect.gd:12) and is the honest declaration of intent - but it does NOT dispatch this
## override, and a reviewer should not read it as though it does. apply_on_hits calls
## effect.on_hit(...) for every effect in the array whatever its apply_on says (on_hit_effect.gd
## :42-46); apply_on is consulted only inside should_abort's consume-lock and save_to_avoid gates
## (:57-72) and inside apply_statuses_and_buffs (:77), and this effect uses none of the three.
## MEASURED: setting apply_on = 0 (ON_ATTACK) on the .tres reddens nothing at all.
## The one thing should_abort DOES do for us unconditionally is its own validity bail at :55 - it
## returns true, skipping on_hit entirely, when the attacked unit or the attacker is already invalid.
## That is a genuine gate, just not an apply_on one; the guard at the top of on_hit below is the
## belt-and-braces copy, because nothing promises apply_on_hits stays the only caller.
## What actually confines the burn to a hit is the engine's own `if roll.hit:` at
## event_unit_attack.gd:83 - and THAT is what test_a_miss_burns_nobody pins.
extends OnHitEffect

## The card's numbers. 2 Burn, and "adjacent" is distance 1.
const BURN:int = 2
const RADIUS:int = 1

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	var context := activation.context
	var attacker:Unit = context.unit
	if not Unit.is_valid(attacker) or not Unit.is_valid(attacked_unit): return

	# The save needs a forcing action to attribute itself to; SpecificAction.is_valid is the same
	# guard action_annihilator.gd:11-12 and action_leap.gd take before using one.
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return

	var hostiles:Array[Unit] = UnitRelation.get_characters_within(
		attacked_unit, RADIUS, false,
		func(other:Unit) -> bool: return UnitRelation.are_enemies(attacker, other),
		attacker,
	)

	for bystander:Unit in hostiles:
		# REAL GUARDS, NOT DECORATION, precisely because the burn is dealt inline: a bystander that
		# dies to its own Burn is destroyed before the next iteration starts, and the array we are
		# walking was gathered before any of it happened. BURN DEALS HP AS WELL AS A STACK -
		# event_unit_damage.gd:119 calls damage() unconditionally and :121-122 adds unit.state.burn on
		# top, the two are not alternatives (Task 1 measured the same thing on the Hammer's own flat
		# 2) - so a death mid-loop is not hypothetical.
		#
		# ALL THREE OF UnitHasecheck.make_saves' OWN RE-CHECKS ARE MIRRORED, which is more than the
		# obvious two: :66 re-runs Unit.is_valid(unit) AND SpecificAction.is_valid(forcing_action)
		# every lap, and :68 re-runs the unit check after the save. (The engine `continue`s on the
		# forcing action because it still has a results dictionary to finish; we have nothing left to
		# do, and no later lap could succeed either, so this one returns.)
		#
		# THE FORCING-ACTION RE-CHECK IS ALSO THE ATTACKER RE-CHECK, which is why no separate one sits
		# at the tail. SpecificAction.is_valid tests specific.unit - and from_context built it from
		# context.unit, the attacker (specific_action.gd:16-22, :46-48) - along with its gear and
		# action, so a Primrose killed by a mirrored or reflected burn on the previous lap stops the
		# loop here. Checking at the TOP rather than after the damage is the difference that matters:
		# a tail guard on the damage branch alone is skipped whenever a save PASSES, so the same death
		# would go unnoticed for one extra lap.
		if not Unit.is_valid(bystander): continue
		if not SpecificAction.is_valid(specific): return
		var passed:bool = await UnitHasecheck.make_agility_save(activation, bystander, specific)
		if not Unit.is_valid(bystander): continue
		if passed: continue

		# NEITHER `gear` NOR `action` IS PASSED, AND THAT IS A DECISION, NOT AN OMISSION (settled at
		# the SP4 whole-branch review, which asked why action_spin.gd:270-278 passes both and this
		# does not). The two are different events and the asymmetry is correct:
		#
		#   - `action` MUST NOT BE PASSED. context.action here is action_eternity_hammer, an
		#     ActionAttackWeapon, and buff_resist_damage.gd:47-54 branches on exactly that:
		#     `if context.action and context.action is ActionAttackWeapon` then matches
		#     weapon_sizes / weapon_types. Passing it would let a bystander's "resist SUPERHEAVY" or
		#     "resist melee" buff reduce a splash Burn that is not an attack on that bystander at
		#     all - it has no roll, no cover and no accuracy, only the save the card gives it. Spin
		#     can pass its action safely because a Spin's action is an ActionSystem, so that branch
		#     never opens.
		#   - `gear` WITHOUT `action` REACHES NOTHING. buff_damage.gd:19 refuses any context whose
		#     SpecificAction.from_context is not fully valid, which needs unit + gear + action
		#     together; event_unit_damage.gd names gear only once, at :36, in the optional-prop list
		#     ("for reactions to inspect"), and reads it nowhere in its body. So the half of the
		#     review's finding about BATTLE-LOG ATTRIBUTION is not true of this engine: the log
		#     lines at event_unit_damage.gd:112 and :159-169 are built from the unit and the damage
		#     numbers and never touch context.gear. A gear passed here would be the inert line this
		#     mod treats as a defect.
		#
		# VANILLA'S OWN STRUCTURAL TWIN AGREES. onhit_tachyon_lance.gd:35-48 is the same shape - an
		# on-hit, save-or-Burn splash on units the weapon never attacked - and passes unit, number,
		# category, target_unit and flags, exactly these five and no more.
		await activation.execute_events([EventCore.create(&'event_unit_damage', {
			unit = bystander,
			number = BURN,
			category = Lancer.DAMAGE_TYPE.BURN,
			target_unit = attacker, # let the damage event know WHO has done this
			flags = [EventService.DAMAGE_FLAG.SAVE_FAILED],
		})])
