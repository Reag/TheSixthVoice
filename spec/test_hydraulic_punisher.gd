# HYDRAULIC PUNISHER (Gloire SP1, design rulings 3-4): "1/round, when the Gloire knocks a hostile
# character Prone, they become Impaired until they clear Prone."
#
# THE PROBE FIRST (design §1): a REAL Ram through SpecFactory.use_solo knocks a hostile Prone and the
# reaction resolves the Gloire as the applier through UnitRelation.get_origin_unit_for_source, off the
# virtual event_unit_apply_status's `string` (mw_ram's GearCore id). "Never fired" and "the source did
# not resolve" look the same, so the first test asserts the Prone landed BEFORE it asserts the buff.
#
# Every Ram here lands on an evasion -10 dummy with the d20 fixed to 10 (gloire_fixture.ram), so a
# miss is never the reason a test is red. The Ram's Knockback 1 opens a reticle the fixture's
# responder answers.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_hydraulic_punisher.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')

## Size 2 at (4,4) covers (4..5, 4..5). Targets sit adjacent to its east edge so the reach rule
## (Extended Zone Control's, its own spec) is not what these tests lean on.
const GLOIRE_TILE := Vector2i(4, 4)
const FIRST_TILE := Vector2i(6, 4)
const SECOND_TILE := Vector2i(6, 6)
## A second, plain PLAYER rammer and its own hostile, well away from the Gloire.
const RAMMER_TILE := Vector2i(10, 8)
const OTHER_HOSTILE_TILE := Vector2i(11, 8)

var game:Gamemaster
var responder
var watcher
var gloire:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	gloire = Fixture.create_gloire(game, GLOIRE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func is_impaired(unit:Unit) -> bool:
	return unit.has_status(Lancer.STATUS.IMPAIRED)

# ---------------------------------------------------------------- the probe

func test_probe_a_real_ram_by_the_gloire_impairs_the_hostile_it_floors() -> void:
	var hostile := Fixture.create_dummy(game, FIRST_TILE)
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'fixture: standing to begin with.')
	await Fixture.ram(game, gloire, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.PRONE), 'the Ram hit and the Prone landed (else nothing below means anything).')
	assert_true(Fixture.is_punished(hostile), 'PROBE: the source resolved to the Gloire and the reaction fired - the target carries buff_hydraulic_punisher.')
	assert_true(is_impaired(hostile), 'and the buff IS the Impaired (applies_statuses).')
	assert_eq(UnitCondition.get_buffs(hostile, Fixture.PUNISHER_BUFF).size(), 1, 'exactly one copy.')
	assert_eq(Fixture.punisher_uses(gloire), 1, 'the round is spent.')

# ---------------------------------------------------------------- "when the Gloire knocks"

func test_a_prone_another_unit_applied_does_not_fire() -> void:
	var rammer := SpecFactory.create_unit(game.map, RAMMER_TILE)
	var hostile := Fixture.create_dummy(game, OTHER_HOSTILE_TILE)
	await Fixture.ram(game, rammer, hostile)
	assert_true(hostile.has_status(Lancer.STATUS.PRONE), 'the other rammer floored it.')
	assert_false(Fixture.is_punished(hostile), 'RULED: the Gloire did not knock it down, so no Impaired.')
	assert_false(is_impaired(hostile), 'not Impaired.')
	assert_eq(Fixture.punisher_uses(gloire), 0, 'and the round is not spent.')

func test_a_prone_the_gloire_applies_to_an_ally_does_not_fire() -> void:
	var ally := Fixture.create_dummy(game, FIRST_TILE, -10, Faction.PLAYER)
	if is_instance_valid(SpecFactory.current_responder): SpecFactory.current_responder.choose_yesnos = true
	await Fixture.ram(game, gloire, ally)
	assert_true(ally.has_status(Lancer.STATUS.PRONE), 'the Gloire floored its own ally.')
	assert_false(Fixture.is_punished(ally), 'RULED: "a hostile character" - an ally is not punished.')
	assert_false(is_impaired(ally), 'not Impaired.')

# ---------------------------------------------------------------- "1/round"

func test_a_second_hostile_floored_in_the_same_round_gets_nothing_and_a_new_round_re_arms() -> void:
	var first := Fixture.create_dummy(game, FIRST_TILE)
	var second := Fixture.create_dummy(game, SECOND_TILE)
	await Fixture.ram(game, gloire, first)
	assert_true(Fixture.is_punished(first), 'the first knockdown is punished.')
	await Fixture.ram_free(game, gloire, second) # a second PAID Ram this turn is refused by the no-repeat rule
	assert_true(second.has_status(Lancer.STATUS.PRONE), 'the second Ram floored its target too.')
	assert_false(Fixture.is_punished(second), 'RULED: 1/round - the second knockdown this round gets nothing.')
	assert_false(is_impaired(second), 'not Impaired.')
	await Fixture.cycle_turn(game, gloire)
	assert_eq(Fixture.punisher_uses(gloire), 0, 'a new round re-arms the trait.')
	await Fixture.ram(game, gloire, second)
	assert_true(Fixture.is_punished(second), 'a Prone landing on an already-Prone hostile still counts, once the round is fresh.')
	assert_true(is_impaired(second), 'Impaired now.')

