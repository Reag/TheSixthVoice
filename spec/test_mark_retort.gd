# THE MARK'S REACTION (the second bullet of MARK OF THE DEAD AND THE DAMNED AND THE LOST, SP1 Task 8).
#
#   "As a reaction, when an attack misses you or an adjacent allied character, you may deal energy
#    damage to the attacker equal to your OVERSHIELD."
#
# A REAL REACTION: it prompts, it spends the Sluagh's one reaction point, and it is 1/round. The
# other three reactions this frame ships are all point-free.
#
# THE OBSERVABLE IS THE ATTACKER'S HEALTH, not the defender's - which is what makes the vanilla
# rifle safe here despite its RELIABLE 2. A miss still lands 2 on whoever was shot at, and that is
# irrelevant to every assertion about the retort's own damage.
#
# BUT IT IS NOT IRRELEVANT TO THE SLUAGH'S SHIELD, and that is the one correction this file makes to
# the plan's own spec source. The dome soaks damage: event_unit_damage.gd:215-218 spends
# state.overshield before HP. So a miss AGAINST the Sluagh lands the rifle's floored 2 on its 3-point
# dome and leaves 1 - AFTER the reaction, which read 3 and dealt 3. "The card spends nothing but the
# reaction" is therefore asserted in the ADJACENT-ALLY case, where nothing is shot at the Sluagh at
# all and the whole shield survives; the self case asserts SHIELD minus the rifle's Reliable and says
# why. Both are still discriminating - a retort that SPENT the shield would leave 0.
#
# AND NO ASSERTION HERE EXPECTS A HIT TO DEAL ITS RAW DIE. Two engine facts stack on the one hit case:
# mw_assault_rifle is RELIABLE 2 and attack_util.gd:144-147 floors the TOTAL of a HIT exactly as of a
# miss (the Task 2 measurement), and the Sluagh is sheltered by its own Mark, so SHIELD Overshield
# soaks first. The hit case therefore uses a die big enough to read THROUGH the dome.
#
# TWO LIMITS, TWO CLOCKS, and one test each.
#  - THE POINT (core.current.reactions) is restored by UnitAction.every_new_turn_refresh, which
#    event_turn_start runs for EVERY unit on the map at ANY unit's turn start ("this is applied to
#    ALL units, including the starting one", event_turn_start.gd:42-44).
#  - THE 1/ROUND TALLY (gear.uses_this_round) is cleared by reset_per_round_usage inside
#    new_turn_refresh, which runs for the STARTING unit only (:79, unit_action.gd:78).
# So SluaghFixture.shoot - which cycles the ATTACKER's turn - hands the point back between shots
# while leaving the tally spent. The point test therefore uses shoot_again(), which fires a second
# time inside the same turn with Action.FLAG.AS_FREEBIE and cycles nothing.
#
# THE PROMPT IS WATCHED, NOT ASSUMED. Five tests read testkit/prompt_watcher.gd. Counting yes/no
# prompts RAW is safe in this file for one specific reason, asserted in the first of them:
# CommonActionUtil.confirm_use returns without asking anything when the acting unit is not
# player-controlled (common_action_util.gd:304), and every attacker here but one is AI_ENEMY - so the
# only yes/no raised by a SHOT is the Sluagh's own. The one test with an ALLIED attacker deliberately
# does NOT count prompts, because a friendly-fire warning (target_action_util.gd:430-435, also a
# yesno) would be in the way.
#
# THE OTHER THING THAT WOULD BE IN THE WAY IS VANILLA BRACE, AND IT IS DESIGNED AROUND RATHER THAN
# TOLERATED (measured in this file's first RED run). ms_brace is a DAMAGE PRE reaction on every
# mech's basic loadout, and action_brace.gd raises a yes/no of its own for a player-controlled unit -
# but only once the incoming damage clears its gate: `incoming > Util.half(get_health_max())`, or it
# would save the unit from structuring (action_brace.gd:44-51). A miss's floored 2 never clears
# either on an 8 HP frame, which is why every miss case here counts clean. The ONE hit case keeps its
# damage AT the threshold rather than over it for exactly this reason - see HIT_DAMAGE_DIE. That is
# not only about the count: a confirmed Brace SPENDS the Sluagh's reaction point, which is the very
# thing two of these tests measure.
#
# THE SETUP RAISES ONE OF ITS OWN, WHICH IS WHY forget_prompts() EXISTS. Pressing the Mark is an
# ActionSystemApplyBuff self-applied activation, and that branch raises its own confirm_use
# (action_system_apply_buff.gd:101-102) - measured in Task 7. Without clearing the log, every
# positive case would count two prompts and every "nothing was offered" case would count one, which
# is the shape of a test that passes for the wrong reason.
#
# DICE: THE SOFT COVER POPS A DIE TOO. Once the Mark is up the Sluagh and its adjacent ally have
# |soft cover|, so an attack against either spends a d6 on the -1 difficulty between the d20 and the
# damage roll (Task 7 measured exactly that: [11, 6, 5] for a sheltered ally). Every miss case here
# queues nothing but 1s - D20_MISSES, DAMAGE_DIE and SluaghFixture.queue's own tail are all 1 - so
# the alignment cannot matter; the ONE hit case writes the same number in both slots, Task 6's idiom.
#
# ASTRAL GUARDIAN IS ON THIS KIT AND NEVER FIRES HERE. It requires a HIT on an adjacent ally, and the
# only hit in this file lands on the Sluagh itself, which its `defender != unit` clause refuses. So
# no guardian d6 is ever popped.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mark_retort.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
const ADJACENT_TILE := Vector2i(5, 6)
const TWO_OUT_TILE := Vector2i(6, 6)
const SHOOTER_TILE := Vector2i(9, 6)
const FRIEND_SHOOTER_TILE := Vector2i(4, 9)

