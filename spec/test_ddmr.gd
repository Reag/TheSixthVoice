# THE DDMR (Primrose SP3 Task 4, a weapon mod).
#
#   "DDMR
#    SP 3 | Fits: types ['Melee'] | sizes ['Heavy', 'Superheavy']
#    Adds tags: UNIQUE
#    Effect: This weapon gains +1 Threat. 1/round, on a hit with the weapon this mod is applied to,
#    the next attack against you has +1 Difficulty until the start of your next turn."
#   (specs/sixth-voice/07-primrose.md, Rank II, "Weapon mod: DDMR")
#
# RULING 23 (author, 2026-09-19): the on-hit chip is PassiveWeaponMod.on_hit_effects, not a
# BuffWeaponTypeOnHit. event_unit_attack.gd:43-45 collects `context.gear.get_weapon_mod_passives
# (owner.core.loadout)` and appends every PassiveWeaponMod's on_hit_effects into mod_on_hit_effects,
# fired at :67/:85/:91 BESIDE the action's own - already scoped to the weapon the mod is fitted to,
# by the engine, with no buff needed for that half. This is why wm_ripper_mod.tres (this mod's other
# weapon-mod Kit, res/content/gear/ipsn/systems/wm_ripper_mod/) is the template referenced throughout
# rather than a BuffWeaponTypeOnHit trait like Magnetic Weight Redistribution's.
#
# RULING 24 (author, 2026-09-19): the chip is named "DDMR" verbatim - the mod's own name off the
# card, not an invented string. Its buff is therefore visible (VISIBLE_BUFFS below), unlike Biting
# Retort's hidden difficulty chip: attack_roll.gd:189 titles an incoming-buff line with
# buff_core.name_text(), and Translate.buff (translate.gd:49-58) falls back to `gear.<compcon_id>.*`
# when there is no localization_key_override - so buff_ddmr_aegis needs no override at all, only its
# own `gear.buff_ddmr_aegis.name` / `.effect` CSV rows.
#
# ---------------------------------------------------------------------------------------------
# WHY THE ROUND LIMIT IS HAND-ROLLED IN THE ON-HIT SCRIPT AND NOT IN A BUFF'S check_if_passive_applies
# (unlike Magnetic Weight Redistribution's buff_magnetic_weight_redistribution.gd, which gates
# get_uses_this_round_alt inside check_if_passive_applies): ruling 23's collection path
# (PassiveWeaponMod.on_hit_effects, event_unit_attack.gd:43-45/:67/:85) is unconditional - it carries
# no per-passive gate of its own, unlike Buff.TO.ONHIT_EFFECT's route through
# UnitCondition.get_buffs_to. So the 1/round has to live on the OnHitEffect's own should_abort, the
# wormhole_grasp/magnetic_weight shape one level down: onhit_wormhole_grasp_slow.gd and
# onhit_magnetic_weight_redistribution.gd are both read before writing onhit_ddmr.gd. Unlike either of
# those two, onhit_ddmr.gd's gate ALSO aborts (skips the buff) when the round is already spent -
# wormhole's and MWR's traits both let their effect through every time and rely on a save-avoid /
# declarative gate elsewhere for their "1/round" to mean anything measurable; the DDMR has no such
# second gate, so should_abort's own true/false IS the round limit.
#
# WHY THE COUNTER LIVES ON THE MOD'S OWN GEAR, NOT THE WEAPON'S. unit.get_gear(&'wm_ddmr')
# (unit.gd:220-225) reads core.loadout.get_by_compcon_id, backed by the compcon_id_to_gear cache
# that LoadoutCore.regenerate_caches() (loadout_core.gd:284-289, called from
# regenerate_derived_gear at :275) rebuilds from get_all_gear() - which includes `systems`, where
# LoadoutCore.equip_weapon_mod appends the mod's own GearCore (loadout_core.gd:356-362). Every
# equip/full_repair pass (UnitPrinter.full_repair -> full_repair_loadout -> regenerate_derived_gear)
# rebuilds that cache, so the mod's gear is findable by its own compcon_id after
# SpecFactory.apply_passive_buffs the same way any equipped system is.
# test_the_units_own_get_gear_resolves_the_fitted_mod BELOW IS THE MEASUREMENT THE PLAN ASKED FOR,
# not an assumption: onhit_ddmr.gd's should_abort is dead code if this does not resolve, and the
# whole 1/round gate silently never engages (every hit would then either always chip or never chip,
# depending which way the null read fails).
#
# WHY THE INCREMENT HAPPENS BEFORE super(stage, ...): should_abort's own base body
# (on_hit_effect.gd:54-73) only rolls a save_to_avoid, which this OnHitEffect does not use (no
# save_to_avoid on onhit_ddmr.tres) - so there is no "roll a save first, spend second" ordering
# question here the way ruling 10's Slowed effect has one. The increment is placed before the round
# check's own early return so a card that already used its round this turn is refused WITHOUT ever
# touching the counter a second time.
#
# WHY increment_action_usage's SECOND ARGUMENT IS false: it gates only the uses_this_turn tally
# (gear_core.gd:171-181); the per-round counter this gate reads (uses_this_round, via
# get_uses_this_round_alt) is written either way, and nothing in this mechanism reads a per-turn
# count under this key. Matches onhit_wormhole_grasp_slow.gd and
# onhit_magnetic_weight_redistribution.gd's identical choice.
#
# ---------------------------------------------------------------------------------------------
# HOW "1/ROUND" IS ACTUALLY CLEARED, AND WHY THE FIXTURE ADVANCES THE PRIMROSE'S OWN TURN, NOT A
# GLOBAL ROUND EVENT. UnitAction.reset_per_round_usage (unit_action.gd:86-88) is called only from
# new_turn_refresh, which unit_action.gd:73 says outright is "Called only on us starting a new turn" -
# i.e. the OWNING unit's own turn start, not any unit's, and not a global event_round_new (that event
# exists and matters for OTHER mods' hand-rolled stamps - see test_symbiosis.gd - but GearCore's own
# uses_this_round dictionary is cleared by a unit's own turn start alone).
# test_magnetic_weight_redistribution.gd:249-309 is the precedent this file's round tests copy:
# SpecFactory.end_turn(game, primrose) then SpecFactory.start_turn(game, primrose), never
# event_round_new.
#
# THE CHIP'S OWN until = START_OF_OWNERS_TURN (6, counted off Lancer.UNTIL at lancer.gd:45-56: 0
# MANUAL, 1 END_OF_NEXT_TURN, 2 END_OF_THIS_TURN, 3 START_OF_TURN, 4 END_OF_MOVE, 5 FORCED_SAVE, 6
# START_OF_OWNERS_TURN) clears through the SAME event, a different mechanism -
# event_turn_start.gd:77's UnitCondition.clear_owners_turn_statuses, gated on
# BuffCore.is_unit_owner(unit) (buff_core.gd:97-100), which resolves true here because the chip's
# from_gear is the WEAPON (apply_buffs_to_self routes through context.gear, on_hit_effect.gd:79-83),
# and that weapon sits in the PRIMROSE's own loadout - so "the owner" is the Primrose whichever
# weapon carried the mod. Both mechanisms fire off the identical event_turn_start, which is why one
# fixture call (SpecFactory.start_turn(game, primrose)) proves both at once in
# test_the_next_round_raises_it_again.
#
# ---------------------------------------------------------------------------------------------
# WHY THE CHIP TESTS USE mw_heavy_melee_weapon, NOT THE FALCATA, AND NEED NO PROMPT RESPONDER. The
# Falcata also carries action_biting_retort (Task 2/3), a PRE reaction that raises a yes/no on ANY
# hostile melee attack against the Primrose - fitting the DDMR to the Falcata for the "hostile attacks
# the Primrose" half of these tests would conflate two mechanisms and need the same Brace/prompt
# bookkeeping test_biting_retort.gd carries. Fitting it to the vanilla Heavy Melee Weapon instead
# sidesteps that entirely: that Kit carries no reaction, so a hostile's attack on the Primrose here
# only ever meets the DDMR's own chip. (Task 5's stacking pin is where the Falcata, Artful Caress,
# Wormhole Grasp AND the DDMR are deliberately all in play together.)
#
# Vanilla ms_brace still sits on the Primrose's basic loadout and could in principle offer a second
# yes/no when a hit lands (content/gear/basic/ms_brace/action_brace.gd:13-46 gates on incoming damage
# being at least half max health) - so every attack against the Primrose in this file is dice-pinned
# to low, non-threshold damage (pin_dice below pins every damage die to 1) rather than dropped from
# the loadout, which keeps Brace's own trigger condition false without a drop_brace() helper this
# file does not otherwise need.
#
# ---------------------------------------------------------------------------------------------
# HOW THE ROLL'S ACCURACY IS MEASURED: RollRecorder, copied from test_biting_retort.gd (its own header
# explains the mechanism - a Buff.TO.MODIFY_ATTACK_ROLL passive that never applies and only keeps a
# reference to the live AttackRoll, so accuracy_mods_total() reads the roll's own named breakdown
# rather than inferring anything from hit/miss).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_ddmr.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const DDMR := &'wm_ddmr'
const FALCATA := &'mw_acrasial_falcata'
const AEGIS_BUFF := &'buff_ddmr_aegis'

