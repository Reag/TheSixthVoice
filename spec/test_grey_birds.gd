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
## SIX east of the hostile and five east of a Sluagh standing at ADJACENT_TO_HOSTILE - far enough
## that an RPG's Blast 2 centred here does not already cover the Sluagh, which would make the
## recentre a no-op at buff_grey_birds_recentre.gd:75 instead of a refusal at :166.
const ALLY_CLEAR_OF_A_BLAST_TWO := Vector2i(14, 6)
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
	# ALL THREE, which the name has claimed since Task 5 and only now can be asked: the recentre is
	# created in Task 6, and until it existed action_grey_birds logged an X.error and applied two.
	for buff_id:StringName in [
		SluaghFixture.GREY_BIRDS_BAN, SluaghFixture.GREY_BIRDS_RECENTRE, SluaghFixture.GREY_BIRDS_CHIP
	]:
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
	# Scanpedia.is_anything_unscanned(target) (action_scan.gd:17), and the SLUAGH's own frame is
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
	# THE THIRD LIFETIME, added in Task 6 and the only thing in the suite that can see it. The
	# recentre is hidden and draws nothing, so without this assertion a recentre that outlived the
	# other two would be invisible - which is exactly the half-expired set three independent
	# lifetimes exist to make impossible. Task 6's mutations 3 and 4 both land here.
	assert_false(UnitCondition.has_buff(hostile, SluaghFixture.GREY_BIRDS_RECENTRE),
		'...and so did the AoE recentre, which nothing else in this file would notice.')
	assert_true(can_target(rifle_of(hostile), ally), 'And the ally is targetable again.')

# ================================================================================================
# THE AoE RECENTRE (SP2 Task 6). Everything above is the ban, which a tile-targeted AoE never asks.
# ================================================================================================

## THE THREE VANILLA SHAPES, EACH MEASURED OFF ITS OWN .tres RATHER THAN OFF THE PLAN, which named
## mw_thermal_pistol as the Burst and is wrong: its range_pattern is `pattern = 2` (LINE), value 5
## (content/gear/gms/weapons/mw_thermal_pistol.tres). test_draw_fire.gd:94 says the same in prose.
## The vanilla Burst that suite uses is the Bristlecrown, and that is what is used here.
##
## Blast 1, Range 15, Arcing, Inaccurate, 1d6+1 explosive. `pattern = 1` (BLAST). Its weapon_type is
## 1 = CANNON, NOT a launcher, so the "ordnance cannot hit adjacent" clause
## (action_attack_weapon.gd:232-237) is doubly irrelevant here - it also needs BOTH units ENGAGED.
const MORTAR := &'mw_mortar'
## Line 10 heavy cannon, 1d6+3 energy, self-heat 2. `pattern = 2` (LINE), value 10.
const THERMAL_LANCE := &'mw_thermal_lance'
## IPS-N Burst 1 aux CQB, 1 kinetic, aim_range 1, threat 0. `pattern = 4` (BURST), value 1.
const BRISTLECROWN := &'mw_bristlecrown_flechette_launcher'
## Blast 2, Range 10, LOADING + ORDNANCE, 1d6+1 explosive. `pattern = 1` (BLAST), value 2
## (content/gear/gms/weapons/mw_rocket_propelled_grenade.tres). THE ONLY VANILLA WEAPON SHAPE THAT
## CAN REACH THE RECENTRE'S `new_units.has(owner)` REFUSAL - see
## test_an_ordnance_blast_is_not_dragged_onto_an_engaged_sluagh. LOADING is harmless here:
## GearCore.is_loaded defaults to TRUE (gear_core.gd:12) and only a use clears it, so the first shot
## always fires.
const RPG := &'mw_rocket_propelled_grenade'

