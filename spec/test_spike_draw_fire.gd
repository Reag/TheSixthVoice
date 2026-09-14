# Spike 3 (roadmap §5 row 3): ATTACK REDIRECTION BY REACTION.
#
# The Subutai's Draw Fire says "the attack is made against you instead" - a reaction that moves an
# attack declared against an ally onto the reactor, so that the ROLL (evasion, cover, the target's
# own modifiers), the DAMAGE and the on-hit effects all resolve against the reactor. Sluagh's
# O' Trickery, Rakshasa's Neuro-Hijack and Lovers Knot's Gemini Charge hang on the same verdict, so
# it is settled here on the cheapest frame that needs it.
#
# NO VANILLA ABILITY DOES THIS. The Bastion's Fearless Defender and Bonded's Intercede redirect the
# DAMAGE EVENT only (the roll stays against the original target); the Sentinel's Reflexive Blow and
# the NOAH's Diluvian Ark Ward react at attack_declared PRE but never change who is rolled against.
#
# THE SEAM UNDER TEST. Every per-target roll is its own event_unit_attack, whose context carries
# the target in `target_units` and whose PRE preblock runs the ATTACK PRE reactions BEFORE execute()
# reads `context.target_unit` (event_block.gd:92-99 then :101-107; event_unit_attack.gd:31-39). The
# DeclaredAttackSummary in `context.resource` is the same object the declared-attack event holds, so
# swapping the ally out of `all_attacked_units` there keeps the two in step for everything that
# reads the summary afterwards (halve_bonus_damage, attack_declared POST reactions, get_all_hit_units).
#
# The probe reaction below is an inline ActionReactionAttacked on a runtime Kit. It is a PROBE: when
# the Subutai's SP2 builds the real Draw Fire on cp_siege_engine, this file is deleted and
# test_draw_fire.gd carries the coverage against the real .tres.
#
# Feasibility doc: D:\DEV\lancer-tactics-claude\specs\2026-09-14-attack-redirection-feasibility.md
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const FrameIsolation := preload('res://testkit/frame_isolation.gd')

## One row, west to east: the enemy shoots east at the ally; the guardian stands further east.
const ENEMY_TILE := Vector2i(2, 4)
const ALLY_TILE := Vector2i(5, 4)
const GUARDIAN_TILE := Vector2i(9, 4)
## Adjacent to the guardian, on the enemy's ray to it: HARD cover for the guardian, nothing for the
## ally (cover_calculator.gd:154-156: adjacent raised terrain = HARD).
const COVER_TILE := Vector2i(8, 4)
## 11 tiles from the enemy: past the assault rifle's Range 10.
const FAR_TILE := Vector2i(13, 4)
## Inside a Blast 1 centred on the ally.
const BYSTANDER_TILE := Vector2i(5, 5)
## Adjacent to the ally, for the melee control.
const ADJACENT_TO_ALLY := Vector2i(4, 4)

## Vanilla GMS Main Rifle: Range 10, 1d6 kinetic, Reliable 2, no accuracy of its own.
const RIFLE := &'mw_assault_rifle'
## Vanilla GMS melee, threat 1.
const MELEE := &'mw_tactical_melee_weapon'
## Vanilla GMS Blast 1 cannon, Range 15, Arcing, Inaccurate.
const MORTAR := &'mw_mortar'

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
var probe:DrawFireProbe

# ---------------------------------------------------------------- the probe

