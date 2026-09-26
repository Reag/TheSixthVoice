# SOULBIND (a Mask of Many Faces mode, design 2.4, rulings 18-19):
#
#   "Choose a character within Sensors. Whenever you gain heat from any other source, they immediately
#    gain the same amount of heat. Whenever they gain heat from any other source, you immediately gain
#    the same amount of heat."
#
# The partner is picked right after the mode (auto-picked when there is one), any character within
# Sensors, ally or hostile, no line of sight. The bond holds wherever they go until the Rakshasa's next
# turn start, and ends early if either dies. The mirror is vanilla Symbiosis' (action_symbiosis_heat.gd)
# on damage, HEAT only, re-dealt flagged MIRRORED, whose guards are "from any other source" (ruling 19) -
# but it is NOT an ActionReactionMirror: vanilla's is_first_mirror_in_block aborts on ANY earlier sibling
# mirror, so Soulbind and a vanilla Metahook reacting to one heat event would each switch the other off
# (close review). Its own once-per-block check counts only its own activations.
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
	assert_true(action is ActionReaction, 'A reaction.')
	# is_first_mirror_in_block aborts on ANY completed sibling ActionReactionMirror, so being one would
	# switch off a vanilla Metahook or Symbiosis mirroring the same heat.
	assert_false(action is ActionReactionMirror, 'Not vanilla\'s mirror archetype, so no vanilla mirror sees it.')
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

# ---------------------------------------------------------------- beside other mirrors (close review)

## Vanilla Metahook (ms_metahook, li_goblin rank 2) linked to an ally, Soulbind bound to a hostile. Both
## mirrors react to the Rakshasa's one heat event as sibling blocks; vanilla's is_first_mirror_in_block
## aborts whichever runs second if the other is an ActionReactionMirror. Each card says its partner
## "immediately gains the same amount", so both do.
func test_a_vanilla_metahook_and_soulbind_both_mirror_the_same_heat():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var metahook:GearCore = Fixture.equip(rakshasa, &'ms_metahook') # equip full_repairs: before any state
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	var ally := Fixture.create_ally(game, Vector2i(3, 4))
	responder.unit_queue.append(hostile)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	# Metahook's link is this state key (action_metahook.gd:4, :22), which its heat mirror reads.
	metahook.set_state('linked_unit', ally.core.persistent_id)
	var before_r := Fixture.heat(rakshasa)
	var before_a := Fixture.heat(ally)
	var before_h := Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(ally) - before_a, 2, 'Metahook\'s ally gains the same: Soulbind does not switch a vanilla mirror off.')
	assert_eq(Fixture.heat(hostile) - before_h, 2, 'Soulbind\'s hostile gains the same: Metahook does not switch Soulbind off.')
	assert_eq(Fixture.heat(rakshasa) - before_r, 2, 'No echo back from either.')

## The same collision the other way round. On one unit the loadout order puts Metahook's reaction first,
## so the test above catches Metahook switching Soulbind off. Here a SECOND unit owns the Metahook, linked
## to the Rakshasa's partner and registered AFTER the Rakshasa - ReactionBus.trigger_occurred walks
## map.get_all_units() in registration order - so Soulbind runs first, and an ActionReactionMirror
## Soulbind would switch off a vanilla player's Metahook.
func test_soulbind_running_first_does_not_switch_off_a_vanilla_metahook():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	var goblin := Fixture.create_ally(game, Vector2i(3, 4))
	var metahook:GearCore = Fixture.equip(goblin, &'ms_metahook')
	responder.unit_queue.append(hostile)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	metahook.set_state('linked_unit', hostile.core.persistent_id)
	var before_r := Fixture.heat(rakshasa)
	var before_g := Fixture.heat(goblin)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(rakshasa) - before_r, 2, 'Soulbind mirrors the partner\'s heat.')
	assert_eq(Fixture.heat(goblin) - before_g, 2, 'And the vanilla Metahook linked to the same unit still does.')

## The other way in: heat Metahook reflects onto the Rakshasa is flagged MIRRORED, so Soulbind does not
## pass it on (ruling 19) - and heat Soulbind reflects is not passed on by Metahook either.
func test_heat_another_mirror_reflects_is_not_mirrored_again():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var metahook:GearCore = Fixture.equip(rakshasa, &'ms_metahook')
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	var ally := Fixture.create_ally(game, Vector2i(3, 4))
	responder.unit_queue.append(hostile)
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	metahook.set_state('linked_unit', ally.core.persistent_id)
	var before_r := Fixture.heat(rakshasa)
	var before_h := Fixture.heat(hostile)
	await Fixture.deal_heat(game, ally, 2)
	assert_eq(Fixture.heat(rakshasa) - before_r, 2, 'fixture: Metahook reflected the ally\'s heat.')
	assert_eq(Fixture.heat(hostile), before_h, 'Soulbind does not reflect a reflection.')
	var before_a := Fixture.heat(ally)
	before_r = Fixture.heat(rakshasa)
	await Fixture.deal_heat(game, hostile, 1)
	assert_eq(Fixture.heat(rakshasa) - before_r, 1, 'fixture: Soulbind reflected the hostile\'s heat.')
	assert_eq(Fixture.heat(ally), before_a, 'Metahook does not reflect Soulbind\'s reflection.')

