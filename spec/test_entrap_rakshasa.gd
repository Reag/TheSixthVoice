# ENTRAP (a Mask of Many Faces mode, design 3.1, rulings 23-25):
#
#   "As a free action, choose a character within sensors and line of sight. They must make a systems
#    save or only be able to draw line of sight to adjacent spaces. Targets affected this way always
#    consider you within range, threat, and line of sight."
#
# A FREE ActionSystemApplyBuff on the core Kit, available only while the Entrap chip is held. A failed
# Systems save leaves two buffs on the target, both until the Rakshasa's next turn start:
#  - buff_entrap_rakshasa, visible, carrying vanilla BLINDED (ruling 24);
#  - buff_entrap_rakshasa_reach, hidden, ACTION_TILES adding the Rakshasa's tiles to the target's
#    attacks and tech attacks, with no line-of-sight intersection (ruling 25).
# Its REACTIONS are waived in unit_relation.gd_ext.gd (the reach buff never reaches them, design 7).
#
# THE MAP IS WIDE (30x6): the entrapped hostile stands 15 tiles away, outside its own Sensors and far
# beyond its melee threat, but inside the Rakshasa's Sensors 20.
#
# Dice: the save d20 first. Fixture.queue's tail of 3s misses every evasion here.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_entrap_rakshasa.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(2, 2)
const FAR_HOSTILE_TILE := Vector2i(17, 2)   ## distance 15
const BYSTANDER_TILE := Vector2i(14, 2)     ## an ally of the Rakshasa, distance 3 from the far hostile
const NEAR_HOSTILE_TILE := Vector2i(3, 2)   ## adjacent to the Rakshasa
const MID_HOSTILE_TILE := Vector2i(5, 2)    ## distance 3 from the Rakshasa
const SAVE_FAILS := 1
const SAVE_PASSES := 20
const HIT := 18

var game:Gamemaster
var responder
var rakshasa:Unit
var hostile:Unit

func before_each() -> void:
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self, Fixture.WIDE_MAP_SIZE)
	game = built[0]
	responder = built[1]
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, FAR_HOSTILE_TILE)
	Fixture.equip(hostile, Fixture.MELEE)
	# Worm Code asks on every failed save; its heat is not under test except where named.
	responder.chosen_yesnos = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func blinded(unit:Unit) -> bool: return unit.has_status(Lancer.STATUS.BLINDED)
func entrapped(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, Fixture.ENTRAP_BUFF) or UnitCondition.has_buff(unit, Fixture.ENTRAP_REACH_BUFF)

func _action():
	var specific := Fixture.entrap_specific(rakshasa)
	return specific.action if specific != null else null

func entrap_fails() -> void:
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	await Fixture.entrap(game, rakshasa, hostile, SAVE_FAILS)
	assert_true(UnitCondition.has_buff(hostile, Fixture.ENTRAP_BUFF), 'fixture: the save failed and Entrap landed.')

# ---------------------------------------------------------------- shape

func test_entrap_is_a_free_systems_save_buff_action_within_sensors():
	var action = _action()
	assert_not_null(action, 'The core system carries Entrap.')
	if action == null: return
	var specific := Fixture.entrap_specific(rakshasa)
	assert_true(action is ActionSystemApplyBuff, 'An apply-buff system action.')
	assert_eq(action.get_action_type(specific), Lancer.ACTION.FREE, 'A free action.')
	assert_eq(action.get_per_round_hard_limit(specific), 1, 'Free actions are 1/round by the engine.')
	assert_true(action.apply_to_sensors, 'Within Sensors.')
	assert_true(action.requires_line_of_sight(specific), 'And line of sight.')
	assert_true(action.save_to_avoid, 'A save to avoid.')
	assert_eq(action.save_type, Lancer.HASE.SYS, 'A Systems save.')
	assert_eq(action.usage_group, Fixture.ENTRAP_USAGE, "On its own usage group, not the Koremasa's.")
	assert_false(action.is_tech, 'Not tech: the core Kit stays non-tech (design 2.1).')
	assert_true(action.hide_if_disabled, 'Its button is removed outside Entrap mode.')

# ---------------------------------------------------------------- reachability

