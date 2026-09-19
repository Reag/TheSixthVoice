## THE ACRASIAL FALCATA (Primrose rank II, SP3 Task 1). The weapon profile only - the reaction it
## grants ("Gain the Biting Retort reaction") is Task 2/3's job and lives in test_biting_retort.gd,
## per this plan's stated deviation from design (splitting the sibling of test_rend_axe.gd's
## single-file shape because the weapon and the reaction fail for different reasons).
##
## "Superheavy Melee | SP 1 | Tags: none | Damage: 2d6+4 Kinetic | Range: Threat 3
## Effect: Gain the Biting Retort reaction."
## (specs/sixth-voice/07-primrose.md, Rank II, "Weapon: Acrasial Falcata")
##
## SCRIPTLESS, unlike the Rend Axe. The card carries no charges, no thrown range, no on-hit clause
## and no tags of its own - the whole profile is exports on the base ActionAttackWeapon, so
## action_acrasial_falcata.tres names no id="1_..." .gd, only the engine script
## (action_attack_weapon.gd, uid://vi3dfs5ql3lg). Task 2 appends action_biting_retort.gd as a SECOND
## action beside this one on the same Kit; nothing here changes when that happens.
##
## SUPERHEAVY -> FULL ACTION IS DERIVED, NOT DECLARED. action_attack_weapon.gd:87-91 returns FULL
## only for weapon_size == SUPERHEAVY and QUICK for everything else; there is no action-cost export
## to get wrong. test_a_superheavy_swing_is_a_full_action pins the derivation, matching the shape of
## test_rend_axe.gd's own test_the_ordinary_attack_is_a_quick_action for its Main weapon.
##
## THREAT 3 AND ARTFUL CARESS. threat_distance() (action_attack_weapon.gd:187-190) is the printed
## `threat` plus every Buff.TO.ACTION_RANGE buff whose bonus_subtype is threat_range. The frame's own
## Artful Caress trait (mf_primrose/mt_artful_caress/buff_artful_caress.tres) is exactly such a buff:
## weapon_sizes = [2, 3] (HEAVY, SUPERHEAVY), weapon_types = [2] (MELEE), bonus_value = 1 - so a
## Falcata on a Primrose (created through PrimroseFixture.create_primrose, which calls
## SpecFactory.apply_passive_buffs) sits at threat 4 by default, not 3. Both numbers are asserted:
## the printed 3 alone (weapon() . threat) is never checked in isolation, because the trait applying
## automatically is exactly what a Primrose spec always sees - test_the_profile_is_a_superheavy_melee
## _at_threat_three reads threat_distance() on the PRIMROSE and gets 4 on a fresh checkout, which is
## why it exists as the SEPARATE test_artful_caress_widens_it_to_four with its own bare-unit control.
##
## SURPRISE, WORTH RECORDING: the Primrose's tabletop mounts are "Main, Main, Heavy" (07-primrose.md
## stats table) - no Superheavy mount at all - yet nothing here refuses to equip a Superheavy weapon.
## UnitPrinter.equip_system (unit_printer.gd:178-185) -> LoadoutCore.equip_system
## (loadout_core.gd:337-339) just appends the Kit to `equipped_kits`; MountCore / mount-size matching
## is a separate loadout-building/UI concern this call never touches. So there is no "Superheavy
## mount arithmetic" to pin at the engine level for this task - PrimroseFixture.equip() bypasses
## mounts entirely, the same way it does for every other weapon spec in this mod.
##
## LICENCE ACCESSOR CORRECTED FROM THE PLAN'S DRAFT (same correction test_rend_axe.gd already
## recorded): ContentLibrary has no get_license() method. The real accessor is get_license_tree()
## (content_library.gd:254).
##
## CARD-TEXT LINK CONVENTION CORRECTED FROM THE PLAN'S DRAFT. The plan's Step 3 CSV sketch wrote the
## Kit's `.effect` row as `Gain the |Biting Retort| reaction.` - a bare, untargeted pipe. That is not
## this mod's convention for naming a sibling ability: `|term|` with no `=target` only ever resolves
## through GlossaryItem.find_key_from_label against the curated glossary_terms.json allow-list
## (glossary_item.gd:174-209), and "Biting Retort" is a reaction name, not a registered rules term -
## it would render as inert coloured text with no link, silently. The established shape, matched
## verbatim in Reag-ThyHubris (localization/localizations.csv:49,
## `gear.ms_root.effect,"Gain the |Dig In=gear.ms_root.action_dig_in| |reaction|."` - the identical
## "grants a reaction" phrasing this card uses) and in vanilla (assets/localization/localizations.csv,
## e.g. `gear.cp_fortress.action_fortress_protocol_deactivate.effect`), is an explicit kit link plus a
## separately-piped generic term: `|Biting Retort=gear.mw_acrasial_falcata.action_biting_retort|
## |reaction|`. This resolves cleanly even before Task 2 creates action_biting_retort, because
## GlossaryItem.process_glossed_text only resolves the KIT half of a gear link (split_key[1]) and
## discards the `.<action>` segment entirely (glossary_item.gd:239-240; localization/README.md's
## "Wiki markup" section says so directly) - so the link is live against mw_acrasial_falcata (which
## this task creates) from the moment this task's content lands. `|reaction|` itself resolves to
## `lancer.action.rxn` (assets/localization/word_lists/glossary_terms.json:8; label "Reaction", a
## non-empty .desc, checked ahead of the unrelated `lancer.geartag.reaction` entry at :44 which has no
## .desc and would fail GlossaryItem's own guard). No LCP words were changed - the LCP's underlying
## sentence is "Gain the Biting Retort reaction."; only the wiki markup wrapping it was corrected to
## match house style instead of the plan's draft.
##
## Run:
##   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_acrasial_falcata.gd
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')

