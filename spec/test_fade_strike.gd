# FADE STRIKE (Maiden's Blush trait, SP1 Task 5).
#
#   "If the Maiden's Blush begins its turn Invisible, it may reroll its first melee attack roll it
#    makes on that turn. It must keep the second result."
#
# TWO BUFFS, AND THE SPLIT IS RULING 7. "Begins its turn Invisible" is evaluated at NEW_TURN / PRE,
# BEFORE handle_starting_unit clears start-of-turn statuses - which is what lets Uncertainty Field's
# own Invisible ("until the beginning of its next turn") arm the reroll, and is the reading in which
# the frame's kit chains: teleport, fade through the enemy turn, reroll the first melee strike. The
# arming buff is that evaluation; the chip is what the engine's attack sequence then consumes.
#
# "INVISIBLE" IS THE STATUS ONLY (ruling 7). A TREAT_AS_INVISIBLE buff the mech might hold - the
# Banshee's tear, or SP2's own Step chip on somebody else - is not "being Invisible", and the arming
# gate reads unit.has_status() rather than UnitCondition.is_invisible() for exactly that reason.
#
# THE REROLL ITSELF IS THE ENGINE'S. handle_reroll_take_second asks on a hit or a miss, never on a
# crit, rerolls through roll.roll_attack, and consumes the buff when it rerolled OR when it cannot
# bank. Nothing in this mod re-implements any of that; the chip only has to be the right shape and to
# refuse the wrong attacks.
#
# HOW MANY VALUES AN ATTACK POPS OFF Dice.CHEAT_ROLL_QUEUE IS PER WEAPON, and it is NOT one pair each.
# The sword is Accurate, so it pops a d20 and an accuracy die, and a REROLL pops another of each; the
# rifle pops four and the Improvised Attack three, for the reasons set out over cheat() below. The
# constants under it are named per weapon and every call site lists its values draw by draw, because a
# queue that desyncs does not fail - it silently hands the next roll somebody else's number.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_fade_strike.gd
extends GutTest

const MaidensBlushFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/maidens_blush_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const TRAIT_ID := &'mt_fade_strike'
const ARM_BUFF_ID := &'buff_fade_strike_arm'
const CHIP_ID := &'buff_fade_strike'

const BLUSH_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4) # adjacent, so the sword and the Improvised Attack both reach

## The dummy's evasion. 10 so a cheated 2 misses and a cheated 14 hits - both sides are needed here,
## unlike in test_rend.gd where everything had to land.
const TARGET_EVASION := 10

var game:Gamemaster
var blush:Unit
var target:Unit
var watcher:PromptWatcher
var responder:SpecFactory.ChoiceBusResponder

func before_each() -> void:
	game = MaidensBlushFixture.create_game(self)
	blush = MaidensBlushFixture.create_maidens_blush(game, BLUSH_TILE)
	MaidensBlushFixture.equip_melee(blush)
	MaidensBlushFixture.equip_ranged(blush)
	target = MaidensBlushFixture.create_dummy(game, TARGET_TILE, TARGET_EVASION)
	responder = SpecFactory.current_responder
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- fixture helpers

func has_chip() -> bool:
	return UnitCondition.has_buff(blush, CHIP_ID)

func yesno_mark() -> int:
	return watcher.kinds(PromptWatcher.KIND.yesno).size()

func yesnos_since(mark:int) -> Array[Dictionary]:
	return watcher.kinds(PromptWatcher.KIND.yesno).slice(mark)

## Start the Blush's turn WITH the Invisible status up, which is the card's condition and exactly the
## state Uncertainty Field leaves it in: applied with Lancer.UNTIL.START_OF_TURN, so the same turn
## start that arms the chip also clears the status.
func arm() -> void:
	SpecFactory.apply(blush, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.START_OF_TURN)
	await SpecFactory.start_turn(game, blush)

