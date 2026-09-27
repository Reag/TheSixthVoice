# SHREDDER CANNON (Purple Thorn rank II weapon, SP3 Task 1, design ruling 11).
#
#   Main Cannon, SP 0. SMART, ACCURATE, LOADING. 3 Kinetic, Range 15.
#   On hit: Until the end of your next turn, the target is Shredded, and all characters gain +1 to
#   all attack rolls against them.
#
# The profile is pure .tres; the on-hit is onhit_shredder_cannon (a chip on the target, its clock on
# the Thorn - the Naga's Ping, whose clock script this reuses). Pinned here: the tags act (LOADING
# unloads until Reload, ACCURATE is a +1 accuracy mod, SMART rolls against E-Defense); a hit hangs
# the visible chip with its Shredded; an ally's weapon attack AND a tech attack get flat +1; a
# non-character attacker gets nothing; a miss hangs nothing; the window ends at the end of the
# Thorn's next turn in BOTH turn orders (the Ping's two measurements); a second target runs its own
# clock.
#
# ON THE THORN, so Vigil opens a reticle on every hit (cancelled by an unreachable answer). Blessed
# Bolt is Auxiliary-only and never asks about a Main weapon; the yes/no is declined anyway.
#
# THE DICE: flat 3 rolls no damage die, and ACCURATE pops one accuracy d6 after the d20.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_shredder_cannon.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const KIT_ID := &'mw_shredder_cannon'
const ACTION_ID := &'action_shredder_cannon'
const CHIP := &'buff_shredded_mark'
const CLOCK := &'buff_shredded_clock'
const FLEX_MOUNT := 2
const FRAGMENT_SIGNAL := &'ms_fragment_signal'

const THORN_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(12, 6)
const SECOND_TILE := Vector2i(12, 9)
const ALLY_TILE := Vector2i(14, 6)
const DRONE_TILE := Vector2i(14, 8)
## Exactly Range 15 east of the Thorn, and one tile past it.
const AT_RANGE := Vector2i(19, 6)
const PAST_RANGE := Vector2i(20, 6)

const D20_HITS := 19
const D20_MISSES := 1
## On the map, far outside range 3 of anywhere the Thorn stands: cancels Vigil's reticle.
const CANCEL_VIGIL := Vector2i(28, 0)

var game:Gamemaster
var thorn:Unit
var target:Unit
var responder

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	target = Fixture.create_hostile(game, TARGET_TILE)
	responder.chosen_yesnos = false
	responder.chosen_move_tile = CANCEL_VIGIL

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func arm_cannon() -> GearCore:
	Fixture.mount_pair(thorn, FLEX_MOUNT, KIT_ID)
	return thorn.get_gear(KIT_ID)

## One cannon shot that HITS, opening the Thorn's turn if it is not already open. Reloads first
## when the cannon is spent, so a spec can fire on consecutive turns.
func fire(at:Unit, d20:int = D20_HITS) -> void:
	var gear := thorn.get_gear(KIT_ID)
	if not gear.is_loaded: await reload()
	if not thorn.state.is_taking_turn: await Fixture.open_turn(game, thorn)
	Fixture.queue([d20])
	await SpecFactory.use_solo(game, thorn, KIT_ID, at, [Action.FLAG.AS_FREEBIE])

func reload() -> void:
	await game.execute_event(&'event_gear_reload', {unit = thorn, gear = thorn.get_gear(KIT_ID)})

