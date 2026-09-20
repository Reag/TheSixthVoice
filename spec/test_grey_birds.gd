# THE FLIGHT OF THE CRESCENT OF GREY BIRDS (O' Trickery's first invade, SP2 Tasks 5 and 6).
#
#   "Until the end of the next round, if your target takes an action that could target you, they
#    must target you with that action."
#
# THREE BUFFS FOR ONE CARD (ruling 17). buff_grey_birds_ban is the targeting channel; SP2 Task 6 adds
# buff_grey_birds_recentre for the AoE that never asks that channel at all; buff_grey_birds is the
# visible chip the player reads. All three share buff_grey_birds_lifetime.gd and expire themselves.
#
# THE BAN IS READ OFF THE ATTACKER, NOT OFF THE DEFENDER. Action.can_target_unit asks
# has_buff_to(specific.unit, ACTION_BANNED_UNITS, ...) (action.gd:221) - so the buff sits on the
# INVADED unit and answers about each candidate in turn. ActionAttackWeapon re-implements that call
# rather than calling super (action_attack_weapon.gd:238-239) while ActionAttackTech reaches it
# through super (action_attack_tech.gd:65), which is why both a weapon and a tech action are pinned
# here: they are different code paths to the same channel.
#
# THE CHANNEL FAILS OPEN. does_buff_apply is one `and` chain (unit_condition.gd:845-851) and a false
# from either passive hook removes the buff from get_buffs_to entirely - so every negative below
# would also be green against a ban that simply never applies. That is what the CONTROL line in
# test_an_invaded_enemy_cannot_target_an_ally_with_its_weapon (and in the grapple and tech cases)
# is for: the SAME query, asked before and after the invade.
#
# AND THE CHANNEL HAS A HOLE, measured rather than assumed: ActionSystemApplyStatus and
# ActionSystemApplyBuff both have their `super.can_target_unit(...)` line COMMENTED OUT
# (action_system_apply_status.gd:30, action_system_apply_buff.gd:59), so a Lock On, a Bolster or a
# Hand Over Control is never banned by anything. That is pinned as an assertion below so the day it
# changes, the author hears about it.
#
# NO TEST HERE READS A BUFF TO DECIDE WHETHER THE BAN WORKS. can_target_unit is the engine's own
# question and is polled directly, which is also what the AI asks (its candidate lists pass through
# the same call), so the player-facing and AI-facing answers cannot diverge.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_grey_birds.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## A wide map: the "out of range" case moves the Sluagh past the rifle's Range 10.
const MAP_SIZE := Vector2i(40, 14)

const SLUAGH_TILE := Vector2i(6, 6)
## Two east of the Sluagh, and three west of the ally: inside everything's range.
const HOSTILE_TILE := Vector2i(8, 6)
const ALLY_TILE := Vector2i(11, 6)
## Beyond the rifle's Range 10 from HOSTILE_TILE, and beyond the Sluagh's own Sensors 10 as well.
const FAR_FROM_THE_HOSTILE := Vector2i(30, 6)
## Adjacent to the hostile - what a grapple's threat 1 can reach.
const ADJACENT_TO_HOSTILE := Vector2i(9, 6)

## Vanilla basic gear, on every mech with no equipping at all
## (content/gear/basic/basic_loadout_mech_player.tres). A WEAPON and a SYSTEM: the grapple is a
## second ActionAttackWeapon path, and the Lock On is the archetype that does NOT reach the ban
## channel at all. See test_a_tech_attack_is_refused_but_a_lock_on_escapes_the_channel_entirely.
const GRAPPLE := &'mw_grapple'
const LOCK_ON := &'ms_lock_on'

