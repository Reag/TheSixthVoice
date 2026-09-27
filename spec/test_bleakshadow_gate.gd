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

## Vanilla's bare Buff.TO.TECH_IMMUNITY carrier - the Napoleon's Trueblack Aegis, `to =
## &"tech_immunity"` and nothing else. There is no Lancer.STATUS for tech immunity:
## UnitCondition.is_immune_to_tech reads frame.is_biological or a buff on that channel
## (unit_condition.gd:532). test_in_triumvirate.gd carries the same constant for the ward's half.
const TECH_IMMUNITY_BUFF := &'buff_trueblack_aegis_tech_immunity'

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
	# THE AUTHOR'S ORDERED CHANGE (2026-09-21), and the message was wrong independently of the
	# polarity. show_in_tooltip governs the kit/trait CARD - tooltip_organ_kit.gd:71 is its only
	# caller in the whole tree - not the gear bar, which drops every ActionReaction unconditionally
	# at gear_bar.gd:145 and never consults this function. Until the override came off, nothing in
	# the game described this reaction anywhere: the Kit ships no gear.ms_bleakshadow_gate.effect
	# row, so the system card was the activate's row alone.
	assert_true(eyes.show_in_tooltip(kit),
		'DRAWN ON THE SYSTEM CARD, with its own trigger and effect rows: action.gd:350-353 returns '
		+ 'true because this action\'s effect row is non-empty and differs from the Kit\'s, which does '
		+ 'not exist. The gear bar still never draws it (gear_bar.gd:145).')

func test_the_sluaghs_own_hit_on_a_covered_enemy_deals_three_more_and_costs_it_two():
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, 'The player was asked, once, whether to open its Eyes.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE + EYES_BONUS,
		'THE CARD: 3 from the die plus the +3 - applied at POST and read by the same roll (Task 0).')
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

func test_an_allied_drones_hit_offers_it_too():
	# THE MOD'S READING OF "CHARACTER", FLIPPED (ruling 2026-09-27, mod-wide): "an allied CHARACTER"
	# in this trigger is is_character() again, a drone included - the LCP's own DRONE tag: "Drones
	# are Size 1/2 characters." The canonical paragraph is in action_stealing_of_the_souls.gd's
	# header, and every other Sluagh card follows it the same way.
	#
	# THE SETUP ASSERTIONS ARE KEPT AS ENGINE FACTS: this drone really is a drone (is_actor false)
	# and really is a character (is_character true) - the second is now what the gate reads.
	#
	# The drone stands on ALLY_TILE, three tiles out, so the Sensors clause passes and is_character()
	# now admits it, exactly as the bare engine predicate always would have.
	var drone := SluaghFixture.create_drone(game, ALLY_TILE)
	assert_false(drone.is_actor(), 'fixture: it is not an actor - which no longer decides this...')
	assert_true(drone.is_character(), '...and it IS a character, which is what the gate now reads.')
	SluaghFixture.arm_rifle(drone)
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, drone, hostile)
	assert_eq(offers(), 1, 'Offered on an allied DRONE\'s hit too.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE + EYES_BONUS, 'The drone\'s attack deals the +3...')
	assert_eq(sluagh.current_damage(), EYES_SELF_DAMAGE, '...and the SLUAGH takes the 2.')

## TECH IMMUNITY KILLS THE WHOLE REACTION, not just its +3 (close review, slice 6 I-2; the branch
## used to document the wrong gate). The Gate is TECH gear - UnitAction.is_tech is true of a Kit
## any of whose ActionSystems sets is_tech (unit_action.gd:567-571), and the activate does - so
## ActionReaction.check_if_prohibited (action_reaction.gd:99-111) refuses the reaction whenever the
## triggering context.unit or context.target_unit is tech-immune. reaction_bus.gd:120 asks it inside
## does_reaction_trigger, BEFORE triggers_on_event at :123, so the reaction never even evaluates its
## own clauses: no prompt, no +3, and - the observable difference from the mechanism we used to
## document - no 2 self-damage either. Buff.check_if_prohibited (buff.gd:228-239) is the gate for the
## PAIR and the WARD, where the buff really is applied and read; here it is unreachable.
func test_a_tech_immune_defender_offers_nothing():
	SluaghFixture.cover(hostile)
	SpecFactory.apply_buff(hostile, TECH_IMMUNITY_BUFF)
	assert_true(UnitCondition.is_immune_to_tech(hostile), 'fixture: the defender is immune to tech.')
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 0, 'Nothing offered: a tech reaction is prohibited against a tech-immune defender.')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE, 'Just the die - no +3.')
	assert_eq(sluagh.current_damage(), 0,
		'AND NO 2 EITHER: the whole reaction is refused, not merely its bonus - which is what the branch used to say.')

