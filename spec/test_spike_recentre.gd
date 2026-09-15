# Subutai SP2, the RECENTRE PROBE (design §2.0). Run before any SP2 content is written.
#
# Ruling 1 (2026-09-15) reversed Spike 3's per-unit swap: Draw Fire RECENTRES an AoE on the Subutai.
# A Blast is recentred on the Subutai's tile, a Line or Cone is re-aimed from the attacker at the
# Subutai, and the whole area and its caught units are rebuilt - so whoever stands around the
# Subutai is caught and whoever stood near the original ally is spared. A Burst (centred on the
# attacker) and a Line or Cone that cannot reach the Subutai are refused outright (ruling 2).
#
# THE SEAM UNDER TEST is NOT the one Spike 3 proved. Spike 3 rewrote the per-target event_unit_attack's
# target at ATTACK PRE; this probe rewrites the DeclaredAttackSummary itself at ATTACK_DECLARED PRE.
# event_unit_attack_declared.execute_preblock awaits the PRE reactions (:21-23) BEFORE execute reads
# directly_attacked_tiles / all_attacked_tiles (:34-36, the on-targeted-tile effects), duplicates
# all_attacked_units for the per-target rolls (:54) and hands all_attacked_tiles to the ground-damage
# event (:193). Nothing between the preblock and those reads copies the summary, so rewriting its
# arrays IN PLACE is seen by every one of them. The rebuild copies the exact three steps of
# ActionAttack.get_attacked_tiles_and_units_from_plan (action_attack.gd:156-173).
#
# The probe reaction below is an inline ActionReaction on a runtime Kit, exactly as
# test_spike_draw_fire.gd did. It is a PROBE: when the real Draw Fire is built on cp_siege_engine,
# this file is deleted and test_draw_fire.gd carries the coverage against the real .tres.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_recentre.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')

## One row, west to east: the enemy shoots east at the ally; the guardian stands further east.
const ENEMY_TILE := Vector2i(2, 6)
const ALLY_TILE := Vector2i(5, 6)
const GUARDIAN_TILE := Vector2i(9, 6)
## Inside a Blast 1 centred on the ally, and inside a Blast 1 centred on the guardian, respectively.
const BESIDE_ALLY := Vector2i(5, 7)
const BESIDE_GUARDIAN := Vector2i(9, 7)
## Off the ray from the enemy to the guardian: a Line re-aimed at the guardian no longer crosses it.
const ALLY_OFF_RAY := Vector2i(5, 4)
## Adjacent to the ally, for the Burst control.
const ADJACENT_TO_ALLY := Vector2i(4, 6)

## Vanilla GMS Main Rifle: Range 10, 1d6 kinetic, Reliable 2, no accuracy of its own.
const RIFLE := &'mw_assault_rifle'
## Vanilla GMS Blast 1 cannon, Range 15, Arcing, Inaccurate, explosive.
const MORTAR := &'mw_mortar'
## Vanilla GMS Line 5 aux rifle, 2 energy.
const THERMAL_PISTOL := &'mw_thermal_pistol'
## Vanilla GMS Line 10 heavy cannon, 1d6+3 energy, self-heat 2.
const THERMAL_LANCE := &'mw_thermal_lance'
## Vanilla HORUS Cone 3 aux CQB, 1d3 energy, self-heat 2.
const CATALYST_PISTOL := &'mw_catalyst_pistol'
## Vanilla IPS-N Burst 1 aux CQB, 1 kinetic.
const BRISTLECROWN := &'mw_bristlecrown_flechette_launcher'

## Evasions chosen so ONE d20 tells the two apart: a 10 hits the ally and misses the guardian.
const ALLY_EVASION := 5
const GUARDIAN_EVASION := 15
const ENEMY_EVASION := -10
const D20_HITS_ALLY_ONLY := 10
const D20_HITS_BOTH := 19 # and never crits

var game:Gamemaster
var enemy:Unit
var ally:Unit
var guardian:Unit
var probe:RecentreProbe
var recorder:TerrainRecorder

# ---------------------------------------------------------------- the probe