const D20_MISSES := 1
const D20_HITS := 19
## Small enough that the 8 HP Sluagh survives a hit.
const DAMAGE_DIE := 1
## What the Sluagh holds, and therefore what the retort deals.
const SHIELD := 3
## mw_assault_rifle's RELIABLE, which lands on a MISS as well as flooring a hit
## (attack_util.gd:126 get_miss, :144-147 the floor).
const RIFLE_RELIABLE := 2
## The damage die for the ONE hit case. THREE constraints meet on this number, and 4 is the only
## value that satisfies all of them on an 8 HP frame holding a 3-point dome:
##  - ABOVE the rifle's RELIABLE 2, so the die is what is read rather than the floor
##    (attack_util.gd:144-147);
##  - ABOVE SHIELD, so something reaches HP at all and a hit is legible against a miss (which lands 2
##    and is soaked whole);
##  - NOT ABOVE Util.half(8), or vanilla Brace offers its own yes/no and, if taken, spends the very
##    reaction point this file measures (action_brace.gd:44-51 is the gate, :65 the prompt).
## A 5 breaks the third and was measured doing exactly that in the first RED run.
const HIT_DAMAGE_DIE := 4

var game:Gamemaster
var sluagh:Unit
var ally:Unit
var shooter:Unit
var watcher:PromptWatcher

## One-shot latch for test_a_dome_emptied_during_the_prompt_spends_no_point; see its own comment.
var _drained_the_dome:bool = false

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	ally = SluaghFixture.create_ally(game, ADJACENT_TILE)
	shooter = SluaghFixture.create_hostile(game, SHOOTER_TILE)
	SluaghFixture.arm_rifle(shooter)
	watcher = add_child_autoqfree(PromptWatcher.new())
	_drained_the_dome = false

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	SpecFactory.current_responder.chosen_yesnos = true

func core_gear() -> GearCore: return sluagh.get_gear(SluaghFixture.CORE_ID)

func retort() -> Action:
	var gear:GearCore = core_gear()
	return gear.get_action(SluaghFixture.RETORT_ID) if GearCore.is_valid(gear) else null

