# ENSORCEL (a Mask of Many Faces mode, design 3.2, rulings 20-22):
#
#   "When you scan, you may take 2 heat to choose one of your Invade options and apply the effects
#    instead of learning any information. This does not count as an attack and cannot apply any heat."
#
# The Ensorcel chip is a VARIANT_ACTIONS buff on vanilla Scan (the Throughbolt shape). The variant swaps
# Scan for action_ensorcel: a Quick tech action on a hostile character within Sensors and line of sight,
# 2 self-heat, whose effect is ONE chosen invade's on_hit and on-hit effects run on the target - no
# event_unit_attack, so no ATTACK reaction, no invade heat and nothing learned. Heat the invade deals
# INSIDE its effect (Sear) is cancelled by a hidden suppressor held on the target while it resolves.
#
# Dice: none - nothing here rolls to hit. Fixture.queue's tail of 3s covers the controls that do.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ensorcel.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(3, 4)
const HOSTILE_TILE := Vector2i(7, 4)
const BESIDE_HOSTILE := Vector2i(8, 4)
const HIT := 18

var game:Gamemaster
var responder
var rakshasa:Unit
var hostile:Unit

func before_each() -> void:
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self)
	game = built[0]
	responder = built[1]
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	responder.chosen_yesnos = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func chip() -> Buff: return ContentLibrary.get_buff(Fixture.MODE_CHIPS[MODE.ENSORCEL])
func ensorcel_action() -> Action:
	var buff := chip()
	return buff.get('ensorcel_action') if buff != null else null
func scan_gear() -> GearCore: return rakshasa.get_gear(Fixture.SCAN)
func unscanned(unit:Unit) -> bool: return Scanpedia.is_anything_unscanned(unit)
func options() -> Array: return load(Fixture.ENSORCEL_SCRIPT).invade_options(rakshasa)

# ---------------------------------------------------------------- shape

func test_the_chip_offers_a_variant_of_scan():
	var buff := chip()
	assert_not_null(buff, 'The Ensorcel chip exists.')
	if buff == null: return
	assert_eq(buff.to, Buff.TO.VARIANT_ACTIONS, 'A variant-action buff (the Throughbolt shape).')
	assert_false(buff.hide_from_player, 'Still the visible mode chip.')
	var action := ensorcel_action()
	assert_not_null(action, 'It carries the replacement action.')
	if action == null: return
	var specific := SpecificAction.create(rakshasa, scan_gear(), action)
	assert_eq(action.get_action_type(specific), Lancer.ACTION.QUICK, 'Quick, as Scan is.')
	assert_true(action.is_tech, 'A tech action, as Scan is.')
	assert_eq(action.get_self_heat_dice(specific.to_context()), '2', 'Take 2 heat.')
	assert_false(action is ActionAttack, 'This does not count as an attack.')

func test_the_variant_is_offered_on_scan_only_in_ensorcel_mode():
	var scan:Action = scan_gear().get_solo_action()
	var specific := SpecificAction.create(rakshasa, scan_gear(), scan)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	assert_true(scan.get_alternate_actions(specific).is_empty(), 'Holding Drain: Scan has no variants.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var groups := scan.get_alternate_actions(specific)
	assert_eq(groups.size(), 1, 'Holding Ensorcel: one variant group.')
	if groups.size() == 1: assert_true(groups[0].is_blankable, 'Blankable: "may".')

func test_the_variant_is_not_offered_on_another_action():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var gear:GearCore = rakshasa.get_gear(Fixture.TECH)
	var invade:Action = gear.get_solo_action()
	assert_true(invade.get_alternate_actions(SpecificAction.create(rakshasa, gear, invade)).is_empty(),
		'Only Scan: an ordinary invade gets nothing.')

func test_it_targets_a_hostile_character_only():
	var ally := Fixture.create_ally(game, Vector2i(3, 6))
	var drone := Fixture.create_hostile_drone(game, Vector2i(5, 6))
	var tiles := UnitTargeting.get_tiles_targetable(SpecificAction.create(rakshasa, scan_gear(), ensorcel_action()))
	assert_has(tiles, hostile.tile(), 'A hostile character.')
	assert_does_not_have(tiles, ally.tile(), 'Not an ally.')
	assert_does_not_have(tiles, drone.tile(), 'Not a drone (rulings row 301).')

# ---------------------------------------------------------------- the effect

func test_fragment_signal_through_ensorcel_applies_its_conditions_and_no_heat():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var hostile_heat := Fixture.heat(hostile)
	var own_heat := Fixture.heat(rakshasa)
	await Fixture.ensorcel(game, rakshasa, hostile, responder)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Impaired, as Fragment Signal applies.')
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'Slowed, as Fragment Signal applies.')
	assert_eq(Fixture.heat(hostile), hostile_heat, 'Cannot apply any heat: not the invade\'s 2.')
	assert_eq(Fixture.heat(rakshasa) - own_heat, 2, 'The Rakshasa takes 2 heat.')

