## THE REND AXE (Primrose rank I, SP2 Task 1 and Task 2).
##
## "Main Melee, Limited 3, AP, Unique, Thrown 3. 2 kinetic, threat 1. You may attack with this weapon
## without expending or requiring charges, and this weapon can be destroyed even if it has no charges
## remaining. 1/round, you may expend a charge to attack with this weapon as a free action during your
## turn. On crit: until the start of their next turn, the target is Shredded."
##
## THE CARD IS TWO ACTIONS, AND THE SPLIT IS THE WHOLE DESIGN (ruling 3). One Action cannot answer
## consumes_charges both ways, and consumes_charges is read for two different purposes from one
## return value: unit_action.gd:153 refuses the activation when it is true and the gear is empty, and
## unit_action.gd:275 is the only caller of gear.spend_charge(). The ordinary attack answers false to
## both halves - which is exactly "without expending or requiring charges" - and the free attack, Task
## 2's, answers true.
##
## LIMITED 3 IS kit.charges_max, NOT A WEAPON TAG. There is no LIMITED entry in Lancer.WEAPON_TAG;
## the engine expresses it as charges (kit.gd:35), the way this mod's own ms_hull_break_thrusters.tres
## writes the identical "Limited 3" line. A tags entry would be silently ignored.
##
## "CAN BE DESTROYED EVEN IF IT HAS NO CHARGES" NEEDS NOTHING (ruling 14). Nothing in the engine reads
## an empty charge pool as destruction: gear.is_intact() is a separate flag
## (unit_action.gd:151 vs :153), and has_charges_left() only ever gates an activation. There is
## therefore no code and no test for that clause - it is a clarification aimed at a tabletop reader,
## and this comment is the record that it was read and found to be a no-op.
##
## Run:
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rend_axe.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const KIT_ID := &'mw_rend_axe'
const ATTACK_ID := &'action_rend_axe'
const ONHIT_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/weapons/mw_rend_axe/onhit_rend_axe.tres'

## The card's numbers, transcribed once so a typo in the .tres reads as a number and not as a vague
## "feels wrong".
const CHARGES := 3
const SP_COST := 0
const THREAT := 1
const THROWN := 3
const DAMAGE_DICE := '2'

## A flat "2", not a die: cheat dice cannot change it, so the exact damage a hit deals through armor 0
## is 2. Asserting the exact number is what would catch a "2d6" typo that "more than zero" would pass.
const AXE_DAMAGE := 2

const PRIMROSE_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4)   # threat 1: adjacent, so the melee attack is legal

var game:Gamemaster
var unit:Unit
var target:Unit
var gear:GearCore

func before_each() -> void:
	game = Fixture.create_game(self)
	unit = Fixture.create_primrose(game, PRIMROSE_TILE)
	target = Fixture.create_hostile(game, TARGET_TILE, 5)  # evasion 5: a cheated 19 always lands
	gear = Fixture.equip(unit, KIT_ID)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The ordinary attack, opening the turn first. Fired through use_solo, which reaches
## kit.actions[0] - the ordinary profile - by way of gear.get_solo_action().
func swing() -> void:
	await Fixture.attack(game, unit, KIT_ID, target)

## The same swing as a THROW. use_solo's desired_variant is the engine's own variant selector and
## &'thrown' is the id action_attack_weapon.gd:355 gives the group; vanilla's
## test/talent/test_t_skirmisher.gd:42 is the precedent for driving a variant from a spec.
func throw_it() -> void:
	await Fixture.open_turn(game, unit)
	await SpecFactory.use_solo(game, unit, KIT_ID, target, [], 'thrown')

func weapon() -> ActionAttackWeapon:
	return gear.get_action(ATTACK_ID) as ActionAttackWeapon

# ---------------------------------------------------------------- the weapon as data