const FALCATA := &'mw_acrasial_falcata'
const ATTACK := &'action_acrasial_falcata'

## The card's numbers, transcribed once so a typo in the .tres reads as a number and not as a vague
## "feels wrong".
const SP_COST := 1
const THREAT := 3
const THREAT_WITH_CARESS := 4
const DAMAGE_DICE := '2d6+4'

## 2d6+4 with the fixture's cheat_a_hit() all-sixes buffer: 6 + 6 + 4 = 16, always, never a range.
const FALCATA_DAMAGE := 16

## SP3 Task 5. The three threat sources that stack on this weapon (ruling 11), and the trait ids the
## three pins below read.
const THREAT_WITH_CARESS_AND_DDMR := 5
const THREAT_WITH_EVERYTHING := 6
const MWR_USAGE_KEY := &'magnetic_weight'

const START := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)     # threat 1 would still reach this; not what THREAT proves alone
const AT_THREE := Vector2i(7, 4)     # exactly threat 3 away - a threat-1 regression cannot reach it
const CONTROL_TILE := Vector2i(20, 20) # far from everything else in this spec's map

var game:Gamemaster
var responder
var primrose:Unit
var hostile:Unit
var gear:GearCore

## SP3 Task 5 CHANGED THE FIXTURE FROM create_game TO create_game_with_prompts, and the difference is
## exactly one object: which ChoiceBusResponder is in the tree. setup_gamemaster's add_responder
## argument goes false and testkit/mod_choice_responder.gd is added instead (primrose_fixture.gd:121-126);
## everything else - the combat, the landscape, the forbidden_interiors_enabled flag - is identical
## between the two helpers (fitzgerald_fixture.gd:69-73 against primrose_fixture.gd:122-125). The
## testkit responder inherits choose_gear untouched and falls back to the stock `chosen_yesnos` /
## `chosen_multiple_choice_index` whenever its own queues are empty (mod_choice_responder.gd:82-83,
## :172), so the eight tests written under the stock responder see the same answers they always did -
## MEASURED, not assumed: this file went 8/8 -> 11/11 with no change to any pre-existing assertion.
## It is needed because PrimroseFixture.press_protocol takes a responder as an argument and answers
## GLIMMERING ARMAMENTS' multiple-choice from multiple_choice_queue, which the stock responder has no
## equivalent of at all.
func before_each() -> void:
	var pair := PrimroseFixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	primrose = PrimroseFixture.create_primrose(game, START)
	hostile = PrimroseFixture.create_hostile(game, ADJACENT, -10) # every swing hits
	hostile.core.frame.stat.health = 200
	hostile.core.full_repair()
	gear = PrimroseFixture.equip(primrose, FALCATA)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func weapon() -> ActionAttackWeapon:
	return gear.get_action(ATTACK) as ActionAttackWeapon

