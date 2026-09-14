## O.R.S HYPERCHARGE, the scene-long effect: after every firing of a Loading weapon, put the weapon's
## is_loaded flag straight back and charge 1d3 heat.
##
## THE ORDERING IS WHY THE PLAYER NEVER SEES AN EMPTY WEAPON. is_loaded drops inside the attack
## action's own spend_actions, during activate() (unit_action.gd:276); the attack's roll and damage
## events are queued as that activation's children; the UNIT_ACTION POST reaction is queued after them
## (event_gear_activate.gd:111) and runs last. Between the drop and this restore nothing reads the
## flag - so the gear bar never greys the weapon, Stabilize never offers a Reload for it
## (UnitAction.get_unloaded_weapons, unit_action.gd:411-416), and it fires again next action.
##
## RULING 7 FALLS OUT OF THE TRIGGER, it is not enforced here. UNIT_ACTION POST is queued exactly once
## per gear activation that moved its usage counter (event_gear_activate.gd:110-111, gated at
## :100-104 on pre_activate_uses having actually changed), so the cardinality of the heat is the
## cardinality of the activation, whatever the attack did inside it.
##
## WHICH HALVES OF THAT ARE MEASURED, AND WHICH ARE READ OFF THE ENGINE. The distinction matters:
## only the measured ones would go red if this stopped being true.
##
## - MEASURED, in spec/test_ors_hypercharge.gd:
##   - two separate activations pay two separate 1d3s, at the value each one ROLLED
##     (test_two_loading_shots_pay_twice);
##   - a FREEBIE activation pays its own (test_a_freebie_shot_pays_the_heat_too) - which is the claim
##     gear_core.gd:175-176 carries, incrementing uses_this_round unconditionally and gating only the
##     per-TURN counter on the freebie flag;
##   - an activation that ABORTS mid-flight pays nothing, and its round counter proves it aborted
##     rather than merely finding a dead buff (test_an_aborted_activation_neither_heats_nor_reloads);
##   - an activation the engine REFUSES up front does not reload the weapon behind its back
##     (test_a_refused_activation_does_not_reload_the_weapon).
## - ENGINE-DERIVED, asserted by nothing here: that a Blast pays ONE 1d3 however many targets it
##   sweeps, and that an Overwatch or a Skirmish followup pays as any other activation does. Both
##   follow from the same gate - the POST is queued on the ACTIVATION at event_gear_activate.gd:111,
##   after all of the attack's own per-target work, and a reaction is itself an event_gear_activate
##   (reaction_bus.gd:54-59). Staging a Skirmish followup or an Overwatch in a spec costs a mounted
##   loadout and an enemy movement respectively, and neither would be testing THIS file. Treat them
##   as reasoning, not as coverage.
##
## THE WEAPON IS READ OFF THE TRIGGERING EVENT, NOT OFF THIS ACTIVATION'S OWN CONTEXT. A reacting
## buff runs as event_buff_activate, whose context carries only `buff`, `unit` (the HOLDER) and
## `event` (content/events/event_buff_activate.gd:7-11) - there is no `gear` on it at all, and
## `activation.context.gear` would be null every single time. The gun lives on the virtual
## event_unit_action core hanging off `event`, which event_gear_activate.create_virtual_event_unit_action
## builds with the real gear and action attached "for internal usage" (event_gear_activate.gd:128-130).
## triggers_on_event is handed that same virtual core directly, which is why the two halves of this
## file reach the weapon by different routes.
##
## THE HEAT IS ATTRIBUTED TO THE CORE SYSTEM, NOT TO THE WEAPON, so anything inspecting the damage
## finds the ability the player chose rather than the gun.
## UnitAction.gain_self_heat_alt queues event_unit_damage HEAT with SELF_INFLICTED and
## SKIP_CONSUMING_RESIST_BUFFS (unit_action.gd:297-307), the same path every self-heat weapon takes -
## so a weapon fired at heat cap still pays and can push the M/K2 into stress, which is the card.
## The attribution rides on gain_self_heat_alt copying specific.gear and specific.action straight into
## that damage context (unit_action.gd:305-306), which is why the SpecificAction below is built by
## hand rather than taken from the activation - see the comment at the call itself. Asserted by
## test_the_heat_is_attributed_to_the_core_system_not_the_weapon, which reads the gear and action off
## the damage event through a spy buff; without it the tidy-up to SpecificAction.from_context() would
## rename the damage source and leave every other test in the file green.
## What it does NOT buy is a named source in the battle log: the heat line is
## event.unit_damage.heated_self.log, which formats an amount and an icon and nothing else
## (event_unit_damage.gd:108-115).
##
## Dice.roll_d3 goes through roll_and_sum -> roll_dice (dice.gd:93, :22-38), so CHEAT_ROLL_QUEUE fixes
## it in specs.
##
## activate() DOES NOT CALL super(): the default (buff.gd:254-255) clears the buff, and this one lasts
## the scene.
extends Buff

