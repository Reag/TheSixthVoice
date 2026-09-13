## HEAER: the destroying hit that makes the body explode. SP2 Task 4, design §3.2, ruling 6.
##
## "Whenever you destroy a hostile character with a rifle, launcher, or cannon you may expend a
##  charge to make them explode violently. All characters within burst 1 of the destroyed character
##  must make an Agility save or take 1d6+1 AP kinetic damage."
##
## THERE IS NO KILL TRIGGER. ReactionBus.TRIGGER carries DEATH, but a DEATH reaction is a whole event
## too late: by then the body is off the map and the attack that did it is out of hand. The seam is
## DAMAGE **POST**, and the ordering inside event_unit_damage.gd's execute() is the entire reason
## this ability is expressible at all:
##
##     ... applies the damage to health ...
##     core.queue_reaction_events(TRIGGER.DAMAGE, TIMING.POST)   <- we run here
##     queue_structure_or_stress_if_necessary(core, unit)        <- structure is spent AFTER us
##
## So when this reaction is asked whether it triggers, the victim's health is already at or below 0
## and its structure has NOT yet been decremented - which is exactly the information ruling 6 needs,
## and which is unavailable anywhere else in the chain. See was_destroyed_by_this_damage() below.
##
## EXTENDS ActionReaction, NOT ActionReactionSelf, and the plan's naming of the latter was a slip.
## ActionReactionSelf's whole body is a gate that the triggering event's `unit` is us - and on a
## DAMAGE event `context.unit` is the VICTIM (event_unit_damage.gd:21-37), so inheriting it would
## make HEAER fire only when the Fitzgerald itself is shot. The Vorpal Gun's action_snicker_snack.gd
## extends ActionReaction for precisely this reason, and it is the worked precedent for reading this
## context.
extends ActionReaction

## The three weapon types the card names. Read off the ACTION the damage context carries, never off
## the gear: a multi-profile Kit (the Fitzgerald's own Swivel Gun, for one) has a different
## weapon_type per profile, so "what did the gear fire" is not a question the gear can answer.
const TRIGGERING_WEAPON_TYPES:Array[Lancer.WEAPON_TYPE] = [
	Lancer.WEAPON_TYPE.RIFLE,
	Lancer.WEAPON_TYPE.LAUNCHER,
	Lancer.WEAPON_TYPE.CANNON,
]

const BLAST_RADIUS := 1
const BLAST_DAMAGE_DICE := '1d6+1'

## Bookkeeping, not a rule the player reads twice: the system's own effect row says everything there
## is to say, and a reaction never reaches the gear bar anyway (gear_bar.gd drops every
## ActionReaction). show_in_tooltip is a FUNCTION on Action (action.gd:341), not an exported
## property, so this is the only way to set it - same as mt_blasting_powder's spend reaction.
func show_in_tooltip(kit:Kit) -> bool: return false

## DELIBERATELY EMPTY, overriding ActionReaction's own empty default only to say so out loud (design
## §3.2). A required triggering prop is re-checked at execution time, not just at collection time
## (event_gear_activate.gd:37), and the one prop this reaction cares about most - the victim - is
## exactly the thing that may have stopped being a valid Unit by then. Requiring it would abort the
## activation precisely in the case the ability exists for.
func get_required_triggering_context() -> Array[Context.PROP]:
	return []

# ---------------------------------------------------------------- the gate

