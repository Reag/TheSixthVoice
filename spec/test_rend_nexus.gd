# REND NEXUS (the Sluagh's rank-I weapon, SP2 Task 2).
#
#   "Main Nexus, SMART, AP. 1d3+1 Energy, Range 10.
#    On crit: Until the end of your next turn, the next attack against you has +2 Difficulty."
#
# NO SCRIPT ANYWHERE IN THIS ABILITY, and that is the point of the shape. The engine's OnHitEffect
# already carries apply_on (on_hit_effect.gd:12), buffs (:14) and apply_buffs_to_self (:18), and
# apply_statuses_and_buffs puts the buffs on activation.context.unit - the ATTACKER - when that last
# flag is set (:85-86). The mod's own onhit_ddmr.tres is the precedent for exactly this combination.
#
# THE CHIP IS WICKED HOST'S AT A DIFFERENT VALUE AND A DIFFERENT CLOCK (ruling 10): accuracy -2
# instead of -1, and until = END_OF_NEXT_TURN instead of MANUAL. Everything else - onetime,
# attack_roll_incoming, visible - is the same, so the two stack on one roll and are consumed by it
# together, which test_the_two_chips_land_on_one_roll is what pins.
#
# THE ACCURACY DIE COUNT IS THE MEASUREMENT IN THREE TESTS HERE, so it is written out once:
# Dice.roll_d6_accuracy(-2) is roll_and_sum({count = -2, dietype = 6}, MAX) (dice.gd:86-88), which
# rolls abs(count) dice (:24), keeps the MAX (:45-51) and multiplies by signi(count) (:65). So the
# chip makes an incoming roll pop TWO accuracy dice, not one, and with Wicked Host's -1 as well it
# pops THREE. The damage die's POSITION in the queue is therefore what says how many chips were live,
# and no test here reads a buff to decide.
#
# THE SLUAGH'S OWN SHOT POPS THREE ENTRIES: the d20 (attack_roll.gd:67), then the damage dice TWICE,
# because AttackUtil.DamageRoll.roll_base_damage rolls hit_rolls and crit_rolls separately
# (attack_util.gd:250-251) - on a miss as much as on a crit. No accuracy die, because the weapon sets
# no attack_accuracy and roll_d6_accuracy(0) returns 0 without rolling (dice.gd:87-88).
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rend_nexus.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## Three tiles east: inside Range 10 and inside the rifle's Range 10, outside anything's threat.
const TARGET_TILE := Vector2i(7, 6)

## Crits: attack_roll.gd:73 is `crit = (total_roll >= 20) and hit and can_crit`, and a weapon's
## can_crit is unconditionally true (action_attack_weapon.gd:246).
const D20_CRITS := 20
## Hits a dummy comfortably and does NOT reach 20, so the ON_CRIT stage never runs.
const D20_HITS_WITHOUT_CRITTING := 15
## Loses to anything.
const D20_MISSES := 1

## The Sluagh's own evasion, off the sheet.
const SLUAGH_EVASION := 10
## Beats 10 with no accuracy die in play.
const D20_HITS_THE_SLUAGH := 19
## Beats 10 on its own, and does NOT once the chip's -2 pops a 6.
const D20_HITS_ONLY_WITHOUT_THE_CHIP := 11
## Queued for each accuracy die the chip adds. Applied as -6 (the MAX of the popped dice, negated).
const WORST_ACCURACY_DIE := 6
## The rifle's 1d6, cheated ABOVE its Reliable 2 so a hit and a miss are distinguishable by the
## damage number - Reliable is a FLOOR on a HIT's total too (attack_util.gd:144-147), which is the
## correction test_wicked_host.gd already records.
const DAMAGE_DIE := 3
## What a MISS with the rifle still lands: it is Reliable 2.
const RELIABLE := 2

var game:Gamemaster
var sluagh:Unit
var target:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.arm_rend_nexus(sluagh)
	target = SluaghFixture.create_hostile(game, TARGET_TILE)
	SluaghFixture.arm_rifle(target)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func chips() -> Array[BuffCore]:
	return UnitCondition.get_buffs(sluagh, SluaghFixture.REND_NEXUS_CHIP)

