# SPIKE 6 PROBE (roadmap §5 row 6): can "Smart weapons Critically Hit on an attack roll of 18 or
# higher rather than 20" reach the roll evaluation? For the Naga's Advanced Targeting Calculations.
# Doc: specs/2026-09-22-crit-threshold-feasibility.md.
#
# No production code is added. The roadmap pointed at dice.gd and unit_hasecheck.gd because those
# are the two files Karma Dice proves live for a .gd_ext.gd - but neither decides a crit. The ONE
# line that does is attack_roll.gd:73, `crit = (total_roll >= 20) and hit and can_crit`, on a
# class_name RefCounted that no extension can reach. What CAN reach it is the vanilla step that runs
# right after it: EventUnitAttack.prospective_hit (event_unit_attack.gd:196-210) asks every
# Buff.TO.MODIFY_ATTACK_ROLL buff on the attacker and the target for SEQUENCE_STEP.turn_hit_to_crit
# and, if one confirms, re-routes the roll through prospective_crit. Markerlight's Weak Spot is the
# vanilla user (buff_markerlight_weak_spot.tres, step = 5). The buff is handed a context whose
# `object` is the AttackRoll itself and whose `action` / `gear` are the weapon (get_buffs_for_step,
# :345-354), so "18 or higher" and "Smart" are both one read away.
#
# WHAT THIS FILE MEASURES, with a stand-in buff built in code (no .tres; specs are not scanned):
#   a. the vanilla baseline: an 18 is a plain hit, a 20 is a crit                (control)
#   b. under the buff, a Smart 18 and a Smart 19 are crits
#   c. the threshold is exact: a Smart 17 is a plain hit
#   d. a NON-Smart 18 is a plain hit - the weapon read is live
#   e. a Smart 18 that MISSES stays a miss - prospective_hit only runs on hits, so "18+" can never
#      manufacture a crit out of a miss, which is the card's own rule (a crit is a hit)
#   f. the buff is PERMANENT: a trait buff is not is_onetime, so consume_buffs (unit_condition.gd:938)
#      filters it out and a second 18 in the same scene crits again
#   g. CRIT_IMMUNITY still wins: prospective_crit (:222-223) demotes the crit after our step, so an
#      Aegis' Defense Net beats Advanced Targeting Calculations exactly as it beats a natural 20
#
# MUTATION: set THRESHOLD to 20 -> b (both) and f go RED, a/c/d/e/g stay green. Drop the Smart
# clause -> d goes RED, the rest green. See the doc's Runs table.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_crit_threshold.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## Vanilla Smart weapon: GMS Nexus (Light), Aux, 1d3, Range 10, tags [smart]. One d20 and one damage
## die per shot.
const SMART_WEAPON := &'mw_nexus_light'
## Vanilla NON-Smart control: GMS Assault Rifle, 1d6, tags [reliable].
const PLAIN_WEAPON := &'mw_assault_rifle'
## Regenerative Shielding's crit immunity is a BARE Buff with to = &'crit_immunity' and no gate
## (npcf_regenerative_shielding_aegis.tres, sub_resource Resource_ogopk); this is that, in code.
## NOT buff_defense_net_crit_immunity: that one is gated on its OWNER's distance to the attacker
## (buff_defense_net_distance.gd), and a buff applied with no from_gear has no owner, so it never
## applies - measured on this file's first run (7/8, the immunity test red for that reason alone).
class CritImmunity extends Buff:
	func _init() -> void:
		compcon_id = &'buff_spike_crit_immunity'
		to = Buff.TO.CRIT_IMMUNITY

const SHOOTER_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(8, 4) # 4 out: inside Range 10, outside any threat

## The stand-in has no pilot licence level, so grit is 0 (pilot_core.gd:204) and a Smart weapon adds
## no tech attack either (calculate_flat_bonus reads `using`, which is WEAPON for a weapon). No
## accuracy dice are rolled without a modifier. total_roll == the cheated d20, and every test asserts
## that equality as its liveness line so a silent flat bonus cannot fake a threshold.
## E-DEF: a Smart weapon rolls against E-DEFENCE (action_attack_weapon.gd:251). The dummy's is set
## explicitly below, so hit/miss is known.
const TARGET_EDEF := 8
const EDEF_THAT_ONLY_A_19_BEATS := 19

