# EXALT (Black Mountain SP2, Blackstone Bell's passive Bringer of Glory, design ruling 11):
#   "Reaction, 3/round. Trigger: An allied character within Sensors and line of sight destroys or deals
#    structure damage to a hostile mech character. Effect: The triggering allied character gains
#    Overshield equal to 1 + GRIT. If they already have Overshield it increases by that much instead. A
#    character can only benefit from this effect 1/round."
#
# A DAMAGE POST ActionReaction on cp_blackstone_bell, a REAL reaction (consumes_rxn) with a hard limit of 3,
# automatic. "Deals structure damage" is read at DAMAGE POST as THIS damage taking the mech from above 0 HP
# to 0 or below - DAMAGE POST is queued one line before the structure event (event_unit_damage.gd), so the
# shield lands before the structure roll, and the resident talents' replacement of the structure event is
# never in the path. One call, Overshield.increase_by, covers both sentences and hangs the "granted by"
# mark; buff_exalt_benefited (hidden, START_OF_OWNERS_TURN) is the 1/round-per-character.
#
# WHAT THIS FILE PROVES: an ally's structuring hit within Sensors and LOS shields the ally by 1+Grit (the
# BLACK MOUNTAIN's Grit), with the "granted by" mark, before the structure roll, PROMPTED and accepted
# (author ruling, close review finding 1 - a real reaction is always the reacting player's choice, so
# declining spends nothing); an ally holding N ends at N+1+Grit; destruction counts; an owned drone's hit
# shields its owner; two Black Mountains each exalt the SAME ally independently (M-1 fix: the 1/round mark
# is scoped to the granting Black Mountain's own gear). And NOT: the Black Mountain's own hit, a hostile
# drone victim, an allied victim, heat (even a zero-heat-cap victim whose heat crosses zero as converted
# HP damage - the type exclusion, not the arithmetic, refuses it there), a hit that leaves HP above zero,
# a hit landing exactly on zero (counts) versus a second chunk landing exactly on zero after an earlier
# chunk already crossed it (does not), a sourceless burn tick, the ally outside LOS, the ally outside
# Sensors, the same ally twice before the Black Mountain's next turn, a fourth trigger in one round. And
# the mark clears at the Black Mountain's turn start.
#
# DAMAGE IS DEALT THROUGH Fixture.damage (a bare event_unit_damage with the ally as dealer) except in the
# one rifle-shot test: the card reads "deals structure damage", not "attacks", and the bare event is
# exactly what an attack's damage chunk is. The structure roll that follows pops the dice FIFO, so every
# test queues 6s (a glancing blow) - Fixture.queue tails with 1s, and a 1 on a structure check is a
# crushing hit.
#
# GEOMETRY (map 30x12). The Black Mountain at (4,4), Sensors 10. The ally at (6,4); victims at (10,4) and
# around. FAR_ALLY (15,4) is 11 from the Black Mountain. WALL x = 5, rows 5-7 hides WALLED_ALLY (4,8) from
# the Black Mountain.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_exalt.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const BM_TILE := Vector2i(4, 4)
const ALLY_TILE := Vector2i(6, 4)
const ALLY_B_TILE := Vector2i(6, 2)
const ALLY_C_TILE := Vector2i(6, 6)
const ALLY_D_TILE := Vector2i(6, 8)
const FAR_ALLY_TILE := Vector2i(15, 4)
const WALLED_ALLY_TILE := Vector2i(4, 8)
const WALL:Array[Vector2i] = [Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6)]
const HOSTILE_TILE := Vector2i(10, 4)
const HOSTILE_B_TILE := Vector2i(10, 2)
const HOSTILE_C_TILE := Vector2i(10, 6)
const HOSTILE_D_TILE := Vector2i(10, 8)
const BYSTANDER_TILE := Vector2i(20, 10)
const GRIT := 2
const SHIELD := 1 + GRIT
const HIT := 5

var game:Gamemaster
var responder
var black_mountain:Unit
var ally:Unit
var hostile:Unit
var bystander:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	black_mountain = Fixture.create_black_mountain(game, BM_TILE)
	Fixture.set_grit(black_mountain, GRIT)
	ally = Fixture.create_ally(game, ALLY_TILE)
	hostile = hostile_mech(HOSTILE_TILE)
	bystander = Fixture.create_dummy(game, BYSTANDER_TILE, 10, Faction.AI_ENEMY)
	Fixture.queue([6, 6, 6, 6])

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## A hostile MECH at 3 HP: any hit of HIT (5) crosses zero.
func hostile_mech(tile:Vector2i, evasion:int = 10) -> Unit:
	var unit := Fixture.create_hostile(game, tile, evasion)
	Fixture.weaken(unit, 3)
	return unit