## DECLINING IS FREE, and until the close nothing tested it (slice 6 I-3). Ruling 1 makes the
## reaction prompt because "a reaction the player cannot decline is not one", and the header
## promises declining "costs neither the point nor the round". Every other case in this file lets
## the stock responder say yes; offers() counts that a prompt HAPPENED, never that the answer was
## honoured, so ignoring the answer altogether would redden nothing.
##
## THE RESPONDER IS FLIPPED IN PLACE rather than swapped for testkit/mod_choice_responder.gd (which
## the reviewer suggested): this file's before_each already installs the stock responder, and
## SluaghFixture.create_game_with_prompt_queues passes add_responder = false precisely so that TWO
## responders never answer the same request - building a second game mid-test would leave both
## listening. SpecFactory.current_responder.chosen_yesnos is vanilla's own knob for this
## (test/gear/test_ms_armor_lock_plating.gd and test_ms_brace.gd set its siblings), and the Gate is
## opened BEFORE the flip so the activate's own confirm still answers yes.
func test_declining_costs_the_sluagh_neither_the_point_nor_the_round():
	SluaghFixture.cover(hostile)
	await SluaghFixture.open_gate(game, sluagh)
	forget_prompts()
	SpecFactory.current_responder.chosen_yesnos = false
	var hp_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot(game, sluagh, hostile)
	assert_eq(offers(), 1, 'The player WAS asked...')
	assert_eq(hp_before - hostile.core.current.health, DAMAGE_DIE, '...and said no, so the enemy took just the die.')
	assert_eq(sluagh.current_damage(), 0, 'And the Sluagh paid nothing: the return is BEFORE spend_actions.')

	forget_prompts()
	var second_before:int = hostile.core.current.health
	SluaghFixture.queue([D20_HITS, COVER_DIE, DAMAGE_DIE])
	await SluaghFixture.shoot_again(game, sluagh, hostile)
	assert_eq(offers(), 1,
		'AND THE SAME TURN\'S SECOND COVERED HIT IS STILL OFFERED: the reaction point is spent only '
		+ 'inside UnitAction.spend (unit_action.gd:257), reached only from spend_actions - which a '
		+ 'declined reaction never calls. test_the_bonus_is_consumed... is this line\'s mirror, where '
		+ 'the first shot was ACCEPTED and the second reads 0.')
	assert_eq(second_before - hostile.core.current.health, DAMAGE_DIE, 'Declined again: still just the die.')

## THE +3 IS NAMED IN THE PLAYER'S BATTLE LOG, and it used to name the wrong card (slice 6 I-1).
## attack_util.gd:307-308 stamps both bonus_source_id AND bonus_source_name =
## bonus_damage_buff.name_text() onto the roll, and event_unit_attack_declared.gd:305-313 writes the
## NAMES into "{unit} is dealing +{amount}{type} bonus damage against {target} from {sources}.".
## With no row of its own the buff fell through Translate.buff to the OWNER GEAR's actions[0]
## (translate.gd:72-75, gear_core.gd:337-339) - the ACTIVATE on this two-action Kit - so the log
## credited "Activate Bleakshadow Gate". Vanilla's twelve bonus_damage_specific buffs carry no row
## either and are all fine, because every one of them sits on a SINGLE-action Kit.
##
## THE CORE IS BUILT BY HAND because the buff is consumed inside the roll that reads it (is_onetime,
## event_unit_attack_declared.gd:296) - there is no instant at which a test could pick it off a
## unit. name_text() is the same read the log line makes.
##
## test_the_gate_chip_borrows_the_activates_card_on_purpose is the deliberate opposite one buff
## over, and the contrast is the point: the CHIP wants the activate's card, the BONUS does not.
func test_the_bonus_names_the_reaction_not_the_activate():
	var core := BuffCore.create(ContentLibrary.get_buff(SluaghFixture.EYES_BONUS), gate().persistent_id)
	assert_eq(core.get_owner_gear(), gate(), 'fixture: the core resolves the Gate as its owner gear.')
	assert_eq(core.name_text(), 'EYES OF NIGHT', 'THE LOG LINE names the reaction...')
	assert_ne(core.name_text(), X.tr('gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.name'),
		'...and NOT the activate, which is what actions[0] hands any buff on this Kit with no row of its own.')

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

func test_the_second_qualifying_hit_in_one_turn_offers_nothing():
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