## The card's numbers, transcribed once so a typo in the .tres reads as a number and not as a vague
## "feels wrong".
const SP_COST := 3
## 3 (printed) + 1 Artful Caress (mt_artful_caress, applies automatically to any Heavy/Superheavy
## melee weapon the Primrose carries) = the Falcata's threat BEFORE the DDMR is fitted at all.
const THREAT_WITH_CARESS := 4

const MAP_SIZE := Vector2i(15, 9)
const PRIMROSE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)

## The one die not pinned to 1: the accuracy/difficulty die. Dice.roll_d6_accuracy(-1) rolls one d6,
## takes the max and multiplies by signi(count) (dice.gd:86-88), so a 6 here reads back as
## accuracy_roll == -6 - the identical idiom test_biting_retort.gd uses.
const ACCURACY_DIE := 6
const HIT_D20 := 19   ## beats the Primrose's evasion 8 even at -6, and beats hostile's -10 evasion always
const MISS_D20 := 1   ## cannot beat any evasion this fixture hands out

var game:Gamemaster
var primrose:Unit
var hostile:Unit


# ============================== THE MEASUREMENT INSTRUMENT ==============================

## A passive that never applies and only takes a reference to the AttackRoll it was shown. Copied
## from test_biting_retort.gd's RollRecorder (itself Task 0's instrument) - see that file's header for
## why it can be trusted: check_if_passive_applies is polled with the live roll already built
## (event_unit_attack.gd:53 then :144), returns false so it is never collected or consumed, and the
## roll is mutated in place afterwards (attack_roll.gd:65-71), so the same reference reads back the
## final accuracy_mods_total().
class RollRecorder extends Buff:
	var last_roll:AttackRoll = null

	func _init() -> void:
		to = Buff.TO.MODIFY_ATTACK_ROLL
		hide_from_player = true

	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		if AttackRoll.is_valid(context.object): last_roll = context.object
		return false ## never actually a modifier, so never collected and never consumed