func specific() -> SpecificAction:
	return PrimroseFixture.specific(primrose, FALCATA)

## The Falcata's CURRENT threat, re-derived from the unit on every call.
##
## RE-DERIVED RATHER THAN CACHED, and that is load-bearing for the stacking pin: fit_ddmr and
## press_protocol both run SpecFactory.apply_passive_buffs -> full_repair -> regenerate_derived_gear,
## which rebuilds the loadout's GearCores, so a SpecificAction taken before either of them can be
## reading a gear the unit no longer holds. test_ddmr.gd re-takes its specific for the same reason.
func falcata_threat() -> int:
	var current := PrimroseFixture.specific(primrose, FALCATA)
	return current.action.threat_distance(current)

## Whether an overwatch-weapon list offers the Falcata. Matched on the KIT id, the shape
## test_wormhole_grasp.gd's offers_superheavy() uses for the Combat Drill.
func offers_falcata(list:Array[SpecificAction]) -> bool:
	for candidate:SpecificAction in list:
		if candidate.gear.kit.compcon_id == FALCATA: return true
	return false

## How many times Magnetic Weight Redistribution has spent its 1/round this round. -1 when the trait
## gear cannot be found at all, which is a different failure from "it never fired".
func mwr_uses() -> int:
	var trait_gear := primrose.get_gear(PrimroseFixture.MWR_ID)
	return trait_gear.get_uses_this_round_alt(MWR_USAGE_KEY) if GearCore.is_valid(trait_gear) else -1

## Fires the Falcata at `target_unit` (default `hostile`), opening the turn first. Does NOT clear the
## dice queue - the caller's cheat_* call is what decides the roll, same idiom as test_rend_axe.gd's
## swing().
func swing(target_unit:Unit = null) -> void:
	await PrimroseFixture.attack(game, primrose, FALCATA, target_unit if target_unit else hostile)

# ---------------------------------------------------------------- the weapon as data

func test_the_kit_is_registered_and_costs_one_sp() -> void:
	# Read off ContentLibrary, not off disk: this proves the resource was INDEXED under the right
	# ContentLibrary index. A weapon whose filename prefix is wrong is silently filed somewhere else
	# and vanishes from get_kit with no error at all.
	var kit:Kit = ContentLibrary.get_kit(FALCATA)
	assert_not_null(kit, 'mw_acrasial_falcata is in the kits index.')
	# assert_not_null ALONE IS VACUOUS AND WOULD PASS WITH THE KIT DELETED. MEASURED on this task's
	# own pre-content RED run: content_library.gd:231-236 never returns null from get_kit - an
	# unregistered id falls back to the shared Kit.UNKNOWN_ID ("mt_missing_mechsystem") placeholder
	# Kit, so assert_not_null passed silently even with no .tres on disk, and only the sp_cost
	# assertion (which read the placeholder's default 0) caught the absence. compcon_id is lazily
	# derived from the resource's own path (kit.gd:11-14), so the placeholder answers its OWN id, not
	# ours - checking it is the real gate this test needed and the plan's draft did not have.
	assert_eq(kit.compcon_id, FALCATA, 'the id asked for, not the Kit.UNKNOWN_ID placeholder.')
	if kit == null: return
	assert_eq(kit.sp_cost, SP_COST, 'SP 1, per the card.')

