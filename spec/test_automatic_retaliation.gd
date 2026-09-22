# THE AUTOMATIC RETALIATION CORE (Leoleth rank III, design ruling 17):
#
#   "While the A.R.C systems are active, you gain the following effects:
#    - Whenever you take damage from a hostile character for the first time each round, you
#      automatically retaliate, and must immediately attack the closest character -hostile or
#      allied- within Threat with a non-Superheavy melee attack as a reaction. If there are more
#      than one characters tied for closest, you attack one at random.
#    - You deal +1d6 bonus damage on a successful melee attack against Slowed or Impaired targets.
#    - You gain 1 heat every time you make an attack.
#    You can begin to deactivate this system as a protocol. At the start of your next turn it
#    deactivates."
#
# THE BERSERKER'S AGGRESSION IS THE REFERENCE (content/frames/npc/npcc_berserker/aggression/), and
# this card differs from it in three ways it names outright: THREAT rather than adjacency, CLOSEST
# rather than random, and a REAL reaction (consumes_rxn, so the point is the price and the 1/round
# comes free from ActionReaction.get_per_round_hard_limit, action_reaction.gd:69 - which is why the
# production script does NOT override that method).
#
# THE FOUR GATES ARE ALL SEPARATELY TESTED because three of them can hide each other. "The point is
# spent", "the round is spent", "nothing is in threat" and "the chip is not held" each refuse the
# same way - silently - so a test that arranges two of them at once proves nothing about either.
#
# THE TURN CYCLE HANDS THE POINT BACK. UnitAction.every_new_turn_refresh runs for EVERY unit on the
# map at ANY unit's turn start (event_turn_start.gd:42-44), while reset_per_round_usage runs for the
# STARTING unit only (unit_action.gd:78). LeolethFixture.shoot() cycles the shooter's turn, so it
# refreshes the Leoleth's reaction POINT and leaves its per-round TALLY alone; shoot_again() cycles
# nothing. Every test below picks the one it means.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_automatic_retaliation.gd
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

const LEOLETH_TILE := Vector2i(6, 6)
## Far enough that the shooter is never itself a retaliation candidate: the melee weapon's threat
## is 1, and every "nothing in threat" test depends on that being true of the DAMAGER too.
const SHOOTER_TILE := Vector2i(16, 6)
const NEAR_TILE := Vector2i(7, 6)   ## adjacent, inside threat 1
const FAR_TILE := Vector2i(9, 6)    ## three out, outside threat 1
const OPPOSITE_TILE := Vector2i(5, 6) ## adjacent on the other side - the tie case

var game:Gamemaster
var leoleth:Unit
var shooter:Unit

func before_each() -> void:
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	shooter = LeolethFixture.create_hostile(game, SHOOTER_TILE)
	# EQUIP BEFORE PRESSING ANYTHING. equip() calls full_repair, which refunds the core power and
	# re-arms the frame - see the fixture's header.
	LeolethFixture.arm_melee(leoleth)
	LeolethFixture.arm_jormungandr(leoleth)
	# THE SHOOTER NEEDS A GUN. SpecFactory.create_unit hands out no weapons, and use_solo on an
	# unarmed unit dies inside spec_factory with 'Nonexistent function get_solo_action in base Nil'
	# rather than failing an assertion.
	LeolethFixture.arm_rifle(shooter)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ------------------------------------------------------------------ helpers

## The dice for ONE shot at the Leoleth that lands, followed by ONE retaliation that lands.
##
## THE TAIL IS 4s, NOT THE FIXTURE'S 1s, AND THAT IS THIS TEST FILE. LeolethFixture.queue() tails
## with 1s because its subject is an 8 HP frame; here the frame takes exactly one explicitly-sized
## hit and everything after it is rolled BY the Leoleth against a 200 HP dummy, where a 1 is
## indistinguishable from a floor and a miss.
##
## [shooter d20, rifle hit column, rifle crit column, leoleth d20, ...4s]. The shooter's 1d6 of 5
## lands 4 on an 8 HP frame with armor 1 - real damage, comfortably short of a structure.
##
## A DAMAGE ROLL POPS TWO DICE, NOT ONE, and that is what this queue exists to say. AttackUtil rolls
## the weapon's dice once per damage COLUMN - the log prints "if hit:5 if crit:19 if maximized:6" -
## so a queue written as [d20, damage, d20, damage] hands the retaliation's d20 whatever was meant
## to be the first weapon's crit column. Measured 2026-09-22: that exact queue made every
## retaliation miss on a 4 and three tests read "nothing happened".
func queue_hit_then_retaliation() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = [19, 5, 5, 19]
	for i:int in 60: rolls.append(4)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

