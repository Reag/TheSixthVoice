# DREAD HARBINGER (Black Mountain SP1, design rulings 8-9):
#   "1/round, whenever the Black Mountain or an allied character within Sensors and line of sight
#    critically hits, the target receives Lock On. Additionally, when this Lock On is consumed, the
#    Black Mountain gains 1d6 Overshield."
#
# An ATTACK POST crit reaction on mt_dread_harbinger (automatic, a trait's 1/round) that locks the
# target through the shared Lockon hook and hangs the VISIBLE mark buff_dread_harbinger_mark; the mark
# pays 1d6 Overshield to the Black Mountain when the lock is CONSUMED and clears itself on any loss.
#
# WHAT THIS FILE PROVES: the Black Mountain's own crit locks and marks; an ally's crit within Sensors
# and line of sight locks; an ally one tile outside Sensors does not; an ally behind a wall does not; an
# unowned allied drone's crit counts as its own (a drone is a character, ruling 2026-09-27) and an OWNED
# drone's still counts as its owner's; a hostile's crit on
# an ally does nothing; a plain hit does nothing; a crit on a target already Locked On spends nothing;
# 1/round, reset at the Black Mountain's turn; a tech crit locks too; the consume pays 1d6 (max
# semantics against a larger shield) and clears the mark and the lock; a Stabilize-shaped loss pays
# nothing and clears the mark; no prompt is ever raised.
#
# DICE (M-6: corrected wording - crit() queues FIVE values, not a run of one). Hostiles here have
# EVASION -10, so every d20 hits and only "is it 20+" matters: 30 crits, 4 does not. The d20 is
# followed by a run of the SAME value (4) for every OTHER die the engine pops - the accuracy d6 of a
# consumed lock, the damage dice of a hit column and a crit column, the mark's own 1d6 - so their
# relative order need not be pinned; only the first (d20) value distinguishes crit() from hit().
# Fixture.queue tails with 1s.
#
# GEOMETRY (map 30x12). The Black Mountain at (4,4), Sensors 10. IN_SENSORS (6,4) is 2 from it;
# OUT_OF_SENSORS (15,4) is 11. HOSTILE (10,4) is 6 from the Black Mountain, 4 from the near ally, 5 from
# the far one - inside everyone's rifle Range 10. WALL x = 5, rows 3-5, sits between the Black Mountain
# and the near ally and nothing else.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_dread_harbinger.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')
const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const BM_TILE := Vector2i(4, 4)
const IN_SENSORS := Vector2i(6, 4)
const OUT_OF_SENSORS := Vector2i(15, 4)
const HOSTILE_TILE := Vector2i(10, 4)
const SECOND_HOSTILE_TILE := Vector2i(10, 7)
const WALL:Array[Vector2i] = [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)]
const ALWAYS_HIT := -10

var game:Gamemaster
var responder
var black_mountain:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	black_mountain = Fixture.create_black_mountain(game, BM_TILE)
	Fixture.arm_rifle(black_mountain)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE, ALWAYS_HIT)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func ally_at(tile:Vector2i) -> Unit:
	var ally := Fixture.create_ally(game, tile)
	Fixture.arm_rifle(ally)
	return ally

func crit(attacker:Unit, target:Unit = hostile) -> void:
	Fixture.queue([Fixture.CRIT_ROLL, 4, 4, 4, 4])
	await Fixture.shoot(game, attacker, target)

func hit(attacker:Unit, target:Unit = hostile) -> void:
	Fixture.queue([4, 4, 4, 4, 4])
	await Fixture.shoot(game, attacker, target)

func harbinger_gear() -> GearCore: return black_mountain.get_gear(Fixture.HARBINGER_ID)
func uses() -> int: return Fixture.uses_this_round(black_mountain, Fixture.HARBINGER_ID, Fixture.HARBINGER_ACTION)

