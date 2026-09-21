# WICKED HOST (the Sluagh's first sheet trait, SP1 Task 2).
#
#   "Whenever the Sluagh is hit by an attack made by a hostile character, the next attack against it
#    has +1 difficulty. This effect lasts until the end of the scene."
#
# TWO BUFFS FOR ONE CARD. buff_wicked_host_watch is a permanent hidden observer applied by the
# trait's PassiveBuffApplicator; buff_wicked_host is the visible one-time chip it hangs. The
# alternative - an ActionReaction - would pay the per-kit reaction allowance and need a Kit action
# the player can see in the reaction list, and the card is not a reaction. The Ripper Mod's and the
# Effervescent counter's reasoning, verbatim.
#
# THE DAMAGE DIE IS CHEATED TO 1 IN EVERY TEST HERE, and that is the frame: the Sluagh has 8 HP and
# 0 armor, so two cheated sixes destroy it mid-test and every assertion afterwards reads as broken
# content. SluaghFixture.queue tails the FIFO with 1s for the same reason.
#
# THE ACCURACY DIE IS THE SECOND ENTRY IN THE QUEUE, NOT THE FIRST. AttackRoll.roll_attack pops the
# d20 at attack_roll.gd:67 and only then the accuracy die at :70, and Dice.roll_d6_accuracy(-1) is
# roll_and_sum({count = -1, dietype = 6}, MAX), whose result is multiplied by signi(count)
# (dice.gd:65) - so a queued 6 becomes -6. A roll made WITHOUT the chip pops no accuracy die at all
# (dice.gd:87-88 returns 0 without rolling when the bonus is 0), so the two paths consume different
# numbers of entries and every queue here is written out in full.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_wicked_host.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## Three tiles east: inside the rifle's Range 10, outside anything's threat.
const SHOOTER_TILE := Vector2i(7, 6)
## A friendly shooter, for the "an allied attack applies nothing" case.
const FRIEND_TILE := Vector2i(4, 8)

## The Sluagh's own evasion, off the sheet. One cheated d20 decides a hit or a miss against it.
const SLUAGH_EVASION := 10
## Beats 10 with no accuracy die in play.
const D20_HITS := 19
## Beats 10 on its own, and does NOT beat it once the chip's -1 pops a 6.
const D20_HITS_ONLY_WITHOUT_THE_CHIP := 11
## Loses to 10 either way.
const D20_MISSES := 1
## The accuracy die the chip makes the roll pop. Queued as 6, applied as -6.
const WORST_ACCURACY_DIE := 6
## The rifle's 1d6, cheated ABOVE the weapon's Reliable 2 and no higher.
##
## NOT 1, AND THE PLAN'S 1 WAS WRONG AGAINST THE ENGINE (SP1 Task 2, measured 2026-09-20). Reliable
## is a FLOOR on the total, not only a miss payout: AttackUtil reduces the rolled damage and then
## tops it back up whenever `total < reliable` (attack_util.gd:144-147), on a HIT exactly as on a
## miss. So a cheated 1 lands 2, hit and miss become indistinguishable by the damage number, and
## test_the_next_hostile_roll_... - whose whole evidence is that number - would read green for the
## wrong reason. 3 is the smallest value that separates them while keeping two hits (6) inside the
## frame's 8 HP, which is what the 1 was protecting.
const DAMAGE_DIE := 3
## What a MISS with the rifle still lands: it is Reliable 2.
const RELIABLE := 2

var game:Gamemaster
var sluagh:Unit
var shooter:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	shooter = SluaghFixture.create_hostile(game, SHOOTER_TILE)
	SluaghFixture.arm_rifle(shooter)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func chips() -> Array[BuffCore]:
	return UnitCondition.get_buffs(sluagh, SluaghFixture.WICKED_HOST_CHIP)

