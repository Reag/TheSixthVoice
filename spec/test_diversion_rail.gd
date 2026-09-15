# The DIVERSION RAIL, the Siege Engine's integrated weapon (Subutai SP2 Task 2).
#
#   "Main Rifle, AP, 1d6 Kinetic, Range 15.
#    On attack: You become immobilized until the start of your next turn.
#    On hit: The target takes +2 difficulty on all attacks that do not target the Subutai until the
#    end of their next turn."
#
# THREE PIECES, THREE SHAPES:
#  - the weapon is an ActionAttackWeapon on the core Kit (an INTEGRATED weapon: no mount, no mod);
#  - "on attack" hangs off activate(), not an OnHitEffect, because it fires on a miss as well as a
#    hit - the Bizarre Cannon's idiom, including its `if activation.aborted: return` guard, since an
#    aborted targeting is a shot that was never fired and must cost nothing;
#  - "on hit" is a scriptless OnHitEffect carrying a BuffBonus whose GATE does all the work.
#
# WHY THE -2 IS A CONSTANT WITH A GATE, AND NOT A COMPUTED VALUE. attack_roll.gd:184 calls
# buff_core.get_values() BARE - no context - so get_values cannot see which roll it is modifying;
# only check_if_passive_applies is handed the roll's context, whose target_unit is THAT roll's
# target. So the value is fixed at -2 and the gate asks "is this roll aimed at somebody other than
# my owner". A Blast catching the Subutai and two others is therefore at -2 on the two rolls and +0
# on the Subutai's, from one buff. Same split as the M/K2's Hybridized Shot.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_diversion_rail.gd
extends GutTest

const SubutaiFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/subutai_fixture.gd')
const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const CORE_ID := &'cp_siege_engine'
const RAIL_ID := &'action_diversion_rail'
const CHIP_ID := &'buff_diversion_rail'

## The key attack_roll.gd:189 resolves the breakdown line's title through - buff_core.name_text().
const CHIP_NAME_KEY := 'gear.%s.name' % CHIP_ID

const SUBUTAI_TILE := Vector2i(4, 6)
const TARGET_TILE := Vector2i(10, 6)
const ALLY_TILE := Vector2i(14, 6)
## Inside a Blast 1 centred on SUBUTAI_TILE + (1, 0), for the per-roll split.
const BESIDE_SUBUTAI := Vector2i(6, 6)

## Off the 24x16 map entirely, so the attack plan fails validation and the activation aborts - the
## test_ors_hypercharge.OFF_MAP idiom, which is how this suite reaches a real abort.
const OFF_MAP := Vector2i(99, 99)

const TARGET_EVASION := -10 # a 6 beats it: every shot in this file hits unless it is told not to
const D20_HIT := 19         # and never crits
const D20_MISS := 1

## Vanilla GMS Main Rifle, Range 10 (test_spike_recentre.gd:41).
const RIFLE := &'mw_assault_rifle'
## Vanilla GMS Blast 1 cannon, Range 15, Arcing, Inaccurate (test_spike_recentre.gd:43).
const MORTAR := &'mw_mortar'
## A vanilla TECH attack that is the whole of its Kit, so get_solo_action() finds it:
## ms_fragment_signal's single action is an ActionAttackTech (content/gear/basic/ms_fragment_signal.tres).
const TECH := &'ms_fragment_signal'

var game:Gamemaster
var subutai:Unit
var target:Unit

func before_each() -> void:
	game = SubutaiFixture.create_game(self, Vector2i(24, 16))
	subutai = SubutaiFixture.create_subutai(game, SUBUTAI_TILE)
	target = SubutaiFixture.create_dummy(game, TARGET_TILE, TARGET_EVASION)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

# ---------------------------------------------------------------- helpers

func core_gear() -> GearCore:
	return subutai.get_gear(CORE_ID)

