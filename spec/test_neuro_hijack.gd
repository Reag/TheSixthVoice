# NEURO-HIJACK (the Rakshasa's core active, design 4, rulings 26-31):
#
#   "You hijack the targeting and threat recognition systems of all nearby mechs. For the rest of the
#    scene, whenever a hostile character within Sensors targets you with an attack and has another
#    valid character to target, they must first pass a Systems save. On a failure, they cannot attack
#    you and must choose a different target for that attack at +1 Difficulty. If a character succeeds
#    their save they are unaffected by this ability for the rest of the turn."
#
# A core-power PROTOCOL hanging buff_neuro_hijack (until MANUAL) on the Rakshasa. The buff listens at
# the per-target ATTACK PRE and moves the roll (spike 3's per-roll swap). A failed save leaves a hidden
# +1 Difficulty on the attacker scoped to that one declared attack; a passed one, a hidden exemption
# keyed by this Rakshasa's core gear until the end of the turn in progress.
#
# GEOMETRY (16x10 unless a test says otherwise). The attacker swings a MELEE weapon (threat 1, no tags,
# no engaged penalty): its "other valid characters" are exactly the characters ADJACENT to it, which
# is what lets every test place or withhold an alternative by one tile.
#
#   (5,4) attacker's ally          RAKSHASA (4,5)  ATTACKER (5,5)  (6,5) the Rakshasa's ally
#
# Dice: when a save is asked its d20 is popped FIRST (ATTACK PRE runs before the roll). Fixture.queue's
# tail of 3s then feeds the difficulty and damage dice. A 3 misses every evasion in this file, so a
# roll nobody queued for is a miss. Every NEGATIVE test queues one number that reads differently
# depending on whether a save took it: [HIT] is a passed save (and an exemption) if asked, a hit if not.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_neuro_hijack.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')

const RAKSHASA_TILE := Vector2i(4, 5)
const ATTACKER_TILE := Vector2i(5, 5)
const RAKSHASA_ALLY_TILE := Vector2i(6, 5)
const ATTACKER_ALLY_TILE := Vector2i(5, 4)
const SAVE_FAILS := 1
const SAVE_PASSES := 20
const HIT := 18

var game:Gamemaster
var responder
var rakshasa:Unit
var attacker:Unit
var melee:GearCore

func before_each() -> void:
	await get_tree().process_frame

## ONE game and ONE responder per test, built by the test itself so it can pick the map: two
## responders on one bus both answer the same request, and the first to answer wins.
func make_game(map_size:Vector2i = Fixture.DEFAULT_MAP_SIZE) -> void:
	var built:Array = Fixture.create_game_with_prompts(self, map_size)
	game = built[0]
	responder = built[1]
	# Worm Code asks on every failed save the Rakshasa forces; its heat is not under test except where named.
	responder.chosen_yesnos = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The standard cast: a PLAYER Rakshasa and an adjacent AI hostile with a melee weapon.
func build(rakshasa_faction:Faction.SIDE = Faction.PLAYER, attacker_faction:Faction.SIDE = Faction.AI_ENEMY) -> void:
	make_game()
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, rakshasa_faction)
	attacker = Fixture.create_hostile(game, ATTACKER_TILE, 8, attacker_faction)
	melee = Fixture.equip(attacker, Fixture.MELEE)

## Declare `shooter`'s solo action on `target`, the dice queued, and hand back the summary.
func fire(shooter:Unit, weapon:GearCore, target:Unit, rolls:Array[int], flags:Array = []) -> DeclaredAttackSummary:
	Fixture.queue(rolls)
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = target, flags = flags,
	})
	await game.execute_event_block(EventBlock.create_multiple([core] as Array[EventCore]))
	return core.context.resource as DeclaredAttackSummary

func fire_at_tile(shooter:Unit, weapon:GearCore, tile:Vector2i, rolls:Array[int]) -> DeclaredAttackSummary:
	Fixture.queue(rolls)
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_tiles = [tile] as Array[Vector2i],
	})
	await game.execute_event_block(EventBlock.create_multiple([core] as Array[EventCore]))
	return core.context.resource as DeclaredAttackSummary

