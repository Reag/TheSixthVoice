# ALL SYSTEMS RED - the passive half of HYDRAULIC EXCESS (SP1 Task 5).
#
#   "When you would structure, you do not take any overflow damage and gain the benefits of hard
#    cover until the end of the current turn."
#
# A HIDDEN, POINT-FREE ActionReactionSelf ON structured / PRE (ruling 6). The TIMING is the whole
# ability and it was measured in Task 0, not here: spec/test_spike_structured_pre_under_talents.gd
# (commit 208d557) put a knockoff PRE reaction on a 4-structure, 8 HP dummy, hit it past zero, and
# read the new bar at exactly full with the reaction and at 3 without - under the talents mod's
# wholesale replacement of event_unit_structure.execute, which leaves execute_preblock alone. THAT
# FILE IS FROZEN AND THIS ONE DOES NOT ABSORB IT; the control case lives there.
#
# OVERFLOW IS THE NEGATIVE HP. event_unit_structure.execute decrements structure (:41) and then folds
# (:44): health = mini(health + get_health_max(), get_health_max()). A unit at -4 comes out at 4;
# zeroing the -4 first makes it come out at 8. Nothing else in the engine is called "overflow".
#
# THE DICE. event_unit_damage rolls nothing for a bare number, and make_structure_check rolls
# `structure_max - structure_current` d6 and takes the LOWEST (event_unit_structure.gd:98-104) - ONE
# die at the first structure, TWO at the second. A 5 or 6 is IMPAIRED (:108-111), which raises only an
# informational brochure the stock responder answers; 2-4 rolls ANOTHER d6 and destroys gear through a
# pick menu, and a 1 stuns. LeolethFixture.structure() cheats one 6; the two-structure test queues
# its own.
#
# NO TEST HERE COUNTS PROMPTS, because a structure event raises the brochure and, on the way in,
# vanilla ms_brace can raise a yes/no of its own once incoming damage clears half the frame's HP
# (action_brace.gd:44-51) - which 13 against an 8 HP frame certainly does. That is fine as long as
# nothing counts.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_all_systems_red.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const LEOLETH_TILE := Vector2i(4, 6)
## Well inside the rifle's Range 10, well outside anything's threat.
const SHOOTER_TILE := Vector2i(10, 6)

## 13 against 8 HP and armor 1 lands 12 and leaves the bar at -4. LeolethFixture.structure's default.
const BIG_HIT := 13
const OVERFLOW := 4

var game:Gamemaster
var leoleth:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear() -> GearCore:
	return leoleth.get_gear(LeolethFixture.CORE_ID)

func asr() -> ActionReactionSelf:
	var gear:GearCore = core_gear()
	if not GearCore.is_valid(gear): return null
	for action:Action in gear.kit.actions:
		if action.get_id() == LeolethFixture.ASR_ID: return action
	return null

# ---------------------------------------------------------------- the wiring

func test_the_core_kit_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.CORE_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % LeolethFixture.CORE_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'A core system is a trait Kit, not equippable gear.')
	assert_true(GearCore.is_valid(core_gear()), 'And the live Leoleth carries it as gear.')
	# CARRIES, not "has exactly one action": Tasks 6, 10 and 11 append three more, and Task 13 pins
	# the final list.
	assert_not_null(asr(), 'It carries %s.' % LeolethFixture.ASR_ID)

func test_the_reaction_is_wired_as_ruling_6_says():
	var action := asr()
	assert_not_null(action, 'fixture: the reaction is on the Kit.')
	if action == null: return
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.STRUCTURED] as Array[StringName],
		'It triggers on `structured` and nothing else.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE,
		'PRE - the ONE thing this ability is. Task 0 measured that execute_preblock (:33-34) runs '
		+ 'before the fold at :44, and that the talents resident does not override it.')
	assert_false(action.consumes_rxn, 'It spends no reaction point: it is not a reaction the player takes.')
	assert_false(action.counts_as_free_action, 'And it is not a free action either - it is automatic.')
	assert_eq(action.get_per_round_hard_limit(SpecificAction.create(leoleth, core_gear(), action)), 99,
		'No per-round limit: a point-free reaction defaults to 99 (action_reaction.gd:69), and '
		+ 'the card fires on EVERY structure.')
	assert_false(action.show_in_tooltip(ContentLibrary.get_kit(LeolethFixture.CORE_ID)),
		'Hidden: the core Kit\'s own effect row IS this card, so a second line would say it twice.')

func test_the_cover_chip_is_wired_as_hard_cover():
	var buff:Buff = ContentLibrary.get_buff(LeolethFixture.ASR_COVER_CHIP)
	assert_not_null(buff, '%s loads as a Buff.' % LeolethFixture.ASR_COVER_CHIP)
	if buff == null: return
	assert_true(buff is BuffCover, 'It is a BuffCover.')
	if not (buff is BuffCover): return
	assert_eq(buff.cover, Lancer.COVER.HARD, 'HARD cover, which is Lancer.COVER 2.')
	assert_eq(buff.to, Buff.TO.COVER, 'to = cover, which is what CoverCalculator reads.')
	assert_true(buff.to_incoming_attacks, 'And it shelters the HOLDER, not the holder\'s targets.')
	assert_eq(buff.until, Lancer.UNTIL.END_OF_THIS_TURN,
		'until = END_OF_THIS_TURN: event_turn_end ends it for ALL units at :40, which is the card\'s '
		+ '"the current turn" whoever owns that turn.')
	assert_false(buff.hide_from_player, 'VISIBLE: it is the only sign the passive fired.')

