# DRAW FIRE (the Siege Engine's reaction, Subutai SP2 Task 3).
#
#   "Reaction, 1/round. Trigger: A hostile character within Range of the Diversion Rail and line of
#    sight makes a ranged attack against an allied character within Sensors. Effect: The attack is
#    made against you instead. After the attack, you may make an attack against the hostile
#    character with the Diversion Rail."
#
# THIS FILE ABSORBS BOTH PROBES. spec/test_spike_draw_fire.gd (Spike 3, 12 tests, the per-target
# ATTACK PRE swap) and spec/test_spike_recentre.gd (SP2 SS2.0, 11 tests, the ATTACK_DECLARED PRE
# rebuild) are DELETED once this is green; their cases live here, against the real .tres instead of
# an inline probe Kit. Do not re-derive anything they measured - read their headers for why each
# case exists.
#
# THE SEAM. event_unit_attack_declared.execute_preblock awaits the ATTACK_DECLARED PRE reactions
# (:21-23) BEFORE execute reads directly_attacked_tiles / all_attacked_tiles (:35-36, the
# on-targeted-tile effects), duplicates all_attacked_units for the per-target rolls (:54) and hands
# all_attacked_tiles to the ground-damage event (:193). Nothing in between copies the summary, so
# rewriting its arrays IN PLACE is seen by every one of them.
#
# RULING 6, AND WHY NO SPEC HERE ASSERTS ON FX: ActionAttack.activate has already run the muzzle and
# target FX (:265) before this event exists, so the tracer plays at the ORIGINAL target while the
# d20, log, damage and damage FX land on the Subutai. Accepted; no content hook precedes it.
#
# THE REACTOR IS A REAL SUBUTAI, which is the one way this file differs from the probes, and it
# changes three numbers they were free to choose:
#  - its evasion is the frame's 6, not a chosen 15, so a MISS is a low d20 and not a high one;
#  - mt_reinforced_chassis takes 1 off every Kinetic and Explosive hit and the frame carries 1 armor,
#    so a 6-damage kinetic rifle lands as 4 on it;
#  - it is SIZE 2, so its aim tile is a real choice (case: the nearest-tile ruling) and every AoE
#    lookup depends on the map indexing all four of its tiles.
#
# EVERY ENEMY SHOT HERE HAPPENS OFF THE SUBUTAI'S TURN, as in real play: make_subutai() presses
# GATHER ROUND on the Subutai's turn and then ENDS that turn. Juggernaut Drive's end-of-turn reaction
# does not fire on the way out - it requires the Subutai to be Immobilized, which it is not unless a
# test fired the Rail first.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_draw_fire.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const CORE_ID := &'cp_siege_engine'
## The Rail is its OWN Kit since 2026-09-15, so the character sheet can title the
## integrated-weapon box "Diversion Rail" rather than "Siege Engine"
## (weapon_mount_item.gd:101 reads the KIT's name). See test_integrated_weapon_names.gd.
const RAIL_KIT_ID := &'mw_diversion_rail'
const RAIL_ID := &'action_diversion_rail'
const DRAW_FIRE_ID := &'action_draw_fire'
const GATHER_ROUND_BUFF := &'buff_gather_round'

## Wide enough for the two range tests, which need a 16-tile gap plus a shooter beyond it.
const MAP_SIZE := Vector2i(30, 20)

## One row, west to east: the enemy shoots east at the ally; the Subutai stands further east.
const ENEMY_TILE := Vector2i(2, 6)
const ALLY_TILE := Vector2i(5, 6)
## A size-2 anchor: the Subutai occupies (9..10, 6..7). Its tile closest to ENEMY_TILE is the anchor
## itself, so every test but the nearest-tile one is indifferent to which tile the rebuild aims at.
const SUBUTAI_TILE := Vector2i(9, 6)
const SUBUTAI_AIM := Vector2i(9, 6)
## Inside a Blast 1 centred on the ally, and inside a Blast 1 centred on SUBUTAI_AIM but OUTSIDE the
## Subutai's own footprint, respectively.
const BESIDE_ALLY := Vector2i(5, 7)
const BESIDE_SUBUTAI := Vector2i(8, 6)
## Off the ray from the enemy to the Subutai: a Line re-aimed at the Subutai no longer crosses it.
const ALLY_OFF_RAY := Vector2i(5, 4)
## ON that re-aimed ray, between the enemy and the Subutai.
const ON_THE_RAY := Vector2i(6, 6)
## Adjacent to the ally, for the Burst and melee controls.
const ADJACENT_TO_ALLY := Vector2i(4, 6)
## 12 from the enemy: past the assault rifle's Range 10, inside the Rail's Range 15.
const FAR_SUBUTAI_TILE := Vector2i(14, 6)
## Adjacent to the ALLY on the enemy's ray to it: hard cover for the ally, nothing for the Subutai
## (cover_calculator.gd:154-156: adjacent raised terrain = HARD).
##
## THE COVER TEST IS RUN FROM THIS SIDE, and the first RED run is why. A one-tall block beside a
## SIZE-2 Subutai gives it no cover at all: cover_calculator.gd:150-153 drops any terrain hit whose
## elevation is not above BOTH ray ends, and a size-2 unit's upper voxel is already level with a
## height-1 block - so that ray comes back clear and the lowest-cover-wins loop returns NONE
## (measured: preview(...).cover was 0 where the probe's size-1 reactor got 2). Raising the block
## higher would start blocking the sightline the trigger needs. Putting the cover on the ALLY instead
## makes the same point the other way round and with the geometry this suite has already proven: the
## roll must come back at the SUBUTAI's cover, which is NONE, and not carry the ally's HARD.
const COVER_TILE := Vector2i(4, 6)

## Vanilla GMS Main Rifle: Range 10, 1d6 kinetic, Reliable 2, no accuracy of its own.
const RIFLE := &'mw_assault_rifle'
## Vanilla GMS melee, threat 1.
const MELEE := &'mw_tactical_melee_weapon'
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
## Vanilla GMS superheavy, Range 15, RELIABLE 5 and Accurate. The only reliable ranged weapon whose
## minimum damage survives the chassis' -1 and the frame's 1 armor as a number a test can see.
const CYCLONE := &'mw_cyclone_pulse_rifle'
## A vanilla TECH attack that is the whole of its Kit, so get_solo_action() finds it
## (test_diversion_rail.gd:53-55).
const TECH := &'ms_fragment_signal'
## Vanilla SSC superheavy launcher: Blast 1, Range 20, Arcing - and the only vanilla weapon that takes
## TWO direct target tiles (target_requirements_override count = 2), which is what the overlapping-
## areas case needs. Its Kit carries two actions (the delayed variant's trigger is the other), so
## get_solo_action() does not reach it and the action is named.
const PINAKA := &'mw_pinaka_missiles'
const PINAKA_ACTION := &'action_pinaka_missiles'
## The Pinaka's SECOND aim tile, chosen so that its Blast 1 (9..10 is the Subutai's column pair)
##  - does NOT overlap the blast aimed at the ally, which the engine's targeting forbids for a
##    multipick AoE, and
##  - does NOT already cover the Subutai's footprint at (9..10, 6..7), which would refuse the draw as
##    an attack already covering us, and yet
##  - DOES overlap the blast once it has been recentred on SUBUTAI_AIM: (8..10, 3..5) against
##    (8..10, 5..7) shares the whole y = 5 row.
const SECOND_AIM := Vector2i(9, 4)

## THE SPLASH GEOMETRY, east-facing (frame close). The blast is AIMED at an allied character 16 tiles
## from the Subutai - outside its Sensors 15, so not an ally this reaction answers for - and SPLASHES
## one at 15, which is. The shooter stands at 10, inside the Rail's Range 15, and outside its own
## Blast 1 so nothing but the two allies is caught.
const EAST_ENEMY_TILE := Vector2i(20, 6)
const ALLY_OUTSIDE_SENSORS := Vector2i(26, 6)
const ALLY_INSIDE_SENSORS := Vector2i(25, 6)