func rail_action() -> Action:
	var gear:GearCore = core_gear()
	return gear.get_action(RAIL_ID) if GearCore.is_valid(gear) else null

## Every die in the rest of this activation comes back 6 after the one d20 we care about. A thinner
## queue than the attack pops is the usual source of a flaky attack spec.
func queue_dice(d20:int) -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	var buffer:Array[int] = []
	for i:int in 60: buffer.append(6)
	Dice.cheat_attack([d20], buffer)

## Fire the Rail at a unit and hand back the DeclaredAttackSummary it resolved through. Built by
## hand rather than through game.execute_event() because the summary lives on the activation event's
## OWN context, which execute_event does not return (test_hybridized_shot.fire_and_capture's reason).
func fire_rail(at:Unit, d20:int = D20_HIT) -> DeclaredAttackSummary:
	queue_dice(d20)
	var core := EventCore.create(&'event_gear_activate', {
		action = rail_action(), gear = core_gear(), unit = subutai, target_unit = at,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	return core.context.resource as DeclaredAttackSummary

## Fire the Rail at a TILE rather than a unit. Only the abort test needs this, and it needs it
## because abort_all cannot reach an attack that was handed its target: a target_unit in the event
## raises no ChoiceRequest at all, so the responder is never asked and nothing aborts (measured -
## .superpowers/sdd/task2-green.log's first run, where abort_all changed nothing). An OFF-MAP tile is
## how the rest of this suite reaches a real abort: the plan fails CompconPlan.is_valid_with_targets
## and action_attack.gd:236 returns through activation.abort_when, which is the flag the guard reads.
func fire_rail_at_tile(tile:Vector2i) -> void:
	queue_dice(D20_HIT)
	var tiles:Array[Vector2i] = [tile]
	var core := EventCore.create(&'event_gear_activate', {
		action = rail_action(), gear = core_gear(), unit = subutai, target_tiles = tiles,
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))

## What a roll by `shooter` at `against` with `weapon` would compute right now - the way
## test_hybridized_shot.accuracy_for and test_spike_draw_fire.preview both read a modifier without
## firing anything.
func preview(shooter:Unit, weapon:GearCore, against:Unit) -> AttackRoll.PreAttack:
	var specific := SpecificAction.create(shooter, weapon, weapon.get_solo_action())
	var context := Context.clone(specific.to_context(), {target_unit = against})
	return AttackRoll.PreAttack.create(context)

## Does this roll carry the chip's OWN breakdown line? Read off the mod list rather than the total,
## for test_hybridized_shot.got_the_bonus's reason: the total is the sum of every accuracy source on
## the roll (cover, Inaccurate, statuses), so a test that only watched the total would be measuring
## the map as much as the chip. The title is buff_core.name_text(), which is what attack_roll.gd:189
## puts on the line.
func has_chip_mod(pre:AttackRoll.PreAttack) -> bool:
	for mod:AttackRoll.AccuracyMod in pre.accuracy_mods:
		if mod.title_key == tr(CHIP_NAME_KEY) and mod.mod == -2: return true
	return false

func arm(unit:Unit, weapon_id:StringName) -> GearCore:
	var weapon:GearCore = unit.core.equip_system(weapon_id)
	SpecFactory.apply_passive_buffs(unit)
	return weapon

# ---------------------------------------------------------------- the weapon profile

func test_the_rail_is_on_the_core_kit():
	var kit:Kit = ContentLibrary.get_kit(CORE_ID)
	assert_true(Kit.is_valid(kit), 'cp_siege_engine loads.')
	if not Kit.is_valid(kit): return
	var action:Action = kit.get_action(RAIL_ID)
	assert_not_null(action, 'The Kit carries action_diversion_rail.')
	assert_true(action is ActionAttackWeapon, 'It is a weapon action.')

func test_the_profile_matches_the_card():
	var action = rail_action()
	assert_true(action is ActionAttackWeapon, 'The unit holds the Rail.')
	if action is not ActionAttackWeapon: return
	assert_eq(action.weapon_size, Lancer.WEAPON_SIZE.MAIN, 'Main.')
	assert_eq(action.weapon_type, Lancer.WEAPON_TYPE.RIFLE, 'Rifle.')
	assert_eq(action.damage_type, Lancer.DAMAGE_TYPE.KINETIC, 'Kinetic.')
	assert_eq(action.damage_dice, '1d6', '1d6.')
	assert_eq(action.aim_range, 15, 'Range 15.')
	assert_has(action.tags, &'ap', 'AP.')

func test_the_rail_carries_no_loading_and_no_other_tag():
	# The card's tag line is AP and nothing else. Tags are add-only in this engine, so a stray one
	# here can never be taken back off by a mod.
	var action = rail_action()
	assert_true(action is ActionAttackWeapon, 'The unit holds the Rail.')
	if action is not ActionAttackWeapon: return
	assert_eq(action.tags, [&'ap'] as Array[StringName], 'Exactly one tag: AP.')

func test_range_fifteen_is_what_the_targeting_actually_uses():
	# Asserted through get_target_range and not only off aim_range, because that is the call Draw
	# Fire (Task 3) reads the Rail's reach with - if the two ever disagree, the reaction's range gate
	# silently uses a different number from the weapon.
	var action = rail_action()
	assert_not_null(action, 'The unit holds the Rail.')
	if action == null: return
	var specific := SpecificAction.create(subutai, core_gear(), action)
	assert_eq(action.get_target_range(specific), 15, 'The targeting range is 15.')

func test_the_ap_flag_reaches_the_damage_event():
	# AP is what makes the Rail worth firing into armor; it is carried as a weapon tag and turned
	# into a DAMAGE_FLAG by the attack pipeline. A 3-armor target taking the full 6 is the proof.
	# create_dummy has already FrameIsolation'd it, so this write is to its own copy of the frame
	# (the test_full_speed_ahead.make_victim idiom).
	var armored:Unit = FitzgeraldFixture.create_dummy(game, Vector2i(10, 10), TARGET_EVASION)
	armored.core.frame.stat.armor = 3
	armored.core.full_repair()
	var before:int = armored.core.current.health
	await fire_rail(armored)
	assert_eq(before - armored.core.current.health, 6, 'Six kinetic through 3 armor: AP skipped it.')

# ---------------------------------------------------------------- on attack: the self-immobilize

func test_firing_immobilizes_the_subutai():
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'On attack: the Subutai is Immobilized.')

func test_it_immobilizes_on_a_miss_too():
	# "On attack", not "on hit": the drawback is the price of firing, not of landing.
	#
	# A SEPARATE, DODGY DUMMY, NOT `target`. TARGET_EVASION is -10 so that every other test in this
	# file lands without saying so - and -10 is beaten even by a natural 1 plus grit, so D20_MISS
	# against `target` is a HIT (measured: the first green run reported "rolled 1 ... hit!"). The one
	# test that needs a miss has to supply a defence a 1 cannot beat.
	var dodgy:Unit = SubutaiFixture.create_dummy(game, Vector2i(10, 12), 30)
	await SubutaiFixture.open_turn(game, subutai)
	var summary := await fire_rail(dodgy, D20_MISS)
	assert_false(summary.attack_rolls[0].hit, 'CONTROL: the shot missed.')
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED), 'Still Immobilized.')

