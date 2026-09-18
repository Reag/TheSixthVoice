# GRAV-AMPED INTERFERENCE, the Vauban's core protocol (design §2.2). Three clauses on one button, and
# this file grows a section per clause: A the Burst 1 field (Task 1), B the +1 save difficulty
# (Task 2), C the 3 AP on a failed forced save (Task 3).
#
# THE ONE THING TO KNOW BEFORE READING ANY OF IT: difficult terrain in this engine is a FACTIONLESS
# property of a map tile. The card says "Hostile Characters treat all spaces within Burst 1 of the
# Vauban as difficult terrain"; the engine cannot do that, so design ruling 1 (the author's call) made
# the field real terrain for everyone, the Vauban's own tile included, and ruling 2 rewrote that
# bullet on the card to say so. The consequence the author accepted, and which section A pins
# deliberately rather than incidentally: once the protocol is pressed the Vauban is permanently
# standing in difficult ground, so GRAVITY WELL is on for the rest of the scene.
#
# A PROTOCOL NEEDS A TURN. unit_action.gd:144 refuses one unless unit.state.is_using_protocols, which
# only event_turn_start opens - hence VaubanFixture.press_protocol opening a turn first. Without it
# every test here fails with "[ Gear not available ] reason : protocol" in the log while the
# ASSERTION reads "no field", which looks like broken content. Grep a red run for `Gear not
# available` before suspecting the .tres.
#
# AND A PRESS DOES NOT SURVIVE A REPAIR. GearCore.short_repair clears gear state (gear_core.gd:143-150)
# and SpecFactory.apply_passive_buffs calls full_repair, so anything that equips or re-applies gear
# AFTER the press silently unpresses it. Arrange first, press last.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_grav_amped_interference.gd
extends GutTest

const VaubanFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/vauban_fixture.gd')
## Gravity Well's own terrain question, asked the way buff_gravity_well.gd asks it - the same preload
## test_sap.gd and test_terrain.gd carry.
const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

const CORE_ID := &'cp_earth_shaker_grav_gen'
const PROTOCOL_ID := &'action_grav_amped_interference'
const FIELD_STATE_KEY := 'grav_amped'

const MAP_SIZE := Vector2i(15, 9)
const VAUBAN_TILE := Vector2i(4, 4)

var game:Gamemaster
var vauban:Unit

func before_each() -> void:
	game = VaubanFixture.create_game(self, MAP_SIZE)
	vauban = VaubanFixture.create_vauban(game, VAUBAN_TILE)
	VaubanFixture.track(game)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func core() -> GearCore:
	return vauban.get_gear(CORE_ID)

func is_difficult(tile:Vector2i) -> bool:
	return game.map.get_surface_terrain_at(tile).is_difficult()

## The 3x3 the card's Burst 1 means around a size-1 unit: AoeCalculator.burst iterates
## range(-radius, center_size + radius) on both axes (aoe_calculator.gd:33-35), so radius 1 around a
## size-1 origin is the origin's own tile plus its eight neighbours.
func burst_1_around(centre:Vector2i) -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for dx:int in [-1, 0, 1]:
		for dy:int in [-1, 0, 1]:
			tiles.append(centre + Vector2i(dx, dy))
	return tiles

func difficult_tiles_on_the_map() -> Array[Vector2i]:
	var tiles:Array[Vector2i] = []
	for y:int in game.map.size.y:
		for x:int in game.map.size.x:
			if is_difficult(Vector2i(x, y)): tiles.append(Vector2i(x, y))
	return tiles

# ---------------------------------------------------------------- A. wiring and text

func test_the_core_is_on_the_frame_and_carries_the_protocol() -> void:
	var gear := core()
	assert_true(GearCore.is_valid(gear), 'the Vauban carries cp_earth_shaker_grav_gen')
	if not GearCore.is_valid(gear): return
	assert_true(gear.kit.is_trait, 'as a frame trait: no SP cost, cannot be unequipped')
	var action := gear.get_action(PROTOCOL_ID)
	assert_not_null(action, 'and the protocol is on it')
	if action == null: return
	assert_eq(action.get_action_type(SpecificAction.create(vauban, gear, action)), Lancer.ACTION.PROTOCOL,
		'declared as a PROTOCOL (Lancer.ACTION.PROTOCOL == 4)')
	# Asked through consumes_core_power(), which is the call the engine's own refusal chain makes
	# (unit_action.gd:145) - but it is declared `-> int` on ActionSystem while returning the bool
	# export (action_system.gd:32), and GUT's assert_true refuses the 1 outright ("Cannot convert 1 to
	# boolean"). So the VALUE is compared. test_gather_round.gd reads the export instead; either says
	# the same thing.
	assert_eq(int(action.consumes_core_power()), 1, 'and it spends the frame core power')

