# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA - the Leoleth's second sheet trait (SP1 Task 3).
#
#   "The Leoleth makes all ranged attacks at +2 difficulty."
#
# FORTY-THREE As. The Kit's id is the card's name downcased (design 1.1) and the name row is the
# string verbatim. Counted against the LCP: len == 43.
#
# ONE PERMANENT HIDDEN BuffWeaponTypeBonus, applied by the trait's PassiveBuffApplicator (ruling 4).
# "Ranged" is the ENGINE's own predicate: ActionAttackWeapon.is_difficulty_when_engaged is
# `weapon_type != MELEE` (action_attack_weapon.gd:254-255), so weapon_types_forbidden = [MELEE] with
# no positive filter is every other weapon type and nothing else.
#
# READ THROUGH AttackRoll.PreAttack, NOT through the buff list. The number the player sees is
# accuracy_mods_total() (attack_roll.gd:106-109), which is what roll_attack feeds to
# Dice.roll_d6_accuracy (:70). A test that only asserted "the buff is on the unit" would stay green
# through a wrong `to`, a wrong subtype or a wrong sign. The preview idiom is
# test_diversion_rail.preview's, verbatim.
#
# THE TARGET STANDS IN THE OPEN, on purpose: PreAttack.create folds COVER into the same mod list
# (attack_roll.gd:158-169), so a target behind anything would make these totals the map's and not the
# trait's.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_aaaa_difficulty.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

## FORTY-THREE As, uppercase - the card's name, verbatim, as the CSV row carries it.
const CARD_NAME := 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

const LEOLETH_TILE := Vector2i(4, 6)
## TWO TILES AWAY, DELIBERATELY NOT ADJACENT (IMPLEMENTER CORRECTION, Task 3).
## An adjacent target confounds every ranged total with the engine's own ENGAGED penalty:
## attack_roll.gd's PreAttack.create adds `UnitCondition.is_engaged(unit) and
## action.is_difficulty_when_engaged()` as a further -1, and is_engaged reads a CACHED status that a
## unit carries whenever a hostile is within engagement range - measured directly (a throwaway probe
## with this fixture at Vector2i(5, 6)): accuracy_mods_total() was -1 with no trait buff wired at
## all. That -1 would silently stack onto this trait's own -2, and shooting AT the Leoleth from
## adjacency would read -1 instead of the 0 `test_a_hostile_shooting_the_leoleth_is_untouched`
## expects, in both cases for a reason that has nothing to do with the 43-A trait. At this distance
## (2 tiles, still well inside the rifle's aim_range 10) the same probe reads 0. The melee case does
## not need adjacency either: `preview()` computes accuracy mods directly and never validates that
## the target is actually in melee range.
const TARGET_TILE := Vector2i(6, 6)

const PENALTY := -2

var game:Gamemaster
var leoleth:Unit
var target:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## What a roll by `shooter` at `against` with `weapon` would compute right now, without firing
## anything - test_diversion_rail.preview's idiom.
func preview(shooter:Unit, weapon:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, weapon, weapon.get_solo_action())
	return AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = against}))

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.AAAA_ID)
	assert_not_null(kit, 'The 43-A trait loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	assert_eq(String(LeolethFixture.AAAA_ID).length(), 46,
		'The id is mt_ plus FORTY-THREE As: 3 + 43 = 46 characters.')
	assert_true(GearCore.is_valid(leoleth.get_gear(LeolethFixture.AAAA_ID)),
		'And the live Leoleth carries it as gear.')
	# The buff really got hung. Without it nothing below can fire, and the failure would read as "the
	# filter is wrong" rather than "the buff was never applied".
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.AAAA_BUFF),
		'The trait\'s PassiveBuffApplicator hung the chip at the start of combat.')

func test_the_card_text_is_the_lcp_verbatim():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	var name_key := 'gear.%s.name' % LeolethFixture.AAAA_ID
	var effect_key := 'gear.%s.effect' % LeolethFixture.AAAA_ID
	assert_ne(translation.get_message(name_key), StringName(''), 'Our own artifact carries the name row.')
	assert_ne(translation.get_message(effect_key), StringName(''), 'And the effect row.')
	assert_eq(X.tr(name_key), CARD_NAME, 'The name is the 43-A string, verbatim.')
	assert_eq(X.tr(name_key).length(), 43, 'FORTY-THREE of them - count, do not eyeball.')
	assert_eq(X.tr(effect_key), 'The Leoleth makes all ranged attacks at +2 |difficulty|.',
		'And the effect row is the card with the one glossary pipe.')