## The Draw Fire shape: an ATTACK PRE reaction on the reactor, gated on the defender being an ally
## (not the reactor itself), the attacker an enemy, the weapon ranged, and the weapon not one the
## engine already exempts from redirects (the Sniper's AMR overrides
## is_immune_to_automisses_and_redirects; the NOAH honours it the same way).
class DrawFireProbe extends ActionReactionAttacked:
	const USAGE := &'spike_draw_fire'

	## The reactor's own weapon for the "after the attack, you may make an attack against the
	## hostile" half. Null = no follow-up.
	var counter_weapon:GearCore = null

	func _init() -> void:
		triggers_on = [ReactionBus.TRIGGER.ATTACK]
		trigger_timing = ReactionBus.TIMING.PRE
		require_defender_relation = RELATION.ALLIES
		require_attacker_relation = RELATION.ENEMIES
		# A real reaction is 1/round by usage group, and the group defaults to the KIT id - the real
		# Draw Fire will share cp_siege_engine with the protocol and the Rail, so it names its own.
		usage_group = USAGE

	func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
		if not super.triggers_on_event(unit, gear, triggering_event): return false
		var triggering_context:Context = triggering_event.context
		if triggering_context.target_unit == unit: return false # an attack on ourselves needs no drawing
		if not UnitAction.is_ranged_weapon(triggering_context.action, triggering_context.gear): return false
		if triggering_context.action.is_immune_to_automisses_and_redirects(triggering_context): return false
		return true

	func activate(context:Context, activation:EventCore) -> void:
		var triggering_context:Context = context.event.context
		var ally_under_fire:Unit = triggering_context.target_unit

		var confirmed := await CommonActionUtil.confirm_use(context, [ally_under_fire], [], SpecificAction.from_context(triggering_context))
		if activation.abort_when(not confirmed): return
		spend_actions(activation)

		# THE SEAM: this per-target attack event has not read its target yet (event_unit_attack.gd:39
		# runs after the PRE preblock), so point it at us, and keep the declared summary in step.
		triggering_context.target_unit = context.unit
		var summary:DeclaredAttackSummary = triggering_context.resource
		var index := summary.all_attacked_units.find(ally_under_fire)
		if index >= 0: summary.all_attacked_units[index] = context.unit

		# "After the attack, you may make an attack against the hostile": queued to the declared
		# attack event at tertiary_attack priority, so it runs once the whole attack has resolved.
		#
		# THE `using` ACTION IS THE SHOT, NOT THIS REACTION. event_gear_choose_and_use re-validates
		# `using` with can_activate_gear at execute time (event_gear_choose_and_use.gd:44-47), and
		# AS_FREEBIE skips only the per-turn and affordability checks - a real reaction's 1/round hard
		# limit still applies, and by then this reaction HAS been used this round. Measured: with the
		# reaction as `using`, the queued event aborted with "specific: invalid" and no shot was fired.
		# (The Sentinel's Reflexive Blow avoids it differently: get_per_round_hard_limit 99.)
		if GearCore.is_valid(counter_weapon):
			var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
			var shot := SpecificAction.create(context.unit, counter_weapon, counter_weapon.get_solo_action())
			CommonActionUtil.choose_and_use_after_triggering_event(
				activation, shot, [shot],
				CommonActionUtil.choose_and_use_no_spend, attacker, [Action.FLAG.AS_FREEBIE]
			)

# ---------------------------------------------------------------- fixture

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	enemy = FitzgeraldFixture.create_dummy(game, ENEMY_TILE, ENEMY_EVASION)
	ally = make_player_unit(ALLY_TILE, ALLY_EVASION)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

## A 200 HP, 0 armor player-side character with a chosen evasion - create_dummy's shape, on our side.
func make_player_unit(tile:Vector2i, evasion:int) -> Unit:
	var unit := FitzgeraldFixture.create_dummy(game, tile, evasion, Faction.PLAYER)
	return unit

## The reactor: a player unit carrying the probe on a runtime trait Kit, with one reaction point.
## A dummy frame has stat.reactions 0 and full_repair clamps current.reactions to the max
## (unit_printer.gd:169), so the max is raised on the (already isolated) frame first.
func make_guardian(tile:Vector2i, followup_weapon_id:StringName = &'') -> Unit:
	guardian = make_player_unit(tile, GUARDIAN_EVASION)
	guardian.core.frame.stat.reactions = 1

	probe = DrawFireProbe.new()
	var kit := Kit.new()
	kit.compcon_id = &'spike_draw_fire_kit'
	kit.is_trait = true
	kit.actions.append(probe)
	guardian.core.loadout.equipped_kits.append(kit)

	if followup_weapon_id != &'':
		probe.counter_weapon = guardian.core.equip_system(followup_weapon_id)
	guardian.core.full_repair() # regenerates derived gear: the Kit's reaction is indexed by trigger here
	guardian.core.current.reactions = 1
	return guardian