func test_the_profile_is_a_superheavy_melee_at_threat_three() -> void:
	var attack := weapon()
	assert_not_null(attack, 'the Kit carries action_acrasial_falcata.')
	if attack == null: return
	assert_eq(attack.weapon_size, Lancer.WEAPON_SIZE.SUPERHEAVY, 'Superheavy.')
	assert_true(attack.is_weapon_type(Lancer.WEAPON_TYPE.MELEE, gear), 'Melee.')
	assert_eq(attack.damage_dice, DAMAGE_DICE, '2d6+4 damage.')
	assert_eq(attack.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'kinetic.')
	assert_true(attack.tags.is_empty(), 'the card lists no tags at all.')
	# aim_range is 0 on every melee weapon in the tree; a nonzero value would make the Falcata
	# shootable at range through ranged_distance and is the single most likely copy-paste error here.
	assert_eq(attack.aim_range, 0, 'no aim range - it is a melee weapon.')
	# Read on the PRIMROSE, not on a bare printed `threat` field: Artful Caress applies automatically
	# to any Heavy/Superheavy melee weapon the Primrose carries (see header), so 4 is what every real
	# Primrose spec actually sees. The printed-3-alone case is test_artful_caress_widens_it_to_four's
	# control, not this test's.
	assert_eq(attack.threat_distance(specific()), THREAT_WITH_CARESS,
		'threat 3 printed, widened to 4 by the frame\'s own Artful Caress trait.')

func test_a_superheavy_swing_is_a_full_action() -> void:
	# Derived from weapon_size, not declared: action_attack_weapon.gd:87-91 returns FULL only for
	# SUPERHEAVY and QUICK for everything else. So this assertion is really "weapon_size really is 3",
	# pinned behaviourally rather than just as a data field.
	var attack := weapon()
	if attack == null: return assert_true(false, 'no action to inspect.')
	assert_eq(attack.get_action_type(specific()), Lancer.ACTION.FULL, 'a Superheavy weapon is a Full action.')

func test_it_hits_for_two_d_six_plus_four() -> void:
	PrimroseFixture.cheat_a_hit()
	await swing()
	# Exact, not just >0: this is also the vacuity guard (16 > 0 proves the roll happened at all), and
	# an exact number catches a "2d4+4" or a dropped "+4" typo that "some damage landed" would not.
	assert_eq(hostile.current_damage(), FALCATA_DAMAGE, 'VACUITY + exact damage: 2d6(6,6)+4 = 16.')

func test_it_reaches_a_hostile_three_tiles_away() -> void:
	# CORRECTED AT IMPLEMENTATION, after MEASURING mutation M1 (threat 3 -> 1) fail to redden a first
	# draft of this test that only fired SpecFactory.use_solo() and checked damage landed. Root cause:
	# use_solo/use build event_gear_activate directly with a pre-chosen target_unit
	# (test/factory/spec_factory.gd:248-278) and NOTHING downstream re-validates that target against
	# range. event_gear_activate.check_specific_context (content/events/event_gear_activate.gd:32-51)
	# gates on UnitAction.can_activate_gear alone, which is charges/usage/action-economy, never a
	# specific target's distance - range/threat legality is a picker-time concern
	# (UnitTargeting.get_tiles_in_range, below) that a spec-driven direct target bypasses entirely.
	# So firing at AT_THREE and checking damage landed would have stayed GREEN with the printed
	# threat wrongly at 1 - the mutation table's own prediction for this test was WRONG, and this is
	# the fix, not a rationalization of the wrong prediction.
	#
	# The real proof is that the ENGINE'S OWN legal-targeting computation - the same one the player's
	# target picker and the AI both consult - considers AT_THREE reachable at all:
	# UnitTargeting.get_tiles_in_range (engine/character/unit/service/unit_targeting.gd:16-58) builds
	# its tile set from action.get_target_range(specific), which for a melee weapon at threat > 0 IS
	# threat_distance(specific) (action_attack_weapon.gd:197-201) - so tile membership here is a
	# direct, non-bypassable read of the same threat number the card promises.
	var in_range:Array[Vector2i] = UnitTargeting.get_tiles_in_range(specific())
	assert_has(in_range, AT_THREE, 'AT_THREE is within the Falcata\'s legal target range.')

	# Kept as a behavioural companion, not the proof: it shows the reach is not merely computed but
	# also fireable, and it is what a threat-3-but-broken-LOS or threat-3-but-refused-activation
	# regression would still catch.
	UnitTile.move_to(hostile, AT_THREE)
	PrimroseFixture.cheat_a_hit()
	await swing()
	assert_eq(hostile.current_damage(), FALCATA_DAMAGE, 'and firing at that range really lands.')