## Records the FINAL target set of every declared attack. ATTACK_DECLARED / POST, so it reads the
## summary AFTER any PRE rewrite - which is the thing under test. A reaction that never fires: it
## reads the triggering context and returns false, so it costs no reaction point and opens no
## prompt. test_draw_fire.gd's TerrainRecorder is the shape.
class DeclarationRecorder extends ActionReaction:
	var declared:Array[Array] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.resource]

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		var summary:DeclaredAttackSummary = triggering_event.context.resource
		if DeclaredAttackSummary.is_valid(summary):
			declared.append(summary.all_attacked_units.duplicate())
		return false

var recorder:DeclarationRecorder

## Hang the recorder on a unit through a throwaway trait Kit. test_draw_fire.gd:242-250, verbatim.
func install_recorder(on:Unit) -> void:
	recorder = DeclarationRecorder.new()
	var kit := Kit.new()
	kit.compcon_id = &'grey_birds_spec_recorder_kit'
	kit.is_trait = true
	kit.actions.append(recorder)
	on.core.loadout.equipped_kits.append(kit)
	on.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

## Fire a weapon at a TILE - a Blast aims at ground, a Line or Cone along a ray - and hand back the
## summary the attack resolved through. Built by hand rather than through game.execute_event because
## the summary lives on the activation event's OWN context, which execute_event does not return
## (test_draw_fire.gd:296-305).
##
## THE TAIL IS 1s, NOT test_draw_fire's 6s, and it is this frame that decides it: the Sluagh has 8 HP
## and 0 armor, and ms_brace raises its own yes/no once incoming damage clears half the health max
## (action_brace.gd:44-51) - above 4 here. A cheated tail of sixes would put a mortar's 1d6+1 at 7 and
## open a prompt the stock responder would have to answer. SluaghFixture.queue's header records the
## same reasoning for the same reason.
func fire_at_tile(shooter:Unit, weapon:GearCore, tile:Vector2i, d20:int) -> DeclaredAttackSummary:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(1)
	Dice.cheat_attack([d20], buffer)
	var tiles:Array[Vector2i] = [tile]
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	return weapon

func test_a_blast_declared_on_the_ally_lands_centred_on_the_sluagh():
	# THE HALF THE BAN CANNOT REACH. A tile-targeted AoE never calls can_target_unit on the tiles it
	# aims at, so ACTION_BANNED_UNITS is never asked and the ally is hit through the ban. The recentre
	# rewrites the declared summary in place at ATTACK_DECLARED PRE, before execute() reads
	# directly_attacked_tiles (event_unit_attack_declared.gd:35-36) or duplicates all_attacked_units
	# for the per-target rolls (:54).
	var mortar := arm(hostile, MORTAR)
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(bound(), 'fixture: the invade landed.')

	var summary:DeclaredAttackSummary = await fire_at_tile(hostile, mortar, ALLY_TILE, 19)
	assert_not_null(summary, 'fixture: the shot resolved and produced a summary.')
	if summary == null: return
	assert_true(summary.directly_attacked_tiles.has(sluagh.tile()),
		'THE CARD: the blast is re-aimed onto the Sluagh...')
	assert_eq(summary.directly_attacked_tiles.size(), 1,
		'...and onto ONE tile - every direct target collapses to the aim tile, deduped.')
	assert_true(summary.all_attacked_units.has(sluagh), 'The Sluagh is in the rebuilt area.')

