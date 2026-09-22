# RAGE's turn-start roll (ruling 7): a hidden, point-free ActionReactionSelf on new_turn at POST that
# rolls a d6 and grants that face's effect, for as long as the buff_rage chip is held.
#
# POST, NOT PRE, AND THAT IS THE WHOLE TIMING. event_turn_start awaits the NEW_TURN PRE reactions at
# :14; `execute` then runs handle_starting_unit at :39, which calls UnitCondition.new_turn_for_statuses
# at :76 - the function that CLEARS START_OF_TURN buffs; only afterwards, at :56, is the NEW_TURN POST
# queue built. Every face chip is until = START_OF_TURN, so one applied at PRE would be wiped by that
# clear in the same event. At POST the previous turn's chip is already gone and the new one survives.
#
# THE FACES ARE A TABLE, AND FIVE OF THEM ARE JUST A BUFF. FACE_CHIPS is written COMPLETE at SP1 Task
# 6, naming ids that Tasks 7, 8, 9, 11 and 12 create one at a time; ContentLibrary.get_buff returns
# null for one that does not exist yet and this script skips it, so a face starts working the moment
# its .tres lands and no edit to this file is needed. Face 4 (Combust) has NO chip - it is an action,
# not a lasting effect - and faces 1, 2 and 4 additionally need something a buff cannot say, which is
# what apply_face_effect is for.
#
# THE d6 GOES THROUGH Dice.roll_d6, which is roll_and_sum({count = 1, dietype = 6}) (dice.gd:90-91),
# so Dice.CHEAT_ROLL_QUEUE feeds it and a spec can fix the face. It is the FIRST pop of the new turn:
# handle_starting_unit's recharge loop rolls a d6 per UN-RECHARGED non-basic gear (:89-91), and
# GearCore.is_recharged defaults true (gear_core.gd:13) with full_repair resetting it (:136), so with
# no recharge_on anywhere on this frame that loop pops nothing.
#
# NO INVENTED STRINGS. The battle-log row is vanilla's own battle.generic_roll.log
# (assets/localization/localizations.csv:489, "Rolled {dice}: [b]{result}[/b]"), the die pops through
# effect_bus.play_d6, and the popcorn is the face chip's OWN name_text() - a row this mod writes.
# action_step_of_mist_and_thunder.gd:72-77 is the same three lines. Face 4 has no chip and therefore
# no popcorn of its own; Combust's activation logs itself.
extends ActionReactionSelf

const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

const RAGE_CHIP := &'buff_rage'

## face -> the standalone buff that face grants. Face 4 (Combust) is deliberately absent: it is an
## action, not a chip.
const FACE_CHIPS:Dictionary[int, StringName] = {
	1: &'buff_rage_decimate_crit',
	2: &'buff_rage_swift',
	3: &'buff_rage_reach',
	5: &'buff_rage_bulwark',
	6: &'buff_rage_hatred',
}

