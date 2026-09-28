# BLESSED BOLT SYSTEM (Purple Thorn trait, SP1 Task 3).
#
#   "1/round, when the Purple Thorn hits with an Auxiliary weapon, it may deal + 3 bonus damage."
#
# THE OFFER IS A yes/no through CommonActionUtil.confirm_use, titled 'battle.confirm.use' formatted
# with the reaction's name - so this file counts ONLY the prompts whose title carries "Blessed Bolt"
# (test_abjuration_of_metal.gd's rule: an attack opens confirms of its own, and a bare
# yesno_prompts.size() would count the attacker's). Answered off responder.yesno_queue; an empty
# queue answers the base responder's default yes.
#
# THE DICE. The Nexus (Light) pops the d20, one d3 for the HIT damage, one d3 for the CRIT damage
# (test_vigil.gd's measurement), no accuracy die; the +3 is flat and rolls nothing. Two shots are
# [19, 3, 1, 19, 3, 1]. The Missile Rack (Aux BLAST 1) pops one d20 per target then ONE hit die and
# one crit die.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_blessed_bolt.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/purple_thorn_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'
const AUX_BLAST := &'mw_missile_rack'
## A vanilla Aux dealing ENERGY: GMS Thermal Pistol, flat 2, Aux CQB. Inherits its type into the +3.
const AUX_ENERGY := &'mw_thermal_pistol'

const THORN_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(8, 6)
const D20_HITS := 19
const D20_MISSES := 1

