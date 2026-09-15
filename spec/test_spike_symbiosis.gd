# SPIKE 4 (roadmap §5): can a mod give the Myconid an extra reaction, and can that extra be limited
# to 1/ROUND, excluding 1/scene and 1/mission reactions?
#
# Symbiosis (sheet 04-myconid.md): "1/round, the Myconid may use a reaction an additional time.
# This cannot be used on reactions that are 1/scene or 1/mission."
#
# THIS IS A PROBE, NOT CONTENT. It asserts only against VANILLA frames and vanilla engine services -
# the Myconid does not exist yet - so every test here is a characterisation of the 1.4.3 engine and
# stays true no matter how the trait is eventually built. Delete it when the design lands, as
# test_spike_ripper_mod_ap.gd and test_spike_draw_fire.gd were deleted.
#
# WHY THE OBVIOUS SEAM IS NOT PROBED: the only reader of the reaction budget is
# UnitAction.can_take_reactions (unit_action.gd:378) -> has_reaction (:374), and unit_action.gd is
# the one autoload whose .gd_ext.gd extensions install and then never run (CLAUDE.md; measured
# 2026-09-02 on can_take_reactions itself, zero invocations). So the question is not "can we
# override the gate" - it is "what can content do to the numbers the gate reads", which is what
# follows.
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

## The Gorgon - the Myconid's own base frame - already carries GAZE (mt_gaze.tres), a trait Kit
## whose single passive is a passive_stat_increase with Statblock.reactions = 1. It is the vanilla
## precedent for "+1 reaction" as pure content, and the Myconid REPLACES it with Symbiosis.
const GAZE_FRAME_ID := &'mf_gorgon'

## A vanilla 1/scene reaction: the Manticore's Castigate The Enemies Of The Godhead, whose Kit
## declares uses_per_scene = 1. Symbiosis must be able to exclude this shape.
const SCENE_LIMITED_REACTION_KIT := &'mt_castigate_the_enemies_of_the_godhead'
## A vanilla reaction with no scene limit at all, as the control for the same question.
const UNLIMITED_REACTION_KIT := &'ms_overwatch'

var game:Gamemaster

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)

## The knockoff Everest SpecFactory hands out: statblock_default.tres, reactions = 1.
func _plain_unit(tile:Vector2i = Vector2i(2, 2)) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	SpecFactory.apply_passive_buffs(unit)
	return unit

## A Gorgon, with GAZE's passive folded into core.bonus by full_repair().
func _gaze_unit(tile:Vector2i = Vector2i(4, 2)) -> Unit:
	var unit := SpecFactory.create_unit(game.map, tile)
	unit.core.frame = ContentLibrary.get_mech_frame(GAZE_FRAME_ID)
	SpecFactory.apply_passive_buffs(unit)
	return unit

## A Buff.TO.STATBLOCK buff granting +1 reaction, built the way the Goblin's Instinct Rig builds its
## own (content/frames/horus/mf_goblin/cp_instinct_rig/buff_symbiosis_statblock.gd): return a
## Statblock in the context's `object`. This is the ONLY dynamic stat hook a mod has - buffs can be
## applied and removed mid-scene, passives cannot - so whether it reaches the reaction budget is the
## question this probe exists to settle.
class ReactionStatblockBuff extends Buff:
	func get_values(_core:BuffCore, _context:Context) -> Context:
		var statblock := Statblock.new()
		statblock.reactions = 1
		return Context.create({ object = statblock })

func _apply_reaction_statblock_buff(unit:Unit) -> void:
	var base := ReactionStatblockBuff.new()
	base.to = Buff.TO.STATBLOCK
	UnitCondition.apply_buff_alt(SpecFactory.dummy_event(), unit, BuffCore.create(base))
	unit.update_cached_values_and_token() # what buff_symbiosis_statblock.gd does in on_application


# ============================== A. THE STAT ROUTE (vanilla precedent) ==============================

func test_a_plain_frame_has_one_reaction_per_turn() -> void:
	var unit := _plain_unit()
	assert_eq(unit.core.get_reactions_max(), 1, 'the default statblock grants exactly one reaction')

func test_the_gorgon_gaze_trait_raises_the_core_reaction_max() -> void:
	var unit := _gaze_unit()
	assert_eq(unit.core.get_reactions_max(), 2,
		'GAZE is a passive_stat_increase and unit_printer.gd:134 folds it into core.bonus')

func test_a_plain_frame_cannot_react_twice_in_a_turn() -> void:
	var unit := _plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	assert_false(UnitAction.has_reaction(unit), 'one reaction, spent')

