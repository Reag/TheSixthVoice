# SLUAGH SP1 PROBE (design 1.0): does an ATTACK POST reaction run BEFORE the attack's damage lands?
#
# Two of the Sluagh's rulings lean on it. Astral Guardian (ruling 13) grants an adjacent ally 1d6
# Overshield "before damage is dealt" from an ATTACK POST reaction, and Eyes of Night (ruling 22,
# SP4) applies a specific bonus-damage buff at ATTACK POST that the same attack's damage roll must
# then read. The engine reading behind both: event_unit_attack queues its POST reactions onto the
# per-target event (event_unit_attack.gd:123), event_unit_attack_declared awaits every per-target
# event (event_unit_attack_declared.gd:67) and only then rolls damage (:74). This file measures it.
#
# THE SHAPE IS ASTRAL GUARDIAN'S, MINUS THE CARD: a bystander ally holds a knockoff trait Kit whose
# one action is a hidden, point-free reaction; when the protected unit is HIT it grants that unit a
# fixed 10 Overshield. Under a 6-damage hit (the assault rifle's 1d6 at cheated sixes, into a 0-armor
# dummy) the ordering shows in the numbers: POST-before-damage leaves HP untouched and Overshield at
# 4; POST-after-damage would leave HP down 6 and Overshield at 10.
#
# THE REACTION EXTENDS ActionReaction, NOT ActionReactionAttacked, so that the mutation can be run at
# all: the archetype's own gate needs an attack summary and would simply never fire on a DAMAGE
# event, and "never fired" and "fired too late" both leave HP down 6. The gate here reads whichever
# event it is given, so the mutation (TRIGGER -> DAMAGE) fires AFTER the damage and the file records
# the late grant as Overshield 10 / HP 194 rather than as silence.
#
# MUTATION: set TRIGGER to ReactionBus.TRIGGER.DAMAGE. test_a_post_attack_grant_lands_before_the_damage
# must go red on BOTH its HP and its Overshield lines (measured 2026-09-20: HP 194, Overshield 10 -
# the grant fired, and fired late). The miss test goes red too, because the rifle's Reliable 2 is a
# damage event of its own and the DAMAGE gate fires on it (fired 1, Overshield 10); the control stays
# green. 1/3, 10/14 asserts. Restored byte-identical (SHA-256) afterwards.
# No production code. The Sluagh's real reaction is built on the archetype by the SP1 plan.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_post_before_damage.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## Vanilla GMS Main Rifle: Range 10, 1d6 kinetic, RELIABLE 2, no accuracy dice of its own.
const RIFLE := &'mw_assault_rifle'
## What a MISS with it still lands (measured on the first run: 198 where 200 was expected).
const RIFLE_RELIABLE := 2
## A cheated d20 that beats evasion 10 with a grit-0 pilot, and one that does not.
const HITTING_D20 := 15
const MISSING_D20 := 2
const DUMMY_EVASION := 10
const DUMMY_HP := 200
## The rifle's 1d6 at a cheated six.
const RIFLE_DAMAGE := 6
## More than the hit, so a grant that lands first soaks all of it and leaves a remainder to read.
const GRANT := 10

## THE MUTATION KNOB. ATTACK is the claim under test; DAMAGE is the mutation.
const TRIGGER := ReactionBus.TRIGGER.ATTACK

## One row: the enemy shoots east at the protected unit; the guardian stands beside it.
const ENEMY_TILE := Vector2i(2, 4)
const PROTECTED_TILE := Vector2i(6, 4)
const GUARDIAN_TILE := Vector2i(7, 4)

var game:Gamemaster
var enemy:Unit
var protected:Unit
var guardian:Unit
var rifle:GearCore
var reaction:ShieldOnHit


