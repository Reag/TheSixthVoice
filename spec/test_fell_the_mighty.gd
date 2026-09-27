# FELL THE MIGHTY and DOOMED (Black Mountain SP2, Blackstone Bell's active, design rulings 12-13):
#   "Choose a hostile character within sensors and line of sight, they are DOOMED for the rest of the
#    scene. Allies attacks against a DOOMED character have +1 Accuracy and whenever an allied character
#    deals damage to them, they increase their Overshield by 1. This ability is Efficient and will refund
#    1 Core Point at the end of any scene in which this ability was used."
#
# A PROTOCOL on cp_blackstone_bell - vanilla's ActionSystemApplyBuff aimed at a hostile within Sensors -
# hanging buff_doomed (visible, the scene, SURVIVES the Black Mountain's death). The buff's two gates read
# the Black Mountain's side and id stored at application, never the owner. The Efficient pair refunds.
#
# WHAT THIS FILE PROVES: the Protocol spends the core power and stamps Efficient, and cannot be pressed
# twice; it targets a hostile character within Sensors and LOS only; an ally's attack on the DOOMED target
# has +1 Accuracy (a weapon and a tech attack), the Black Mountain's and a hostile's do not; an ally's
# damaging hit gives +1 Overshield, marked as the Black Mountain's; once for a two-type weapon, once per
# separate damage event; a hit armour zeroes, heat, the Black Mountain's own and a hostile's give none; the
# buff survives the Black Mountain's death and still gives both; the target's death ends it; two Black
# Mountains stack; the refund at spawn and at combat end.
#
# GEOMETRY (map 30x12). The Black Mountain at (4,4), Sensors 10. The DOOMED hostile at (10,4). The ally at
# (6,4) with a rifle; TORCH_ALLY at (11,4), adjacent, with the Cutter plasma torch (1 energy + 1 burn +
# 1 heat, flat - three damage events in ONE attack). FAR_HOSTILE (15,4) is outside Sensors. WALL x = 8,
# rows 3-5 cuts the Black Mountain's sight of the hostile at (10,4) itself.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_fell_the_mighty.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')

const BM_TILE := Vector2i(4, 4)
const BM_B_TILE := Vector2i(4, 2)
const ALLY_TILE := Vector2i(6, 4)
const TORCH_ALLY_TILE := Vector2i(11, 4)
const HOSTILE_TILE := Vector2i(10, 4)
const HOSTILE_B_TILE := Vector2i(10, 8)
const FAR_HOSTILE_TILE := Vector2i(15, 4)
const WALL:Array[Vector2i] = [Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5)]
const RESPAWN_TILE := Vector2i(2, 10)
const TORCH := &'mw_cutter_mkii_plasma_torch'

var game:Gamemaster
var responder
var black_mountain:Unit
var ally:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	black_mountain = Fixture.create_black_mountain(game, BM_TILE)
	ally = Fixture.create_ally(game, ALLY_TILE)
	Fixture.arm_rifle(ally)
	Fixture.equip(ally, Fixture.INVADE)
	Fixture.arm_rifle(black_mountain)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	Fixture.queue([6, 6, 6, 6])

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear(unit:Unit = black_mountain) -> GearCore: return unit.get_gear(Fixture.CORE_ID)
func fell_action() -> Action: return core_gear().kit.get_action(Fixture.FELL_ACTION)

func doom(target:Unit = hostile, by:Unit = black_mountain) -> void:
	await Fixture.fell(game, by, target)

## The accuracy DOOMED hands `attacker`'s attack on the hostile, read the way attack_roll.gd:135 reads it.
func accuracy_for(attacker:Unit, kit_id:StringName = Fixture.MAIN_RIFLE) -> int:
	var gear:GearCore = attacker.get_gear(kit_id)
	if not GearCore.is_valid(gear): gear = Fixture.equip(attacker, kit_id)
	var context := SpecificAction.create(attacker, gear, gear.get_solo_action()).to_context()
	context.target_unit = hostile
	var total := 0
	for buff:BuffCore in UnitCondition.get_buffs_to(hostile, Buff.TO.ATTACK_ROLL_INCOMING, context):
		if buff.base.compcon_id == Fixture.DOOMED: total += buff.get_values().number
	return total

