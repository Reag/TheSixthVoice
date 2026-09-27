# MARK OF THE DEAD AND THE DAMNED AND THE LOST (the active half of CRY OF THE HOSTED DEAD, SP1
# Task 7) - the chip, and the soft cover it hangs on everyone beside the Sluagh.
#
#   "A dome of bleak darkness envelops you, causing the following effects until the end of the scene:
#    - You and adjacent allied characters gain soft cover."
#
# (The card's SECOND bullet, the miss reaction, is Task 8 and is specced in test_mark_retort.gd.)
#
# AN AURA, BECAUSE COVER READS TWO UNITS AND NEITHER OF THEM IS A BYSTANDER.
# CoverCalculator.determine_cover asks the DEFENDER's and the ATTACKER's Buff.TO.COVER buffs and
# nobody else's (cover_calculator.gd:56-62), so a buff on the Sluagh cannot shelter the ally standing
# next to it. The buff has to be ON the ally. Ruling 14.
#
# MOST ASSERTIONS GO THROUGH UnitCondition.has_buff, AND TWO GO THROUGH CoverCalculator - on purpose.
# has_buff says the aura placed the chip; determine_cover says the engine's own cover pipeline reads
# it. The end-to-end case fires a real shot and reads the DAMAGE, because an accuracy modifier that
# turns a hit into a miss is the only statement about cover that cannot be satisfied by the buff
# merely existing.
#
# ASTRAL GUARDIAN IS ON THIS SAME KIT AND FIRES ON A HIT ON AN ADJACENT ALLY, 1/round - so the
# end-to-end case is arranged so it is never offered: the hit lands on an ally TWO TILES OUT (not
# adjacent), and the adjacent ally is MISSED (the guardian requires a hit). Nothing pops a guardian
# d6, so the damage die stays the last entry of each queue. Task 6's finding, applied.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mark_of_the_dead.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
const ADJACENT_TILE := Vector2i(5, 6)
const TWO_OUT_TILE := Vector2i(6, 6)
## Adjacent on the other side, for the enemy and drone controls.
const OTHER_ADJACENT_TILE := Vector2i(4, 5)
const SHOOTER_TILE := Vector2i(9, 6)

## Beats the dummy's evasion 10 on its own, and loses to it once soft cover's -1 pops a 6. The same
## trick test_wicked_host.gd uses, and for the same reason: it makes the cover measurable as DAMAGE
## rather than as the presence of a buff.
const D20_HITS_ONLY_WITHOUT_COVER := 11
const WORST_ACCURACY_DIE := 6
const DAMAGE_DIE := 5
const RELIABLE := 2

var game:Gamemaster
var sluagh:Unit
var ally:Unit
var shooter:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	ally = SluaghFixture.create_ally(game, ADJACENT_TILE)
	shooter = SluaghFixture.create_hostile(game, SHOOTER_TILE)
	SluaghFixture.arm_rifle(shooter)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func sheltered(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, SluaghFixture.SOFT_COVER_CHIP)

func cover_against_the_shooter(unit:Unit) -> Lancer.COVER:
	return CoverCalculator.determine_cover(unit, shooter).total

func core_gear() -> GearCore: return sluagh.get_gear(SluaghFixture.CORE_ID)

# ---------------------------------------------------------------- the wiring

