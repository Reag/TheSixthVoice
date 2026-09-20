# NIGHTFARE NEXUS (the Sluagh's rank-II weapon, SP3 Task 1).
#
#   "Auxiliary Nexus, SMART. 3 Energy, Range 15.
#    On hit: The target gains soft cover until the start of your next turn."
#
# NO SCRIPT ANYWHERE IN THIS ABILITY, the Rend Nexus's shape one card over. The engine's OnHitEffect
# carries apply_on, buffs and apply_buffs_to_self, and the ON_HIT stage with apply_buffs_to_self
# LEFT FALSE puts the buff on the attacked unit (on_hit_effect.gd:86-88) - which is the whole
# difference between this card and the Rend Nexus's, whose crit chip goes to the attacker.
#
# THE CLOCK IS THE SLUAGH'S, AND IT IS THE GEAR THAT SAYS SO. Lancer.UNTIL.START_OF_OWNERS_TURN
# (lancer.gd:51, enum index 6) "hangs out until the start of the turn of the unit who placed this",
# and "the unit who placed this" is resolved from the buff's from_gear:
# BuffCore.get_owner_unit (buff_core.gd:102-105) maps from_gear through
# map.get_unit_from_source_id, and UnitCondition.clear_owners_turn_statuses - called for the
# STARTING unit at event_turn_start.gd:77 - walks every unit on the map clearing buffs that answer
# is_unit_owner(starter). OnHitEffect passes context.gear into apply_buffs, so the owner is the
# Sluagh and the chip clears at the SLUAGH'S turn start however far away the target is standing.
# test_the_chip_clears_at_the_start_of_the_sluaghs_next_turn asserts BOTH halves of that, because a
# buff with an empty from_gear would have a null owner and never clear at all - and "it is still
# there" and "it was never applied" leave the same absence.
#
# THIS WEAPON POPS ONE ENTRY OFF Dice.CHEAT_ROLL_QUEUE, NOT THREE. Its damage is the flat string
# '3', so Dice.roll_dice's loop body never runs (the same reason a tech attack's flat '2' costs no
# queue entry, dice.gd:22-35), and it sets no attack_accuracy so roll_d6_accuracy(0) returns 0
# without rolling (dice.gd:87-88). Only the d20 is popped. THE REND NEXUS POPS THREE because 1d3+1
# is rolled twice (attack_util.gd:250-251, hit_rolls and crit_rolls separately) - do not copy
# nexus_shot's queue comment onto this weapon.
#
# COVER IS ASSERTED TWO WAYS ON PURPOSE, the shape test_mark_of_the_dead.gd established:
# UnitCondition.has_buff says the on-hit effect placed the chip, and
# CoverCalculator.determine_cover says the engine's own cover pipeline reads it. Neither implies the
# other - the first would stay green if the buff were authored on the wrong channel, and the second
# would stay green if some other source of cover were in play.
#
# NOTHING ON THE FRAME INTERFERES, and it is worth saying which things were checked. Astral Guardian
# needs the DEFENDER to be an allied character adjacent to the Sluagh; every shot here is at a
# hostile fifteen tiles away. Wicked Host needs the SLUAGH to be hit; nothing shoots back. The
# Stealing needs a hostile death; the target is a 200 HP dummy. So no trait pops a d6 and the queue
# is exactly what each test writes.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_nightfare_nexus.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## Eight tiles east: well inside Range 15, and far outside anything's threat or adjacency.
const TARGET_TILE := Vector2i(12, 6)

## Beats a dummy's evasion 10 comfortably and does not reach attack_roll.gd:73's total_roll >= 20,
## so the ON_CRIT stage never runs and a crit-staged effect could not pass for an on-hit one.
const D20_HITS := 15
## Loses to anything.
const D20_MISSES := 1

## The card's flat damage. A Nexus has no Reliable, so a miss really does land nothing - which is
## what lets test_a_miss_leaves_nothing read the damage number as evidence the shot missed.
const FLAT_DAMAGE := 3

