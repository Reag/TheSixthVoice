# ASTRAL GUARDIAN (the passive half of CRY OF THE HOSTED DEAD, SP1 Task 6).
#
#   "1/round, when an adjacent allied character is hit by an attack made by a hostile character, they
#    gain +1d6 OVERSHIELD. The OVERSHIELD is granted before damage is dealt."
#
# THE ORDERING IS ALREADY PROVED AND IS NOT RE-PROVED HERE. spec/test_spike_post_before_damage.gd
# (SP1 Task 0, 3 tests, mutation-verified) measured that an ATTACK POST reaction runs before the
# attack's damage, on a knockoff Kit with a plain ActionReaction so that the mutation could fire at
# all. That file stays where it is; this one builds on its verdict and reads the ordering off the
# REAL card's numbers instead.
#
# THE NUMBERS ARE THE TEST. A cheated queue of [19, 4, 5] is a d20 of 19 (a hit), then the guardian's
# d6 of 4, then the rifle's damage d6 of 5 - in that order, because Dice.roll_d6() pops from the same
# global FIFO as the attack roll (dice.gd:33-35) and the POST reactions run at
# event_unit_attack.gd:123, while damage is rolled at event_unit_attack_declared.gd:74. So the ally
# ends with 4 Overshield granted, 5 damage dealt, 4 absorbed, 1 on HP and 0 Overshield left. Granted
# AFTER the damage, it would read 4 Overshield and 5 HP lost.
#
# WHICH IS WHY A *NEGATIVE* CASE MUST NOT USE THAT QUEUE, and this is the one correction this file
# makes to the plan's own spec source (SP1 Task 6, Step 1). The guardian's d6 and the damage d6 come
# out of ONE FIFO, so in a case where the guardian is correctly refused nothing pops the middle
# entry and the DAMAGE die is the second number, not the third. Written the plan's way, every
# "gets nothing" test would have read GUARDIAN_D6 as its damage and failed on a build that is
# working. Each negative case therefore writes the SAME number in both slots, so the damage read is
# identical whether or not a d6 was popped first - which makes those assertions statements about the
# gate rather than about queue alignment. (Measured in the first RED run and recorded in the Task 6
# report.)
#
# AND NO ASSERTION HERE EXPECTS A HIT TO DEAL LESS THAN 2. mw_assault_rifle is RELIABLE 2 and
# attack_util.gd:144-147 floors the TOTAL of a roll at `reliable` on a HIT exactly as on a miss - the
# Task 2 measurement. The self-hit case below is the only one where an 8 HP subject made the plan
# reach for a 1, and it uses 3 instead.
#
# THE ALLY IS A 200 HP DUMMY, so it survives every case and the damage numbers are the weapon's.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_astral_guardian.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## One tile east of the Sluagh: adjacent, by any measure.
const ADJACENT_TILE := Vector2i(5, 6)
## Two tiles east: NOT adjacent in vanilla, and exactly the tile House Guard's widening pulls in -
## which is what test_compat.gd asserts about in Task 9.
const TWO_OUT_TILE := Vector2i(6, 6)
## Five east of the Sluagh, four from the adjacent ally: inside the rifle's Range 10 of everyone.
const SHOOTER_TILE := Vector2i(9, 6)
## A second hostile, so the two shots in the 1/round case come from different shooters and neither
## per-turn nor per-round weapon bookkeeping is in the way.
const SECOND_SHOOTER_TILE := Vector2i(9, 8)
## A friendly shooter, for the "an allied attacker's hit grants nothing" case.
const FRIEND_SHOOTER_TILE := Vector2i(4, 9)

## Beats the dummy's evasion 10 and never crits (19 minus the worst accuracy die is 13).
const D20_HITS := 19
const D20_MISSES := 1
## The guardian's d6, cheated. Chosen BELOW the damage die so "granted first" and "granted last" give
## different HP as well as different Overshield.
const GUARDIAN_D6 := 4
## The rifle's damage d6, cheated.
const DAMAGE_DIE := 5
## The damage die for the one case whose subject is the 8 HP mech rather than a 200 HP dummy. Above
## the rifle's RELIABLE 2 (so it is the die that is read, not the floor) and well under 8.
const SELF_HIT_DIE := 3

var game:Gamemaster
var sluagh:Unit
var ally:Unit
var shooter:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	ally = SluaghFixture.create_ally(game, ADJACENT_TILE)
	shooter = SluaghFixture.create_hostile(game, SHOOTER_TILE)
	SluaghFixture.arm_rifle(shooter)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear() -> GearCore: return sluagh.get_gear(SluaghFixture.CORE_ID)

func guardian() -> Action:
	var gear:GearCore = core_gear()
	return gear.get_action(SluaghFixture.GUARDIAN_ID) if GearCore.is_valid(gear) else null

