# RPA PULLBACK (Gloire SP2, design rulings 10-13): "For the rest of the scene, your non-Superheavy
# weapons may be fired as if they had a line 5 pattern and targets hit are immediately pulled towards
# you by the most direct route possible. If this movement would cause a character to hit another
# mech or an obstruction, then they must succeed a Hull save or be knocked Prone."
#
# GEOMETRY. The Gloire is size 2 at (4,4), covering (4..5, 4..5). Every line here is fired due east
# from its east edge (5,4): under the variant a line 5 covers (6..10, 4), and a target on it is
# pulled west along row 4 until it is adjacent (6,4) or something stops it. A BLOCKER stands on the
# row at (7,4), two from the footprint - NOT adjacent, so the Gloire is never Engaged and no
# Difficulty die is rolled that would shift the cheated queue - with evasion 30, so the line's roll
# against it MISSES and it is neither pulled nor Prone: it is only ever the thing hit.
#
# DICE. Dice.CHEAT_ROLL_QUEUE feeds EVERY die (dice.gd:33-35), in the order the engine rolls them:
# one d20 per line target - the PICKED target first, then the rest (measured 2026-09-24; the pull
# sorts closest-first itself for that reason) - then the weapon's damage dice (two pops for a
# two-target 1d6 line), then - inside on_resolution, after damage - one d20 per collision save. The
# fixture's fire_pulled queues the hits and then a TAIL that serves as both damage and save: 1 fails
# any Hull save, 20 passes. Read its header.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_rpa_pullback.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/gloire_fixture.gd')

const GLOIRE_TILE := Vector2i(4, 4)
const ADJACENT := Vector2i(6, 4)
const BLOCKER_TILE := Vector2i(7, 4)
## One short of the blocker: where a pull from the east stops against it.
const SHORT := Vector2i(8, 4)
const FAR := Vector2i(10, 4)
const MISS := 10 # against evasion 30
const HIT := 10 # against evasion -10
const FAIL := 1
const PASS := 20

