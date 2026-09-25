# KOREMASA SPIKE 7 (roadmap §5 row 7): can a size-1/2 mech occupy a LARGER HOSTILE mech's space and
# move with it, with the host Impaired and able to buck it off with a contested Hull check - and can
# every hit it lands on the host be a crit whose damage is NOT rolled twice? (Lassissian Folly.)
#
# THE ENGINE ALREADY HAS RIDING. It is the "stackup": PassiveAttachment.is_stackup on a Kit, and
# CommonActionUtil.start_riding(activation, rider, base, that_gear) (common_action_util.gd:532-571),
# which is what the Mule Harness (ms_mule_harness, the BASE holds the gear), the Goblin's Symbiosis
# (cp_instinct_rig, the RIDER holds the gear) and the Latch Drone all call. A rider's
# stackup_order > 0 (unit_battle_state.gd:195-216) makes it occupy the base's whole footprint, drag
# along on every katamari move (katamari.gd:95 - involuntary moves too, "strongly attached"), lose
# its own movement (pathfinder.gd:343: allowed tiles = none) and its movement actions
# (unit_action.gd:418-424, via can_be_used_while_stackup_rider), and be immune to knockback
# (unit_condition.gd:552). NOTHING in that chain reads faction: Symbiosis' `are_allies` and the
# harness's are their own can_target checks. So the spike's question is really three:
#
#  1. Does start_riding land a HOSTILE rider? Its share-space move (:557-562) goes through the
#     pathfinder's occupation rules, and pathfinder.gd:116-125 accepts CAN_SHARE_SPACE from either
#     side regardless of faction; the engagement branch at :136-144 is skipped whenever the
#     share-space list is non-empty. The Goblin never exercised the hostile path. Tests a, b, c.
#  2. Can the HOST use a Quick action that lives on the RIDER's Kit? Vanilla's situational actions
#     (Action.is_situationally_activated + can_be_used_situationally_by, unit_action.gd:31-53) are
#     exactly "another unit's gear offers me an action" - the harness's climb-on is one. Contested
#     checks exist: UnitHasecheck.make_contested_hull_check(event, unit1, unit2) (:20-22) rolls
#     unit2 first and returns whether unit1 met or beat it. Tests d, e, f.
#  3. "All of your attacks against them are considered critical hits. Resulting damage is not
#     rolled twice." The crit half is the Naga's spike 6 verbatim: a BuffModifyAttackRoll at
#     SEQUENCE_STEP.turn_hit_to_crit, gated on the target being the mount. The damage half has NO
#     hook between the crit roll and the damage number - damage dice are rolled after the attack
#     rolls (event_unit_attack_declared.gd:76-90), DamageRoll.crit is the max-sum of hit+crit dice
#     (attack_util.gd:251-256) and get_for_attack_roll picks it on roll.crit (:118-123) with
#     nothing in between - BUT event_unit_damage's DamageModifications (damage_modifications.gd)
#     reads RESIST_DAMAGE buffs on the VICTIM with the AttackRoll in context.object, and a REDUCE
#     buff subtracts a number AFTER armor. Subtraction commutes: (crit - armor) - (crit - hit) is
#     hit - armor, so a mount-side reduce-by-(crit - hit) buff yields exactly the single-roll damage
#     against the same armor. Tests g, h. (Exposed doubles before the reduction; the buff doubles
#     its number to match. Resistance halving between the two is the one case that does not
#     commute - a ruling, see the doc.)
#
# MUTATIONS. SUPPRESS_DOUBLE_ROLL := false - test g must go red on its damage line only (the crit
# itself stays). OFFER_THROW_OFF := false - tests d, e and f must go red (the mount is offered
# nothing). Every other test stays green under both, because everything else here is the engine's.
#
# No production code. The real core power is built on cp_overdrive_exploitation_sequences.
#
#   powershell -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log $env:TEMP/riding.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_riding.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

## MUTATION KNOBS. Both are the claim under test as written.
const SUPPRESS_DOUBLE_ROLL := true
const OFFER_THROW_OFF := true

const KIT_ID := &'reag_spike_saddle'
const BLADE := &'mw_tactical_melee_weapon' # GMS main melee, 1d6+2 kinetic, threat 1
const BOOST := &'ms_boost'