func assert_locked_and_marked(target:Unit, message:String) -> void:
	assert_true(Fixture.is_locked(target), message + ' Locked On.')
	assert_eq(Lockon.source_of(target), harbinger_gear().persistent_id, message + ' The lock is sourced to the Harbinger.')
	assert_eq(Fixture.marks(target), 1, message + ' One mark.')
	assert_eq(uses(), 1, message + ' The round is spent.')

func assert_untouched(target:Unit, message:String) -> void:
	assert_false(Fixture.is_locked(target), message + ' Not locked.')
	assert_eq(Fixture.marks(target), 0, message + ' No mark.')
	assert_eq(uses(), 0, message + ' The round is not spent.')

# ---------------------------------------------------------------- the lock

func test_the_kit_and_its_reaction_and_mark_are_registered() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.HARBINGER_ID)
	assert_true(Kit.is_valid(kit), 'mt_dread_harbinger is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'A trait.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var action:Action = kit.get_action(Fixture.HARBINGER_ACTION)
	assert_true(action is ActionReactionAttacked, 'An ActionReactionAttacked.')
	if action is ActionReactionAttacked:
		assert_true(action.require_crit, 'require_crit: read off the POST roll.')
		assert_false(action.consumes_rxn, 'A trait, not a reaction point.')
		assert_true(action.allow_tech and action.allow_basic, 'Tech and basic crits count.')
		assert_eq(action.get_per_round_hard_limit(null), 1, '1/round.')
	var mark:Buff = ContentLibrary.get_buff(Fixture.HARBINGER_MARK)
	assert_not_null(mark, 'buff_dread_harbinger_mark is in the buffs index.')
	if mark == null: return
	assert_false(mark.hide_from_player, 'VISIBLE (ruling 9, the author\'s call).')
	assert_eq(mark.until, Lancer.UNTIL.MANUAL, 'Lives until the lock is lost.')
	assert_eq(mark.trigger_timing, ReactionBus.TIMING.POST, 'POST: a status CLEARED, not applied.')

func test_the_black_mountains_own_crit_locks_and_marks_the_target() -> void:
	await crit(black_mountain)
	assert_locked_and_marked(hostile, 'The Black Mountain crit.')
	assert_eq(UnitCondition.get_buffs(hostile, Fixture.HARBINGER_MARK)[0].get_owner_unit(game.map), black_mountain,
		'The mark knows whose it is: the Black Mountain, through the Harbinger gear.')
	assert_true(responder.yesno_prompts.is_empty(), 'Automatic: no prompt was raised.')

func test_an_allied_characters_crit_within_sensors_and_sight_locks() -> void:
	var ally := ally_at(IN_SENSORS)
	await crit(ally)
	assert_locked_and_marked(hostile, 'An ally within Sensors and LOS crit.')

func test_an_ally_one_tile_outside_sensors_does_not() -> void:
	var ally := ally_at(OUT_OF_SENSORS)
	assert_eq(UnitRelation.distance_between(black_mountain, ally), 11, 'fixture: one past Sensors 10.')
	await crit(ally)
	assert_untouched(hostile, 'Out of Sensors.')

func test_an_ally_behind_a_wall_does_not() -> void:
	var ally := ally_at(IN_SENSORS)
	Fixture.raise_wall(game, WALL)
	assert_false(UnitRelation.can_see(black_mountain, ally), 'fixture: the wall blocks the Black Mountain\'s sight of the ally.')
	assert_true(UnitRelation.can_see(ally, hostile), 'fixture: and not the ally\'s shot.')
	await crit(ally)
	assert_untouched(hostile, 'No line of sight to the ally.')

func test_an_unowned_drones_crit_is_offered_as_itself_and_an_owned_ones_as_its_owner() -> void:
	# A drone is a character (ruling 2026-09-27): an unowned drone's crit now qualifies on its own.
	var drone := Fixture.create_drone(game, IN_SENSORS)
	Fixture.arm_rifle(drone)
	await crit(drone)
	assert_locked_and_marked(hostile, 'An unowned drone is a character and counts as itself.')
	await Fixture.cycle_turn(game, black_mountain) # a fresh round: two independent scenarios, not the 1/round mechanic
	var second := Fixture.create_hostile(game, SECOND_HOSTILE_TILE, ALWAYS_HIT)
	var owner := ally_at(Vector2i(6, 6))
	Fixture.own_drone(drone, owner)
	await crit(drone, second)
	assert_locked_and_marked(second, 'An owned drone acts as its owner, an allied character within Sensors.')

func test_a_hostiles_crit_on_an_ally_does_nothing() -> void:
	var ally := ally_at(IN_SENSORS)
	Fixture.arm_rifle(hostile)
	await crit(hostile, ally)
	assert_lt(Fixture.health(ally), 200, 'LIVENESS (M-6): the hostile\'s crit still landed on the ally.')
	assert_untouched(ally, 'The target must be a hostile of the Black Mountain.')
	assert_untouched(hostile, 'And the attacker is not locked either.')

func test_a_plain_hit_does_nothing() -> void:
	await hit(black_mountain)
	assert_true(Fixture.health(hostile) < 200, 'fixture: it hit.')
	assert_untouched(hostile, 'A hit that is not a crit.')

func test_a_crit_on_a_target_already_locked_on_spends_nothing() -> void:
	# THE SHOOTER MUST DECLINE THE CONSUME, or there is no "already locked" target left by the time the
	# crit is read: the consume is an ATTACK_DECLARED PRE reaction, so a Black Mountain that consumes its
	# ally's lock on the way in finds the target UNLOCKED at ATTACK POST and relocks it - measured on the
	# first run of this file, and correct (the card says "the target receives Lock On"; the next test
	# pins it). The one yes/no in the Black Mountain's shot is that consume prompt; the Harbinger itself
	# never asks.
	var ally := ally_at(IN_SENSORS)
	assert_true(Fixture.lock_by_hand(ally, hostile), 'fixture: locked by the ally\'s own Lock On.')
	var source_before := Lockon.source_of(hostile)
	responder.yesno_queue.assign([false])
	await crit(black_mountain)
	assert_eq(responder.yesno_prompts.size(), 1, 'fixture: the one prompt was the consume, declined.')
	assert_true(Fixture.is_locked(hostile), 'Still locked.')
	assert_eq(Lockon.source_of(hostile), source_before, 'By the SAME lock: the Harbinger did not relock.')
	assert_eq(Fixture.marks(hostile), 0, 'No mark.')
	assert_eq(uses(), 0, 'And the round is not spent (ruling 8).')

func test_a_crit_that_consumed_the_allys_lock_on_the_way_in_relocks_the_target() -> void:
	# The other half of the case above, recorded: the consume happens before the roll, so at ATTACK POST
	# the target is unlocked and the card's "receives Lock On" applies. The Black Mountain spends the
	# ally's lock to relock, and its own Harbinger mark now sits where the ally's plain lock was.
	var ally := ally_at(IN_SENSORS)
	assert_true(Fixture.lock_by_hand(ally, hostile), 'fixture: locked by the ally.')
	await crit(black_mountain) # the responder consumes
	assert_locked_and_marked(hostile, 'Consumed on the way in, relocked by the crit.')

func test_one_per_round_reset_at_the_black_mountains_turn() -> void:
	var second := Fixture.create_hostile(game, SECOND_HOSTILE_TILE, ALWAYS_HIT)
	await crit(black_mountain, hostile)
	assert_locked_and_marked(hostile, 'The first crit.')
	Fixture.queue([Fixture.CRIT_ROLL, 4, 4, 4, 4])
	await Fixture.shoot_again(game, black_mountain, second)
	assert_lt(Fixture.health(second), 200, 'LIVENESS (M-6): the second, unanswered crit still actually hit.')
	assert_false(Fixture.is_locked(second), 'The second crit in the round locks nothing.')
	assert_eq(Fixture.marks(second), 0, 'And marks nothing.')
	await crit(black_mountain, second) # shoot() cycles the Black Mountain's turn: the tally resets
	assert_true(Fixture.is_locked(second), 'A new round, a new lock.')

func test_a_tech_attack_never_crits_in_this_engine_so_an_invade_never_locks() -> void:
	# MEASURED ON THE FIRST RUN OF THIS FILE (2026-09-27), and an ENGINE fact, not a gate of ours:
	# event_unit_attack.gd:241 rolls with context.action.can_crit(context), ActionAttack.can_crit is
	# `return false` (action_attack.gd:48) and only ActionAttackWeapon overrides it to true (:246), so
	# attack_roll.gd:73 leaves crit false on every tech attack however high the d20. Lancer's own rules
	# agree (tech attacks do not critically hit). allow_tech stays true on the .tres because the card
	# says "critically hits", unqualified, and the day a tech attack can crit this must not refuse it -
	# Eyes of Night's reasoning for its weapon-only cover clause. A 30 against E-Def 8 is a HIT here.
	Fixture.queue([Fixture.CRIT_ROLL, 4, 4, 4])
	await Fixture.invade(game, black_mountain, hostile)
	assert_true(Fixture.heat(hostile) >= 2, 'fixture: the invade hit (Fragment Signal\'s 2 heat landed).')
	assert_untouched(hostile, 'A tech attack cannot crit, so the Harbinger has nothing to answer.')

# ---------------------------------------------------------------- the payoff

func test_consuming_the_lock_pays_the_black_mountain_a_d6_and_clears_the_mark() -> void:
	var ally := ally_at(IN_SENSORS)
	await crit(black_mountain)
	assert_locked_and_marked(hostile, 'fixture:')
	Fixture.queue([6, 6, 6, 6, 6, 6]) # every die a 6: the d20 hits, the mark's 1d6 is 6
	await Fixture.shoot(game, ally, hostile) # the ally's consume prompt is answered yes by the responder
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: the ally\'s shot consumed the lock.')
	assert_eq(Overshield.current(black_mountain), 6, 'The Black Mountain gained 1d6 Overshield (rolled 6).')
	assert_eq(Fixture.marks(hostile), 0, 'The mark cleared itself.')