# ============================== FIXTURE ==============================

func before_each() -> void:
	game = PrimroseFixture.create_game(self, MAP_SIZE)
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	hostile = PrimroseFixture.create_hostile(game, ADJACENT, -10) # every swing FROM the Primrose hits
	hostile.core.frame.stat.health = 200
	hostile.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## Equip a Kit as a system and hand back its GearCore - the plain equip half of
## PrimroseFixture.fit_ddmr's own precondition (test_ripper_mod.gd's equip_modded records the same
## "equip everything before touching state" trap).
func equip(kit_id:StringName) -> GearCore:
	return primrose.core.equip_system(kit_id)

## Pin the whole global cheat queue: the d20, then the accuracy die, then forty 1s of buffer - low
## enough that no hit in this file threatens the Primrose's 8 HP or crosses Brace's half-health
## trigger (see header).
func pin_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = [ACCURACY_DIE]
	for i:int in 40: buffer.append(1)
	Dice.cheat_attack([d20], buffer)

## How many buff_ddmr_aegis instances are on the Primrose right now. NOT has_buff(): the round-limit
## tests need to tell "still exactly one" apart from "a second one stacked on top", and
## UnitCondition.apply_buff/apply_buffs (unit_condition.gd:695-716) never deduplicates - each call
## creates a brand new BuffCore and appends it, so a broken round gate reads as a SECOND chip, not a
## refused one.
func chip_count() -> int:
	var count := 0
	for core:BuffCore in primrose.state.buffs:
		if core.base.compcon_id == AEGIS_BUFF: count += 1
	return count

