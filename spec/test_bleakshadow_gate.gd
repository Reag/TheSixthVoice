# BLEAKSHADOW GATE (Sluagh rank III, SP4). Design section 4.1, ruling 22.
#
#   "UNIQUE, Tech, 2 SP. Activate Bleakshadow Gate (Quick Tech): Until the end of your next turn,
#    you gain the EYES OF NIGHT reaction."
#
# THE CHIP IS THE REACTION'S ONLY GATE. action_eyes_of_night.gd's is_available_to_activate asks
# UnitCondition.has_buff(unit, buff_bleakshadow_gate) and nothing else about the Gate; so the whole
# of "you gain the reaction until..." is this chip's lifetime, which is why its clock has its own
# test here and why that test asserts survival past the ENEMY's turn end (SP3 departure 2: an
# END_OF_THIS_TURN mutation would otherwise pass).
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
const HOSTILE_TILE := Vector2i(9, 6)      # 5 from the Sluagh: inside the rifle's Range 10, well inside Sensors 10
const SECOND_HOSTILE_TILE := Vector2i(10, 6)
const ALLY_TILE := Vector2i(4, 9)         # 3 from the Sluagh
const FAR_ALLY_TILE := Vector2i(15, 6)    # 11 from the Sluagh: one past Sensors 10

const D20_HITS := 19
const D20_MISSES := 1
## THE RIFLE'S 1d6, CHEATED TO 3 AND NOT TO 1, AND THAT IS ITS RELIABLE 2 (Task 2, measured).
## A cheated 1 does NOT arrive as 1: the run log reads ">> rolled 1d6 damage if hit:1" and then
## "number: 2 ... took 2", because RELIABLE floors the damage of a HIT as well as a miss. At the
## floor the arithmetic stops separating anything - "the die" and "the die plus the +3" would be
## 2 and 4, and the blast case's first_loss - second_loss would read 2 where the card's bonus is 3.
## Cheated to 3, every number below is the plain sum: 3 alone, 6 with the Eyes.
const DAMAGE_DIE := 3
## What the DIFFICULTY die cover adds is cheated to. Cover is an accuracy mod of -1 per step
## (Lancer.cover_modifier, lancer.gd:154) and roll_d6_accuracy rolls abs(mod) dice off the SAME
## global FIFO as everything else (dice.gd:86-88, :22-35) - so a shot at a SOFT-covered target pops
## one more entry than a shot at an uncovered one, BETWEEN the d20 and the damage. Every queue in
## this file is written for the cover its own target is standing in; get it wrong and the damage die
## silently becomes the tail of 1s.
const COVER_DIE := 1
const RIFLE_RELIABLE := 2
const EYES_BONUS := 3
const EYES_SELF_DAMAGE := 2

var game:Gamemaster
var sluagh:Unit
var hostile:Unit
var watcher:PromptWatcher

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_gate(sluagh)
	SluaghFixture.arm_rifle(sluagh)
	hostile = SluaghFixture.create_hostile(game, HOSTILE_TILE)
	SluaghFixture.arm_rifle(hostile)
	watcher = add_child_autoqfree(PromptWatcher.new())

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func gate() -> GearCore: return sluagh.get_gear(SluaghFixture.BLEAKSHADOW_GATE)
func has_chip() -> bool: return UnitCondition.has_buff(sluagh, SluaghFixture.GATE_CHIP)
func offers() -> int: return watcher.kinds(PromptWatcher.KIND.yesno).size()
func forget_prompts() -> void: watcher.prompts.clear()

# ---------------------------------------------------------------- Task 1: the Kit, the activate, the chip

func test_the_kit_matches_the_card():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.BLEAKSHADOW_GATE)
	# BEFORE any guard: get_kit hands back the mt_missing_mechsystem placeholder for an unknown id
	# (kit.gd:13), never null, so this is the first assertion that can discriminate.
	assert_eq(kit.compcon_id, SluaghFixture.BLEAKSHADOW_GATE, 'The Kit is registered under its own id.')
	assert_eq(kit.sp_cost, 2, 'SP 2.')
	assert_true(kit.is_unique(), 'UNIQUE.')
	assert_false(kit.is_ai(), 'Not an AI system.')
	assert_gte(kit.actions.size(), 1, 'It carries the activate (Task 2 appends the reaction).')
	if kit.actions.is_empty(): return
	var activate:Action = kit.actions[0]
	assert_eq(activate.get_id(), SluaghFixture.GATE_ACTION_ID, 'The first action is the activate.')
	assert_true(activate is ActionSystemApplyBuff, 'An ActionSystemApplyBuff, script-less.')
	assert_eq(activate.action_type, Lancer.ACTION.QUICK, 'QUICK.')
	assert_true(activate.is_tech, 'A tech action - jammable.')
	assert_true(activate.apply_only_to_self, 'Self only: nothing to target.')