## THE OFF-AXIS LINE GEOMETRY. Every other Line and Cone case in this file re-aims on a compass axis
## ((2,6)->(9,6) east, (14,6)->(9,6) west, (4,6)->(4,9) south); a Subutai anchored here is re-aimed at
## a bearing of about 23 degrees, which is what exercises AoeCalculator.line's per-ring bearing pick
## and the LOS filter (action.gd:273-278) on a diagonal rather than along a row.
const OFF_AXIS_SUBUTAI_TILE := Vector2i(9, 9)
const OFF_AXIS_ALLY_TILE := Vector2i(5, 3)

## The Subutai's own evasion is the frame's, and is NOT settable: SubutaiFixture does not isolate the
## frame, so writing to stat.evasion would reach the shared ContentLibrary copy.
const SUBUTAI_EVASION := 6
## Everything else is -10, which a natural 1 plus a level-0 pilot's grit of 0 already beats. So ONE
## d20 tells the two apart in the other direction from the probes': a 1 hits the ally and misses the
## Subutai.
const ALLY_EVASION := -10
const ENEMY_EVASION := -10
const D20_MISSES_THE_SUBUTAI := 1
const D20_HITS_BOTH := 19 # and never crits

## 1d6 of sixes, less mt_reinforced_chassis' 1 off every Kinetic hit, less the frame's 1 armor.
const RIFLE_DAMAGE_ON_THE_SUBUTAI := 4
## The Cyclone's Reliable 5, through the same two.
const RELIABLE_DAMAGE_ON_THE_SUBUTAI := 3
## The Rail's 1d6 of sixes, AP, into a 0-armor dummy.
const RAIL_DAMAGE := 6

var game:Gamemaster
var enemy:Unit
var ally:Unit
var subutai:Unit
var recorder:TerrainRecorder

# ---------------------------------------------------------------- the terrain probe

## Records the tiles every terrain-damage event was raised against. PORTED VERBATIM from
## test_spike_recentre.gd. A reaction that never fires: it reads the triggering context and refuses,
## so it costs no point and opens no prompt.
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

## Every test places its own units, because the geometry IS the test: the same three roles stand in
## different places for a Line, a Cone, a Burst, a wall and a size-2 footprint.
func before_each() -> void:
	game = SubutaiFixture.create_game(self, MAP_SIZE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func place_enemy(tile:Vector2i = ENEMY_TILE) -> Unit:
	enemy = SubutaiFixture.create_dummy(game, tile, ENEMY_EVASION)
	return enemy

func place_ally(tile:Vector2i = ALLY_TILE) -> Unit:
	ally = make_player_unit(tile, ALLY_EVASION)
	return ally

## A 200 HP, 0 armor player-side character with a chosen evasion - create_dummy's shape, on our side.
func make_player_unit(tile:Vector2i, evasion:int = ALLY_EVASION) -> Unit:
	return SubutaiFixture.create_dummy(game, tile, evasion, Faction.PLAYER)

## The reactor: a real Subutai with GATHER ROUND pressed, its turn then ENDED.
##
## THE PROTOCOL IS THE GATE, not a convenience. action_draw_fire.is_available_to_activate asks
## UnitCondition.has_buff(unit, &'buff_gather_round'), so a Subutai that has not pressed the button
## is never offered the draw - which is what test_without_gather_round_the_ally_is_attacked pins.
func make_subutai(tile:Vector2i = SUBUTAI_TILE) -> Unit:
	await make_subutai_mid_turn(tile)
	await end_subutai_turn()
	return subutai

## The same, with the Subutai's own turn still OPEN: only the test that fires the Rail first needs
## this, and it needs it because the Rail is a QUICK action on the Subutai's own turn.
func make_subutai_mid_turn(tile:Vector2i = SUBUTAI_TILE) -> Unit:
	subutai = SubutaiFixture.create_subutai(game, tile)
	await SubutaiFixture.gather_round(game, subutai)
	assert_true(UnitCondition.has_buff(subutai, GATHER_ROUND_BUFF), 'fixture: GATHER ROUND is up.')
	return subutai

## Without the protocol. The chip is the whole difference.
func make_subutai_without_gather_round(tile:Vector2i = SUBUTAI_TILE) -> Unit:
	subutai = SubutaiFixture.create_subutai(game, tile)
	assert_false(UnitCondition.has_buff(subutai, GATHER_ROUND_BUFF), 'fixture: no chip.')
	return subutai

func end_subutai_turn() -> void:
	await game.execute_event(&'event_turn_end', {unit = subutai})
	# The frame's stat.reactions is 1 and create_subutai's full_repair() already granted it. ASSERTED
	# rather than set, so a frame change shows up here rather than as a silently un-drawable Subutai.
	assert_eq(subutai.core.current.reactions, 1, 'fixture: the Subutai has its one reaction point.')

## The map must index a size-2 Subutai on ALL FOUR of its tiles, or every AoE lookup through
## get_all_units_at_tiles (the whole attack pipeline, action_attack.gd:164) misses it on three of
## them and a Line that reaches its near edge finds nobody there. SubutaiFixture.create_subutai
## re-tracks for exactly this reason; this is the assertion that would notice the line going away.
func assert_map_indexes_the_whole_footprint() -> void:
	for tile:Vector2i in subutai.occupied_tiles():
		assert_true(game.map.get_all_units_at_tile(tile).has(subutai),
			'The map indexes the Subutai at %s.' % tile)

## The ground-damage recorder, on the Subutai's own loadout as a runtime trait Kit (the probe's
## idiom). Installed BEFORE the protocol is pressed, because full_repair() regenerates derived gear -
## which is also where the Kit's reaction gets indexed by trigger.
func install_recorder() -> void:
	recorder = TerrainRecorder.new()
	var kit := Kit.new()
	kit.compcon_id = &'draw_fire_spec_recorder_kit'
	kit.is_trait = true
	kit.actions.append(recorder)
	subutai.core.loadout.equipped_kits.append(kit)
	subutai.core.full_repair()
	UnitTile.update_tracking_and_statuses(game.map)

func rail_gear() -> GearCore:
	return subutai.get_gear(RAIL_KIT_ID)

func rail_action() -> Action:
	var gear:GearCore = rail_gear()
	return gear.get_action(RAIL_ID) if GearCore.is_valid(gear) else null

func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	return weapon

## Sixty sixes after the one d20 we care about: accuracy dice (prone, cover, inaccurate), damage dice
## and any second d20 all come back 6, so nothing drains the FIFO into real RNG.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## The same, with the FIRST d6 forced low. The Cyclone is Accurate, so its one accuracy die is the
## first d6 the attack pops - and at sixes a cheated 1 would still beat the Subutai's evasion 6.
func queue_dice_with_low_accuracy(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = [1]
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Fire a weapon at a UNIT for real and hand back the DeclaredAttackSummary the attack resolved
## through. Built by hand rather than through game.execute_event() because the summary lives on the
## activation event's OWN context, which execute_event does not return.
func fire(shooter:Unit, weapon:GearCore, target:Unit, d20:int) -> DeclaredAttackSummary:
	queue_dice(d20)
	return await fire_pre_queued(shooter, weapon, target)

## The same, taking whatever is already in the cheat queue.
func fire_pre_queued(shooter:Unit, weapon:GearCore, target:Unit) -> DeclaredAttackSummary:
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

## Fire at SEVERAL tiles with a NAMED action - the multipick case, which get_solo_action() cannot
## reach because the Pinaka's Kit carries two actions.
func fire_at_tiles(shooter:Unit, weapon:GearCore, action:Action, tiles:Array[Vector2i], d20:int) -> DeclaredAttackSummary:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = action, gear = weapon, unit = shooter, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

func rolled_against(summary:DeclaredAttackSummary) -> Array[Unit]:
	var targets:Array[Unit] = []
	for roll:AttackRoll in summary.attack_rolls: targets.append(roll.target_unit)
	return targets

## Raise one tile of terrain so it can serve as cover (the test_hole_puncher idiom).
func raise_cover_at(tile:Vector2i) -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 1, [tile])
	game.map.calculate_los_blockers()

## A full-height forbidden-interior column spanning the map north to south at `x`: blocks sight at
## every layer and gives no cover of its own (test_juggernaut_drive.build_wall_at).
func build_wall_at(x:int) -> void:
	var wall:Array[Vector2i] = []
	for y:int in game.map.size.y: wall.append(Vector2i(x, y))
	SpecFactory.add_setpieces_to_landscape(game.get_landscape_node(), &'setpiece_forbidden_interior', wall)
	game.map.calculate_los_blockers()

## What the roll WOULD compute against this target from this shooter, right now - the control for the
## "recomputed against the Subutai" tests, read the way test_hybridized_shot.accuracy_for does.
func preview(shooter:Unit, weapon:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, weapon, weapon.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context)

# ---------------------------------------------------------------- the single-target verdict

func test_the_roll_is_made_against_the_subutai() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_MISSES_THE_SUBUTAI)

	assert_eq(summary.attack_rolls.size(), 1, 'One roll: the ally was swapped out, not added to.')
	assert_eq(rolled_against(summary), [subutai], 'The roll was made against the Subutai.')
	var roll:AttackRoll = summary.attack_rolls[0]
	assert_eq(roll.pre.target_defense, SUBUTAI_EVASION, 'Against the SUBUTAI s evasion.')
	assert_false(roll.hit, 'A 1 that would have hit the ally missed the Subutai.')
	# The summary is what every later reader sees (halve_bonus_damage, attack_declared POST
	# reactions, get_all_hit_units), so it is kept in step too.
	assert_eq(summary.all_attacked_units, [subutai], 'The declared summary names the Subutai.')
	assert_eq(summary.directly_attacked_tiles, [SUBUTAI_AIM] as Array[Vector2i], 'The direct target moved.')
	assert_eq(summary.all_attacked_tiles, [SUBUTAI_AIM] as Array[Vector2i], 'The attacked tiles moved.')

