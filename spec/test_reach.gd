# REACH - RAGE's face 3 (SP1 Task 9).
#
#   "3 Reach: Your melee weapons gain +1 Threat and Reliable 2."
#
# THREE PIECES FOR ONE CARD LINE, and the third is the author's ruling (design section 1.5.5, AS
# BUILT). Buff.to is a single StringName (buff.gd:123) and the halves are read at two different keys:
# threat_distance asks Buff.TO.ACTION_RANGE / THREAT_RANGE (action_attack_weapon.gd:187-190) and
# get_weapon_tags asks Buff.TO.WEAPON_TAG (:169). So:
#   buff_rage_reach            VISIBLE chip, the threat half, carries the whole card line
#   buff_rage_reach_reliable   HIDDEN companion, puts "Reliable 2" on the weapon's TOOLTIP
#   action_reach_reliable      HIDDEN reaction, makes a miss actually LAND it
#
# WHY THE THIRD EXISTS, MEASURED HERE AT TASK 9. A WEAPON_TAG buff reaches get_weapon_tags and nothing
# else. The damage floor is read ONCE, from the action's own export, at
# content/events/event_unit_attack/event_unit_attack_declared.gd:82 -
# `base_damage.reliable = unit.get_tiered_int(action.reliable_damage)` - and a miss pays out exactly
# that int (attack_util.gd:120-126: get_miss() returns { primary_type: reliable }). Nothing writes
# DamageRollSummary.reliable again (:108 copies it, :177 zeroes it for bonus damage) and Buff.TO has
# no channel for it. Measured with the tag buff up: get_weapon_tags read { &"reliable": 2 } while a
# miss with a Reliable-0 melee weapon still landed 0. No vanilla buff or weapon mod grants RELIABLE
# anywhere, which is why the dead path had never been noticed.
#
# THE ENGINE STILL ADDS RELIABLE where it reads the tag (add_tag_to_collection's RELIABLE arm is
# old_value + tag_value, :134; only THROWN takes a maxi, :135), so the companion buff still returns
# maxi(0, 2 - printed) - otherwise a printed-Reliable-3 weapon's TOOLTIP would read Reliable 5. The
# reaction's gate uses the same arithmetic on the damage side, so the higher stands in both places.
#
# FOUR WEAPONS, ONE PER CASE, AND EACH TEST EQUIPS ITS OWN: the Leoleth has one Flex and one Heavy
# mount, so two MAIN weapons cannot both be aboard.
#   mw_tactical_melee_weapon  MAIN  MELEE  1d6+2  threat 1  Reliable 0   (the topped-up case)
#   mw_chain_axe              MAIN  MELEE  1d6    threat 1  Reliable 2   (the boundary: add nothing)
#   mw_nanocarbon_sword       HEAVY MELEE  1d6+4  threat 2  Reliable 3   (the higher stands)
#   mw_nexus_hunter_killer    MAIN  NEXUS  1d6    aim 10    Reliable 0   (the MELEE clause's control)
# The last one has to be Reliable 0 to isolate the MELEE clause: mw_assault_rifle prints Reliable 2,
# so the reaction's printed-Reliable clause would refuse it even with the weapon-type filter gone.
#
# RELIABLE IS MEASURED ON A MISS, which is the cleanest reading of it: on a miss the base total is
# zero, so whatever lands is the floor. The target is a 200 HP, 0-armor dummy so the number is the
# weapon's. THE CONTROLS MEASURE BEFORE AND AFTER rather than against a literal, because a hit's
# damage depends on the pilot's grit and this frame's own dice tail.
#
# THE TARGET IS PARKED ACROSS EVERY RAGE CYCLE, and that is the Task 7 carry-forward rather than
# caution: LeolethFixture.rage() ENDS the Leoleth's turn, and Toe To Toe is an END_TURN PRE free
# Skirmish - so every cycle in a spec that has armed a melee weapon would fire an extra attack on
# whatever happens to be left in the dice FIFO (rage() re-queues only AFTER end_turn returns).
# Departure 15's reach clause is the off switch: with nothing a melee weapon can reach, the trait
# offers nothing and the cycle is quiet.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_reach.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(6, 6)
const TARGET_TILE := Vector2i(7, 6)
## Fourteen tiles out on the 24x12 landscape: nothing melee reaches it, so Toe To Toe stays quiet.
const PARKED_TILE := Vector2i(20, 2)

## The shortfall reaction, which is this task's own and therefore not a frozen fixture constant.
const SHORTFALL_ID := &'action_reach_reliable'
## A Reliable-ZERO ranged weapon - see the header for why mw_assault_rifle cannot play this part.
const RANGED_KIT := &'mw_nexus_hunter_killer'

