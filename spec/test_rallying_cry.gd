# BRIGID-CLASS NHP and RALLYING CRY (Hazard rank III system, SP4 Task 2, design rulings 13-14).
# The barkset, portrait and name the Kit hands the pilot are spec/test_brigid_nhp.gd.
#
#   Brigid-Class NHP. LIMITED 4, AI, UNIQUE. SP 2.
#   Your mech gains the AI tag and the Rallying Cry quick action.
#   Rallying Cry (Quick): 1/scene, expend a charge and choose an allied mech character within
#   sensors. They clear Impaired, Shredded, and Slowed if they weren't self-inflicted. If they are
#   prone, they stand up. They also clear 1d6+1 Heat.
#
# "IF THEY WEREN'T SELF-INFLICTED" IS THE ENGINE'S OWN RULE, not ours: clear_status_via_ability ->
# ability_can_clear keeps a status whose source is a gear on the unit's OWN loadout and clears every
# other source (unit_condition.gd:472-483; StatusCondition.is_unit_owner, status_condition.gd:41-44).
# So the two cases below differ only in the SOURCE id the status carries.
#
# PRONE IS A DIFFERENT CALL. Prone is not a condition to the engine, so clear_status_via_ability can
# never clear it for anyone; the stand-up is UnitCondition.clear_status, Remote Reboot's shape.
#
# 1/SCENE IS Kit.uses_per_scene = 1, refused at unit_action.gd:147 with REASON.PER_SCENE, and reset
# by GearCore.short_repair (gear_core.gd:133) - which leaves the CHARGES alone, so four charges are
# four scenes.
#
# THE DICE: the turn is opened BEFORE queueing, then the one 1d6 of the heat.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rallying_cry.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

const KIT_ID := &'ms_brigid_class_nhp'
const ACTION_ID := &'action_rallying_cry'

const HAZARD_TILE := Vector2i(4, 6)
const ALLY_TILE := Vector2i(6, 6)
const HOSTILE_TILE := Vector2i(8, 6)
const DRONE_TILE := Vector2i(5, 8)
## The Hazard's Sensors are 10: ten tiles east is in, eleven is out.
const AT_SENSORS := Vector2i(14, 6)
const PAST_SENSORS := Vector2i(15, 6)