func test_pressing_the_gate_spends_a_quick_action_and_hangs_the_chip_on_the_sluagh():
	assert_false(has_chip(), 'Control: no chip before the press.')
	await SluaghFixture.open_gate(game, sluagh)
	assert_true(has_chip(), 'THE CARD: the Sluagh holds the Gate chip.')
	var activate:Action = gate().get_action(SluaghFixture.GATE_ACTION_ID)
	assert_eq(activate.get_action_type(SpecificAction.create(sluagh, gate(), activate)), Lancer.ACTION.QUICK,
		'A QUICK action (the economy caps a turn at two; the repeat-action rule exempts quick tech).')
	var chip:BuffCore = UnitCondition.get_buff(sluagh, SluaghFixture.GATE_CHIP)
	assert_false(chip.base.hide_from_player, 'VISIBLE (ruling 22): it is the only thing on the board that says the Gate is open.')
	assert_eq(chip.base.until, Lancer.UNTIL.END_OF_NEXT_TURN, 'until = END_OF_NEXT_TURN (1).')

func test_the_chip_survives_the_enemys_turn_and_clears_at_the_end_of_the_sluaghs_next_turn():
	await SluaghFixture.open_gate(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	assert_true(has_chip(), 'Survives the end of the turn it was pressed on.')
	await SpecFactory.start_turn(game, hostile)
	assert_true(has_chip(), 'Survives the enemy\'s turn start...')
	await SpecFactory.end_turn(game, hostile)
	assert_true(has_chip(), '...AND the enemy\'s turn end (the assertion an END_OF_THIS_TURN mutation fails).')
	await SpecFactory.start_turn(game, sluagh)
	assert_true(has_chip(), 'Still there through the Sluagh\'s next turn...')
	await SpecFactory.end_turn(game, sluagh)
	assert_false(has_chip(), '...and gone at its END. "Until the end of your next turn."')

func test_the_gate_is_jammed_with_the_rest_of_the_tech():
	SpecFactory.apply(sluagh, Lancer.STATUS.JAMMED)
	await SluaghFixture.open_gate(game, sluagh)
	assert_false(has_chip(), 'A Jammed Sluagh cannot open the Gate: is_tech makes it jammable (action_system.gd:32).')

# ---------------------------------------------------------------- Task 2: EYES OF NIGHT
#
#   "EYES OF NIGHT (Reaction, 1/Turn). Trigger: You or an allied character within Sensors hit an
#    enemy benefiting from soft or hard cover for the first time this turn. Effect: The attack
#    deals an additional +3 bonus damage and you take 2 Energy damage. This damage cannot be
#    reduced in any way."
#
# THE PROMPT IS WATCHED, NOT ASSUMED. offers() counts yes/no prompts through testkit/prompt_watcher.
# A positive case counts ONE (the reaction's own confirm); a "nothing offered" case counts zero.
# The stock responder says yes.
#
# ...WHICH IS WHY EVERY CASE HERE CALLS forget_prompts() THE MOMENT THE GATE IS OPEN (Task 2,
# measured on the RED run). Pressing the Gate is an ActionSystemApplyBuff, and that archetype raises
# a confirm of its own - so open_gate() leaves ONE yes/no already on the watcher, and an untouched
# offers() would read 1 for a case whose whole subject is that nothing was offered. Three of this
# block's absence cases failed RED on exactly that, and the positive ones would have read 2 once the
# reaction worked. The clear is the arrangement; it is not a softened assertion.
#
# EVERY SHOT HERE IS THE ASSAULT RIFLE, and its queue is NOT one shape: cover adds a difficulty die
# between the d20 and the damage (see COVER_DIE), so a soft-covered target takes
# [D20_HITS, COVER_DIE, DAMAGE_DIE], a hard-covered one takes two cover entries, and an uncovered
# one takes [D20_HITS, DAMAGE_DIE]. The damage is popped TWICE (the hit roll and the crit roll,
# attack_util.gd:250-251); only the first is read on a non-crit hit and the second comes off
# queue()'s tail.

func armed_ally(tile:Vector2i) -> Unit:
	var ally := SluaghFixture.create_ally(game, tile)
	SluaghFixture.arm_rifle(ally)
	return ally

func test_the_reaction_is_on_the_kit_and_shaped_like_the_card():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.BLEAKSHADOW_GATE)
	assert_eq(kit.actions.size(), 2, 'Two actions: the activate and the reaction.')
	if kit.actions.size() < 2: return
	var eyes:Action = kit.actions[1]
	assert_eq(eyes.get_id(), SluaghFixture.EYES_ID, 'The second is Eyes of Night.')
	assert_true(eyes is ActionReactionAttacked, 'An ActionReactionAttacked.')
	assert_true(eyes.triggers_on.has(&'attack'), 'On the per-target ATTACK event...')
	assert_eq(eyes.trigger_timing, ReactionBus.TIMING.POST, '...at POST, where the roll exists.')
	assert_true(eyes.require_hit, 'require_hit.')
	assert_eq(eyes.require_defender_relation, ActionReactionAttacked.RELATION.ENEMIES, 'The defender is an enemy of the Sluagh.')
	assert_eq(eyes.require_attacker_relation, ActionReactionAttacked.RELATION.ANY, 'The attacker may be the Sluagh itself: ANY, the script decides.')
	assert_true(eyes.allow_tech and eyes.allow_basic, '"hit an enemy" - any attack.')
	assert_true(eyes.consumes_rxn, 'A real reaction: spends the point, which is the 1/round.')
	assert_eq(eyes.usage_group, &'action_eyes_of_night', 'Its own usage group.')
	assert_false(eyes.show_in_tooltip(kit), 'A reaction; never a gear-bar button.')

