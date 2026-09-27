# RAPID RUSHDOWN (Gloire SP2, design rulings 7-9): "You take 2 heat and may move 4 spaces in any
# direction in a straight line. This movement ignores engagement and doesn't provoke reactions. You
# may then ram as a free action. Until the start of your next turn, you gain +1 Armor."
#
# GEOMETRY. The Gloire is size 2 at (4,4), covering (4..5, 4..5); anchors are what the reticle offers
# and what tile() reports. A dash of 4 due east lands the anchor on (8,4), the footprint on (8..9,
# 4..5). Hostiles for the free Ram stand within Extended Zone Control's Range 3 of the NEW footprint.
#
# HOW THE DASH IS AIMED: target_tiles on the activation (test_full_speed_ahead.gd's header). What
# was OFFERED is read off the watcher's move_tile prompt, as every Gloire spec reads offers.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rapid_rushdown.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const GLOIRE_TILE := Vector2i(4, 4)
const EAST_4 := Vector2i(8, 4)
const SOUTH_4 := Vector2i(4, 8)
## Two east of the dashed footprint's east edge (x = 9): inside the free Ram's Range 3.
const RAM_TARGET_TILE := Vector2i(11, 4)
const HEAT := 2

var game:Gamemaster
var responder
var watcher
var gloire:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	gloire = Fixture.create_gloire(game, GLOIRE_TILE)
	await Fixture.open_turn(game, gloire)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.move_tile_queue.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false
	responder.abort_plans = 0

func reason() -> UnitAction.REASON:
	return UnitAction.get_gear_unavailable_reason(Fixture.rushdown_specific(gloire))

## A flat kinetic hit on the Gloire from `dealer`, returning the HP it cost.
func hit_for(amount:int, dealer:Unit) -> int:
	var before:int = gloire.core.current.health
	await game.execute_event(&'event_unit_damage', {
		unit = gloire, number = amount, category = Lancer.DAMAGE_TYPE.KINETIC, target_unit = dealer, flags = [],
	})
	return before - gloire.core.current.health

# ---------------------------------------------------------------- the move

func test_it_moves_four_straight_costs_a_quick_and_two_heat() -> void:
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), EAST_4, 'four spaces due east.')
	assert_eq(gloire.core.current.heat, HEAT, '"You take 2 heat".')
	assert_eq(gloire.state.actions, 1, 'one Quick action spent.')
	assert_eq(Fixture.rushdown_uses(gloire), 1, 'the round is spent.')
	assert_true(gloire.core.has_core_power, 'the passive half costs no core point.')

## "IN A STRAIGHT LINE" IS THE ENGINE'S RAY, NOT THE EIGHT COMPASS DIRECTIONS - measured 2026-09-24
## and recorded rather than fought: MovementType.straight_line changes the PATH the pathfinder walks
## (pathfinder.gd:496-497, calculate_step_path_for_line - one Bresenham ray from origin to
## destination), not which destinations it offers, so every tile within 4 is on the reticle and (6,5)
## is reached by a ray that steps 2 east and 1 south. Ramjet, the vanilla card with the same words,
## offers exactly the same square. What the flag buys is that the Gloire cannot thread a corner: the
## path to any offered tile is the one ray, which test_the_movement_type_carries_every_clause pins.
func test_every_tile_within_four_is_offered_and_none_beyond() -> void:
	var from:int = watcher.prompts.size()
	await Fixture.rushdown_to(game, gloire, EAST_4)
	var pools:Array = Fixture.offered_pools(watcher, from)
	assert_eq(pools.size(), 1, 'one reticle: the dash.')
	if pools.size() != 1: return
	var pool:Array = pools[0]
	for tile:Vector2i in [Vector2i(5, 4), Vector2i(7, 4), EAST_4, SOUTH_4, Vector2i(8, 8), Vector2i(0, 4), Vector2i(6, 5)]:
		assert_has(pool, tile, '%s: within 4 - a ray reaches it.' % tile)
	assert_does_not_have(pool, Vector2i(9, 4), 'five is too far.')
	assert_does_not_have(pool, Vector2i(4, 9), 'in any direction.')
	assert_does_not_have(pool, GLOIRE_TILE, 'staying put is not a move.')

func test_the_movement_type_carries_every_clause_of_the_card_and_nothing_more() -> void:
	# The merged type is what the pathfinder walks (action_system_movement.gd:38-45); pinning its flags
	# is the only way to hold each clause independently of where the dash happened to land.
	var action:ActionSystemMovement = Fixture.rushdown_specific(gloire).action as ActionSystemMovement
	assert_not_null(action)
	if action == null: return
	var movement_type := action.get_movement_type(gloire)
	assert_true(movement_type.straight_line, '"in a straight line".')
	assert_true(movement_type.ignore_engagement, '"ignores engagement".')
	assert_true(movement_type.ignore_rxns, '"doesn\'t provoke reactions".')
	assert_false(movement_type.must_move_max_possible, 'RULED: UP TO 4 - "may move 4 spaces".')
	assert_false(movement_type.can_move_through_enemies, 'RULED: the card does not say through.')
	assert_false(movement_type.flying, 'a grounded Gloire stays grounded.')
	assert_false(movement_type.spend_move, 'the 4 spaces are the card\'s, not this turn\'s movement.')
	assert_eq(action.get_target_range(Fixture.rushdown_specific(gloire)), 4, 'the budget is exactly 4.')