## The dice for an attack the LEOLETH ITSELF makes and lands: [d20, then 4s].
##
## THE QUEUE ORDER IS THE WHOLE DIFFERENCE between these two families of helper. A provoked
## retaliation is the SECOND attack in its queue - the shot that provoked it pops a d20 and its
## damage first - while a swing or a shot made directly by the Leoleth is the first. One helper for
## both would have made "the swing missed" pass on a hit.
func queue_leoleth_attack() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = [19]
	for i:int in 60: rolls.append(4)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

## The same, but the roll cannot beat any evasion this fixture hands out.
func queue_a_missed_leoleth_attack() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var rolls:Array[int] = [1]
	for i:int in 60: rolls.append(4)
	Dice.CHEAT_ROLL_QUEUE.assign(rolls)

func hp(unit:Unit) -> int: return unit.core.current.health
func damage_taken(unit:Unit) -> int: return unit.core.get_health_max() - hp(unit)

## Take TOE TO TOE off the board before a test ends the Leoleth's turn.
##
## TOE TO TOE IS AN UNLISTED SECOND ATTACKER ON THIS FRAME, and it is the confound every provoked
## test here has to close. It fires at END_TURN PRE and gives the Leoleth a free Skirmish at
## anything a melee weapon can reach (ruling 3) - so in a test that opens the Leoleth's turn to
## press a protocol and then ends it to shoot, the victim standing in threat takes damage that
## reads exactly like a retaliation, and every targeting assertion below would pass whether or not
## the A.R.C. did anything at all. Measured 2026-09-22: it fired in each of them.
##
## ITS GATE IS `current.speed >= get_speed_max()` (ruling 2), so ONE spent space closes it. Spent
## directly rather than walked, because a real step would move the Leoleth and re-order every
## distance this card is about. test_toe_to_toe_is_really_off_in_these_tests is what keeps this
## helper from silently becoming a no-op.
func spend_a_space(unit:Unit = leoleth) -> void:
	unit.core.current.speed -= 1

## One attack with the Leoleth's turn ALREADY open and nothing cycled.
##
## LeolethFixture.swing() cannot be used for a heat or a damage measurement: it opens with
## end_turn, which is where Toe To Toe offers its own free Skirmish - a second attack, which
## correctly costs a second point of heat and lands a second lot of damage.
##
## Action.FLAG.AS_FREEBIE is how a second measurement fits in the same turn: it bypasses the
## per-turn soft limit (action.gd:161-163) without touching anything this card reads.
func attack_in_place(kit_id:StringName, target:Unit, flags:Array = []) -> void:
	await SpecFactory.use_solo(game, leoleth, kit_id, target, flags)

func swing_in_place(target:Unit, flags:Array = []) -> void:
	await attack_in_place(LeolethFixture.MELEE_KIT, target, flags)

## The Kit's reaction, as a SpecificAction - the handle every candidate assertion reads through.
func reaction() -> SpecificAction:
	return SpecificAction.from_id(leoleth, LeolethFixture.JORMUNGANDR_ID, LeolethFixture.ARC_REACTION)

func retaliation() -> ActionReaction:
	var specific := reaction()
	return specific.action as ActionReaction if SpecificAction.is_valid(specific) else null

# ------------------------------------------------------------------ the wiring

func test_the_kit_is_a_unique_ai_nhp_costing_three_sp():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.JORMUNGANDR_ID)
	assert_true(Kit.is_valid(kit), '%s is in the kits index.' % LeolethFixture.JORMUNGANDR_ID)
	if not Kit.is_valid(kit): return
	# Unique 1 + AI 4 + NHP 8 = 13 (kit.gd:30), every vanilla NHP's value and the Morrigan's.
	assert_eq(kit.system_tags, 13, 'UNIQUE + AI + NHP.')
	assert_eq(kit.sp_cost, 3, 'SP 3, off the sheet.')
	assert_true(kit.is_ai(), 'is_ai() is what the one-AI limit reads.')

