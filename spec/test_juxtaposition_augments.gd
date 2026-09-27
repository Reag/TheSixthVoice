# JUXTAPOSITION AUGMENTS (Koremasa rank III weapon mod, design section 5, ruling 30):
#
#   SP 2 | Fits: types ['Melee'] | sizes ['Auxiliary', 'Main', 'Heavy'] | Adds tags: UNIQUE
#   "While you are in the Danger Zone, you may reroll the first attack made with this weapon each
#    round, but must keep the second result."
#
# RULING 30 (author): RAW - the weapon's FIRST attack each round spends the chance, in the Danger Zone
# or not. Per turn, not per round (ruling 18): re-armed at the Koremasa's own turn start.
#
# THE SHAPE. A PassiveWeaponMod applies a one-time BuffModifyAttackRoll at reroll_take_second (the
# Death's Head's Neurolink, buff_neurolink.tres), reapplied at every turn start, gated on the modded
# weapon (context.gear.is_weapon_mod_attached(core.from_gear), BuffWeaponType's from_weapon_mod test)
# and on DANGER ZONE at the roll. The engine asks the question itself (event_unit_attack.gd:264-305):
# it never asks on a crit, and without CAN_BANK it consumes the chip whether the player rerolls or not
# (:271, :303). What the engine CANNOT do is spend a chip that did not apply - an out-of-DZ first
# attack - so the mod also carries an ON_ATTACK effect that consumes it after ANY attack with the
# weapon. That is the design's "ATTACK POST watcher", met through PassiveWeaponMod.on_hit_effects,
# which the engine already scopes to the fitted weapon (event_unit_attack.gd:44-45, :66) - the DDMR's
# ruling 23 route, so no reaction and no bus.
#
# THE DICE. The weapon is the GMS main melee (1d6+2, threat 1) against an evasion-10 dummy: the
# attack d20, a rerolled d20 when one is taken, then the d6, which the fixture's tail makes a 3 - so
# a hit deals 5.
#
# EVERY "NOTHING WAS OFFERED" TEST PROVES ITS ATTACK HAPPENED (Pass F, open item D). "No prompt and no
# damage" also reads true of an attack that never ran, so each one hangs a RollRecorder (test_ddmr.gd's
# instrument) and asserts the roll exists and still shows the MISS that was queued - a reroll would
# have replaced it (event_unit_attack.gd:300 rerolls the same AttackRoll in place).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_juxtaposition_augments.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 5)
const HOSTILE_TILE := Vector2i(4, 5)

const HIT := 15
const MISS := 1
## A runtime Main Melee with BURST 1 (the install_on pattern, test_superpositional_profile.gd): the
## multi-target clause of onhit_juxtaposition_augments.gd needs one attack that rolls twice.
const AREA_MELEE := &'spec_juxtaposition_area_melee'
const SECOND_HOSTILE_TILE := Vector2i(2, 5)
const CRIT := 20
const DAMAGE := 5
## The Koremasa's heat cap is 8; the DANGER ZONE is half, rounded up.
const DANGER := 4

var game:Gamemaster
var responder
var koremasa:Unit
var hostile:Unit

