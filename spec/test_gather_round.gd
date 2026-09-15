# GATHER ROUND and the Siege Engine Kit (Subutai SP2 Task 1).
#
#   "Active: GATHER ROUND (Protocol). For the rest of the scene, you gain the Draw Fire reaction."
#
# The M/K2's O.R.S HYPERCHARGE shape - a core-power PROTOCOL applying one scene-long buff - with no
# script at all, because the buff's whole job is to BE PRESENT: Draw Fire's is_available_to_activate
# (Task 3) asks UnitCondition.has_buff for it by id. Nothing reads its `to`, nothing reacts to it.
#
# WHY THE BUFF IS A STANDALONE buff_*.tres AND NOT AN INLINE SubResource. It is player-visible (it
# is the only on-map signal that the core power is running), and this mod's house rule is that a
# visible buff MUST live in its own file: test_content_integrity's VISIBLE_BUFFS guard reads the
# mod's `buffs` INDEX through ModResources, and an inline Buff never enters that index - so an inline
# visible chip would sail past the icon pass and ship blank. See that file's VISIBLE_BUFFS comment.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_gather_round.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')

const CORE_ID := &'cp_siege_engine'
const PROTOCOL_ID := &'action_gather_round'
const BUFF_ID := &'buff_gather_round'
const FRAME_ID := &'mf_subutai'

const START := Vector2i(4, 4)

var game:Gamemaster
var subutai:Unit

func before_each() -> void:
	game = SubutaiFixture.create_game(self)
	subutai = SubutaiFixture.create_subutai(game, START)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func core_gear() -> GearCore:
	return subutai.get_gear(CORE_ID)

# ---------------------------------------------------------------- registration

func test_the_core_kit_is_in_the_content_library():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), 'cp_siege_engine is in the kits index.')
	if not Kit.is_valid(kit): return
	assert_true(kit.is_trait, 'It is a trait (an integrated core system, not equippable gear).')
	assert_not_null(kit.get_action(PROTOCOL_ID), 'It carries action_gather_round.')

func test_the_buff_is_in_the_buffs_index_as_its_own_resource():
	# Its FILENAME PREFIX is what files it: buff_* -> the buffs index. A Buff carried inline on the
	# action would not be here at all, and the VISIBLE_BUFFS icon guard would never see it.
	var buff:Buff = ContentLibrary.get_buff(BUFF_ID)
	assert_not_null(buff, 'buff_gather_round is in the buffs index.')
	if buff == null: return
	assert_false(buff.hide_from_player, 'It is a visible chip: it is the only signal the core is up.')
	assert_eq(buff.until, Lancer.UNTIL.MANUAL, 'For the rest of the scene: nothing clears it.')
	assert_eq(buff.to, Buff.TO.NONE, 'It grants nothing by itself; its job is to be present.')

func test_the_frame_carries_the_core_system_last():
	# Appended, not inserted: the sheet lists the four traits first and the core system after them,
	# and the frame card renders traits in array order. test_subutai_frame.SHEET_TRAITS is the pin.
	var frame:Frame = ContentLibrary.get_mech_frame(FRAME_ID)
	assert_not_null(frame, 'mf_subutai loads.')
	if frame == null: return
	var ids:Array[StringName] = []
	for kit:Kit in frame.traits: ids.append(kit.compcon_id)
	assert_eq(ids.size(), 5, 'Four traits plus the core system.')
	assert_eq(ids.back(), CORE_ID, 'The core system is last.')

func test_a_subutai_actually_holds_the_core_system():
	assert_true(GearCore.is_valid(core_gear()), 'The unit has cp_siege_engine as gear.')

# ---------------------------------------------------------------- the protocol

func test_the_protocol_is_a_core_power_protocol_applied_only_to_self():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	if not Kit.is_valid(kit): return
	var action:Action = kit.get_action(PROTOCOL_ID)
	assert_true(action is ActionSystemApplyBuff, 'It applies a buff.')
	if action is not ActionSystemApplyBuff: return
	assert_eq(action.action_type, Lancer.ACTION.PROTOCOL, 'A PROTOCOL.')
	assert_true(action.consumes_cp, 'It spends the core power.')
	assert_true(action.apply_only_to_self, 'It targets nobody but the Subutai.')
	var buff_ids:Array[StringName] = []
	for buff:Buff in action.buffs: buff_ids.append(buff.compcon_id)
	assert_eq(buff_ids, [BUFF_ID] as Array[StringName], 'It applies exactly buff_gather_round.')

func test_activating_it_applies_the_chip():
	await SubutaiFixture.gather_round(game, subutai)
	assert_true(UnitCondition.has_buff(subutai, BUFF_ID), 'The Subutai carries the chip.')

func test_activating_it_spends_the_core_power():
	await SubutaiFixture.open_turn(game, subutai)
	assert_true(subutai.core.has_core_power, 'CONTROL: the core power is up beforehand.')
	await SpecFactory.use(game, subutai, CORE_ID, PROTOCOL_ID)
	assert_false(subutai.core.has_core_power, 'The core power is spent.')

func test_the_chip_survives_the_end_of_the_turn():
	# "For the rest of the scene" - until = MANUAL, so neither turn end nor the next turn start
	# touches it. A buff that quietly cleared here would take Draw Fire with it from turn two on.
	await SubutaiFixture.gather_round(game, subutai)
	await game.execute_event(&'event_turn_end', {unit = subutai})
	assert_true(UnitCondition.has_buff(subutai, BUFF_ID), 'Still there after the turn ends.')
	await SubutaiFixture.open_turn(game, subutai)
	assert_true(UnitCondition.has_buff(subutai, BUFF_ID), 'And after the next turn starts.')

func test_a_subutai_that_has_not_gathered_round_carries_no_chip():
	# The control that makes every "without GATHER ROUND" test in test_draw_fire.gd mean something.
	await SubutaiFixture.open_turn(game, subutai)
	assert_false(UnitCondition.has_buff(subutai, BUFF_ID), 'No protocol, no chip.')

# ---------------------------------------------------------------- localisation

func test_the_kit_rows_resolve():
	for key:String in [
		'gear.cp_siege_engine.name', 'gear.cp_siege_engine.flavor', 'gear.cp_siege_engine.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_siege_engine.name'), 'Siege Engine', 'The core system is named.')

func test_the_protocol_rows_resolve():
	for key:String in [
		'gear.cp_siege_engine.action_gather_round.name',
		'gear.cp_siege_engine.action_gather_round.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_siege_engine.action_gather_round.name'), 'GATHER ROUND',
		'The button is named as the card names it.')

func test_the_chips_row_resolves():
	# Translate.buff falls through to the OWNER GEAR's keys when a buff has no rows of its own
	# (translate.gd:65-77), so without these the chip would read "Siege Engine" on the unit.
	assert_eq(X.tr('gear.buff_gather_round.name'), 'Gather Round', 'The chip is named for the protocol.')
	assert_ne(X.tr('gear.buff_gather_round.effect'), 'gear.buff_gather_round.effect',
		'The chip has hover text.')
