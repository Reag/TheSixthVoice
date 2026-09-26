## WORM CODE: "1/round, when a hostile character fails a save the Rakshasa forced, it may have them
## take 2 heat." Design 1.2, rulings 3-6.
##
## The Lesson of the Open Door's shape (action_the_lesson_of_the_open_door.gd): a forced_save POST
## reaction, the saver's heat queued as an event_unit_damage of HEAT (there is no "gain heat" event,
## so resistance halves it and Invulnerable skips it - ruling 5). The gates are the Vauban's
## (action_grav_amped_shock.gd):
##   - FAILED: event_unit_save puts the result on context.boolean after PRE (event_unit_save.gd:54).
##   - THE RAKSHASA FORCED IT: the forcer resolved through get_owner_unit_or_self (unit.gd:270-273),
##     so a save its mine or drone forces counts (ruling 4).
##   - A FULL TRIFECTA: the saver's own buffs never see a forcer that is not unit AND gear AND action
##     (unit_hasecheck.gd:180), so neither does this - the Vauban close's M-3 reasoning.
##   - A HOSTILE CHARACTER: is_actor(), the mod-wide rule (rulings row 301, re-confirmed for this
##     frame at SP1 over design ruling 3's is_character()). A drone is not a character. A
##     non-character never reaches here at all: make_*_save auto-fails it without raising the event
##     (unit_hasecheck.gd:43-58).
## EVERY save the Rakshasa forces counts, its own frame's included (ruling 6) - with ONE exception:
##
## NOT INSIDE THE ENSORCEL WINDOW (author's ruling, rulings "Worm Code inside the Ensorcel window"). An
## invade run through Ensorcel that forces a save (Smite, Logic Bomb) resolves while the saver holds
## this Rakshasa's buff_ensorcel_suppressor, which cancels the Rakshasa's heat - so Worm Code would ask,
## spend its round and deal nothing. It is not offered there at all: the gate is in triggers_on_event,
## so nothing is asked and nothing is spent, and the round is kept for a later save. Only THIS
## Rakshasa's suppressor (owner-matched, as the suppressor itself matches its owner) closes it.
##
## THE "MAY" IS ASKED BEFORE THE ROUND IS SPENT, so declining keeps the 1/round (ruling 4). spend_actions
## is what moves uses_this_round on the usage group `worm_code` (reset at the Rakshasa's own turn
## start, ruling 3); an ActionReaction's activate has to call it itself.
##
## NOT A REACTION POINT ("1/round", not "Reaction"): consumes_rxn = false in the .tres. HIDDEN from the
## card by localization_key_override (action.gd:348); the Kit's own rows carry the text, and the
## prompt and the log read "Worm Code".
extends ActionReaction

const HEAT := 2
## action_ensorcel.gd SUPPRESSOR: held by the Ensorcel's target only while the invade resolves.
const ENSORCEL_SUPPRESSOR := &'buff_ensorcel_suppressor'

func get_per_round_hard_limit(_specific:SpecificAction) -> int: return 1

# responds to event_unit_save
func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.target_units, # the unit MAKING the save
		Context.PROP.unit,         # the unit FORCING it
	]

func triggers_on_event(unit:Unit, _gear:GearCore, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.boolean == true: return false # they made the save

	var forcer:Unit = context.unit
	if not Unit.is_valid(forcer): return false
	if not SpecificAction.is_valid(SpecificAction.from_context(context)): return false
	if forcer.get_owner_unit_or_self() != unit: return false

	var saver:Unit = context.target_unit
	if not Unit.is_valid(saver): return false
	if not saver.is_actor(): return false
	if not UnitRelation.are_enemies(unit, saver): return false
	return not is_inside_ensorcel(unit, saver)

## Whether `saver` holds `unit`'s own Ensorcel suppressor, i.e. the save was forced inside the window.
static func is_inside_ensorcel(unit:Unit, saver:Unit) -> bool:
	for suppressor:BuffCore in UnitCondition.get_buffs(saver, ENSORCEL_SUPPRESSOR):
		if suppressor.get_owner_unit(unit.map) == unit: return true
	return false

func activate(context:Context, activation:EventCore) -> void:
	var saver:Unit = context.event.context.target_unit
	if activation.abort_without_unit(saver): return

	var confirmed := await CommonActionUtil.confirm_use(context, [saver])
	if activation.abort_when(not confirmed): return
	spend_actions(activation)

	activation.queue_event(&'event_unit_damage', {
		unit = saver,
		number = HEAT,
		category = Lancer.DAMAGE_TYPE.HEAT,
		target_unit = context.unit, # who did this to them
	})
