# ZWARTE HOOP's spend (design rulings 9, 12, 13) - and, drawn on the card, the passive itself.
#
#   "On your first attack roll each round, you may expend any number of charges. For each charge
#    expended choose one of the following options: [...] You may choose the same option up to twice"
#
# ATTACK_DECLARED PRE, ON THE PIER'S OWN ATTACK. After targeting and spending, before every read that
# matters: Reliable at event_unit_attack_declared.gd:82, the attack-roll buffs at PreAttack.create
# (event_unit_attack.gd:53), knockback in on_hit, the on-hit buffs at :47. +Range is the one option
# that cannot wait this long - range is decided at targeting - so it is a variant row picked before
# targeting instead (buff_zwarte_hoop_range, ruling 10); the other five are picked here.
#
# "FIRST ATTACK ROLL EACH ROUND" IS A ROUND STAMP (ruling 9). Stamped at the Pier's first declared
# attack of the round, weapon or tech, on its turn or as a reaction, whether or not it spends - RAW,
# the first roll is the first roll. No per-round attack counter exists (unit_battle_state.gd), and
# uses_this_round resets at the owner's own turn start, not the round's (unit_action.gd:87-88).
#
# A LOOP OF SINGLE CHOICES. The choice bus has no multi-select or number picker
# (choice_bus.gd:131-141), so each charge is one prompt: the five options with their (k/2) tallies,
# plus Done. A pick spends its charge at once; cancelling is Done. An AI-controlled Pier never spends
# (mod convention, ruling 19) - it still stamps the round.
#
# THE PICKS LAND AFTER THE LOOP, each as one effect carrying its count: Reliable through the shared
# native_reliable.raise (which lowers itself when the attack's block is done, and composes with the
# Clark's writer - its header); the attack roll and Knockback as FINISH_DAMAGE buffs on the Pier whose
# BuffCore.state carries the count (a flat bonus is read through buff_core.get_values() with NO
# context, attack_roll.gd:182-189, so the count cannot come off the attack); Overshield and heat as
# one on-hit buff whose effect reads its counts off the DeclaredAttackSummary and fires once.
#
# DRAWN ON THE CARD AS ZWARTE HOOP. show_in_tooltip is true (the Hazard's Supporting Fire shape), so
# the passive's name and text reach the core Kit's card under this action's rows; it is still a hidden
# reaction everywhere else (no reaction point, never logged).
extends ActionReactionSelf

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')
const NativeReliable := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/reliable/native_reliable.gd')

enum PICK { RELIABLE, KNOCKBACK, ATTACK_ROLL, OVERSHIELD, HEAT }
## The menu, in card order (+Range, the card's second, is the variant row).
const MENU:Array[PICK] = [PICK.RELIABLE, PICK.KNOCKBACK, PICK.ATTACK_ROLL, PICK.OVERSHIELD, PICK.HEAT]
const OPTION_KEYS:Dictionary[PICK, String] = {
	PICK.RELIABLE: 'reliable',
	PICK.KNOCKBACK: 'knockback',
	PICK.ATTACK_ROLL: 'attack_roll',
	PICK.OVERSHIELD: 'overshield',
	PICK.HEAT: 'heat',
}
## "You may choose the same option up to twice".
const MAX_PER_OPTION := 2

const ACCURACY_BUFF := &'buff_zwarte_hoop_accuracy'
const KNOCKBACK_BUFF := &'buff_zwarte_hoop_knockback'
const ONHIT_BUFF := &'buff_zwarte_hoop_onhit'
## Where the on-hit counts ride: the DeclaredAttackSummary, the same object from PRE to the last hit.
const ONHIT_META := &'reag_zwarte_hoop_onhit'
## The Reliable raise's source token (native_reliable.raise: one raise per source per attack).
const RELIABLE_SOURCE := &'zwarte_hoop'

const KEY := 'gear.cp_inevitability_core.zwarte_hoop'