## The five conditions, in the order design §3.2 states them. Any one of them failing is a silent
## no-trigger; none of them is allowed to throw, because this runs for every unit's every gear on
## every damage event in the game.
##
## Note what is NOT here: a charge check. UnitAction.can_activate_gear runs ahead of
## triggers_on_event inside ReactionBus.does_reaction_trigger (reaction_bus.gd:119-124) and already
## answers REASON.NO_CHARGES for an empty system (unit_action.gd:153), because consumes_charges()
## defaults to true and activate() below really does spend one. has_charges_left() is asserted here
## anyway, as the belt to that brace: it costs nothing, and it keeps the five conditions readable as
## the five the design names.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return false
	var context:Context = triggering_event.context

	# 1. WE fired the shot. context.target_unit on a damage event is the unit that dealt it
	#    (event_unit_damage.gd:35). Compared strictly, not through get_attacker(): "whenever YOU
	#    destroy" is about this mech's own gun, so a drone or deployable of ours that kills something
	#    does not set the Fitzgerald's shells off.
	if context.target_unit != unit: return false

	# 2. with a rifle, launcher or cannon.
	if not (context.action is ActionAttackWeapon): return false
	var weapon:ActionAttackWeapon = context.action
	if not TRIGGERING_WEAPON_TYPES.any(
		func(check:Lancer.WEAPON_TYPE) -> bool: return weapon.is_weapon_type(check, context.gear)
	): return false

	# 3. the victim is a hostile character.
	#
	#    OR A DEPLOYABLE - and that is a deliberate widening of the plan's bare is_character(), which
	#    would have contradicted both ruling 6 ("an object or structureless character reaches 0 HP")
	#    and design §3.2's own required spec, "a destroyed deployable counts". is_deployable() rather
	#    than is_object() keeps wrecks, scenery, markers and the engine's own
	#    dep_attack_ground_proxy (an OBJECT with is_deployable false, spawned whenever a non-AOE shot
	#    is aimed at bare ground) from setting the system off.
	var victim:Unit = context.unit
	if not Unit.is_valid(victim): return false
	if not (victim.is_character() or victim.is_deployable()): return false
	if not UnitRelation.are_enemies(unit, victim): return false

	# 4. and this damage destroyed it.
	if not was_destroyed_by_this_damage(victim): return false

	# 5. and there is a charge to spend.
	if not gear.has_charges_left(): return false

	capture_victim(gear, victim)
	return true

## Ruling 6, read against the event ordering in this file's header.
##
## A MECH is destroyed by damage when it is driven to 0 HP on its LAST structure: event_unit_structure
## decrements structure (:41) and kills at 0 (:53). Since that event has not run yet when we are
## asked, "its last structure" is `current.structure <= 1`.
##
## ANYTHING ELSE - a structureless character, an object, a deployable - has no structure event at
## all: EventUnitDamage.queue_structure_or_stress_if_necessary sends every non-mech straight to
## event_unit_die at 0 HP. So health is the whole question.
##
## TWO KNOWN DEPARTURES, BOTH DELIBERATE, NEITHER IN SCOPE (design §3.2):
##
##  - A mech with more than one structure left can still die from a bad structure CHECK
##    (OUTCOME.DIE / HULL_CHECK_OR_DIE, event_unit_structure.gd:56-66). Ruling 6 says "loses its last
##    structure", so this does not fire on that path and must not try to: the outcome is rolled
##    inside an event that has not been queued yet, and there is nothing here to read.
##  - The mirror case: a victim carrying a SURVIVES_AT_ZERO_STRUCTURE buff survives what this reads
##    as a kill, and HEAER will have gone off. Both are rare, both are visible in play, and both are
##    preferable to guessing at a die roll that has not happened.
static func was_destroyed_by_this_damage(victim:Unit) -> bool:
	if victim.core.current.health > 0: return false
	if not victim.is_mech(): return true
	return victim.core.current.structure <= 1

# ---------------------------------------------------------------- capturing the body

## Where the victim's footprint is stashed between the gate and the activation, keyed by the victim
## so two bodies dropped by one Line shot cannot overwrite each other's tiles.
##
## ON THE GEAR'S STATE DICTIONARY, NEVER ON THIS RESOURCE. An Action is loaded once by ContentLibrary
## and handed to every unit that equips the Kit, so a member variable here would be shared across
## every Fitzgerald on the map (and across saves). GearCore.set_state_tile serialises a Vector2i to a
## string for the same reason the rest of the engine does - gear state has to survive a save file.
static func tile_key(victim:Unit) -> String: return 'heaer_tile_%s' % victim.core.persistent_id
static func size_key(victim:Unit) -> String: return 'heaer_size_%s' % victim.core.persistent_id