func test_a_gaze_frame_can_react_twice_in_a_turn() -> void:
	var unit := _gaze_unit()
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	assert_true(UnitAction.has_reaction(unit), 'the second reaction is real, not just a bigger number')
	UnitAction.spend_reaction(unit)
	assert_false(UnitAction.has_reaction(unit), 'and there is no third')


# ======================= B. THE BUFF ROUTE - the only DYNAMIC stat hook =======================

func test_a_statblock_buff_raises_the_unit_level_reaction_max() -> void:
	var unit := _plain_unit()
	_apply_reaction_statblock_buff(unit)
	assert_eq(unit.get_reactions_max(), 2,
		'unit.gd:315 adds state.stat_bonus.reactions, which unit_battle_state.gd:231-234 fills from TO.STATBLOCK buffs')

func test_a_statblock_buff_does_not_reach_the_core_reaction_max() -> void:
	var unit := _plain_unit()
	_apply_reaction_statblock_buff(unit)
	assert_eq(unit.core.get_reactions_max(), 1,
		'unit_core.gd:415 is frame.stat + core.bonus only; no buff can write core.bonus')

## THE FINDING. The turn refill reads the CORE max, not the unit max, so the buff never becomes a
## reaction point.
func test_the_turn_refill_ignores_a_statblock_reaction_buff() -> void:
	var unit := _plain_unit()
	_apply_reaction_statblock_buff(unit)
	UnitAction.every_new_turn_refresh(unit)
	assert_eq(unit.core.current.reactions, 1,
		'unit_action.gd:69 sets current.reactions = unit.core.get_reactions_max()')

## The same finding stated as behaviour rather than as a number, so a future engine change that
## fixes one and not the other cannot leave this spike half-true.
func test_a_statblock_buff_does_not_buy_a_second_reaction() -> void:
	var unit := _plain_unit()
	_apply_reaction_statblock_buff(unit)
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	assert_false(UnitAction.has_reaction(unit), 'the +1 is inert at the gate that matters')


# ===================== C. THE GRANTED-POINT ROUTE (what the refund path uses) =====================

## common_action_util.gd:734 already does exactly this to keep Flank and Overwatch from double-
## billing one reaction ("rip Gorgon"), so a hand-written += 1 is an established vanilla move.
func test_a_hand_granted_reaction_point_buys_a_second_reaction() -> void:
	var unit := _plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	UnitAction.spend_reaction(unit)
	unit.core.current.reactions += 1
	assert_true(UnitAction.has_reaction(unit), 'a granted point is spendable with no clamp in the way')

## Which is why a granted point cannot BY ITSELF be a 1/round grant: the refill runs on EVERY unit's
## turn (event_turn_start.gd:43-44, for every unit on the map), so the point is re-issued per turn
## unless something takes it away again.
func test_a_hand_granted_reaction_point_does_not_survive_the_turn_refill() -> void:
	var unit := _plain_unit()
	unit.core.current.reactions += 1
	UnitAction.every_new_turn_refresh(unit)
	assert_eq(unit.core.current.reactions, 1, 'the refill assigns, it does not top up')

## And the clamp is the other eraser: anything that full-repairs mid-scene takes the point back.
func test_the_printer_clamp_erases_a_hand_granted_reaction_point() -> void:
	var unit := _plain_unit()
	UnitAction.every_new_turn_refresh(unit)
	unit.core.current.reactions += 1
	UnitPrinter.clamp_current_stats_to_max(unit.core)
	assert_eq(unit.core.current.reactions, 1, 'unit_printer.gd:169 clamps to the CORE max')


# ===================== D. THE EXCLUSION (1/scene and 1/mission are readable) =====================

func test_a_one_per_scene_reaction_kit_declares_its_scene_limit() -> void:
	var kit := ContentLibrary.get_kit(SCENE_LIMITED_REACTION_KIT)
	assert_true(Kit.is_valid(kit), 'the Manticore trait Kit loaded')
	assert_eq(kit.uses_per_scene, 1, 'kit.gd:39 is where 1/scene lives, readable without a script extension')

func test_an_unlimited_reaction_kit_declares_no_scene_limit() -> void:
	var kit := ContentLibrary.get_kit(UNLIMITED_REACTION_KIT)
	assert_true(Kit.is_valid(kit), 'the Overwatch Kit loaded')
	assert_eq(kit.uses_per_scene, 0, 'so the exclusion is a readable property, not a guess')
	assert_eq(kit.charges_max, 0, 'and Limited X - the 1/mission shape - is kit.gd:35, beside it')