func test_artful_caress_widens_it_to_four() -> void:
	# The Primrose case, restated on its own so a regression here cannot hide behind the combined
	# assertion in test_the_profile_is_a_superheavy_melee_at_threat_three.
	assert_eq(weapon().threat_distance(specific()), THREAT_WITH_CARESS,
		'Artful Caress (mt_artful_caress/buff_artful_caress.tres) widens threat 3 -> 4.')

	# The control: a plain unit with no Primrose frame, so it cannot carry the Artful Caress trait
	# Kit at all - built with SpecFactory.create_unit + PrimroseFixture.equip() directly, the same
	# shape test_uncertainty_field.gd's "plain" control uses.
	var control:Unit = SpecFactory.create_unit(game.map, CONTROL_TILE)
	var control_gear:GearCore = PrimroseFixture.equip(control, FALCATA)
	# GUARD: the control really lacks the trait, so a green result below cannot be an accident of the
	# control unhappily inheriting Artful Caress from somewhere else (e.g. a shared default frame).
	assert_false(control.has_kit(PrimroseFixture.CARESS_ID),
		'GUARD: the control carries no mt_artful_caress trait Kit.')
	var control_weapon:ActionAttackWeapon = control_gear.get_action(ATTACK) as ActionAttackWeapon
	var control_specific := PrimroseFixture.specific(control, FALCATA)
	assert_eq(control_weapon.threat_distance(control_specific), THREAT,
		'without the trait, the same Kit is back to its printed threat 3.')

func test_the_licence_grants_it_at_rank_two() -> void:
	# CORRECTED FROM THE PLAN'S DRAFT (same correction test_rend_axe.gd already made for rank 1):
	# ContentLibrary.get_license does not exist. get_license_tree (content_library.gd:254) is real.
	var license:UnlockTree = ContentLibrary.get_license_tree(PrimroseFixture.LICENSE_ID)
	assert_not_null(license, 'li_primrose is registered.')
	if license == null or license.rank_2 == null: return
	var ids:Array[StringName] = []
	for kit:Kit in license.rank_2.granted_gear: ids.append(kit.compcon_id)
	assert_has(ids, FALCATA, 'rank 2 grants the Acrasial Falcata.')

## THIS MOD'S OWN compiled artifact, not the global tr() - see test_rend_axe.gd's identical const for
## why: get_message returns an EMPTY StringName for a key the artifact does not carry, where the
## global tr() falls back to the raw key, so only this lookup can attribute the row to THIS mod and
## not to a sibling Reag-* mod that happens to answer the same key.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

