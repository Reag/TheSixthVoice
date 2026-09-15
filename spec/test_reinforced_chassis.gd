# Reinforced Chassis (Subutai trait, SP1 Task 2).
#
#   "The Subutai reduces all Kinetic and Explosive damage by 1 before Armor and Resistances are
#    calculated."
#
# Built as a BuffResistDamage in REDUCE mode. Two divergences from "before Armor and Resistances"
# are ACCEPTED by ruling 11 and PINNED here rather than left to drift:
#
#  1. The engine subtracts the 1 AFTER halving for resistance (damage_modifications.gd:104-110), so
#     a resisted hit takes up to 1 less than the card - in the Subutai's favour.
#  2. Shredded returns early (:77-81) and skips the reduction entirely.
#
# Armor ORDER makes no numeric difference: max(0, d - 1 - A) either way. AP skips only the armor
# line (:99), so AP damage is still reduced. Heat and burn are excluded by the damage-type list.
#
# Damage is applied through event_unit_damage directly rather than through an attack, so each test
# pins one arithmetic path with nothing else moving.
#
# apply_status_alt / apply_buff_alt do not exist. test_ripper_mod.gd calls
# UnitCondition.apply_buff(SpecFactory.dummy_event(), unit, <Buff instance>) directly for an
# ad-hoc buff not registered under any kit, and SpecFactory.apply()/dummy_event() are what
# UnitCondition.apply_status itself needs (an EventCore, not just a unit) - so both appliers below
# go through SpecFactory.dummy_event() rather than a nonexistent "_alt" wrapper.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_reinforced_chassis.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')

const TRAIT_ID := &'mt_reinforced_chassis'
const START := Vector2i(4, 4)

var game:Gamemaster
var subutai:Unit

func before_each() -> void:
	game = SubutaiFixture.create_game(self)
	subutai = SubutaiFixture.create_subutai(game, START)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Apply raw damage and return how much HP was actually lost.
func damage_taken(amount:int, type:Lancer.DAMAGE_TYPE, flags:Array = []) -> int:
	var before:int = subutai.core.current.health
	await game.execute_event(&'event_unit_damage', {
		unit = subutai,
		number = amount,
		category = type,
		flags = flags,
	})
	return before - subutai.core.current.health

func test_the_trait_is_on_the_frame_and_is_a_trait():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_reinforced_chassis is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait, not equippable gear.')
	assert_true(kit.actions.is_empty(), 'It is a pure passive: no actions.')
	var frame:Frame = ContentLibrary.get_mech_frame(&'mf_subutai')
	var trait_ids:Array[StringName] = []
	for t:Kit in frame.traits: trait_ids.append(t.compcon_id)
	assert_has(trait_ids, TRAIT_ID, 'The frame carries it.')

func test_six_kinetic_against_armor_one_takes_four():
	# 6 - 1 armor - 1 reduction = 4.
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC), 4, 'Kinetic is reduced.')

func test_six_explosive_against_armor_one_takes_four():
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.EXPLOSIVE), 4, 'Explosive is reduced.')

func test_six_energy_takes_five_because_energy_is_not_reduced():
	# 6 - 1 armor = 5. The card names Kinetic and Explosive only; this is what makes the
	# damage_types list discriminate rather than the buff just resisting everything.
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.ENERGY), 5, 'Energy takes armor only.')

func test_ap_kinetic_skips_armor_but_is_still_reduced():
	# AP skips the armor line (:99) and nothing else. 6 - 1 reduction = 5.
	assert_eq(
		await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC, [EventService.DAMAGE_FLAG.AP]), 5,
		'AP kinetic loses the armor but keeps the reduction.'
	)

func test_heat_is_not_reduced():
	var before:int = subutai.core.current.heat
	await game.execute_event(&'event_unit_damage', {
		unit = subutai, number = 3, category = Lancer.DAMAGE_TYPE.HEAT,
	})
	assert_eq(subutai.core.current.heat - before, 3, 'Heat is untouched by the trait.')