func test_the_damage_lands_on_the_subutai_and_the_ally_is_untouched() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var rifle := arm(enemy, RIFLE)
	var ally_before:int = ally.core.current.health
	var subutai_before:int = subutai.core.current.health
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(subutai_before - subutai.core.current.health, RIFLE_DAMAGE_ON_THE_SUBUTAI,
		'The Subutai took the 1d6 of sixes, less the chassis  1 and its 1 armor.')
	assert_eq(ally.core.current.health, ally_before, 'The ally took nothing.')

func test_reliable_damage_from_a_miss_lands_on_the_subutai_too() -> void:
	# The Cyclone is Accurate, so its accuracy die is forced to 1: at sixes even a natural 1 would
	# clear the Subutai s evasion 6 and there would be no miss to read Reliable off.
	place_enemy()
	place_ally()
	await make_subutai()
	var cyclone := arm(enemy, CYCLONE)
	var ally_before:int = ally.core.current.health
	var subutai_before:int = subutai.core.current.health
	queue_dice_with_low_accuracy(D20_MISSES_THE_SUBUTAI)
	var summary := await fire_pre_queued(enemy, cyclone, ally)

	assert_eq(rolled_against(summary), [subutai], 'The roll was drawn onto the Subutai.')
	assert_false(summary.attack_rolls[0].hit, 'CONTROL: and it missed.')
	assert_eq(subutai_before - subutai.core.current.health, RELIABLE_DAMAGE_ON_THE_SUBUTAI,
		'Reliable 5 on the miss hit the Subutai, less the chassis  1 and its 1 armor.')
	assert_eq(ally.core.current.health, ally_before, 'The ally took nothing.')

func test_the_subutais_own_modifiers_are_applied_to_the_roll() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	SpecFactory.apply(subutai, Lancer.STATUS.PRONE) # +1 accuracy against the Subutai, none vs the ally
	var rifle := arm(enemy, RIFLE)
	assert_eq(preview(enemy, rifle, ally).accuracy_mods_total(), 0, 'CONTROL: nothing modifies a shot at the ally.')
	assert_eq(preview(enemy, rifle, subutai).accuracy_mods_total(), 1, 'CONTROL: Prone is +1 against the Subutai.')

	var summary := await fire(enemy, rifle, ally, D20_MISSES_THE_SUBUTAI)
	assert_eq(summary.attack_rolls[0].pre.accuracy_mods_total(), 1,
		'The roll carried the SUBUTAI s Prone accuracy, not the ally s nothing.')

func test_cover_is_read_from_the_subutais_position() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	raise_cover_at(COVER_TILE)
	var rifle := arm(enemy, RIFLE)
	# The block is one tall and the Subutai is size 2: it can still see over it, so the range-and-
	# sight gate is untouched and the only thing this test moves is the cover on the roll.
	assert_true(UnitRelation.can_see(subutai, enemy), 'fixture: the low block does not blind the Subutai.')
	assert_eq(preview(enemy, rifle, ally).cover, Lancer.COVER.HARD, 'CONTROL: the block is hard cover for the ally.')
	assert_eq(preview(enemy, rifle, subutai).cover, Lancer.COVER.NONE, 'CONTROL: the Subutai stands in the open.')

	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)
	assert_eq(rolled_against(summary), [subutai], 'fixture: the shot was drawn.')
	assert_eq(summary.attack_rolls[0].pre.cover, Lancer.COVER.NONE,
		'The roll took the SUBUTAI s cover, not the ally s HARD.')

func test_the_subutai_is_attacked_even_beyond_the_attackers_weapon_range() -> void:
	# Ruling 4: range and sight are the SUBUTAI s checks on the attacker. The engine never re-checks
	# the attacker s own range against the new target, and that is the card as written.
	place_enemy()
	place_ally()
	await make_subutai(FAR_SUBUTAI_TILE) # 12 from the enemy; the rifle reaches 10
	var rifle := arm(enemy, RIFLE)
	assert_gt(UnitRelation.distance_between(enemy, subutai), 10,
		'fixture: the Subutai is outside the rifle s own Range 10.')
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'The swapped roll is never re-validated for range.')

func test_the_follow_up_rail_shot_lands_on_the_attacker() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var rifle := arm(enemy, RIFLE)
	var enemy_before:int = enemy.core.current.health
	var subutai_before:int = subutai.core.current.health
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(subutai_before - subutai.core.current.health, RIFLE_DAMAGE_ON_THE_SUBUTAI,
		'The Subutai took the drawn shot.')
	assert_eq(enemy_before - enemy.core.current.health, RAIL_DAMAGE,
		'Then the Diversion Rail answered the attacker (a six beats -10 evasion).')

# ---------------------------------------------------------------- ruling 1: the AoE rebuild

func test_a_blast_is_recentred_on_the_subutai() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var beside_ally := SubutaiFixture.create_dummy(game, BESIDE_ALLY, ENEMY_EVASION)
	var beside_subutai := SubutaiFixture.create_dummy(game, BESIDE_SUBUTAI, ENEMY_EVASION)
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_eq(targets.size(), 2, 'Two rolls: the Subutai and the unit beside it.')
	assert_true(targets.has(subutai), 'The Subutai is caught.')
	assert_true(targets.has(beside_subutai), 'The bystander beside the Subutai is caught.')
	assert_false(targets.has(ally), 'The ally is spared.')
	assert_false(targets.has(beside_ally), 'The bystander beside the ally is spared.')
	assert_eq(summary.directly_attacked_tiles, [SUBUTAI_AIM] as Array[Vector2i], 'The blast is centred on the Subutai.')
	assert_true(summary.all_attacked_tiles.has(BESIDE_SUBUTAI), 'The rebuilt area surrounds the Subutai.')
	assert_false(summary.all_attacked_tiles.has(ALLY_TILE), 'The rebuilt area no longer covers the ally.')
	# THE COVER AND KNOCKBACK ORIGIN, and nothing else in this file discriminates it (frame close,
	# 2026-09-15: deleting the reaction's source_voxels assignment left the whole suite GREEN). A
	# Blast's origin is its CENTRE, not the firer (action_attack.gd:179-185, the BLAST branch at
	# :181-184), and the summary's source_voxels are read twice downstream: attack_roll.gd:118-119
	# copies them into PreAttack.create, which hands them to CoverCalculator.determine_cover (:158),
	# and action_attack_weapon.gd:337-343 makes Tile.from_voxels(source_voxels) the knockback origin.
	# test_cover_is_read_from_the_subutais_position cannot see any of that: it fires a RIFLE, and
	# get_origin_voxels returns the attacker's OWN voxels for every non-Blast shape (:185), so it
	# exercises the no-op path. A recentred Blast is the only case where the line does work.
	assert_eq(Tile.from_voxels(summary.source_voxels), [SUBUTAI_AIM] as Array[Vector2i],
		'The blast s cover and knockback origin moved to the Subutai with it.')