func test_an_engaged_gloire_leaves_without_provoking() -> void:
	# A hostile with a War Pike (threat 3) stands against the east edge: the Gloire is engaged and
	# would be in threat for an Overwatch as it goes.
	var hostile := Fixture.create_dummy(game, Vector2i(6, 4))
	Fixture.equip(hostile, Fixture.PIKE)
	var health:int = gloire.core.current.health
	var reactions:int = hostile.core.current.reactions
	await Fixture.rushdown_to(game, gloire, SOUTH_4)
	assert_eq(gloire.tile(), SOUTH_4, 'engagement did not hold it.')
	assert_eq(gloire.core.current.health, health, 'nothing struck it on the way out.')
	assert_eq(hostile.core.current.reactions, reactions, 'and the hostile spent no reaction.')

## THE POSITIVE CONTROL for the test above (close-out Pass D, open item "no positive control"): the
## same armed hostile, the same walk south, taken as an ORDINARY move - and the hostile overwatches.
## Without it, "spent no reaction" could be passing because this hostile never overwatches anything.
## Read off the reaction spend, so a missed overwatch still counts as one fired.
func test_an_ordinary_move_from_the_same_spot_draws_the_overwatch() -> void:
	var hostile := Fixture.create_dummy(game, Vector2i(6, 4))
	Fixture.equip(hostile, Fixture.PIKE)
	var reactions:int = hostile.core.current.reactions
	await SpecFactory.move(game, gloire, SOUTH_4)
	assert_eq(gloire.tile(), SOUTH_4, 'fixture: it actually walked.')
	assert_lt(hostile.core.current.reactions, reactions, "Walking out of the Pike's threat draws its overwatch.")

# ---------------------------------------------------------------- the free Ram

func test_the_free_ram_follows_the_dash_and_the_frames_loop_closes() -> void:
	var hostile := Fixture.create_dummy(game, RAM_TARGET_TILE)
	Dice.CHEAT_ROLL_QUEUE.append(10) # the Ram's d20
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), EAST_4, 'dashed.')
	assert_true(hostile.has_status(Lancer.STATUS.PRONE), 'RULED: the free Ram was offered after the move and it landed.')
	assert_eq(gloire.state.actions, 1, 'the Ram was FREE: only the Quick is spent.')
	assert_true(Fixture.is_punished(hostile), 'and Hydraulic Punisher resolved the Gloire as the knocker - the frame\'s loop.')
	assert_true(Fixture.is_braced(gloire), 'the armour is up too.')

func test_cancelling_the_free_ram_costs_nothing_and_keeps_the_dash() -> void:
	var hostile := Fixture.create_dummy(game, RAM_TARGET_TILE)
	responder.abort_plans = 1 # the Ram's target picker is refused; the dash's reticle before it is answered
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), EAST_4, 'the dash stands.')
	assert_eq(gloire.core.current.heat, HEAT, 'the heat was paid for the dash,')
	assert_eq(gloire.state.actions, 1, 'the Quick too,')
	assert_true(Fixture.is_braced(gloire), 'and the armour is up (it lands BEFORE the Ram, ruling 9);')
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'the "may" Ram simply did not happen.')

func test_no_legal_ram_target_offers_no_picker() -> void:
	# Nobody within Range 3 of the dashed footprint: nothing is offered, and nothing hangs.
	Fixture.create_dummy(game, Vector2i(14, 4)) # 5 from x = 9
	var from:int = watcher.prompts.size()
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), EAST_4)
	var pickers := 0
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind == PromptWatcher.KIND.compcon_plan: pickers += 1
	assert_eq(pickers, 0, 'no Ram picker was raised for an empty field.')
	assert_true(Fixture.is_braced(gloire), 'the armour is up regardless.')

# ---------------------------------------------------------------- the armour

func test_the_armour_blunts_a_kinetic_hit_and_lifts_at_the_next_turn_start() -> void:
	# Three hits of 4 on 8 HP: 2 + 1 + 2 = 5, so the Gloire never structures mid-test (three 5s did,
	# and the fresh structure's HP read as a heal).
	var dealer := Fixture.create_dummy(game, Vector2i(12, 10))
	assert_eq(await hit_for(4, dealer), 2, 'fixture: the sheet\'s 2 armour takes 2 off a 4.')
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_true(Fixture.is_braced(gloire), 'both halves of the pair are on.')
	assert_eq(gloire.get_armor(), 3, 'the readout says 3.')
	assert_eq(await hit_for(4, dealer), 1, 'RULED: +1 Armor - a 4 now costs 1.')
	await Fixture.cycle_turn(game, gloire)
	assert_false(Fixture.is_braced(gloire), '"until the start of your next turn".')
	assert_eq(gloire.get_armor(), 2, 'back to the sheet.')
	assert_eq(await hit_for(4, dealer), 2, 'and a 4 costs 2 again.')