## The chip's own BuffCore, or null if there is none right now. NEEDED BESIDE chip_count(), not
## instead of it - see test_a_second_hit_in_the_same_round_raises_nothing's header for why a raw
## count cannot discriminate "refused" from "replaced".
func chip_buff() -> BuffCore:
	for core:BuffCore in primrose.state.buffs:
		if core.base.compcon_id == AEGIS_BUFF: return core
	return null

## Hang a RollRecorder on the Primrose and hand it back.
func watch_roll() -> RollRecorder:
	var recorder := RollRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), primrose, recorder)
	return recorder

## One melee swing by the hostile at the Primrose, dice pinned, guarded against vacuity.
##
## MELEE, DELIBERATELY, NOT THE MAIN RIFLE - measured on this task's own first green run:
## action_attack_weapon.gd:254-255 makes is_difficulty_when_engaged() true for any non-MELEE weapon,
## and the hostile stands ADJACENT to the Primrose (ADJACENT, one tile away) so a ranged shot from
## there is "Engaged", carrying its OWN -1 into attack_roll.gd's accuracy_mods_total()
## (content/events/event_unit_attack/attack_roll.gd:166-167) - which read as -2 instead of the DDMR
## chip's -1 and would have made every chip measurement in this file silently wrong by one. A melee
## weapon (attack_attack_weapon.gd:255's `weapon_type != MELEE` gate) carries no such penalty while
## engaged, so it isolates the chip as the only accuracy source in play.
func attack_primrose(d20:int) -> void:
	await PrimroseFixture.open_turn(game, hostile)
	pin_dice(d20)
	var queued:int = Dice.CHEAT_ROLL_QUEUE.size()
	await SpecFactory.use_solo(game, hostile, PrimroseFixture.HEAVY_MELEE, primrose)
	assert_lt(Dice.CHEAT_ROLL_QUEUE.size(), queued, 'fixture: the attack on the Primrose really rolled.')


# ============================== THE KIT AND ITS FIT RULES ==============================

func test_the_kit_is_registered_and_costs_three_sp_and_is_unique() -> void:
	var kit:Kit = ContentLibrary.get_kit(DDMR)
	assert_not_null(kit, 'wm_ddmr is in the kits index.')
	# assert_not_null ALONE IS VACUOUS - content_library.gd:231-236 falls back to the shared
	# Kit.UNKNOWN_ID placeholder for an unregistered id rather than returning null
	# (test_acrasial_falcata.gd's identical finding). compcon_id is what tells the two apart.
	assert_eq(kit.compcon_id, DDMR, 'the id asked for, not the Kit.UNKNOWN_ID placeholder.')
	if kit == null: return
	assert_eq(kit.sp_cost, SP_COST, 'SP 3, per the card.')
	assert_true(kit.is_unique(), '"Adds tags: UNIQUE" is system_tags = 1 on the KIT (kit.gd:30,53) - '
		+ 'the mod itself is Unique, as the Rend Axe is, not an added_tags entry on the passive.')
	assert_eq(kit.get_passives(PassiveWeaponMod).size(), 1, 'Exactly one PassiveWeaponMod.')

func test_it_fits_a_heavy_melee_weapon() -> void:
	var weapon := equip(PrimroseFixture.HEAVY_MELEE)
	var mod := primrose.core.loadout.equip_weapon_mod(DDMR, weapon)
	assert_true(GearCore.is_valid(mod), 'A Heavy melee weapon (mw_heavy_melee_weapon) takes the mod.')
	if not GearCore.is_valid(mod): return
	assert_true(weapon.mod_ids.has(mod.persistent_id), 'and the weapon names it in mod_ids.')

