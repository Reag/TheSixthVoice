# INEXORABLE FORMATION (the Sluagh's third sheet trait, SP1 Task 5).
#
#   "The Sluagh increases its Sensors equal to its OVERSHIELD."
#
# A Buff.TO.STATBLOCK buff whose get_values reports the holder's CURRENT Overshield as a
# sensor_range bonus - the Effervescent Immunity shape, and the Goblin's buff_symbiosis_statblock.gd
# is vanilla's. There is no other channel: Unit.get_sensor_range() is
# core.get_sensor_range() + state.stat_bonus.sensor_range (unit.gd:305), and stat_bonus is built from
# STATBLOCK buffs alone (unit_battle_state.gd:229-234).
#
# TWENTY-FIVE READERS DOWNSTREAM, which is why this trait is worth its own file: Scan, Search, tech
# attack range, every target_range_is_sensors action, Eye of Horus - and all four of this frame's own
# Sensors reads, one of which (the Stealing) is asserted here from the other side.
#
# THE REFRESH IS TWO MECHANISMS AND BOTH ARE TESTED. A GAIN is refreshed by the shared helper
# (SP1 Task 4's one line in Overshield.grant); a LOSS is not - event_unit_damage spends the shield
# inside damage() at :119 and rebuilds nothing - so the buff itself listens on DAMAGE POST for its
# own holder and refreshes there.
#
# DELETE EITHER AND SEVERAL TESTS GO RED - not one, which is what this line claimed until the close
# (SP1 ledger line 104 had the real numbers all along). MEASURED at SP1 Task 5: emptying
# buff_inexorable_formation.tres's `triggers_on` reddens THREE
# (test_the_chip_is_hidden_and_on_the_statblock_channel,
# test_sensors_fall_back_when_damage_strips_the_overshield, test_partial_loss_moves_sensors_partway);
# neutralising overshield.gd:87's `target.update_cached_values_and_token()` reddens FOUR here, plus
# two in test_overshield.gd.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_inexorable_formation.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const SLUAGH_TILE := Vector2i(4, 6)
## The sheet's Sensors.
const BASE_SENSORS := 10
## Eleven tiles east: one past base Sensors, and exactly what one point of Overshield buys.
const ELEVEN_TILE := Vector2i(15, 6)

const GRIT := 2

var game:Gamemaster
var sluagh:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- the wiring

func test_the_trait_is_registered_and_on_the_frame():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.FORMATION_ID)
	assert_not_null(kit, '%s loads as a Kit through ContentLibrary.' % SluaghFixture.FORMATION_ID)
	if kit == null: return
	assert_true(kit.is_trait, 'It is a frame trait, not equippable gear.')
	assert_true(GearCore.is_valid(sluagh.get_gear(SluaghFixture.FORMATION_ID)),
		'And the live Sluagh carries it as gear.')
	assert_true(UnitCondition.has_buff(sluagh, SluaghFixture.FORMATION_CHIP),
		'And its PassiveBuffApplicator hung the chip at combat start - the trait is always on.')

func test_the_card_rows_resolve():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['gear.mt_inexorable_formation.name', 'gear.mt_inexorable_formation.effect']:
		assert_ne(translation.get_message(key), StringName(''), 'Our own artifact carries %s.' % key)
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.mt_inexorable_formation.name'), 'Inexorable Formation', 'The card\'s name.')

func test_the_chip_is_hidden_and_on_the_statblock_channel():
	# Untyped local: `to` is a Buff export but this buff carries OUR script, and naming a subclass's
	# member through a typed local of the wrong class is a parse error GUT answers by skipping the
	# file (memory lancer-tactics-spec-harness-traps).
	var chip = ContentLibrary.get_buff(SluaghFixture.FORMATION_CHIP)
	assert_not_null(chip, 'buff_inexorable_formation loads.')
	if chip == null: return
	assert_eq(chip.to, Buff.TO.STATBLOCK, 'It speaks on the statblock channel and no other.')
	# HIDDEN, and that is design 1.4's recommendation taken: the Sensors number on the unit already
	# moves, so a chip would be a second signal for one effect. It also needs no icon, because
	# nothing draws a STATBLOCK buff - update_cached_values asks for get_values() and never for an
	# icon (unit_battle_state.gd:231-234) - which is why it is in neither icon table.
	assert_true(chip.hide_from_player, 'And it is hidden: the number on the unit is the signal.')
	assert_eq(chip.triggers_on, [&'damage'] as Array[StringName],
		'It listens on DAMAGE, which is the only way a LOSS of Overshield reaches it.')
	assert_eq(chip.trigger_timing, ReactionBus.TIMING.POST,
		'At POST: event_unit_damage spends the shield at :119 and queues POST at :196.')