func uses() -> int: return Fixture.uses_this_round(black_mountain, Fixture.CORE_ID, Fixture.EXALT_ACTION)

## The confirm prompts this reaction raised - titled with its own name row (An End to All Things'
## offers() pattern, test_an_end_to_all_things.gd).
func offers() -> int:
	var name:String = X.tr('gear.cp_blackstone_bell.action_exalt.name')
	var count := 0
	for seen:Dictionary in responder.yesno_prompts:
		if String(seen.get('title', '')).contains(name) or String(seen.get('desc', '')).contains(name): count += 1
	return count

func structure(victim:Unit = hostile, dealer:Unit = ally, amount:int = HIT,
		type:Lancer.DAMAGE_TYPE = Lancer.DAMAGE_TYPE.KINETIC) -> void:
	await Fixture.damage(game, victim, amount, dealer, type)

func assert_exalted(unit:Unit, expected:int, message:String) -> void:
	assert_eq(Fixture.overshield(unit), expected, message + ' Overshield %d.' % expected)
	assert_true(Overshield.is_granted_by(unit, black_mountain), message + ' Marked as the Black Mountain\'s grant.')

func assert_not_exalted(unit:Unit, message:String) -> void:
	assert_eq(Fixture.overshield(unit), 0, message + ' No Overshield.')
	assert_eq(uses(), 0, message + ' Nothing spent.')
	assert_eq(black_mountain.core.current.reactions, black_mountain.core.get_reactions_max(),
		message + ' The reaction point is still there.')

# ---------------------------------------------------------------- registration

func test_exalt_is_a_real_reaction_on_the_core_kit_with_a_hard_limit_of_three() -> void:
	var core:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	if not Kit.is_valid(core):
		fail_test('The core Kit loads.')
		return
	var action:Action = core.get_action(Fixture.EXALT_ACTION)
	assert_true(action is ActionReaction, 'action_exalt is an ActionReaction.')
	if not action is ActionReaction: return
	assert_true(action.consumes_rxn, 'A real reaction: it spends the reaction point (author).')
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.DAMAGE] as Array[StringName], 'On damage.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, 'At POST.')
	assert_eq(action.get_per_round_hard_limit(null), 3, '3/round.')
	assert_eq(action.usage_group, Fixture.EXALT_ACTION, 'Its own usage group.')
	var mark:Buff = ContentLibrary.get_buff(Fixture.EXALT_BENEFITED)
	assert_not_null(mark, 'buff_exalt_benefited is in the buffs index.')
	if mark == null: return
	assert_true(mark.hide_from_player, 'Hidden.')
	assert_eq(mark.until, Lancer.UNTIL.START_OF_OWNERS_TURN, 'Until the Black Mountain\'s next turn.')

# ---------------------------------------------------------------- the effect

func test_an_allys_structuring_hit_shields_the_ally_by_one_plus_the_black_mountains_grit() -> void:
	Fixture.set_grit(ally, 0) # the ALLY's own Grit is not the one read
	await structure()
	assert_exalted(ally, SHIELD, 'An ally structured a hostile mech within Sensors and LOS.')
	assert_eq(uses(), 1, 'One of three spent.')
	assert_eq(black_mountain.core.current.reactions, black_mountain.core.get_reactions_max() - 1,
		'A real reaction: the point is spent.')
	assert_eq(offers(), 1, 'Offered once (author ruling); accepted by default.')

func test_the_player_may_decline_exalt() -> void:
	responder.yesno_queue.assign([false])
	await structure()
	assert_eq(offers(), 1, 'Offered once.')
	assert_not_exalted(ally, 'Declined: no Overshield, no use spent, the reaction point is intact.')
	assert_true(UnitCondition.get_buffs(ally, Fixture.EXALT_BENEFITED).is_empty(),
		'Declined: no benefited mark either.')

func test_grit_zero_still_gives_one() -> void:
	Fixture.set_grit(black_mountain, 0)
	await structure()
	assert_exalted(ally, 1, 'Grit 0.')

func test_an_ally_already_holding_overshield_increases_by_that_much() -> void:
	await Fixture.grant_overshield(ally, 4)
	await structure()
	assert_exalted(ally, 4 + SHIELD, 'N + 1 + Grit, not max(N, 1 + Grit).')