func test_it_fits_a_superheavy_melee_weapon() -> void:
	var weapon := equip(PrimroseFixture.SUPERHEAVY_MELEE) # vanilla mw_combat_drill
	var mod := primrose.core.loadout.equip_weapon_mod(DDMR, weapon)
	assert_true(GearCore.is_valid(mod), 'A Superheavy melee weapon takes the mod too.')
	if not GearCore.is_valid(mod): return
	assert_true(weapon.mod_ids.has(mod.persistent_id), 'and the weapon names it in mod_ids.')

func test_it_refuses_a_main_melee_weapon() -> void:
	var weapon := equip(PrimroseFixture.MAIN_MELEE)
	var mod := primrose.core.loadout.equip_weapon_mod(DDMR, weapon)
	assert_null(mod, 'MAIN is not in allowed_sizes [HEAVY, SUPERHEAVY] - equip_weapon_mod refuses it '
		+ '(loadout_core.gd:344-351, gated on PassiveWeaponMod.is_applicable_to).')
	assert_true(weapon.mod_ids.is_empty(), 'and the weapon carries no mod at all.')

func test_it_refuses_a_heavy_rifle() -> void:
	var weapon := equip(PrimroseFixture.HEAVY_RIFLE)
	var mod := primrose.core.loadout.equip_weapon_mod(DDMR, weapon)
	assert_null(mod, 'RIFLE is not in allowed_types [MELEE] - refused despite being Heavy-sized, which '
		+ 'is the control that proves the mod filters on TYPE and not only on SIZE.')
	assert_true(weapon.mod_ids.is_empty(), 'and the weapon carries no mod at all.')

func test_the_units_own_get_gear_resolves_the_fitted_mod() -> void:
	# THE MEASUREMENT THE PLAN ASKED FOR, not an assumption: onhit_ddmr.gd's should_abort reads
	# unit.get_gear(&'wm_ddmr') to find the mod's own round counter, and the whole 1/round gate is
	# dead code if that resolves null. See this file's header for the citations.
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	var mod := PrimroseFixture.fit_ddmr(primrose, weapon)
	assert_true(GearCore.is_valid(mod), 'fixture: fit_ddmr returned a real GearCore.')
	var resolved:GearCore = primrose.get_gear(DDMR)
	assert_true(GearCore.is_valid(resolved), 'THE CLAIM: unit.get_gear(&\'wm_ddmr\') resolves the '
		+ 'fitted mod after equip_weapon_mod + apply_passive_buffs (full_repair rebuilds the cache).')
	if GearCore.is_valid(mod) and GearCore.is_valid(resolved):
		assert_eq(resolved.persistent_id, mod.persistent_id,
			'and it is the SAME GearCore instance equip_weapon_mod created, not some other lookup.')


# ============================== THE THREAT BUFF ==============================

func test_the_modded_weapon_gains_one_threat() -> void:
	var falcata := PrimroseFixture.equip(primrose, FALCATA)
	var before_specific := PrimroseFixture.specific(primrose, FALCATA)
	var before:int = before_specific.action.threat_distance(before_specific)
	assert_eq(before, THREAT_WITH_CARESS, 'fixture: printed 3 + Artful Caress, before any mod - 4.')

	PrimroseFixture.fit_ddmr(primrose, falcata)
	var after_specific := PrimroseFixture.specific(primrose, FALCATA)
	var after:int = after_specific.action.threat_distance(after_specific)
	assert_eq(after, THREAT_WITH_CARESS + 1,
		'THE CLAIM: +1 more from the DDMR - 3 printed + Artful Caress + DDMR = 5.')