func test_the_blasts_ground_damage_lands_on_the_new_tiles() -> void:
	place_enemy()
	place_ally()
	subutai = SubutaiFixture.create_subutai(game, SUBUTAI_TILE)
	install_recorder()
	await SubutaiFixture.gather_round(game, subutai)
	# make_subutai()'s own assertion, restored by hand: the fixture is inlined here only to get the
	# recorder installed BEFORE the protocol is pressed, and inlining it dropped the one check that
	# the protocol actually landed - without which this test would read the same if it had not.
	assert_true(UnitCondition.has_buff(subutai, GATHER_ROUND_BUFF), 'fixture: GATHER ROUND is up.')
	await end_subutai_turn()
	var mortar := arm(enemy, MORTAR)
	await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_false(recorder.recorded_tiles.is_empty(), 'A terrain-damage event was raised at all.')
	assert_true(recorder.recorded_tiles.has(SUBUTAI_AIM), 'The ground under the Subutai took the blast.')
	assert_true(recorder.recorded_tiles.has(BESIDE_SUBUTAI), 'And the ground beside it.')
	assert_false(recorder.recorded_tiles.has(ALLY_TILE), 'The ground under the ally did not.')

func test_a_line_that_reaches_the_subutai_is_re_aimed_at_it() -> void:
	# Enemy (2,6), ally moved OFF the ray at (5,4), Subutai (9,6): Line 10 aimed at the ally runs
	# north-east; re-aimed at the Subutai it runs due east and no longer crosses the ally.
	place_enemy()
	place_ally(ALLY_OFF_RAY)
	await make_subutai()
	var lance := arm(enemy, THERMAL_LANCE)
	var summary := await fire_at_tile(enemy, lance, ALLY_OFF_RAY, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'The line was re-aimed at the Subutai and catches only it.')
	assert_true(summary.all_attacked_tiles.has(SUBUTAI_AIM), 'The rebuilt line reaches the Subutai.')
	assert_false(summary.all_attacked_tiles.has(ALLY_OFF_RAY), 'The rebuilt line no longer crosses the ally.')
	assert_eq(subutai.core.current.reactions, 0, 'The reaction was spent.')