func rolled_against(summary:DeclaredAttackSummary) -> Array[Unit]:
	var targets:Array[Unit] = []
	if summary == null: return targets
	for roll:AttackRoll in summary.attack_rolls: targets.append(roll.target_unit)
	return targets

## The Neuro-Hijack difficulty on a roll: the sum of accuracy mods the roll breakdown titles with the
## protocol's own name. 0 when absent.
func hijack_difficulty(roll:AttackRoll) -> int:
	var total := 0
	var title := tr('gear.buff_neuro_hijack.name')
	for acc_mod in roll.pre.accuracy_mods:
		if acc_mod.title_key == title: total += acc_mod.mod
	return total

## Press the protocol. Its own confirm (CommonActionUtil.confirm_use, action_system_apply_buff.gd:103)
## is a yes/no, and before_each declines every yes/no for Worm Code's sake - so this one is queued YES.
func hijack(unit:Unit) -> void:
	responder.yesno_queue.append(true)
	await Fixture.hijack(game, unit)
	assert_true(UnitCondition.has_buff(unit, Fixture.HIJACK_BUFF), 'fixture: Neuro-Hijack is up.')

func core_gear() -> GearCore: return rakshasa.get_gear(Fixture.CORE_ID)

func protocol():
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	return kit.get_action(Fixture.HIJACK_ACTION) if Kit.is_valid(kit) else null

# ---------------------------------------------------------------- the protocol

func test_the_protocol_is_a_core_power_protocol_applied_only_to_self():
	var action = protocol()
	assert_true(action is ActionSystemApplyBuff, 'The core Kit carries Neuro-Hijack, an apply-buff system action.')
	if action is not ActionSystemApplyBuff: return
	assert_eq(action.action_type, Lancer.ACTION.PROTOCOL, 'A PROTOCOL.')
	assert_true(action.consumes_cp, 'It spends the core power.')
	assert_true(action.apply_only_to_self, 'It targets nobody but the Rakshasa.')
	assert_false(action.can_reapply, 'Pressing it twice does nothing new.')
	assert_eq(action.usage_group, Fixture.HIJACK_USAGE, 'On its own usage group.')
	var buff_ids:Array[String] = []
	for buff:Buff in action.buffs: buff_ids.append(String(buff.compcon_id))
	assert_eq(buff_ids, ['buff_neuro_hijack'] as Array[String], 'It applies exactly buff_neuro_hijack.')

func test_the_core_kit_stays_non_tech():
	# Design 2.1's trap: a tech action anywhere on the core Kit would refuse every reaction on it
	# against tech-immune units (unit_action.gd:567-571).
	build()
	assert_true(protocol() != null, 'fixture: the protocol exists.')
	assert_false(UnitAction.is_tech(core_gear()), 'The core Kit is still not a tech Kit.')

func test_activating_it_spends_the_core_power_and_hangs_the_chip_for_the_scene():
	build()
	await Fixture.open_turn(game, rakshasa)
	assert_true(rakshasa.core.has_core_power, 'CONTROL: the core power is up beforehand.')
	responder.yesno_queue.append(true)
	await SpecFactory.use(game, rakshasa, Fixture.CORE_ID, Fixture.HIJACK_ACTION)
	assert_false(rakshasa.core.has_core_power, 'The core power is spent.')
	assert_true(UnitCondition.has_buff(rakshasa, Fixture.HIJACK_BUFF), 'The Rakshasa carries the chip.')
	await SpecFactory.end_turn(game, rakshasa)
	await SpecFactory.start_turn(game, rakshasa)
	assert_true(UnitCondition.has_buff(rakshasa, Fixture.HIJACK_BUFF), 'For the rest of the scene.')

# ---------------------------------------------------------------- single target

func test_a_failed_save_moves_the_roll_to_another_character():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(rolled_against(summary), [ally] as Array[Unit], 'The roll was made against the other character.')
	assert_gt(ally.current_damage(), 0, 'The new target takes the damage.')
	assert_eq(rakshasa.current_damage(), 0, 'The Rakshasa takes none: "they cannot attack you".')
	assert_eq(summary.all_attacked_units, [ally] as Array[Unit], "The summary's entry is replaced in place.")