func targetable() -> Array[Vector2i]:
	return UnitTargeting.get_tiles_targetable(SpecificAction.create(black_mountain, core_gear(), fell_action()))

## Kill a unit through the engine's own death path: 1 HP, last structure, a 5-point hit.
func kill(unit:Unit, dealer:Unit = null) -> void:
	Fixture.weaken(unit, 1, 1)
	Fixture.queue([6, 6, 6, 6])
	await Fixture.damage(game, unit, 5, dealer)

# ---------------------------------------------------------------- registration

func test_the_core_kit_carries_the_protocol_exalt_the_refund_and_the_stamp() -> void:
	var core:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	if not Kit.is_valid(core):
		fail_test('The core Kit loads.')
		return
	var fell:Action = core.get_action(Fixture.FELL_ACTION)
	assert_true(fell is ActionSystemApplyBuff, 'Fell the Mighty is an ActionSystemApplyBuff.')
	if fell is ActionSystemApplyBuff:
		assert_eq(fell.action_type, Lancer.ACTION.PROTOCOL, 'A Protocol.')
		assert_true(fell.consumes_cp, 'Consumes the core power.')
		assert_true(fell.apply_to_sensors and fell.apply_only_to_enemies, 'A hostile within Sensors.')
		assert_eq(fell.usage_group, Fixture.FELL_ACTION, 'Its own usage group.')
	assert_not_null(core.get_action(Fixture.EXALT_ACTION), 'Exalt.')
	var refund:Action = core.get_action(Fixture.EFFICIENT_REFUND)
	assert_true(refund is ActionReaction, 'The Efficient refund.')
	if refund is ActionReaction:
		assert_eq(refund.triggers_on, [&'combat_end', &'unit_spawn'] as Array[StringName], 'Both triggers.')
		assert_false(refund.consumes_rxn, 'No reaction point.')
	assert_true(core.passives.any(func(p:Passive) -> bool: return p is PassiveDieCounter), 'The Efficient stamp passive.')
	var doomed:Buff = ContentLibrary.get_buff(Fixture.DOOMED)
	assert_not_null(doomed, 'buff_doomed is in the buffs index.')
	if doomed == null: return
	assert_false(doomed.hide_from_player, 'Visible.')
	assert_eq(doomed.until, Lancer.UNTIL.MANUAL, 'For the rest of the scene.')
	assert_false(doomed.is_cleared_on_owner_death(), 'Survives the Black Mountain (author).')
	assert_eq(X.tr('gear.buff_doomed.name'), 'DOOMED', 'Its own name row.')
	assert_eq(X.tr('gear.buff_doomed.effect'),
		'Allies attacks against a DOOMED |character| have +1 |Accuracy| and whenever an allied |character| deals damage to them, they increase their |Overshield| by 1.',
		'Its own effect row, verbatim (frame close C-1: was truncated at the comma, unquoted).')

# ---------------------------------------------------------------- the Protocol

func test_the_protocol_dooms_the_target_spends_the_core_power_and_stamps_efficient() -> void:
	assert_true(Fixture.has_core_power(black_mountain), 'fixture: the power is there.')
	await doom()
	assert_true(Fixture.is_doomed(hostile), 'DOOMED.')
	assert_false(Fixture.has_core_power(black_mountain), 'The core power is spent.')
	assert_true(Efficient.is_marked(core_gear()), 'And Efficient is stamped.')