func test_the_active_is_on_the_core_kit():
	var gear:GearCore = core_gear()
	assert_true(GearCore.is_valid(gear), 'fixture: the core system is on the unit.')
	if not GearCore.is_valid(gear): return
	var action = gear.get_action(SluaghFixture.MARK_ACTION_ID)
	assert_true(action is ActionSystemApplyBuff, 'The Mark is an ActionSystemApplyBuff.')
	if action is not ActionSystemApplyBuff: return
	# Lancer.ACTION is { NONE, QUICK, FULL, FREE, PROTOCOL, RXN } (lancer.gd:27), so QUICK is 1 - and
	# ActionSystem.action_type defaults to NONE, which would also make show_in_tooltip false
	# (action_system.gd:27-29) and drop the card's own name off the trait card.
	assert_eq(action.get_action_type(SpecificAction.create(sluagh, gear, action)), Lancer.ACTION.QUICK,
		'QUICK, per the LCP\'s activation.')
	# IT IS THE CORE POWER. action_step_of_mist_and_thunder.tres is this mod's own precedent for
	# action_type = 1 plus consumes_cp, and vanilla's action_charge_rail.tres is the engine's.
	#
	# int(), NOT assert_true: consumes_core_power() is declared `-> int` while returning a bool
	# export (action.gd:167, action_system.gd:31), so it hands back 1 and GUT's assert_true refuses
	# it outright with "Cannot convert 1 to boolean". test_glimmering_armaments.gd:76,
	# test_grav_amped_interference.gd:91 and test_mastication_of_the_maar.gd:142 are this mod's
	# three existing readings of the same call, and they all do this.
	assert_eq(int(action.consumes_core_power()), 1, 'And it spends the core power.')
	assert_true(action.apply_only_to_self, 'The dome envelops YOU - there is no target to pick.')
	# A usage_group PER ACTION on a Kit that carries three (unit_action.gd:167-168).
	assert_ne(gear.get_usage_group_for_action(action), SluaghFixture.CORE_ID,
		'It has its own usage group, not the Kit\'s default - three actions share this Kit.')

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.name',
			'gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.effect',
			'gear.buff_mark_of_the_dead.name',
			# THE CHIP'S OWN EFFECT ROW, added at the close (slice 3 M-1). It shipped correct and
			# nothing read it, so deleting it would have been silent - and not silent in a harmless
			# way. Translate.buff's fallback chain (translate.gd:73-77) would then try
			# gear.cp_cry_of_the_hosted_dead.<actions[0]>.effect, and actions[0] on this Kit is
			# action_astral_guardian (cp_cry_of_the_hosted_dead.tres), which deliberately has no
			# effect row - so the chain would land on gear.cp_cry_of_the_hosted_dead.effect, which
			# IS Astral Guardian's text. The dome's chip would read out the 1d6 Overshield passive
			# and the fallback would SUCCEED, so no raw-key guard anywhere would fire. That is the
			# lancer-tactics-buff-card-fallback shape exactly.
			'gear.buff_mark_of_the_dead.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	# The discriminating half: "it resolves" is not enough, because the fallback resolves too.
	assert_ne(X.tr('gear.buff_mark_of_the_dead.effect'), X.tr('gear.cp_cry_of_the_hosted_dead.effect'),
		'The chip describes the DOME, not Astral Guardian - which is what the Kit-level fallback '
		+ 'would hand it if the chip\'s own row went missing.')
	assert_eq(X.tr('gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.name'),
		'Mark of the Dead and the Damned and the Lost', 'The card\'s own name, entire.')
	# THE EFFECT ROW IS THE WHOLE active_effect, BOTH BULLETS. That is what the LCP holds - one
	# string - and the card should read the way the book reads. Task 8's reaction restates its own
	# half in its own row, which is exactly what GLIMMERING ARMAMENTS already does for its two
	# armaments in this same file.
	#
	# THE SUBSTRINGS CARRY THEIR GLOSSARY PIPES, because X.tr hands back the row exactly as the CSV
	# holds it - the pipes are stripped by the presentation layer, not by the translation. Measured
	# on the first green run of this file: the unpiped forms both failed while begins_with (a
	# pipe-free span) passed. Asserting the piped forms therefore also pins the pipes, which the
	# sub-project's localisation constraint wants pinned anyway: |soft cover| resolves to
	# lancer.cover.soft and |energy| to lancer.damagetype.energy.short, and "adjacent" is
	# deliberately UNPIPED because no glossary term matches it.
	var effect:String = X.tr('gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.effect')
	assert_true(effect.begins_with('A dome of bleak darkness'), 'It opens on the dome.')
	assert_true(effect.contains('adjacent allied characters gain |soft cover|'), 'It carries bullet one...')
	assert_true(effect.contains('deal |energy| damage to the attacker'), '...and bullet two.')

func test_the_aura_is_wired_the_way_ruling_14_specifies():
	# READ OFF THE LIVE KIT, because loadout.auras is what the engine polls and it is indexed from
	# kit.has_passive_type(PassiveAura) (loadout_core.gd:298-301). Untyped local for the passive: the
	# fields below are PassiveAura exports but the resource carries OUR subclass.
	var gear:GearCore = core_gear()
	assert_true(GearCore.is_valid(gear), 'fixture: the core system is on the unit.')
	if not GearCore.is_valid(gear): return
	# THE INDEXING IS THE FIRST CLAIM, and it is the one that fails silently. Kit.is_passive_of_type
	# matches the script or its DIRECT base and "only goes one layer deep" (kit.gd:161-165), so a
	# subclass of a subclass would never be indexed here and the aura would be dead with every other
	# assertion in this file still green.
	assert_true(sluagh.core.loadout.auras.has(gear),
		'The core Kit is indexed as an aura source - so passive_mark_cover_aura.gd extends '
		+ 'PassiveAura DIRECTLY (kit.gd:161-165 only goes one layer deep).')
	var auras:Array[Passive] = gear.get_passives_of_type(PassiveAura)
	assert_eq(auras.size(), 1, 'Exactly one aura on this Kit.')
	if auras.is_empty(): return
	var aura = auras[0]
	assert_not_null(aura.requires_buff, 'It is gated on a buff...')
	if aura.requires_buff == null: return
	assert_eq(aura.requires_buff.compcon_id, SluaghFixture.MARK_CHIP, '...and that buff is the Mark.')
	assert_eq(aura.buffs.size(), 1, 'It hangs exactly one buff...')
	if aura.buffs.is_empty(): return
	assert_eq(aura.buffs[0].compcon_id, SluaghFixture.SOFT_COVER_CHIP, '...the soft-cover one.')
	assert_true(aura.applies_to_self, 'On the Sluagh itself ("You and...").')
	assert_true(aura.applies_to_allies, 'And on allies.')
	assert_false(aura.applies_to_enemies, 'And never on enemies.')
	assert_true(aura.applies_only_to_characters, 'Characters only.')
	# The cover buff's own shape.
	var cover_buff:BuffCover = ContentLibrary.get_buff(SluaghFixture.SOFT_COVER_CHIP)
	assert_not_null(cover_buff, 'buff_mark_soft_cover loads as a BuffCover.')
	if cover_buff == null: return
	assert_eq(cover_buff.cover, Lancer.COVER.SOFT, 'SOFT cover, not hard.')
	assert_eq(cover_buff.to, Buff.TO.COVER, 'On the cover channel, which is the only one read.')
	assert_true(cover_buff.hide_from_player,
		'Hidden: the Mark chip is the signal, and two chips for one effect read as two effects.')