func test_a_burst_is_refused_and_the_attack_is_left_alone():
	# RULING 17's own exception, and the engine's reason for it: a BURST is centred on the ACTOR -
	# RangePattern.get_aoe_tiles takes occupied_tiles[0] and ignores target_tiles entirely
	# (range_pattern.gd:45-46) - so there is nothing to re-aim. Refused outright rather than
	# half-applied.
	#
	# THE ALLY IS WALKED IN ADJACENT, because the Bristlecrown is Burst 1 and its area is drawn round
	# the HOSTILE: at ALLY_TILE the ally is three tiles out and nothing would be declared at all, so
	# "the attack still happened" would be vacuous. test_draw_fire.gd:578-583 stands its brawler
	# adjacent for exactly this.
	#
	# AND THE BAN IS DORMANT HERE, measured rather than incidental: the Bristlecrown's aim_range is 1
	# and the Sluagh is two tiles away, so owner_is_a_legal_target's get_tiles_in_range clause is
	# false and the ban never applies - which is what leaves the ally inside the declared area
	# (action_attack.gd:172 filters all_attacked_units through can_target_unit at DECLARE time). This
	# test is about the RECENTRE refusing a Burst; the ban has its own eight cases above.
	SluaghFixture.step(ally, ADJACENT_TO_HOSTILE)
	SluaghFixture.track(game)
	var burst := arm(hostile, BRISTLECROWN)
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)

	var before := ally.current_damage()
	var summary:DeclaredAttackSummary = await fire_at_tile(hostile, burst, ADJACENT_TO_HOSTILE, 19)
	if summary == null: return
	assert_false(summary.directly_attacked_tiles.has(sluagh.tile()),
		'A Burst is not re-aimed, whatever it catches.')
	assert_gt(ally.current_damage(), before, 'And the attack it did declare still happened.')

func test_a_line_that_cannot_reach_the_sluagh_is_left_alone():
	# RULING 17: a Line or Cone whose rebuilt area would not contain the owner is refused by the same
	# `new_units.has(owner)` check that lets a reachable one through - the rebuild is the gate, run
	# DRY in triggers_on_event and LIVE in activate.
	#
	# THE INVADE COMES FIRST AND THE WALK SECOND, which is a correction to the plan's own ordering:
	# at FAR_FROM_THE_HOSTILE the Sluagh is 22 tiles from its victim and the invade would be pressed
	# from out of range. test_the_ally_is_targetable_again_when_the_sluagh_is_out_of_the_attackers_
	# range does it in this order for the same reason.
	var line := arm(hostile, THERMAL_LANCE)
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	SluaghFixture.step(sluagh, FAR_FROM_THE_HOSTILE)
	SluaghFixture.track(game)

	var summary:DeclaredAttackSummary = await fire_at_tile(hostile, line, ALLY_TILE, 19)
	if summary == null: return
	# ASSERTED ON THE AIM TILE, not only on the unit list, and that is a correction to the plan: the
	# rebuilt Line 10 east contains the ally and NOT the Sluagh either way, so
	# `all_attacked_units.has(sluagh)` is false whether the reach check refuses the rewrite or waves
	# it through - it would stay green under this task's own mutation 2. directly_attacked_tiles is
	# what actually moves: [ALLY_TILE] when refused, [FAR_FROM_THE_HOSTILE] when not.
	assert_true(summary.directly_attacked_tiles.has(ALLY_TILE),
		'The Sluagh is out of reach, so the Line keeps the aim the attacker gave it.')
	assert_false(summary.directly_attacked_tiles.has(sluagh.tile()),
		'And is not dragged onto the Sluagh.')
	assert_false(summary.all_attacked_units.has(sluagh), 'The Sluagh is not in the area either.')