## The Draw Fire shape on the ATTACK_DECLARED seam: gated on the attacker being an enemy character
## with a ranged weapon the engine does not exempt from redirects, on at least one allied character
## being in the declared attack and the reactor not, and on a DRY rebuild that actually contains the
## reactor (a Burst never does; a Line or Cone only if it reaches).
class RecentreProbe extends ActionReaction:
	const USAGE := &'spike_recentre'

	## The reactor's own weapon for the follow-up. Null = no follow-up.
	var counter_weapon:GearCore = null

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK_DECLARED]
		trigger_timing = ReactionBus.TIMING.PRE
		usage_group = USAGE

	func get_required_triggering_context() -> Array[Context.PROP]:
		return [Context.PROP.unit, Context.PROP.gear, Context.PROP.action, Context.PROP.resource]

	func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
		var triggering_context:Context = triggering_event.context
		var summary:DeclaredAttackSummary = triggering_context.resource
		if not DeclaredAttackSummary.is_valid(summary): return false
		var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
		if not Unit.is_valid(attacker) or not attacker.is_character(): return false
		if not UnitRelation.are_enemies(unit, attacker): return false
		if not UnitAction.is_ranged_weapon(triggering_context.action, triggering_context.gear): return false
		if triggering_context.action.is_immune_to_automisses_and_redirects(triggering_context): return false
		if summary.all_attacked_units.has(unit): return false # an attack already on us needs no drawing
		if allies_under_fire(unit, summary).is_empty(): return false
		return rebuild(unit, triggering_context, false)

	func activate(context:Context, activation:EventCore) -> void:
		var triggering_context:Context = context.event.context
		var summary:DeclaredAttackSummary = triggering_context.resource
		var allies := allies_under_fire(context.unit, summary)

		var confirmed := await CommonActionUtil.confirm_use(context, allies, [], SpecificAction.from_context(triggering_context))
		if activation.abort_when(not confirmed): return
		spend_actions(activation)

		rebuild(context.unit, triggering_context, true)

		if GearCore.is_valid(counter_weapon):
			var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
			var shot := SpecificAction.create(context.unit, counter_weapon, counter_weapon.get_solo_action())
			CommonActionUtil.choose_and_use_after_triggering_event(
				activation, shot, [shot],
				CommonActionUtil.choose_and_use_no_spend, attacker, [Action.FLAG.AS_FREEBIE]
			)

	static func allies_under_fire(unit:Unit, summary:DeclaredAttackSummary) -> Array[Unit]:
		var allies:Array[Unit] = []
		for attacked:Unit in summary.all_attacked_units:
			if attacked == unit: continue
			if attacked.is_character() and UnitRelation.are_allies(unit, attacked): allies.append(attacked)
		return allies

	## THE REBUILD. DRY (live = false) answers "would the rebuilt area contain the reactor?"; LIVE
	## writes the four summary arrays in place. Copies get_attacked_tiles_and_units_from_plan
	## (action_attack.gd:156-173) step for step, so the rebuilt area is exactly what the attacker
	## would have got by aiming there.
	##
	## THE AIM TILE is the reactor's occupied tile closest to the attacker, not its anchor: for a
	## size-2 reactor a Line 5 that reaches the near edge but not the north-west anchor still
	## "includes" the reactor on the table. A Blast 1 centred on ANY tile of a 2x2 footprint covers
	## the whole footprint, so it makes no difference to a Blast. Recorded for the author.
	static func rebuild(unit:Unit, triggering_context:Context, live:bool) -> bool:
		var specific := SpecificAction.from_context(triggering_context)
		var summary:DeclaredAttackSummary = triggering_context.resource
		var map:MapState = specific.unit.map
		var aim:Vector2i = Tile.closest_possible_to(unit.occupied_tiles(), specific.unit.tile())

		# 1. the direct targets: every tile an allied character stands on becomes the aim tile
		var allies := allies_under_fire(unit, summary)
		var new_targets:Array[Vector2i] = []
		for tile:Vector2i in summary.directly_attacked_tiles:
			var moved := tile
			for allied:Unit in allies:
				if allied.occupied_tiles().has(tile):
					moved = aim
					break
			Util.append_nonduplicate(new_targets, moved)

		# 2. the area and the units in it
		var reqs := specific.action.get_target_requirements(specific)
		var pattern := specific.action.get_range_pattern_for_targets(specific, specific.unit.tile(), new_targets)
		var new_tiles:Array[Vector2i] = []
		var new_units:Array[Unit] = []
		if pattern and not reqs.aoe_is_just_for_show:
			if pattern.pattern == Lancer.AOE_TYPE.BURST: return false # centred on the attacker: cannot be moved
			new_tiles = specific.action.get_aoe_tiles_with_targets(pattern, new_targets, specific.unit.tile(), specific)
			for aoe_unit:Unit in map.get_all_units_at_tiles(new_tiles, specific.unit):
				Util.append_nonduplicate(new_units, aoe_unit)
		else:
			new_tiles = new_targets
			for attacked:Unit in summary.all_attacked_units:
				Util.append_nonduplicate(new_units, unit if allies.has(attacked) else attacked)
		Util.filter(new_units, specific.action.can_target_unit.bind(specific))
		CommonActionUtil.sort_deployables_and_grunts_to_back(new_units)

		if not new_units.has(unit): return false
		if not live: return true

		# 3. IN PLACE: the summary is shared by reference with the declared-attack event and the
		# attack action's own context, so the arrays are assigned, never replaced.
		summary.directly_attacked_tiles.assign(new_targets)
		summary.all_attacked_tiles.assign(new_tiles)
		summary.all_attacked_units.assign(new_units)
		summary.source_voxels.assign(specific.action.get_origin_voxels(specific, new_targets, specific.unit.tile()))
		return true