func test_the_card_text_reaches_the_player() -> void:
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation,
		'This mod has a compiled translation (run the headless --import if this is a fresh clone).')
	if translation == null: return
	for key:String in ['gear.mw_acrasial_falcata.name', 'gear.mw_acrasial_falcata.flavor',
			'gear.mw_acrasial_falcata.effect']:
		assert_ne(translation.get_message(key), StringName(''),
			'%s is carried by THIS mod, not by a sibling.' % key)

	# THE CSV ESCAPING, CHECKED DIRECTLY. The LCP's flavour text quotes "gunsword" verbatim, which the
	# CSV needs doubled (""gunsword"") per RFC4180 so the csv_translation importer treats it as a
	# literal embedded quote rather than closing the field early - the same escaping this mod's own
	# frame.mf_fitzgerald.flavor and gear.mw_psychopomp_fold_pike.name rows already use successfully.
	# Checked here rather than assumed from that precedent: a single stray quote would either truncate
	# the field (breaking the CSV importer's later rows, not just this one) or leave the doubled quotes
	# in the compiled text verbatim, and neither failure mode would be caught by the mere non-emptiness
	# check above.
	var flavor := String(translation.get_message('gear.mw_acrasial_falcata.flavor'))
	assert_true(flavor.contains('no mere "gunsword", it is far too sharp'),
		'the doubled CSV quotes compiled down to a single literal pair, not zero and not four.')
	assert_false(flavor.contains('""'), 'no doubled quotes survived into the compiled text.')

# ------------------------------------------------------- SP3 Task 5: the frame meeting the weapon

## THE THREE PINS BELOW ARE IN THIS FILE, NOT IN test_ddmr.gd OR test_magnetic_weight_redistribution.gd,
## and the reason is the same one for all three: each asks what the FALCATA does, and the frame
## mechanic is the variable. A reader who sees a red here is told "the Falcata is wrong"; the same
## assertion in the DDMR's or the trait's file would say "the DDMR is wrong" about a weapon that file
## otherwise never mounts. This file already carries the weapon's other two threat readings (3 printed,
## 4 under Artful Caress), so the stacking pin is the third and fourth entries of a table that already
## lives here, rather than a fifth reading in a fourth place.
##
## ALL THREE ARE CHARACTERISATION PINS AND WERE GREEN ON ARRIVAL: no content was written for any of
## them, which was the expected result (this sub-project's remaining content shipped in Tasks 1-4).
## Their discriminating evidence is therefore the mutation each one carries, recorded in
## .superpowers/sdd/progress-primrose-sp3.md - not a first-run RED.

func test_the_three_threat_sources_stack_on_the_falcata() -> void:
	# RULING 11: Artful Caress (+1, Heavy/Superheavy melee), the DDMR (+1, the modded weapon) and
	# Wormhole Grasp (+1, every weapon) are unfiltered BY EACH OTHER and stack. threat_distance sums
	# every Buff.TO.ACTION_RANGE buff whose bonus_subtype is threat_range (action_attack_weapon.gd:
	# 187-190), and none of the three overrides, so the arithmetic is plain addition.
	#
	# EVERY INTERMEDIATE NUMBER IS ASSERTED, deliberately, so a red names the missing source instead of
	# just "6 was not 6": 3 is the printed field, 4 adds the frame's trait, 5 adds the weapon mod, 6
	# adds the core power. Tasks 1 and 4 measured the first three; only the last is new here.
	assert_eq(weapon().threat, THREAT, 'printed threat 3, before anything at all.')
	assert_eq(falcata_threat(), THREAT_WITH_CARESS, '+ Artful Caress (frame trait) = 4.')

	PrimroseFixture.fit_ddmr(primrose, primrose.get_gear(FALCATA))
	assert_eq(falcata_threat(), THREAT_WITH_CARESS_AND_DDMR, '+ the DDMR (weapon mod) = 5.')

	# THE PROTOCOL IS PRESSED LAST, AND THAT IS NOT STYLE. PrimroseFixture.equip's header records why:
	# every equip/fit runs SpecFactory.apply_passive_buffs -> full_repair, which sets
	# core.has_core_power = true again (unit_printer.gd:76) - so fitting the DDMR after this press would
	# silently refund the core power and the assertion below would be measuring a Primrose that had
	# never spent it.
	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_true(UnitCondition.has_buff(primrose, PrimroseFixture.WORMHOLE_GRASP),
		'fixture: the Wormhole Grasp marker landed.')
	assert_eq(falcata_threat(), THREAT_WITH_EVERYTHING, '+ Wormhole Grasp (core power) = 6, ruling 11.')