func has_chip() -> bool:
	return UnitCondition.has_buff(sluagh, SluaghFixture.REND_NEXUS_CHIP)

# ---------------------------------------------------------------- the profile

func test_the_profile_matches_the_card():
	# EVERY NUMBER OFF THE SHEET (specs/sixth-voice/08-sluagh.md:49-54), read from the RESOURCE, so a
	# red here means the .tres drifted from the card rather than that the engine changed.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.REND_NEXUS)
	assert_not_null(kit, 'mw_rend_nexus loads as a Kit through ContentLibrary.')
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0, as the sheet says.')
	assert_false(kit.is_trait, 'It is licence gear, not a frame trait.')
	assert_eq(kit.actions.size(), 1, 'One action.')
	if kit.actions.is_empty(): return

	var shot:ActionAttackWeapon = kit.actions[0]
	assert_not_null(shot, 'And it is an ActionAttackWeapon.')
	if shot == null: return
	assert_eq(shot.get_id(), &'action_rend_nexus', 'Named for its own file.')
	assert_eq(shot.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'MAIN.')
	assert_eq(shot.weapon_type, Lancer.WEAPON_TYPE.NEXUS, 'NEXUS.')
	assert_eq(shot.damage_dice, '1d3+1', 'Damage 1d3+1...')
	assert_eq(shot.damage_type, Lancer.DAMAGE_TYPE.ENERGY, '...of ENERGY.')
	assert_eq(shot.aim_range, 10, 'Range 10.')
	assert_true(shot.tags.has(Lancer.WEAPON_TAG.SMART), 'SMART...')
	assert_true(shot.tags.has(Lancer.WEAPON_TAG.AP), '...and AP.')
	assert_eq(shot.tags.size(), 2, 'And nothing else.')
	# 1d3+1 REALLY PARSES, and this is the assertion that says so rather than assuming it.
	# Dice.process_dice_string slices the bonus off at the '+' (dice.gd:117-119) and then reads the
	# die count and type (:122-124); sum_rolls adds the bonus once, after the dice (:67). Six vanilla
	# weapons ship the identical string - mw_tactical_knife.tres:13 is the shortest of them.
	var parsed:Dictionary = Dice.process_dice_string(shot.damage_dice)
	assert_eq(parsed.count, 1, '1d3+1 parses to one die...')
	assert_eq(parsed.dietype, 3, '...of three sides...')
	assert_eq(parsed.bonus, 1, '...plus a flat 1.')

func test_the_kit_carries_one_on_crit_effect_that_buffs_the_attacker():
	# THE DECLARATIVE HALF. Everything this ability does lives in these four fields, so a mutation to
	# any of them has to be visible here as well as behaviourally - otherwise a silent .tres edit that
	# only bites on a rare path reads green.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.REND_NEXUS)
	if kit == null or kit.actions.is_empty(): return assert_true(false, 'fixture: the Kit loaded.')
	var shot:ActionAttackWeapon = kit.actions[0]
	assert_eq(shot.on_hit_effects.size(), 1, 'One on-hit effect.')
	if shot.on_hit_effects.is_empty(): return

	var effect:OnHitEffect = shot.on_hit_effects[0]
	assert_eq(effect.apply_on, OnHitEffect.STAGE.ON_CRIT, 'It runs at the CRIT stage, not on a hit.')
	assert_true(effect.apply_buffs_to_self,
		'And it buffs the ATTACKER - apply_statuses_and_buffs sends them to activation.context.unit '
		+ 'when this is set (on_hit_effect.gd:85-86). The card says "against YOU".')
	assert_eq(effect.buffs.size(), 1, 'Exactly one buff.')
	if effect.buffs.is_empty(): return
	assert_eq(effect.buffs[0].compcon_id, SluaghFixture.REND_NEXUS_CHIP, 'And it is the chip.')
	assert_true(effect.statuses.is_empty(), 'No statuses: the card applies none.')
	assert_false(effect.save_to_avoid, 'And no save: the card offers none.')

	# READ OFF THE RESOURCE, typed as BuffBonus because that is a real class_name and these are its
	# exports - a .tres-exported property reached through a typed local of the WRONG class is a parse
	# error GUT reports by SKIPPING the file (memory lancer-tactics-spec-harness-traps).
	var chip:BuffBonus = ContentLibrary.get_buff(SluaghFixture.REND_NEXUS_CHIP)
	assert_not_null(chip, 'buff_rend_nexus loads as a BuffBonus.')
	if chip == null: return
	assert_eq(chip.bonus_subtype, Buff.BONUS_SUBTYPE.ACCURACY, 'An accuracy modifier...')
	assert_eq(chip.bonus_value, -2, '...of -2, which the card calls +2 Difficulty.')
	assert_eq(chip.to, Buff.TO.ATTACK_ROLL_INCOMING, 'On rolls made AGAINST the holder.')
	assert_true(chip.is_onetime, 'Consumed by one roll.')
	# NOT MANUAL, which is what Wicked Host's otherwise identical chip uses: this card says "until the
	# end of your next turn" and that is a real UNTIL value (lancer.gd:48).
	assert_eq(chip.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'And it expires at the end of the next turn.')
	assert_false(chip.hide_from_player, 'Visible: the attacker has to know this shot is harder.')

