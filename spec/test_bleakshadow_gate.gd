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
const DAMAGE_DIE := 1                     # the rifle's 1d6 read as 1, so the +3 is legible
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
