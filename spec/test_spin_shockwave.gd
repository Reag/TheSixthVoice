# SPIN'S SHOCKWAVE (Primrose rank III, Flourishing Twirl). Author request, 2026-09-20:
#
#   "add an additional 'shockwave' style effect in the affected area, emanating out from the user
#    and traveling the threat range. I think it would tie the whole capstone ability together."
#
# Design: lancer-tactics-claude/specs/2026-09-20-spin-shockwave-fx-design.md
#
# RULING 20 STILL HOLDS: nothing here asserts anything about how the wave LOOKS - not its duration,
# not its colour, not whether it reads as a wave at all. The author's eye through the FX tester is
# the acceptance for every one of those. What IS in here is wiring, arithmetic and one call site:
# claims about the source, which the screen cannot be asked about and a spec can.
#
# KEPT OUT OF test_spin.gd ON PURPOSE. That file's 17 tests are the control for this change - if any
# of them moves, the activation changed in a way it should not have. Mixing new tests in would
# destroy the only clean signal available.
extends GutTest

const SHOCKWAVE_SCENE := 'res://unpacked/Reag-TheSixthVoice/res/content/fx_groups/actions/fxg_shockwave.tscn'

## The radius arithmetic, with no game in the way. One tile is 1.0 world unit in X/Z (Tile.SIZE),
## and the scene's QuadMesh is 2x2, so a particle at scale S draws a ring of RADIUS S tiles. The
## mesh size was picked to make this a straight assignment; if someone changes it, this test is what
## notices.
func test_set_radius_in_tiles_scales_the_emitter() -> void:
	var fxg:Node = load(SHOCKWAVE_SCENE).instantiate()
	autofree(fxg)
	var ring:Node = fxg.get_node('Ring')
	assert_not_null(ring, 'the scene has a Ring node.')
	if ring == null: return

	ring.set_radius_in_tiles(4)
	assert_eq(ring.process_material.scale_min, 4.0, 'a threat-4 weapon gives a 4-tile ring.')
	assert_eq(ring.process_material.scale_max, 4.0, 'and it does not vary between particles.')

## THE SHARED SUB-RESOURCE TRAP, pinned. A ParticleProcessMaterial set in a PackedScene is shared by
## every instance unless it is duplicated, so writing the scale straight onto it would make the last
## Spin's radius apply to every ring already on screen. Wickworks hit the identical defect in
## line_3d_anchored.gd:52 ("they were all sharing the same array"). Two instances, two radii, and
## neither may move the other.
func test_two_rings_do_not_share_a_process_material() -> void:
	var first:Node = load(SHOCKWAVE_SCENE).instantiate()
	autofree(first)
	var second:Node = load(SHOCKWAVE_SCENE).instantiate()
	autofree(second)

	first.get_node('Ring').set_radius_in_tiles(1)
	second.get_node('Ring').set_radius_in_tiles(5)

	assert_eq(first.get_node('Ring').process_material.scale_min, 1.0,
		'the first ring kept its own radius after the second was sized.')
	assert_eq(second.get_node('Ring').process_material.scale_min, 5.0,
		'and the second got the radius it asked for.')

## A radius of zero or less is not a ring, and must not become one. Spin cannot reach this today -
## collect_mounted_profiles only yields weapons with printed threat above zero - but the method is
## public and the next caller will not know that.
func test_a_non_positive_radius_is_refused() -> void:
	var fxg:Node = load(SHOCKWAVE_SCENE).instantiate()
	autofree(fxg)
	var ring:Node = fxg.get_node('Ring')

	ring.set_radius_in_tiles(3)
	ring.set_radius_in_tiles(0)
	assert_eq(ring.process_material.scale_min, 3.0, 'a zero radius leaves the last good one alone.')
	ring.set_radius_in_tiles(-2)
	assert_eq(ring.process_material.scale_min, 3.0, 'and so does a negative one.')

# ================================================================ the per-unit impact pop

## NO CODE MAKES THIS FIRE, which is exactly why it needs a wiring test. run_attack_and_target_fx's
## `if fxg_target:` block loops every target unit unconditionally (common_action_util.gd:872-877), so
## the only two things that can go wrong are the resource losing the scene and Task 3's call losing
## its `hostiles` argument. This test covers the first; test_activate_passes_the_hostiles_to_the_fx
## covers the second.
func test_the_spin_action_carries_an_impact_fx() -> void:
	var kit:Kit = ContentLibrary.get_kit(&'ms_flourishing_twirl')
	assert_not_null(kit, 'the kit loads.')
	if kit == null: return
	var action = kit.get_action(&'action_spin')
	assert_not_null(action, 'action_spin is on the kit.')
	if action == null: return

	assert_not_null(action.fxg_target, 'Spin carries a target-FX for the units it catches.')
	if action.fxg_target == null: return
	assert_true(action.fxg_target.resource_path.ends_with('fxg_spin_impact.tscn'),
		'And it is fxg_spin_impact.tscn: %s' % action.fxg_target.resource_path)