## Decimate's crater (face 1), wired in action_rage_roll.tres. An export rather than a preload,
## because a mod resource preloading another mod resource by absolute res:// path is a hard
## dependency Godot resolves at parse time - and because this is how every vanilla deploy names its
## Frame.
@export var decimate_deployable:Frame

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# "for the rest of the scene": only while the protocol's chip is held.
	return UnitCondition.has_buff(unit, RAGE_CHIP)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return

	var face:int = Dice.roll_d6()
	effect_bus.play_d6(face, unit.tile())
	battle_log.log_tr(&'battle.generic_roll.log', {dice = '1d6', result = face})

	var chip_id:StringName = FACE_CHIPS.get(face, &'')
	if chip_id != &'':
		var chip:Buff = ContentLibrary.get_buff(chip_id)
		# AT FRAME CLOSE THIS IS NO LONGER "NULL IS EXPECTED DURING SP1". That was true while the faces
		# landed one per task against a table written complete at Task 6; every face in FACE_CHIPS now
		# names a shipped buff, so a null here means a renamed or mistyped id and should be LOUD. Left
		# silent it degrades to "that face does nothing" - no log line, no error, and the d6 still
		# rolls, so a player sees RAGE fire and nothing happen.
		#
		# push_warning, and NOT push_error or assert: action_glimmering_armaments.gd:96-102 is this
		# mod's own precedent for exactly this shape. GUT lists push_error in failure_error_types
		# (gut_config.gd:57), so a missing buff would red every OTHER Kit's suite alongside this one,
		# and assert() is stripped from release builds, so it would do nothing at all in a shipped
		# mod. push_warning is visible in the editor and the log without either cost.
		if chip != null:
			apply_buffs(activation, unit, [chip] as Array[Buff])
			# The popcorn is the chip's OWN name, read off the LIVE BuffCore that was just hung -
			# BuffCore.name_text() delegates to Buff.name_text (buff_core.gd:78), which walks
			# Translate.buff's fallback chain. No string is invented here.
			var live:BuffCore = UnitCondition.get_buff(unit, chip_id)
			if live != null: effect_bus.play_text(live.name_text(), unit.tile())
		else:
			push_warning('%s: face %s chip %s is not in the buffs index - the face does nothing.'
				% [context.gear.kit.compcon_id, face, chip_id])

	await apply_face_effect(face, context, activation)

## OVERRIDE POINT for the faces a buff alone cannot express: Decimate lays terrain (Task 7), Swift
## queues a free Boost (Task 8), Reach hangs a SECOND buff (Task 9) and Combust offers an action
## (Task 10). Faces 5 and 6 are entirely their chip and never reach here.
func apply_face_effect(face:int, context:Context, activation:EventCore) -> void:
	match face:
		1: await lay_the_crater(context, activation)
		2: await boost_for_free(context, activation)
		3: hang_the_reliable_companion(context, activation)
		4: await offer_combust(context, activation)