func test_a_line_that_cannot_reach_the_subutai_is_refused() -> void:
	# Line 5 from (2,6) ends at (7,6); the Subutai's near column at (9,6) is out of reach, so nothing
	# moves. Ruling 2: one code path - the rebuild, run dry, returning false.
	place_enemy()
	place_ally()
	await make_subutai()
	var pistol := arm(enemy, THERMAL_PISTOL)
	var summary := await fire_at_tile(enemy, pistol, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'The ally is still the one attacked.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_off_axis_line_is_re_aimed_at_the_subutai() -> void:
	# THE ONLY NON-COMPASS GEOMETRY IN THE FILE, added at the frame close. Enemy (2,6), ally off the
	# ray at (5,3) to the north-east, Subutai anchored at (9,9) to the south-east: the line is aimed
	# up-right and re-aimed down-right, at a bearing no other case here uses. Draw Fire derives the
	# line exactly once - it hands new_targets to the attacker's own get_aoe_tiles_with_targets - so
	# there is no second derivation to disagree with the first the way Juggernaut Drive's pathfinder
	# does (SP1's off-axis measurement); what this case exercises that the axis cases do not is
	# AoeCalculator.line's per-ring bearing pick and the LOS filter on a diagonal.
	#
	# NO TILE IS ASSERTED BY NAME. The Subutai's four tiles tie on Chebyshev distance from (2,6) and
	# the aim tile falls out of the engine's own tiebreak, which test_a_size_two_subutai_is_aimed_at_
	# by_its_nearest_tile already pins on a geometry where it is unambiguous. Here the claim is the
	# card's: the shot comes to the Subutai and leaves the ally.
	place_enemy()
	place_ally(OFF_AXIS_ALLY_TILE)
	await make_subutai(OFF_AXIS_SUBUTAI_TILE)
	assert_map_indexes_the_whole_footprint()
	var lance := arm(enemy, THERMAL_LANCE)
	var summary := await fire_at_tile(enemy, lance, OFF_AXIS_ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'The off-axis line was re-aimed onto the Subutai.')
	assert_false(summary.all_attacked_tiles.has(OFF_AXIS_ALLY_TILE), 'And no longer crosses the ally.')
	assert_eq(subutai.core.current.reactions, 0, 'The reaction was spent.')

func test_a_cone_that_reaches_the_subutai_is_re_aimed_at_it() -> void:
	# Cone 3 from the brawler at (4,6): aimed east at the ally at (6,6) it catches the ally; re-aimed
	# due south at a Subutai anchored at (4,9) its rings hold only the tiles nearest that bearing
	# (aoe_calculator.gd:56-58), so the ally at bearing 0 is outside it.
	var brawler := SubutaiFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	enemy = brawler
	place_ally(Vector2i(6, 6))
	await make_subutai(Vector2i(4, 9))
	var catalyst := arm(brawler, CATALYST_PISTOL)
	var summary := await fire_at_tile(brawler, catalyst, Vector2i(6, 6), D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_true(targets.has(subutai), 'The cone was re-aimed at the Subutai.')
	assert_false(targets.has(ally), 'The ally at (6,6) is outside a cone aimed due south.')
	assert_eq(subutai.core.current.reactions, 0, 'The reaction was spent.')

func test_a_burst_is_refused() -> void:
	# Ruling 2: Burst 1 is centred on the ATTACKER (range_pattern.gd:45-46), so there is nothing to
	# re-aim and the draw is refused outright rather than half-applied.
	#
	# THE OUTCOME IS OVER-DETERMINED, and no geometry can change that (mutation 6, 2026-09-15:
	# deleting the reaction's explicit BURST line reddened nothing). A Burst that misses the Subutai
	# rebuilds to an area still centred on the attacker and is refused by the generic "would the
	# rebuilt area contain us" check; a Burst that catches the Subutai is refused earlier still, as
	# an attack already covering it. This test pins the BEHAVIOUR - a Burst is never drawn - and not
	# which of the two gates refused it.
	var brawler := SubutaiFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	enemy = brawler
	place_ally()
	await make_subutai()
	var flechettes := arm(brawler, BRISTLECROWN)
	var summary := await fire(brawler, flechettes, ally, D20_HITS_BOTH)

	assert_true(rolled_against(summary).has(ally), 'The ally is still in the burst.')
	assert_false(rolled_against(summary).has(subutai), 'The Subutai was not drawn into it.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_size_two_subutai_is_aimed_at_by_its_nearest_tile() -> void:
	# THE AIM-TILE RULING, made concrete. Enemy at (14,6) fires a Line 5 west; a Subutai anchored at
	# (8,6) occupies (8..9, 6..7), so its near column is at distance 5 and its anchor at distance 6.
	# Aimed at the anchor the line stops one short and the draw is refused; aimed at the nearest
	# occupied tile it reaches. The reaction aims at the nearest tile.
	place_enemy(Vector2i(14, 6))
	place_ally(Vector2i(11, 4))
	await make_subutai(Vector2i(8, 6))
	# THE PRECONDITION FIRST, measured the hard way: without the map indexing all four tiles the
	# rebuilt line finds nobody at (9,6) and this reads as the ruling being wrong.
	assert_map_indexes_the_whole_footprint()
	var pistol := arm(enemy, THERMAL_PISTOL)
	var summary := await fire_at_tile(enemy, pistol, Vector2i(11, 4), D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'The line reaches the Subutai by its nearest tile.')
	assert_eq(summary.directly_attacked_tiles.size(), 1, 'One aim tile.')
	assert_eq(summary.directly_attacked_tiles[0].x, 9, 'Aimed at the near column, not the anchor column.')
	assert_false(summary.all_attacked_tiles.has(Vector2i(11, 4)), 'The ally is spared.')

func test_two_overlapping_blasts_do_not_double_up_the_attacked_tiles() -> void:
	# THE REBUILD IS THE ONE THING IN THE GAME THAT ROUTINELY MAKES AOE AREAS OVERLAP: it drags one
	# direct target onto our aim tile and leaves the others where they were. Vanilla appends its AoE
	# tiles NON-DUPLICATE (action_attack.gd:165-166), and the rebuild does the same.
	#
	# IT DOES NOT DISCRIMINATE THAT LINE, and that is worth knowing before trusting it as a regression
	# pin: the SP2 review expected duplicates without it, but get_aoe_tiles already ends in
	# filter_valid_aoe_tiles -> Util.filter_and_remove_duplicates (range_pattern.gd:79-80), so the
	# array is unique before the rebuild touches it (mutation, 2026-09-15: assigning it straight to
	# new_tiles left this test GREEN). What this test pins is the BEHAVIOUR - an overlapping rebuilt
	# area hands event_map_damage each tile once - across whichever layer happens to provide it.
	place_enemy()
	place_ally()
	await make_subutai()
	var pinaka := arm(enemy, PINAKA)
	var action:Action = pinaka.get_action(PINAKA_ACTION)
	assert_not_null(action, 'fixture: the Pinaka s own attack action, named past its Kit s two.')
	if action == null: return
	var aim:Array[Vector2i] = [ALLY_TILE, SECOND_AIM]
	var summary := await fire_at_tiles(enemy, pinaka, action, aim, D20_HITS_BOTH)

	assert_true(summary.directly_attacked_tiles.has(SUBUTAI_AIM), 'The ally s blast was recentred on us.')
	assert_true(summary.directly_attacked_tiles.has(SECOND_AIM), 'The other blast stayed where it was aimed.')
	# THE VACUITY GUARD: both 3x3s really are in the rebuilt area, and they really do share the y = 5
	# row - so without the dedupe there would be duplicates to find.
	for tile:Vector2i in [Vector2i(9, 7), Vector2i(9, 3), Vector2i(9, 5), Vector2i(8, 5), Vector2i(10, 5)]:
		assert_true(summary.all_attacked_tiles.has(tile), 'The rebuilt area covers %s.' % tile)
	var seen := {}
	for tile:Vector2i in summary.all_attacked_tiles: seen[tile] = true
	assert_eq(summary.all_attacked_tiles.size(), seen.size(),
		'No tile appears twice: the rebuild keeps vanilla s non-duplicate append.')

func test_an_ally_on_the_re_aimed_ray_is_still_caught() -> void:
	# RECORDED BEHAVIOUR, NOT A FAILED DRAW. The shot IS made against the Subutai; whatever stands
	# between the attacker and the Subutai is inside the rebuilt area, ally or not. The line here is
	# re-aimed from (5,4) onto the Subutai's row and sweeps the ally standing at (6,6) on the way.
	place_enemy()
	place_ally(ALLY_OFF_RAY)
	var on_the_ray := make_player_unit(ON_THE_RAY)
	await make_subutai()
	var lance := arm(enemy, THERMAL_LANCE)
	var summary := await fire_at_tile(enemy, lance, ALLY_OFF_RAY, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_true(targets.has(subutai), 'The shot was drawn onto the Subutai.')
	assert_true(targets.has(on_the_ray), 'And the ally standing on the re-aimed ray is caught with it.')
	assert_false(targets.has(ally), 'The originally targeted ally is off the new ray, and spared.')

# ---------------------------------------------------------------- the splash case (frame close)
#
# AIMED AT vs CAUGHT BY, and the two were out of step until the frame close. The trigger's ally gate
# reads summary.all_attacked_units, which includes SPLASHED units; the rebuild's step 1 only moved a
# direct target tile an allied character was STANDING on. When an AoE is aimed at something that is
# not an in-Sensors allied character but splashes one, nothing moved, the rebuilt area came back
# unchanged, the dry rebuild returned false and Draw Fire was silently never offered - no point spent,
# no wrong roll, the capability simply absent. Step 1a re-aims the direct target nearest an ally when
# step 1 moves nothing; the two cases below are the AI-driven ways in.

func test_a_blast_aimed_at_a_friendly_deployable_that_splashes_an_ally_is_drawn() -> void:
	# THE ROUTINE CASE, not an exotic one: several NPC behaviours weight player deployables positively
	# as blast targets (npcc_demolisher's action_seismic_destroyer_demolisher.tres sets
	# weight_deployables = 1.25), so a mortar aimed at a Jericho with a mech beside it is ordinary AI
	# play. The deployable is an ALLY but not a CHARACTER, so allies_under_fire excludes it and the
	# only tile the blast is aimed at belongs to nobody this reaction answers for.
	place_enemy()
	var cover := SubutaiFixture.create_allied_deployable(game, ALLY_TILE)
	place_ally(BESIDE_ALLY)
	await make_subutai()
	assert_false(cover.is_character(), 'fixture: the deployable is not a character.')
	assert_true(UnitRelation.are_allies(subutai, cover), 'fixture: but it is on our side.')
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_eq(targets, [subutai], 'The blast was drawn off the deployable and onto the Subutai.')
	assert_false(targets.has(ally), 'The splashed ally is spared.')
	assert_eq(summary.directly_attacked_tiles, [SUBUTAI_AIM] as Array[Vector2i],
		'And the blast is centred on the Subutai, not still on the deployable.')
	assert_eq(subutai.core.current.reactions, 0, 'The reaction was spent.')

func test_a_blast_aimed_outside_sensors_that_splashes_an_ally_inside_them_is_drawn() -> void:
	# THE SAME DEFECT FROM THE OTHER DIRECTION: the aimed-at unit IS an allied character, but it is 16
	# tiles away and allies_under_fire drops it at the Sensors line - so again no direct target tile
	# belongs to an ally this reaction answers for, while the splashed ally at 15 does.
	#
	# THE AIM TILE IS NOT ASSERTED BY NAME: the shooter is east of the Subutai and its two east tiles
	# tie on Chebyshev, where every other case in this file shoots from the west. That the re-aim
	# lands on one of the four is the whole claim.
	place_enemy(EAST_ENEMY_TILE)
	var far_ally := make_player_unit(ALLY_OUTSIDE_SENSORS)
	place_ally(ALLY_INSIDE_SENSORS)
	await make_subutai()
	assert_eq(UnitRelation.distance_between(subutai, far_ally), 16, 'fixture: the aimed-at ally is outside Sensors 15.')
	assert_eq(UnitRelation.distance_between(subutai, ally), 15, 'fixture: the splashed ally is inside them.')
	assert_true(UnitRelation.distance_between(subutai, enemy) <= 15, 'fixture: and the shooter is inside the Rail s range.')
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_OUTSIDE_SENSORS, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_eq(targets, [subutai], 'The blast was drawn onto the Subutai.')
	assert_false(targets.has(far_ally), 'The ally it was aimed at is spared.')
	assert_false(targets.has(ally), 'And so is the one it splashed.')
	assert_eq(summary.directly_attacked_tiles.size(), 1, 'One aim tile.')
	assert_true(subutai.occupied_tiles().has(summary.directly_attacked_tiles[0]),
		'Centred on one of the Subutai s own tiles.')
	assert_eq(subutai.core.current.reactions, 0, 'The reaction was spent.')

# ---------------------------------------------------------------- the reaction economy

func test_the_protocol_spends_the_core_power() -> void:
	# The only thing that makes the whole reaction cost anything at all.
	place_enemy()
	place_ally()
	subutai = SubutaiFixture.create_subutai(game, SUBUTAI_TILE)
	assert_true(subutai.core.has_core_power, 'CONTROL: the core power is up beforehand.')
	await SubutaiFixture.gather_round(game, subutai)
	assert_false(subutai.core.has_core_power, 'GATHER ROUND spent it.')

func test_it_spends_the_reaction_point() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var rifle := arm(enemy, RIFLE)
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(subutai.core.current.reactions, 0, 'A real reaction: the point is gone.')

func test_without_a_reaction_point_the_ally_is_attacked() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	subutai.core.current.reactions = 0
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'No reaction, no draw.')

func test_declining_the_prompt_leaves_the_ally_attacked_and_keeps_the_point() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	SpecFactory.current_responder.chosen_yesnos = false
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Declined: the attack stays where it was declared.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_declining_leaves_the_blast_where_it_was() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	SpecFactory.current_responder.chosen_yesnos = false
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Declined: the blast stays where it was declared.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_without_gather_round_the_ally_is_attacked() -> void:
	# The protocol IS the gate: is_available_to_activate asks for buff_gather_round by id.
	place_enemy()
	place_ally()
	make_subutai_without_gather_round()
	assert_eq(subutai.core.current.reactions, 1, 'fixture: it has a point to spend, and does not.')
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'No protocol, no draw.')
	assert_eq(subutai.core.current.reactions, 1, 'And the point is still there.')

func test_two_draws_in_one_round_are_refused() -> void:
	# Ruling 3: the engine's per-round hard limit BY USAGE GROUP, which is stricter than the reaction
	# point - the point refreshes at every turn start, the round counter does not. The second enemy's
	# turn is opened between the two shots precisely so the refusal cannot be a missing point: the
	# assertion below pins that it is there. Grep the run output for PER_ROUND as corroboration.
	place_enemy()
	place_ally()
	var enemy_b := SubutaiFixture.create_dummy(game, Vector2i(2, 9), ENEMY_EVASION)
	var ally_b := make_player_unit(Vector2i(5, 9))
	await make_subutai()
	var rifle_a := arm(enemy, RIFLE)
	var rifle_b := arm(enemy_b, RIFLE)

	var first := await fire(enemy, rifle_a, ally, D20_HITS_BOTH)
	assert_eq(rolled_against(first), [subutai], 'The first shot was drawn.')

	await SubutaiFixture.open_turn(game, enemy_b)
	assert_eq(subutai.core.current.reactions, 1, 'The reaction point came back at the turn start.')
	# AND EVERY OTHER GATE IS OPEN for the second pair, so the refusal can only be the round counter.
	assert_true(UnitRelation.can_see(subutai, enemy_b), 'fixture: the second attacker is in sight.')
	assert_true(UnitRelation.distance_between(subutai, enemy_b) <= rail_action().get_target_range(
		SpecificAction.create(subutai, rail_gear(), rail_action())),
		'fixture: and inside the Rail s range.')
	assert_true(UnitRelation.distance_between(subutai, ally_b) <= subutai.get_sensor_range(),
		'fixture: the second ally is inside the Subutai s sensors.')
	var second := await fire(enemy_b, rifle_b, ally_b, D20_HITS_BOTH)
	assert_eq(rolled_against(second), [ally_b], 'The second is refused: one draw per round.')

func test_a_draw_is_available_again_after_the_subutais_own_turn() -> void:
	# WHAT THE ENGINE DOES, NOT WHAT THE CARD SAYS, and the reaction's header now says so too. The
	# per-round counter is cleared by UnitAction.new_turn_refresh -> reset_per_round_usage
	# (unit_action.gd:75-78, :87-88), which runs only at the SUBUTAI'S OWN turn start, while the
	# reaction POINT refreshes at every unit's turn start (every_new_turn_refresh, :67-70). So "1/round"
	# is really "once since my last turn start": a draw is available once per enemy phase on either
	# side of the Subutai's turn, and two draws can land inside one game round. Every vanilla 1/round
	# reaction shares the property; this is a PIN on it, not an endorsement of it -
	# test_two_draws_in_one_round_are_refused pins the other half, that the counter does bind within
	# one enemy phase.
	place_enemy()
	place_ally()
	var enemy_b := SubutaiFixture.create_dummy(game, Vector2i(2, 9), ENEMY_EVASION)
	var ally_b := make_player_unit(Vector2i(5, 9))
	await make_subutai()
	var rifle_a := arm(enemy, RIFLE)
	var rifle_b := arm(enemy_b, RIFLE)

	var first := await fire(enemy, rifle_a, ally, D20_HITS_BOTH)
	assert_eq(rolled_against(first), [subutai], 'The first shot was drawn.')

	# The Subutai's OWN turn, opened and ended: this, and only this, clears uses_this_round.
	await SubutaiFixture.open_turn(game, subutai)
	await end_subutai_turn()

	await SubutaiFixture.open_turn(game, enemy_b)
	assert_eq(subutai.core.current.reactions, 1, 'The reaction point is there for the second shot.')
	var second := await fire(enemy_b, rifle_b, ally_b, D20_HITS_BOTH)
	assert_eq(rolled_against(second), [subutai],
		'Drawn again: the per-round counter cleared at the Subutai s own turn start.')
	assert_eq(subutai.core.current.reactions, 0, 'And the second point was spent.')

func test_a_second_subutai_cannot_redraw_an_attack_already_drawn() -> void:
	# A DECLARED ATTACK MAY BE DRAWN ONCE. Every reaction's gate is evaluated before any body runs, so
	# two Subutais watching the same shot are both queued; the first to activate stamps the summary and
	# the second aborts WITHOUT spending. The allies re-check cannot do this job - after the first draw
	# all_attacked_units is [Subutai A], and A is an allied character inside B's sensors, so B's
	# allies_under_fire is non-empty and B would redraw the attack onto itself.
	place_enemy()
	place_ally()
	await make_subutai()
	var first_subutai := subutai
	var second_subutai := SubutaiFixture.create_subutai(game, Vector2i(9, 10))
	await SubutaiFixture.gather_round(game, second_subutai)
	assert_true(UnitCondition.has_buff(second_subutai, GATHER_ROUND_BUFF), 'fixture: the second Subutai pressed it too.')
	await game.execute_event(&'event_turn_end', {unit = second_subutai})
	assert_eq(second_subutai.core.current.reactions, 1, 'fixture: and it has its own point.')
	assert_eq(first_subutai.core.current.reactions, 1, 'fixture: so does the first.')

	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(summary.attack_rolls.size(), 1, 'One roll: the shot was drawn once, not twice.')
	var drawn := rolled_against(summary)
	assert_false(drawn.has(ally), 'It was drawn off the ally.')
	assert_true(drawn.has(first_subutai) or drawn.has(second_subutai), 'Onto ONE of the two Subutais.')
	var spent:int = (1 - first_subutai.core.current.reactions) + (1 - second_subutai.core.current.reactions)
	assert_eq(spent, 1, 'Exactly one reaction point went: the other aborted without spending.')

func test_firing_the_rail_does_not_spend_the_draw() -> void:
	# PINS THE BEHAVIOUR, NOT THE MECHANISM. A Rail shot fired on an earlier turn leaves the draw
	# available on the turn that follows. That holds today because the protocol and the Rail each
	# carry their OWN usage_group (cf56dfc) - so nothing on this Kit still falls into the default
	# cp_siege_engine group Draw Fire's own group would otherwise collide with. Consequence, checked
	# by hand rather than by this test: deleting &'action_draw_fire' from the .tres would NOT redden
	# this test - the fallback group now collides with nothing here either. That field's VALUE is
	# guarded elsewhere, by test_the_reaction_is_on_the_core_kit; its EFFECT (actually preventing a
	# collision) is currently unguarded by any spec, because there is nothing left on the Kit for it
	# to collide with.
	#
	# THE RAIL IS STILL FIRED ON A SECOND TURN, so the per-ROUND counter this test is about is
	# provably the draw's own and not an artefact of a fresh turn. The protocol and the Rail now
	# carry their own usage_group too (review fix, test_diversion_rail.test_the_rail_fires_on_the_
	# turn_gather_round_is_pressed), so the same-turn per-TURN refusal the first RED run of this file
	# hit ("specific: invalid", no reason line, measured 2026-09-15) no longer happens; a fresh turn
	# here is just this test's own setup, not a workaround for it.
	place_enemy()
	place_ally()
	await make_subutai()
	await SubutaiFixture.open_turn(game, subutai)
	queue_dice(D20_HITS_BOTH)
	var shot := EventCore.create(&'event_gear_activate', {
		action = rail_action(), gear = rail_gear(), unit = subutai, target_unit = enemy,
	})
	var shots:Array[EventCore] = [shot]
	await game.execute_event_block(EventBlock.create_multiple(shots))
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'fixture: the Rail really did fire (its on-attack drawback landed).')
	await end_subutai_turn()

	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)
	assert_eq(rolled_against(summary), [subutai], 'The draw is still available: the Rail has its own usage group.')