## Records the tiles every terrain-damage event was raised against. A reaction that never fires:
## it reads the triggering context and refuses, so it costs no point and opens no prompt.
class TerrainRecorder extends ActionReaction:
	var recorded_tiles:Array[Vector2i] = []

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.TERRAIN_DAMAGE]
		trigger_timing = ReactionBus.TIMING.PRE
		consumes_rxn = false

	func triggers_on_event(_unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
		recorded_tiles.append_array(triggering_event.context.target_tiles)
		return false

# ---------------------------------------------------------------- fixture

## Every test places its own units, because the geometry is the test: the same three roles stand
## in different places for a Line, a Cone, a Burst and a size-2 reactor.
func before_each() -> void:
	game = FitzgeraldFixture.create_game(self, Vector2i(20, 12))

func place_enemy(tile:Vector2i = ENEMY_TILE) -> Unit:
	enemy = FitzgeraldFixture.create_dummy(game, tile, ENEMY_EVASION)
	return enemy

func place_ally(tile:Vector2i = ALLY_TILE) -> Unit:
	ally = make_player_unit(tile, ALLY_EVASION)
	return ally

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## A 200 HP, 0 armor player-side character with a chosen evasion - create_dummy's shape, on our side.
func make_player_unit(tile:Vector2i, evasion:int) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.PLAYER)

## The reactor: a player unit carrying the probe on a runtime trait Kit, with one reaction point.
## A dummy frame has stat.reactions 0 and full_repair clamps current.reactions to the max
## (unit_printer.gd:169), so the max is raised on the (already isolated) frame first.
func make_guardian(tile:Vector2i, followup_weapon_id:StringName = &'', evasion:int = GUARDIAN_EVASION) -> Unit:
	guardian = make_player_unit(tile, evasion)
	guardian.core.frame.stat.reactions = 1
	arm_probe(guardian, followup_weapon_id)
	return guardian

## The same probe on a REAL Subutai (size 2), for the tests where the footprint matters.
func make_subutai_guardian(tile:Vector2i) -> Unit:
	guardian = SubutaiFixture.create_subutai(game, tile)
	arm_probe(guardian)
	return guardian

func arm_probe(unit:Unit, followup_weapon_id:StringName = &'') -> void:
	probe = RecentreProbe.new()
	recorder = TerrainRecorder.new()
	var kit := Kit.new()
	kit.compcon_id = &'spike_recentre_kit'
	kit.is_trait = true
	kit.actions.append(probe)
	kit.actions.append(recorder)
	unit.core.loadout.equipped_kits.append(kit)
	if followup_weapon_id != &'':
		probe.counter_weapon = unit.core.equip_system(followup_weapon_id)
	unit.core.full_repair() # regenerates derived gear: the Kit's reactions are indexed by trigger here
	unit.core.current.reactions = 1

func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	return weapon

## Sixty sixes after the one d20 we care about: accuracy dice (prone, cover, inaccurate), damage
## dice and any second d20 all come back 6, so nothing drains the FIFO into real RNG.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Fire a weapon at a UNIT for real and hand back the DeclaredAttackSummary the attack resolved
## through (test_spike_draw_fire.gd's helper).
func fire(shooter:Unit, weapon:GearCore, target:Unit, d20:int) -> DeclaredAttackSummary:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = target,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

## Fire at a TILE (a Blast aims at ground; a Line or Cone aims along a ray).
func fire_at_tile(shooter:Unit, weapon:GearCore, tile:Vector2i, d20:int) -> DeclaredAttackSummary:
	queue_dice(d20)
	var tiles:Array[Vector2i] = [tile]
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

