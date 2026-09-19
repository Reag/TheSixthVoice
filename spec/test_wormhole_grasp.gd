# WORMHOLE GRASP - the first of GLIMMERING ARMAMENTS' two effects (Primrose SP1 Task 5).
#
#   "Your weapons gain +1 threat and you may Overwatch with Superheavy weapons. Attacks made this way
#    deal half damage, Heat, and Burn. 1/round, when you damage a character with an Overwatch, they
#    must succeed a Hull save or be Slowed until the end of their next turn."
#
# FOUR BUFFS: the visible marker (which is all the unit_relation extension reads), an UNFILTERED
# threat bonus, an ATTACK_DECLARED PRE observer that stamps Action.FLAG.HALF_DAMAGE, and a
# BuffWeaponTypeOnHit carrying the Hull save.
#
# THE SUPERHEAVY WAIVER IS NOT BUILT HERE. res/engine/character/unit/service/unit_relation.gd_ext.gd
# was built and measured by the SP1 probe (spec/test_unit_relation_extension.gd, 8 tests), which
# applies the raw marker and asks the engine directly at every depth. THIS file proves the other half:
# that pressing the protocol produces a marker the waiver recognises, and that a real hostile move
# then draws a real Overwatch with a Superheavy weapon.
#
# TWO ROUTES TO AN OVERWATCH, AND BOTH ARE USED ON PURPOSE. ms_overwatch is ITSELF 1/round -
# ActionReaction.get_per_round_hard_limit returns 1 for a consuming reaction (action_reaction.gd:66) -
# so a second real overwatch inside one round is impossible and this trait's OWN 1/round could never
# be reached. Every case except the real-move one therefore fires the weapon directly with
# SpecFactory.use_solo(..., [Action.FLAG.IS_OVERWATCH]); flags flow from event_gear_activate straight
# into event_unit_attack_declared unchanged (action_attack.gd:267-272 passes context.flags), so the
# two routes are identical from the declared event down, which is where everything in this file is
# read. Stated as a limitation, not hidden: the OFFER is proved on the real route and the BOOKKEEPING
# on the flag route.
#
# TYPED-LOCAL TRAP: a property declared on a Buff SUBCLASS cannot be read through a `Buff`-typed
# local - GDScript resolves members at parse time and the whole file would be SKIPPED, not failed
# (memory lancer-tactics-spec-harness-traps). So test_the_bundle_is_wired takes the two subclass
# buffs UNTYPED and keeps the `is` assertions as the type evidence.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_wormhole_grasp.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const CORE_ID := &'cp_mobian_rainbow'
const MARKER := &'buff_wormhole_grasp'
const USAGE_KEY := &'wormhole_slow'

## The Combat Drill cheated to all sixes: 3d6 kinetic = 18, plus 1d6 energy = 6. Armour 0 on every
## dummy here and the weapon is AP anyway, so an unhalved hit is exactly 24 and a halved one is
## ceil(18/2) + ceil(6/2) = 9 + 3 = 12. Util.half is ceili (util.gd:14-15) and the flag is applied
## PER DAMAGE TYPE (event_unit_attack_declared.gd:150-163), which is why 12 and not ceil(24/2).
const DRILL_FULL := 24
const DRILL_HALVED := 12
## The Torch's flat 3 BURN, and its half. No dice, so this number cannot drift.
const TORCH_BURN := 3
const TORCH_BURN_HALVED := 2

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 5)    ## distance 1 - inside every threat here, and a legal move start
const WALK_TO := Vector2i(7, 7)     ## distance 3 from ADJACENT; a speed-4 hostile can reach it

var game:Gamemaster
var responder
var primrose:Unit
var mover:Unit