func test_the_moved_roll_is_at_plus_one_difficulty():
	build()
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(summary.attack_rolls.size(), 1, 'fixture: one roll.')
	if summary.attack_rolls.is_empty(): return
	assert_eq(hijack_difficulty(summary.attack_rolls[0]), -1, '+1 Difficulty, titled Neuro-Hijack.')

func test_the_difficulty_is_scoped_to_that_one_attack():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_true(UnitCondition.has_buff(attacker, Fixture.HIJACK_DIFFICULTY), 'fixture: the difficulty buff is still on the attacker.')
	var second := await fire(attacker, melee, ally, [HIT], [Action.FLAG.AS_FREEBIE])
	assert_eq(rolled_against(second), [ally] as Array[Unit], 'fixture: the second attack was rolled.')
	if second.attack_rolls.is_empty(): return
	assert_eq(hijack_difficulty(second.attack_rolls[0]), 0, 'A later attack that turn is not at +1.')

func test_an_ai_attacker_picks_by_its_own_score():
	build()
	# REGISTERED FIRST, so an implementation that just takes the front of the list takes this one.
	var own_ally := Fixture.create_hostile(game, ATTACKER_ALLY_TILE)
	var enemy := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(rolled_against(summary), [enemy] as Array[Unit], 'The AI swings at the unit its own score prefers.')
	assert_eq(own_ally.current_damage(), 0, 'Not its own ally.')

func test_the_ai_candidates_list_its_own_ally_first():
	# The vacuity guard for the test above: the production candidate list really does put the
	# attacker's own ally ahead, so the pick above is the score's and not the list's.
	build()
	var own_ally := Fixture.create_hostile(game, ATTACKER_ALLY_TILE)
	var enemy := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	var context := Context.create({
		unit = attacker, target_unit = rakshasa, gear = melee, action = melee.get_solo_action(),
		resource = DeclaredAttackSummary.create([rakshasa] as Array[Unit], [rakshasa.tile()] as Array[Vector2i],
			[rakshasa.tile()] as Array[Vector2i], [] as Array[Vector3i]),
	})
	var candidates:Array[Unit] = load(Fixture.HIJACK_SCRIPT).alternatives(rakshasa, context)
	assert_eq(candidates, [own_ally, enemy] as Array[Unit], 'Both are offered, own ally first.')

func test_a_player_attacker_chooses_and_its_own_ally_is_offered():
	build(Faction.AI_ENEMY, Faction.PLAYER)
	var own_ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	var other := Fixture.create_hostile(game, ATTACKER_ALLY_TILE)
	await hijack(rakshasa)
	responder.unit_queue = [own_ally]
	var summary := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(responder.unit_prompts.size(), 1, 'The player attacker is asked once.')
	if responder.unit_prompts.is_empty(): return
	var offered:Array = responder.unit_prompts[0].units
	assert_true(offered.has(own_ally), "The attacker's own ally is offered.")
	assert_true(offered.has(other), 'And the other character.')
	assert_false(offered.has(rakshasa), 'Never the Rakshasa.')
	assert_false(offered.has(attacker), 'Never the attacker itself.')
	assert_eq(rolled_against(summary), [own_ally] as Array[Unit], 'The roll goes where the player chose.')

func test_the_players_choice_is_mandatory():
	build(Faction.AI_ENEMY, Faction.PLAYER)
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	Fixture.create_hostile(game, ATTACKER_ALLY_TILE) # a second candidate, or nothing is asked
	await hijack(rakshasa)
	responder.unit_queue = [null] # declines the pick
	var summary := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(responder.unit_prompts.size(), 1, 'fixture: the prompt was raised.')
	assert_eq(rolled_against(summary).size(), 1, 'fixture: one roll.')
	assert_false(rolled_against(summary).has(rakshasa), 'Declining still cannot attack the Rakshasa.')
	assert_eq(rakshasa.current_damage(), 0, 'The Rakshasa is untouched.')