func test_flooring_an_already_punished_hostile_again_neither_stacks_nor_spends_the_round() -> void:
	var first := Fixture.create_dummy(game, FIRST_TILE)
	var second := Fixture.create_dummy(game, SECOND_TILE)
	await Fixture.ram(game, gloire, first)
	await Fixture.cycle_turn(game, gloire)
	await Fixture.ram(game, gloire, first)
	assert_eq(UnitCondition.get_buffs(first, Fixture.PUNISHER_BUFF).size(), 1, 'still exactly one copy on a target floored twice.')
	assert_eq(Fixture.punisher_uses(gloire), 0, 'and the no-op did not spend the round,')
	await Fixture.ram_free(game, gloire, second)
	assert_true(Fixture.is_punished(second), 'so the next hostile floored this round is punished.')

# ---------------------------------------------------------------- "until they clear Prone"

func test_standing_up_clears_the_impaired() -> void:
	var hostile := Fixture.create_dummy(game, FIRST_TILE)
	await Fixture.ram(game, gloire, hostile)
	assert_true(is_impaired(hostile), 'fixture: Impaired while down.')
	await SpecFactory.start_turn(game, hostile)
	await SpecFactory.use_solo(game, hostile, Fixture.STAND_UP)
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'it stood up.')
	assert_false(Fixture.is_punished(hostile), 'RULED: the buff dropped itself when the Prone cleared.')
	assert_false(is_impaired(hostile), 'and the Impaired went with it.')

func test_a_prone_still_held_from_a_second_source_keeps_the_impaired() -> void:
	var hostile := Fixture.create_dummy(game, FIRST_TILE)
	await Fixture.ram(game, gloire, hostile)
	var ram_source:StringName = gloire.get_gear(Fixture.RAM).persistent_id
	assert_true(UnitCondition.has_status(hostile, Lancer.STATUS.PRONE, ram_source), 'fixture: the Prone is the Ram\'s.')
	SpecFactory.apply(hostile, Lancer.STATUS.PRONE, Lancer.UNTIL.MANUAL, 'somebody_else')
	# A SOURCE-SPECIFIC clear of the Ram's copy alone, through vanilla's own event (naga_fixture's
	# clear_by_ability shape): fires one statuses_changed POST while the other copy survives.
	await game.execute_event(&'event_unit_clear_status', {unit = hostile, category = Lancer.STATUS.PRONE, string = ram_source})
	assert_true(hostile.has_status(Lancer.STATUS.PRONE), 'still Prone from the other source.')
	assert_true(Fixture.is_punished(hostile), 'RULED: "until they clear Prone" - they have not.')
	assert_true(is_impaired(hostile), 'still Impaired.')
	await game.execute_event(&'event_unit_clear_status', {unit = hostile, category = Lancer.STATUS.PRONE, string = &'somebody_else'})
	assert_false(hostile.has_status(Lancer.STATUS.PRONE), 'now standing.')
	assert_false(Fixture.is_punished(hostile), 'and the Impaired lifts with the last Prone.')
	assert_false(is_impaired(hostile), 'not Impaired.')

# ---------------------------------------------------------------- the card

func test_the_reaction_is_hidden_from_the_card_and_the_kit_is_a_trait() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.PUNISHER_ID)
	assert_true(Kit.is_valid(kit), 'mt_hydraulic_punisher is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'a trait.')
	assert_eq(kit.actions.size(), 1, 'one action: the hidden reaction.')
	if kit.actions.is_empty(): return
	var reaction:Action = kit.actions[0]
	assert_true(reaction is ActionReaction, 'an ActionReaction.')
	assert_false(reaction.show_in_tooltip(kit), 'hidden from the card (localization_key_override).')
	assert_false((reaction as ActionReaction).consumes_reaction(), 'not a reaction point: "1/round", not "Reaction".')
	assert_eq(reaction.get_per_round_hard_limit(SpecificAction.create(gloire, gloire.get_gear(Fixture.PUNISHER_ID), reaction)), 1, '1/round.')
	for key:String in ['gear.mt_hydraulic_punisher.name', 'gear.mt_hydraulic_punisher.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mt_hydraulic_punisher.effect'),
		'1/round, when the Gloire knocks a hostile character |Prone|, they become |Impaired| until they clear |Prone|.',
		'the card is the LCP verbatim.')
