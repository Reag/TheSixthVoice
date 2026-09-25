# MAKIBISHI MAGNETS (Koremasa rank I, design 3.1, rulings 21-25):
#
#   "Effect: On use, you may choose to expend a second charge, if you do, you may deploy a second mine
#    in valid space.
#    Throw Magnets (Quick): Throw Magnets at a character within Range 5. They must make an agility save
#    or have the Magnets attach to them. Characters to whom they are attached are impaired and take 1
#    AP Kinetic damage for each space they voluntarily move up to a maximum of 5. Characters can detach
#    makibishi magnets from themselves by passing an Agility save as a quick action on their turn. All
#    magnets detach at the end of the scene.
#    Deployable: Makibishi Magnets (Mine): When a character moves over or adjacent to this mine, they
#    must make an Agility save or it attaches to them and deals 1d3 AP Kinetic damage. [...]"
#
# ONE ATTACHED BUFF for both routes, buff_makibishi_attached, from the MAKIBISHI KIT (not the mine):
# Impaired via applies_statuses, MANUAL, not cleared on the owner's death, 1 AP Kinetic per VOLUNTARY
# step (the Barricade's Drag Down), capped at 5 PER TURN of the victim (ruling 21, the Excommunicate
# key), and carrying the victim's own detach as situational gear (the Hornet's javelins). A second
# magnet from the same Koremasa REPLACES the first (ruling 22). The mine is vanilla's (arm at a
# character's end of turn, trigger within 1, allies too - ruling 25), and its detonation reaches the
# triggering character only. The second mine is an Iskander Mine Deployers reaction on a mine DEPLOY
# only (ruling 24), costing the second charge.
#
# DICE: a hostile's Agility save is a bare d20 against the Koremasa's save target 10 - 5 fails, 15
# passes. The mine's 1d3 follows its save. Fixture.queue tails with 3s.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_makibishi_magnets.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const KOREMASA_TILE := Vector2i(4, 5)
const VICTIM_TILE := Vector2i(8, 5)   ## 4 away: inside Range 5
const MINE_TILE := Vector2i(5, 5)     ## adjacent to the Koremasa (deploy range 1)
const SECOND_MINE_TILE := Vector2i(3, 5) ## the other side: not adjacent to the first
const WALKER_START := Vector2i(5, 9)

const FAIL := 5
const PASS := 15

var game:Gamemaster
var responder
var koremasa:Unit
var victim:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.MAKIBISHI_ID)
	victim = Fixture.create_hostile(game, VICTIM_TILE)
	# ARMOR 1, so "AP" is measured rather than assumed: a non-AP point would be eaten whole.
	victim.core.frame.stat.armor = 1
	victim.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.chosen_move_tile = Tile.INVALID
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

func throw_at(target:Unit, save_d20:int) -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue([save_d20])
	await SpecFactory.use(game, koremasa, Fixture.MAKIBISHI_ID, Fixture.THROW_MAGNETS_ACTION, target)

func attached(unit:Unit) -> Array[BuffCore]:
	return UnitCondition.get_buffs(unit, Fixture.MAKIBISHI_BUFF)

func is_attached(unit:Unit) -> bool:
	return not attached(unit).is_empty()

func damage_taken(unit:Unit) -> int:
	return unit.current_damage()

## Walk `unit` to `tile` on its own (open) turn: a VOLUNTARY move, one event, one step per tile.
func walk(unit:Unit, tile:Vector2i) -> void:
	await SpecFactory.move(game, unit, tile)

func open_victims_turn() -> void:
	if koremasa.state.is_taking_turn: await SpecFactory.end_turn(game, koremasa)
	await Fixture.cycle_turn(game, victim)

func detaches_offered(unit:Unit) -> Array[SpecificAction]:
	return UnitAction.get_situational_actions(unit).filter(func(specific:SpecificAction) -> bool:
		return specific.action.get_id() == Fixture.DETACH_ACTION
	)