var game:Gamemaster
var shooter:Unit
var target:Unit


## THE STAND-IN for Advanced Targeting Calculations: the Markerlight shape, permanent, attacker-side,
## gated on the roll and on the weapon.
class Crit18 extends BuffModifyAttackRoll:
	const THRESHOLD := 18
	## Every total_roll this buff was asked about at its step - the liveness record.
	static var asked:Array[int] = []

	func _init() -> void:
		compcon_id = &'buff_spike_crit_threshold'
		to = Buff.TO.MODIFY_ATTACK_ROLL
		step = EventUnitAttack.SEQUENCE_STEP.turn_hit_to_crit
		applies_when_holder_is = APPLIES_WHEN.attacker
		needs_confirmation = false
		is_onetime = false
		allow_tech = false

	func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
		if not super.check_if_passive_applies(core, context): return false
		var roll:AttackRoll = context.object
		asked.append(roll.total_roll)
		if not (context.action is ActionAttackWeapon): return false
		if not context.action.has_tag(Lancer.WEAPON_TAG.SMART, context): return false
		return roll.total_roll >= THRESHOLD


func before_each() -> void:
	Crit18.asked.clear()
	game = Fixture.create_game(self)
	shooter = SpecFactory.create_unit(game.map, SHOOTER_TILE)
	shooter.core.full_repair()
	target = Fixture.create_dummy(game, TARGET_TILE, 10)
	set_edef(TARGET_EDEF)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## create_dummy isolates the frame and rewrites evasion; E-DEF is the same Statblock's `edef`.
func set_edef(edef:int) -> void:
	target.core.frame.stat.edef = edef
	target.core.full_repair()

func arm(kit_id:StringName) -> GearCore:
	shooter.core.equip_system(kit_id)
	SpecFactory.apply_passive_buffs(shooter)
	return shooter.get_gear(kit_id)

func give_the_trait() -> BuffCore:
	return UnitCondition.apply_buff(SpecFactory.dummy_event(), shooter, Crit18.new())

func has_the_trait() -> bool:
	return UnitCondition.has_buff(shooter, &'buff_spike_crit_threshold')

## [d20, then a tail of 6s for the damage die]. The shooter's turn is cycled first, for the reason
## sluagh_fixture.shoot gives: the per-turn soft limit silently swallows a second shot in one turn.
func fire(weapon:GearCore, d20:int) -> AttackRoll:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 20: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

	if shooter.state.is_taking_turn: await SpecFactory.end_turn(game, shooter)
	await SpecFactory.start_turn(game, shooter)

	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = target,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary := core.context.resource as DeclaredAttackSummary
	assert_not_null(summary, 'fixture: the shot resolved to a DeclaredAttackSummary.')
	if summary == null or summary.attack_rolls.is_empty():
		fail_test('fixture: no attack roll was made.')
		return null
	var roll:AttackRoll = summary.attack_rolls[0]
	assert_eq(roll.total_roll, d20,
		'LIVENESS: total_roll is the cheated d20 - no flat bonus, no accuracy die.')
	return roll


# ===================== a. vanilla baseline =====================

func test_vanilla_an_18_is_a_hit_and_a_20_is_a_crit() -> void:
	var nexus := arm(SMART_WEAPON)
	var eighteen := await fire(nexus, 18)
	if eighteen == null: return
	assert_true(eighteen.hit, 'An 18 against E-DEF 8 hits...')
	assert_false(eighteen.crit, '...and is NOT a crit under vanilla (attack_roll.gd:73).')

	var twenty := await fire(nexus, 20)
	if twenty == null: return
	assert_true(twenty.crit, 'CONTROL: a 20 is a crit with no buff in play.')
	assert_true(Crit18.asked.is_empty(), 'CONTROL: nothing asked the stand-in - it is not on the unit.')


