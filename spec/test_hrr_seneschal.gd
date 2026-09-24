# HRR-SENESCHAL (Hazard rank III weapon, SP4 Task 1, design ruling 12).
#
#   Main Rifle, SP 1. RELIABLE 2, HEAT SELF 1. 1d6 Kinetic, Range 20.
#
# PURE .tres - every behaviour below is ActionAttackWeapon's own: RELIABLE's value is
# reliable_damage, HEAT SELF is self_heat_dice (drawn as a tag by action.gd:359-361, NOT a `tags`
# entry), rolled by UnitAction.gain_self_heat inside spend_actions. The Annihilator is the vanilla
# precedent (self_heat_dice = "2").
#
# THE SELF-HEAT NEVER OFFERS EMERGENCY ARMATURE, and that is the one cross-card clause here:
# gain_self_heat_alt queues the heat as event_unit_damage with SELF_INFLICTED and the Hazard as its
# own dealer (unit_action.gd:296-306), and the Armature's gate refuses both (ruling 9). The case is
# asserted with a LIVENESS control - the same Armature, the same spec, offers on a hostile's hit -
# so a quiet responder cannot pass it by being broken.
#
# THE DICE: d20 first, then the 1d6 damage column. The flat "1" of HEAT SELF pops nothing
# (test_in_triumvirate.gd measured a flat self_heat_dice rolls no dice).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hrr_seneschal.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const KIT_ID := &'mw_hrr_seneschal'
const ACTION_ID := &'action_hrr_seneschal'
const ARMATURE_ID := &'ms_emergency_armature'

const HAZARD_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(8, 6)
## Exactly Range 20 east of the Hazard, and one tile past it (the map is 30 wide).
const AT_RANGE := Vector2i(24, 6)
const PAST_RANGE := Vector2i(25, 6)

var game:Gamemaster
var responder
var hazard:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func arm() -> GearCore:
	return Fixture.equip(hazard, KIT_ID)

func specific(gear:GearCore) -> SpecificAction:
	return SpecificAction.create(hazard, gear, gear.get_solo_action())

## A d20 of 15 hits evasion 10 without critting; then the 1d6.
func shoot_hit(damage_die:int) -> void:
	Fixture.queue([15, damage_die])
	await Fixture.shoot(game, hazard, hostile, KIT_ID)

## A d20 of 2 misses evasion 10.
func shoot_miss() -> void:
	Fixture.queue([2])
	await Fixture.shoot(game, hazard, hostile, KIT_ID)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The weapon loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 1, 'SP 1.')
	assert_eq(kit.charges_max, 0, 'Not LIMITED.')
	assert_eq(kit.actions.size(), 1, 'One profile.')
	var weapon := kit.actions[0] as ActionAttackWeapon
	assert_not_null(weapon, 'The profile is an ActionAttackWeapon.')
	if weapon == null: return
	assert_eq(weapon.get_id(), ACTION_ID, 'Its id.')
	assert_eq(weapon.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(weapon.weapon_type, Lancer.WEAPON_TYPE.RIFLE, 'Rifle.')
	assert_eq(weapon.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(weapon.damage_dice, '1d6', '1d6.')
	assert_eq(weapon.aim_range, 20, 'Range 20.')
	assert_null(weapon.range_pattern, 'A single target, no area.')
	assert_eq(weapon.tags, [&'reliable'] as Array[StringName], 'RELIABLE is the one tag entry.')
	assert_eq(weapon.get_base_value_for_tag(Lancer.WEAPON_TAG.RELIABLE), 2, 'RELIABLE 2.')
	assert_eq(weapon.self_heat_dice, '1', 'HEAT SELF 1 - a field, drawn as a tag by the card.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'HRR-SENESCHAL', 'The name row.')
	# The LCP's own spelling inside the flavour ("HRR-SENESHAL") is kept verbatim.
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('The most experimental weapon IPS-N has put'),
		'The flavour row.')

# ---------------------------------------------------------------- the engine acts on it

func test_a_hit_deals_the_die():
	arm()
	await shoot_hit(5)
	assert_eq(hostile.current_damage(), 5, 'A hit: the 1d6, cheated to 5.')

func test_a_low_hit_is_floored_at_reliable_two():
	arm()
	await shoot_hit(1)
	assert_eq(hostile.current_damage(), 2, 'A hit rolling 1 is lifted to RELIABLE 2.')

func test_a_miss_still_deals_reliable_two():
	arm()
	await shoot_miss()
	assert_eq(hostile.current_damage(), 2, 'A miss: RELIABLE 2 lands anyway.')

func test_under_weight_of_fire_the_reliable_rises_by_half_grit():
	# Grit 4: Weight of Fire adds +2 to a non-Auxiliary weapon (ruling 2), raised by native_reliable.gd.
	Fixture.set_grit(hazard, 4)
	SpecFactory.apply_passive_buffs(hazard)
	UnitTile.update_tracking_and_statuses(game.map)
	arm()
	assert_eq(Fixture.reliable(hazard, KIT_ID), 4, 'The card reads RELIABLE 2 + 2.')
	await shoot_miss()
	assert_eq(hostile.current_damage(), 4, 'And a miss deals it.')

func test_each_attack_costs_one_heat():
	arm()
	await Fixture.open_turn(game, hazard)
	var before:int = hazard.core.current.heat
	await shoot_miss()
	assert_eq(hazard.core.current.heat - before, 1, 'HEAT SELF 1.')
	var after_one:int = hazard.core.current.heat
	await shoot_miss()
	assert_eq(hazard.core.current.heat - after_one, 1, 'And again on the next attack - per attack, not per scene.')

func test_range_twenty_is_the_edge():
	var gear := arm()
	var tiles := UnitTargeting.get_tiles_in_range(specific(gear))
	assert_has(tiles, AT_RANGE, 'Twenty tiles away is in range.')
	assert_does_not_have(tiles, PAST_RANGE, 'Twenty-one is not.')

# ------------------------------------------------- the heat is not Emergency Armature's trigger

func test_the_self_heat_does_not_offer_emergency_armature():
	Fixture.equip(hazard, ARMATURE_ID)
	arm()
	var before:int = hazard.core.current.heat
	await shoot_miss()
	assert_eq(hazard.core.current.heat - before, 1, 'LIVENESS: the heat landed.')
	assert_eq(responder.yesno_prompts.size(), 0, 'Our own heat is not damage from a hostile.')

func test_control_the_same_armature_offers_on_a_hostile_hit():
	# The control for the case above: same Kit, same responder, a hostile's kinetic hit.
	Fixture.equip(hazard, ARMATURE_ID)
	responder.yesno_queue.assign([false])
	await game.execute_event(&'event_unit_damage', {
		unit = hazard, number = 3, category = Lancer.DAMAGE_TYPE.KINETIC, target_unit = hostile,
	})
	assert_eq(responder.yesno_prompts.size(), 1, 'The Armature is live and asks.')