func test_the_buff_is_wired_exactly_as_ruling_4_says():
	# DECLARATIVE, and every line here is a mutation target. The behavioural tests below cannot
	# separate `allow_basic` from the rest, because EVERY basic weapon in the player loadout is MELEE
	# (mw_ram, mw_grapple and mw_improvised_attack all set weapon_type = 2), so the flag has nothing to
	# catch today. It is set anyway - the card says "all ranged attacks" with no qualifier, and a mod
	# or a later modkit adding a basic ranged weapon should be caught without an edit here.
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.AAAA_BUFF)
	assert_not_null(buff, '%s loads as a Buff through ContentLibrary.' % LeolethFixture.AAAA_BUFF)
	if buff == null: return
	assert_true(buff is BuffWeaponTypeBonus, 'It is a BuffWeaponTypeBonus.')
	if not (buff is BuffWeaponTypeBonus): return
	assert_eq(buff.to, Buff.TO.ATTACK_ROLL, 'to = attack_roll: the ATTACKER\'s own channel.')
	assert_eq(buff.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'The subtype is accuracy.')
	assert_eq(buff.bonus_value, PENALTY, 'And the value is -2, which is +2 difficulty.')
	assert_eq(buff.weapon_types_forbidden, [Lancer.WEAPON_TYPE.MELEE] as Array[Lancer.WEAPON_TYPE],
		'MELEE is forbidden and nothing else is filtered - the engine\'s own "ranged".')
	assert_true(buff.weapon_types.is_empty(), 'No positive filter, so every non-melee type is caught.')
	assert_true(buff.allow_basic, 'Basic gear is caught too - "all ranged attacks".')
	assert_true(buff.hide_from_player, 'Hidden: the card is the trait, not a chip on the token.')
	assert_eq(buff.until, Lancer.UNTIL.MANUAL, 'And permanent - it is a frame trait.')

# ---------------------------------------------------------------- the measurement

func test_a_rifle_attack_is_at_two_difficulty():
	var rifle:GearCore = LeolethFixture.arm_rifle(leoleth)
	assert_eq(preview(leoleth, rifle, target).accuracy_mods_total(), PENALTY,
		'A rifle shot by the Leoleth is at -2 accuracy.')

func test_a_melee_attack_is_untouched():
	var blade:GearCore = LeolethFixture.arm_melee(leoleth)
	assert_eq(preview(leoleth, blade, target).accuracy_mods_total(), 0,
		'A melee swing is at 0 - weapon_types_forbidden catches it.')

func test_a_tech_attack_is_untouched():
	# BuffWeaponType.check_if_passive_applies refuses anything that is not an ActionAttackWeapon at its
	# very first line (buff_weapon_type.gd:35), so this needs no clause of its own in the .tres - which
	# is exactly the claim this test makes. ms_fragment_signal is basic gear and needs no equipping.
	var tech:GearCore = leoleth.get_gear(LeolethFixture.TECH_ID)
	assert_true(GearCore.is_valid(tech), 'fixture: the basic tech attack is in the loadout.')
	if not GearCore.is_valid(tech): return
	assert_eq(preview(leoleth, tech, target).accuracy_mods_total(), 0,
		'A tech attack is at 0 - the buff is a WEAPON buff.')

func test_a_hostile_shooting_the_leoleth_is_untouched():
	# to = attack_roll is the ATTACKER's channel: PreAttack.create collects it from `unit`
	# (attack_roll.gd:134) and collects attack_roll_incoming from the DEFENDER (:135). A buff wired to
	# the wrong one would make the Leoleth harder to hit instead of worse at shooting, and every test
	# above would still be green.
	var rifle:GearCore = LeolethFixture.arm_rifle(target)
	assert_eq(preview(target, rifle, leoleth).accuracy_mods_total(), 0,
		'Shooting AT the Leoleth is at 0: the penalty is its own, not its targets\'.')

func test_the_penalty_really_reaches_the_d20():
	# THE END-TO-END HALF. accuracy_mods_total is what roll_attack hands to Dice.roll_d6_accuracy
	# (attack_roll.gd:70), and a NEGATIVE count makes roll_and_sum multiply the result by signi(count)
	# (dice.gd:65) - so a queued 6 becomes -6. The dummy's evasion is 10 and the Leoleth has no flat
	# bonus, so a base 13 hits on its own and misses once the die lands.
	#
	# THE QUEUE IS WRITTEN OUT IN FULL because the two paths pop different numbers of entries: with the
	# penalty the roll pops [d20, accuracy die, damage die], and without it Dice.roll_d6_accuracy
	# returns 0 WITHOUT rolling (dice.gd:86-88) and the damage die would be the SECOND entry. The
	# control below therefore writes the same number in both of the first two slots, which is the
	# Sluagh close's carry-forward #3.
	var rifle:GearCore = LeolethFixture.arm_rifle(leoleth)
	assert_eq(preview(leoleth, rifle, target).accuracy_mods_total(), PENALTY, 'fixture: the -2 is live.')
	LeolethFixture.queue([13, 6, 3])
	await SpecFactory.use_solo(game, leoleth, LeolethFixture.MAIN_RIFLE, target)
	assert_eq(target.current_damage(), 2,
		'A 13 that would have hit misses, and the rifle\'s Reliable 2 is all that lands.')