# ---------------------------------------------------------------- the dome

func test_pressing_the_mark_shelters_the_sluagh_and_an_adjacent_ally():
	assert_false(sheltered(sluagh), 'fixture: nobody is sheltered before the press.')
	assert_false(sheltered(ally), 'fixture: nor the ally.')

	await SluaghFixture.press_mark(game, sluagh)

	assert_true(UnitCondition.has_buff(sluagh, SluaghFixture.MARK_CHIP), 'The chip landed.')
	# NO track() CALL HERE, AND THAT IS THE TEST. Applying a buff from gear that holds a PassiveAura
	# runs the map-wide tracking pass itself (unit_condition.gd:712-715 -> :775 -> unit.gd:158-160 ->
	# unit_tile.gd:12,24), so the dome is up the moment the button is pressed. A spec that called
	# track() by hand would pass with that chain broken.
	assert_true(sheltered(sluagh), 'The Sluagh itself is sheltered - "You and...".')
	assert_true(sheltered(ally), 'And so is the adjacent ally, in the same event.')
	assert_eq(cover_against_the_shooter(ally), Lancer.COVER.SOFT,
		'And the engine\'s own cover pipeline reads it as SOFT.')

func test_an_ally_two_tiles_out_is_not_sheltered():
	var far:Unit = SluaghFixture.create_ally(game, TWO_OUT_TILE)
	await SluaghFixture.press_mark(game, sluagh)
	assert_true(sheltered(ally), 'fixture: the adjacent one is.')
	assert_false(sheltered(far), 'Two tiles out is not adjacent, and gets nothing.')
	assert_eq(cover_against_the_shooter(far), Lancer.COVER.NONE, 'It stands in the open.')

func test_an_ally_stepping_adjacent_gains_it_and_stepping_away_loses_it():
	# THE AURA IS DYNAMIC, and this is the only test that says so. PassiveAura.update_unit both
	# APPLIES and CLEARS (passive_aura.gd:55-64), and UnitTile.move_to runs the pass on every step
	# (unit_tile.gd:10-13) - so the dome follows the Sluagh without anything in our content tracking
	# anybody.
	var walker:Unit = SluaghFixture.create_ally(game, TWO_OUT_TILE)
	await SluaghFixture.press_mark(game, sluagh)
	assert_false(sheltered(walker), 'fixture: it starts outside.')

	SluaghFixture.step(walker, ADJACENT_TILE + Vector2i(0, 1))
	assert_true(UnitRelation.is_adjacent(sluagh, walker), 'fixture: now adjacent.')
	assert_true(sheltered(walker), 'Stepping in gains the cover.')

	SluaghFixture.step(walker, TWO_OUT_TILE)
	assert_false(UnitRelation.is_adjacent(sluagh, walker), 'fixture: and out again.')
	assert_false(sheltered(walker), 'And stepping out loses it.')

func test_an_adjacent_enemy_is_not_sheltered():
	var enemy:Unit = SluaghFixture.create_hostile(game, OTHER_ADJACENT_TILE)
	await SluaghFixture.press_mark(game, sluagh)
	assert_true(UnitRelation.is_adjacent(sluagh, enemy), 'fixture: it really is adjacent.')
	assert_false(sheltered(enemy), 'applies_to_enemies is false: the dome shelters its own.')