func test_an_unmodded_weapon_on_the_same_mech_is_unchanged() -> void:
	PrimroseFixture.equip_heavy_melee(primrose)
	var control_specific := PrimroseFixture.specific(primrose, PrimroseFixture.HEAVY_MELEE)
	var before:int = control_specific.action.threat_distance(control_specific)
	# MEASURED, NOT TRUSTED (the plan's own instruction): the Heavy Melee Weapon prints threat 1
	# (mw_heavy_melee_weapon.tres) and Artful Caress covers Heavy melee too, so 2 is the expected
	# number here - asserted explicitly so a reader sees the real value rather than only a before/after
	# equality that a doubly-wrong pair of numbers could still satisfy.
	assert_eq(before, 2, 'REAL NUMBER MEASURED: 1 printed + 1 Artful Caress, unmodded.')

	var falcata := PrimroseFixture.equip(primrose, FALCATA)
	PrimroseFixture.fit_ddmr(primrose, falcata)

	var after_specific := PrimroseFixture.specific(primrose, PrimroseFixture.HEAVY_MELEE)
	var after:int = after_specific.action.threat_distance(after_specific)
	assert_eq(after, before,
		'THE CLAIM: from_weapon_mod (buff_ddmr_threat.tres) gates on is_weapon_mod_attached(core.'
		+ 'from_gear) (buff_weapon_type.gd:55) against the FALCATA specifically - the buff never '
		+ 'reaches this unmodded Heavy Melee Weapon on the same mech.')


# ============================== THE ON-HIT CHIP ==============================

func test_a_hit_raises_the_chip() -> void:
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	assert_eq(chip_count(), 0, 'fixture: no chip before any hit.')

	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_gt(hostile.current_damage(), 0, 'VACUITY GUARD: the hit really landed.')
	assert_eq(chip_count(), 1, 'THE CLAIM: the hit raised exactly one chip on the Primrose.')

func test_a_hit_with_an_unmodded_weapon_raises_nothing() -> void:
	PrimroseFixture.equip_heavy_melee(primrose) # NOT modded
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_gt(hostile.current_damage(), 0, 'VACUITY GUARD: the hit really landed.')
	assert_eq(chip_count(), 0, 'No mod fitted, no chip: ruling 23\'s on_hit_effects are only collected '
		+ 'from a weapon mod actually attached to the firing weapon (event_unit_attack.gd:43-45).')

func test_the_chip_puts_the_next_attack_on_us_at_minus_one_and_is_consumed() -> void:
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'fixture: the chip is up.')

	PrimroseFixture.equip_heavy_melee(hostile)
	var recorder := watch_roll()
	await attack_primrose(HIT_D20)

	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the attack on the Primrose really resolved.')
	assert_eq(recorder.last_roll.pre.accuracy_mods_total(), -1,
		'THE MEASUREMENT: the chip\'s -1 Difficulty landed on the attacker\'s roll.')
	assert_eq(recorder.last_roll.accuracy_roll, -ACCURACY_DIE,
		'Which costs the roll a full difficulty die (dice.gd:86-88).')
	assert_eq(chip_count(), 0,
		'is_onetime consumed it: event_unit_attack.gd:114 consumes the one-time buffs the roll '
		+ 'applied, so the chip is gone after the roll whether it hit or missed.')

func test_the_chip_is_consumed_by_a_missing_attack_as_well() -> void:
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'fixture: the chip is up.')

	PrimroseFixture.equip_heavy_melee(hostile)
	var recorder := watch_roll()
	await attack_primrose(MISS_D20)

	assert_not_null(recorder.last_roll, 'VACUITY GUARD: the attack on the Primrose really resolved.')
	assert_false(recorder.last_roll.hit, 'fixture: and it missed.')
	assert_eq(recorder.last_roll.pre.accuracy_mods_total(), -1, 'THE CHIP STILL LANDED on the miss.')
	assert_eq(chip_count(), 0,
		'RULING 17: consumed whether it hits or misses - is_onetime does not care about the outcome.')