func test_a_blast_is_left_alone_when_the_sluagh_is_beyond_the_weapons_range():
	# RULING 17's OTHER HALF, and the gap the controller found in the first cut of this file: "a
	# rebuild centred on the owner is legal BY THE ATTACKER'S OWN TARGETING" is a question about
	# RANGE as much as about the unit refilter, and can_target_unit carries no geometry at all
	# (Task 5 departure 2 measured that: action.gd:215-222 is self / hidden / banned, and
	# ActionAttackWeapon's override adds arcs and knockback immunity).
	#
	# THE BLAST IS WHY THIS NEEDS ITS OWN CASE AND THE LINE ONE DOES NOT COVER IT. A Line's reach is
	# its own pattern, so a Sluagh past it drops out of the rebuilt area and `new_units.has(owner)`
	# refuses the rewrite. A BLAST re-centres wherever it is aimed and always contains its own
	# centre, so that check can never refuse one however far away the aim tile is - and the engine
	# never re-checks range against a rewritten target (action_draw_fire.gd's own header records it).
	# Without an explicit range clause the mortar's Blast 1 is dragged 22 tiles onto a Sluagh its
	# aim_range 15 could not have been pointed at by any player.
	var mortar := arm(hostile, MORTAR)
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	SluaghFixture.step(sluagh, FAR_FROM_THE_HOSTILE)
	SluaghFixture.track(game)
	# THE PRECONDITION, measured rather than assumed, so this cannot pass because the geometry drifted:
	# 22 against the mortar's 15.
	var specific := SpecificAction.from_id(hostile, MORTAR)
	var reach:int = specific.action.get_target_range(specific)
	var gap:int = int(UnitRelation.closest_tiles_between(hostile, sluagh).distance)
	assert_gt(gap, reach,
		'fixture: the Sluagh is beyond the mortar\'s reach (%d against %d).' % [gap, reach])

	var summary:DeclaredAttackSummary = await fire_at_tile(hostile, mortar, ALLY_TILE, 19)
	if summary == null: return
	assert_true(summary.directly_attacked_tiles.has(ALLY_TILE),
		'THE CARD STOPS AT THE WEAPON: the blast keeps the aim the attacker gave it...')
	assert_false(summary.directly_attacked_tiles.has(sluagh.tile()),
		'...and is not dragged onto a Sluagh the mortar cannot reach.')
	assert_false(summary.all_attacked_units.has(sluagh), 'The Sluagh is not in the area either.')