func test_it_cannot_be_pressed_twice_in_a_scene() -> void:
	# Cycle the Black Mountain's turn before the second press (slice3 finding 4): a Protocol has a
	# FREE cost, so Action.get_per_round_hard_limit refuses a same-turn second press on its own, before
	# consumes_cp is ever asked. Without the cycle this test measures the per-round hard limit, not the
	# spent core power its comment claims. Mutation check: consumes_cp = false on the .tres reddens
	# this WITH the cycle and not without it (recorded 2026-09-27).
	var second := Fixture.create_hostile(game, HOSTILE_B_TILE)
	await doom()
	await Fixture.cycle_turn(game, black_mountain)
	await doom(second)
	assert_false(Fixture.is_doomed(second), 'The spent core power refuses the second press.')

func test_it_targets_a_hostile_character_within_sensors_and_line_of_sight_only() -> void:
	var drone := Fixture.create_drone(game, HOSTILE_B_TILE, Faction.AI_ENEMY)
	var far := Fixture.create_hostile(game, FAR_HOSTILE_TILE)
	var tiles := targetable()
	assert_has(tiles, hostile.tile(), 'A hostile character within Sensors and LOS.')
	assert_does_not_have(tiles, ally.tile(), 'Not an ally.')
	assert_does_not_have(tiles, black_mountain.tile(), 'Not itself.')
	assert_does_not_have(tiles, drone.tile(), 'Not a drone.')
	assert_does_not_have(tiles, far.tile(), 'Not beyond Sensors.')

func test_it_cannot_target_a_hostile_out_of_line_of_sight() -> void:
	Fixture.raise_wall(game, WALL)
	assert_false(UnitRelation.can_see(black_mountain, hostile), 'fixture: the wall hides the hostile.')
	assert_does_not_have(targetable(), hostile.tile(), 'Behind a wall.')

# ---------------------------------------------------------------- accuracy

func test_an_allys_attack_on_the_doomed_target_has_plus_one_accuracy() -> void:
	await doom()
	assert_eq(accuracy_for(ally), 1, 'A weapon attack.')
	assert_eq(accuracy_for(ally, Fixture.INVADE), 1, 'A tech attack: "Allies attacks", unqualified.')

func test_the_black_mountains_and_a_hostiles_attacks_get_nothing() -> void:
	var other_hostile := Fixture.create_hostile(game, HOSTILE_B_TILE)
	Fixture.arm_rifle(other_hostile)
	await doom()
	assert_eq(accuracy_for(black_mountain), 0, '"Allies" excludes the Black Mountain (ruling 3).')
	assert_eq(accuracy_for(other_hostile), 0, 'A hostile.')

func test_the_accuracy_turns_a_real_miss_into_a_hit() -> void:
	await doom()
	# d20 9 against evasion 10: a miss alone; the +1 Accuracy's d6 of 6 makes 15.
	Fixture.queue([9, 6, 4, 6, 6])
	await Fixture.shoot(game, ally, hostile)
	assert_eq(200 - Fixture.health(hostile), 4, 'The ally hit: the rifle\'s 4.')
	# CONTROL: the Black Mountain's identical shot misses (RELIABLE 2 still lands).
	var before := Fixture.health(hostile)
	Fixture.queue([9, 6, 4, 6, 6])
	await Fixture.shoot(game, black_mountain, hostile)
	assert_eq(before - Fixture.health(hostile), 2, 'The Black Mountain missed: RELIABLE 2 only.')

# ---------------------------------------------------------------- Overshield on damage

func test_an_allys_damage_gives_them_one_overshield_marked_as_the_black_mountains() -> void:
	await doom()
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 1, '+1 Overshield.')
	assert_true(Overshield.is_granted_by(ally, black_mountain), 'Granted by the Black Mountain.')

func test_it_increases_existing_overshield() -> void:
	await doom()
	await Fixture.grant_overshield(ally, 3)
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 4, 'Increase by 1, not max(3, 1).')

func test_each_separate_damage_event_counts() -> void:
	await doom()
	await Fixture.damage(game, hostile, 3, ally)
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 2, 'Two events outside any attack: two.')