func test_entrap_can_be_pressed_only_in_entrap_mode():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var specific := Fixture.entrap_specific(rakshasa)
	assert_not_null(specific, 'fixture: the action exists.')
	if specific == null: return
	assert_false(UnitAction.can_activate_gear(specific), 'Holding Drain, Entrap cannot be pressed.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	assert_true(UnitAction.can_activate_gear(specific), 'Holding Entrap, it can.')

func test_any_character_may_be_chosen_but_not_a_drone():
	var ally := Fixture.create_ally(game, BYSTANDER_TILE)
	var drone := Fixture.create_hostile_drone(game, MID_HOSTILE_TILE)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	var tiles := UnitTargeting.get_tiles_targetable(Fixture.entrap_specific(rakshasa))
	assert_has(tiles, hostile.tile(), 'A hostile at 15, inside Sensors.')
	assert_has(tiles, ally.tile(), 'An ally: the card says "a character".')
	assert_does_not_have(tiles, drone.tile(), 'A drone is not a character (rulings row 301).')

func test_a_blinded_rakshasa_can_only_entrap_an_adjacent_character():
	var near := Fixture.create_hostile(game, NEAR_HOSTILE_TILE)
	var mid := Fixture.create_hostile(game, MID_HOSTILE_TILE)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	var before := UnitTargeting.get_tiles_targetable(Fixture.entrap_specific(rakshasa))
	assert_has(before, mid.tile(), 'fixture: unblinded, a hostile at 3 can be chosen.')
	SpecFactory.apply(rakshasa, Lancer.STATUS.BLINDED)
	var after := UnitTargeting.get_tiles_targetable(Fixture.entrap_specific(rakshasa))
	assert_has(after, near.tile(), 'Blinded, the adjacent hostile still can.')
	assert_does_not_have(after, mid.tile(), 'Blinded, the one at 3 cannot (unit_tile.gd:579).')

# ---------------------------------------------------------------- the save

func test_a_failed_save_blinds_the_target():
	await entrap_fails()
	assert_true(blinded(hostile), 'Only able to draw line of sight to adjacent spaces: BLINDED.')

func test_a_passed_save_leaves_the_target_untouched():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	await Fixture.entrap(game, rakshasa, hostile, SAVE_PASSES)
	assert_true(Fixture.d20_was_rolled(), 'fixture: the save was rolled.')
	assert_false(blinded(hostile), 'Not blinded.')
	assert_false(entrapped(hostile), 'No Entrap buff of either kind.')

func test_worm_code_fires_on_the_failure():
	responder.chosen_yesnos = true
	var before := Fixture.heat(hostile)
	await entrap_fails()
	assert_eq(Fixture.heat(hostile) - before, 2, 'Worm Code: the Rakshasa forced this save (ruling 6).')
	assert_eq(Fixture.worm_code_uses(rakshasa), 1, 'Its 1/round is spent.')

# ---------------------------------------------------------------- the target's own attacks

func test_the_entrapped_target_cannot_target_a_non_adjacent_character():
	var bystander := Fixture.create_ally(game, BYSTANDER_TILE)
	assert_has(Fixture.targetable(hostile, Fixture.TECH), bystander.tile(),
		'fixture: before Entrap, its tech attack reaches a character 3 away.')
	await entrap_fails()
	assert_does_not_have(Fixture.targetable(hostile, Fixture.TECH), bystander.tile(),
		'Blinded, it cannot.')

func test_the_entrapped_target_can_tech_attack_the_rakshasa_beyond_its_sensors():
	assert_gt(UnitRelation.distance_between(hostile, rakshasa), hostile.get_sensor_range(),
		"fixture: the Rakshasa is outside the hostile's Sensors.")
	assert_does_not_have(Fixture.targetable(hostile, Fixture.TECH), rakshasa.tile(),
		'fixture: before Entrap, out of reach.')
	await entrap_fails()
	assert_has(Fixture.targetable(hostile, Fixture.TECH), rakshasa.tile(),
		'Entrapped, the Rakshasa is always within range and line of sight.')

func test_the_entrapped_target_can_melee_the_rakshasa_at_fifteen_tiles():
	assert_does_not_have(Fixture.targetable(hostile, Fixture.MELEE), rakshasa.tile(),
		'fixture: before Entrap, out of threat.')
	await entrap_fails()
	assert_has(Fixture.targetable(hostile, Fixture.MELEE), rakshasa.tile(),
		'Within threat, literally: melee reaches it from anywhere (ruling 25, recorded).')

func test_hidden_still_protects_the_rakshasa():
	await entrap_fails()
	assert_has(Fixture.targetable(hostile, Fixture.MELEE), rakshasa.tile(), 'fixture: reachable while visible.')
	SpecFactory.apply(rakshasa, Lancer.STATUS.HIDDEN)
	assert_true(UnitRelation.is_hidden_from(rakshasa, hostile), 'fixture: now hidden from it.')
	assert_does_not_have(Fixture.targetable(hostile, Fixture.MELEE), rakshasa.tile(), 'Hidden: not targetable.')
	assert_true(UnitRelation.get_weapons_that_can_overwatch(hostile, rakshasa).is_empty(), 'Hidden: no Overwatch.')
	assert_true(UnitRelation.get_tech_attacks_that_can_react_against(hostile, rakshasa, true).is_empty(),
		'Hidden: no tech reaction either.')

func test_a_system_that_is_not_an_attack_gets_no_reach():
	# Lock On (vanilla ms_lock_on, basic gear) targets within Sensors and line of sight, and is an
	# ActionSystemApplyStatus, not an ActionAttack. (Scan cannot be the vehicle: an NPC's Scan never
	# targets a player unit at all.) The control half: nothing but range keeps it off the Rakshasa.
	var gear:GearCore = hostile.get_gear(&'ms_lock_on')
	assert_true(GearCore.is_valid(gear), 'fixture: the hostile carries Lock On.')
	if not GearCore.is_valid(gear): return
	var lock_on:Action = gear.get_solo_action()
	assert_false(lock_on is ActionAttack, 'fixture: Lock On is not an attack.')
	assert_true(lock_on.can_target_unit(rakshasa, SpecificAction.create(hostile, gear, lock_on)),
		'fixture: Lock On could target the Rakshasa if it were in range.')
	await entrap_fails()
	assert_has(Fixture.targetable(hostile, Fixture.TECH), rakshasa.tile(), 'fixture: the reach landed.')
	assert_does_not_have(Fixture.targetable(hostile, &'ms_lock_on'), rakshasa.tile(),
		'The card waives range for ATTACKS: Lock On still cannot reach 15 tiles.')

# ---------------------------------------------------------------- the target's reactions

func test_the_entrapped_targets_weapons_can_react_against_the_rakshasa_from_anywhere():
	assert_true(UnitRelation.get_weapons_that_can_overwatch(hostile, rakshasa).is_empty(),
		'fixture: before Entrap, no Overwatch at 15.')
	await entrap_fails()
	assert_false(UnitRelation.get_weapons_that_can_overwatch(hostile, rakshasa).is_empty(),
		'Entrapped: its melee may Overwatch the Rakshasa beyond threat and without sight.')

func test_the_entrapped_targets_tech_attacks_can_react_against_the_rakshasa_from_anywhere():
	assert_true(UnitRelation.get_tech_attacks_that_can_react_against(hostile, rakshasa, true).is_empty(),
		'fixture: before Entrap, beyond its Sensors.')
	await entrap_fails()
	assert_false(UnitRelation.get_tech_attacks_that_can_react_against(hostile, rakshasa, true).is_empty(),
		'Entrapped: its tech attacks may react against the Rakshasa.')

func test_the_waiver_keeps_vanillas_other_gates():
	# A Superheavy weapon may never react (unit_relation.gd:296); the waiver lifts range, threat and
	# sight, nothing else. The control half: the same hostile's ordinary melee IS offered.
	Fixture.equip(hostile, &'mw_combat_drill')
	await entrap_fails()
	var offered:Array[StringName] = []
	for specific:SpecificAction in UnitRelation.get_weapons_that_can_react_against(hostile, rakshasa):
		offered.append(specific.gear.kit.compcon_id)
	assert_has(offered, Fixture.MELEE, 'Control: the ordinary melee weapon is offered.')
	assert_does_not_have(offered, &'mw_combat_drill', 'The Superheavy drill is still refused.')

func test_the_waiver_is_only_toward_the_rakshasa():
	var bystander := Fixture.create_ally(game, Vector2i(10, 2))
	await entrap_fails()
	assert_true(UnitRelation.get_weapons_that_can_overwatch(hostile, bystander).is_empty(),
		'A different character 7 away gets no waiver.')
	assert_true(UnitRelation.get_tech_attacks_that_can_react_against(hostile, bystander, true).is_empty(),
		'Nor from its tech attacks: it is Blinded.')

func test_the_rakshasa_moving_draws_the_entrapped_targets_overwatch():
	var other := Fixture.create_hostile(game, Vector2i(6, 4))
	Fixture.equip(other, Fixture.MELEE)
	await entrap_fails()
	assert_true(UnitRelation.get_weapons_that_can_overwatch(other, rakshasa).is_empty(),
		'Control: the non-Entrapped hostile at 4 has no Overwatch on it.')
	Fixture.queue([HIT])
	await SpecFactory.move(game, rakshasa, Vector2i(2, 4))
	assert_eq(rakshasa.tile(), Vector2i(2, 4), 'fixture: it actually moved.')
	assert_gt(rakshasa.current_damage(), 0, 'A real Overwatch fired from 15 tiles.')

func test_without_entrap_the_same_move_draws_nothing():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENTRAP)
	Fixture.queue([HIT])
	await SpecFactory.move(game, rakshasa, Vector2i(2, 4))
	assert_eq(rakshasa.tile(), Vector2i(2, 4), 'fixture: it actually moved.')
	assert_eq(rakshasa.current_damage(), 0, 'Vanilla: no Overwatch from beyond threat.')

# ---------------------------------------------------------------- lifetime

func test_it_survives_the_targets_own_turn():
	await entrap_fails()
	await SpecFactory.end_turn(game, rakshasa)
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.end_turn(game, hostile)
	assert_true(blinded(hostile), 'Still Blinded after its own turn.')
	assert_true(UnitCondition.has_buff(hostile, Fixture.ENTRAP_REACH_BUFF), 'Still reaching the Rakshasa.')

func test_it_clears_at_the_rakshasas_next_turn_start():
	await entrap_fails()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	assert_false(blinded(hostile), 'No longer Blinded.')
	assert_false(entrapped(hostile), 'Both buffs gone (ruling 15).')
