## GLIMMERING ARMAMENTS, the active half of MÖBIAN RAINBOW.
##
##   "For the rest of the scene you gain one of the following effects: Wormhole Grasp /
##    Shimmering Shield."
##
## ONE PROTOCOL WITH A TWO-CHOICE PROMPT (ruling 1), not two actions. Closer to the card's single
## heading, and choose_from_multiple_choice is the one picker the testkit responder can answer -
## choose_from_gear, the native gear picker, has no answerer at all, so a spec using it would hang.
##
## THE ORDER OF THE THREE LINES IN activate IS THE WHOLE OF RULING 1. The prompt comes FIRST, the
## cancel returns BEFORE spend_actions, and spend_actions is what
## UnitAction.spend_actions_gain_heat calls spend_core_power from (unit_action.gd:272). Cancel after
## the spend and the card's "you gain one of the following" would cost a core power for nothing.
##
## THE CHOICE LABELS ARE THE MARKERS' OWN NAME ROWS, not new option.* keys. One string in one place:
## the menu entry and the chip the press produces read identically, and a rename moves both.
## test_the_prompt_offers_exactly_the_two_effects is what holds them together.
##
## A BUFF CANNOT CARRY OTHER BUFFS, so each armament is a BUNDLE applied together - the marker the
## player sees plus its hidden machinery. The marker is what
## res/engine/character/unit/service/unit_relation.gd_ext.gd reads by id to waive the Superheavy
## Overwatch refusal, and what buff_effervescent_immunity.cap_for reads by id to raise its cap.
##
## UnitCondition.apply_buffs RATHER THAN A LOOP OF apply_buff: it applies the whole array and updates
## the caches ONCE at the end (unit_condition.gd:703-715), rather than once per buff.
##
## WHY THERE IS NO hibernate_action CALL. The Vauban's protocol adds one belt-and-braces; the design
## names none here, and consumes_cp already answers: UnitAction.get_gear_unavailable_reason refuses
## an action whose consumes_core_power() is true on a unit with has_core_power false
## (unit_action.gd:145). Taking the button OFF the gear bar rather than greying it out is a UX
## preference, and it is the author's to make at the close rather than this task's to assume.
##
## THE usage_group ON THE .tres IS NOT DECORATION: a protocol and any later pressable on one Kit need
## a group EACH (gear_core.gd:166-171, the Subutai SP2 lesson). This Kit has one action today, and
## a Kit that grows a second would otherwise share the first's per-turn tally.
##
## FIXED AT THE SP5 CLOSE: fxg_use = fxg_super_activation.tscn on the .tres was inert for three
## sub-projects because nothing called run_system_fxgs - the exact omission action_spin.gd's own
## header (ms_flourishing_twirl) documents and cites this file by name as the still-live case.
## ActionSystem.run_system_fxgs (action_system.gd:70-105) is read from NOWHERE automatically; every
## one of its ~60 callers invokes it from their own activate. test_the_activation_plays_its_fx below
## is the source-level pin the same header prescribes, since ruling 20 forbids a spec on the
## animation itself but says nothing about the call site.
extends ActionSystem

## Wormhole Grasp: the visible marker, the unfiltered +1 threat, the ATTACK_DECLARED PRE observer that
## stamps HALF_DAMAGE on an overwatch, and the on-hit Slow.
const WORMHOLE_BUNDLE:Array[StringName] = [
	&'buff_wormhole_grasp',
	&'buff_wormhole_grasp_threat',
	&'buff_wormhole_grasp_half',
	&'buff_wormhole_grasp_slow',
]

## Shimmering Shield: the visible marker, which buff_effervescent_immunity.cap_for reads by id, and
## the hidden cover chip that carries the +1 Difficulty.
const SHIELD_BUNDLE:Array[StringName] = [
	&'buff_shimmering_shield',
	&'buff_shimmering_shield_cover',
]

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return
	var specific := SpecificAction.from_context(context)

	# THE PROMPT COMES FIRST. choose_from_multiple_choice returns the chosen index, or -1 when the
	# player cancels (choice_bus.gd:131-141). BrochureCore.create normalises plain Strings into its
	# {text, disabled_reason} dictionaries (brochure_core.gd:26-28), which is the shape vanilla's own
	# callers pass.
	#
	# AI-CONTROLLED, NO PROMPT. fateofman's Cascades hands a cascading player mech to the AI, and
	# vanilla's Hand Over Control does the same (buff_hand_over_control, unit.gd:252). A core-power
	# protocol is never run through Cascade Personalities' safety scan - plan_core_power gathers
	# consumes_cp actions unscanned (cascade_system_action_ai.gd:48-64) - so this menu would open on an
	# AI turn with nobody to answer it. Author's ruling 2026-09-28: the AI takes Wormhole Grasp, and
	# never declines. Kill Host's shape (Thy Hubris action_kill_host.gd:135).
	var chosen:int
	if unit.is_player_controlled():
		chosen = await choice_bus.choose_from_multiple_choice(specific, [
			Translate.gear('buff_wormhole_grasp', 'name'),
			Translate.gear('buff_shimmering_shield', 'name'),
		], true)
	else:
		chosen = 0 # Wormhole Grasp
	# Cancelled, or the unit died mid-prompt. Return BEFORE spend_actions, which is what makes
	# declining free (ruling 1).
	if chosen < 0: return
	if activation.abort_without_unit(unit): return

	spend_actions(activation)

	# THE FX, NOT THE fxg_use WIRING - see the header. The await crosses real frames, so re-check
	# before touching `unit` again, the same guard action_spin.gd's own call takes.
	await run_system_fxgs(unit)
	if activation.abort_without_unit(unit): return

	var bundle:Array[StringName] = WORMHOLE_BUNDLE if chosen == 0 else SHIELD_BUNDLE
	var buffs:Array[Buff] = []
	for buff_id:StringName in bundle:
		var buff:Buff = ContentLibrary.get_buff(buff_id)
		if buff != null:
			buffs.append(buff)
		else:
			# A TYPO IN A BUNDLE ID IS OTHERWISE SILENT, and silent in the worst way: the visible
			# marker still lands, so the waiver and the cap still read it, and every spec that checks
			# the marker stays green while the mechanic is simply absent. Task 6 appends to
			# SHIELD_BUNDLE, which is exactly when this would first matter. push_warning and not
			# push_error deliberately - GUT fails a test on push_error (gut_config.gd:57) and a
			# missing buff should not red a suite that is not about this Kit.
			push_warning('%s: bundle buff %s is not in the buffs index - the armament applies WITHOUT it.'
				% [gear.kit.compcon_id, buff_id])
	UnitCondition.apply_buffs(activation, unit, buffs, gear)