func test_the_kit_is_registered() -> void:
	# Read off ContentLibrary, not off disk: this proves the resource was INDEXED. A weapon whose
	# filename prefix or resource group is wrong is silently filed somewhere else and vanishes from
	# get_kit with no error at all.
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'mw_rend_axe is in ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, SP_COST, 'SP cost is 0.')
	assert_eq(kit.charges_max, CHARGES, 'Limited 3 is charges_max 3.')
	assert_eq(kit.system_tags & Kit.SYSTEM_TAGS.UNIQUE, int(Kit.SYSTEM_TAGS.UNIQUE),
		'Unique is the UNIQUE system_tags bit.')

func test_the_profile_matches_the_card() -> void:
	var attack := weapon()
	assert_not_null(attack, 'the Kit carries action_rend_axe.')
	if attack == null: return
	assert_eq(attack.damage_dice, DAMAGE_DICE, '2 damage.')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'kinetic.')
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(attack.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(attack.threat, THREAT, 'threat 1.')
	assert_eq(attack.thrown, THROWN, 'Thrown 3.')
	# aim_range is 0 on every melee weapon in the tree; a nonzero value would make the axe shootable
	# at range through ranged_distance and is the single most likely copy-paste error here.
	assert_eq(attack.aim_range, 0, 'no aim range - it is a melee weapon.')

func test_the_axe_is_ap_and_thrown_and_nothing_else() -> void:
	var attack := weapon()
	if attack == null: return assert_true(false, 'no action to inspect.')
	var specific := Fixture.specific(unit, KIT_ID)
	assert_true(attack.has_tag(Lancer.WEAPON_TAG.AP, specific), 'AP.')
	assert_true(attack.has_tag(Lancer.WEAPON_TAG.THROWN, specific), 'Thrown.')
	# The exact list, not just "has AP": a stray RELIABLE or SEEKING would change the weapon's whole
	# behaviour and every has_tag assertion above would stay green.
	assert_eq(attack.tags, [&'ap', &'thrown'] as Array[StringName], 'exactly AP and Thrown.')

func test_the_ordinary_attack_is_a_quick_action() -> void:
	var attack := weapon()
	if attack == null: return assert_true(false, 'no action to inspect.')
	# Derived from weapon_size, not declared: action_attack_weapon.gd:87-91 returns FULL only for
	# SUPERHEAVY. So this assertion is really "weapon_size is not SUPERHEAVY", which is worth pinning
	# because nothing else in this file would notice a 3 in that field.
	assert_eq(attack.get_action_type(Fixture.specific(unit, KIT_ID)), Lancer.ACTION.QUICK,
		'a Main weapon is a Quick action.')

# ---------------------------------------------------------------- charges

func test_the_axe_starts_with_three_charges() -> void:
	assert_eq(gear.charges_current, CHARGES, 'three charges when equipped.')

func test_the_ordinary_attack_spends_no_charge() -> void:
	Fixture.cheat_a_hit()
	await swing()
	assert_eq(gear.charges_current, CHARGES, 'still three charges after a swing.')
	# The vacuity guard: a swing that never happened would also leave the charges alone.
	assert_gt(target.current_damage(), 0, 'VACUITY: the swing actually landed.')

func test_the_ordinary_attack_still_works_with_no_charges_left() -> void:
	gear.charges_current = 0
	# The engine's own gate, read directly, so the reason is named rather than inferred from a
	# silent no-op: unit_action.gd:153 would answer NO_CHARGES if consumes_charges were true here.
	assert_eq(UnitAction.get_gear_unavailable_reason(Fixture.specific(unit, KIT_ID)),
		UnitAction.REASON.NONE, 'an empty axe is still available.')
	Fixture.cheat_a_hit()
	await swing()
	assert_eq(target.current_damage(), AXE_DAMAGE, 'and it deals its full damage.')
	assert_eq(gear.charges_current, 0, 'and it did not go negative.')

# ---------------------------------------------------------------- damage

func test_a_hit_deals_two_kinetic_through_armor() -> void:
	# AP: the target is built with armor 0 by the fixture, so this number alone does not prove AP.
	# test_the_ap_tag_bypasses_armor below is what does.
	Fixture.cheat_a_hit()
	await swing()
	assert_eq(target.current_damage(), AXE_DAMAGE, 'a hit deals exactly 2.')

func test_the_ap_tag_bypasses_armor() -> void:
	# Two armor would take a non-AP 2 down to 0. The damage arriving intact IS the AP tag working,
	# and it is the only assertion in this file that can tell an AP axe from a plain one.
	target.core.frame.stat.armor = 2
	target.core.full_repair()
	Fixture.cheat_a_hit()
	await swing()
	assert_eq(target.current_damage(), AXE_DAMAGE, 'armor 2 takes nothing off an AP hit.')

# ---------------------------------------------------------------- the crit

func test_a_crit_shreds_the_target() -> void:
	Fixture.cheat_a_crit()
	await swing()
	assert_true(target.has_status(Lancer.STATUS.SHREDDED), 'a crit applies Shredded.')

func test_a_plain_hit_does_not_shred() -> void:
	Fixture.cheat_a_hit()
	await swing()
	assert_gt(target.current_damage(), 0, 'VACUITY: the hit landed.')
	assert_false(target.has_status(Lancer.STATUS.SHREDDED), 'a hit that is not a crit shreds nobody.')

func test_a_miss_does_not_shred() -> void:
	Fixture.cheat_a_miss()
	await swing()
	assert_eq(target.current_damage(), 0, 'VACUITY: the swing missed.')
	assert_false(target.has_status(Lancer.STATUS.SHREDDED), 'a miss shreds nobody.')

func test_the_shred_is_declared_to_last_until_the_start_of_the_targets_turn() -> void:
	# The vanilla default for Shredded is END_OF_NEXT_TURN (content/statuses/status_shredded.tres:11,
	# standard_until = 1). The card says "until the start of their next turn", which is a DIFFERENT
	# and shorter window, so this override is the whole of the clause. Asserted on the resource as
	# well as behaviourally below, the way test_swivel_gun.gd:518 pins its sibling override: the
	# behavioural test alone would stay green if the override were deleted and the engine default
	# happened to look similar at the one moment the test samples.
	var onhit:OnHitEffect = load(ONHIT_PATH)
	assert_not_null(onhit, 'onhit_rend_axe.tres loads.')
	if onhit == null: return
	assert_eq(onhit.apply_on, OnHitEffect.STAGE.ON_CRIT, 'it fires ON_CRIT, not ON_HIT.')
	assert_eq(onhit.statuses, [&'shredded'] as Array[StringName], 'it applies Shredded and nothing else.')
	assert_eq(onhit.get_applied_duration_for_statuses(&'shredded', null, null),
		Lancer.UNTIL.START_OF_TURN, 'until the START of their next turn.')

func test_the_shred_survives_the_end_of_the_attackers_turn_and_clears_at_the_targets_turn_start() -> void:
	Fixture.cheat_a_crit()
	await swing()
	assert_true(target.has_status(Lancer.STATUS.SHREDDED), 'VACUITY: the crit shredded.')
	await game.execute_event(&'event_turn_end', {unit = unit})
	assert_true(target.has_status(Lancer.STATUS.SHREDDED),
		'it is still there at the end of the Primrose turn - this is what rules out END_OF_THIS_TURN.')
	await game.execute_event(&'event_turn_start', {unit = target})
	assert_false(target.has_status(Lancer.STATUS.SHREDDED),
		'and gone at the start of the target turn - this is what rules out END_OF_NEXT_TURN.')

# ---------------------------------------------------------------- Thrown

func test_the_thrown_submenu_exists_on_the_ordinary_attack() -> void:
	# Built by the engine from the tag, not by us (action_attack_weapon.gd:349-372). The assertion is
	# that the tag is doing it: a Thrown value written into the .tres with the tag left off would
	# leave this list empty while test_the_profile_matches_the_card stayed green.
	var attack := weapon()
	if attack == null: return assert_true(false, 'no action to inspect.')
	var groups:Array[VariantActionGroup] = attack.get_alternate_actions(Fixture.specific(unit, KIT_ID))
	# The field is `key`, not `id` (variant_action_group.gd:13) - an `id` would be a silent null.
	var keys:Array[StringName] = []
	for group:VariantActionGroup in groups: keys.append(group.key)
	assert_has(keys, &'thrown', 'the axe offers a Thrown sub-menu.')

func test_a_thrown_crit_still_shreds__ruling_22() -> void:
	# AUTHOR RULING 22, 2026-09-19. The card's on-crit line carries no melee qualifier, so it fires on
	# any crit with this weapon, thrown included - unlike Shimmering Shield, Biting Retort and
	# Magnetic Weight Redistribution, whose cards do say "melee attack" and which ruling 8 gates on
	# threat > 0. This is the engine default (OnHitEffect.should_abort never consults threat), so
	# there is no code behind this test; it exists so that a later should_abort override added for
	# some other reason cannot quietly take the clause away.
	Fixture.cheat_a_crit()
	await throw_it()
	# VACUITY GUARD, ADDED BY THE CONTROLLER AFTER TASK 1's M4 (2026-09-19). Without it this test
	# does not test a THROW at all: use_solo's desired_variant asks for the group by name, and a
	# weapon with no Thrown tag simply has no such group (action_attack_weapon.gd:349-372), so the
	# call silently falls back to the ordinary threat-1 swing - which shreds for the ordinary
	# reason and leaves the assertion below green. M4 measured exactly that. A real throw sets
	# is_thrown_retrieved false (action_attack_weapon.gd:293-295), and nothing else in this spec
	# does, so this is the one fact that can only be true if the variant really applied.
	assert_false(gear.is_thrown_retrieved, 'VACUITY: the axe was really THROWN, not swung.')
	assert_true(target.has_status(Lancer.STATUS.SHREDDED), 'a thrown crit shreds too.')

# ---------------------------------------------------------------- the licence and the card text

func test_the_licence_grants_the_axe_at_rank_one() -> void:
	# CORRECTED AT IMPLEMENTATION: the plan's draft called ContentLibrary.get_license, which does not
	# exist (content_library.gd has no such method). The real accessor is get_license_tree
	# (content_library.gd:254) - test_swivel_gun.gd's own _license() helper already uses it.
	var license:UnlockTree = ContentLibrary.get_license_tree(Fixture.LICENSE_ID)
	assert_not_null(license, 'li_primrose is registered.')
	if license == null or license.rank_1 == null: return
	var ids:Array[StringName] = []
	for kit:Kit in license.rank_1.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, KIT_ID, 'rank 1 grants the Rend Axe.')