func show_in_tooltip(_kit:Kit) -> bool: return true

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not DeclaredAttackSummary.is_valid(triggering_event.context.resource): return false
	return gear.get_state(Core.SPENT_ROUND, -1) != Core.current_round(unit)

func activate(context:Context, activation:EventCore) -> void:
	var pier:Unit = context.unit
	var gear:GearCore = context.gear
	var declared:EventCore = context.event
	if not Unit.is_valid(pier) or not GearCore.is_valid(gear) or declared == null: return
	gear.set_state(Core.SPENT_ROUND, Core.current_round(pier))
	if not pier.is_player_controlled(): return

	var is_weapon:bool = declared.context.action is ActionAttackWeapon
	var picks:Dictionary[PICK, int] = {}
	while Core.charges(gear) > 0:
		var choices:Array = []
		for pick:PICK in MENU:
			var count:int = picks.get(pick, 0)
			var reason := ''
			if count >= MAX_PER_OPTION: reason = X.tr('%s.twice' % KEY)
			elif not is_weapon and (pick == PICK.RELIABLE or pick == PICK.KNOCKBACK): reason = X.tr('%s.not_weapon' % KEY)
			choices.append({
				text = X.tr('%s.option.%s' % [KEY, OPTION_KEYS[pick]]).format({count = count}),
				disabled_reason = reason,
			})
		choices.append({text = X.tr('%s.done' % KEY), disabled_reason = ''})

		var chosen:int = await choice_bus.choose_from_multiple_choice_for({
			brochure = BrochureCore.create({
				title = name(SpecificAction.create(pier, gear, self)),
				description = X.tr('%s.prompt' % KEY).format({charges = Core.charges(gear)}),
				choices = choices,
			}),
			can_voluntarily_cancel = true,
		})
		if activation.abort_without_unit(pier): return
		if chosen < 0 or chosen >= MENU.size(): break # Done, or cancelled
		if not str(choices[chosen].disabled_reason).is_empty(): continue # a refused pick costs nothing
		var pick:PICK = MENU[chosen]
		picks[pick] = picks.get(pick, 0) + 1
		Core.set_charges(pier, gear, Core.charges(gear) - 1)

	apply_picks(picks, pier, gear, declared, activation)

func apply_picks(picks:Dictionary[PICK, int], pier:Unit, gear:GearCore, declared:EventCore, activation:EventCore) -> void:
	if picks.get(PICK.RELIABLE, 0) > 0:
		NativeReliable.raise(declared, picks[PICK.RELIABLE], RELIABLE_SOURCE)
	if picks.get(PICK.ATTACK_ROLL, 0) > 0:
		apply_counted(activation, pier, gear, ACCURACY_BUFF, picks[PICK.ATTACK_ROLL])
	if picks.get(PICK.KNOCKBACK, 0) > 0:
		apply_counted(activation, pier, gear, KNOCKBACK_BUFF, picks[PICK.KNOCKBACK])
	var overshield:int = picks.get(PICK.OVERSHIELD, 0)
	var heat:int = picks.get(PICK.HEAT, 0)
	if overshield > 0 or heat > 0:
		declared.context.resource.set_meta(ONHIT_META, {overshield = overshield, heat = heat, done = false})
		apply_counted(activation, pier, gear, ONHIT_BUFF, 1)

## Hang one of the FINISH_DAMAGE buffs with its count in BuffCore.state['n'].
static func apply_counted(activation:EventCore, pier:Unit, gear:GearCore, buff_id:StringName, n:int) -> void:
	var buff:Buff = ContentLibrary.get_buff(buff_id)
	if buff == null:
		push_warning('%s: %s is not in the buffs index - the pick does nothing.' % [Core.CORE_ID, buff_id])
		return
	var core:BuffCore = UnitCondition.apply_buff(activation, pier, buff, gear)
	if core != null: core.set_state('n', n)