func test_the_cards_text_resolves() -> void:
	assert_ne(X.tr('gear.%s.name' % CORE_ID), 'gear.%s.name' % CORE_ID, 'the core has a name row')
	var effect_key := 'gear.%s.%s.effect' % [CORE_ID, PROTOCOL_ID]
	var effect := X.tr(effect_key)
	assert_ne(effect, effect_key, 'the protocol has an effect row')
	assert_true(effect.contains('field of'), "and it carries ruling 2's rewritten first bullet")
	assert_true(effect.contains('once per round'), 'and the third bullet')

# ---------------------------------------------------------------- A. the field

func test_before_the_press_there_is_no_field() -> void:
	assert_eq(difficult_tiles_on_the_map().size(), 0, 'a clean map: the zone is dark')
	assert_false(core().get_state(FIELD_STATE_KEY, false), 'and the gear state says so')

func test_the_press_raises_a_burst_1_field_of_difficult_terrain() -> void:
	await VaubanFixture.press_protocol(game, vauban)

	assert_true(core().get_state(FIELD_STATE_KEY, false), 'the protocol set the field state key')
	for tile:Vector2i in burst_1_around(VAUBAN_TILE):
		assert_true(is_difficult(tile), '%s is difficult ground' % tile)

func test_the_field_covers_the_vaubans_own_tile() -> void:
	# Ruling 1, the author's call, and the whole reason Gravity Well is permanently on afterwards.
	await VaubanFixture.press_protocol(game, vauban)
	assert_true(is_difficult(VAUBAN_TILE), "the Vauban's own space is in its own field")

func test_the_field_is_exactly_nine_tiles() -> void:
	await VaubanFixture.press_protocol(game, vauban)
	assert_eq(difficult_tiles_on_the_map().size(), 9, 'nine tiles and no more - a Burst 1, not a Burst 2')

func test_the_field_follows_the_vauban() -> void:
	await VaubanFixture.press_protocol(game, vauban)
	var destination := Vector2i(7, 4)
	await SpecFactory.move(game, vauban, destination)
	VaubanFixture.track(game)

	for tile:Vector2i in burst_1_around(destination):
		assert_true(is_difficult(tile), '%s moved with it' % tile)
	assert_false(is_difficult(Vector2i(3, 4)), 'and the far edge of the old field is clean again')

func test_the_field_makes_gravity_well_permanent() -> void:
	# The consequence design ruling 1 accepted, pinned here on purpose: Gravity Well's buff asks
	# whether the VAUBAN is standing in difficult ground (buff_gravity_well.gd, through this same
	# Terrain helper), and after the press it always is - with no other terrain anywhere on the map.
	assert_false(Terrain.is_unit_in_difficult(vauban), 'before the press it stands on clean ground')

	await VaubanFixture.press_protocol(game, vauban)

	assert_true(Terrain.is_unit_in_difficult(vauban),
		'the Vauban now stands in its own difficult ground, so Gravity Well is on for the rest of the scene')

func test_a_second_press_is_refused() -> void:
	await VaubanFixture.press_protocol(game, vauban)
	var before := difficult_tiles_on_the_map().size()
	await SpecFactory.use(game, vauban, CORE_ID, PROTOCOL_ID)
	assert_eq(difficult_tiles_on_the_map().size(), before, 'nothing changed: the core power is spent')
	assert_false(vauban.core.has_core_power, 'and the frame says so')

func test_the_field_survives_a_later_tracking_pass() -> void:
	# The zone is rebuilt from scratch on every pass (map_state.gd:371-378), so a field that is a
	# one-shot write rather than a live projection would vanish here.
	await VaubanFixture.press_protocol(game, vauban)
	VaubanFixture.track(game)
	VaubanFixture.track(game)
	assert_eq(difficult_tiles_on_the_map().size(), 9, 'still nine after two more passes')

func test_clearing_the_state_key_puts_the_field_out() -> void:
	# The gate is the STATE KEY, not the aura flag. This is the mutation guard for
	# passive_grav_amped_field.tres's state_key: with the wrong key (or none) the zone would either
	# never light or light from the start, and both of those pass every test above except this one
	# and test_before_the_press_there_is_no_field.
	await VaubanFixture.press_protocol(game, vauban)
	assert_eq(difficult_tiles_on_the_map().size(), 9, 'fixture: the field is up')

	core().set_state(FIELD_STATE_KEY, false)
	VaubanFixture.track(game)

	assert_eq(difficult_tiles_on_the_map().size(), 0, 'the zone reads the key on every pass')