func has_chip() -> bool:
	return UnitCondition.has_buff(sluagh, SluaghFixture.WICKED_HOST_CHIP)

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.WICKED_HOST_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % SluaghFixture.WICKED_HOST_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	# ON THE FRAME, and reachable as GEAR on a live unit - which is a different claim from "the
	# resource exists". core.frame = <frame> alone never runs loadout.regenerate_derived_gear, so a
	# trait wired into the array but not reachable through get_gear would leave this ability
	# completely dead while every resource assertion above stayed green.
	assert_true(GearCore.is_valid(sluagh.get_gear(SluaghFixture.WICKED_HOST_ID)),
		'And the live Sluagh carries it as gear.')
	# The watcher really got hung on the unit. Without it nothing below can fire, and the failure
	# would read as "the gate is wrong" rather than "the buff was never applied".
	assert_true(UnitCondition.has_buff(sluagh, SluaghFixture.WATCH_BUFF),
		'The trait\'s PassiveBuffApplicator hung the watcher on the Sluagh at combat start.')

func test_the_card_rows_resolve():
	# Through THIS MOD'S OWN artifact first, so a sibling Reag-* mod cannot hold this green.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mt_wicked_host.name', 'gear.mt_wicked_host.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mt_wicked_host.name'), 'Wicked Host', 'The card\'s own name.')
	assert_true(X.tr('gear.mt_wicked_host.effect').ends_with('until the end of the scene.'),
		'And the effect row is the LCP\'s sentence, entire.')
	# THE CHIP BORROWS THE TRAIT'S NAME AND WRITES NO ROW OF ITS OWN. Translate.buff falls through to
	# the OWNER GEAR's keys when the buff has none (translate.gd:76-77), and the chip's from_gear is
	# the trait's gear because the watcher passes it - so the player reads "Wicked Host" on the chip
	# with no invented string anywhere. buff_weak_computer is this mod's precedent.
	assert_eq(translation.get_message('gear.buff_wicked_host.name'), StringName(''),
		'The chip deliberately has no name row of its own.')

func test_the_chip_has_the_shape_ruling_9_specifies():
	# READ OFF THE RESOURCE, not off a live unit, so this is a statement about the .tres. Typed as
	# BuffBonus because that is a real class_name and the four fields below are its exports; a
	# .tres-exported property reached through a typed local of the WRONG class is a parse error that
	# GUT reports by SKIPPING the whole file (memory lancer-tactics-spec-harness-traps).
	var chip:BuffBonus = ContentLibrary.get_buff(SluaghFixture.WICKED_HOST_CHIP)
	assert_not_null(chip, 'buff_wicked_host loads as a BuffBonus.')
	if chip == null: return
	assert_eq(chip.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'An accuracy modifier...')
	assert_eq(chip.bonus_value, -1, '...of -1, which the card calls +1 difficulty.')
	assert_eq(chip.to, Buff.TO.ATTACK_ROLL_INCOMING, 'On rolls made AGAINST the holder.')
	assert_true(chip.is_onetime, 'Consumed by one roll.')
	# NOT FINISH_ATTACK_ROLL, which is what vanilla's identical buff_warp_shield.tres uses: that
	# value also consumes at the end of every turn (lancer.gd:53), and this card says "until the end
	# of the scene". MANUAL is the engine's spelling of that.
	assert_eq(chip.until, Lancer.UNTIL.MANUAL, 'And it lasts until the end of the scene.')
	assert_false(chip.hide_from_player, 'Visible: the target has to know it is at +1 difficulty.')
	# The observer is the opposite on both counts.
	var watcher = ContentLibrary.get_buff(SluaghFixture.WATCH_BUFF)
	assert_not_null(watcher, 'buff_wicked_host_watch loads.')
	if watcher == null: return
	assert_true(watcher.hide_from_player, 'The watcher is plumbing and is never a chip on the unit.')
	assert_eq(watcher.to, Buff.TO.NONE, 'It has no passive channel at all; it only triggers.')

# ---------------------------------------------------------------- arming it

func test_a_hostile_hit_leaves_the_chip():
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(sluagh.current_damage(), DAMAGE_DIE, 'fixture: the shot really hit, for 1.')
	assert_true(has_chip(), 'A hostile character\'s hit arms the next attack against the Sluagh.')

func test_a_hostile_miss_leaves_nothing():
	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(sluagh.current_damage(), RELIABLE,
		'fixture: the shot really missed - only the rifle\'s Reliable 2 landed.')
	assert_false(has_chip(), 'A miss is not a hit; nothing is armed.')