## The values Dice.CHEAT_ROLL_QUEUE hands out, in DRAW order, followed by a buffer of 6s. Cleared first
## because cheat_attack only APPENDS and this file rolls up to three times in one test.
##
## HOW MANY VALUES A DRAW EATS IS PER WEAPON, not one pair per attack - measured off the runner's own
## `CHEATING roll, popping` lines, 2026-09-17:
##   - the Variable Sword eats TWO, a d20 and its Accurate die (attack_accuracy = "1"). Melee is not
##     difficult when engaged, so nothing offsets that +1. Its damage is a flat "3" and rolls nothing.
##     A REROLL eats another two.
##   - mw_assault_rifle eats FOUR: a d20, then an ENGAGED difficulty die (these tests fire it from an
##     adjacent tile, and accuracy_mods_total() of -1 still rolls 1d6 and negates it,
##     attack_roll.gd:70 / dice.gd:87), then TWO for its 1d6 damage - the summary rolls an if-hit value
##     and an if-crit value, and it rolls them whether or not the attack landed.
##   - mw_improvised_attack eats THREE: a d20 (no accuracy modifier, and melee takes no engaged
##     difficulty), then the same two damage values for its own 1d6.
## Every caller below names its values draw by draw. The trailing 6s are a buffer and no test here
## reaches them.
func cheat(values:Array[int]) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.cheat_attack(values, [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6])

## SWORD, two values: 13 + 1 = 14, a hit against evasion 10 and nowhere near the >= 20 crit threshold.
const HIT:Array[int] = [13, 1]
## SWORD, two values: 1 + 1 = 2, a miss against evasion 10.
const MISS:Array[int] = [1, 1]
## SWORD, two values: 30 + 6 = 36, a crit, which handle_reroll_take_second never asks about.
const CRIT:Array[int] = [30, 6]

## RIFLE, four values: d20 13, engaged difficulty die 1 (so 13 - 1 = 12, a hit against evasion 10 and
## short of a crit), then the 1d6 damage summary's if-hit and if-crit rolls. A HIT rather than a miss
## on purpose - a Reliable 2 miss also leaves damage on the board, so only a hit separates "the shot
## resolved" from "Reliable paid out".
const RIFLE_HIT:Array[int] = [13, 1, 6, 6]

## IMPROVISED ATTACK, three values: d20 13 (nothing modifies it, so 13 hits evasion 10 and does not
## crit), then its own 1d6 damage summary's two rolls.
const IMPROVISED_HIT:Array[int] = [13, 6, 6]

func swing() -> void:
	await SpecFactory.use_solo(game, blush, MaidensBlushFixture.MELEE_ID, [target])

func shoot() -> void:
	await SpecFactory.use_solo(game, blush, MaidensBlushFixture.RANGED_ID, [target])

func improvise() -> void:
	await SpecFactory.use_solo(game, blush, MaidensBlushFixture.BASIC_MELEE_ID, [target])

# ---------------------------------------------------------------- the wiring