# ---------------------------------------------------------------- Task 3: the card text and rank 3

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in [
			'gear.ms_bleakshadow_gate.name', 'gear.ms_bleakshadow_gate.flavor',
			'gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.name',
			'gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.effect',
			'gear.ms_bleakshadow_gate.action_eyes_of_night.name',
			'gear.ms_bleakshadow_gate.action_eyes_of_night.trigger',
			'gear.ms_bleakshadow_gate.action_eyes_of_night.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.ms_bleakshadow_gate.name'), 'Bleakshadow Gate', 'The card name.')
	# The LCP's words are untouched; the pipes are the house style. EYES OF NIGHT carries an
	# EXPLICIT key (`|Label=key|`) so it renders as a green gear link to the Gate's own card, which
	# is where the reaction's trigger and effect now live - the author's ask, 2026-09-21, and
	# gear.mw_acrasial_falcata.effect's shape (it links Biting Retort the same way).
	assert_eq(X.tr('gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.effect'),
		'Until the end of your next turn, you gain the |EYES OF NIGHT=gear.ms_bleakshadow_gate.action_eyes_of_night| |reaction|.',
		'The LCP verbatim, two pipes - the reaction linked, the term glossed.')
	assert_eq(X.tr('gear.ms_bleakshadow_gate.action_eyes_of_night.trigger'),
		'You or an allied character within |Sensors| hit an enemy benefiting from soft or hard cover for the first time this turn.',
		'The trigger, verbatim. "soft or hard cover" is NOT piped (Global Constraints).')
	assert_eq(X.tr('gear.ms_bleakshadow_gate.action_eyes_of_night.effect'),
		'The attack deals an additional +3 bonus damage and you take 2 |Energy| damage. This damage cannot be reduced in any way.',
		'The effect, verbatim.')
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.BLEAKSHADOW_GATE)
	if kit.actions.size() < 2: return assert_true(false, 'fixture: the Kit loaded with both actions.')
	assert_eq(Translate.action(kit, kit.actions[0], 'effect', false),
		X.tr('gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.effect'), 'The activate finds its own row...')
	assert_eq(Translate.action(kit, kit.actions[1], 'effect', false),
		X.tr('gear.ms_bleakshadow_gate.action_eyes_of_night.effect'), '...and the reaction its own.')
	for key:String in ['gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.effect',
			'gear.ms_bleakshadow_gate.action_eyes_of_night.trigger', 'gear.ms_bleakshadow_gate.action_eyes_of_night.effect']:
		assert_every_pipe_resolves(key)

## THE GATE CHIP BORROWS THE ACTIVATE'S CARD, AND THAT IS THE ARRANGEMENT (final review, item 1).
##
## Translate.buff falls through to the OWNER GEAR's actions[0] rows when a buff has none of its own
## (translate.gd:72-77, get_solo_action = kit.actions[0], gear_core.gd:337-339). On this Kit
## actions[0] IS the activate, whose rows read "Activate Bleakshadow Gate" / "Until the end of your
## next turn, you gain the EYES OF NIGHT reaction" - which is precisely what the chip means, so
## nothing is invented and the two sibling In Triumvirate chips' fix (rows of their own) is not
## wanted here.
##
## IT IS PINNED BECAUSE THE FALLBACK IS SILENT. It SUCCEEDS whatever it lands on - no resolution
## guard ever fires (memory lancer-tactics-buff-card-fallback) - and this Kit is the multi-action
## shape that rule warns about: reorder kit.actions and this chip starts rendering EYES OF NIGHT's
## trigger at a unit that has not reacted, with every other test in this file still green. So both
## halves are asserted: the chip's own rows are ABSENT from the compiled artifact (nobody quietly
## adds them and thinks the fallback is gone), and name_text()/effect_text() are the ACTIVATE's rows
## rather than the reaction's. test_wicked_host.gd:107-113 is this mod's precedent for the shape.
func test_the_gate_chip_borrows_the_activates_card_on_purpose():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for property:String in ['name', 'effect']:
		assert_eq(translation.get_message('gear.%s.%s' % [SluaghFixture.GATE_CHIP, property]), StringName(''),
			'The chip deliberately writes no %s row of its own.' % property)

	await SluaghFixture.open_gate(game, sluagh)
	var chip:BuffCore = UnitCondition.get_buff(sluagh, SluaghFixture.GATE_CHIP)
	assert_not_null(chip, 'fixture: the Gate is open and the chip is on the Sluagh.')
	if chip == null: return
	assert_eq(chip.name_text(), X.tr('gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.name'),
		'It renders the ACTIVATE\'s name...')
	assert_eq(chip.effect_text(), X.tr('gear.ms_bleakshadow_gate.action_activate_bleakshadow_gate.effect'),
		'...and the activate\'s effect: "Until the end of your next turn, you gain the EYES OF NIGHT reaction."')
	assert_ne(chip.effect_text(), X.tr('gear.ms_bleakshadow_gate.action_eyes_of_night.effect'),
		'NOT the reaction\'s card, which the fallback would render just as silently if actions[] were reordered.')