func test_the_reduction_floors_at_zero():
	# 1 - 1 armor - 1 reduction = -1, clamped by max(0, ...). Pins that a small hit cannot heal.
	assert_eq(await damage_taken(1, Lancer.DAMAGE_TYPE.KINETIC), 0, 'Damage never goes negative.')

func test_shredded_skips_the_reduction_entirely():
	# Ruling 11's second accepted divergence. Shredded returns early BEFORE the reduction is applied
	# (:77-81) and also before armor, so a Shredded Subutai takes the full 6.
	UnitCondition.apply_status(SpecFactory.dummy_event(), subutai, Lancer.STATUS.SHREDDED, Lancer.UNTIL.MANUAL)
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC), 6,
		'Shredded takes the raw number: no armor, no reduction.')

func test_a_resisted_hit_is_halved_first_and_then_reduced():
	# Ruling 11's first accepted divergence, pinned on the rounding side. 6 - 1 armor = 5;
	# Util.half is ceili, so 5 -> 3; then - 1 reduction = 2. The card's order would give
	# ceil((6 - 1 - 1) / 2) = 2 as well for armor, but 3 without - so this asserts the ENGINE's
	# order, which is what ships.
	var resist := BuffResistDamage.new()
	resist.to = Buff.TO.RESIST_DAMAGE
	resist.resist_everything = true
	resist.hide_from_player = true
	# A freshly-constructed Buff with no resource_path of its own gets compcon_id = GENERIC_ID
	# (buff.gd:105-112) - same as the trait's own inline SubResource buff. apply_buff_alt's
	# already-applied dedup (unit_condition.gd:741-747) matches on compcon_id via get_buffs_alt,
	# and passing an empty from_gear there (unit_condition.gd:794-795) makes it match ANY from_gear,
	# not just ''. Without this flag the trait's own reduction buff (same `to`, same default `until`)
	# gets silently cleared the instant this ad-hoc one is applied, and the test would be measuring
	# armor+halving alone. multiple_copies_can_stack skips that whole dedup block.
	resist.multiple_copies_can_stack = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), subutai, resist)
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC), 2,
		'Armor, then halve (ceil), then reduce.')

func test_self_inflicted_kinetic_is_reduced():
	# resist_self_inflicted = true, as vanilla Pressure Plating sets it. Without the flag the buff
	# returns false for self-damage and the Subutai eats the full amount from its own gear.
	assert_eq(
		await damage_taken(3, Lancer.DAMAGE_TYPE.KINETIC,
			[EventService.DAMAGE_FLAG.AP, EventService.DAMAGE_FLAG.SELF_INFLICTED]),
		2,
		'Self-inflicted AP kinetic is still reduced by 1.'
	)

func test_the_reduction_is_not_one_time():
	# is_onetime would make the trait fire once per scene: damage_modifications assigns every
	# reduction buff to buffs_to_consume and event_unit_damage consumes them.
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC), 4, 'First hit reduced.')
	# 8 - 4 = 4 HP left, exactly what the second hit's math also produces, so a naive back-to-back
	# rehit would land the unit at exactly 0 HP and trip event_unit_damage.gd's
	# queue_structure_or_stress_if_necessary (health <= 0 -> event_unit_structure), which restores
	# HP to max - a real Lancer structure-damage mechanic, not a trait bug, but it would make
	# "before - after" go negative and falsely read as the reduction being lost. Repair between hits
	# so this test isolates "is the buff still active", not "did the unit also structure-damage".
	subutai.core.full_repair() # touches core.current.* only; does not clear unit.state.buffs
	assert_eq(await damage_taken(6, Lancer.DAMAGE_TYPE.KINETIC), 4, 'Second hit reduced too.')

func test_the_effect_row_resolves():
	assert_ne(X.tr('gear.mt_reinforced_chassis.name'), 'gear.mt_reinforced_chassis.name',
		'The trait is named.')
	assert_ne(X.tr('gear.mt_reinforced_chassis.effect'), 'gear.mt_reinforced_chassis.effect',
		'The trait has rule text.')