func test_the_name_and_flavour_and_effect_resolve() -> void:
	# Read THIS MOD'S OWN compiled artifact rather than the global tr(), so a passing display-text
	# test can be attributed to this mod and not to a sibling Reag-* mod loaded in the same run.
	# Same pattern as test_content_integrity.gd and test_primrose_frame.gd.
	var ours := TranslationServer.get_translation_object('en')
	for key:String in ['gear.mw_rend_axe.name', 'gear.mw_rend_axe.flavor',
			'gear.mw_rend_axe.action_rend_axe.effect']:
		assert_ne(tr(key), key, '%s resolves to real text.' % key)

# ================================================================ the FREE attack (SP2 Task 2)
#
# "1/round, you may expend a charge to attack with this weapon as a free action during your turn."
#
# A SECOND ACTION, NOT A VARIANT (ruling 3). A VARIANT_ACTIONS sub-menu would have to change the
# action's COST after the player picked, which no vanilla variant does - every one of them changes
# the weapon profile and leaves the cost alone (action_attack_weapon.gd:349-372 is the shape). Two
# actions also put two buttons on the gear bar, each saying what it costs, which is the point.

const FREE_ID := &'action_rend_axe_free'

func free_weapon() -> ActionAttackWeapon:
	return gear.get_action(FREE_ID) as ActionAttackWeapon