var game:Gamemaster
var hazard:Unit
var ally:Unit
var hostile:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	ally = Fixture.create_ally(game, ALLY_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	Fixture.equip(hazard, KIT_ID)
	# A weapon on the hostile gives its statuses a real, foreign gear source.
	Fixture.equip(hostile, Fixture.MAIN_RIFLE)
	# ...and one on the ally gives it a source of its OWN, for the self-inflicted case.
	Fixture.equip(ally, Fixture.MAIN_RIFLE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func gear() -> GearCore: return hazard.get_gear(KIT_ID)
func action() -> Action: return gear().kit.get_action(ACTION_ID)
func specific() -> SpecificAction: return SpecificAction.create(hazard, gear(), action())

func reason() -> UnitAction.REASON:
	return UnitAction.get_gear_unavailable_reason(specific())

func hostile_source() -> StringName: return hostile.get_gear(Fixture.MAIN_RIFLE).persistent_id
func own_source(unit:Unit) -> StringName: return unit.get_gear(Fixture.MAIN_RIFLE).persistent_id

func inflict(unit:Unit, status:StringName, source:StringName) -> void:
	UnitCondition.apply_status(SpecFactory.dummy_event(), unit, status, Lancer.UNTIL.MANUAL, source)

## Press Rallying Cry on a target, the 1d6 of its heat cheated to `die`.
func cry(target:Unit, die:int = 1) -> void:
	await Fixture.open_turn(game, hazard)
	Fixture.queue([die])
	await SpecFactory.use(game, hazard, KIT_ID, ACTION_ID, target)

# ---------------------------------------------------------------- the card

func test_the_kit_is_the_cards_profile():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The system loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.charges_max, 4, 'LIMITED 4.')
	assert_eq(kit.uses_per_scene, 1, '1/scene.')
	assert_true(kit.is_unique(), 'UNIQUE.')
	assert_true(kit.is_ai(), 'AI - "your mech gains the AI tag" is this bit.')
	assert_true(kit.is_nhp(),
		'NHP - the card does not print it, but has_nhp_copilot() reads it and nothing else, and it '
		+ 'is what lets Brigid speak and show her face (test_brigid_nhp.gd). The Morrigan\'s 13.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var cry_action := kit.get_action(ACTION_ID) as ActionSystemTargetUnit
	assert_not_null(cry_action, 'Rallying Cry is an ActionSystemTargetUnit.')
	if cry_action == null: return
	assert_eq(cry_action.action_type, Lancer.ACTION.QUICK, 'A quick action.')
	assert_false(cry_action.is_tech, 'Not a tech action - the card says quick action, not quick tech.')
	assert_true(cry_action.target_range_is_sensors, 'Within Sensors.')

func test_the_names_resolve_from_our_translation():
	assert_eq(X.tr('gear.%s.name' % KIT_ID), 'Brigid-Class NHP', 'The Kit\'s name row.')
	assert_eq(X.tr('gear.%s.%s.name' % [KIT_ID, ACTION_ID]), 'Rallying Cry', 'The action\'s name row.')
	assert_true(X.tr('gear.%s.flavor' % KIT_ID).begins_with('The Brigid-Class NHP was designed'), 'The flavour row.')

# ---------------------------------------------------------------- what it clears

func test_it_clears_impaired_shredded_and_slowed_from_an_enemy():
	for status:StringName in [Lancer.STATUS.IMPAIRED, Lancer.STATUS.SHREDDED, Lancer.STATUS.SLOWED]:
		inflict(ally, status, hostile_source())
	await cry(ally)
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'Impaired cleared.')
	assert_false(ally.has_status(Lancer.STATUS.SHREDDED), 'Shredded cleared.')
	assert_false(ally.has_status(Lancer.STATUS.SLOWED), 'Slowed cleared.')

func test_it_clears_a_sourceless_status_too():
	# A status with no gear source (terrain, a scripted effect) is not self-inflicted either.
	inflict(ally, Lancer.STATUS.SLOWED, &'')
	await cry(ally)
	assert_false(ally.has_status(Lancer.STATUS.SLOWED), 'A sourceless Slowed is cleared.')

func test_it_keeps_a_slowed_the_ally_applied_to_itself():
	inflict(ally, Lancer.STATUS.SLOWED, own_source(ally))
	inflict(ally, Lancer.STATUS.IMPAIRED, hostile_source())
	await cry(ally)
	assert_false(ally.has_status(Lancer.STATUS.IMPAIRED), 'LIVENESS: the enemy\'s Impaired went.')
	assert_true(ally.has_status(Lancer.STATUS.SLOWED), 'The self-inflicted Slowed stays.')

func test_it_leaves_other_conditions_alone():
	inflict(ally, Lancer.STATUS.JAMMED, hostile_source())
	await cry(ally)
	assert_true(ally.has_status(Lancer.STATUS.JAMMED), 'Jammed is not on the card.')

func test_it_stands_a_prone_ally():
	inflict(ally, Lancer.STATUS.PRONE, hostile_source())
	await cry(ally)
	assert_false(ally.has_status(Lancer.STATUS.PRONE), 'They stand up.')

func test_it_stands_even_a_self_inflicted_prone():
	# "If they are prone, they stand up" carries no self-inflicted clause.
	inflict(ally, Lancer.STATUS.PRONE, own_source(ally))
	await cry(ally)
	assert_false(ally.has_status(Lancer.STATUS.PRONE), 'Prone from any source is stood up.')

func test_it_clears_one_d6_plus_one_heat():
	ally.core.current.heat = 4
	await cry(ally, 2)
	assert_eq(ally.core.current.heat, 1, '1d6 (cheated 2) + 1 = 3 cleared from 4.')

func test_the_heat_clear_is_capped_at_current_heat():
	ally.core.current.heat = 2
	await cry(ally, 6)
	assert_eq(ally.core.current.heat, 0, '7 to clear, 2 to clear it from: heat 0, never negative.')

# ---------------------------------------------------------------- what it costs

func test_it_spends_a_charge_and_the_scene_use():
	await cry(ally)
	assert_eq(gear().charges_current, 3, 'One of four charges expended.')
	assert_eq(reason(), UnitAction.REASON.PER_SCENE, 'The scene\'s use is spent.')

func test_a_target_with_nothing_to_clear_still_spends_both():
	# The card gates nothing on the target's state.
	await cry(ally)
	assert_eq(gear().charges_current, 3, 'The charge is spent regardless.')

func test_a_second_use_in_the_scene_is_refused_with_charges_left():
	await cry(ally)
	await SpecFactory.end_turn(game, hazard)
	await SpecFactory.start_turn(game, hazard)
	assert_true(gear().has_charges_left(), 'fixture: three charges left.')
	assert_eq(reason(), UnitAction.REASON.PER_SCENE, 'A new turn does not reopen it; the scene does.')

func test_a_short_repair_makes_it_available_again_and_keeps_the_charges():
	await cry(ally)
	await SpecFactory.end_turn(game, hazard)
	hazard.core.short_repair()
	await SpecFactory.start_turn(game, hazard)
	assert_eq(reason(), UnitAction.REASON.NONE, 'A new scene, a new use.')
	assert_eq(gear().charges_current, 3, 'A short repair does not refill the charges.')

func test_with_no_charges_it_is_refused():
	gear().charges_current = 0
	await Fixture.open_turn(game, hazard)
	assert_eq(reason(), UnitAction.REASON.NO_CHARGES, 'Four charges, then nothing.')

func test_the_empty_kit_is_not_destructible():
	# An empty LIMITED system is not a structure-damage target (unit_printer.gd:311-319, vanilla's
	# rule); nothing on this card asks otherwise.
	assert_has(UnitPrinter.get_destructable_gear([gear()] as Array[GearCore]), gear(),
		'LIVENESS: with charges left it is a destruction candidate.')
	gear().charges_current = 0
	assert_true(UnitPrinter.get_destructable_gear([gear()] as Array[GearCore]).is_empty(),
		'With none it is not.')

# ---------------------------------------------------------------- who it can choose

func test_an_allied_mech_within_sensors_is_a_target():
	var edge := Fixture.create_ally(game, AT_SENSORS)
	assert_true(action().can_target_unit(ally, specific()), 'The adjacent ally.')
	assert_has(UnitTargeting.get_tiles_targetable(specific()), AT_SENSORS, 'Ten tiles out, at Sensors.')
	assert_true(Unit.is_valid(edge), 'fixture: the edge ally exists.')

func test_an_ally_outside_sensors_is_not():
	Fixture.create_ally(game, PAST_SENSORS)
	assert_does_not_have(UnitTargeting.get_tiles_targetable(specific()), PAST_SENSORS, 'Eleven tiles out is past Sensors.')

func test_self_is_not_a_target():
	assert_false(action().can_target_unit_self(specific()), 'The archetype\'s self flag is off.')
	assert_false(action().can_target_unit(hazard, specific()), 'And the filter refuses the Hazard itself.')

func test_a_hostile_is_not_a_target():
	assert_false(action().can_target_unit(hostile, specific()), 'Not an enemy.')

func test_an_allied_drone_is_not_a_target():
	var drone := Fixture.create_drone(game, DRONE_TILE)
	assert_true(drone.is_character(), 'fixture: the engine calls a drone a character...')
	assert_false(drone.is_mech(), '...and not a mech, which is the card\'s word.')
	assert_false(action().can_target_unit(drone, specific()), 'The filter refuses it.')
	inflict(drone, Lancer.STATUS.SLOWED, hostile_source())
	await cry(drone)
	assert_true(drone.has_status(Lancer.STATUS.SLOWED), 'And handing it to the action by hand clears nothing.')

# ---------------------------------------------------------------- the licence

func test_the_licence_grants_it_at_rank_three():
	var license:UnlockTree = ContentLibrary.get_license_tree(Fixture.LICENSE_ID)
	assert_not_null(license, 'li_hazard loads.')
	if license == null: return
	var ids:Array = license.rank_3.granted_gear.map(func(k:Kit) -> StringName: return k.compcon_id)
	assert_has(ids, KIT_ID, 'Rank 3.')
