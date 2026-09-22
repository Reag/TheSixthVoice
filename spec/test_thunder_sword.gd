# THE THUNDER SWORD (Leoleth rank I, SP2 Task 1) - design ruling 19, sheet 09-leoleth.md.
#
#   "Main Melee | SP 0 | HEAT SELF 1 | 1d6 Kinetic | Threat 1
#    On hit: Until the end of your next turn, if the damaged character voluntarily moves, they take
#    1 AP Energy damage per space, up to a maximum of 5."
#
# THE CHIP'S CLOCK IS THE LEOLETH'S, NOT THE TARGET'S, and the engine reaches that through
# END_OF_OWNERS_NEXT_TURN (Lancer.UNTIL 7, lancer.gd:52) rather than END_OF_NEXT_TURN (1, which is
# what vanilla's Barricade uses and which would be the TARGET's clock). The clear runs from
# content/events/event_turn_end.gd:62 at the OWNER's turn end, and skips any core whose turn_count is
# still 0 (unit_condition.gd:62) - turn_count ticking at the HOLDER's turn start
# (unit_condition.gd:24). So the full cycle a lifetime test has to drive is:
#   Leoleth's turn: hit  ->  Leoleth ends turn (NOT cleared, turn_count 0)
#   target's turn starts (turn_count 1) and ends
#   Leoleth's next turn starts and ENDS  ->  cleared
#
# ARMOR IS NOT A FACTOR AND THAT IS THE AP FLAG, not luck: EventService.DAMAGE_FLAG.AP is passed on
# every bleed, exactly as buff_drag_down_barricade.gd does.
#
# THE DUMMY CARRIES 200 HP AND ARMOR 0 (leoleth_fixture.create_dummy), so every number asserted here
# is the number the card promises and nothing dies mid-test.
extends GutTest

const LeolethFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/leoleth_fixture.gd')

var game:Gamemaster
var leoleth:Unit
var target:Unit

const LEOLETH_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(5, 4)   # adjacent: Threat 1 reaches it

func before_each():
	game = LeolethFixture.create_game(self)
	leoleth = LeolethFixture.create_leoleth(game, LEOLETH_TILE)
	target = LeolethFixture.create_hostile(game, TARGET_TILE)
	LeolethFixture.arm_thunder_sword(leoleth)
	# AMPLE SPEED, DISCOVERED RATHER THAN DESIGNED: the target's own turn never cycles in this file
	# (walk() spends real speed via MovementType.create_for_standard_move, and nothing here calls
	# SpecFactory.start_turn on the TARGET to refresh it), so the frame's default speed of 4
	# (statblock_default.tres) silently truncates the whole move via
	# event_unit_move.has_enough_move_to_reach_end (event_unit_move.gd:156-159, :288-291) - core.set_
	# aborted() with no error - the moment a test's cumulative walk()s exceed it. Three tests here
	# drive the target 6-7 voluntary spaces across several separate walk() calls to pin the 5-point
	# cap and the reset-on-rehit case, well past that budget. This is FrameIsolation'd
	# (fitzgerald_fixture.create_dummy), so the write cannot reach the shared ContentLibrary copy -
	# the same reasoning create_dummy already relies on for health/armor/evasion.
	target.core.frame.stat.speed = 20
	target.core.full_repair()

func after_each():
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- the card's printed numbers

func test_the_kit_is_registered_with_the_cards_stats():
	var kit := ContentLibrary.get_kit(LeolethFixture.THUNDER_SWORD_ID)
	assert_not_null(kit, '%s loads through ContentLibrary.' % LeolethFixture.THUNDER_SWORD_ID)
	if kit == null: return
	assert_eq(kit.sp_cost, 0, 'SP 0.')
	assert_eq(kit.actions.size(), 1, 'One action, and it is the swing.')
	assert_eq(kit.charges_max, 0, 'No charges: the card has no LIMITED tag.')

