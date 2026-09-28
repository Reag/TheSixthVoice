## GEMINI CHARGE, "this counts as one attack" for the Knot's ONE-TIME ROLL BUFFS (Pass F task 11c, the
## author's report 2026-09-28): every target of a Gemini attack reads the one-time attack-roll buffs the
## Knot held when the attack began, and they are consumed ONCE, after the whole attack.
##
## WHY IT IS NEEDED. The engine rolls each target of a declared attack as its own event_unit_attack, in
## order (event_unit_attack_declared.gd:54-67; event_block.gd:101-107 runs them one after another), and
## each one consumes the one-time buffs its own roll read (roll.pre.applied_buffs,
## event_unit_attack.gd:114) before the next target's roll is even built. Vanilla Core Siphon's +1
## (is_onetime, to = attack_roll) was eaten by the contact's roll, and its on_consumption hung the -1 on
## the Knot at once, so every redirected target read the -1. Vanilla does the same to ANY multi-target
## attack; only an attack Gemini recorded is changed here.
##
## THE SHAPE, both halves in this one effect (handed to the pipeline by buff_gemini_one_attack):
##   on_attack      per target, after its roll and BEFORE its consume_buffs (:69, :111-114): the Knot's own
##                  one-time ATTACK_ROLL / IGNORE_COVER buffs are taken OUT of roll.pre.applied_buffs and
##                  set aside on the DeclaredAttackSummary. PreAttack.create already folded them into this
##                  roll's accuracy and cover, so removing them changes nothing about the roll - only that
##                  this target no longer consumes them, and the next target's PreAttack finds them
##                  still on the Knot and reads them against its OWN target (a target-conditional buff
##                  still decides per target).
##   on_resolution  once, after damage, from the declared attack (event_unit_attack_declared.gd:212-214):
##                  telegraph and consume the set-aside buffs, as the per-target event would have
##                  (event_unit_attack.gd:111-114) - so Core Siphon's -1 lands once, here.
##
## LIVE, NOT A SNAPSHOT: a later target reads the Knot's one-time buffs as they stand when ITS roll is
## built, not a copy of what the contact read. The two differ only if the Knot gains or loses such a buff
## mid-attack (a reaction during an earlier target's roll); then the later target reads the new state.
## Only the KNOT's buffs are deferred (the holder filter): a target's own one-time buffs - Lock On's
## ATTACK_ROLL_INCOMING, a target-held "cannot benefit from cover" IGNORE_COVER - are still consumed by
## that target's own roll.
##
## Ruling 9 is untouched: one d20 face, each target's own accuracy and difficulty. These buffs are simply
## part of each target's own accuracy now.
##
## NOT DEFERRED: DEAL_DOUBLE_DAMAGE (action_attack.gd:80 reads it from applied_buffs at DAMAGE time, so
## removing it would drop the doubling); the target's own ATTACK_ROLL_INCOMING (Lock On is per target);
## one-time MODIFY_ATTACK_ROLL and ONHIT_EFFECT buffs (consumed inside the step check and from a local
## array, event_unit_attack.gd:115, :383 - no seam). The declared attack reaches on_resolution unless the
## Knot is gone (:68) or the level exits, when nothing is left to consume for.
extends OnHitEffect

const Record := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_lovers_knot/cp_integrated_redirection_aggregate/gemini_record.gd')

## Buff.TO channels PreAttack.create folds into the roll itself (attack_roll.gd:131-135, :182-188).
const DEFERRED_TO:Array[StringName] = [Buff.TO.ATTACK_ROLL, Buff.TO.IGNORE_COVER]

func on_attack(activation:EventCore, _attacked_unit:Unit) -> void:
	var context:Context = activation.context
	var summary = context.resource
	if Record.record_of(summary).is_empty() or not (context.object is AttackRoll): return
	var knot:Unit = context.unit.get_attacker(context)
	var roll:AttackRoll = context.object
	var deferred:Array[BuffCore] = deferred_of(summary)
	var kept:Array[BuffCore] = []
	for buff:BuffCore in roll.pre.applied_buffs:
		if buff.base.is_onetime and DEFERRED_TO.has(buff.base.to) and buff.get_holder_unit(context.map) == knot:
			Util.append_nonduplicate(deferred, buff)
		else:
			kept.append(buff)
	roll.pre.applied_buffs = kept
	summary.set_meta(Record.DEFERRED_BUFFS, deferred)

func on_resolution(activation:EventCore) -> void:
	var summary = activation.context.resource
	var deferred:Array[BuffCore] = deferred_of(summary)
	if deferred.is_empty(): return
	summary.remove_meta(Record.DEFERRED_BUFFS)
	await UnitCondition.telegraph_relevant_buffs(activation, deferred)
	UnitCondition.consume_buffs(activation, deferred)

static func deferred_of(summary) -> Array[BuffCore]:
	var deferred:Array[BuffCore] = []
	if DeclaredAttackSummary.is_valid(summary) and summary.has_meta(Record.DEFERRED_BUFFS):
		deferred.assign(summary.get_meta(Record.DEFERRED_BUFFS))
	return deferred