## How many times the reaction has fired this round, read off the engine's own per-round tally rather
## than off a counter of our own - test_uffish_gyre.gd's idiom.
func guardian_uses_this_round() -> int:
	var gear:GearCore = core_gear()
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(guardian()))

# ---------------------------------------------------------------- the wiring

func test_the_core_kit_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.CORE_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % SluaghFixture.CORE_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'A core system is a frame trait, not equippable gear.')
	assert_true(GearCore.is_valid(core_gear()), 'And the live Sluagh carries it as gear.')
	assert_not_null(guardian(), 'And the Kit carries action_astral_guardian by that id.')

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_cry_of_the_hosted_dead.name', 'gear.cp_cry_of_the_hosted_dead.effect',
			'gear.cp_cry_of_the_hosted_dead.action_astral_guardian.name']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_cry_of_the_hosted_dead.name'), 'Cry of the Hosted Dead', 'The core\'s name.')
	# THE KIT'S EFFECT ROW IS THE PASSIVE'S TEXT, which is MÖBIAN RAINBOW's arrangement exactly: the
	# engine has no separate key for a core power's passive, so gear.<cp>.effect is where it goes.
	assert_true(X.tr('gear.cp_cry_of_the_hosted_dead.effect').ends_with('before damage is dealt.'),
		'And the Kit\'s effect row is Astral Guardian\'s own text, entire.')
	# THE REACTION CARRIES A NAME ROW AND NO EFFECT ROW, and both halves are deliberate.
	# ActionReaction.log_usage writes a battle-log line naming the action every time it fires
	# (action_reaction.gd:31-40), and Translate.action falls back to gear.<kit>.name when the action
	# has no row (translate.gd:44-45) - so without this the log would say "Cry of the Hosted Dead".
	# "Astral Guardian" is the LCP's own passive_name, so nothing is invented. There is NO effect row,
	# because the Kit's covers it and a second copy on the card would read as two abilities.
	assert_eq(X.tr('gear.cp_cry_of_the_hosted_dead.action_astral_guardian.name'), 'Astral Guardian',
		'The battle log names the passive, off the LCP\'s own passive_name.')
	assert_eq(translation.get_message('gear.cp_cry_of_the_hosted_dead.action_astral_guardian.effect'),
		StringName(''), 'And it deliberately has no effect row of its own.')

func test_the_reaction_is_a_hidden_point_free_one_per_round_attacked_reaction():
	var gear:GearCore = core_gear()
	var reaction = guardian()
	assert_true(GearCore.is_valid(gear) and reaction != null, 'fixture: the reaction is on the unit.')
	if not GearCore.is_valid(gear) or reaction == null: return
	assert_true(reaction is ActionReactionAttacked,
		'ActionReactionAttacked, not the plain base the Task 0 probe used - the archetype supplies '
		+ 'require_hit, both relation filters and the character test.')
	if reaction is not ActionReactionAttacked: return
	assert_eq(reaction.triggers_on, [&'attack'] as Array[StringName], 'ATTACK...')
	assert_eq(reaction.trigger_timing, ReactionBus.TIMING.POST,
		'...at POST, which is where the roll exists AND is still before the damage.')
	assert_true(reaction.require_hit, 'Only a hit.')
	assert_false(reaction.require_miss, 'And not a miss - that is the Mark\'s reaction, Task 8.')
	assert_eq(reaction.require_attacker_relation, ActionReactionAttacked.RELATION.ENEMIES,
		'Made by a hostile...')
	assert_eq(reaction.require_defender_relation, ActionReactionAttacked.RELATION.ALLIES,
		'...against an ally.')
	assert_true(reaction.require_defender_to_be_character, 'An allied CHARACTER.')
	# BOTH FLAGS, and both are departures from the design doc's field list (Departure 1). They default
	# FALSE (action_reaction_attacked.gd:42-43), which would silently exclude a hostile invade and a
	# hostile basic attack from a card that says only "an attack". Vanilla's own
	# action_focused_shielding_aegis.tres - shield an ally who was hit - sets allow_basic.
	assert_true(reaction.allow_tech, 'A tech attack is an attack (ruling 9\'s reading, one card over).')
	assert_true(reaction.allow_basic, 'And so is a basic one.')
	# NEVER require_defender_within: that is a radius (distance_between, :92), and ruling 6 has this
	# card taking House Guard's widening, which reaches is_adjacent and nothing that measures a radius.
	assert_eq(reaction.require_defender_within, 0,
		'The adjacency is is_adjacent in the script, NOT a radius on the .tres (ruling 6).')
	assert_false(reaction.consumes_rxn,
		'It costs no reaction point - the card names none, and it must fire on an enemy turn.')
	assert_false(reaction.show_in_tooltip(gear.kit), 'And it never reaches the trait card.')
	# ActionReaction returns 99 for a point-free reaction (action_reaction.gd:69); the card says
	# 1/round, so this one is overridden - unlike the Stealing's, which is not.
	assert_eq(reaction.get_per_round_hard_limit(SpecificAction.create(sluagh, gear, reaction)), 1,
		'1/round, overriding ActionReaction\'s 99 for a point-free reaction.')