func free_specific() -> SpecificAction:
	return SpecificAction.from_id(unit, KIT_ID, FREE_ID)

## The free swing. SpecFactory.use names the action, unlike use_solo which always takes
## kit.actions[0] (gear_core.gd:337-339).
func free_swing() -> void:
	await Fixture.open_turn(game, unit)
	await SpecFactory.use(game, unit, KIT_ID, FREE_ID, target)

func test_the_free_attack_is_a_free_action() -> void:
	var free := free_weapon()
	assert_not_null(free, 'the Kit carries action_rend_axe_free.')
	if free == null: return
	assert_eq(free.get_action_type(free_specific()), Lancer.ACTION.FREE, 'it is a FREE action.')
	assert_eq(free.get_action_cost(free_specific()), Lancer.ACTION_COST_FREE, 'and it costs nothing.')

func test_the_free_attack_spends_a_charge() -> void:
	Fixture.cheat_a_hit()
	await free_swing()
	assert_gt(target.current_damage(), 0, 'VACUITY: the free swing actually landed.')
	assert_eq(gear.charges_current, CHARGES - 1, 'one charge gone.')

func test_the_free_attack_costs_no_action_points() -> void:
	await Fixture.open_turn(game, unit)
	var before:int = unit.state.actions
	Fixture.cheat_a_hit()
	await SpecFactory.use(game, unit, KIT_ID, FREE_ID, target)
	assert_gt(target.current_damage(), 0, 'VACUITY: the free swing landed.')
	assert_eq(unit.state.actions, before, 'and cost no action points.')