func rolled_against(summary:DeclaredAttackSummary) -> Array[Unit]:
	var targets:Array[Unit] = []
	for roll:AttackRoll in summary.attack_rolls: targets.append(roll.target_unit)
	return targets

# ---------------------------------------------------------------- the verdict

func test_a_single_target_shot_resolves_against_the_reactor_on_the_new_seam() -> void:
	# Spike 3's first test, re-proven on ATTACK_DECLARED PRE: the roll, its evasion and the summary.
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE)
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_ALLY_ONLY)

	assert_eq(summary.attack_rolls.size(), 1, 'One roll: the ally was swapped out, not added to.')
	assert_eq(rolled_against(summary), [guardian], 'The roll was made against the reactor.')
	assert_eq(summary.attack_rolls[0].pre.target_defense, GUARDIAN_EVASION, 'Against the REACTOR\'s evasion.')
	assert_false(summary.attack_rolls[0].hit, 'A 10 that would have hit the ally missed the reactor.')
	assert_eq(summary.directly_attacked_tiles, [GUARDIAN_TILE] as Array[Vector2i], 'The direct target moved.')
	assert_eq(summary.all_attacked_tiles, [GUARDIAN_TILE] as Array[Vector2i], 'The attacked tiles moved.')

func test_a_blast_is_recentred_on_the_reactor() -> void:
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE)
	var beside_ally := FitzgeraldFixture.create_dummy(game, BESIDE_ALLY, ENEMY_EVASION)
	var beside_guardian := FitzgeraldFixture.create_dummy(game, BESIDE_GUARDIAN, ENEMY_EVASION)
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_eq(targets.size(), 2, 'Two rolls: the reactor and the unit beside it.')
	assert_true(targets.has(guardian), 'The reactor is caught.')
	assert_true(targets.has(beside_guardian), 'The bystander beside the reactor is caught.')
	assert_false(targets.has(ally), 'The ally is spared.')
	assert_false(targets.has(beside_ally), 'The bystander beside the ally is spared.')
	assert_eq(summary.directly_attacked_tiles, [GUARDIAN_TILE] as Array[Vector2i], 'The blast is centred on the reactor.')
	assert_true(summary.all_attacked_tiles.has(BESIDE_GUARDIAN), 'The rebuilt area surrounds the reactor.')
	assert_false(summary.all_attacked_tiles.has(ALLY_TILE), 'The rebuilt area no longer covers the ally.')

func test_the_blasts_ground_damage_lands_on_the_new_tiles() -> void:
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE)
	var mortar := arm(enemy, MORTAR)
	await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_false(recorder.recorded_tiles.is_empty(), 'A terrain-damage event was raised at all.')
	assert_true(recorder.recorded_tiles.has(GUARDIAN_TILE), 'The ground under the reactor took the blast.')
	assert_true(recorder.recorded_tiles.has(BESIDE_GUARDIAN), 'And the ground beside it.')
	assert_false(recorder.recorded_tiles.has(ALLY_TILE), 'The ground under the ally did not.')

func test_a_line_that_reaches_the_reactor_is_re_aimed_at_it() -> void:
	# Enemy (2,6), ally moved OFF the ray at (5,4), reactor (9,6): Line 10 aimed at the ally runs
	# north-east; re-aimed at the reactor it runs due east and no longer crosses the ally.
	place_enemy()
	place_ally(ALLY_OFF_RAY)
	make_guardian(GUARDIAN_TILE)
	var lance := arm(enemy, THERMAL_LANCE)
	var summary := await fire_at_tile(enemy, lance, ALLY_OFF_RAY, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [guardian], 'The line was re-aimed at the reactor and catches only it.')
	assert_true(summary.all_attacked_tiles.has(GUARDIAN_TILE), 'The rebuilt line reaches the reactor.')
	assert_false(summary.all_attacked_tiles.has(ALLY_OFF_RAY), 'The rebuilt line no longer crosses the ally.')
	assert_eq(guardian.core.current.reactions, 0, 'The reaction was spent.')