func test_the_kit_carries_two_protocols_and_one_reaction():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.JORMUNGANDR_ID)
	if not Kit.is_valid(kit): return fail_test('the Kit resolves.')
	var ids:Array[StringName] = []
	for action:Action in kit.actions: ids.append(action.get_id())
	assert_eq(ids.size(), 3, 'Three actions.')
	assert_true(ids.has(LeolethFixture.ARC_ACTIVATE), 'The activation protocol.')
	assert_true(ids.has(LeolethFixture.ARC_DEACTIVATE), 'The deactivation protocol.')
	assert_true(ids.has(LeolethFixture.ARC_REACTION), 'And the retaliation reaction.')

func test_every_action_owns_its_usage_group():
	# THE SINGLE MOST LOAD-BEARING LINE ON THIS KIT. GearCore.get_usage_group_for_action falls back
	# to the KIT id when an action names no group (gear_core.gd:166-168), and UnitAction.spend
	# records every activation under that group - so with the groups left blank, PRESSING THE
	# PROTOCOL would spend the reaction's whole round, silently, with no log line (memory
	# lancer-tactics-reactions-and-usage).
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.JORMUNGANDR_ID)
	if not Kit.is_valid(kit): return fail_test('the Kit resolves.')
	var groups:Array[StringName] = []
	for action:Action in kit.actions:
		assert_false(action.usage_group.is_empty(),
			'%s names its own usage group.' % action.get_id())
		assert_false(groups.has(action.usage_group),
			'%s does not share a group with a sibling.' % action.get_id())
		groups.append(action.usage_group)

func test_the_retaliation_is_a_real_reaction_and_does_not_re_declare_its_own_limit():
	var rxn := retaliation()
	if rxn == null: return fail_test('the reaction resolves.')
	assert_true(rxn.consumes_rxn, 'A REAL reaction - the card calls it one, and the point is its price.')
	assert_false(rxn.counts_as_free_action, 'Not a free action: it fires on somebody else\'s turn.')
	assert_eq(rxn.triggers_on, [&'damage'] as Array[StringName], 'Triggers on damage...')
	assert_eq(rxn.trigger_timing, ReactionBus.TIMING.POST, '...at POST, once the number is final.')
	# get_per_round_hard_limit already returns 1 for a consumes_rxn reaction (action_reaction.gd:69).
	# Overriding it would be an inert line that reads as load-bearing.
	assert_eq(rxn.get_per_round_hard_limit(reaction()), 1,
		'"for the first time each round" is the ENGINE\'s, not ours.')
	assert_eq(rxn.get_priority(), Priority.DAMAGE.counterattack,
		'The Berserker\'s counterattack slot.')

func test_the_ai_privilege_hands_over_task_ones_portrait_and_barkset():
	var kit:Kit = ContentLibrary.get_kit(LeolethFixture.JORMUNGANDR_ID)
	if not Kit.is_valid(kit): return fail_test('the Kit resolves.')
	# get_passives is typed Array[Passive] whatever it filters for (kit.gd:157), so the narrowing
	# happens here - an Array[PassiveAiPrivilege] local would not parse, and a spec that fails to
	# parse is SKIPPED rather than failed.
	var found:Array[Passive] = kit.get_passives(PassiveAiPrivilege)
	assert_eq(found.size(), 1, 'Exactly one PassiveAiPrivilege.')
	if found.is_empty(): return
	var ai := found[0] as PassiveAiPrivilege
	assert_not_null(ai.default_portrait, 'It hands out a portrait JSON...')
	assert_true(BarkSet.is_valid(ai.default_barkset), '...and a barkset.')
	if BarkSet.is_valid(ai.default_barkset):
		assert_eq(ai.default_barkset.compcon_id, LeolethFixture.JORMUNGANDR_BARKSET,
			'And it is bark_nhp_jormungandr - the ASCII filename every bark key is built from.')

