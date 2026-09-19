## BITING RETORT, the riposte: the half of the card that can only be decided after the roll.
##
##   "If the attack misses, the attacker takes 3 |AP| |Kinetic| damage and must succeed a |Hull save|
##    or be knocked |Prone|."
##
## THE FIRST HALF IS action_biting_retort.gd, one file over, and it is a reaction at ATTACK **PRE**
## because the +1 Difficulty has to be on the defender before AttackRoll.create
## (event_unit_attack.gd:31-32, then :53). This half cannot live there: when that activate() returns,
## the roll it just modified does not exist yet. So something has to be listening at ATTACK **POST**,
## and THIS FILE IS THAT LISTENER - a hidden buff the reaction arms on its way out.
##
## ========================= WHY IT IS NOT until = FINISH_ATTACK_ROLL =========================
##
## READ THIS BEFORE "SIMPLIFYING" THE LIFETIME BELOW. The obvious lifetime for an observer that must
## expire with the roll is Lancer.UNTIL.FINISH_ATTACK_ROLL, and the design (§3.1) specified exactly
## that. IT FIRES ZERO TIMES. event_unit_attack.gd ends its execute() in this order:
##
##     :120   UnitCondition.clear_buffs_until(core, clear_unit, Lancer.UNTIL.FINISH_ATTACK_ROLL)
##     :123   core.queue_reaction_events(ReactionBus.TRIGGER.ATTACK, ReactionBus.TIMING.POST)
##
## clear_buffs_until -> clear_buffs -> clear_buff ERASES the BuffCore from unit.state.buffs
## synchronously (unit_condition.gd:1010-1013 -> :952-965 -> :967-990, the erase at :980), and
## ReactionBus.trigger_occurred polls unit.state.buffs at QUEUE time (reaction_bus.gd:61-67). The
## observer is gone ONE LINE before anything asks it whether it wants to fire.
##
## THIS IS MEASURED, NOT REASONED. SP3 Task 0's probe (ruling 25, commit b9f3047) ran the design's
## buff and counted ZERO activations, then hung a second until = MANUAL witness inside
## does_buff_trigger at ATTACK POST and recorded that the observer was ALREADY ABSENT from
## unit.state.buffs at that exact moment. A reader who changes `until` back to 8 will get a card that
## does nothing, with no error, no warning and no log line.
##
## ONE LINE IN THE .tres BESIDE THIS IS NOT LOAD-BEARING, SAID OUT LOUD SO NOBODY TESTS IT AND IS
## PUZZLED: `trigger_timing = 1` is already the export default (buff.gd:139,
## `@export var trigger_timing:ReactionBus.TIMING = ReactionBus.TIMING.POST`). It is written anyway,
## because `until = 2` directly above it IS load-bearing and the pair only reads correctly together -
## and because buff_uncertainty_field_break.tres, this mod's other triggered buff, spells it out for
## the same reason. `until` is the line to look at; changing it silently kills the card.
##
## SO THE LIFETIME IS END_OF_THIS_TURN (= 2, counted off lancer.gd:46-56), which outlives :120 - and
## the self-clear below, not the lifetime, is what ends it. END_OF_THIS_TURN is only the net: it
## clears at the end of the very next turn on ANY unit (BuffCore.turn_count starts at 0,
## buff_core.gd:7; end_turn_for_statuses runs over every unit, unit_condition.gd:33-42), so it is a
## one-turn backstop and a leaked observer still fires freely WITHIN the turn.
##
## ========================= THE SELF-CLEAR IS LOAD-BEARING, AND IT IS FIRST =========================
##
## Task 0 P3e measured the leak directly: with the clear removed, ONE accepted reaction riposted TWO
## swings in the same turn, and the second was not re-armed by anything - the reaction point was
## already spent, so the PRE half was never even offered again. An observer that survives its own roll
## ripostes every further attack in the turn, for free.
##
## IT IS THE EXPLICIT CALL, PLACED FIRST, and not a trailing super(). Buff.activate's default body IS
## `UnitCondition.clear_buff(activation, activation.context.unit, core)` (buff.gd:254-255) and the
## probe measured that a trailing super() clears just as well - but every early return below it (a hit,
## a dead attacker, missing gear) would skip it, which is the one shape that leaves a second riposte
## armed. Clearing first costs nothing: the BuffCore is erased from unit.state.buffs, and this
## function keeps running from its own locals.
##
## AND triggers_on_event DELIBERATELY DOES NOT GATE ON roll.hit. A landed attack is not a riposte, but
## it still has to give this buff an activation to clean itself up in; the `if roll.hit: return` below
## is what makes the hit path a no-op, one line AFTER the clear.
##
## CANDIDATE B WAS REJECTED FOR EXACTLY THIS. Task 0 also built the alternative - a second
## ActionReactionAttacked at POST with require_miss and consumes_rxn = false, gated on a marker the PRE
## half writes on the gear. It works, but consumes_rxn = false makes its per-round hard limit 99
## (action_reaction.gd:69) and short-circuits is_available_to_activate (:51), so the marker is the ONLY
## gate - and require_miss means a HIT gives it nowhere to disarm itself, leaving the marker set and
## every later hostile melee miss worth a free riposte (probe P4c, P4d). Two moving parts where this is
## one, and the failure mode this one cannot have.
##
## ========================= THE DAMAGE IS AWAITED INLINE, NOT QUEUED =========================
##
## activation.queue_event is DEPTH-FIRST and runs after activate() returns (event_core.gd:83-88),
## while UnitHasecheck.run_save_event executes its save event IMMEDIATELY (unit_hasecheck.gd:74-89 ->
## EventCore.execute_events). So queueing the damage would put the SAVE first and the damage second -
## the reverse of the card, which reads "takes 3 AP Kinetic damage AND must succeed a Hull save" - and
## would roll that save on an attacker about to die. Awaiting it inline gets both: the card's order,
## and a Unit.is_valid guard that can actually see a kill.
##
## Two specs pin it. test_the_damage_lands_before_the_save_is_forced reads the attacker's own
## current_damage() from inside the save's buff pass and finds it already at 3;
## test_a_riposte_that_kills_the_attacker_forces_no_save finishes a 1 HP attacker and asserts no save
## was forced at all. This mod's own action_solfataric_breach.gd:195-208 made the identical call for
## the identical reason, and recorded the same mutation.
##
## THE DAMAGE EVENT CARRIES NO `action` AND NO `gear`, deliberately. vanilla Brace reacts at DAMAGE PRE
## and its get_required_triggering_context demands Context.PROP.action while its triggers_on_event
## demands `action is ActionAttack` (content/gear/basic/ms_brace/action_brace.gd:5-21) - so naming this
## activation on the event would be the difference between a riposte and a riposte the attacker can
## brace. A riposte is not an attack; it has no roll, no accuracy and no weapon. target_unit is set so
## the Primrose still gets the credit, which is what action_grav_amped_shock.gd:144-150 does for this
## frame's other flat 3 AP kinetic.
##
## ========================= THE SAVE, AND WHO IS ALLOWED TO BE MADE TO TAKE ONE =========================
##
## THE FULL TRIFECTA IS NOT OPTIONAL, and what it costs to get it wrong was MEASURED at Task 3's
## mutation step, not reasoned. UnitHasecheck.run_save_event copies forcing_action.unit / .gear /
## .action onto the save EVENT unconditionally (:78-85), and event_unit_save.gd:54 then rebuilds a
## SpecificAction out of that context and hands it down - so a bare-unit call passes
## SpecificAction.is_valid nowhere and the rebuild comes back invalid. Two things follow, and they are
## different:
##   - The save STILL HAPPENS and still uses the Primrose's own save target, because
##     event_unit_save.gd:41-43 reads context.unit directly rather than through the SpecificAction.
##     (Measured: the rolled line reads "against 10" either way.) So nothing about the odds changes and
##     nothing looks broken.
##   - But unit_hasecheck.gd:176-184 builds the SAVER'S buff context with target_unit, category, array
##     and flags, and only then, gated on SpecificAction.is_valid at :180, copies unit AND gear AND
##     action onto it as ONE BLOCK. So every buff on the attacker that keys on "a save the Primrose
##     forced" loses not just the gear and the action but the FORCING UNIT TOO. And the player-facing
##     battle-log row degrades from "failed a Hull save from Player XX [Biting Retort]" to
##     "failed a Hull save from ?".
## Hence SpecificAction.create(unit, gear, gear.kit.get_action(...)) - unit AND gear AND action
## (specific_action.gd:16-23). spec/test_biting_retort.gd's
## test_a_missed_attack_forces_a_hull_save_the_saver_can_attribute is the pin, and it reads that
## context from inside the saver's own buff pass, which is the only channel that sees all four facets.
##
## THE ACTION IS THIS REACTION, NOT THE FALCATA'S SWING. gear.kit.get_action(action_id) matches on
## Action.get_id() (kit.gd:117-122); get_solo_action() would hand back actions[0], the attack profile.
##
## AND THE SAVE IS GATED ON is_character(), WHERE THE DAMAGE IS NOT. UnitHasecheck.make_hull_save
## short-circuits a non-character to FALSE without rolling anything (:52-53, "noncharacters always
## fail; doesn't even count as a force") - and false is the FAILURE branch, so an ungated riposte would
## automatically Prone any hostile deployable, object or turret that swung and missed.
## ActionReactionAttacked gates the DEFENDER on is_character (require_defender_to_be_character,
## action_reaction_attacked.gd:95) and never the ATTACKER, so that state is reachable in play. The
## damage stays unconditional, because the card says the attacker takes it and a deployable taking a
## hit needs no save rules to work.
##
## ========================= HIDDEN, AND WHY THAT NEEDS NO ICON ROW =========================
##
## hide_from_player, so this leaves no chip on the token: it exists for a fraction of one event, and
## the player has already been told what they accepted by the reaction's own confirm. Unlike
## buff_biting_retort_difficulty it is NOT in test_content_integrity.gd's HIDDEN_BUFFS_NEEDING_ICONS,
## and that is the right answer rather than an omission - that list exists for buffs something OTHER
## than the status bar draws, and `to` is left at its default &'none', so no roll breakdown, no
## tooltip and no card ever reaches for an icon here.
##
## ========================= ONE RESIDUAL RISK, STATED =========================
##
## If a roll's ATTACK POST is never reached at all - the attack aborts between :53 and :123 - this buff
## is left armed and would riposte the next attack on the Primrose IN THE SAME TURN. The
## END_OF_THIS_TURN sweep is the backstop, and
## spec/test_biting_retort.gd's test_the_observer_is_gone_after_a_landed_roll /
## ..._after_a_missed_roll are what would catch a regression in the self-clear itself. No case in the
## suite currently reaches that abort.
extends Buff

