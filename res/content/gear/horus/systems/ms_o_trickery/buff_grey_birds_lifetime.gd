# THE GREY BIRDS LIFETIME, shared by all three buffs O' Trickery's first invade applies (ruling 16):
# "until the end of the next round".
#
# NO Lancer.UNTIL VALUE IS ROUND-SHAPED. Every one of them is a turn, a move, a roll or MANUAL
# (lancer.gd:46-56), so the clock is kept by hand: the round count at application goes into buff
# state, and a NEW_ROUND trigger clears the buff once round_count >= applied + 2. Applied in round R,
# alive through the whole of R+1, gone as R+2 begins.
#
# THE COUNTER IS ALREADY INCREMENTED AT EITHER TIMING, which is what makes the arithmetic the same
# whichever is chosen: event_round_new.execute raises game_core.round_count at :31 and only THEN
# fires NEW_ROUND PRE at :40 ("end-of-previous-round stuff") and POST at :77 ("start-of-new-round
# stuff").
#
# PRE, NOT POST, AND FOR ONE REASON. Buff.trigger_timing is a SINGLE value (buff.gd:139) while
# triggers_on is an ARRAY (:138), and buff_grey_birds_recentre must be ATTACK_DECLARED / PRE. PRE is
# therefore the only timing all three can share - and sharing it is what lets one base carry the
# whole lifetime instead of a keeper buff walking the other two.
#
# EACH BUFF CLEARS ITSELF, AND activate IS DELIBERATELY NOT OVERRIDDEN HERE. Buff.activate's default
# body is UnitCondition.clear_buff(activation, activation.context.unit, core) (buff.gd:254-255), and
# activation.context.unit is the HOLDER - the reaction bus builds the block with unit = the unit whose
# buffs it walked (reaction_bus.gd:61-67). So "clear myself when the gate says it is time" is free.
# The alternative the design offered - one keeper that clears all three - can half-expire if the
# keeper is cleared by anything else first; three independent lifetimes cannot.
#
# get_required_triggering_context RETURNS NOTHING, AND THAT IS LOAD-BEARING rather than lazy.
# Buff.check_required_triggering_context refuses the trigger when any listed prop is absent
# (buff.gd:258-262) and does_buff_trigger ANDs it (reaction_bus.gd:136), and event_round_new's
# context carries only `map`. A subclass that listed unit/gear/action/resource for its OTHER trigger
# would silently lose its expiry - see buff_grey_birds_recentre's own header.
#
# No class_name (res/content/gear/shared/README.md): a class_name declared in a script a mod loads at
# runtime is never registered. The two subclasses extend it BY PATH, which is this mod's own idiom
# (action_more_black_powder.gd:23).
extends Buff

const APPLIED_ROUND_KEY := 'grey_birds_applied_round'
## Applied in round R, alive through R+1, gone as R+2 begins.
const ROUNDS_ALIVE := 2

func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	core.set_state(APPLIED_ROUND_KEY, current_round(unit.map if Unit.is_valid(unit) else null))

## The round the game is on, or -1 when there is no game core to read - a spec's bare map rather
## than a live combat. A buff that cannot read the clock never expires BY the clock, which is the
## safe direction: its other two lifetimes (the owner dying, the gear being destroyed) still apply,
## and the alternative would be a buff that vanishes the instant it is applied.
static func current_round(map:MapState) -> int:
	if map == null or not GamemasterCore.is_valid(map.game_core): return -1
	return map.game_core.round_count

func is_expired(core:BuffCore, map:MapState) -> bool:
	var applied:int = core.get_state(APPLIED_ROUND_KEY, -1)
	if applied < 0: return false
	var now := current_round(map)
	if now < 0: return false
	return now >= applied + ROUNDS_ALIVE

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	return is_expired(core, triggering_event.context.map)