func test_the_pilot_adopts_the_name_the_face_and_the_voice_on_a_print():
	# THE NAME IS GATED ON THE PORTRAIT: the nhp_name assignment sits INSIDE the
	# `if passive.default_portrait:` branch (passive_ai_privilege.gd:66-70), reached from
	# UnitPrinter.full_repair (:79). All three ship together or none of them reach the pilot.
	leoleth.core.pilot.nhp_name = ''
	leoleth.core.pilot.nhp_portrait_json = {}
	leoleth.core.pilot.nhp_barks = null
	leoleth.core.full_repair()
	assert_eq(leoleth.core.pilot.nhp_name, 'JÖRMUNGANDR',
		'gear.ms_jormungandr_class_nhp.default_name - the diaeresis lives in the ROW.')
	assert_true(leoleth.core.pilot.nhp_portrait_json.get('is_nhp', false), 'The face arrived.')
	assert_true(BarkSet.is_valid(leoleth.core.pilot.nhp_barks), 'And the voice.')
	if BarkSet.is_valid(leoleth.core.pilot.nhp_barks):
		assert_eq(leoleth.core.pilot.nhp_barks.compcon_id, LeolethFixture.JORMUNGANDR_BARKSET,
			'This barkset, as a duplicate.')

# ------------------------------------------------------- the protocol and the chip

func test_the_protocol_hangs_the_chip():
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP), 'Nothing held to begin with.')
	await LeolethFixture.press_arc(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP), 'A.R.C. active.')

func test_the_activation_protocol_is_unavailable_while_the_chip_is_held():
	await LeolethFixture.press_arc(game, leoleth)
	var specific := SpecificAction.from_id(leoleth, LeolethFixture.JORMUNGANDR_ID, LeolethFixture.ARC_ACTIVATE)
	assert_false(UnitAction.is_gear_available(specific),
		'can_reapply FALSE - pressing again would re-hang a chip we already hold.')

func test_the_deactivation_protocol_is_unavailable_until_the_chip_is_held():
	var specific := SpecificAction.from_id(leoleth, LeolethFixture.JORMUNGANDR_ID, LeolethFixture.ARC_DEACTIVATE)
	assert_false(UnitAction.is_gear_available(specific), 'Nothing to begin deactivating.')
	await LeolethFixture.press_arc(game, leoleth)
	assert_true(UnitAction.is_gear_available(specific), 'And now there is.')

# ------------------------------------------------------------------ the retaliation

func test_the_closest_character_in_threat_is_attacked():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_lt(hp(victim), victim.core.get_health_max(),
		'The character in threat was struck by the retaliation.')
	assert_lt(hp(leoleth), leoleth.core.get_health_max(), 'And the shot that provoked it landed.')

func test_an_ally_is_attacked_when_the_ally_is_the_closest():
	# "the closest character -hostile or allied-". The card is explicit and this is the test that
	# says so: the hostile is further out, so it must be passed over.
	var ally := LeolethFixture.create_ally(game, NEAR_TILE)
	var hostile := LeolethFixture.create_hostile(game, FAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_lt(hp(ally), ally.core.get_health_max(), 'The ALLY was the closest, so the ally was hit.')
	assert_eq(hp(hostile), hostile.core.get_health_max(), 'And the hostile out of threat was not.')

func test_the_closest_of_two_in_threat_is_chosen_whichever_was_placed_first():
	# THE TEST THAT ACTUALLY EXERCISES "CLOSEST", and neither of the two above did. With the
	# tactical melee weapon's Threat 1 there is only ever ONE tile in reach, so a second candidate
	# is excluded by reach rather than by distance and the sort is never asked anything. MEASURED
	# 2026-09-22: neutralising the distance compare to "keep the first candidate you see" reddened
	# NOTHING until this test existed.
	#
	# THE REGISTRATION ORDER IS ADVERSARIAL ON PURPOSE - map.get_all_units walks in the order units
	# were added, so the FURTHER one is created first here. A "closest" that merely kept the first
	# candidate would now pick it and fail.
	#
	# ITS OWN LEOLETH, carrying ONLY the Reliable Sword (HEAVY MELEE, Threat 2). One eligible weapon
	# means choose_and_use auto-picks and raises no menu (common_action_util.gd:658-659), which
	# keeps this test about distance and not about a prompt.
	var swordsman := LeolethFixture.create_leoleth(game, Vector2i(6, 9))
	LeolethFixture.equip(swordsman, LeolethFixture.RELIABLE_SWORD)
	LeolethFixture.arm_jormungandr(swordsman)
	var two_out := LeolethFixture.create_hostile(game, Vector2i(8, 9))
	var next_door := LeolethFixture.create_hostile(game, Vector2i(7, 9))
	await LeolethFixture.press_arc(game, swordsman)
	spend_a_space(swordsman)
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, swordsman)
	assert_lt(hp(next_door), next_door.core.get_health_max(), 'The adjacent one was struck...')
	assert_eq(hp(two_out), two_out.core.get_health_max(),
		'...and the one two spaces out, in Threat but further, was passed over.')