func pre_attack(attacker:Unit, gear:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var action:Action = gear.get_solo_action()
	var ctx := Context.create({unit = attacker, gear = gear, action = action, target_unit = against})
	return AttackRoll.PreAttack.create(ctx)

func shredded(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, CHIP) and unit.has_status(Lancer.STATUS.SHREDDED)

func clears_both() -> bool:
	return not UnitCondition.has_buff(target, CHIP) and not target.has_status(Lancer.STATUS.SHREDDED)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The weapon loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var weapon := kit.actions[0] as ActionAttackWeapon
	assert_not_null(weapon, 'The profile is an ActionAttackWeapon.')
	if weapon == null: return
	assert_eq(weapon.get_id(), ACTION_ID, 'Its id.')
	assert_eq(weapon.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(weapon.weapon_type, Lancer.WEAPON_TYPE.CANNON, 'Cannon.')
	assert_eq(weapon.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(weapon.damage_dice, '3', '3 damage, flat.')
	assert_eq(weapon.aim_range, 15, 'Range 15.')
	assert_eq(weapon.tags, [&'smart', &'accurate', &'loading'] as Array[StringName], 'SMART, ACCURATE, LOADING - the card\'s order.')
	assert_eq(weapon.attack_accuracy, '1', 'ACCURATE\'s +1 is attack_accuracy (the tag itself is display).')
	assert_eq(weapon.on_hit_effects.size(), 1, 'One on-hit effect.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Shredder Cannon', 'The name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('Comprised of a three part automatic targeting system'), 'The flavour row.')
	assert_true(X.tr('gear.%s.on_hit' % KIT_ID).begins_with('Until the end of your next turn, the target is'), 'The on-hit row.')
	assert_eq(X.tr('gear.%s.name' % CHIP), 'Shredder Cannon', 'The chip\'s name row.')

# ---------------------------------------------------------------- the tags act

func test_range_fifteen_is_the_edge():
	var gear := arm_cannon()
	var tiles := UnitTargeting.get_tiles_in_range(SpecificAction.create(thorn, gear, gear.get_solo_action()))
	assert_has(tiles, AT_RANGE, 'Fifteen tiles away is in range.')
	assert_does_not_have(tiles, PAST_RANGE, 'Sixteen is not.')

func test_accurate_is_a_plus_one_accuracy_mod():
	var gear := arm_cannon()
	assert_eq(pre_attack(thorn, gear, target).accuracy_mods_total(), 1, 'ACCURATE: +1 accuracy in the roll, and nothing else.')

func test_smart_rolls_against_e_defense():
	var gear := arm_cannon()
	Fixture.set_edef(target, 7)
	var pre := pre_attack(thorn, gear, target)
	assert_eq(pre.against, AttackRoll.ATTACK_TYPE.TECH, 'SMART: the roll is against E-Defense...')
	assert_eq(pre.target_defense, 7, '...the target\'s 7, not its evasion 10.')

func test_loading_refuses_a_second_shot_until_reload():
	var gear := arm_cannon()
	await fire(target)
	assert_false(gear.is_loaded, 'LOADING: the shot unloaded the cannon.')
	var specific := SpecificAction.create(thorn, gear, gear.get_solo_action())
	assert_eq(UnitAction.get_gear_unavailable_reason(specific, true), UnitAction.REASON.UNLOADED,
		'A second shot is refused, even as a freebie, for exactly that reason.')
	await reload()
	assert_true(gear.is_loaded, 'Reload restores the shot...')
	assert_eq(UnitAction.get_gear_unavailable_reason(specific, true), UnitAction.REASON.NONE, '...and it is available again.')

# ---------------------------------------------------------------- the on-hit

func test_a_hit_deals_three_and_shreds_the_target_with_a_visible_chip():
	arm_cannon()
	await fire(target)
	assert_eq(target.current_damage(), 3, 'A hit: 3.')
	assert_true(target.has_status(Lancer.STATUS.SHREDDED), 'The target is Shredded.')
	assert_true(UnitCondition.has_buff(target, CHIP), 'It carries the chip.')
	var chip := UnitCondition.get_buff(target, CHIP)
	if chip: assert_false(chip.base.hide_from_player, 'The chip is visible.')
	assert_true(UnitCondition.has_buff(thorn, CLOCK), 'The clock hangs on the Thorn.')

func test_a_miss_hangs_nothing():
	arm_cannon()
	await fire(target, D20_MISSES)
	assert_false(target.has_status(Lancer.STATUS.SHREDDED), 'No Shredded.')
	assert_false(UnitCondition.has_buff(target, CHIP), 'No chip.')
	assert_false(UnitCondition.has_buff(thorn, CLOCK), 'No clock.')

func test_an_allys_weapon_attack_against_the_target_gains_flat_plus_one():
	arm_cannon()
	var ally := Fixture.create_ally(game, ALLY_TILE)
	var rifle := Fixture.equip(ally, Fixture.MAIN_RIFLE)
	var before := pre_attack(ally, rifle, target).flat_bonus
	await fire(target)
	assert_eq(pre_attack(ally, rifle, target).flat_bonus, before + 1, 'An ally\'s rifle: +1 to the roll.')
	var accuracy := pre_attack(ally, rifle, target).accuracy_mods_total()
	assert_eq(accuracy, 0, 'Flat +1, not accuracy.')

func test_a_tech_attack_against_the_target_gains_flat_plus_one():
	arm_cannon()
	var ally := Fixture.create_ally(game, ALLY_TILE)
	var signal_gear := ally.get_gear(FRAGMENT_SIGNAL)
	assert_true(GearCore.is_valid(signal_gear), 'fixture: every mech carries Fragment Signal.')
	if not GearCore.is_valid(signal_gear): return
	assert_true(signal_gear.get_solo_action() is ActionAttackTech, 'fixture: and it is a tech attack.')
	var before := pre_attack(ally, signal_gear, target).flat_bonus
	await fire(target)
	assert_eq(pre_attack(ally, signal_gear, target).flat_bonus, before + 1, '"All attack rolls": a tech attack gets +1 too.')

func test_the_thorns_own_next_attack_gains_it_too():
	var gear := arm_cannon()
	await fire(target)
	await reload()
	assert_eq(pre_attack(thorn, gear, target).flat_bonus - pre_attack(thorn, gear, Fixture.create_hostile(game, SECOND_TILE)).flat_bonus, 1,
		'"All characters" includes the Thorn: +1 against the shredded target, none against a fresh one.')

func test_an_unowned_drone_attacker_gains_the_plus_one():
	# A drone is a character (ruling 2026-09-27): an unowned drone resolves to itself through
	# get_attacker, and it is a character, so it gains the +1 like any other attacker.
	arm_cannon()
	var drone := Fixture.create_drone(game, DRONE_TILE, Faction.PLAYER)
	var rifle := Fixture.equip(drone, Fixture.MAIN_RIFLE)
	var before := pre_attack(drone, rifle, target).flat_bonus
	await fire(target)
	assert_eq(pre_attack(drone, rifle, target).flat_bonus, before + 1,
		'An unowned drone is a character (ruling 2026-09-27): +1.')

# ---------------------------------------------------------------- the clock

## ORDER ONE: the target takes a turn between the hit and the Thorn's next turn.
func test_the_window_ends_at_the_end_of_the_thorns_next_turn():
	arm_cannon()
	await fire(target)
	await SpecFactory.end_turn(game, thorn)
	assert_true(shredded(target), 'Up after the Thorn\'s firing turn.')
	await SpecFactory.start_turn(game, target)
	await SpecFactory.end_turn(game, target)
	assert_true(shredded(target), 'Up after the target\'s turn.')
	await SpecFactory.start_turn(game, thorn)
	assert_true(shredded(target), 'Up through the Thorn\'s next turn...')
	await SpecFactory.end_turn(game, thorn)
	assert_true(clears_both(), '...and the chip and the Shredded are gone when it ends.')
	assert_false(UnitCondition.has_buff(thorn, CLOCK), 'The clock went too.')

## ORDER TWO: the target never starts a turn in between. A target-side clock would never tick here.
func test_the_window_ends_on_the_thorns_next_turn_even_if_the_target_never_acted():
	arm_cannon()
	await fire(target)
	await SpecFactory.end_turn(game, thorn)
	await SpecFactory.start_turn(game, thorn)
	assert_true(shredded(target), 'Up through the Thorn\'s next turn...')
	await SpecFactory.end_turn(game, thorn)
	assert_true(clears_both(), '...and gone at its end, though the target never started a turn.')

func test_a_second_target_runs_its_own_clock():
	arm_cannon()
	var second := Fixture.create_hostile(game, SECOND_TILE)
	await fire(target)
	await SpecFactory.end_turn(game, thorn)
	await fire(second) # reloads, opens the Thorn's next turn
	assert_true(shredded(target) and shredded(second), 'Both are Shredded.')
	await SpecFactory.end_turn(game, thorn)
	assert_true(clears_both(), 'The first window ends at the end of this turn...')
	assert_true(shredded(second), '...and the second, its own, stands...')
	await SpecFactory.start_turn(game, thorn)
	await SpecFactory.end_turn(game, thorn)
	assert_false(shredded(second), '...until a turn later.')

func test_a_second_hit_on_the_same_target_restarts_the_window():
	arm_cannon()
	await fire(target)
	await SpecFactory.end_turn(game, thorn)
	await fire(target)
	assert_eq(UnitCondition.get_buffs(target, CHIP).size(), 1,
		'One chip, not two - the second replaced the first.')
	await SpecFactory.end_turn(game, thorn)
	assert_true(shredded(target), 'The first hit\'s window ended here, but the second chip stands...')
	await SpecFactory.start_turn(game, thorn)
	await SpecFactory.end_turn(game, thorn)
	assert_true(clears_both(), '...and ends a turn later.')