func test_nothing_is_learned():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	assert_true(unscanned(hostile), 'fixture: something to learn.')
	await Fixture.ensorcel(game, rakshasa, hostile, responder)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'fixture: Ensorcel ran.')
	assert_true(unscanned(hostile), 'Instead of learning any information: still unscanned.')

func test_the_plain_scan_still_scans_in_ensorcel_mode():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var own_heat := Fixture.heat(rakshasa)
	await SpecFactory.use_solo(game, rakshasa, Fixture.SCAN, hostile)
	assert_false(unscanned(hostile), 'The blank variant is vanilla Scan: it learns everything.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'And invades nothing.')
	assert_eq(Fixture.heat(rakshasa), own_heat, 'And costs no heat.')

func test_the_ai_never_takes_the_variant():
	# event_gear_activate.gd:83-91: a non-player unit, or SKIP_PLAYER_DECISIONS, takes each group's
	# first entry - the blank, for a blankable group. The flag drives that exact branch.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var own_heat := Fixture.heat(rakshasa)
	await SpecFactory.use_solo(game, rakshasa, Fixture.SCAN, hostile, [Action.FLAG.SKIP_PLAYER_DECISIONS])
	assert_false(unscanned(hostile), 'It scanned.')
	assert_eq(Fixture.heat(rakshasa), own_heat, 'No Ensorcel heat.')

func test_no_attack_reaction_fires():
	# Drain reacts to the Rakshasa's own successful invade (ATTACK POST). Held by hand beside Ensorcel,
	# it would add 1 heat to the target of a real invade - the control half, below.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	SpecFactory.apply_buff(rakshasa, Fixture.MODE_CHIPS[MODE.DRAIN], rakshasa.get_gear(Fixture.CORE_ID))
	var before := Fixture.heat(hostile)
	await Fixture.ensorcel(game, rakshasa, hostile, responder)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'fixture: Ensorcel ran.')
	assert_eq(Fixture.heat(hostile), before, 'Not an attack: Drain never hears it.')

func test_a_real_invade_with_drain_held_does_trigger_it():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	SpecFactory.apply_buff(rakshasa, Fixture.MODE_CHIPS[MODE.DRAIN], rakshasa.get_gear(Fixture.CORE_ID))
	var before := Fixture.heat(hostile)
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_eq(Fixture.heat(hostile) - before, 3, 'Control: the invade\'s 2 and Drain\'s 1.')

func test_sears_heat_is_suppressed():
	Fixture.equip(rakshasa, Fixture.SMITE)
	Fixture.create_ally(game, BESIDE_HOSTILE) # one adjacent character: Sear deals 2 heat
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var before := Fixture.heat(hostile)
	await Fixture.ensorcel(game, rakshasa, hostile, responder, Fixture.SMITE, Fixture.SEAR_ACTION)
	assert_gt(rakshasa.current_damage(), 0, 'fixture: Sear ran (its self-damage landed).')
	assert_eq(Fixture.heat(hostile), before, 'Cannot apply any heat: Sear\'s own heat is cancelled.')
	assert_false(UnitCondition.has_buff(hostile, Fixture.ENSORCEL_SUPPRESSOR), 'The suppressor is gone.')

func test_the_suppressor_cancels_only_heat_from_the_rakshasa():
	# The buff alone, placed by hand exactly as action_ensorcel places it (owned by the Scan gear).
	SpecFactory.apply_buff(hostile, Fixture.ENSORCEL_SUPPRESSOR, scan_gear())
	assert_true(UnitCondition.has_buff(hostile, Fixture.ENSORCEL_SUPPRESSOR), 'fixture: held.')
	var heat := Fixture.heat(hostile)
	await game.execute_event(&'event_unit_damage', {unit = hostile, number = 2,
		category = Lancer.DAMAGE_TYPE.HEAT, target_unit = rakshasa})
	assert_eq(Fixture.heat(hostile), heat, 'Heat from the Rakshasa: cancelled.')
	var other := Fixture.create_ally(game, Vector2i(3, 6))
	await game.execute_event(&'event_unit_damage', {unit = hostile, number = 2,
		category = Lancer.DAMAGE_TYPE.HEAT, target_unit = other})
	assert_eq(Fixture.heat(hostile) - heat, 2, 'Heat from anyone else: lands.')
	var hp := hostile.current_damage()
	await game.execute_event(&'event_unit_damage', {unit = hostile, number = 3,
		category = Lancer.DAMAGE_TYPE.KINETIC, target_unit = rakshasa})
	assert_eq(hostile.current_damage() - hp, 3, 'Other damage from the Rakshasa: lands - the card says heat.')