func test_destroying_a_hostile_mech_counts() -> void:
	Fixture.weaken(hostile, 3, 1) # the last structure
	await structure()
	assert_exalted(ally, SHIELD, 'A destroying hit.')
	assert_false(Unit.is_valid(hostile), 'CONTROL: the hostile was destroyed.')

func test_a_real_rifle_shot_that_structures_counts() -> void:
	Fixture.arm_rifle(ally)
	var target := hostile_mech(HOSTILE_B_TILE, -10)
	Fixture.queue([19, 6, 6, 6, 6])
	await Fixture.shoot(game, ally, target)
	assert_exalted(ally, SHIELD, 'A rifle hit of 6 on a 3-HP mech.')

func test_an_owned_drones_hit_shields_its_owner() -> void:
	var drone := Fixture.own_drone(Fixture.create_drone(game, ALLY_B_TILE), ally)
	await structure(hostile, drone)
	assert_exalted(ally, SHIELD, 'get_attacker resolves the drone to its owner.')
	assert_eq(Fixture.overshield(drone), 0, 'The drone is not the character that benefits.')

func test_the_shield_lands_before_the_structure_roll() -> void:
	var spy := StructureSpy.new()
	spy.watched = ally
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event({unit = hostile}), hostile, BuffCore.create(spy))
	await structure()
	assert_eq(spy.seen, SHIELD, 'At the structure event\'s PRE, the ally already held the shield.')

# ---------------------------------------------------------------- not offered

func test_the_black_mountains_own_structuring_hit_is_not_exalted() -> void:
	await structure(hostile, black_mountain)
	assert_not_exalted(black_mountain, '"Allied character" excludes the Black Mountain (ruling 3).')

func test_a_hostile_drone_is_not_a_mech() -> void:
	var drone := Fixture.create_drone(game, HOSTILE_B_TILE, Faction.AI_ENEMY)
	Fixture.weaken(drone, 3)
	await structure(drone)
	assert_not_exalted(ally, 'A drone victim.')

func test_an_allied_mech_victim_is_not_hostile() -> void:
	var friend := Fixture.create_ally(game, ALLY_B_TILE)
	Fixture.weaken(friend, 3)
	await structure(friend)
	assert_not_exalted(ally, 'An allied victim.')

func test_heat_does_not_count() -> void:
	# A normal heat cap: heat never touches HP (event_unit_damage.gd's heat() adds to the heat pool),
	# so the arithmetic gate refuses this alone - the HEAT exclusion is never actually asked. See the
	# next test for the case where it is.
	await structure(hostile, ally, HIT, Lancer.DAMAGE_TYPE.HEAT)
	assert_eq(Fixture.health(hostile), 3, 'CONTROL: heat never touched HP.')
	assert_not_exalted(ally, 'Heat, with a normal heat cap.')

func test_heat_does_not_count_even_when_it_crosses_zero_via_a_zero_heat_cap_victim() -> void:
	# No stock NPC has heat 0 (slice3 finding 6 records this as academic), but the exclusion must hold
	# even here: a zero heat cap converts heat straight to ENERGY damage to HP
	# (event_unit_damage.gd:207-208), crossing zero - so this time it is the HEAT type exclusion
	# itself (VigilAction.is_damage_dealt_by), not the arithmetic, that refuses it.
	# NOT asserted on final Fixture.health(hostile): a surviving (non-destroying) structure result
	# heals HP back up to max (event_unit_structure.gd:41-44), so by the time this returns the crossing
	# is no longer observable on the unit - only the gate, evaluated at DAMAGE POST queue time before
	# the structure event runs, ever saw it. That is exactly what assert_not_exalted below checks.
	hostile.core.frame.stat.heat = 0
	await structure(hostile, ally, HIT, Lancer.DAMAGE_TYPE.HEAT)
	assert_not_exalted(ally, 'Heat, even when it crosses zero.')

func test_a_hit_that_leaves_hp_above_zero_does_not_count() -> void:
	await structure(hostile, ally, 2)
	assert_eq(Fixture.health(hostile), 1, 'CONTROL: still standing.')
	assert_not_exalted(ally, 'No structure damage.')

func test_a_hit_landing_exactly_on_zero_counts() -> void:
	# health < 0 would be a bug: the card is "takes it to 0 or below". Weaken so the hit lands exactly
	# on zero rather than past it. NOT asserted on final Fixture.health(hostile): a surviving structure
	# result heals HP back to max (event_unit_structure.gd:41-44) by the time this returns - see the
	# heat test above for the same note.
	Fixture.weaken(hostile, HIT)
	await structure()
	assert_exalted(ally, SHIELD, 'A hit landing exactly on zero still counts (health <= 0).')