func test_the_cards_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_hydraulic_excess.name', 'gear.cp_hydraulic_excess.effect',
			'gear.buff_all_systems_red_cover.name', 'gear.buff_all_systems_red_cover.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
	assert_eq(X.tr('gear.cp_hydraulic_excess.name'), 'Hydraulic Excess', 'The core system\'s name.')
	assert_eq(X.tr('gear.buff_all_systems_red_cover.name'), 'ALL SYSTEMS RED',
		'The chip wears the passive\'s own name, in the card\'s capitals.')
	# THE KIT'S EFFECT ROW IS THE PASSIVE, VERBATIM - which is also why the reaction is hidden.
	assert_true(X.tr('gear.cp_hydraulic_excess.effect').contains('you do not take any overflow damage'),
		'And the Kit\'s effect row is ALL SYSTEMS RED, verbatim.')

# ---------------------------------------------------------------- the overflow

func test_structuring_carries_no_overflow():
	# THE CARD. The control - the same event on a unit with no such reaction - is Task 0's probe, which
	# measured 3 where 8 was expected. This is the production half of that measurement.
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(), 'fixture: full HP.')
	assert_eq(leoleth.core.current.structure, 4, 'fixture: full structure.')
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_eq(leoleth.core.current.structure, 3, 'One structure was lost.')
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(),
		'And the new bar is EXACTLY full: the %d past zero was zeroed before the fold.' % OVERFLOW)

func test_it_fires_on_the_second_structure_too():
	# "WHEN YOU WOULD STRUCTURE" has no once-per-scene in it, and get_per_round_hard_limit is 99 for a
	# point-free reaction (action_reaction.gd:69), so nothing in the engine would stop it either.
	#
	# THE SECOND CHECK ROLLS TWO DICE, not one: make_structure_check's count is
	# structure_max - structure_current AFTER the decrement (event_unit_structure.gd:99), so it is 1 at
	# the first structure and 2 at the second, and it takes the LOWEST (:102). Both are queued as 6 so
	# both outcomes are IMPAIRED.
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(), 'fixture: the first one was clean.')
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign([6, 6] as Array[int])
	await game.execute_event(&'event_unit_damage', {
		unit = leoleth, number = BIG_HIT, category = Lancer.DAMAGE_TYPE.KINETIC,
	})
	assert_eq(leoleth.core.current.structure, 2, 'A second structure was lost.')
	assert_eq(leoleth.core.current.health, leoleth.get_health_max(),
		'And the second bar is full too - the reaction is not once per anything.')

# ---------------------------------------------------------------- the cover

func test_the_hard_cover_chip_lands_when_it_structures():
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP),
		'fixture: no chip before anything happens.')
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP),
		'Structuring hangs the hard-cover chip.')

func test_a_ranged_attack_against_the_structured_leoleth_reads_hard_cover():
	# THE HALF THAT MATTERS. has_buff says the chip is on the unit; determine_cover says the engine's
	# own cover pipeline reads it. CoverCalculator.determine_cover asks the DEFENDER's and the
	# ATTACKER's Buff.TO.COVER buffs and nobody else's (cover_calculator.gd:56-62), and
	# PreAttack.create folds the result into the accuracy mods with Lancer.cover_modifier, which is
	# `int(cover) * -1` (lancer.gd:154) - so HARD is -2.
	var shooter:Unit = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	var rifle:GearCore = LeolethFixture.arm_rifle(shooter)
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.NONE,
		'fixture: standing in the open, before anything, it has no cover.')
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.HARD,
		'After structuring it has HARD cover against that shooter.')
	var specific := SpecificAction.create(shooter, rifle, rifle.get_solo_action())
	var pre := AttackRoll.PreAttack.create(Context.clone(specific.to_context(), {target_unit = leoleth}))
	assert_eq(pre.cover, Lancer.COVER.HARD, 'And the roll itself computes HARD.')
	assert_eq(pre.accuracy_mods_total(), -2, 'Which is -2 on the attacker - Lancer.cover_modifier.')

func test_the_cover_chip_is_gone_after_the_current_turn_ends():
	# "UNTIL THE END OF THE CURRENT TURN", whoever owns that turn. Lancer.UNTIL.END_OF_THIS_TURN is
	# ended for ALL units by event_turn_end.execute at :40, in a loop over map.get_all_units() - NOT
	# only for the unit whose turn it is. So a Leoleth structured on an ENEMY's turn loses the cover at
	# the end of that enemy's turn, which is what the card says.
	var shooter:Unit = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	await LeolethFixture.open_turn(game, shooter)
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP), 'fixture: the chip landed.')
	await SpecFactory.end_turn(game, shooter)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP),
		'And it is gone at the end of the turn that was current when it landed - somebody else\'s.')

func test_the_chip_is_a_floor_and_not_a_ceiling():
	# THE ENGINE'S COVER IS MAX-THEN-ZERO, so a Leoleth already in HARD cover from terrain keeps HARD
	# rather than being handed a second, lesser source. Read the other way round: this chip can only
	# ever RAISE the cover a roll sees, never lower it. Asserted with a SECOND hard-cover buff from
	# vanilla (the Goblin's buff_symbiosis_cover, cover = 2) standing in for the terrain, because a
	# one-tall block beside a size-1 unit is exactly the geometry other specs in this mod have measured
	# as unreliable.
	var shooter:Unit = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	SpecFactory.apply_buff(leoleth, &'buff_symbiosis_cover')
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.HARD,
		'fixture: it is already in hard cover from something else.')
	await LeolethFixture.structure(game, leoleth, BIG_HIT)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ASR_COVER_CHIP), 'The chip landed anyway.')
	assert_eq(CoverCalculator.determine_cover(leoleth, shooter).total, Lancer.COVER.HARD,
		'And the cover is still HARD - two sources do not stack into something else.')