func test_the_immobilize_lasts_to_the_start_of_the_subutais_next_turn():
	# START_OF_TURN clears at the unit's OWN next turn start (unit_condition.gd:21). It must survive
	# the Subutai's own turn END - which is exactly when Juggernaut Drive wants to see it - AND the
	# whole of any intervening enemy turn, which is the case Draw Fire's follow-up depends on
	# (design SS2.3): a Rail shot fired on the Subutai's turn must still have it locked down while
	# the enemy acts.
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	await game.execute_event(&'event_turn_end', {unit = subutai})
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'Still Immobilized at its own turn end - the Drive can still fire.')

	await SubutaiFixture.open_turn(game, target)
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'Still Immobilized through the enemy turn that follows.')
	await game.execute_event(&'event_turn_end', {unit = target})
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'And at that enemy turn s end: only the Subutai s OWN turn start clears it.')

	await SubutaiFixture.open_turn(game, subutai)
	assert_false(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'Cleared at the start of its next turn.')

func test_an_aborted_shot_does_not_immobilize():
	# ActionAttack.activate bails before spend_actions when targeting is cancelled, so there is no
	# cost - and there must be no drawback either. Vanilla guards its own followups the same way.
	#
	# THE CONTROL AT THE BOTTOM IS NOT DECORATION (the test_ors_hypercharge lesson): "not
	# Immobilized" is also what a completely dead activate() override reads like. Firing for real
	# straight afterwards, in the same turn, from the same state, proves the status was reachable
	# from here - and reachable only because the aborted shot cost nothing at all.
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail_at_tile(OFF_MAP)
	assert_false(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'A shot that was never fired costs nothing.')

	await fire_rail(target)
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'control: a real shot from that same state, same turn, does Immobilize.')