## ONE FRAME FIRST, AND IT IS LOAD-BEARING. A test that never awaits (the profile tests) ends in the
## same frame it began, so the responder add_child_autoqfree gave it is only QUEUED for freeing when
## the next test starts - still connected to the choice bus. Measured: the first attacking test after
## two synchronous ones saw 11 on_choice_request listeners against 9 in every later test, both stale
## responders answered its variant prompt, and the whole activation ran twice (two attack_declared
## events, two proxies, the first target hit twice).
func before_each() -> void:
	await get_tree().process_frame
	var pair := Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	Fixture.equip(koremasa, Fixture.MELEE)
	Fixture.equip(koremasa, Fixture.KNIFE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## A passive that never applies and only keeps references to the AttackRolls it was shown. Copied from
## test_ddmr.gd's RollRecorder (itself test_biting_retort.gd's) - see that file for why it can be
## trusted: check_if_passive_applies is polled with the live roll already built, returns false so it
## is never collected or consumed, and the roll is mutated in place afterwards, so the same reference
## reads back the final result. `rolls` adds every distinct roll in order, for the multi-target case.
class RollRecorder extends Buff:
	var last_roll:AttackRoll = null
	var rolls:Array[AttackRoll] = []

	func _init() -> void:
		to = Buff.TO.MODIFY_ATTACK_ROLL
		hide_from_player = true

	func check_if_passive_applies(_core:BuffCore, context:Context) -> bool:
		if AttackRoll.is_valid(context.object):
			last_roll = context.object
			if not rolls.has(last_roll): rolls.append(last_roll)
		return false ## never actually a modifier, so never collected and never consumed

# ---------------------------------------------------------------- helpers

func passive() -> PassiveWeaponMod:
	var kit:Kit = ContentLibrary.get_kit(Fixture.JUXTAPOSITION_ID)
	if not Kit.is_valid(kit): return null
	var mods := kit.get_passives(PassiveWeaponMod)
	return mods.front() if not mods.is_empty() else null

func fit(weapon_id:StringName = Fixture.MELEE) -> GearCore:
	return Fixture.fit_mod(koremasa, Fixture.JUXTAPOSITION_ID, weapon_id)

func chips() -> Array[BuffCore]:
	return UnitCondition.get_buffs(koremasa, Fixture.JUXTAPOSITION_BUFF)

## Attack the hostile with `kit_id` from the Koremasa's open turn. AS_FREEBIE, so a second attack
## with the same weapon in one turn is not refused by the per-turn soft limit.
func attack(d20s:Array[int], kit_id:StringName = Fixture.MELEE) -> void:
	await Fixture.open_turn(game, koremasa)
	Fixture.queue(d20s)
	await SpecFactory.use_solo(game, koremasa, kit_id, hostile, [Action.FLAG.AS_FREEBIE])

## Every yes/no prompt that was the engine's reroll question.
func reroll_prompts() -> Array[Dictionary]:
	var key := X.tr('event.unit_attack.reroll.confirm')
	var found:Array[Dictionary] = []
	for info:Dictionary in responder.yesno_prompts:
		if String(info.get('title', '')).contains(key): found.append(info)
	return found

func lost(before:int) -> int: return before - hostile.core.current.health

## Hang a fresh RollRecorder on the Koremasa (the attacker's buffs are polled too,
## event_unit_attack.gd:356) and hand it back. Hang it AFTER fit(): that re-applies passive buffs.
func watch_roll() -> RollRecorder:
	var recorder := RollRecorder.new()
	UnitCondition.apply_buff(SpecFactory.dummy_event(), koremasa, recorder)
	return recorder

## The attack happened, and its d20 is still the MISS that was queued: nothing rerolled it.
func assert_missed_unrerolled(recorder:RollRecorder, what:String) -> void:
	assert_true(recorder.last_roll != null and recorder.last_roll.base_roll == MISS,
		'LIVENESS: %s really rolled, and kept its MISS (got %s).' % [what,
			recorder.last_roll.base_roll if recorder.last_roll != null else 'no roll'])

## A Main Melee Kit built at runtime from the GMS main melee's own attack, with a BURST 1 pattern.
func install_area_melee() -> GearCore:
	var source:Kit = ContentLibrary.get_kit(Fixture.MELEE)
	var action:ActionAttackWeapon = source.get_weapon_actions()[0].create_duplicate_for_variant()
	action.range_pattern = RangePattern.create(Lancer.AOE_TYPE.BURST, 1)
	var kit := Kit.new()
	kit.compcon_id = AREA_MELEE
	kit.actions.append(action)
	koremasa.core.loadout.equipped_kits.append(kit)
	koremasa.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	return koremasa.get_gear(AREA_MELEE)

# ---------------------------------------------------------------- the profile

func test_the_mod_is_a_unique_two_sp_weapon_mod():
	var kit:Kit = ContentLibrary.get_kit(Fixture.JUXTAPOSITION_ID)
	assert_true(Kit.is_valid(kit), 'wm_juxtaposition_augments is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_true(kit.is_unique(), 'UNIQUE.')
	var mod := passive()
	assert_not_null(mod, 'One PassiveWeaponMod.')
	if mod == null: return
	assert_eq(mod.allowed_types, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE], 'Melee only.')
	assert_eq(mod.allowed_sizes, [Lancer.WEAPON_SIZE.AUX, Lancer.WEAPON_SIZE.MAIN, Lancer.WEAPON_SIZE.HEAVY]
		as Array[Lancer.WEAPON_SIZE], 'Auxiliary, Main, Heavy - not Superheavy.')
	assert_true(mod.reapply_at_the_start_of_each_turn, 'Re-armed at every turn start.')

func test_a_melee_weapon_takes_the_mod_and_a_ranged_one_does_not():
	Fixture.equip(koremasa, Fixture.RIFLE)
	var rifle := koremasa.get_gear(Fixture.RIFLE)
	var melee := koremasa.get_gear(Fixture.MELEE)
	var knife := koremasa.get_gear(Fixture.KNIFE)
	var mod := passive()
	assert_not_null(mod, 'fixture: the passive loads.')
	if mod == null: return
	assert_false(mod.is_applicable_to(rifle), 'A rifle cannot take it.')
	assert_true(mod.is_applicable_to(melee), 'A main melee weapon can.')
	assert_true(mod.is_applicable_to(knife), 'An auxiliary melee weapon can.')
	assert_null(koremasa.core.loadout.equip_weapon_mod(Fixture.JUXTAPOSITION_ID, rifle),
		'And the loadout refuses to fit it to the rifle.')

func test_fitting_it_puts_a_visible_chip_on_the_koremasa():
	var mod_gear := fit()
	assert_not_null(mod_gear, 'fixture: the mod fits the melee weapon.')
	if mod_gear == null: return
	var found := chips()
	assert_eq(found.size(), 1, 'One chip.')
	if found.is_empty(): return
	assert_eq(found[0].from_gear, mod_gear.persistent_id, 'From the mod.')
	assert_false(found[0].base.hide_from_player, 'Visible (ruling 34).')
	assert_true(found[0].base.is_onetime, 'One use.')

# ---------------------------------------------------------------- in the Danger Zone

func test_in_the_danger_zone_a_missed_first_attack_may_be_rerolled():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([MISS, HIT])
	assert_eq(reroll_prompts().size(), 1, 'The reroll was offered.')
	assert_eq(lost(before), DAMAGE, 'Taken: the second roll hit.')
	assert_eq(chips().size(), 0, 'And the chip is spent.')

func test_the_second_result_stands_even_when_worse():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([HIT, MISS])
	assert_eq(reroll_prompts().size(), 1, 'LIVENESS: the reroll was offered on a hit.')
	assert_eq(lost(before), 0, '"must keep the second result": the reroll missed, so the attack missed.')

func test_declining_keeps_the_roll_and_still_spends_the_chip():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	responder.yesno_queue.append(false)
	var before := hostile.core.current.health
	await attack([HIT])
	assert_eq(reroll_prompts().size(), 1, 'LIVENESS: offered.')
	assert_eq(lost(before), DAMAGE, 'Declined: the first roll stands.')
	assert_eq(chips().size(), 0, 'The first attack spent the chance anyway.')

func test_only_the_first_attack_is_offered():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	await attack([HIT])
	assert_eq(reroll_prompts().size(), 1, 'LIVENESS: the first attack was offered.')
	var before := hostile.core.current.health
	var recorder := watch_roll()
	await attack([MISS, HIT])
	assert_missed_unrerolled(recorder, 'the second attack')
	assert_eq(reroll_prompts().size(), 1, 'The second attack was not.')
	assert_eq(lost(before), 0, 'So its miss stood.')

func test_a_crit_is_never_offered_but_spends_the_chip():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([CRIT])
	assert_gt(lost(before), 0, 'LIVENESS: the crit landed.')
	assert_eq(reroll_prompts().size(), 0, 'Nobody rerolls a crit (event_unit_attack.gd:275).')
	assert_eq(chips().size(), 0, 'But it was the first attack, so the chance is gone.')

# ---------------------------------------------------------------- outside the Danger Zone

func test_outside_the_danger_zone_nothing_is_offered():
	fit()
	await Fixture.open_turn(game, koremasa)
	var before := hostile.core.current.health
	var recorder := watch_roll()
	await attack([MISS, HIT])
	assert_missed_unrerolled(recorder, 'the out-of-zone attack')
	assert_eq(reroll_prompts().size(), 0, 'Not in the Danger Zone: no reroll.')
	assert_eq(lost(before), 0, 'The miss stood.')

func test_an_out_of_zone_first_attack_spends_the_turns_chance():
	fit()
	await Fixture.open_turn(game, koremasa)
	await attack([HIT])
	assert_eq(chips().size(), 0, 'The first attack spent the chip, in the Danger Zone or not (ruling 30).')
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	var recorder := watch_roll()
	await attack([MISS, HIT])
	assert_missed_unrerolled(recorder, 'the later in-zone attack')
	assert_eq(reroll_prompts().size(), 0, 'So a later in-zone attack that turn is not offered.')
	assert_eq(lost(before), 0, 'Its miss stood.')

# ---------------------------------------------------------------- one attack, two targets

## onhit_juxtaposition_augments.gd:8-9: "A multi-target attack spends it on the first target's roll, as
## the engine does." One Burst 1 swing in the Danger Zone at two hostiles: the first roll MISSES and is
## offered, the reroll hits, and the second target's roll - a MISS that could be rerolled if the chip
## were still there - is offered nothing.
func test_a_multi_target_attack_spends_it_on_the_first_targets_roll():
	var area := install_area_melee()
	assert_true(GearCore.is_valid(area), 'fixture: the runtime area melee is equipped.')
	if not GearCore.is_valid(area): return
	var mod := Fixture.fit_mod(koremasa, Fixture.JUXTAPOSITION_ID, AREA_MELEE)
	assert_not_null(mod, 'fixture: the mod fits the area melee.')
	if mod == null: return
	var second := Fixture.create_hostile(game, SECOND_HOSTILE_TILE)
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	assert_eq(chips().size(), 1, 'fixture: the chip is live.')
	var recorder := watch_roll()
	await attack([MISS, HIT, MISS], AREA_MELEE)
	assert_eq(recorder.rolls.size(), 2, 'LIVENESS: one attack, two rolls.')
	if recorder.rolls.size() != 2: return
	var targets := [recorder.rolls[0].target_unit, recorder.rolls[1].target_unit]
	assert_true(targets.has(hostile) and targets.has(second), 'fixture: both hostiles were in the burst.')
	assert_eq(recorder.rolls[0].base_roll, HIT, 'The first target\'s MISS was rerolled into a hit.')
	assert_eq(reroll_prompts().size(), 1, 'Exactly one reroll prompt, on the first target.')
	assert_eq(chips().size(), 0, 'The chip is consumed.')
	assert_eq(recorder.rolls[1].base_roll, MISS, 'The second target\'s MISS stood: offered nothing.')

# ---------------------------------------------------------------- the weapon and the turn

func test_another_weapon_neither_offers_nor_spends_it():
	fit()
	await Fixture.open_turn(game, koremasa)
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([MISS, HIT], Fixture.KNIFE)
	assert_eq(reroll_prompts().size(), 0, 'The unmodded knife is not offered.')
	assert_eq(lost(before), 0, 'LIVENESS: the knife attacked and its miss stood.')
	assert_eq(chips().size(), 1, 'And the chip is still there.')
	await attack([MISS, HIT])
	assert_eq(reroll_prompts().size(), 1, 'The modded weapon, attacking after it, is offered.')

func test_the_chip_is_back_next_turn():
	fit()
	await Fixture.open_turn(game, koremasa)
	await attack([HIT])
	assert_eq(chips().size(), 0, 'LIVENESS: spent this turn.')
	await Fixture.cycle_turn(game, koremasa)
	assert_eq(chips().size(), 1, 'Re-armed at the next turn start.')
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([MISS, HIT])
	assert_eq(reroll_prompts().size(), 1, 'And offered again.')
	assert_eq(lost(before), DAMAGE, 'The reroll hit.')

# ---------------------------------------------------------------- the card

func test_the_card_rows_resolve():
	for key:String in ['gear.wm_juxtaposition_augments.name', 'gear.wm_juxtaposition_augments.flavor',
			'gear.wm_juxtaposition_augments.effect', 'gear.buff_juxtaposition_augments.name',
			'gear.buff_juxtaposition_augments.effect']:
		assert_ne(X.tr(key), key, '%s resolves.' % key)
	assert_eq(X.tr('gear.wm_juxtaposition_augments.name'), 'Juxtaposition Augments', 'The name.')
	assert_eq(X.tr('gear.buff_juxtaposition_augments.name'), 'Juxtaposition Augments', 'The chip is titled for the mod.')
