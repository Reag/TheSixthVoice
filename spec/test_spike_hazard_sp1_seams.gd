# HAZARD SP1 PROBES (design §1.0): the two engine seams this frame's traits and core are built on,
# measured with knockoff Kits on vanilla player units before any content is written.
#
# PROBE 1 - WEIGHT OF FIRE's Grit (ruling 2). A WEAPON_TAG buff applied by a PassiveAura carries
# the aura GEAR's persistent id in its core's `from_gear` (passive_aura.gd:80 ->
# UnitCondition.apply_buffs(..., aura_gear)), so `core.get_owner_unit(map)` inside get_values is
# the AURA unit, not the holder. The Hazard stand-in has Grit 4 and the adjacent ally Grit 1, so
# the ally's Reliable-2 rifle reads 2 + half(4) = 4 if the claim holds and 2 + half(1) = 3 if the
# buff reads the holder instead.
#
# PROBE 2 - SUPPORTING FIRE's trigger (rulings 4-5). NEW_TURN POST (event_turn_start.gd:54) reaches
# a reaction whose holder is NOT the turn unit, with the starter in `context.unit`, once per turn
# start; and a per-round hard limit of 1 on a point-free reaction holds across two allies' turn
# starts, because the holder's uses_this_round is only cleared at the HOLDER's own turn start
# (new_turn_refresh -> reset_per_round_usage, unit_action.gd:76-88).
#
# MUTATION. Probe 1: GRIT_FROM_OWNER := false reads the holder (`context.unit`) instead - the ally
# case must go red with 3. Probe 2: ROUND_LIMIT := 99 - the two-allies case must go red.
#
# If probe 1 fails, the fallback is a buff subclass that walks the map for the adjacent Hazard
# (design §1.0). If probe 2 fails, stop and report. No production code.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_hazard_sp1_seams.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## MUTATION KNOBS. The claims under test as written.
const GRIT_FROM_OWNER := true
const ROUND_LIMIT := 1

const RIFLE := &'mw_assault_rifle' # MAIN, RELIABLE 2, 1d6, aim_range 10
const HAZARD_TILE := Vector2i(4, 4)
const ALLY_TILE := Vector2i(5, 4)
const OTHER_ALLY_TILE := Vector2i(4, 5)
const FAR_TILE := Vector2i(8, 4)


## PROBE 1's buff: Reliable + half the Grit of whoever the claim says it reads.
class SpikeWofBuff extends BuffWeaponTypeTag:
	func _init() -> void:
		compcon_id = &'buff_spike_hazard_wof'
		to = Buff.TO.WEAPON_TAG
		added_tag = Lancer.WEAPON_TAG.RELIABLE
		weapon_sizes = [Lancer.WEAPON_SIZE.MAIN, Lancer.WEAPON_SIZE.HEAVY, Lancer.WEAPON_SIZE.SUPERHEAVY]
		hide_from_player = true

	func get_values(core:BuffCore, context:Context) -> Context:
		var reader:Unit = core.get_owner_unit(context.map) if GRIT_FROM_OWNER else context.unit
		return Context.create({category = added_tag, number = Util.half(Overshield.grit(reader))})


## PROBE 2's reaction: point-free NEW_TURN POST, gated on an allied starter that is not the holder.
class TurnWatcher extends ActionReaction:
	var starters:Array[Unit] = []
	var asked:int = 0

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.NEW_TURN]
		trigger_timing = ReactionBus.TIMING.POST
		consumes_rxn = false

	func show_in_tooltip(_kit:Kit) -> bool: return false
	func get_per_round_hard_limit(_specific:SpecificAction) -> int: return ROUND_LIMIT
	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit]

	func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		asked += 1
		var starter:Unit = triggering_event.context.unit
		if not Unit.is_valid(starter) or starter == unit: return false
		return UnitRelation.are_allies(unit, starter)

	func activate(context:Context, activation:EventCore) -> void:
		starters.append(context.event.context.unit)
		spend_actions(activation)


var game:Gamemaster
var hazard:Unit
var ally:Unit


func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = SpecFactory.create_unit(game.map, HAZARD_TILE, Faction.PLAYER)
	hazard.core.pilot.license_level = 8 # Grit 4
	ally = SpecFactory.create_unit(game.map, ALLY_TILE, Faction.PLAYER)
	ally.core.pilot.license_level = 2 # Grit 1
	ally.core.equip_system(RIFLE)
	ally.core.full_repair()

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