func test_a_tie_for_closest_picks_exactly_one_of_the_tied():
	var left := LeolethFixture.create_hostile(game, OPPOSITE_TILE)
	var right := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	var struck:int = 0
	if hp(left) < left.core.get_health_max(): struck += 1
	if hp(right) < right.core.get_health_max(): struck += 1
	assert_eq(struck, 1, '"you attack one at random" - exactly one of the two tied, never both.')

func test_a_character_outside_threat_is_never_reached():
	var far := LeolethFixture.create_hostile(game, FAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(hp(far), far.core.get_health_max(), 'Out of Threat, so no candidate.')
	assert_true(LeolethFixture.has_reaction_point(leoleth),
		'And with no candidate the reaction is not offered at all, so the point is not spent.')

func test_a_superheavy_only_loadout_retaliates_with_nothing():
	# "with a non-Superheavy melee attack". ActionAttackWeapon.get_action_type reports FULL for a
	# SUPERHEAVY (action_attack_weapon.gd:87-91), and the card rules it out by name besides.
	var bare := LeolethFixture.create_leoleth(game, Vector2i(6, 9))
	LeolethFixture.equip(bare, LeolethFixture.SUPERHEAVY_MELEE)
	LeolethFixture.arm_jormungandr(bare)
	var victim := LeolethFixture.create_hostile(game, Vector2i(7, 9))
	await LeolethFixture.press_arc(game, bare)
	spend_a_space(bare)
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, bare)
	assert_eq(hp(victim), victim.core.get_health_max(), 'A Superheavy cannot answer for this card.')
	assert_true(LeolethFixture.has_reaction_point(bare), 'And the point is untouched.')

func test_nothing_happens_without_the_chip():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(hp(victim), victim.core.get_health_max(),
		'"While the A.R.C systems are active" - and they are not.')

func test_nothing_happens_with_the_reaction_point_already_spent():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	# The point has to be spent AFTER the shooter's turn opens: every_new_turn_refresh would hand it
	# straight back (see the header).
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, shooter)
	UnitAction.spend_reaction(leoleth)
	assert_false(LeolethFixture.has_reaction_point(leoleth), 'The point really is gone.')
	queue_hit_then_retaliation()
	await LeolethFixture.shoot_again(game, shooter, leoleth)
	assert_lt(hp(leoleth), leoleth.core.get_health_max(), 'The shot still landed...')
	assert_eq(hp(victim), victim.core.get_health_max(), '...and no retaliation answered it.')

func test_only_the_first_hit_each_round_retaliates():
	# THE POINT IS HANDED BACK DELIBERATELY, so this test is about the ROUND and not about the
	# point. Without that line the second hit would be refused by the spent point instead and the
	# 1/round rule would go untested (the two gates hide each other - see the header).
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	var after_first:int = hp(victim)
	assert_lt(after_first, victim.core.get_health_max(), 'The first hit was answered.')
	leoleth.core.current.reactions = leoleth.core.get_reactions_max()
	assert_true(LeolethFixture.has_reaction_point(leoleth), 'The point is available again...')
	queue_hit_then_retaliation()
	await LeolethFixture.shoot_again(game, shooter, leoleth)
	assert_eq(hp(victim), after_first,
		'...and the second hit in the SAME round is still not answered.')

func test_heat_damage_is_not_damage_for_this_card():
	# The Berserker's Aggression excludes heat the same way (action_aggression_berserker.gd:20).
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	await game.execute_event(&'event_unit_damage', {
		unit = leoleth, number = 2, category = Lancer.DAMAGE_TYPE.HEAT, target_unit = shooter,
	})
	assert_eq(hp(victim), victim.core.get_health_max(), 'Heat provokes nothing.')