# ---------------------------------------------------------------- arming it

func test_a_crit_leaves_the_chip_on_the_sluagh():
	SluaghFixture.queue([D20_CRITS])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_gt(target.current_damage(), 0, 'fixture: the shot really landed.')
	assert_true(has_chip(), 'A crit arms the next attack against the Sluagh.')
	assert_eq(chips().size(), 1, 'Exactly one.')

func test_a_plain_hit_leaves_nothing():
	# THE DISCRIMINATING NEGATIVE: the ON_CRIT stage is nested inside `if roll.hit:`
	# (event_unit_attack.gd:83, :89), so a hit that does not reach 20 must run the ON_HIT pass and
	# stop. An effect authored at the wrong stage passes the crit test above and fails here.
	SluaghFixture.queue([D20_HITS_WITHOUT_CRITTING])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_gt(target.current_damage(), 0, 'fixture: the shot hit.')
	assert_false(has_chip(), 'But it did not crit, so nothing was armed.')

func test_a_miss_leaves_nothing():
	SluaghFixture.queue([D20_MISSES])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_eq(target.current_damage(), 0,
		'fixture: the shot missed, and a Nexus has no Reliable to floor it.')
	assert_false(has_chip(), 'A miss arms nothing.')

# ---------------------------------------------------------------- spending it

func test_the_next_attack_against_the_sluagh_carries_the_difficulty_and_consumes_the_chip():
	# THE WHOLE CARD, IN NUMBERS, and the shape test_wicked_host.gd already proved on this frame. The
	# incoming d20 is 11 - which beats the Sluagh's evasion 10 on its own - and the chip makes it pop
	# TWO accuracy dice, the MAX of which is applied as -6, for a total of 5. So the SAME d20 hits
	# without the chip and misses with it, and the two outcomes differ by DAMAGE_DIE against the
	# rifle's Reliable 2. Nothing here reads the chip to decide; the damage number is the evidence.
	SluaghFixture.queue([D20_CRITS])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_true(has_chip(), 'fixture: the crit armed it.')

	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_CHIP, WORST_ACCURACY_DIE, WORST_ACCURACY_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, target, sluagh)
	assert_eq(sluagh.current_damage(), RELIABLE,
		'The shot MISSED: 11 - 6 is 5, short of evasion 10. Without the chip 11 would hit for 3.')
	assert_false(has_chip(),
		'And the chip was consumed by that roll even though it missed - is_onetime buffs in '
		+ 'pre.applied_buffs are consumed after every roll (event_unit_attack.gd:114).')