func test_a_second_chunk_after_hp_is_already_below_zero_does_not_refire() -> void:
	# Two chunks of one hit in ONE block - the two-type shape: both land before either POST runs, and
	# each POST's gate is evaluated when it is QUEUED (reaction_bus.gd), right after its own chunk.
	await damage_block([hostile, hostile], [Lancer.DAMAGE_TYPE.KINETIC, Lancer.DAMAGE_TYPE.ENERGY])
	assert_eq(Fixture.overshield(ally), SHIELD, 'Shielded once, not twice.')
	assert_eq(uses(), 1, 'One use.')

func test_one_hit_structuring_two_hostiles_shields_the_ally_once() -> void:
	# A Blast's shape: two victims in one block. Both gates pass at queue time (no mark yet); the second
	# activation must be refused by the 1/round-per-character check inside activate.
	var second := hostile_mech(HOSTILE_B_TILE)
	await damage_block([hostile, second], [Lancer.DAMAGE_TYPE.KINETIC, Lancer.DAMAGE_TYPE.KINETIC])
	assert_eq(Fixture.overshield(ally), SHIELD, 'Shielded once.')
	assert_eq(uses(), 1, 'One use.')

## THE NEXT TWO GIVE THE BLACK MOUNTAIN TWO REACTION POINTS, and that is the point of them: with one, a
## second activation in the same block is refused by the spent point, which masks both gates below
## (measured: deleting either survived the two tests above).
func test_a_second_allys_chunk_after_hp_is_already_below_zero_does_not_count() -> void:
	black_mountain.core.current.reactions = 2
	var second_ally := Fixture.create_ally(game, ALLY_B_TILE)
	await damage_block([hostile, hostile], [Lancer.DAMAGE_TYPE.KINETIC, Lancer.DAMAGE_TYPE.KINETIC],
		[ally, second_ally])
	assert_eq(Fixture.overshield(ally), SHIELD, 'The ally whose hit crossed zero.')
	assert_eq(Fixture.overshield(second_ally), 0, 'Not the one hitting a mech already below zero.')

func test_a_second_allys_chunk_landing_exactly_on_zero_after_hp_already_crossed_it_does_not_count() -> void:
	# The gate is health + number > 0, not >= 0. Weaken so the FIRST chunk lands exactly on zero (and
	# benefits, per the test above); the second chunk's own arithmetic then sits right on the boundary
	# (-5 + 5 = 0) and must still be refused.
	Fixture.weaken(hostile, HIT)
	black_mountain.core.current.reactions = 2
	var second_ally := Fixture.create_ally(game, ALLY_B_TILE)
	await damage_block([hostile, hostile], [Lancer.DAMAGE_TYPE.KINETIC, Lancer.DAMAGE_TYPE.KINETIC],
		[ally, second_ally])
	assert_eq(Fixture.overshield(ally), SHIELD, 'The ally whose hit landed exactly on zero.')
	assert_eq(Fixture.overshield(second_ally), 0, 'Not the one hitting a mech already at zero (boundary: > 0, not >= 0).')

func test_with_a_point_to_spare_one_hit_on_two_hostiles_still_shields_once() -> void:
	black_mountain.core.current.reactions = 2
	var second := hostile_mech(HOSTILE_B_TILE)
	await damage_block([hostile, second], [Lancer.DAMAGE_TYPE.KINETIC, Lancer.DAMAGE_TYPE.KINETIC])
	assert_eq(Fixture.overshield(ally), SHIELD, 'Refused inside activate by the 1/round-per-character mark.')
	assert_eq(uses(), 1, 'One use.')

func damage_block(victims:Array[Unit], types:Array, dealers:Array = []) -> void:
	var cores:Array[EventCore] = []
	for i:int in victims.size():
		var dealer:Unit = dealers[i] if i < dealers.size() else ally
		cores.append(EventCore.create(&'event_unit_damage',
			{unit = victims[i], number = HIT, category = types[i], target_unit = dealer}))
	await game.execute_event_block(EventBlock.create_multiple(cores))

func test_a_sourceless_burn_tick_does_not_count() -> void:
	await structure(hostile, null, HIT, Lancer.DAMAGE_TYPE.BURN)
	assert_not_exalted(ally, 'No dealer.')

func test_an_ally_outside_line_of_sight_is_not_exalted() -> void:
	Fixture.raise_wall(game, WALL)
	var walled := Fixture.create_ally(game, WALLED_ALLY_TILE)
	assert_false(UnitRelation.can_see(black_mountain, walled), 'fixture: the wall hides the ally.')
	await structure(hostile, walled)
	assert_not_exalted(walled, 'Behind a wall.')