func test_a_damager_that_is_not_a_hostile_character_provokes_nothing():
	# "from a hostile character". An ALLY's friendly fire is damage taken and is not a provocation.
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	var ally := LeolethFixture.create_ally(game, Vector2i(6, 3))
	await LeolethFixture.press_arc(game, leoleth)
	await game.execute_event(&'event_unit_damage', {
		unit = leoleth, number = 2, category = Lancer.DAMAGE_TYPE.KINETIC, target_unit = ally,
	})
	assert_eq(hp(victim), victim.core.get_health_max(), 'An ally\'s hit is not a provocation.')

# ---------------------------------------------------- the weapon the player picks

func test_one_eligible_weapon_raises_no_menu_and_two_do():
	# The pick menu is a ChoiceBus.TYPE.gear request that testkit/prompt_watcher.gd does not report,
	# and choose_and_use auto-picks a lone option for a player-controlled unit
	# (common_action_util.gd:658-659) - so the offer is read at its SOURCE, the way
	# test_toe_to_toe.gd reads eligible_attacks.
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	var rxn := retaliation()
	if rxn == null: return fail_test('the reaction resolves.')
	assert_eq(rxn.eligible_attacks(leoleth, victim).size(), 1,
		'One melee weapon equipped, so one option and no menu.')
	LeolethFixture.equip(leoleth, LeolethFixture.RELIABLE_SWORD)
	assert_eq(rxn.eligible_attacks(leoleth, victim).size(), 2,
		'A second melee weapon is a second option, and the player picks.')

func test_a_superheavy_profile_is_never_among_the_options():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	LeolethFixture.equip(leoleth, LeolethFixture.SUPERHEAVY_MELEE)
	var rxn := retaliation()
	if rxn == null: return fail_test('the reaction resolves.')
	var offered:Array[SpecificAction] = rxn.eligible_attacks(leoleth, victim)
	assert_eq(offered.size(), 1, 'Still just the one non-Superheavy weapon.')
	for specific:SpecificAction in offered:
		assert_ne(specific.gear.kit.compcon_id, LeolethFixture.SUPERHEAVY_MELEE,
			'The Superheavy is excluded by name.')

func test_a_ranged_weapon_is_never_among_the_options():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	LeolethFixture.arm_rifle(leoleth)
	var rxn := retaliation()
	if rxn == null: return fail_test('the reaction resolves.')
	for specific:SpecificAction in rxn.eligible_attacks(leoleth, victim):
		assert_true(UnitAction.is_melee_weapon(specific.action, specific.gear),
			'"a non-Superheavy MELEE attack" - the rifle is not offered.')

# ------------------------------------------------------------------ the bonus damage

func test_a_melee_hit_on_a_slowed_target_rolls_the_extra_die():
	# ASSERTED AS A DIFFERENCE, not as an absolute: what this card adds is exactly one more d6, and
	# the cheated tail of 4s makes every die on both swings the same number.
	#
	# BOTH SWINGS HAPPEN IN ONE OPEN TURN, through attack_in_place. LeolethFixture.swing() opens with
	# end_turn, and END_TURN PRE is where Toe To Toe lands a free Skirmish of its own - a second lot
	# of damage on the same victim, which would have made this difference meaningless.
	var clean := LeolethFixture.create_hostile(game, NEAR_TILE)
	var slowed := LeolethFixture.create_hostile(game, Vector2i(5, 5))
	UnitCondition.apply_status(SpecFactory.dummy_event(), slowed, Lancer.STATUS.SLOWED, Lancer.UNTIL.MANUAL)
	await LeolethFixture.press_arc(game, leoleth)

	queue_leoleth_attack()
	await swing_in_place(clean)
	var without:int = damage_taken(clean)
	assert_gt(without, 0, 'The clean swing landed.')

	queue_leoleth_attack()
	await swing_in_place(slowed, [Action.FLAG.AS_FREEBIE])
	assert_eq(damage_taken(slowed) - without, 4,
		'+1d6, and the cheated die is a 4 - a Slowed target takes exactly that much more.')

func test_an_impaired_target_reads_the_same_as_a_slowed_one():
	var clean := LeolethFixture.create_hostile(game, NEAR_TILE)
	var impaired := LeolethFixture.create_hostile(game, Vector2i(5, 5))
	UnitCondition.apply_status(SpecFactory.dummy_event(), impaired, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.MANUAL)
	await LeolethFixture.press_arc(game, leoleth)

	queue_leoleth_attack()
	await swing_in_place(clean)
	var without:int = damage_taken(clean)

	queue_leoleth_attack()
	await swing_in_place(impaired, [Action.FLAG.AS_FREEBIE])
	assert_eq(damage_taken(impaired) - without, 4,
		'Impaired is the other half of the card and costs the same extra die.')

