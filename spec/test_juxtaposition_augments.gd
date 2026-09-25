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
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_juxtaposition_augments.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')

const KOREMASA_TILE := Vector2i(3, 5)
const HOSTILE_TILE := Vector2i(4, 5)

const HIT := 15
const MISS := 1
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
	await attack([MISS, HIT])
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
	await attack([MISS, HIT])
	assert_eq(reroll_prompts().size(), 0, 'Not in the Danger Zone: no reroll.')
	assert_eq(lost(before), 0, 'The miss stood.')

func test_an_out_of_zone_first_attack_spends_the_turns_chance():
	fit()
	await Fixture.open_turn(game, koremasa)
	await attack([HIT])
	assert_eq(chips().size(), 0, 'The first attack spent the chip, in the Danger Zone or not (ruling 30).')
	Fixture.set_heat(game, koremasa, DANGER)
	var before := hostile.core.current.health
	await attack([MISS, HIT])
	assert_eq(reroll_prompts().size(), 0, 'So a later in-zone attack that turn is not offered.')
	assert_eq(lost(before), 0, 'Its miss stood.')

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