## Splitting on '|' alternates literal text (even indices) with labels (odd) - test_draw_fire.gd's
## _unpiped idiom. An unbalanced pipe leaves an odd count; a label the glossary does not know
## renders as a coloured word with no hover, which test_content_integrity.gd:162 explains.
## Mirrors GlossaryItem.process_glossed_text (glossary_item.gd:219-256) rather than checking every
## pipe the same way, because the engine does not: a pipe carrying an EXPLICIT key (`|Label=key|`)
## never reaches find_key_from_label at all (:235-237), so the LABEL is free text by design and only
## the KEY has to resolve.
##
## This helper used to validate the label in both cases, which was latently wrong and went unnoticed
## only because no row in this file carried an explicit key until the activate's did (author's ask,
## 2026-09-21). test_in_triumvirate.gd carries an identical copy that is still label-only; it has no
## explicit-key row today, so it is correct by accident - fix it there when one lands.
func assert_every_pipe_resolves(key:String) -> void:
	var parts := X.tr(key).split('|')
	assert_eq(parts.size() % 2, 1, '%s: pipes are balanced.' % key)
	for i in parts.size():
		if i % 2 == 0: continue
		var inner:String = parts[i]
		if not inner.contains('='):
			assert_ne(GlossaryItem.find_key_from_label(inner), '',
				'%s: |%s| is a glossary term.' % [key, inner])
			continue
		# An explicit key. The engine renders it as a GREEN GEAR LINK when the key begins `gear.`
		# and its second segment names a real Kit (:239-246); otherwise it is a plain term link
		# whose key must translate.
		var split_tag := inner.split('=')
		var label:String = split_tag[0]
		var tag_key:String = split_tag[1] if split_tag.size() >= 2 else ''
		assert_false(label.is_empty(), '%s: an explicit pipe still has a label.' % key)
		assert_false(tag_key.is_empty(), '%s: |%s=| names a key.' % [key, label])
		var segments := tag_key.split('.')
		if tag_key.begins_with('gear') and segments.size() >= 2:
			# NOT assert_not_null on get_kit - that assertion is VACUOUS, and a mutation caught it
			# being so. ContentLibrary.get_kit NEVER returns null: on a miss it logs X.error and
			# returns the Kit.UNKNOWN_ID placeholder (content_library.gd:231-236). Compare the id.
			#
			# THE ENGINE HAS THE SAME HOLE, and it is worth knowing rather than fixing here:
			# process_glossed_text takes the green-gear branch on `ContentLibrary.get_kit(kit_id)
			# != null` (glossary_item.gd:245), which is ALWAYS true - so a link with a misspelled
			# kit id still renders GREEN and still opens a tooltip, just the UNKNOWN kit's. The
			# text looks right and points nowhere. This assertion is the only thing that would
			# notice.
			var linked_id := StringName(segments[1])
			assert_eq(ContentLibrary.get_kit(linked_id).compcon_id, linked_id,
				'%s: |%s| links to Kit %s, which really is registered - so it renders GREEN and opens THAT card, not the UNKNOWN placeholder.'
					% [key, label, linked_id])
		else:
			assert_ne(X.tr(tag_key), tag_key, '%s: |%s| links to %s, which resolves.' % [key, label, tag_key])

func test_the_licence_grants_it_at_rank_three():
	var license:UnlockTree = ContentLibrary.get_license_tree(SluaghFixture.LICENSE_ID)
	assert_not_null(license, 'The licence is registered.')
	# A BARE `return` HERE WAS A SILENT PASS (close review, slice 6 M-5): the one assertion above it
	# has already succeeded, so a missing rank 3 left the test green having asserted nothing about
	# rank 3 at all. test_in_triumvirate.test_the_licence_grants_it_at_rank_three is the convention.
	if license == null or license.rank_3 == null: return assert_true(false, 'fixture: the licence loaded with a rank 3.')
	var ids:Array[String] = []
	for kit:Kit in license.rank_3.granted_gear: ids.append(String(kit.compcon_id))
	assert_true(ids.has('ms_bleakshadow_gate'), 'Rank 3 grants Bleakshadow Gate.')