func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self, MAP_SIZE)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	# evasion -10: every overwatch in this file has to land, and the crit half is never wanted.
	mover = PrimroseFixture.create_hostile(game, ADJACENT, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func mark() -> void:
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_true(UnitCondition.has_buff(primrose, MARKER), 'fixture: the marker landed.')

## Fire `weapon_id` at the mover AS AN OVERWATCH - see the file header for why this route exists.
func overwatch_with(weapon_id:StringName) -> void:
	await SpecFactory.use_solo(game, primrose, weapon_id, mover, [Action.FLAG.IS_OVERWATCH])

## The SAME shot again inside ONE open turn. AS_FREEBIE is load-bearing, not decoration: the per-turn
## soft limit silently refuses a second activation of one weapon in a turn (action.gd:161-163) with no
## "Gear not available" line at all - only `[ ABORT event_gear_activate ] ... specific: invalid` - so
## the shot never fires and a "the second one does nothing" assertion passes for the boring reason.
## event_gear_activate.gd:45,51 -> unit_action.gd:114 makes AS_FREEBIE bypass activation LEGALITY
## only; it never reaches a buff's own round gate in check_if_passive_applies, which is the thing
## under test. Every caller pairs this with a vacuity guard on the mover's damage.
func overwatch_again_with(weapon_id:StringName) -> void:
	await SpecFactory.use_solo(game, primrose, weapon_id, mover,
		[Action.FLAG.IS_OVERWATCH, Action.FLAG.AS_FREEBIE])

## Fire the same weapon with no flags at all.
func attack_with(weapon_id:StringName) -> void:
	await SpecFactory.use_solo(game, primrose, weapon_id, mover)

func offers_superheavy(list:Array[SpecificAction]) -> bool:
	for specific:SpecificAction in list:
		if specific.gear.kit.compcon_id == PrimroseFixture.SUPERHEAVY_MELEE: return true
	return false

func core_gear() -> GearCore:
	return primrose.get_gear(CORE_ID)

func slow_uses() -> int:
	var gear := core_gear()
	return gear.get_uses_this_round_alt(USAGE_KEY) if GearCore.is_valid(gear) else -1

# ---------------------------------------------------------------- wiring and text

func test_the_bundle_is_wired():
	var marker:Buff = ContentLibrary.get_buff(MARKER)
	assert_not_null(marker, '%s is in the buffs index.' % MARKER)
	if marker == null: return
	assert_eq(marker.until, Lancer.UNTIL.MANUAL, 'The marker lasts the scene.')
	assert_false(marker.hide_from_player, 'And is VISIBLE: it is the only sign which armament is up.')
	assert_eq(marker.to, Buff.TO.NONE,
		'It modifies nothing itself - it is an identity the extension and the specs read by id.')

	var threat = ContentLibrary.get_buff(&'buff_wormhole_grasp_threat')
	assert_not_null(threat, 'buff_wormhole_grasp_threat is in the buffs index.')
	if threat == null: return
	assert_true(threat is BuffBonus, 'It is a plain BuffBonus.')
	assert_false(threat is BuffWeaponType,
		'And NOT a BuffWeaponType: ruling 11 says EVERY weapon, so there is nothing to filter on.')
	if threat is not BuffBonus: return
	assert_eq(threat.to, Buff.TO.ACTION_RANGE, 'On the action-range channel.')
	assert_eq(threat.bonus_subtype, Buff.BONUS_SUBTYPE.THREAT_RANGE, 'Threat, specifically.')
	assert_eq(threat.bonus_value, 1, 'By one.')
	assert_false(threat.overrides, 'Additive, so it stacks with Artful Caress (ruling 11).')

	var half:Buff = ContentLibrary.get_buff(&'buff_wormhole_grasp_half')
	assert_not_null(half, 'buff_wormhole_grasp_half is in the buffs index.')
	if half == null: return
	assert_eq(half.triggers_on, [&'attack_declared'] as Array[StringName],
		'It watches the DECLARED attack, which is the only event that still carries the flags '
		+ 'before damage is built (event_unit_attack_declared.gd:21-23 against :158-163).')
	assert_eq(half.trigger_timing, ReactionBus.TIMING.PRE, 'At PRE.')
	assert_true(half.hide_from_player, 'And is hidden - the marker is the chip.')

	var slow = ContentLibrary.get_buff(&'buff_wormhole_grasp_slow')
	assert_not_null(slow, 'buff_wormhole_grasp_slow is in the buffs index.')
	if slow == null: return
	assert_true(slow is BuffWeaponTypeOnHit, 'It supplies an on-hit effect.')
	if slow is not BuffWeaponTypeOnHit: return
	assert_true(slow.hide_from_player, 'Hidden.')
	assert_eq(slow.weapon_sizes, [] as Array[int], 'With no size filter: the card says "an Overwatch".')
	assert_eq(slow.weapon_types, [] as Array[int], 'And no type filter.')
	assert_true(slow.allow_basic,
		'Including basic gear - an overwatch with a basic weapon is still an Overwatch, and '
		+ 'BuffWeaponType refuses basics by default (buff_weapon_type.gd:55).')
	assert_eq(slow.effects.size(), 1, 'Carrying one OnHitEffect.')
	if slow.effects.is_empty(): return
	var effect:OnHitEffect = slow.effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_HIT, 'Which fires on a HIT (ruling 10).')
	assert_eq(effect.statuses, [&'slowed'] as Array[StringName], 'Applying Slowed.')
	assert_true(effect.save_to_avoid, 'Avoidable by a save.')
	assert_eq(effect.save_type, Lancer.HASE.HULL, 'A Hull save.')