const RIDER_TILE := Vector2i(3, 3)
const HOST_TILE := Vector2i(4, 3) # size 2: (4,3) (5,3) (4,4) (5,4); adjacent to the rider
const BYSTANDER_TILE := Vector2i(10, 6) # a second hostile, far away, never involved
const RIDE_TO := Vector2i(7, 3) # three steps east; dummy speed covers it
const SHOVE_TO := Vector2i(4, 5) # two steps south, as a knockback would

var game:Gamemaster
var rider:Unit
var host:Unit
var bystander:Unit
var saddle:GearCore
var mount_action:Mount
var throw_off:ThrowOff
var watcher:CritWatcher


# ---------------------------------------------------------------- the knockoff core power

## The rider's crit rule: every hit on the MOUNT is a crit. Spike 6's seam, gated on the target.
class AlwaysCrit extends BuffModifyAttackRoll:
	var mount_id:StringName

	func _init() -> void:
		to = Buff.TO.MODIFY_ATTACK_ROLL
		until = Lancer.UNTIL.MANUAL
		step = EventUnitAttack.SEQUENCE_STEP.turn_hit_to_crit
		applies_when_holder_is = APPLIES_WHEN.attacker
		needs_confirmation = false
		hide_from_player = true

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if not super.check_if_passive_applies(core, context): return false
		return Unit.is_valid(context.target_unit) and context.target_unit.core.persistent_id == mount_id


## The mount's damage rule: a crit from the RIDER deals its single-roll damage. Sits on the mount
## (RESIST_DAMAGE is read on the victim), REDUCE by (crit sum - hit sum) of this damage type.
class NotRolledTwice extends BuffResistDamage:
	var rider_id:StringName

	func _init() -> void:
		to = Buff.TO.RESIST_DAMAGE
		until = Lancer.UNTIL.MANUAL
		reduce_instead_of_resist = true
		hide_from_player = true

	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		if not SUPPRESS_DOUBLE_ROLL: return false
		if not AttackRoll.is_valid(context.object): return false
		var roll:AttackRoll = context.object
		if not roll.crit: return false
		# the damage event's target_unit is WHO DEALT it (event_unit_damage.gd:35, :83)
		return Unit.is_valid(context.target_unit) and context.target_unit.core.persistent_id == rider_id

	func get_values(_core:BuffCore, context:Context) -> Context:
		var roll:AttackRoll = context.object
		var type:Lancer.DAMAGE_TYPE = context.category_int as Lancer.DAMAGE_TYPE
		var difference:int = roll.damage.get_crits().get(type, 0) - roll.damage.get_hits().get(type, 0)
		# Exposed doubled the incoming amount before any reduction is read (damage_modifications.gd:55-57)
		if context.unit.has_status(Lancer.STATUS.EXPOSED) and not [Lancer.DAMAGE_TYPE.HEAT, Lancer.DAMAGE_TYPE.BURN].has(type):
			difference *= 2
		return Context.create({number = difference, flags = [BuffResistDamage.FLAG.REDUCE]})


## Quick: climb onto an adjacent larger hostile mech. Symbiosis with `are_allies` flipped.
class Mount extends ActionSystem:
	func _init() -> void:
		action_type = Lancer.ACTION.QUICK
		play_fxg_on_activate = false
		original_id = &'reag_spike_mount'

	func get_target_range(_specific:SpecificAction) -> int: return 1

	func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
		if not super.can_target_unit(potential_target, specific): return false
		if not potential_target.is_mech(): return false
		if not UnitRelation.are_enemies(specific.unit, potential_target): return false
		if UnitRelation.compare_size(specific.unit, potential_target) >= 0: return false # they must be larger
		if Katamari.create(specific.unit).all_units.has(potential_target): return false
		if UnitCondition.is_in_stackup(potential_target): return false
		if UnitCondition.is_in_stackup(specific.unit): return false
		return true

	func candidates(specific:SpecificAction) -> Array[Unit]:
		return UnitRelation.get_units_within(specific.unit, 1, true, false, can_target_unit.bind(specific))

	func activate(context:Context, activation:EventCore) -> void:
		var specific := SpecificAction.from_context(context)
		var mount:Unit = context.target_unit
		if not Unit.is_valid(mount):
			var options := candidates(specific)
			if activation.abort_when(options.is_empty()): return
			mount = options.front()
		if activation.abort_without_units([specific.unit, mount]): return

		await CommonActionUtil.start_riding(activation, specific.unit, mount, specific.gear)
		if activation.abort_without_units([specific.unit, mount]): return
		spend_actions(activation)

		# the mount is Impaired while ridden; the rider's hits are crits; the crit is not rolled twice
		UnitCondition.apply_status(activation, mount, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL, specific.gear.persistent_id)
		var not_twice := NotRolledTwice.new()
		not_twice.rider_id = specific.unit.core.persistent_id
		UnitCondition.apply_buff_alt(activation, mount, BuffCore.create(not_twice, specific.gear.persistent_id))
		var always := AlwaysCrit.new()
		always.mount_id = mount.core.persistent_id
		UnitCondition.apply_buff_alt(activation, specific.unit, BuffCore.create(always, specific.gear.persistent_id))

	## Everything the ride put on either unit comes off, the attachment is dropped, the rider is
	## bumped to a free tile around the mount (the harness's end action, action_mule_harness_end.gd).
	static func dismount(event:EventCore, rider_unit:Unit, mount:Unit, gear:GearCore) -> void:
		UnitCondition.clear_status_source(event, mount, gear.persistent_id)
		UnitCondition.clear_buffs_owned_by(event, mount, gear.persistent_id)
		UnitCondition.clear_buffs_owned_by(event, rider_unit, gear.persistent_id)
		Katamari.dettach_units(event, rider_unit, mount, gear.persistent_id)
		EventUnitMove.queue_events_to_make_sure_units_are_in_valid_spots(
			[rider_unit], event, UnitTile.get_tiles_within(mount, 1, false)
		)