func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	return weapon

## Sixty sixes after the one d20 we care about: accuracy dice (prone, cover), damage dice and any
## second d20 all come back 6, so nothing drains the FIFO into real RNG (memory
## lancer-tactics-spec-harness-traps: a thinner queue than the attack pops is the usual flake).
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Fire a weapon at a UNIT for real and hand back the DeclaredAttackSummary the attack resolved
## through - the one object that remembers who each roll was actually made against. Built by hand
## for the reason test_hybridized_shot.fire_and_capture gives: the summary lives on the activation
## event's own context, which game.execute_event() does not return.
func fire(shooter:Unit, weapon:GearCore, target:Unit, d20:int) -> DeclaredAttackSummary:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = weapon.get_solo_action(), gear = weapon, unit = shooter, target_unit = target,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

## Fire at a TILE (a Blast aims at ground).
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

## Raise one tile of terrain so it can serve as cover (the test_hole_puncher idiom).
func raise_cover_at(tile:Vector2i) -> void:
	SpecFactory.set_blocks_to_height(game.get_landscape_node(), 1, [tile])
	game.map.calculate_los_blockers()

## What the roll WOULD compute against this target from this shooter, right now - the control for
## the "recomputed against the reactor" tests, read the way test_hybridized_shot.accuracy_for does.
func preview(shooter:Unit, weapon:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, weapon, weapon.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context)

# ---------------------------------------------------------------- the verdict

func test_the_roll_is_made_against_the_reactor() -> void:
	make_guardian(GUARDIAN_TILE)
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_ALLY_ONLY)

	assert_eq(summary.attack_rolls.size(), 1, 'One roll: the ally was swapped out, not added to.')
	assert_eq(rolled_against(summary), [guardian], 'The roll was made against the reactor.')
	var roll:AttackRoll = summary.attack_rolls[0]
	assert_eq(roll.pre.target_defense, GUARDIAN_EVASION, 'Against the REACTOR\'s evasion.')
	assert_false(roll.hit, 'A 10 that would have hit the ally missed the reactor.')
	# The roll comes from the per-target event's context (event_unit_attack.gd:53); the summary is
	# what every later reader sees (halve_bonus_damage, attack_declared POST reactions), so it is
	# kept in step too.
	assert_eq(summary.all_attacked_units, [guardian], 'The declared summary names the reactor, not the ally.')

func test_the_damage_lands_on_the_reactor_and_the_ally_is_untouched() -> void:
	make_guardian(GUARDIAN_TILE)
	var rifle := arm(enemy, RIFLE)
	var ally_before:int = ally.core.current.health
	var guardian_before:int = guardian.core.current.health
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(guardian_before - guardian.core.current.health, 6, 'The reactor took the 1d6 (all sixes).')
	assert_eq(ally.core.current.health, ally_before, 'The ally took nothing.')

func test_reliable_damage_from_a_miss_lands_on_the_reactor_too() -> void:
	make_guardian(GUARDIAN_TILE)
	var rifle := arm(enemy, RIFLE)
	var ally_before:int = ally.core.current.health
	var guardian_before:int = guardian.core.current.health
	await fire(enemy, rifle, ally, D20_HITS_ALLY_ONLY) # misses the reactor

	assert_eq(guardian_before - guardian.core.current.health, 2, 'Reliable 2 on the miss hit the reactor.')
	assert_eq(ally.core.current.health, ally_before, 'The ally took nothing.')

func test_the_reactors_own_modifiers_are_applied_to_the_roll() -> void:
	make_guardian(GUARDIAN_TILE)
	SpecFactory.apply(guardian, Lancer.STATUS.PRONE) # +1 accuracy against the reactor, none against the ally
	var rifle := arm(enemy, RIFLE)
	assert_eq(preview(enemy, rifle, ally).accuracy_mods_total(), 0, 'CONTROL: nothing modifies a shot at the ally.')

	var summary := await fire(enemy, rifle, ally, D20_HITS_ALLY_ONLY)
	assert_eq(summary.attack_rolls[0].pre.accuracy_mods_total(), 1, 'The roll carried the reactor\'s Prone accuracy.')