func test_an_adjacent_allied_drone_is_sheltered_too():
	# applies_only_to_characters is checked by PassiveAura.can_apply_buff_to_unit (passive_aura.gd:73)
	# - and a drone IS a character to the engine (ruling 2026-09-27, mod-wide), so the aura's own
	# explicit `moving_unit.is_character()` clause (passive_mark_cover_aura.gd) now asks the same
	# predicate the flag already does - a redundant restatement, not a narrowing.
	#
	# THE TWO SETUP ASSERTIONS ARE KEPT AS ENGINE FACTS: a drone really is a character and really is
	# not an actor, though the second no longer decides anything here.
	var drone:Unit = SluaghFixture.create_drone(game, OTHER_ADJACENT_TILE)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor - which no longer matters here.')
	await SluaghFixture.press_mark(game, sluagh)
	assert_true(UnitRelation.is_adjacent(sluagh, drone), 'fixture: and it really is adjacent.')
	assert_true(sheltered(drone), 'An adjacent allied DRONE is sheltered too.')
	assert_eq(cover_against_the_shooter(drone), Lancer.COVER.SOFT,
		'And the engine\'s own cover pipeline agrees: soft cover reaches it.')

func test_without_the_mark_nobody_is_sheltered():
	# requires_buff is what gates the whole aura (passive_aura.gd:40-42), and it is why the core
	# power is a button rather than a permanent trait. A tracking pass with no chip must place
	# nothing, which is a different claim from "the chip has not been applied yet".
	SluaghFixture.track(game)
	assert_false(sheltered(sluagh), 'The Sluagh is not sheltered before the press...')
	assert_false(sheltered(ally), '...and neither is the ally.')
	assert_eq(cover_against_the_shooter(ally), Lancer.COVER.NONE, 'Nobody is in cover.')

# ---------------------------------------------------------------- what the cover does

func test_a_hostile_roll_against_the_sheltered_ally_really_is_harder():
	# END TO END, AND IN DAMAGE RATHER THAN IN BUFFS. Soft cover is -1 accuracy
	# (Lancer.cover_modifier, lancer.gd:154) and attack_roll.gd:169 adds it as a real accuracy mod, so
	# the roll pops an accuracy die that an uncovered roll does not. A d20 of 11 beats evasion 10 on
	# its own and loses to it once that die comes up 6 - so the same queue hits an uncovered ally and
	# misses a sheltered one, and the difference is 5 damage against the rifle's Reliable 2.
	#
	# THE CONTROL COMES FIRST, on a second ally standing two out, so both halves run in one test and
	# neither can be green for want of the other.
	var uncovered:Unit = SluaghFixture.create_ally(game, TWO_OUT_TILE)
	await SluaghFixture.press_mark(game, sluagh)
	assert_true(sheltered(ally), 'fixture: one is sheltered...')
	assert_false(sheltered(uncovered), 'fixture: ...and one is not.')

	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_COVER, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, uncovered)
	assert_eq(uncovered.current_damage(), DAMAGE_DIE,
		'CONTROL: 11 beats evasion 10 with no cover in the way, for the full 5.')

	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_COVER, WORST_ACCURACY_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(ally.current_damage(), RELIABLE,
		'The same d20 MISSES the sheltered ally: 11 - 6 is 5. Only the rifle\'s Reliable 2 landed.')

func test_hard_cover_still_wins_over_the_marks_soft_cover():
	# RULING 14's max-then-zero half. CoverResult.add keeps the greater of what it already had and
	# what it is given, at the same source position (cover_calculator.gd:19-24), and every COVER buff
	# is added at the target's own position (:62) - so an ally already in HARD cover keeps hard and
	# the dome adds nothing it did not have.
	#
	# A VANILLA HARD-COVER BUFF RATHER THAN TERRAIN, deliberately: a one-tall block beside a size-1
	# unit is exactly the geometry test_draw_fire.gd measured as unreliable for this purpose, and the
	# claim here is about the cover CHANNEL, not about sightlines.
	SpecFactory.apply_buff(ally, SluaghFixture.HARD_COVER_BUFF)
	assert_eq(cover_against_the_shooter(ally), Lancer.COVER.HARD, 'fixture: it starts in hard cover.')

	await SluaghFixture.press_mark(game, sluagh)
	assert_true(sheltered(ally), 'fixture: and the dome reached it too.')
	assert_eq(cover_against_the_shooter(ally), Lancer.COVER.HARD,
		'Hard cover still wins: the soft chip does not downgrade it.')

func test_the_chip_survives_a_turn_end():
	# "until the end of the scene" - so Lancer.UNTIL.MANUAL, the enum's own zero, which is why the
	# .tres writes no `until` line at all. And the aura survives with it, because requires_buff is
	# re-read on every tracking pass.
	await SluaghFixture.press_mark(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, shooter)
	await SpecFactory.end_turn(game, shooter)
	assert_true(UnitCondition.has_buff(sluagh, SluaghFixture.MARK_CHIP), 'The chip is still up.')
	SluaghFixture.track(game)
	assert_true(sheltered(ally), 'And the ally is still sheltered after two turn ends.')