func retort_uses_this_round() -> int:
	var gear:GearCore = core_gear()
	if not GearCore.is_valid(gear): return -1
	return gear.get_uses_this_round_alt(gear.get_usage_group_for_action(retort()))

## Yes/no prompts seen SINCE the last forget_prompts() - i.e. what the SHOT asked. See the file
## header for why the raw count is only meaningful after the setup's own prompt is discarded.
func offers() -> int: return watcher.kinds(PromptWatcher.KIND.yesno).size()

## Discard the setup's prompts. Pressing the Mark raises one confirm of its own.
func forget_prompts() -> void: watcher.prompts.clear()

## Everything a positive case needs: the Mark up and SHIELD Overshield held. CALLED AFTER ANY EQUIP,
## for the reason SluaghFixture.equip's header gives - a later equip would refund the core power.
func arm_the_sluagh() -> void:
	await SluaghFixture.press_mark(game, sluagh)
	await SluaghFixture.grant_overshield(sluagh, SHIELD)
	await SpecFactory.end_turn(game, sluagh)
	forget_prompts()

# ---------------------------------------------------------------- the wiring

func test_the_reaction_is_on_the_core_kit():
	var gear:GearCore = core_gear()
	var reaction = retort()
	assert_true(GearCore.is_valid(gear) and reaction != null, 'fixture: it is on the unit.')
	if not GearCore.is_valid(gear) or reaction == null: return
	assert_true(reaction is ActionReactionAttacked, 'An ActionReactionAttacked.')
	if reaction is not ActionReactionAttacked: return
	assert_eq(reaction.triggers_on, [&'attack'] as Array[StringName], 'ATTACK...')
	assert_eq(reaction.trigger_timing, ReactionBus.TIMING.POST,
		'...at POST, which is the only timing that carries a resolved roll '
		+ '(action_reaction_attacked.gd:101-107).')
	assert_true(reaction.require_miss, 'Only a miss.')
	assert_false(reaction.require_hit, 'And never a hit - that is Astral Guardian.')
	assert_eq(reaction.require_attacker_relation, ActionReactionAttacked.RELATION.ENEMIES, 'A hostile attacker...')
	assert_eq(reaction.require_defender_relation, ActionReactionAttacked.RELATION.ALLIES,
		'...against us or an ally (are_allies is true of a unit and itself, which is what lets this '
		+ 'cover "misses YOU" as well).')
	assert_true(reaction.allow_tech, 'A tech attack is an attack (ruling 15).')
	assert_true(reaction.allow_basic, 'And so is a basic one - every vanilla require_miss reaction '
		+ 'sets both: defense_net_aegis_miss, feedback_priest, metastatic_paralysis, scorpion.')
	assert_eq(reaction.require_defender_within, 0, 'The adjacency is is_adjacent, NOT a radius (ruling 6).')
	# A REAL REACTION, unlike the other three this frame ships.
	assert_true(reaction.consumes_rxn, 'It spends the reaction point - "as a reaction".')
	# ActionReaction returns 1 for a reaction that DOES consume the point (action_reaction.gd:69), so
	# there is no override here: the card's 1/round is the engine's default for this shape.
	assert_eq(reaction.get_per_round_hard_limit(SpecificAction.create(sluagh, gear, reaction)), 1,
		'And 1/round, which ActionReaction already gives a point-spending reaction.')
	# IT REACHES THE TRAIT CARD, unlike Astral Guardian: it has its own effect row and does not
	# override show_in_tooltip, so action.gd:341-353 answers true - the action_draw_fire /
	# action_uffish_gyre shape. That is why it has an ICON_TARGETS row and Astral Guardian does not.
	assert_true(reaction.show_in_tooltip(gear.kit), 'And the player can read it on the trait card.')

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.cp_cry_of_the_hosted_dead.action_mark_retort.name',
			'gear.cp_cry_of_the_hosted_dead.action_mark_retort.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	# THE NAME IS THE MARK'S OWN, and that is Departure 9 rather than an oversight: the LCP gives
	# this reaction no name of its own - it is the second <li> of active_effect - and the tagline is
	# the only invented string this sub-project is allowed. Reusing the card's own name invents
	# nothing.
	assert_eq(X.tr('gear.cp_cry_of_the_hosted_dead.action_mark_retort.name'),
		X.tr('gear.cp_cry_of_the_hosted_dead.action_mark_of_the_dead.name'),
		'The reaction wears the Mark\'s own name - the LCP gives it none.')
	# THE GLOSSARY PIPES ARE PART OF THE ROW. X.tr hands back the stored string with them intact -
	# they are stripped by the presentation layer, not by the translation - so this asserts the
	# piping as well as the wording. Measured in Task 7, where the plan's pipe-stripped substrings
	# failed against a correct CSV. "adjacent" is deliberately UNPIPED: no glossary term matches it,
	# and that is this mod's house convention.
	assert_eq(X.tr('gear.cp_cry_of_the_hosted_dead.action_mark_retort.effect'),
		'As a |reaction|, when an attack misses you or an adjacent allied character, you may deal '
		+ '|energy| damage to the attacker equal to your |OVERSHIELD|.',
		'And its effect row is the card\'s second bullet, verbatim.')