func test_cover_is_read_from_the_reactors_position() -> void:
	make_guardian(GUARDIAN_TILE)
	raise_cover_at(COVER_TILE)
	var rifle := arm(enemy, RIFLE)
	assert_eq(preview(enemy, rifle, ally).cover, Lancer.COVER.NONE, 'CONTROL: the ally stands in the open.')
	assert_eq(preview(enemy, rifle, guardian).cover, Lancer.COVER.HARD, 'CONTROL: the block is hard cover for the reactor.')

	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)
	assert_eq(summary.attack_rolls[0].pre.cover, Lancer.COVER.HARD, 'The roll took the REACTOR\'s cover, not the ally\'s.')

func test_the_reactor_is_attacked_even_beyond_the_weapons_range() -> void:
	make_guardian(FAR_TILE) # 11 from the enemy; the rifle reaches 10
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [guardian], 'Range is checked at targeting only; the swapped roll is never re-validated.')

func test_the_follow_up_attack_lands_on_the_attacker() -> void:
	make_guardian(GUARDIAN_TILE, RIFLE)
	var rifle := arm(enemy, RIFLE)
	var enemy_before:int = enemy.core.current.health
	var guardian_before:int = guardian.core.current.health
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(guardian_before - guardian.core.current.health, 6, 'The reactor took the redirected shot.')
	assert_eq(enemy_before - enemy.core.current.health, 6, 'Then the reactor shot the attacker back with its own rifle (a 6 beats -10 evasion).')

func test_a_blast_catching_the_ally_swaps_only_the_allys_roll() -> void:
	make_guardian(GUARDIAN_TILE)
	var bystander := FitzgeraldFixture.create_dummy(game, BYSTANDER_TILE, ENEMY_EVASION) # inside the blast, NOT an ally
	var mortar := arm(enemy, MORTAR)
	var summary := await fire_at_tile(enemy, mortar, ALLY_TILE, D20_HITS_BOTH)

	var targets := rolled_against(summary)
	assert_eq(targets.size(), 2, 'Two rolls for two caught units.')
	assert_true(targets.has(guardian), 'The ally\'s roll became the reactor\'s.')
	assert_true(targets.has(bystander), 'The bystander\'s roll is untouched.')
	assert_false(targets.has(ally), 'The ally is no longer rolled against.')

# ---------------------------------------------------------------- controls: the gate is the reaction's

func test_without_a_reaction_point_the_ally_is_attacked() -> void:
	make_guardian(GUARDIAN_TILE)
	guardian.core.current.reactions = 0
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'No reaction, no redirect.')

func test_declining_the_prompt_leaves_the_ally_attacked() -> void:
	make_guardian(GUARDIAN_TILE)
	SpecFactory.current_responder.chosen_yesnos = false
	var rifle := arm(enemy, RIFLE)
	var summary := await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'Declined: the attack stays where it was declared.')
	assert_eq(guardian.core.current.reactions, 1, 'And the reaction was not spent.')

func test_a_melee_attack_is_not_drawn() -> void:
	make_guardian(GUARDIAN_TILE)
	var brawler := FitzgeraldFixture.create_dummy(game, ADJACENT_TO_ALLY, ENEMY_EVASION)
	var blade := arm(brawler, MELEE)
	var summary := await fire(brawler, blade, ally, D20_HITS_BOTH)

	assert_eq(rolled_against(summary), [ally], 'The card says ranged; a melee swing is left alone.')
	assert_eq(guardian.core.current.reactions, 1, 'And the reaction was not spent.')

func test_it_spends_the_reaction() -> void:
	make_guardian(GUARDIAN_TILE)
	var rifle := arm(enemy, RIFLE)
	await fire(enemy, rifle, ally, D20_HITS_BOTH)

	assert_eq(guardian.core.current.reactions, 0, 'A real reaction: the point is gone.')