func test_a_ranged_hit_on_a_slowed_target_gets_nothing():
	# "on a successful MELEE attack". Two RIFLE shots rather than a rifle against a sword, because
	# the rifle pops a die of its own the sword does not: the 43 As puts -2 accuracy on every
	# non-melee attack, and Dice.roll_d6_accuracy rolls only when the bonus is non-zero
	# (dice.gd:86-88).
	var clean := LeolethFixture.create_hostile(game, FAR_TILE)
	var slowed := LeolethFixture.create_hostile(game, Vector2i(9, 8))
	UnitCondition.apply_status(SpecFactory.dummy_event(), slowed, Lancer.STATUS.SLOWED, Lancer.UNTIL.MANUAL)
	LeolethFixture.arm_rifle(leoleth)
	await LeolethFixture.press_arc(game, leoleth)

	queue_leoleth_attack()
	await attack_in_place(LeolethFixture.MAIN_RIFLE, clean)
	var without:int = damage_taken(clean)
	assert_gt(without, 0, 'The clean shot landed.')

	queue_leoleth_attack()
	await attack_in_place(LeolethFixture.MAIN_RIFLE, slowed, [Action.FLAG.AS_FREEBIE])
	assert_eq(damage_taken(slowed), without,
		'A ranged hit on a Slowed target gets no bonus at all.')

func test_the_bonus_needs_the_chip():
	var slowed := LeolethFixture.create_hostile(game, NEAR_TILE)
	var also_slowed := LeolethFixture.create_hostile(game, Vector2i(5, 5))
	for dummy:Unit in [slowed, also_slowed]:
		UnitCondition.apply_status(SpecFactory.dummy_event(), dummy, Lancer.STATUS.SLOWED, Lancer.UNTIL.MANUAL)
	await LeolethFixture.open_turn(game, leoleth)

	queue_leoleth_attack()
	await swing_in_place(slowed)
	var without_chip:int = damage_taken(slowed)

	# THE TURN HAS TO BE CYCLED HERE, unlike the tests above, and swinging first is why: taking a
	# non-protocol action ends the protocol phase (UnitAction.does_action_end_protocol_phase, read
	# inside spend at unit_action.gd:268), so pressing the A.R.C. afterwards is refused with
	# "[ Gear not available ] reason : protocol" - a red line in the log and a silently unpressed
	# protocol, not an assertion failure. spend_a_space keeps Toe To Toe out of the end_turn.
	spend_a_space()
	await SpecFactory.end_turn(game, leoleth)
	await LeolethFixture.press_arc(game, leoleth)
	queue_leoleth_attack()
	await swing_in_place(also_slowed)
	assert_eq(damage_taken(also_slowed) - without_chip, 4,
		'The die arrives with the chip and not before.')

# ------------------------------------------------------------------ the heat

func test_every_attack_costs_one_heat_while_the_chip_is_held():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	var before:int = leoleth.core.current.heat
	queue_leoleth_attack()
	await swing_in_place(victim)
	assert_eq(leoleth.core.current.heat, before + 1, '"You gain 1 heat every time you make an attack."')

func test_a_missed_attack_still_costs_the_heat():
	# "every time you MAKE an attack" - the card prices the swing, not the hit. attack_declared fires
	# whether or not the roll lands.
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	var before:int = leoleth.core.current.heat
	queue_a_missed_leoleth_attack()
	await swing_in_place(victim)
	assert_eq(hp(victim), victim.core.get_health_max(), 'The swing missed...')
	assert_eq(leoleth.core.current.heat, before + 1, '...and still cost its heat.')

func test_toe_to_toes_free_skirmish_costs_its_heat_too():
	# THE INTERACTION THAT MADE EVERY HEAT MEASUREMENT READ 2, asserted deliberately rather than
	# designed around. Toe To Toe is an attack like any other, so while the A.R.C. is up it costs
	# its own point of heat - and this is also what keeps spend_a_space() honest, because the second
	# half proves the helper really does shut that Skirmish off.
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	var before:int = leoleth.core.current.heat
	queue_leoleth_attack()
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(leoleth.core.current.heat, before + 1,
		'The free Skirmish at end of turn is an attack, and the A.R.C. prices it.')
	assert_lt(hp(victim), victim.core.get_health_max(), 'And it really swung.')

