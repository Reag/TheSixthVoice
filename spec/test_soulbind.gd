# SOULBIND (a Mask of Many Faces mode, design 2.4, rulings 18-19):
#
#   "Choose a character within Sensors. Whenever you gain heat from any other source, they immediately
#    gain the same amount of heat. Whenever they gain heat from any other source, you immediately gain
#    the same amount of heat."
#
# The partner is picked right after the mode (auto-picked when there is one), any character within
# Sensors, ally or hostile, no line of sight. The bond holds wherever they go until the Rakshasa's next
# turn start, and ends early if either dies. The mirror is vanilla Symbiosis' (action_symbiosis_heat.gd):
# an ActionReactionMirror on damage, HEAT only, re-dealt flagged MIRRORED, whose guards are "from any
# other source" (ruling 19).
#
# Heat is dealt straight through event_unit_damage from no source (Fixture.deal_heat). The Rakshasa's
# heat cap is its sheet's 5, so no test here puts more than 4 on it.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_soulbind.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/rakshasa_fixture.gd')
const MODE := Fixture.MODE

const RAKSHASA_TILE := Vector2i(1, 2)
const HOSTILE_TILE := Vector2i(5, 2)
## 24 tiles from the Rakshasa: outside its Sensors 20.
const FAR_TILE := Vector2i(25, 2)

var game:Gamemaster
var responder
var rakshasa:Unit
var hostile:Unit

func before_each() -> void:
	await get_tree().process_frame
	var built:Array = Fixture.create_game_with_prompts(self, Fixture.WIDE_MAP_SIZE)
	game = built[0]
	responder = built[1]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## The plain arrangement: a player Rakshasa bound to its only hostile.
func bound_to_a_hostile() -> void:
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	assert_true(Fixture.holds_mode(rakshasa, MODE.SOULBIND), 'fixture: Soulbind is held.')

func _action() -> Action:
	var gear:GearCore = rakshasa.get_gear(Fixture.CORE_ID)
	return gear.get_action(Fixture.SOULBIND_ACTION) if GearCore.is_valid(gear) else null

# ---------------------------------------------------------------- shape

func test_soulbind_is_a_quiet_heat_mirror_on_the_core_system():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var action = _action()
	assert_not_null(action, 'The core system carries Soulbind.')
	if action == null: return
	assert_true(action is ActionReactionMirror, 'Vanilla\'s mirror archetype.')
	assert_eq(action.triggers_on, [&'damage'] as Array[StringName], 'On damage.')
	assert_false(action.consumes_reaction(), 'No reaction point.')
	assert_ne(action.usage_group, &'', 'On its own usage group.')

# ---------------------------------------------------------------- the pick

func test_one_character_in_sensors_is_bound_without_asking():
	await bound_to_a_hostile()
	assert_eq(responder.unit_prompts.size(), 0, 'Nobody to choose between.')
	var before := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(hostile) - before, 2, 'Bound to the only one.')

func test_the_pick_offers_every_character_in_sensors_and_nobody_else():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	var ally := Fixture.create_ally(game, Vector2i(3, 4))
	var far := Fixture.create_hostile(game, FAR_TILE)
	var drone := Fixture.create_hostile_drone(game, Vector2i(2, 4))
	responder.unit_queue.append(ally)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	assert_eq(responder.unit_prompts.size(), 1, 'One pick.')
	if responder.unit_prompts.is_empty(): return
	var offered:Array = responder.unit_prompts[0].units
	assert_true(offered.has(hostile), 'A hostile within Sensors.')
	assert_true(offered.has(ally), 'An ally within Sensors: any character.')
	assert_false(offered.has(far), 'Not beyond Sensors.')
	assert_false(offered.has(drone), 'Not a drone.')
	assert_false(offered.has(rakshasa), 'Not itself.')
	assert_eq(offered.size(), 2, 'Those two only.')

func test_an_allied_partner_is_mirrored_the_same_way():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	var ally := Fixture.create_ally(game, Vector2i(3, 4))
	responder.unit_queue.append(ally)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	var before_ally := Fixture.heat(ally)
	var before_hostile := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(ally) - before_ally, 2, 'The chosen ally.')
	assert_eq(Fixture.heat(hostile), before_hostile, 'Not the hostile nobody chose.')

func test_an_ai_rakshasa_binds_the_nearest_hostile():
	# Nobody answers an AI's pick; it takes the nearest hostile character, its allies only failing that.
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE, Faction.AI_ENEMY)
	var its_ally := Fixture.create_hostile(game, Vector2i(2, 2)) # AI_ENEMY: the Rakshasa's own side
	var near := Fixture.create_ally(game, Vector2i(6, 2))        # PLAYER: hostile to it
	var further := Fixture.create_ally(game, Vector2i(12, 2))
	for i:int in 4: await Fixture.cycle_turn(game, rakshasa) # Drain, Entrap, Stabilizer Override, Soulbind
	assert_true(Fixture.holds_mode(rakshasa, MODE.SOULBIND), 'fixture: the fourth turn is Soulbind.')
	assert_eq(responder.unit_prompts.size(), 0, 'Nobody was asked.')
	var before := Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, near, 2)
	assert_eq(Fixture.heat(rakshasa) - before, 2, 'Bound to the nearest hostile.')
	before = Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, its_ally, 2)
	await Fixture.deal_heat(game, further, 2)
	assert_eq(Fixture.heat(rakshasa), before, 'And nobody else.')