# ---------------------------------------------------------------- the card

func test_a_miss_against_the_sluagh_deals_its_overshield_to_the_attacker():
	await arm_the_sluagh()
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(offers(), 1, 'The player was asked, exactly once, whether to retort.')
	assert_eq(retort_uses_this_round(), 1, 'And it fired.')
	assert_eq(shooter.current_damage() - before, SHIELD,
		'The attacker took the Sluagh\'s whole Overshield as energy damage.')
	# THE RETORT SPENT NONE OF IT. What the dome lost is the rifle's RELIABLE 2, soaked at
	# event_unit_damage.gd:215-218 - and it lands AFTER this reaction, which read the full 3. A retort
	# that spent the shield would leave 0 here, so the number still discriminates; the clean statement
	# of "the card spends nothing but the reaction" is the adjacent-ally case below, where nothing is
	# shot at the Sluagh at all.
	assert_eq(Overshield.current(sluagh), SHIELD - RIFLE_RELIABLE,
		'And all the Sluagh lost was the rifle\'s Reliable 2 - the retort spent none of the dome.')

func test_a_miss_against_an_adjacent_ally_does_the_same():
	await arm_the_sluagh()
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, ally)

	assert_eq(retort_uses_this_round(), 1, 'A miss against an ADJACENT ally fires it too.')
	assert_eq(shooter.current_damage() - before, SHIELD, 'For the same amount.')
	# NOTHING WAS SHOT AT THE SLUAGH, so nothing soaked: this is the clean form of "equal to your
	# OVERSHIELD", not "spend your OVERSHIELD".
	assert_eq(Overshield.current(sluagh), SHIELD,
		'And the Sluagh KEPT its whole shield - the card spends nothing but the reaction.')