## Grants GRANT Overshield to `protected` when the event it is handed concerns a hit on that unit.
## Point-free and hidden, so the bus runs it without a prompt and without the action economy.
class ShieldOnHit extends ActionReaction:
	var protected:Unit
	var fired:int = 0

	func _init(trigger:StringName) -> void:
		triggers_on = [trigger]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_required_triggering_context() -> Array[Context.PROP]: return []
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 99

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var context:Context = triggering_event.context
		if not Unit.is_valid(protected): return false
		if triggers_on.has(ReactionBus.TRIGGER.ATTACK):
			# The per-target attack event: target_unit is the defender, object the resolved roll.
			if context.target_unit != protected: return false
			if not AttackRoll.is_valid(context.object): return false
			return (context.object as AttackRoll).hit
		# The mutation's damage event: unit is the victim.
		return context.unit == protected and context.number > 0

	func activate(_context:Context, activation:EventCore) -> void:
		fired += 1
		await Overshield.grant(activation, protected, GRANT)


func before_each() -> void:
	game = Fixture.create_game(self)
	enemy = Fixture.create_dummy(game, ENEMY_TILE, DUMMY_EVASION, Faction.AI_ENEMY)
	protected = Fixture.create_dummy(game, PROTECTED_TILE, DUMMY_EVASION, Faction.PLAYER)
	guardian = Fixture.create_dummy(game, GUARDIAN_TILE, DUMMY_EVASION, Faction.PLAYER)
	rifle = enemy.core.equip_system(RIFLE)
	SpecFactory.apply_passive_buffs(enemy)
	assert_eq(protected.core.current.health, DUMMY_HP, 'fixture: the protected unit starts at full HP.')
	assert_eq(Overshield.current(protected), 0, 'fixture: ...and with no Overshield.')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## The knockoff Kit on the guardian's own loadout as a runtime trait Kit (test_draw_fire.gd's
## recorder idiom). full_repair() regenerates derived gear, which is where the Kit's reaction gets
## indexed by trigger.
func install_guardian() -> void:
	reaction = ShieldOnHit.new(TRIGGER)
	reaction.protected = protected
	var kit := Kit.new()
	kit.compcon_id = &'post_before_damage_probe_kit'
	kit.is_trait = true
	kit.actions.append(reaction)
	guardian.core.loadout.equipped_kits.append(kit)
	guardian.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## Sixty sixes after the one d20: the rifle's damage die comes back 6.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Fire the rifle at the protected unit for real, through the whole attack pipeline.
func fire(d20:int) -> void:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = rifle.get_solo_action(), gear = rifle, unit = enemy, target_unit = protected,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))


# ---------------------------------------------------------------- the probe

## THE CLAIM. The ATTACK POST grant runs before the damage: the 10 Overshield soaks the whole 6 and
## HP never moves.
func test_a_post_attack_grant_lands_before_the_damage() -> void:
	install_guardian()
	await fire(HITTING_D20)
	assert_eq(reaction.fired, 1, 'LIVENESS: the reaction fired exactly once for the one hit.')
	assert_eq(protected.core.current.health, DUMMY_HP,
		'HP is untouched: the grant landed BEFORE the damage and soaked it.')
	assert_eq(Overshield.current(protected), GRANT - RIFLE_DAMAGE,
		'Overshield reads the grant minus the hit: the soak happened against the fresh grant.')

## CONTROL: the same hit with nobody shielding lands on HP for the full 6. Pins the damage number the
## probe reads its ordering off, so a rifle or dice change shows here rather than as a wrong verdict.
func test_without_the_guardian_the_hit_lands_on_hp() -> void:
	await fire(HITTING_D20)
	assert_eq(protected.core.current.health, DUMMY_HP - RIFLE_DAMAGE, 'The rifle lands 6 on a 0-armor dummy.')
	assert_eq(Overshield.current(protected), 0, 'Nothing granted anything.')

## A miss grants nothing: the gate reads the resolved roll off the per-target event (the archetype's
## own require_hit reads the same object), so the ordering measured above is that of a HIT's POST.
## The rifle's Reliable 2 still lands on a miss, and lands on HP, since nothing was granted.
func test_a_miss_grants_nothing() -> void:
	install_guardian()
	await fire(MISSING_D20)
	assert_eq(reaction.fired, 0, 'The reaction did not fire on a miss.')
	assert_eq(protected.core.current.health, DUMMY_HP - RIFLE_RELIABLE,
		'A miss lands only the Reliable 2, on HP.')
	assert_eq(Overshield.current(protected), 0, 'No grant on a miss.')