func test_a_second_hit_in_the_same_round_raises_nothing() -> void:
	# MEASURED ON THIS TASK'S OWN MUTATION PASS: a first draft of this test asserted only chip_count()
	# == 1 after the second hit, and that assertion STAYED GREEN with onhit_ddmr.gd's
	# get_uses_this_round_alt gate deleted entirely - a false negative, not a passing mutation.
	# Root cause: UnitCondition.apply_buff_alt's "same buff from the same source" dedup
	# (unit_condition.gd:739-746) CLEARS an existing non-stacking buff (multiple_copies_can_stack is
	# left at its default false on buff_ddmr_aegis.tres) sharing the same compcon_id AND from_gear
	# before appending the new one - so an UNGATED second application also reads chip_count() == 1,
	# because the old chip was replaced, not stacked, by a fresh one from the SAME weapon. The
	# discriminator is therefore whether it is the SAME BuffCore instance across both hits (gate held)
	# or a NEW one with a different persistent_id (gate deleted, second application silently replaced
	# the first).
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'fixture: the first hit raised exactly one chip.')
	var first_chip:BuffCore = chip_buff()
	assert_not_null(first_chip, 'fixture: and it is identifiable.')
	var damage_after_first:int = hostile.current_damage()

	# THE VACUITY GUARD, AS FREEBIE: without Action.FLAG.AS_FREEBIE the per-turn soft limit silently
	# refuses a second activation of the same Kit in the same turn (unit_action.gd:114-116) and the
	# await returns normally with nothing logged - the SP1/SP2 lesson every 1/round test in this mod
	# repeats. Ends with the target having taken damage TWICE, which is what proves the shot fired.
	PrimroseFixture.cheat_a_hit()
	await SpecFactory.use_solo(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile, [Action.FLAG.AS_FREEBIE])
	assert_gt(hostile.current_damage(), damage_after_first, 'VACUITY GUARD: the second hit really landed too.')
	assert_eq(chip_count(), 1, 'fixture: still exactly one chip by the naive count (see header - this '
		+ 'alone does not discriminate a refusal from a silent replacement).')
	var second_chip:BuffCore = chip_buff()
	assert_not_null(second_chip, 'fixture: and it is still identifiable.')
	if first_chip == null or second_chip == null: return
	assert_eq(second_chip.persistent_id, first_chip.persistent_id,
		'THE CLAIM: the 1/round gate refused the second application outright - the SAME chip survives '
		+ 'untouched, it was never cleared and replaced by a new one.')

func test_the_next_round_raises_it_again() -> void:
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'fixture: the first hit raised one chip.')

	# A NEW TURN FOR THE PRIMROSE ITSELF, not a global event_round_new - see the header for why that
	# is what actually clears GearCore.uses_this_round (unit_action.gd:73-78,86-88), and why the SAME
	# call proves the chip's own until = START_OF_OWNERS_TURN too (event_turn_start.gd:77).
	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, primrose)
	assert_eq(chip_count(), 0, 'fixture: START_OF_OWNERS_TURN also cleared the unconsumed chip.')

	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'THE CLAIM: the new round\'s hit raises the chip again.')

func test_an_unconsumed_chip_is_gone_at_the_start_of_the_primroses_next_turn() -> void:
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)
	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, hostile)
	assert_eq(chip_count(), 1, 'fixture: the chip is up, and nothing has consumed it.')

	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, primrose)
	assert_eq(chip_count(), 0,
		'THE CLAIM: until = START_OF_OWNERS_TURN (6) cleared it even though nothing ever attacked the '
		+ 'Primrose to consume it (event_turn_start.gd:77, BuffCore.is_unit_owner at buff_core.gd:97-100).')


# ============================== THE CARD TEXT ==============================

## THIS MOD'S OWN compiled artifact, not the global tr() - test_acrasial_falcata.gd and
## test_biting_retort.gd carry the identical const for the identical reason: get_message returns an
## EMPTY StringName for a key the artifact does not carry, where the global tr() falls back to the raw
## key, so only this lookup can attribute a row to THIS mod rather than to a sibling Reag-* mod.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

func test_the_rows_resolve_and_the_chip_has_its_own_card() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in [
		'gear.wm_ddmr.name', 'gear.wm_ddmr.flavor', 'gear.wm_ddmr.effect',
		'gear.buff_ddmr_aegis.name', 'gear.buff_ddmr_aegis.effect',
	]:
		assert_ne(translation.get_message(key), StringName(''),
			'%s is carried by THIS mod, not by a sibling.' % key)