## Quick, SITUATIONAL: offered to the unit this gear's owner is riding, and to nobody else.
## Contested Hull, the mount against the rider; a win throws the rider off.
class ThrowOff extends ActionSystem:
	## The last contested check's outcome, for the spec to read.
	var last_thrown := false
	var activations := 0

	func _init() -> void:
		action_type = Lancer.ACTION.QUICK
		is_situationally_activated = true
		play_fxg_on_activate = false
		hide_if_disabled = true
		original_id = &'reag_spike_throw_off'

	## (From the POV of the unit who wants to use the action; situational unit/gear hold it.)
	func can_be_used_situationally_by(unit:Unit, situational_unit:Unit, situational_gear:GearCore) -> bool:
		if not OFFER_THROW_OFF: return false
		if unit == situational_unit: return false
		if not UnitCondition.is_stackup_base(unit): return false
		return PassiveAttachment.get_stackup_base(situational_unit.state, situational_unit.map) == unit

	func activate(context:Context, activation:EventCore) -> void:
		var mount:Unit = context.unit # the one bucking
		var rider_unit:Unit = context.map.get_unit_from_source_id(context.gear.persistent_id)
		if activation.abort_without_units([mount, rider_unit]): return
		activations += 1
		spend_actions(activation)
		var specific := SpecificAction.from_context(context)
		last_thrown = await UnitHasecheck.make_contested_hull_check(activation, mount, rider_unit, specific)
		if activation.abort_without_units([mount, rider_unit]): return
		if not last_thrown: return
		Mount.dismount(activation, rider_unit, mount, context.gear)


## Records which units each attack CRIT, off the DeclaredAttackSummary at ATTACK_DECLARED POST.
class CritWatcher extends ActionReaction:
	var crit_units:Array[Unit] = []
	var attacks := 0

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.resource]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == unit and DeclaredAttackSummary.is_valid(triggering_event.context.resource)

	func activate(context:Context, _activation:EventCore) -> void:
		attacks += 1
		var summary:DeclaredAttackSummary = context.event.context.resource
		crit_units = summary.get_all_crit_units()


# ---------------------------------------------------------------- fixture

func before_each() -> void:
	game = Fixture.create_game(self)

	rider = SpecFactory.create_unit(game.map, RIDER_TILE, Faction.PLAYER)
	FrameIsolation.isolate_frame(rider) # we write is_size_half on it
	rider.core.frame.stat.is_size_half = true
	rider.core.frame.stat.evasion = 10 # a throw-off's contested check never touches this; a hit does not either
	install_saddle()
	rider.core.equip_system(BLADE)
	SpecFactory.apply_passive_buffs(rider)
	UnitTile.move_to(rider, RIDER_TILE)

	host = Fixture.create_dummy(game, HOST_TILE, 10, Faction.AI_ENEMY) # 200 HP, armor 0, evasion 10
	SpecFactory.change_size(host, 2)
	UnitTile.move_to(host, HOST_TILE)

	bystander = Fixture.create_dummy(game, BYSTANDER_TILE, 10, Faction.AI_ENEMY)

	UnitTile.update_tracking_and_statuses(game.map)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The knockoff Kit: the stackup passive plus the two actions, on the rider's own loadout.
