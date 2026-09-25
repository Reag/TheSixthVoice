# ENTRAP (Koremasa trait, design 1.4, rulings 14, 16 and 18):
#
#   "Gain the Entrap reaction.
#    Entrap (Reaction, 1/round). Trigger: The Koremasa hits a hostile character with a melee attack
#    that it has already successfully hit with tech attack that round. Effect: That character takes
#    1 Heat."
#
# TWO PIECES. A hidden watcher (action_entrap_mark_koremasa, no reaction point) hangs a VISIBLE mark,
# buff_entrap_mark, on a hostile the Koremasa hits with a tech attack; the mark is stamped with the
# round and clears itself at the next NEW_ROUND (ruling 16 - "that round" is the true round, not the
# Koremasa's turn). The reaction proper (action_entrap_koremasa) is a REAL reaction - it spends the
# point - offered on a melee hit AT THREAT on a hostile carrying this Koremasa's mark: a thrown attack
# is a ranged attack (ruling 14's "attack" half).
#
# HEAT IS MEASURED AS A DELTA ACROSS THE SWING. The vanilla Invade (ms_fragment_signal) hands its
# target heat of its own on a hit, so the only number that says anything about Entrap is what the
# melee swing added on top.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_entrap.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/koremasa_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

const KOREMASA_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(5, 4)
const OTHER_ADJACENT := Vector2i(3, 4)
const THROWN_OUT := Vector2i(7, 4)

## Tech: 19 (+1 tech attack) clears e-defense 8, 1 cannot. Melee: 15 is a plain hit on evasion 10,
## never a crit (so Exploit Weakness stays out of every heat delta here).
const TECH_HIT := 19
const TECH_MISS := 1
const HIT := 15

var game:Gamemaster
var responder
var koremasa:Unit
var hostile:Unit