func test_the_rows_resolve_and_the_marker_has_its_own_card():
	for key:String in ['gear.buff_wormhole_grasp.name', 'gear.buff_wormhole_grasp.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.buff_wormhole_grasp.name'), 'Wormhole Grasp', 'Named off the card.')

# ---------------------------------------------------------------- the threat

func test_every_weapons_threat_rises_by_one():
	# RULING 11: UNFILTERED. A rifle is the case that says so - Artful Caress cannot touch it, so the
	# whole difference here is Wormhole Grasp's. Every weapon in the engine has a threat: the export
	# defaults to 1 (action_attack_weapon.gd:16).
	PrimroseFixture.equip_main_rifle(primrose)
	var rifle := PrimroseFixture.specific(primrose, PrimroseFixture.MAIN_RIFLE)
	assert_eq(rifle.action.threat_distance(rifle), 1, 'fixture: the rifle threatens 1 to begin with.')

	await mark()

	assert_eq(rifle.action.threat_distance(rifle), 2,
		'Wormhole Grasp widens a RANGED weapon\'s threat too (ruling 11).')

func test_the_threat_stacks_with_artful_caress():
	# RULING 11's second half, and the reason both buffs are additive rather than overriding:
	# threat_distance SUMS every ACTION_RANGE/threat_range buff (action_attack_weapon.gd:187-190,
	# BuffBonus.get_bonus_for_subtype), so a Superheavy melee weapon under both reads printed + 1 + 1.
	PrimroseFixture.equip_superheavy_melee(primrose)
	var drill := PrimroseFixture.specific(primrose, PrimroseFixture.SUPERHEAVY_MELEE)
	assert_eq(drill.action.threat, 1, 'fixture: the Drill prints threat 1.')
	assert_eq(drill.action.threat_distance(drill), 2, 'fixture: Artful Caress alone makes it 2.')

	await mark()

	assert_eq(drill.action.threat_distance(drill), 3, 'And Wormhole Grasp on top makes it 3.')

# ---------------------------------------------------------------- the waiver, through the protocol

func test_a_superheavy_melee_weapon_is_offered_to_overwatch_only_under_the_marker():
	# THE EXACT CALL action_overwatch.gd:21 MAKES. The probe asks this too, with the raw marker applied
	# by hand; this asks it after a real press, which is the half that proves the protocol produces a
	# marker the extension actually recognises.
	PrimroseFixture.equip_superheavy_melee(primrose)
	assert_false(offers_superheavy(UnitRelation.get_weapons_that_can_overwatch(primrose, mover)),
		'Vanilla refuses SUPERHEAVY, and so does the extension without the marker.')

	await mark()

	assert_true(offers_superheavy(UnitRelation.get_weapons_that_can_overwatch(primrose, mover)),
		'With the marker up, Overwatch offers the Drill.')