var game:Gamemaster
var sluagh:Unit
var target:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.arm_nightfare_nexus(sluagh)
	target = SluaghFixture.create_hostile(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func chipped(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, SluaghFixture.NIGHTFARE_CHIP)

## What the engine's own cover pipeline answers for a shot from the Sluagh at `unit`. A pure read -
## it rolls nothing and spends nothing, so it can be called as often as a test likes.
func cover_from_the_sluagh(unit:Unit) -> Lancer.COVER:
	return CoverCalculator.determine_cover(unit, sluagh).total

# ---------------------------------------------------------------- the profile

func test_the_profile_matches_the_card():
	# EVERY NUMBER OFF THE SHEET (specs/sixth-voice/08-sluagh.md:69-74), read from the RESOURCE, so a
	# red here means the .tres drifted from the card rather than that the engine changed.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.NIGHTFARE_NEXUS)
	assert_not_null(kit, 'mw_nightfare_nexus loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0, as the sheet says.')
	assert_false(kit.is_trait, 'It is licence gear, not a frame trait.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	assert_true(kit.passives.is_empty(), 'And no passives.')
	if kit.actions.is_empty(): return

	var shot:ActionAttackWeapon = kit.actions[0]
	assert_not_null(shot, 'And it is an ActionAttackWeapon.')
	if shot == null: return
	assert_eq(shot.get_id(), &'action_nightfare_nexus', 'Named for its own file.')
	assert_eq(shot.weapon_size, Lancer.WEAPON_SIZE.AUX, 'AUXILIARY - the Rend Nexus is the MAIN one.')
	assert_eq(shot.weapon_type, Lancer.WEAPON_TYPE.NEXUS, 'NEXUS.')
	assert_eq(shot.damage_dice, '3', 'Damage a flat 3...')
	assert_eq(shot.damage_type, Lancer.DAMAGE_TYPE.ENERGY, '...of ENERGY.')
	assert_eq(shot.aim_range, 15, 'Range 15.')
	assert_true(shot.tags.has(Lancer.WEAPON_TAG.SMART), 'SMART...')
	assert_false(shot.tags.has(Lancer.WEAPON_TAG.AP),
		'...and NOT AP - the card gives this one SMART alone, unlike the Rend Nexus.')
	assert_eq(shot.tags.size(), 1, 'And nothing else.')
	# A FLAT DAMAGE STRING REALLY PARSES TO NO DICE, and this is what says so rather than assuming
	# it. Dice.process_dice_string finds no 'd' and returns count 0 with the whole string as the
	# bonus, so roll_dice's loop body never runs and the queue is untouched. Every test below counts
	# on that: their queues are one entry long.
	var parsed:Dictionary = Dice.process_dice_string(shot.damage_dice)
	assert_eq(parsed.count, 0, '"3" parses to no dice at all...')
	assert_eq(parsed.bonus, 3, '...and a flat bonus of 3.')

func test_the_kit_carries_one_on_hit_effect_that_buffs_the_target():
	# THE DECLARATIVE HALF. Everything this ability does lives in these four fields, so a mutation to
	# any of them has to be visible here as well as behaviourally - otherwise a silent .tres edit
	# that only bites on a rare path reads green.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.NIGHTFARE_NEXUS)
	assert_not_null(kit, 'fixture: the Kit loads.')
	# THE ACTION COUNT IS ASSERTED BEFORE THE GUARD, not after it. ContentLibrary.get_kit does not
	# return null for an id it has never heard of - it hands back the mt_missing_mechsystem
	# placeholder (kit.gd:13, UNKNOWN_ID), which is a Kit with an empty actions array - so a bare
	# `if kit == null or kit.actions.is_empty(): return` would slip past assert_not_null and return
	# without asserting anything discriminating. Measured on this very file's RED run (2026-09-21):
	# this test was the ONE green of eight before any content existed.
	assert_eq(kit.actions.size(), 1, 'fixture: the Kit carries its one action.')
	if kit == null or kit.actions.is_empty(): return
	var shot:ActionAttackWeapon = kit.actions[0]
	assert_eq(shot.on_hit_effects.size(), 1, 'Exactly one on-hit effect.')
	if shot.on_hit_effects.is_empty(): return

	var effect:OnHitEffect = shot.on_hit_effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_HIT,
		'ON_HIT, not ON_CRIT - the card says "on hit".')
	assert_false(effect.apply_buffs_to_self,
		'On the TARGET. apply_buffs_to_self is the Rend Nexus\'s switch, and this card is the '
		+ 'opposite case: on_hit_effect.gd:86-88 sends the buff to attacked_unit when it is false.')
	assert_true(effect.statuses.is_empty(), 'No statuses - a buff is the whole effect.')
	assert_eq(effect.buffs.size(), 1, 'And one buff.')
	if effect.buffs.is_empty(): return

	var chip:Buff = effect.buffs[0]
	assert_eq(chip.compcon_id, SluaghFixture.NIGHTFARE_CHIP, 'It is the soft-cover chip...')
	assert_true(chip is BuffCover, '...a BuffCover...')
	if chip is not BuffCover: return
	assert_eq((chip as BuffCover).cover, Lancer.COVER.SOFT, '...SOFT, not hard...')
	assert_eq(chip.to, Buff.TO.COVER,
		'...on the cover channel, which is the only one CoverCalculator reads.')
	assert_eq(chip.until, Lancer.UNTIL.START_OF_OWNERS_TURN,
		'"until the start of your next turn" - the OWNER\'S turn, and the owner is the Sluagh '
		+ 'because OnHitEffect passes its gear into apply_buffs.')
	assert_false(chip.hide_from_player,
		'VISIBLE (author, 2026-09-21). Unlike buff_mark_soft_cover, which is hidden because '
		+ 'buff_mark_of_the_dead stands beside it as the signal, this chip is the only marker the '
		+ 'shot leaves on the target.')

# ---------------------------------------------------------------- landing it

func test_a_hit_leaves_the_soft_cover_chip_on_the_target():
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_eq(target.current_damage(), FLAT_DAMAGE, 'fixture: the shot landed its flat 3.')
	assert_true(chipped(target), 'A hit hands the target soft cover.')

func test_a_hit_leaves_nothing_on_the_sluagh():
	# THE DISCRIMINATING NEGATIVE against the Rend Nexus's shape, which is the mistake this file is
	# one copy-paste away from: apply_buffs_to_self would put the chip here instead, and the test
	# above would still be red-or-green for the wrong reason only if it also checked the target.
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_false(chipped(sluagh), 'The Sluagh gains nothing; the cover is the TARGET\'S.')
	assert_eq(cover_from_the_sluagh(sluagh), Lancer.COVER.NONE, 'And it stands in the open.')

func test_a_miss_leaves_nothing():
	SluaghFixture.queue([D20_MISSES])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_eq(target.current_damage(), 0,
		'fixture: the shot missed, and a Nexus has no Reliable to floor it.')
	assert_false(chipped(target), 'A miss hands out no cover.')

# ---------------------------------------------------------------- reading it

func test_the_next_attack_against_the_target_reads_soft_cover():
	# has_buff above says the chip was PLACED. This says the engine's own pipeline READS it, which is
	# a different claim: CoverCalculator.determine_cover consults the defender's and the attacker's
	# Buff.TO.COVER buffs and nobody else's (cover_calculator.gd:56-62), so a chip authored on any
	# other channel would satisfy has_buff and fail here.
	assert_eq(cover_from_the_sluagh(target), Lancer.COVER.NONE, 'fixture: the target starts open.')
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_eq(cover_from_the_sluagh(target), Lancer.COVER.SOFT,
		'The cover pipeline answers SOFT for the next shot at it.')

func test_a_target_already_in_hard_cover_keeps_hard():
	# MAX-THEN-ZERO (cover_calculator.gd). Soft cover landing on a unit already in hard cover changes
	# nothing, which is ruling 19's own recorded consequence - "a target already in hard cover
	# changes nothing" - and is the honest limit of this card against a dug-in enemy.
	# A VANILLA HARD-COVER BUFF RATHER THAN TERRAIN, test_mark_of_the_dead.gd's reasoning verbatim: a
	# one-tall block beside a size-1 unit is exactly the geometry test_draw_fire.gd measured as
	# unreliable, and the claim here is about the cover CHANNEL, not about sightlines.
	SpecFactory.apply_buff(target, SluaghFixture.HARD_COVER_BUFF)
	assert_eq(cover_from_the_sluagh(target), Lancer.COVER.HARD, 'fixture: it is in hard cover.')

	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_true(chipped(target), 'The chip still lands...')
	assert_eq(cover_from_the_sluagh(target), Lancer.COVER.HARD,
		'...and the total is still HARD: cover is the MAX of what applies, not a sum.')

# ---------------------------------------------------------------- the clock

func test_the_chip_clears_at_the_start_of_the_sluaghs_next_turn():
	# BOTH HALVES OF THE CLOCK IN ONE TEST, because they are one claim: the buff belongs to the
	# SLUAGH, not to the unit wearing it. UnitCondition.clear_owners_turn_statuses is called for the
	# STARTING unit (event_turn_start.gd:77) and clears only buffs that answer is_unit_owner(starter)
	# - so the target's own turn start must leave it alone and the Sluagh's must take it.
	#
	# WITHOUT THE FIRST HALF THIS TEST WOULD PASS ON A BROKEN BUFF. A chip whose from_gear were empty
	# would have a NULL owner and clear at nobody's turn start; a chip owned by the TARGET would
	# clear one turn too early. Only asserting the survival and the clearing separately tells the
	# two apart.
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.nightfare_shot(game, sluagh, target)
	assert_true(chipped(target), 'fixture: the chip landed.')

	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, target)
	assert_true(chipped(target),
		'It survives the TARGET\'S own turn start - the owner is the Sluagh, not the wearer.')
	await SpecFactory.end_turn(game, target)
	assert_true(chipped(target),
		'And it survives the target\'s turn END too. THIS IS THE ASSERTION THAT MAKES THE CLOCK '
		+ 'MEASURABLE, and it was added after a mutation ran green without it (2026-09-21): '
		+ 'UnitCondition.end_turn_for_statuses runs on ALL units at every turn end and clears an '
		+ 'END_OF_NEXT_TURN buff once its turn_count has reached 1 (unit_condition.gd:32-41), which '
		+ 'that counter does at the wearer\'s own turn start (:24). So a chip authored until = 1 '
		+ 'would be gone HERE - one step before the Sluagh\'s turn start - and the assertion below '
		+ 'would pass for the wrong reason.')

	await SluaghFixture.open_turn(game, sluagh)
	assert_false(chipped(target), 'And the SLUAGH\'S next turn start is what clears it.')
	assert_eq(cover_from_the_sluagh(target), Lancer.COVER.NONE, 'The cover goes with it.')