func test_the_vaubans_death_takes_the_field_with_it() -> void:
	await VaubanFixture.press_protocol(game, vauban)
	assert_eq(difficult_tiles_on_the_map().size(), 9, 'fixture: the field is up')

	await game.execute_event(&'event_unit_die', {unit = vauban})
	VaubanFixture.track(game)

	assert_eq(difficult_tiles_on_the_map().size(), 0, 'unit-projected terrain needs its unit')

# ---------------------------------------------------------------- B. the save difficulty

const CHIP_ID := &'buff_grav_amped_saves'
const SAP_ID := &'mt_sap'

## A hostile far enough from the Vauban to be outside its Burst 1 field, and close enough to be inside
## its Sensors (8) and line of sight - which is what Sap measures to.
const SAP_VICTIM_TILE := Vector2i(10, 4)

func hostile_at(tile:Vector2i) -> Unit:
	var unit := VaubanFixture.create_hostile(game, tile)
	VaubanFixture.track(game)
	return unit

## Stand `unit` in its own patch of difficult ground and open its turn, which is Sap's `new_turn` half.
##
## lay_difficult REPLACES the whole map's ground terrain, so it is called ONCE with every tile any
## test wants; the Vauban's own field is DYNAMIC terrain and is merged on top of this rather than
## erased by it (map_state.gd:474-478), so pressing the protocol and laying a patch compose.
func sap_turn_for(unit:Unit) -> void:
	VaubanFixture.lay_difficult(game, [unit.tile()])
	VaubanFixture.track(game)
	await VaubanFixture.open_turn(game, unit)

func test_before_the_press_no_hostile_carries_the_chip() -> void:
	var hostile := hostile_at(SAP_VICTIM_TILE)
	assert_false(UnitCondition.has_buff(hostile, CHIP_ID), 'the aura starts dark')

func test_the_press_chips_every_hostile() -> void:
	var near := hostile_at(Vector2i(6, 4))
	var far := hostile_at(Vector2i(13, 8)) # the far corner: the clause has no range on the card
	await VaubanFixture.press_protocol(game, vauban)

	assert_true(UnitCondition.has_buff(near, CHIP_ID), 'the near hostile is chipped')
	assert_true(UnitCondition.has_buff(far, CHIP_ID), 'and so is the far one')

func test_the_chip_reaches_a_hostile_that_arrives_after_the_press() -> void:
	await VaubanFixture.press_protocol(game, vauban)
	var latecomer := hostile_at(Vector2i(12, 6))
	assert_true(UnitCondition.has_buff(latecomer, CHIP_ID), 'the aura keeps tracking after the press')

func test_allies_the_vauban_and_non_characters_are_not_chipped() -> void:
	var ally := VaubanFixture.create_ally(game, Vector2i(6, 6))
	var hostile_drone := VaubanFixture.create_drone(game, Vector2i(8, 6), Faction.AI_ENEMY)
	VaubanFixture.track(game)
	await VaubanFixture.press_protocol(game, vauban)

	assert_false(UnitCondition.has_buff(ally, CHIP_ID), 'an ally is not chipped')
	assert_false(UnitCondition.has_buff(vauban, CHIP_ID), 'nor is the Vauban itself')
	assert_true(UnitCondition.has_buff(hostile_drone, CHIP_ID),
		'a hostile DRONE is a character and is chipped - applies_only_to_characters lets it through')

func test_the_chip_is_visible_to_the_player() -> void:
	# Ruling 11: the author chose to see it. If they change their mind at the close it becomes
	# hide_from_player = true and this assertion flips with it.
	await VaubanFixture.press_protocol(game, vauban)
	var hostile := hostile_at(SAP_VICTIM_TILE)
	var chip := UnitCondition.get_buff(hostile, CHIP_ID)
	assert_not_null(chip, 'fixture: the chip is there')
	assert_false(chip.base.hide_from_player, 'and the player can see it')

func test_the_vaubans_death_clears_the_chip() -> void:
	var hostile := hostile_at(SAP_VICTIM_TILE)
	await VaubanFixture.press_protocol(game, vauban)
	assert_true(UnitCondition.has_buff(hostile, CHIP_ID), 'fixture: chipped')

	await game.execute_event(&'event_unit_die', {unit = vauban})
	VaubanFixture.track(game)

	assert_false(UnitCondition.has_buff(hostile, CHIP_ID),
		'aura buffs carry the aura gear as from_gear and go with its owner (passive_aura.gd:52-58)')