func test_an_ally_outside_sensors_is_not_exalted() -> void:
	var far := Fixture.create_ally(game, FAR_ALLY_TILE)
	assert_gt(UnitRelation.distance_between(black_mountain, far), black_mountain.get_sensor_range(),
		'fixture: beyond Sensors.')
	await structure(hostile, far)
	assert_not_exalted(far, 'Outside Sensors.')

# ---------------------------------------------------------------- the limits

func test_the_same_ally_benefits_once_before_the_black_mountains_next_turn() -> void:
	await structure()
	assert_exalted(ally, SHIELD, 'First.')
	await Fixture.refresh_reactions(game, bystander)
	var second := hostile_mech(HOSTILE_B_TILE)
	Fixture.queue([6, 6, 6, 6])
	await structure(second)
	assert_eq(Fixture.overshield(ally), SHIELD, 'The same ally is not shielded again.')
	assert_eq(uses(), 1, 'Nothing spent the second time.')
	# CONTROL: the reaction point IS back, so a different ally would be.
	var other := Fixture.create_ally(game, ALLY_B_TILE)
	var third := hostile_mech(HOSTILE_C_TILE)
	Fixture.queue([6, 6, 6, 6])
	await structure(third, other)
	assert_exalted(other, SHIELD, 'CONTROL: another ally.')

func test_two_black_mountains_each_exalt_the_same_ally() -> void:
	# M-1 fix: the 1/round mark is scoped to the GRANTING Black Mountain's own gear
	# (UnitCondition.get_buffs(dealer, BENEFITED, gear.persistent_id)), so a second Black Mountain is
	# unaffected by the first's mark - the same reading ruling 13 already gives two DOOMs.
	var second_bm := Fixture.create_black_mountain(game, Vector2i(2, 4))
	Fixture.set_grit(second_bm, GRIT)
	await structure()
	assert_eq(Fixture.overshield(ally), 2 * SHIELD, 'Each Black Mountain\'s Exalt is its own effect: they stack.')
	assert_true(Overshield.is_granted_by(ally, black_mountain), 'Marked as the first Black Mountain\'s grant.')
	assert_true(Overshield.is_granted_by(ally, second_bm), 'And as the second\'s.')

func test_the_benefit_mark_clears_at_the_black_mountains_turn_start() -> void:
	await structure()
	await Fixture.cycle_turn(game, black_mountain)
	assert_true(UnitCondition.get_buffs(ally, Fixture.EXALT_BENEFITED).is_empty(), 'The mark is gone.')
	var second := hostile_mech(HOSTILE_B_TILE)
	Fixture.queue([6, 6, 6, 6])
	await structure(second)
	assert_eq(Fixture.overshield(ally), 2 * SHIELD, 'Shielded again, additively.')

func test_three_per_round_and_the_fourth_is_refused() -> void:
	var allies:Array[Unit] = [ally, Fixture.create_ally(game, ALLY_B_TILE),
		Fixture.create_ally(game, ALLY_C_TILE), Fixture.create_ally(game, ALLY_D_TILE)]
	var victims:Array[Unit] = [hostile, hostile_mech(HOSTILE_B_TILE), hostile_mech(HOSTILE_C_TILE),
		hostile_mech(HOSTILE_D_TILE)]
	for i:int in 4:
		if i > 0: await Fixture.refresh_reactions(game, bystander)
		Fixture.queue([6, 6, 6, 6])
		await structure(victims[i], allies[i])
	for i:int in 3:
		assert_exalted(allies[i], SHIELD, 'Ally %d.' % i)
	assert_eq(Fixture.overshield(allies[3]), 0, 'The fourth is refused by the round.')
	assert_eq(uses(), 3, 'Three uses.')

func test_without_a_reaction_point_nothing_happens() -> void:
	black_mountain.core.current.reactions = 0
	await structure()
	assert_eq(Fixture.overshield(ally), 0, 'A real reaction needs its point.')

## Records the watched unit's Overshield when the holder's structure event reaches PRE.
class StructureSpy extends Buff:
	var watched:Unit
	var seen := -1
	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.STRUCTURED]
		trigger_timing = ReactionBus.TIMING.PRE
		hide_from_player = true
	func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
		return triggering_event.context.unit == unit
	func activate(_core:BuffCore, _activation:EventCore) -> void:
		seen = Overshield.current(watched)