var game:Gamemaster
var responder
var watcher
var gloire:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	gloire = Fixture.create_gloire(game, GLOIRE_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	responder.move_tile_queue.clear()
	responder.yesno_queue.clear()

## A hostile the line cannot hit (evasion 30), standing in the pull's way.
func blocker() -> Unit:
	return Fixture.create_dummy(game, BLOCKER_TILE, 30)

func is_impaired(unit:Unit) -> bool:
	return unit.has_status(Lancer.STATUS.IMPAIRED)

## Equip, press the protocol, and leave the turn open for a shot.
func arm(kit_id:StringName) -> void:
	Fixture.equip(gloire, kit_id)
	assert_true(await Fixture.press_pullback(game, gloire), 'fixture: the protocol is on.')

# ---------------------------------------------------------------- the protocol

func test_a_protocol_outside_the_window_is_refused() -> void:
	# No turn opened: is_using_protocols is false, and unit_action.gd:144 refuses.
	assert_eq(UnitAction.get_gear_unavailable_reason(Fixture.pullback_specific(gloire)), UnitAction.REASON.PROTOCOL)
	await SpecFactory.use(game, gloire, Fixture.CORE_ID, Fixture.PULLBACK_ID)
	assert_false(Fixture.has_pullback(gloire), 'nothing landed.')
	assert_true(gloire.core.has_core_power, 'and the core point is intact.')

func test_pressing_it_spends_the_core_power_and_hangs_both_buffs_for_the_scene() -> void:
	assert_true(await Fixture.press_pullback(game, gloire), 'the variant buff landed.')
	assert_true(UnitCondition.has_buff(gloire, Fixture.PULLBACK_PULL_BUFF), 'and the hidden pull carrier.')
	assert_false(gloire.core.has_core_power, 'the core point is spent.')
	await Fixture.cycle_turn(game, gloire)
	await Fixture.cycle_turn(game, gloire)
	assert_true(Fixture.has_pullback(gloire), '"for the rest of the scene": two rounds on, still up.')
	assert_true(UnitCondition.has_buff(gloire, Fixture.PULLBACK_PULL_BUFF))

# ---------------------------------------------------------------- the variant

func test_the_variant_appears_on_every_non_superheavy_weapon_and_nowhere_else() -> void:
	for kit_id:StringName in [Fixture.RIFLE, Fixture.PIKE, Fixture.HMG, Fixture.SUPERHEAVY]: Fixture.equip(gloire, kit_id)
	assert_does_not_have(Fixture.variant_keys_for(gloire, Fixture.RIFLE), Fixture.PULLBACK_VARIANT, 'before the protocol: nothing.')
	assert_true(await Fixture.press_pullback(game, gloire))
	assert_has(Fixture.variant_keys_for(gloire, Fixture.RIFLE), Fixture.PULLBACK_VARIANT, 'a Main rifle.')
	assert_has(Fixture.variant_keys_for(gloire, Fixture.PIKE), Fixture.PULLBACK_VARIANT, 'RULED: a Main MELEE weapon too.')
	assert_has(Fixture.variant_keys_for(gloire, Fixture.HMG), Fixture.PULLBACK_VARIANT, 'a Heavy.')
	assert_does_not_have(Fixture.variant_keys_for(gloire, Fixture.SUPERHEAVY), Fixture.PULLBACK_VARIANT, '"non-Superheavy".')
	assert_does_not_have(Fixture.variant_keys_for(gloire, Fixture.RAM), Fixture.PULLBACK_VARIANT, 'RULED: the Ram is not a weapon on the card (size NONE).')

# ---------------------------------------------------------------- the pull

## THE PULL ENDS INTO THE GLOIRE (the author, 2026-09-25, reversing ruling 13's "arriving is not
## hitting"): a hostile pulled all the way collides with the Gloire itself and makes the Hull save.
func test_a_line_5_hit_pulls_the_target_into_the_gloire_by_the_straight_route() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, FAR)
	var health:int = target.core.current.health
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE)
	assert_lt(target.core.current.health, health, 'fixture: the line hit it (a Range-10 rifle fired as a line 5 reaches (10,4)).')
	assert_eq(target.tile(), ADJACENT, 'RULED: pulled straight west along the row, stopped against the Gloire.')
	assert_true(target.has_status(Lancer.STATUS.PRONE), 'RULED (author): it hit the Gloire - a Hull save, failed: Prone.')
	assert_true(Fixture.is_punished(target), 'and the Prone is the Gloire\'s, so Hydraulic Punisher fires.')

func test_a_target_that_passes_the_save_against_the_gloire_is_not_prone() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, FAR)
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE, [HIT], PASS)
	assert_eq(target.tile(), ADJACENT)
	assert_false(target.has_status(Lancer.STATUS.PRONE), 'passed: not Prone.')

func test_a_pike_hit_pushes_then_pulls_and_the_target_ends_adjacent() -> void:
	# The War Pike's own Knockback 1 resolves FIRST (the author's ruling 12): the push is queued by
	# action.on_hit on the per-target attack and lands before the pull runs at on_resolution.
	await arm(Fixture.PIKE)
	var target := Fixture.create_dummy(game, BLOCKER_TILE) # 2 from the edge: in the pike's threat 3
	responder.move_tile_queue.assign([SHORT]) # the push: one east
	var from:int = watcher.prompts.size()
	await Fixture.fire_pulled(game, gloire, target, Fixture.PIKE)
	assert_eq(Fixture.offered_pools(watcher, from).size(), 1, 'the pike\'s knockback reticle was offered (the push happened).')
	assert_eq(target.tile(), ADJACENT, 'RULED: pushed, then pulled back into the Gloire.')
	assert_true(target.has_status(Lancer.STATUS.PRONE), 'the pull ends in the Gloire: a save, failed.')