# ---------------------------------------------------------------- the card

func test_a_hostile_hit_on_an_adjacent_ally_grants_a_d6_before_the_damage():
	# THE WHOLE CARD IN THREE NUMBERS. Granted first, the 4 absorbs 4 of the 5 and 1 reaches HP.
	# Granted last, the ally would read 4 Overshield and 5 damage. Task 0 proved the ordering on a
	# probe; this is the real card saying the same thing.
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'The reaction fired exactly once.')
	assert_eq(ally.current_damage(), DAMAGE_DIE - GUARDIAN_D6,
		'Only 1 of the 5 reached HP: the 4 Overshield was there first and absorbed the rest.')
	assert_eq(Overshield.current(ally), 0, 'And the shield is spent, which is what absorbing means.')

func test_an_ally_two_tiles_out_gets_nothing():
	var far:Unit = SluaghFixture.create_ally(game, TWO_OUT_TILE)
	assert_false(UnitRelation.is_adjacent(sluagh, far), 'fixture: two tiles is not adjacent.')
	# BOTH SLOTS THE SAME NUMBER - see the file header. The guardian must not fire here, so the damage
	# roll takes the SECOND entry; writing DAMAGE_DIE twice makes the hit land 5 either way, so the
	# assertion below is about the gate rather than about which entry the damage die reached.
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, far)
	assert_eq(guardian_uses_this_round(), 0, 'The reaction did not fire.')
	assert_eq(Overshield.current(far), 0, 'And the ally got nothing.')
	assert_eq(far.current_damage(), DAMAGE_DIE, 'It took the whole 5 on HP.')

func test_a_hit_on_the_sluagh_itself_gets_nothing():
	# "an ADJACENT ALLIED CHARACTER" - and UnitRelation.are_allies is true of a unit and itself, so
	# the archetype's ALLIES filter passes the Sluagh. TWO clauses in the script refuse it and EITHER
	# ALONE IS ENOUGH TODAY, which the plan's own comment did not know: `defender != unit`, and the
	# adjacency clause, because is_adjacent(u, u) is already false - adjacent_characters goes through
	# get_units_within, whose first clause is `other_unit != unit` (unit_relation.gd:58). Measured in
	# SP1 Task 6: neutralising either one alone leaves this test GREEN, and neutralising both together
	# reddens it. The redundancy is deliberate and is recorded in the script's header - a third party
	# widening adjacent_characters (ruling 6's seam, which this card TAKES) could put the Sluagh in
	# its own adjacency, and `defender != unit` is what would still refuse it then.
	#
	# THE DAMAGE DIE IS DROPPED TO 3 HERE, because the subject is the 8 HP mech rather than the
	# 200 HP dummy and a 5 would take most of it. NOT the plan's 1: the rifle is RELIABLE 2 and
	# attack_util.gd:144-147 floors a HIT's total at 2, so a 1 would be unreadable. Both slots carry
	# it, per the file header.
	SluaghFixture.queue([D20_HITS, SELF_HIT_DIE, SELF_HIT_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(guardian_uses_this_round(), 0, 'The Sluagh does not guard itself.')
	assert_eq(Overshield.current(sluagh), 0, 'It gained nothing...')
	assert_eq(sluagh.current_damage(), SELF_HIT_DIE, '...and took the hit.')

func test_a_miss_on_an_adjacent_ally_gets_nothing():
	SluaghFixture.queue([D20_MISSES, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 0, 'require_hit: a miss offers nothing.')
	assert_eq(Overshield.current(ally), 0, 'And the ally gained nothing.')

func test_an_allied_attackers_hit_gets_nothing():
	# An invade against an ally AUTO-HITS, so this is a guaranteed hit by a non-hostile - which makes
	# the green a statement about require_attacker_relation and not about the dice.
	var friend:Unit = SluaghFixture.create_ally(game, FRIEND_SHOOTER_TILE)
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6])
	await SluaghFixture.invade(game, friend, ally)
	assert_eq(guardian_uses_this_round(), 0, 'An ALLY hitting the ally offers nothing.')
	assert_eq(Overshield.current(ally), 0, 'And nothing was granted.')

func test_a_hit_on_an_adjacent_allied_drone_grants_too():
	# "A character": is_character(), a drone included (ruling 2026-09-27, mod-wide). The archetype's
	# require_defender_to_be_character already asks exactly this (action_reaction_attacked.gd:95),
	# and the script's own `defender.is_character()` clause now asks the same predicate - a redundant
	# restatement, not a narrowing. The canonical paragraph is in action_stealing_of_the_souls.gd's
	# header.
	#
	# THE TWO SETUP ASSERTIONS ARE KEPT AS ENGINE FACTS: a drone really is a character and really is
	# not an actor, though the second no longer decides anything here.
	var drone:Unit = SluaghFixture.create_drone(game, ADJACENT_TILE + Vector2i(0, 1))
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor - which no longer matters, since the gate asks is_character().')
	assert_true(UnitRelation.is_adjacent(sluagh, drone), 'fixture: and it is adjacent.')
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, drone)
	assert_eq(guardian_uses_this_round(), 1, 'An adjacent allied DRONE is guarded too.')
	assert_eq(Overshield.current(drone), 0, 'The 4 Overshield absorbed 4 of the 5...')
	assert_eq(drone.current_damage(), DAMAGE_DIE - GUARDIAN_D6, '...and only 1 reached HP.')

