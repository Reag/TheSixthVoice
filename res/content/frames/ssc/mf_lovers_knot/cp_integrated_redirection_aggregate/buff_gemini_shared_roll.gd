## GEMINI CHARGE, "one attack roll": each redirected target gets the contact's d20 FACE with its OWN
## accuracy and difficulty (ruling 9, the author's reading - it supersedes the spike's one-total).
##
## ONE PERMANENT HIDDEN BUFF ON THE KNOT answers all three steps of every redirected target's roll
## sequence (event_unit_attack.gd:142-183). It stands down for anything buff_gemini_charge did not
## record on the declared attack, so it needs no lifetime of its own. It is one buff, not three:
## three would collide on apply_buff_alt's same-id/same-to/same-until replacement. It is not
## one-time: check_buffs_for_step consumes what it uses, and consume_buffs keeps non-one-time buffs.
##
##   auto_miss   First the cover (ruling 10): the engine measured it from the Knot, and
##               buff_gemini_ignore_cover has already suppressed that, so the cover measured from the
##               leg's start goes on here - honouring the target's own "cannot benefit from cover" buffs
##               and a weapon that ignores cover, as PreAttack.create would (attack_roll.gd:153-169).
##               Then, only if the contact rolled a d20: invisibility, asked HERE because the engine asks
##               it only after auto_hit (:148-163) (ruling 11); then the shared face plus this target's
##               own dice. A miss is answered here.
##   auto_hit    A hit is answered here. (A weapon immune to auto-misses skips auto_miss - the NPC
##               Sniper's rifle only, ruling 16a - so the cover is also put on here if still missing, and
##               the target then rolls its own d20.)
##   turn_hit_to_crit   A total of 20 or more crits, if the weapon can; CRIT_IMMUNITY still demotes
##               (:222).
##
## The decision is made once per roll and cached on it. confirm_modification is not told the step, so
## check_if_passive_applies stamps it on the roll just before - check_buffs_for_step always asks one
## then the other, for the same step (:360-385).
extends BuffModifyAttackRoll

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

const STEP_META:StringName = &'reag_gemini_step'
const DECISION_META:StringName = &'reag_gemini_decision'
const COVER_META:StringName = &'reag_gemini_cover'
enum DECISION { MISS, HIT, CRIT }

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var holder:Unit = core.get_holder_unit(context.map)
	if not Unit.is_valid(holder) or context.unit != holder: return false
	var roll = context.object
	if not (roll is AttackRoll) or context.event == null: return false
	if not Record.is_redirected(context.event.context.resource, context.target_unit): return false
	var applies := false
	match context.category_int:
		EventUnitAttack.SEQUENCE_STEP.auto_miss:
			applies = not roll.has_meta(DECISION_META)
		EventUnitAttack.SEQUENCE_STEP.auto_hit:
			applies = not roll.has_meta(COVER_META) or roll.get_meta(DECISION_META, DECISION.MISS) != DECISION.MISS
		EventUnitAttack.SEQUENCE_STEP.turn_hit_to_crit:
			applies = roll.get_meta(DECISION_META, DECISION.MISS) == DECISION.CRIT
	if applies: roll.set_meta(STEP_META, context.category_int)
	return applies

func confirm_modification(_core:BuffCore, roll:AttackRoll, activation:EventCore) -> bool:
	var context:Context = activation.context
	var summary = context.resource
	if not roll.has_meta(COVER_META):
		add_leg_cover(roll, context, summary)
		roll.set_meta(COVER_META, true)

	match roll.get_meta(STEP_META, -1):
		EventUnitAttack.SEQUENCE_STEP.auto_miss:
			var face := Record.face_of(summary)
			if face <= 0: return false # the contact rolled no d20: this target rolls its own
			var forced_miss := await AttackUtil.check_if_invisibility_forces_miss(activation)
			if activation.abort_without_units([context.unit, context.target_unit]): return false
			if forced_miss:
				roll.roll_modifications.append(&'invisibility')
				roll.set_meta(DECISION_META, DECISION.MISS)
				return true
			roll.base_roll = face
			roll.accuracy_roll = Dice.roll_d6_accuracy(roll.pre.accuracy_mods_total())
			roll.total_roll = face + roll.accuracy_roll + roll.pre.flat_bonus
			var hit:bool = roll.total_roll >= roll.pre.target_defense
			var crit:bool = hit and roll.total_roll >= 20 and context.action.can_crit(context)
			roll.set_meta(DECISION_META, DECISION.CRIT if crit else DECISION.HIT if hit else DECISION.MISS)
			print('     gemini shared face : %s   (+ acc %s)   against %s' % [roll.total_roll, roll.accuracy_roll, roll.pre.target_defense])
			return not hit
		EventUnitAttack.SEQUENCE_STEP.auto_hit:
			return roll.get_meta(DECISION_META, DECISION.MISS) != DECISION.MISS
		EventUnitAttack.SEQUENCE_STEP.turn_hit_to_crit:
			return roll.get_meta(DECISION_META, DECISION.MISS) == DECISION.CRIT
	return false

## Cover measured from the leg's own start (ruling 10), as PreAttack.create measures it from the
## attacker. The engine's cover from the Knot never reached this roll: buff_gemini_ignore_cover
## suppressed it. Every gate PreAttack.create applies is applied here too (attack_roll.gd:131, :154-161):
## the weapon's own ignores_cover, the Knot's attacker-side IGNORE_COVER - Gunslinger III, See Through
## Seeker - OTHER than Gemini's own suppressor, and the target's refusal.
static func add_leg_cover(roll:AttackRoll, context:Context, summary) -> void:
	var action = context.action
	if not (action is ActionAttackWeapon) or action.ignores_cover(context): return
	var target:Unit = context.target_unit
	var knot:Unit = context.unit.get_attacker(context)
	var knot_ignores:Array[BuffCore] = UnitCondition.get_buffs_to(knot, Buff.TO.IGNORE_COVER, context)
	Util.filter(knot_ignores, func(core:BuffCore) -> bool: return core.base.compcon_id != Record.GEMINI_IGNORE_COVER)
	if not knot_ignores.is_empty():
		roll.pre.applied_buffs.append_array(knot_ignores)
		return
	var result := CoverCalculator.determine_cover(target, knot, Record.leg_start_voxels(summary, target))
	var refusing := UnitCondition.get_buffs_to(target, Buff.TO.IGNORE_COVER, Context.clone(context, {category = result.total}))
	roll.pre.applied_buffs.append_array(refusing)
	if not refusing.is_empty(): result.total = Lancer.COVER.NONE
	roll.pre.cover_sources = result.sources
	roll.pre.cover = result.total
	if result.total != Lancer.COVER.NONE:
		roll.pre.add_mod(Lancer.cover_name(result.total), Lancer.cover_modifier(result.total), Icon.cover(result.total), false)