func test_a_target_pulled_into_a_third_unit_saves_and_a_failure_is_prone_plus_impaired() -> void:
	await arm(Fixture.RIFLE)
	var wall := blocker()
	var target := Fixture.create_dummy(game, FAR)
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE, [HIT, MISS], FAIL) # the picked target rolls first
	assert_eq(wall.tile(), BLOCKER_TILE, 'the blocker was missed and never moved.')
	assert_false(wall.has_status(Lancer.STATUS.PRONE), 'nor floored.')
	assert_eq(target.tile(), SHORT, 'the pull stopped against it.')
	assert_true(target.has_status(Lancer.STATUS.PRONE), 'RULED: a failed Hull save is Prone.')
	assert_true(Fixture.is_punished(target), 'and the Prone is the Gloire\'s (source: the core Kit), so Hydraulic Punisher fires -')
	assert_true(is_impaired(target), 'Impaired. The frame\'s loop.')

func test_a_passed_save_is_neither() -> void:
	await arm(Fixture.RIFLE)
	blocker()
	var target := Fixture.create_dummy(game, FAR)
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE, [HIT, MISS], PASS)
	assert_eq(target.tile(), SHORT, 'stopped against the blocker,')
	assert_false(target.has_status(Lancer.STATUS.PRONE), 'passed: not Prone,')
	assert_false(is_impaired(target), 'not Impaired.')

## A target ALREADY adjacent is pulled one space into the Gloire and collides at once (the author,
## 2026-09-25: "it saves too" - the pull is one space into the Gloire for everyone).
func test_an_adjacent_target_collides_with_the_gloire_at_once_and_saves() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, ADJACENT)
	var from:int = watcher.prompts.size()
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE, [HIT], FAIL)
	assert_eq(target.tile(), ADJACENT, 'it cannot move into the Gloire: it stays put,')
	assert_true(target.has_status(Lancer.STATUS.PRONE), 'RULED (author): and saves for hitting it - failed, Prone.')
	assert_eq(Fixture.offered_pools(watcher, from).size(), 0, 'and no reticle of any kind.')

func test_a_knockback_immune_target_is_not_pulled() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, FAR)
	SpecFactory.apply_buff(target, &'buff_fortress_knockback')
	var health:int = target.core.current.health
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE)
	assert_lt(target.core.current.health, health, 'fixture: hit.')
	assert_eq(target.tile(), FAR, 'RULED: immune - the helper does no check of its own, so the effect does.')

func test_a_flying_target_is_landed_when_the_gloire_is_not_flying() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, FAR)
	await game.execute_event(&'event_unit_apply_status', {unit = target, category = Lancer.STATUS.FLYING, flags = [Lancer.UNTIL.MANUAL]})
	assert_true(target.has_status(Lancer.STATUS.FLYING), 'fixture: it flies.')
	var health:int = target.core.current.health
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE)
	assert_lt(target.core.current.health, health, 'fixture: the line hit the flier.')
	assert_eq(target.tile(), ADJACENT, 'pulled into the Gloire and stopped against it, not across its footprint,')
	assert_false(target.has_status(Lancer.STATUS.FLYING), 'RULED: landed (force_to_land, the Omni Harpoon\'s reading) -')
	assert_true(target.has_status(Lancer.STATUS.PRONE), 'BEFORE the pull, so it hits the grounded Gloire and saves (failed).')

func test_a_pulled_ally_saves_too() -> void:
	# The Gloire's own line catches an ally; "a character" saves whatever its side. The friendly-fire
	# confirm is answered yes by the responder's default.
	await arm(Fixture.RIFLE)
	blocker()
	var ally := Fixture.create_dummy(game, FAR, -10, Faction.PLAYER)
	await Fixture.fire_pulled(game, gloire, ally, Fixture.RIFLE, [HIT, MISS], FAIL)
	assert_eq(ally.tile(), SHORT, 'the ally was pulled and stopped against the blocker.')
	assert_true(ally.has_status(Lancer.STATUS.PRONE), 'RULED: an ally saves too, and this one failed.')
	assert_false(Fixture.is_punished(ally), 'but Hydraulic Punisher wants a HOSTILE: no Impaired.')