func test_the_falcata_can_overwatch_only_under_wormhole_grasp() -> void:
	# SP1 proved this waiver (res/engine/character/unit/service/unit_relation.gd_ext.gd) with vanilla's
	# mw_combat_drill, the only Superheavy melee weapon in the base game. This is the same claim asked
	# of the frame's OWN Superheavy, which is what a player will actually be holding: the extension
	# reads nothing but the marker buff and the weapon's size, so a Falcata that failed here would mean
	# the weapon's size export, not the waiver.
	#
	# THE EXACT CALL action_overwatch.gd:21 MAKES, copied from test_wormhole_grasp.gd rather than
	# invented - get_weapons_that_can_overwatch is where vanilla's SUPERHEAVY refusal
	# (unit_relation.gd:293-299, through is_weapon_available_as_a_rxn) is reached from.

	# VACUITY GUARD, and it is the one this test actually needs: "not offered" is also what an
	# out-of-threat or unreachable target produces, and that failure would survive the press and make
	# BOTH halves read as a broken waiver. Asking the engine's own legal-target set first rules it out.
	assert_has(UnitTargeting.get_tiles_in_range(specific()), ADJACENT,
		'GUARD: the hostile is inside the Falcata\'s threat, so nothing but the SIZE gate is in play.')

	assert_false(offers_falcata(UnitRelation.get_weapons_that_can_overwatch(primrose, hostile)),
		'Vanilla refuses a SUPERHEAVY weapon an Overwatch, and so does the extension without the marker.')

	await PrimroseFixture.press_protocol(game, primrose, responder, PrimroseFixture.WORMHOLE_INDEX)
	assert_true(UnitCondition.has_buff(primrose, PrimroseFixture.WORMHOLE_GRASP),
		'fixture: the Wormhole Grasp marker landed.')

	assert_true(offers_falcata(UnitRelation.get_weapons_that_can_overwatch(primrose, hostile)),
		'THE CLAIM: with the marker up, Overwatch offers the frame\'s own Superheavy.')

func test_a_falcata_crit_fires_magnetic_weight_redistribution() -> void:
	# The trait is "a Heavy or Superheavy melee weapon", and until this sub-project the only Superheavy
	# a Primrose could hold was vanilla's Combat Drill - so test_magnetic_weight_redistribution.gd
	# proves the trait against a weapon the frame does not ship. This is the same claim against the
	# frame's own, and it is the only place the two halves of the licence meet.
	#
	# THE SAVE IS FORCED TO FAIL THROUGH HaseBlock, NOT THE DICE QUEUE (PrimroseFixture.force_save_to_
	# fail): the attack ahead of the save pops an unpredictable number of accuracy and damage dice out
	# of the same global FIFO, so queuing a d20 for the save would be guessing how many the attack ate
	# first. With the save pinned, Prone is an assertion about the TRAIT and not about the dice.
	PrimroseFixture.force_save_to_fail(hostile)
	assert_eq(mwr_uses(), 0, 'fixture: the trait has not fired yet this round.')

	PrimroseFixture.cheat_a_crit()
	await swing()

	assert_gt(hostile.current_damage(), 0, 'VACUITY GUARD: the swing really landed.')
	assert_true(hostile.has_status(Lancer.STATUS.PRONE),
		'THE CLAIM: a Superheavy melee CRIT with the Falcata forced a Hull save, and it was failed.')
	# RULING 12's own pin, restated here: the round is spent by FORCING the save, so this reads 1 only
	# if onhit_magnetic_weight_redistribution.should_abort actually ran for this weapon. Without it,
	# "Prone" alone could in principle come from anywhere.
	assert_eq(mwr_uses(), 1, 'And the trait spent its 1/round on this weapon.')