func deploy_mine(tile:Vector2i, second_tile:Vector2i = Tile.INVALID) -> void:
	await Fixture.open_turn(game, koremasa)
	# The second-mine offer is the Iskander's choose_and_use: with one candidate the menu is skipped
	# (common_action_util.gd:660) and the deploy's own targeting is the offer - a compcon plan, whose
	# ABORTED answer is the decline.
	responder.chosen_plan_queue.clear()
	if second_tile == Tile.INVALID: responder.chosen_plan_queue.append(CompconPlan.create_aborted())
	else: responder.chosen_plan_queue.append(CompconPlan.create([second_tile]))
	await SpecFactory.use(game, koremasa, Fixture.MAKIBISHI_ID, Fixture.MAKIBISHI_MINE_ACTION, [tile])
	responder.chosen_plan_queue.clear()

func mines() -> Array[Unit]:
	return Fixture.units_of_frame(game, Fixture.MAKIBISHI_MINE_FRAME)

# ---------------------------------------------------------------- wiring

func test_the_kit_is_limited_2_with_a_throw_a_mine_and_a_hidden_second_mine():
	var kit:Kit = ContentLibrary.get_kit(Fixture.MAKIBISHI_ID)
	assert_true(Kit.is_valid(kit), 'ms_makibishi_magnets is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.charges_max, 2, 'LIMITED 2.')
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_eq(kit.system_tags, 0, 'Not UNIQUE.')
	var throw:Action = kit.get_action(Fixture.THROW_MAGNETS_ACTION)
	var mine:Action = kit.get_action(Fixture.MAKIBISHI_MINE_ACTION)
	var second:Action = kit.get_action(Fixture.SECOND_MINE_ACTION)
	assert_true(throw is ActionSystemApplyBuff, 'Throw Magnets applies a buff.')
	assert_true(mine is ActionSystemDeploy, 'The mine is a deploy.')
	assert_true(second is ActionReactionSelf, 'The second mine is a self-reaction.')
	if not throw is ActionSystemApplyBuff or not mine is ActionSystemDeploy or not second is ActionReactionSelf: return
	assert_eq(kit.actions.front(), throw, 'Throw Magnets FIRST: get_solo_action is the detach save\'s applier (action_system_clear_buff.gd:92).')
	assert_eq(throw.action_type, Lancer.ACTION.QUICK, 'Throw: Quick.')
	assert_eq(throw.apply_range, 5, 'Range 5.')
	assert_true(throw.save_to_avoid, 'Save to avoid...')
	assert_eq(throw.save_type, Lancer.HASE.AGI, '...an Agility save.')
	assert_true(throw.metatags.has(&'grenade'), 'GRENADE.')
	assert_eq(mine.action_type, Lancer.ACTION.QUICK, 'Mine: Quick to deploy.')
	assert_true(mine.deployable_frame.is_mine, 'A mine.')
	assert_eq(throw.usage_group, mine.usage_group, 'One charge pool, one usage group.')
	assert_false(second.consumes_rxn, 'The second mine costs no reaction.')
	assert_false(second.show_in_tooltip(kit), 'And is not on the card.')

func test_the_attached_buff_is_visible_manual_and_impairs():
	var buff:Buff = ContentLibrary.get_buff(Fixture.MAKIBISHI_BUFF)
	assert_not_null(buff, 'buff_makibishi_attached is in the buffs index.')
	if buff == null: return
	assert_false(buff.hide_from_player, 'VISIBLE: the victim wears the magnets.')
	assert_eq(buff.until, Lancer.UNTIL.MANUAL, 'MANUAL: "all magnets detach at the end of the scene".')
	assert_eq(buff.applies_statuses, [Lancer.STATUS.IMPAIRED] as Array[StringName], 'Impaired.')
	assert_false(buff.is_cleared_on_owner_death(), 'Magnets outlive the Koremasa (ruling 25).')

## ONE GLYPH FAMILY (design 6, the icon-glyph-families directive): the throw, the mine, the attached
## buff and the detach. The detach's Kit and the mine's trait Kit wear the Makibishi Kit's own glyph
## rather than two of their own (frame-close finding M1).
func test_the_detach_and_the_mines_trait_wear_the_makibishi_glyph():
	var kit:Kit = ContentLibrary.get_kit(Fixture.MAKIBISHI_ID)
	var detach_kit:Kit = ContentLibrary.get_kit(Fixture.DETACH_KIT)
	var detonation_kit:Kit = ContentLibrary.get_kit(&'mt_makibishi_magnets_detonation')
	assert_true(Kit.is_valid(kit) and Kit.is_valid(detach_kit) and Kit.is_valid(detonation_kit), 'fixture: all three Kits load.')
	if not (Kit.is_valid(kit) and Kit.is_valid(detach_kit) and Kit.is_valid(detonation_kit)): return
	assert_not_null(kit.icon_override, 'fixture: the Makibishi Kit has its glyph.')
	assert_eq(detach_kit.icon_override, kit.icon_override, 'The detach Kit wears the Makibishi glyph.')
	assert_eq(detonation_kit.icon_override, kit.icon_override, 'The mine\'s trait wears the Makibishi glyph.')
	var detach:Action = detach_kit.get_action(Fixture.DETACH_ACTION)
	assert_eq(detach.get_icon(detach_kit), kit.icon_override, 'And so does the detach button the victim sees.')

# ---------------------------------------------------------------- Throw Magnets

func test_a_failed_agility_save_attaches_and_impairs():
	await throw_at(victim, FAIL)
	assert_true(is_attached(victim), 'Attached.')
	assert_true(victim.has_status(Lancer.STATUS.IMPAIRED), 'Impaired.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 1, 'One charge spent.')
	var buff := attached(victim)
	if buff.is_empty(): return
	assert_eq(buff[0].from_gear, koremasa.get_gear(Fixture.MAKIBISHI_ID).persistent_id, 'From the Makibishi Kit.')

func test_a_passed_save_attaches_nothing_but_spends_the_charge():
	await throw_at(victim, PASS)
	assert_false(is_attached(victim), 'Not attached.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 1, 'The throw still spent a charge.')

func test_a_second_magnet_replaces_the_first():
	await throw_at(victim, FAIL)
	await throw_at(victim, FAIL)
	assert_eq(attached(victim).size(), 1, 'No stacking (ruling 22).')

func test_throw_magnets_cannot_target_a_drone():
	var drone := Fixture.create_hostile_drone(game, Vector2i(6, 7))
	var specific := SpecificAction.from_id(koremasa, Fixture.MAKIBISHI_ID, Fixture.THROW_MAGNETS_ACTION)
	assert_false(specific.action.can_target_unit(drone, specific), 'Not a drone (ruling 25, recorded).')
	assert_true(specific.action.can_target_unit(victim, specific), 'Control: a hostile mech.')

func test_throw_magnets_does_not_offer_a_second_mine():
	responder.gear_queue.clear()
	await throw_at(victim, FAIL)
	assert_true(mines().is_empty(), 'Only a mine DEPLOY offers a second mine (ruling 24).')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 1, 'One charge, not two.')

# ---------------------------------------------------------------- per step (rulings 21, 23)

func test_each_voluntary_space_costs_1_ap_kinetic():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var before := damage_taken(victim)
	await walk(victim, VICTIM_TILE + Vector2i(0, 3))
	assert_eq(damage_taken(victim) - before, 3, 'Three spaces, three AP points through armor 1.')

func test_the_cap_is_5_per_turn():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var before := damage_taken(victim)
	await walk(victim, VICTIM_TILE + Vector2i(0, 4))
	await walk(victim, VICTIM_TILE + Vector2i(3, 4))
	assert_eq(damage_taken(victim) - before, 5, 'Seven spaces in one turn: capped at 5.')
	# The victim's NEXT turn, in the next round: the Excommunicate key is round + activations, and a
	# second turn start inside one round leaves activations at 0 (event_turn_start.gd:73).
	await SpecFactory.end_turn(game, victim)
	await Fixture.new_round(game)
	await Fixture.cycle_turn(game, victim)
	before = damage_taken(victim)
	await walk(victim, VICTIM_TILE + Vector2i(3, 2))
	assert_eq(damage_taken(victim) - before, 2, 'A new turn: the cap is fresh.')

## Frame-close finding I-2: a same-source magnet landing mid-turn REPLACES the old buff core
## (unit_condition.gd:741-747), and the cap's counter must survive that, or one turn costs up to 10.
func test_the_cap_survives_a_same_source_magnet_replacing_the_first_mid_turn():
	await throw_at(victim, FAIL) # the first charge
	await Fixture.cycle_turn(game, koremasa) # throw and deploy share a usage group: one per turn
	await deploy_mine(MINE_TILE) # the second charge; armed at the Koremasa's end of turn below
	assert_eq(mines().size(), 1, 'fixture: one mine laid.')
	await open_victims_turn()
	var before := damage_taken(victim)
	await walk(victim, VICTIM_TILE + Vector2i(0, 5)) # (8,10): five spaces, never within 1 of the mine
	assert_eq(damage_taken(victim) - before, 5, 'fixture: five spaces, capped.')
	# The victim is already Impaired, so its save also rolls a d6 of difficulty: 2 for that and for
	# the mine's 1d3, whichever comes first.
	Fixture.queue([FAIL, 2, 2])
	await walk(victim, MINE_TILE + Vector2i(1, 1)) # (6,6): adjacent to the mine - it goes off
	assert_true(mines().is_empty(), 'fixture: the mine went off.')
	assert_eq(attached(victim).size(), 1, 'fixture: one magnet - the mine\'s replaced the thrown one (ruling 22).')
	await walk(victim, MINE_TILE + Vector2i(1, 4)) # (6,9): three more voluntary spaces
	assert_eq(damage_taken(victim) - before - 2, 5, 'Per-step damage this turn, less the mine\'s 1d3 (2): still capped at 5 (ruling 21).')

func test_an_involuntary_move_costs_nothing():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var before := damage_taken(victim)
	await SpecFactory.move(game, victim, VICTIM_TILE + Vector2i(0, 3), MovementType.create_for_involuntary(victim))
	assert_eq(victim.tile(), VICTIM_TILE + Vector2i(0, 3), 'fixture: it was moved.')
	assert_eq(damage_taken(victim) - before, 0, 'Only VOLUNTARY spaces cost damage.')

func test_a_voluntary_teleport_costs_1():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var before := damage_taken(victim)
	var type := MovementType.create(victim, true)
	type.teleport = true
	await SpecFactory.move(game, victim, VICTIM_TILE + Vector2i(0, 4), type)
	assert_eq(victim.tile(), VICTIM_TILE + Vector2i(0, 4), 'fixture: it teleported.')
	assert_eq(damage_taken(victim) - before, 1, 'A teleport is one step (ruling 23).')

# ---------------------------------------------------------------- the detach

func test_the_victim_is_offered_exactly_one_detach():
	await throw_at(victim, FAIL)
	var bystander := Fixture.create_hostile(game, Vector2i(10, 8))
	await Fixture.cycle_turn(game, koremasa) # one throw per turn: the same system twice is refused
	await throw_at(bystander, FAIL)
	assert_true(is_attached(bystander), 'LIVENESS: a second victim carries magnets too (caught by mutation M9).')
	await open_victims_turn()
	assert_eq(detaches_offered(victim).size(), 1, 'One detach, however many magnets are on the board (ruling 22).')
	var offered := detaches_offered(koremasa)
	assert_true(offered.is_empty(), 'Nobody without magnets is offered one.')

func test_a_passed_detach_save_removes_the_magnets():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var offered := detaches_offered(victim)
	assert_eq(offered.size(), 1, 'LIVENESS: offered.')
	if offered.is_empty(): return
	Fixture.queue([PASS])
	await SpecFactory.use_specific(game, offered.front())
	assert_false(is_attached(victim), 'Detached.')
	assert_false(victim.has_status(Lancer.STATUS.IMPAIRED), 'No longer Impaired.')

func test_a_failed_detach_save_keeps_them():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var offered := detaches_offered(victim)
	if offered.is_empty():
		fail_test('not offered')
		return
	Fixture.queue([FAIL])
	await SpecFactory.use_specific(game, offered.front())
	assert_true(is_attached(victim), 'Still attached.')

func test_the_magnets_survive_the_koremasas_death_and_can_still_be_detached():
	await throw_at(victim, FAIL)
	await SpecFactory.end_turn(game, koremasa)
	await game.execute_event(&'event_unit_die', {unit = koremasa})
	assert_true(is_attached(victim), 'Still attached after the Koremasa is gone.')
	await Fixture.cycle_turn(game, victim)
	assert_eq(detaches_offered(victim).size(), 1, 'And the victim can still try to get them off.')

## Frame-close finding I-1: the detach is spent BEFORE its save (action_system_clear_buff.gd:72),
## and the engine's per-turn usage reset never reaches a buff's situational gear
## (unit_action.gd:85-88), so a failed detach used to lock it for the rest of the scene. The card:
## "by passing an Agility save as a quick action on their turn" - every turn.
func test_a_failed_detach_can_be_tried_again_on_the_next_turn():
	await throw_at(victim, FAIL)
	await open_victims_turn()
	var offered := detaches_offered(victim)
	assert_eq(offered.size(), 1, 'LIVENESS: offered.')
	if offered.is_empty(): return
	Fixture.queue([FAIL])
	await SpecFactory.use_specific(game, offered.front())
	assert_true(is_attached(victim), 'fixture: the detach failed.')
	assert_eq(detaches_offered(victim).size(), 0, 'Control: a quick action once a turn - not again this turn.')
	await SpecFactory.end_turn(game, victim)
	await Fixture.new_round(game)
	await Fixture.cycle_turn(game, victim)
	offered = detaches_offered(victim)
	assert_eq(offered.size(), 1, 'The victim\'s next turn: offered again.')
	if offered.is_empty(): return
	Fixture.queue([PASS])
	await SpecFactory.use_specific(game, offered.front())
	assert_false(is_attached(victim), 'And it works: detached.')

## With the Koremasa gone the save has no applier, so the archetype falls back to a DC 10 Agility
## check (action_system_clear_buff.gd:78-82, ruling 25). The Koremasa's save target is raised to 18
## first, so a 15 passes ONLY through the fallback: against the Koremasa it would fail.
func test_with_the_koremasa_gone_the_detach_is_a_dc_10_check_passed():
	FrameIsolation.isolate_frame(koremasa)
	koremasa.core.frame.stat.save_target = 18
	await throw_at(victim, FAIL)
	await SpecFactory.end_turn(game, koremasa)
	await game.execute_event(&'event_unit_die', {unit = koremasa})
	await Fixture.cycle_turn(game, victim)
	var offered := detaches_offered(victim)
	assert_eq(offered.size(), 1, 'LIVENESS: offered.')
	if offered.is_empty(): return
	Fixture.queue([PASS])
	await SpecFactory.use_specific(game, offered.front())
	assert_false(is_attached(victim), '15 (less Impaired\'s difficulty) against DC 10: detached.')

func test_with_the_koremasa_gone_the_detach_is_a_dc_10_check_failed():
	await throw_at(victim, FAIL)
	await SpecFactory.end_turn(game, koremasa)
	await game.execute_event(&'event_unit_die', {unit = koremasa})
	await Fixture.cycle_turn(game, victim)
	var offered := detaches_offered(victim)
	assert_eq(offered.size(), 1, 'LIVENESS: offered.')
	if offered.is_empty(): return
	Fixture.queue([FAIL])
	await SpecFactory.use_specific(game, offered.front())
	assert_true(is_attached(victim), '5 against DC 10: still attached.')

# ---------------------------------------------------------------- the mine (rulings 24, 25)

func test_a_mine_attaches_and_deals_1d3_ap_to_whoever_walks_by():
	await deploy_mine(MINE_TILE)
	assert_eq(mines().size(), 1, 'One mine laid.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 1, 'One charge spent.')
	var walker := Fixture.create_hostile(game, WALKER_START)
	walker.core.frame.stat.armor = 1
	walker.core.full_repair()
	await SpecFactory.end_turn(game, koremasa) # arms the mine (any character's end of turn)
	await Fixture.cycle_turn(game, walker)
	Fixture.queue([FAIL, 2])
	await walk(walker, MINE_TILE + Vector2i(0, 1))
	assert_true(is_attached(walker), 'Attached on a failed save.')
	assert_eq(walker.tile(), MINE_TILE + Vector2i(0, 1), 'fixture: it arrived.')
	assert_eq(damage_taken(walker), 2, '1d3 (2) AP from the mine - and nothing for the step that tripped it, taken before it was attached.')
	assert_true(mines().is_empty(), 'The mine is spent.')

func test_a_passed_save_against_the_mine_attaches_nothing():
	await deploy_mine(MINE_TILE)
	var walker := Fixture.create_hostile(game, WALKER_START)
	await SpecFactory.end_turn(game, koremasa)
	await Fixture.cycle_turn(game, walker)
	Fixture.queue([PASS, 2])
	await walk(walker, MINE_TILE + Vector2i(0, 1))
	assert_false(is_attached(walker), 'Not attached.')
	assert_eq(damage_taken(walker), 0, 'And no damage.')

func test_an_ally_trips_the_mine_too():
	await deploy_mine(MINE_TILE)
	var ally := Fixture.create_ally(game, WALKER_START)
	await SpecFactory.end_turn(game, koremasa)
	await Fixture.cycle_turn(game, ally)
	Fixture.queue([FAIL, 2])
	await walk(ally, MINE_TILE + Vector2i(0, 1))
	assert_true(is_attached(ally), 'Vanilla mines are friendly-fire (ruling 25).')

func test_the_mines_magnet_is_from_the_makibishi_kit():
	await deploy_mine(MINE_TILE)
	var walker := Fixture.create_hostile(game, WALKER_START)
	await SpecFactory.end_turn(game, koremasa)
	await Fixture.cycle_turn(game, walker)
	Fixture.queue([FAIL, 2])
	await walk(walker, MINE_TILE + Vector2i(0, 1))
	var buff := attached(walker)
	assert_false(buff.is_empty(), 'fixture: attached.')
	if buff.is_empty(): return
	assert_eq(buff[0].from_gear, koremasa.get_gear(Fixture.MAKIBISHI_ID).persistent_id,
		'From the Makibishi Kit, not the mine: the detach saves against the Koremasa (ruling 25).')

func test_a_mine_deploy_offers_a_second_mine_for_the_second_charge():
	await deploy_mine(MINE_TILE, SECOND_MINE_TILE)
	assert_eq(mines().size(), 2, 'Two mines.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 0, 'Both charges spent.')

func test_the_second_mine_may_be_declined():
	await deploy_mine(MINE_TILE)
	assert_eq(mines().size(), 1, 'One mine.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 1, 'One charge left.')

func test_with_one_charge_left_a_mine_deploy_offers_no_second():
	await throw_at(victim, PASS) # the first charge
	# The next turn: throw and deploy share the Kit's usage group, and the engine refuses the same
	# system twice in one turn (vanilla's Havok Charges alike).
	await Fixture.cycle_turn(game, koremasa)
	await deploy_mine(MINE_TILE, SECOND_MINE_TILE)
	assert_eq(mines().size(), 1, 'Only the one mine the charge paid for.')
	assert_eq(Fixture.charges(koremasa, Fixture.MAKIBISHI_ID), 0, 'Out of charges.')
