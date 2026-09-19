# MAGNETIC WEIGHT REDISTRIBUTION (Primrose SP1 Task 2).
#
#   "1/round, when the Primrose critically hits with a Heavy or Superheavy melee weapon, the target
#    must succeed a Hull save or be knocked Prone."
#
# THE FITZGERALD'S KNOCK 'EM DOWN, COPIED with a different filter (design 1.2, and the plan's own
# decision note). There is no crit trigger in the engine: crit effects come through
# Buff.TO.ONHIT_EFFECT carrying an OnHitEffect whose apply_on is the ON_CRIT stage
# (event_unit_attack.gd:89-93, gathered from get_buffs_to(owner, Buff.TO.ONHIT_EFFECT, context) at
# :46). The engine enforces a per-round limit only for ActionReactions (reaction_bus.gd:116-124),
# never for a buff-triggered effect, so the 1/round is hand-rolled: the buff gates on
# GearCore.get_uses_this_round_alt and the OnHitEffect increments it.
#
# RULING 12 IS THE WHOLE POINT OF TWO OF THESE TESTS: the round is spent by FORCING the save, pass or
# fail - not by the target actually going Prone - and only a CHARACTER target spends it. So the
# increment happens in should_abort(), before super() rolls the save, and behind an is_character()
# gate. test_a_passed_save... and test_the_second_qualifying_crit... are the two that would pass
# under the alternative (spend-on-a-failed-save) reading and do not here.
#
# THE HULL SAVE IS PINNED THROUGH HaseBlock, NOT THE DICE QUEUE (PrimroseFixture.force_save_to_fail):
# the attack ahead of the save pops an unpredictable number of accuracy and damage dice out of the
# same global FIFO, so queuing a specific d20 for the save would be guessing how many the attack ate
# first.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_magnetic_weight_redistribution.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const TRAIT_ID := &'mt_magnetic_weight_redistribution'
const BUFF_ID := &'buff_magnetic_weight_redistribution'
const USAGE_KEY := &'magnetic_weight'

const PRIMROSE_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4)   ## adjacent: inside threat 1 for every melee weapon here
## Out of threat, and the ONE test that needs it says why: the heavy rifle control is ORDNANCE, which
## cannot target an engaged adjacent unit at all (action_attack_weapon.gd:232-237).
const RIFLE_TARGET_TILE := Vector2i(9, 4)

var game:Gamemaster
var primrose:Unit
var target:Unit

func before_each() -> void:
	game = PrimroseFixture.create_game(self)
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)
	# evasion -10: every test in this file needs a guaranteed hit, and the crit half is the cheated
	# d20's job. Same value and same reason as test_knock_em_down.gd's before_each.
	target = PrimroseFixture.create_dummy(game, TARGET_TILE, -10)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func trait_gear() -> GearCore:
	var gear := primrose.get_gear(TRAIT_ID)
	return gear if GearCore.is_valid(gear) else null

func uses() -> int:
	var gear := trait_gear()
	return gear.get_uses_this_round_alt(USAGE_KEY) if gear != null else -1

func proned() -> bool:
	return target.has_status(Lancer.STATUS.PRONE)

# ---------------------------------------------------------------- wiring and text

func test_the_trait_is_wired():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % TRAIT_ID)
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait, so it costs no SP and cannot be unequipped.')
	assert_eq(kit.actions.size(), 0, 'It has no actions - the whole trait is the passive buff.')
	assert_eq(kit.passives.size(), 1, 'And exactly one passive.')
	var applicator = kit.passives[0]
	assert_true(applicator is PassiveBuffApplicator, 'Which is a PassiveBuffApplicator.')
	if applicator is not PassiveBuffApplicator: return
	assert_eq(applicator.applied_buffs.size(), 1, 'Carrying exactly one buff.')
	assert_true(applicator.reapply_at_the_start_of_each_turn,
		'Re-applied every turn, as Knock \'em down\'s is: this buff carries NO state, so a fresh copy '
		+ 'each turn costs nothing and keeps it alive through anything that strips buffs.')
	assert_true(GearCore.is_valid(trait_gear()), 'The Primrose is wearing it.')

	# assert_not_null rather than Buff.is_valid: there IS no Buff.is_valid, and naming it is a PARSE
	# error - at which point GUT SKIPS the whole script rather than failing it and eleven tests quietly
	# vanish. test_gravity_well.gd:119-125 and test_sap.gd record the same correction.
	var buff:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(buff, '%s is in the buffs index.' % BUFF_ID)
	if buff == null: return
	assert_true(buff is BuffWeaponTypeOnHit, 'It is a BuffWeaponTypeOnHit subclass.')
	assert_eq(buff.to, Buff.TO.ONHIT_EFFECT, 'It supplies on-hit effects to the wearer\'s attacks.')
	assert_true(buff.hide_from_player, 'And is trait plumbing, never a chip on the unit.')
	if buff is not BuffWeaponTypeOnHit: return
	assert_eq(buff.weapon_sizes, [Lancer.WEAPON_SIZE.HEAVY, Lancer.WEAPON_SIZE.SUPERHEAVY] as Array[int],
		'Filtered to Heavy and Superheavy.')
	assert_eq(buff.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[int], 'And to melee.')
	assert_eq(buff.effects.size(), 1, 'Carrying one OnHitEffect.')
	if buff.effects.is_empty(): return
	var effect:OnHitEffect = buff.effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_CRIT, 'Which fires at the CRIT stage.')
	assert_eq(effect.statuses, [&'prone'] as Array[StringName], 'Applying Prone.')
	assert_true(effect.save_to_avoid, 'Avoidable by a save.')
	assert_eq(effect.save_type, Lancer.HASE.HULL, 'A Hull save.')