func test_the_sluaghs_own_hit_on_a_covered_enemy_deals_three_more_and_costs_it_two():
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, 'The player was asked, once, whether to open its Eyes.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE + EYES_BONUS,
		'THE CARD: 1 from the die plus the +3 - applied at POST and read by the same roll (Task 0).')
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, '...and the Sluagh took 2.')

func test_held_overshield_soaks_the_two_first():
	SluaghFixture.cover(hostile)
	await SluaghFixture.grant_overshield(sluagh, 5)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, 'Offered.')
	assert_eq(Overshield.current(sluagh), 3, 'The soak sits inside damage() and sees NO_REDUCE like any flag (ruling 7 parity).')
	assert_eq(sluagh.current_damage(), 0, 'HP untouched.')

func test_the_two_cannot_be_reduced_by_armor():
	SluaghFixture.cover(hostile)
	sluagh.core.current.armor = 2   # the pool directly: the pipeline's only armor read (test_twilight_swarm.gd:243-249)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, 'NO_REDUCE: armor 2 takes nothing off the 2.')

func test_an_allys_hit_within_sensors_offers_it_and_the_sluagh_pays():
	var ally := armed_ally(ALLY_TILE)
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, ally, hostile)
	assert_eq(offers(), 1, 'Offered on an ALLY\'s hit.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE + EYES_BONUS, 'The ALLY\'s attack deals the +3...')
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, '...and the SLUAGH takes the 2.')
	assert_eq(ally.current_damage(), 0, 'Not the ally.')

func test_an_ally_one_past_sensors_offers_nothing():
	var ally := armed_ally(FAR_ALLY_TILE)
	assert_eq(UnitRelation.distance_between(sluagh, ally), 11, 'fixture: eleven tiles, Sensors 10.')
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, ally, hostile)
	assert_eq(offers(), 0, 'Nothing offered: the attacker is outside the Sluagh\'s Sensors.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE, 'Just the die.')
	assert_eq(sluagh.current_damage(), 0, 'And the Sluagh pays nothing.')

func test_inexorable_formation_extends_the_sensors_the_trigger_reads():
	# The LIVE read: one point of Overshield is one tile of Sensors, and the ally at 11 comes inside.
	var ally := armed_ally(FAR_ALLY_TILE)
	await SluaghFixture.grant_overshield(sluagh, 1)
	assert_eq(sluagh.get_sensor_range(), 11, 'fixture: Inexorable Formation lifted Sensors to 11.')
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, ally, hostile)
	assert_eq(offers(), 1, 'Now offered.')

