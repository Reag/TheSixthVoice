# OVERSHIELD "GRANTED BY" FROM ANY SOURCE (playtest finding, 2026-09-29; ruling 5 widened by the author).
#
# The finding: a Black Mountain carrying the GMS Micro-Maintenance Suite (Reag-CrisisCoreCatalogEvolved)
# shielded its allies, and An End to All Things never fired for them. The mark it gates on was hung only
# by the shared helper's grant_by / increase_by, so a vanilla or another mod's grant - a plain
# event_unit_overshield fired from inside a gear activation - carried none. The card says "OVERSHIELD
# you granted", with no restriction on the source.
#
# The fix is res/content/events/event_unit_overshield.gd_ext.gd: every Overshield event credits the
# gear whose ACTIVATION it runs inside (the nearest event_gear_activate ancestor block). A buff
# activation between them is a boundary - a buff's grant is its owner's, and our buffs name that owner
# through grant_by / increase_by already.
#
# WHAT THIS FILE PROVES: vanilla's Aceso Stabilizer used by the Black Mountain marks the ally; the
# Micro-Maintenance Suite does too, and An End to All Things then fires - the playtest case, end to end;
# an ALLY's Aceso does not credit the Black Mountain; a grant outside any activation marks nobody; a
# foreign grant onto an EMPTY shield whose mark went stale does not re-credit the old granter; and the
# extension runs at all (its behaviour is the only way the first test can pass).
#
# The Micro-Maintenance Suite is another of our mods, loaded whenever its checkout is in unpacked/;
# its tests are PENDING, not failed, when it is absent.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_overshield_granted_by_any_source.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const ACESO := &'ms_aceso_stabilizer'
const MM_SUITE := &'ms_mm_suite'

const BM_TILE := Vector2i(4, 4)
const ALLY_TILE := Vector2i(6, 4)
const OTHER_ALLY_TILE := Vector2i(6, 6)
const HOSTILE_TILE := Vector2i(10, 4)
const ALWAYS_HIT := -10
const RIFLE_DIE := 4
const BONUS := 3

var game:Gamemaster
var responder
var black_mountain:Unit
var ally:Unit
var other_ally:Unit
var hostile:Unit

func before_each() -> void:
	var pair := Fixture.create_game_with_prompt_queues(self)
	game = pair[0]
	responder = pair[1]
	black_mountain = Fixture.create_black_mountain(game, BM_TILE)
	ally = Fixture.create_ally(game, ALLY_TILE)
	other_ally = Fixture.create_ally(game, OTHER_ALLY_TILE)
	hostile = Fixture.create_hostile(game, HOSTILE_TILE, ALWAYS_HIT)

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()

func has_mm_suite() -> bool: return Kit.is_valid(ContentLibrary.get_kit(MM_SUITE))

## `user` activates a one-action shield system on `target`, its turn opened first (both are QUICK).
func shield(user:Unit, kit_id:StringName, target:Unit) -> void:
	Fixture.equip(user, kit_id)
	await Fixture.open_turn(game, user)
	await SpecFactory.use_solo(game, user, kit_id, target)

# ---------------------------------------------------------------- vanilla

func test_the_black_mountains_aceso_stabilizer_marks_the_ally() -> void:
	await shield(black_mountain, ACESO, ally)
	assert_gt(Overshield.current(ally), 0, 'fixture: the Aceso Stabilizer shielded the ally.')
	assert_true(Overshield.is_granted_by(ally, black_mountain),
		'A plain vanilla grant from the Black Mountain\'s own gear is Overshield it granted.')

func test_an_allys_aceso_stabilizer_does_not_credit_the_black_mountain() -> void:
	await shield(other_ally, ACESO, ally)
	assert_gt(Overshield.current(ally), 0, 'fixture: shielded.')
	assert_false(Overshield.is_granted_by(ally, black_mountain), 'Somebody else granted it.')
	assert_true(Overshield.is_granted_by(ally, other_ally), 'The ally that granted it is credited.')

func test_a_grant_outside_any_activation_marks_nobody() -> void:
	await Fixture.grant_overshield(ally, 3)
	assert_eq(Overshield.current(ally), 3, 'fixture: shielded.')
	assert_eq(UnitCondition.get_buffs(ally, Fixture.GRANTED_BY_MARK).size(), 0,
		'No activation to credit, so no mark.')

func test_a_foreign_grant_onto_an_empty_shield_does_not_re_credit_a_stale_mark() -> void:
	await Fixture.grant_overshield_by(black_mountain, ally, 3)
	assert_true(Overshield.is_granted_by(ally, black_mountain), 'fixture: marked.')
	# Zero the shield the way the two vanilla paths that skip LOSE_OVERSHIELD do: no clear.
	ally.state.overshield = 0
	await shield(other_ally, ACESO, ally)
	assert_gt(Overshield.current(ally), 0, 'fixture: shielded again.')
	assert_false(Overshield.is_granted_by(ally, black_mountain),
		'The stale Black Mountain mark is cleared before a foreign grant lands on an empty shield.')

# ---------------------------------------------------------------- the playtest case

func test_the_black_mountains_micro_maintenance_suite_marks_the_ally() -> void:
	if not has_mm_suite():
		pending('Reag-CrisisCoreCatalogEvolved is not unpacked.')
		return
	await shield(black_mountain, MM_SUITE, ally)
	assert_eq(Overshield.current(ally), 3, 'fixture: the Suite granted 3.')
	assert_true(Overshield.is_granted_by(ally, black_mountain), 'Another mod\'s grant counts too.')

func test_an_end_to_all_things_fires_for_an_ally_the_suite_shielded() -> void:
	if not has_mm_suite():
		pending('Reag-CrisisCoreCatalogEvolved is not unpacked.')
		return
	await shield(black_mountain, MM_SUITE, ally)
	Fixture.arm_rifle(ally)
	Fixture.queue([RIFLE_DIE, RIFLE_DIE, RIFLE_DIE, RIFLE_DIE])
	await Fixture.shoot(game, ally, hostile)
	assert_eq(Fixture.heat(black_mountain), 1, 'The Black Mountain paid 1 heat.')
	assert_eq(200 - Fixture.health(hostile), RIFLE_DIE + BONUS, 'The hostile took the rifle plus 3.')