func test_the_chip_clears_at_the_end_of_the_sluaghs_next_turn_unused():
	# "Until the end of your next turn" - the clock is the SLUAGH'S, not the attacker's, which is what
	# Lancer.UNTIL.END_OF_NEXT_TURN means and what separates this chip from Wicked Host's MANUAL one.
	# The crit happens on the Sluagh's own turn, so the FIRST end-turn it sees is the end of that same
	# turn - which END_OF_NEXT_TURN survives, stepping down to END_OF_THIS_TURN - and the second is
	# what clears it (buff.gd:9-10: "will naturally progress from next turn -> this turn -> end").
	SluaghFixture.queue([D20_CRITS])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_true(has_chip(), 'fixture: armed.')

	await SpecFactory.end_turn(game, sluagh)
	assert_true(has_chip(), 'It survives the turn the crit happened on...')
	await SluaghFixture.open_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_false(has_chip(), '...and clears at the end of the Sluagh\'s NEXT turn, unused.')

func test_an_attack_that_never_comes_costs_the_attacker_nothing():
	# THE NEGATIVE CONTROL FOR THE TEST ABOVE, and it is not redundant: "the chip expired" and "the
	# chip was never applied" leave the same absence, so this pins that a roll made AFTER the expiry
	# is an ordinary one - it pops NO accuracy die at all (dice.gd:87-88 returns 0 without rolling),
	# so the damage die sits in slot 2 rather than slot 4.
	SluaghFixture.queue([D20_CRITS])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	await SpecFactory.end_turn(game, sluagh)
	await SluaghFixture.open_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_false(has_chip(), 'fixture: expired.')

	SluaghFixture.queue([D20_HITS_ONLY_WITHOUT_THE_CHIP, DAMAGE_DIE])
	await SluaghFixture.shoot(game, target, sluagh)
	assert_eq(sluagh.current_damage(), DAMAGE_DIE,
		'11 hits evasion 10 cleanly and the damage die is the SECOND entry - so no accuracy die was '
		+ 'popped, which is what "the chip is really gone" means in this engine.')

func test_the_two_chips_land_on_one_roll():
	# RULING 9's last clause and RULING 10's, together: Wicked Host's -1 and this card's -2 are
	# separate buffs on the same channel, so they ADD to -3 and are consumed by the same roll.
	#
	# THE EVIDENCE IS THE DAMAGE DIE'S POSITION, not a buff count, because that is the only thing that
	# distinguishes -3 from -2. roll_d6_accuracy pops abs(total) dice (dice.gd:24, :86-88), so with
	# three 1s queued the accuracy applied is -1, the d20 of 19 still hits, and the damage die is the
	# FIFTH entry. If only one chip were live the roll would pop two dice or none, the damage die
	# would be read from the wrong slot as a 1, and Reliable 2 would floor it to 2 - which is why
	# DAMAGE_DIE is 3.
	SluaghFixture.queue([D20_HITS_THE_SLUAGH, DAMAGE_DIE])
	await SluaghFixture.shoot(game, target, sluagh)
	assert_true(UnitCondition.has_buff(sluagh, SluaghFixture.WICKED_HOST_CHIP),
		'fixture: the hostile hit armed Wicked Host.')
	var wicked_host_chips:Array[BuffCore] = UnitCondition.get_buffs(sluagh, SluaghFixture.WICKED_HOST_CHIP)
	var first_wicked_host_chip:BuffCore = wicked_host_chips[0]
	var after_wicked_host:int = sluagh.current_damage()

	SluaghFixture.queue([D20_CRITS])
	await SluaghFixture.nexus_shot(game, sluagh, target)
	assert_true(has_chip(), 'fixture: the crit armed the Rend Nexus chip too.')

	SluaghFixture.queue([D20_HITS_THE_SLUAGH, 1, 1, 1, DAMAGE_DIE])
	await SluaghFixture.shoot(game, target, sluagh)
	assert_eq(sluagh.current_damage() - after_wicked_host, DAMAGE_DIE,
		'THE FINDING: exactly THREE accuracy dice were popped, so both chips were on that one roll.')
	assert_false(has_chip(), 'The Rend Nexus chip was consumed...')
	# WICKED HOST'S WAS CONSUMED BY THE SAME ROLL AND RE-ARMED BY THE SAME HIT, which is the one thing
	# the plan predicted wrongly here and the frame's own trait is why. event_unit_attack consumes the
	# roll's one-time buffs at :114 and queues the ATTACK POST reactions nine lines later at :123;
	# buff_wicked_host_watch.triggers_on_event ends on `(context.object as AttackRoll).hit`, and
	# 19 - 1 is 18 against evasion 10, so this roll IS a hit and the watcher fires. A bare
	# assert_false would therefore be asserting the absence of a trait that is working - so what is
	# pinned instead is that the chip standing now is a DIFFERENT BuffCore, which says the first one
	# really went. test_wicked_host.gd's
	# test_a_second_hit_consumes_the_pending_chip_and_leaves_exactly_one_fresh_one is the same
	# measurement from the other side, by count.
	var wicked_host_after:Array[BuffCore] = UnitCondition.get_buffs(sluagh, SluaghFixture.WICKED_HOST_CHIP)
	assert_false(wicked_host_after.has(first_wicked_host_chip),
		'...and so was Wicked Host\'s, by the same roll - the chip on the Sluagh now is the fresh one '
		+ 'that same HIT armed, not the one that was live for the roll.')