var game:Gamemaster
var leoleth:Unit
var target:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear() -> GearCore:
	return leoleth.get_gear(LeolethFixture.CORE_ID)

func action_by_id(action_id:StringName) -> Action:
	var gear:GearCore = core_gear()
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == action_id: return action
	return null

## Roll the RAGE d6 onto `face` with the target parked out of every melee weapon's reach, then put it
## back. See the header: the cycle's end_turn is Toe To Toe's trigger.
func rage_to(face:int) -> void:
	LeolethFixture.step(target, PARKED_TILE)
	await LeolethFixture.rage(game, leoleth, face)
	LeolethFixture.step(target, TARGET_TILE)

## The range the engine would actually target with, for this weapon, right now.
func target_range(kit_id:StringName) -> int:
	var specific:SpecificAction = SpecificAction.from_id(leoleth, kit_id)
	if not SpecificAction.is_valid(specific): return -1
	return specific.action.get_target_range(specific)

## What a MISS with this weapon lands on the target - which is exactly its Reliable.
func damage_on_a_miss(kit_id:StringName) -> int:
	var before:int = target.current_damage()
	LeolethFixture.cheat_a_miss()
	await SpecFactory.use_solo(game, leoleth, kit_id, target, [Action.FLAG.AS_FREEBIE])
	return target.current_damage() - before

## And what a HIT lands, for the control that proves the shortfall is the MISS case only.
func damage_on_a_hit(kit_id:StringName) -> int:
	var before:int = target.current_damage()
	LeolethFixture.cheat_a_hit()
	await SpecFactory.use_solo(game, leoleth, kit_id, target, [Action.FLAG.AS_FREEBIE])
	return target.current_damage() - before

# ---------------------------------------------------------------- the wiring

func test_the_visible_chip_is_the_threat_half():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.REACH_CHIP)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.REACH_CHIP)
	if buff == null: return
	assert_true(buff is BuffWeaponTypeBonus, 'It is a BuffWeaponTypeBonus.')
	if not (buff is BuffWeaponTypeBonus): return
	assert_eq(buff.to, Buff.TO.ACTION_RANGE, 'to = action_range, which threat_distance reads.')
	assert_eq(buff.bonus_subtype, Buff.BONUS_SUBTYPE.THREAT_RANGE, 'The THREAT_RANGE subtype.')
	assert_eq(buff.bonus_value, 1, '+1.')
	assert_eq(buff.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE],
		'MELEE only - a positive filter here, unlike the 43 As\' exclusion.')
	assert_false(buff.from_weapon_mod,
		'And NOT from_weapon_mod: the DDMR\'s threat buff sets it because it rides a mod; this one '
		+ 'is the frame\'s own.')
	assert_eq(buff.until, Lancer.UNTIL.START_OF_TURN, 'Until the start of the next turn.')
	assert_false(buff.hide_from_player, 'VISIBLE: it is the chip that carries this face\'s card line.')

func test_the_hidden_companion_is_the_reliable_half():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.REACH_RELIABLE_BUFF)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.REACH_RELIABLE_BUFF)
	if buff == null: return
	assert_true(buff is BuffWeaponTypeTag,
		'It extends BuffWeaponTypeTag - the archetype whose get_values returns a CATEGORY as well as '
		+ 'a number (buff_weapon_type_tag.gd:9-13). Plain BuffWeaponType returns only a number, so '
		+ 'add_tag_to_collection would be handed an EMPTY tag name.')
	if not (buff is BuffWeaponTypeTag): return
	assert_eq(buff.to, Buff.TO.WEAPON_TAG, 'to = weapon_tag.')
	assert_eq(buff.added_tag, Lancer.WEAPON_TAG.RELIABLE, 'The tag is `reliable`.')
	assert_eq(buff.added_tag_value, 2, 'And the target value is 2.')
	assert_eq(buff.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE], 'MELEE only.')
	assert_eq(buff.until, Lancer.UNTIL.START_OF_TURN, 'Same lifetime as its visible partner.')
	assert_true(buff.hide_from_player,
		'HIDDEN: one card line, one chip. Nothing draws a WEAPON_TAG buff\'s icon either '
		+ '(get_weapon_tags reads category_str and number, action_attack_weapon.gd:169-172), so it '
		+ 'needs no HIDDEN_BUFFS_NEEDING_ICONS row.')