# ---------------------------------------------------------------- the card and the licence

func test_the_card_rows_resolve():
	# Through THIS MOD'S OWN compiled artifact first, so a sibling Reag-* mod loaded in the same
	# testkit run cannot hold this green - test_rend_nexus.gd's pattern, and the mod's habit.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mw_nightfare_nexus.name', 'gear.mw_nightfare_nexus.flavor',
			'gear.mw_nightfare_nexus.on_hit']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mw_nightfare_nexus.name'), 'Nightfare Nexus', 'The card\'s own name.')
	# X.tr KEEPS THE GLOSSARY PIPES (SP1 Task 7's finding), so this pins the pipe too - the only
	# thing that would catch |soft cover| being written unpiped, or piped on a label that does not
	# resolve. lancer.cover.SOFT is what it resolves to, and the mod already pipes that exact
	# spelling at gear.buff_mark_of_the_dead.effect.
	assert_eq(X.tr('gear.mw_nightfare_nexus.on_hit'),
		'The target gains |soft cover| until the start of your next turn.',
		'The LCP verbatim, pipes added. No divergence is recorded for this card and none is wanted.')
	# THE ENGINE REALLY READS THIS KEY - it is not decoration. Translate.action falls through from
	# gear.<kit>.<action>.on_hit to gear.<kit>.on_hit (translate.gd:26-29, :44-45), and both surfaces
	# that draw a weapon card read it through that fallback: the character sheet at kit.gd:256 and
	# the action tooltip at tooltip_organ_action.gd:188.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.NIGHTFARE_NEXUS)
	if kit == null or kit.actions.is_empty(): return assert_true(false, 'fixture: the Kit loaded.')
	assert_eq(Translate.action(kit, kit.actions[0], 'on_hit', false),
		X.tr('gear.mw_nightfare_nexus.on_hit'),
		'And Translate.action finds it from the ACTION, through the Kit-level fallback.')