# ---------------------------------------------------------------- the trigger's gates

func test_a_melee_attack_is_not_drawn() -> void:
	place_enemy()
	place_ally()
	await make_subutai()
	var brawler := SubutaiFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	var blade := arm(brawler, MELEE)
	var summary := await fire(brawler, blade, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'The card says ranged; a melee swing is left alone.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_tech_attack_is_not_drawn() -> void:
	# UnitAction.is_ranged_weapon is false for a tech attack, whatever its range.
	place_enemy()
	place_ally()
	await make_subutai()
	var invade := arm(enemy, TECH)
	var summary := await fire(enemy, invade, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'A tech attack is not a ranged weapon attack.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_attack_already_covering_the_subutai_is_not_drawn() -> void:
	# The Subutai stands beside the ally, inside the original Blast 1: nothing to draw.
	place_enemy()
	place_ally()
	await make_subutai(BESIDE_ALLY)
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_true(targets.has(ally) and targets.has(subutai), 'Both are hit where they stand.')
	assert_eq(subutai.core.current.reactions, 1, 'The reaction was not offered.')

func test_an_attacker_beyond_the_rails_range_cannot_be_drawn() -> void:
	# "within Range of the Diversion Rail" - 16 tiles, against a Range 15 weapon.
	place_enemy(Vector2i(26, 6))
	place_ally(Vector2i(21, 6))
	await make_subutai()
	assert_eq(UnitRelation.distance_between(subutai, enemy), 16, 'fixture: one tile past Range 15.')
	assert_true(UnitRelation.can_see(subutai, enemy), 'fixture: and plainly visible, so range is the only gate.')
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Out of the Rail s reach: no draw.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_attacker_behind_a_wall_cannot_be_drawn() -> void:
	# "and line of sight". Both the attacker and its victim stand east of the wall, so the shot
	# itself is unobstructed and the only thing that changed is what the SUBUTAI can see.
	place_enemy(Vector2i(20, 6))
	place_ally(Vector2i(18, 6))
	await make_subutai()
	build_wall_at(15)
	assert_false(UnitRelation.can_see(subutai, enemy), 'fixture: the wall blocks sight to the attacker.')
	assert_true(UnitRelation.distance_between(subutai, enemy) <= 15, 'fixture: and it is well inside Range 15.')
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Unseen attacker: no draw.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_ally_beyond_the_subutais_sensors_cannot_be_drawn_for() -> void:
	# "against an allied character within Sensors" - 16 tiles, against sensors 15.
	place_enemy(Vector2i(25, 6))
	place_ally(Vector2i(26, 6))
	await make_subutai()
	assert_eq(subutai.get_sensor_range(), 15, 'fixture: the frame s sensors.')
	assert_eq(UnitRelation.distance_between(subutai, ally), 16, 'fixture: the ally is one tile outside them.')
	assert_eq(UnitRelation.distance_between(subutai, enemy), 15, 'fixture: the ATTACKER is inside the Rail s range.')
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Out of sensors: not an ally this reaction answers for.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

# ---------------------------------------------------------------- who may shoot, and at whom
#
# FOUR IDENTITY FILTERS, ONE TEST EACH, added at the frame close because each was deletable with the
# whole suite green. They are written so that no two of them redden together: the attacker cases use
# an attacker the other filter does not object to, and the victim cases use a victim the other filter
# lets through.

func test_a_teammates_friendly_fire_is_not_drawn() -> void:
	# "A HOSTILE character". Without the are_enemies check the Subutai answers its own side's stray
	# shot by pulling it onto itself - and then, because the follow-up is unconditional, Rails the
	# teammate that fired. Friendly fire is a live engine concept, not a hypothetical: ActionAttack
	# stops to confirm it (action_attack.gd:247, TargetActionUtil.confirm_friendly_fire).
	var teammate := make_player_unit(ENEMY_TILE)
	place_ally()
	await make_subutai()
	# The shooter's own turn is opened, unlike every enemy case in this file: a player unit firing on
	# its turn is the only way this shot happens in play, and confirm_friendly_fire only asks anything
	# of a player-controlled attacker (target_action_util.gd:431). The spec responder answers it yes.
	await SubutaiFixture.open_turn(game, teammate)
	assert_false(UnitRelation.are_enemies(subutai, teammate), 'fixture: the shooter is on our side.')
	assert_true(UnitRelation.can_see(subutai, teammate), 'fixture: and is in sight, inside the Rail s range.')
	var rifle := arm(teammate, RIFLE)
	var summary := await fire(teammate, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'The card says HOSTILE: a teammate s shot is left alone.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_unowned_hostile_deployables_shot_is_not_drawn() -> void:
	# "A hostile CHARACTER". test_a_hostile_drones_shot_is_drawn_and_the_rail_answers_its_owner does
	# NOT pin this: its drone has an OWNER, so get_attacker() hands back a character and the check
	# passes either way. An ownerless deployable answers for itself (unit.gd:276-282 falls through to
	# get_owner_unit_or_self, which returns `self`), so it is the case where the filter is the only
	# thing standing between the card's wording and a draw.
	place_ally()
	await make_subutai()
	var turret := FitzgeraldFixture.create_deployable(game, Vector2i(4, 7), 20, 0, ENEMY_EVASION)
	enemy = turret
	assert_false(turret.is_character(), 'fixture: a deployable is not a character.')
	assert_eq(turret.get_attacker(), turret, 'fixture: and with no owner it answers for itself.')
	var rifle := arm(turret, RIFLE)
	var summary := await fire(turret, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'No character pulled that trigger: no draw.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_blast_that_catches_only_a_friendly_deployable_is_not_drawn() -> void:
	# "against an allied CHARACTER", and the control that makes the splash case above mean something.
	# Without the is_character filter on the victim side the Subutai draws attacks aimed at its own
	# turrets and cover - and, since the frame close, step 1a would re-aim them onto it as well.
	place_enemy()
	var cover := SubutaiFixture.create_allied_deployable(game, ALLY_TILE)
	await make_subutai()
	assert_true(UnitRelation.are_allies(subutai, cover), 'fixture: the deployable is ours.')
	assert_false(cover.is_character(), 'fixture: and it is not a character.')
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [cover], 'The deployable eats it: a deployable is not an allied character.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_an_attack_on_another_hostile_is_not_drawn() -> void:
	# "against an ALLIED character". Without the are_allies filter every character caught by the shot
	# counts, and the Subutai would step in front of one enemy shooting another.
	place_enemy()
	var victim := SubutaiFixture.create_dummy(game, ALLY_TILE, ENEMY_EVASION)
	await make_subutai()
	assert_true(victim.is_character(), 'fixture: the victim IS a character, so only are_allies can refuse it.')
	assert_false(UnitRelation.are_allies(subutai, victim), 'fixture: and it is not ours.')
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, victim, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [victim], 'Nobody allied is under fire: no draw.')
	assert_eq(subutai.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_hostile_drones_shot_is_drawn_and_the_rail_answers_its_owner() -> void:
	# Ruling 5: "a hostile CHARACTER". A deployable is not one, so the trigger asks
	# triggering_context.unit.get_attacker() - which resolves a deployable to its owner - and the
	# follow-up shot goes to the OWNER, not to the thing that pulled the trigger.
	place_enemy()
	place_ally()
	await make_subutai()
	var drone := FitzgeraldFixture.create_deployable(game, Vector2i(4, 7), 20, 0, ENEMY_EVASION)
	drone.state.set_owner(enemy)
	assert_false(drone.is_character(), 'fixture: the drone is not a character.')
	assert_eq(drone.get_attacker(), enemy, 'fixture: its attacks are its owner s.')
	var rifle := arm(drone, RIFLE)
	var enemy_before:int = enemy.core.current.health
	var drone_before:int = drone.core.current.health
	var summary := await fire(drone, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'The drone s shot was drawn onto the Subutai.')
	assert_eq(enemy_before - enemy.core.current.health, RAIL_DAMAGE, 'The Rail answered the OWNER.')
	assert_eq(drone.core.current.health, drone_before, 'And not the drone that fired.')

func test_the_follow_up_immobilizes_the_subutai() -> void:
	# The Rail's own on-attack drawback fires on the follow-up as on any shot, and it is
	# START_OF_TURN - so it must survive the whole of the enemy turn it was applied during and clear
	# only at the Subutai's own next turn start.
	place_enemy()
	place_ally()
	await make_subutai()
	await SubutaiFixture.open_turn(game, enemy)
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [subutai], 'fixture: the draw happened, so the Rail fired.')
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'The follow-up shot immobilized the Subutai, on the enemy s turn.')
	await game.execute_event(&'event_turn_end', {unit = enemy})
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'Still there at that enemy turn s end.')
	await SubutaiFixture.open_turn(game, subutai)
	assert_false(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'Cleared at the start of the Subutai s next turn.')

# ---------------------------------------------------------------- localisation and wiring

func test_the_reaction_is_on_the_core_kit():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), 'cp_siege_engine loads.')
	if not Kit.is_valid(kit): return
	var action:Action = kit.get_action(DRAW_FIRE_ID)
	assert_not_null(action, 'The Kit carries action_draw_fire.')
	if action == null: return
	assert_true(action is ActionReaction, 'It is a reaction.')
	assert_eq(action.triggers_on, [ReactionBus.TRIGGER.ATTACK_DECLARED] as Array[StringName],
		'On the attack_declared trigger.')
	assert_eq(action.trigger_timing, ReactionBus.TIMING.PRE, 'PRE, before the summary is read.')
	assert_true(action.consumes_rxn, 'A real reaction: it spends the point, which is its 1/round.')
	assert_eq(action.usage_group, DRAW_FIRE_ID,
		'Its own usage group, so the Rail and the protocol do not spend it.')

