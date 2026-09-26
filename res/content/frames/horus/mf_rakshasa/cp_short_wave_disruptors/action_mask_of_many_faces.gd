## MASK OF MANY FACES (design 2.1, rulings 12-15): "At the start of each of your turns choose one of the
## following effects. These effects last until the start of your next turn and you cannot choose the
## same option two turns in a row".
##
## A point-free ActionReactionSelf on new_turn at POST - the Leoleth's Rage roll timing
## (action_rage_roll.gd's header): event_turn_start clears START_OF_TURN buffs in
## new_turn_for_statuses (event_turn_start.gd:76) BEFORE it queues the POST reactions (:56), so last
## turn's chip is already gone and this turn's survives until the next own turn start (ruling 15).
##
## PLAYER-CONTROLLED: a mandatory five-button brochure, card order, with last turn's mode disabled and
## Soulbind disabled when no other character is within Sensors (ruling 12). A disabled button still
## resolves (informational_brochure.gd:76-84, the Grutte Pier's action_zwarte_hoop_spend.gd), so the
## pick is RE-CHECKED and a refused one asks again - at most MAX_ASKS times, then the AI's rotation
## decides, so a responder that keeps answering a disabled button can never hang the turn start.
## A cancel (the brochure is mandatory, but a request can still be aborted) takes the rotation too.
##
## AI-CONTROLLED (is_player_controlled() false: an NPC Rakshasa, dialogue, Hand Over Control): the next
## option in card order after the last one, skipping whatever is disabled (ruling 14). No prompt: the
## brochure has no AI answerer.
##
## STUNNED OR SHUT DOWN STILL CHOOSES: a non-consuming reaction passes the stun gate
## (action_reaction.gd:62-66). The card's "at the start of each of your turns" is not an action.
##
## THE MEMORY is the core gear's state (short_wave_disruptors.gd), which repair clears, so the first
## turn of every scene may choose anything (ruling 13).
##
## SOULBIND picks its partner right here, after the chip: auto-picked when there is one candidate, a
## mandatory unit pick for a player, the nearest hostile character for the AI (nearest character at
## all when no hostile is in Sensors). Nothing else in the menu needs a follow-up.
##
## DRAWN ON THE CARD: this action's own name and effect rows are the passive's LCP text, so the core
## Kit's card shows it (Action.show_in_tooltip's default: an effect row of its own). The mode reactions
## beside it on the Kit are hidden by localization_key_override.
extends ActionReactionSelf

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

const KEY := 'gear.cp_short_wave_disruptors.mask'
## How many times a refused pick is asked again before the rotation decides.
const MAX_ASKS := 3

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return

	var mode:int = await choose(unit, gear)
	if not Unit.is_valid(unit) or mode == Core.NO_MODE: return
	gear.set_state(Core.LAST_MODE_KEY, mode)
	gear.set_state(Core.PARTNER_KEY, &'')

	var chip:Buff = ContentLibrary.get_buff(Core.CHIPS[mode])
	if chip == null:
		# The Rage roll's reasoning (action_rage_roll.gd): loud, but not push_error, which would red
		# every other suite through GUT's failure_error_types.
		push_warning('%s: %s is not in the buffs index - the mode does nothing.' % [Core.CORE_ID, Core.CHIPS[mode]])
		return
	apply_buffs(activation, unit, [chip] as Array[Buff])
	var live:BuffCore = UnitCondition.get_buff(unit, Core.CHIPS[mode])
	if live != null: effect_bus.play_text(live.name_text(), unit.tile())

	if mode == Core.MODE.SOULBIND: await bind(context, unit, gear)

func choose(unit:Unit, gear:GearCore) -> int:
	if not unit.is_player_controlled(): return rotate(unit, gear)
	for ask:int in MAX_ASKS:
		var choices:Array = []
		for mode:int in Core.CHIPS.size():
			choices.append({text = X.tr('gear.%s.name' % Core.CHIPS[mode]), disabled_reason = disabled_reason(unit, gear, mode)})
		var chosen:int = await choice_bus.choose_from_multiple_choice_for({
			brochure = BrochureCore.create({
				title = name(SpecificAction.create(unit, gear, self)),
				description = Translate.action(gear.kit, self, 'effect'),
				choices = choices,
			}),
			can_voluntarily_cancel = false,
		})
		if not Unit.is_valid(unit): return Core.NO_MODE
		if chosen < 0 or chosen >= Core.CHIPS.size(): break # nobody answered
		if disabled_reason(unit, gear, chosen).is_empty(): return chosen
	return rotate(unit, gear)

## Ruling 14: the next enabled option in card order after the last one; Drain on a scene's first turn.
## At most two options are ever disabled, so this always finds one.
func rotate(unit:Unit, gear:GearCore) -> int:
	var start:int = Core.last_mode(gear) + 1
	for i:int in Core.CHIPS.size():
		var mode:int = (start + i) % Core.CHIPS.size()
		if disabled_reason(unit, gear, mode).is_empty(): return mode
	return Core.NO_MODE

func disabled_reason(unit:Unit, gear:GearCore, mode:int) -> String:
	if mode == Core.last_mode(gear): return X.tr('%s.chosen_last_turn' % KEY)
	if mode == Core.MODE.SOULBIND and Core.soulbind_candidates(unit).is_empty():
		return X.tr('%s.nobody_in_sensors' % KEY)
	return ''

## SOULBIND's partner (ruling 18): any character within Sensors, ally or hostile.
func bind(context:Context, unit:Unit, gear:GearCore) -> void:
	var candidates := Core.soulbind_candidates(unit)
	if candidates.is_empty(): return # the menu refuses Soulbind first; this is a race with a death
	var chosen:Unit = null
	if candidates.size() == 1:
		chosen = candidates.front()
	elif unit.is_player_controlled():
		chosen = await choice_bus.choose_unit(candidates, false, SpecificAction.from_context(context))
	if not Unit.is_valid(unit): return
	if not Unit.is_valid(chosen) or not candidates.has(chosen): chosen = nearest(unit, candidates)
	if not Unit.is_valid(chosen): return
	gear.set_state(Core.PARTNER_KEY, chosen.core.persistent_id)
	effect_bus.play_text(X.tr('gear.%s.name' % Core.CHIPS[Core.MODE.SOULBIND]), chosen.tile())

## The AI's partner: the nearest hostile character, else the nearest character. Ties keep the first
## found (map registration order).
static func nearest(unit:Unit, candidates:Array[Unit]) -> Unit:
	var best:Unit = null
	var best_hostile:bool = false
	var best_distance:int = 0
	for other:Unit in candidates:
		var hostile:bool = UnitRelation.are_enemies(unit, other)
		var distance:int = UnitRelation.distance_between(unit, other)
		var better:bool = (
			best == null
			or (hostile and not best_hostile)
			or (hostile == best_hostile and distance < best_distance)
		)
		if better:
			best = other
			best_hostile = hostile
			best_distance = distance
	return best