func test_the_trait_its_arming_buff_and_its_chip_are_shaped_right():
	var kit:Kit = ContentLibrary.get_kit(TRAIT_ID)
	assert_true(Kit.is_valid(kit), 'mt_fade_strike is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait.')
	assert_true(kit.actions.is_empty(),
		'And it carries NO action, so the trait card shows only the card text.')

	var arm_buff:Buff = ContentLibrary.get_buff(ARM_BUFF_ID)
	assert_not_null(arm_buff, 'buff_fade_strike_arm is in the buffs index.')
	if arm_buff == null: return
	assert_true(arm_buff.hide_from_player, 'The arming buff is bookkeeping: never a chip on the unit.')
	assert_has(arm_buff.triggers_on, ReactionBus.TRIGGER.NEW_TURN, 'It listens on new_turn.')
	assert_eq(arm_buff.trigger_timing, ReactionBus.TIMING.PRE,
		'PRE - RULING 7, and the load-bearing line of this trait: handle_starting_unit clears'
		+ ' START_OF_TURN statuses between PRE and POST, so at POST the fade is already gone.')

	var chip:Buff = ContentLibrary.get_buff(CHIP_ID)
	assert_not_null(chip, 'buff_fade_strike is in the buffs index.')
	if chip == null: return
	assert_true(chip is BuffModifyAttackRoll, 'The chip is a BuffModifyAttackRoll subclass.')
	assert_false(chip.hide_from_player,
		'And it IS visible: it is the only on-map signal that the reroll is live.')
	assert_eq(chip.to, Buff.TO.MODIFY_ATTACK_ROLL,
		'Its `to` is what EventUnitAttack.get_buffs_for_step collects on - a chip with the wrong one is'
		+ ' simply never consulted.')
	assert_eq(chip.step, EventUnitAttack.SEQUENCE_STEP.reroll_take_second,
		'reroll_take_second: reroll and KEEP the second, not roll-twice-take-high.')
	assert_eq(chip.applies_when_holder_is, BuffModifyAttackRoll.APPLIES_WHEN.attacker,
		'It applies when we are the attacker.')
	assert_true(chip.needs_confirmation, 'The card says "may", so the player is asked.')
	assert_false(chip.can_bank,
		'And the FIRST melee attack roll consumes it, rerolled or not - which is what "its first"'
		+ ' means.')
	assert_true(chip.allow_weapon, 'Mounted weapons, yes.')
	assert_false(chip.allow_tech, 'Tech attacks are not melee attack rolls.')
	assert_false(chip.allow_basic,
		'And basic gear is excluded (ruling 12): a Ram never burns the reroll before the real strike.')
	assert_eq(chip.until, Lancer.UNTIL.END_OF_THIS_TURN, 'It lasts the turn it was hung on.')
	assert_true(chip.is_onetime, 'And it is consumed rather than lingering.')