# ===================== b. the seam =====================

func test_under_the_trait_a_smart_18_is_a_crit() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	var roll := await fire(nexus, 18)
	if roll == null: return
	assert_true(roll.hit, 'It hits...')
	assert_true(roll.crit, '...AND IT IS A CRIT: turn_hit_to_crit re-routed an 18 through prospective_crit.')
	assert_eq(Crit18.asked, [18], 'The buff was asked exactly once, at the hit step, and saw the 18.')

func test_under_the_trait_a_smart_19_is_a_crit() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	var roll := await fire(nexus, 19)
	if roll == null: return
	assert_true(roll.crit, 'A 19 is a crit too.')


# ===================== c. the threshold is exact =====================

func test_under_the_trait_a_smart_17_is_a_plain_hit() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	var roll := await fire(nexus, 17)
	if roll == null: return
	assert_true(roll.hit, 'A 17 hits...')
	assert_false(roll.crit, '...and is not a crit: the threshold is 18, not "any hit".')
	assert_eq(Crit18.asked, [17], 'LIVENESS: the buff WAS asked and declined - not skipped.')


# ===================== d. the weapon read =====================

func test_under_the_trait_a_non_smart_18_is_a_plain_hit() -> void:
	var rifle := arm(PLAIN_WEAPON)
	give_the_trait()
	var roll := await fire(rifle, 18)
	if roll == null: return
	assert_true(roll.hit, 'The rifle hits on an 18...')
	assert_false(roll.crit, '...and does not crit: the buff reads the weapon and the rifle is not Smart.')
	assert_eq(Crit18.asked, [18], 'LIVENESS: the buff was asked about the rifle shot and declined.')


# ===================== e. never a crit out of a miss =====================

func test_under_the_trait_a_smart_18_that_misses_stays_a_miss() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	set_edef(EDEF_THAT_ONLY_A_19_BEATS)
	var roll := await fire(nexus, 18)
	if roll == null: return
	assert_eq(roll.pre.target_defense, EDEF_THAT_ONLY_A_19_BEATS,
		'LIVENESS: the roll was made against the raised E-DEF (a Smart weapon rolls against E-DEF).')
	assert_false(roll.hit, 'An 18 against 19 misses...')
	assert_false(roll.crit, '...and is no crit.')
	assert_true(Crit18.asked.is_empty(),
		'The buff was never even asked: turn_hit_to_crit is a step of prospective_HIT (:205).')


# ===================== f. permanence =====================

func test_the_trait_survives_its_own_use_and_fires_again() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	var first := await fire(nexus, 18)
	if first == null: return
	assert_true(first.crit, 'fixture: the first 18 crit.')
	assert_true(has_the_trait(),
		'The buff is still on the unit: check_buffs_for_step consumes only is_onetime buffs '
		+ '(unit_condition.gd:938) and a trait buff is not one.')

	var second := await fire(nexus, 18)
	if second == null: return
	assert_true(second.crit, 'And the second 18 crits again.')
	assert_eq(Crit18.asked, [18, 18], 'Asked once per shot.')


# ===================== g. crit immunity still wins =====================

func test_crit_immunity_on_the_target_demotes_the_trait_crit_to_a_hit() -> void:
	var nexus := arm(SMART_WEAPON)
	give_the_trait()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), target, CritImmunity.new())
	assert_true(UnitCondition.has_buff_to(target, Buff.TO.CRIT_IMMUNITY),
		'fixture: the target holds a live CRIT_IMMUNITY buff.')

	var roll := await fire(nexus, 18)
	if roll == null: return
	assert_true(roll.hit, 'It hits...')
	assert_false(roll.crit,
		'...but CRIT_IMMUNITY demotes it (prospective_crit :222-223 runs AFTER our step), as it would a 20.')
	assert_eq(Crit18.asked, [18], 'LIVENESS: our step fired; the demotion came after it.')