## The preamble is AWAITED before the saves roll (common_action_util.gd:879-882), so every millisecond
## here is dead air between the wave and the first die. Pinned low rather than left to drift.
func test_the_impact_fx_does_not_stall_the_saves() -> void:
	const IMPACT_SCENE := 'res://unpacked/Reag-TheSixthVoice/res/content/fx_groups/actions/fxg_spin_impact.tscn'
	var fxg:Node = load(IMPACT_SCENE).instantiate()
	autofree(fxg)
	assert_lt(fxg.preamble_duration, 0.2,
		'the impact preamble is short - it is awaited before the first save is rolled.')

# ================================================================ the call sites

## THE SAME KIND OF PIN AS test_spin.gd's TEST 17, AND FOR THE SAME REASON. Test 16 there records
## that wiring fxg_use is inert without the call, and that action_glimmering_armaments.gd sat in
## exactly that state for three sub-projects with an FX nobody ever saw. fire_shockwave is a second
## line with the same property: delete it and every behavioural test in this mod stays green while
## the screen loses the wave.
##
## RULING 20 IS NOT BREACHED - this asserts that a call exists, which is a claim about the source,
## not about the animation.
const SPIN_SOURCE := 'res://unpacked/Reag-TheSixthVoice/res/content/gear/ssc/systems/ms_flourishing_twirl/action_spin.gd'

## The body of activate(), non-comment lines only. Scoped the way test_spin.gd's test 17 scopes its
## own: the calls below are named in comments several times over, so a bare contains() would stay
## green with the statement deleted or commented out.
func activate_body_lines() -> Array[String]:
	var src := FileAccess.get_file_as_string(SPIN_SOURCE)
	assert_false(src.is_empty(), 'The action\'s source reads back.')
	if src.is_empty(): return []
	# SCOPED TO activate()'S BODY AND NO FURTHER. substr(find('func activate(')) alone runs to the
	# END OF THE FILE, and that silently defeats the fire_shockwave pin below: fire_shockwave's own
	# DEFINITION line sits under activate() and contains 'fire_shockwave(', so the pin would match
	# its own definition and stay green with the call site deleted. Caught by Task 3's mutation step,
	# where mutation 1 reddened only the ordering test - the pin was asserting nothing. The body
	# therefore ends at the next top-level func.
	#
	# test_spin.gd's test 17 uses the unbounded form and is CORRECT to: it searches for
	# 'await run_system_fxgs(', which never appears as a definition in that file. Do not "fix" it.
	var body:String = src.substr(src.find('func activate('))
	var next_func:int = body.find('\nfunc ', 1)
	if next_func > 0: body = body.substr(0, next_func)
	var code_lines:Array[String] = []
	for line:String in body.split('\n'):
		var code := line.strip_edges()
		if code.begins_with('#'): continue
		code_lines.append(code)
	return code_lines

func test_activate_actually_fires_the_shockwave() -> void:
	var called := false
	for code:String in activate_body_lines():
		if code.contains('fire_shockwave('): called = true
	assert_true(called,
		'activate() really calls fire_shockwave - without it the ring never plays, however wired.')

## The pops only draw because run_system_fxgs is handed a non-empty target list: the engine's
## `if fxg_target:` loop iterates target_units (common_action_util.gd:872-877), and Spin used to pass
## none. A bare run_system_fxgs(unit) leaves test_the_spin_action_carries_an_impact_fx green and
## draws nothing.
func test_activate_passes_the_hostiles_to_the_fx() -> void:
	var passed := false
	for code:String in activate_body_lines():
		if code.contains('run_system_fxgs(unit, hostiles)'): passed = true
	assert_true(passed,
		'run_system_fxgs is handed the hostiles, which is what makes the impact pops draw.')

## ORDER, NOT JUST PRESENCE. The wave has to be thrown before the FX is awaited, and both have to sit
## BELOW spend_actions - a mech that spins and shocks for a cancelled prompt is a lie about what the
## action cost, which is ruling 4 and what test_spin.gd's cancel tests hold from the other side.
func test_the_shockwave_is_thrown_after_the_spend_and_before_the_await() -> void:
	var spend_at := -1
	var fire_at := -1
	var await_at := -1
	var lines := activate_body_lines()
	for i:int in lines.size():
		if spend_at < 0 and lines[i].contains('spend_actions('): spend_at = i
		if fire_at < 0 and lines[i].contains('fire_shockwave('): fire_at = i
		if await_at < 0 and lines[i].contains('await run_system_fxgs('): await_at = i

	assert_gt(spend_at, -1, 'spend_actions is in activate().')
	assert_gt(fire_at, spend_at, 'the wave is thrown AFTER the action is paid for.')
	assert_gt(await_at, fire_at, 'and before the FX await, so the ring is already travelling.')