func test_a_hit_on_an_uncovered_enemy_offers_nothing():
	# NO COVER ENTRY IN THE QUEUE, and that is the case rather than an oversight: with no cover there
	# is no accuracy mod, and roll_d6_accuracy(0) returns 0 without rolling at all (dice.gd:87-88).
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 0, 'No cover, no trigger.')
	assert_eq(sluagh.current_damage(), 0, 'Nothing paid.')

func test_a_hit_on_a_hard_covered_enemy_offers_it():
	# TWO cover entries: HARD is an accuracy mod of -2, and roll_d6_accuracy rolls abs(mod) dice and
	# keeps the highest (dice.gd:86-88, sum_rolls' MAX branch multiplied by signi(count)).
	SpecFactory.apply_buff(hostile, SluaghFixture.HARD_COVER_BUFF)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, COVER_DIE, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, '"soft or hard cover".')

func test_a_covered_enemy_under_markerlight_offers_nothing():
	# Markerlight's buff_markerlight_no_cover sits on the DEFENDER and zeroes a computed SOFT cover
	# (attack_roll.gd:161-163). The roll's pre.cover is then NONE - and that is what the reaction
	# reads, so the enemy did not "benefit from cover" as far as the roll is concerned. Fact 5.
	# AND NO COVER ENTRY IN THE QUEUE EITHER, for the same reason as the uncovered case: the zeroing
	# happens INSIDE PreAttack.create, before the mod is added (attack_roll.gd:161-168), so the roll
	# carries no accuracy penalty and rolls no difficulty die.
	SluaghFixture.cover(hostile)
	SpecFactory.apply_buff(hostile, &'buff_markerlight_no_cover')
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 0, 'The roll computed no cover, so no trigger.')

func test_without_the_gate_open_nothing_is_offered():
	SluaghFixture.cover(hostile)
	assert_false(has_chip(), 'Control: the Gate is closed.')
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 0, 'The reaction exists only while the chip is held.')
	assert_eq(sluagh.current_damage(), 0, 'Nothing paid.')

func test_the_second_qualifying_hit_in_one_enemy_turn_offers_nothing():
	# "1/Turn" and "for the first time this turn" are BOTH the reaction point: it is restored at
	# every unit's turn start (event_turn_start.gd:42-44), so within one turn the second offer is
	# refused by the spent point. Draw Fire ruling 3.
	var ally := armed_ally(ALLY_TILE)
	var second := SluaghFixture.create_hostile(game, SECOND_HOSTILE_TILE)
	SluaghFixture.cover(hostile)
	SluaghFixture.cover(second)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	await SpecFactory.end_turn(game, sluagh)
	await SpecFactory.start_turn(game, ally)
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SpecFactory.use_solo(game, ally, SluaghFixture.MAIN_RIFLE, hostile)
	assert_eq(offers(), 1, 'First hit of the ally\'s turn: offered.')
	forget_prompts()
	var hp_before:int = second.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot_again(game, ally, second)
	assert_eq(offers(), 0, 'Second hit, same turn: the point is spent.')
	assert_eq(hp_before - second.core.current.health, DAMAGE_DIE, 'Just the die on the second target.')
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, 'The Sluagh paid exactly once.')