## [Context.PROP.unit], for the reason recorded ONCE at buff_rapid_stabilization_jets.gd:64-79. All
## three of the frame's reacting buffs declare this and none of the other two restate why.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

## Was this OUR firing of a Loading weapon?
##
## THE HOLDER CHECK IS NOT DEFENCE IN DEPTH HERE - it is load-bearing.
## reaction_bus.trigger_occurred polls EVERY unit's buffs on every trigger (reaction_bus.gd:50,
## :61-62) and hands each of them the SAME triggering event, so without the first line this buff would
## reload an ENEMY's rifle and charge US the heat for it. Measured, not reasoned: deleting this line
## turns BOTH assertions of test_an_enemys_loading_shot_neither_heats_us_nor_reloads_them red - we
## take 3 heat for their shot and their rifle comes back loaded
## (.superpowers/sdd/task3-mutation-5-no-holder-check.log).
##
## context.action is the action the attack was declared through; a non-weapon action (a tech action, a
## protocol, this very core power) casts to null and is refused. has_tag is asked WITH the context
## rather than bare so a weapon that is Loading only because of a mod or a buff still counts
## (action_attack_weapon.gd:161-172 reads both off the specific/context).
func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.unit != unit: return false
	if not GearCore.is_valid(context.gear): return false
	var weapon:ActionAttackWeapon = context.action as ActionAttackWeapon
	if weapon == null: return false
	return weapon.has_tag(Lancer.WEAPON_TAG.LOADING, context)

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	# Checked with a plain null test, not an EventCore.is_valid() - EventCore has no such static
	# (engine/event/event_core.gd declares none). event_buff_activate.get_required_context already
	# demands PROP.event, so this only covers the impossible case.
	var triggering:EventCore = activation.context.event
	if triggering == null: return
	var fired:Context = triggering.context
	if not GearCore.is_valid(fired.gear): return

	# INTACTNESS, ASKED THE SAME WAY THE PROTOCOL ASKS IT (action_ors_hypercharge.gd:25). A destroyed
	# weapon is wreckage, not a readied gun, and the two halves of one ability must not hand the next
	# author two different rulings on one question.
	#
	# NOTHING PLAYER-VISIBLE TURNS ON IT, and the comment is here so nobody "simplifies" it back out
	# believing it was load-bearing: unit_action.gd:149 refuses a destroyed weapon with
	# REASON.DESTROYED two lines before :151 ever looks at is_loaded, so a wrecked gun is unusable
	# whatever this flag says. The check makes the ruling legible; it fixes no bug.
	#
	# IT GUARDS ONLY THE RELOAD, NOT THE HEAT. The card charges "each time you fire a Loading weapon",
	# and a shot that went off and then lost its gun was still fired - so the d3 below is unconditional
	# and an early return here would be a behaviour change this file has no mandate for.
	if fired.gear.is_intact(): fired.gear.is_loaded = true

	var core_gear:GearCore = core.get_owner_gear(unit.map)
	if not GearCore.is_valid(core_gear): return
	# BUILT BY HAND, AND NOT SpecificAction.from_context(activation.context). This is the whole of the
	# attribution: gain_self_heat_alt copies specific.gear and specific.action straight into the
	# event_unit_damage context (unit_action.gd:305-306), and that context is what anything asking
	# what caused the heat reads. Taking the SpecificAction off the activation instead looks
	# equivalent and is not - a reacting buff runs as event_buff_activate, whose context carries no
	# gear and no action at all (content/events/event_buff_activate.gd:7-11), so the damage would
	# arrive anonymous with the number unchanged. Measured: that substitution turns
	# test_the_heat_is_attributed_to_the_core_system_not_the_weapon red on both of its assertions
	# (empty gear id, empty action id) and leaves the other 15 tests in the file green
	# (.superpowers/sdd/mk2-sp1-task3-mutation-attribution.log).
	# The PROTOCOL action, not null: SpecificAction.create is happy to hold one
	# (specific_action.gd:32-37), and naming the thing the player actually pressed is the better
	# attribution as well as the safer value.
	UnitAction.gain_self_heat_alt(
		Dice.roll_d3(),
		SpecificAction.create(unit, core_gear, core_gear.get_action(&'action_ors_hypercharge')),
		activation)