## An ALLY is not pulled into the Gloire: the engine lets a unit forced by an ally pass through that
## ally's allies (event_unit_move.gd:428-429), so the step would carry it INTO the footprint. It stops
## adjacent, as before, and saves only for something else in the way.
func test_an_ally_pulled_all_the_way_stops_adjacent_and_does_not_save() -> void:
	await arm(Fixture.RIFLE)
	var ally := Fixture.create_dummy(game, FAR, -10, Faction.PLAYER)
	await Fixture.fire_pulled(game, gloire, ally, Fixture.RIFLE, [HIT], FAIL)
	assert_eq(ally.tile(), ADJACENT, 'pulled adjacent, not into the footprint.')
	assert_false(ally.has_status(Lancer.STATUS.PRONE), 'no save against its own side\'s Gloire.')

## SP2's measurement, pinned (2026-09-24): the pulls run at on_resolution, AFTER every roll and the
## damage, closest first - see onhit_rpa_pullback.gd's header for why a pull queued at on_hit
## beside the weapon's push cannot work, and why the effect sorts (the line rolled the far, picked
## target first, and without the sort it was dragged into the near one still standing at (7,4)).
## Two hostiles on one line: the near one settles adjacent, the far one is dragged into it and saves.
func test_two_targets_on_one_line_are_pulled_after_every_roll_closest_first() -> void:
	await arm(Fixture.RIFLE)
	var near := Fixture.create_dummy(game, BLOCKER_TILE)
	var far := Fixture.create_dummy(game, FAR)
	await Fixture.fire_pulled(game, gloire, far, Fixture.RIFLE, [HIT, HIT], FAIL)
	assert_eq(near.tile(), ADJACENT, 'the near target was pulled into the Gloire first,')
	assert_true(near.has_status(Lancer.STATUS.PRONE), 'and saved against it (failed): Prone,')
	assert_true(Fixture.is_punished(near), 'Hydraulic Punisher took the round on it -')
	assert_eq(far.tile(), BLOCKER_TILE, 'the far one was dragged up behind it and stopped,')
	assert_true(far.has_status(Lancer.STATUS.PRONE), 'saved against the collision and failed: Prone,')
	assert_false(Fixture.is_punished(far), 'but the Punisher is once a round.')

# ---------------------------------------------------------------- close review, 2026-09-25

## A LEDGE IS AN OBSTRUCTION (ruling 13's "a step uphill"). An involuntary step costs 1 at any height
## (pathfinder.gd calculate_step_cost_alt), so without cannot_move_uphill the pull hauled the target
## straight up the step to the Gloire with no save. With it, is_next_step_blocked calls the step a
## collision (event_unit_move.gd:406-411) - Ferrous Lash's and every Knockback's flag.
func test_a_target_pulled_into_a_ledge_stops_at_its_foot_and_saves() -> void:
	await arm(Fixture.RIFLE)
	var ledge:Array[Vector2i] = [ADJACENT, BLOCKER_TILE]
	SpecFactory.set_tiles_elevation(game.map, game.map.elevation(FAR) + 1, ledge)
	UnitTile.update_tracking_and_statuses(game.map)
	var target := Fixture.create_dummy(game, FAR)
	var health:int = target.core.current.health
	await Fixture.fire_pulled(game, gloire, target, Fixture.RIFLE, [HIT], FAIL)
	assert_lt(target.core.current.health, health, 'fixture: the line hit it over the step.')
	assert_eq(target.tile(), SHORT, 'the pull stopped at the foot of the step, not up it.')
	assert_true(target.has_status(Lancer.STATUS.PRONE), '"hit an obstruction": a Hull save, failed - Prone.')

