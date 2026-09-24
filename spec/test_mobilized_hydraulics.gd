# MOBILIZED HYDRAULICS (Shackleton, SP1): "1/round, when the Shackleton hits an enemy with a melee
# attack, it may have that attack gain Knockback 2." Design specs/2026-09-24-shackleton-design.md
# rulings 6-7.
#
# WHAT IS MEASURED. The push's size is read off the OFFER, never off where the target lands (the
# responder's answer is not checked against the offer - test_bizarre_cannon.gd's RECOIL_ANY note):
# with Spatial Rerouting every direction is open, and a must-move-max straight push of N offers only
# tiles exactly N away, so the reach of the offered pool from the target's tile IS the knockback. A
# knockback of 0 raises no reticle at all.
#
# THE PROMPT is found by its title (the trait's name), not by position: the diagnostic run on
# 2026-09-24 showed a player melee swing raises exactly one yes/no, this one, so yesno_queue[0] is
# always its answer here.
#
# NOT TESTED, AND WHY: the multi-target melee case. No vanilla melee weapon has an area (every
# weapon_type = 2 mw_*.tres under content/gear was checked, 2026-09-24), so there is nothing to swing
# it with; the state-flag shape that would serve it is argued in onhit_mobilized_hydraulics.gd.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_mobilized_hydraulics.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/shackleton_fixture.gd')
const PromptWatcher := preload('res://testkit/prompt_watcher.gd')

## GMS Tactical Melee Weapon: MAIN MELEE, 1d6+2, NO knockback of its own.
const BLADE := &'mw_tactical_melee_weapon'

const SHACKLETON_TILE := Vector2i(5, 5)
## Adjacent to the Shackleton's east edge, so the Ram reaches it too.
const TARGET_TILE := Vector2i(7, 5)

var game:Gamemaster
var responder
var watcher
var shackleton:Unit
var target:Unit

func before_each() -> void:
	var made:Array = Fixture.create_game(self)
	game = made[0]; responder = made[1]; watcher = made[2]
	shackleton = Fixture.create_shackleton(game, SHACKLETON_TILE)
	Fixture.equip(shackleton, Fixture.PIKE)
	Fixture.equip(shackleton, BLADE)
	Fixture.equip(shackleton, Fixture.RIFLE)
	target = Fixture.create_dummy(game, TARGET_TILE)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func hydraulics_prompts(from:int) -> int:
	var n := 0
	var name:String = X.tr('gear.mt_mobilized_hydraulics.name')
	for seen:Dictionary in watcher.prompts.slice(from):
		if seen.kind == PromptWatcher.KIND.yesno and String(seen.info.title).contains(name): n += 1
	return n

## One attack at the target, put back on TARGET_TILE first. Returns {prompts, pools, reach}.
func attack(kit_id:StringName, answers:Array[bool] = []) -> Dictionary:
	UnitTile.move_to(target, TARGET_TILE)
	UnitTile.update_tracking_and_statuses(game.map)
	responder.yesno_queue.assign(answers)
	var before:int = watcher.prompts.size()
	await Fixture.swing(game, shackleton, target, kit_id)
	var pools:Array = Fixture.offered_pools(watcher, before)
	return {
		prompts = hydraulics_prompts(before),
		pools = pools.size(),
		reach = Fixture.reach_of(pools[0], TARGET_TILE) if pools.size() == 1 else 0,
	}

func test_a_melee_hit_prompts_and_a_yes_adds_knockback_two() -> void:
	var swing:Dictionary = await attack(Fixture.PIKE, [true])
	assert_eq(swing.prompts, 1, 'the hit offered Mobilized Hydraulics.')
	assert_eq(swing.pools, 1, 'one push.')
	assert_eq(swing.reach, 3, 'the pike\'s Knockback 1 became 3 - one push, not two.')
	assert_eq(Fixture.hydraulics_uses(shackleton), 1, 'the round is spent.')

func test_a_weapon_with_no_knockback_gains_two() -> void:
	# "gain Knockback 2": the buff is UNGATED, so a weapon with none still gets it
	# (action_attack_weapon.gd:327-331 adds gated values only to a weapon that already had some).
	var swing:Dictionary = await attack(BLADE, [true])
	assert_eq(swing.prompts, 1, 'the hit offered Mobilized Hydraulics.')
	assert_eq(swing.reach, 2, 'a knockback-less blade pushes 2.')

func test_the_ram_is_a_melee_attack_and_gains_it() -> void:
	# Ruling 6 (the author): Ram is MELEE in the engine and in the tabletop, so it counts.
	var ram:Dictionary = await attack(Fixture.RAM, [true])
	assert_eq(ram.prompts, 1, 'a Ram hit offered Mobilized Hydraulics.')
	assert_eq(ram.reach, 3, 'the Ram\'s Knockback 1 became 3.')

func test_a_ranged_hit_is_not_offered() -> void:
	var shot:Dictionary = await attack(Fixture.RIFLE, [true])
	assert_eq(shot.prompts, 0, 'a rifle hit is not a melee attack.')
	assert_eq(shot.pools, 0, 'and the rifle pushes nothing.')
	assert_eq(Fixture.hydraulics_uses(shackleton), 0, 'nothing spent.')

func test_a_miss_is_not_offered() -> void:
	target.core.frame.stat.evasion = 99
	var swing:Dictionary = await attack(Fixture.PIKE, [true])
	assert_eq(swing.prompts, 0, 'a miss offers nothing.')
	assert_eq(Fixture.hydraulics_uses(shackleton), 0, 'nothing spent.')

func test_an_ally_is_not_offered() -> void:
	UnitTile.move_to(target, Vector2i(14, 10)) # the enemy dummy, parked out of reach
	target = Fixture.create_dummy(game, TARGET_TILE, -10, Faction.PLAYER)
	assert_false(UnitRelation.are_enemies(shackleton, target), 'fixture: the target is an ally.')
	var swing:Dictionary = await attack(Fixture.PIKE, [true])
	assert_eq(swing.prompts, 0, 'hitting an ally offers nothing - "hits an enemy".')
	assert_eq(swing.reach, 1, 'the pike pushes its own 1.')

func test_a_decline_spends_nothing_and_the_next_hit_asks_again() -> void:
	var declined:Dictionary = await attack(Fixture.PIKE, [false])
	assert_eq(declined.prompts, 1, 'the hit offered it.')
	assert_eq(declined.reach, 1, 'declined: the pike pushes its own 1.')
	assert_eq(Fixture.hydraulics_uses(shackleton), 0, 'a decline spends nothing.')

	var ram:Dictionary = await attack(Fixture.RAM, [true])
	assert_eq(ram.prompts, 1, 'the next melee hit in the same round is offered again.')
	assert_eq(ram.reach, 3, 'and taken.')

func test_once_a_round() -> void:
	var first:Dictionary = await attack(Fixture.PIKE, [true])
	assert_eq(first.reach, 3, 'fixture: the first hit took it.')
	var second:Dictionary = await attack(Fixture.RAM, [true])
	assert_eq(second.prompts, 0, 'the second melee hit in the round is not offered.')
	assert_eq(second.reach, 1, 'and the arming did not outlive the first attack: the Ram pushes 1.')

	await Fixture.cycle_turn(game, shackleton)
	assert_eq(Fixture.hydraulics_uses(shackleton), 0, 'fixture: a new round reset the tally.')
	var next:Dictionary = await attack(Fixture.PIKE, [true])
	assert_eq(next.prompts, 1, 'a new round offers it again.')
	assert_eq(next.reach, 3, 'and it works.')