func test_a_two_type_weapon_counts_once_per_attack() -> void:
	var torch_ally := Fixture.create_ally(game, TORCH_ALLY_TILE)
	Fixture.equip(torch_ally, TORCH)
	hostile.core.frame.stat.evasion = -10
	hostile.update_cached_values_and_token()
	await doom()
	Fixture.queue([19, 6, 6, 6])
	await Fixture.cycle_turn(game, torch_ally)
	await SpecFactory.use_solo(game, torch_ally, TORCH, hostile)
	assert_eq(200 - Fixture.health(hostile), 2, 'fixture: the energy and burn chunks both landed.')
	assert_eq(Fixture.overshield(torch_ally), 1, 'One attack, one Overshield.')

func test_a_hit_armour_zeroes_gives_nothing() -> void:
	# A REAL shot, the Purple Thorn probe's shape: armour 3 eats the rifle's Reliable-floored 2, and
	# DAMAGE POST still runs with number 0 (test_spike_purple_thorn_sp1_seams.gd).
	hostile.core.frame.stat.armor = 3
	hostile.core.full_repair()
	await doom()
	# The DOOMED accuracy d6 pops after the d20; the tail of 1s makes it and the damage die 1.
	Fixture.queue([19])
	await Fixture.shoot(game, ally, hostile)
	assert_eq(Fixture.health(hostile), 200, 'fixture: armour ate it.')
	assert_eq(Fixture.overshield(ally), 0, 'No damage dealt, no Overshield.')

func test_heat_the_black_mountains_own_and_a_hostiles_damage_give_nothing() -> void:
	var other_hostile := Fixture.create_hostile(game, HOSTILE_B_TILE)
	await doom()
	await Fixture.damage(game, hostile, 3, ally, Lancer.DAMAGE_TYPE.HEAT)
	assert_eq(Fixture.overshield(ally), 0, 'Heat.')
	await Fixture.damage(game, hostile, 3, black_mountain)
	assert_eq(Fixture.overshield(black_mountain), 0, 'The Black Mountain\'s own.')
	await Fixture.damage(game, hostile, 3, other_hostile)
	assert_eq(Fixture.overshield(other_hostile), 0, 'A hostile\'s.')

func test_an_unowned_allied_drone_is_not_a_character_and_an_owned_one_acts_as_its_owner() -> void:
	var stray := Fixture.create_drone(game, ALLY_TILE + Vector2i(0, 2))
	var owned := Fixture.own_drone(Fixture.create_drone(game, ALLY_TILE + Vector2i(0, -2)), ally)
	await doom()
	await Fixture.damage(game, hostile, 3, stray)
	assert_eq(Fixture.overshield(stray), 0, 'An unowned drone is not a character.')
	await Fixture.damage(game, hostile, 3, owned)
	assert_eq(Fixture.overshield(ally), 1, 'An owned drone hit counts as its owner hit (get_attacker).')
	assert_eq(Fixture.overshield(owned), 0, 'Not the drone itself.')

# ---------------------------------------------------------------- lifetime

func test_doomed_survives_the_black_mountains_death_and_still_gives_both() -> void:
	var killer := Fixture.create_hostile(game, HOSTILE_B_TILE)
	await doom()
	await kill(black_mountain, killer)
	assert_false(Unit.is_valid(black_mountain), 'fixture: the Black Mountain is destroyed.')
	assert_true(Fixture.is_doomed(hostile), 'DOOMED persists (author).')
	assert_eq(accuracy_for(ally), 1, 'Still +1 Accuracy.')
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 1, 'Still +1 Overshield - unmarked, nothing of the Black Mountain is left.')
	assert_eq(UnitCondition.get_buffs(ally, Fixture.GRANTED_BY_MARK).size(), 0,
		'And truly unmarked (slice1 finding 5): no granted-by mark - DOOMED.get_owner_gear resolved null.')