func test_the_shortfall_reaction_is_wired_as_the_ruling_says():
	var action := action_by_id(SHORTFALL_ID)
	assert_not_null(action, 'The core Kit carries %s.' % SHORTFALL_ID)
	if action == null: return
	assert_true(action is ActionReactionAttacked,
		'ActionReactionAttacked, whose own gate is four of the five clauses declaratively.')
	if not (action is ActionReactionAttacked): return
	assert_true(action.triggers_on.has(ReactionBus.TRIGGER.ATTACK), 'It reacts to `attack`.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST,
		'At POST, the only timing that carries a RESOLVED AttackRoll in the triggering context - '
		+ 'action_reaction_attacked.gd:105-112 asserts exactly that, and require_miss reads it.')
	assert_eq(action.require_unit_to_be, ActionReactionAttacked.UNIT_ROLE.ATTACKER,
		'The Leoleth SWUNG; this is not a reaction to being attacked.')
	assert_true(action.require_miss, 'And only on a miss - a Reliable payout is the miss case.')
	assert_false(action.require_hit, 'Never on a hit.')
	assert_eq(action.weapon_types, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE],
		'MELEE only, which IS UnitAction.is_melee_weapon (unit_action.gd:549-553) spelled out.')
	assert_false(action.allow_basic, 'Not basic gear - the same filter the companion buff carries.')
	assert_false(action.allow_tech, 'And not a tech attack.')
	assert_false(action.require_defender_to_be_character,
		'NO character clause: the engine\'s own Reliable has none, so a missed swing at an object '
		+ 'pays out too.')
	assert_false(action.consumes_rxn, 'It spends no reaction point...')
	assert_eq(action.get_per_round_hard_limit(SpecificAction.create(leoleth, core_gear(), action)), 99,
		'...which is what makes the per-round hard limit 99 (action_reaction.gd:69), so EVERY missed '
		+ 'swing pays, not the first of the round.')
	assert_false(action.show_in_tooltip(core_gear().kit),
		'HIDDEN: the chip carries the card line, so this takes no ICON_TARGETS row.')
	# THE ARITHMETIC, POLLED DIRECTLY. activate() re-derives this, so a mutation to the gate alone
	# would be re-checked and abort quietly (Sluagh carry-forward 2).
	assert_eq(action.shortfall_for(leoleth, ContentLibrary.get_kit(LeolethFixture.MELEE_KIT).get_action()), 2,
		'A printed-Reliable-0 weapon is owed 2.')
	assert_eq(action.shortfall_for(leoleth, ContentLibrary.get_kit(LeolethFixture.RELIABLE_AXE).get_action()), 0,
		'A printed-Reliable-2 weapon is owed nothing.')
	assert_eq(action.shortfall_for(leoleth, ContentLibrary.get_kit(LeolethFixture.RELIABLE_SWORD).get_action()), 0,
		'And a printed-Reliable-3 weapon is owed nothing - the higher stands, never a sum.')

func test_the_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.buff_rage_reach.name', 'gear.buff_rage_reach.effect',
			'gear.cp_hydraulic_excess.action_reach_reliable.name']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.buff_rage_reach.name'), 'Reach', 'Named off the table.')
	assert_eq(X.tr('gear.buff_rage_reach.effect'),
		'Your melee weapons gain |+1 Threat| and |Reliable 2|.',
		'And the VISIBLE chip carries the WHOLE line - both halves - because the companion is hidden.')
	assert_eq(X.tr('gear.cp_hydraulic_excess.action_reach_reliable.name'), 'Reach',
		'The reaction has a NAME row and no effect row: it is hidden from the card, but the battle '
		+ 'log names it, and without this Translate.action falls through to the Kit\'s own '
		+ '"Hydraulic Excess".')

# ---------------------------------------------------------------- the threat

