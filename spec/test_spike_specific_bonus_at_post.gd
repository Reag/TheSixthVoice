# SLUAGH SP4 PROBE (design 4.0): is a `bonus_damage_specific` buff applied to the ATTACKER at
# ATTACK / POST read by THAT SAME attack's damage roll?
#
# Everything Eyes of Night does hangs on this. The channel is read in roll_specific_bonus_damage
# (event_unit_attack_declared.gd:268-296), which runs AFTER the declared event has awaited every
# per-target attack event (:65) - and ATTACK / POST reactions are queued on those per-target events
# (event_unit_attack.gd:123). So a buff applied by such a reaction should be on the attacker before
# :268 asks for it, be rolled unhalved, and be consumed at :296. SP1's probe measured the same
# ordering with an Overshield grant; this one measures it with the buff, because a grant that lands
# early and a buff that is READ early are two different claims.
#
# THE MUTATION IS THE EVIDENCE. Moving the trigger to ATTACK_DECLARED / POST puts the application
# AFTER :268, so the +3 misses this attack - and then sits on the attacker for the NEXT one. Test 1
# must go red on the damage, and test 3 on the lingering buff.
#
# A KNOCKOFF Kit on the guardian, built in code, with the reaction extending the BASE ActionReaction
# rather than ActionReactionAttacked: the archetype's gate needs an attack summary and would simply
# never fire at ATTACK_DECLARED, and "never fired" and "fired late" leave the same HP. SP1's probe
# made the same choice for the same reason.
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const RIFLE := &'mw_assault_rifle'
const HITTING_D20 := 15
const MISSING_D20 := 2
const DUMMY_EVASION := 10
const DUMMY_HP := 200
const RIFLE_DAMAGE := 6    # a buffer of 6s under the 1d6
const RIFLE_RELIABLE := 2
const BONUS := 3

## The trigger under test. The mutation swaps this for ReactionBus.TRIGGER.ATTACK_DECLARED.
const TRIGGER := ReactionBus.TRIGGER.ATTACK

const ENEMY_TILE := Vector2i(2, 4)
const VICTIM_TILE := Vector2i(6, 4)
const WATCHER_TILE := Vector2i(7, 4)

var game:Gamemaster
var enemy:Unit
var victim:Unit
var watcher:Unit
var rifle:GearCore
var reaction:BonusOnHit
var kit:Kit


class BonusOnHit extends ActionReaction:
	var victim:Unit
	var fired:int = 0
	var bonus:Buff

	func _init(trigger:StringName) -> void:
		triggers_on = [trigger]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_required_triggering_context() -> Array[Context.PROP]: return []
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if not Unit.is_valid(victim): return false
		if triggers_on.has(ReactionBus.TRIGGER.ATTACK):
			# The per-target attack event: target_unit is the defender, object the resolved roll.
			if context.target_unit != victim: return false
			if not AttackRoll.is_valid(context.object): return false
			return (context.object as AttackRoll).hit
		# The mutation: the declared event. Its resource is the summary; fire when the victim was hit.
		var summary:DeclaredAttackSummary = context.resource
		if not DeclaredAttackSummary.is_valid(summary): return false
		return summary.attack_rolls.any(func(roll:AttackRoll) -> bool:
			return roll.target_unit == victim and roll.hit)

	func activate(context:Context, activation:EventCore) -> void:
		fired += 1
		var attacker:Unit = context.event.context.unit
		var core := BuffCore.create(bonus, &'')
		UnitCondition.apply_buff_alt(activation, attacker, core)


func before_each() -> void:
	game = Fixture.create_game(self)
	enemy = Fixture.create_dummy(game, ENEMY_TILE, DUMMY_EVASION, Faction.AI_ENEMY)
	victim = Fixture.create_dummy(game, VICTIM_TILE, DUMMY_EVASION, Faction.PLAYER)
	watcher = Fixture.create_dummy(game, WATCHER_TILE, DUMMY_EVASION, Faction.PLAYER)
	rifle = enemy.core.equip_system(RIFLE)
	SpecFactory.apply_passive_buffs(enemy)
	assert_eq(victim.core.current.health, DUMMY_HP, 'fixture: the victim starts at full HP.')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


func make_bonus() -> Buff:
	var buff := BuffDamage.new()
	buff.compcon_id = &'specific_bonus_probe_buff'
	buff.to = Buff.TO.BONUS_DAMAGE_SPECIFIC
	buff.damage_dice = str(BONUS)
	buff.is_onetime = true
	buff.hide_from_player = true
	return buff

func install_watcher() -> void:
	reaction = BonusOnHit.new(TRIGGER)
	reaction.victim = victim
	reaction.bonus = make_bonus()
	kit = Kit.new()
	kit.compcon_id = &'specific_bonus_probe_kit'
	kit.is_trait = true
	kit.actions.append(reaction)
	watcher.core.loadout.equipped_kits.append(kit)
	watcher.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

func fire(d20:int, as_freebie:bool = false) -> void:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = rifle.get_solo_action(), gear = rifle, unit = enemy, target_unit = victim,
		flags = [Action.FLAG.AS_FREEBIE] if as_freebie else [],
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))

func attacker_holds_the_bonus() -> bool:
	return enemy.state.buffs.any(func(core:BuffCore) -> bool:
		return core.base.compcon_id == &'specific_bonus_probe_buff')


func test_a_specific_bonus_applied_at_attack_post_is_rolled_into_the_same_hit() -> void:
	install_watcher()
	await fire(HITTING_D20)
	assert_eq(reaction.fired, 1, 'LIVENESS: the reaction fired exactly once for the one hit.')
	assert_eq(victim.core.current.health, DUMMY_HP - RIFLE_DAMAGE - BONUS,
		'THE PROBE: the hit landed the rifle\'s 6 PLUS the 3 applied at POST - the channel was read after the reaction.')

func test_without_the_watcher_the_hit_is_just_the_rifle() -> void:
	await fire(HITTING_D20)
	assert_eq(victim.core.current.health, DUMMY_HP - RIFLE_DAMAGE, 'Control: 6 on a 0-armor dummy.')

func test_the_one_time_bonus_is_consumed_by_that_roll_and_a_miss_applies_nothing() -> void:
	install_watcher()
	await fire(HITTING_D20)
	assert_false(attacker_holds_the_bonus(),
		'Consumed at event_unit_attack_declared.gd:296 - nothing lingers for the next shot.')
	# No turn is open in this probe (SP1's probe never opened one either), so a second activation
	# in the same turn silently aborts at event_gear_activate's check_specific_context on the
	# rifle's per-turn soft limit (action.gd:161-163) - no "Gear not available" line, just
	# "specific: invalid" and a shot that never happened. AS_FREEBIE is the fixture's own exemption
	# from that limit (sluagh_fixture.gd's shoot_again).
	await fire(MISSING_D20, true)
	assert_eq(reaction.fired, 1, 'A miss does not fire it.')
	assert_eq(victim.core.current.health, DUMMY_HP - RIFLE_DAMAGE - BONUS - RIFLE_RELIABLE,
		'The miss landed only Reliable 2 - no bonus from a stale buff.')