func install_saddle() -> void:
	var kit := Kit.new()
	kit.compcon_id = KIT_ID
	kit.is_trait = true
	var passive := PassiveAttachment.new()
	passive.is_stackup = true
	kit.passives.append(passive)
	mount_action = Mount.new()
	throw_off = ThrowOff.new()
	watcher = CritWatcher.new()
	kit.actions.append(mount_action)
	kit.actions.append(throw_off)
	kit.actions.append(watcher)
	rider.core.loadout.equipped_kits.append(kit)
	rider.core.full_repair()
	saddle = rider.get_gear(KIT_ID)

func open_turn(unit:Unit) -> void:
	if unit.state.is_taking_turn: await SpecFactory.end_turn(game, unit)
	await SpecFactory.start_turn(game, unit)

func mount() -> void:
	await open_turn(rider)
	await game.execute_event(&'event_gear_activate', {
		action = mount_action, gear = saddle, unit = rider, target_unit = host,
	})

## [these], then a long tail of 1s.
func queue(rolls:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var all:Array[int] = rolls.duplicate()
	for i:int in 40: all.append(1)
	Dice.CHEAT_ROLL_QUEUE.assign(all)

## The mount's buck: a Quick action on the RIDER's gear, used by the HOST. The contested check
## rolls the RIDER first (unit2, number to beat), then the MOUNT (unit1).
func buck(rider_d20:int, mount_d20:int) -> void:
	await open_turn(host)
	queue([rider_d20, mount_d20])
	var offered := offered_throw_offs(host)
	assert_eq(offered.size(), 1, 'LIVENESS: the mount is offered exactly one throw-off.')
	if offered.is_empty(): return
	await SpecFactory.use_specific(game, offered.front())

func offered_throw_offs(unit:Unit) -> Array[SpecificAction]:
	return UnitAction.get_situational_actions(unit).filter(func(specific:SpecificAction) -> bool:
		return specific.action == throw_off
	)

## The d20, then the hit die, then the crit die of the blade's 1d6+2 (no accuracy dice: nothing
## grants any, and a MELEE attack takes no difficulty from being Engaged).
func slash(target:Unit, d20:int, hit_die:int, crit_die:int) -> void:
	await open_turn(rider)
	queue([d20, hit_die, crit_die])
	await SpecFactory.use_solo(game, rider, BLADE, target)

func assert_riding() -> void:
	assert_eq(rider.tile(), host.tile(), 'The rider stands on the mount\'s tile.')
	assert_eq(rider.occupied_tiles(), host.occupied_tiles(), 'The rider occupies the mount\'s whole footprint.')
	assert_true(Katamari.are_attached(rider, host), 'They are attached.')
	assert_true(UnitCondition.is_stackup_rider(rider), 'The rider is a stackup RIDER.')
	assert_true(UnitCondition.is_stackup_base(host), 'The mount is the stackup BASE.')

func assert_dismounted() -> void:
	assert_false(Katamari.are_attached(rider, host), 'They are no longer attached.')
	assert_false(UnitCondition.is_in_stackup(rider), 'The rider is out of the stackup.')
	assert_false(UnitCondition.is_in_stackup(host), 'The mount is out of the stackup.')
	assert_ne(rider.tile(), host.tile(), 'The rider is off the mount\'s tile.')
	assert_eq(rider.occupied_tiles().size(), 1, 'The rider is back to its own footprint.')
	assert_eq(UnitRelation.distance_between(rider, host), 1, 'The rider landed adjacent to the mount.')
	assert_false(host.has_status(Lancer.STATUS.IMPAIRED), 'The mount is no longer Impaired.')
	assert_true(UnitCondition.get_buffs_from(host.state, saddle.persistent_id).is_empty(), 'Nothing of the ride is left on the mount.')
	assert_true(UnitCondition.get_buffs_from(rider.state, saddle.persistent_id).is_empty(), 'Nothing of the ride is left on the rider.')


# ---------------------------------------------------------------- 1. a hostile rider

func test_a_mounts_a_larger_hostile_and_shares_its_space() -> void:
	assert_true(rider.is_size_half(), 'FIXTURE: the rider is size 1/2.')
	assert_eq(host.get_size(), 2, 'FIXTURE: the mount is size 2.')
	assert_true(UnitRelation.are_enemies(rider, host), 'FIXTURE: they are enemies.')
	var specific := SpecificAction.create(rider, saddle, mount_action)
	assert_true(mount_action.can_target_unit(host, specific), 'The larger adjacent hostile is a valid mount.')
	assert_true(mount_action.can_target_unit(bystander, specific), 'A size-1 hostile is LARGER than a size-1/2 rider (compare_size reads size-half as 0), so it qualifies too.')
	assert_eq(mount_action.candidates(specific), [host] as Array[Unit], 'Only the adjacent one is a candidate.')
	bystander.core.frame.stat.is_size_half = true
	bystander.core.full_repair()
	assert_false(mount_action.can_target_unit(bystander, specific), 'A size-1/2 hostile is not larger.')

	await mount()

	assert_riding()
	assert_true(host.has_status(Lancer.STATUS.IMPAIRED), 'The mount is Impaired while ridden.')
	assert_eq(UnitCondition.get_buffs_from(host.state, saddle.persistent_id).size(), 1, 'The mount carries the ride\'s damage rule.')
	assert_eq(UnitCondition.get_buffs_from(rider.state, saddle.persistent_id).size(), 1, 'The rider carries the ride\'s crit rule.')
	# ENGINE FACT, not a claim: two hostiles at distance 0 engage each other.
	assert_true(rider.has_status(Lancer.STATUS.ENGAGED), 'FACT: the rider is Engaged with its mount.')
	assert_true(host.has_status(Lancer.STATUS.ENGAGED), 'FACT: the mount is Engaged with its rider.')

func test_b_rides_along_when_the_mount_moves_even_while_immobilized_and_slowed() -> void:
	await mount()
	SpecFactory.apply(rider, Lancer.STATUS.IMMOBILIZED)
	SpecFactory.apply(rider, Lancer.STATUS.SLOWED)
	assert_true(UnitCondition.is_immobilized(rider), 'FIXTURE: the rider is Immobilized.')

	await SpecFactory.move(game, host, RIDE_TO)
	assert_eq(host.tile(), RIDE_TO, 'The mount walked (voluntary move).')
	assert_riding()
	# ENGINE FACT, measured on the first green run: the rider's basic Overwatch TRIGGERED on its own
	# mount starting to walk (a hostile moving inside threat 1 is a hostile moving inside threat 1),
	# and the stock responder took the shot. A design ruling, not a spike question.
	assert_eq(watcher.attacks, 1, "FACT: the rider's Overwatch fires on its own mount walking.")

	await SpecFactory.move(game, host, SHOVE_TO, MovementType.create_for_involuntary(host))
	assert_eq(host.tile(), SHOVE_TO, 'The mount was shoved (involuntary move).')
	assert_riding()
	assert_true(host.has_status(Lancer.STATUS.IMPAIRED), 'Still Impaired after moving.')

func test_c_the_rider_cannot_move_by_itself_or_be_knocked_off() -> void:
	await open_turn(rider)
	assert_true(UnitAction.can_activate_gear(SpecificAction.from_id(rider, BOOST)), 'Before mounting the rider can Boost.')
	await mount()
	assert_false(UnitAction.can_activate_gear(SpecificAction.from_id(rider, BOOST)), 'Riding, the rider cannot Boost (unit_action.gd:418).')
	var shove := MovementType.create_for_involuntary(rider)
	assert_true(UnitCondition.is_immune_to_knockback_from(rider, SpecificAction.create(host, null, null), shove, false),
		'Riding, the rider is immune to knockback (unit_condition.gd:552).')
	await SpecFactory.move(game, rider, SHOVE_TO, shove)
	assert_riding()


# ---------------------------------------------------------------- 2. the mount bucks

func test_d_throw_off_is_offered_to_the_mount_and_nobody_else() -> void:
	await open_turn(host)
	assert_eq(offered_throw_offs(host).size(), 0, 'Unridden, the host is offered nothing.')
	await mount()
	await open_turn(host)
	var offered := offered_throw_offs(host)
	assert_eq(offered.size(), 1, 'Ridden, the mount is offered the throw-off.')
	if not offered.is_empty():
		assert_eq(offered.front().gear, saddle, 'It comes from the RIDER\'s gear.')
		assert_eq(offered.front().unit, host, 'It is the MOUNT\'s action.')
	await open_turn(bystander)
	assert_eq(offered_throw_offs(bystander).size(), 0, 'Another hostile is offered nothing.')
	await open_turn(rider)
	assert_eq(offered_throw_offs(rider).size(), 0, 'The rider is not offered its own buck.')

func test_e_throw_off_wins_the_contested_hull_check_and_dismounts() -> void:
	await mount()
	await buck(5, 15) # rider 5 + 0, mount 15 + 0: the mount wins
	assert_eq(throw_off.activations, 1, 'LIVENESS: the throw-off ran.')
	assert_true(throw_off.last_thrown, 'The mount won the contested Hull check.')
	assert_dismounted()

func test_f_throw_off_loses_and_the_rider_stays() -> void:
	await mount()
	await buck(15, 5) # rider 15, mount 5: the rider hangs on
	assert_eq(throw_off.activations, 1, 'LIVENESS: the throw-off ran.')
	assert_false(throw_off.last_thrown, 'The mount lost the contested Hull check.')
	assert_riding()
	assert_true(host.has_status(Lancer.STATUS.IMPAIRED), 'Still Impaired.')
	assert_lt(host.state.actions, Lancer.ACTION_COST_FULL, 'The failed buck still cost the mount its Quick action.')


# ---------------------------------------------------------------- 3. every hit is a crit, rolled once

func test_g_a_melee_hit_on_the_mount_is_a_crit_whose_damage_is_the_single_roll() -> void:
	await mount()
	var targetable := CommonActionUtil.get_targetable_units(SpecificAction.from_id(rider, BLADE), [])
	assert_true(targetable.has(host), 'The mount is in the blade\'s threat from its own tile (distance 0).')

	var before:int = host.core.current.health
	await slash(host, 11, 1, 6) # 11 vs evasion 10: a plain hit; hit die 1, crit die 6
	assert_eq(watcher.attacks, 1, 'LIVENESS: the attack resolved.')
	assert_true(watcher.crit_units.has(host), 'An 11 on the mount was a CRIT.')
	assert_eq(before - host.core.current.health, 1 + 2, 'Its damage was the single roll (1+2), not the crit\'s (6+2).')

func test_h_control_the_same_hit_on_an_unmounted_hostile_is_a_plain_hit() -> void:
	# adjacent but NOT mounted: the same Kit and blade, no ride
	await open_turn(rider)
	var before:int = host.core.current.health
	await slash(host, 11, 1, 6)
	assert_eq(watcher.attacks, 1, 'LIVENESS: the attack resolved.')
	assert_false(watcher.crit_units.has(host), 'Unmounted, an 11 is a plain hit.')
	assert_eq(before - host.core.current.health, 1 + 2, 'Plain hit damage.')

func test_i_a_natural_crit_on_the_mount_is_also_rolled_once() -> void:
	await mount()
	var before:int = host.core.current.health
	await slash(host, 20, 1, 6)
	assert_true(watcher.crit_units.has(host), 'A 20 is a crit, as ever.')
	assert_eq(before - host.core.current.health, 1 + 2, 'The card covers every attack on the mount, so a natural crit is rolled once too.')

func test_j_control_a_natural_crit_on_an_unmounted_hostile_rolls_twice() -> void:
	await open_turn(rider)
	var before:int = host.core.current.health
	await slash(host, 20, 1, 6)
	assert_true(watcher.crit_units.has(host), 'A 20 is a crit.')
	assert_eq(before - host.core.current.health, 6 + 2, 'Vanilla crit damage: the higher of the two dice.')


# ---------------------------------------------------------------- 4. the mount dies

func test_k_the_mount_dying_leaves_the_rider_standing() -> void:
	await mount()
	Dice.CHEAT_ROLL_QUEUE.clear()
	host.core.current.structure = 1 # one more structure loss is death
	await game.execute_event(&'event_unit_damage', {
		unit = host, number = 9999, category = Lancer.DAMAGE_TYPE.KINETIC,
		flags = [EventService.DAMAGE_FLAG.AP],
	})
	assert_true(Unit.is_valid(rider), 'The rider is still on the field.')
	assert_false(UnitCondition.is_in_stackup(rider), 'The rider is out of the stackup.')
	assert_true(rider.state.attachments.is_empty(), 'No attachment survives the mount.')
	assert_eq(rider.occupied_tiles().size(), 1, 'The rider is back to its own footprint.')