func test_the_free_attack_is_refused_with_no_charges() -> void:
	gear.charges_current = 0
	assert_eq(UnitAction.get_gear_unavailable_reason(free_specific()), UnitAction.REASON.NO_CHARGES,
		'the free attack needs a charge, and the engine names that reason.')

func test_the_free_attack_is_hidden_rather_than_greyed_when_it_cannot_be_used() -> void:
	# hide_if_disabled: the gear bar drops the button instead of drawing a dead one. Read off the
	# resource - the gear bar's own filtering is per-instance runtime state this spec cannot reach.
	var free := free_weapon()
	if free == null: return assert_true(false, 'no free action to inspect.')
	assert_true(free.hide_if_disabled, 'an empty axe hides the free button.')

func test_a_second_free_attack_in_the_same_round_is_refused() -> void:
	Fixture.cheat_a_hit()
	await free_swing()
	assert_eq(gear.charges_current, CHARGES - 1, 'VACUITY: the first free swing happened.')
	assert_eq(UnitAction.get_gear_unavailable_reason(free_specific()), UnitAction.REASON.PER_ROUND,
		'the second is refused for PER_ROUND, not for charges.')

func test_the_engine_itself_caps_a_naturally_free_action_at_one_per_round() -> void:
	# NOT a get_per_round_hard_limit override of ours, and this test is the reason there is none.
	# action.gd:156-158 already returns 1 when get_action_cost <= Lancer.ACTION_COST_FREE, and
	# Lancer.ACTION_COST[ACTION.FREE] is 0 (lancer.gd:31). Writing the override anyway would be an
	# inert line that reads as load-bearing; asserting the engine's own answer instead means a future
	# engine change to that default goes RED here rather than silently uncapping the axe.
	var free := free_weapon()
	if free == null: return assert_true(false, 'no free action to inspect.')
	assert_eq(free.get_per_round_hard_limit(free_specific()), 1, 'the engine caps it at 1/round.')

func test_the_free_attack_does_not_use_up_the_ordinary_attack() -> void:
	# THE TEST THIS TASK EXISTS FOR. Two actions on one Kit share a usage group unless one declares
	# its own (gear_core.gd:166-168 falls back to kit.compcon_id), and unit_action.gd:281 increments
	# uses_this_turn for a player-pressed action. The ordinary attack's per-turn soft limit is 1
	# (action.gd:161-163), so a shared group would make the free swing silently forbid the ordinary
	# one for the rest of the turn - a refusal of the OTHER button, which is why nothing about the
	# free attack's own behaviour would notice.
	Fixture.cheat_a_hit()
	await free_swing()
	assert_eq(gear.charges_current, CHARGES - 1, 'VACUITY: the free swing happened.')
	assert_true(UnitAction.can_activate_gear(Fixture.specific(unit, KIT_ID)),
		'the ordinary attack is still available in the same turn.')
	var before:int = target.current_damage()
	Fixture.cheat_a_hit()
	await SpecFactory.use(game, unit, KIT_ID, ATTACK_ID, target)
	assert_eq(target.current_damage(), before + AXE_DAMAGE, 'and it really swings.')