func test_a_real_sear_deals_its_heat():
	Fixture.equip(rakshasa, Fixture.SMITE)
	Fixture.create_ally(game, BESIDE_HOSTILE)
	# Pinned: the menu's default answer is Drain, whose +1 on a hit would read as Sear's.
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	var before := Fixture.heat(hostile)
	await Fixture.attack_with(game, rakshasa, Fixture.SMITE, Fixture.SEAR_ACTION, hostile, [HIT])
	assert_eq(Fixture.heat(hostile) - before, 4, 'Control: Sear\'s 2 and the invade\'s 2.')

func test_a_real_invade_after_ensorcel_still_deals_heat():
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	await Fixture.ensorcel(game, rakshasa, hostile, responder)
	var before := Fixture.heat(hostile)
	await Fixture.invade(game, rakshasa, hostile, [HIT])
	assert_eq(Fixture.heat(hostile) - before, 2, 'The suppressor does not outlive the Ensorcel.')

func test_a_systems_invade_is_offered():
	Fixture.equip(rakshasa, Fixture.SHRIKE)
	var offered:Array[StringName] = []
	for option in options(): offered.append(option.action.get_id())
	assert_has(offered, Fixture.SHRIKE_ACTION, 'Shrike Code, a system\'s invade, is offered.')
	assert_eq(Fixture.invade_index(options(), Fixture.TECH) >= 0, true, 'And Fragment Signal.')

func test_a_systems_invade_applies_its_effect():
	Fixture.equip(rakshasa, Fixture.SHRIKE)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	await Fixture.ensorcel(game, rakshasa, hostile, responder, Fixture.SHRIKE, Fixture.SHRIKE_ACTION)
	assert_true(UnitCondition.has_buff(hostile, &'buff_shrike_code'), 'Shrike Code\'s effect landed.')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'And not Fragment Signal\'s.')

func test_a_talents_invade_is_offered_and_applies():
	# Vanilla Hacker rank 2's Hack/Slash is an invade on a TALENT, which get_all_tech_attacks (equipped
	# attacks plus basics) never lists - get_all_gear(true) does. The case design ruling 21 names.
	rakshasa.core.pilot.set_talent_to_rank(&'t_hacker', 2)
	rakshasa.core.full_repair()
	SpecFactory.apply_passive_buffs(rakshasa)
	assert_gt(Fixture.invade_index(options(), &'tal_safe_cracker', &'action_hack_slash'), -1,
		'Hack/Slash, a talent\'s invade, is offered.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	await Fixture.ensorcel(game, rakshasa, hostile, responder, &'tal_safe_cracker', &'action_hack_slash')
	assert_true(UnitCondition.has_buff(hostile, &'buff_hack_slash'), 'Hack/Slash\'s effect landed.')

func test_the_menu_answer_decides_which_invade_runs():
	# The pick must be honoured, not just the first entry: with Smite equipped, Fragment Signal is NOT
	# the first option (equipped gear lists before basic gear).
	Fixture.equip(rakshasa, Fixture.SMITE)
	assert_gt(Fixture.invade_index(options(), Fixture.TECH), 0, 'fixture: Fragment Signal is not first.')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.ENSORCEL)
	await Fixture.ensorcel(game, rakshasa, hostile, responder, Fixture.TECH)
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'Fragment Signal ran.')
	assert_eq(rakshasa.current_damage(), 0, 'Sear did not (no self-damage).')

func test_a_non_invade_tech_attack_is_not_offered():
	Fixture.equip(rakshasa, Fixture.MARKERLIGHT)
	for option in options():
		assert_ne(option.action.get_id(), Fixture.MARKERLIGHT_ACTION, 'Markerlight is not an invade.')
	assert_gt(options().size(), 0, 'fixture: the list is not empty.')