## DECIMATE (ruling 8): "A Burst 1 area around you becomes difficult terrain."
##
## Through the mod's FROZEN shared Terrain helper, which is the Apocalypse Rail's own recipe -
## a Faction.NONE unit built from the frame, spawned with SKIP_ANIMATION, owned through
## UnitAction.set_deployable_owner. THE HELPER RETURNS NULL WHEN THE SPAWN DID NOT LAND (its header
## enumerates three different failures), and this checks it: a crater that is not on the map is not a
## crater, and reading a non-null Unit as success would take a corpse for a laid field.
##
## LAID WHERE THE LEOLETH STANDS AT THE ROLL, which is the card's "around you". The Blast 1 is the
## zone's own range_pattern, centred on the crater, so nothing here computes tiles.
##
## THE NULL BRANCH IS A SILENT RETURN, DELIBERATELY. There is no vanilla event.unit_spawn.failed row
## to log with (assets/localization/localizations.csv carries event.unit_spawn, .desc and .log and
## nothing else), and inventing one would break this sub-project's one-invented-string rule. The
## Vauban's own Terrain.lay caller does the same.
func lay_the_crater(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if decimate_deployable == null: return
	var laid:Unit = await Terrain.lay(activation, SpecificAction.from_context(context), unit.tile(), decimate_deployable)
	if laid == null: return # the spawn did not land; nothing to do and nothing to say

## REACH's second buff (ruling 11). Buff.to is a single StringName (buff.gd:123) and the card's two
## halves are read at two different keys - Buff.TO.ACTION_RANGE by threat_distance
## (action_attack_weapon.gd:187-190) and Buff.TO.WEAPON_TAG by get_weapon_tags (:169) - so one Buff
## cannot carry both. The threat half is the VISIBLE chip in FACE_CHIPS and carries the whole card
## line; this is its hidden companion.
##
## NULL IS SKIPPED for the same reason the chip lookup above skips one: a player whose install is
## missing a resource gets the half that loaded rather than an error.
func hang_the_reliable_companion(context:Context, activation:EventCore) -> void:
	var companion:Buff = ContentLibrary.get_buff(&'buff_rage_reach_reliable')
	if companion == null: return
	apply_buffs(activation, context.unit, [companion] as Array[Buff])

## COMBUST (ruling 12): "Choose a blast 1 area within line of sight and SENSORS."
##
## Offered rather than fired, because the card says CHOOSE. CommonActionUtil.choose_and_use supplies
## AS_FREEBIE and TARGETS_ARE_MANDATORY itself (common_action_util.gd:693-696) and, with exactly one
## option and a player-controlled unit, picks it without raising a menu (:658-659) - so what the
## player sees is Combust's own targeting screen, which they can back out of.
##
## NOT OFFERED AT ALL WHEN NOTHING IS IN RANGE: an empty targeting screen is not a choice. Toe To Toe
## uses the same UnitTargeting guard for the same reason (action_predator_prey_concepts.gd:36 is the
## vanilla precedent). NO SPEC EXERCISES THIS BRANCH, AND THAT IS RECORDED RATHER THAN CONTRIVED:
## Combust's TargetRequirements sets can_target_empty_tiles (the card picks an AREA, not a unit), so
## get_tiles_targetable keeps every in-range in-LOS tile (unit_targeting.gd:84-87) and is empty only
## for a unit that is effectively off the map. The guard is a safety net for a future variant, not a
## live clause - unlike Toe To Toe's, where a weapon's requirements leave the flag false and the list
## really does empty out.
##
## choose_and_use_no_spend: this reaction costs nothing, so there is nothing to defer.
func offer_combust(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	# from_id takes a KIT id and, optionally, an ACTION id (specific_action.gd:68-76). Both are given
	# here, because the core Kit carries five actions and the one-argument form returns
	# gear.get_solo_action(), which on a multi-action Kit is not this one.
	var combust := SpecificAction.from_id(unit, &'cp_hydraulic_excess', &'action_combust')
	if not SpecificAction.is_valid(combust): return
	if UnitTargeting.get_tiles_targetable(combust).is_empty(): return
	await CommonActionUtil.choose_and_use(
		activation,
		SpecificAction.from_context(context),
		[combust] as Array[SpecificAction],
		CommonActionUtil.choose_and_use_no_spend,
	)

## SWIFT (ruling 10): "You may immediately Boost as a free action."
##
## AUTOMATIC. The Berserker's Aggression is the shape - event_gear_activate with AS_FREEBIE and
## SKIP_PLAYER_DECISIONS (action_aggression_berserker.gd:38-45) - AWAITED rather than queued, because
## the card says "immediately" and a queued activation would land after the rest of this roll
## (action_the_lesson_of_the_held_image.gd:37-44 is the awaited form). TARGETS_ARE_MANDATORY is
## dropped: a Boost has no target.
##
## SKIP_PLAYER_DECISIONS IS LOAD-BEARING: action_boost.activate opens with
## CommonActionUtil.confirm_use (action_boost.gd:19-20), which returns true without asking exactly
## when that flag is present (common_action_util.gd:330). Without it the player is asked a yes/no in
## the middle of their own turn-start roll, six times a scene, for an effect with no downside.
##
## AS_FREEBIE IS WHAT MAKES IT FREE: UnitAction.spend wraps the whole action/boost/reaction block in
## `if not as_freebie` (unit_action.gd:242-265), and has_normal_boost = false is inside it (:264-265).
##
## AND can_boost IS STILL CHECKED. UnitAction.can_activate_gear asks is_gear_available at :112, BEFORE
## the freebie short-circuit at :114, and ms_boost's is_available_to_activate is
## UnitAction.can_boost (action_boost.gd:15-16). A Slowed or Immobilized Leoleth simply does not
## Boost, which ruling 10 accepts. The chip has already been applied by the caller either way.
func boost_for_free(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var boost := SpecificAction.from_id(unit, &'ms_boost')
	if not SpecificAction.is_valid(boost): return
	if not UnitAction.can_activate_gear(boost, true): return
	await activation.execute_event(&'event_gear_activate', {
		unit = unit,
		gear = boost.gear,
		action = boost.action,
		flags = [Action.FLAG.AS_FREEBIE, Action.FLAG.SKIP_PLAYER_DECISIONS],
		event = activation, # tell the activation which reaction sent it
	})