func test_a_miss_on_an_adjacent_allied_drone_offers_too():
	# THE DRONE CASE, FLIPPED BY THE MOD-WIDE RULING (2026-09-27): a drone is a character, so
	# `defender.is_character()` in action_mark_retort.gd now passes it - the same predicate
	# require_defender_to_be_character already asks (action_reaction_attacked.gd:95), so the line is
	# a redundant restatement rather than a narrowing. The canonical paragraph is in
	# action_stealing_of_the_souls.gd's header.
	#
	# THE TWO SETUP ASSERTIONS NAME THE ENGINE FACTS: a drone really is a character and really is not
	# an actor, though the second no longer decides anything here.
	#
	# THE DRONE IS BUILT BEFORE arm_the_sluagh(), per SluaghFixture.equip's rule - the Mark is
	# pressed LAST. Every entry in the queue is a 1 either way (the file header's idiom), so the
	# alignment cannot matter whether or not the drone is also sheltered by the dome.
	var drone:Unit = SluaghFixture.create_drone(game, ADJACENT_TILE + Vector2i(0, 1))
	await arm_the_sluagh()
	assert_true(drone.is_character(), 'fixture: a drone IS a character to the engine...')
	assert_false(drone.is_actor(), '...and is NOT an actor - which no longer matters here.')
	assert_true(UnitRelation.is_adjacent(sluagh, drone), 'fixture: and it is adjacent.')
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, drone)

	assert_eq(offers(), 1, 'The player was asked, exactly once, whether to retort.')
	assert_eq(retort_uses_this_round(), 1, 'A miss against an adjacent allied DRONE fires it too.')
	assert_eq(shooter.current_damage() - before, SHIELD, 'The attacker took the Sluagh\'s whole Overshield.')
	assert_eq(Overshield.current(sluagh), SHIELD, 'And the Sluagh kept its whole shield.')

func test_an_ally_two_tiles_out_offers_nothing():
	var far:Unit = SluaghFixture.create_ally(game, TWO_OUT_TILE)
	await arm_the_sluagh()
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, far)

	assert_eq(offers(), 0, 'Nothing was even offered.')
	assert_eq(retort_uses_this_round(), 0, 'And nothing fired.')
	assert_eq(shooter.current_damage(), before, 'The attacker took nothing.')