func test_toe_to_toe_is_really_off_once_a_space_is_spent():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	var before:int = leoleth.core.current.heat
	queue_leoleth_attack()
	await SpecFactory.end_turn(game, leoleth)
	assert_eq(leoleth.core.current.heat, before, 'No free Skirmish, so no heat...')
	assert_eq(hp(victim), victim.core.get_health_max(), '...and nothing was struck.')

func test_no_heat_without_the_chip():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	var before:int = leoleth.core.current.heat
	queue_leoleth_attack()
	await LeolethFixture.swing(game, leoleth, victim)
	assert_eq(leoleth.core.current.heat, before, 'No chip, no toll.')

func test_somebody_elses_attack_costs_the_leoleth_nothing():
	# The reaction bus offers every chip on the map every event (reaction_bus.gd:61-67), so the
	# holder check is not decoration.
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	var before:int = leoleth.core.current.heat
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, victim)
	assert_eq(leoleth.core.current.heat, before, 'The shooter\'s attack is the shooter\'s problem.')

# ------------------------------------------------------------------ deactivation

func test_the_chip_survives_the_turn_the_protocol_was_pressed_on():
	await LeolethFixture.press_arc(game, leoleth)
	await LeolethFixture.press_arc_deactivate(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP),
		'"You can BEGIN to deactivate" - it is still active for the rest of this turn.')

func test_the_chip_is_gone_at_the_next_turn_start():
	await LeolethFixture.press_arc(game, leoleth)
	await LeolethFixture.press_arc_deactivate(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP),
		'"At the start of your next turn it deactivates."')

func test_the_chip_survives_a_turn_start_when_the_protocol_was_never_pressed():
	# until = MANUAL, so nothing else can end it. This is the negative control for the stamp: a chip
	# that expired on its own would pass the test above for entirely the wrong reason.
	await LeolethFixture.press_arc(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP),
		'Un-stamped, the A.R.C. runs until it is told to stop.')

func test_somebody_elses_turn_start_does_not_deactivate_it():
	await LeolethFixture.press_arc(game, leoleth)
	await LeolethFixture.press_arc_deactivate(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, shooter)
	assert_true(LeolethFixture.has(leoleth, LeolethFixture.ARC_CHIP),
		'"YOUR next turn" - the hostile\'s turn start is not it.')

func test_the_retaliation_stops_once_the_chip_has_gone():
	var victim := LeolethFixture.create_hostile(game, NEAR_TILE)
	await LeolethFixture.press_arc(game, leoleth)
	spend_a_space()
	await LeolethFixture.press_arc_deactivate(game, leoleth)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, leoleth)
	queue_hit_then_retaliation()
	await LeolethFixture.shoot(game, shooter, leoleth)
	assert_eq(hp(victim), victim.core.get_health_max(), 'Deactivated means deactivated.')

# ------------------------------------------------------------------ the card

func test_the_card_text_is_the_lcp_verbatim():
	assert_eq(X.tr('gear.%s.name' % LeolethFixture.JORMUNGANDR_ID), 'Jörmungandr-Class NHP',
		'The name off the sheet, diaeresis and all.')
	var effect:String = X.tr('gear.%s.%s.effect' % [LeolethFixture.JORMUNGANDR_ID, LeolethFixture.ARC_ACTIVATE])
	assert_ne(effect, 'gear.%s.%s.effect' % [LeolethFixture.JORMUNGANDR_ID, LeolethFixture.ARC_ACTIVATE],
		'The protocol has an effect row at all.')
	assert_true(effect.contains('the closest character'), 'It carries the targeting clause...')
	assert_true(effect.contains('+1d6 bonus damage'), '...the bonus clause...')
	assert_true(effect.contains('At the start of your next turn it deactivates'), '...and the deactivation.')
	var flavor:String = X.tr('gear.%s.flavor' % LeolethFixture.JORMUNGANDR_ID)
	assert_true(flavor.begins_with('JÖRMUNGANDR began life'),
		'The flavour opens with the name unbroken - the LCP wraps the J in a span, which is '
		+ 'presentation, not a space.')