func test_the_actions_are_in_the_cards_order():
	# Protocol, reaction, weapon - the order the frame card renders them in.
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), 'cp_siege_engine loads.')
	if not Kit.is_valid(kit): return
	var ids:Array[StringName] = []
	for action:Action in kit.actions: ids.append(action.get_id())
	assert_eq(ids, [&'action_gather_round', DRAW_FIRE_ID] as Array[StringName],
		'Protocol then reaction. The weapon is no longer on this Kit.')
	var rail_kit:Kit = ContentLibrary.get_kit(RAIL_KIT_ID)
	assert_true(Kit.is_valid(rail_kit), 'mw_diversion_rail loads,')
	if not Kit.is_valid(rail_kit): return
	var rail_ids:Array[StringName] = []
	for rail_a:Action in rail_kit.actions: rail_ids.append(rail_a.get_id())
	assert_eq(rail_ids, [RAIL_ID] as Array[StringName], 'and carries the weapon alone.')

## A SOURCE-ORDER PIN, not a behaviour test, because the race it guards is not reproducible in this
## harness: it needs a SECOND attack_declared PRE reaction to displace the Subutai or the ally while
## confirm_use is awaited. The harness CAN define one - this file's own inline TerrainRecorder is a
## PRE reaction on a different trigger, and nothing stops a PRE reaction on ATTACK_DECLARED the same
## way - but ORDERING it to actually run between Draw Fire's own trigger evaluation and its activate
## is engine-controlled (reaction resolution order is not a knob a spec can turn), so the race cannot
## be steered from here even though a second reaction to write is not the obstacle. What activate() must
## never do is spend the point before it knows the LIVE rebuild succeeded - rebuild() returns false
## without writing anything when the rebuilt area no longer contains us, and a spend on that path
## costs the point, leaves the attack undrawn AND still queues a free Rail shot. This was GREEN from
## the moment it was written (the fix landed in the same task), so it is a regression pin only.
func test_activate_checks_the_live_rebuild_before_spending():
	# THE UNPACKED PATH, not the mirror path. The overlay maps res/ onto res:// for RESOURCES (via
	# take_over_path); raw file access still has to name the file where it actually sits on disk, and
	# FileAccess on the mirror path comes back empty (measured, first RED run of this pin).
	const SOURCE := 'res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_subutai/cp_siege_engine/action_draw_fire.gd'
	var src := FileAccess.get_file_as_string(SOURCE)
	assert_false(src.is_empty(), 'The reaction s source reads back.')
	if src.is_empty(): return
	var body:String = src.substr(src.find('func activate('))
	assert_gt(body.length(), 0, 'func activate is in the file.')
	var rebuild_at:int = body.find('rebuild(context.unit, triggering_context, true)')
	var spend_at:int = body.find('spend_actions(activation)')
	assert_gt(rebuild_at, -1, 'activate runs the LIVE rebuild.')
	assert_gt(spend_at, -1, 'activate spends the reaction.')
	assert_lt(rebuild_at, spend_at, 'The LIVE rebuild is checked BEFORE the point is spent.')

