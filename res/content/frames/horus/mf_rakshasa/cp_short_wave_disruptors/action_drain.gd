## DRAIN (a Mask of Many Faces mode, design 2.2, ruling 16): "Your successful invades always apply
## Impaired and +1 heat."
##
## The Koremasa's tech-hit watcher (action_entrap_mark_koremasa.gd), with the .tres doing the filtering:
## ATTACKER, ENEMIES, require_hit, allow_weapon = false, allow_tech = true and allow_basic = TRUE - the
## vanilla Invade (ms_fragment_signal) is basic gear. HOSTILE ONLY is the author's call: the engine
## zeroes an invade's own heat against a non-enemy (action_attack_tech.gd:19-23), and every tech "hit"
## on an ally is an auto-hit. A "successful invade" is a hit with an ActionAttackTech whose is_invade is
## true, so Markerlight and its kind are out. A Silver Tongue reroll that hits is a new attack by the
## Rakshasa (ruling 11) and counts.
##
## Impaired at its standard until (END_OF_NEXT_TURN, the Gut Reactor's), and the heat as a SEPARATE
## event naming the Rakshasa: 3 in all with the invade's own 2. Only while the Drain chip is held.
##
## NOT A REACTION POINT and not limited. Spent anyway, so the tally is honest. NO PROMPT ("always").
## HIDDEN from the card by localization_key_override: the Mask's own row carries the text, and the log
## reads "Drain" off the chip's name row.
extends ActionReactionAttacked

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

const HEAT := 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not Core.holds(unit, Core.MODE.DRAIN): return false
	var action = triggering_event.context.action
	return action is ActionAttackTech and action.is_invade

func activate(context:Context, activation:EventCore) -> void:
	var defender:Unit = context.event.context.target_unit
	if activation.abort_without_unit(defender): return
	spend_actions(activation)
	UnitCondition.apply_status(activation, defender, Lancer.STATUS.IMPAIRED, Lancer.UNTIL.END_OF_NEXT_TURN, context.gear.persistent_id)
	activation.queue_event(&'event_unit_damage', {
		unit = defender,
		number = HEAT,
		category = Lancer.DAMAGE_TYPE.HEAT,
		target_unit = context.unit, # who did this to them
		gear = context.gear,
		action = self,
	})
