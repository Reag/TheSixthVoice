## ENTRAP'S MARK: "a hostile character ... that it has already successfully hit with tech attack that
## round" (design 1.4, ruling 16). Hung on the TARGET by action_entrap_mark_koremasa when the Koremasa
## lands a tech attack; read by action_entrap_koremasa when it lands a melee one.
##
## VISIBLE, deliberately: the chip is how the player sees who can be Entrapped this round.
##
## "THAT ROUND" IS THE TRUE ROUND, not the Koremasa's turn. No Lancer.UNTIL value is round-shaped, so
## the clock is kept by hand - O' Trickery's buff_grey_birds_lifetime.gd shape with one round alive
## instead of two: the round count at application goes into buff state, and a NEW_ROUND trigger clears
## the buff once round_count has moved past it. event_round_new raises round_count at :31 BEFORE
## NEW_ROUND PRE fires at :40, so PRE already sees the new number.
##
## THE STAMP IS ALSO WHAT THE REACTION READS (is_live below), so the mark and the reaction cannot
## disagree about "this round" even if the expiry trigger were ever missed.
##
## A MAP WITH NO GAME CORE (a bare spec map) reads round -1: never expired BY the clock, and never
## live for the reaction either - the safe direction for both.
##
## Buff.activate's default body clears the buff from its holder (buff.gd:254-255), so the expiry needs
## no activate of its own. get_required_triggering_context returns nothing: event_round_new's context
## carries only `map` (buff_grey_birds_lifetime.gd's header).
##
## No class_name (res/content/gear/shared/README.md): the reaction preloads this file by path.
extends Buff

const APPLIED_ROUND_KEY := 'entrap_applied_round'

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	core.set_state(APPLIED_ROUND_KEY, current_round(unit.map if Unit.is_valid(unit) else null))

static func current_round(map:MapState) -> int:
	if map == null or not GamemasterCore.is_valid(map.game_core): return -1
	return map.game_core.round_count

## Was this mark applied in the round the game is on now?
static func is_live(core:BuffCore, map:MapState) -> bool:
	var applied:int = core.get_state(APPLIED_ROUND_KEY, -1)
	var now := current_round(map)
	return applied >= 0 and applied == now

func get_required_triggering_context() -> Array[Context.PROP]:
	return []

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var applied:int = core.get_state(APPLIED_ROUND_KEY, -1)
	if applied < 0: return false
	var now := current_round(triggering_event.context.map)
	return now >= 0 and now > applied