func test_a_tech_attack_is_asked_too():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	var tech:GearCore = attacker.get_gear(Fixture.TECH)
	assert_true(GearCore.is_valid(tech), 'fixture: the hostile carries the basic invade.')
	if not GearCore.is_valid(tech): return
	await hijack(rakshasa)
	var summary := await fire(attacker, tech, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(rolled_against(summary), [ally] as Array[Unit], 'The invade is moved as well.')

# ---------------------------------------------------------------- area

func test_a_blast_catching_the_rakshasa_and_two_others_drops_only_its_roll():
	make_game()
	# NO build(): its melee attacker at (5,5) would stand inside the Blast.
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var north := Fixture.create_ally(game, RAKSHASA_TILE + Vector2i(0, -1))
	var south := Fixture.create_ally(game, RAKSHASA_TILE + Vector2i(0, 1))
	var gunner := Fixture.create_hostile(game, Vector2i(12, 5))
	var mortar := Fixture.equip(gunner, Fixture.MORTAR)
	await hijack(rakshasa)
	var summary := await fire_at_tile(gunner, mortar, RAKSHASA_TILE, [SAVE_FAILS, HIT, 3, 3, HIT, 3, 3])
	var rolled := rolled_against(summary)
	assert_eq(rolled.size(), 2, 'Two rolls.')
	assert_true(rolled.has(north) and rolled.has(south), 'Against the two other characters.')
	assert_false(rolled.has(rakshasa), "The Rakshasa's roll is aborted.")
	assert_eq(rakshasa.current_damage(), 0, 'It takes nothing.')
	for roll:AttackRoll in summary.attack_rolls:
		assert_eq(hijack_difficulty(roll), -1, 'Each other roll is at +1 Difficulty.')
	assert_true(summary.all_attacked_units.has(rakshasa), 'The declared list is left as declared (recorded).')

func test_a_blast_catching_only_the_rakshasa_asks_nothing():
	make_game()
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	# A character OUTSIDE the Blast: it is not "another valid character" for an area attack.
	Fixture.create_ally(game, Vector2i(4, 8))
	var gunner := Fixture.create_hostile(game, Vector2i(12, 5))
	var mortar := Fixture.equip(gunner, Fixture.MORTAR)
	await hijack(rakshasa)
	var summary := await fire_at_tile(gunner, mortar, RAKSHASA_TILE, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'Rolled against the Rakshasa.')
	assert_false(Fixture.is_exempt(gunner, rakshasa), 'No save was asked (a pass would have exempted).')

# ---------------------------------------------------------------- a pass, and the exemption

func test_a_pass_lets_the_attack_through_and_exempts_the_attacker():
	build()
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [SAVE_PASSES, HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'The attack proceeds against the Rakshasa.')
	assert_gt(rakshasa.current_damage(), 0, 'And hits it.')
	assert_true(Fixture.is_exempt(attacker, rakshasa), 'The attacker is exempt.')
	if summary.attack_rolls.is_empty(): return
	assert_eq(hijack_difficulty(summary.attack_rolls[0]), 0, 'No difficulty on a pass.')

func test_an_exempt_attacker_is_not_asked_again_that_turn():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	await fire(attacker, melee, rakshasa, [SAVE_PASSES, HIT])
	assert_true(Fixture.is_exempt(attacker, rakshasa), 'fixture: exempt.')
	# If it were asked, the 1 would fail the save and move the roll to the ally.
	var second := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT], [Action.FLAG.AS_FREEBIE])
	assert_eq(rolled_against(second), [rakshasa] as Array[Unit], 'Not asked: rolled against the Rakshasa.')
	assert_eq(ally.current_damage(), 0, 'The ally is untouched.')

func test_the_exemption_ends_with_the_turn_and_it_asks_again():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	await fire(attacker, melee, rakshasa, [SAVE_PASSES, HIT])
	assert_true(Fixture.is_exempt(attacker, rakshasa), 'fixture: exempt.')
	await SpecFactory.end_turn(game, rakshasa)
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'The exemption ends with the turn in progress.')
	var next := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT], [Action.FLAG.AS_FREEBIE])
	assert_eq(rolled_against(next), [ally] as Array[Unit], 'The next turn it asks again, and the roll moves.')

# ---------------------------------------------------------------- when it does not apply