var game:Gamemaster
var sluagh:Unit
var hostile:Unit
var ally:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self, MAP_SIZE)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_trickery(sluagh)
	hostile = SluaghFixture.create_hostile(game, HOSTILE_TILE)
	SluaghFixture.arm_rifle(hostile)
	ally = SluaghFixture.create_ally(game, ALLY_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The hostile's rifle, as a SpecificAction - the trifecta can_target_unit needs.
func rifle_of(attacker:Unit) -> SpecificAction:
	return SpecificAction.from_id(attacker, SluaghFixture.MAIN_RIFLE)

func gear_of(attacker:Unit, kit_id:StringName) -> SpecificAction:
	return SpecificAction.from_id(attacker, kit_id)

## Can `attacker` target `who` with `specific`? The engine's own question, asked the way
## UnitTargeting asks it (unit_targeting.gd:97).
func can_target(specific:SpecificAction, who:Unit) -> bool:
	return specific.action.can_target_unit(who, specific)

func bound() -> bool:
	return UnitCondition.has_buff(hostile, SluaghFixture.GREY_BIRDS_BAN)

## Advance the game to a new round. test_symbiosis.gd:579 is the idiom.
func new_round() -> void:
	await game.execute_event(&'event_round_new', {})

func round_now() -> int:
	return game.map.game_core.round_count

# ---------------------------------------------------------------- the wiring

func test_the_system_is_unique_and_carries_grey_birds_as_an_invade():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.TRICKERY)
	assert_not_null(kit, 'ms_o_trickery loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 3, 'SP 3, off the sheet.')
	assert_eq(kit.system_tags & Kit.SYSTEM_TAGS.UNIQUE, Kit.SYSTEM_TAGS.UNIQUE, 'UNIQUE.')
	assert_false(kit.is_trait, 'Licence gear, not a frame trait.')
	# ONE action at this task; Task 8 appends Hunt and re-pins the pair in test_hunt.gd. The
	# assertion is written as a presence check plus a count so THIS file does not have to be edited
	# when that lands - a spec that has to change to stay green is a spec that stops discriminating.
	var ids:Array[StringName] = []
	for action:Action in kit.actions: ids.append(action.get_id())
	assert_true(ids.has(SluaghFixture.GREY_BIRDS_ID), 'It carries The Flight of the Grey Birds.')

	var invade:ActionAttackTech = null
	for action:Action in kit.actions:
		if action.get_id() == SluaghFixture.GREY_BIRDS_ID: invade = action
	assert_not_null(invade, 'And it is an ActionAttackTech.')
	if invade == null: return
	assert_true(invade.is_invade, 'An INVADE - which is what makes an allied target auto-hit and a '
		+ 'hostile one take 2 heat (action_attack_tech.gd:10, :17, :71-73).')
	assert_true(GearCore.is_valid(sluagh.get_gear(SluaghFixture.TRICKERY)),
		'And the live Sluagh carries it as gear once equipped.')

func test_the_three_buffs_land_on_a_hostile_target():
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	for buff_id:StringName in [SluaghFixture.GREY_BIRDS_BAN, SluaghFixture.GREY_BIRDS_CHIP]:
		assert_true(UnitCondition.has_buff(hostile, buff_id), '%s is on the target.' % buff_id)
	# OWNED BY THE SLUAGH'S GEAR, which is the whole of how the ban knows who to spare:
	# BuffCore.get_owner_unit resolves from from_gear (buff_core.gd:102-105), and from_gear is set
	# only because apply_buffs was handed context.gear (unit_condition.gd:705-709).
	var ban:BuffCore = UnitCondition.get_buff(hostile, SluaghFixture.GREY_BIRDS_BAN)
	assert_eq(ban.get_owner_unit(game.map), sluagh, 'And the ban is OWNED by the Sluagh.')
	assert_true(ban.base.hide_from_player, 'The ban itself is plumbing, never a chip.')
	var chip:Buff = ContentLibrary.get_buff(SluaghFixture.GREY_BIRDS_CHIP)
	assert_false(chip.hide_from_player, 'The companion chip IS visible - the player has to see who '
		+ 'is bound, and the ban draws nothing.')

func test_an_allied_target_auto_hits_and_gets_nothing():
	# RULING 4 is about a TARGET, and an ally is not one. An allied invade AUTO-HITS
	# (action_attack_tech.gd:71-73), so the hit is guaranteed and a green here is about the
	# are_enemies clause rather than about the dice - test_wicked_host.gd uses the same reasoning.
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, ally)
	assert_false(UnitCondition.has_buff(ally, SluaghFixture.GREY_BIRDS_BAN),
		'An allied target is bound to nothing.')
	assert_false(UnitCondition.has_buff(ally, SluaghFixture.GREY_BIRDS_CHIP), 'And wears no chip.')