# ---------------------------------------------------------------- the card and the licence

func test_the_card_rows_resolve():
	# Through THIS MOD'S OWN compiled artifact first, so a sibling Reag-* mod loaded in the same
	# testkit run cannot hold this green - the same pattern test_wicked_host.gd and
	# test_sluagh_frame.gd use.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mw_rend_nexus.name', 'gear.mw_rend_nexus.flavor', 'gear.mw_rend_nexus.on_crit']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mw_rend_nexus.name'), 'Rend Nexus', 'The card\'s own name.')
	# X.tr KEEPS THE GLOSSARY PIPES (SP1 Task 7's finding), so this pins the pipe too - which is the
	# only thing that would catch |Difficulty| being written unpiped or piped on a label that does not
	# resolve.
	assert_eq(X.tr('gear.mw_rend_nexus.on_crit'),
		'Until the end of your next turn, the next attack against you has +2 |Difficulty|.',
		'RULING 2: the crit row ships "against YOU". The LCP doubles the word, and '
		+ 'tools/check_content.py carries that as a recorded exemption rather than a silent edit.')
	# THE ENGINE REALLY READS THIS KEY - it is not decoration. Translate.action falls through from
	# gear.<kit>.<action>.on_crit to gear.<kit>.on_crit (translate.gd:26-29, :44-45), and both
	# surfaces that draw a weapon card read 'on_crit' through it: the character sheet at kit.gd:256
	# and the action tooltip at tooltip_organ_action.gd:188.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.REND_NEXUS)
	if kit == null or kit.actions.is_empty(): return assert_true(false, 'fixture: the Kit loaded.')
	assert_eq(Translate.action(kit, kit.actions[0], 'on_crit', false),
		X.tr('gear.mw_rend_nexus.on_crit'),
		'And Translate.action finds it from the ACTION, through the Kit-level fallback.')

func test_the_licence_grants_it_at_rank_one():
	var licence:UnlockTree = ContentLibrary.get_license_tree(SluaghFixture.LICENSE_ID)
	assert_not_null(licence, 'li_sluagh loads as an UnlockTree.')
	if licence == null: return
	var rank_1_ids:Array[StringName] = []
	for kit:Kit in licence.rank_1.granted_gear: rank_1_ids.append(kit.compcon_id)
	assert_true(rank_1_ids.has(SluaghFixture.REND_NEXUS), 'Rank 1 grants the Rend Nexus.')
	# The frame is still rank 2's and nothing else moved - the assertion test_sluagh_frame.gd makes
	# about rank 2 is not repeated here, only the one this task could have broken.
	assert_true(licence.rank_2.granted_gear.is_empty(),
		'Rank 2 still grants no GEAR - only the frame, until SP3.')
	assert_true(licence.rank_3.granted_gear.is_empty(), 'And rank 3 is still empty, until SP4.')