## "3 AP Kinetic damage" - flat, so no die is drawn and nothing is taken out of Dice.CHEAT_ROLL_QUEUE.
const RIPOSTE_DAMAGE:int = 3
## The action the save is attributed to: the reaction, not the Falcata's swing. See the header.
const RETORT_ACTION:StringName = &'action_biting_retort'

## DELIBERATELY EMPTY, buff_uncertainty_field_break.gd's reasoning: a required prop is re-checked at
## EXECUTION time as well as at collection time, and everything read below is read defensively.
## Requiring Context.PROP.object here would abort exactly the activations this buff exists for.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit): return false
	var context:Context = triggering_event.context
	# WE were the one attacked. The bus polls every unit's buffs on every trigger with the same event
	# (reaction_bus.gd:46-67), so without this line the Primrose would riposte attacks on other people.
	if context.target_unit != unit: return false
	# HIT OR MISS ALIKE - see the header. The hit path is where this buff cleans itself up.
	return AttackRoll.is_valid(context.object)

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	# FIRST, BEFORE ANY EARLY RETURN BELOW IT CAN SKIP IT. See the header: this is the whole of what
	# keeps one accepted reaction to one riposte.
	UnitCondition.clear_buff(activation, unit, core)

	var context:Context = activation.context.event.context
	if not AttackRoll.is_valid(context.object): return
	var roll:AttackRoll = context.object
	if roll.hit: return # "if the attack MISSES" - a landed blow costs the attacker nothing
	if not Unit.is_valid(unit): return

	# The same accessor event_unit_attack.gd:38 uses, and Task 0's probe asserted the Unit it returns
	# at POST is identically the attacker.
	if not Unit.is_valid(context.unit): return
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(attacker): return
	# The Falcata, stamped on this buff by apply_buff_id's `event.context.gear` (action.gd:375-376).
	# Needed for the save's trifecta and for the Prone's source id.
	var gear:GearCore = core.get_owner_gear(activation.context.map)
	if not GearCore.is_valid(gear): return

	await activation.execute_event(&'event_unit_damage', {
		unit = attacker,
		number = RIPOSTE_DAMAGE,
		category = Lancer.DAMAGE_TYPE.KINETIC,
		flags = [EventService.DAMAGE_FLAG.AP],
		target_unit = unit, # who gets the credit: the Primrose
	})
	# The kill guard the inline await buys us. Plain Unit.is_valid rather than
	# activation.abort_without_unit: the riposte's own work is finished either way, and marking the
	# whole POST activation aborted would poison any sibling event on the same block.
	if not Unit.is_valid(attacker): return
	if not attacker.is_character(): return # see the header: a forced save auto-FAILS for one
	if not Unit.is_valid(unit): return

	var specific := SpecificAction.create(unit, gear, gear.kit.get_action(RETORT_ACTION))
	var passed:bool = await UnitHasecheck.make_hull_save(
		activation, attacker, specific, [Lancer.STATUS.PRONE]
	)
	if not Unit.is_valid(attacker): return
	if passed: return
	UnitCondition.apply_status(
		activation, attacker, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, gear.persistent_id
	)