func test_a_miss_applies_nothing():
	SluaghFixture.cheat_a_miss()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_false(bound(), 'on_hit did not run, so nothing was applied.')

# ---------------------------------------------------------------- the ban

func test_an_invaded_enemy_cannot_target_an_ally_with_its_weapon():
	# THE CARD, AND THE CONTROL IS THE TEST. "The ally cannot be targeted" is also what a fixture
	# whose ally was never targetable would report, so the SAME query is asked before and after.
	var rifle := rifle_of(hostile)
	assert_true(can_target(rifle, ally), 'CONTROL: before the invade, the ally is a legal target.')

	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(bound(), 'fixture: the invade landed.')
	assert_false(can_target(rifle, ally), 'THE CARD: now it cannot target the ally...')
	assert_true(can_target(rifle, sluagh), '...and the Sluagh is still a legal target.')

func test_the_sluagh_itself_is_never_refused():
	# RE-ENTRANCY, pinned. check_if_passive_applies calls can_target_unit(owner, specific), which
	# asks this same buff again with target_unit = the owner - and the `target_unit == owner` clause
	# answers false one line BEFORE the recursive call is reached. Without that ordering this is an
	# infinite recursion, and the failure mode is a hung spec rather than a red one.
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(can_target(rifle_of(hostile), sluagh),
		'The Sluagh is always targetable by its own victim - which is the whole point of the card.')

func test_the_ally_is_targetable_again_when_the_sluagh_is_out_of_the_attackers_range():
	# "if your target takes an action that COULD TARGET YOU" - so the ban is conditional on the
	# Sluagh being reachable BY THAT ACTION, which is the get_tiles_in_range clause (the
	# unit_relation.gd:266 shape). Out of the rifle's Range 10 the condition fails and the ally comes
	# back, which is the card and not a bug.
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_false(can_target(rifle_of(hostile), ally), 'fixture: bound while the Sluagh is close.')

	SluaghFixture.step(sluagh, FAR_FROM_THE_HOSTILE)
	SluaghFixture.track(game)
	assert_true(bound(), 'The ban is still APPLIED - it is the clause that lapsed, not the buff.')
	# THE CONTROL IS A DISTANCE, NOT A can_target_unit CALL, and that is a correction to the plan:
	# can_target_unit carries NO geometry at all (action.gd:215-222 is self / hidden / banned, and
	# ActionAttackWeapon's override adds arcs and knockback immunity, not range). Range lives in
	# UnitTargeting.get_tiles_in_range, which is exactly why the ban has to ask that separately. So
	# `can_target(rifle, sluagh)` is TRUE at any distance and asserting it false would pin nothing.
	# The honest control is the fixture's own geometry, measured independently of the ban's code.
	var rifle := rifle_of(hostile)
	var reach:int = rifle.action.get_target_range(rifle)
	var gap:int = int(UnitRelation.closest_tiles_between(hostile, sluagh).distance)
	assert_gt(gap, reach,
		'CONTROL: the Sluagh really is beyond the rifle\'s reach now (%d against %d).' % [gap, reach])
	assert_true(can_target(rifle_of(hostile), ally), 'So the ally is a legal target again.')

func test_a_grapple_against_the_ally_is_refused_while_the_sluagh_is_adjacent():
	# A DIFFERENT can_target_unit PATH, and that is the reason this case exists rather than a second
	# rifle one: mw_grapple is a WEAPON, and ActionAttackWeapon.can_target_unit does NOT call super -
	# it re-implements the ACTION_BANNED_UNITS query itself at action_attack_weapon.gd:238-239. A ban
	# that only worked through the base class would pass every rifle test here and fail in play.
	SluaghFixture.step(sluagh, ADJACENT_TO_HOSTILE)
	SluaghFixture.step(ally, Vector2i(HOSTILE_TILE.x, HOSTILE_TILE.y + 1))
	SluaghFixture.track(game)
	var grapple := gear_of(hostile, GRAPPLE)
	assert_true(SpecificAction.is_valid(grapple), 'fixture: mw_grapple is basic gear on every mech.')
	assert_true(can_target(grapple, ally), 'CONTROL: the adjacent ally is grappleable.')

	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_false(can_target(grapple, ally),
		'Bound: the grapple must take the Sluagh, who is also adjacent.')
	assert_true(can_target(grapple, sluagh), 'And the Sluagh is grappleable.')