func test_a_melee_weapons_threat_reads_one_higher():
	LeolethFixture.arm_melee(leoleth)
	assert_eq(target_range(LeolethFixture.MELEE_KIT), 1, 'fixture: the printed threat is 1.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(target_range(LeolethFixture.MELEE_KIT), 2, 'And the chip makes it 2.')

func test_a_rifles_aim_range_is_untouched():
	# The subtype is THREAT_RANGE, and ranged_distance reads AIM_RANGE (action_attack_weapon.gd:180).
	# A buff wired to the wrong subtype would extend the rifle instead, and the melee test above would
	# still be green.
	LeolethFixture.arm_rifle(leoleth)
	assert_eq(target_range(LeolethFixture.MAIN_RIFLE), 10, 'fixture: the rifle reaches 10.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(target_range(LeolethFixture.MAIN_RIFLE), 10, 'And Reach does not touch it.')

# ---------------------------------------------------------------- the Reliable

func test_a_reliable_zero_melee_weapon_gains_reliable_two():
	LeolethFixture.arm_melee(leoleth)
	assert_eq(await damage_on_a_miss(LeolethFixture.MELEE_KIT), 0,
		'fixture: a miss with a Reliable-0 weapon lands nothing.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(await damage_on_a_miss(LeolethFixture.MELEE_KIT), 2,
		'With the chip, a miss lands exactly 2 - the shortfall reaction paid 2 - 0, ONCE. Twice '
		+ 'would read 4, and the printed floor stays 0 either way.')

func test_a_reliable_three_weapon_still_deals_three():
	# THE J MEASUREMENT (ruling 11, deferred to SP1). The engine ADDS where it reads the tag
	# (action_attack_weapon.gd:134), and the reaction would double-pay if its arithmetic were the
	# target rather than the shortfall. Lancer's Reliable does not stack; the higher stands.
	LeolethFixture.equip(leoleth, LeolethFixture.RELIABLE_SWORD)
	var sword:GearCore = leoleth.get_gear(LeolethFixture.RELIABLE_SWORD)
	assert_true(GearCore.is_valid(sword), 'fixture: the HEAVY sword reached the Heavy mount.')
	if not GearCore.is_valid(sword): return
	assert_eq(await damage_on_a_miss(LeolethFixture.RELIABLE_SWORD), 3,
		'fixture: its printed Reliable is 3.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(await damage_on_a_miss(LeolethFixture.RELIABLE_SWORD), 3,
		'And it is STILL 3 with the chip - not 5. The higher stands.')

func test_a_reliable_two_weapon_stays_at_two():
	# THE BOUNDARY. maxi(0, 2 - 2) is 0, and the reaction's gate refuses outright at zero. If the
	# arithmetic were `2 - printed` without the maxi, a printed-3 weapon would be owed -1 and this
	# test would still pass - which is why the printed-3 case above exists too.
	LeolethFixture.equip(leoleth, LeolethFixture.RELIABLE_AXE)
	assert_eq(await damage_on_a_miss(LeolethFixture.RELIABLE_AXE), 2,
		'fixture: its printed Reliable is 2.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(await damage_on_a_miss(LeolethFixture.RELIABLE_AXE), 2, 'And it stays 2.')

# ---------------------------------------------------------------- the three refusals

func test_a_ranged_miss_gets_no_shortfall():
	# THE MELEE CLAUSE. This weapon prints Reliable 0, so the printed clause cannot be what refuses
	# it - only weapon_types = [MELEE] can.
	LeolethFixture.equip(leoleth, RANGED_KIT)
	assert_true(GearCore.is_valid(leoleth.get_gear(RANGED_KIT)), 'fixture: the ranged weapon is aboard.')
	assert_eq(await damage_on_a_miss(RANGED_KIT), 0, 'fixture: its printed Reliable is 0.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(await damage_on_a_miss(RANGED_KIT), 0, 'And Reach does not reach it: still nothing.')

func test_a_melee_hit_gets_no_shortfall():
	# THE MISS CLAUSE. Measured before and after rather than against a literal, because a hit's
	# number carries the pilot's grit and the weapon's own dice.
	LeolethFixture.arm_melee(leoleth)
	var plain:int = await damage_on_a_hit(LeolethFixture.MELEE_KIT)
	assert_gt(plain, 0, 'fixture: a hit lands something.')
	await rage_to(LeolethFixture.FACE_REACH)
	assert_eq(await damage_on_a_hit(LeolethFixture.MELEE_KIT), plain,
		'A HIT is unchanged by Reach - the shortfall is the miss case and nothing else.')

func test_another_face_grants_no_shortfall():
	# THE CHIP CLAUSE, and a stronger control than "before any rage": the roll happened, a face
	# landed, the reaction is on the Kit - and it still does not fire.
	LeolethFixture.arm_melee(leoleth)
	await rage_to(LeolethFixture.FACE_SWIFT)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.REACH_CHIP), 'fixture: no Reach chip on a 2.')
	assert_eq(await damage_on_a_miss(LeolethFixture.MELEE_KIT), 0,
		'So a miss lands nothing: the shortfall is gated on the chip, not on the reaction existing.')

# ---------------------------------------------------------------- the lifetime

func test_both_chips_are_gone_at_the_next_turn_start():
	LeolethFixture.arm_melee(leoleth)
	await rage_to(LeolethFixture.FACE_REACH)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.REACH_CHIP), 'fixture: the visible chip.')
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.REACH_RELIABLE_BUFF), 'fixture: and the hidden one.')
	await rage_to(LeolethFixture.FACE_SWIFT)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.REACH_CHIP), 'Both are gone the next turn:')
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.REACH_RELIABLE_BUFF), 'the hidden one too.')
	assert_eq(target_range(LeolethFixture.MELEE_KIT), 1, 'And the threat is back to printed.')
	assert_eq(await damage_on_a_miss(LeolethFixture.MELEE_KIT), 0, 'And a miss lands nothing again.')