func test_the_armour_pairs_untils_match() -> void:
	# The two halves tearing apart is the one way this mechanic fails silently (buff_armor_reduction.gd).
	var chip:Buff = ContentLibrary.get_buff(Fixture.RUSHDOWN_ARMOR_BUFF)
	var blunt:Buff = ContentLibrary.get_buff(Fixture.RUSHDOWN_REDUCTION_BUFF)
	assert_not_null(chip); assert_not_null(blunt)
	if chip == null or blunt == null: return
	assert_eq(chip.until, Lancer.UNTIL.START_OF_TURN, 'the chip: START_OF_TURN.')
	assert_eq(blunt.until, chip.until, 'the blunting half: the same.')
	assert_false(chip.hide_from_player, 'the chip is visible,')
	assert_true(blunt.hide_from_player, 'the blunting half is not.')

# ---------------------------------------------------------------- refusals

func test_slowed_refuses_it() -> void:
	SpecFactory.apply(gloire, Lancer.STATUS.SLOWED)
	assert_eq(reason(), UnitAction.REASON.SPECIFIC, 'the archetype refuses a voluntary system move while Slowed (RAW).')
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), GLOIRE_TILE, 'unmoved,')
	assert_eq(gloire.core.current.heat, 0, 'no heat.')

func test_immobilized_refuses_it() -> void:
	SpecFactory.apply(gloire, Lancer.STATUS.IMMOBILIZED)
	assert_eq(reason(), UnitAction.REASON.SPECIFIC)
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), GLOIRE_TILE)
	assert_eq(gloire.core.current.heat, 0)

func test_a_second_use_in_the_round_is_refused_and_a_new_round_re_arms() -> void:
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(reason(), UnitAction.REASON.PER_ROUND, '"1/round".')
	await Fixture.rushdown_to(game, gloire, Vector2i(8, 8))
	assert_eq(gloire.tile(), EAST_4, 'the second press moved nothing,')
	assert_eq(gloire.core.current.heat, HEAT, 'and cost nothing.')
	await Fixture.cycle_turn(game, gloire)
	assert_eq(reason(), UnitAction.REASON.NONE, 'a new round re-arms it.')

func test_cancelling_the_reticle_spends_nothing() -> void:
	responder.abort_all = true
	await Fixture.rushdown_to(game, gloire, EAST_4)
	assert_eq(gloire.tile(), GLOIRE_TILE, 'nothing moved,')
	assert_eq(gloire.core.current.heat, 0, 'RULED: no heat,')
	assert_eq(gloire.state.actions, 2, 'no action,')
	assert_false(Fixture.is_braced(gloire), 'no armour,')
	assert_eq(Fixture.rushdown_uses(gloire), 0, 'and the round is not spent.')

# ---------------------------------------------------------------- the card

func test_the_card_and_the_kit() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_true(Kit.is_valid(kit), 'the core Kit is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'a trait.')
	assert_eq(kit.actions.size(), 3, 'Rapid Rushdown, RPA Pullback, the hidden collision reaction.')
	if kit.actions.size() != 3: return
	var rushdown:Action = kit.actions[0]
	assert_eq(rushdown.get_id(), Fixture.RUSHDOWN_ID, 'actions[0] IS Rapid Rushdown: get_solo_action() is what the hidden armour half\'s log name falls through to.')
	assert_true(rushdown is ActionSystemMovement, 'a system movement.')
	var specific := Fixture.rushdown_specific(gloire)
	assert_eq(rushdown.get_action_type(specific), Lancer.ACTION.QUICK, 'Quick.')
	assert_eq(rushdown.get_per_round_hard_limit(specific), 1, '1/round.')
	assert_eq(rushdown.self_heat_dice, '2', '2 heat.')
	assert_true(rushdown.show_in_tooltip(kit), 'on the card.')
	assert_eq(kit.actions[1].get_id(), Fixture.PULLBACK_ID, 'then RPA Pullback,')
	assert_eq(kit.actions[2].get_id(), Fixture.PULLBACK_COLLIDE_ID, 'then its collision half.')
	for key:String in ['gear.cp_retaliation_protocol_amplification.name', 'gear.cp_retaliation_protocol_amplification.flavor',
			'gear.cp_retaliation_protocol_amplification.action_rapid_rushdown.name',
			'gear.cp_retaliation_protocol_amplification.action_rapid_rushdown.effect',
			'gear.buff_rapid_rushdown_armor.name', 'gear.buff_rapid_rushdown_armor.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_retaliation_protocol_amplification.action_rapid_rushdown.effect'),
		'You take 2 |heat| and may move 4 spaces in any direction in a straight line. This movement ignores |engagement| and doesn\u2019t provoke |reactions|. You may then |ram| as a free action. Until the start of your next turn, you gain +1 |Armor|.',
		'the card is the LCP verbatim.')