func test_the_rows_resolve():
	for key:String in ['gear.mt_fade_strike.name', 'gear.mt_fade_strike.effect',
			'gear.buff_fade_strike.name', 'gear.buff_fade_strike.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)

# ---------------------------------------------------------------- arming

func test_invisible_at_turn_start_leaves_the_chip_on_the_blush():
	assert_false(has_chip(), 'No chip before the turn starts.')
	await arm()
	assert_true(has_chip(), 'Beginning the turn Invisible hangs the chip.')
	assert_false(blush.has_status(Lancer.STATUS.INVISIBLE),
		'And the START_OF_TURN fade itself is gone by the time the turn is running - the chip is what'
		+ ' survives it, which is the whole point of evaluating at PRE.')

func test_not_invisible_at_turn_start_means_no_chip():
	# The negative that makes the positive mean something: without it, a trait that hung the chip on
	# EVERY turn start would pass test_invisible_at_turn_start_leaves_the_chip_on_the_blush.
	await SpecFactory.start_turn(game, blush)
	assert_false(has_chip(), 'A turn begun in plain sight arms nothing.')

func test_another_units_turn_start_does_not_arm_the_chip():
	# THE HOLDER GUARD (buff_fade_strike_arm.gd:38), and this frame's own design is what makes it
	# reachable: Uncertainty Field's fade lasts "until the beginning of its next turn", so the Blush
	# spends the ENEMY's whole turn Invisible. NEW_TURN fires for every turn on the map and the bus polls
	# every unit's buffs with the same event, so without that line an enemy's turn start arms the chip -
	# and until = END_OF_THIS_TURN then throws it away at the end of THAT turn, costing the player the
	# reroll they paid a fade for. buff_hybridized_shot.gd:74-76 carries the same guard for the same
	# reason.
	#
	# MANUAL rather than START_OF_TURN, because the status has to survive the other unit's turn to still
	# be up for the control below - which is the whole point: the two halves differ only in WHOSE turn
	# starts.
	SpecFactory.apply(blush, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.MANUAL)
	await SpecFactory.start_turn(game, target)
	assert_false(has_chip(),
		'Somebody else beginning their turn arms nothing, however Invisible the Blush is.')
	await SpecFactory.end_turn(game, target)

	await SpecFactory.start_turn(game, blush)
	assert_true(has_chip(),
		'CONTROL: the Blush\'s OWN turn start, with the same status still up, does arm it.')

func test_invisible_gained_mid_turn_arms_nothing_until_the_next_turn_start():
	# "BEGINS its turn Invisible" - fading after the turn has started does not retroactively arm it.
	await SpecFactory.start_turn(game, blush)
	assert_false(has_chip(), 'Fixture: nothing armed.')
	SpecFactory.apply(blush, Lancer.STATUS.INVISIBLE, Lancer.UNTIL.MANUAL)
	assert_false(has_chip(), 'Fading mid-turn arms nothing now...')
	await SpecFactory.end_turn(game, blush)
	await SpecFactory.start_turn(game, blush)
	assert_true(has_chip(), '...but the NEXT turn begins Invisible, and that one does.')

func test_an_unused_chip_is_gone_at_turn_end():
	await arm()
	assert_true(has_chip(), 'Fixture: armed.')
	await SpecFactory.end_turn(game, blush)
	assert_false(has_chip(),
		'END_OF_THIS_TURN: an unspent reroll does not carry into the next turn. (new_turn_for_statuses'
		+ ' ticks turn_count at the start, end_turn_for_statuses clears it at the end.)')

# ---------------------------------------------------------------- the reroll

func test_a_missed_first_melee_attack_is_offered_a_reroll_and_takes_the_second_result():
	# The headline case, with BOTH results observed: the first roll misses, the reroll hits, and the
	# damage is what says the second result was kept.
	await arm()
	responder.chosen_yesnos = true
	cheat(MISS + HIT)
	var mark := yesno_mark()
	await swing()

	assert_eq(yesnos_since(mark).size(), 1, 'The player was asked, once.')
	assert_gt(target.current_damage(), 0, 'The reroll hit, and the second result was taken.')
	assert_false(has_chip(), 'And the chip is spent.')

func test_a_hit_is_offered_the_reroll_too():
	# handle_reroll_take_second asks on a hit as well as a miss - only a CRIT is never asked about.
	# The reroll here MISSES, which is the honest reading of "it must keep the second result": a
	# player who rerolls a hit can lose it.
	await arm()
	responder.chosen_yesnos = true
	cheat(HIT + MISS)
	var mark := yesno_mark()
	await swing()

	assert_eq(yesnos_since(mark).size(), 1, 'A hit is offered the reroll too.')
	assert_eq(target.current_damage(), 0,
		'And the second result stands even though it is worse - the sword has no Reliable, so a miss'
		+ ' deals nothing.')
	assert_false(has_chip(), 'The chip is spent.')

func test_a_crit_is_not_asked_and_the_chip_is_consumed_anyway():
	# event_unit_attack.gd:276 - "don't ask to reroll crits". can_bank is false, so
	# consume_regardless_of_use is true and the chip goes regardless (:304-305). Both halves are the
	# engine's; this test says we inherited them rather than fighting them.
	await arm()
	responder.chosen_yesnos = true
	cheat(CRIT)
	var mark := yesno_mark()
	await swing()

	assert_eq(yesnos_since(mark).size(), 0, 'Nobody is asked to reroll a crit.')
	assert_gt(target.current_damage(), 0, 'Fixture: the crit landed.')
	assert_false(has_chip(), 'And the chip is consumed anyway: it was the first melee attack roll.')

func test_declining_the_reroll_still_consumes_the_chip():
	# can_bank = false is what makes this true, and it is the difference between "reroll your first
	# melee attack" and "reroll one melee attack, whenever you like". Declining keeps the first result
	# AND spends the chip.
	await arm()
	responder.chosen_yesnos = false
	cheat(HIT + MISS) # the second pair would be the reroll, and must never be reached
	var mark := yesno_mark()
	await swing()

	assert_eq(yesnos_since(mark).size(), 1, 'The player was asked...')
	assert_gt(target.current_damage(), 0, '...kept the hit...')
	assert_false(has_chip(), '...and spent the chip anyway.')

func test_the_second_melee_attack_in_the_same_turn_is_not_rerolled():
	# "its FIRST melee attack roll". The crit spends the chip without a prompt, which is the cheapest
	# way to get to the second swing; the second swing then misses and stays missed.
	await arm()
	responder.chosen_yesnos = true
	cheat(CRIT + MISS)
	var mark := yesno_mark()
	await swing()
	var after_first:int = target.current_damage()
	assert_gt(after_first, 0, 'Fixture: the first swing crit.')
	assert_false(has_chip(), 'Fixture: and spent the chip.')

	await swing()
	assert_eq(yesnos_since(mark).size(), 0, 'The second swing opened no prompt at all.')
	assert_eq(target.current_damage(), after_first, 'It missed, and stayed missed.')

# ---------------------------------------------------------------- which attacks

func test_a_ranged_attack_leaves_the_chip_for_the_melee_attack_after_it():
	# A non-melee attack never matches check_if_passive_applies, so get_buffs_for_step never collects
	# the chip and handle_reroll_take_second never sees it - it is neither used NOR consumed. That is
	# the engine's own filtering (event_unit_attack.gd:356-357 through UnitCondition.get_buffs_to), and
	# it is what stops a rifle shot eating the melee reroll.
	#
	# THE SHOT HAS TO LAND FOR THIS TO BE A NEGATIVE ABOUT THE CHIP. "No prompt, and the chip is still
	# there" is also exactly what a use_solo the engine silently refused reports
	# ([ Gear not available ]), so the damage assertion is what separates the two - test_rend.gd does
	# the same for its own ranged and improvised cases.
	await arm()
	responder.chosen_yesnos = true
	# rifle d20, its engaged difficulty die, its two damage rolls | the sword's d20 and Accurate die,
	# missing | the reroll's d20 and Accurate die, hitting. Eight values, eight draws.
	cheat(RIFLE_HIT + MISS + HIT)
	var mark := yesno_mark()
	await shoot()
	assert_gt(target.current_damage(), MaidensBlushFixture.RELIABLE_ON_MISS,
		'Fixture: the rifle shot really HIT - more than the 2 its Reliable pays on a miss.')
	assert_eq(yesnos_since(mark).size(), 0, 'The rifle shot was offered no reroll...')
	assert_true(has_chip(), '...and left the chip alone.')

	var after_shot:int = target.current_damage()
	await swing()
	assert_eq(yesnos_since(mark).size(), 1, 'The melee attack after it got the offer...')
	assert_false(has_chip(), '...and spent it.')
	assert_gt(target.current_damage(), after_shot,
		'Fixture: and the rerolled swing landed, so the chip went to a real attack.')

func test_an_improvised_attack_leaves_the_chip_untouched():
	# RULING 12. The Improvised Attack IS weapon_type MELEE, so the type filter alone would let it
	# through; what refuses it is BuffModifyAttackRoll.allow_basic being false
	# (buff_modify_attack_roll.gd:48, loadout_core.gd:414). Without this, a Ram or an Improvised Attack
	# would burn the reroll before the real strike - which is the reason the author took the ruling.
	#
	# AND IT HAS TO LAND, for the same reason as the ranged case above: a use_solo the engine refused
	# reports "no prompt, chip untouched" too. Cheated to a HIT rather than a miss so the damage is
	# unambiguous - the Improvised Attack has no Reliable to pay out.
	MaidensBlushFixture.equip_basic_melee(blush)
	await arm()
	responder.chosen_yesnos = true
	cheat(IMPROVISED_HIT) # its d20, then its two 1d6 damage rolls. Three values, three draws.
	var mark := yesno_mark()
	await improvise()

	assert_gt(target.current_damage(), 0, 'Fixture: the improvised attack really landed.')
	assert_eq(yesnos_since(mark).size(), 0, 'Basic melee is offered no reroll...')
	assert_true(has_chip(), '...and the chip is still there for a real weapon.')