func test_the_payoff_keeps_the_engines_max_rule() -> void:
	# Astral Guardian's reading: a low roll on a Black Mountain already shielded may change nothing -
	# but the roll must still be READ. REWORKED (M-6): the original held-6-roll-4-expect-6 shape cannot
	# tell a real max(6, 4) = 6 apart from the payoff never firing at ALL (both leave the number at 6).
	# Held 2, rolled 4: max(2, 4) = 4 only happens if the grant actually ran with the rolled value.
	var ally := ally_at(IN_SENSORS)
	await crit(black_mountain)
	await Fixture.grant_overshield(black_mountain, 2)
	Fixture.queue([4, 4, 4, 4, 4, 4]) # the 1d6 is a 4
	await Fixture.shoot(game, ally, hostile)
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: consumed.')
	assert_eq(Overshield.current(black_mountain), 4, 'max(2, 4) is 4 - the payoff ran with the rolled value, and the engine\'s max rule held.')
	assert_eq(Fixture.marks(hostile), 0, 'The mark still cleared.')

## Stack a SECOND Lock On (source = other_source) onto target by hand, then clear THAT ONE specific
## status object directly (clear_specific_status - the ability-clear primitive Stabilize itself calls,
## the one that reaches one stacked StatusCondition by object rather than by type; LOCKON's own
## status_lockon.tres sets remains_when_gear_destroyed = true, so clear_status_source refuses to touch
## it at all, unit_condition.gd:336-338). Run inside a REAL root event block (clear_like_stabilize's
## own shape) so the POST reaction it queues actually runs before this returns.
class StackAndClearAnotherLockEvent extends EventBase:
	func get_required_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.string]
	func execute(core:EventCore) -> void:
		var target:Unit = core.context.unit
		var other_source:StringName = core.context.string
		UnitCondition.apply_status(core, target, Lancer.STATUS.LOCKON, Lancer.UNTIL.MANUAL, other_source)
		for condition:StatusCondition in target.state.statuses.duplicate():
			if condition.type == Lancer.STATUS.LOCKON and condition.source == other_source:
				UnitCondition.clear_specific_status(core, target, condition)