func test_the_ordinary_attack_does_not_use_up_the_free_one() -> void:
	# The other direction, and it holds for a DIFFERENT engine reason than its sibling above, which is
	# why the pair is not one assertion written twice: the free action has no per-turn soft limit at
	# all (action.gd:161-163 returns 99 for a naturally free action), so the counter that would stop
	# it is the per-ROUND one instead - get_per_round_hard_limit is 1, and is_under_per_round_limit
	# (unit_action.gd:170-175) is checked inside get_gear_unavailable_reason at :148.
	#
	# CORRECTED AT IMPLEMENTATION (SP2 Task 2, 2026-09-19). The plan's draft said this test "would
	# survive the usage_group being deleted". MEASURED: it does not. Mutation M1 - dropping
	# usage_group from action_rend_axe_free.tres - reddened this test as well as its sibling, because
	# a shared group means the ORDINARY swing above bumps uses_this_round for the group the free
	# action reads, and 1 is already its whole round allowance. So the ordinary attack refuses the
	# free one for PER_ROUND while the free one refuses the ordinary for the per-TURN soft limit: two
	# different counters, two different gates, both broken by the same missing line. The conclusion
	# the draft drew from that claim still stands - these are not duplicate assertions - but its
	# evidence was wrong, and the corrected version is stronger: BOTH directions fail without the
	# usage_group, so either test alone would catch it.
	Fixture.cheat_a_hit()
	await swing()
	assert_gt(target.current_damage(), 0, 'VACUITY: the ordinary swing happened.')
	assert_true(UnitAction.can_activate_gear(free_specific()),
		'the free attack is still available in the same turn.')

func test_the_two_profiles_are_the_same_weapon() -> void:
	# The profile is written twice, in two .tres files, and nothing in the engine keeps them in step.
	# A card that said "attack with this weapon" and then dealt different damage depending on which
	# button was pressed would be a content bug no other test in this file could see.
	var ordinary := weapon()
	var free := free_weapon()
	if ordinary == null or free == null: return assert_true(false, 'both profiles must exist.')
	assert_eq(free.damage_dice, ordinary.damage_dice, 'same damage.')
	assert_eq(free.damage_type, ordinary.damage_type, 'same damage type.')
	assert_eq(free.weapon_size, ordinary.weapon_size, 'same size.')
	assert_eq(free.weapon_type, ordinary.weapon_type, 'same type.')
	assert_eq(free.threat, ordinary.threat, 'same threat.')
	assert_eq(free.thrown, ordinary.thrown, 'same thrown range.')
	assert_eq(free.tags, ordinary.tags, 'same tags.')
	assert_eq(free.aim_range, ordinary.aim_range, 'same aim range.')
	# The SAME OnHitEffect resource, not a second copy of it: one Shredded clause, one file.
	assert_eq(free.on_hit_effects, ordinary.on_hit_effects, 'the same on-hit effect object.')

func test_the_free_attack_also_offers_the_thrown_submenu() -> void:
	var free := free_weapon()
	if free == null: return assert_true(false, 'no free action to inspect.')
	var keys:Array[StringName] = []
	for group:VariantActionGroup in free.get_alternate_actions(free_specific()): keys.append(group.key)
	assert_has(keys, &'thrown', 'a free throw is still a throw (ruling 14).')

func test_the_free_attacks_card_text_resolves() -> void:
	var key := 'gear.mw_rend_axe.action_rend_axe_free.effect'
	assert_ne(tr(key), key, '%s resolves to real text.' % key)