func test_the_action_is_a_main_melee_kinetic_swing_with_self_heat():
	var kit := ContentLibrary.get_kit(LeolethFixture.THUNDER_SWORD_ID)
	assert_not_null(kit, 'fixture: the kit loads.')
	if kit == null: return
	var action:Action = kit.actions[0]
	assert_true(action is ActionAttackWeapon, 'It is an ActionAttackWeapon.')
	if not (action is ActionAttackWeapon): return
	assert_eq(action.get_id(), LeolethFixture.THUNDER_SWORD_ACTION, 'Named action_thunder_sword.')
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.MELEE, 'Melee.')
	assert_eq(action.damage_dice, '1d6', '1d6.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(action.threat, 1, 'Threat 1 - the archetype default, left unset in the .tres.')
	assert_eq(action.self_heat_dice, '1', 'HEAT SELF 1.')
	assert_eq(action.on_hit_effects.size(), 1, 'Exactly one on-hit effect.')

func test_the_card_text_renders_rather_than_a_raw_key():
	assert_eq(
		X.tr('gear.mw_thunder_sword.name'), 'Thunder Sword',
		'The Kit names itself.')
	assert_string_contains(
		X.tr('gear.mw_thunder_sword.on_hit'), 'up to a maximum of 5',
		'The on-hit row is the card, not a raw key.')
	assert_string_contains(
		X.tr('gear.buff_thunder_sword.effect'), 'per space',
		'The chip carries its OWN effect row - a weapon Kit has no .effect row to fall back on, so a '
		+ 'row-less chip would render the raw key (house rule, Sluagh frame close).')

# ---------------------------------------------------------------- the chip lands

func test_a_hit_hangs_the_chip_on_the_target():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'The damaged character carries the chip.')
	assert_false(LeolethFixture.has(leoleth, LeolethFixture.THUNDER_SWORD_CHIP),
		'And the Leoleth does not - the chip goes on the TARGET.')

func test_a_miss_hangs_nothing():
	LeolethFixture.cheat_a_miss()
	await LeolethFixture.swing_sword(game, leoleth, target)
	assert_false(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'A miss applies nothing: ON_HIT runs only inside `if roll.hit` (event_unit_attack.gd:83).')

func test_the_leoleth_takes_one_heat_per_swing():
	var before:int = leoleth.core.current.heat
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	assert_eq(leoleth.core.current.heat, before + 1, 'HEAT SELF 1.')

# ---------------------------------------------------------------- the bleed

func test_each_voluntary_space_costs_one_ap_energy():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp:int = target.core.current.health
	await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(1, 0))
	assert_eq(target.core.current.health, hp - 1, 'One space, one point.')
	await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(3, 0))
	assert_eq(target.core.current.health, hp - 3, 'Two more spaces, two more points.')

func test_the_bleed_ignores_armor():
	# A fresh target with armor 2. Without EventService.DAMAGE_FLAG.AP a 1-point hit would floor at 0
	# (event_unit_damage caps at armor) and this test would read "nothing happened".
	var armored := LeolethFixture.create_hostile(game, Vector2i(3, 4))
	armored.core.current.armor = 2
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, armored)
	var hp:int = armored.core.current.health
	await LeolethFixture.walk(game, armored, Vector2i(2, 4))
	assert_eq(armored.core.current.health, hp - 1, 'AP: armor 2 does not stop 1 point.')

func test_the_fifth_space_is_the_last():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp:int = target.core.current.health
	for i:int in 5:
		await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(i + 1, 0))
	assert_eq(target.core.current.health, hp - 5, 'Five spaces, five points.')
	assert_false(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'And the chip removes itself the moment it pays out the fifth point (author ruling, '
		+ '2026-09-22), so nothing on screen threatens damage it can no longer deal.')
	await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(6, 0))
	assert_eq(target.core.current.health, hp - 5, 'The sixth space is free: "up to a maximum of 5".')

func test_a_knockback_step_costs_nothing():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp:int = target.core.current.health
	await SpecFactory.move(game, target, TARGET_TILE + Vector2i(2, 0),
		MovementType.create_for_involuntary(target))
	assert_eq(target.core.current.health, hp,
		'"voluntarily moves": MovementType.voluntary is false on an involuntary move, and '
		+ 'create_for_involuntary merges no buffs at all (movement_type.gd:64-72).')

func test_a_second_hit_resets_the_count():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp:int = target.core.current.health
	for i:int in 5:
		await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(i + 1, 0))
	assert_eq(target.core.current.health, hp - 5, 'The first chip is spent out.')

	LeolethFixture.cheat_a_hit()
	LeolethFixture.step(leoleth, target.tile() + Vector2i(1, 0)) # back into threat
	await LeolethFixture.swing_sword(game, leoleth, target)
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'The fresh hit hangs a fresh chip.')
	var hp2:int = target.core.current.health
	await LeolethFixture.walk(game, target, target.tile() + Vector2i(0, 1))
	assert_eq(target.core.current.health, hp2 - 1,
		'A fresh hit is a fresh 5. Here the spent chip had ALREADY removed itself (the author '
		+ 'ruling), so this is a plain application onto a clean unit - the reset is not what is '
		+ 'under test. test_a_part_spent_chip_resets_when_hit_again is.')