# ---------------------------------------------------------------- on hit: the chip

func test_a_hit_applies_the_chip_and_a_miss_does_not():
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target, D20_HIT)
	assert_true(UnitCondition.has_buff(target, CHIP_ID), 'A hit chips the target.')

	var missed:Unit = SubutaiFixture.create_dummy(game, Vector2i(10, 12), 30)
	await fire_rail(missed, D20_MISS)
	assert_false(UnitCondition.has_buff(missed, CHIP_ID), 'A miss does not.')

func test_a_second_hit_refreshes_the_chip_rather_than_stacking_it():
	# NOT CUMULATIVE, and this pins the correction: the Task 2 report claimed a second hit would stack
	# a second -2. Buff.multiple_copies_can_stack defaults to FALSE (buff.gd:131), and
	# UnitCondition.apply_buff_alt (unit_condition.gd:741-748) clears every buff already on the unit
	# with the same compcon_id, the same from_gear, the same `to` and the same `until` before appending
	# the new one - so a second hit REPLACES the chip with its lifetime refreshed. One buff, one -2.
	#
	# THE SECOND SHOT NEEDS A SECOND TURN: the Rail's per-turn soft limit is 1. The Subutai's own turn
	# is ended and reopened rather than the target's, because the target taking a turn is what would
	# expire the chip (test_the_chip_clears_at_the_end_of_the_targets_next_turn).
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_eq(UnitCondition.get_buffs(target, CHIP_ID).size(), 1, 'CONTROL: one chip after the first hit.')

	await game.execute_event(&'event_turn_end', {unit = subutai})
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_eq(UnitCondition.get_buffs(target, CHIP_ID).size(), 1,
		'Still ONE chip after the second hit: the old one was cleared, not added to.')

	var ally:Unit = SubutaiFixture.create_ally(game, ALLY_TILE)
	var rifle := arm(target, RIFLE)
	assert_eq(preview(target, rifle, ally).accuracy_mods_total(), -2,
		'And the modifier is still -2, not -4.')

func test_the_chipped_target_is_at_minus_two_against_an_ally():
	var ally:Unit = SubutaiFixture.create_ally(game, ALLY_TILE)
	var rifle := arm(target, RIFLE)
	assert_eq(preview(target, rifle, ally).accuracy_mods_total(), 0, 'CONTROL: unchipped, no modifier.')

	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_eq(preview(target, rifle, ally).accuracy_mods_total(), -2,
		'+2 difficulty on an attack that does not target the Subutai.')

	# ...and the breakdown line the player reads is attributed to the Rail, not to a bare -2 from
	# nowhere. attack_roll.gd:189 titles the line with buff_core.name_text(), so this is also what
	# pins the chip's localization row to the roll UI (design SS2.3).
	assert_true(has_chip_mod(preview(target, rifle, ally)),
		'The -2 is labelled Diversion Rail in the roll breakdown.')

