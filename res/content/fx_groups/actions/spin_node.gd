## FLOURISHING TWIRL, SPIN - the use-FX's bump node (Primrose rank III, SP4 Task 4).
##
##   "Spin (Quick): Choose a weapon you have mounted, all hostile characters within its threat and
##    line of sight must succeed an Agility save or take 4 kinetic damage and become Impaired until
##    the end of their next turn."
##   (specs/sixth-voice/07-primrose.md, Rank III, "System: Flourishing Twirl")
##
## The card is a mech whipping round on the spot, so the FX is exactly that and nothing else: one
## full turn of the sprite's FACING, over SPIN_DURATION, ending back where it started.
##
## ================== WHY A BumpNode AND NOT A PARTICLE EMITTER ==================
##
## A BumpNode is the only child type FxGroup hands the TOKEN to. `FxGroup.initialize` walks its
## children and calls `child.set_target_node(bumping_node, bump_angle)` for every `child is BumpNode`
## (fx_group.gd:158), where `bumping_node` is `user.token.Bumper` - the caller passes it in from
## `CommonActionUtil.run_attack_and_target_fx` (common_action_util.gd:839, :842). Nothing else in the
## census reaches the acting unit's own token. So subclassing BumpNode is not a convenience here; it
## is the seam.
##
## ================== target_node IS THE Bumper, NOT THE TOKEN ==================
##
## `Bumper` is a CHILD of the UnitToken ("bounce the sprite when we want attention // BumpNode pushes
## around", unit_token.gd:41, fetched at :94), and `set_facing_angle` lives on the UnitToken itself
## (:327). So the token is found by walking UP from target_node, not by casting it. The walk is by
## `has_method(&'set_facing_angle')` rather than `is UnitToken` deliberately: the FX tester builds
## real UnitTokens (ui/page/fx_group_tester/tester_world.gd:13-14, :27-28) but a future caller
## handing us any node that can face a direction should just work, and a bad guess should be a quiet
## no-op rather than a crash inside an FX.
##
## ================== THE FACING IS READ BACK, NOT ASSUMED ==================
##
## There is no getter for the current facing on UnitToken, so read_facing mirrors the SETTER's own
## branch (unit_token.gd:329-332): a 2D sprite keeps its facing in the `facing_angle` shader uniform,
## a 3D mesh in TokenMesh.rotation.y. Reading `state.current_facing` instead would be wrong in the
## one place a human will actually watch this - the FX tester sets the target token's facing with
## `set_facing_angle(PI)` and never touches its state (tester_world.gd:34-35), so the two disagree
## there by a half turn, and the restore below would silently re-aim the token.
##
## ================== WHAT IT LOOKS LIKE, SO NOBODY FILES IT AS A BUG ==================
##
## The facing is a shader uniform and the sprite shows front, back or a mirror per quadrant
## (assets/shaders/unit_token.gdshader:20), so a full turn reads as FOUR VIEW FLIPS in under half a
## second - the engine's idiom for a mech whipping round, not a smooth 3D rotation. That is the
## intended look.
##
## Nothing here touches the unit's TRUE facing: `state.current_facing` is never written, and the last
## thing the tween does is put the visual back exactly where it found it.
extends BumpNode

## One full turn. Short enough to read as a whip rather than a pirouette; the four quadrant flips
## above mean anything much longer reads as a stutter. Tuned by eye in the FX tester, which
## hot-reloads - edit, save, alt-tab back.
const SPIN_DURATION:float = 0.45

func start() -> void:
	# FIRST LINE, EXACTLY AS VANILLA'S BumpNode.start (bump_node.gd:43). This is not a leak: in
	# TEST_MODE `FxGroup.run` calls `finish()` outright before the child census (fx_group.gd:207-209),
	# which emits `all_effects_finished` and sets `is_finished`, so the `live_bump_count` this bump
	# would otherwise decrement no longer gates anything. Deliberately does NOT emit `finished` in
	# TEST_MODE - vanilla does not either, and matching vanilla is the point (ruling 20).
	#
	# THE GUARD IS REALLY EXERCISED, AND IS REALLY NOT LOAD-BEARING - both measured at Task 4 rather
	# than assumed. Instrumented, start() is reached 12 times in one test_spin.gd run, every one of
	# them TEST_MODE=true, in-tree, with target_node = a Bumper: so run_system_fxgs, FxGroup.run and
	# activate_bump all execute under a spec and this line is the only thing stopping the tween.
	# Deleted, test_spin.gd is still 16/16 on the identical 105 asserts in 5.78 s against 5.80 s -
	# no red, no hang, no measurable cost. Kept for the vanilla match, not for the suite.
	if X.TEST_MODE: return

	# create_tween() needs us in the tree; vanilla guards the same way at bump_node.gd:48.
	if not is_inside_tree(): return
	if not is_instance_valid(target_node): return

	var token:Node3D = find_facing_node(target_node)
	if token == null: return # bail quietly: an FX that cannot find its token is not an error

	var start_angle:float = read_facing(token)

	var tween:Tween = create_tween()
	# tween_method rather than tween_property: `facing_angle` is not a property of anything - it is an
	# argument to a setter that writes a shader uniform (unit_token.gd:331 -> :308-312).
	tween.tween_method(
		func(angle:float) -> void:
			# Re-checked every frame: the token can be freed mid-spin (the unit dies to a reaction the
			# same activation fired) while the tween keeps ticking on this node.
			if is_instance_valid(token): token.set_facing_angle(angle),
		start_angle, start_angle + TAU, SPIN_DURATION
	)
	tween.finished.connect(func() -> void:
		# Land exactly on the start angle rather than on start + TAU. Numerically the same facing, but
		# the uniform is what the next reader sees and a drifting value would accumulate over repeats.
		if is_instance_valid(token): token.set_facing_angle(start_angle)
		# LOAD-BEARING OUTSIDE TEST_MODE, AND NO SPEC CAN PROTECT IT (ruling 20 - the FX tester is the
		# acceptance). `FxGroup.activate_bump` increments `live_bump_count` and connects to this signal
		# (fx_group.gd:361-364); a bump that never emits it leaves the whole group alive until its
		# MAX_EFFECT_TIME timer fires at 10 s (fx_group.gd:25, :216-222). MEASURED at Task 4: deleted,
		# test_spin.gd is 16/16 on the identical 105 asserts - the guard above returns long before
		# this closure is ever built, so no spec can ever reach it.
		finished.emit()
	)

## Walk UP from the Bumper to the first ancestor that can be faced - see the header for why the
## target_node we are handed is not itself the token.
func find_facing_node(from:Node3D) -> Node3D:
	var node:Node = from
	while node != null:
		if node.has_method(&'set_facing_angle') and node is Node3D: return node
		node = node.get_parent()
	return null

## The current VISUAL facing, mirroring set_facing_angle's own branch (unit_token.gd:329-332).
## Returns 0.0 when the token is shaped in some way this does not recognise, which costs a wrong
## starting quadrant and nothing else - the spin still turns a full TAU and still restores.
func read_facing(token:Node3D) -> float:
	var token_mesh = token.get(&'TokenMesh')
	if not (token_mesh is MeshInstance3D): return 0.0
	if token_mesh.mesh == token.get(&'mesh_quad'): # a 2D sprite: the uniform is the truth
		var material = token.get(&'mesh_quad_material')
		if material is ShaderMaterial:
			var value = material.get_shader_parameter(&'facing_angle')
			if value is float: return value
		return 0.0
	return token_mesh.rotation.y # a 3D mesh