func test_a_hit_offers_nothing():
	await arm_the_sluagh()
	var before:int = shooter.current_damage()

	# BOTH DICE SLOTS CARRY THE SAME NUMBER, Task 6's idiom, so the damage read is identical whether
	# or not the soft cover's -1 popped an entry first. See the file header.
	SluaghFixture.queue([D20_HITS, HIT_DAMAGE_DIE, HIT_DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(sluagh.current_damage(), HIT_DAMAGE_DIE - SHIELD,
		'fixture: the shot really hit - 4 through a 3-point dome leaves 1 on HP, where a MISS lands '
		+ 'the floored 2 and the dome soaks all of it.')
	assert_eq(offers(), 0, 'require_miss: a hit offers nothing.')
	assert_eq(retort_uses_this_round(), 0, 'And nothing fired.')
	assert_eq(shooter.current_damage(), before, 'And the attacker took nothing.')

func test_without_the_mark_nothing_is_offered():
	# is_available_to_activate's first clause. The chip is the whole difference: the reaction exists
	# on the Kit from the moment the frame does, and the core power is what turns it on.
	# action_draw_fire.gd:79-81 is the pattern.
	await SluaghFixture.grant_overshield(sluagh, SHIELD)
	assert_false(UnitCondition.has_buff(sluagh, SluaghFixture.MARK_CHIP), 'fixture: no chip.')
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(offers(), 0, 'Without the Mark pressed, the reaction is never offered.')
	assert_eq(shooter.current_damage(), before, 'And the attacker took nothing.')

func test_at_zero_overshield_nothing_is_offered():
	# RULING 15's "not offered at 0 Overshield". Without this clause the player would be asked
	# whether to spend their one reaction to deal zero damage, on every miss, for as long as the dome
	# is up - which is the same class of defect as Halo's Grit-0 prompt.
	await SluaghFixture.press_mark(game, sluagh)
	await SpecFactory.end_turn(game, sluagh)
	forget_prompts() # the press raised one of its own; see the file header
	assert_eq(Overshield.current(sluagh), 0, 'fixture: no shield.')
	# THE GATE IS POLLED DIRECTLY, and that is not belt-and-braces. MEASURED in this task's mutation
	# run: with the Overshield clause replaced by `return true`, the file was still 12/12 GREEN,
	# because activate() RE-DERIVES the same zero check and returns before CommonActionUtil.confirm_use
	# - so the prompt never appears either way and offers() cannot tell the two builds apart. That is
	# the controller's standing carry-forward from Task 3: pin a clause activate re-derives by
	# polling, never behaviourally. With this line, mutation 4 reddens here and nowhere else.
	assert_false(retort().is_available_to_activate(sluagh, core_gear()),
		'The reaction is not even AVAILABLE at 0 Overshield - the gate, not the abort, is what '
		+ 'stops the player being asked.')
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(offers(), 0, 'At 0 Overshield the reaction is not offered at all.')
	assert_eq(shooter.current_damage(), before, 'And nothing happened.')
	# AND THE SHIELD IS THE WHOLE DIFFERENCE, asserted last so it disturbs nothing above: the Mark is
	# already up and the point was never spent, so the only thing that changes is the dome.
	await SluaghFixture.grant_overshield(sluagh, SHIELD)
	assert_true(retort().is_available_to_activate(sluagh, core_gear()),
		'...and with the dome actually held, the same gate says yes.')

func test_an_allied_attackers_miss_offers_nothing():
	# NO PROMPT COUNT HERE, and that is deliberate: an ALLY shooting at an ally raises the engine's
	# own friendly-fire warning (TargetActionUtil.confirm_friendly_fire), so a raw yes/no count would
	# be measuring the wrong thing. The observables are the tally and the attacker's health.
	var friend:Unit = SluaghFixture.create_ally(game, FRIEND_SHOOTER_TILE)
	SluaghFixture.arm_rifle(friend)
	await arm_the_sluagh()
	var before:int = friend.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, friend, sluagh)

	assert_eq(retort_uses_this_round(), 0, 'An ALLY missing offers nothing - the card says the attacker.')
	assert_eq(friend.current_damage(), before, 'And the ally took nothing.')

func test_armor_on_the_attacker_reduces_it():
	# RULING 15: "no flags (armor and resistance apply; the card says nothing)". The contrast is with
	# Crown of Restless Dead in SP3, which carries [SELF_INFLICTED, NO_REDUCE] because its card DOES
	# say so. This is the only place in SP1 where the absence of a flag is the content.
	shooter.core.frame.stat.armor = 2 # FrameIsolation'd by create_dummy, so this cannot leak
	shooter.core.full_repair()
	assert_eq(shooter.get_armor(), 2, 'fixture: the attacker has armor 2.')
	await arm_the_sluagh()
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(retort_uses_this_round(), 1, 'fixture: it still fired.')
	assert_eq(shooter.current_damage() - before, SHIELD - 2,
		'Armor 2 took two off the three - the retort carries no NO_REDUCE flag.')

## Empty the Sluagh's dome the instant the retort's yes/no is RAISED, before it is answered.
##
## THE TIMING IS THE ENGINE'S, not a guess. SpecFactory.ChoiceBusResponder.choose_yesno opens with
## `await get_tree().process_frame` (spec_factory.gd:508-512), so the answer lands a frame later; the
## responder connects to on_choice_request in create_game and this watcher connects after it, so the
## watcher's `prompt` signal fires inside the same emission, before the responder resumes. This
## handler therefore runs in exactly the gap activate()'s own re-read exists to cover.
##
## IT WRITES state.overshield DIRECTLY rather than through an event, and that is deliberate: an
## awaited event inside a choice-bus signal handler would re-enter the bus mid-request. Direct
## assignment is what the engine's own soak does (event_unit_damage.gd:215-218), and Overshield.current
## reads that same field (overshield.gd:32-34).
func _drain_the_dome_on_the_first_prompt(kind:StringName, _info:Dictionary) -> void:
	if _drained_the_dome or kind != PromptWatcher.KIND.yesno: return
	_drained_the_dome = true
	sluagh.state.overshield = 0

func test_a_dome_emptied_during_the_prompt_spends_no_point():
	# NOTHING IS SPENT UNTIL THE RETORT IS KNOWN TO HAVE SOMETHING TO DEAL (close review, slice 3
	# M-2). The card's "you may" and ruling 15's "not offered at 0 Overshield" are both about never
	# charging the player a reaction for zero damage, and the prompt is a real gap in which the dome
	# can empty - a second attacker's hit, an ally's ability, anything.
	#
	# THIS TEST IS RED AGAINST THE SHIPPED ORDER as of 2026-09-21: spend_actions(activation) used to
	# sit ABOVE the final Overshield re-read, so the point and the round went whatever the re-read
	# then found. Moving it below the abort - Draw Fire's order exactly, action_draw_fire.gd:201-212 -
	# is the fix, and it reddens nothing else: in every other test here the dome is unchanged across
	# the prompt.
	#
	# THE OFFER ITSELF IS ASSERTED FIRST, which is what stops this passing for the boring reason. If
	# the reaction were never offered at all (a broken gate, a missing chip) every other assertion
	# below would also hold, and the test would say nothing about ordering.
	await arm_the_sluagh()
	assert_eq(sluagh.core.current.reactions, 1, 'fixture: the frame has its one reaction point.')
	assert_eq(Overshield.current(sluagh), SHIELD, 'fixture: and a full dome when the gate runs.')
	watcher.prompt.connect(_drain_the_dome_on_the_first_prompt)
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(offers(), 1, 'It WAS offered - the dome was full when is_available_to_activate ran.')
	assert_true(_drained_the_dome, 'fixture: and the handler really fired inside the prompt.')
	assert_eq(Overshield.current(sluagh), 0, 'fixture: the dome was emptied across the question.')
	assert_eq(shooter.current_damage(), before, 'Nothing was dealt...')
	assert_eq(retort_uses_this_round(), 0, '...no round was spent...')
	assert_eq(sluagh.core.current.reactions, 1,
		'...and the reaction point SURVIVES. spend_actions sits below the final re-read.')

func test_declining_the_prompt_deals_nothing_and_spends_nothing():
	# "you MAY", which is why activate() calls CommonActionUtil.confirm_use and returns BEFORE
	# spend_actions on a decline - Draw Fire's shape (action_draw_fire.gd:205-212). Declining must
	# cost neither the point nor the round, so the Sluagh can hold the retort for a better miss.
	await arm_the_sluagh()
	SpecFactory.current_responder.chosen_yesnos = false
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)

	assert_eq(offers(), 1, 'It was still offered...')
	assert_eq(shooter.current_damage(), before, '...but declining dealt nothing...')
	assert_eq(retort_uses_this_round(), 0, '...and spent no round...')
	assert_eq(sluagh.core.current.reactions, 1, '...and no reaction point.')