func test_an_ordnance_blast_is_not_dragged_onto_an_engaged_sluagh():
	# THE `new_units.has(owner)` REFUSAL (buff_grey_birds_recentre.gd:166), AND THE ONLY CASE IN THE
	# SUITE THAT REACHES IT. Added at the frame close (2026-09-21) for a coverage regression nobody
	# re-measured: step 0 - the attacker's own range and LOS to the aim tile, added at :133 as a
	# follow-up to Task 6 - now refuses all three of this file's older recentre NEGATIVES before any
	# later clause is consulted, so Task 6's mutations 1 and 2b stopped discriminating.
	# MEASURED, NOT ASSUMED: neutralising :166 to `if false: return false` left this file 19/19
	# green, and so did neutralising the BURST refusal at :150.
	#
	# A HIDDEN SLUAGH WOULD NOT WORK, and that is worth recording because it is the obvious idea:
	# ActionAttackWeapon.can_target_unit puts its hidden check INSIDE `if not range_pattern`
	# (action_attack_weapon.gd:226-229), under a comment that says so outright - "we can target
	# hidden guys just fine with AOE". So Action.can_target_unit:219 is never reached for an AoE
	# weapon and hiding changes nothing about the refilter. Measured on 2026-09-21: a hidden Sluagh
	# ten tiles out was dragged onto by a mortar exactly as an unhidden one is.
	#
	# WHAT DOES WORK IS THE ORDNANCE CLAUSE, the one other geometry-free refusal that override adds
	# (:232-237): an ORDNANCE weapon cannot target a unit that is engaging its wielder. Every leg of
	# that is arranged here - the RPG carries the tag, the Sluagh is stood adjacent so both ends are
	# ENGAGED, and get_engaging_units(hostile) then holds the Sluagh. A BLAST always contains the
	# tile it is centred on, so unlike the Thermal Lance case the pattern itself cannot drop the
	# owner; the refilter at :162 is the only thing that can, and :166 is the only clause left to act
	# on it.
	#
	# AND IT IS A CARD READING, NOT ONLY A CODE PATH: the recentre never re-aims an attack onto a
	# unit the attacker could not legally have aimed at. Draw Fire's own copy of the clause names the
	# same family of case (action_draw_fire.gd:402-403). No ruling says it out loud; this is where
	# the frame records it.
	#
	# THE BAN LAPSES FOR THIS WEAPON AND ONLY THIS WEAPON, and that is asserted both ways rather than
	# left implicit. owner_is_a_legal_target asks whichever action is in the context the identical
	# can_target_unit question, so the RPG - refused by its own ordnance clause - is unbanned, while
	# the hostile's RIFLE, which can see the adjacent Sluagh perfectly well, is still bound. Measured
	# 2026-09-21; the first draft of this case asserted the rifle and went red for that reason. It
	# matters because without the RPG half, "the blast stayed on the ally" could just as well be the
	# ban having stripped the ally out of the declared area instead (action_attack.gd:172).
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(bound(), 'fixture: the invade landed.')

	var rpg := arm(hostile, RPG)
	SluaghFixture.step(sluagh, ADJACENT_TO_HOSTILE)
	SluaghFixture.step(ally, ALLY_CLEAR_OF_A_BLAST_TWO)
	SluaghFixture.track(game)
	# THE ORDNANCE PHASE, BY HAND - vanilla's own spec idiom (test/gear/test_mw_railgun.gd:16-19).
	# UnitAction.get_gear_unavailable_reason refuses any ordnance outside it (:146,
	# REASON.ORDNANCE), and event_turn_start sets the flag only for the STARTING unit (:83) - which
	# here is the SLUAGH, because the invade opened its turn and nobody has opened the hostile's.
	# Without this line fire_at_tile aborts at event_gear_activate, the summary comes back NULL and
	# the case returns early having asserted only its fixture: measured 2026-09-21, and it is exactly
	# the silent-abort trap the fixture's own headers warn about.
	hostile.state.is_firing_ordnance = true
	var specific := SpecificAction.from_id(hostile, RPG)
	assert_true(UnitAction.is_ordnance(specific), 'fixture: the RPG really is ORDNANCE.')
	assert_true(UnitAction.is_gear_available(specific),
		'fixture: and it really can be fired, so a null summary cannot hide this case.')
	assert_true(hostile.has_status(Lancer.STATUS.ENGAGED), 'fixture: the attacker is engaged...')
	assert_true(sluagh.has_status(Lancer.STATUS.ENGAGED), '...by the Sluagh, which is engaged too...')
	assert_true(UnitRelation.get_engaging_units(hostile).has(sluagh),
		'...and it is the Sluagh doing the engaging, which is the clause\'s last leg.')
	# STEP 0 IS NOT WHAT REFUSES THIS ONE, measured rather than assumed - which is the entire point
	# of the case, and the thing the three older negatives cannot say.
	assert_true(UnitTargeting.get_tiles_in_range(specific).has(sluagh.tile()),
		'AND THE SLUAGH\'S TILE IS IN THE RPG\'S RANGE, so step 0 passes and :166 is what acts.')
	assert_false(specific.action.can_target_unit(sluagh, specific),
		'But the ordnance clause refuses the Sluagh, so the refilter drops it out of the rebuild.')
	assert_true(specific.action.can_target_unit(ally, specific),
		'fixture: the BAN lapses for THIS weapon by the same clause, so the ally stays in the '
		+ 'declared area rather than being filtered out of it.')
	assert_false(can_target(rifle_of(hostile), ally),
		'...while the hostile\'s RIFLE is still bound, because the ordnance clause is per-ACTION: '
		+ 'that is how the ban and the recentre can disagree about one Sluagh on one board.')

	var summary:DeclaredAttackSummary = await fire_at_tile(hostile, rpg, ALLY_CLEAR_OF_A_BLAST_TWO, 19)
	assert_not_null(summary, 'fixture: the shot resolved and produced a summary.')
	if summary == null: return
	assert_true(summary.directly_attacked_tiles.has(ALLY_CLEAR_OF_A_BLAST_TWO),
		'THE CARD STOPS AT THE ATTACKER\'S OWN TARGETING: the blast keeps the aim it was given...')
	assert_false(summary.directly_attacked_tiles.has(sluagh.tile()),
		'...it is not re-aimed onto a unit this weapon could not legally have been pointed at...')
	assert_false(summary.all_attacked_units.has(sluagh), '...and the Sluagh is not in the area.')