# ---------------------------------------------------------------- both directions

func test_the_rakshasa_gaining_heat_gives_the_partner_the_same_once():
	await bound_to_a_hostile()
	var before_r := Fixture.heat(rakshasa)
	var before_h := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 3)
	assert_eq(Fixture.heat(hostile) - before_h, 3, 'The same amount.')
	assert_eq(Fixture.heat(rakshasa) - before_r, 3, 'No echo back: exactly its own 3.')

func test_the_partner_gaining_heat_gives_the_rakshasa_the_same_once():
	await bound_to_a_hostile()
	var before_r := Fixture.heat(rakshasa)
	var before_h := Fixture.heat(hostile)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(rakshasa) - before_r, 2, 'The same amount.')
	assert_eq(Fixture.heat(hostile) - before_h, 2, 'No echo back: exactly its own 2.')

func test_mirrored_heat_is_not_mirrored_again():
	# "From any other source": vanilla's MIRRORED guard. Symbiosis and Metahook flag their heat so.
	await bound_to_a_hostile()
	var before := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2, [EventService.DAMAGE_FLAG.MIRRORED])
	assert_eq(Fixture.heat(rakshasa), 2, 'fixture: the Rakshasa took it.')
	assert_eq(Fixture.heat(hostile), before, 'Not reflected a second time.')

func test_self_heat_from_a_system_is_mirrored():
	await bound_to_a_hostile()
	var before_r := Fixture.heat(rakshasa)
	var before_h := Fixture.heat(hostile)
	await SpecFactory.use_solo(game, rakshasa, &'ms_overcharge') # the first Overcharge: 1 self-heat
	var gained:int = Fixture.heat(rakshasa) - before_r
	assert_gt(gained, 0, 'fixture: the Overcharge cost heat.')
	assert_eq(Fixture.heat(hostile) - before_h, gained, 'The partner gains the same.')

func test_heat_to_somebody_else_is_not_mirrored():
	await bound_to_a_hostile()
	var stranger := Fixture.create_hostile(game, Vector2i(8, 4))
	var before := Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, stranger, 2)
	assert_eq(Fixture.heat(stranger), 2, 'fixture: the stranger took it.')
	assert_eq(Fixture.heat(rakshasa), before, 'Only the bound partner.')

func test_damage_that_is_not_heat_is_not_mirrored():
	await bound_to_a_hostile()
	var before := hostile.current_damage()
	var before_heat := Fixture.heat(hostile)
	await SpecFactory.damage(game, rakshasa, 2, Lancer.DAMAGE_TYPE.KINETIC)
	assert_gt(rakshasa.current_damage(), 0, 'fixture: the Rakshasa was hurt.')
	assert_eq(hostile.current_damage(), before, 'Heat only: no damage passed on.')
	# The mirror always deals HEAT, so a mirrored Kinetic hit would show here, not in current_damage.
	assert_eq(Fixture.heat(hostile), before_heat, 'Heat only: no heat passed on either.')

func test_the_bond_is_the_chip_stripping_it_ends_the_bond():
	# The partner survives in gear state until the next menu; the chip is what holds the mode, so a
	# chip stripped mid-turn (by anything that clears buffs) ends the bond at once.
	await bound_to_a_hostile()
	var chip:BuffCore = UnitCondition.get_buff(rakshasa, Fixture.MODE_CHIPS[MODE.SOULBIND])
	UnitCondition.clear_buffs(SpecFactory.dummy_event(), rakshasa, [chip] as Array[BuffCore])
	assert_false(Fixture.holds_mode(rakshasa, MODE.SOULBIND), 'fixture: the chip is gone.')
	var before := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(hostile), before, 'No chip, no bond.')

# ---------------------------------------------------------------- how long

func test_the_bond_holds_through_other_turns():
	await bound_to_a_hostile()
	await SpecFactory.end_turn(game, rakshasa)
	await SpecFactory.start_turn(game, hostile)
	var before := Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(rakshasa) - before, 2, 'Until the Rakshasa\'s NEXT turn start.')

func test_the_bond_outlasts_leaving_sensors():
	# Ruling 18 (author): Sensors is checked only at the choice.
	await bound_to_a_hostile()
	UnitTile.move_to(hostile, FAR_TILE)
	assert_gt(UnitRelation.distance_between(rakshasa, hostile), rakshasa.get_sensor_range(), 'fixture: out of Sensors.')
	var before := Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(rakshasa) - before, 2, 'Still bound.')

func test_the_bond_ends_at_the_next_turn_start():
	await bound_to_a_hostile()
	await Fixture.choose_mode(game, rakshasa, responder, MODE.DRAIN)
	var before := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(hostile), before, 'A new mode: no bond.')

## OVER-DETERMINED, RECORDED (mutation B7, 2026-09-26): short_wave_disruptors.partner's liveness check
## can be deleted with this test still green, because the mirror's activate aborts on the dead unit
## (abort_without_units) and generate_damage_events skips an invalid target anyway. The test pins the
## outcome, which three independent guards all produce.
func test_a_dead_partner_ends_the_bond():
	await bound_to_a_hostile()
	await game.execute_event(&'event_unit_die', {unit = hostile})
	assert_false(Unit.is_valid(hostile), 'fixture: the partner is dead.')
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(rakshasa), 2, 'The Rakshasa takes its own heat and nothing more.')