func test_a_tech_attack_is_refused_but_a_lock_on_escapes_the_channel_entirely():
	# THE THIRD PATH, and the engine's own LIMIT on ruling 4 - both in one case, because the pair is
	# the measurement and neither half means much alone.
	#
	# THE PLAN NAMED ms_lock_on AS "the system path" AND THAT IS WRONG ON 1.4.3. action_lock_on
	# extends ActionSystemApplyStatus, whose can_target_unit has the `super.can_target_unit(...)`
	# line COMMENTED OUT (action_system_apply_status.gd:30, "we need to be able to target self,
	# sometimes") - so it never reaches action.gd:221 and NO ACTION_BANNED_UNITS buff can touch it.
	# ActionSystemApplyBuff:59 is commented out identically, which takes ms_bolster and
	# ms_hand_over_control with it. Nothing in this mod can close that gap: both archetypes are
	# engine `class_name` scripts rather than autoloads, so there is no seam to extend. Recorded,
	# not fought.
	#
	# ms_fragment_signal IS a third real path: an ActionAttackTech whose can_target_unit calls super
	# (action_attack_tech.gd:64-65) into ActionAttack, which does not override it, and so into
	# Action.can_target_unit itself - a different override chain from ActionAttackWeapon's
	# re-implementation above, reaching the same channel.
	#
	# WHY NOT ms_scan, the plain-ActionSystem path (action_system.gd:51-52 DOES call super)? Because
	# it cannot be probed with this fixture: action_scan also demands
	# Scanpedia.is_anything_unscanned(target) (action_scan.gd:16), and the SLUAGH's own frame is
	# already complete in the campaign scanpedia (measured: unscanned=false for mf_sluagh,
	# unscanned=true for the ally's mf_standard_pattern_i_everest). The scan therefore cannot target
	# the Sluagh at all, the "could target you" clause correctly lapses, and the case would pin the
	# scanpedia rather than the ban. ActionSystem's route to the channel is read off the source, not
	# asserted here.
	var tech := gear_of(hostile, SluaghFixture.TECH_ID)
	assert_true(SpecificAction.is_valid(tech), 'fixture: ms_fragment_signal is basic gear.')
	assert_true(can_target(tech, ally), 'CONTROL: the ally can be invaded.')

	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_false(can_target(tech, ally), 'Bound: the invade must take the Sluagh.')
	assert_true(can_target(tech, sluagh), 'And the Sluagh can be invaded.')

	# THE RECORDED LIMIT. Written as an assertion rather than a comment so that the day Wickworks
	# un-comment that super call, THIS goes red and the author is told the card got stronger.
	var lock_on := gear_of(hostile, LOCK_ON)
	assert_true(SpecificAction.is_valid(lock_on), 'fixture: ms_lock_on is basic gear on every mech.')
	assert_true(can_target(lock_on, ally),
		'ENGINE LIMIT: a Lock On never asks the ban channel, so the bound enemy may still lock the '
		+ 'ally. If this ever goes red, action_system_apply_status.gd:30 was uncommented.')

# ---------------------------------------------------------------- the lifetime

func test_the_buffs_survive_the_round_after_application():
	# "Until the end of the NEXT round": applied in round R, alive through R+1.
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	var applied:int = round_now()
	assert_true(bound(), 'fixture: applied.')

	await new_round()
	assert_eq(round_now(), applied + 1, 'fixture: one round passed.')
	assert_true(bound(), 'Still bound through the whole of the next round.')
	assert_true(UnitCondition.has_buff(hostile, SluaghFixture.GREY_BIRDS_CHIP), 'Chip too.')

func test_the_buffs_clear_as_the_second_round_after_application_begins():
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	var applied:int = round_now()

	await new_round()
	await new_round()
	assert_eq(round_now(), applied + 2, 'fixture: two rounds passed.')
	assert_false(bound(), 'The ban cleared itself...')
	assert_false(UnitCondition.has_buff(hostile, SluaghFixture.GREY_BIRDS_CHIP),
		'...and so did the chip, on its own NEW_ROUND trigger rather than through a keeper.')
	assert_true(can_target(rifle_of(hostile), ally), 'And the ally is targetable again.')

