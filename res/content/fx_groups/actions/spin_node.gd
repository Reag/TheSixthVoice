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
## `CommonActionUtil.run_attack_and_target_fx`'s single-attack-fxg branch, the one Spin actually takes
## because `RUN_FX_FLAGS.multiple_attack_fxgs` is never passed to `run_system_fxgs` and the branch
## check (`if fx_flags.has(RUN_FX_FLAGS.multiple_attack_fxgs):`, common_action_util.gd:837) is
## therefore false - action_spin.gd's activate() passes no `run_fx_flags` argument at all. Nothing
## else in the census reaches the acting unit's own token. So subclassing BumpNode is not a
## convenience here; it is the seam.
##
## THIS WAS WRONGLY ATTRIBUTED TO AN EMPTY `primary_targets` UNTIL THE SP4 WHOLE-BRANCH REVIEW.
## Spin no longer calls `run_system_fxgs(unit)`; Task 3 changed the call to
## `run_system_fxgs(unit, hostiles)`, so `primary_targets` is the non-empty hostiles array whenever
## Spin catches anyone. The else-branch above is still taken for the reason restated above -
## `multiple_attack_fxgs` is never passed - not because the target list is empty.
##
## WHAT THE NOW NON-EMPTY TARGET LIST ACTUALLY CHANGES FOR fxg_spin, ALL OF IT INERT (confirmed at
## this review). TWO DIFFERENT THINGS ARE BOTH CALLED "target_node" HERE AND MUST NOT BE CONFLATED:
## FxGroup.initialize's own 5th PARAMETER (null before this task, `hostiles[0].token.Bumper` now) is a
## different variable from BumpNode's own `target_node` MEMBER (set below by `set_target_node`, and
## what `start()` actually reads).
##
##   - `average_target_pos` becomes the hostiles' centroid rather than `origin_position`
##     (common_action_util.gd's single-attack-fxg branch averages `target_tiles`, which is non-empty
##     now that `target_units` is), so `FxGroup.initialize` computes a real non-zero `bump_angle`
##     instead of 0 and hands it into the same `set_target_node(bumping_node, bump_angle)` call named
##     above (fx_group.gd:158) - which stores it as BumpNode's `angle` property. Unread: the `start()`
##     override below never references `angle`.
##   - `initialize`'s `target_node` PARAMETER becomes `hostiles[0].token.Bumper` instead of null - but
##     that parameter is never even handed to a BumpNode child: the same call above passes only
##     `bumping_node` and `bump_angle` (fx_group.gd:158). `target_node` is wired only to
##     ArcingProjectile.set_target and Line3DAnchored.set_anchor_nodes (fx_group.gd:161-166), and
##     `fxg_spin.tscn` has neither. So BumpNode's OWN `target_node` member - what `start()`'s
##     `find_facing_node(target_node)` actually reads - is always set from `bumping_node`, i.e. always
##     the ACTING unit's Bumper, in every branch of run_attack_and_target_fx, unaffected by any of
##     this.
##
## Likewise `additional_preamble_time` (`fx_group.gd:152`, distance-scaled by
## `preamble_duration_per_tile`) does not move, because `fxg_spin.tscn` leaves
## `preamble_duration_per_tile` at its default of 0. Recorded because this is exactly what a future
## change to this scene - adding a projectile child, say, or a distance-scaled preamble - would break
## silently.
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
## branch (unit_token.gd:329-333): a 2D sprite keeps its facing in the `facing_angle` shader uniform,
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
## ================== ON THE PRIMROSE IT IS TWO FLIPS, NOT FOUR, AND IT SHOWS ==================
##
## REPORTED, TRACED AND LEFT AS IS (author, 2026-09-19: "the spin FX did not play, if it was even
## created"). It was created, it is wired, and it runs - activate() calls run_system_fxgs and the
## call is pinned by test_spin.gd's test 17. What the player sees is the problem, and the cause is
## the frame's ART, not this file.
##
## "FOUR VIEW FLIPS" above is only true for a frame that HAS A BACK SPRITE. TokenBase.
## create_for_sprite looks for one at a sibling file named `<sprite>_back.png` and sets sprite_back
## to null when there is none (token_base.gd:48-53); TokenCore.get_sprite_back then falls back to the
## FRONT texture (token_core.gd:172). The shader's four quadrants are front-normal, front-mirrored,
## back-mirrored, back-normal (unit_token_facing_func.gdshaderinc) - so with front == back, two of
## the four are duplicates and a full TAU collapses to ONE MIRROR OUT AND ONE BACK. In 0.45 s that
## reads as a twitch, or as nothing at all.
##
## 74 vanilla frames ship a `_back.png`. `mf_primrose_back.png` does not exist, and neither does a
## back sprite for any other frame in this mod except mf_mk2's bombard variant. The fix is art -
## an 80x80 rear view beside mf_primrose.png - and it would improve every time the Primrose turns to
## face a target, not just Spin. Deliberately NOT worked around here: a different FX that reads
## without a back sprite would hide a gap that is real for the whole frame.
##
## Nothing here touches the unit's TRUE facing: `state.current_facing` is never written, and the last
## thing the tween does is put the visual back exactly where it found it.
##
## ================== WHY THE SCENE IS SHAPED THE WAY IT IS (fxg_spin.tscn) ==================
##
## Relocated here from fxg_spin.tscn's own comments (SP4 Task 4 fix wave): Godot re-serialises a
## scene from the in-memory tree on save, and comments are not part of that tree, so the first
## inspector edit on the scene - e.g. tuning preamble_duration - silently deletes anything written
## there. This is the durable copy.
##
## -- preamble_mode is DURATION (2), not BASIC_CHILDREN_FINISHED (1) --
## The root's preamble_duration (0.45) matches SPIN_DURATION below, so the saves land as the mech
## comes back round rather than while it is still turning. This is the vanilla idiom for a system
## activation: fxg_base_activation.tscn, the DEFAULT_ACTIVATE_FXG this scene displaces, is also
## preamble_mode 2, with preamble_duration 0.5.
##
## NOT BASIC_CHILDREN_FINISHED, which would also wait for the bump and would read as the more honest
## wiring. A timer cannot hang on a bail: start() below returns without emitting `finished` when it
## cannot find a token, exactly as vanilla's own BumpNode bails (bump_node.gd:45, :54), and under
## mode 1 that would stall the preamble - and therefore the whole activation - until MAX_EFFECT_TIME
## fires at 10 s (fx_group.gd:25).
##
## THAT ONLY EXPLAINS THE BAIL CASE, THOUGH - DURATION mode does not avoid MAX_EFFECT_TIME either.
## Traced further: fx_group.gd's DURATION timer connects its timeout to
## `emit_signal.bind(&'preamble_finished')` rather than to `emit_finished_preamble()`
## (fx_group.gd:260), so `is_preamble_finished` is never set to true, and `check_if_finished`'s
## DURATION clause (`preamble_mode != PREAMBLE_MODE.DURATION or is_preamble_finished`,
## fx_group.gd:439) is therefore never satisfied. So EVERY fxg_spin instance - bail or no bail -
## is freed only by the MAX_EFFECT_TIME timer, ten seconds later. This is vanilla-wide, not a defect
## introduced here: fxg_base_activation.tscn has the identical preamble_mode/preamble_duration shape
## and the same fate. Recorded so DURATION mode is not mistaken for a fix specific to the bail case.
##
## -- why `core` on the BumpCore sub-resource may not be null, even though start() is overridden --
## fxg_spin.tscn's BumpCore sub-resource sets distance = 0. This script overrides start() and never
## reads `core`, so every field on it is inert to us here - but `core` may not be NULL: FxGroup.
## scale_bumps calls `bumpnode.core.duplicate()` unguarded on every BumpNode child
## (fx_group.gd:189-191), and vanilla's own BumpNode.start dereferences it at bump_node.gd:45.
## distance = 0 states the intent for a reader who deletes this override: the fallback behaviour is
## "no positional bump", not a lurch.
##
## -- why there are no particles or SFX --
## The card is a mech whipping round on the spot; the sprite IS the effect (see "WHAT IT LOOKS LIKE"
## above for what four quadrant flips in under half a second look like). Anything added would be
## decorating a motion nobody has judged yet - the author's eye through the FX tester is this task's
## acceptance, not a spec (ruling 20).
##
## -- the scene's shape --
## Structurally the smallest thing that can reach the acting unit's own token: one FxGroup root, one
## BumpNode child holding the BumpCore above. fxg_lock_on.tscn is vanilla's precedent for that same
## root + BumpNode + BumpCore skeleton - it is not itself a two-node scene (it also carries an
## SfxEmitter and a GPUParticles3D), but the FxGroup/BumpNode/BumpCore shape is the same one.
extends BumpNode

## One full turn. Short enough to read as a whip rather than a pirouette; the four quadrant flips
## above mean anything much longer reads as a stutter. Tuned by eye in the FX tester, which
## hot-reloads - edit, save, alt-tab back.
##
## KEPT IN STEP BY HAND with fxg_spin.tscn's `preamble_duration` (currently 0.45) - nothing in code
## enforces the pairing. A mismatch is not a crash, just a beat (the saves resolving) landing early
## or late relative to the spin; cosmetic, not correctness.
const SPIN_DURATION:float = 0.45

func start() -> void:
	# FIRST LINE, EXACTLY AS VANILLA'S BumpNode.start (bump_node.gd:43). This is not a leak: in
	# TEST_MODE `FxGroup.run` calls `finish()` outright before the child census (fx_group.gd:209-211),
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

## The current VISUAL facing, mirroring set_facing_angle's own branch (unit_token.gd:329-333).
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