## A localization row with its glossary markup taken back off: |Label| -> Label, |Label=key| -> Label,
## the way GlossaryItem.process_glossed_text renders it (glossary_item.gd:212-257). Splitting on '|'
## alternates literal text (even indices) with labels (odd), so an UNBALANCED pipe leaves a stray
## label in the output and the compare fails loudly - which is the right failure for a malformed row.
func _unpiped(key:String) -> String:
	var parts := X.tr(key).split('|')
	var out := ''
	for i in parts.size():
		var part:String = parts[i]
		if i % 2 == 1 and part.contains('='): part = part.split('=')[0]
		out += part
	return out

func test_the_draw_fire_rows_resolve():
	for key:String in [
		'gear.cp_siege_engine.action_draw_fire.name',
		'gear.cp_siege_engine.action_draw_fire.trigger',
		'gear.cp_siege_engine.action_draw_fire.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_siege_engine.action_draw_fire.name'), 'Draw Fire', 'Named as the card names it.')
	# The engine prepends "Trigger:" itself (action_reaction.gd:21-24), so the row must not.
	assert_false(X.tr('gear.cp_siege_engine.action_draw_fire.trigger').begins_with('Trigger:'),
		'The row carries the sentence, not the label.')
	# THE LCP'S SENTENCES VERBATIM. The card text is Bel's words, not ours: any engine divergence goes
	# in a ruling, never into the row. Source: specs/sixth-voice/03-subutai.md.
	#
	# COMPARED WITH ITS GLOSSARY MARKUP TAKEN BACK OFF. The frame close piped this row's keywords
	# (|Range|, |line of sight|, |ranged attack|, |Sensors|) to match every sibling row in the mod.
	# Pipes are MARKUP, not rewording, so the verbatim guarantee is unchanged - but a raw byte compare
	# would now fail on the pipe characters. Stripping and THEN comparing keeps the guarantee that the
	# words are still Bel's; pasting the piped string into the literal would have thrown it away.
	assert_eq(_unpiped('gear.cp_siege_engine.action_draw_fire.trigger'),
		'A hostile character within Range of the Diversion Rail and line of sight makes a ranged attack against an allied character within Sensors.',
		'The trigger row is the LCP sentence, verbatim, under its glossary markup.')
	assert_eq(X.tr('gear.cp_siege_engine.action_draw_fire.effect'),
		'The attack is made against you instead. After the attack, you may make an attack against the hostile character with the Diversion Rail.',
		'The effect row is the LCP sentence, verbatim.')