func test_a_biological_ally_escapes_the_ban_entirely():
	# THE SECOND ENGINE-IMPOSED EXCEPTION TO RULING 4, of the same family as the Lock On escape above
	# and recorded the same way: as a PAIR of assertions on one board, so the day the engine closes
	# the hole the positive half reddens and the day the ban itself breaks the negative half does.
	#
	# WHY IT HAPPENS. The ban buff is owned by a TECH gear - both of O' Trickery's actions are
	# ActionAttackTech, which is what makes UnitAction.is_tech true for the Kit (unit_action.gd:567-571)
	# - so Buff.check_if_prohibited drops it out of get_buffs_to whenever the CANDIDATE is tech-immune
	# (buff.gd:234, :238, reached from the end of does_buff_apply at unit_condition.gd:845-851). And
	# UnitCondition.is_immune_to_tech is `frame.is_biological or has_buff_to(TECH_IMMUNITY)`
	# (:532-533), so this is not only the Iceout drone: ANY biological unit is outside the ban and a
	# bound enemy may shoot it freely. The card says nothing of the kind.
	#
	# NOT FIXABLE IN-MOD, which is why this is a pin rather than a fix: check_if_prohibited is a
	# static on an engine `class_name` script (no extension seam), and dropping context.gear from
	# apply_buffs to dodge it would break BuffCore.get_owner_unit (buff_core.gd:102-105), which the
	# whole ban is built on.
	#
	# SECOND CONSEQUENCE, RECORDED HERE RATHER THAN PINNED: reaction_bus.gd:138 ANDs the same
	# check_if_prohibited, and event_round_new's context carries only `map`, so it is the HOLDER test
	# at buff.gd:236 that is live there - a bound unit that GAINS tech immunity after being bound
	# never fires its NEW_ROUND expiry and wears the (inert) ban and its visible chip for the rest of
	# the scene. Asking that needs a tech-immunity source this mod does not ship.
	#
	# is_biological IS SET THE WAY THE FIXTURE SETS is_drone (sluagh_fixture.gd:147): create_ally goes
	# through FrameIsolation.isolate_frame, which deep-duplicates the Frame and its Statblock, so this
	# write cannot reach the shared ContentLibrary copy.
	var bio_ally:Unit = SluaghFixture.create_ally(game, Vector2i(ALLY_TILE.x, ALLY_TILE.y + 1))
	bio_ally.core.frame.is_biological = true
	bio_ally.core.full_repair()
	SluaghFixture.track(game)
	assert_true(UnitCondition.is_immune_to_tech(bio_ally),
		'fixture: a biological frame is tech-immune, and that is the whole mechanism.')
	assert_false(UnitCondition.is_immune_to_tech(ally), 'fixture: the ordinary ally is not.')
	var rifle := rifle_of(hostile)
	assert_true(can_target(rifle, ally), 'CONTROL: before the invade, both allies are legal targets.')
	assert_true(can_target(rifle, bio_ally), 'CONTROL: including the biological one.')

	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(bound(), 'fixture: the invade landed.')
	assert_false(can_target(rifle, ally), 'THE CARD: the ordinary ally is banned...')
	assert_true(can_target(rifle, bio_ally),
		'ENGINE LIMIT: ...and the BIOLOGICAL one is not. A tech-owned buff is prohibited outright '
		+ 'against a tech-immune candidate, so this ally is outside the card. If this ever goes red, '
		+ 'buff.gd:238 changed and ruling 4 got stronger.')