func test_an_allied_invade_applies_nothing():
	# AN INVADE AGAINST AN ALLY AUTO-HITS (action_attack_tech.gd's is_invade branch), so this is a
	# guaranteed hit by a unit that is not hostile - which makes the green here a statement about the
	# are_enemies clause and not about the dice. A friendly rifle shot would be the weaker test: it
	# could miss.
	var friend:Unit = SluaghFixture.create_ally(game, FRIEND_TILE)
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.invade(game, friend, sluagh)
	# THE VACUITY GUARD (close review, slice 2 M-1). "No chip" is also what an activation that never
	# happened leaves, and an invade deals no damage of its own, so there is no damage number to
	# read. ms_fragment_signal's on-hit applies Impaired and Slowed
	# (content/gear/basic/ms_fragment_signal.tres), and only a LANDED invade produces them.
	assert_true(sluagh.has_status(Lancer.STATUS.IMPAIRED),
		'fixture: the invade really landed - the fragment signal applied Impaired.')
	assert_false(has_chip(), 'An ALLY hitting the Sluagh arms nothing - the card says hostile.')

## THE TWO DRONE CASES BELOW ARE ONE RULING IN TWO HALVES, and nothing in this file pinned either
## until the close (slice 2 I-1). Every attacker here was a mech, so buff_wicked_host_watch.gd's
## attacker predicate could have been flipped or deleted with the whole suite green.
##
## THE MOD'S SETTLED READING OF "CHARACTER" is that A DRONE IS NOT ONE IN ITS OWN RIGHT, AND WHERE A
## DRONE ACTS, IT ACTS AS ITS OWNER - ruling 194 (the Vauban's Gravity Well), rulings 64 and 70
## (Draw Fire, CONFIRMED: a hostile drone's shot counts as its owner's, resolved through
## Unit.get_attacker) and ruling 269 (the Stealing). The canonical paragraph is in
## action_stealing_of_the_souls.gd's header.
##
## THIS IS THE FRAME'S ONLY ATTACKER-SIDE CLAUSE, so it is the only place the second half of that
## sentence does any work: the watcher resolves through get_attacker() BEFORE asking is_actor(), so
## the owned drone below arms the chip as its OWNER'S hit while the unowned one arms nothing. Every
## other Sluagh card asks the bare predicate and refuses a drone outright.
##
## THE PAIR IS THE EVIDENCE, NOT EITHER CASE ALONE. Owned-only would pass under a bare
## is_character(); unowned-only would pass under a build with no get_attacker call at all. Together
## they say exactly which two lines are doing the work, and each names the predicate out loud.

func test_an_owned_hostile_drones_hit_arms_the_chip_as_its_owners():
	# RULING 70's own sentence, on this card. The drone's owner is `shooter`, a hostile MECH, so
	# get_attacker -> get_owner_unit_or_self (unit.gd:270-282) hands the watcher an ACTOR and the
	# chip is armed - by a unit that is not itself a character on this frame.
	var drone:Unit = SluaghFixture.create_drone(game, SHOOTER_TILE + Vector2i(0, 1), Faction.AI_ENEMY)
	SluaghFixture.own_drone(drone, shooter)
	SluaghFixture.arm_rifle(drone)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor, so it never qualifies in its own right.')
	assert_eq(drone.get_attacker(), shooter,
		'fixture: but its shots resolve to its OWNER, which is the whole of ruling 70.')
	assert_true(shooter.is_actor(), 'fixture: and the owner IS an actor.')
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, drone, sluagh)
	assert_eq(sluagh.current_damage(), DAMAGE_DIE, 'fixture: the drone\'s shot really hit, for 3.')
	assert_true(has_chip(), 'An OWNED hostile drone\'s hit arms the chip - as its owner\'s hit.')