func test_doomed_survives_a_serialise_round_trip() -> void:
	# BuffCore has its own serialize/deserialize (buff_core.gd:36,53), used by UnitBattleState for a
	# mid-scene save. Round-trip the DOOMED BuffCore through JSON (which is what a real save does, and
	# which turns doomed_by_side's stored int into a float on the way back - buff_doomed.gd:61,68) and
	# confirm both halves of the card still read it.
	await doom()
	var original:BuffCore = UnitCondition.get_buffs(hostile, Fixture.DOOMED).front()
	if not assert_not_null(original, 'fixture: DOOMED is on the hostile.'): return
	var index:int = hostile.state.buffs.find(original)
	if not assert_ne(index, -1, 'fixture: found in state.buffs.'): return
	var restored:BuffCore = BuffCore.deserialize(JSON.parse_string(JSON.stringify(original.serialize())))
	hostile.state.buffs[index] = restored
	assert_eq(accuracy_for(ally), 1, 'DOOMED still gives +1 Accuracy after the round trip.')
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 1, 'And still +1 Overshield on a damaging hit.')

func test_the_doomed_targets_death_ends_it() -> void:
	# NOT asserted over game.map.get_all_units() (slice3 finding 5): a destroyed unit is removed from
	# the map, so that loop never sees the only unit that could carry DOOMED and passes vacuously
	# whatever DOOMED's lifetime is. Read the held reference's own state directly instead -
	# event_service.gd's clear_all_buffs is what actually does this.
	await doom()
	await kill(hostile, ally)
	assert_false(Unit.is_valid(hostile), 'fixture: destroyed.')
	assert_true(UnitCondition.get_buffs(hostile, Fixture.DOOMED).is_empty(),
		'The dead hostile carries no DOOMED: clear_all_buffs ran on its death.')

func test_two_black_mountains_stack() -> void:
	var second := Fixture.create_black_mountain(game, BM_B_TILE)
	await doom()
	await doom(hostile, second)
	assert_eq(UnitCondition.get_buffs(hostile, Fixture.DOOMED).size(), 2, 'Two marks.')
	assert_eq(accuracy_for(ally), 2, '+2 Accuracy.')
	await Fixture.damage(game, hostile, 3, ally)
	assert_eq(Fixture.overshield(ally), 2, '+2 Overshield.')

# ---------------------------------------------------------------- Efficient

## A mech arriving in the NEXT SCENE (test_form_of_the_myriad.gd's spawn_into_next_scene, verbatim).
func spawn_into_next_scene(from:Unit) -> Unit:
	var saved:Dictionary = from.core.serialize()
	from.remove_from_game()
	var core := UnitCore.deserialize(saved)
	core.persistent_id = Util.generate_random_hexcode()
	var arriving := Unit.create(core)
	await game.execute_event('event_unit_spawn', {unit = arriving, target_tiles = [RESPAWN_TILE]})
	return arriving

func test_a_used_fell_the_mighty_is_refunded_when_the_black_mountain_spawns_into_the_next_scene() -> void:
	await doom()
	assert_false(Fixture.has_core_power(black_mountain), 'fixture: spent.')
	var arriving := await spawn_into_next_scene(black_mountain)
	assert_true(Fixture.has_core_power(arriving), 'The next scene starts with the point back.')
	assert_false(Efficient.is_marked(arriving.get_gear(Fixture.CORE_ID)), 'And the stamp cleared.')

## LAST IN THE FILE, for test_efficient.gd's reason: event_combat_end emits campaign_bus.end_level.
func test_a_used_fell_the_mighty_is_refunded_at_combat_end() -> void:
	await doom()
	assert_false(Fixture.has_core_power(black_mountain), 'fixture: spent.')
	await game.execute_event('event_combat_end',
		{boolean = true, flags = [EventService.COMBAT_END_FLAG.SKIP_BANNER]})
	assert_true(Fixture.has_core_power(black_mountain), 'The scene ended and the point came back.')
	assert_false(Efficient.is_marked(core_gear()), 'And the stamp cleared.')