func test_without_the_ban_the_hostile_can_target_the_ally():
	# THE CONTROL FOR THE AI CASE BELOW, and it is what makes that one mean anything: an AI that
	# would have shot the Sluagh anyway proves nothing. This is the same board, unbound.
	assert_true(can_target(rifle_of(hostile), ally),
		'Unbound, the ally is a legal target for the hostile.')
	assert_true(can_target(rifle_of(hostile), sluagh), 'And so is the Sluagh.')

func test_the_ai_declares_its_shot_at_the_sluagh():
	# THE POINT OF THE WHOLE MECHANISM: the AI's candidate lists pass through can_target_unit, so the
	# ban steers an opponent rather than only answering a query. Asserted on what was DECLARED, plus
	# a shot really happening - "the ally is untouched" alone would be green for an AI that did
	# nothing at all.
	install_recorder(sluagh)
	SluaghFixture.cheat_a_hit()
	await SluaghFixture.grey_birds(game, sluagh, hostile)
	assert_true(bound(), 'fixture: bound.')
	assert_false(can_target(rifle_of(hostile), ally), 'fixture: and the ally is refused.')

	var before_sluagh := sluagh.current_damage()
	var before_ally := ally.current_damage()
	SluaghFixture.queue([19])
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.execute_ai_action(game, hostile)

	assert_false(recorder.declared.is_empty(), 'The AI declared an attack at all.')
	if recorder.declared.is_empty(): return
	assert_true(recorder.declared.back().has(sluagh), 'And it declared it AT THE SLUAGH.')
	assert_gt(sluagh.current_damage(), before_sluagh, 'A shot really landed on the Sluagh...')
	assert_eq(ally.current_damage(), before_ally, '...and none on the ally.')

# ---------------------------------------------------------------- the card and the licence

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in [
		'gear.ms_o_trickery.name', 'gear.ms_o_trickery.flavor',
		'gear.ms_o_trickery.action_grey_birds.name', 'gear.ms_o_trickery.action_grey_birds.effect',
	]:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.ms_o_trickery.name'), "O' Trickery", 'The card\'s own name.')
	assert_eq(X.tr('gear.ms_o_trickery.action_grey_birds.effect'),
		'Until the end of the next round, if your target takes an action that could target you, '
		+ 'they must target you with that action.',
		'And the invade\'s effect row is the LCP\'s sentence, entire and unpiped.')
	# THE CHIP INVENTS NOTHING: it has no rows of its own and wears the action's through
	# localization_key_override (buff_grey_birds.tres). This asserts BOTH halves - the absence and
	# the override - because either alone would leave the chip reading as its own Kit's name or as
	# a raw key.
	assert_eq(translation.get_message('gear.buff_grey_birds.name'), StringName(''),
		'The chip deliberately has no name row of its own...')
	var chip:Buff = ContentLibrary.get_buff(SluaghFixture.GREY_BIRDS_CHIP)
	assert_eq(chip.localization_key_override, 'ms_o_trickery.action_grey_birds',
		'...and wears the invade\'s instead.')

func test_the_licence_grants_the_system_at_rank_one():
	var licence:UnlockTree = ContentLibrary.get_license_tree(SluaghFixture.LICENSE_ID)
	assert_not_null(licence, 'li_sluagh loads as an UnlockTree.')
	if licence == null: return
	var rank_1_ids:Array[StringName] = []
	for kit:Kit in licence.rank_1.granted_gear: rank_1_ids.append(kit.compcon_id)
	assert_true(rank_1_ids.has(SluaghFixture.TRICKERY), 'Rank 1 grants O\' Trickery...')
	assert_true(rank_1_ids.has(SluaghFixture.REND_NEXUS), '...alongside the Rend Nexus...')
	assert_eq(rank_1_ids.size(), 2, '...and nothing else. Rank I is two items on the sheet.')