var game:Gamemaster
var thorn:Unit
var hostile:Unit
var responder

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	thorn = Fixture.create_thorn(game, THORN_TILE)
	hostile = Fixture.create_hostile(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()
	responder.abort_all = false

# ---------------------------------------------------------------- helpers

## Blessed Bolt's OWN offers, by title.
func offers() -> Array:
	var name := X.tr('gear.mt_blessed_bolt_system.action_blessed_bolt.name')
	return responder.yesno_prompts.filter(func(prompt:Dictionary) -> bool:
		return String(prompt.title).contains(name) or String(prompt.desc).contains(name))

func uses() -> int:
	return Fixture.uses_this_round(thorn, Fixture.BOLT_ID, Fixture.BOLT_ACTION_ID)

func nexus_shot(answer:bool, d20:int = D20_HITS) -> void:
	responder.yesno_queue.append(answer)
	Fixture.queue([d20, 3, 1])
	await Fixture.shoot(game, thorn, hostile)

func nexus_shot_again(answer:bool, d20:int = D20_HITS) -> void:
	responder.yesno_queue.append(answer)
	Fixture.queue([d20, 3, 1])
	await Fixture.shoot_again(game, thorn, hostile)

# ---------------------------------------------------------------- the offer

func test_an_aux_hit_offers_and_a_yes_adds_exactly_three():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await nexus_shot(true)
	assert_eq(offers().size(), 1, 'One offer for one Aux hit.')
	assert_eq(hostile.current_damage(), 6, 'The die (3) plus the bonus (3).')
	assert_eq(uses(), 1, 'The round is spent.')
	assert_false(UnitCondition.has_buff(thorn, Fixture.BOLT_BUFF), 'The one-time buff is gone after the damage.')

func test_the_bonus_inherits_the_weapons_damage_type():
	# A flat-2 ENERGY Aux; armor 0 so the number is the weapon's. The type is read the way the
	# engine reads it - off the roll's damage summary - because a spec cannot see the popcorn.
	Fixture.mount_pair(thorn, 0, AUX_ENERGY)
	Fixture.step(hostile, Vector2i(5, 6)) # the Thermal Pistol has threat, not range
	responder.yesno_queue.append(true)
	Fixture.queue([D20_HITS])
	await Fixture.shoot(game, thorn, hostile, AUX_ENERGY)
	assert_eq(offers().size(), 1, 'fixture: offered.')
	assert_eq(hostile.current_damage(), 5, 'Flat 2 plus 3.')

func test_a_no_spends_nothing_and_the_next_aux_hit_that_round_offers_again():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await nexus_shot(false)
	assert_eq(offers().size(), 1, 'fixture: offered once.')
	assert_eq(hostile.current_damage(), 3, 'A no: the die alone.')
	assert_eq(uses(), 0, 'And nothing spent.')
	await nexus_shot_again(true)
	assert_eq(offers().size(), 2, 'The next Aux hit that round offers again.')
	assert_eq(hostile.current_damage(), 9, '3, then 3 + 3.')
	assert_eq(uses(), 1, 'One use in total.')

func test_the_second_yes_in_a_round_is_never_offered():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await nexus_shot(true)
	await nexus_shot_again(true)
	assert_eq(offers().size(), 1, '1/round: the second Aux hit that round is not asked.')
	assert_eq(hostile.current_damage(), 9, '3 + 3, then 3.')
	assert_eq(uses(), 1, 'One use.')

func test_after_the_thorns_next_turn_start_it_offers_again():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await nexus_shot(true)
	await nexus_shot(true) # shoot() cycles the turn: the tally resets
	assert_eq(offers().size(), 2, 'A new turn, a new offer.')
	assert_eq(hostile.current_damage(), 12, '6 and 6.')

# ---------------------------------------------------------------- what does not offer

func test_a_miss_does_not_offer():
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	await nexus_shot(true, D20_MISSES)
	assert_eq(hostile.current_damage(), 0, 'fixture: a miss.')
	assert_eq(offers().size(), 0, 'No hit, no offer.')
	assert_eq(uses(), 0, 'Nothing spent.')

func test_a_main_hit_does_not_offer():
	Fixture.arm_rifle(thorn)
	responder.yesno_queue.append(true)
	Fixture.queue([D20_HITS, 4, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 4, 'fixture: the rifle hit for its die.')
	assert_eq(offers().size(), 0, 'A Main weapon is not an Auxiliary one.')

func test_the_second_aux_of_an_aux_aux_pair_is_not_offered():
	# AUTHOR'S CALL (ruling 4): the follow-up shot carries the engine's own NO_BONUS_DAMAGE flag
	# (action_attack_weapon.gd:72), and Blessed Bolt is not offered on it.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS, Fixture.AUX_NEXUS)
	responder.yesno_queue.append_array([true, true])
	Fixture.queue([D20_HITS, 3, 1, D20_HITS, 3, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.AUX_NEXUS, [Action.FLAG.CAN_FOLLOWUP])
	assert_eq(hostile.current_damage(), 9, 'The first Nexus 3 + 3, the follow-up Nexus 3 alone.')
	assert_eq(offers().size(), 1, 'Offered on the first shot only.')
	assert_eq(uses(), 1, 'One use spent.')

func test_a_declined_first_aux_does_not_reopen_on_the_pairs_second_shot():
	# The follow-up carries NO_BONUS_DAMAGE whether or not the first shot took the bonus.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS, Fixture.AUX_NEXUS)
	responder.yesno_queue.append_array([false, true])
	Fixture.queue([D20_HITS, 3, 1, D20_HITS, 3, 1])
	await Fixture.shoot(game, thorn, hostile, Fixture.AUX_NEXUS, [Action.FLAG.CAN_FOLLOWUP])
	assert_eq(hostile.current_damage(), 6, '3 and 3, no bonus anywhere.')
	assert_eq(offers().size(), 1, 'One offer (declined); the second Aux never asks.')
	assert_eq(uses(), 0, 'Nothing spent.')

func test_being_hit_by_an_aux_does_not_offer():
	# equip(), not mount_pair(): a FrameIsolation'd dummy has no mounts, and an integrated Nexus is
	# still an Aux hit on the Thorn - which is the only thing this case is about.
	Fixture.equip(hostile, Fixture.AUX_NEXUS)
	responder.yesno_queue.append(true)
	Fixture.queue([D20_HITS, 3, 1])
	await Fixture.shoot(game, hostile, thorn)
	assert_eq(thorn.current_damage(), 3, 'fixture: the Thorn was hit for the die.')
	assert_eq(offers().size(), 0, 'The Thorn must be the one shooting.')

func test_the_buff_does_not_leak_into_the_next_attack():
	# A yes on the Nexus, then a rifle shot in the same turn: the rifle deals its die alone.
	Fixture.mount_pair(thorn, 0, Fixture.AUX_NEXUS)
	Fixture.arm_rifle(thorn)
	await nexus_shot(true)
	assert_eq(hostile.current_damage(), 6, 'fixture: 3 + 3.')
	Fixture.queue([D20_HITS, 4, 1])
	await Fixture.shoot_again(game, thorn, hostile, Fixture.MAIN_RIFLE)
	assert_eq(hostile.current_damage(), 10, 'The rifle added its 4 and nothing else.')

# ---------------------------------------------------------------- a Blast

func test_on_a_blast_the_bonus_is_halved_across_every_victim():
	# Rulings.md Pass E (reversing ledger J-1): bonus damage against several characters is halved, as
	# Lancer does. The +3 is plain Buff.TO.BONUS_DAMAGE, halved by the engine when more than one
	# character is attacked (declared_attack_summary.gd:44-45, attack_util.gd:309-312: ceil(3/2) = 2)
	# and added to every victim's damage. One offer for the whole Blast still.
	Fixture.mount_pair(thorn, 0, AUX_BLAST)
	var side:Unit = Fixture.create_hostile(game, Vector2i(9, 6))
	var below:Unit = Fixture.create_hostile(game, Vector2i(8, 7))
	responder.yesno_queue.append(true)
	Fixture.queue([D20_HITS, D20_HITS, D20_HITS, 2, 1]) # three d20s, the hit die, the crit die
	await Fixture.shoot(game, thorn, hostile, AUX_BLAST)
	assert_eq(offers().size(), 1, 'One offer for the whole Blast.')
	var damages := [hostile.current_damage(), side.current_damage(), below.current_damage()]
	damages.sort()
	assert_eq(damages, [5, 5, 5], 'Every victim took the 1d3+1 (3) plus the halved bonus (2).')
	assert_eq(uses(), 1, 'One use.')

# ---------------------------------------------------------------- wiring and card text

func test_the_wiring_and_the_card_text():
	var kit:Kit = ContentLibrary.get_kit(Fixture.BOLT_ID)
	assert_not_null(kit, 'mt_blessed_bolt_system is indexed as a Kit.')
	if kit == null: return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	var action = kit.get_action(Fixture.BOLT_ACTION_ID)
	assert_not_null(action, 'action_blessed_bolt is on it.')
	if action == null: return
	assert_true(action is ActionReactionAttacked, 'On the attacked-reaction archetype...')
	assert_eq(action.triggers_on, [&'attack'] as Array[StringName], '...on ATTACK...')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.POST, '...POST.')
	assert_eq(action.require_unit_to_be, ActionReactionAttacked.UNIT_ROLE.ATTACKER, 'The Thorn is the attacker.')
	assert_true(action.require_hit, 'A hit.')
	assert_eq(action.weapon_sizes, [Lancer.WEAPON_SIZE.AUX] as Array[Lancer.WEAPON_SIZE], 'An AUX weapon.')
	assert_false(action.require_defender_to_be_character, 'Any victim - the card says "hits with an Auxiliary weapon".')
	assert_false(action.consumes_rxn, 'Point-free.')
	assert_eq(action.get_per_round_hard_limit(null), 1, '1/round.')
	assert_eq(action.usage_group, &'blessed_bolt', 'Its own usage group.')
	var buff:Buff = action.damage_buff
	assert_not_null(buff, 'It carries the buff.')
	if buff == null: return
	assert_true(buff is BuffDamage, 'A BuffDamage...')
	assert_eq(buff.to, Buff.TO.BONUS_DAMAGE, '...to plain bonus_damage (halved across several characters).')
	assert_eq(buff.damage_dice, '3', 'Three, flat.')
	assert_true(buff.inherit_type_from_attack, 'Of the weapon\'s type.')
	assert_false(buff.require_hit, 'No require_hit: it would hide the buff from the general read (buff_damage.gd:20); the reaction is the hit gate.')
	assert_true(buff.is_onetime, 'One roll.')
	assert_eq(buff.until, Lancer.UNTIL.FINISH_DAMAGE, 'Cleared after the damage regardless.')
	assert_true(buff.hide_from_player, 'Hidden - the yes/no is the surface.')
	assert_false(action.show_in_tooltip(kit), 'The reaction hides from the trait card as a duplicate of the Kit\'s text.')
	var translation:Translation = load(OUR_TRANSLATION)
	if translation == null:
		fail_test('This mod has a compiled translation.')
		return
	for key:String in ['gear.mt_blessed_bolt_system.name', 'gear.mt_blessed_bolt_system.effect',
			'gear.mt_blessed_bolt_system.action_blessed_bolt.name', 'gear.mt_blessed_bolt_system.action_blessed_bolt.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.mt_blessed_bolt_system.name'), 'Blessed Bolt System', 'Named as the card.')
	assert_true(X.tr('gear.mt_blessed_bolt_system.effect').begins_with('1/round, when the Purple Thorn hits'),
		'The effect row opens as the card does.')