func before_each() -> void:
	var pair:Array = Fixture.create_game_with_prompts(self)
	game = pair[0]
	responder = pair[1]
	koremasa = Fixture.create_koremasa(game, KOREMASA_TILE)
	hostile = Fixture.create_hostile(game, ADJACENT)
	Fixture.equip(koremasa, Fixture.MELEE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.yesno_queue.clear()

func invade(target:Unit, d20:int, attacker:Unit = koremasa) -> void:
	await Fixture.attack(game, attacker, Fixture.TECH, target, d20)

## The heat a melee swing ADDS to its target.
func swing_delta(target:Unit, flags:Array = [], kit_id:StringName = Fixture.MELEE, variant:String = '') -> int:
	var before := Fixture.heat(target)
	var health_before := target.core.current.health
	await Fixture.attack(game, koremasa, kit_id, target, HIT, flags, variant)
	assert_lt(target.core.current.health, health_before, 'fixture: the swing really landed.')
	return Fixture.heat(target) - before

# ---------------------------------------------------------------- wiring

func test_the_trait_carries_a_real_reaction_and_a_hidden_watcher():
	var kit:Kit = ContentLibrary.get_kit(Fixture.ENTRAP_ID)
	assert_true(Kit.is_valid(kit), 'mt_entrap is in the kits index.')
	if not Kit.is_valid(kit): return
	var reaction:Action = kit.get_action(Fixture.ENTRAP_ACTION)
	var watcher:Action = kit.get_action(Fixture.ENTRAP_MARK_ACTION)
	assert_true(reaction is ActionReactionAttacked, 'The reaction is an ActionReactionAttacked.')
	assert_true(watcher is ActionReactionAttacked, 'So is the watcher.')
	if not reaction is ActionReactionAttacked or not watcher is ActionReactionAttacked: return
	assert_true(reaction.consumes_rxn, 'Entrap is a real reaction: it spends the point.')
	assert_false(watcher.consumes_rxn, 'The watcher is not.')
	assert_true(reaction.show_in_tooltip(kit), 'The reaction is on the card.')
	assert_false(watcher.show_in_tooltip(kit), 'The watcher is not.')
	var mark = ContentLibrary.get_buff(Fixture.ENTRAP_MARK)
	assert_not_null(mark, 'buff_entrap_mark is in the buffs index.')
	if mark == null: return
	assert_false(mark.hide_from_player, 'The mark is VISIBLE: it tells the player who can be Entrapped.')

# ---------------------------------------------------------------- the mark

func test_a_tech_hit_marks_the_target():
	await invade(hostile, TECH_HIT)
	assert_true(Fixture.is_marked(hostile), 'The invaded hostile wears the mark.')

func test_a_tech_miss_marks_nothing():
	await invade(hostile, TECH_MISS)
	assert_false(Fixture.is_marked(hostile), 'A missed invade leaves no mark.')

func test_the_mark_clears_at_the_next_round():
	await invade(hostile, TECH_HIT)
	await Fixture.new_round(game)
	assert_false(Fixture.is_marked(hostile), 'Gone as the next round begins ("that round").')

func test_an_allys_tech_hit_marks_nothing():
	var ally:Unit = Fixture.create_ally(game, Vector2i(6, 5))
	await invade(hostile, TECH_HIT, ally)
	assert_false(Fixture.is_marked(hostile), 'Only the Koremasa\'s own tech hits mark.')

# ---------------------------------------------------------------- the reaction

func test_a_tech_hit_then_a_melee_hit_deals_one_heat():
	await invade(hostile, TECH_HIT)
	assert_eq(await swing_delta(hostile), 1, 'Entrap: one heat on top of the swing.')
	assert_eq(koremasa.core.current.reactions, 0, 'And the reaction point is spent.')

## A REAL REACTION IS A CHOICE (ruling 16, "prompts"): nothing asks on a reaction's behalf
## (reaction_bus.gd:114-122 only checks eligibility), so the reaction confirms inside its own activate,
## as Warp Shield and Vanish do. Found by the close review: Entrap spent the point unasked.
func test_entrap_asks_once_before_it_spends():
	await invade(hostile, TECH_HIT)
	var watcher = add_child_autoqfree(PromptWatcher.new())
	assert_eq(await swing_delta(hostile), 1, 'fixture: accepted, Entrap dealt its heat.')
	assert_eq(watcher.kinds(PromptWatcher.KIND.yesno).size(), 1, 'Entrap asked exactly once.')

func test_declining_entrap_spends_nothing():
	await invade(hostile, TECH_HIT)
	responder.yesno_queue.assign([false])
	assert_eq(await swing_delta(hostile), 0, 'Declined: no heat.')
	assert_eq(koremasa.core.current.reactions, koremasa.core.get_reactions_max(), 'The point is untouched.')

func test_a_melee_hit_without_a_tech_hit_asks_nothing():
	var watcher = add_child_autoqfree(PromptWatcher.new())
	await swing_delta(hostile)
	assert_eq(watcher.kinds(PromptWatcher.KIND.yesno).size(), 0, 'No mark, no question.')

## A drone is not a "hostile character" here (ruling 16's actor check), on either half.
func test_a_tech_hit_on_a_drone_marks_nothing():
	var drone := Fixture.create_hostile_drone(game, OTHER_ADJACENT)
	await invade(drone, TECH_HIT)
	assert_false(Fixture.is_marked(drone), 'The watcher skips a drone.')

func test_a_live_mark_on_a_drone_arms_nothing():
	var drone := Fixture.create_hostile_drone(game, OTHER_ADJACENT)
	UnitCondition.apply_buff_id(SpecFactory.dummy_event(), drone, Fixture.ENTRAP_MARK, koremasa.get_gear(Fixture.ENTRAP_ID))
	assert_true(Fixture.is_marked(drone), 'fixture: a live mark hung on the drone by hand.')
	assert_eq(await swing_delta(drone), 0, 'The reaction skips a drone too.')
	assert_eq(koremasa.core.current.reactions, koremasa.core.get_reactions_max(), 'The point is untouched.')

func test_a_melee_hit_without_a_tech_hit_does_nothing():
	assert_eq(await swing_delta(hostile), 0, 'No tech hit this round, no Entrap.')
	assert_eq(koremasa.core.current.reactions, koremasa.core.get_reactions_max(), 'The point is untouched.')

func test_a_tech_miss_then_a_melee_hit_does_nothing():
	await invade(hostile, TECH_MISS)
	assert_eq(await swing_delta(hostile), 0, 'A missed tech attack does not arm Entrap.')

func test_a_tech_hit_in_an_earlier_round_does_nothing():
	await invade(hostile, TECH_HIT)
	await SpecFactory.end_turn(game, koremasa)
	await Fixture.new_round(game)
	await SpecFactory.start_turn(game, koremasa)
	assert_eq(await swing_delta(hostile), 0, 'Last round\'s tech hit does not count.')

func test_a_tech_hit_on_a_different_hostile_does_nothing():
	var other:Unit = Fixture.create_hostile(game, OTHER_ADJACENT)
	await invade(other, TECH_HIT)
	assert_eq(await swing_delta(hostile), 0, 'The mark is on the other hostile, not this one.')

func test_a_thrown_hit_does_nothing():
	# Ruling 14: a thrown attack is not a melee ATTACK.
	Fixture.equip(koremasa, Fixture.KNIFE)
	var far:Unit = Fixture.create_hostile(game, THROWN_OUT)
	await invade(far, TECH_HIT)
	assert_true(Fixture.is_marked(far), 'fixture: the target is marked.')
	assert_eq(await swing_delta(far, [], Fixture.KNIFE, 'thrown'), 0, 'A thrown knife: no Entrap.')

func test_the_same_knife_at_threat_does_entrap():
	# The control for the test above: only the throw differs.
	Fixture.equip(koremasa, Fixture.KNIFE)
	await invade(hostile, TECH_HIT)
	assert_eq(await swing_delta(hostile, [], Fixture.KNIFE), 1, 'The knife at threat Entraps.')

func test_a_second_melee_hit_in_the_round_does_nothing():
	await invade(hostile, TECH_HIT)
	assert_eq(await swing_delta(hostile), 1, 'fixture: the first swing Entraps.')
	koremasa.core.current.reactions = koremasa.core.get_reactions_max() # isolate the 1/round from the point
	assert_eq(await swing_delta(hostile, [Action.FLAG.AS_FREEBIE]), 0, 'The second does not (1/round).')