func stack_and_clear_another_lock(target:Unit, other_source:StringName) -> void:
	var core := EventCore.new()
	core.base = StackAndClearAnotherLockEvent.new()
	core.base.event_type = &'event_reag_spec_stack_and_clear_lock'
	core.context = Context.create({unit = target, string = other_source})
	core.id = Util.generate_random_hexcode()
	await game.execute_event_block(EventBlock.create_multiple([core]))

func test_a_stacked_second_lock_ons_loss_does_not_pay_out_or_clear_the_harbingers_own_mark() -> void:
	# M-3: is_lost() only checks the CATEGORY (any Lock On lost on the holder), and
	# UnitCondition.apply_status never refuses stacking a SECOND Lock On from another source - unlike
	# Lockon.apply, which is the vanilla-shaped guard the Harbinger itself calls. Unguarded appliers
	# exist (e.g. ms_athena_class_nhp/deployable/action_simulacrum_lock_on.gd:9). Clearing that OTHER
	# lock fires the identical statuses_changed POST event while the Harbinger's own lock is still
	# live, and the old code paid nothing and cleared the mark anyway - so the REAL later consume of
	# the Harbinger's own lock would pay nothing at all.
	var ally := ally_at(IN_SENSORS)
	await crit(black_mountain)
	assert_locked_and_marked(hostile, 'fixture:')
	var other_gear:GearCore = ally.get_gear(Fixture.MAIN_RIFLE) # any OTHER gear will do as a second source
	await stack_and_clear_another_lock(hostile, other_gear.persistent_id)
	assert_true(Fixture.is_locked(hostile), 'LIVENESS: the Harbinger\'s own lock is still there.')
	assert_eq(Fixture.marks(hostile), 1, 'The mark survives a loss that was not its own lock\'s.')
	Fixture.queue([6, 6, 6, 6, 6, 6])
	await Fixture.shoot(game, ally, hostile) # consumes the Harbinger's REAL lock
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: the real consume landed.')
	assert_eq(Overshield.current(black_mountain), 6, 'And the later real consume still pays.')
	assert_eq(Fixture.marks(hostile), 0, 'The mark cleared on the real loss.')

func test_a_lock_lost_any_other_way_pays_nothing_and_clears_the_mark() -> void:
	await crit(black_mountain)
	assert_locked_and_marked(hostile, 'fixture:')
	await Fixture.clear_like_stabilize(game, hostile, Lancer.STATUS.LOCKON)
	assert_false(Fixture.is_locked(hostile), 'LIVENESS: cleared by ability.')
	assert_eq(Overshield.current(black_mountain), 0, 'Nothing paid (ruling 9\'s "lost otherwise" branch).')
	assert_eq(Fixture.marks(hostile), 0, 'The mark is gone with the lock.')

func test_the_marks_rows_resolve() -> void:
	assert_eq(X.tr('gear.buff_dread_harbinger_mark.name'), 'Dread Harbinger', 'Named for the trait.')
	assert_eq(X.tr('gear.buff_dread_harbinger_mark.effect'), 'When this |Lock On| is consumed, the Black Mountain gains 1d6 |Overshield|.',
		'The card\'s second sentence, in Bel\'s words (ruling 15).')