func install_kit(unit:Unit, kit_id:StringName, actions:Array[Action], passives:Array[Passive]) -> GearCore:
	var kit := Kit.new()
	kit.compcon_id = kit_id
	kit.is_trait = true
	kit.actions.append_array(actions)
	kit.passives.append_array(passives)
	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)
	return unit.get_gear(kit_id)

func install_aura() -> void:
	var aura := PassiveAura.new()
	aura.buffs = [SpikeWofBuff.new()] as Array[Buff]
	aura.aura_range = 1
	aura.applies_to_enemies = false
	install_kit(hazard, &'spike_hazard_wof', [] as Array[Action], [aura] as Array[Passive])

func reliable_of(unit:Unit, kit_id:StringName) -> int:
	var gear:GearCore = unit.get_gear(kit_id)
	var specific := SpecificAction.create(unit, gear, gear.get_solo_action())
	return specific.action.get_weapon_tags(specific).get(Lancer.WEAPON_TAG.RELIABLE, 0)


# ---------------------------------------------------------------- probe 1

func test_fixture_grits():
	assert_eq(Overshield.grit(hazard), 4, 'fixture: the Hazard stand-in has Grit 4.')
	assert_eq(Overshield.grit(ally), 1, 'fixture: the ally has Grit 1.')
	assert_eq(reliable_of(ally, RIFLE), 2, 'fixture: the rifle prints Reliable 2 with no aura.')

func test_an_aura_applied_weapon_tag_buff_reads_the_aura_units_grit():
	install_aura()
	assert_true(UnitCondition.has_buff(ally, &'buff_spike_hazard_wof'), 'LIVENESS: the aura put the buff on the adjacent ally.')
	var core:BuffCore = UnitCondition.get_buff(ally, &'buff_spike_hazard_wof')
	assert_eq(core.get_owner_unit(game.map), hazard, 'CLAIM: the buff core names the AURA unit as its owner.')
	assert_eq(reliable_of(ally, RIFLE), 4, 'CLAIM: Reliable 2 + half the HAZARD\'s Grit 4 = 4 (3 would be the ally\'s own Grit).')

func test_the_aura_buff_goes_away_out_of_range_and_the_tag_with_it():
	install_aura()
	UnitTile.move_to(ally, FAR_TILE)
	assert_false(UnitCondition.has_buff(ally, &'buff_spike_hazard_wof'), 'The aura strips the buff out of range.')
	assert_eq(reliable_of(ally, RIFLE), 2, 'And the tag returns to printed.')


# ---------------------------------------------------------------- probe 2

func test_an_allys_turn_start_reaches_the_holders_new_turn_post_reaction_with_the_starter():
	var watcher := TurnWatcher.new()
	install_kit(hazard, &'spike_hazard_turn', [watcher] as Array[Action], [] as Array[Passive])
	await SpecFactory.start_turn(game, ally)
	assert_gt(watcher.asked, 0, 'LIVENESS: the bus asked the holder about the ally\'s turn start.')
	assert_eq(watcher.starters, [ally] as Array[Unit], 'CLAIM: one activation, with the STARTER in context.unit.')

func test_the_holders_own_turn_start_does_not_trigger():
	var watcher := TurnWatcher.new()
	install_kit(hazard, &'spike_hazard_turn', [watcher] as Array[Action], [] as Array[Passive])
	await SpecFactory.start_turn(game, hazard)
	assert_eq(watcher.starters.size(), 0, 'The holder\'s own turn start is gated out.')

func test_the_per_round_limit_holds_across_two_allies_and_resets_on_the_holders_turn():
	var other := SpecFactory.create_unit(game.map, OTHER_ALLY_TILE, Faction.PLAYER)
	var watcher := TurnWatcher.new()
	var gear := install_kit(hazard, &'spike_hazard_turn', [watcher] as Array[Action], [] as Array[Passive])
	await SpecFactory.start_turn(game, ally)
	await SpecFactory.end_turn(game, ally)
	await SpecFactory.start_turn(game, other)
	await SpecFactory.end_turn(game, other)
	assert_eq(watcher.starters, [ally] as Array[Unit], 'CLAIM: 1/round - the second ally\'s turn start is refused.')
	assert_eq(gear.get_uses_this_round(watcher), 1, 'The tally is 1.')
	await SpecFactory.start_turn(game, hazard)
	await SpecFactory.end_turn(game, hazard)
	await SpecFactory.start_turn(game, other)
	assert_eq(watcher.starters, [ally, other] as Array[Unit], 'The holder\'s own turn start re-arms it.')