func test_a_blast_hitting_two_covered_enemies_adds_the_three_to_the_reacted_target_only():
	# One event_unit_attack per attacked unit (event_unit_attack_declared.gd:52-65); the first
	# per-target event's POST reaction spends the point, and its bonus buff is scoped by state to
	# THAT defender (buff_eyes_of_night_bonus.gd), so the second roll reads no bonus even before
	# consumption would have removed it. Mortar: Blast 1, 1d6 explosive.
	var second := SluaghFixture.create_hostile(game, SECOND_HOSTILE_TILE)
	SluaghFixture.cover(hostile)
	SluaghFixture.cover(second)
	var mortar:GearCore = SluaghFixture.equip(sluagh, &'mw_mortar')
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var first_before:int = hostile.core.current.health
	var second_before:int = second.core.current.health
	# THE QUEUE IS [d20, acc, acc, d20], MEASURED, and the two middle entries are not padding. The
	# mortar is INACCURATE (attack_accuracy "-1", mw_mortar.tres) and both targets are in soft cover
	# (-1), so each of its two attack rolls pops a d20 and then TWO difficulty dice
	# (roll_d6_accuracy(-2) rolls abs(count) of them, dice.gd:86-88). Written as [19, 19] - the
	# brief's first draft - the second 19 was eaten as the FIRST roll's difficulty die and the run
	# logged "total roll : 0 (+ acc -19)": both shots missed and both targets took nothing, which
	# reads exactly like the bonus never landing.
	# The mortar carries no RELIABLE tag, so 1d6+1 off the tail of 1s is a clean 2 per target.
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(1)
	Dice.cheat_attack([D20_HITS, COVER_DIE, COVER_DIE, D20_HITS], buffer)
	var tiles:Array[Vector2i] = [HOSTILE_TILE]
	var core := EventCore.create(&'event_gear_activate', {
		action = mortar.get_solo_action(), gear = mortar, unit = sluagh, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	assert_eq(offers(), 1, 'Offered once, for the first roll.')
	var first_loss:int = first_before - hostile.core.current.health
	var second_loss:int = second_before - second.core.current.health
	assert_eq(first_loss - second_loss, EYES_BONUS,
		'Exactly one of the two took the +3 (%d against %d).' % [first_loss, second_loss])
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, 'Paid once.')

func test_the_bonus_is_consumed_by_the_roll_that_read_it_and_does_not_ride_the_next_shot():
	# is_onetime on buff_eyes_of_night_bonus.tres, and THE ONLY CASE THAT PINS IT - added because the
	# mutation found the gap rather than because the plan asked for it (Task 2 mutation 6). The
	# defender scope in check_if_passive_applies already keeps the +3 off a SECOND target, which is
	# what carries the blast case, so deleting is_onetime reddens nothing there. What the scope does
	# NOT cover is a second shot at the SAME defender: consume_buffs eats the one-time buffs at
	# event_unit_attack_declared.gd:296, and without the flag the buff simply sits on the attacker and
	# is rolled into the next attack on that unit too, with no reaction fired and nothing to see.
	#
	# shoot() then shoot_again(): the first cycles the Sluagh's turn, the second is AS_FREEBIE inside
	# it, so the reaction point stays spent between them (sluagh_fixture.gd:229-244) and the second
	# hit's +3, if any, can only be a leftover.
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, 'LIVENESS: the first shot really did fire the reaction...')
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot_again(game, sluagh, hostile)
	assert_eq(offers(), 0, '...and the second, in the same turn, did not: the point is spent.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE,
		'Just the die: the +3 was consumed by the roll that read it, not carried to the next.')

func test_an_invade_on_a_covered_enemy_offers_nothing_because_a_tech_attack_computes_no_cover():
	# THE PLAN ASKED FOR THE OPPOSITE OF THIS, and the engine settled it (Task 2 departure 3, RED and
	# GREEN both measured). The brief's case expected an invade on a covered enemy to offer the
	# reaction and turn the +3 into +3 HEAT. It cannot: the reaction reads roll.pre.cover, and
	# PreAttack.create computes cover ONLY inside `if action is ActionAttackWeapon`
	# (attack_roll.gd:152-156). ActionAttackTech is a SIBLING of ActionAttackWeapon under ActionAttack
	# (action_attack_tech.gd:3), not a subclass, so a tech attack's pre.cover is the initialiser NONE
	# (:99) no matter what the defender is standing behind - and the trigger's cover clause is false.
	# Lancer's own rules agree that cover does not apply to a tech attack, which is why this is
	# recorded as the card's behaviour rather than papered over by computing cover a second way.
	#
	# WHAT THIS CASE IS WORTH KEEPING FOR: it goes RED the moment the cover clause stops reading the
	# ROLL - if somebody re-reads cover off the defender instead, the invade starts offering and this
	# fails. Its liveness twin is test_the_sluaghs_own_hit..., one covered rifle shot away.
	#
	# Fragment Signal pops ONE entry (the d20) - a tech attack's damage is the flat string '2'
	# (action_attack_tech.gd:17) and no cover means no difficulty die.
	SluaghFixture.cover(hostile)
	SluaghFixture.equip(sluagh, SluaghFixture.TECH_ID)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var heat_before:int = hostile.core.current.heat
	SluaghFixture.queue([D20_HITS])
	await SluaghFixture.invade(game, sluagh, hostile)
	assert_eq(offers(), 0, 'Nothing offered: the roll computed no cover, because it is a tech attack.')
	assert_eq(hostile.core.current.heat - heat_before, 2, 'The invade\'s own 2 heat, and no bonus.')
	assert_eq(sluagh.current_damage(), 0, 'Nothing paid.')