func test_a_hostile_tech_hit_on_an_adjacent_ally_grants_too():
	# DEPARTURE 1, both halves at once: ms_fragment_signal is an ActionAttackTech AND it is basic
	# gear, so this case needs allow_tech and allow_basic together. With the archetype's defaults it
	# is refused at action_reaction_attacked.gd:113 and :126-127 and nothing fires.
	#
	# A hostile invade rolls against E-DEF, and the dummy ally's is its frame default; 19 clears it.
	# It deals NO damage of its own, so the ally keeps the whole d6.
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6])
	await SluaghFixture.invade(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'A hostile TECH attack that hits fires it too.')
	assert_eq(Overshield.current(ally), GUARDIAN_D6, 'And the whole d6 survives - a tech hit deals no damage.')

# ---------------------------------------------------------------- the round

func test_the_second_qualifying_hit_in_a_round_gets_nothing():
	# 1/ROUND, and it is the ENGINE's limit rather than a counter of ours: get_per_round_hard_limit
	# is consulted inside ReactionBus.does_reaction_trigger via can_activate_gear, so a second
	# guardian is never OFFERED rather than offered and refused.
	#
	# TWO SHOOTERS, so neither the per-turn soft limit nor the weapon's own round tally is in the way
	# and the only limit being tested is the reaction's.
	#
	# NO SLUAGH TURN STARTS HERE. uses_this_round is cleared by UnitAction.new_turn_refresh at the
	# SLUAGH's own turn start, and SluaghFixture.shoot cycles only the SHOOTER's turn.
	var second:Unit = SluaghFixture.create_hostile(game, SECOND_SHOOTER_TILE)
	SluaghFixture.arm_rifle(second)

	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'fixture: the first hit fired it.')
	var after_first:int = ally.current_damage()

	# THE SECOND QUEUE IS THE NEGATIVE FORM (both slots the same), because the guardian must NOT fire
	# this time and nothing pops the middle entry - see the file header.
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, second, ally)
	assert_eq(guardian_uses_this_round(), 1, 'Still one: the second hit was never offered.')
	assert_eq(ally.current_damage() - after_first, DAMAGE_DIE,
		'So the ally took the whole 5 that time, with nothing to absorb it.')

func test_the_next_round_works_again():
	# "1/round" in this engine means "once since the holder's own turn start" - uses_this_round is
	# cleared by reset_per_round_usage inside UnitAction.new_turn_refresh, which runs only at the
	# SLUAGH's turn start. Draw Fire ruling 3 records the same property from the other side, and this
	# is the half that proves the limit is not permanent.
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'fixture: spent.')

	await SpecFactory.start_turn(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_eq(guardian_uses_this_round(), 0, 'The Sluagh\'s own turn start cleared the tally.')

	var before:int = Overshield.current(ally)
	SluaghFixture.queue([D20_HITS, GUARDIAN_D6, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'And it fires again.')
	assert_ne(Overshield.current(ally) + ally.current_damage(), before,
		'Something actually happened, rather than the tally moving alone.')

func test_a_grant_below_the_allys_overshield_changes_nothing_and_still_spends_the_round():
	# RULING 13's max-semantics half: event_unit_overshield sets max(old, amount) and never adds
	# (event_unit_overshield.gd:15), so a d6 under what the ally already holds moves no number at
	# all - and the card is "they gain", so the round is spent regardless. Both halves are asserted,
	# because the first alone is satisfied by a reaction that never fired.
	await SluaghFixture.grant_overshield(ally, 6)
	SluaghFixture.queue([D20_HITS, 2, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)
	assert_eq(guardian_uses_this_round(), 1, 'The round was spent...')
	assert_eq(Overshield.current(ally), 6 - DAMAGE_DIE,
		'...and the roll of 2 changed nothing: the ally kept its 6 and spent 5 of it on the hit.')