func test_the_licence_grants_it_at_rank_two():
	var licence:UnlockTree = ContentLibrary.get_license_tree(SluaghFixture.LICENSE_ID)
	assert_not_null(licence, 'li_sluagh loads as an UnlockTree.')
	if licence == null: return
	var rank_2_ids:Array[StringName] = []
	for kit:Kit in licence.rank_2.granted_gear: rank_2_ids.append(kit.compcon_id)
	assert_true(rank_2_ids.has(SluaghFixture.NIGHTFARE_NEXUS), 'Rank 2 grants the Nightfare Nexus.')
	# RANK 2 ALSO STILL GRANTS THE FRAME, and that is worth one line here: UnlockTree.license_name
	# reads rank_2.granted_frames.front() (unlock_tree.gd:28-32), so a granted_gear edit that
	# clobbered granted_frames would rename the whole licence "???" - which test_sluagh_frame.gd
	# catches by its own route, but this task is the one that could cause it.
	assert_eq(licence.rank_2.granted_frames.size(), 1, 'And rank 2 still grants the frame itself.')
	# Only the claims THIS task could have broken; the exact sorted lists are test_sluagh_frame.gd's.
	assert_true(licence.rank_3.granted_gear.is_empty(), 'Rank 3 is still empty, until SP4.')