func test_a_sap_save_before_the_press_passes_on_an_exact_roll() -> void:
	# The control the next test is measured against. The save target is the FORCER's - the Vauban's 12
	# (event_unit_save.gd:41-43) - and the flat bonus is the SAVER's Hull, so a d20 of exactly
	# (target - hull) meets it.
	var hostile := hostile_at(SAP_VICTIM_TILE)
	VaubanFixture.queue_save_dice(VaubanFixture.save_target_of(vauban) - hostile.core.get_hull())

	await sap_turn_for(hostile)

	assert_false(hostile.has_status(Lancer.STATUS.SLOWED), 'the save was made: no Slowed')

func test_the_same_sap_save_after_the_press_fails() -> void:
	# The difficulty die: Dice.roll_d6_accuracy(-1) rolls ONE d6 and negates it (dice.gd:86-88), and
	# VaubanFixture.queue_save_dice's tail of sixes is what it pops - so the roll that exactly met the
	# target now misses it by six.
	var hostile := hostile_at(SAP_VICTIM_TILE)
	await VaubanFixture.press_protocol(game, vauban)
	VaubanFixture.queue_save_dice(VaubanFixture.save_target_of(vauban) - hostile.core.get_hull())

	await sap_turn_for(hostile)

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'the +1 difficulty turned the pass into a failure')

func test_a_save_forced_by_somebody_else_is_untouched() -> void:
	var hostile := hostile_at(SAP_VICTIM_TILE)
	var stranger := hostile_at(Vector2i(12, 2))
	await VaubanFixture.press_protocol(game, vauban)
	VaubanFixture.queue_save_dice(VaubanFixture.save_target_of(stranger) - hostile.core.get_hull())

	var passed:bool = await VaubanFixture.force_hull_save(self, hostile, VaubanFixture.forcer(stranger))

	assert_true(passed, 'the chip asks WHO is forcing, and it is not the Vauban')

func test_a_save_with_no_valid_forcer_is_untouched_and_does_not_throw() -> void:
	# MEASURED BY THE SP2 PROBE, and the reason the buff's context-validity gate is load-bearing:
	# roll_check copies the forcer into the buff context only `if SpecificAction.is_valid(forcing_action)`
	# (unit_hasecheck.gd:180), and SpecificAction.is_valid demands ALL THREE of unit, gear and action
	# (specific_action.gd:16-23). A save forced with anything less reaches the saver's buffs with NO
	# forcer at all - the battle log says "failed a Hull save from ?" - and the chip must answer "no"
	# rather than throw on a null context.unit.
	var hostile := hostile_at(SAP_VICTIM_TILE)
	await VaubanFixture.press_protocol(game, vauban)
	VaubanFixture.queue_save_dice(VaubanFixture.save_target_of(vauban) - hostile.core.get_hull())

	var passed:bool = await VaubanFixture.force_hull_save(self, hostile, SpecificAction.create(vauban, null, null))

	assert_true(passed, 'no valid forcer reached the roll, so no -1 and no error')

func test_a_save_forced_by_a_mine_the_vauban_owns_is_at_plus_one_difficulty() -> void:
	# Ruling 9, and the reason the Iskander licence's own gear synergises with this core: "saves you
	# force" is the forcer resolved through get_owner_unit_or_self (unit.gd:270-273), so a Grounding
	# Charge mine the Vauban put down counts as the Vauban.
	#
	# The mine is DEPLOYED for real and then asked to force a save directly, rather than detonated:
	# action_grounding_mine_trigger.activate calls TargetActionUtil.ask_for_targets_alt, an
	# interactive pick, and a spec that hangs proves nothing. What is under test is the forcer
	# resolution, not the mine's own targeting.
	var hostile := hostile_at(SAP_VICTIM_TILE)
	var gear := vauban.core.equip_system(&'ms_grounding_charges')
	SpecFactory.apply_passive_buffs(vauban)
	await VaubanFixture.press_protocol(game, vauban) # LAST: a repair would clear the press
	await SpecFactory.use(game, vauban, &'ms_grounding_charges', &'action_grounding_mine', Vector2i(5, 4))
	var deployed:Array = UnitAction.get_deployables_from(vauban, gear)
	assert_false(deployed.is_empty(), 'fixture: a grounding mine was deployed')
	var mine:Unit = deployed.front()

	VaubanFixture.queue_save_dice(VaubanFixture.save_target_of(mine) - hostile.core.get_hull())
	var passed:bool = await VaubanFixture.force_hull_save(self, hostile, VaubanFixture.forcer(mine, &'mt_grounding_mine'))

	assert_false(passed, 'the mine forced it, and the mine is the Vauban')