func test_a_part_spent_chip_resets_when_hit_again():
	# THE CASE THE SELF-CLEARING RULING DOES NOT COVER: a chip with 2 of its 5 spent, hit again.
	# Only multiple_copies_can_stack = false (the Buff default, buff.gd:131) can reset this one -
	# apply_buff_alt clears the matching old core (unit_condition.gd:741-747) and apply_buffs then
	# makes a NEW BuffCore with an empty state (:709). So this is the assertion that actually pins
	# ruling 19's "a second hit resets the counter".
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp:int = target.core.current.health
	await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(1, 0))
	await LeolethFixture.walk(game, target, TARGET_TILE + Vector2i(2, 0))
	assert_eq(target.core.current.health, hp - 2, 'Two of the five are spent.')
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'And the chip is still up - it only removes itself at 5.')

	LeolethFixture.cheat_a_hit()
	LeolethFixture.step(leoleth, target.tile() + Vector2i(1, 0)) # back into threat
	await LeolethFixture.swing_sword(game, leoleth, target)
	var hp2:int = target.core.current.health
	for i:int in 5:
		await LeolethFixture.walk(game, target, target.tile() + Vector2i(0, 1))
	assert_eq(target.core.current.health, hp2 - 5,
		'Five more, not three: the second hit replaced the part-spent core with a fresh one.')

func test_an_unchipped_character_bleeds_nothing():
	var bystander := LeolethFixture.create_hostile(game, Vector2i(8, 8))
	var hp:int = bystander.core.current.health
	await LeolethFixture.walk(game, bystander, Vector2i(9, 8))
	assert_eq(bystander.core.current.health, hp, 'No chip, no bleed.')

func test_the_chip_bleeds_only_its_own_holder():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	var other := LeolethFixture.create_hostile(game, Vector2i(8, 8))
	var hp:int = other.core.current.health
	await LeolethFixture.walk(game, other, Vector2i(9, 8))
	assert_eq(other.core.current.health, hp,
		'triggers_on_event returns false when the moving unit is not us.')

# ---------------------------------------------------------------- the clock

func test_the_chip_survives_the_leoleths_own_turn_end():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	await SpecFactory.end_turn(game, leoleth)
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'"your NEXT turn": clear_owners_turn_statuses skips a core whose turn_count is still 0 '
		+ '(unit_condition.gd:62).')

func test_the_chip_dies_at_the_end_of_the_leoleths_next_turn():
	LeolethFixture.cheat_a_hit()
	await LeolethFixture.swing_sword(game, leoleth, target)
	await SpecFactory.end_turn(game, leoleth)
	await SpecFactory.start_turn(game, target)   # turn_count -> 1
	await SpecFactory.end_turn(game, target)
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'The TARGET\'s own turn end does not clear it - the clock is the owner\'s.')
	await SpecFactory.start_turn(game, leoleth)
	assert_true(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'Nor the start of the owner\'s next turn.')
	await SpecFactory.end_turn(game, leoleth)
	assert_false(LeolethFixture.has(target, LeolethFixture.THUNDER_SWORD_CHIP),
		'The end of the Leoleth\'s NEXT turn clears it.')

func test_the_chip_is_visible():
	var buff := ContentLibrary.get_buff(LeolethFixture.THUNDER_SWORD_CHIP)
	assert_not_null(buff, 'The chip is a standalone buff_*.tres in the buffs index.')
	if buff == null: return
	assert_false(buff.hide_from_player,
		'The target\'s only warning that moving will cost it - so it is a chip, not plumbing.')
	assert_eq(buff.until, Lancer.UNTIL.END_OF_OWNERS_NEXT_TURN,
		'UNTIL 7, the OWNER\'s clock - not 1, which is the Barricade\'s and the target\'s.')
	assert_eq(buff.triggers_on, [&'step'] as Array[StringName], 'One trigger: step.')
	assert_eq(buff.trigger_timing, ReactionBus.TIMING.POST,
		'POST - the Buff default (buff.gd:139), left unset in the .tres.')

# ---------------------------------------------------------------- the licence

func test_the_licence_grants_the_sword_at_rank_one():
	var tree := ContentLibrary.get_license_tree(LeolethFixture.LICENSE_ID)
	assert_not_null(tree, 'fixture: the licence loads.')
	if tree == null or tree.rank_1 == null: return
	var ids:Array = tree.rank_1.granted_gear.map(func(kit:Kit) -> StringName: return kit.compcon_id)
	assert_true(ids.has(LeolethFixture.THUNDER_SWORD_ID), 'Rank 1 grants the Thunder Sword.')
