# SHACKLETON SP1 PROBE (design ruling 3): is a generate_knockback_events override on the
# CommonActionUtil autoload reached from a REAL weapon knockback?
#
# Nothing had ever extended common_action_util.gd - no resident, none of the 25 installed zips - so
# the install log proved nothing (memory lancer-tactics-extension-seams). Every vanilla knockback
# reaches the helper through a QUALIFIED call through the autoload node
# (`CommonActionUtil.generate_knockback_events`, action_attack_weapon.gd:337): depth 0 of the
# ONE-LEVEL rule, so the override needs no sibling overrides.
#
# MEASURED 2026-09-24, LIVE. The first form of this file ran against a throwaway extension that
# counted calls in an Engine meta: 2/2 green, 4/4 asserts. With mod_main.gd's EXTENDED_AUTOLOADS
# entry commented out, BOTH went red (2/4 asserts: the target still moved, the count stayed 0), so the
# test discriminates and the deferred autoload reload is load-bearing here as for every autoload
# extension. The meta was then replaced by the production rule, and this file now proves the same
# thing BY BEHAVIOUR: a plain size-1 unit wearing only the trait Kit gets an every-direction offer
# from an ordinary War Pike swing through action_attack_weapon.on_hit - an offer only the override can
# produce - and the same swing without the Kit gets vanilla's cone (the control).
#
# The knockback path is confirmed to have RUN (a reticle was offered) before the offer is read,
# because "never fired" and "never called" look the same (design §4).
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_shackleton_sp1_seam.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')

const ATTACKER_TILE := Vector2i(6, 6)
const TARGET_TILE := Vector2i(7, 6)
## Behind the target's line, on the attacker's side: vanilla's cone angled away east never offers it.
const BESIDE_THE_ATTACKER := Vector2i(6, 5)

var game:Gamemaster
var responder
var watcher

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func swing_pool(with_trait:bool) -> Array:
	var attacker := SpecFactory.create_unit(game.map, ATTACKER_TILE)
	if with_trait: Fixture.equip(attacker, Fixture.REROUTING_ID)
	Fixture.equip(attacker, Fixture.PIKE)
	var target := Fixture.create_dummy(game, TARGET_TILE)
	var before:int = watcher.prompts.size()
	await Fixture.swing(game, attacker, target)
	var pools:Array = Fixture.offered_pools(watcher, before)
	assert_eq(pools.size(), 1, 'the knockback path ran: one reticle was offered.')
	return pools[0] if pools.size() == 1 else []

func test_a_live_autoload_runs_the_extension() -> void:
	var script:Script = CommonActionUtil.get_script()
	var found := false
	while script != null:
		if script.source_code.contains('SPATIAL_REROUTING'): found = true
		script = script.get_base_script()
	assert_true(found, 'the CommonActionUtil node carries our extension in its chain.')

func test_a_weapon_knockback_reaches_the_override() -> void:
	var pool:Array = await swing_pool(true)
	assert_has(pool, BESIDE_THE_ATTACKER, 'the override emptied the origin: every direction is offered.')

func test_without_the_trait_the_cone_is_vanillas() -> void:
	var pool:Array = await swing_pool(false)
	assert_false(pool.is_empty(), 'the cone offered something.')
	assert_does_not_have(pool, BESIDE_THE_ATTACKER, 'and nothing back toward the attacker.')