func test_the_point_and_the_round_are_both_spent():
	# TWO SHOTS INSIDE ONE TURN, through shoot_again() - which is the whole reason that helper
	# exists. SluaghFixture.shoot cycles the ATTACKER's turn, and event_turn_start restores
	# core.current.reactions for EVERY unit on the map at any unit's turn start
	# (event_turn_start.gd:42-44 -> unit_action.gd:67-69), so a cycled turn would hand the point back
	# between the two misses and this test would be about the 1/round tally alone.
	#
	# BOTH NUMBERS ARE READ, because the two limits refresh on different clocks and only one of them
	# is what the card calls "a reaction".
	await arm_the_sluagh()
	assert_eq(sluagh.core.current.reactions, 1, 'fixture: the frame has its one reaction point.')
	var before:int = shooter.current_damage()

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot(game, shooter, sluagh)
	assert_eq(retort_uses_this_round(), 1, 'fixture: the first miss fired it.')
	assert_eq(sluagh.core.current.reactions, 0, 'And the point is spent.')
	var after_first:int = shooter.current_damage()
	assert_eq(after_first - before, SHIELD, 'fixture: for the full amount.')

	SluaghFixture.queue([D20_MISSES, DAMAGE_DIE])
	await SluaghFixture.shoot_again(game, shooter, sluagh)
	assert_eq(retort_uses_this_round(), 1, 'The second miss in the same turn fired nothing.')
	assert_eq(shooter.current_damage(), after_first, 'And the attacker took nothing more.')