# ---------------------------------------------------------------- the card

func test_sensors_are_the_sheet_value_at_zero_overshield():
	assert_eq(Overshield.current(sluagh), 0, 'fixture: a fresh Sluagh holds none.')
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS,
		'With no Overshield the trait adds nothing and the sheet value stands.')

func test_sensors_rise_with_the_overshield():
	# THE GAIN PATH, which is Task 4's one line in Overshield.grant. Without it this reads 10.
	await SluaghFixture.grant_overshield(sluagh, 3)
	assert_eq(Overshield.current(sluagh), 3, 'fixture: the grant landed.')
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 3, 'Sensors 13 at 3 Overshield.')

func test_sensors_fall_back_when_damage_strips_the_overshield():
	# THE LOSS PATH, which the helper does NOT cover: event_unit_damage spends the shield inside
	# damage() (:119, the mini(amount, overshield) subtraction at :215-218) and rebuilds no cache at
	# all. The buff's own DAMAGE POST trigger is what puts it back, and deleting that trigger reddens
	# exactly this test.
	#
	# THREE DAMAGE AGAINST THREE OVERSHIELD, so the shield is spent to the point and the 8 HP frame
	# is untouched - which the second assertion pins, because a test whose subject died would be a
	# different test.
	await SluaghFixture.grant_overshield(sluagh, 3)
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 3, 'fixture: up to 13.')

	await game.execute_event(&'event_unit_damage', {unit = sluagh, number = 3})
	assert_eq(Overshield.current(sluagh), 0, 'fixture: the shield absorbed all of it.')
	assert_eq(sluagh.current_damage(), 0, 'fixture: and none of it reached the frame.')
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS,
		'Sensors fell back the moment the Overshield did.')

func test_partial_loss_moves_sensors_partway():
	# The card is "equal to its OVERSHIELD", not a flag: 3 granted, 1 spent, 2 left, Sensors 12. A
	# buff written as a fixed bonus, or one that only refreshed at zero, passes every other test in
	# this file and fails here.
	await SluaghFixture.grant_overshield(sluagh, 3)
	await game.execute_event(&'event_unit_damage', {unit = sluagh, number = 1})
	assert_eq(Overshield.current(sluagh), 2, 'fixture: 3 - 1.')
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 2, 'Sensors track the remainder, not a flag.')

func test_scans_target_range_follows_the_live_sensors():
	# A REAL DOWNSTREAM READER, not another look at the same accessor. Vanilla Scan's action
	# overrides get_target_range to specific.unit.get_sensor_range() (action_scan.gd:4-5), and
	# ms_scan is in every player mech's basic loadout so nothing has to be equipped for it. This is
	# the cheapest proof that the twenty-five readers of that accessor really do see the bonus.
	var scan := SpecificAction.from_id(sluagh, SluaghFixture.SCAN_ID)
	assert_true(SpecificAction.is_valid(scan), 'fixture: every player mech carries Scan.')
	if not SpecificAction.is_valid(scan): return
	assert_eq(scan.action.get_target_range(scan), BASE_SENSORS, 'Scan reaches 10 to start.')

	await SluaghFixture.grant_overshield(sluagh, 4)
	assert_eq(scan.action.get_target_range(scan), BASE_SENSORS + 4,
		'And 14 once the Sluagh is holding 4 Overshield.')

func test_the_stealing_reaches_one_tile_further_with_overshield_held():
	# RULING 11's "the LIVE value, Inexorable Formation included", asserted from the OTHER trait's
	# side - which is the only place the two meet. test_stealing_of_the_souls.gd pins the same tile
	# as OUT of range at 0 Overshield; this pins it IN at 1.
	#
	# ONE POINT OF OVERSHIELD, not three: eleven is exactly one past the sheet's ten, so this is the
	# smallest possible statement of "the range moved".
	SluaghFixture.set_grit(sluagh, GRIT)
	await SluaghFixture.grant_overshield(sluagh, 1)
	assert_eq(sluagh.get_sensor_range(), BASE_SENSORS + 1, 'fixture: Sensors 11.')

	var victim:Unit = SluaghFixture.create_hostile(game, ELEVEN_TILE)
	assert_eq(UnitRelation.distance_between(sluagh, victim), 11, 'fixture: eleven away.')
	await SluaghFixture.kill(game, victim)
	assert_eq(Overshield.current(sluagh), GRIT,
		'The Stealing reached it, and granted GRIT - which is 2, above the 1 it started with, so '
		+ 'the max-semantics grant is visible as a change rather than a no-op.')
