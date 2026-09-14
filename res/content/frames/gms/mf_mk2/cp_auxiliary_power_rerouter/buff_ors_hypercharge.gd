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
## RULING 7 FALLS OUT OF THE TRIGGER, it is not enforced here. UNIT_ACTION POST fires exactly once per
## gear activation that moved its usage counter, so a Blast pays one 1d3, a two-weapon Skirmish pays
## twice, and an Overwatch or a freebie pays too - the ROUND counter is incremented even for
## AS_FREEBIE (gear_core.gd:170-178). An ABORTED activation never fires the POST at all
## (event_gear_activate.gd:100-104 gates it on pre_activate_uses having actually moved), so it neither
## heats nor reloads.
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
## THE HEAT IS ATTRIBUTED TO THE CORE SYSTEM, NOT TO THE WEAPON, so the battle log and any
## damage-source inspection name the ability the player chose rather than the gun.
## UnitAction.gain_self_heat_alt queues event_unit_damage HEAT with SELF_INFLICTED and
## SKIP_CONSUMING_RESIST_BUFFS (unit_action.gd:297-307), the same path every self-heat weapon takes -
## so a weapon fired at heat cap still pays and can push the M/K2 into stress, which is the card.
##
## Dice.roll_d3 goes through roll_and_sum -> roll_dice (dice.gd:93, :22-38), so CHEAT_ROLL_QUEUE fixes
## it in specs.
##
## activate() DOES NOT CALL super(): the default (buff.gd:254-255) clears the buff, and this one lasts
## the scene.
extends Buff

## Restores the guarantee triggers_on_event below relies on: without it,
## Buff.check_required_triggering_context lets this buff be evaluated against trigger events carrying
## no unit at all, and the holder comparison would be made against a null context.unit instead of
## refusing cleanly. Same reasoning, and the same list, as buff_rapid_stabilization_jets.gd:47-48.
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

	fired.gear.is_loaded = true

	var core_gear:GearCore = core.get_owner_gear(unit.map)
	if not GearCore.is_valid(core_gear): return
	# The PROTOCOL action, not null. SpecificAction.create is happy to hold a null action
	# (specific_action.gd:32-37), but gain_self_heat_alt copies specific.action straight into the
	# event_unit_damage context (unit_action.gd:306), and the damage log reads it - so naming the
	# action the player actually pressed is both safer and the better attribution.
	UnitAction.gain_self_heat_alt(
		Dice.roll_d3(),
		SpecificAction.create(unit, core_gear, core_gear.get_action(&'action_ors_hypercharge')),
		activation)