## Two Rakshasas bound to one partner are two bonds: each mirrors. The once-per-block check counts only
## THIS gear's own activations, so the other Rakshasa's Soulbind is not "a mirror that beat us to it".
func test_two_rakshasas_bound_to_one_partner_both_mirror():
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var second := Fixture.create_rakshasa(game, Vector2i(1, 4))
	hostile = Fixture.create_hostile(game, HOSTILE_TILE)
	responder.unit_queue.append(hostile) # each has two candidates: the hostile and the other Rakshasa
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	responder.unit_queue.append(hostile)
	await Fixture.choose_mode(game, second, responder, MODE.SOULBIND)
	assert_true(Fixture.holds_mode(rakshasa, MODE.SOULBIND) and Fixture.holds_mode(second, MODE.SOULBIND),
		'fixture: both hold Soulbind.')
	var before_1 := Fixture.heat(rakshasa)
	var before_2 := Fixture.heat(second)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(rakshasa) - before_1, 2, 'The first Rakshasa gains the same.')
	assert_eq(Fixture.heat(second) - before_2, 2, 'And so does the second.')

## Ruling 19, recorded rather than fought: several heat events in ONE block (multi-target attack heat,
## each Overkill tick) are mirrored once - vanilla Symbiosis' behaviour, kept by the own-activation check.
func test_several_heat_events_in_one_block_are_mirrored_once():
	await bound_to_a_hostile()
	var before_r := Fixture.heat(rakshasa)
	var before_h := Fixture.heat(hostile)
	var block := EventBlock.create_multiple([
		EventCore.create(&'event_unit_damage', {unit = rakshasa, number = 1, category = Lancer.DAMAGE_TYPE.HEAT}),
		EventCore.create(&'event_unit_damage', {unit = rakshasa, number = 1, category = Lancer.DAMAGE_TYPE.HEAT}),
	] as Array[EventCore])
	await game.execute_event_block(block)
	assert_eq(Fixture.heat(rakshasa) - before_r, 2, 'fixture: both heat events landed.')
	assert_eq(Fixture.heat(hostile) - before_h, 1, 'Mirrored once per block.')

# ---------------------------------------------------------------- the same amount (close review)

## Weak (npcf_weak_grunt, action_weak_grunt.gd:19-20): "destroyed when they take heat from any source
## other than their own systems" - it spares only SELF_INFLICTED heat. Heat Soulbind passes to a partner
## comes from the Rakshasa's system, not theirs, so it must not carry that flag.
func test_a_weak_grunt_partner_is_destroyed_by_mirrored_heat():
	var control := Fixture.create_hostile(game, FAR_TILE) # beyond Sensors: never a Soulbind candidate
	Fixture.equip(control, &'npcf_weak_grunt')
	await Fixture.deal_heat(game, control, 1)
	assert_false(Unit.is_valid(control), 'fixture: Weak is live - a grunt taking heat is destroyed.')
	rakshasa = Fixture.create_rakshasa(game, RAKSHASA_TILE)
	var grunt := Fixture.create_hostile(game, HOSTILE_TILE)
	Fixture.equip(grunt, &'npcf_weak_grunt')
	await Fixture.choose_mode(game, rakshasa, responder, MODE.SOULBIND)
	assert_true(Unit.is_valid(grunt), 'fixture: the grunt lived through the Rakshasa\'s turn start.')
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_false(Unit.is_valid(grunt), 'Heat from the Rakshasa\'s system destroys a Weak grunt.')

## "The same amount": a partner that resists heat still gains all of it (NO_REDUCE on the partner's side).
func test_a_partner_resisting_heat_still_gains_the_same_amount():
	await bound_to_a_hostile()
	var resist := BuffResistDamage.new()
	resist.to = Buff.TO.RESIST_DAMAGE
	var types:Array[Lancer.DAMAGE_TYPE] = [Lancer.DAMAGE_TYPE.HEAT]
	resist.damage_types = types
	resist.hide_from_player = true
	UnitCondition.apply_buff(SpecFactory.dummy_event(), hostile, resist)
	var before_h := Fixture.heat(hostile)
	await Fixture.deal_heat(game, hostile, 2)
	assert_eq(Fixture.heat(hostile) - before_h, 1, 'fixture: the partner resists heat - 2 halved to 1.')
	before_h = Fixture.heat(hostile)
	await Fixture.deal_heat(game, rakshasa, 2)
	assert_eq(Fixture.heat(hostile) - before_h, 2, 'Mirrored heat is not resisted: the same 2.')