func test_a_line_that_cannot_reach_the_reactor_is_refused() -> void:
	# Line 5 from (2,6) ends at (7,6); the reactor at (9,6) is out of reach, so nothing moves.
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE)
	var pistol := arm(enemy, THERMAL_PISTOL)
	var summary := await fire_at_tile(enemy, pistol, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'The ally is still the one attacked.')
	assert_eq(guardian.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_cone_that_reaches_the_reactor_is_re_aimed_at_it() -> void:
	# Cone 3 from the brawler at (4,6): aimed east at the ally at (6,6) it catches the ally; re-aimed
	# due south at a reactor at (4,9) its rings hold only the tiles nearest that bearing
	# (aoe_calculator.gd:56-58), so the ally at bearing 0 is outside it.
	var brawler := FitzgeraldFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	place_ally(Vector2i(6, 6))
	make_guardian(Vector2i(4, 9))
	var catalyst := arm(brawler, CATALYST_PISTOL)
	var summary := await fire_at_tile(brawler, catalyst, Vector2i(6, 6), D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_true(targets.has(guardian), 'The cone was re-aimed at the reactor.')
	assert_false(targets.has(ally), 'The ally at (6,6) is outside a cone aimed due south at (4,9).')
	assert_eq(guardian.core.current.reactions, 0, 'The reaction was spent.')

func test_a_burst_is_refused() -> void:
	# Burst 1 is centred on the attacker (range_pattern.gd:45-46): there is nothing to re-aim.
	var brawler := FitzgeraldFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	place_ally()
	make_guardian(GUARDIAN_TILE)
	var flechettes := arm(brawler, BRISTLECROWN)
	var summary := await fire(brawler, flechettes, ally, D20_HITS_BOTH)

	assert_true(rolled_against(summary).has(ally), 'The ally is still in the burst.')
	assert_false(rolled_against(summary).has(guardian), 'The reactor was not drawn into it.')
	assert_eq(guardian.core.current.reactions, 1, 'And the reaction was not spent.')

func test_the_follow_up_attack_still_fires_after_a_recentred_blast() -> void:
	# The mortar is Inaccurate, so the cheated 19 lands as 13: the reactor here has the ALLY's
	# evasion so the recentred shot HITS and the damage numbers are real.
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE, RIFLE, ALLY_EVASION)
	var mortar := arm(enemy, MORTAR)
	var enemy_before:int = enemy.core.current.health
	var guardian_before:int = guardian.core.current.health
	await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(guardian_before - guardian.core.current.health, 7, 'The reactor took the 1d6+1 mortar (a six).')
	assert_eq(enemy_before - enemy.core.current.health, 6, 'Then the reactor shot the attacker back (a six beats -10 evasion).')

func test_a_size_two_reactor_is_aimed_at_by_its_nearest_tile() -> void:
	# THE AIM-TILE QUESTION, made concrete. Enemy at (14,6) fires a Line 5 west; a real Subutai
	# anchored at (8,6) occupies (8..9, 6..7), so its near column is at distance 5 and its anchor
	# at distance 6. Aimed at the anchor the line stops one short and the draw is refused; aimed
	# at the nearest occupied tile it reaches. The probe aims at the nearest tile.
	place_enemy(Vector2i(14, 6))
	place_ally(Vector2i(11, 4))
	make_subutai_guardian(Vector2i(8, 6))
	# PRECONDITION, measured the hard way: the map must index the Subutai on all four tiles, or the
	# rebuilt line finds nobody at (9,6). See subutai_fixture.create_subutai.
	assert_true(game.map.get_all_units_at_tile(Vector2i(9, 6)).has(guardian), 'The map indexes the Subutai at its near tile.')
	var pistol := arm(enemy, THERMAL_PISTOL)
	var summary := await fire_at_tile(enemy, pistol, Vector2i(11, 4), D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [guardian], 'The line reaches the Subutai by its nearest tile.')
	assert_eq(summary.directly_attacked_tiles.size(), 1, 'One aim tile.')
	assert_eq(summary.directly_attacked_tiles[0].x, 9, 'Aimed at the near column, not the anchor column.')
	assert_false(summary.all_attacked_tiles.has(Vector2i(11, 4)), 'The ally is spared.')

# ---------------------------------------------------------------- controls

func test_declining_leaves_the_blast_where_it_was() -> void:
	place_enemy()
	place_ally()
	make_guardian(GUARDIAN_TILE)
	SpecFactory.current_responder.chosen_yesnos = false
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Declined: the blast stays where it was declared.')
	assert_eq(guardian.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_attack_already_covering_the_reactor_is_not_drawn() -> void:
	# The reactor stands beside the ally, inside the original Blast 1: nothing to draw.
	place_enemy()
	place_ally()
	make_guardian(BESIDE_ALLY)
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_true(targets.has(ally) and targets.has(guardian), 'Both are hit where they stand.')
	assert_eq(guardian.core.current.reactions, 1, 'The reaction was not offered.')