## MEASURED, 2026-09-13, and it is the reason this is belt and braces rather than load-bearing: at
## activation time the victim reads Unit.is_valid = true, is_on_map = true, is_alive = true, on its
## own tile, at -3 HP. POST reactions are queued from inside event_unit_damage.execute(), BEFORE the
## structure and death events, so nothing has removed the body yet. Better still, Unit extends
## Resource - the triggering Context holds a strong reference, so even after remove_from_game() the
## object survives and state.tile stays readable.
##
## The capture is kept anyway, exactly as design §3.2 asks. It costs two dictionary writes, and it is
## the difference between "the burst is drawn where the body was" and a crash the day that ordering
## moves. state.cached_size in particular is refreshed by the map's tile tracking and is the value
## most likely to go stale under a corpse.
static func capture_victim(gear:GearCore, victim:Unit) -> void:
	gear.set_state_tile(tile_key(victim), victim.state.tile)
	gear.set_state(size_key(victim), victim.get_size())

# ---------------------------------------------------------------- the explosion

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	if not is_instance_valid(context.event): return

	var victim:Unit = context.event.context.unit
	if not is_instance_valid(victim) or not is_instance_valid(victim.core): return

	# Read the capture back and drop it: whether the explosion happens or not, this body has been
	# accounted for and the two keys must not linger on the gear until the end of the scene.
	var center:Vector2i = gear.get_state_tile(tile_key(victim))
	var center_size:int = int(gear.get_state(size_key(victim), 1))
	gear.state.erase(tile_key(victim))
	gear.state.erase(size_key(victim))
	if center == Tile.INVALID: return

	# "you MAY expend a charge". The AI always says yes - it has no way to weigh the friendly fire,
	# and a reaction it never takes is a reaction that may as well not exist. Same shape as the
	# Armor Lock Plating's brace trigger (action_armor_lock_plating_trigger_knockback.gd:36-47),
	# which is this mod's model for asking, since SP1 shipped no prompt of its own.
	if unit.is_player_controlled():
		var confirmed:bool = await choice_bus.quick_yesno_for({
			tile = center,
			title = Translate.action(gear.kit, self, 'confirm'),
			description = Translate.gear(gear.kit.compcon_id, 'effect'),
			using = SpecificAction.create(unit, gear, self),
		})
		if not confirmed: return
	if activation.abort_without_unit(unit): return

	# THE CHARGE IS SPENT HERE, BY HAND, AND NOTHING ELSE WOULD SPEND IT. event_gear_activate calls
	# action.activate() and stops (event_gear_activate.gd:80); only an action that calls
	# spend_actions() reaches UnitAction.spend, which is the one place `gear.spend_charge()` lives
	# (unit_action.gd:274). Going through spend_actions() rather than calling spend_charge()
	# directly is what also records the usage under this action's own usage_group and writes the
	# "reacted" line into the battle log. It costs no actions: get_action_type() is RXN, so the
	# action cost is FREE, and consumes_rxn is false on the .tres, so no reaction point is taken
	# either - the charge is the whole price.
	spend_actions(activation)

	var burst_tiles := AoeCalculator.burst(center, center_size, BLAST_RADIUS, context.map.shape)
	var specific := SpecificAction.from_context(context)

	# ONE damage roll for the whole blast, as an area attack has in Lancer - not one per victim.
	var blast_damage:int = Dice.roll_string(BLAST_DAMAGE_DICE)

	var blast_events:Array[EventCore] = []
	for caught:Unit in context.map.get_all_units_at_tiles(burst_tiles, unit):
		# "All CHARACTERS within burst 1": objects and scenery standing in it are not part of the
		# effect. The corpse is skipped explicitly - it is still on the map at this point, since the
		# death event has not run yet, and shelling it again would only manufacture overkill.
		if caught == victim: continue
		if not caught.is_character(): continue
		# Allies and the Fitzgerald itself are NOT skipped (design §3.2: "the pilot chose it").
		var passed_save:bool = await UnitHasecheck.make_agility_save(activation, caught, specific)
		if activation.abort_without_unit(unit): return
		if passed_save: continue
		blast_events.append(EventCore.create(&'event_unit_damage', {
			unit = caught,
			number = blast_damage,
			category = Lancer.DAMAGE_TYPE.KINETIC,
			target_unit = unit, # let the damage event know WHO has done this
			flags = [EventService.DAMAGE_FLAG.AP, EventService.DAMAGE_FLAG.SAVE_FAILED],
		}))

	activation.queue_events(blast_events)