func test_an_unowned_hostile_drones_hit_arms_nothing():
	# THE OTHER HALF, and the one that pins is_actor() rather than is_character(). With no owner id
	# get_owner_unit returns null (unit.gd:264-268), so get_attacker hands back the DRONE, and a
	# drone is not a character on this frame. Flip buff_wicked_host_watch.gd's predicate to
	# is_character() and this is the one test in the file that reddens.
	#
	# THE HIT ITSELF IS ASSERTED FIRST, which is what stops this passing for the boring reason: a
	# shot that missed, or never happened, would also leave no chip.
	var drone:Unit = SluaghFixture.create_drone(game, SHOOTER_TILE + Vector2i(0, 1), Faction.AI_ENEMY)
	SluaghFixture.arm_rifle(drone)
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor, which is the distinction the gate uses.')
	assert_eq(drone.get_attacker(), drone, 'fixture: unowned, so it answers for its own shots.')
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, drone, sluagh)
	assert_eq(sluagh.current_damage(), DAMAGE_DIE, 'fixture: the drone\'s shot really hit, for 3.')
	assert_false(has_chip(), 'An UNOWNED hostile drone acts in its own right, and is not a character.')

func test_a_hostile_tech_attack_that_hits_applies_it():
	# "Any attack roll, weapon or tech" - ruling 9. ms_fragment_signal is an ActionAttackTech and it
	# is BASIC gear, so this case would also fail if the gate had inherited an allow_weapon-style
	# filter from somewhere; the watcher deliberately has none, because it is a Buff and not an
	# ActionReactionAttacked. A hostile invade rolls against E-DEF (10 here, the sheet) rather than
	# evasion, and 19 clears it.
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.invade(game, shooter, sluagh)
	assert_true(has_chip(), 'A hostile tech attack that hits arms the chip too.')

# ---------------------------------------------------------------- spending it

func test_the_next_hostile_roll_carries_the_difficulty_and_consumes_the_chip():
	# THE WHOLE CARD, IN NUMBERS. The second shot's d20 is 11 - which beats the Sluagh's evasion 10
	# on its own - and the chip makes it pop an accuracy die of 6, applied as -6, for a total of 5.
	# So the SAME d20 hits without the chip and misses with it, and the two outcomes are 1 damage
	# against the rifle's Reliable 2. Nothing here reads the chip to decide; the damage number is the
	# evidence.
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_true(has_chip(), 'fixture: the first hit armed it.')
	var after_first:int = sluagh.current_damage()

	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_CHIP, WORST_ACCURACY_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(sluagh.current_damage() - after_first, RELIABLE,
		'The second shot MISSED: 11 - 6 is 5, short of evasion 10. Without the chip 11 would hit.')
	assert_false(has_chip(),
		'And the chip was consumed by that roll even though it missed - is_onetime buffs in '
		+ 'pre.applied_buffs are consumed after every roll (event_unit_attack.gd:114).')

func test_a_second_hit_consumes_the_pending_chip_and_leaves_exactly_one_fresh_one():
	# RULING 9's "it never stacks with itself", and the reason is ORDER rather than anything in our
	# code: event_unit_attack consumes the roll's applied one-time buffs at :114 and only queues the
	# ATTACK POST reactions at :123, so the pending chip is gone before the watcher is even asked.
	# The count is what this asserts - a naive implementation leaves two, and every other test in
	# this file stays green when it does.
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(chips().size(), 1, 'fixture: one chip after the first hit.')

	# The second shot pops the accuracy die the chip added, so the queue carries one more entry than
	# the first did - and a 1 there keeps 19 - 1 = 18 comfortably above evasion 10, so it still HITS.
	SluaghFixture.queue([D20_HITS, 1, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(sluagh.current_damage(), DAMAGE_DIE * 2, 'fixture: the second shot hit too.')
	assert_eq(chips().size(), 1,
		'Still exactly ONE chip: the hit consumed the pending one before arming a new one.')

func test_the_chip_survives_a_turn_end():
	# "until the end of the scene" - so MANUAL, not FINISH_ATTACK_ROLL, which vanilla's otherwise
	# identical buff_warp_shield.tres uses and which would ALSO clear here (lancer.gd:53).
	# BOTH turn ends matter and they are different clocks: the SLUAGH'S own (which is what
	# clear_buffs_until reads for END_OF_THIS_TURN) and the shooter's.
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_true(has_chip(), 'fixture: armed.')

	await SpecFactory.end_turn(game, shooter)
	assert_true(has_chip(), 'The shooter ending its turn does not clear it.')

	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_true(has_chip(), 'And neither does a whole Sluagh turn. It lasts the scene.')