func test_a_real_hostile_move_draws_a_superheavy_overwatch_after_the_protocol():
	# THE END-TO-END CASE, and the only one in this file that goes through ms_overwatch. Modelled on
	# vanilla test/gear/test_ms_overwatch.gd: spec units carry ms_overwatch from the basic loadout, the
	# watcher only needs a weapon, and "did overwatch fire" reads off the mover's damage.
	#
	# THE DRILL IS THE ONLY MOUNTED WEAPON, deliberately: CommonActionUtil.choose_and_use raises a gear
	# pick when there is more than one, and the responder answers it with the first entry - so a second
	# weapon would make which one fired an accident of list order.
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.cheat_a_hit()

	await SpecFactory.move(game, mover, WALK_TO)

	assert_eq(mover.tile(), WALK_TO, 'fixture: it actually moved.')
	assert_gt(mover.current_damage(), 0,
		'The Drill fired as a real Overwatch, drawn by a real move, under a marker a real press applied.')

func test_an_unmarked_primrose_draws_no_superheavy_overwatch():
	# The control, and the one that keeps the test above from passing for the wrong reason.
	PrimroseFixture.equip_superheavy_melee(primrose)
	PrimroseFixture.cheat_a_hit()

	await SpecFactory.move(game, mover, WALK_TO)

	assert_eq(mover.tile(), WALK_TO, 'fixture: it actually moved.')
	assert_eq(mover.current_damage(), 0, 'Vanilla behaviour is intact without the marker.')

# ---------------------------------------------------------------- half damage

func test_an_overwatch_attacks_damage_is_halved_rounding_up():
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_eq(mover.current_damage(), DRILL_HALVED,
		'9 + 3, not 12: the HALVED flag is applied PER DAMAGE TYPE and Util.half is ceil.')

func test_a_normal_attacks_damage_is_not_halved():
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()

	PrimroseFixture.cheat_a_hit()
	await attack_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_eq(mover.current_damage(), DRILL_FULL,
		'The same weapon, the same marker, no IS_OVERWATCH flag: full damage.')

func test_the_half_damage_needs_the_marker():
	# Without this, "halved" above would be satisfied by anything at all that halved overwatch damage -
	# including a vanilla rule nobody wrote.
	PrimroseFixture.equip_superheavy_melee(primrose)

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_eq(mover.current_damage(), DRILL_FULL, 'An unmarked overwatch deals full damage.')

func test_an_overwatch_attacks_burn_is_halved_too():
	# "half damage, HEAT, AND BURN" (ruling 9). The flag is type-agnostic: event_unit_attack_declared
	# loops every entry of damage_and_types and calls get_damage_flags once per type (:150-163), so one
	# line halves all five. The Torch carries a FLAT 3 BURN beside its 1d6 energy, so this number
	# involves no dice and cannot drift. Proving a second type is what makes the loop, rather than one
	# special case, the thing under test.
	#
	# A MAIN MELEE WEAPON, deliberately: the half-damage buff carries no size filter, and using a
	# weapon vanilla would let overwatch anyway keeps the waiver out of this measurement entirely.
	PrimroseFixture.equip(primrose, PrimroseFixture.BURN_MELEE)
	await mark()

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.BURN_MELEE)

	assert_eq(mover.state.burn, TORCH_BURN_HALVED, 'Three Burn becomes two - ceil(3/2).')

func test_a_normal_attacks_burn_is_not_halved():
	PrimroseFixture.equip(primrose, PrimroseFixture.BURN_MELEE)
	await mark()

	PrimroseFixture.cheat_a_hit()
	await attack_with(PrimroseFixture.BURN_MELEE)

	assert_eq(mover.state.burn, TORCH_BURN, 'The same weapon off overwatch burns for three.')

# ---------------------------------------------------------------- the Slowed

func test_an_overwatch_hit_forces_a_hull_save_and_slows_on_failure():
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.force_save_to_fail(mover)

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_gt(mover.current_damage(), 0, 'fixture: the overwatch landed.')
	assert_true(mover.has_status(Lancer.STATUS.SLOWED), 'A failed Hull save leaves it Slowed.')
	assert_eq(slow_uses(), 1, 'And the 1/round is spent.')