func test_the_rows_resolve():
	for key:String in ['gear.mt_magnetic_weight_redistribution.name',
			'gear.mt_magnetic_weight_redistribution.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

# ---------------------------------------------------------------- what fires it

func test_a_superheavy_melee_crit_forces_a_hull_save_and_prones_on_a_failure():
	PrimroseFixture.equip_superheavy_melee(primrose)
	PrimroseFixture.force_save_to_fail(target)

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the drill landed.')
	assert_true(proned(), 'A Superheavy melee crit forced a Hull save, and the target failed it.')
	# Proves the round was actually spent, not just that Prone happened to apply - the only way this
	# reads 1 is if should_abort ran and incremented the trait's own gear.
	assert_eq(uses(), 1, 'And the trait spent its 1/round usage.')

func test_a_heavy_melee_crit_does_the_same():
	PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.force_save_to_fail(target)

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the blade landed.')
	assert_true(proned(), 'A Heavy melee crit is the card\'s other half.')
	assert_eq(uses(), 1, 'And spends the same 1/round.')

func test_a_passed_save_leaves_the_target_standing_and_still_spends_the_round():
	# RULING 12, half one. Without the usage assertion this test would pass identically against a trait
	# that never fired at all: a passed save and "never triggered" both leave the target standing.
	PrimroseFixture.equip_superheavy_melee(primrose)
	PrimroseFixture.force_save_to_pass(target)

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot still landed, so a save spared it.')
	assert_false(proned(), 'A passed Hull save leaves the target standing.')
	assert_eq(uses(), 1, 'And the round is spent anyway - the trigger is the crit, not the knockdown.')

# ---------------------------------------------------------------- what does not

func test_a_main_melee_crit_does_nothing():
	PrimroseFixture.equip(primrose, PrimroseFixture.MAIN_MELEE)
	PrimroseFixture.force_save_to_fail(target) # would guarantee Prone IF a save were forced

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.MAIN_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot landed and crit.')
	assert_false(proned(), 'MAIN is not Heavy or Superheavy: the weapon_sizes filter holds.')
	assert_eq(uses(), 0, 'And the buff was never even asked for, so no round was spent.')

func test_a_heavy_rifle_crit_does_nothing():
	# The control that proves the filter is on TYPE as well as size. Without it, dropping
	# weapon_types = [MELEE] from the .tres would redden nothing.
	#
	# THE TARGET IS WALKED OUT OF THREAT FIRST, AND THAT IS NOT OPTIONAL. mw_anti_materiel_rifle
	# carries the ORDNANCE tag (content/gear/gms/weapons/mw_anti_materiel_rifle.tres), and
	# ActionAttackWeapon.can_target_unit refuses an adjacent target outright when both units are
	# ENGAGED and the target is one of the attacker's engaging units
	# (action_attack_weapon.gd:232-237, "ordnance can't hit adjacent guys"). At TARGET_TILE - the one
	# tile every melee test in this file needs - the activation ABORTS at event_gear_activate with no
	# damage and, because can_activate_gear() is perfectly happy, WITHOUT the red
	# "[ Gear not available ] reason : ..." line that usually names a refusal. It reads as a dead
	# trait rather than an unusable weapon. Measured 2026-09-19: can_target_unit is false at (5,4)
	# and true at (9,4) for exactly this specific.
	#
	# Moving the existing target rather than making a second one keeps proned() and uses() reading the
	# unit they were written for.
	PrimroseFixture.equip(primrose, PrimroseFixture.HEAVY_RIFLE)
	UnitTile.move_to(target, RIFLE_TARGET_TILE)
	PrimroseFixture.force_save_to_fail(target)

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_RIFLE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the rifle landed and crit.')
	assert_false(proned(), 'A HEAVY rifle is the right size and the wrong type.')
	assert_eq(uses(), 0, 'And spent nothing.')

func test_a_heavy_melee_hit_that_is_not_a_crit_does_nothing():
	PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.force_save_to_fail(target)

	PrimroseFixture.cheat_a_hit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.HEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot landed.')
	assert_false(proned(), 'A hit that is not a crit does not reach the ON_CRIT stage.')
	assert_eq(uses(), 0, 'And spends nothing - without this a wholly dead trait would pass too.')

func test_a_thrown_heavy_melee_crit_does_nothing():
	# RULING 8. A throw is the same action with threat set to 0 (action_attack_weapon.gd:349-372), and
	# the card says "melee weapon", not "thrown melee weapon". Fired through use_specific with the
	# fixture's thrown variant, which is exactly what VariantActionGroup.get_variant_specifics builds
	# when a player picks Thrown off the sub-menu.
	#
	# WITHOUT THE threat > 0 GATE THIS IS THE ONLY TEST THAT REDDENS - the size and type filters both
	# pass a thrown variant, because a throw changes neither.
	var gear:GearCore = PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.force_save_to_fail(target)
	var thrown := PrimroseFixture.thrown_variant(PrimroseFixture.specific(primrose, PrimroseFixture.HEAVY_MELEE))
	assert_eq(thrown.action.threat, 0, 'Fixture: the thrown variant really has threat 0.')

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.open_turn(game, primrose)
	await SpecFactory.use_specific(game, thrown, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the throw landed and crit.')
	assert_false(proned(), 'A thrown Heavy melee weapon is not a melee attack (ruling 8).')
	assert_eq(uses(), 0, 'And spent nothing.')

func test_a_crit_on_a_non_character_does_nothing():
	# RULING 12, half two, and the Fitzgerald's own review finding 1 carried over.
	# event_unit_attack.gd's apply_on_crits is reached for ANY valid target unit - it only checks
	# is_character() two lines later, for the crit bark (:93) - so without the explicit gate a crit on
	# a destructible object would spend the 1/round and force a Hull save that can do nothing.
	#
	# THE PRONE ASSERTION BELOW IS A SANITY CHECK, NOT THE CLAIM: a non-character cannot end up Prone
	# whether or not the gate exists (unit_hasecheck auto-fails a non-character's save without rolling
	# and unit_condition.gd:502 makes it immune to Prone outright), so it would read green against a
	# version with the gate torn out. The usage counter is what discriminates.
	target.core.frame.entity_type = Frame.ENTITY.OBJECT
	target.core.full_repair()
	assert_false(target.is_character(), 'fixture: the target is no longer a character.')
	PrimroseFixture.equip_superheavy_melee(primrose)
	PrimroseFixture.force_save_to_fail(target)

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the shot still landed and crit.')
	assert_false(proned(), 'Sanity check: guaranteed by the engine either way.')
	assert_eq(uses(), 0,
		'THE CLAIM: the is_character() gate refused before it ever incremented (ruling 12).')

# ---------------------------------------------------------------- the round

func test_the_second_qualifying_crit_in_a_round_does_nothing_and_the_next_round_works_again():
	# RULING 12 again, and the first crit's save PASSES on purpose: if the round were spent only by a
	# FAILED save, this pass would leave the 1/round untouched and the second crit below would still be
	# free to force (and fail) its own.
	#
	# BOTH SHOTS ARE IN ONE TURN, deliberately. "1/round" is cleared by
	# UnitAction.new_turn_refresh -> reset_per_round_usage at the PRIMROSE'S OWN turn start
	# (unit_action.gd:73-78, :87-88), so a start_turn between the two would make the refusal vacuous.
	#
	# THE SECOND SHOT IS A FREEBIE, AND THAT IS WHAT MAKES THIS TEST MEAN ANYTHING. A plain second
	# activation of the same weapon in the same turn CANNOT HAPPEN: Action.get_per_turn_soft_limit
	# returns 1 for anything that is not free (action.gd:161-163), so UnitAction.can_activate_gear
	# refuses it (unit_action.gd:116) and event_gear_activate logs
	# "[ ABORT event_gear_activate ] (invalid context! | missing props: none | specific: invalid)"
	# with no "[ Gear not available ]" line to explain it - can_activate_gear failed on the soft
	# limit, not on a REASON. The Combat Drill is a FULL action besides, so the Primrose has 0 actions
	# left and overcharge cannot cover it either (would_consume_overcharge_to_use_gear's
	# `total_cost > current_total` bail, unit_action.gd:210). Measured 2026-09-19: written the obvious
	# way this test passes while the second shot never fires at all, and it stays green with the
	# 1/round gate torn out of buff_magnetic_weight_redistribution.gd - i.e. it tests nothing.
	# Action.FLAG.AS_FREEBIE short-circuits can_activate_gear (unit_action.gd:114) without touching
	# the buff or the OnHitEffect, which read no flags, and it is how the Primrose really would get a
	# second qualifying crit inside one round in play: a reaction. The damage assertion below is the
	# guard that keeps it honest.
	PrimroseFixture.equip_superheavy_melee(primrose)
	PrimroseFixture.force_save_to_pass(target)
	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target)

	assert_gt(target.current_damage(), 0, 'Fixture: the first shot crit and landed.')
	assert_false(proned(), 'Fixture: the first Hull save passed.')
	assert_eq(uses(), 1, 'Fixture: and the first crit spent the 1/round despite the passed save.')

	# Second crit, same round, with the save now pinned to auto-FAIL: if the round limit were not
	# gating the buff, this shot would force a save and the target would go Prone.
	#
	# force_save_to_fail RE-REPAIRS THE TARGET (primrose_fixture.gd:251-253 - the hase only reaches
	# core.current through full_repair), so current_damage() is back at 0 here and the assertion below
	# measures the SECOND shot alone rather than a running total.
	PrimroseFixture.force_save_to_fail(target)
	assert_eq(target.current_damage(), 0, 'Fixture: re-pinning the save repaired the target.')
	PrimroseFixture.cheat_a_crit()
	await SpecFactory.use_solo(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target,
		[Action.FLAG.AS_FREEBIE])

	assert_gt(target.current_damage(), 0,
		'THE VACUITY GUARD: the second shot really landed. Without this the test reads green when the'
		+ ' activation was refused and no second crit ever happened.')
	assert_false(proned(), 'The second crit in the same round does nothing: the round is spent.')
	assert_eq(uses(), 1, 'And spent nothing further.')

	# A new round (a new turn, in this single-unit spec) resets the usage, and the save is still pinned
	# to auto-fail - so the trait re-firing is what makes this Prone.
	await SpecFactory.end_turn(game, primrose)
	await SpecFactory.start_turn(game, primrose)
	assert_eq(uses(), 0, 'Fixture: the new round reset the counter.')

	PrimroseFixture.cheat_a_crit()
	await PrimroseFixture.attack(game, primrose, PrimroseFixture.SUPERHEAVY_MELEE, target)

	assert_true(proned(), 'Magnetic Weight Redistribution works again on the new round.')

func test_the_trait_does_not_share_a_round_with_knock_em_down():
	# THE USAGE KEY IS ITS OWN, and this is the one test that says so. Both traits hand-roll their
	# 1/round through GearCore.get_uses_this_round_alt, which is keyed on a STRING - so a copy that
	# kept &'knock_em_down' would work perfectly on this frame and silently halve both traits on any
	# future frame that carried both. Read off the constants rather than through behaviour, because no
	# frame in this mod carries both and the behavioural case cannot be built.
	var ours:Script = load('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_primrose/mt_magnetic_weight_redistribution/onhit_magnetic_weight_redistribution.gd')
	var theirs:Script = load('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_fitzgerald/mt_knock_em_down/onhit_knock_em_down.gd')
	assert_not_null(ours, 'fixture: our on-hit script loads.')
	assert_not_null(theirs, 'fixture: the Fitzgerald\'s loads.')
	if ours == null or theirs == null: return
	var our_key = ours.get_script_constant_map().get('USAGE_KEY', &'')
	var their_key = theirs.get_script_constant_map().get('USAGE_KEY', &'')
	assert_eq(our_key, USAGE_KEY, 'Ours is %s.' % USAGE_KEY)
	assert_ne(our_key, their_key, 'And it is NOT the Fitzgerald\'s key.')
	assert_eq(ours.get_script_constant_map().get('TRAIT_ID', &''), TRAIT_ID,
		'And it looks its own gear up by its own trait id.')