## "THIS MOVEMENT" IS THE PULL. Every forced move of a Pullback attack carries the same composed
## action (action_attack_weapon.gd:337 queues the weapon's Knockback with it, and it rides to the
## move's `object`), so keying the save on the variant alone gave the War Pike's own push into a
## wall a save the card never grants. The pull's MovementType carries a tag the push's does not.
func test_the_weapons_own_knockback_into_a_wall_forces_no_save() -> void:
	await arm(Fixture.PIKE)
	var target := Fixture.create_dummy(game, BLOCKER_TILE)
	Fixture.build_wall_at(game, SHORT.x, GLOIRE_TILE) # every tile east of it: the push can only collide
	responder.move_tile_queue.assign([SHORT])
	var from:int = watcher.prompts.size()
	# One save only, the pull's into the Gloire: it takes the PASS (after the two damage dice, hit and crit). Had the push saved too, the push
	# would have taken the PASS and the pull the FAIL behind it.
	await Fixture.fire_pulled(game, gloire, target, Fixture.PIKE, [HIT, 3, 3, PASS], FAIL)
	assert_eq(Fixture.offered_pools(watcher, from).size(), 1, 'fixture: the pike\'s knockback reticle was offered.')
	assert_eq(target.tile(), ADJACENT, 'the push hit the wall, then the pull brought it into the Gloire.')
	assert_false(target.has_status(Lancer.STATUS.PRONE), 'the push is the weapon\'s Knockback, not "this movement": its only save was the pull\'s, passed.')

## The protocol makes the line an OPTION ("may be fired as if"): the same rifle fired normally is an
## ordinary shot, and nothing is pulled.
func test_an_ordinary_shot_with_the_protocol_on_pulls_nothing() -> void:
	await arm(Fixture.RIFLE)
	var target := Fixture.create_dummy(game, BLOCKER_TILE)
	var health:int = target.core.current.health
	await Fixture.open_turn(game, gloire)
	Dice.CHEAT_ROLL_QUEUE.append_array([HIT, 3, 3, 3])
	await SpecFactory.use_solo(game, gloire, Fixture.RIFLE, target)
	assert_lt(target.core.current.health, health, 'fixture: the ordinary shot hit.')
	assert_eq(target.tile(), BLOCKER_TILE, 'no variant, no pull.')

# ---------------------------------------------------------------- the card

func test_the_protocol_the_reaction_and_the_rows() -> void:
	var kit:Kit = ContentLibrary.get_kit(Fixture.CORE_ID)
	assert_true(Kit.is_valid(kit))
	if not Kit.is_valid(kit): return
	var pullback:Action = kit.get_action(Fixture.PULLBACK_ID)
	var collide:Action = kit.get_action(Fixture.PULLBACK_COLLIDE_ID)
	assert_not_null(pullback); assert_not_null(collide)
	if pullback == null or collide == null: return
	var specific := Fixture.pullback_specific(gloire)
	assert_eq(pullback.get_action_type(specific), Lancer.ACTION.PROTOCOL, 'a Protocol.')
	assert_true(bool(pullback.consumes_core_power()), 'it costs the core point (the accessor answers an int, action_system.gd:31).')
	assert_true(pullback.show_in_tooltip(kit), 'on the card.')
	assert_true(collide is ActionReaction, 'the collision half is a reaction,')
	assert_false(collide.show_in_tooltip(kit), 'hidden from the card (localization_key_override),')
	assert_false((collide as ActionReaction).consumes_reaction(), 'not a reaction point,')
	assert_eq(collide.get_per_round_hard_limit(SpecificAction.create(gloire, gloire.get_gear(Fixture.CORE_ID), collide)), 99, 'and unlimited.')
	assert_eq(collide.usage_group, &'rpa_pullback_collide', 'its own usage group.')
	assert_eq(pullback.usage_group, &'rpa_pullback', 'and the protocol its own.')
	for key:String in ['gear.cp_retaliation_protocol_amplification.action_rpa_pullback.name',
			'gear.cp_retaliation_protocol_amplification.action_rpa_pullback.effect',
			'gear.buff_rpa_pullback.name', 'gear.buff_rpa_pullback.effect']:
		assert_ne(X.tr(key), key, '%s resolves to real text.' % key)
	assert_eq(X.tr('gear.cp_retaliation_protocol_amplification.action_rpa_pullback.effect'),
		'For the rest of the scene, your non-|Superheavy| weapons may be fired as if they had a line 5 pattern and targets hit are immediately pulled towards you by the most direct route possible. If this movement would cause a character to hit another mech or an obstruction, then they must succeed a |Hull save| or be knocked |Prone|.',
		'the card is the LCP verbatim.')