func test_the_slow_lasts_until_the_end_of_the_targets_next_turn():
	# RULING 10: END_OF_NEXT_TURN, which is the status's own standard (content/statuses/status_slowed.tres
	# declares standard_until = 1) - so OnHitEffect.get_applied_duration_for_statuses needs no override
	# and there is deliberately none. This test is what would notice one being added.
	#
	# SOURCED TO THE WEAPON, NOT THE CORE KIT - corrected against the 1.4.3 engine on 2026-09-19. The
	# task brief asked for primrose.get_gear(CORE_ID).persistent_id here and that came back NULL when
	# it was first run: OnHitEffect.apply_statuses_and_buffs reads `context.gear.persistent_id`
	# (on_hit_effect.gd:80-83), and `context` belongs to the event_unit_attack, whose gear is the
	# WEAPON that fired (event_unit_attack.gd:43) - never the Kit whose buff supplied the effect. The
	# 1/round is still bookkept on the core Kit, because onhit_wormhole_grasp_slow.gd looks that gear
	# up by id itself rather than reading it out of the context.
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.force_save_to_fail(mover)

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)

	var weapon_source := primrose.get_gear(PrimroseFixture.SUPERHEAVY_MELEE).persistent_id
	var condition:StatusCondition = UnitCondition.get_status(mover, Lancer.STATUS.SLOWED, weapon_source)
	assert_not_null(condition, 'The Slowed is sourced to the WEAPON that fired the overwatch.')
	if condition == null: return
	assert_eq(condition.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'Until the end of their next turn.')

func test_a_passed_save_leaves_the_target_unslowed_and_still_spends_the_round():
	# RULING 10: the round is spent by FORCING the save, pass or fail - the Knock 'em down pattern. The
	# usage assertion is what discriminates: without it this test would pass identically against a
	# trait that never fired.
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.force_save_to_pass(mover)

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_gt(mover.current_damage(), 0, 'fixture: the overwatch landed.')
	assert_false(mover.has_status(Lancer.STATUS.SLOWED), 'A passed save leaves it moving freely.')
	assert_eq(slow_uses(), 1, 'And the round is spent anyway.')

func test_the_second_overwatch_hit_in_a_round_forces_no_save():
	# BOTH OVERWATCHES IN ONE TURN, because "1/round" is cleared by UnitAction.new_turn_refresh at the
	# PRIMROSE'S OWN turn start (unit_action.gd:73-78, :87-88) - a start_turn between them would make
	# this vacuous. This is the case that only the flag route can reach: ms_overwatch is itself 1/round
	# (action_reaction.gd:66), so two REAL overwatches in one round do not exist.
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.force_save_to_pass(mover)

	PrimroseFixture.cheat_a_hit()
	await overwatch_with(PrimroseFixture.SUPERHEAVY_MELEE)
	assert_eq(slow_uses(), 1, 'fixture: the first overwatch spent the round despite the passed save.')

	# The save is now pinned to auto-FAIL: if the round limit were not gating the buff, this hit would
	# force a save and the mover would be Slowed. force_save_to_fail full_repairs the MOVER, so its
	# damage is back at zero and the assertion below is a real vacuity guard on the second shot.
	PrimroseFixture.force_save_to_fail(mover)
	PrimroseFixture.cheat_a_hit()
	await overwatch_again_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_gt(mover.current_damage(), 0,
		'VACUITY GUARD: the second shot really fired. Without AS_FREEBIE the per-turn soft limit '
		+ 'aborts it silently and everything below passes for the boring reason.')
	assert_false(mover.has_status(Lancer.STATUS.SLOWED),
		'The second overwatch in the same round forces nothing.')
	assert_eq(slow_uses(), 1, 'And spends nothing further.')

func test_a_normal_hit_forces_no_save():
	# "when you damage a character with an OVERWATCH". The on-hit aborts unless the activation carries
	# Action.FLAG.IS_OVERWATCH - the Tortuga's onhit_hyper_reflex_mode_immobilize.gd line for line.
	PrimroseFixture.equip_superheavy_melee(primrose)
	await mark()
	PrimroseFixture.force_save_to_fail(mover)

	PrimroseFixture.cheat_a_hit()
	await attack_with(PrimroseFixture.SUPERHEAVY_MELEE)

	assert_gt(mover.current_damage(), 0, 'fixture: the attack landed.')
	assert_false(mover.has_status(Lancer.STATUS.SLOWED), 'A normal hit slows nobody.')
	assert_eq(slow_uses(), 0, 'And spends nothing - so the round is still there for a real overwatch.')