func test_the_chipped_target_is_unmodified_against_the_subutai():
	# "...that do not target the Subutai". This is the whole gate, and it is per ROLL.
	var rifle := arm(target, RIFLE)
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_eq(preview(target, rifle, subutai).accuracy_mods_total(), 0,
		'Shooting the Subutai itself is unmodified.')

func test_a_blast_catching_both_is_minus_two_on_one_roll_and_zero_on_the_other():
	# One buff, two different answers in one attack: the value is read bare and the gate is handed
	# each roll's own context. The Subutai is size 2 and anchors north-west, so a Blast 1 on a tile
	# adjacent to its footprint catches both it and the bystander.
	var bystander:Unit = FitzgeraldFixture.create_dummy(game, BESIDE_SUBUTAI, TARGET_EVASION)
	var mortar := arm(target, MORTAR)
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)

	queue_dice(D20_HIT)
	var core := EventCore.create(&'event_gear_activate', {
		action = mortar.get_solo_action(), gear = mortar, unit = target,
		target_tiles = [SUBUTAI_TILE + Vector2i(1, 0)] as Array[Vector2i],
	})
	var cores:Array[EventCore] = [core]
	await game.execute_event_block(EventBlock.create_multiple(cores))
	var summary:DeclaredAttackSummary = core.context.resource

	var by_target := {}
	for roll:AttackRoll in summary.attack_rolls: by_target[roll.target_unit] = roll
	assert_true(by_target.has(subutai) and by_target.has(bystander), 'Both were caught.')
	if not (by_target.has(subutai) and by_target.has(bystander)): return
	var at_subutai:AttackRoll.PreAttack = by_target[subutai].pre
	var at_bystander:AttackRoll.PreAttack = by_target[bystander].pre
	assert_false(has_chip_mod(at_subutai), 'The Subutai s own roll carries no Diversion Rail line.')
	assert_true(has_chip_mod(at_bystander), 'The bystander s roll carries the Diversion Rail -2.')
	# THE BASELINE IS -1, NOT 0, AND IT IS MEASURED, NOT ASSUMED. The mortar is INACCURATE, so every
	# roll it makes already carries a -1 of its own before the chip is asked anything - the first RED
	# run of this file reported -1 on BOTH rolls with no chip in play. The totals are therefore
	# pinned around that baseline; the chip's own contribution is the pair of assertions above.
	assert_eq(at_subutai.accuracy_mods_total(), -1, 'Only the mortar s own Inaccurate.')
	assert_eq(at_bystander.accuracy_mods_total(), -3, 'Inaccurate -1 plus the chip s -2.')

func test_a_tech_attack_on_an_ally_also_takes_the_minus_two():
	# "all attacks" - tech attacks, Ram and Grapple all go through PreAttack.create, so the buff
	# reaches them without naming any of them.
	var ally:Unit = SubutaiFixture.create_ally(game, ALLY_TILE)
	var invade := arm(target, TECH)
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	assert_eq(preview(target, invade, ally).accuracy_mods_total(), -2, 'A tech attack too.')

func test_the_chip_clears_at_the_end_of_the_targets_next_turn():
	# Applied on the SUBUTAI's turn: turn_count is 0 at the target's next turn start, incremented to
	# 1 there (unit_condition.gd:24), and the buff clears at that turn's end (:41-42).
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	await game.execute_event(&'event_turn_end', {unit = subutai})
	await SubutaiFixture.open_turn(game, target)
	assert_true(UnitCondition.has_buff(target, CHIP_ID), 'Still there through the target s own turn.')
	await game.execute_event(&'event_turn_end', {unit = target})
	assert_false(UnitCondition.has_buff(target, CHIP_ID), 'Gone at the end of that turn.')