func test_an_attacker_outside_sensors_is_not_asked():
	make_game(Fixture.WIDE_MAP_SIZE)
	rakshasa = Fixture.create_rakshasa(game, Vector2i(1, 2))
	attacker = Fixture.create_hostile(game, Vector2i(24, 2)) # distance 23 > Sensors 20
	melee = Fixture.equip(attacker, Fixture.MELEE)
	var ally := Fixture.create_ally(game, Vector2i(25, 2))
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'Outside Sensors: not asked.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'No save at all.')
	# CONTROL: the same attack from within Sensors is asked, so the alternative above was a real one.
	UnitTile.move_to(rakshasa, Vector2i(5, 2)) # distance 19
	var control := await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT], [Action.FLAG.AS_FREEBIE])
	assert_eq(rolled_against(control), [ally] as Array[Unit], 'Within Sensors it is asked, and the roll moves.')

func test_an_attack_on_another_character_is_not_asked():
	build()
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	# A SECOND candidate: without it the gate under test is held by the already-targeted exclusion
	# (the ally is this attack's own target), and the test could not tell (mutation M15).
	Fixture.create_hostile(game, ATTACKER_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, ally, [HIT])
	assert_eq(rolled_against(summary), [ally] as Array[Unit], 'Only attacks on the Rakshasa are hijacked.')
	assert_gt(ally.current_damage(), 0, 'The HIT was the attack roll, not a save.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'No save at all.')

func test_an_ally_attacking_the_rakshasa_is_not_asked():
	build(Faction.PLAYER, Faction.PLAYER)
	Fixture.create_hostile(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	responder.yesno_queue.append(true) # the friendly-fire confirm
	var summary := await fire(attacker, melee, rakshasa, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'An ally is not hijacked.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'No save at all.')

func test_a_drone_is_not_a_character_and_is_not_asked():
	make_game()
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	attacker = Fixture.create_hostile_drone(game, ATTACKER_TILE)
	melee = Fixture.equip(attacker, Fixture.MELEE)
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'A drone attacker is not hijacked.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'No save at all.')

func test_no_other_valid_character_means_no_save():
	build()
	# A character the melee cannot reach is not a valid target for THIS attack.
	var far := Fixture.create_ally(game, Vector2i(9, 5))
	await hijack(rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'Nobody else to target: the attack proceeds.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'And no save was asked.')
	assert_eq(far.current_damage(), 0, 'The unreachable character is untouched.')

func test_before_the_protocol_nothing_is_asked():
	build()
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await Fixture.open_turn(game, rakshasa)
	var summary := await fire(attacker, melee, rakshasa, [HIT])
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'Without the protocol: vanilla.')
	assert_false(Fixture.is_exempt(attacker, rakshasa), 'No save at all.')

func test_the_sniper_amr_under_its_mark_is_immune():
	make_game()
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	Fixture.create_ally(game, RAKSHASA_TILE + Vector2i(0, 2))
	var sniper := sniper_at(Vector2i(12, 5))
	var mark_gear:GearCore = sniper.get_gear(&'npcf_snipers_mark_sniper')
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), rakshasa, &'buff_snipers_mark_sniper', mark_gear)
	await hijack(rakshasa)
	var summary := await fire(sniper, sniper.get_gear(&'npcf_anti_materiel_rifle_sniper'), rakshasa, [HIT], ORDNANCE_FREEBIE)
	assert_eq(rolled_against(summary), [rakshasa] as Array[Unit], 'Immune to redirects: rolled against the Rakshasa.')
	assert_false(Fixture.is_exempt(sniper, rakshasa), 'No save was asked.')

func test_the_sniper_amr_without_its_mark_is_asked():
	make_game()
	# The control for the test above: the same sniper and geometry, no mark.
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	Fixture.create_ally(game, RAKSHASA_TILE + Vector2i(0, 2))
	var sniper := sniper_at(Vector2i(12, 5))
	await hijack(rakshasa)
	await fire(sniper, sniper.get_gear(&'npcf_anti_materiel_rifle_sniper'), rakshasa, [SAVE_PASSES, HIT], ORDNANCE_FREEBIE)
	assert_true(Fixture.is_exempt(sniper, rakshasa), 'Asked, and the pass exempted it.')

## The AMR is ORDNANCE: outside the firer's own opening it is refused (unit_action.gd:146) unless freebie.
const ORDNANCE_FREEBIE := [Action.FLAG.AS_FREEBIE]

func sniper_at(tile:Vector2i) -> Unit:
	var sniper := Fixture.create_hostile(game, tile)
	Fixture.equip(sniper, &'npcf_snipers_mark_sniper')
	Fixture.equip(sniper, &'npcf_anti_materiel_rifle_sniper')
	return sniper

# ---------------------------------------------------------------- reaction attacks

func test_an_overwatch_on_the_rakshasa_is_asked():
	make_game()
	rakshasa = Fixture.create_rakshasa(game, Vector2i(4, 4))
	attacker = Fixture.create_hostile(game, ATTACKER_TILE)
	melee = Fixture.equip(attacker, Fixture.MELEE)
	var ally := Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	Fixture.queue([SAVE_FAILS, HIT])
	await SpecFactory.move(game, rakshasa, Vector2i(4, 6))
	assert_eq(rakshasa.tile(), Vector2i(4, 6), 'fixture: it actually moved.')
	assert_gt(ally.current_damage(), 0, 'The Overwatch was moved to the other character.')
	assert_eq(rakshasa.current_damage(), 0, 'The Rakshasa is untouched.')

# ---------------------------------------------------------------- interactions

func test_worm_code_fires_on_the_failure():
	build()
	Fixture.create_ally(game, RAKSHASA_ALLY_TILE)
	await hijack(rakshasa)
	responder.chosen_yesnos = true
	await fire(attacker, melee, rakshasa, [SAVE_FAILS, HIT])
	assert_eq(Fixture.heat(attacker), 2, 'Worm Code gave the attacker 2 heat on the failed save.')

func test_two_rakshasas_stay_independent():
	build()
	var second := Fixture.create_rakshasa(game, Vector2i(6, 5))
	Fixture.create_ally(game, Vector2i(5, 6))
	await hijack(rakshasa)
	await SpecFactory.end_turn(game, rakshasa)
	await hijack(second)
	await fire(attacker, melee, rakshasa, [SAVE_PASSES, HIT])
	assert_true(Fixture.is_exempt(attacker, rakshasa), 'Exempt from the first Rakshasa.')
	assert_false(Fixture.is_exempt(attacker, second), 'Not from the second.')
	var at_second := await fire(attacker, melee, second, [SAVE_FAILS, HIT], [Action.FLAG.AS_FREEBIE])
	assert_false(rolled_against(at_second).has(second), 'The second Rakshasa still asks, and the roll moves off it.')
	assert_eq(at_second.attack_rolls.size(), 1, 'fixture: the attack was rolled.')

func test_it_asks_once_per_declared_attack_even_when_a_reroll_comes_back_to_it():
	# Ruling 27's stamp. A reroll against a new target builds a SECOND event_unit_attack on the SAME
	# summary (event_unit_attack.gd:327-336), so ATTACK PRE fires again. The vehicle is a second
	# Rakshasa's own Silver Tongue: its invade is hijacked onto a hostile, misses, and the reroll comes
	# back to the hijacking Rakshasa. Without the stamp the reroll would be asked again - and the HIT
	# queued for it would be taken as a passed save instead.
	make_game()
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, Faction.AI_ENEMY)
	var caster := Fixture.create_rakshasa(game, ATTACKER_TILE)
	var hostile := Fixture.create_hostile(game, RAKSHASA_ALLY_TILE)
	# A THIRD character, so the reroll still has a candidate: without it the already-targeted exclusion
	# empties the list on the reroll and holds this test green with the stamp deleted (mutation M14).
	Fixture.create_hostile(game, ATTACKER_TILE + Vector2i(0, 1))
	await hijack(rakshasa)
	responder.unit_queue = [hostile, rakshasa] # the hijack's pick, then Silver Tongue's new target
	# Dice: the save, the first d20 and its +1 Difficulty d6 (both misses), then the reroll's d20.
	var summary := await fire(caster, caster.get_gear(Fixture.TECH), rakshasa, [SAVE_FAILS, 3, 3, HIT])
	assert_eq(rolled_against(summary), [hostile, rakshasa] as Array[Unit],
		'Hijacked onto the hostile, missed, and rerolled back onto the Rakshasa.')
	assert_eq(summary.attack_rolls.size(), 2, 'fixture: two rolls.')
	if summary.attack_rolls.size() < 2: return
	assert_true(summary.attack_rolls[1].hit, 'The reroll was not asked again: the HIT was the attack roll.')
	assert_false(Fixture.is_exempt(caster, rakshasa), 'No second save, so no exemption.')