func test_a_chip_applied_during_the_targets_own_turn_survives_that_turn_and_clears_at_the_next():
	# The Draw Fire follow-up case: the Rail fires on the ENEMY's turn. turn_count is 0 at that
	# turn's end so the buff survives it, and reaches 1 at the following turn's start.
	await SubutaiFixture.open_turn(game, target)
	await fire_rail(target)
	await game.execute_event(&'event_turn_end', {unit = target})
	assert_true(UnitCondition.has_buff(target, CHIP_ID),
		'It survives the turn it was applied during.')
	await SubutaiFixture.open_turn(game, target)
	await game.execute_event(&'event_turn_end', {unit = target})
	assert_false(UnitCondition.has_buff(target, CHIP_ID), 'And clears at the end of the next one.')

func test_the_chip_knows_the_subutai_is_its_owner():
	# OnHitEffect.apply_statuses_and_buffs applies the buff with context.gear as from_gear, which is
	# what makes BuffCore.get_owner_unit resolve to the Subutai - and the gate's whole question is
	# "is this roll aimed at my owner". If from_gear were lost the gate would compare against null
	# and the -2 would apply to EVERY attack, including ones at the Subutai.
	await SubutaiFixture.open_turn(game, subutai)
	await fire_rail(target)
	var rifle := arm(target, RIFLE)
	assert_eq(preview(target, rifle, subutai).accuracy_mods_total(), 0,
		'The owner is resolved: attacks on the Subutai are exempt.')

# ---------------------------------------------------------------- usage groups

func test_the_rail_fires_on_the_turn_gather_round_is_pressed():
	# THE USAGE-GROUP TEST (review fix, following test_draw_fire's own). action_gather_round had no
	# usage_group of its own, so gear_core.gd:166-168 fell it back to the Kit id cp_siege_engine -
	# the same group action_diversion_rail (also groupless) fell back to. UnitAction.spend
	# (unit_action.gd:279) records every activation under its group, and the per-TURN soft limit
	# (unit_action.gd:167-168, is_under_per_turn_limit) then refuses a second use of that group in
	# the same turn: pressing GATHER ROUND put cp_siege_engine on 1 use for the turn, and the Rail
	# (soft limit 1, same group) could only be fired by overcharging. Every vanilla core Kit pairing
	# a protocol with a pressable action gives each its own group - the Raleigh's Thunder God
	# (action_thunder_god.tres: usage_group = &"thunder_god") beside its cannon's own, and the
	# Sherman/Tokugawa/Death's Head the same - and Draw Fire already followed suit
	# (usage_group = &"action_draw_fire"). The fix gives the protocol and the Rail their own groups
	# too, so both can fire in the same turn.
	await SubutaiFixture.gather_round(game, subutai) # opens the turn AND presses the protocol
	assert_true(UnitCondition.has_buff(subutai, &'buff_gather_round'),
		'fixture control: the protocol really landed.')
	await fire_rail(target)
	assert_true(UnitCondition.has_status(subutai, Lancer.STATUS.IMMOBILIZED),
		'The Rail really fired (its on-attack drawback landed) on the SAME turn as the protocol.')

# ---------------------------------------------------------------- localisation

func test_the_rail_rows_resolve():
	for key:String in [
		'gear.cp_siege_engine.action_diversion_rail.name',
		'gear.cp_siege_engine.action_diversion_rail.effect',
		'gear.buff_diversion_rail.name', 'gear.buff_diversion_rail.effect',
	]:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_siege_engine.action_diversion_rail.name'), 'Diversion Rail', 'Named.')
	assert_eq(X.tr('gear.buff_diversion_rail.name'), 'Diversion Rail',
		'The chip is named after its source (ruling 14).')
